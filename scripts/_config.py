"""Single source of truth for paths and knobs.

Rule from docs/maintenance-workflow.md: the same judgement lives in one place. Every script in this
directory imports these helpers instead of re-deriving paths (which is how two copies of "where do
backups go" end up disagreeing).

Resolution order for each setting: environment variable > `config.env` > default.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List

REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_config_env() -> None:
    """Load `config.env` (git-ignored) without overriding real environment variables."""
    path = REPO_ROOT / "config.env"
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


_load_config_env()


def _setting(name: str, default: str) -> str:
    value = os.environ.get(name, "").strip()
    return value or default


def agent_home() -> Path:
    return Path(_setting("AGENT_HOME", str(REPO_ROOT / "example-agent"))).expanduser()


def skills_root() -> Path:
    return Path(_setting("AGENT_SKILLS_ROOT", str(agent_home() / "skills"))).expanduser()


def backup_dir() -> Path:
    """Backups deliberately default to a directory *outside* the agent home."""
    return Path(_setting("AGENT_BACKUP_DIR", str(REPO_ROOT / ".backups"))).expanduser()


def context_files() -> List[Path]:
    names = _setting("AGENT_CONTEXT_FILES", "IDENTITY.md USER.md MEMORY.md POINTERS.md").split()
    return [agent_home() / name for name in names]


def context_names() -> List[str]:
    return [p.name for p in context_files()]


def mutual_files() -> List[str]:
    """Files that must cross-reference the others. Empty value disables the check."""
    raw = os.environ.get("AGENT_MUTUAL_FILES")
    if raw is None:
        return context_names()
    return [item.strip() for item in raw.split(",") if item.strip()]


def archive_names() -> List[str]:
    """Archive directory names inside the skill tree (AGENT_ARCHIVE_DIRS, colon-separated).

    One home for this rule: both checkers ask here, so "what counts as archived" cannot drift.
    """
    raw = os.environ.get("AGENT_ARCHIVE_DIRS", ".archive")
    return [item.strip() for item in raw.split(":") if item.strip()]


def archive_dirs() -> List[Path]:
    return [skills_root() / name for name in archive_names()]


def keep(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    if not raw.isdigit() or not 1 <= int(raw) <= 100000:
        print(f"[!] {name}='{raw}' is not a positive integer; using {default}")
        return default
    return int(raw)


def pool_texts(paths: List[str]) -> Dict[str, str]:
    """Read `--pool` arguments into {path: text}. A directory contributes every readable text file."""
    collected: Dict[str, str] = {}
    for item in paths:
        path = Path(item).expanduser()
        candidates: List[Path]
        if path.is_dir():
            candidates = [p for p in sorted(path.rglob("*")) if p.is_file()]
        elif path.is_file():
            candidates = [path]
        else:
            print(f"[!] pool path not found: {item}")
            continue
        for candidate in candidates:
            try:
                collected[str(candidate)] = candidate.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue  # binary or unreadable: not a text pool
    return collected
