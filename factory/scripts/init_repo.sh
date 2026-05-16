#!/usr/bin/env bash
# Initialize the shared upstream.git bare repo from the seed.
# This is the only place files originate; all agents clone from here.
set -euo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$FACTORY_DIR/factory.yaml}"
UPSTREAM="$FACTORY_DIR/upstream.git"
SEED=$(yq -r '.seed_repo' "$CONFIG")

if [ -d "$UPSTREAM" ]; then
  echo "upstream.git already exists; reusing. Delete it to start fresh."
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [[ "$SEED" =~ ^https?:// || "$SEED" =~ ^git@ ]]; then
  git clone --depth 1 "$SEED" "$WORK/seed"
else
  cp -r "$SEED" "$WORK/seed"
fi

# Render CLAUDE.md from template, substituting target description and gate.
TARGET=$(yq -r '.target' "$CONFIG")
GATE_TYPE=$(yq -r '.gate.type' "$CONFIG")
case "$GATE_TYPE" in
  shell) GATE_DESC="Run: $(yq -r '.gate.cmd' "$CONFIG")" ;;
  judge) GATE_DESC="LLM judge: $(yq -r '.gate.criteria' "$CONFIG")" ;;
esac

export TARGET GATE_DESC
envsubst < "$FACTORY_DIR/CLAUDE.md.template" > "$WORK/seed/CLAUDE.md"

# Create coordination dirs the agents will use.
mkdir -p "$WORK/seed/current_tasks" "$WORK/seed/ideas"
touch "$WORK/seed/current_tasks/.keep" "$WORK/seed/ideas/.keep"

cd "$WORK/seed"
git init -q -b main
git add -A
git commit -q -m "Factory seed"

git init --bare "$UPSTREAM"
git remote add upstream "$UPSTREAM"
git push -q upstream main

echo "Initialized $UPSTREAM"
