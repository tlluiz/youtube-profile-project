# Testing

ExUnit ships with Elixir — no dependency needed. Reference:
<https://hexdocs.pm/ex_unit/ExUnit.html>.

## Basics

`test/test_helper.exs` starts ExUnit (`ExUnit.start()`). Test files end in
`_test.exs` and live under `test/`. Run with `mix test`.

```elixir
defmodule RankingTest do
  use ExUnit.Case, async: true

  alias MyApp.Ranking

  describe "top/2" do
    test "returns the n most-liked videos, highest first" do
      videos = [
        %{id: "a", like_count: 10},
        %{id: "b", like_count: 99},
        %{id: "c", like_count: 50}
      ]

      assert [%{id: "b"}, %{id: "c"}] = Ranking.top(videos, 2)
    end

    test "n larger than the list returns all" do
      assert Ranking.top([%{id: "a", like_count: 1}], 5) |> length() == 1
    end
  end
end
```

- `async: true` runs the case concurrently with other async cases — use it for
  tests with no shared global state (huge speedup). Omit it when a test touches
  shared resources.
- `describe` groups tests around one function/behavior.
- Prefer pattern-match assertions (`assert {:ok, v} = ...`) — failures show the
  full structure.

## setup and fixtures

`setup` runs before each test; return `{:ok, context}` (or a map) to inject values.

```elixir
setup do
  {:ok, videos: [%{id: "a", like_count: 1}]}
end

test "uses the fixture", %{videos: videos} do
  assert length(videos) == 1
end
```

Use `setup_all` for expensive one-time setup shared by the whole case.

## Common assertions

```elixir
assert value == expected
refute value
assert_raise ArgumentError, fn -> risky() end
assert_in_delta 0.1 + 0.2, 0.3, 0.0001
assert {:error, :not_found} = lookup("missing")
```

Reference: <https://hexdocs.pm/ex_unit/ExUnit.Assertions.html>.

## Doctests — examples that are also tests

Examples in `@doc` run as tests, keeping docs honest.

```elixir
defmodule MyMath do
  @doc """
  Doubles a number.

      iex> MyMath.double(21)
      42
  """
  @spec double(number()) :: number()
  def double(n), do: n * 2
end
```

```elixir
# in the test file
defmodule MyMathTest do
  use ExUnit.Case, async: true
  doctest MyMath
end
```

Reference: <https://hexdocs.pm/ex_unit/ExUnit.DocTest.html>.

## Mocking — Mox (behaviour-based, the community standard)

Mox mocks **behaviours**, not arbitrary modules — you define a mock that
implements a behaviour and set expectations per test. This keeps mocks honest
(they must match the real callback contract) and concurrency-safe.

Principle: *mock the boundary you own an abstraction for.* Define a behaviour for
the external dependency (e.g. an HTTP/transcription client), inject which
implementation to use via config, and use the real one in prod, the mock in test.

```elixir
# test deps in mix.exs:  {:mox, "~> 1.2", only: :test}

# test/test_helper.exs
Mox.defmock(TranscriberMock, for: Transcriber)
Application.put_env(:my_app, :transcriber, TranscriberMock)
ExUnit.start()
```

```elixir
defmodule ProfilerTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!   # fail the test if expectations weren't met

  test "summarizes a transcript" do
    expect(TranscriberMock, :transcribe, fn _path -> {:ok, "hello world"} end)

    assert {:ok, profile} = MyApp.Profiler.run("/tmp/audio.mp3")
    assert profile.word_count == 2
  end
end
```

The code under test resolves the implementation at runtime, e.g.
`Application.get_env(:my_app, :transcriber, Transcriber.Whisper)`.
Reference: <https://hexdocs.pm/mox/>.

## Property-based testing — StreamData

Generate many inputs to assert invariants instead of hand-picking cases. Good for
pure transformations (parsers, ranking, encoders).

```elixir
# test deps:  {:stream_data, "~> 1.1", only: :test}

defmodule RankingPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "top/2 never returns more than n items" do
    check all(
            videos <-
              list_of(fixed_map(%{id: string(:alphanumeric), like_count: positive_integer()})),
            n <- positive_integer()
          ) do
      assert length(MyApp.Ranking.top(videos, n)) <= n
    end
  end
end
```

Reference: <https://hexdocs.pm/stream_data/>.

## Guidance

- Default to `async: true`; reserve sync tests for shared-state cases.
- Test pure functions directly; test processes through their public API.
- Mock only at owned behaviour boundaries — don't mock the language or stdlib.
- Tag slow/integration tests (`@tag :integration`) and exclude them by default in
  `test_helper.exs` (`ExUnit.configure(exclude: [:integration])`).
