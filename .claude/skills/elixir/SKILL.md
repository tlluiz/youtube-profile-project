---
name: elixir
description: >-
  Write idiomatic, modern Elixir (OTP applications and long-running services).
  Use when creating, editing, reviewing, or debugging Elixir/Mix code — language
  core, typespecs and the set-theoretic type system, OTP/GenServer/supervision,
  Mix tooling and releases, ExUnit testing, and HTTP/JSON clients. Targets the
  Elixir/OTP versions installed on this machine.
---

# Idiomatic Modern Elixir (OTP for building services)

This Skill makes you fluent in **modern, idiomatic Elixir** for building
**OTP applications and long-running services** — the kind of code this project's
MCP servers are made of (fetch external APIs, process data through supervised
processes, expose a stable interface).

Prefer the **standard library** and **widely-adopted, actively-maintained Hex
packages**. Write small, correct, runnable examples that pass `mix format`. Do
not use deprecated APIs or unverified workarounds. When a recommendation is
non-obvious, it carries a link to the authoritative source.

## Toolchain on this machine (detected, not assumed)

These were detected with `elixir --version` / `mix --version` on this machine and
are what the examples in this Skill target:

| Tool       | Version           |
| ---------- | ----------------- |
| Elixir     | **1.20.1**        |
| Mix        | **1.20.1**        |
| Erlang/OTP | **29** (erts 17.0.2, JIT) |

Managed via **asdf** — pinned in the project's `.tool-versions`
(`erlang 29.0.2`, `elixir 1.20.1-otp-29`). `crypto` + `ssl` are available, so
outbound HTTPS works. Before relying on a version-specific feature, re-check with
`elixir --version`; if the machine differs from the table above, prefer what is
actually installed and say so.

## How to use this Skill

`SKILL.md` is the map. Load the reference file for the task at hand — each is
self-contained and example-driven:

| When you're… | Read |
| --- | --- |
| Writing core logic (pattern matching, structs, protocols, `with`, error handling) | [references/language-core.md](references/language-core.md) |
| Adding `@spec`/`@type`, running Dialyzer, or using the set-theoretic type system | [references/types-and-specs.md](references/types-and-specs.md) |
| Building processes, `GenServer`s, supervision trees, `Registry`, `Task` | [references/otp-and-concurrency.md](references/otp-and-concurrency.md) |
| Scaffolding a project, managing deps, config, formatting, linting, releases | [references/project-and-tooling.md](references/project-and-tooling.md) |
| Writing tests (ExUnit, async, Mox, doctests, property-based) | [references/testing.md](references/testing.md) |
| Calling HTTP APIs and handling JSON | [references/http-and-json.md](references/http-and-json.md) |

## The non-negotiables (apply to every Elixir change)

1. **Format everything.** Run `mix format` (config in `.formatter.exs`). Formatted
   code is the community baseline — never hand-format.
   <https://hexdocs.pm/mix/Mix.Tasks.Format.html>
2. **Model success and failure explicitly.** Functions that can fail return
   `{:ok, value}` / `{:error, reason}`; a trailing-`!` variant raises. Reserve
   exceptions for truly exceptional conditions, not control flow.
   <https://hexdocs.pm/elixir/Kernel.html>
3. **Let it crash — under a supervisor.** Don't defensively rescue everything;
   isolate state in processes and let a supervisor restart them. Design the
   supervision tree deliberately. <https://hexdocs.pm/elixir/Supervisor.html>
4. **Pure core, effects at the edges.** Keep transformation logic pure and
   testable; push I/O (HTTP, files, DB) to the boundary.
5. **Prefer stdlib and the de-facto default lib.** Reach for a dependency only
   when it's the community standard and actively maintained — and say why.
6. **Documented, specced public functions.** `@moduledoc`/`@doc` on public API,
   `@spec` on public functions, doctests where examples clarify behavior.

## Quick start — a new supervised app

```bash
# A supervised OTP application (not a bare library): --sup adds an Application
# callback module and a top-level supervisor.
mix new my_app --sup
cd my_app
mix deps.get
mix format
mix test
```

This produces `lib/my_app/application.ex` (the supervision tree entry point) and
`lib/my_app.ex`. Add child processes to the supervisor's child list, put pure
logic in plain modules, and put external calls behind a small client module. See
[references/otp-and-concurrency.md](references/otp-and-concurrency.md) and
[references/project-and-tooling.md](references/project-and-tooling.md).

## Authoritative sources

Cite and prefer these over blog posts:

- Elixir docs & guides — <https://hexdocs.pm/elixir/> · <https://elixir-lang.org/getting-started/introduction.html>
- Mix & ExUnit — <https://hexdocs.pm/mix/> · <https://hexdocs.pm/ex_unit/>
- Erlang/OTP — <https://www.erlang.org/doc/>
- Elixir type system — <https://hexdocs.pm/elixir/gradual-set-theoretic-types.html>
- A package's own HexDocs page (e.g. <https://hexdocs.pm/req/>) for that package.
