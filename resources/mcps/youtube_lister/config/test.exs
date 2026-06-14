import Config

# Tests mock HTTP at the client boundary and never start the stdio server.
config :youtube_lister,
  http_client: YoutubeLister.HTTPMock,
  start_server?: false,
  request_delay_ms: 0
