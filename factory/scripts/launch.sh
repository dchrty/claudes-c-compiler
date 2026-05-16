#!/usr/bin/env bash
# Spin up N agent containers. Each gets:
#   - upstream.git mounted RW (the coordination layer)
#   - factory/ mounted RO  (scripts + config the entrypoint reads)
#   - logs/ mounted RW     (per-agent transcript)
set -euo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$FACTORY_DIR/factory.yaml}"
AGENTS=$(yq -r '.agents' "$CONFIG")

mkdir -p "$FACTORY_DIR/logs"
RUN_PREFIX="factory-agent-$(date +%s)"

# Clean up any leftover agent containers from previous runs in this dir.
docker ps -a --filter "name=factory-agent-" -q | head -64 | xargs -r docker rm -f >/dev/null

for i in $(seq 1 "$AGENTS"); do
  NAME="${RUN_PREFIX}-${i}"
  docker run -d \
    --name "$NAME" \
    --memory 8g --cpus 2 \
    --restart unless-stopped \
    -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    -e AGENT_ID="$i" \
    -v "$FACTORY_DIR/upstream.git:/upstream" \
    -v "$FACTORY_DIR:/factory:ro" \
    -v "$FACTORY_DIR/logs:/workspace/logs" \
    factory-agent >/dev/null
  echo "Started $NAME"
done
