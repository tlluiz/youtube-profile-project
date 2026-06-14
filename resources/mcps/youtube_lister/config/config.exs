import Config

# Default output directory: the repo's resources/videos (this file lives at
# resources/mcps/youtube_lister/config). Override per-run via the tool/options.
config :youtube_lister,
  videos_dir: Path.expand("../../../videos", __DIR__),
  http_client: YoutubeLister.HTTP.Req,
  # A realistic desktop-Chrome UA — the anonymous endpoints expect a browser.
  user_agent:
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " <>
      "Chrome/126.0.0.0 Safari/537.36",
  # Polite client: bounded concurrency + per-request pacing for the stats walk.
  max_concurrency: 4,
  request_delay_ms: 150,
  # Start the stdio MCP server as part of the supervision tree.
  start_server?: true

# stdout is the MCP JSON-RPC channel — all logs must go to stderr or they corrupt it.
config :logger, :default_handler, config: %{type: :standard_error}
config :logger, level: :info

import_config "#{config_env()}.exs"
