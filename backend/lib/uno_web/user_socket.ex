defmodule UnoWeb.UserSocket do
  use Phoenix.Socket
  channel("lobby", UnoWeb.LobbyChannel)
  channel("room:*", UnoWeb.RoomChannel)
  def connect(_params, socket, _info), do: {:ok, socket}
  def id(_socket), do: nil
end
