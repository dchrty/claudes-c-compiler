#!/usr/bin/env bash
# Spin up N agent containers. Per-agent isolation:
#   - own /workspace (no cross-agent file visibility)
#   - shared /upstream bare repo as the only meeting point
#   - read-only /factory mount for scripts + config
set -uo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$FACTORY_DIR/factory.yaml}"
AGENTS=$(yq -r '.agents' "$CONFIG")
KIND=$(yq -r '.agent.kind' "$CONFIG")

# Agent-specific credentials passed through from host. Add new ones as
# new adapters appear.
CRED_ARGS=()
case "$KIND" in
  codex)
    : "${OPENAI_API_KEY:?OPENAI_API_KEY required for agent.kind=codex}"
    CRED_ARGS+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")
    ;;
  claude-code)
    : "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY required for agent.kind=claude-code}"
    CRED_ARGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    ;;
esac

mkdir -p "$FACTORY_DIR/logs"
RUN_PREFIX="factory-agent-$(date +%s)"

docker ps -a --filter "name=factory-agent-" -q | head -64 | xargs -r docker rm -f >/dev/null

for i in $(seq 1 "$AGENTS"); do
  NAME="${RUN_PREFIX}-${i}"
  docker run -d \
    --name "$NAME" \
    --memory 8g --cpus 2 \
    --restart unless-stopped \
    "${CRED_ARGS[@]}" \
    -e AGENT_ID="$i" \
    -v "$FACTORY_DIR/upstream.git:/upstream" \
    -v "$FACTORY_DIR:/factory:ro" \
    -v "$FACTORY_DIR/logs:/workspace/logs" \
    factory-agent >/dev/null
  echo "Started $NAME"
done
