defmodule ExCompact.Registry do
  @moduledoc false

  @default_path Path.expand("~/.ex_compact/nodes.json")

  def register(project_root, node_name, opts \\ []) do
    path = Keyword.get(opts, :registry_path, @default_path)
    entries = read(path)
    entry = %{"node" => to_string(node_name), "root" => project_root}
    updated = Map.put(entries, project_root, entry)
    write(path, updated)
  end

  def unregister(project_root, opts \\ []) do
    path = Keyword.get(opts, :registry_path, @default_path)
    entries = read(path)
    updated = Map.delete(entries, project_root)
    write(path, updated)
  end

  def find_node(cwd, opts \\ []) do
    path = Keyword.get(opts, :registry_path, @default_path)
    entries = read(path)

    case Map.get(entries, cwd) do
      %{"node" => node_str} -> {:ok, String.to_atom(node_str)}
      nil -> :error
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, contents} -> Jason.decode!(contents)
      {:error, :enoent} -> %{}
    end
  end

  defp write(path, data) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, Jason.encode!(data, pretty: true))
  end
end
