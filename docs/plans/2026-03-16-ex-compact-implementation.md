# ex_compact Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Build an Elixir tool that compacts noisy BEAM output (stack traces, test failures, crash reports) before Claude Code sees it, reducing token usage while preserving debugging information.

**Architecture:** Three-tier connection strategy (project node → daemon → inline fallback) with pattern-based text compaction. Ships as a hex package with an Igniter installer that wires up Claude Code hooks automatically.

**Tech Stack:** Elixir, OTP (:gen_tcp for Unix sockets, distributed Erlang for node connection), Igniter (installer), usage_rules (AI dev rules propagation), escript (CLI).

---

### Task 0: Project Scaffold

**Files:**
- Create: `mix.exs`
- Create: `lib/ex_compact.ex`
- Create: `.formatter.exs`
- Create: `.gitignore`

**Step 1: Initialize the project**

```bash
mix new ex_compact --sup
cd ex_compact
```

**Step 2: Configure mix.exs with deps and escript**

Replace `mix.exs` with:

```elixir
defmodule ExCompact.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ex_compact,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: ExCompact.CLI],
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExCompact.Application, []}
    ]
  end

  defp deps do
    [
      {:igniter, "~> 0.7", only: [:dev]},
      {:usage_rules, "~> 1.1", only: [:dev]},
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      description: "Compact noisy BEAM output for Claude Code",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/youruser/ex_compact"},
      files: ~w(lib hooks mix.exs README.md LICENSE usage-rules.md usage-rules)
    ]
  end
end
```

**Step 3: Create the public API module stub**

`lib/ex_compact.ex`:
```elixir
defmodule ExCompact do
  @moduledoc """
  Compacts noisy BEAM output (stack traces, test failures, crash reports).
  """

  @doc """
  Compact the given text by applying all registered patterns.

  Options:
    - `:max_frames` - max stack frames to keep per trace (default: 4)
    - `:app` - project app name for frame scoring (auto-detected if nil)
  """
  def compact(text, opts \\ []) do
    ExCompact.Compactor.compact(text, opts)
  end
end
```

**Step 4: Fetch deps and verify it compiles**

```bash
mix deps.get
mix compile
```

**Step 5: Commit**

```bash
git init
git add -A
git commit -m "feat: scaffold ex_compact project with deps"
```

---

### Task 1: Compactor Orchestrator

**Files:**
- Create: `lib/ex_compact/compactor.ex`
- Create: `test/ex_compact/compactor_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/compactor_test.exs`:
```elixir
defmodule ExCompact.CompactorTest do
  use ExUnit.Case, async: true

  test "passes through text with no recognizable patterns" do
    input = "Hello, this is normal output.\nNothing to compact here."
    assert ExCompact.Compactor.compact(input) == input
  end

  test "applies matching patterns and leaves non-matching text intact" do
    # This test will become meaningful once we add patterns.
    # For now it verifies the pipeline runs without error.
    input = "some output\nmore output"
    result = ExCompact.Compactor.compact(input)
    assert is_binary(result)
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/compactor_test.exs
```
Expected: FAIL — `ExCompact.Compactor` not defined.

**Step 3: Write the compactor module**

`lib/ex_compact/compactor.ex`:
```elixir
defmodule ExCompact.Compactor do
  @moduledoc false

  @patterns [
    ExCompact.Patterns.StackTrace,
    ExCompact.Patterns.TestFailure,
    ExCompact.Patterns.GenServerCrash,
    ExCompact.Patterns.TestSummary
  ]

  @doc """
  Run all compaction patterns against the input text.
  Each pattern scans for its block type and replaces matches with compacted versions.
  """
  def compact(text, opts \\ []) do
    Enum.reduce(@patterns, text, fn pattern, acc ->
      pattern.compact(acc, opts)
    rescue
      _ -> acc
    end)
  end
end
```

**Step 4: Create pattern behaviour and stubs**

`lib/ex_compact/patterns/pattern.ex`:
```elixir
defmodule ExCompact.Patterns.Pattern do
  @moduledoc false
  @callback compact(text :: String.t(), opts :: keyword()) :: String.t()
end
```

Create stub modules that pass through text (one file each):

`lib/ex_compact/patterns/stack_trace.ex`:
```elixir
defmodule ExCompact.Patterns.StackTrace do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts), do: text
end
```

`lib/ex_compact/patterns/test_failure.ex`:
```elixir
defmodule ExCompact.Patterns.TestFailure do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts), do: text
end
```

`lib/ex_compact/patterns/genserver_crash.ex`:
```elixir
defmodule ExCompact.Patterns.GenServerCrash do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts), do: text
end
```

`lib/ex_compact/patterns/test_summary.ex`:
```elixir
defmodule ExCompact.Patterns.TestSummary do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts), do: text
end
```

**Step 5: Run tests and verify they pass**

```bash
mix test test/ex_compact/compactor_test.exs
```
Expected: PASS

**Step 6: Commit**

```bash
git add lib/ex_compact/compactor.ex lib/ex_compact/patterns/ test/ex_compact/compactor_test.exs
git commit -m "feat: add compactor orchestrator with pattern behaviour stubs"
```

---

### Task 2: Frame Scoring

**Files:**
- Create: `lib/ex_compact/frame_scorer.ex`
- Create: `test/ex_compact/frame_scorer_test.exs`

Frame scoring is shared across stack trace and crash report patterns, so build it first.

**Step 1: Write the failing test**

