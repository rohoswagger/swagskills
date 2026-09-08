---
name: reclaim
description: Find what is actually consuming disk space and free it, measuring every deletion against real free space rather than trusting du. Use whenever the user says their disk is full, asks "what's taking up all my storage", wants to purge/clean up/free up space, mentions "startup disk almost full", "no space left on device", a failing build or Docker pull blamed on space, or asks where their space went. Also use for cleaning specific hoards — Docker, Xcode DerivedData, node_modules, venvs, package manager caches, stale git worktrees. Prefer this over ad-hoc du commands even when the user only wants a diagnosis, because the counting method is the part that goes wrong.
---

# reclaim — free real disk space, measured not guessed

Disk cleanup looks like a search problem ("find the big directories") but it is
really a **measurement problem**. The standard tool lies, and it lies by an
order of magnitude, so a session driven by `du` output can spend an hour
deleting things and free almost nothing.

## The one thing to get right: `du` is not truth, `df` is

On APFS — every modern Mac — files are routinely **copy-on-write clones** that
share physical blocks. `du` charges every clone the full logical size, so it
counts the same bytes many times over. Real numbers from a real session:

| What `du` reported | What deleting it actually freed |
|---|---|
| 8.7 GB of stale `node_modules` + venvs | **393 MB** |
| 14 GB bun cache | 8.5 GB |
| 3.5 GB from `uv cache prune` | **0 MB** (went *down* 636 MB) |

`uv`, `bun`, `pnpm`, and `cp -c` all clone by default. So package caches and the
`node_modules`/`.venv` trees built from them **share blocks**. Deleting the
cache while the venvs still reference those blocks frees nothing. This is why
"you have 30 GB of node_modules" is usually a phantom, and why migrating
projects to a hardlink store to "deduplicate" can be pure wasted effort — the
filesystem already deduplicated them.

Two rules follow, and they matter more than anything else in this skill:

1. **Establish ground truth with `df` before and after every deletion.** Use
   `scripts/measure.sh`, which does exactly this. Report reclaimed bytes from
   the `df` delta, never from `du`.
2. **When you cite a `du` number, call it "apparent".** It is an upper bound on
   what you might free, frequently a wild one. Do not promise it to the user.

