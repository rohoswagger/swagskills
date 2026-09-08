#!/usr/bin/env bash
# Ranked survey of the usual disk hoards.
#
# Ground truth (df) comes first. Everything after it is an APPARENT size from
# `du`, which over-reports copy-on-write clones on APFS — treat those numbers
# as upper bounds and confirm with scripts/measure.sh when you delete.
#
# Deliberately avoids a whole-disk `du`: that takes many minutes and buries the
# answer in noise. Instead it probes where space actually accumulates, running
# the expensive directory scans in parallel.
#
#   usage: survey.sh              # standard survey (~1 min)
#          survey.sh --deep       # also scan for nested build dirs (slower)
set -uo pipefail

DEEP=0
[ "${1:-}" = "--deep" ] && DEEP=1

VOL="${RECLAIM_VOL:-/System/Volumes/Data}"
[ -d "$VOL" ] || VOL=/

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
EXPLICIT="$WORK/explicit"   # curated entries, with prune commands — win on dedupe
GLOB="$WORK/glob"           # discovered entries
: > "$EXPLICIT"; : > "$GLOB"

MIN_MB=${RECLAIM_MIN_MB:-100}

# Rows are: size_mb \t class \t path \t label
# Dedupe keys on path, so a curated row suppresses the generic discovery of it.

emit() {  # emit <file> <class> <path> <label>
  local out="$1" cls="$2" p="$3" label="$4" s
  [ -e "$p" ] || return 0
  s=$(du -sm -x "$p" 2>/dev/null | awk 'NR==1{print $1}')
  [ -z "${s:-}" ] && return 0
  [ "$s" -lt "$MIN_MB" ] && return 0
  printf '%s\t%s\t%s\t%s\n' "$s" "$cls" "$p" "$label" >> "$out"
}

echo "════════ GROUND TRUTH (df) ════════"
df -h "$VOL" | awk 'NR==1 || NR==2'
echo
echo "Everything below is APPARENT size (du) — an upper bound."
echo "Verify every deletion with scripts/measure.sh."
echo
echo "scanning (parallel)..." >&2

