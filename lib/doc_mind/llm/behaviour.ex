defmodule DocMind.LLM.Behaviour do
  @callback complete(String.t()) :: {:ok, String.t()} | {:error, term()}
end