`test/ex_compact/frame_scorer_test.exs`:
```elixir
defmodule ExCompact.FrameScorerTest do
  use ExUnit.Case, async: true

  alias ExCompact.FrameScorer

  @app_name :my_app

  test "project frames score highest" do
    frame = "    (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1"
    assert FrameScorer.score(frame, @app_name, 0) >= 100
  end

  test "OTP/stdlib frames score low" do
    frame = "    (stdlib 5.0) gen_server.erl:1234: :gen_server.handle_msg/6"
    assert FrameScorer.score(frame, @app_name, 0) <= 0
  end

  test "dependency frames score medium" do
    frame = "    (phoenix 1.7.0) lib/phoenix/endpoint.ex:10: Phoenix.Endpoint.call/2"
    score = FrameScorer.score(frame, @app_name, 0)
    assert score > 0 and score < 100
  end

  test "position penalty reduces score for distant frames" do
    frame = "    (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1"
    score_0 = FrameScorer.score(frame, @app_name, 0)
    score_5 = FrameScorer.score(frame, @app_name, 5)
    assert score_0 > score_5
  end

  test "select_top_frames keeps at most max_frames" do
    frames = for i <- 1..10 do
      "    (my_app 0.1.0) lib/my_app/mod#{i}.ex:#{i}: MyApp.Mod#{i}.f/0"
    end
    result = FrameScorer.select_top_frames(frames, @app_name, max_frames: 4)
    assert length(result) == 4
  end

  test "select_top_frames prefers project frames over OTP" do
    frames = [
      "    (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6",
      "    (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1",
      "    (elixir 1.17.0) lib/enum.ex:1: Enum.map/2"
    ]
    result = FrameScorer.select_top_frames(frames, @app_name, max_frames: 1)
    assert length(result) == 1
    assert hd(result) =~ "my_app"
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/frame_scorer_test.exs
```

**Step 3: Implement frame scorer**

`lib/ex_compact/frame_scorer.ex`:
```elixir
defmodule ExCompact.FrameScorer do
  @moduledoc false

  @otp_apps ~w(stdlib kernel elixir logger compiler crypto ssl inets)

  @doc "Score a single stack frame."
  def score(frame, app_name, position) do
    base =
      cond do
        frame_from_app?(frame, app_name) -> 100
        frame_from_otp?(frame) -> -10
        true -> 10  # dependency
      end

    base - 5 * position
  end

  @doc "Select the top N frames by score."
  def select_top_frames(frames, app_name, opts \\ []) do
    max = Keyword.get(opts, :max_frames, 4)

    frames
    |> Enum.with_index()
    |> Enum.map(fn {frame, idx} -> {frame, score(frame, app_name, idx)} end)
    |> Enum.sort_by(fn {_frame, score} -> -score end)
    |> Enum.take(max)
    |> Enum.sort_by(fn {_frame, _score} ->
      # Restore original order among selected frames
      Enum.find_index(frames, &(&1 == elem({_frame, _score}, 0)))
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp frame_from_app?(frame, app_name) do
    frame =~ "(#{app_name} "
  end

  defp frame_from_otp?(frame) do
    Enum.any?(@otp_apps, fn otp -> frame =~ "(#{otp} " end)
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/frame_scorer_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/frame_scorer.ex test/ex_compact/frame_scorer_test.exs
git commit -m "feat: add frame scorer for stack trace compaction"
```

---

### Task 3: Stack Trace Pattern

**Files:**
- Modify: `lib/ex_compact/patterns/stack_trace.ex`
- Create: `test/ex_compact/patterns/stack_trace_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/patterns/stack_trace_test.exs`:
```elixir
defmodule ExCompact.Patterns.StackTraceTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.StackTrace

  @sample_trace """
  ** (RuntimeError) something went wrong
      (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1
      (my_app 0.1.0) lib/my_app/server.ex:10: MyApp.Server.handle_call/3
      (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
      (stdlib 5.0) gen_server.erl:1200: :gen_server.handle_msg/6
      (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
      (elixir 1.17.0) lib/enum.ex:1: Enum.map/2
      (elixir 1.17.0) lib/kernel.ex:100: Kernel.apply/3
  """

  test "compacts a stack trace to exception + top project frames" do
    result = StackTrace.compact(@sample_trace, app: :my_app, max_frames: 4)
    # Exception line preserved
    assert result =~ "** (RuntimeError) something went wrong"
    # Project frames kept
    assert result =~ "MyApp.Worker.run/1"
    assert result =~ "MyApp.Server.handle_call/3"
    # OTP noise removed
    refute result =~ ":gen_server.try_dispatch/4"
    refute result =~ ":proc_lib.init_p_do_apply/3"
  end

  test "passes through text with no stack traces" do
    input = "Just normal output\nnothing special"
    assert StackTrace.compact(input, []) == input
  end

  test "handles multiple stack traces in one text" do
    input = """
    Some output before
    ** (ArgumentError) bad arg
        (my_app 0.1.0) lib/my_app/a.ex:1: MyApp.A.f/0
        (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6
    Some middle text
    ** (KeyError) key :foo not found
        (my_app 0.1.0) lib/my_app/b.ex:2: MyApp.B.g/1
        (stdlib 5.0) gen_server.erl:200: :gen_server.handle_msg/6
    Some output after
    """
    result = StackTrace.compact(input, app: :my_app)
    assert result =~ "** (ArgumentError)"
    assert result =~ "** (KeyError)"
    assert result =~ "MyApp.A.f/0"
    assert result =~ "MyApp.B.g/1"
    refute result =~ ":gen_server.handle_msg/6"
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/patterns/stack_trace_test.exs
```

**Step 3: Implement stack trace pattern**

