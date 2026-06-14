defmodule YoutubeLister.Lister do
  @moduledoc """
  Top-level use case: crawl a channel and write/update its
  `<videos_dir>/<channel>/list.csv`, returning a short summary.
  """

  alias YoutubeLister.{Channel, CSV}

  @type summary :: %{
          channel: String.t(),
          slug: String.t(),
          path: String.t(),
          total_stored: non_neg_integer(),
          newly_prepended: non_neg_integer()
        }

  @doc """
  Runs the crawl + CSV update for `channel`. Options are forwarded to
  `YoutubeLister.Channel.crawl/2`, plus `:videos_dir` to override the output root.
  """
  @spec run(String.t(), keyword()) :: {:ok, summary()} | {:error, term()}
  def run(channel, opts \\ []) do
    videos_dir = opts[:videos_dir] || Application.fetch_env!(:youtube_lister, :videos_dir)
    slug = slugify(channel)
    path = Path.join([videos_dir, slug, "list.csv"])

    case Channel.crawl(channel, opts) do
      {:ok, fetched} ->
        existing = read_existing(path)
        {merged, added} = CSV.merge(existing, fetched)

        File.mkdir_p!(Path.dirname(path))
        File.write!(path, CSV.encode(merged))

        {:ok,
         %{
           channel: channel,
           slug: slug,
           path: path,
           total_stored: length(merged),
           newly_prepended: added
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Filesystem-safe directory name for a channel handle or id."
  @spec slugify(String.t()) :: String.t()
  def slugify(channel) do
    channel
    |> String.trim()
    |> String.trim_leading("@")
    |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
  end

  defp read_existing(path) do
    case File.read(path) do
      {:ok, binary} -> CSV.decode(binary)
      {:error, _} -> []
    end
  end
end
