#!/usr/bin/env python3
"""Does the skill tree match its index tables?

Usage:
    index-audit.py [--skills-root DIR] [--quiet]

Owned dimensions (an entry in any of them sets exit code 1):

  [A] frontmatter `name` missing, or not equal to the directory name — the loader then either cannot
      find the skill by name or reports two skills that look like one.
  [B] three or more files in `references/` but no `references/INDEX.md` table.
  [C] an entry in `references/INDEX.md` whose file is not on disk (ghost entry).
  [D] a file in `references/` that the index table never mentions (coverage gap).
  [E] the same skill directory name appearing twice under the tree (ambiguous lookup).
  [F] a SKILL.md with an odd number of ``` fences — the body renders and scans as truncated text.
  [G] a directory holding files but no SKILL.md at or below it — content that cannot be loaded as a
      skill. Anything filed under an archive directory (AGENT_ARCHIVE_DIRS, default `.archive`) is not
      a live skill and is skipped rather than reported.

Information only (printed, never affects the exit code): a SKILL.md larger than 40 KB, which is worth
splitting, but is a sizing opinion rather than a defect.

Exit codes: 0 = clean, 1 = entries, 2 = usage error (missing skill tree).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import archive_names, skills_root  # noqa: E402

NAME_FIELD = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)
INDEX_ROW = re.compile(r"`?([\w./-]+\.md)`?")
BIG_SKILL = 40 * 1024
MAX_DEPTH = 4


def is_archived(path: Path, root: Path) -> bool:
    """True for anything filed under an archive directory: archived skills are not live skills."""
    names = set(archive_names())
    return any(part in names or (part.startswith(".") and part != ".") for part in
               path.relative_to(root).parts[:-1])


def skill_files(root: Path) -> List[Path]:
    if not root.is_dir():
        return []
    return [p for p in sorted(root.rglob("SKILL.md"))
            if len(p.relative_to(root).parts) <= MAX_DEPTH and not is_archived(p, root)]


def orphan_content(root: Path) -> List[str]:
    """[G] directories holding files but no SKILL.md anywhere beneath them: nothing can load them."""
    entries: List[str] = []
    if not root.is_dir():
        return entries
    skill_dirs = {p.parent.resolve() for p in skill_files(root)}
    for directory in sorted(p for p in root.rglob("*") if p.is_dir()):
        relative = directory.relative_to(root)
        if len(relative.parts) > MAX_DEPTH or is_archived(directory, root):
            continue
        if directory.name.startswith("."):
            continue
        # Directories that belong to a skill (below its SKILL.md) are content, not skills.
        resolved = directory.resolve()
        if any(resolved == skill or skill in resolved.parents for skill in skill_dirs):
            continue
        files = [p for p in directory.rglob("*") if p.is_file() and not p.name.startswith(".")]
        if files and not any(p.name == "SKILL.md" for p in files):
            entries.append(f"[G] {directory.relative_to(root)} — {len(files)} file(s) but no SKILL.md "
                           f"at or below this directory (unloadable content)")
    return entries


def index_entries(index: Path) -> List[str]:
    """File names mentioned in an index table (only the first column of table rows)."""
    names: List[str] = []
    for line in index.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip().startswith("|") or set(line.strip()) <= set("|- "):
            continue
        first = line.strip().strip("|").split("|")[0].strip()
        match = INDEX_ROW.search(first)
        if match:
            names.append(Path(match.group(1)).name)
    return names


def audit(root: Path) -> Dict[str, List[str]]:
    owned: List[str] = []
    info: List[str] = []
    seen: Dict[str, Path] = {}

    for skill_md in skill_files(root):
        directory = skill_md.parent
        text = skill_md.read_text(encoding="utf-8", errors="replace")
        name_match = NAME_FIELD.search(text.split("---", 2)[1] if text.startswith("---") else "")
        declared = name_match.group(1).strip().strip('"').strip("'") if name_match else ""
        if not declared:
            owned.append(f"[A] {skill_md} — no `name:` in frontmatter")
        elif declared != directory.name:
            owned.append(f"[A] {skill_md} — name '{declared}' != directory '{directory.name}'")

        if directory.name in seen:
            owned.append(f"[E] {directory.name} — duplicate skill directory ({seen[directory.name]}, {directory})")
        else:
            seen[directory.name] = directory

        if text.count("```") % 2:
            owned.append(f"[F] {skill_md} — odd number of ``` fences (unclosed code block)")

        if len(text.encode("utf-8")) > BIG_SKILL:
            info.append(f"[i] {skill_md} — {len(text) // 1024} KB, consider splitting")

        refs_dir = directory / "references"
        if not refs_dir.is_dir():
            continue
        files = [p for p in sorted(refs_dir.rglob("*")) if p.is_file() and p.name != "INDEX.md"]
        index = refs_dir / "INDEX.md"
        if not index.is_file():
            if len(files) >= 3:
                owned.append(f"[B] {directory.name} — {len(files)} reference files but no references/INDEX.md")
            continue
        listed = index_entries(index)
        for name in listed:
            if not (refs_dir / name).is_file():
                owned.append(f"[C] {index} — entry '{name}' is not on disk")
        for path in files:
            if path.name not in listed:
                owned.append(f"[D] {index} — {path.relative_to(refs_dir)} exists but is not listed")
    owned.extend(orphan_content(root))
    return {"owned": owned, "info": info}


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Audit the skill tree against its index tables.")
    parser.add_argument("--skills-root", default=None)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    root = Path(args.skills_root).expanduser() if args.skills_root else skills_root()
    if not root.is_dir():
        print(f"[x] skill tree not found: {root} (set AGENT_SKILLS_ROOT)", file=sys.stderr)
        return 2

    result = audit(root)
    if not args.quiet:
        for entry in result["owned"] + result["info"]:
            print(entry)
    skills = len(skill_files(root))
    if result["owned"]:
        print(f"[!] {len(result['owned'])} index problem(s) across {skills} skill(s)"
              f" (+{len(result['info'])} informational)")
        return 1
    print(f"[v] skill tree ok ({skills} skill(s), {len(result['info'])} informational note(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
