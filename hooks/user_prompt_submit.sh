#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — compacts pasted traces in user prompts
set -euo pipefail

# Extract the user's prompt
prompt=$(jq -r '.prompt // ""')

if [ -z "$prompt" ]; then
  exit 0
fi

# Compact via ex_compact (exit cleanly if ex_compact not found or fails)
compacted=$(echo "$prompt" | ex_compact compact 2>/dev/null) || exit 0

# Only output if something changed
if [ "$compacted" != "$prompt" ]; then
  echo "$compacted" | jq -Rs '{"updatedPrompt": .}'
fi
