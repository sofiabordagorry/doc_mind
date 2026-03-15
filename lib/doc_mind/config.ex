defmodule DocMind.Config do
  def openai_api_key do
    Application.get_env(:docmind, :openai_api_key) ||
      System.get_env("OPENAI_API_KEY") ||
      raise "OpenAI API key not configured. Set OPENAI_API_KEY env var or config :docmind, :openai_api_key"
  end

  def embedding_model do
    Application.get_env(:docmind, :embedding_model, "text-embedding-3-small")
  end

  def llm_model do
    Application.get_env(:docmind, :llm_model, "gpt-4o-mini")
  end

  def store_path do
    Application.get_env(:docmind, :store_path, ".docmind/index.bin")
  end

  def embedding_adapter do
    Application.get_env(:docmind, :embedding_adapter, DocMind.Embeddings.OpenAI)
  end

  def llm_adapter do
    Application.get_env(:docmind, :llm_adapter, DocMind.LLM.OpenAI)
  end

  def start_web? do
    Application.get_env(:docmind, :start_web, false)
  end

  def web_port do
    Application.get_env(:docmind, :web_port, 4040)
  end
end
