#!/usr/bin/env bash
# Claude Code PostToolUse hook — compacts Bash tool output via ex_compact
set -euo pipefail

input=$(cat)

# Only process Bash tool results
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

# Extract stdout
tool_output=$(echo "$input" | jq -r '.tool_result.stdout // empty')
if [ -z "$tool_output" ]; then
  exit 0
fi

# Compact via ex_compact (fall back to original if ex_compact fails)
compacted=$(echo "$tool_output" | ex_compact compact 2>/dev/null) || exit 0

# Only output if something changed
if [ "$compacted" != "$tool_output" ]; then
  echo "$input" | jq --arg output "$compacted" '.tool_result.stdout = $output'
fi
