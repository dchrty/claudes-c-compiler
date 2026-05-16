#!/usr/bin/env bash
# Spin up N agent containers. Per-agent isolation:
#   - own /workspace (no cross-agent file visibility)
#   - shared /upstream bare repo as the only meeting point
#   - read-only /factory mount for scripts + config
#
# Auth: we mount the host user's CLI auth dir read-only into /factory_auth.
# entrypoint.sh copies it to the agent's $HOME so token refresh inside the
# container doesn't write back to the host (and parallel agents don't race
# on the host's auth file).
set -uo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$FACTORY_DIR/factory.yaml}"
AGENTS=$(yq -r '.agents' "$CONFIG")
KIND=$(yq -r '.agent.kind' "$CONFIG")

case "$KIND" in
  codex)        HOST_AUTH="$HOME/.codex" ;;
  claude-code)  HOST_AUTH="$HOME/.claude" ;;
  *) echo "Unknown agent.kind: $KIND" >&2; exit 2 ;;
esac

if [ ! -d "$HOST_AUTH" ]; then
  echo "Auth directory $HOST_AUTH not found." >&2
  echo "Log in on the host first (e.g. 'codex login' or 'claude login')." >&2
  exit 1
fi

mkdir -p "$FACTORY_DIR/logs"
RUN_PREFIX="factory-agent-$(date +%s)"

docker ps -a --filter "name=factory-agent-" -q | head -64 | xargs -r docker rm -f >/dev/null

for i in $(seq 1 "$AGENTS"); do
  NAME="${RUN_PREFIX}-${i}"
  docker run -d \
    --name "$NAME" \
    --memory 8g --cpus 2 \
    --restart unless-stopped \
    -e AGENT_ID="$i" \
    -e AGENT_KIND="$KIND" \
    -v "$HOST_AUTH:/factory_auth:ro" \
    -v "$FACTORY_DIR/upstream.git:/upstream" \
    -v "$FACTORY_DIR:/factory:ro" \
    -v "$FACTORY_DIR/logs:/workspace/logs" \
    factory-agent >/dev/null
  echo "Started $NAME"
done
