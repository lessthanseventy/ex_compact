#!/usr/bin/env bash
# Claude Code PreToolUse hook — wraps Bash commands to pipe through ex_compact
set -euo pipefail

input=$(cat)

# Extract the command
command=$(echo "$input" | jq -r '.tool_input.command // ""')

if [ -z "$command" ]; then
  exit 0
fi

# Don't wrap if the command already uses ex_compact (avoid infinite loop)
if echo "$command" | grep -q "ex_compact"; then
  exit 0
fi

# Wrap the command to pipe stdout+stderr through ex_compact
wrapped="set -o pipefail; ($command) 2>&1 | ex_compact compact"

echo "$input" | jq --arg cmd "$wrapped" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": {"command": $cmd}}}'
