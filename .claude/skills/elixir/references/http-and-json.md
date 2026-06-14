# HTTP & JSON

The MCP servers call external APIs (YouTube) and exchange JSON. Use the community
default HTTP client and the standard-library JSON module.

## JSON — prefer the built-in `JSON` module

Elixir ships a built-in `JSON` module (since Elixir 1.18) — no dependency needed
for encode/decode. Use it as the default.

```elixir
{:ok, data} = JSON.decode(~s({"id":"abc","likes":42}))
# => %{"id" => "abc", "likes" => 42}

JSON.encode!(%{id: "abc", likes: 42})
# => ~s({"id":"abc","likes":42})
```

- `JSON.decode/1` → `{:ok, term} | {:error, reason}`; `JSON.decode!/1` raises.
- Decoded object keys are **strings**, not atoms. Don't blindly convert untrusted
  keys to atoms (`String.to_atom/1` on attacker-controlled input can exhaust the
  atom table) — match the strings you expect, or use `String.to_existing_atom/1`.
- Reference: <https://hexdocs.pm/elixir/JSON.html>.

`Jason` is the long-standing community JSON library and is still widely used (some
libraries depend on it). The built-in `JSON` module is the right default for new
code; reach for Jason only if a dependency requires it. <https://hexdocs.pm/jason/>.

## HTTP client — Req (the community default)

Req is the high-level HTTP client most new Elixir code uses. It does sensible
things by default: follows redirects, retries, decodes JSON responses
automatically, and raises clear errors. Built on Finch/Mint.
Reference: <https://hexdocs.pm/req/>.

```elixir
# mix.exs:  {:req, "~> 0.5"}

# GET with query params; Req decodes a JSON body into resp.body automatically.
{:ok, resp} =
  Req.get("https://www.googleapis.com/youtube/v3/videos",
    params: [part: "statistics", id: video_id, key: api_key]
  )

case resp.status do
  200 -> {:ok, resp.body}            # already a decoded map
  status -> {:error, {:http, status, resp.body}}
end
```

`Req.get!/2` raises on transport errors; `Req.get/2` returns
`{:ok, resp} | {:error, exception}`. Choose per call site — tuples at boundaries
you handle, `!` where a failure should crash a supervised process.

### A small, testable API client

Keep external calls behind a thin module with a behaviour, so it's swappable and
mockable (see testing.md). Inject a base `Req.Request` for easy test stubbing.

```elixir
defmodule MyApp.YouTube do
  @moduledoc "Thin client for the YouTube Data API v3."

  @callback list_videos(channel_id :: String.t()) ::
              {:ok, [map()]} | {:error, term()}

  @base "https://www.googleapis.com/youtube/v3"

  @spec list_videos(String.t()) :: {:ok, [map()]} | {:error, term()}
  def list_videos(channel_id) do
    key = Application.fetch_env!(:my_app, :youtube_api_key)

    with {:ok, %{status: 200, body: body}} <-
           Req.get("#{@base}/search",
             params: [part: "id", channelId: channel_id, maxResults: 50, key: key]
           ) do
      {:ok, body["items"]}
    else
      {:ok, %{status: status, body: body}} -> {:error, {:http, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Concurrency for many requests

To fetch metadata for many videos, fan out with bounded concurrency rather than
sequential calls (see otp-and-concurrency.md):

```elixir
video_ids
|> Task.async_stream(&MyApp.YouTube.fetch_stats/1,
     max_concurrency: 8,
     timeout: 30_000,
     on_timeout: :kill_task
   )
|> Enum.reduce({[], []}, fn
  {:ok, {:ok, stats}}, {oks, errs} -> {[stats | oks], errs}
  {:ok, {:error, e}}, {oks, errs} -> {oks, [e | errs]}
  {:exit, reason}, {oks, errs} -> {oks, [{:timeout, reason} | errs]}
end)
```

## Testing HTTP code

Don't hit the network in unit tests. Two good options:

- **Req's built-in test stubs** — set `plug:` or `Req.Test` stubs to return canned
  responses. <https://hexdocs.pm/req/Req.Test.html>
- **Behaviour + Mox** — mock the `MyApp.YouTube` behaviour at the boundary (see
  testing.md). Best when you want to assert *your* code's handling, not Req's.

## Guidance

- New code: built-in `JSON` + `Req`. Don't pull in `HTTPoison`/`Tesla`/`Jason`
  unless a dependency forces it or you have a concrete need Req doesn't meet.
- Always set timeouts on outbound calls; never let a request block a GenServer.
- Treat external responses as untrusted: match expected string keys, validate
  shapes, and return tagged errors for anything unexpected.
- Read secrets (API keys) from runtime config / env, never from source.
