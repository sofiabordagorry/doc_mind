defmodule DocMindWeb.SourcesPanelTest do
  use DocMindWeb.ConnCase, async: true

  test "renders empty state when there are no sources" do
    html =
      render_component(&DocMindWeb.SourcesPanel.sources_panel/1,
        source_list: [],
        collections: []
      )

    assert html =~ "No sources indexed yet"
  end

  test "renders sources grouped by collection" do
    collections = [
      %{
        name: "Elixir Docs",
        sources: [
          %{name: "https://hexdocs.pm/elixir/GenServer.html", collection: "Elixir Docs"},
          %{name: "README.md", collection: "Elixir Docs"}
        ]
      }
    ]

    html =
      render_component(&DocMindWeb.SourcesPanel.sources_panel/1,
        source_list: [%{name: "README.md"}, %{name: "https://hexdocs.pm/elixir/GenServer.html"}],
        collections: collections
      )

    assert html =~ "Elixir Docs"
    assert html =~ "README.md"
    assert html =~ "https://hexdocs.pm/elixir/GenServer.html"
  end

  test "renders a globe icon for URLs and document icon for local files" do
    collections = [
      %{
        name: nil,
        sources: [
          %{name: "https://hexdocs.pm/elixir", collection: nil},
          %{name: "local_file.md", collection: nil}
        ]
      }
    ]

    html =
      render_component(&DocMindWeb.SourcesPanel.sources_panel/1,
        source_list: [%{name: "https://hexdocs.pm/elixir"}, %{name: "local_file.md"}],
        collections: collections
      )

    assert html =~ "hero-globe-alt-micro"
    assert html =~ "hero-document-text-micro"
  end

  test "renders remove button for each source" do
    collections = [
      %{name: nil, sources: [%{name: "README.md", collection: nil}]}
    ]

    html =
      render_component(&DocMindWeb.SourcesPanel.sources_panel/1,
        source_list: [%{name: "README.md"}],
        collections: collections
      )

    assert html =~ ~s(phx-click="remove_source")
    assert html =~ ~s(phx-value-source="README.md")
  end

  test "renders uncollected label when collection name is nil" do
    collections = [%{name: nil, sources: [%{name: "README.md", collection: nil}]}]

    html =
      render_component(&DocMindWeb.SourcesPanel.sources_panel/1,
        source_list: [%{name: "README.md"}],
        collections: collections
      )

    assert html =~ "Uncollected"
  end
end
