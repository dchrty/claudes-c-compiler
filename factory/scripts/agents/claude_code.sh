#!/usr/bin/env bash
# Claude Code CLI adapter. Stub for now — codex is the current target.
# Contract: $1 = prompt, $2 = working directory.
set -uo pipefail
PROMPT="$1"
WORKDIR="$2"
cd "$WORKDIR"
claude -p "$PROMPT" --dangerously-skip-permissions
