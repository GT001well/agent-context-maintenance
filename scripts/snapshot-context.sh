#!/usr/bin/env bash
# Timestamped snapshots of the context files.
#
# Usage: snapshot-context.sh [--prune [N]]
#
# Snapshots are cheap; pruning is a separate, explicit operation. Deletion as a side effect of taking a
# snapshot has exactly one failure mode — an empty snapshot directory — and it is discovered at the
# moment the snapshot is needed.
#
# Exit codes: 0 = snapshots written, 2 = usage error or no context file found.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_config.sh"

prune=0
keep="$AGENT_SNAPSHOT_KEEP"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prune)
      prune=1
      shift
      if [ "$#" -gt 0 ] && [ "${1#--}" = "$1" ]; then
        keep="$1"
        shift
      fi ;;
    *)
      echo "usage: $0 [--prune [N]]" >&2
      exit 2 ;;
  esac
done

if [ "$prune" -eq 1 ]; then
  require_positive_int "$keep" "--prune" || exit 2
  if [ "${#keep}" -gt 4 ]; then
    echo "[x] --prune takes at most 4 digits (got '$keep') — refusing; nothing was deleted" >&2
    exit 2
  fi
fi

snapshot_root="$AGENT_BACKUP_DIR/snapshots"
mkdir -p "$snapshot_root"
stamp="$(date +%Y%m%d_%H%M%S)"
dedupe=0
dest="$snapshot_root/$stamp"
while [ -e "$dest" ]; do           # same-second rerun: never overwrite an existing snapshot
  dedupe=$((dedupe + 1))
  dest="$snapshot_root/${stamp}-$dedupe"
done
mkdir -p "$dest"

written=0
for name in $AGENT_CONTEXT_FILES; do
  src="$AGENT_HOME/$name"
  if [ -f "$src" ]; then
    cp -a "$src" "$dest/$name"
    written=$((written + 1))
  else
    echo "[!] missing, skipped: $src" >&2
  fi
done

if [ "$written" -eq 0 ]; then
  rmdir "$dest" 2>/dev/null || true
  echo "[x] no context file found under $AGENT_HOME (set AGENT_HOME)" >&2
  exit 2
fi
echo "[v] snapshot: $dest ($written file(s))"

if [ "$prune" -eq 1 ]; then
  mapfile -t all < <(find "$snapshot_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
  if [ "${#all[@]}" -gt "$keep" ]; then
    doomed=("${all[@]:$keep}")
    echo "[i] prune: keeping $keep, deleting ${#doomed[@]}:"
    printf '    %s\n' "${doomed[@]}"
    for name in "${doomed[@]}"; do
      rm -rf "$snapshot_root/$name"
    done
    echo "[v] pruned ${#doomed[@]} snapshot(s)"
  else
    echo "[i] prune: ${#all[@]} snapshot(s), nothing to delete (keep=$keep)"
  fi
fi
