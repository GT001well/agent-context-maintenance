#!/usr/bin/env python3
"""Pack old backups, and delete old archives by age.

Usage:
    archive-baks.py plan [--from DIR] [--keep N]
    archive-baks.py apply [--from DIR] [--keep N]
    archive-baks.py prune-archive DAYS [--apply]

`plan` is read-only. Backups are grouped by their source file (everything before `.bak.`); the newest
`--keep` (default 3, or `AGENT_ARCHIVE_KEEP`) per source stay where they are, the rest are packed into
`<backup dir>/archives/baks-archive-<stamp>.tar.gz` with a matching `-filelist.txt`.

Destructive arguments refuse malformed values instead of falling back to an implicit default:
`prune-archive` needs a valid day count, and `--keep` needs an integer in 1..100000 (the default is 3 or
`AGENT_ARCHIVE_KEEP`; `--keep 0`, which would pack every backup, is refused rather than accepted).
The file list is deleted together with its archive, so orphan lists never accumulate. Without `--apply`
it only lists.

Exit codes: 0 = ok (including "nothing to do" and dry runs), 2 = usage/argument error,
             3 = the packing subprocess failed.
"""

from __future__ import annotations

import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import backup_dir, keep  # noqa: E402

ARCHIVES = "archives"
MAX_DAYS = 3650


def collect(root: Path) -> Dict[str, List[Path]]:
    """Backup files under root, grouped by source file. The archives directory is skipped."""
    groups: Dict[str, List[Path]] = {}
    for path in sorted(root.rglob("*.bak.*")):
        if ARCHIVES in path.parts or not path.is_file():
            continue
        source = path.name.split(".bak.")[0]
        groups.setdefault(f"{path.parent}/{source}", []).append(path)
    return groups


def split_groups(groups: Dict[str, List[Path]], keep_n: int) -> Tuple[List[Path], int]:
    """Return (candidates to pack, number of sources) keeping the newest `keep_n` per source."""
    candidates: List[Path] = []
    for paths in groups.values():
        ordered = sorted(paths, key=lambda p: (p.stat().st_mtime, p.name), reverse=True)
        candidates.extend(ordered[keep_n:])
    return sorted(candidates), len(groups)


def describe(candidates: List[Path], sources: int, keep_n: int, root: Path) -> None:
    packed = sum(path.stat().st_size for path in candidates)
    print(f"[i] root: {root}")
    print(f"[i] {sources} source(s); keeping the newest {keep_n} per source, "
          f"{len(candidates)} backup(s) to pack ({packed / 1024:.0f} KB)")
    for path in candidates[:20]:
        print(f"    {path.relative_to(root)}")
    if len(candidates) > 20:
        print(f"    ... and {len(candidates) - 20} more")


def pack(candidates: List[Path], root: Path) -> int:
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = root / ARCHIVES
    out_dir.mkdir(parents=True, exist_ok=True)
    archive = out_dir / f"baks-archive-{stamp}.tar.gz"
    filelist = archive.with_name(f"baks-archive-{stamp}-filelist.txt")
    filelist.write_text("\n".join(str(p.relative_to(root)) for p in candidates) + "\n", encoding="utf-8")

    try:
        completed = subprocess.run(
            ["tar", "-czf", str(archive), "-C", str(root), "-T", str(filelist)],
            capture_output=True, text=True)
    except FileNotFoundError as exc:  # tar missing: do not leave an orphan list behind
        filelist.unlink(missing_ok=True)
        print(f"[x] cannot run tar: {exc}", file=sys.stderr)
        return 3
    if completed.returncode != 0:
        filelist.unlink(missing_ok=True)
        archive.unlink(missing_ok=True)
        print(f"[x] tar failed: {completed.stderr.strip()[:300]}", file=sys.stderr)
        return 3

    for path in candidates:
        path.unlink()
    print(f"[v] packed {len(candidates)} backup(s) -> {archive} ({archive.stat().st_size / 1024:.0f} KB)")
    return 0


def prune(days_raw: str, apply: bool, root: Path) -> int:
    if not days_raw.isdigit() or not 1 <= int(days_raw) <= MAX_DAYS:
        print(f"[x] prune-archive needs a day count between 1 and {MAX_DAYS}, got '{days_raw}'",
              file=sys.stderr)
        return 2
    days = int(days_raw)
    cutoff = (datetime.datetime.now() - datetime.timedelta(days=days)).timestamp()
    out_dir = root / ARCHIVES
    victims = [p for p in sorted(out_dir.glob("baks-archive-*")) if p.stat().st_mtime < cutoff]
    if not victims:
        print(f"[i] no archive or list older than {days} day(s) under {out_dir}")
        return 0
    print(f"[i] {len(victims)} archive(s)/list(s) older than {days} day(s):")
    for path in victims:
        print(f"    {path.name}")
    if not apply:
        print("[i] dry run — re-run with --apply to delete")
        return 0
    for path in victims:
        path.unlink()
        if path.name.endswith(".tar.gz"):
            path.with_name(path.name.replace(".tar.gz", "-filelist.txt")).unlink(missing_ok=True)
    print(f"[v] removed {len(victims)} file(s)")
    return 0


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Pack and prune backups.")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("plan", "apply"):
        node = sub.add_parser(name, help=f"{name} packing of old backups")
        node.add_argument("--from", dest="source", default=None, help="directory to scan (default: backup dir)")
        node.add_argument("--keep", dest="keep_n", default=None, help="backups to keep per source (default 3)")
    prune_node = sub.add_parser("prune-archive", help="delete archives older than N days")
    prune_node.add_argument("days", help="age in days (required, 1..%d)" % MAX_DAYS)
    prune_node.add_argument("--apply", action="store_true", help="actually delete (default: dry run)")
    prune_node.add_argument("--from", dest="source", default=None)
    args = parser.parse_args(argv)

    if args.command in ("plan", "apply") and args.keep_n is not None \
            and not re.fullmatch(r"[1-9][0-9]{0,5}", args.keep_n):
        # ASCII digits only: str.isdigit() accepts superscripts that int() then rejects, and `--keep 0`
        # would mean "pack every backup". `apply` is the destructive step, so no implicit default.
        print(f"[x] --keep needs a positive integer (1..100000), got '{args.keep_n}' — refusing\n"
              f"usage: archive-baks.py plan | apply [--keep N] | prune-archive <days> [--apply]",
              file=sys.stderr)
        return 2

    root = Path(args.source).expanduser() if getattr(args, "source", None) else backup_dir()
    if not root.is_dir():
        print(f"[x] backup directory not found: {root} (set AGENT_BACKUP_DIR)", file=sys.stderr)
        return 2

    if args.command == "prune-archive":
        return prune(args.days, args.apply, root)

    # The CLI value was validated above; `keep()` validates the environment variable (and warns).
    keep_n = int(args.keep_n) if args.keep_n else keep("AGENT_ARCHIVE_KEEP", 3)
    candidates, sources = split_groups(collect(root), keep_n)
    describe(candidates, sources, keep_n, root)
    if not candidates:
        print("[i] nothing to pack")
        return 0
    if args.command == "plan":
        print("[i] dry run — re-run with `apply` to pack and delete the packed backups")
        return 0
    return pack(candidates, root)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
