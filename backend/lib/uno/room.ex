defmodule Uno.Room do
  use GenServer
  alias Uno.Game

  def child_spec(code),
    do: %{id: {__MODULE__, code}, start: {__MODULE__, :start_link, [code]}, restart: :temporary}

  def start_link(code),
    do: GenServer.start_link(__MODULE__, code, name: {:via, Registry, {Uno.Registry, code}})

  def init(code) do
    Process.send_after(self(), :cleanup, 60_000)

    {:ok,
     %{
       code: code,
       players: [],
       connections: %{},
       game: nil,
       revision: 0,
       history: %{},
       empty_since: now()
     }}
  end

  def format_status(status) do
    Map.new(status, fn
      {:state, _} -> {:state, "[REDACTED]"}
      {:message, _} -> {:message, "[REDACTED]"}
      {:log, _} -> {:log, []}
      entry -> entry
    end)
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp random, do: Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

  def join(room, params, pid) when is_pid(room) do
    try do
      GenServer.call(room, {:join, params, pid})
    catch
      :exit, _ -> {:error, "Room is unavailable."}
    end
  end

  def action(code, id, params), do: call(code, {:action, id, params})

  defp call(code, message) do
    case Registry.lookup(Uno.Registry, code) do
      [{pid, _}] ->
        try do
          GenServer.call(pid, message)
        catch
          :exit, _ -> {:error, "Room is unavailable."}
        end

      [] ->
        {:error, "Room not found."}
    end
  end

  def handle_call({:join, params, pid}, _from, s) do
    name = params["name"]
    token = params["token"]
    admission_key = params["admissionKey"]
    has_token = Map.has_key?(params, "token")
    valid_key = is_binary(admission_key) and Regex.match?(~r/\A[0-9a-f]{64}\z/, admission_key)

    existing =
      if has_token,
        do: Enum.find(s.players, &(&1.token == token)),
        else: if(valid_key, do: Enum.find(s.players, &(&1.admission_key == admission_key)))

    cond do
      not is_binary(name) or not String.valid?(name) or String.trim(name) == "" or
          byte_size(name) > 40 ->
        {:reply, {:error, "Name must be 1–40 bytes."}, s}

      has_token and (not is_binary(token) or is_nil(existing)) ->
        {:reply, {:error, "Invalid reconnect token."}, s}

      not has_token and not valid_key ->
        {:reply, {:error, "Invalid admission key."}, s}

      existing ->
        s = connect(s, existing.id, pid)
        notify(s)
        {:reply, {:ok, existing.token, view(s, existing.id), existing.id}, s}

      s.game != nil ->
        {:reply, {:error, "Game already started."}, s}

      length(s.players) >= 4 ->
        {:reply, {:error, "Room is full."}, s}

      true ->
        p = %{
          id: random(),
          token: random(),
          admission_key: admission_key,
          name: String.trim(name)
        }

        s = %{s | players: s.players ++ [p], revision: s.revision + 1} |> connect(p.id, pid)
        notify(s)
        {:reply, {:ok, p.token, view(s, p.id), p.id}, s}
    end
  end

  def handle_call({:action, id, params}, _from, s) do
    cmd = params["commandId"]
    prior = Enum.find(Map.get(s.history, id, []), fn {key, _, _} -> key == cmd end)

    cond do
      not is_binary(cmd) or byte_size(cmd) < 1 or byte_size(cmd) > 128 ->
        {:reply, {:error, "Invalid command ID."}, s}

      prior != nil ->
        {_, old, _} = prior

        if old == params,
          do: {:reply, {:ok, view(s, id)}, s},
          else: {:reply, {:error, "Command ID already used."}, s}

      not is_integer(params["revision"]) or params["revision"] != s.revision ->
        {:reply, {:error, "Stale revision; refresh your state."}, s}

      true ->
        case apply_action(s, id, params) do
          {:error, message} ->
            {:reply, {:error, message}, s}

          {:ok, s} ->
            s = %{s | revision: s.revision + 1}
            history = Enum.take([{cmd, params, s.revision} | Map.get(s.history, id, [])], 100)
            s = put_in(s.history[id], history)
            notify(s)
            {:reply, {:ok, view(s, id)}, s}
        end
    end
  end

  defp apply_action(s, id, %{"type" => "start"} = p) do
    cond do
      not valid_keys?(p, ~w(type revision commandId)) ->
        {:error, "Invalid action payload."}

      hd(s.players).id != id ->
        {:error, "Only the host can start."}

      s.game != nil and s.game.winner == nil ->
        {:error, "Game already started."}

      length(s.players) < 2 or Enum.any?(s.players, &(not connected?(s, &1.id))) ->
        {:error, "At least two players must be present and all players connected."}

      true ->
        {:ok, %{s | game: Game.new(Enum.map(s.players, &Map.take(&1, [:id, :name])))}}
    end
  end

  defp apply_action(s, id, %{"type" => type} = p) when type in ~w(play draw pass uno) do
    keys =
      if type == "play",
        do: ~w(type revision commandId cardId color),
        else: ~w(type revision commandId)

    cond do
      not valid_keys?(p, keys) ->
        {:error, "Invalid action payload."}

      type == "play" and
          (not is_binary(p["cardId"]) or byte_size(p["cardId"]) > 128 or
             (Map.has_key?(p, "color") and p["color"] not in Game.colors())) ->
        {:error, "Invalid card or color."}

      is_nil(s.game) or s.game.winner != nil ->
        {:error, "No game in progress."}

      Game.current(s.game).id != id ->
        {:error, "It is not your turn."}

      true ->
        case Game.action(s.game, type, p) do
          {:ok, game} -> {:ok, %{s | game: game}}
          error -> error
        end
    end
  end

  defp apply_action(_, _, _), do: {:error, "Invalid action."}
  defp valid_keys?(map, keys), do: Enum.all?(Map.keys(map), &(&1 in keys))

  defp connect(s, id, pid) do
    ref = Process.monitor(pid)
    %{s | connections: Map.put(s.connections, ref, {id, pid}), empty_since: nil}
  end

  defp connected?(s, id), do: Enum.any?(s.connections, fn {_, {player, _}} -> player == id end)

  def handle_info({:DOWN, ref, :process, _, _}, s) do
    connections = Map.delete(s.connections, ref)

    s = %{
      s
      | connections: connections,
        empty_since: if(map_size(connections) == 0, do: now(), else: nil)
    }

    notify(s)
    {:noreply, s}
  end

  def handle_info(:cleanup, s) do
    if s.empty_since && now() - s.empty_since >= 600_000 do
      {:stop, :normal, s}
    else
      Process.send_after(self(), :cleanup, 60_000)
      {:noreply, s}
    end
  end

  defp notify(s),
    do: Enum.each(s.connections, fn {_, {id, pid}} -> send(pid, {:room_state, view(s, id)}) end)

  defp view(s, id) do
    g = s.game
    me = if g, do: Enum.find(g.players, &(&1.id == id))
    my_turn = g && g.winner == nil && Game.current(g).id == id

    %{
      code: s.code,
      phase: if(is_nil(g), do: "lobby", else: if(g.winner, do: "finished", else: "playing")),
      selfId: id,
      hostId: hd(s.players).id,
      players:
        Enum.map(s.players, fn p ->
          gp = if g, do: Enum.find(g.players, &(&1.id == p.id))

          %{
            id: p.id,
            name: p.name,
            count: if(gp, do: length(gp.hand), else: 0),
            connected: connected?(s, p.id)
          }
        end),
      hand: if(me, do: me.hand, else: []),
      topCard: if(g, do: hd(g.discard), else: nil),
      currentPlayerId: if(g && !g.winner, do: Game.current(g).id, else: nil),
      currentColor: if(g, do: g.color, else: "red"),
      direction: if(g, do: g.direction, else: 1),
      drawnCardId: if(my_turn, do: g.drawn, else: nil),
      unoArmed: if(my_turn, do: g.uno, else: false),
      winnerId: if(g, do: g.winner, else: nil),
      playableIds: if(my_turn, do: Enum.map(Game.playable(g), & &1.id), else: []),
      log: if(g, do: g.log, else: []),
      revision: s.revision
    }
  end
end