Replace `lib/ex_compact/patterns/stack_trace.ex`:
```elixir
defmodule ExCompact.Patterns.StackTrace do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  alias ExCompact.FrameScorer

  # Matches "** (ExceptionType) message" followed by indented stack frames
  @trace_regex ~r/(\*\* \([A-Za-z\.]+Error|Exception|ArgumentError|KeyError|FunctionClauseError|RuntimeError|MatchError|CaseClauseError|BadArityError|UndefinedFunctionError\b[^)]*\)[^\n]*)\n((?:[ \t]+\(.*\n?)+)/

  @impl true
  def compact(text, opts) do
    app = Keyword.get(opts, :app) |> detect_app()
    max_frames = Keyword.get(opts, :max_frames, 4)

    Regex.replace(@trace_regex, text, fn _full, exception_line, frames_block ->
      frames = String.split(frames_block, "\n", trim: true)
      selected = FrameScorer.select_top_frames(frames, app, max_frames: max_frames)
      compacted_frames = Enum.join(selected, "\n")
      "#{exception_line}\n#{compacted_frames}\n"
    end)
  end

  defp detect_app(nil) do
    case Mix.Project.config()[:app] do
      nil -> :unknown
      app -> app
    end
  rescue
    _ -> :unknown
  end

  defp detect_app(app), do: app
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/patterns/stack_trace_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/patterns/stack_trace.ex test/ex_compact/patterns/stack_trace_test.exs
git commit -m "feat: implement stack trace compaction pattern"
```

---

### Task 4: Test Failure Pattern

**Files:**
- Modify: `lib/ex_compact/patterns/test_failure.ex`
- Create: `test/ex_compact/patterns/test_failure_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/patterns/test_failure_test.exs`:
```elixir
defmodule ExCompact.Patterns.TestFailureTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.TestFailure

  @sample_failure """
  Compiling 3 files (.ex)

  ..........

    1) test creates a user (MyApp.AccountsTest)
       test/my_app/accounts_test.exs:10
       Assertion with == failed
       code:  assert result == {:ok, %User{}}
       left:  {:error, %Ecto.Changeset{}}
       right: {:ok, %User{}}
       stacktrace:
         test/my_app/accounts_test.exs:15: (test)

    2) test updates a user (MyApp.AccountsTest)
       test/my_app/accounts_test.exs:20
       ** (MatchError) no match of right hand side value: {:error, :not_found}
       stacktrace:
         test/my_app/accounts_test.exs:25: (test)

  Finished in 0.3 seconds (0.1s async, 0.2s sync)
  50 tests, 2 failures

  Randomized with seed 12345
  """

  test "compacts test failures to essentials" do
    result = TestFailure.compact(@sample_failure, [])
    # Keeps failure info
    assert result =~ "test creates a user"
    assert result =~ "accounts_test.exs:10"
    assert result =~ "left:"
    assert result =~ "right:"
    # Strips compilation output
    refute result =~ "Compiling 3 files"
    # Strips dots
    refute result =~ ".........."
    # Strips seed
    refute result =~ "Randomized with seed"
  end

  test "passes through text with no test failures" do
    input = "Normal output here"
    assert TestFailure.compact(input, []) == input
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/patterns/test_failure_test.exs
```

**Step 3: Implement test failure pattern**

Replace `lib/ex_compact/patterns/test_failure.ex`:
```elixir
defmodule ExCompact.Patterns.TestFailure do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts) do
    if text =~ ~r/\d+ tests?, \d+ failures?/ do
      text
      |> remove_compilation_output()
      |> remove_test_dots()
      |> remove_seed_line()
      |> remove_finished_line()
      |> String.trim()
      |> Kernel.<>("\n")
    else
      text
    end
  end

  defp remove_compilation_output(text) do
    # Remove "Compiling N files (.ex)" and similar
    Regex.replace(~r/^Compiling \d+ files? \(\.ex\)\n*/m, text, "")
  end

  defp remove_test_dots(text) do
    # Remove lines that are only dots (test progress)
    Regex.replace(~r/^[\.]+\n*/m, text, "")
  end

  defp remove_seed_line(text) do
    Regex.replace(~r/^\n*Randomized with seed \d+\n*/m, text, "")
  end

  defp remove_finished_line(text) do
    # Keep the summary line "N tests, N failures" but remove "Finished in..."
    Regex.replace(~r/^Finished in .*\n/m, text, "")
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/patterns/test_failure_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/patterns/test_failure.ex test/ex_compact/patterns/test_failure_test.exs
git commit -m "feat: implement test failure compaction pattern"
```

---

### Task 5: GenServer Crash Report Pattern

**Files:**
- Modify: `lib/ex_compact/patterns/genserver_crash.ex`
- Create: `test/ex_compact/patterns/genserver_crash_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/patterns/genserver_crash_test.exs`:
```elixir
defmodule ExCompact.Patterns.GenServerCrashTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.GenServerCrash

  @sample_crash """
  [error] GenServer MyApp.Worker terminating
  ** (RuntimeError) something broke
      (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.handle_info/2
      (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
      (stdlib 5.0) gen_server.erl:1200: :gen_server.handle_msg/6
      (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
  Last message: :tick
  State: %{counter: 42, data: "a]very long string that goes on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on"}
  """

  test "compacts GenServer crash to module + exception + project frames + last message" do
    result = GenServerCrash.compact(@sample_crash, app: :my_app, max_frames: 2)
    assert result =~ "GenServer MyApp.Worker terminating"
    assert result =~ "RuntimeError"
    assert result =~ "MyApp.Worker.handle_info/2"
    assert result =~ "Last message: :tick"
    # OTP frames removed
    refute result =~ ":gen_server.try_dispatch/4"
    refute result =~ ":proc_lib.init_p_do_apply/3"
  end

  test "truncates large state" do
    result = GenServerCrash.compact(@sample_crash, app: :my_app)
    # State should be truncated, not the full long string
    if result =~ "State:" do
      state_line = result |> String.split("\n") |> Enum.find(&(&1 =~ "State:"))
      assert String.length(state_line) < 200
    end
  end

  test "passes through text with no crash reports" do
    input = "Normal log output"
    assert GenServerCrash.compact(input, []) == input
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/patterns/genserver_crash_test.exs
```

