# Types & specs

Two complementary systems: **typespecs + Dialyzer** (mature, success-typing) and
the **set-theoretic type system** built into the compiler (newer, expanding each
release). Use both.

## Typespecs (`@type`, `@spec`)

Annotate public functions with `@spec` and name domain types with `@type`. These
document intent, drive Dialyzer, and render in HexDocs.

```elixir
defmodule Ranking do
  @type video :: %{id: String.t(), like_count: non_neg_integer()}
  @type t :: [video()]

  @spec top(t(), pos_integer()) :: t()
  def top(videos, n) when is_integer(n) and n > 0 do
    videos
    |> Enum.sort_by(& &1.like_count, :desc)
    |> Enum.take(n)
  end
end
```

Common built-in types: `term()` (any), `String.t()` (a binary string),
`non_neg_integer()`, `pos_integer()`, `keyword()`, `map()`, `{:ok, t} | {:error, term()}`.
Full list: <https://hexdocs.pm/elixir/typespecs.html>.

- `@type` — public, shows in docs. `@typep` — private. `@opaque` — exported by
  name but its structure is hidden from callers.
- Spec the public surface; internal helpers are optional.

## Dialyzer (static analysis via success typing)

Dialyzer finds type contradictions, impossible guards, and unreachable clauses.
It never reports a false error — it only flags things that *cannot* succeed. Run
it through **Dialyxir** (the standard Mix wrapper).

```elixir
# mix.exs deps
{:dialyxir, "~> 1.4", only: [:dev], runtime: false}
```

```bash
mix dialyzer   # first run builds a PLT cache (slow once, fast after)
```

Reference: <https://hexdocs.pm/dialyxir/> · <https://www.erlang.org/doc/man/dialyzer.html>.

## The set-theoretic type system (built into the compiler)

Elixir is gradually gaining a **sound gradual set-theoretic type system**, shipped
incrementally with each release. It already runs during normal `mix compile` — no
extra tool — and infers types for patterns, guards, and many function heads,
reporting violations as compiler warnings.

What this means in practice on this toolchain (Elixir 1.20):

- You get type warnings for free at compile time for things like obviously
  mismatched pattern matches and field access on the wrong struct.
- Coverage is **expanding but not complete** — it does not yet type the entire
  language, and is not a replacement for `@spec`/Dialyzer. Treat it as an
  additional, evolving safety net.
- Because it's evolving, don't rely on it to catch everything, and don't assume a
  given construct is typed yet. Verify behavior against the official guide for the
  installed version rather than from memory.

Authoritative, version-tracking references (read these for what's covered *now*):

- Gradual set-theoretic types guide — <https://hexdocs.pm/elixir/gradual-set-theoretic-types.html>
- Elixir release notes (each minor release lists new type-system coverage) —
  <https://github.com/elixir-lang/elixir/releases>

## Practical guidance

- Add `@spec` to public functions regardless of the type system — it's
  documentation and Dialyzer fuel, and the two systems reinforce each other.
- Treat compiler type warnings as errors in CI once your codebase is clean.
- Keep functions small and data shapes explicit (structs over loose maps) — both
  type systems reason far better about well-named, well-shaped data.
