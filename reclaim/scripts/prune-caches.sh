#!/usr/bin/env bash
# Prune every package-manager cache with its own official command, measured.
#
# Each tool has a different incantation and several fail in ways worth noticing
# (a running process holding a lock, a subcommand that needs a project dir).
# Doing this by hand means rediscovering all of that every time.
#
# Uses each tool's own prune where one exists, because those preserve what is
# still referenced. Falls back to rm only where the tool offers nothing.
#
#   usage: prune-caches.sh              # DRY RUN: show sizes and commands
#          prune-caches.sh --apply      # actually prune, measuring the df delta
#          prune-caches.sh --apply --only bun,uv
#
# Note on APFS: caches are frequently clone-shared with live node_modules and
# venvs, so a 14 GB cache can free 8 GB, or 0. The measured total at the end is
# the only number worth quoting.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --only)  ONLY="$2"; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

VOL="${RECLAIM_VOL:-/System/Volumes/Data}"; [ -d "$VOL" ] || VOL=/
free_kb() { df -k "$VOL" | awk 'NR==2 {print $4}'; }
mb() { [ -e "$1" ] || { echo 0; return; }; du -sm -x "$1" 2>/dev/null | awk 'NR==1{print $1}'; }

wants() { [ -z "$ONLY" ] && return 0; case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

# name | probe path | command
run_one() {
  local name="$1" path="$2" cmd="$3"
  wants "$name" || return 0
  local size; size=$(mb "$path")
  [ "${size:-0}" -eq 0 ] && return 0

  if [ "$APPLY" = "0" ]; then
    printf '  %-14s %6s MB apparent   %s\n' "$name" "$size" "$cmd"
    return 0
  fi

  printf '  %-14s %6s MB apparent ... ' "$name" "$size"
  local out; out=$(sh -c "$cmd" 2>&1); local rc=$?
  if [ $rc -ne 0 ]; then
    printf 'FAILED\n'
    # Surface the useful part of the failure rather than swallowing it: a held
    # lock is the single most common cause and it names the culprit process.
    echo "$out" | grep -iE 'lock|another|running|denied|not found' | head -2 | sed 's/^/      /'
    if echo "$out" | grep -qi 'lock'; then
      local holder; holder=$(pgrep -fl "$name" 2>/dev/null | head -1)
      [ -n "$holder" ] && echo "      holder: $holder"
      echo "      -> stop that process, then re-run --only $name"
    fi
  else
    printf 'ok\n'
  fi
}

echo "════════ package manager caches ════════"
[ "$APPLY" = "0" ] && echo "(DRY RUN — re-run with --apply to prune)"
echo

before=$(free_kb)

run_one bun    "$HOME/.bun/install/cache"      'bun pm cache rm 2>/dev/null || rm -rf "$HOME/.bun/install/cache"'
run_one uv     "$HOME/.cache/uv"               'UV_LOCK_TIMEOUT=30 uv cache prune'
run_one pip    "$HOME/Library/Caches/pip"      'pip3 cache purge || pip cache purge'
run_one brew   "$HOME/Library/Caches/Homebrew" 'brew cleanup --prune=all'
run_one pnpm   "$HOME/Library/pnpm/store"      'pnpm store prune'
run_one npm    "$HOME/.npm/_cacache"           'npm cache clean --force'
run_one npx    "$HOME/.npm/_npx"               'rm -rf "$HOME/.npm/_npx"'
run_one precommit "$HOME/.cache/pre-commit"    'pre-commit gc'
run_one go     "$HOME/go/pkg/mod"              'go clean -modcache'
run_one cargo  "$HOME/.cargo/registry/cache"   'rm -rf "$HOME/.cargo/registry/cache"'
run_one gradle "$HOME/.gradle/caches"          'rm -rf "$HOME/.gradle/caches"'
run_one swiftpm "$HOME/Library/Caches/org.swift.swiftpm" 'rm -rf "$HOME/Library/Caches/org.swift.swiftpm"'
run_one cocoapods "$HOME/Library/Caches/CocoaPods" 'rm -rf "$HOME/Library/Caches/CocoaPods"'

if [ "$APPLY" = "1" ]; then
  sleep 2
  after=$(free_kb)
  echo
  awk -v d="$((after - before))" 'BEGIN {
    printf "MEASURED TOTAL RECLAIMED: %s%.2f GB\n", (d<0?"-":""), (d<0?-d:d)/1048576
  }'
  echo "(apparent sums are always larger — clones share blocks)"
else
  echo
  echo "Playwright/puppeteer browsers are handled separately:"
  echo "  $HERE/browser-prune.sh"
fi
