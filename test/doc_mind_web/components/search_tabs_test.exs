defmodule DocMindWeb.SearchTabsTest do
  use DocMindWeb.ConnCase, async: true

  test "renders all four tabs" do
    html = render_component(&DocMindWeb.SearchTabs.search_tabs/1, tab: :ask)

    assert html =~ "Ask"
    assert html =~ "Search"
    assert html =~ "Index"
    assert html =~ "Sources"
  end

  test "marks the active tab with the primary border class" do
    for active_tab <- [:ask, :search, :index, :sources] do
      html = render_component(&DocMindWeb.SearchTabs.search_tabs/1, tab: active_tab)

      assert html =~ ~s(phx-value-tab="#{active_tab}")
      assert html =~ "border-primary"
    end
  end

  test "each tab button sends the correct phx-value-tab" do
    html = render_component(&DocMindWeb.SearchTabs.search_tabs/1, tab: :ask)

    assert html =~ ~s(phx-value-tab="ask")
    assert html =~ ~s(phx-value-tab="search")
    assert html =~ ~s(phx-value-tab="index")
    assert html =~ ~s(phx-value-tab="sources")
  end
end
