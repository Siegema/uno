defmodule Uno.Lobby do
  use GenServer
  @alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state), do: {:ok, state}
  def create, do: GenServer.call(__MODULE__, :create)

  def handle_call(:create, _from, state) do
    now = System.monotonic_time(:millisecond)
    times = Enum.filter(Map.get(state, :times, []), &(now - &1 < 60_000))

    cond do
      length(times) >= 30 ->
        {:reply, {:error, "Too many rooms created; try again later."}, %{times: times}}

      DynamicSupervisor.count_children(Uno.RoomSupervisor).active >= 500 ->
        {:reply, {:error, "Room capacity reached."}, %{times: times}}

      true ->
        code = code()

        case DynamicSupervisor.start_child(Uno.RoomSupervisor, {Uno.Room, code}) do
          {:ok, _} -> {:reply, {:ok, code}, %{times: [now | times]}}
          _ -> {:reply, {:error, "Could not create room; try again."}, %{times: times}}
        end
    end
  end

  defp code do
    code =
      for <<x <- :crypto.strong_rand_bytes(6)>>,
        into: "",
        do: <<Enum.at(@alphabet, rem(x, length(@alphabet)))>>

    if Registry.lookup(Uno.Registry, code) == [], do: code, else: code()
  end
end
