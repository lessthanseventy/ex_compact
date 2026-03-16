defmodule ExCompact.ApplicationTest do
  use ExUnit.Case

  test "application starts successfully" do
    assert Process.whereis(ExCompact.Supervisor)
  end
end