**Step 3: Implement GenServer crash pattern**

Replace `lib/ex_compact/patterns/genserver_crash.ex`:
```elixir
defmodule ExCompact.Patterns.GenServerCrash do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  alias ExCompact.FrameScorer

  @max_state_length 150

  @crash_regex ~r/(\[error\] GenServer \S+ terminating)\n(\*\* \([^)]+\)[^\n]*)\n((?:[ \t]+\(.*\n)+)(Last message: [^\n]*)\n(State: [^\n]*)/

  @impl true
  def compact(text, opts) do
    app = Keyword.get(opts, :app, :unknown)
    max_frames = Keyword.get(opts, :max_frames, 4)

    Regex.replace(@crash_regex, text, fn _full, header, exception, frames_block, last_msg, state ->
      frames = String.split(frames_block, "\n", trim: true)
      selected = FrameScorer.select_top_frames(frames, app, max_frames: max_frames)
      compacted_frames = Enum.join(selected, "\n")
      truncated_state = truncate_state(state)

      "#{header}\n#{exception}\n#{compacted_frames}\n#{last_msg}\n#{truncated_state}"
    end)
  end

  defp truncate_state(state) do
    if String.length(state) > @max_state_length do
      String.slice(state, 0, @max_state_length) <> "... (truncated)"
    else
      state
    end
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/patterns/genserver_crash_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/patterns/genserver_crash.ex test/ex_compact/patterns/genserver_crash_test.exs
git commit -m "feat: implement GenServer crash report compaction pattern"
```

---

### Task 6: Test Summary Pattern

**Files:**
- Modify: `lib/ex_compact/patterns/test_summary.ex`
- Create: `test/ex_compact/patterns/test_summary_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/patterns/test_summary_test.exs`:
```elixir
defmodule ExCompact.Patterns.TestSummaryTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.TestSummary

  @verbose_run """
  Running ExUnit with seed: 54321, max_cases: 16

  ............................................................................................
  ............................................................................................
  ............................................................................................
  .......F.....F.............

    1) test something (MyApp.SomeTest)
       test/my_app/some_test.exs:10
       Assertion with == failed
       left:  1
       right: 2

    2) test other thing (MyApp.OtherTest)
       test/my_app/other_test.exs:20
       ** (MatchError) no match

  Finished in 2.5 seconds (1.0s async, 1.5s sync)
  300 tests, 2 failures

  Randomized with seed 54321
  """

  test "compacts verbose test run to just failures and summary" do
    result = TestSummary.compact(@verbose_run, [])
    # Failures preserved
    assert result =~ "test something (MyApp.SomeTest)"
    assert result =~ "test other thing (MyApp.OtherTest)"
    assert result =~ "300 tests, 2 failures"
    # Dots and seed stripped
    refute result =~ "....."
    refute result =~ "Randomized with seed"
    refute result =~ "Running ExUnit with seed"
  end

  test "passes through text with no test summary" do
    input = "Normal output"
    assert TestSummary.compact(input, []) == input
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/patterns/test_summary_test.exs
```

**Step 3: Implement test summary pattern**

Replace `lib/ex_compact/patterns/test_summary.ex`:
```elixir
defmodule ExCompact.Patterns.TestSummary do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts) do
    if text =~ ~r/\d+ tests?, \d+ failures?/ and text =~ ~r/^\.{10,}/m do
      text
      |> remove_running_line()
      |> remove_test_dots()
      |> remove_seed_line()
      |> remove_finished_line()
      |> collapse_blank_lines()
      |> String.trim()
      |> Kernel.<>("\n")
    else
      text
    end
  end

  defp remove_running_line(text) do
    Regex.replace(~r/^Running ExUnit with seed.*\n*/m, text, "")
  end

  defp remove_test_dots(text) do
    Regex.replace(~r/^[\.F]+\n*/m, text, "")
  end

  defp remove_seed_line(text) do
    Regex.replace(~r/^\n*Randomized with seed \d+\n*/m, text, "")
  end

  defp remove_finished_line(text) do
    Regex.replace(~r/^Finished in .*\n/m, text, "")
  end

  defp collapse_blank_lines(text) do
    Regex.replace(~r/\n{3,}/, text, "\n\n")
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/patterns/test_summary_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/patterns/test_summary.ex test/ex_compact/patterns/test_summary_test.exs
git commit -m "feat: implement test summary compaction pattern"
```

---

### Task 7: Integration Tests for Full Pipeline

**Files:**
- Create: `test/ex_compact_test.exs`

**Step 1: Write integration tests**

