defmodule DocMind.LLM.HuggingFace do
  @behaviour DocMind.LLM.Behaviour

  @base_url "https://router.huggingface.co/hf-inference/v1"

  @impl true
  def complete(prompt) do
    api_key = Application.fetch_env!(:doc_mind, :huggingface_api_key)
    model = Application.get_env(:doc_mind, :llm_model, "mistralai/Mistral-7B-Instruct-v0.2")

    case Req.post("#{@base_url}/chat/completions",
           json: %{
             model: model,
             messages: [%{role: "user", content: prompt}],
             max_tokens: 1024
           },
           headers: [{"authorization", "Bearer #{api_key}"}]
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
