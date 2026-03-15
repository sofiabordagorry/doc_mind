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
    tab_atom = case tab do
      "search"  -> :search
      "ask"     -> :ask
      "index"   -> :index
      "sources" -> :sources
      _         -> :search
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

  defp error_to_string(:too_large), do: "File is too large (max 10 MB)"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "Only .md and .txt files are accepted"

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

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding-top: 5rem; padding-bottom: 4rem; max-width: 42rem; margin-left: auto; margin-right: auto; padding-left: 2rem; padding-right: 2rem;">
    <%!-- Header --%>
    <div style="display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 3rem;">
      <div>
        <h1 style="font-size: 1.875rem; font-weight: 700; letter-spacing: -0.025em;">DocMind</h1>
        <p style="font-size: 1rem; color: oklch(var(--bc) / 0.5); margin-top: 0.5rem;">Semantic search & QA over your docs</p>
        <div style="display: flex; gap: 1.25rem; margin-top: 1rem; font-size: 0.875rem; color: oklch(var(--bc) / 0.4);">
          <span style="display: flex; align-items: center; gap: 0.375rem;">
            <.icon name="hero-circle-stack-micro" class="size-4" />
            {@stats.chunks} chunks
          </span>
          <span style="display: flex; align-items: center; gap: 0.375rem;">
            <.icon name="hero-document-text-micro" class="size-4" />
            {@stats.sources} source(s)
          </span>
        </div>
      </div>
      <DocMindWeb.Layouts.theme_toggle />
    </div>

    <%!-- Main card: tabs + form together --%>
    <div class="border border-base-300 rounded-2xl overflow-hidden shadow-sm">
      <%!-- Tab bar --%>
      <div class="flex border-b border-base-300 bg-base-200/40">
        <button
          class={"flex items-center gap-2 px-6 py-4 text-sm font-medium transition-colors border-b-2 -mb-px " <> if(@tab == :ask, do: "border-primary text-primary bg-base-100", else: "border-transparent text-base-content/40 hover:text-base-content")}
          phx-click="switch_tab" phx-value-tab="ask">
          <.icon name="hero-chat-bubble-left-ellipsis-micro" class="size-4" /> Ask
        </button>
        <button
          class={"flex items-center gap-2 px-6 py-4 text-sm font-medium transition-colors border-b-2 -mb-px " <> if(@tab == :search, do: "border-primary text-primary bg-base-100", else: "border-transparent text-base-content/40 hover:text-base-content")}
          phx-click="switch_tab" phx-value-tab="search">
          <.icon name="hero-magnifying-glass-micro" class="size-4" /> Search
        </button>
        <button
          class={"flex items-center gap-2 px-6 py-4 text-sm font-medium transition-colors border-b-2 -mb-px " <> if(@tab == :index, do: "border-primary text-primary bg-base-100", else: "border-transparent text-base-content/40 hover:text-base-content")}
          phx-click="switch_tab" phx-value-tab="index">
          <.icon name="hero-arrow-up-tray-micro" class="size-4" /> Index
        </button>
        <button
          class={"flex items-center gap-2 px-6 py-4 text-sm font-medium transition-colors border-b-2 -mb-px " <> if(@tab == :sources, do: "border-primary text-primary bg-base-100", else: "border-transparent text-base-content/40 hover:text-base-content")}
          phx-click="switch_tab" phx-value-tab="sources">
          <.icon name="hero-rectangle-stack-micro" class="size-4" /> Sources
        </button>
      </div>

      <%!-- Tab body --%>
      <div class="bg-base-100 px-6 py-6">
        <form :if={@tab in [:search, :ask]} phx-submit="search" class="space-y-4">
          <textarea
            name="query"
            rows="3"
            class="textarea textarea-bordered w-full resize-none text-sm leading-relaxed"
            placeholder={if @tab == :ask, do: "What is a GenServer callback?", else: "how does supervision work?"}
          >{@query}</textarea>
          <div class="flex items-center gap-5">
            <button type="submit" class="btn btn-primary btn-sm px-5">
              <.icon name={if @tab == :ask, do: "hero-sparkles-micro", else: "hero-magnifying-glass-micro"} class="size-4" />
              {if @tab == :ask, do: "Ask", else: "Search"}
            </button>
            <label class="flex items-center gap-2 cursor-pointer select-none">
              <input type="checkbox" name="rerank" value="true" checked={@rerank} class="checkbox checkbox-xs" />
              <span class="text-sm text-base-content/40">Rerank results</span>
            </label>
          </div>
        </form>

        <div :if={@tab == :index} class="space-y-5">
          <div
            :if={@index_message}
            class={"alert text-sm " <> if(@index_message_type == :ok, do: "alert-success", else: "alert-error")}
          >
            <.icon name={if @index_message_type == :ok, do: "hero-check-circle-micro", else: "hero-x-circle-micro"} class="size-4" />
            {@index_message}
          </div>
          <div :if={@indexing} class="alert alert-info text-sm">
            <span class="loading loading-spinner loading-sm"></span>
            <div>
              <p class="font-medium">Indexing in progress…</p>
              <p :for={line <- Enum.take(@index_log, 3)} class="font-mono text-xs opacity-60 mt-1">{line}</p>
            </div>
          </div>
          <form phx-submit="index" phx-change="validate" class="space-y-4">
            <div>
              <p class="text-sm font-medium mb-2">Collection <span class="text-base-content/30 font-normal">(optional)</span></p>
              <input
                type="text"
                name="collection"
                class="input input-bordered w-full text-sm"
                placeholder="e.g. Elixir Docs, My Project…"
              />
            </div>
            <div>
              <p class="text-sm font-medium mb-2">Upload files <span class="text-base-content/30 font-normal">(.md, .txt)</span></p>
              <div
                phx-drop-target={@uploads.files.ref}
                class="border-2 border-dashed border-base-300 rounded-xl p-5 text-center hover:border-primary/40 transition-colors"
              >
                <.icon name="hero-arrow-up-tray" class="size-7 mx-auto mb-2 text-base-content/25" />
                <p class="text-sm text-base-content/40 mb-3">Drop files here or</p>
                <label for={@uploads.files.ref} class="btn btn-sm btn-outline cursor-pointer">Browse files</label>
                <.live_file_input upload={@uploads.files} class="hidden" />
              </div>
              <div :if={@uploads.files.entries != []} class="mt-2 space-y-1">
                <div :for={entry <- @uploads.files.entries} class="flex items-center gap-2 text-sm py-1">
                  <.icon name="hero-document-text-micro" class="size-3.5 text-base-content/40 shrink-0" />
                  <span class="flex-1 truncate text-base-content/70">{entry.client_name}</span>
                  <span class="text-xs text-base-content/30">{Float.round(entry.client_size / 1024, 1)} KB</span>
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="btn btn-ghost btn-xs text-error px-1">
                    <.icon name="hero-x-mark-micro" class="size-3.5" />
                  </button>
                </div>
                <%= for entry <- @uploads.files.entries, err <- upload_errors(@uploads.files, entry) do %>
                  <div class="text-xs text-error">{entry.client_name}: {error_to_string(err)}</div>
                <% end %>
                <div :for={err <- upload_errors(@uploads.files)} class="text-xs text-error">
                  {error_to_string(err)}
                </div>
              </div>
            </div>
            <div>
              <p class="text-sm font-medium mb-2">Sources</p>
              <textarea
                name="sources"
                rows="4"
                class="textarea textarea-bordered w-full text-sm font-mono leading-relaxed"
                placeholder={"One URL per line:\nhttps://hexdocs.pm/elixir/GenServer.html"}
              ></textarea>
            </div>
            <div class="flex items-center gap-5">
              <button type="submit" class="btn btn-primary btn-sm px-5" disabled={@indexing}>
                <.icon name="hero-arrow-up-tray-micro" class="size-4" /> Start indexing
              </button>
              <span class="text-sm text-base-content/40">Runs in the background</span>
            </div>
          </form>
        </div>

        <%!-- Sources tab --%>
        <div :if={@tab == :sources}>
          <div :if={@source_list == []} class="text-center py-10 text-base-content/30">
            <.icon name="hero-rectangle-stack" class="size-10 mx-auto mb-3" />
            <p class="text-sm">No sources indexed yet</p>
          </div>
          <div :if={@source_list != []} class="-mx-6 -my-6 divide-y divide-base-200">
            <details :for={c <- @collections} open class="group">
              <summary class="flex items-center gap-2 px-6 py-3 text-xs font-semibold uppercase tracking-widest text-base-content/40 cursor-pointer select-none hover:text-base-content/60 transition-colors list-none">
                <.icon name="hero-chevron-right-micro" class="size-3 group-open:rotate-90 transition-transform" />
                {c.name || "Uncollected"} ({length(c.sources)})
              </summary>
              <div class="border-t border-base-200">
                <div
                  :for={s <- c.sources}
                  class="flex items-center px-6 py-3 hover:bg-base-200/20 transition-colors group"
                >
                  <.icon
                    name={if String.starts_with?(s.name, "http"), do: "hero-globe-alt-micro", else: "hero-document-text-micro"}
                    class="size-3.5 shrink-0 text-base-content/30 mr-2.5"
                  />
                  <span class="text-sm text-base-content/80 truncate flex-1">{s.name}</span>
                  <button
                    type="button"
                    phx-click="remove_source"
                    phx-value-source={s.name}
                    class="btn btn-ghost btn-xs text-error opacity-0 group-hover:opacity-100 transition-opacity px-1"
                    title="Remove source"
                  >
                    <.icon name="hero-trash-micro" class="size-3.5" />
                  </button>
                </div>
              </div>
            </details>
          </div>
        </div>
      </div>
    </div>

    <%!-- Search results --%>
    <div :if={@tab == :search and is_list(@results)} class="mt-8">
      <div :if={@results == []} class="text-center py-20 text-base-content/25">
        <.icon name="hero-magnifying-glass" class="size-12 mx-auto mb-4" />
        <p class="text-sm">No results found</p>
      </div>
      <div :if={@results != []} class="border border-base-300 rounded-2xl overflow-hidden divide-y divide-base-200">
        <div :for={r <- @results || []} class="px-6 py-5 hover:bg-base-200/20 transition-colors">
          <div class="flex items-center gap-2.5 mb-3">
            <span class="badge badge-primary badge-outline badge-sm font-mono shrink-0">
              {Float.round(r.score, 3)}
            </span>
            <span class="text-xs text-base-content/40 truncate">
              {r.metadata[:source] || r.metadata[:url] || "unknown"}
              <span :if={r.metadata[:heading]}> — {r.metadata[:heading]}</span>
            </span>
          </div>
          <p class="text-sm text-base-content/75 leading-relaxed">{String.slice(r.text, 0, 500)}</p>
        </div>
      </div>
    </div>

    <%!-- Ask answer --%>
    <div :if={@tab == :ask and not is_nil(@answer)} class="mt-8 space-y-4">
      <div class="border border-base-300 rounded-2xl px-6 py-6">
        <p class="text-xs font-semibold text-base-content/30 uppercase tracking-widest mb-4">Answer</p>
        <p class="text-sm leading-loose">{@answer.answer}</p>
      </div>
      <div :if={@answer.sources != []} class="border border-base-300 rounded-2xl px-6 py-5">
        <p class="text-xs font-semibold text-base-content/30 uppercase tracking-widest mb-4">Sources</p>
        <div :for={s <- @answer.sources} class="flex items-center gap-2.5 text-sm text-base-content/50 py-1.5">
          <.icon name="hero-document-text-micro" class="size-3.5 shrink-0 text-base-content/25" />
          {s[:source] || s[:url] || "unknown"}
          <span :if={s[:heading]} class="text-base-content/30"> — {s[:heading]}</span>
        </div>
      </div>
    </div>
    </div>
    """
  end
end