`test/ex_compact_test.exs`:
```elixir
defmodule ExCompactTest do
  use ExUnit.Case, async: true

  test "compact/1 handles a mix of patterns in one text block" do
    input = """
    ** (RuntimeError) oops
        (my_app 0.1.0) lib/my_app/foo.ex:1: MyApp.Foo.bar/0
        (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6
        (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3

    Some normal text in between.

    [error] GenServer MyApp.Worker terminating
    ** (RuntimeError) broke
        (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.handle_info/2
        (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
    Last message: :tick
    State: %{x: 1}
    """
    result = ExCompact.compact(input, app: :my_app)
    # Both patterns compacted
    assert result =~ "MyApp.Foo.bar/0"
    assert result =~ "MyApp.Worker.handle_info/2"
    # OTP noise removed from both
    refute result =~ ":proc_lib.init_p_do_apply/3"
    # Normal text preserved
    assert result =~ "Some normal text in between."
  end

  test "compact/1 returns unchanged text when nothing matches" do
    input = "Hello world\nNothing to see here."
    assert ExCompact.compact(input) == input
  end
end
```

**Step 2: Run all tests**

```bash
mix test
```
Expected: All PASS

**Step 3: Commit**

```bash
git add test/ex_compact_test.exs
git commit -m "test: add integration tests for full compaction pipeline"
```

---

### Task 8: Unix Socket Daemon

**Files:**
- Create: `lib/ex_compact/daemon.ex`
- Create: `test/ex_compact/daemon_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/daemon_test.exs`:
```elixir
defmodule ExCompact.DaemonTest do
  use ExUnit.Case

  @socket_path "/tmp/ex_compact_test_#{System.pid()}.sock"

  setup do
    File.rm(@socket_path)
    {:ok, pid} = ExCompact.Daemon.start_link(socket_path: @socket_path)
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
      File.rm(@socket_path)
    end)
    %{pid: pid}
  end

  test "accepts a connection and returns compacted text" do
    input = "Hello, normal text"
    {:ok, socket} = :gen_tcp.connect({:local, @socket_path}, 0, [:binary, packet: 4, active: false], 5_000)
    :ok = :gen_tcp.send(socket, input)
    {:ok, response} = :gen_tcp.recv(socket, 0, 5_000)
    :gen_tcp.close(socket)
    # Normal text passes through unchanged
    assert response == input
  end

  test "cleans up socket file on stop" do
    assert File.exists?(@socket_path)
    GenServer.stop(ExCompact.Daemon)
    # Give it a moment to clean up
    Process.sleep(50)
    refute File.exists?(@socket_path)
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/daemon_test.exs
```

**Step 3: Implement the daemon**

`lib/ex_compact/daemon.ex`:
```elixir
defmodule ExCompact.Daemon do
  @moduledoc false
  use GenServer

  defstruct [:listen_socket, :socket_path, :acceptor]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def socket_path do
    "/tmp/ex_compact_#{System.get_env("USER")}.sock"
  end

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :socket_path, socket_path())
    cleanup_stale_socket(path)

    {:ok, listen} = :gen_tcp.listen(0, [
      {:ifaddr, {:local, path}},
      :binary,
      packet: 4,
      active: false,
      reuseaddr: true
    ])

    acceptor = spawn_link(fn -> accept_loop(listen) end)

    {:ok, %__MODULE__{listen_socket: listen, socket_path: path, acceptor: acceptor}}
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.listen_socket)
    File.rm(state.socket_path)
    :ok
  end

  defp accept_loop(listen) do
    case :gen_tcp.accept(listen) do
      {:ok, client} ->
        spawn(fn -> handle_client(client) end)
        accept_loop(listen)
      {:error, :closed} ->
        :ok
    end
  end

  defp handle_client(socket) do
    case :gen_tcp.recv(socket, 0, 30_000) do
      {:ok, data} ->
        result = ExCompact.compact(data)
        :gen_tcp.send(socket, result)
        :gen_tcp.close(socket)
      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end

  defp cleanup_stale_socket(path) do
    if File.exists?(path) do
      case :gen_tcp.connect({:local, path}, 0, [:binary], 1_000) do
        {:ok, sock} ->
          :gen_tcp.close(sock)
          raise "ex_compact daemon already running at #{path}"
        {:error, _} ->
          File.rm!(path)
      end
    end
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/daemon_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/daemon.ex test/ex_compact/daemon_test.exs
git commit -m "feat: implement Unix socket daemon for IPC"
```

---

### Task 9: Node Registry

**Files:**
- Create: `lib/ex_compact/registry.ex`
- Create: `test/ex_compact/registry_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/registry_test.exs`:
```elixir
defmodule ExCompact.RegistryTest do
  use ExUnit.Case

  @test_registry_path "/tmp/ex_compact_registry_test_#{System.pid()}.json"

  setup do
    File.rm(@test_registry_path)
    on_exit(fn -> File.rm(@test_registry_path) end)
    :ok
  end

  test "register and find a node" do
    ExCompact.Registry.register("/home/user/my_project", :"myapp@localhost",
      registry_path: @test_registry_path
    )

    assert {:ok, :"myapp@localhost"} =
             ExCompact.Registry.find_node("/home/user/my_project",
               registry_path: @test_registry_path
             )
  end

  test "find_node returns :error for unknown path" do
    assert :error =
             ExCompact.Registry.find_node("/nonexistent",
               registry_path: @test_registry_path
             )
  end

  test "unregister removes entry" do
    ExCompact.Registry.register("/home/user/proj", :"app@host",
      registry_path: @test_registry_path
    )

    ExCompact.Registry.unregister("/home/user/proj",
      registry_path: @test_registry_path
    )

    assert :error =
             ExCompact.Registry.find_node("/home/user/proj",
               registry_path: @test_registry_path
             )
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/registry_test.exs
```

**Step 3: Implement the registry**