# ---- big directory scans, in parallel (these dominate wall time) -----------
{
  du -sm -x "$HOME"/* 2>/dev/null | sort -rn | head -8 | while IFS=$'\t' read -r s p; do
    [ "${s:-0}" -ge 2000 ] && printf '%s\tCHECK\t%s\t%s  [top-level]\n' "$s" "$p" "$p"
  done
} > "$WORK/g1" &
P1=$!
{
  du -sm -x "$HOME"/Library/Caches/* 2>/dev/null | sort -rn | head -10 | while IFS=$'\t' read -r s p; do
    [ "${s:-0}" -ge 400 ] && printf '%s\tREGEN\t%s\t%s  [app cache]\n' "$s" "$p" "$p"
  done
} > "$WORK/g2" &
P2=$!
{
  du -sm -x "$HOME"/Library/Application\ Support/* 2>/dev/null | sort -rn | head -8 | while IFS=$'\t' read -r s p; do
    [ "${s:-0}" -ge 500 ] && printf '%s\tCHECK\t%s\t%s  [app state — check first]\n' "$s" "$p" "$p"
  done
} > "$WORK/g3" &
P3=$!

{
  du -sm -x "$HOME"/.cache/* 2>/dev/null | sort -rn | head -10 | while IFS=$'\t' read -r s p; do
    [ "${s:-0}" -ge 400 ] && printf '%s\tREGEN\t%s\t%s  [XDG cache]\n' "$s" "$p" "$p"
  done
} > "$WORK/g4" &
P4=$!

# ---- curated probes (cheap; each is one stat'able path) ---------------------

# container / VM images: usually the single biggest item
for f in \
  "$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw" \
  "$HOME/.docker/desktop/vms/0/data/Docker.raw" \
  "$HOME/.colima" "$HOME/.lima" "$HOME/.orbstack"
do emit "$EXPLICIT" REGEN-CHECK "$f" "$(basename "$f")  [container/VM image — see references/docker.md]"; done
emit "$EXPLICIT" STATEFUL "$HOME/Library/Containers/com.utmapp.UTM" "UTM VMs  [STATEFUL]"

# build output — regenerable
emit "$EXPLICIT" REGEN "$HOME/Library/Developer/Xcode/DerivedData"        "Xcode DerivedData"
emit "$EXPLICIT" REGEN "$HOME/Library/Developer/Xcode/iOS DeviceSupport"  "Xcode iOS DeviceSupport"
emit "$EXPLICIT" REGEN "$HOME/Library/Developer/CoreSimulator/Caches"     "CoreSimulator Caches"
emit "$EXPLICIT" STATEFUL "$HOME/Library/Developer/CoreSimulator/Devices" "Simulator Devices  [STATEFUL]"

# package manager caches — regenerable, but often clone-shared with live trees
emit "$EXPLICIT" REGEN "$HOME/.bun/install/cache"               "bun cache            [bun pm cache rm]"
emit "$EXPLICIT" REGEN "$HOME/.cache/uv"                        "uv cache             [uv cache prune]"
emit "$EXPLICIT" REGEN "$HOME/Library/Caches/pip"               "pip cache            [pip cache purge]"
emit "$EXPLICIT" REGEN "$HOME/Library/Caches/Homebrew"          "Homebrew cache       [brew cleanup --prune=all]"
emit "$EXPLICIT" REGEN "$HOME/Library/Caches/pnpm"              "pnpm cache           [pnpm store prune]"
emit "$EXPLICIT" REGEN "$HOME/Library/pnpm/store"               "pnpm store           [pnpm store prune]"
emit "$EXPLICIT" REGEN "$HOME/.npm/_cacache"                    "npm cache            [npm cache clean --force]"
emit "$EXPLICIT" REGEN "$HOME/.npm/_npx"                        "npx cache            [rm -rf ~/.npm/_npx]"
emit "$EXPLICIT" REGEN "$HOME/.cache/pre-commit"                "pre-commit envs      [pre-commit gc]"
emit "$EXPLICIT" REGEN "$HOME/.cache/puppeteer"                 "puppeteer browsers   [keep newest]"
emit "$EXPLICIT" REGEN "$HOME/go/pkg/mod"                       "go module cache      [go clean -modcache]"
emit "$EXPLICIT" REGEN "$HOME/.cargo/registry"                  "cargo registry"
emit "$EXPLICIT" REGEN "$HOME/.gradle/caches"                   "gradle caches"
emit "$EXPLICIT" REGEN "$HOME/Library/Caches/ms-playwright"     "Playwright browsers  [keep newest of each]"
emit "$EXPLICIT" REGEN "$HOME/Library/Caches/org.swift.swiftpm" "SwiftPM cache"
emit "$EXPLICIT" REGEN "$HOME/Library/Caches/CocoaPods"         "CocoaPods cache"

# ---- nested build dirs (deep mode) -----------------------------------------
if [ "$DEEP" = "1" ]; then
  echo "  deep scan: nested build dirs..." >&2
  for root in "$HOME/Documents" "$HOME/Developer" "$HOME/src" "$HOME/code" "$HOME/repos" "$HOME/projects"; do
    [ -d "$root" ] || continue
    find "$root" -maxdepth 6 -type d \
      \( -name .build -o -name target -o -name DerivedData -o -name .next \
         -o -name .mypy_cache -o -name .turbo -o -name .gradle \) -prune 2>/dev/null
  done | while read -r d; do
    emit "$GLOB" REGEN "$d" "$d  [build output]"
  done
fi

wait $P1 $P2 $P3 $P4 2>/dev/null
cat "$WORK"/g1 "$WORK"/g2 "$WORK"/g3 "$WORK"/g4 >> "$GLOB" 2>/dev/null

# ---- ranked output, deduped by path (curated rows first so they win) -------
echo "════════ RANKED (apparent MB) ════════"
if [ -s "$EXPLICIT" ] || [ -s "$GLOB" ]; then
  cat "$EXPLICIT" "$GLOB" \
    | awk -F'\t' '!seen[$3]++' \
    | sort -t$'\t' -k1,1rn \
    | awk -F'\t' '{
        if ($1 >= 1024) printf "  %8.1f GB  %-12s %s\n", $1/1024, $2, $4;
        else            printf "  %8d MB  %-12s %s\n", $1, $2, $4;
      }'
else
  echo "  (nothing above ${MIN_MB} MB — disk pressure may be outside \$HOME)"
fi

cat <<'EOF'

  REGEN        regenerable — delete without asking
  REGEN-CHECK  regenerable content, but may hold volumes/state; inspect first
  STATEFUL     non-reproducible state — confirm with the user
  CHECK        mixed; look before deleting

════════ macOS traps ════════
EOF
snap=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple' || true)
echo "  APFS local snapshots: ${snap:-0}  (can pin space you just freed)"
if pgrep -qf MacUpdateBrain 2>/dev/null; then
  echo "  ⚠ macOS update staging (MacUpdateBrain) — consumes GB and will fight"
  echo "    your cleanup; expect free space to move unpredictably."
fi
if command -v docker >/dev/null 2>&1; then
  echo "  Docker present — read references/docker.md before pruning."
fi
holder=$(pgrep -fl 'uv ' 2>/dev/null | head -1)
[ -n "${holder:-}" ] && echo "  uv process running (holds the cache lock): $holder"

cat <<'EOF'

════════ next ════════
  1. Form a hypothesis about the top 3 before deleting anything.
  2. Classify each: regenerable / stateful / active (by mtime, not name).
  3. Delete via:  scripts/measure.sh --paths <path> [path...]
  4. Report the df delta, never du.
EOF
