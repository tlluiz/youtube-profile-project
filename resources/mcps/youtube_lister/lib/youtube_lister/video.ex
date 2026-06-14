defmodule YoutubeLister.Video do
  @moduledoc """
  A single video row.

  `published` is an ISO-8601 string (as YouTube reports it in the player
  microformat); `views` and `likes` are integers, or `nil` when the metric was
  not available anonymously for that video.
  """

  @enforce_keys [:id]
  defstruct [:id, :title, :url, :published, :views, :likes]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t() | nil,
          url: String.t() | nil,
          published: String.t() | nil,
          views: non_neg_integer() | nil,
          likes: non_neg_integer() | nil
        }

  @doc "The canonical watch URL for a video id."
  @spec url_for(String.t()) :: String.t()
  def url_for(id), do: "https://www.youtube.com/watch?v=" <> id

  @doc """
  Parses `published` into a `DateTime` for ordering. Returns `nil` when absent
  or unparseable so callers can sort missing dates last.
  """
  @spec published_at(t()) :: DateTime.t() | nil
  def published_at(%__MODULE__{published: nil}), do: nil

  def published_at(%__MODULE__{published: iso}) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end
end
