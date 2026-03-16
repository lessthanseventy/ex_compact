defmodule ExCompact.ClientTest do
  use ExUnit.Case

  @socket_path "/tmp/ex_compact_client_test_#{System.pid()}.sock"

  test "falls back to inline when no daemon or project node" do
    result = ExCompact.Client.compact("hello world", cwd: "/nonexistent", socket_path: "/nonexistent.sock")
    assert result == "hello world"
  end

  test "connects to daemon when available" do
    File.rm(@socket_path)
    {:ok, _pid} = ExCompact.Daemon.start_link(socket_path: @socket_path)

    result = ExCompact.Client.compact("hello world", socket_path: @socket_path)
    assert result == "hello world"

    GenServer.stop(ExCompact.Daemon)
    File.rm(@socket_path)
  end

  test "daemon compacts text" do
    File.rm(@socket_path)
    {:ok, _pid} = ExCompact.Daemon.start_link(socket_path: @socket_path)

    input = """
    [debug] QUERY OK source="users" db=2.5ms
    SELECT u0."id" FROM "users" AS u0
    Important output
    """
    result = ExCompact.Client.compact(input, socket_path: @socket_path)
    refute result =~ "QUERY OK"
    assert result =~ "Important output"

    GenServer.stop(ExCompact.Daemon)
    File.rm(@socket_path)
  end
end
