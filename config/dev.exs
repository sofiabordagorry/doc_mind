import Config

config :doc_mind, DocMind.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "doc_mind_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :doc_mind, DocMindWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "hKCoSSpauZEkXisnfze/IF0fwmXPVDYpZbJp0drfd+tIvob4vpk/Xvvjf91cJzqF",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:doc_mind, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:doc_mind, ~w(--watch)]}
  ]

config :doc_mind, DocMindWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*\.po$",
      ~r"lib/doc_mind_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

config :doc_mind, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
