#!/usr/bin/env bash
# Run a command and report the space it ACTUALLY reclaimed, from the df delta.
#
# Why this exists: on APFS, `du` charges every copy-on-write clone the full
# logical size, so it over-reports shared blocks — sometimes by 20x. The only
# honest measure of a deletion is how much free space the volume gained.
#
#   usage: measure.sh '<shell command>' [more commands...]
#          measure.sh --paths <path> [path...]     # rm -rf each, measured together
#
#   RECLAIM_VOL=/  measure.sh ...                  # override volume to measure
#
# Exit status is the first non-zero status of the commands run, so failures
# still surface instead of hiding behind a clean-looking measurement.
set -uo pipefail

VOL="${RECLAIM_VOL:-/System/Volumes/Data}"
[ -d "$VOL" ] || VOL=/

free_kb() { df -k "$VOL" 2>/dev/null | awk 'NR==2 {print $4}'; }

human() {
  # signed KB -> human, preserving sign (free space can legitimately go down)
  awk -v kb="$1" 'BEGIN {
    s = (kb < 0) ? "-" : ""; a = (kb < 0) ? -kb : kb;
    if (a >= 1048576) printf "%s%.2f GB", s, a/1048576;
    else if (a >= 1024) printf "%s%.1f MB", s, a/1024;
    else printf "%s%d KB", s, a;
  }'
}

if [ "$#" -eq 0 ]; then
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

# --paths mode: build `rm -rf` commands for existing paths only.
cmds=()
if [ "$1" = "--paths" ]; then
  shift
  for p in "$@"; do
    if [ -e "$p" ]; then
      cmds+=("rm -rf -- '${p//\'/\'\\\'\'}'")
    else
      printf '  skip (missing): %s\n' "$p" >&2
    fi
  done
  if [ "${#cmds[@]}" -eq 0 ]; then
    echo "nothing to do: no listed paths exist" >&2
    exit 0
  fi
else
  cmds=("$@")
fi

before=$(free_kb)
if [ -z "$before" ]; then
  echo "error: could not read free space for $VOL" >&2
  exit 1
fi
printf 'free before:  %s\n' "$(human "$before")"

rc=0
for c in "${cmds[@]}"; do
  printf '  run: %s\n' "$c"
  sh -c "$c"
  s=$?
  [ "$s" -ne 0 ] && { printf '  ^ exited %d\n' "$s" >&2; [ "$rc" -eq 0 ] && rc=$s; }
done

# APFS accounting settles asynchronously; a brief pause keeps the delta honest.
sleep 2
after=$(free_kb)

printf 'free after:   %s\n' "$(human "$after")"
printf 'RECLAIMED:    %s\n' "$(human "$((after - before))")"

if [ "$((after - before))" -lt 0 ]; then
  cat >&2 <<'EOF'

  note: free space went DOWN. That is usually not your deletion failing —
  something else is writing concurrently (a staging macOS update, a container
  VM, Spotlight reindexing), or the bytes you deleted were clones sharing
  blocks with files that still exist. Check `tmutil listlocalsnapshots /` and
  for a MacUpdateBrain process before concluding anything went wrong.
EOF
fi

exit "$rc"
