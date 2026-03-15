defmodule DocMindWeb.QueryFormTest do
  use DocMindWeb.ConnCase, async: true

  test "renders the ask form when tab is :ask" do
    html = render_component(&DocMindWeb.QueryForm.query_form/1,
      tab: :ask,
      query: "",
      rerank: false
    )

    assert html =~ "Ask"
    assert html =~ ~s(placeholder="What is a GenServer callback?")
    assert html =~ "hero-sparkles-micro"
  end

  test "renders the search form when tab is :search" do
    html = render_component(&DocMindWeb.QueryForm.query_form/1,
      tab: :search,
      query: "",
      rerank: false
    )

    assert html =~ "Search"
    assert html =~ ~s(placeholder="how does supervision work?")
    assert html =~ "hero-magnifying-glass-micro"
  end

  test "renders nothing when tab is :index or :sources" do
    for tab <- [:index, :sources] do
      html = render_component(&DocMindWeb.QueryForm.query_form/1,
        tab: tab,
        query: "",
        rerank: false
      )

      refute html =~ "<form"
    end
  end

  test "pre-fills the query value" do
    html = render_component(&DocMindWeb.QueryForm.query_form/1,
      tab: :ask,
      query: "what is a supervisor?",
      rerank: false
    )

    assert html =~ "what is a supervisor?"
  end

  test "checks the rerank checkbox when rerank is true" do
    html = render_component(&DocMindWeb.QueryForm.query_form/1,
      tab: :ask,
      query: "",
      rerank: true
    )

    assert html =~ ~s(checked)
  end
end
