#!/usr/bin/env python3
"""Do the pointers still point anywhere?

Usage:
    pointers-check.py [--context-dir DIR] [--skills-root DIR] [--quiet]

Dimensions (all owned — an entry in any of them sets exit code 1):

  [1] Broken links      — `skill:name` references whose skill does not exist, and backticked relative
                          paths (`scripts/pre-change-backup.sh`, `references/INDEX.md`) that resolve
                          neither relative to the containing file, nor to the agent home, nor to the repo.
  [2] Missing cross-refs — each file listed in AGENT_MUTUAL_FILES must name the other files. These
                          edges are what keeps the non-injected layer (POINTERS.md) findable; trimming
                          text for size is how they disappear silently.
  [3] Orphan index      — a `references/INDEX.md` that its own SKILL.md never points at.
  [4] Archived target   — a pointer that no longer resolves from the live tree but *does* resolve inside
                          an archive directory (AGENT_ARCHIVE_DIRS, default `.archive`): reported as
                          recoverable rather than lost. A pointer is never allowed to fail silently just
                          because something was filed away.

Exit codes: 0 = clean, 1 = entries, 2 = usage error (missing directory).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import REPO_ROOT, agent_home, archive_dirs, archive_names, context_files, mutual_files, skills_root  # noqa: E402

SKILL_REF = re.compile(r"skill:([A-Za-z0-9_.-]+)")
CODE_SPAN = re.compile(r"`([^`\n]+)`")
PATH_LIKE = re.compile(r"^[\w./-]+\.(md|py|sh|json|env|toml|yaml)$")
SKIP_MARKERS = ("<", ">", "*", "…", "...", "$")
_REPO_FILES: List[str] | None = None
_ARCHIVE_INDEX: Tuple[Dict[str, Path], List[str]] | None = None


def skill_dirs(root: Path) -> Dict[str, Path]:
    """{skill name: directory} for every *live* SKILL.md under root, keyed by directory name."""
    found: Dict[str, Path] = {}
    if not root.is_dir():
        return found
    archived = set(archive_names())
    for skill_md in sorted(root.rglob("SKILL.md")):
        relative = skill_md.relative_to(root)
        if len(relative.parts) > 4 or any(part in archived for part in relative.parts[:-1]):
            continue
        found.setdefault(skill_md.parent.name, skill_md.parent)
    return found


def repo_files() -> List[str]:
    """Every file path under the repository, relative to its root. Cached: one walk per run."""
    global _REPO_FILES
    if _REPO_FILES is None:
        paths: List[str] = []
        skip = {".git", ".backups", "archives", "__pycache__"}
        for path in REPO_ROOT.rglob("*"):
            if any(part in skip for part in path.parts) or not path.is_file():
                continue
            paths.append(str(path.relative_to(REPO_ROOT)))
        _REPO_FILES = paths
    return _REPO_FILES


def resolves(candidate: str, source: Path, home: Path) -> bool:
    if candidate.startswith("http") or any(marker in candidate for marker in SKIP_MARKERS):
        return True  # not a local path: templates, globs, URLs are out of scope
    if " " in candidate:
        return True  # a command line, not a path
    for base in (source.parent, home, REPO_ROOT, Path.cwd()):
        if (base / candidate).exists():
            return True
    # A bare file name (`pre-change-backup.sh`) or a partial path (`references/INDEX.md`) is how people
    # write references in prose. Resolve it by suffix against the repository before calling it broken.
    return any(rel == candidate or rel.endswith("/" + candidate) for rel in repo_files())


def archive_index() -> Tuple[Dict[str, Path], List[str]]:
    """(name -> archived skill dir, archived file paths) for the pointer recovery pass."""
    global _ARCHIVE_INDEX
    if _ARCHIVE_INDEX is None:
        skills: Dict[str, Path] = {}
        files: List[str] = []
        root = skills_root()
        for directory in archive_dirs():
            if not directory.is_dir():
                continue
            for skill_md in sorted(directory.rglob("SKILL.md")):
                skills.setdefault(skill_md.parent.name, skill_md.parent)
            for path in sorted(directory.rglob("*")):
                if path.is_file():
                    files.append(str(path.relative_to(root)))
        _ARCHIVE_INDEX = (skills, files)
    return _ARCHIVE_INDEX


def scan_links(paths: List[Path], skills: Dict[str, Path]) -> List[str]:
    entries: List[str] = []
    archived_skills, archived_files = archive_index()
    for path in paths:
        if not path.is_file():
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for name in SKILL_REF.findall(line):
                if name in skills:
                    continue
                if name in archived_skills:
                    entries.append(f"[4] {path}:{number}  skill:{name} — archived at "
                                   f"{archived_skills[name]}; restore it or re-point (recoverable)")
                    continue
                entries.append(f"[1] {path}:{number}  skill:{name} — no such skill under {skills_root()}")
            for span in CODE_SPAN.findall(line):
                candidate = span.strip()
                if not PATH_LIKE.match(candidate) or resolves(candidate, path, agent_home()):
                    continue
                if any(rel == candidate or rel.endswith("/" + candidate) for rel in archived_files):
                    entries.append(f"[4] {path}:{number}  `{candidate}` — only present in an archive "
                                   f"directory (recoverable, not lost)")
                    continue
                entries.append(f"[1] {path}:{number}  `{candidate}` does not resolve")
    return entries


def scan_mutual_edges(names: List[str]) -> List[str]:
    entries: List[str] = []
    home = agent_home()
    for name in names:
        path = home / name
        if not path.is_file():
            entries.append(f"[2] {path} — listed in AGENT_MUTUAL_FILES but missing on disk")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for other in names:
            if other != name and other not in text:
                entries.append(f"[2] {path} — does not mention {other}")
    return entries


def scan_orphan_indexes(root: Path) -> List[str]:
    entries: List[str] = []
    if not root.is_dir():
        return entries
    for index in sorted(root.rglob("references/INDEX.md")):
        skill_md = index.parent.parent / "SKILL.md"
        if not skill_md.is_file():
            entries.append(f"[3] {index} — no SKILL.md beside it")
            continue
        if "INDEX.md" not in skill_md.read_text(encoding="utf-8", errors="replace"):
            entries.append(f"[3] {skill_md} — does not point at {index.relative_to(skill_md.parent)}")
    return entries


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Check that pointers and cross-references resolve.")
    parser.add_argument("--context-dir", default=None, help="directory holding the context files")
    parser.add_argument("--skills-root", default=None, help="the skill tree")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    if args.context_dir:
        import os
        os.environ["AGENT_HOME"] = str(Path(args.context_dir).expanduser())
    if args.skills_root:
        import os
        os.environ["AGENT_SKILLS_ROOT"] = str(Path(args.skills_root).expanduser())

    home = agent_home()
    root = skills_root()
    if not home.is_dir():
        print(f"[x] context directory not found: {home} (set AGENT_HOME)", file=sys.stderr)
        return 2

    files = context_files()
    skills = skill_dirs(root)
    archived_names = set(archive_names())
    live_skill_md = [
        path for path in sorted(root.rglob("SKILL.md"))
        if len(path.relative_to(root).parts) <= 4
        and not any(part in archived_names for part in path.relative_to(root).parts)
    ] if root.is_dir() else []

    entries = (
        scan_links(files + live_skill_md, skills)
        + scan_mutual_edges(mutual_files())
        + scan_orphan_indexes(root)
    )

    if not args.quiet:
        for entry in entries:
            print(entry)
    missing = [path.name for path in files if not path.is_file()]
    if missing and not args.quiet:
        print(f"[i] context files not present (skipped): {', '.join(missing)}")
    total = len(entries)
    if total:
        print(f"[!] {total} pointer problem(s) — [1] broken, [4] recoverable (archived)")
        return 1
    print(f"[v] pointers ok ({len(files)} context file(s), {len(skills)} skill(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
