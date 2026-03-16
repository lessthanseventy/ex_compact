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

## What It Does

ExCompact intercepts verbose Elixir/Erlang output and compacts it:

- **Stack traces**: Keeps the exception line + top project-relevant frames, strips OTP/stdlib noise
- **Test failures**: Strips compilation output, progress dots, and seed info
- **GenServer crashes**: Keeps module, exception, project frames, and last message. Truncates large state.
- **Test summaries**: Strips dots and metadata from verbose test runs
- **Compiler warnings**: Compacts multi-line warnings to single-line summaries
- **Task/Supervisor crashes**: Same treatment as GenServer crashes
- **Ecto query logs**: Strips debug-level QUERY OK lines, keeps errors

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
