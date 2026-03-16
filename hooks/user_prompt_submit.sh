#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — compacts pasted traces in user prompts
set -euo pipefail

input=$(cat)

user_message=$(echo "$input" | jq -r '.user_message // empty')
if [ -z "$user_message" ]; then
  exit 0
fi

compacted=$(echo "$user_message" | ex_compact compact 2>/dev/null) || exit 0

if [ "$compacted" != "$user_message" ]; then
  echo "$input" | jq --arg msg "$compacted" '.user_message = $msg'
fi
