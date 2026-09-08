#!/usr/bin/env bash
# Reclaim Docker space without destroying data, including nested cluster stores.
#
# Codifies the parts that are easy to get wrong:
#   * `docker system df` reports images as "100% reclaimable" while every one is
#     in use by a running container, so `prune -a` frees ~nothing. Check first.
#   * Kubernetes-in-Docker nodes hide a whole containerd image store in an
#     anonymous volume that `docker images` cannot see. That store is often the
#     single largest item on the machine.
#   * `crictl rmi --prune` fails large layers with DeadlineExceeded and must be
#     re-run until it goes quiet — one pass silently leaves GBs behind.
#   * Named volumes hold seeded databases. Never swept automatically here.
#
#   usage: docker-reclaim.sh              # DRY RUN: report only
#          docker-reclaim.sh --apply      # prune images + build cache (KEEPS volumes)
#          docker-reclaim.sh --apply --kind      # also prune nested cluster images
#
# Never passes --volumes. Removing named volumes is a decision for a human who
# knows which database matters; this script will only ever list them.
set -uo pipefail

APPLY=0; KIND=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --kind)  KIND=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

VOL="${RECLAIM_VOL:-/System/Volumes/Data}"; [ -d "$VOL" ] || VOL=/
free_kb() { df -k "$VOL" | awk 'NR==2 {print $4}'; }

command -v docker >/dev/null 2>&1 || { echo "docker not installed"; exit 0; }

# A wedged daemon hangs forever instead of erroring, so bound the probe.
echo "checking daemon..."
if ! ( docker version --format '{{.Server.Version}}' >/dev/null 2>&1 & p=$!
       ( sleep 25; kill $p 2>/dev/null ) & wait $p 2>/dev/null ); then
  cat <<'EOF'
daemon not responding within 25s.

If the socket exists but the API never answers, containers are probably
crash-looping under a restart policy and saturating dockerd. Restarting alone
will not fix it — the loop resumes. See references/docker.md, and use
scripts/docker-unwedge.py to neutralise the restart policies offline.
EOF
  exit 1
fi

echo
echo "════════ host view ════════"
f="$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
if [ -f "$f" ]; then
  printf '  Docker.raw apparent: %s\n' "$(ls -lh "$f" | awk '{print $5}')"
  printf '  Docker.raw on disk:  %s   <- the number that matters\n' "$(du -sh "$f" | awk '{print $1}')"
fi

echo
echo "════════ daemon view ════════"
docker system df

echo
echo "════════ images actually removable ════════"
# "Reclaimable" in system df counts images not used by a *running* container,
# which is not the same as unused. Compute the honest figure.
total_imgs=$(docker images -q 2>/dev/null | sort -u | wc -l | tr -d ' ')
inuse=$(docker ps -a --format '{{.Image}}' 2>/dev/null | sort -u | wc -l | tr -d ' ')
dangling=$(docker images -qf dangling=true 2>/dev/null | wc -l | tr -d ' ')
printf '  %s image(s) total, %s referenced by containers, %s dangling\n' "$total_imgs" "$inuse" "$dangling"

echo
echo "════════ volumes (never auto-removed) ════════"
dang=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l | tr -d ' ')
printf '  %s dangling volume(s):\n' "$dang"
docker volume ls -qf dangling=true 2>/dev/null | head -20 | sed 's/^/     /'
[ "${dang:-0}" -gt 20 ] && echo "     ... and $((dang-20)) more"
cat <<'EOF'
  Review these by NAME before removing any. Zero-byte volumes are free to drop;
  anything matching *db*, *data*, *opensearch*, *postgres* may be seeded data.
  Watch for near-duplicates differing by one character (foo_bar vs foo-bar) —
  a blanket prune takes the wrong one.
EOF

# ---- nested cluster stores -------------------------------------------------
nodes=$(docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null \
        | awk -F'\t' '$2 ~ /kindest\/node|k3s|rancher/ {print $1}')
if [ -n "$nodes" ]; then
  echo
  echo "════════ nested cluster image stores ════════"
  for n in $nodes; do
    sz=$(docker exec "$n" du -sh /var/lib/containerd 2>/dev/null | awk '{print $1}')
    imgs=$(docker exec "$n" crictl images -q 2>/dev/null | wc -l | tr -d ' ')
    untagged=$(docker exec "$n" crictl images 2>/dev/null | tail -n +2 | awk '$1=="<none>"' | wc -l | tr -d ' ')
    printf '  %s: containerd=%s, %s image(s), %s untagged\n' "$n" "${sz:-?}" "${imgs:-?}" "${untagged:-?}"
    echo "     invisible to \`docker images\`; prune with --kind"
  done
fi

if [ "$APPLY" = "0" ]; then
  echo
  echo "(DRY RUN) --apply prunes images + build cache, KEEPING all volumes."
  echo "          --apply --kind also prunes nested cluster images."
  exit 0
fi

before=$(free_kb)
echo
echo "════════ pruning (volumes preserved) ════════"
docker system prune -a -f 2>&1 | tail -3

if [ "$KIND" = "1" ] && [ -n "$nodes" ]; then
  for n in $nodes; do
    echo
    echo "── crictl rmi --prune on $n (repeating until quiet)"
    for pass in 1 2 3 4 5; do
      errs=$(docker exec "$n" crictl rmi --prune 2>&1 | grep -cE '^E[0-9]|DeadlineExceeded' || true)
      left=$(docker exec "$n" crictl images 2>/dev/null | tail -n +2 | awk '$1=="<none>"' | wc -l | tr -d ' ')
      sz=$(docker exec "$n" du -sh /var/lib/containerd 2>/dev/null | awk '{print $1}')
      printf '   pass %d: errors=%s untagged_left=%s containerd=%s\n' "$pass" "${errs:-0}" "${left:-?}" "${sz:-?}"
      [ "${errs:-0}" -eq 0 ] && [ "${left:-0}" -eq 0 ] && break
      sleep 3
    done
  done
fi

sleep 3
after=$(free_kb)
echo
awk -v d="$((after - before))" 'BEGIN {
  printf "MEASURED HOST RECLAIMED: %s%.2f GB\n", (d<0?"-":""), (d<0?-d:d)/1048576
}'
cat <<'EOF'
Space returns from inside the VM asynchronously via TRIM, so the host figure
lags. Re-check `du -sh` on Docker.raw in a minute. If it still has not shrunk,
run the Docker Desktop reclaim helper:
  docker run --rm --privileged --pid=host docker/desktop-reclaim-space
EOF
