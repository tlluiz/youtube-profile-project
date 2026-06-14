defmodule YoutubeLister.Tools.ListChannelVideos do
  @moduledoc """
  List all videos of a public YouTube channel (anonymously, no API key) and
  write them to resources/videos/<channel>/list.csv, newest first, with view
  and like counts. Re-runs prepend only newly published videos.
  """

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias YoutubeLister.Lister

  schema do
    field(:channel, :string, required: true)
  end

  @impl true
  def execute(%{channel: channel}, frame) do
    case Lister.run(channel) do
      {:ok, summary} ->
        {:reply, Response.json(Response.tool(), summary), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "list failed: #{inspect(reason)}"), frame}
    end
  end
end
