#!/usr/bin/env bash
# Claude Code PreToolUse hook — wraps Bash commands to pipe through ex_compact
set -euo pipefail

input=$(cat)

# Extract the command
command=$(echo "$input" | jq -r '.tool_input.command // ""')

if [ -z "$command" ]; then
  exit 0
fi

# Don't wrap ex_compact or tmux commands
if echo "$command" | grep -qE '(ex_compact|tmux|tmux-cli)'; then
  exit 0
fi

# Only wrap commands likely to produce noisy BEAM output
should_wrap=false
case "$command" in
  *"mix test"*|*"mix compile"*|*"mix deps"*|*"mix ecto"*|*"mix phx"*|*"iex"*|*"elixir "*|*"mix run"*)
    should_wrap=true
    ;;
esac

# Don't wrap if the command already pipes to a filtering tool
if echo "$command" | grep -qE '\|\s*(tail|head|grep|wc|awk|sed|cut|sort|uniq|less|more)'; then
  should_wrap=false
fi

if [ "$should_wrap" = false ]; then
  exit 0
fi

# Wrap the command to pipe stdout+stderr through ex_compact
wrapped="set -o pipefail; ($command) 2>&1 | ex_compact compact"

echo "$input" | jq --arg cmd "$wrapped" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": {"command": $cmd}}}'
