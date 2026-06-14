# Language core

Idiomatic Elixir building blocks. Examples are formatted with `mix format`.
Reference: <https://hexdocs.pm/elixir/>.

## Pattern matching is the control flow

`=` is a match, not assignment. Prefer matching in function heads over conditionals
inside the body.

```elixir
def area({:circle, r}), do: :math.pi() * r * r
def area({:rect, w, h}), do: w * h
```

Bind-and-assert with a match; destructure in one step:

```elixir
%{"id" => id, "items" => items} = payload
[first | _rest] = items
```

The pin operator `^` matches against an existing value instead of rebinding:

```elixir
expected = "ready"
^expected = status  # matches only if status == "ready", else MatchError
```

## Guards

Guards constrain clauses with a restricted, side-effect-free expression set
(see the allowed list: <https://hexdocs.pm/elixir/patterns-and-guards.html>).

```elixir
def classify(n) when is_integer(n) and n > 0, do: :positive
def classify(n) when is_integer(n) and n < 0, do: :negative
def classify(0), do: :zero
```

Reusable guards via `defguard`:

```elixir
defguard is_http_ok(status) when is_integer(status) and status in 200..299
```

## The pipe operator

`|>` passes the left value as the **first argument** of the right call. Design
functions to take the "subject" data first so they pipe cleanly.

```elixir
"  Hello, World  "
|> String.trim()
|> String.downcase()
|> String.split(", ")
# => ["hello", "world"]
```

Don't pipe into anonymous functions or start a pipe with a raw literal call;
keep each step a named function call for readability.

## `with` — happy-path chaining of `{:ok, _}` / `{:error, _}`

`with` threads a sequence of pattern matches; the first non-match short-circuits
and returns that value (or is handled in `else`). This is the idiomatic way to
sequence fallible steps without nested `case`.

```elixir
def load_profile(raw) do
  with {:ok, json} <- decode(raw),
       {:ok, user} <- fetch_user(json),
       {:ok, prefs} <- fetch_prefs(user) do
    {:ok, %{user: user, prefs: prefs}}
  else
    {:error, :not_found} -> {:error, :user_missing}
    {:error, reason} -> {:error, reason}
  end
end
```

Reference: <https://hexdocs.pm/elixir/Kernel.SpecialForms.html#with/1>.

## `case`, `cond`, `if`

- `case` — match one value against patterns (with optional guards).
- `cond` — first truthy condition wins (a chain of unrelated booleans).
- `if`/`unless` — a single boolean branch; for anything richer use `case`/`cond`.

```elixir
case Integer.parse(input) do
  {n, ""} -> {:ok, n}
  {_n, _rest} -> {:error, :trailing_chars}
  :error -> {:error, :not_a_number}
end
```

Only `nil` and `false` are falsy; everything else (including `0` and `""`) is truthy.

## Structs

A struct is a tagged map with a fixed set of keys, defined on top of a module.
Enforce required keys with `@enforce_keys`.

```elixir
defmodule Video do
  @enforce_keys [:id, :title]
  defstruct [:id, :title, view_count: 0, like_count: 0]
end

video = %Video{id: "abc123", title: "Intro"}
%Video{video | like_count: 42}  # update, returns a new struct
```

Pattern match on the struct type to assert shape: `def rank(%Video{} = v), do: ...`.

## Protocols — polymorphism over data shapes

Define behavior dispatched on the data type. Prefer protocols over giant `case`
statements when many types need the same operation.

```elixir
defprotocol Summary do
  @doc "A one-line human summary of the value."
  @spec describe(t) :: String.t()
  def describe(value)
end

defimpl Summary, for: Video do
  def describe(%Video{title: t, like_count: l}), do: "#{t} (#{l} likes)"
end
```

Built-in protocols you'll implement often: `String.Chars` (`to_string/1`),
`Inspect` (debug output), `Enumerable`, `Collectable`.
Reference: <https://hexdocs.pm/elixir/Protocol.html>.

## Behaviours — pluggable module contracts

A behaviour declares a set of callbacks a module must implement. Use it for
swappable implementations (and to enable mocking — see testing.md).

```elixir
defmodule Transcriber do
  @callback transcribe(audio_path :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
end

defmodule Transcriber.Whisper do
  @behaviour Transcriber
  @impl true
  def transcribe(path), do: {:ok, "..."}
end
```

`@impl true` makes the compiler verify the callback signature — always use it.

## Comprehensions

`for` filters, maps, and can build maps/other collectables via `:into`.

```elixir
for v <- videos, v.like_count > 100, do: v.id

for v <- videos, into: %{}, do: {v.id, v.like_count}
```

## Error handling: tuples vs. exceptions

Default to tagged tuples. Use the trailing-`!` convention for a raising twin.

```elixir
def fetch(id) do
  case lookup(id) do
    nil -> {:error, :not_found}
    val -> {:ok, val}
  end
end

def fetch!(id) do
  case fetch(id) do
    {:ok, val} -> val
    {:error, reason} -> raise "fetch failed: #{inspect(reason)}"
  end
end
```

`raise`/`rescue` exist, but rescuing should be rare and specific. In processes,
prefer letting it crash and supervising (see otp-and-concurrency.md). Reserve
`try/rescue` for boundaries with libraries that raise, or genuinely exceptional
states. Reference: <https://hexdocs.pm/elixir/try-catch-and-rescue.html>.

## Enum vs. Stream

`Enum` is eager (computes immediately). `Stream` is lazy (composes, runs once at
the end) — use it for large or infinite sequences to avoid building intermediate
lists.

```elixir
1..1_000_000
|> Stream.map(&(&1 * 2))
|> Stream.filter(&(rem(&1, 3) == 0))
|> Enum.take(5)
```

Reference: <https://hexdocs.pm/elixir/Enum.html> · <https://hexdocs.pm/elixir/Stream.html>.
