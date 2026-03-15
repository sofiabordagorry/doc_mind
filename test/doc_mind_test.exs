defmodule DocMindTest do
  use ExUnit.Case

  test "public API functions are defined" do
    assert is_function(&DocMind.index/1)
    assert is_function(&DocMind.search/1)
    assert is_function(&DocMind.ask/1)
    assert is_function(&DocMind.clear_index/0)
  end
end
