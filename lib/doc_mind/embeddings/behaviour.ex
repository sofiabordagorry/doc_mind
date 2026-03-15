defmodule DocMind.Embeddings.Behaviour do
  @callback embed(String.t()) :: {:ok, [float()]} | {:error, term()}
  @callback embed_many([String.t()]) :: {:ok, [[float()]]} | {:error, term()}
end
