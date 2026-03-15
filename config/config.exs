import Config

config :doc_mind,
  namespace: DocMind,
  generators: [timestamp_type: :utc_datetime],
  embedding_model: "text-embedding-3-small",
  llm_model: "gpt-4o-mini",
  store_path: ".doc_mind/index.bin",
  embedding_adapter: DocMind.Embeddings.OpenAI,
  llm_adapter: DocMind.LLM.OpenAI

config :doc_mind, DocMindWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DocMindWeb.ErrorHTML, json: DocMindWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DocMind.PubSub,
  live_view: [signing_salt: "UpwAf/Bb"]

config :esbuild,
  version: "0.25.4",
  doc_mind: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.12",
  doc_mind: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
