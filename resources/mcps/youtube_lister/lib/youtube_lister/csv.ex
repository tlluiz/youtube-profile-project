defmodule YoutubeLister.CSV do
  @moduledoc """
  Pure CSV encode/decode and the merge that keeps re-runs idempotent.

  Uses NimbleCSV (RFC-4180) so titles with commas, quotes and newlines round-trip
  safely. The on-disk order is newest video first; `merge/2` prepends only the
  videos not already stored, leaving existing rows untouched.
  """

  alias YoutubeLister.Video

  NimbleCSV.define(YoutubeLister.CSV.Parser, separator: ",", escape: "\"")

  @parser YoutubeLister.CSV.Parser
  @header ["id", "title", "url", "published", "views", "likes"]

  @doc "Encodes videos (with header row) to a CSV binary."
  @spec encode([Video.t()]) :: binary()
  def encode(videos) do
    rows = Enum.map(videos, &row/1)

    [@header | rows]
    |> @parser.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc "Decodes a CSV binary (with header) back into videos."
  @spec decode(binary()) :: [Video.t()]
  def decode(binary) do
    binary
    |> @parser.parse_string(skip_headers: true)
    |> Enum.flat_map(&to_video/1)
  end

  @doc """
  Merges a fresh crawl into the stored list. Returns `{merged, added_count}`
  where `merged` is newest-first and `added_count` is the number of newly
  prepended videos. Existing rows are preserved verbatim; dedup is by video id.
  """
  @spec merge([Video.t()], [Video.t()]) :: {[Video.t()], non_neg_integer()}
  def merge(existing, fetched) do
    existing_ids = MapSet.new(existing, & &1.id)

    added =
      fetched
      |> Enum.reject(&MapSet.member?(existing_ids, &1.id))
      |> Enum.uniq_by(& &1.id)
      |> sort_newest_first()

    {added ++ existing, length(added)}
  end

  @doc "Sorts videos newest-first; videos with no publish date sort last (stable)."
  @spec sort_newest_first([Video.t()]) :: [Video.t()]
  def sort_newest_first(videos), do: Enum.sort(videos, &newer_or_equal?/2)

  # --- internals -----------------------------------------------------------

  defp newer_or_equal?(a, b) do
    case {Video.published_at(a), Video.published_at(b)} do
      {nil, nil} -> true
      {nil, _} -> false
      {_, nil} -> true
      {da, db} -> DateTime.compare(da, db) != :lt
    end
  end

  defp row(%Video{} = v) do
    [v.id, v.title || "", v.url || "", v.published || "", int(v.views), int(v.likes)]
  end

  defp int(nil), do: ""
  defp int(n) when is_integer(n), do: Integer.to_string(n)

  defp to_video([id, title, url, published, views, likes]) when byte_size(id) > 0 do
    [
      %Video{
        id: id,
        title: blank_to_nil(title),
        url: blank_to_nil(url),
        published: blank_to_nil(published),
        views: YoutubeLister.Parse.parse_int(blank_to_nil(views)),
        likes: YoutubeLister.Parse.parse_int(blank_to_nil(likes))
      }
    ]
  end

  defp to_video(_), do: []

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
