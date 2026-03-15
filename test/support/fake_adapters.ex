defmodule DocMind.Test.FakeEmbeddingAdapter do
  @behaviour DocMind.Embeddings.Behaviour

  @impl true
  def embed(_text), do: {:ok, [0.1, 0.2, 0.3]}

  @impl true
  def embed_many(texts), do: {:ok, Enum.map(texts, fn _ -> [0.1, 0.2, 0.3] end)}
end

defmodule DocMind.Test.FakeLLMAdapter do
  @behaviour DocMind.LLM.Behaviour

  @impl true
  def complete(_prompt), do: {:ok, "This is a test answer. [1]"}
end
