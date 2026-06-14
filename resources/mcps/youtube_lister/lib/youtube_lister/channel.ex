defmodule YoutubeLister.Channel do
  @moduledoc """
  Orchestrates a full anonymous crawl of a channel's videos: walk every
  continuation page to collect video ids, then enrich each with exact view and
  like counts and an ISO publish date.

  Failure tolerance is the rule, not the exception — a failed page stops the
  walk but keeps what was collected; a failed/partial enrichment yields a video
  with `nil` metrics rather than aborting the run.
  """

  require Logger

  alias YoutubeLister.{InnerTube, Video}

  @max_pages 1_000

  @doc """
  Crawls `channel` (handle or id) and returns the enriched videos in the order
  YouTube lists them (newest first). Options: `:user_agent`, `:max_concurrency`,
  `:request_delay_ms`, and `:max_pages` (continuation page cap; defaults to
  walking every page).
  """
  @spec crawl(String.t(), keyword()) :: {:ok, [Video.t()]} | {:error, term()}
  def crawl(channel, opts \\ []) do
    user_agent = opts[:user_agent] || config(:user_agent)

    case InnerTube.start(channel, user_agent) do
      {:ok, %{context: context, stubs: stubs, token: token}} ->
        stubs = collect(context, stubs, token, [stubs], MapSet.new(), opts)
        {:ok, enrich(context, stubs, opts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp max_pages(opts), do: opts[:max_pages] || @max_pages

  # Walk continuations until exhausted, a page fails, a token repeats, or the
  # page cap is hit. Chunks are accumulated reversed and flattened to preserve
  # newest-first order without quadratic appends.
  defp collect(_context, _stubs, nil, chunks, _seen, _opts), do: flatten(chunks)

  defp collect(context, _stubs, token, chunks, seen, opts) do
    cond do
      MapSet.member?(seen, token) ->
        flatten(chunks)

      MapSet.size(seen) >= max_pages(opts) ->
        flatten(chunks)

      true ->
        pace(opts)

        case InnerTube.browse(context, token) do
          {:ok, {more, next_token}} ->
            collect(context, more, next_token, [more | chunks], MapSet.put(seen, token), opts)

          {:error, reason} ->
            Logger.warning("stopping walk after browse error: #{inspect(reason)}")
            flatten(chunks)
        end
    end
  end

  defp flatten(chunks), do: chunks |> Enum.reverse() |> Enum.concat()

  defp enrich(context, stubs, opts) do
    max_concurrency = opts[:max_concurrency] || config(:max_concurrency)

    stubs
    |> Enum.uniq_by(& &1.id)
    |> Task.async_stream(fn stub -> enrich_one(context, stub, opts) end,
      max_concurrency: max_concurrency,
      timeout: 60_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, video} -> [video]
      {:exit, reason} -> Logger.warning("dropping video: #{inspect(reason)}") && []
    end)
  end

  defp enrich_one(context, %{id: id, title: title}, opts) do
    pace(opts)
    video = %Video{id: id, title: title, url: Video.url_for(id)}

    video =
      case safe(fn -> InnerTube.player(context, id) end) do
        {:ok, %{views: views, published: published, title: player_title}} ->
          %{video | views: views, published: published, title: title || player_title}

        _ ->
          video
      end

    case safe(fn -> InnerTube.next(context, id) end) do
      {:ok, likes} -> %{video | likes: likes}
      _ -> video
    end
  end

  # Swallow both error tuples and unexpected crashes for a single video.
  defp safe(fun) do
    fun.()
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp pace(opts) do
    case opts[:request_delay_ms] || config(:request_delay_ms) do
      ms when is_integer(ms) and ms > 0 -> Process.sleep(ms)
      _ -> :ok
    end
  end

  defp config(key), do: Application.fetch_env!(:youtube_lister, key)
end
