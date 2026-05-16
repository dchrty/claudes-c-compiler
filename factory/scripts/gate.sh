#!/usr/bin/env bash
# Gate contract:
#   - exit 0 = pass, exit 1 = fail
#   - stderr = human-readable feedback for the worker
#
# For type=judge, isolation is structural:
#   * brand-new agent session (own process, no shared CLI history)
#   * sandboxed tmpdir that contains ONLY criteria.txt + diff.patch
#   * the judge has no view of the worker's repo, prompt, or tools beyond
#     what we hand it explicitly
#   * verdict is read from a file the judge writes — pure file IPC
set -uo pipefail

CONFIG="${1:-/factory/factory.yaml}"
WORKSPACE="${2:-/workspace/code}"
TYPE=$(yq -r '.gate.type' "$CONFIG")

case "$TYPE" in
  shell)
    CMD=$(yq -r '.gate.cmd' "$CONFIG")
    OUT=$(cd "$WORKSPACE" && bash -c "$CMD" 2>&1)
    RC=$?
    echo "$OUT" >&2
    exit $RC
    ;;

  judge)
    CRITERIA=$(yq -r '.gate.criteria' "$CONFIG")
    SANDBOX=$(mktemp -d)
    trap 'rm -rf "$SANDBOX"' EXIT

    # Diff against upstream/main = the change being proposed for landing.
    git -C "$WORKSPACE" diff upstream/main -- . \
        ':(exclude)current_tasks' ':(exclude)ideas' \
        > "$SANDBOX/diff.patch"

    if ! [ -s "$SANDBOX/diff.patch" ]; then
      echo "No changes to evaluate." >&2
      exit 1
    fi

    printf '%s\n' "$CRITERIA" > "$SANDBOX/criteria.txt"

    # The judge's whole world is this tmpdir. It writes verdict.json, exits.
    PROMPT='You are an isolated reviewer. You can see two files:
  criteria.txt - what this change must satisfy
  diff.patch   - the proposed change (against upstream/main)

You have no other context. The author of this change cannot argue with you.

Decide pass or fail. Write your verdict to verdict.json with this exact shape
on a single line:

  {"pass": <true|false>, "feedback": "<actionable text; if pass briefly say why; if fail say exactly what to fix>"}

Then exit. Do not modify any other files.'

    FACTORY_CONFIG="$CONFIG" /factory/scripts/run_agent.sh "$PROMPT" "$SANDBOX" >&2

    if ! [ -f "$SANDBOX/verdict.json" ]; then
      echo "Judge produced no verdict.json — failing closed." >&2
      exit 1
    fi

    PASS=$(jq -r '.pass' "$SANDBOX/verdict.json")
    FEEDBACK=$(jq -r '.feedback' "$SANDBOX/verdict.json")
    echo "$FEEDBACK" >&2
    [ "$PASS" = "true" ] && exit 0 || exit 1
    ;;

  *)
    echo "Unknown gate type: $TYPE" >&2
    exit 2
    ;;
esac
