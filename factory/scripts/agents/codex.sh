#!/usr/bin/env bash
# Codex CLI adapter.
#
# Contract: $1 = prompt, $2 = working directory.
# Runs a single fresh codex session in $2. No state shared with previous
# invocations beyond the filesystem in $2.
#
# NOTE: exact codex CLI flags may differ between versions — verify with
# `codex --help`. The stable surface we depend on is "non-interactive
# headless invocation that takes a prompt and exits."
set -uo pipefail
PROMPT="$1"
WORKDIR="$2"
cd "$WORKDIR"

# Adjust if your codex version uses a different headless flag.
codex exec "$PROMPT"
