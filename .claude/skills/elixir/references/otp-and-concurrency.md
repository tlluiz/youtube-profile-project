# OTP & concurrency

Processes are the unit of concurrency, state, and fault isolation. Build on the
OTP abstractions (`GenServer`, `Supervisor`, `Task`, `Registry`) rather than raw
`spawn`/`send`/`receive` unless you have a specific reason.
Reference: <https://hexdocs.pm/elixir/processes.html> · <https://www.erlang.org/doc/design_principles/des_princ.html>.

## Mental model

- Each process has isolated memory; they communicate only by message passing.
- State lives *inside* a process; you change it by sending the process a message.
- A crash kills one process and its linked tree, not the whole system — a
  supervisor restarts it to a known-good state ("let it crash").

## GenServer — a process that holds state and answers calls

`call` is synchronous (waits for a reply); `cast` is fire-and-forget. Keep
callbacks fast; do slow work in a `Task` or handle it asynchronously.

```elixir
defmodule Counter do
  use GenServer

  # --- Client API (runs in the caller) ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:start] || 0, name: opts[:name] || __MODULE__)
  end

  @spec increment(GenServer.server()) :: :ok
  def increment(server \\ __MODULE__), do: GenServer.cast(server, :increment)

  @spec value(GenServer.server()) :: integer()
  def value(server \\ __MODULE__), do: GenServer.call(server, :value)

  # --- Server callbacks (run in the GenServer process) ---

  @impl true
  def init(start), do: {:ok, start}

  @impl true
  def handle_cast(:increment, count), do: {:noreply, count + 1}

  @impl true
  def handle_call(:value, _from, count), do: {:reply, count, count}
end
```

Split **client API** (thin functions callers use) from **server callbacks** (the
logic running in the process). Reference: <https://hexdocs.pm/elixir/GenServer.html>.

## Supervisors and supervision trees

A supervisor starts children and restarts them per a strategy when they crash.
This is the backbone of an OTP application.

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: MyApp.Registry},
      {Counter, name: Counter},
      {Task.Supervisor, name: MyApp.TaskSupervisor},
      MyApp.Worker
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

Restart strategies:

- `:one_for_one` — restart only the crashed child (default, most common).
- `:one_for_all` — restart all children if one dies (use when they're interdependent).
- `:rest_for_one` — restart the crashed child and those started after it.

Each child is a **child spec**; the `{Module, arg}` tuple is shorthand that calls
`Module.child_spec(arg)`. Reference: <https://hexdocs.pm/elixir/Supervisor.html>.

## DynamicSupervisor — children started at runtime

Use when you don't know the children up front (e.g. one worker per active job).

```elixir
# In the supervision tree:
{DynamicSupervisor, strategy: :one_for_one, name: MyApp.JobSupervisor}

# Start a child on demand:
DynamicSupervisor.start_child(MyApp.JobSupervisor, {JobWorker, job_id: id})
```

Reference: <https://hexdocs.pm/elixir/DynamicSupervisor.html>.

## Registry — name and discover processes

Map keys to processes (e.g. look up the worker for a given video id) without
hardcoding PIDs. Use `:via` tuples so a process registers itself by a logical key.

```elixir
def start_link(id) do
  GenServer.start_link(__MODULE__, id, name: {:via, Registry, {MyApp.Registry, id}})
end

def whereis(id) do
  case Registry.lookup(MyApp.Registry, id) do
    [{pid, _}] -> {:ok, pid}
    [] -> {:error, :not_found}
  end
end
```

Reference: <https://hexdocs.pm/elixir/Registry.html>.

## Task — concurrent and async work

`Task.async/await` for a single concurrent computation; `Task.async_stream/3` for
bounded parallelism over a collection (ideal for fanning out HTTP calls — e.g.
fetching metadata for many videos at once).

```elixir
# Bounded-concurrency fan-out; preserves order, caps simultaneous work.
videos
|> Task.async_stream(&fetch_metadata/1, max_concurrency: 8, timeout: 30_000)
|> Enum.map(fn {:ok, result} -> result end)
```

Supervise tasks that run independently of a caller via a `Task.Supervisor`
(started in the tree above):

```elixir
Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn -> do_work() end)
```

Reference: <https://hexdocs.pm/elixir/Task.html>.

## Other state holders

- `Agent` — a tiny process wrapping a single piece of state (simpler than a
  GenServer when you only need get/update). <https://hexdocs.pm/elixir/Agent.html>
- `:ets` — in-memory term storage for shared, high-read caches.
  <https://www.erlang.org/doc/man/ets.html>

## Guidance

- Don't reach for processes to organize code — reach for them for **state,
  concurrency, or fault isolation**. Pure logic belongs in plain modules.
- Keep GenServer callbacks quick; never block the loop on a long HTTP call —
  delegate to a Task.
- Always give long-lived processes a place in a supervision tree; don't `spawn`
  orphans.
