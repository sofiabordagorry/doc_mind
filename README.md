# DocMind

Semantic search and question-answering over your documentation. Index local files, directories, or HexDocs URLs, then search or ask questions through a web UI or directly from IEx.

## Getting started

1. Set your OpenAI API key:

```bash
export OPENAI_API_KEY=sk-...
```

2. Install dependencies and start the server:

```bash
mix setup
mix phx.server
```

3. Open [localhost:4000](http://localhost:4000) in your browser.

## How it works

### Indexing

When you index a source, DocMind runs it through a pipeline:

1. **Load** — Files and directories are read from disk. HexDocs URLs are crawled recursively, following links within the same package.
2. **Chunk** — Each document is split into sections based on Markdown headings, then further split if a section exceeds the max character limit (default 1200 chars, with 100-char overlap between chunks).
3. **Embed** — Each chunk is sent to OpenAI's `text-embedding-3-small` to generate a vector embedding.
4. **Store** — Chunks and embeddings are kept in an in-memory ETS cache and persisted to disk at `.doc_mind/index.bin`. A manifest file tracks content hashes so unchanged documents are skipped on re-index.

Indexing runs asynchronously in a supervised Task. Progress is broadcast over PubSub and shown live in the UI.

You can optionally assign a **collection** name when indexing (e.g. "Elixir Docs", "My Project"). Collections are stored in each chunk's metadata and used to group sources in the Sources tab.

### Search

Search uses **hybrid retrieval**: results are scored by both vector similarity (cosine distance against the query embedding) and BM25 keyword matching, then combined with a weighted sum (default: 70% semantic, 30% BM25). This means queries work well whether they're conceptual ("how does supervision work?") or keyword-specific ("GenServer handle_call").

Optionally enabling **Rerank** sends the top results to the LLM to re-order them by relevance before returning. Useful for large indexes, but adds an extra API call.

### Ask

Ask retrieves the top-5 most relevant chunks for your question, then sends them as context to `gpt-4o-mini` with a prompt that instructs it to answer using only the provided context and cite sources by number. If the answer cannot be determined from the indexed content, it says so and no sources are shown.

### Architecture

```
lib/doc_mind/
├── ingestion/
│   ├── loader.ex          # Dispatches to file_loader or hexdocs_crawler
│   ├── file_loader.ex     # Reads .md, .txt, .ex, .exs files and directories
│   └── hexdocs_crawler.ex # Crawls HexDocs pages, extracts Markdown content
├── chunking/
│   └── section_chunker.ex # Splits documents into overlapping sections
├── embeddings/
│   └── openai.ex          # Batch embedding via text-embedding-3-small
├── store/
│   ├── cache.ex           # In-memory ETS store for chunks + embeddings
│   ├── file_store.ex      # Binary serialization to disk
│   └── manifest.ex        # Content-hash manifest for incremental indexing
├── retrieval/
│   ├── retriever.ex       # Orchestrates hybrid search + optional reranking
│   ├── similarity.ex      # Cosine similarity scoring
│   ├── bm25.ex            # BM25 keyword scoring
│   ├── hybrid_ranker.ex   # Combines semantic + BM25 scores
│   └── reranker.ex        # LLM-based result reranking
├── qa/
│   └── answerer.ex        # Builds RAG prompt and calls LLM
├── indexer.ex             # GenServer managing async indexing jobs
└── config.ex              # Runtime configuration

lib/doc_mind_web/
└── live/
    └── search_live.ex     # Single LiveView: Ask, Search, Index, Sources tabs
```

## Configuration

DocMind uses an adapter pattern for both LLM calls (Ask / Rerank) and embeddings (Index / Search). You can mix and match adapters independently.

### LLM adapter

Controls which model powers the Ask feature and the optional Rerank step.

| Adapter | Config key | Default model key | Default |
|---|---|---|---|
| `DocMind.LLM.OpenAI` | `openai_api_key` | `llm_model` | `gpt-4o-mini` |
| `DocMind.LLM.Anthropic` | `anthropic_api_key` | `anthropic_llm_model` | `claude-haiku-4-5` |

```elixir
# config/config.exs

# OpenAI (default)
config :doc_mind,
  llm_adapter: DocMind.LLM.OpenAI,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  llm_model: "gpt-4o-mini"

# Anthropic
config :doc_mind,
  llm_adapter: DocMind.LLM.Anthropic,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  anthropic_llm_model: "claude-haiku-4-5"   # any Claude model works
```

### Embedding adapter

Controls how chunks are embedded at index time and how queries are embedded at search time.

| Adapter | Config key | Default model key | Default |
|---|---|---|---|
| `DocMind.Embeddings.OpenAI` | `openai_api_key` | `embedding_model` | `text-embedding-3-small` |
| `DocMind.Embeddings.HuggingFace` | `huggingface_api_key` | `embedding_model` | `intfloat/e5-large-v2` |

```elixir
# config/config.exs

# OpenAI (default)
config :doc_mind,
  embedding_adapter: DocMind.Embeddings.OpenAI,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  embedding_model: "text-embedding-3-small"

# HuggingFace (free, runs e5-large-v2 by default)
config :doc_mind,
  embedding_adapter: DocMind.Embeddings.HuggingFace,
  huggingface_api_key: System.get_env("HUGGINGFACE_API_KEY"),
  embedding_model: "intfloat/e5-large-v2"
```

> **Note:** The embedding adapter must stay the same between indexing and search — embeddings from different models are not comparable. If you switch adapters, clear the index first with `DocMind.clear_index()`.

### Other options

| Key | Default | Description |
|---|---|---|
| `store_path` | `.doc_mind/index.bin` | Where the index is persisted to disk |

## Using from IEx

```elixir
# Index files or URLs (blocking)
DocMind.index(["README.md", "docs/", "https://hexdocs.pm/elixir/GenServer.html"])

# Index asynchronously
{:ok, job_id} = DocMind.index_async(["https://hexdocs.pm/elixir"], collection: "Elixir Docs")
DocMind.job_status(job_id)  # => {:running, started_at} | {:done, result}

# Search
{:ok, results} = DocMind.search("how does supervision work?", top_k: 8)

# Ask a question
{:ok, answer} = DocMind.ask("when should I use handle_info instead of handle_cast?")

# Clear the index
DocMind.clear_index()
```
