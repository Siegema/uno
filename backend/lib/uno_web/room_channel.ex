defmodule UnoWeb.RoomChannel do
  use Phoenix.Channel, log_join: false, log_handle_in: false

  def join("room:" <> code, params, socket) when is_map(params) do
    if Regex.match?(~r/^[A-HJ-NP-Z2-9]{6}$/, code) and
         Enum.all?(Map.keys(params), &(&1 in ~w(name token admissionKey))) do
      case Registry.lookup(Uno.Registry, code) do
        [{pid, _}] ->
          ref = Process.monitor(pid)

          case Uno.Room.join(pid, params, self()) do
            {:ok, token, view, id} ->
              {:ok, %{token: token, view: view},
               assign(socket, %{code: code, player_id: id, times: [], room_ref: ref})}

            {:error, message} ->
              Process.demonitor(ref, [:flush])
              {:error, %{message: message}}
          end

        [] ->
          {:error, %{message: "Room not found."}}
      end
    else
      {:error, %{message: "Invalid room or join payload."}}
    end
  end

  def join(_, _, _), do: {:error, %{message: "Invalid join payload."}}

  def handle_in("action", payload, socket) when is_map(payload) do
    now = System.monotonic_time(:millisecond)
    times = Enum.filter(socket.assigns.times, &(now - &1 < 1000))
    socket = assign(socket, :times, [now | Enum.take(times, 10)])

    if length(times) >= 10 do
      {:reply, {:error, %{message: "Too many actions; slow down."}}, socket}
    else
      case Uno.Room.action(socket.assigns.code, socket.assigns.player_id, payload) do
        {:ok, view} -> {:reply, {:ok, %{view: view}}, socket}
        {:error, message} -> {:reply, {:error, %{message: message}}, socket}
      end
    end
  end

  def handle_in(_, _, socket), do: {:reply, {:error, %{message: "Invalid request."}}, socket}

  def handle_info({:room_state, view}, socket) do
    push(socket, "state", view)
    {:noreply, socket}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{assigns: %{room_ref: ref}} = socket) do
    push(socket, "room_closed", %{
      message: "This room is no longer available. Create or join a room to play."
    })

    {:stop, :normal, socket}
  end
end
