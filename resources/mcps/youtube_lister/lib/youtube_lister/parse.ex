defmodule YoutubeLister.Parse do
  @moduledoc """
  Pure parsing of YouTube's anonymous InnerTube responses.

  The shapes here were verified empirically against live responses (June 2026):

    * Channel `/videos` HTML embeds `var ytInitialData = {...};` plus
      `"INNERTUBE_API_KEY"` and `"INNERTUBE_CONTEXT_CLIENT_VERSION"`.
    * The Videos tab is a `richGridRenderer` whose `contents` are
      `richItemRenderer -> lockupViewModel` entries (video id in `contentId`,
      title in `metadata.lockupMetadataViewModel.title.content`), terminated by a
      `continuationItemRenderer` carrying the next-page token.
    * `POST /youtubei/v1/browse` returns more items under
      `onResponseReceivedActions[].appendContinuationItemsAction.continuationItems`.
    * `POST /youtubei/v1/player` returns `videoDetails.viewCount` (exact) and
      `microformat.playerMicroformatRenderer.publishDate` (ISO-8601).
    * `POST /youtubei/v1/next` exposes the like count only via the like button's
      `accessibilityText`: "like this video along with N other people".
  """

  @key_re ~r/"INNERTUBE_API_KEY":"([^"]+)"/
  @ver_re ~r/"INNERTUBE_CONTEXT_CLIENT_VERSION":"([^"]+)"/
  @like_re ~r/like this video along with ([\d.,\s]+) other people/

  @doc "Decodes a JSON body with the built-in `JSON` module."
  @spec decode_json(binary()) :: {:ok, term()} | :error
  def decode_json(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, term} -> {:ok, term}
      {:error, _} -> :error
    end
  end

  @doc """
  Extracts the InnerTube client config (API key + client version) from the
  channel page HTML.
  """
  @spec client_config(binary()) ::
          {:ok, %{api_key: String.t(), client_version: String.t()}} | :error
  def client_config(html) when is_binary(html) do
    with [_, key] <- Regex.run(@key_re, html),
         [_, version] <- Regex.run(@ver_re, html) do
      {:ok, %{api_key: key, client_version: version}}
    else
      _ -> :error
    end
  end

  @doc "Extracts and decodes the `ytInitialData` object from channel page HTML."
  @spec initial_data(binary()) :: {:ok, map()} | :error
  def initial_data(html) when is_binary(html) do
    with {:ok, json} <- extract_json_object(html, "ytInitialData = "),
         {:ok, data} <- decode_json(json) do
      {:ok, data}
    end
  end

  @doc """
  Returns `{stubs, continuation_token}` for the first page, where each stub is
  `%{id: id, title: title}` and the token is `nil` when there are no more pages.
  """
  @spec videos_from_initial(map()) :: {[map()], String.t() | nil}
  def videos_from_initial(data) do
    tabs = get_in(data, ["contents", "twoColumnBrowseResultsRenderer", "tabs"]) || []

    grid =
      tabs
      |> Enum.find_value(fn tab ->
        if get_in(tab, ["tabRenderer", "selected"]) == true,
          do: get_in(tab, ["tabRenderer", "content", "richGridRenderer"])
      end) ||
        Enum.find_value(tabs, &get_in(&1, ["tabRenderer", "content", "richGridRenderer"]))

    parse_items((grid || %{})["contents"] || [])
  end

  @doc "Returns `{stubs, continuation_token}` for a `browse` continuation response."
  @spec videos_from_continuation(map()) :: {[map()], String.t() | nil}
  def videos_from_continuation(data) do
    (data["onResponseReceivedActions"] || [])
    |> Enum.flat_map(fn action ->
      get_in(action, ["appendContinuationItemsAction", "continuationItems"]) || []
    end)
    |> parse_items()
  end

  @doc "Extracts `%{title, views, published}` from a `player` response."
  @spec parse_player(map()) :: %{
          title: String.t() | nil,
          views: integer() | nil,
          published: String.t() | nil
        }
  def parse_player(json) do
    details = json["videoDetails"] || %{}
    microformat = get_in(json, ["microformat", "playerMicroformatRenderer"]) || %{}

    %{
      title: details["title"],
      views: parse_int(details["viewCount"]),
      published: microformat["publishDate"]
    }
  end

  @doc "Extracts the like count from a `next` response, or `nil` if unavailable."
  @spec likes_from_next(term()) :: integer() | nil
  def likes_from_next(data), do: deep_find_like(data)

  @doc """
  Parses an integer from a string of exact digits (commas/spaces stripped).
  Returns `nil` for `nil` or unparseable input. Not for abbreviated counts.
  """
  @spec parse_int(term()) :: integer() | nil
  def parse_int(nil), do: nil
  def parse_int(n) when is_integer(n), do: n

  def parse_int(str) when is_binary(str) do
    case Integer.parse(String.replace(str, ~r/[^\d]/, "")) do
      {n, _} -> n
      :error -> nil
    end
  end

  def parse_int(_), do: nil

  # --- internals -----------------------------------------------------------

  defp parse_items(items) do
    stubs = Enum.flat_map(items, &item_to_stub/1)
    token = Enum.find_value(items, &continuation_token/1)
    {stubs, token}
  end

  defp item_to_stub(item) do
    lvm = get_in(item, ["richItemRenderer", "content", "lockupViewModel"])

    case lvm do
      %{"contentId" => id, "contentType" => "LOCKUP_CONTENT_TYPE_VIDEO"} when is_binary(id) ->
        [
          %{
            id: id,
            title: get_in(lvm, ["metadata", "lockupMetadataViewModel", "title", "content"])
          }
        ]

      _ ->
        []
    end
  end

  defp continuation_token(item),
    do:
      get_in(item, [
        "continuationItemRenderer",
        "continuationEndpoint",
        "continuationCommand",
        "token"
      ])

  defp deep_find_like(%{"accessibilityText" => text} = map) when is_binary(text) do
    case Regex.run(@like_re, text) do
      [_, number] -> parse_int(number)
      _ -> deep_find_like(Map.delete(map, "accessibilityText"))
    end
  end

  defp deep_find_like(map) when is_map(map), do: deep_find_in(Map.values(map))
  defp deep_find_like(list) when is_list(list), do: deep_find_in(list)
  defp deep_find_like(_), do: nil

  defp deep_find_in(enum), do: Enum.find_value(enum, &deep_find_like/1)

  # Finds `marker` then captures the balanced `{...}` object that follows,
  # respecting JSON string literals and escapes. Tail-recursive (no stack growth).
  @doc false
  @spec extract_json_object(binary(), binary()) :: {:ok, binary()} | :error
  def extract_json_object(html, marker) do
    case :binary.match(html, marker) do
      :nomatch ->
        :error

      {pos, len} ->
        rest = binary_part(html, pos + len, byte_size(html) - pos - len)

        with {:ok, <<?{, after_brace::binary>> = from_brace} <- drop_to_brace(rest),
             {:ok, length} <- scan(after_brace, 1, 1, false, false) do
          {:ok, binary_part(from_brace, 0, length)}
        end
    end
  end

  defp drop_to_brace(<<?{, _::binary>> = bin), do: {:ok, bin}
  defp drop_to_brace(<<_, rest::binary>>), do: drop_to_brace(rest)
  defp drop_to_brace(<<>>), do: :error

  # scan/5 starts one byte past the opening brace (n=1, depth=1).
  defp scan(<<>>, _n, _depth, _in_string, _escaped), do: :error

  # inside a string, previous char was a backslash: consume this char literally
  defp scan(<<_, rest::binary>>, n, d, true, true), do: scan(rest, n + 1, d, true, false)
  defp scan(<<?\\, rest::binary>>, n, d, true, false), do: scan(rest, n + 1, d, true, true)
  defp scan(<<?", rest::binary>>, n, d, true, false), do: scan(rest, n + 1, d, false, false)
  defp scan(<<_, rest::binary>>, n, d, true, false), do: scan(rest, n + 1, d, true, false)

  # outside a string
  defp scan(<<?", rest::binary>>, n, d, false, _), do: scan(rest, n + 1, d, true, false)
  defp scan(<<?{, rest::binary>>, n, d, false, _), do: scan(rest, n + 1, d + 1, false, false)

  defp scan(<<?}, rest::binary>>, n, d, false, _) do
    case d - 1 do
      0 -> {:ok, n + 1}
      depth -> scan(rest, n + 1, depth, false, false)
    end
  end

  defp scan(<<_, rest::binary>>, n, d, false, _), do: scan(rest, n + 1, d, false, false)
end
