defmodule DocMindWeb.SearchLive do
  use DocMindWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DocMind.PubSub, "indexing")
    end

    {:ok,
     socket
     |> assign(:tab, :ask)
     |> assign(:query, "")
     |> assign(:rerank, false)
     |> assign(:results, nil)
     |> assign(:answer, nil)
     |> assign(:indexing, false)
     |> assign(:index_message, nil)
     |> assign(:index_message_type, nil)
     |> assign(:index_log, [])
     |> assign(:source_list, [])
     |> assign(:collections, [])
     |> allow_upload(:files, accept: ~w(.md .txt), max_entries: 100, max_file_size: 10_000_000)
     |> assign_stats()}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab_atom =
      case tab do
        "search" -> :search
        "ask" -> :ask
        "index" -> :index
        "sources" -> :sources
        _ -> :search
      end

    {:noreply, assign(socket, :tab, tab_atom)}
  end

  def handle_event("search", params, socket) do
    query = String.trim(params["query"] || "")
    rerank? = params["rerank"] == "true"

    {results, answer} =
      cond do
        query == "" ->
          {nil, nil}

        socket.assigns.tab == :search ->
          case DocMind.search(query, top_k: 8, rerank: rerank?) do
            {:ok, r} -> {r, nil}
            _ -> {[], nil}
          end

        socket.assigns.tab == :ask ->
          case DocMind.ask(query, top_k: 5, rerank: rerank?) do
            {:ok, a} -> {nil, a}
            _ -> {nil, nil}
          end
      end

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:rerank, rerank?)
     |> assign(:results, results)
     |> assign(:answer, answer)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  def handle_event("remove_source", %{"source" => source}, socket) do
    DocMind.remove_source(source)
    {:noreply, assign_stats(socket)}
  end

  def handle_event("index", %{"sources" => raw} = params, socket) do
    uploaded =
      consume_uploaded_entries(socket, :files, fn %{path: tmp_path}, entry ->
        dest = Path.join(System.tmp_dir!(), entry.client_name)
        File.cp!(tmp_path, dest)
        {:ok, {dest, entry.client_name}}
      end)

    upload_paths = Enum.map(uploaded, fn {path, _} -> path end)
    source_labels = Map.new(uploaded, fn {path, name} -> {path, name} end)

    text_sources =
      raw
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    sources = upload_paths ++ text_sources

    collection =
      case String.trim(params["collection"] || "") do
        "" -> nil
        name -> name
      end

    if sources == [] do
      {:noreply,
       socket
       |> assign(:index_message, "No sources provided.")
       |> assign(:index_message_type, :error)}
    else
      opts = [source_labels: source_labels]
      opts = if collection, do: Keyword.put(opts, :collection, collection), else: opts
      {:ok, _job_id} = DocMind.index_async(sources, opts)

      {:noreply,
       socket
       |> assign(:indexing, true)
       |> assign(:index_message, nil)
       |> assign(:index_log, [])}
    end
  end

  @impl true
  def handle_info({:indexing_progress, msg}, socket) do
    {:noreply, update(socket, :index_log, &[msg | &1])}
  end

  def handle_info({:indexing_done, result}, socket) do
    msg =
      case result do
        {:ok, stats} ->
          "Done. #{stats.new} new doc(s), #{stats.chunks} new chunk(s), #{stats.total_chunks} total."

        {:error, reason} ->
          "Error: #{inspect(reason)}"
      end

    type = if match?({:ok, _}, result), do: :ok, else: :error

    {:noreply,
     socket
     |> assign(:indexing, false)
     |> assign(:index_message, msg)
     |> assign(:index_message_type, type)
     |> assign_stats()}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_stats(socket) do
    chunks = DocMind.Store.Cache.get_chunks()

    source_list =
      chunks
      |> Enum.group_by(& &1.metadata[:source])
      |> Enum.map(fn {source, cs} ->
        %{name: source || "unknown", collection: hd(cs).metadata[:collection]}
      end)
      |> Enum.sort_by(& &1.name)

    collections =
      source_list
      |> Enum.group_by(& &1.collection)
      |> Enum.map(fn {coll, sources} -> %{name: coll, sources: sources} end)
      |> Enum.sort_by(fn c -> c.name || "" end)

    assign(socket,
      stats: %{chunks: length(chunks), sources: length(source_list)},
      source_list: source_list,
      collections: collections
    )
  end
end
