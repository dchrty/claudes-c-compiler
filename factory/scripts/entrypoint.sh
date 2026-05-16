#!/usr/bin/env bash
# Per-agent loop. The worker is whatever CLI agent factory.yaml selects;
# we never know or care here. Same goes for the judge — gate.sh handles it.
set -uo pipefail

AGENT_ID="${AGENT_ID:-unknown}"
LOG="/workspace/logs/agent-${AGENT_ID}.log"
mkdir -p /workspace/logs
exec > >(tee -a "$LOG") 2>&1

save_work() {
  echo "[agent $AGENT_ID] caught signal, attempting WIP save"
  cd /workspace/code 2>/dev/null || exit 0
  pkill -TERM -f 'codex|claude' 2>/dev/null || true
  sleep 2
  git add -A 2>/dev/null
  git commit -q -m "WIP: agent $AGENT_ID interrupted" 2>/dev/null || true
  git pull --rebase upstream main 2>/dev/null || true
  git push upstream main 2>/dev/null || true
  exit 0
}
trap save_work TERM INT

PROMPT='Read CLAUDE.md for your full instructions, then start working.
Pick or claim a task, implement it, and before pushing run the gate by
invoking /factory/scripts/gate.sh — trust its verdict.'

while true; do
  echo "[agent $AGENT_ID] === new cycle ==="
  rm -rf /workspace/code
  git clone -q /upstream /workspace/code
  cd /workspace/code
  git remote add upstream /upstream 2>/dev/null || git remote set-url upstream /upstream

  /factory/scripts/run_agent.sh "$PROMPT" /workspace/code || true

  sleep 2
done
