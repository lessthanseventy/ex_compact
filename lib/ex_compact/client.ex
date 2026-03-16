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
