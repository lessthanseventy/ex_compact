# ex_compact Design

**Date:** 2026-03-16
**Status:** Approved

## Purpose

Compact noisy BEAM output (stack traces, test failures, crash reports) before Claude Code sees it. Reduces token usage while preserving the information Claude needs to debug.

## Architecture

Three connection strategies, tried in priority order:

1. **Project node** — If a BEAM node is running (e.g., Phoenix dev server) and has ex_compact as a dep, connect via distributed Erlang and call `ExCompact.compact/1`. Zero extra processes.
2. **Daemon** — Standalone GenServer on a Unix socket (`/tmp/ex_compact_<user>.sock`). Started once, stays warm. Near-zero latency.
3. **Inline fallback** — Run the escript directly. ~500ms BEAM boot cost. Always works.

```
┌─────────────────────┐     ┌──────────────────────┐
│ Claude Code Hook    │────▶│ ex_compact CLI       │
│ (shell + jq)        │     │ (thin client)         │
└─────────────────────┘     └──────┬───────────────┘
                                   │
                          ┌────────▼────────────┐
                          │ 1. Project node      │
                          │ 2. Daemon (socket)   │
                          │ 3. Inline fallback   │
                          └─────────────────────┘
```

Hook shell scripts handle the Claude Code JSON envelope (jq to extract input, jq to re-wrap output). ex_compact only sees raw text.

## Compaction Patterns

### 1. Elixir/Erlang Stack Traces

Detects `** (ExceptionType)` followed by indented stack frames.

Compacts to: exception line + top N project-relevant frames.

### 2. Mix Test Failures

Detects numbered test failure blocks from `mix test`.

Compacts to: test name, file:line, assertion type, left/right values. Strips compilation output, passing test dots, seed info.

### 3. GenServer Crash Reports

Detects `[error] GenServer ... terminating` blocks.

Compacts to: GenServer module, exception, project-relevant frames, last message. Truncates large state.

### 4. Mix Test Summary

When a full test run produces verbose output with multiple failures.

Compacts to: just the failures with their locations.

### Frame Scoring

- **+100**: Frame from project code (matches project app name)
- **+10**: Frame from a direct dep (not stdlib/OTP)
- **-5 per position**: Penalty for frames far from the error
- Default **max 4 frames** kept per trace

## Connection Layer

### Unix Socket Daemon

```
ex_compact daemon start   # backgrounded, writes PID file
ex_compact daemon stop    # cleanup
```

Socket at `/tmp/ex_compact_<user>.sock`. Length-prefixed binary protocol: `<<size::32, payload::binary>>`.

### Project Node Connection

Projects with ex_compact as a dep auto-register on boot. Node name + project root written to `~/.ex_compact/nodes.json`. CLI client checks registry for a node matching cwd.

### Hook Scripts

Shell scripts that handle Claude Code JSON via jq, pipe raw text to ex_compact client:

- `PostToolUse` (matched to Bash) — compacts tool output
- `UserPromptSubmit` — compacts pasted traces in user prompts

## Project Structure

```
ex_compact/
├── lib/
│   ├── ex_compact.ex                  # Public API: compact/2
│   ├── ex_compact/
│   │   ├── application.ex             # Supervision tree
│   │   ├── daemon.ex                  # Unix socket GenServer
│   │   ├── cli.ex                     # Escript entrypoint
│   │   ├── client.ex                  # Connection strategy (node → daemon → inline)
│   │   ├── registry.ex                # Node registry (~/.ex_compact/nodes.json)
│   │   ├── compactor.ex               # Orchestrates pattern matching
│   │   └── patterns/
│   │       ├── stack_trace.ex         # ** (Exception) + frames
│   │       ├── test_failure.ex        # mix test assertion failures
│   │       ├── genserver_crash.ex     # GenServer terminating reports
│   │       └── test_summary.ex        # Full test run → failures only
│   └── mix/
│       └── tasks/
│           └── ex_compact.install.ex  # Igniter installer task
├── hooks/
│   ├── post_tool_use.sh               # PostToolUse hook (Bash matcher)
│   └── user_prompt_submit.sh          # UserPromptSubmit hook
├── test/
├── mix.exs
└── README.md
```

## Installation

Uses Igniter for installation. `mix igniter.install ex_compact` will:

1. Build the escript
2. Copy hook scripts to `~/.claude/hooks/`
3. Merge hook config into `~/.claude/settings.json`
4. Start the daemon

For project node connection, add `{:ex_compact, path: "~/projects/ex_compact"}` to project deps. Auto-registers on boot via Application callback.

## Modern Practices

- **Igniter** for installer task (`lib/mix/tasks/ex_compact.install.ex` uses `Igniter.Mix.Task`)
- **usage-rules.md** at project root — documents public API for AI-assisted dev, distributed with hex package
- **usage_rules** integration — projects depending on ex_compact get compactor context in their AGENTS.md automatically
