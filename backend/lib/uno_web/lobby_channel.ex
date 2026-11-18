defmodule UnoWeb.LobbyChannel do
  use Phoenix.Channel, log_join: false, log_handle_in: false
  def join("lobby", %{}, socket), do: {:ok, socket}

  def handle_in("create", payload, socket) when payload == %{} do
    case Uno.Lobby.create() do
      {:ok, code} -> {:reply, {:ok, %{code: code}}, socket}
      {:error, message} -> {:reply, {:error, %{message: message}}, socket}
    end
  end

  def handle_in(_, _, socket), do: {:reply, {:error, %{message: "Invalid request."}}, socket}
end
