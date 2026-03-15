defmodule DocMindWeb.IndexPanel do
  use DocMindWeb, :html

  attr :index_message, :string, default: nil
  attr :index_message_type, :atom, default: nil
  attr :indexing, :boolean, required: true
  attr :index_log, :list, required: true
  attr :uploads, :map, required: true

  def index_panel(assigns) do
    ~H"""
    <div class="space-y-5">
      <.index_alert message={@index_message} type={@index_message_type} />
      <.indexing_progress :if={@indexing} log={@index_log} />
      <form phx-submit="index" phx-change="validate" class="space-y-4">
        <div>
          <p class="text-sm font-medium mb-2">
            Collection <span class="text-base-content/30 font-normal">(optional)</span>
          </p>
          <input
            type="text"
            name="collection"
            class="input input-bordered w-full text-sm"
            placeholder="e.g. Elixir Docs, My Project…"
          />
        </div>
        <.upload_zone uploads={@uploads} />
        <div>
          <p class="text-sm font-medium mb-2">
            URLs <span class="text-base-content/30 font-normal">(optional)</span>
          </p>
          <textarea
            name="sources"
            rows="4"
            class="textarea textarea-bordered w-full text-sm font-mono leading-relaxed"
            placeholder="One URL per line:&#10;https://hexdocs.pm/elixir/GenServer.html"
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
    """
  end

  defp index_alert(%{message: nil} = assigns), do: ~H""

  defp index_alert(assigns) do
    ~H"""
    <div class={"alert text-sm " <> if(@type == :ok, do: "alert-success", else: "alert-error")}>
      <.icon
        name={if @type == :ok, do: "hero-check-circle-micro", else: "hero-x-circle-micro"}
        class="size-4"
      />
      {@message}
    </div>
    """
  end

  defp indexing_progress(assigns) do
    ~H"""
    <div class="alert alert-info text-sm">
      <span class="loading loading-spinner loading-sm"></span>
      <div>
        <p class="font-medium">Indexing in progress…</p>
        <p :for={line <- Enum.take(@log, 3)} class="font-mono text-xs opacity-60 mt-1">{line}</p>
      </div>
    </div>
    """
  end

  defp upload_zone(assigns) do
    ~H"""
    <div>
      <p class="text-sm font-medium mb-2">
        Upload files <span class="text-base-content/30 font-normal">(.md, .txt)</span>
      </p>
      <div
        phx-drop-target={@uploads.files.ref}
        class="border-2 border-dashed border-base-300 rounded-xl p-5 text-center hover:border-primary/40 transition-colors"
      >
        <.icon name="hero-arrow-up-tray" class="size-7 mx-auto mb-2 text-base-content/25" />
        <p class="text-sm text-base-content/40 mb-3">Drop files here or</p>
        <label for={@uploads.files.ref} class="btn btn-sm btn-outline cursor-pointer">
          Browse files
        </label>
        <.live_file_input upload={@uploads.files} class="hidden" />
      </div>
      <div :if={@uploads.files.entries != []} class="mt-2 space-y-1">
        <.uploaded_file :for={entry <- @uploads.files.entries} entry={entry} uploads={@uploads} />
        <div :for={err <- upload_errors(@uploads.files)} class="text-xs text-error">
          {error_to_string(err)}
        </div>
      </div>
    </div>
    """
  end

  defp uploaded_file(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm py-1">
      <.icon name="hero-document-text-micro" class="size-3.5 text-base-content/40 shrink-0" />
      <span class="flex-1 truncate text-base-content/70">{@entry.client_name}</span>
      <span class="text-xs text-base-content/30">
        {Float.round(@entry.client_size / 1024, 1)} KB
      </span>
      <button
        type="button"
        phx-click="cancel_upload"
        phx-value-ref={@entry.ref}
        class="btn btn-ghost btn-xs text-error px-1"
      >
        <.icon name="hero-x-mark-micro" class="size-3.5" />
      </button>
    </div>
    <%= for err <- upload_errors(@uploads.files, @entry) do %>
      <div class="text-xs text-error">{@entry.client_name}: {error_to_string(err)}</div>
    <% end %>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 10 MB)"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "Only .md and .txt files are accepted"
end
