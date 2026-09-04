#!/usr/bin/env bash
# Symlink every skill in ~/.agents/skills into ~/.codex/skills and
# ~/.claude/skills. Prune managed links whose source no longer exists.
# Safe to run repeatedly or by hand.
set -euo pipefail

SOURCE_DIR="$HOME/.agents/skills"
SKILLS_DIRS=("$HOME/.codex/skills" "$HOME/.claude/skills")
BACKUP_DIR="$HOME/.agents/skill-sync-backups"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "error: source directory does not exist: $SOURCE_DIR" >&2
  exit 1
fi

for skills_dir in "${SKILLS_DIRS[@]}"; do
  mkdir -p "$skills_dir"

  for skill in "$SOURCE_DIR"/*/SKILL.md; do
    [ -e "$skill" ] || continue
    name="$(basename "$(dirname "$skill")")"
    target="$SOURCE_DIR/$name"
    link="$skills_dir/$name"
    if [ -e "$link" ] && [ ! -L "$link" ]; then
      client="$(basename "$(dirname "$skills_dir")")"
      backup="$BACKUP_DIR/$client/$name.$(date +%Y%m%dT%H%M%S%N)"
      mkdir -p "$(dirname "$backup")"
      mv "$link" "$backup"
      echo "backed up: $link -> $backup"
    fi
    ln -sfn "$target" "$link"
    echo "linked: $link -> $target"
  done

  for link in "$skills_dir"/*; do
    [ -L "$link" ] || continue
    dest="$(readlink "$link")"
    case "$dest" in
      "$SOURCE_DIR"/*)
        [ -e "$link" ] || { rm "$link"; echo "pruned: $link"; }
        ;;
    esac
  done
done
