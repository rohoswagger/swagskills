#!/usr/bin/env python3
"""Measure the TRUE disk footprint of a path on APFS, without deleting anything.

`du` charges every copy-on-write clone the full logical size, so it routinely
over-reports by 5-20x on machines where uv/bun/pnpm/`cp -c` have cloned files
from a shared cache. That makes `du` useless for deciding what is worth
deleting: a 20 GB directory may hold 2 GB of real bytes.

This asks the filesystem directly. For each file it requests
ATTR_CMNEXT_PRIVATESIZE via getattrlist(2), which reports the bytes that belong
*only* to this file -- blocks shared with a clone sibling are excluded. Summing
private sizes gives the space you would actually reclaim by deleting the tree.

    usage: realsize.py <path> [path...]
           realsize.py --top 20 <path>     # also list the biggest real offenders

Reads only metadata; never opens or modifies file contents.

Interpreting the output:
  apparent ~= real   ->  real bytes, deleting frees what du claims
  apparent >> real   ->  mostly clones; deleting frees far less than du says

One caveat worth knowing before you act on it: if two clone siblings both live
inside the tree you delete, their shared blocks are freed even though each
reports private=0. So this is a conservative *lower* bound on a whole-tree
delete, and an accurate answer for "what do these files cost me beyond the
cache they came from" -- which is the question that actually matters when
deciding whether to prune a cache or migrate a package manager.
"""
import ctypes
import ctypes.util
import os
import sys

# From <sys/attr.h> on macOS (verified against the SDK header, not guessed).
ATTR_BIT_MAP_COUNT = 5
ATTR_CMN_RETURNED_ATTRS = 0x80000000
ATTR_CMNEXT_PRIVATESIZE = 0x00000008
FSOPT_NOFOLLOW = 0x00000001
FSOPT_PACK_INVAL_ATTRS = 0x00000008
FSOPT_ATTR_CMN_EXTENDED = 0x00000020


class Attrlist(ctypes.Structure):
    _fields_ = [
        ("bitmapcount", ctypes.c_ushort),
        ("reserved", ctypes.c_ushort),
        ("commonattr", ctypes.c_uint),
        ("volattr", ctypes.c_uint),
        ("dirattr", ctypes.c_uint),
        ("fileattr", ctypes.c_uint),
        ("forkattr", ctypes.c_uint),
    ]


_libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
_libc.getattrlist.argtypes = [
    ctypes.c_char_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong
]
_libc.getattrlist.restype = ctypes.c_int


def private_size(path):
    """Bytes belonging only to this file, or None if unavailable."""
    al = Attrlist(
        bitmapcount=ATTR_BIT_MAP_COUNT,
        reserved=0,
        commonattr=ATTR_CMN_RETURNED_ATTRS,
        volattr=0,
        dirattr=0,
        fileattr=0,
        forkattr=ATTR_CMNEXT_PRIVATESIZE,
    )
    buf = ctypes.create_string_buffer(64)
    opts = FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW | FSOPT_PACK_INVAL_ATTRS
    if _libc.getattrlist(os.fsencode(path), ctypes.byref(al), buf, len(buf), opts) != 0:
        return None
    # Layout: u_int32 length | attribute_set_t returned (5 x u_int32) | off_t privatesize
    off = 4 + 4 * ATTR_BIT_MAP_COUNT
    off += (8 - off % 8) % 8  # off_t is 8-byte aligned
    return int.from_bytes(buf.raw[off:off + 8], sys.byteorder, signed=True)


def human(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024 or unit == "TB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024.0


def scan(root):
    apparent = real = 0
    files = 0
    unsupported = 0
    biggest = []
    if os.path.isfile(root):
        walker = [(os.path.dirname(root) or ".", [], [os.path.basename(root)])]
    else:
        walker = os.walk(root, onerror=lambda e: None)
    for dirpath, _dirs, names in walker:
        for name in names:
            p = os.path.join(dirpath, name)
            try:
                st = os.lstat(p)
            except OSError:
                continue
            if not (st.st_mode & 0o170000) == 0o100000:  # regular files only
                continue
            files += 1
            apparent += st.st_blocks * 512
            ps = private_size(p)
            if ps is None:
                unsupported += 1
                ps = st.st_blocks * 512  # fail safe: assume it is real
            real += ps
            if ps > 8 * 1024 * 1024:
                biggest.append((ps, p))
    biggest.sort(reverse=True)
    return apparent, real, files, unsupported, biggest


def main():
    args = sys.argv[1:]
    top = 0
    if args and args[0] == "--top":
        top = int(args[1])
        args = args[2:]
    if not args:
        print(__doc__.strip().split("\n\n")[2].strip(), file=sys.stderr)
        return 2

    tot_a = tot_r = 0
    for path in args:
        if not os.path.exists(path):
            print(f"  missing: {path}", file=sys.stderr)
            continue
        a, r, n, unsup, biggest = scan(path)
        tot_a += a
        tot_r += r
        ratio = (a / r) if r else float("inf")
        print(f"{path}")
        print(f"  apparent (du-style): {human(a)}")
        print(f"  REAL (private sum):  {human(r)}   <- lower bound")
        print(f"  files: {n}   over-report: {ratio:.1f}x", end="")
        print(f"   [{unsup} unsupported]" if unsup else "")
        if r and a / r > 2:
            print("  -> mostly clones; deleting frees far less than du claims.")
            print("     If clone siblings both live in this tree, a whole-tree")
            print("     delete frees MORE than the private sum. Confirm the real")
            print("     number with measure.sh before promising it.")
        print()
        if top and biggest:
            print(f"  biggest real consumers in {path}:")
            for ps, p in biggest[:top]:
                print(f"    {human(ps):>10}  {p}")
            print()

    if len(args) > 1:
        print(f"TOTAL apparent: {human(tot_a)}   TOTAL real: {human(tot_r)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
