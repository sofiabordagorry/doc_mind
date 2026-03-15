defmodule DocMindWeb.SearchLiveTest do
  use DocMindWeb.ConnCase, async: false

  alias DocMind.{Chunk, Store.Cache}
  alias DocMind.Test.{FakeEmbeddingAdapter, FakeLLMAdapter}

  setup do
    Application.put_env(:doc_mind, :embedding_adapter, FakeEmbeddingAdapter)
    Application.put_env(:doc_mind, :llm_adapter, FakeLLMAdapter)

    # Subscribe first so we can catch any in-flight jobs from the previous test.
    Phoenix.PubSub.subscribe(DocMind.PubSub, "indexing")

    # Wait up to 200ms for any in-flight job to finish broadcasting, then clear.
    # This prevents async tasks from a previous test writing to the cache after
    # our clear_index() runs.
    drain_indexing()
    DocMind.clear_index()

    on_exit(fn ->
      Application.delete_env(:doc_mind, :embedding_adapter)
      Application.delete_env(:doc_mind, :llm_adapter)
      DocMind.clear_index()
    end)

    :ok
  end

  # Drains all pending indexing PubSub messages. Uses a short timeout so that
  # any job still in flight has time to broadcast before we give up waiting.
  defp drain_indexing do
    receive do
      {:indexing_progress, _} -> drain_indexing()
      {:indexing_done, _} -> drain_indexing()
    after
      200 -> :ok
    end
  end

  defp seed_chunk(attrs \\ %{}) do
    chunk = %Chunk{
      id: attrs[:id] || "test-chunk-#{System.unique_integer([:positive])}",
      document_id: attrs[:document_id] || "doc-1",
      text: attrs[:text] || "Some content about GenServer.",
      embedding: [0.1, 0.2, 0.3],
      metadata: %{
        source: attrs[:source] || "test-doc.md",
        heading: attrs[:heading] || "Introduction",
        collection: attrs[:collection] || nil
      }
    }

    Cache.put_chunks(Cache.get_chunks() ++ [chunk])
    chunk
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
      seed_chunk(%{id: "c1", source: "README.md", collection: "My Project"})
      seed_chunk(%{id: "c2", source: "guide.md", collection: "My Project"})

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

      # Must wait for the job to complete before the test ends so on_exit
      # can clear the cache cleanly without racing against the async task.
      assert_receive {:indexing_done, _}, 5_000
    end

    test "shows success message after indexing completes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element("button[phx-value-tab='index']") |> render_click()

      # Send the done message directly to the LiveView instead of running
      # a real indexing job — tests handle_info logic without timing issues.
      send(view.pid, {:indexing_done, {:ok, %{new: 1, chunks: 14, total_chunks: 14}}})

      assert render(view) =~ "Done."
    end
  end
end
