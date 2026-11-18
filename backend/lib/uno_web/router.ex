defmodule UnoWeb.Router do
  use Plug.Router
  plug(:match)
  plug(:dispatch)
  get("/health", do: send_resp(conn, 200, "ok"))

  get _ do
    path = Application.app_dir(:uno, "priv/static/index.html")
    if File.exists?(path), do: send_file(conn, 200, path), else: send_resp(conn, 404, "Not found")
  end

  match(_, do: send_resp(conn, 404, "Not found"))
end
