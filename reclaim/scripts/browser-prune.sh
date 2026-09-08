#!/usr/bin/env bash
# Keep only the newest version of each Playwright/Puppeteer browser.
#
# These tools never garbage-collect: every version they have ever downloaded
# stays forever. A real machine held 7 chromium builds plus 7 headless shells —
# 4.7 GB where 1.6 GB was needed. The versions are suffixed integers
# (chromium-1200 ... chromium-1237), so "keep the highest per family" is exact
# and safe, which is what makes this worth scripting rather than eyeballing.
#
# Browser *profile* directories (mcp-chrome-*, and anything holding a logged-in
# session) are deliberately never touched — they are state, not cache.
#
#   usage: browser-prune.sh              # DRY RUN
#          browser-prune.sh --apply
#          browser-prune.sh --keep 2 --apply     # keep newest N per family
set -uo pipefail

APPLY=0; KEEP=1
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --keep)  KEEP="$2"; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

VOL="${RECLAIM_VOL:-/System/Volumes/Data}"; [ -d "$VOL" ] || VOL=/
free_kb() { df -k "$VOL" | awk 'NR==2 {print $4}'; }

DIRS=("$HOME/Library/Caches/ms-playwright" "$HOME/.cache/ms-playwright"
      "$HOME/.cache/puppeteer" "$HOME/Library/Caches/puppeteer")

before=$(free_kb)
victims=()

for root in "${DIRS[@]}"; do
  [ -d "$root" ] || continue
  echo "── $root"

  # Family = name with the trailing -<digits> removed. Only versioned dirs are
  # candidates; anything without a numeric suffix is left alone by construction,
  # which is what protects the profile dirs.
  families=$(find "$root" -maxdepth 1 -mindepth 1 -type d 2>/dev/null \
    | while read -r d; do
        b=$(basename "$d")
        case "$b" in
          *-[0-9]|*-[0-9][0-9]|*-[0-9][0-9][0-9]|*-[0-9][0-9][0-9][0-9]|*-[0-9][0-9][0-9][0-9][0-9])
            echo "${b%-*}" ;;
        esac
      done | sort -u)

  if [ -z "$families" ]; then echo "   (no versioned browser dirs)"; echo; continue; fi

  for fam in $families; do
    # Sort numerically on the version suffix so 1237 > 1200 (lexical sort fails).
    vers=()
    while IFS= read -r line; do vers+=("$line"); done < <(
      find "$root" -maxdepth 1 -mindepth 1 -type d -name "${fam}-*" 2>/dev/null \
      | while read -r d; do printf '%s\t%s\n' "$(basename "$d" | sed 's/.*-//')" "$d"; done \
      | sort -rn | cut -f2)
    total=${#vers[@]}
    [ "$total" -le "$KEEP" ] && { printf '   %-34s %d version, keeping all\n' "$fam" "$total"; continue; }
    printf '   %-34s %d versions -> keep %d\n' "$fam" "$total" "$KEEP"
    i=0
    for d in "${vers[@]}"; do
      i=$((i+1))
      sz=$(du -sm -x "$d" 2>/dev/null | awk '{print $1}')
      if [ "$i" -le "$KEEP" ]; then
        printf '        KEEP   %6s MB  %s\n' "${sz:-?}" "$(basename "$d")"
      else
        printf '        prune  %6s MB  %s\n' "${sz:-?}" "$(basename "$d")"
        victims+=("$d")
      fi
    done
  done
  echo

  # Report, never remove: these can hold live logged-in sessions.
  profiles=$(find "$root" -maxdepth 1 -mindepth 1 -type d -name 'mcp-chrome*' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${profiles:-0}" -gt 0 ]; then
    psz=$(du -sm -x "$root"/mcp-chrome* 2>/dev/null | awk '{s+=$1} END{print s}')
    printf '   NOT touching %s browser profile dir(s) (~%s MB) — may hold live logins\n\n' "$profiles" "${psz:-?}"
  fi
done

if [ "${#victims[@]}" -eq 0 ]; then echo "nothing to prune."; exit 0; fi

if [ "$APPLY" = "0" ]; then
  echo "(DRY RUN) would remove ${#victims[@]} dir(s). Re-run with --apply."
  exit 0
fi

for d in "${victims[@]}"; do rm -rf -- "$d" && echo "removed $(basename "$d")"; done
sleep 2
after=$(free_kb)
awk -v d="$((after - before))" 'BEGIN {
  printf "\nMEASURED RECLAIMED: %s%.2f GB\n", (d<0?"-":""), (d<0?-d:d)/1048576
}'
