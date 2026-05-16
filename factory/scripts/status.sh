#!/usr/bin/env bash
# Quick observability. Mirrors ACF's status.sh shape but project-agnostic:
# we don't know the file extensions or build command, so we report git
# activity, agent presence, and active tasks/ideas only.
set -uo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHORT=""
[ "${1:-}" = "--short" ] && { SHORT=1; shift; }
CONFIG="${1:-$FACTORY_DIR/factory.yaml}"
UPSTREAM="$FACTORY_DIR/upstream.git"

[ -d "$UPSTREAM" ] || { echo "no upstream.git yet"; exit 0; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
git clone -q "$UPSTREAM" "$WORK/peek"
cd "$WORK/peek"

COMMITS=$(git rev-list --count HEAD)
RUNNING=$(docker ps --filter "name=factory-agent-" -q | wc -l | tr -d ' ')

if [ -n "$SHORT" ]; then
  echo "commits=$COMMITS  running_agents=$RUNNING"
  exit 0
fi

echo "=== fleet ==="
docker ps --filter "name=factory-agent-" --format "  {{.Names}}  up {{.RunningFor}}"
echo ""
echo "=== upstream.git ==="
echo "  commits: $COMMITS"
echo "  recent:"
git log --oneline -10 | sed 's/^/    /'
echo ""
echo "=== current tasks ==="
ls current_tasks/ 2>/dev/null | grep -v '^\.keep$' | sed 's/^/  /' || echo "  (none)"
echo ""
echo "=== ideas backlog ==="
ls ideas/ 2>/dev/null | grep -v '^\.keep$' | sed 's/^/  /' || echo "  (none)"
