defmodule Mix.Tasks.ExCompact.InstallTest do
  use ExUnit.Case

  test "task module is defined" do
    assert Code.ensure_loaded?(Mix.Tasks.ExCompact.Install)
  end
end
