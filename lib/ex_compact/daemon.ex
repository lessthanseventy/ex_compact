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

    {:ok, listen} =
      :gen_tcp.listen(0, [
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