`lib/ex_compact/registry.ex`:
```elixir
defmodule ExCompact.Registry do
  @moduledoc false

  @default_path Path.expand("~/.ex_compact/nodes.json")

  def register(project_root, node_name, opts \\ []) do
    path = Keyword.get(opts, :registry_path, @default_path)
    entries = read(path)
    entry = %{"node" => to_string(node_name), "root" => project_root}
    updated = Map.put(entries, project_root, entry)
    write(path, updated)
  end

  def unregister(project_root, opts \\ []) do
    path = Keyword.get(opts, :registry_path, @default_path)
    entries = read(path)
    updated = Map.delete(entries, project_root)
    write(path, updated)
  end

  def find_node(cwd, opts \\ []) do
    path = Keyword.get(opts, :registry_path, @default_path)
    entries = read(path)

    case Map.get(entries, cwd) do
      %{"node" => node_str} -> {:ok, String.to_atom(node_str)}
      nil -> :error
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, contents} -> Jason.decode!(contents)
      {:error, :enoent} -> %{}
    end
  end

  defp write(path, data) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, Jason.encode!(data, pretty: true))
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/registry_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/registry.ex test/ex_compact/registry_test.exs
git commit -m "feat: implement node registry for project node connection"
```

---

### Task 10: Client (Connection Strategy)

**Files:**
- Create: `lib/ex_compact/client.ex`
- Create: `test/ex_compact/client_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/client_test.exs`:
```elixir
defmodule ExCompact.ClientTest do
  use ExUnit.Case

  @socket_path "/tmp/ex_compact_client_test_#{System.pid()}.sock"

  test "falls back to inline when no daemon or project node" do
    # No daemon running, no project node — should fall back to inline
    result = ExCompact.Client.compact("hello world", cwd: "/nonexistent")
    assert result == "hello world"
  end

  test "connects to daemon when available" do
    File.rm(@socket_path)
    {:ok, _pid} = ExCompact.Daemon.start_link(socket_path: @socket_path)

    result = ExCompact.Client.compact("hello world", socket_path: @socket_path)
    assert result == "hello world"

    GenServer.stop(ExCompact.Daemon)
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/client_test.exs
```

**Step 3: Implement the client**

`lib/ex_compact/client.ex`:
```elixir
defmodule ExCompact.Client do
  @moduledoc false

  def compact(text, opts \\ []) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    socket_path = Keyword.get(opts, :socket_path, ExCompact.Daemon.socket_path())

    with {:error, _} <- try_project_node(text, cwd),
         {:error, _} <- try_daemon(text, socket_path) do
      # Inline fallback
      ExCompact.compact(text)
    end
  end

  defp try_project_node(text, cwd) do
    case ExCompact.Registry.find_node(cwd) do
      {:ok, node_name} ->
        if Node.connect(node_name) do
          case :rpc.call(node_name, ExCompact, :compact, [text], 5_000) do
            {:badrpc, reason} -> {:error, reason}
            result -> result
          end
        else
          {:error, :connect_failed}
        end

      :error ->
        {:error, :no_node}
    end
  end

  defp try_daemon(text, socket_path) do
    case :gen_tcp.connect({:local, socket_path}, 0, [:binary, packet: 4, active: false], 1_000) do
      {:ok, socket} ->
        :gen_tcp.send(socket, text)

        result =
          case :gen_tcp.recv(socket, 0, 5_000) do
            {:ok, data} -> data
            {:error, reason} -> {:error, reason}
          end

        :gen_tcp.close(socket)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/client_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/ex_compact/client.ex test/ex_compact/client_test.exs
git commit -m "feat: implement client with three-tier connection strategy"
```

---

### Task 11: CLI (Escript Entrypoint)

**Files:**
- Create: `lib/ex_compact/cli.ex`
- Create: `test/ex_compact/cli_test.exs`

**Step 1: Write the failing test**

`test/ex_compact/cli_test.exs`:
```elixir
defmodule ExCompact.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "compact command reads stdin and writes compacted output" do
    input = "Hello, normal text"
    output = capture_io(input, fn ->
      ExCompact.CLI.main(["compact"])
    end)
    assert output == input
  end

  test "daemon start prints confirmation" do
    # Can't fully test daemon lifecycle in unit tests,
    # but we can test arg parsing
    assert ExCompact.CLI.parse_args(["compact"]) == :compact
    assert ExCompact.CLI.parse_args(["daemon", "start"]) == {:daemon, :start}
    assert ExCompact.CLI.parse_args(["daemon", "stop"]) == {:daemon, :stop}
    assert ExCompact.CLI.parse_args([]) == :help
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/ex_compact/cli_test.exs
```

**Step 3: Implement the CLI**

`lib/ex_compact/cli.ex`:
```elixir
defmodule ExCompact.CLI do
  @moduledoc false

  def main(args) do
    case parse_args(args) do
      :compact ->
        input = IO.read(:stdio, :eof)
        output = ExCompact.Client.compact(input)
        IO.write(output)

      {:daemon, :start} ->
        {:ok, _} = ExCompact.Daemon.start_link([])
        IO.puts("ex_compact daemon started at #{ExCompact.Daemon.socket_path()}")
        # Block forever
        Process.sleep(:infinity)

      {:daemon, :stop} ->
        stop_daemon()

      :help ->
        IO.puts("""
        Usage: ex_compact <command>

        Commands:
          compact          Read stdin, write compacted output
          daemon start     Start the background daemon
          daemon stop      Stop the background daemon
        """)
    end
  end

  def parse_args(["compact" | _]), do: :compact
  def parse_args(["daemon", "start" | _]), do: {:daemon, :start}
  def parse_args(["daemon", "stop" | _]), do: {:daemon, :stop}
  def parse_args(_), do: :help

  defp stop_daemon do
    path = ExCompact.Daemon.socket_path()

    case :gen_tcp.connect({:local, path}, 0, [:binary], 1_000) do
      {:ok, sock} ->
        :gen_tcp.close(sock)
        IO.puts("Daemon is running. Removing socket to force restart.")
        File.rm(path)

      {:error, _} ->
        IO.puts("No daemon running.")
    end
  end
end
```

