defmodule DocMind.Retrieval.Similarity do
  def cosine_similarity(a, b) do
    n_a = norm(a)
    n_b = norm(b)
    if n_a == 0.0 or n_b == 0.0, do: 0.0, else: dot_product(a, b) / (n_a * n_b)
  end

  def dot_product(a, b) do
    Enum.zip_reduce(a, b, 0.0, fn x, y, acc -> acc + x * y end)
  end

  def norm(v) do
    v |> Enum.reduce(0.0, fn x, acc -> acc + x * x end) |> :math.sqrt()
  end
end
