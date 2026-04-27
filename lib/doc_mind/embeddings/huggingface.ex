defmodule DocMind.Embeddings.HuggingFace do
  @behaviour DocMind.Embeddings.Behaviour

  @base_url "https://router.huggingface.co/hf-inference/models"
  @batch_size 8

  # E5 models require task-specific prefixes for best results.
  # embed/1 is called at query time; embed_many/1 is called at index time.

  @impl true
  def embed(text) do
    case embed_batch(["query: #{text}"]) do
      {:ok, [embedding]} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def embed_many(texts) do
    texts
    |> Enum.map(&"passage: #{&1}")
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
      case embed_batch(batch) do
        {:ok, embeddings} -> {:cont, {:ok, acc ++ embeddings}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp embed_batch(texts) do
    api_key = Application.fetch_env!(:doc_mind, :huggingface_api_key)
    model = Application.get_env(:doc_mind, :embedding_model, "intfloat/e5-large-v2")

    case Req.post("#{@base_url}/#{model}/pipeline/feature-extraction",
           json: %{inputs: texts, normalize: true},
           headers: [{"authorization", "Bearer #{api_key}"}],
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: embeddings}} when is_list(embeddings) ->
        {:ok, embeddings}

      {:ok, %{status: 503, body: %{"error" => _}}} ->
        # Model is loading — wait and retry once
        Process.sleep(20_000)
        embed_batch(texts)

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
