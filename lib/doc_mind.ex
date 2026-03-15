defmodule DocMind do
  @moduledoc """
  DocMind — Semantic search and QA over technical documentation.

  ## Quick start

      # Index local files and/or HexDocs URLs (blocking)
      DocMind.index(["README.md", "docs/", "https://hexdocs.pm/elixir/GenServer.html"])

      # Or index asynchronously
      {:ok, job_id} = DocMind.index_async(["https://hexdocs.pm/elixir/GenServer.html"])
      DocMind.job_status(job_id)  # => {:running, started_at} | {:done, result}

      # Semantic search (reads from in-memory cache — no disk I/O)
      {:ok, results} = DocMind.search("how does supervision work?")

      # Ask a question with a context-grounded answer
      {:ok, answer} = DocMind.ask("when should I use handle_info instead of handle_cast?")

  ## Configuration

  Set your OpenAI API key:

      export OPENAI_API_KEY=sk-...

  Or in `config/config.exs`:

      config :doc_mind, openai_api_key: "sk-..."

  Optional overrides:

      config :doc_mind,
        embedding_model: "text-embedding-3-small",  # default
        llm_model: "gpt-4o-mini",                   # default
        store_path: ".doc_mind/index.bin"            # default
  """

  alias DocMind.Chunk
  alias DocMind.Ingestion.Loader
  alias DocMind.Chunking.SectionChunker
  alias DocMind.Store.{Cache, Manifest}
  alias DocMind.Retrieval.Retriever
  alias DocMind.QA.Answerer

  @doc """
  Index documents synchronously. Blocks until all embeddings are generated.

  Unchanged documents (same content hash as last run) are skipped.
  New chunks are merged into the existing index.

  ## Options

    * `:max_chars` — max characters per chunk (default: `1200`)
    * `:overlap` — character overlap between chunks (default: `100`)
    * `:request_delay_ms` — delay between crawler requests in ms (default: `100`)

  ## Returns

      {:ok, %{documents: 3, new: 2, skipped: 1, chunks: 47, total_chunks: 47, store_path: "..."}}
  """
  def index(paths_or_urls, opts \\ []) when is_list(paths_or_urls) do
    index_sync(paths_or_urls, opts)
  end

  @doc """
  Index documents asynchronously. Returns `{:ok, job_id}` immediately.

  Use `job_status/1` to poll or `await_job/2` to block until done.
  """
  def index_async(paths_or_urls, opts \\ []) when is_list(paths_or_urls) do
    DocMind.Indexer.index_async(paths_or_urls, opts)
  end

  @doc """
  Returns the status of an async indexing job:
    - `{:running, started_at}`
    - `{:done, result}`
    - `{:error, reason}`
    - `:not_found`
  """
  def job_status(job_id), do: DocMind.Indexer.job_status(job_id)

  @doc "Block until the async job finishes. Default timeout: 5 minutes."
  def await_job(job_id, timeout \\ 300_000), do: DocMind.Indexer.await_job(job_id, timeout)

  @doc """
  Semantic search over indexed documents.

  ## Options

    * `:top_k` — number of results to return (default: `5`)
    * `:semantic_weight` — weight 0.0–1.0 for semantic vs BM25 (default: `0.7`)
    * `:rerank` — run LLM reranker (default: `false`)

  ## Returns

      {:ok, [%DocMind.Result{score: 0.91, text: "...", metadata: %{source: "...", heading: "..."}}]}
  """
  def search(query, opts \\ []) when is_binary(query) do
    Retriever.search(query, opts)
  end

  @doc """
  Ask a question and receive a context-grounded answer with source citations.

  ## Options

    * `:top_k` — number of context chunks to use (default: `5`)

  ## Returns

      {:ok, %DocMind.Answer{answer: "...", sources: [%{source: "...", heading: "..."}]}}
  """
  def ask(query, opts \\ []) when is_binary(query) do
    Answerer.answer(query, opts)
  end

  @doc "Remove all chunks for a given source and drop it from the manifest."
  def remove_source(source) do
    chunks = Cache.get_chunks()
    :ok = Cache.put_chunks(Enum.reject(chunks, &(&1.metadata[:source] == source)))

    case Manifest.load() do
      {:ok, manifest} -> Manifest.save(Map.delete(manifest, source))
      _ -> :ok
    end
  end

  @doc "Clear the in-memory index, the on-disk store, and the manifest."
  def clear_index do
    Cache.clear()
    Manifest.delete()
  end

  # Called by DocMind.Indexer tasks — not part of the public API.
  @doc false
  def index_sync(paths_or_urls, opts) do
    adapter = Application.get_env(:doc_mind, :embedding_adapter)
    max_chars = Keyword.get(opts, :max_chars, 1200)
    overlap = Keyword.get(opts, :overlap, 100)
    collection = Keyword.get(opts, :collection, nil)

    source_labels = Keyword.get(opts, :source_labels, %{})

    with {:ok, docs} <- Loader.load(paths_or_urls, opts),
         {:ok, manifest} <- Manifest.load() do
      docs =
        Enum.map(docs, fn doc ->
          case Map.get(source_labels, doc.source) do
            nil -> doc
            label -> %{doc | source: label}
          end
        end)

      broadcast_progress("Loaded #{length(docs)} document(s)...")
      IO.puts("Loaded #{length(docs)} document(s)...")

      {new_docs, skipped} =
        Enum.split_with(docs, fn doc ->
          Manifest.changed?(manifest, doc.source, doc.content)
        end)

      broadcast_progress(
        "#{length(new_docs)} new/changed, #{length(skipped)} unchanged (skipped)."
      )

      IO.puts("#{length(new_docs)} new/changed, #{length(skipped)} unchanged (skipped).")

      if new_docs == [] do
        result =
          {:ok,
           %{
             documents: length(docs),
             new: 0,
             skipped: length(skipped),
             chunks: 0,
             total_chunks: length(Cache.get_chunks()),
             store_path: Application.get_env(:doc_mind, :store_path)
           }}

        broadcast_done(result)
        result
      else
        new_chunks =
          Enum.flat_map(new_docs, fn doc ->
            case SectionChunker.chunk(doc,
                   max_chars: max_chars,
                   overlap: overlap,
                   collection: collection
                 ) do
              {:ok, chunks} -> chunks
              _ -> []
            end
          end)

        broadcast_progress("Created #{length(new_chunks)} chunk(s), generating embeddings...")
        IO.puts("Created #{length(new_chunks)} chunk(s), generating embeddings...")

        texts = Enum.map(new_chunks, & &1.text)

        case adapter.embed_many(texts) do
          {:ok, embeddings} ->
            embedded =
              Enum.zip(new_chunks, embeddings)
              |> Enum.map(fn {chunk, emb} -> %Chunk{chunk | embedding: emb} end)

            existing = Cache.get_chunks()
            re_indexed_sources = MapSet.new(new_docs, & &1.source)

            all =
              existing
              |> Enum.reject(&MapSet.member?(re_indexed_sources, &1.metadata[:source]))
              |> Kernel.++(embedded)

            :ok = Cache.put_chunks(all)

            updated_manifest =
              Enum.reduce(new_docs, manifest, fn doc, m ->
                Manifest.mark_indexed(m, doc.source, doc.content)
              end)

            :ok = Manifest.save(updated_manifest)

            broadcast_progress("Done. #{length(embedded)} chunk(s) indexed.")
            IO.puts("Done. #{length(embedded)} chunk(s) indexed.")

            result =
              {:ok,
               %{
                 documents: length(docs),
                 new: length(new_docs),
                 skipped: length(skipped),
                 chunks: length(embedded),
                 total_chunks: length(all),
                 store_path: Application.get_env(:doc_mind, :store_path)
               }}

            broadcast_done(result)
            result

          {:error, reason} ->
            result = {:error, reason}
            broadcast_done(result)
            result
        end
      end
    end
  end

  defp broadcast_progress(msg) do
    if Process.whereis(DocMind.PubSub) do
      Phoenix.PubSub.broadcast(DocMind.PubSub, "indexing", {:indexing_progress, msg})
    end
  end

  defp broadcast_done(result) do
    if Process.whereis(DocMind.PubSub) do
      Phoenix.PubSub.broadcast(DocMind.PubSub, "indexing", {:indexing_done, result})
    end
  end
end