**Step 4: Run tests**

```bash
mix test test/ex_compact/cli_test.exs
```
Expected: PASS

**Step 5: Build the escript**

```bash
mix escript.build
```

**Step 6: Commit**

```bash
git add lib/ex_compact/cli.ex test/ex_compact/cli_test.exs
git commit -m "feat: implement CLI escript entrypoint"
```

---

### Task 12: Application Supervision Tree

**Files:**
- Modify: `lib/ex_compact/application.ex`
- Create: `test/ex_compact/application_test.exs`

**Step 1: Write the test**

`test/ex_compact/application_test.exs`:
```elixir
defmodule ExCompact.ApplicationTest do
  use ExUnit.Case

  test "application starts successfully" do
    # Application is already started by ExUnit
    assert Process.whereis(ExCompact.Supervisor) != nil
  end
end
```

**Step 2: Implement the application module**

`lib/ex_compact/application.ex`:
```elixir
defmodule ExCompact.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if daemon_mode?() do
        [{ExCompact.Daemon, []}]
      else
        []
      end

    opts = [strategy: :one_for_one, name: ExCompact.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp daemon_mode? do
    Application.get_env(:ex_compact, :daemon, false)
  end
end
```

**Step 3: Run tests**

```bash
mix test test/ex_compact/application_test.exs
```
Expected: PASS

**Step 4: Commit**

```bash
git add lib/ex_compact/application.ex test/ex_compact/application_test.exs
git commit -m "feat: configure application supervision tree"
```

---

### Task 13: Hook Scripts

**Files:**
- Create: `hooks/post_tool_use.sh`
- Create: `hooks/user_prompt_submit.sh`

**Step 1: Create PostToolUse hook**

`hooks/post_tool_use.sh`:
```bash
#!/usr/bin/env bash
# Claude Code PostToolUse hook — compacts Bash tool output via ex_compact
# Reads JSON from stdin, extracts tool output, compacts it, re-wraps as JSON

set -euo pipefail

# Read the hook JSON from stdin
input=$(cat)

# Extract the tool output text
tool_output=$(echo "$input" | jq -r '.tool_result.stdout // empty')

if [ -z "$tool_output" ]; then
  exit 0
fi

# Pipe through ex_compact
compacted=$(echo "$tool_output" | ex_compact compact 2>/dev/null || echo "$tool_output")

# Re-wrap into the expected JSON output
if [ "$compacted" != "$tool_output" ]; then
  echo "$input" | jq --arg output "$compacted" '.tool_result.stdout = $output'
else
  echo "$input"
fi
```

**Step 2: Create UserPromptSubmit hook**

`hooks/user_prompt_submit.sh`:
```bash
#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — compacts pasted traces in user prompts
# Reads JSON from stdin, extracts user message, compacts it, re-wraps as JSON

set -euo pipefail

input=$(cat)

user_message=$(echo "$input" | jq -r '.user_message // empty')

if [ -z "$user_message" ]; then
  exit 0
fi

compacted=$(echo "$user_message" | ex_compact compact 2>/dev/null || echo "$user_message")

if [ "$compacted" != "$user_message" ]; then
  echo "$input" | jq --arg msg "$compacted" '.user_message = $msg'
else
  echo "$input"
fi
```

**Step 3: Make executable**

```bash
chmod +x hooks/post_tool_use.sh hooks/user_prompt_submit.sh
```

**Step 4: Commit**

```bash
git add hooks/
git commit -m "feat: add Claude Code hook scripts for PostToolUse and UserPromptSubmit"
```

---

### Task 14: Igniter Installer Task

**Files:**
- Create: `lib/mix/tasks/ex_compact.install.ex`
- Create: `test/mix/tasks/ex_compact_install_test.exs`

**Step 1: Write the failing test**

`test/mix/tasks/ex_compact_install_test.exs`:
```elixir
defmodule Mix.Tasks.ExCompact.InstallTest do
  use ExUnit.Case

  test "info returns valid task info" do
    info = Mix.Tasks.ExCompact.Install.info([], nil)
    assert %Igniter.Mix.Task.Info{} = info
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/mix/tasks/ex_compact_install_test.exs
```

**Step 3: Implement the installer task**

