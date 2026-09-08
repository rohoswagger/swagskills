#!/usr/bin/env bash
# Audit every git worktree for uncommitted/unpushed work before you delete anything.
#
# This is the safety check that matters most. Worktrees look like pure duplication
# — eleven copies of the same repo, each with its own 2 GB venv — so a size-ranked
# cleanup targets them immediately. But uncommitted work is invisible to `du`,
# unrecoverable once deleted, and routinely present: a real audit found 12
# uncommitted files in one worktree and 64 in another, both of which a
# size-driven plan had marked for removal because their branches were merged.
#
# "Merged into main" does NOT mean "safe to delete". Merge status describes
# commits; it says nothing about the working tree.
#
#   usage: worktree-audit.sh [repo-or-search-root ...]
#          worktree-audit.sh                 # scans common code roots
#          worktree-audit.sh --days 30       # staleness threshold (default 30)
#
# Read-only: runs no command that changes any repository.
set -uo pipefail

DAYS=30
ROOTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ROOTS+=("$1") ;;
  esac
  shift
done
if [ "${#ROOTS[@]}" -eq 0 ]; then
  for d in "$HOME/Documents" "$HOME/Developer" "$HOME/src" "$HOME/code" "$HOME/repos" "$HOME/projects"; do
    [ -d "$d" ] && ROOTS+=("$d")
  done
fi

now=$(date +%s)
SAFE=0; RISK=0; ACTIVE=0

echo "════════ git worktree audit (stale = untouched > ${DAYS}d) ════════"
echo

# Find repos, then enumerate their worktrees. Enumerating from the repo keeps
# worktrees registered elsewhere on disk (a common layout) in scope.
for root in "${ROOTS[@]}"; do
  find "$root" -maxdepth 4 -type d -name .git -prune 2>/dev/null | while read -r gitdir; do
    repo="$(dirname "$gitdir")"
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    # Only report repos that actually have linked worktrees.
    count=$(git -C "$repo" worktree list 2>/dev/null | wc -l | tr -d ' ')
    [ "${count:-0}" -le 1 ] && continue

    repo_stash=$(git -C "$repo" stash list 2>/dev/null | wc -l | tr -d ' ')
    if [ "${repo_stash:-0}" -gt 0 ]; then
      echo "── $repo  ($((count-1)) linked worktree(s))  [$repo_stash repo-level stash(es), shared]"
    else
      echo "── $repo  ($((count-1)) linked worktree(s))"
    fi
    git -C "$repo" worktree list --porcelain 2>/dev/null \
      | awk '/^worktree /{print substr($0,10)}' \
      | while read -r wt; do
        [ -d "$wt" ] || { printf '   %-46s MISSING (prunable: git worktree prune)\n' "$(basename "$wt")"; continue; }

        branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
        dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        untracked=$(git -C "$wt" status --porcelain 2>/dev/null | grep -c '^??' || true)
        unpushed=$(git -C "$wt" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')
        age=$(( (now - $(stat -f %m "$wt" 2>/dev/null || echo "$now")) / 86400 ))

        merged=no
        if git -C "$wt" merge-base --is-ancestor HEAD origin/HEAD 2>/dev/null \
           || git -C "$wt" merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
          merged=yes
        fi

        verdict="SAFE"
        if [ "${dirty:-0}" -gt 0 ] || [ "${unpushed:-0}" -gt 0 ]; then
          verdict="HOLDS WORK"
        elif [ "$age" -lt "$DAYS" ]; then
          verdict="ACTIVE(${age}d)"
        fi

        printf '   %-40s %-26s %s\n' "$(basename "$wt")" "[$branch]" "$verdict"
        [ "${dirty:-0}" -gt 0 ]    && printf '        uncommitted: %s file(s) (%s untracked)\n' "$dirty" "${untracked:-0}"
        [ "${unpushed:-0}" -gt 0 ] && printf '        unpushed commits: %s\n' "$unpushed"
        [ "$verdict" = "SAFE" ] && printf '        idle %sd, merged=%s\n' "$age" "$merged"
      done
    echo
  done
done

cat <<EOF
════════ how to read this ════════
  HOLDS WORK   do NOT delete. Uncommitted or unpushed changes are
               unrecoverable and invisible to du. Report to the user.
  stashes      shown per REPO, not per worktree: git stores them in refs/stash
               which every worktree shares, so they do not tell you which
               worktree is unsafe. Check them before deleting the last
               worktree of a repo.
  ACTIVE(Nd)   touched within ${DAYS}d — someone's current branch. Leave it,
               and say you left it.
  SAFE         clean tree, idle > ${DAYS}d. Deletion candidate.

  Even for SAFE, deleting the venv/node_modules is usually enough and keeps the
  branch. Prefer that over removing the worktree.

  If .git/ez/stack.json exists, use \`ez worktree delete <name>\` rather than
  raw git so the stack stays consistent.
EOF
