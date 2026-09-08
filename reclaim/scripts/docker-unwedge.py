#!/usr/bin/env python3
"""Break a Docker crash-loop by neutralising restart policies OFFLINE.

When containers crash-loop under `restart: always`/`unless-stopped` they
saturate dockerd: the socket exists, the API never answers, and `docker desktop
status` reports "starting" forever. It is self-sustaining -- fixing it needs the
API the loop has already killed. Restarting Docker does not help; the loop
resumes on boot. A disk that hit 100% is the usual trigger.

The fix is to edit container config inside Docker.raw's ext4 filesystem with the
daemon STOPPED, using debugfs from e2fsprogs. No VM, no kernel extension, no
macFUSE. This script does that, safely and repeatably.

Why it is safe: it rewrites `"Name":"unless-stopped"` as `"Name":"no"` padded
with spaces to the IDENTICAL byte length. JSON ignores the whitespace, so the
file size never changes and only file *data* blocks are touched -- no inode or
extent rewrites, no directory updates, no fsck required. A filesystem already
reporting errors cannot be made worse. Every patch is JSON-validated before
being written and re-read afterwards to confirm.

    # 1. See what is looping (safe, read-only, daemon may be running)
    docker-unwedge.py --report

    # 2. Stop Docker Desktop first, then:
    docker-unwedge.py --network onyx_craft_sandbox --apply
    docker-unwedge.py --all --apply          # every auto-restart container

Then start Docker; the API should answer in seconds. Remove the containers
normally and prune.

Requires: brew install e2fsprogs
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

RAW = os.path.expanduser(
    "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw")
AUTO_RESTART = ("always", "unless-stopped", "on-failure")
OLD_TPL = b'"Name":"%s"'
NEW_NAME = b'"Name":"no"'


def find_debugfs():
    for c in ("debugfs", "/opt/homebrew/opt/e2fsprogs/sbin/debugfs",
              "/usr/local/opt/e2fsprogs/sbin/debugfs"):
        p = shutil.which(c) if os.sep not in c else (c if os.path.exists(c) else None)
        if p:
            return p
    sys.exit("debugfs not found. Install with:  brew install e2fsprogs")


def partition_offset(raw):
    """Byte offset of the first Linux partition in the MBR image."""
    with open(raw, "rb") as fh:
        mbr = fh.read(512)
    if mbr[510:512] != b"\x55\xaa":
        sys.exit(f"{raw}: not an MBR image")
    for i in range(4):
        e = mbr[446 + i * 16: 462 + i * 16]
        ptype = e[4]
        lba = int.from_bytes(e[8:12], "little")
        if ptype in (0x83, 0x8e) and lba:
            off = lba * 512
            with open(raw, "rb") as fh:      # ext4 magic 0x53ef at sb+0x38
                fh.seek(off + 1024 + 0x38)
                if fh.read(2) == b"\x53\xef":
                    return off
    sys.exit("no ext4 Linux partition found in image")


def docker_running():
    out = subprocess.run(["pgrep", "-f", "com.docker.virtualization"],
                         capture_output=True, text=True)
    return bool(out.stdout.strip())


class Fs:
    def __init__(self, debugfs, raw, offset):
        self.debugfs, self.dev = debugfs, f"{raw}?offset={offset}"
        self.raw, self.offset = raw, offset

    def run(self, cmds):
        with tempfile.NamedTemporaryFile("w", suffix=".dbg", delete=False) as f:
            f.write("\n".join(cmds) + "\n")
            path = f.name
        try:
            r = subprocess.run([self.debugfs, "-f", path, self.dev],
                               capture_output=True, text=True, timeout=900)
            return r.stdout
        finally:
            os.unlink(path)

    def blocksize(self):
        out = self.run(["stats -h"])
        m = re.search(r"^Block size:\s+(\d+)", out, re.M)
        return int(m.group(1)) if m else 4096

    def container_ids(self):
        out = self.run(["ls -l /docker/containers"])
        return sorted(set(re.findall(r"\b([0-9a-f]{64})\b", out)))


def stat_files(fs, paths):
    """Return {path: (size, [blocks])} using one debugfs session."""
    out = fs.run([f"stat {p}" for p in paths])
    res = {}
    for rec in re.split(r"debugfs:\s+stat\s+", out)[1:]:
        path = rec.split("\n", 1)[0].strip()
        m = re.search(r"\bSize:\s+(\d+)", rec)
        if not m:
            continue
        size = int(m.group(1))
        blocks = []
        ext = re.search(r"EXTENTS:\s*\n?(.*)", rec, re.S)
        if ext:
            for lo, hi in re.findall(r"\((?:[\d-]+)\):(\d+)(?:-(\d+))?", ext.group(1)):
                a = int(lo); b = int(hi) if hi else a
                blocks.extend(range(a, b + 1))
        res[path] = (size, blocks)
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true", help="read-only summary")
    ap.add_argument("--apply", action="store_true", help="write the patch")
    ap.add_argument("--network", help="only containers on this network")
    ap.add_argument("--all", action="store_true", help="all auto-restart containers")
    ap.add_argument("--raw", default=RAW)
    a = ap.parse_args()

    if not os.path.exists(a.raw):
        sys.exit(f"not found: {a.raw}")
    if not (a.report or a.apply):
        ap.error("pass --report or --apply")
    if not a.report and not (a.network or a.all):
        ap.error("--apply needs --network <name> or --all")
    if a.apply and docker_running():
        sys.exit("Docker is RUNNING. Stop it first:  docker desktop stop\n"
                 "Patching a live filesystem risks corruption.")

    dbg = find_debugfs()
    off = partition_offset(a.raw)
    fs = Fs(dbg, a.raw, off)
    bs = fs.blocksize()
    print(f"image:  {a.raw}\npartition offset: {off}  block size: {bs}")

    ids = fs.container_ids()
    print(f"containers on disk: {len(ids)}")
    if not ids:
        return 0

    # Dump every hostconfig.json in one debugfs session, then classify.
    tmp = tempfile.mkdtemp(prefix="unwedge-")
    fs.run([f"dump /docker/containers/{i}/hostconfig.json {tmp}/{i}.json" for i in ids])

    rows = []
    for i in ids:
        p = os.path.join(tmp, f"{i}.json")
        if not os.path.exists(p):
            continue
        try:
            d = json.load(open(p))
        except Exception:
            continue
        rows.append((i, d.get("NetworkMode", "?"),
                     (d.get("RestartPolicy") or {}).get("Name", "?")))

    from collections import Counter
    print("\nby network x restart policy:")
    for (net, pol), n in Counter((r[1], r[2]) for r in rows).most_common(20):
        flag = "  <-- CRASH-LOOP RISK" if pol in AUTO_RESTART else ""
        print(f"  {n:5d}  net={net:<28} restart={pol}{flag}")

    targets = [r for r in rows if r[2] in AUTO_RESTART
               and (a.all or r[1] == a.network)]
    print(f"\ntargets: {len(targets)}")
    if a.report or not targets:
        print("\n(read-only) re-run with --apply and --network/--all to patch.")
        return 0

    # Locate each file's blocks, patch in place at identical byte length.
    paths = [f"/docker/containers/{i}/hostconfig.json" for i, _, _ in targets]
    meta = stat_files(fs, paths)

    patched = skipped = failed = 0
    with open(a.raw, "r+b") as fh:
        for (cid, _net, pol), path in zip(targets, paths):
            size, blocks = meta.get(path, (None, []))
            if not size or not blocks:
                skipped += 1
                continue
            old = OLD_TPL % pol.encode()
            new = NEW_NAME + b" " * (len(old) - len(NEW_NAME))
            if len(new) != len(old):
                failed += 1
                continue
            data = b""
            for b in blocks:
                fh.seek(off + b * bs)
                data += fh.read(bs)
            content = data[:size]
            if old not in content:
                skipped += 1
                continue
            newc = content.replace(old, new)
            try:
                if (json.loads(newc).get("RestartPolicy") or {}).get("Name") != "no":
                    failed += 1
                    continue
            except Exception:
                failed += 1
                continue
            full = newc + data[size:]
            for idx, b in enumerate(blocks):
                chunk = full[idx * bs:(idx + 1) * bs]
                if chunk != data[idx * bs:(idx + 1) * bs]:
                    fh.seek(off + b * bs)
                    fh.write(chunk)
            patched += 1
        fh.flush()
        os.fsync(fh.fileno())

    print(f"PATCHED={patched} skipped={skipped} failed={failed}")

    # Independent re-read to prove the change persisted.
    ver = tempfile.mkdtemp(prefix="unwedge-verify-")
    fs.run([f"dump {p} {ver}/{i}.json" for (i, _, _), p in zip(targets, paths)])
    ok = bad = 0
    for cid, _, _ in targets:
        p = os.path.join(ver, f"{cid}.json")
        try:
            if (json.load(open(p)).get("RestartPolicy") or {}).get("Name") == "no":
                ok += 1
            else:
                bad += 1
        except Exception:
            bad += 1
    print(f"verified: {ok} now restart=no, {bad} not confirmed")
    print("\nStart Docker; the API should respond in seconds. Then remove the\n"
          "containers normally and prune. Fix the source that set an auto-restart\n"
          "policy on throwaway containers, or this recurs.")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
