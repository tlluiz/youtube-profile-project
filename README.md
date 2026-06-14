# youtube-profile-project

Building, in **Elixir/OTP**, a set of **MCP servers** that together turn a public
YouTube channel into an *influencer communication profile* — fetch a channel's
video metadata, rank and download the top videos, transcribe them, and synthesize
a profile of how the creator communicates.

The work is driven incrementally by a series of prompts (in
[resources/prompts/](resources/prompts/)), each building on a shared, reusable
**Elixir language Skill** so every MCP server is written in idiomatic, modern,
well-tested Elixir. The high-level plan is sketched in
[resources/docs/overview.excalidraw](resources/docs/overview.excalidraw).

## Roadmap

| Stage | What it does | Status |
| --- | --- | --- |
| Elixir Skill | A Claude Code Skill making an agent fluent in modern Elixir/OTP — the foundation for every MCP server | ✅ Done |
| List channel videos | MCP server: anonymously list a channel's videos with view/like counts → CSV | ✅ Done ([youtube_lister](resources/mcps/youtube_lister/)) |
| Rank & download top videos | Pick the most relevant videos and fetch them | 🔜 Planned |
| Transcribe | Produce transcripts of the downloaded videos | 🔜 Planned |
| Synthesize profile | Combine transcripts + metadata into a communication profile | 🔜 Planned |

## Repository layout

```
.claude/skills/elixir/      # the reusable Elixir/OTP Skill (SKILL.md + references)
resources/
  docs/overview.excalidraw  # high-level pipeline sketch
  prompts/                  # the prompts that drive each stage
  mcps/                     # the MCP servers (one Mix project per server)
    youtube_lister/         # anonymous channel video lister
  videos/                   # generated CSV output (gitignored)
.tool-versions              # asdf pins: erlang 29.0.2, elixir 1.20.1-otp-29
```

## Toolchain

Managed with [asdf](https://asdf-vm.com/) via [.tool-versions](.tool-versions):

- **Erlang/OTP** 29.0.2
- **Elixir** 1.20.1 (otp-29)

```bash
asdf install        # install the pinned versions
```

## The Elixir Skill

[.claude/skills/elixir/](/.claude/skills/elixir/) makes an agent fluent in
idiomatic, modern Elixir for building OTP applications and long-running services.
`SKILL.md` is the map; deeper material lives in progressively-disclosed reference
files:

- `references/language-core.md` — pattern matching, structs, protocols, `with`, error handling
- `references/types-and-specs.md` — `@spec`/`@type`, Dialyzer, set-theoretic types
- `references/otp-and-concurrency.md` — processes, `GenServer`, `Task`, supervision
- `references/project-and-tooling.md` — Mix, deps, config, formatting, releases
- `references/testing.md` — ExUnit, Mox, doctests, property-based testing
- `references/http-and-json.md` — HTTP clients (Req) and JSON

Every MCP server in this repo is built by following this Skill.

## MCP servers

### `youtube_lister` — anonymous channel video lister

Lists every video of a public channel **anonymously** (no API key, OAuth, or
login) using the same InnerTube surface the YouTube website uses, and writes
`resources/videos/<channel>/list.csv` (newest first, with view and like counts).
Re-runs incrementally prepend only new videos.

See [resources/mcps/youtube_lister/README.md](resources/mcps/youtube_lister/README.md)
for endpoints, the exposed tool, MCP client configuration, and tests.

```bash
cd resources/mcps/youtube_lister
mix deps.get
mix test
mix run --no-halt        # speaks MCP over stdio
```

## License

No license has been declared yet.
