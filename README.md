# ExCompact

Compact noisy BEAM output (stack traces, test failures, crash reports) before Claude Code sees it. Reduces token usage while preserving the information needed to debug.

## Installation

```bash
mix igniter.install ex_compact
```

This will guide you through:
1. Building the escript
2. Copying hook scripts to `~/.claude/hooks/`
3. Configuring Claude Code settings

## Before & After

**Stack trace** — 12 lines down to 3:

```diff
  ** (RuntimeError) something went wrong
      (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1
      (my_app 0.1.0) lib/my_app/server.ex:10: MyApp.Server.handle_call/3
-     (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
-     (stdlib 5.0) gen_server.erl:1200: :gen_server.handle_msg/6
-     (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
-     (elixir 1.17.0) lib/enum.ex:1: Enum.map/2
-     (elixir 1.17.0) lib/kernel.ex:100: Kernel.apply/3
```

**Test run** — 300+ lines down to just failures:

```diff
- Running ExUnit with seed: 54321, max_cases: 16
-
- ....................................................................
- ....................................................................
- ....................................................................
- .......F.....F.............

    1) test something (MyApp.SomeTest)
       test/my_app/some_test.exs:10
       Assertion with == failed
       left:  1
       right: 2

  300 tests, 2 failures

- Randomized with seed 54321
```

**Postgrex disconnect** — 40 lines down to 1:

```diff
  [error] Postgrex.Protocol (#PID<0.531.0>) disconnected: ** (DBConnection.ConnectionError) owner exited
- Client #PID<0.557.0> (MyApp.Worker) is still using a connection from owner at location:
-     :erlang.port_command/3
-     :prim_inet.send/4
-     (postgrex 0.22.0) lib/postgrex/protocol.ex:3359: Postgrex.Protocol.do_send/3
-     ... 15 more frames ...
- The connection itself was checked out by #PID<0.557.0> at location:
-     (ecto_sql 3.13.5) lib/ecto/adapters/postgres/connection.ex:108: ...
-     ... 10 more frames ...
```

**GenServer crash** — keeps what matters, drops OTP noise:

```diff
  [error] GenServer MyApp.Worker terminating
  ** (RuntimeError) something broke
      (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.handle_info/2
-     (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
-     (stdlib 5.0) gen_server.erl:1200: :gen_server.handle_msg/6
-     (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
  Last message: :tick
- State: %{counter: 42, data: "a very long string that goes on and on and on..."}
+ State: %{counter: 42, data: "a very long stri... (truncated)
```

## What It Does

ExCompact intercepts verbose Elixir/Erlang output and compacts it:

- **Stack traces**: Keeps the exception line + top project-relevant frames, strips OTP/stdlib noise
- **Test failures**: Strips compilation output, progress dots, and seed info
- **GenServer crashes**: Keeps module, exception, project frames, and last message. Truncates large state.
- **Test summaries**: Strips dots and metadata from verbose test runs
- **Compiler warnings**: Compacts multi-line warnings to single-line summaries
- **Task/Supervisor crashes**: Same treatment as GenServer crashes
- **Ecto query logs**: Strips debug-level QUERY OK lines, keeps errors
- **DB disconnects**: Collapses verbose Postgrex disconnection reports to one line

## Usage

Automatic via Claude Code hooks (set up by `mix ex_compact.install`).

Manual:
```bash
echo "some output" | ex_compact compact
```

Daemon mode (faster, stays warm):
```bash
ex_compact daemon start
ex_compact daemon stop
```

## As a Dependency

Add to your project for zero-latency compaction via distributed Erlang:

```elixir
def deps do
  [{:ex_compact, path: "~/projects/ex_compact"}]
end
```

The project node auto-registers on boot. The client connects via `:rpc.call` — no socket overhead.

## License

MIT
