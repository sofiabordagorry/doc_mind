defmodule DocMind.Embeddings.OpenAI do
  @behaviour DocMind.Embeddings.Behaviour

  @base_url "https://api.openai.com/v1"
  @batch_size 20

  @impl true
  def embed(text) do
    case embed_many([text]) do
      {:ok, [embedding]} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def embed_many(texts) do
    texts
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
      case embed_batch(batch) do
        {:ok, embeddings} -> {:cont, {:ok, acc ++ embeddings}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp embed_batch(texts) do
    api_key = Application.fetch_env!(:doc_mind, :openai_api_key)
    model = Application.get_env(:doc_mind, :embedding_model)

    case Req.post("#{@base_url}/embeddings",
           json: %{input: texts, model: model},
           headers: [{"authorization", "Bearer #{api_key}"}]
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        embeddings =
          data |> Enum.sort_by(& &1["index"]) |> Enum.map(& &1["embedding"])

        {:ok, embeddings}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