A corollary worth stating because it prevents a bogus bug report: free space can
*decrease* while you delete things. Other processes write concurrently (a
staging macOS update, Docker's VM, Spotlight reindexing). Judge a single
deletion by its own measured delta, and the session by the overall `df` change.

## Workflow

### 1. Survey

Run `scripts/survey.sh`. It prints real free space first, then an apparent-size
ranking of the usual hoards, and it deliberately avoids a full-disk `du` (which
takes many minutes and mostly reports noise).

Read the output and form a hypothesis about the top 3 consumers before touching
anything. Single opaque files — a Docker disk image, a VM image, a sparsebundle
— are far more likely to be the real answer than a directory of source code.

### 1b. Separate real bytes from phantoms

For any candidate over a few GB, run `scripts/realsize.py <path>` before you
promise anything. It reads each file's `ATTR_CMNEXT_PRIVATESIZE` and reports the
bytes that are genuinely private versus shared with a clone sibling — the
difference between "20 GB of node_modules" and the 2 GB you would actually get
back. This is the step that keeps you from proposing a large, useless migration.

Treat its private sum as a floor, not a promise: if two clone siblings both sit
inside the tree you delete, their shared extent is freed too. On a control of
one file plus a CoW clone plus a real copy, `du` said 600 MB, the private sum
said 200 MB, and the actual delete freed 400 MB. Use `measure.sh` for the number
you quote.

### 2. Classify what you found

Sort every candidate into exactly one of three buckets. This classification *is*
the safety model:

- **Regenerable** — rebuildable or re-downloadable with a command, holding no
  state a human would miss: build output, compiler caches, package manager
  caches, stale toolchain versions, unused container images. **Delete these
  without asking.** That is what the user wants when they ask for a cleanup.
- **Stateful** — holds something not reproducible: databases, Docker named
  volumes, uncommitted code, downloads, logged-in browser profiles.
  **Always confirm with the user, naming what would be lost**, before deleting.
- **Active** — regenerable in principle, but in use right now. Deleting forces
  an expensive rebuild on work in flight. Leave it, and say you did.

Distinguish active from stale by **mtime, not by name**. A worktree touched
today is someone's current branch; one untouched for 90 days is abandoned. Thirty
days is a reasonable default line. Say which line you used so the user can
disagree.

### 3. Reclaim, measuring as you go

Work in reward order, largest first, and measure each step:

```bash
scripts/measure.sh 'rm -rf ~/Library/Developer/Xcode/DerivedData/*'
```

Batch related deletions into one `measure.sh` call so the numbers stay
attributable, and keep a running tally to report at the end.

### 4. Verify and report

Finish with `df -h` and a table of what you deleted and what each item actually
freed. If apparent and actual differ sharply — they will — say so plainly and
explain the clone effect in a sentence. That is genuinely useful information: it
tells the user which of their hoards are real and which are illusions.

## Where the space actually goes

Ordered by how often each is the answer. Sizes are typical apparent sizes from
real machines, not promises.

**Container and VM images — usually the single biggest item.** A Docker disk
image is one opaque file that can be tens or hundreds of GB and **never shrinks
on its own**. It also hides its own nested world: images inside a Kubernetes
node are invisible to `docker images`. If Docker is installed, check it first
and read `references/docker.md` — it covers the wedged daemon, crash-loop
recovery, and nested stores. Don't reinvent it.

**Build output.** Regenerable, often huge, safe to delete:
- Xcode `DerivedData` (10 GB+) and `iOS DeviceSupport`
- Swift/Xcode `.build`, `build`, `DerivedData` inside project dirs (20 GB+ seen)
- Rust `target/` — check nested paths, not just repo roots
- `.mypy_cache`, `.pytest_cache`, `.next`, `dist`, `.turbo`

**Package manager caches.** Regenerable. The real ones, with their prune
commands: `bun pm cache rm` (or `rm -rf ~/.bun/install/cache`), `uv cache prune`,
`pip cache purge`, `brew cleanup --prune=all`, `pnpm store prune`,
`~/Library/Caches/pip`, `~/Library/Caches/Homebrew`, `go clean -modcache`.
Remember the clone caveat: a cache shared with live venvs may free far less
than its size.

**Old toolchain and browser versions.** Playwright keeps every version it ever
downloaded (`~/Library/Caches/ms-playwright`) — keep the newest of each browser
and delete the rest, which is typically a clean multi-GB win. Same pattern for
old Xcode `iOS DeviceSupport`, Simulator runtimes, and stale `nvm`/`rustup`
toolchains. Browser *profile* directories are stateful, not regenerable — they
hold logged-in sessions. Leave those.

**Duplicated per-worktree environments.** Git worktrees each get their own
`.venv` and `node_modules`. Eleven worktrees × 2 GB looks like 22 GB. Check
whether it is real before celebrating — this is the classic phantom. Sort
worktrees by mtime and treat stale ones as candidates.

**Application caches and Electron apps.** `~/Library/Caches/*` and
`~/Library/Application Support/*`. Editor workspace state (Cursor, VS Code) can
reach 10 GB. Caches are regenerable; Application Support often holds real state,
so check before deleting.

**macOS-specific traps.** APFS local snapshots (`tmutil listlocalsnapshots /`)
can pin space you just freed. A staging OS update consumes many GB and competes
with your cleanup — if free space moves the wrong way, check for
`MacUpdateBrain` before doubting your own measurements.

## Safety rules

These exist because each one has a real failure mode behind it.

**Look before deleting.** Read the directory, check its mtime, understand what
it is. Never `rm -rf` a path matched only by a glob or a name pattern.

**Check git state before removing any worktree or repo directory.** Run
`git -C <path> status --porcelain` and check for unpushed commits. Uncommitted
work is unrecoverable and invisible to `du`. If you find any, report it and let
the user decide — never discard it silently. In a repo where `.git/ez/stack.json`
exists, prefer `ez worktree delete` over raw git so the stack stays consistent.

**A running process can hold a cache lock.** `uv cache prune` fails while any
`uv` process runs. Identify the holder with `pgrep -fl`, tell the user what it
is and how long it has been running, and get agreement before killing it.

**Never delete a container volume, database, or data directory without naming
it and confirming.** These read as "just more Docker usage" and are anything but.

**Deleting inside a VM or container disk image does not free host space
immediately.** The guest must TRIM and the host image must be sparse or
compacted. Expect the host `df` to lag, and say so rather than reporting failure.

**Do not mutate the thing you are measuring.** It is easy to pull an image to
run an inspection container, or write a GB of test fixtures to `/tmp` to probe
filesystem behaviour, and then report "read-only, nothing changed". That is both
a side effect on the subsystem under audit and a false statement. Prefer
inspection that touches nothing (`docker exec` into a container that already
exists; the bundled scripts). If you genuinely must create something, clean it
up, and say what you did — never claim a clean run you did not have.

## Reporting — be terse, front-load the risk

Someone reading a cleanup report is making a go/no-go decision, usually in a
hurry. Prose buries the one line that matters ("this deletes your seeded
database") in a wall of context. **Optimise for a human scanning in ten
seconds, not for completeness.**

Bullets, not paragraphs. Numbers, not adjectives. Aim for **under 25 lines**
before any questions. No preamble, no methodology tour, no restating the
request. If you want to explain the clone effect, you get one clause.

Use this shape:

```
Free: 11 GB → 81 GB (measured)

Deleted — regenerable:
- 25.3 GB  gojo .build / build (Swift artifacts)
- 11.0 GB  Xcode DerivedData
-  8.5 GB  bun cache (du claimed 14 GB)

⚠ Needs your call:
1. Docker.raw is 112 GB. Prune images + build cache, keeping volumes? (~40 GB)
2. onyx-craft-sandbox has 243 orphaned volumes, all 0 B. Remove?
3. codex-migration worktree has 12 uncommitted files. Leave it? (default: yes)

Left alone: 11 active worktrees, 4 named volumes (dev Postgres/OpenSearch),
mcp-chrome profiles (live logins).
```

Rules that make the shape work:

- **Anything destructive goes in the questions block, never buried in prose.**
  One line each: what dies, what it costs, what you recommend.
- **Cap the questions at three.** More than that and nobody reads them. If you
  have more, ask the three biggest and say the rest are deferred.
- **Give each question a default** so the user can say "yes to all" and get a
  safe outcome.
- **State apparent-vs-actual inline** (`8.5 GB (du claimed 14 GB)`), not as a
  paragraph about filesystems.
- **The "left alone" list is two lines, not a section.** It exists so the user
  can tell care from luck.

If something is recurring — a process that regenerates 200 containers, a build
that never cleans up — that is one bullet at the end, not an essay. Freeing the
space again next month is worth less than fixing what fills it.

## Scripts

Every one of these encodes an operation that is easy to get subtly wrong by
hand. Prefer them over improvising the equivalent shell. All the destructive
ones default to a dry run and need `--apply`.

| Script | Does |
|---|---|
| `survey.sh [--deep]` | Ranked survey of the usual hoards, `df` first. Read-only. |
| `realsize.py [--top N] <path>` | True vs apparent footprint via `ATTR_CMNEXT_PRIVATESIZE`. Read-only. |
| `measure.sh --paths <p>…` | Run a deletion, report the real `df` delta. **Use for every number you quote.** |
| `worktree-audit.sh [--days N]` | Every git worktree's uncommitted/unpushed state. Read-only. Run before touching any worktree. |
| `prune-caches.sh [--apply]` | All package-manager caches via their own prune commands; surfaces held locks. |
| `browser-prune.sh [--apply]` | Keep newest Playwright/Puppeteer browser per family; never touches profile dirs. |
| `docker-reclaim.sh [--apply] [--kind]` | Docker usage report and prune that **never** passes `--volumes`; optionally prunes nested cluster stores with the required retry loop. |
| `docker-unwedge.py --report\|--apply` | Offline repair of a crash-looping, API-dead daemon. Refuses to run while Docker is up. |

Two habits worth keeping: run the read-only ones freely, and when a script says
it is a dry run, show the user that output rather than paraphrasing it.

## References

- `references/docker.md` — Docker and nested container stores: reading true
  usage, pruning safely, recovering a wedged daemon, crash-loop repair, and
  cleaning Kubernetes-in-Docker image stores. Read this whenever Docker is
  installed and implicated.
