#!/usr/bin/env bash
# Claude Code PostToolUse hook — compacts Bash tool output via ex_compact
set -euo pipefail

# Extract stdout from the tool response
stdout=$(jq -r '.tool_response.stdout // ""')

if [ -z "$stdout" ]; then
  exit 0
fi

# Compact via ex_compact (exit cleanly if ex_compact not found or fails)
compacted=$(echo "$stdout" | ex_compact compact 2>/dev/null) || exit 0

# Only output if something changed
if [ "$compacted" != "$stdout" ]; then
  echo "$compacted" | jq -Rs '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "updatedResponse": {"stdout": .}}}'
fi
