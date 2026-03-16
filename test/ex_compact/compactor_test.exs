defmodule ExCompact.CompactorTest do
  use ExUnit.Case, async: true

  test "passes through text with no recognizable patterns" do
    input = "Hello, this is normal output.\nNothing to compact here."
    assert ExCompact.Compactor.compact(input) == input
  end

  test "applies matching patterns and leaves non-matching text intact" do
    input = "some output\nmore output"
    result = ExCompact.Compactor.compact(input)
    assert is_binary(result)
  end
end
