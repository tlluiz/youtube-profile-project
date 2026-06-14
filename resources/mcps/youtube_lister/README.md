# youtube_lister

An **MCP server** (Elixir/OTP) that lists every video of a public YouTube
channel **anonymously** — no API key, no OAuth, no login — and writes them to a
CSV with view and like counts.

It uses the same anonymous surface the YouTube website itself uses: the
`ytInitialData` embedded in the channel's Videos tab and the `youtubei`
("InnerTube") `browse` / `player` / `next` endpoints that back it. The
**YouTube Data API v3 is deliberately not used** (it requires an API-key
credential, which defeats the anonymous principle).

## What it produces

`<videos_dir>/<channel>/list.csv`, newest video first, with columns:

```
id,title,url,published,views,likes
```

- `<videos_dir>` defaults to the repo's `resources/videos`
  (see `config/config.exs`).
- `<channel>` is the handle or id you requested (e.g. `ElixirConf`).
- Re-runs are **idempotent**: only videos newer than what's already stored are
  prepended; existing rows are preserved verbatim; dedup is by video id.
- Failures mid-walk are swallowed — a bad page stops the walk but keeps what was
  collected, and a video missing a metric is stored with that field blank rather
  than aborting the run.

## The exposed tool

| Tool | Input | Behaviour |
| --- | --- | --- |
| `list_channel_videos` | `{ "channel": "<handle-or-id>" }` | Crawls the channel and creates/updates its `list.csv`, returning a summary `{channel, slug, path, total_stored, newly_prepended}`. |

`channel` accepts `@handle`, `handle`, or a `UC…` channel id.

## How the anonymous data is obtained (verified against live responses)

1. `GET https://www.youtube.com/@<handle>/videos` — scrape `INNERTUBE_API_KEY`,
   `INNERTUBE_CONTEXT_CLIENT_VERSION`, and the `ytInitialData` object. The Videos
   tab is a `richGridRenderer` of `lockupViewModel` items (video id + title), plus
   a `continuationItemRenderer` token.
2. `POST /youtubei/v1/browse` with `{context, continuation}` — walk every page
   via `appendContinuationItemsAction.continuationItems` until no token remains.
3. `POST /youtubei/v1/player` with `{context, videoId}` — exact
   `videoDetails.viewCount` and ISO `microformat…publishDate`.
4. `POST /youtubei/v1/next` with `{context, videoId}` — like count, read from the
   like button's `accessibilityText` ("like this video along with N other people").

Requests carry a realistic browser `User-Agent` and the InnerTube client
headers. The stats walk is a polite client: bounded concurrency
(`Task.async_stream`) plus per-request pacing.

## Running the MCP server (stdio)

```bash
mix deps.get
mix run --no-halt        # speaks MCP over stdio (logs go to stderr)
```

Register it with an MCP client (e.g. Claude Desktop / Claude Code). Example
client config:

```json
{
  "mcpServers": {
    "youtube-lister": {
      "command": "mix",
      "args": ["run", "--no-halt"],
      "cwd": "/home/tlluiz/projects/youtube-profile-project/resources/mcps/youtube_lister"
    }
  }
}
```

> stdout is the JSON-RPC channel, so all logging is routed to stderr
> (`config/config.exs`). Don't print to stdout from tool code.

## Running without the MCP layer

```elixir
# scripted, server disabled — see priv/e2e.exs:
#   mix run --no-start priv/e2e.exs "@ElixirConf" 1000 resources/videos
YoutubeLister.run("@ElixirConf")
# => {:ok, %{channel: "@ElixirConf", total_stored: 412, newly_prepended: 412, ...}}
```

`YoutubeLister.run/2` options: `:videos_dir`, `:max_concurrency`,
`:request_delay_ms`, `:max_pages` (continuation-page cap; defaults to walking
every page).

## Tests

```bash
mix test                  # HTTP mocked at the YoutubeLister.HTTP boundary (Mox)
mix format --check-formatted
```

Covered: CSV ordering/merge/idempotency, InnerTube response parsing, and the
full crawl→merge→write flow with the HTTP boundary mocked.

## A note on the MCP library version

`hermes_mcp` is pinned to the **0.11.x** line. Its 0.12.0 release regressed the
stdio transport: `Hermes.Server.Transport.STDIO.process_message/2` stopped
unwrapping the decoded message list and raises `BadMapError` on every request
(reproduced against 0.14.1). 0.11.3 is the last good stdio release and exposes
the same server/component/`Response` API used here.

## Layout

```
lib/youtube_lister/
  http.ex            # HTTP boundary behaviour (mocked in tests)
  http/req.ex        # Req + supervised Finch implementation
  parse.ex           # pure parsing of InnerTube responses
  inner_tube.ex      # effectful InnerTube client (start/browse/player/next)
  channel.ex         # crawl orchestration: walk pages + enrich, fault-tolerant
  csv.ex             # pure CSV encode/decode + idempotent merge (NimbleCSV)
  video.ex           # the Video struct
  lister.ex          # top-level use case: crawl + write/update CSV
  tools/list_channel_videos.ex   # the MCP tool
  server.ex          # the MCP server
  application.ex     # supervision tree (Finch, Hermes registry, stdio server)
```
