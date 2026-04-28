import Config

if config_env() != :test do
  llm_adapter = Application.get_env(:doc_mind, :llm_adapter)
  embedding_adapter = Application.get_env(:doc_mind, :embedding_adapter)

  openai_adapters = [DocMind.LLM.OpenAI, DocMind.Embeddings.OpenAI]

  if llm_adapter in openai_adapters or embedding_adapter in openai_adapters do
    api_key =
      System.get_env("OPENAI_API_KEY") ||
        raise "OpenAI API key not configured. Set the OPENAI_API_KEY environment variable."

    config :doc_mind, openai_api_key: api_key
  end

  if llm_adapter == DocMind.LLM.Anthropic do
    api_key =
      System.get_env("ANTHROPIC_API_KEY") ||
        raise "Anthropic API key not configured. Set the ANTHROPIC_API_KEY environment variable."

    config :doc_mind, anthropic_api_key: api_key
  end

  huggingface_adapters = [DocMind.LLM.HuggingFace, DocMind.Embeddings.HuggingFace]

  if llm_adapter in huggingface_adapters or embedding_adapter in huggingface_adapters do
    api_key =
      System.get_env("HUGGINGFACE_API_KEY") ||
        raise "HuggingFace API key not configured. Set the HUGGINGFACE_API_KEY environment variable."

    config :doc_mind, huggingface_api_key: api_key
  end
end

if System.get_env("PHX_SERVER") do
  config :doc_mind, DocMindWeb.Endpoint, server: true
end

config :doc_mind, DocMindWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is missing."

  config :doc_mind, DocMind.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :doc_mind, DocMindWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base
end
