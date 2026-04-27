defmodule DocMindWeb.SearchHeaderTest do
  use DocMindWeb.ConnCase, async: true

  test "renders the DocMind title" do
    html =
      render_component(&DocMindWeb.SearchHeader.search_header/1,
        stats: %{chunks: 0, sources: 0}
      )

    assert html =~ "DocMind"
    assert html =~ "Semantic search"
  end

  test "renders chunk and source counts from stats" do
    html =
      render_component(&DocMindWeb.SearchHeader.search_header/1,
        stats: %{chunks: 42, sources: 7}
      )

    assert html =~ "42 chunks"
    assert html =~ "7 source(s)"
  end
end
