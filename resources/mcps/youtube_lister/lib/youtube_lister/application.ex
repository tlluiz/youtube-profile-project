defmodule YoutubeLister.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Supervised HTTP/2-capable connection pool used by Req.
        {Finch, name: YoutubeLister.Finch}
      ] ++ server_children()

    opts = [strategy: :one_for_one, name: YoutubeLister.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # The stdio MCP server is started unless disabled (e.g. in tests, where it
  # would otherwise fight for stdin).
  defp server_children do
    if Application.get_env(:youtube_lister, :start_server?, true) do
      [Hermes.Server.Registry, {YoutubeLister.Server, transport: :stdio}]
    else
      []
    end
  end
end
