defmodule DocMind.Retrieval.SimilarityTest do
  use ExUnit.Case, async: true

  alias DocMind.Retrieval.Similarity

  test "identical vectors have similarity 1.0" do
    v = [1.0, 2.0, 3.0]
    assert_in_delta Similarity.cosine_similarity(v, v), 1.0, 0.0001
  end

  test "orthogonal vectors have similarity 0.0" do
    assert_in_delta Similarity.cosine_similarity([1.0, 0.0], [0.0, 1.0]), 0.0, 0.0001
  end

  test "opposite vectors have similarity -1.0" do
    assert_in_delta Similarity.cosine_similarity([1.0, 0.0], [-1.0, 0.0]), -1.0, 0.0001
  end

  test "zero vector returns 0.0" do
    assert Similarity.cosine_similarity([0.0, 0.0], [1.0, 2.0]) == 0.0
  end

  test "dot product" do
    assert_in_delta Similarity.dot_product([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]), 32.0, 0.0001
  end

  test "norm" do
    assert_in_delta Similarity.norm([3.0, 4.0]), 5.0, 0.0001
  end
end
