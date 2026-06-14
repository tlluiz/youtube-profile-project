# Project & tooling

Mix is the build tool, task runner, and dependency manager.
Reference: <https://hexdocs.pm/mix/Mix.html>.

## Scaffolding

```bash
mix new my_app --sup    # supervised OTP app (Application + supervisor)
mix new my_lib          # plain library (no process tree)
```

Use `--sup` for anything that runs processes (services, MCP servers). Layout:

```
my_app/
  lib/
    my_app/application.ex   # OTP Application callback + supervision tree
    my_app.ex
  test/
  config/                   # add when you need configuration (see below)
  mix.exs                   # project definition, deps, app config
  .formatter.exs            # mix format rules
  .tool-versions            # asdf pins (this project already has one)
```

## `mix.exs` — project + dependencies

```elixir
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # `mod:` wires the Application callback so the supervision tree starts.
  def application do
    [extra_applications: [:logger], mod: {MyApp.Application, []}]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
```

Version requirements use `~>`: `~> 0.5` means `>= 0.5.0 and < 0.6.0`;
`~> 1.4` means `>= 1.4.0 and < 2.0.0`. Reference: <https://hexdocs.pm/elixir/Version.html>.

## Dependency commands

```bash
mix deps.get          # fetch deps into deps/, write mix.lock
mix deps.compile
mix deps.tree         # inspect the dependency graph
mix deps.update req   # update one dep within its requirement
mix hex.outdated      # what has newer releases
```

Commit `mix.lock` — it pins exact resolved versions for reproducible builds.
Find packages on <https://hex.pm>; read each on `https://hexdocs.pm/<package>/`.

## Configuration

Two config files, different timing:

- `config/config.exs` (+ `config/dev.exs` etc.) — **compile-time** config, read at
  build time. Imported per-environment.
- `config/runtime.exs` — **runtime** config, read on boot. This is where secrets
  and anything from the environment belong (e.g. an API key for the YouTube API).

```elixir
# config/runtime.exs
import Config

config :my_app,
  youtube_api_key: System.fetch_env!("YOUTUBE_API_KEY"),
  request_timeout: String.to_integer(System.get_env("REQUEST_TIMEOUT", "30000"))
```

Read it back with `Application.fetch_env!/2` / `Application.get_env/3`. Never
hardcode secrets in source or compile-time config.
Reference: <https://hexdocs.pm/elixir/Config.html> · <https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-runtime-configuration>.

## Formatting — `mix format`

Non-negotiable. Rules live in `.formatter.exs`. Run before every commit; wire it
into CI with the check flag.

```bash
mix format                  # format in place
mix format --check-formatted   # CI: fail if anything is unformatted
```

Reference: <https://hexdocs.pm/mix/Mix.Tasks.Format.html>.

## Linting — Credo

Credo enforces consistency and flags refactoring opportunities and code smells.

```bash
mix credo            # full report
mix credo --strict   # stricter; good default for CI
```

Reference: <https://hexdocs.pm/credo/>.

## Logger

Use the built-in `Logger`, not `IO.puts`, for diagnostics. Levels:
`debug`/`info`/`warning`/`error`. Configure level per environment.

```elixir
require Logger
Logger.info("fetched videos", channel: channel_id, count: length(videos))
```

Reference: <https://hexdocs.pm/logger/Logger.html>.

## Releases — `mix release`

A release is a self-contained, runtime-config-aware artifact for deployment
(bundles your app, its deps, and the BEAM). This is how you ship a service.

```bash
MIX_ENV=prod mix release
_build/prod/rel/my_app/bin/my_app start    # or: daemon, stop, remote
```

`config/runtime.exs` is evaluated when the release boots, so the same artifact
runs across environments with different env vars. Reference:
<https://hexdocs.pm/mix/Mix.Tasks.Release.html>.

## Common Mix tasks

```bash
mix compile
mix test
mix run -e "IO.inspect(MyApp.hello())"   # run an expression in app context
iex -S mix                                # REPL with the project loaded
mix help                                  # list all tasks
```
