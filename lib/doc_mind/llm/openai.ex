defmodule DocMind.LLM.OpenAI do
  @behaviour DocMind.LLM.Behaviour

  @base_url "https://api.openai.com/v1"

  @impl true
  def complete(prompt) do
    api_key = Application.fetch_env!(:doc_mind, :openai_api_key)
    model = Application.get_env(:doc_mind, :llm_model)

    case Req.post("#{@base_url}/chat/completions",
           json: %{
             model: model,
             messages: [%{role: "user", content: prompt}],
             temperature: 0.2
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
