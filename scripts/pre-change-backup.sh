#!/usr/bin/env bash
# Back up files or directories before editing them.
#
# Usage: pre-change-backup.sh <path> [path...]
#
# Guarantees:
#   * never overwrites an existing backup (a same-second rerun gets `-1`, `-2`, ...)
#   * every backup lands in AGENT_BACKUP_DIR, never beside the original — a pile of `.bak` files next
#     to the files they protect is how a context directory gets polluted and how a scanner starts
#     counting backups as content
#   * a path inside the skill tree is flattened relative to the tree, so the backup name still says
#     where it came from
#
# Exit codes: 0 = everything backed up, 1 = some path did not exist (the rest were backed up),
#             2 = usage error.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_config.sh"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <path> [path...]" >&2
  exit 2
fi

stamp="$(date +%Y%m%d_%H%M%S)"

# Refuse to protect a tree with a backup directory inside it: backups there are picked up as content by
# every index check, and a directory-level backup inside a skill tree can make a skill name ambiguous.
for protected in "$AGENT_HOME" "$AGENT_SKILLS_ROOT"; do
  [ -e "$protected" ] || continue
  case "$(realpath -m "$AGENT_BACKUP_DIR")/" in
    "$(realpath -m "$protected")"/*)
      echo "[x] AGENT_BACKUP_DIR ($AGENT_BACKUP_DIR) is inside $protected." >&2
      echo "[x] Backups must live outside what they protect; move it and re-run." >&2
      exit 2 ;;
  esac
done

mkdir -p "$AGENT_BACKUP_DIR"
missing=0
count=0

for src in "$@"; do
  if [ ! -e "$src" ]; then
    echo "[!] not found, skipped: $src" >&2
    missing=1
    continue
  fi

  if [ -d "$src" ]; then
    mkdir -p "$AGENT_BACKUP_DIR/tree-$stamp"
    dest="$(unique_path "$AGENT_BACKUP_DIR/tree-$stamp/$(basename "$src")")"
    cp -a "$src" "$dest"
  else
    real="$(realpath "$src")"
    case "$real" in
      "$AGENT_SKILLS_ROOT"/*)
        flat="$(realpath --relative-to="$AGENT_SKILLS_ROOT" "$real" | tr '/' '_')" ;;
      "$AGENT_HOME"/*)
        flat="$(realpath --relative-to="$AGENT_HOME" "$real" | tr '/' '_')" ;;
      *)
        flat="$(printf '%s' "${real#/}" | tr '/' '_')" ;;
    esac
    dest="$(unique_path "$AGENT_BACKUP_DIR/${flat}.bak.${stamp}")"
    cp -a "$src" "$dest"
  fi

  count=$((count + 1))
  echo "[v] backup: $src -> $dest"
done

echo "[i] next: edit the file, then run: python3 scripts/post-change-compare.py <backup> <file>"
[ "$missing" -eq 0 ] || echo "[!] $count backed up, some paths were missing"
exit "$missing"
