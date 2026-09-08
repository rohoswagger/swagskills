# Docker and nested container stores

Docker is usually the largest single consumer on a developer Mac, and the
hardest to read accurately, because it hides space three levels deep: the host
sees one opaque disk image, the daemon sees images and volumes inside it, and a
Kubernetes-in-Docker node hides a *third* image store that `docker images`
cannot see at all.

Work from the outside in.

## 1. The host view: one giant sparse file

```bash
f=~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
ls -lh "$f"     # APPARENT size — the max it may grow to (e.g. 128G)
du -sh "$f"     # ACTUAL blocks on disk — the number that matters
```

Two facts that shape everything else:

- **The image never shrinks on its own** as a side effect of deleting things
  inside it. Modern Docker Desktop does return space via TRIM after a prune,
  but **asynchronously** — expect host `df` to lag behind `docker system df` by
  seconds to minutes. Don't report failure prematurely; re-check.
- Deleting the file reclaims everything instantly and destroys every image,
  container, and volume. It is the nuclear option, and it does not need a
  working daemon — which makes it the fallback when the daemon is unrecoverable.
- If a prune succeeded but the image still has not shrunk after a minute, force
  the reclaim rather than waiting or deleting anything:

  ```bash
  docker run --rm --privileged --pid=host docker/desktop-reclaim-space
  ```

## 2. The daemon view

```bash
docker system df        # summary
docker system df -v     # per-image, per-volume, per-cache detail
```

Prune, in increasing order of destructiveness:

```bash
docker system prune                      # stopped containers, dangling images, unused networks
docker system prune -a                   # + ALL images not used by a running container
docker builder prune                     # build cache only
docker system prune -a --volumes         # + NAMED VOLUMES — destroys databases
```

**Never run `--volumes` without naming what dies and getting agreement.** Named
volumes hold dev Postgres, search indexes, object storage. `docker system df -v`
plus `docker volume ls -f dangling=true` tells you which are genuinely orphaned.

An orphaned volume is not automatically garbage either: check whether its name
implies real data (`*-db`, `*_data`, `*-opensearch-data`) versus a throwaway
sandbox. Volumes reporting **0 B** are free to remove — no space, just tidying.

`docker rm -v` removes only *anonymous* volumes, never named ones. After
`docker compose down`, named volumes survive unless you pass `-v`.

## 3. The nested view: Kubernetes-in-Docker

If a container runs `kindest/node`, k3s, or similar, it has its **own containerd
image store inside an anonymous volume mounted at `/var`**. This is invisible to
`docker images` and shows up on the host as a single enormous in-use volume.

Real example: a 42 GB anonymous volume where `/var/lib/containerd` held 41 GB —
34 GB of overlayfs snapshots plus 7.5 GB of content store — from repeated dev
builds pushed into the cluster, never cleaned.

Find it:

```bash
docker system df -v | awk '/^VOLUME NAME/,0' | sort -k3 -rh | head
# then map the volume to its container:
for c in $(docker ps -aq); do
  docker inspect "$c" --format '{{.Name}} {{range .Mounts}}{{.Name}}:{{.Destination}} {{end}}'
done | grep <volume-id>
```

Clean it from inside the node:

```bash
docker exec <node> crictl images                 # what the cluster holds
docker exec <node> crictl rmi --prune            # remove unreferenced images
docker exec <node> du -sh /var/lib/containerd    # verify
```

`crictl rmi --prune` is safe by design — it only removes images no container
references, so running workloads keep theirs.

Do not claim a snapshot-count win without checking. Overlayfs holds roughly one
snapshot per layer per image, so a few hundred snapshots across a few dozen
images is normal rather than orphaned cruft. Compare snapshot count to
(images x layers) before promising GBs, or just run the prune and measure.

**Run it repeatedly.** Large layers frequently exceed the RPC deadline and fail
with `DeadlineExceeded ... RST_STREAM`. A first pass may delete image records
while leaving the snapshots behind (41 GB → 35 GB), and further passes reclaim
the rest (35 GB → 20 GB). Loop until it reports zero errors and the size stops
moving.

To keep one image per role, don't guess from tags — read the cluster's own
config, since a deployment spec and a stale local tag often disagree:

