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

    {:ok, socket} =
      :gen_tcp.connect({:local, @socket_path}, 0, [:binary, packet: 4, active: false], 5_000)

    :ok = :gen_tcp.send(socket, input)
    {:ok, response} = :gen_tcp.recv(socket, 0, 5_000)
    :gen_tcp.close(socket)
    assert response == input
  end

  test "compacts text through the socket" do
    input = """
    [debug] QUERY OK source="users" db=2.5ms
    SELECT u0."id" FROM "users" AS u0
    Some important text
    """

    {:ok, socket} =
      :gen_tcp.connect({:local, @socket_path}, 0, [:binary, packet: 4, active: false], 5_000)

    :ok = :gen_tcp.send(socket, input)
    {:ok, response} = :gen_tcp.recv(socket, 0, 5_000)
    :gen_tcp.close(socket)
    refute response =~ "QUERY OK"
    assert response =~ "Some important text"
  end

  test "cleans up socket file on stop", %{pid: pid} do
    assert File.exists?(@socket_path)
    GenServer.stop(pid)
    Process.sleep(50)
    refute File.exists?(@socket_path)
  end
end
