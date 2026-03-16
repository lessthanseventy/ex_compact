if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.ExCompact.Install do
    @moduledoc """
    Installs ex_compact into the current project and optionally sets up Claude Code hooks.

        mix ex_compact.install
        mix ex_compact.install --setup

    Without `--setup`, only adds ex_compact as a dependency.
    With `--setup`, also builds the escript, copies hooks to `~/.claude/hooks/`,
    installs the escript to `~/.local/bin/`, and configures `~/.claude/settings.json`.

    NOTE: This task requires Igniter and is only available in the ex_compact project itself
    or when Igniter is a dependency. Consuming projects should use `mix ex_compact.setup`.
    """
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        schema: [setup: :boolean],
        defaults: [setup: false],
        positional: [],
        composes: [],
        adds_deps: [],
        installs: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      if igniter.args.options[:setup] do
        igniter
        |> Igniter.add_notice("Will build escript and configure Claude Code hooks after project changes.")
        |> Igniter.add_task("ex_compact.setup", [])
      else
        Igniter.add_notice(
          igniter,
          "ex_compact added. Run `mix ex_compact.setup` to install the escript and Claude Code hooks."
        )
      end
    end
  end
end
