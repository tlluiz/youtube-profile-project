defmodule YoutubeLister.Server do
  @moduledoc """
  The MCP server. Exposes a single tool, `list_channel_videos`, over whatever
  transport it is started with (stdio in the supervision tree).
  """

  use Hermes.Server,
    name: "youtube-lister",
    version: "0.1.0",
    capabilities: [:tools]

  component(YoutubeLister.Tools.ListChannelVideos)
end
