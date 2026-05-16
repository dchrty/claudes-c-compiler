#!/usr/bin/env bash
# The single contract every gate honors:
#   - Exit code: 0 = pass, 1 = fail
#   - stdout: human-readable feedback (the worker reads this)
# This is what the worker agent invokes from inside its own claude session;
# its trust is in this script, not in itself.
#
# For type=judge, isolation is enforced here: a brand-new Anthropic API call
# with zero shared context, only the diff and the criteria. The worker has
# no way to bias the judge through its own conversation history.
set -uo pipefail

CONFIG="${1:-/factory/factory.yaml}"
WORKSPACE="${2:-/workspace/code}"
TYPE=$(yq -r '.gate.type' "$CONFIG")

case "$TYPE" in
  shell)
    CMD=$(yq -r '.gate.cmd' "$CONFIG")
    OUT=$(cd "$WORKSPACE" && bash -c "$CMD" 2>&1)
    RC=$?
    echo "$OUT"
    exit $RC
    ;;

  judge)
    # judge.py prints feedback to stderr (so the worker sees it) and exits
    # 0/1 based on the verdict. Runs in an entirely separate Anthropic API
    # session — the judge never sees the worker's prompt or transcript.
    python3 /factory/scripts/judge.py "$CONFIG" "$WORKSPACE"
    exit $?
    ;;

  *)
    echo "Unknown gate type: $TYPE" >&2
    exit 2
    ;;
esac
