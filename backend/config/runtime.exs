import Config

if config_env() == :prod do
  host = System.get_env("PHX_HOST") || "uno-tt0m.onrender.com"
  secret = System.fetch_env!("SECRET_KEY_BASE")
  if byte_size(secret) < 32, do: raise("SECRET_KEY_BASE must contain at least 32 bytes")
  # Render-generated secrets can be shorter than Phoenix's 64-byte minimum.
  secret = :crypto.hash(:sha512, secret) |> Base.encode64()

  config :uno, UnoWeb.Endpoint,
    server: System.get_env("PHX_SERVER") in ["true", "1"],
    url: [host: host, scheme: "https", port: 443],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret,
    check_origin: ["https://uno-tt0m.onrender.com", "https://#{host}"]
end
