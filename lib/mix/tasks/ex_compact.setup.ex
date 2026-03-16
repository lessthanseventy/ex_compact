defmodule Mix.Tasks.ExCompact.Setup do
  @shortdoc "Builds escript, copies hooks, configures Claude Code settings"

  @moduledoc """
  Sets up ex_compact for use with Claude Code.

      mix ex_compact.setup
      mix ex_compact.setup --bin-dir ~/.local/bin

  ## What it does

  1. Builds the `ex_compact` escript from the dep source
  2. Installs it to `~/.local/bin/` (override with `--bin-dir`)
  3. Copies hook scripts to `~/.claude/hooks/`
  4. Merges hook config into `~/.claude/settings.json`

  Each step that modifies files outside the project directory
  asks for confirmation before proceeding.
  """
  use Mix.Task

  @default_bin_dir Path.expand("~/.local/bin")
  @hooks_dir Path.expand("~/.claude/hooks")
  @settings_path Path.expand("~/.claude/settings.json")

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [bin_dir: :string])
    bin_dir = Keyword.get(opts, :bin_dir, @default_bin_dir)

    dep_dir = find_dep_dir!()

    escript_path = build_escript(dep_dir)

    if confirm("Install escript to #{bin_dir}/ex_compact?") do
      install_escript(escript_path, bin_dir)
    end

    if confirm("Copy hook scripts to #{@hooks_dir}/?") do
      copy_hooks(dep_dir)
    end

    if confirm("Add ex_compact hooks to #{@settings_path}?") do
      configure_settings()
    end

    Mix.shell().info("\nDone!")
  end

  defp find_dep_dir! do
    # Check if we're running from the ex_compact project itself
    if Mix.Project.config()[:app] == :ex_compact do
      File.cwd!()
    else
      # Find the dep directory
      deps_path = Mix.Project.deps_path()
      dep_dir = Path.join(deps_path, "ex_compact")

      if !File.dir?(dep_dir) do
        Mix.raise("Could not find ex_compact dep at #{dep_dir}")
      end

      dep_dir
    end
  end

  defp build_escript(dep_dir) do
    Mix.shell().info("Building escript in #{dep_dir}...")

    {output, exit_code} = System.cmd("mix", ["escript.build"], cd: dep_dir, stderr_to_stdout: true)

    if exit_code != 0 do
      Mix.raise("Failed to build escript:\n#{output}")
    end

    escript = Path.join(dep_dir, "ex_compact")

    if !File.exists?(escript) do
      Mix.raise("Escript not found at #{escript} after build")
    end

    escript
  end

  defp install_escript(escript_path, bin_dir) do
    File.mkdir_p!(bin_dir)
    dest = Path.join(bin_dir, "ex_compact")
    File.cp!(escript_path, dest)
    File.chmod!(dest, 0o755)
    Mix.shell().info("  Installed #{dest}")
  end

  defp copy_hooks(dep_dir) do
    File.mkdir_p!(@hooks_dir)

    for {src_name, dest_name} <- [
          {"hooks/post_tool_use.sh", "ex_compact_post_tool_use.sh"},
          {"hooks/user_prompt_submit.sh", "ex_compact_user_prompt_submit.sh"}
        ] do
      src = Path.join(dep_dir, src_name)
      dest = Path.join(@hooks_dir, dest_name)

      if !File.exists?(src) do
        Mix.raise("Hook script not found at #{src}")
      end

      File.cp!(src, dest)
      File.chmod!(dest, 0o755)
      Mix.shell().info("  Copied #{dest}")
    end
  end

  defp confirm(question) do
    Mix.shell().yes?(question)
  end

  defp configure_settings do
    settings =
      case File.read(@settings_path) do
        {:ok, contents} -> Jason.decode!(contents)
        {:error, :enoent} -> %{}
      end

    hooks = Map.get(settings, "hooks", %{})

    hooks =
      hooks
      |> add_hook("PostToolUse", %{
        "type" => "command",
        "command" => Path.join(@hooks_dir, "ex_compact_post_tool_use.sh"),
        "matcher" => %{"tool_name" => "Bash"}
      })
      |> add_hook("UserPromptSubmit", %{
        "type" => "command",
        "command" => Path.join(@hooks_dir, "ex_compact_user_prompt_submit.sh")
      })

    updated = Map.put(settings, "hooks", hooks)
    File.mkdir_p!(Path.dirname(@settings_path))
    File.write!(@settings_path, Jason.encode!(updated, pretty: true))
    Mix.shell().info("  Updated #{@settings_path}")
  end

  defp add_hook(hooks, event, config) do
    existing = Map.get(hooks, event, [])

    if Enum.any?(existing, fn h -> is_binary(h["command"]) and h["command"] =~ "ex_compact" end) do
      Mix.shell().info("  #{event} hook already configured, skipping")
      hooks
    else
      Map.put(hooks, event, existing ++ [config])
    end
  end
end
