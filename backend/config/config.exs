import Config

config :uno, UnoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: String.duplicate("development-secret-", 4),
  pubsub_server: Uno.PubSub,
  check_origin: [
    "http://localhost:5173",
    "http://localhost:4000",
    "http://127.0.0.1:5173",
    "http://127.0.0.1:4000"
  ],
  server: true

config :phoenix, :json_library, Jason
config :phoenix, :filter_parameters, ["password", "token", "admissionKey"]
import_config "#{config_env()}.exs"
