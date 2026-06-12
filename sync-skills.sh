#!/usr/bin/env bash
# Symlink every skill in this repo (any dir containing SKILL.md) into
# ~/.claude/skills, and prune links there that point into this repo but
# no longer resolve. Runs automatically via git hooks; safe to run by hand.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"

# Link each skill dir
for skill in "$REPO_DIR"/*/SKILL.md; do
  [ -e "$skill" ] || continue
  name="$(basename "$(dirname "$skill")")"
  target="$REPO_DIR/$name"
  link="$SKILLS_DIR/$name"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "skip: $link exists and is not a symlink" >&2
    continue
  fi
  ln -sfn "$target" "$link"
  echo "linked: $name"
done

# Prune dangling symlinks that point into this repo
for link in "$SKILLS_DIR"/*; do
  [ -L "$link" ] || continue
  dest="$(readlink "$link")"
  case "$dest" in
    *swagskills*) [ -e "$link" ] || { rm "$link"; echo "pruned: $(basename "$link")"; } ;;
  esac
done
