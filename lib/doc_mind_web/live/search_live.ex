defmodule DocMindWeb.SearchLive do
  use DocMindWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DocMind.PubSub, "indexing")
    end

    {:ok,
     socket
     |> assign(:tab, :search)
     |> assign(:query, "")
     |> assign(:rerank, false)
     |> assign(:results, nil)
     |> assign(:answer, nil)
     |> assign(:indexing, false)
     |> assign(:index_message, nil)
     |> assign(:index_message_type, nil)
     |> assign(:index_log, [])
     |> assign_stats()}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
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

  def handle_event("index", %{"sources" => raw}, socket) do
    sources =
      raw
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if sources == [] do
      {:noreply,
       socket
       |> assign(:index_message, "No sources provided.")
       |> assign(:index_message_type, :error)}
    else
      {:ok, _job_id} = DocMind.index_async(sources)

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
    sources = chunks |> Enum.map(& &1.metadata[:source]) |> Enum.uniq() |> length()
    assign(socket, stats: %{chunks: length(chunks), sources: sources})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      DocMind
      <:subtitle>Semantic search and QA over technical documentation</:subtitle>
    </.header>

    <p class="text-sm text-zinc-500 mt-2">
      Index: <strong>{@stats.chunks}</strong> chunks from <strong>{@stats.sources}</strong> source(s)
    </p>

    <div class="flex gap-2 mt-6 border-b border-zinc-200">
      <button
        class={"pb-2 px-1 text-sm font-medium border-b-2 -mb-px transition-colors " <> if(@tab == :search, do: "border-zinc-900 text-zinc-900", else: "border-transparent text-zinc-500 hover:text-zinc-700")}
        phx-click="switch_tab" phx-value-tab="search">
        Search
      </button>
      <button
        class={"pb-2 px-1 text-sm font-medium border-b-2 -mb-px transition-colors " <> if(@tab == :ask, do: "border-zinc-900 text-zinc-900", else: "border-transparent text-zinc-500 hover:text-zinc-700")}
        phx-click="switch_tab" phx-value-tab="ask">
        Ask
      </button>
      <button
        class={"pb-2 px-1 text-sm font-medium border-b-2 -mb-px transition-colors " <> if(@tab == :index, do: "border-zinc-900 text-zinc-900", else: "border-transparent text-zinc-500 hover:text-zinc-700")}
        phx-click="switch_tab" phx-value-tab="index">
        Manage Index
      </button>
    </div>

    <div :if={@tab in [:search, :ask]} class="mt-6">
      <form phx-submit="search" class="space-y-3">
        <.input
          type="textarea"
          name="query"
          value={@query}
          placeholder={if @tab == :ask, do: "What is a GenServer callback?", else: "how does supervision work?"}
          rows="2"
        />
        <div class="flex items-center gap-4">
          <.button type="submit">{if @tab == :ask, do: "Ask", else: "Search"}</.button>
          <label class="flex items-center gap-2 text-sm text-zinc-600">
            <input type="checkbox" name="rerank" value="true" checked={@rerank} class="rounded" />
            Rerank results
          </label>
        </div>
      </form>
    </div>

    <div :if={@tab == :search and is_list(@results)} class="mt-6 space-y-3">
      <p :if={@results == []} class="text-sm text-zinc-500">No results found.</p>
      <div :for={r <- @results || []} class="rounded-lg border border-zinc-200 p-4">
        <div class="flex items-center gap-2 mb-2">
          <span class="text-xs font-mono bg-violet-50 text-violet-700 px-2 py-0.5 rounded">
            {Float.round(r.score, 3)}
          </span>
          <span class="text-xs text-zinc-500">
            {r.metadata[:source] || r.metadata[:url] || "unknown"}
            {if h = r.metadata[:heading], do: " — #{h}"}
          </span>
        </div>
        <p class="text-sm text-zinc-700 whitespace-pre-wrap">{String.slice(r.text, 0, 600)}</p>
      </div>
    </div>

    <div :if={@tab == :ask and not is_nil(@answer)} class="mt-6">
      <div class="rounded-lg bg-green-50 border border-green-200 p-4 text-sm leading-relaxed">
        {@answer.answer}
      </div>
      <div class="mt-3 text-xs text-zinc-500">
        <strong>Sources:</strong>
        <span :for={s <- @answer.sources} class="block mt-1">
          {s[:source] || s[:url] || "unknown"}
          {if h = s[:heading], do: " — #{h}"}
        </span>
      </div>
    </div>

    <div :if={@tab == :index} class="mt-6">
      <div :if={@index_message} class={"rounded-lg p-3 text-sm mb-4 " <> if(@index_message_type == :ok, do: "bg-green-50 border border-green-200 text-green-800", else: "bg-red-50 border border-red-200 text-red-800")}>
        {@index_message}
      </div>

      <div :if={@indexing} class="text-sm text-zinc-500 italic mb-4">
        <span class="inline-block w-3 h-3 rounded-full border-2 border-zinc-300 border-t-violet-600 animate-spin mr-1 align-middle"></span>
        Indexing in progress...
        <div :for={line <- Enum.reverse(@index_log)} class="mt-1 font-mono text-xs">{line}</div>
      </div>

      <form phx-submit="index" class="space-y-3">
        <.input
          type="textarea"
          name="sources"
          rows="6"
          placeholder={"One path or URL per line:\ndocs/\nREADME.md\nhttps://hexdocs.pm/elixir/GenServer.html"}
        />
        <div class="flex items-center gap-4">
          <.button type="submit" disabled={@indexing}>Start indexing</.button>
          <span class="text-xs text-zinc-500">Runs asynchronously in the background</span>
        </div>
      </form>
    </div>
    """
  end
end