```bash
K='kubectl --kubeconfig=/etc/kubernetes/admin.conf'
docker exec <node> sh -c "$K get deploy,statefulset -A \
  -o jsonpath='{range .items[*]}{.metadata.name}{\"\t\"}{range .spec.template.spec.containers[*]}{.image}{\" \"}{end}{\"\n\"}{end}'"
docker exec <node> sh -c "$K get cm -A -o yaml" | grep -i 'image'
```

Note that a single image commonly backs several containers (an API server and a
proxy sharing one backend image), and that `foo` and `foo-arm64` tags often
point at the *same* image ID — two tags, one copy, no savings from removing one.

## 4. When the daemon is wedged

Symptom: `docker system df` hangs indefinitely, the socket exists but the API
never answers, `docker desktop status` reports `starting` forever.

Diagnose before restarting — a restart alone will not fix a self-sustaining loop:

```bash
tail -50 ~/Library/Containers/com.docker.docker/Data/log/vm/console.log
lsof -U 2>/dev/null | grep -c docker.sock     # a huge count = request backlog
```

Rapid shim connect/disconnect churn on one network means **containers are
crash-looping under a restart policy**. This is self-sustaining: the loop
saturates the daemon, and fixing it needs the API that the loop has killed. A
disk that hit 100% is the usual trigger — containers start failing,
`restart: always` resurrects them forever.

Check for a host-side producer first (`ps aux | grep -i <network-name>`). If
none exists, the loop lives entirely inside the VM.

### Offline repair via debugfs

Container config lives in ext4 inside `Docker.raw`, and it can be edited with
the daemon **stopped** — no VM, no kernel extension, no macFUSE:

```bash
brew install e2fsprogs
export PATH="/opt/homebrew/opt/e2fsprogs/sbin:$PATH"

f=~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
file "$f"                       # MBR; note partition 1 start sector (usually 2048)
D="$f?offset=1048576"           # 2048 * 512 — e2fsprogs supports ?offset= natively

debugfs -R "stats -h" "$D" | head -20
debugfs -R "ls /docker/containers" "$D"
```

The filesystem is mounted at `/var/lib` in the VM, so paths inside it are
`/docker/containers/...`, **not** `/var/lib/docker/containers/...`.

Dump every `hostconfig.json` in one session (one `debugfs` call, not hundreds):

```bash
: > /tmp/cmds
while read id; do echo "dump /docker/containers/$id/hostconfig.json /tmp/hc/$id.json" >> /tmp/cmds; done < ids.txt
debugfs -f /tmp/cmds "$D"
```

Each file's `NetworkMode` and `RestartPolicy` identify the culprits.

To break the loop, neutralize the restart policy with an **in-place,
length-preserving byte patch** — replace `"Name":"unless-stopped"` with
`"Name":"no"` padded with spaces to the identical byte length. JSON ignores the
whitespace, the file size never changes, so **ext4 metadata is never touched**:
no inode or extent rewrites, no fsck needed, and a filesystem already reporting
errors cannot be made worse. That safety margin is the entire reason to prefer
this over deleting container directories.

Get each file's block via `debugfs -R "stat <path>"` (read the `EXTENTS` line),
then patch at `partition_offset + block * block_size`. Validate that the patched
bytes still parse as JSON *before* writing, and re-read through `debugfs`
afterward to confirm it persisted.

Two preconditions worth verifying: the feature list must not include
`inline_data` (otherwise small files live in the inode, not in blocks), and
`metadata_csum` is fine — it covers metadata, not file data, so patching file
contents breaks no checksum.

After patching, start Docker. A daemon that previously never answered should
respond in seconds. Then remove the containers normally and prune.

## 5. Prevention

A cleanup that does not address the cause buys a month. Two recurring patterns
worth naming to the user:

- **Throwaway containers created with a restart policy.** Sandbox and
  test-harness containers should use `--rm` or `restart: no`. With
  `unless-stopped` they accumulate indefinitely and eventually wedge the daemon.
- **Dev images pushed into a nested cluster with no pruning.** Every rebuild
  adds a full image; nothing reclaims the old ones. A periodic
  `crictl rmi --prune` in the dev loop prevents tens of GB from piling up.
