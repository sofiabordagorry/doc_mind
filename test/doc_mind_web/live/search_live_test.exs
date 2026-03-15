defmodule DocMindWeb.SearchLiveTest do
  use DocMindWeb.ConnCase, async: false

  alias DocMind.{Chunk, Store.Cache}
  alias DocMind.Test.{FakeEmbeddingAdapter, FakeLLMAdapter}

  setup do
    DocMind.clear_index()

    Application.put_env(:docmind, :embedding_adapter, FakeEmbeddingAdapter)
    Application.put_env(:docmind, :llm_adapter, FakeLLMAdapter)

    # Subscribe so the test process can wait for indexing jobs to finish,
    # preventing async jobs from leaking into the next test's cache state.
    Phoenix.PubSub.subscribe(DocMind.PubSub, "indexing")

    on_exit(fn ->
      Application.delete_env(:docmind, :embedding_adapter)
      Application.delete_env(:docmind, :llm_adapter)
      DocMind.clear_index()
    end)

    :ok
  end

  defp seed_chunk(attrs \\ %{}) do
    chunk = %Chunk{
      id: attrs[:id] || "chunk-1",
      document_id: attrs[:document_id] || "doc-1",
      text: attrs[:text] || "Some content about GenServer.",
      embedding: [0.1, 0.2, 0.3],
      metadata: %{
        source: attrs[:source] || "README.md",
        heading: attrs[:heading] || "Introduction",
        collection: attrs[:collection] || nil
      }
    }

    Cache.put_chunks(Cache.get_chunks() ++ [chunk])
    chunk
  end

  # Drains any pending indexing_done message so the test's on_exit
  # can clear the cache without racing against the async job.
  defp await_indexing do
    receive do
      {:indexing_done, _} -> :ok
    after
      5_000 -> :ok
    end
  end

  describe "mount" do
    test "renders the page with the ask tab active by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "button[phx-value-tab='ask']")
      assert has_element?(view, "textarea[name='query']")
    end

    test "shows chunk and source counts in the header", %{conn: conn} do
      seed_chunk()
      {:ok, view, _html} = live(conn, "/")

      assert render(view) =~ "1 chunks"
      assert render(view) =~ "1 source(s)"
    end
  end

  describe "tab switching" do
    test "switches to the search tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='search']") |> render_click()

      assert has_element?(view, "textarea[name='query']")
      assert has_element?(view, "button[type='submit']", "Search")
    end

    test "switches to the index tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='index']") |> render_click()

      assert has_element?(view, "form[phx-submit='index']")
      assert has_element?(view, "input[name='collection']")
      assert has_element?(view, "textarea[name='sources']")
    end

    test "switches to the sources tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='sources']") |> render_click()

      assert has_element?(view, "p", "No sources indexed yet")
    end
  end

  describe "sources tab" do
    test "shows empty state when no sources are indexed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='sources']") |> render_click()

      assert has_element?(view, "p", "No sources indexed yet")
    end

    test "lists indexed sources grouped by collection", %{conn: conn} do
      seed_chunk(%{source: "README.md", collection: "My Project"})
      seed_chunk(%{id: "chunk-2", source: "guide.md", collection: "My Project"})

      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='sources']") |> render_click()

      assert has_element?(view, "summary", "My Project")
      assert render(view) =~ "README.md"
      assert render(view) =~ "guide.md"
    end

    test "removes a source when clicking the trash button", %{conn: conn} do
      seed_chunk(%{source: "README.md"})

      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='sources']") |> render_click()
      assert render(view) =~ "README.md"

      view
      |> element("button[phx-click='remove_source'][phx-value-source='README.md']")
      |> render_click()

      refute render(view) =~ "README.md"
      assert has_element?(view, "p", "No sources indexed yet")
    end
  end

  describe "index tab" do
    test "shows error when submitting with no sources", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='index']") |> render_click()

      view
      |> form("form[phx-submit='index']", %{sources: "", collection: ""})
      |> render_submit()

      assert has_element?(view, ".alert-error", "No sources provided.")
    end

    test "shows indexing progress after submitting sources", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='index']") |> render_click()

      view
      |> form("form[phx-submit='index']", %{sources: "README.md", collection: ""})
      |> render_submit()

      assert has_element?(view, ".alert-info", "Indexing in progress")

      await_indexing()
    end

    test "shows success message after indexing completes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='index']") |> render_click()

      view
      |> form("form[phx-submit='index']", %{sources: "README.md", collection: ""})
      |> render_submit()

      assert_receive {:indexing_done, {:ok, _stats}}, 5_000

      assert render(view) =~ "Done."
    end
  end
end
