defmodule ExCompact.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "compact command reads stdin and writes compacted output" do
    input = "Hello, normal text"

    output =
      capture_io(input, fn ->
        ExCompact.CLI.main(["compact"])
      end)

    assert String.trim(output) == input
  end

  test "parse_args handles all commands" do
    assert ExCompact.CLI.parse_args(["compact"]) == :compact
    assert ExCompact.CLI.parse_args(["daemon", "start"]) == {:daemon, :start}
    assert ExCompact.CLI.parse_args(["daemon", "stop"]) == {:daemon, :stop}
    assert ExCompact.CLI.parse_args([]) == :help
  end
end
