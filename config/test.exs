import Config

config :docmind, DocMindWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "W9hwdBQ5J8PTvsEaLN+qhotGbjJtDOnGTCcJ9H52/ixSbYPT5DqlMtzLeIU+kQKp",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
