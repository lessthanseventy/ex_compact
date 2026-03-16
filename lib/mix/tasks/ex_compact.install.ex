defmodule Mix.Tasks.ExCompact.Install do
  @moduledoc """
  Installs ex_compact: builds escript, copies hooks, configures Claude Code settings.

      mix ex_compact.install
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      schema: [],
      positional: [],
      composes: [],
      adds_deps: [],
      installs: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.add_notice(igniter, install_message())
  end

  defp install_message do
    """
    ex_compact setup:

    1. Build the escript:
       mix escript.build

    2. Copy it to your PATH:
       cp ex_compact ~/.local/bin/

    3. Copy hook scripts:
       mkdir -p ~/.claude/hooks
       cp hooks/post_tool_use.sh ~/.claude/hooks/ex_compact_post_tool_use.sh
       cp hooks/user_prompt_submit.sh ~/.claude/hooks/ex_compact_user_prompt_submit.sh

    4. Add hooks to ~/.claude/settings.json (merge into existing):
       {
         "hooks": {
           "PostToolUse": [
             {
               "type": "command",
               "command": "~/.claude/hooks/ex_compact_post_tool_use.sh",
               "matcher": {"tool_name": "Bash"}
             }
           ],
           "UserPromptSubmit": [
             {
               "type": "command",
               "command": "~/.claude/hooks/ex_compact_user_prompt_submit.sh"
             }
           ]
         }
       }

    5. Start the daemon (optional, for faster response):
       ex_compact daemon start
    """
  end
end
