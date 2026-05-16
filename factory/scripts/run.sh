#!/usr/bin/env bash
# Top-level orchestrator: parse config, build image, init upstream, launch
# fleet, monitor until duration expires, then summarize.
set -euo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$FACTORY_DIR/factory.yaml}"

command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }
command -v yq >/dev/null || { echo "yq not found (install: https://github.com/mikefarah/yq)" >&2; exit 1; }

read_cfg() { yq -r "$1" "$CONFIG"; }

AGENTS=$(read_cfg '.agents')
DURATION=$(read_cfg '.duration')
EXTRA_APT=$(read_cfg '.toolchain.apt // [] | join(" ")')
INSTALL_RUST=$(read_cfg 'if .toolchain.rust then "true" else "" end')
RUST_TOOLCHAIN=$(read_cfg '.toolchain.rust // "stable"')
NODE_VERSION=$(read_cfg '.toolchain.node // "20"')

echo "==> Building agent image"
docker build \
  --build-arg EXTRA_APT="$EXTRA_APT" \
  --build-arg INSTALL_RUST="$INSTALL_RUST" \
  --build-arg RUST_TOOLCHAIN="$RUST_TOOLCHAIN" \
  --build-arg NODE_VERSION="$NODE_VERSION" \
  -t factory-agent \
  "$FACTORY_DIR"

echo "==> Initializing upstream.git"
"$FACTORY_DIR/scripts/init_repo.sh" "$CONFIG"

echo "==> Launching $AGENTS agents for $DURATION"
"$FACTORY_DIR/scripts/launch.sh" "$CONFIG"

# Convert duration ("2h", "30m", "120") to seconds.
case "$DURATION" in
  *h) SECONDS_LEFT=$(( ${DURATION%h} * 3600 )) ;;
  *m) SECONDS_LEFT=$(( ${DURATION%m} * 60 )) ;;
  *)  SECONDS_LEFT=$DURATION ;;
esac

echo "==> Monitoring (Ctrl-C to stop early)"
END=$(( $(date +%s) + SECONDS_LEFT ))
while [ "$(date +%s)" -lt "$END" ]; do
  sleep 300
  echo "--- $(date) ---"
  "$FACTORY_DIR/scripts/status.sh" --short "$CONFIG" || true
done

echo "==> Time up. Stopping agents (30s grace)"
docker ps --filter "name=factory-agent-" -q | xargs -r docker stop -t 30

echo "==> Final status"
"$FACTORY_DIR/scripts/status.sh" "$CONFIG"
