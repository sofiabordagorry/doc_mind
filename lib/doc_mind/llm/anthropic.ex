defmodule DocMind.LLM.Anthropic do
  @behaviour DocMind.LLM.Behaviour

  @base_url "https://api.anthropic.com/v1"
  @api_version "2023-06-01"

  @impl true
  def complete(prompt) do
    api_key = Application.fetch_env!(:doc_mind, :anthropic_api_key)
    model = Application.get_env(:doc_mind, :anthropic_llm_model, "claude-haiku-4-5")

    case Req.post("#{@base_url}/messages",
           json: %{
             model: model,
             max_tokens: 1024,
             messages: [%{role: "user", content: prompt}]
           },
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", @api_version}
           ]
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
