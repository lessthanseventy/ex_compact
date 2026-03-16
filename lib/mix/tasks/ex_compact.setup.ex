defmodule Mix.Tasks.ExCompact.Setup do
  @shortdoc "Builds escript, copies hooks, configures Claude Code settings"

  @moduledoc """
  Sets up ex_compact for use with Claude Code.

      mix ex_compact.setup
      mix ex_compact.setup --bin-dir ~/.local/bin

  ## What it does

  1. Builds the `ex_compact` escript
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

    build_escript()

    if confirm("Install escript to #{bin_dir}/ex_compact?") do
      install_escript(bin_dir)
    end

    if confirm("Copy hook scripts to #{@hooks_dir}/?") do
      copy_hooks()
    end

    if confirm("Add ex_compact hooks to #{@settings_path}?") do
      configure_settings()
    end

    Mix.shell().info("\nDone!")
  end

  defp confirm(question) do
    Mix.shell().yes?(question)
  end

  defp build_escript do
    Mix.shell().info("Building escript...")
    Mix.Task.run("escript.build")
  end

  defp install_escript(bin_dir) do
    File.mkdir_p!(bin_dir)
    dest = Path.join(bin_dir, "ex_compact")
    File.cp!("ex_compact", dest)
    File.chmod!(dest, 0o755)
    Mix.shell().info("  Installed #{dest}")
  end

  defp copy_hooks do
    File.mkdir_p!(@hooks_dir)

    for {src, dest_name} <- [
          {"hooks/post_tool_use.sh", "ex_compact_post_tool_use.sh"},
          {"hooks/user_prompt_submit.sh", "ex_compact_user_prompt_submit.sh"}
        ] do
      dest = Path.join(@hooks_dir, dest_name)
      File.cp!(src, dest)
      File.chmod!(dest, 0o755)
      Mix.shell().info("  Copied #{dest}")
    end
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
