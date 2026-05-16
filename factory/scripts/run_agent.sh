#!/usr/bin/env bash
# Single dispatch point for "spawn a fresh agent session here."
# Reads .agent.kind from factory.yaml and execs the matching adapter.
# Used by both the worker (entrypoint.sh) and the judge (gate.sh) so that
# swapping codex <-> claude-code is one config line, not a code change.
set -uo pipefail

CONFIG="${FACTORY_CONFIG:-/factory/factory.yaml}"
PROMPT="$1"
WORKDIR="$2"

KIND=$(yq -r '.agent.kind' "$CONFIG")
case "$KIND" in
  codex)        exec /factory/scripts/agents/codex.sh "$PROMPT" "$WORKDIR" ;;
  claude-code)  exec /factory/scripts/agents/claude_code.sh "$PROMPT" "$WORKDIR" ;;
  *) echo "Unknown agent.kind: $KIND" >&2; exit 2 ;;
esac