`lib/mix/tasks/ex_compact.install.ex`:
```elixir
defmodule Mix.Tasks.ExCompact.Install do
  @moduledoc """
  Installs ex_compact: builds escript, copies hooks, configures Claude Code settings.

      mix ex_compact.install

  ## What it does

  1. Builds the `ex_compact` escript
  2. Copies hook scripts to `~/.claude/hooks/`
  3. Merges hook config into `~/.claude/settings.json`
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      schema: [],
      positional: [],
      composes: [],
      adds_deps: [],
      installs: [],
      only: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    hooks_dir = Path.expand("~/.claude/hooks")
    settings_path = Path.expand("~/.claude/settings.json")

    igniter
    |> Igniter.add_notice("Building ex_compact escript...")
    |> build_escript()
    |> copy_hooks(hooks_dir)
    |> configure_settings(settings_path)
    |> Igniter.add_notice("ex_compact installed successfully!")
  end

  defp build_escript(igniter) do
    # Igniter doesn't have a built-in escript builder,
    # so we run it as a shell command via a notice.
    # The actual build happens in a post-install step.
    Igniter.add_notice(igniter, "Run `mix escript.build` to build the CLI binary.")
  end

  defp copy_hooks(igniter, hooks_dir) do
    File.mkdir_p!(hooks_dir)

    for hook <- ~w(post_tool_use.sh user_prompt_submit.sh) do
      source = Path.join(["hooks", hook])
      dest = Path.join(hooks_dir, hook)

      if File.exists?(source) do
        File.cp!(source, dest)
        File.chmod!(dest, 0o755)
      end
    end

    igniter
  end

  defp configure_settings(igniter, settings_path) do
    settings =
      case File.read(settings_path) do
        {:ok, contents} -> Jason.decode!(contents)
        {:error, :enoent} -> %{}
      end

    hooks = Map.get(settings, "hooks", %{})

    hooks =
      hooks
      |> add_hook("PostToolUse", %{
        "type" => "command",
        "command" => "~/.claude/hooks/post_tool_use.sh",
        "matcher" => %{"tool_name" => "Bash"}
      })
      |> add_hook("UserPromptSubmit", %{
        "type" => "command",
        "command" => "~/.claude/hooks/user_prompt_submit.sh"
      })

    updated = Map.put(settings, "hooks", hooks)
    File.mkdir_p!(Path.dirname(settings_path))
    File.write!(settings_path, Jason.encode!(updated, pretty: true))

    igniter
  end

  defp add_hook(hooks, event, config) do
    existing = Map.get(hooks, event, [])

    unless Enum.any?(existing, &(&1["command"] =~ "ex_compact")) do
      Map.put(hooks, event, existing ++ [config])
    else
      hooks
    end
  end
end
```

**Step 4: Run tests**

```bash
mix test test/mix/tasks/ex_compact_install_test.exs
```
Expected: PASS

**Step 5: Commit**

```bash
git add lib/mix/tasks/ex_compact.install.ex test/mix/tasks/ex_compact_install_test.exs
git commit -m "feat: add Igniter installer task for Claude Code integration"
```

---

### Task 15: usage-rules.md and README

**Files:**
- Create: `usage-rules.md`
- Create: `README.md`

**Step 1: Create usage-rules.md**

`usage-rules.md`:
```markdown
# ExCompact Usage Rules

## Public API

The only public function is `ExCompact.compact/2`:

```elixir
ExCompact.compact(text, opts \\ [])
```

### Options

- `:app` - atom, the project app name for frame scoring. Auto-detected from Mix.Project if nil.
- `:max_frames` - integer, max stack frames to keep per trace. Default: 4.

## Architecture

ExCompact uses a pattern pipeline. Each pattern module implements `compact/2` and is run in sequence:

1. `ExCompact.Patterns.StackTrace` — `** (Exception)` + indented frames
2. `ExCompact.Patterns.TestFailure` — numbered test failure blocks from `mix test`
3. `ExCompact.Patterns.GenServerCrash` — `[error] GenServer ... terminating` blocks
4. `ExCompact.Patterns.TestSummary` — verbose test run output with many dots

## Adding a New Pattern

1. Create `lib/ex_compact/patterns/your_pattern.ex`
2. Implement `@behaviour ExCompact.Patterns.Pattern`
3. Add the module to `@patterns` in `ExCompact.Compactor`
4. Add tests in `test/ex_compact/patterns/your_pattern_test.exs`

## Connection Strategies

The `ExCompact.Client` tries three strategies in order:
1. **Project node** — `:rpc.call` to a running BEAM node that has ex_compact as a dep
2. **Daemon** — Unix socket at `/tmp/ex_compact_<user>.sock`
3. **Inline** — direct function call (escript boot cost ~500ms)

## Do Not

- Call internal modules directly — use `ExCompact.compact/2`
- Modify the hook scripts — they are generated by the installer
- Run the daemon in production — it's a dev tool
```

**Step 2: Create README.md**

`README.md`:
```markdown
# ExCompact

Compact noisy BEAM output (stack traces, test failures, crash reports) before Claude Code sees it. Reduces token usage while preserving the information needed to debug.

## Installation

```bash
mix igniter.install ex_compact
```

This will:
1. Build the escript
2. Copy hook scripts to `~/.claude/hooks/`
3. Configure Claude Code settings

## What It Does

ExCompact intercepts verbose Elixir/Erlang output and compacts it:

- **Stack traces**: Keeps the exception line + top project-relevant frames, strips OTP/stdlib noise
- **Test failures**: Strips compilation output, progress dots, and seed info
- **GenServer crashes**: Keeps module, exception, project frames, and last message. Truncates large state.
- **Test summaries**: Strips dots and metadata from verbose test runs

## Usage

Automatic via Claude Code hooks (installed by `mix ex_compact.install`).

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

The project node auto-registers on boot. The `ex_compact` client connects via `:rpc.call` — no socket overhead.

## License

MIT
```

**Step 3: Commit**

```bash
git add usage-rules.md README.md
git commit -m "docs: add usage-rules.md and README"
```

---

### Task 16: Run Full Test Suite and Final Verification

**Step 1: Run all tests**

```bash
mix test
```
Expected: All PASS

**Step 2: Build escript**

```bash
mix escript.build
```

**Step 3: Smoke test the escript**

```bash
echo "** (RuntimeError) oops\n    (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6" | ./ex_compact compact
```

**Step 4: Verify formatter**

```bash
mix format --check-formatted
```

**Step 5: Final commit if any formatting changes**

```bash
mix format
git add -A
git commit -m "chore: format code"
```
