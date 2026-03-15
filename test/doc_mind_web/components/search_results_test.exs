defmodule DocMindWeb.SearchResultsTest do
  use DocMindWeb.ConnCase, async: true

  test "renders nothing when results is nil" do
    html = render_component(&DocMindWeb.SearchResults.search_results/1, results: nil)

    refute html =~ "No results found"
    refute html =~ "<div"
  end

  test "renders empty state when results list is empty" do
    html = render_component(&DocMindWeb.SearchResults.search_results/1, results: [])

    assert html =~ "No results found"
  end

  test "renders a card for each result" do
    results = [
      %DocMind.Result{
        score: 0.923,
        text: "GenServer is a process that manages state.",
        metadata: %{source: "README.md", heading: "Overview"}
      },
      %DocMind.Result{
        score: 0.811,
        text: "Supervisors restart failed children.",
        metadata: %{source: "guide.md", heading: nil}
      }
    ]

    html = render_component(&DocMindWeb.SearchResults.search_results/1, results: results)

    assert html =~ "0.923"
    assert html =~ "0.811"
    assert html =~ "GenServer is a process"
    assert html =~ "Supervisors restart"
    assert html =~ "README.md"
    assert html =~ "Overview"
    assert html =~ "guide.md"
  end

  test "truncates result text to 500 characters" do
    long_text = String.duplicate("a", 600)

    results = [
      %DocMind.Result{
        score: 0.5,
        text: long_text,
        metadata: %{source: "doc.md", heading: nil}
      }
    ]

    html = render_component(&DocMindWeb.SearchResults.search_results/1, results: results)

    refute html =~ String.duplicate("a", 501)
  end
end
