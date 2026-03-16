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
