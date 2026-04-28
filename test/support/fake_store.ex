defmodule DocMind.Test.FakeStore do
  def save(_chunks), do: :ok
  def load, do: {:ok, []}
  def delete, do: :ok
  def semantic_search(_embedding, _limit), do: %{}
end
