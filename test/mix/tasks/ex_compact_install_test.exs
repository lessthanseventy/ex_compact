defmodule Mix.Tasks.ExCompact.InstallTest do
  use ExUnit.Case

  test "install task module is defined" do
    assert Code.ensure_loaded?(Mix.Tasks.ExCompact.Install)
  end

  test "setup task module is defined" do
    assert Code.ensure_loaded?(Mix.Tasks.ExCompact.Setup)
  end
end
