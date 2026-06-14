defmodule YoutubeLister do
  @moduledoc """
  Anonymous YouTube channel video lister.

  Crawls a public channel's Videos tab via the same anonymous InnerTube surface
  the website uses (no API key, OAuth, or login), collects every video with its
  exact view and like counts, and writes a newest-first CSV that re-runs update
  incrementally. Exposed as an MCP tool (`list_channel_videos`).

  See `YoutubeLister.Lister.run/2` for the programmatic entry point.
  """

  defdelegate run(channel, opts \\ []), to: YoutubeLister.Lister
end
