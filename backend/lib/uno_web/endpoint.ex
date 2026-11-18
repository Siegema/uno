defmodule UnoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :uno
  socket("/socket", UnoWeb.UserSocket, websocket: [max_frame_size: 8192], longpoll: false)
  plug(Plug.Static, at: "/", from: :uno)
  plug(UnoWeb.Router)
end
