#!/usr/bin/env bash
# Run every script in this directory against a throwaway copy of example-agent/.
#
# A checker that has only ever run on a healthy file proves nothing, so each check is exercised in
# BOTH directions: a harmless edit must pass, and a real deletion must be caught.
#
# Usage: selftest.sh        (exit 0 = everything behaved as expected)
set -uo pipefail   # deliberately no -e: a failing case must not stop the remaining cases

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export AGENT_HOME="$WORK/agent"
export AGENT_SKILLS_ROOT="$AGENT_HOME/skills"
export AGENT_BACKUP_DIR="$WORK/backups"
cp -a "$REPO_ROOT/example-agent" "$AGENT_HOME"

pass=0
fail=0
check() { # <name> <expected code> <actual code>
  if [ "$2" = "$3" ]; then
    printf '  PASS  %-52s exit %s\n' "$1" "$3"
    pass=$((pass + 1))
  else
    printf '  FAIL  %-52s expected %s, got %s\n' "$1" "$2" "$3"
    fail=$((fail + 1))
  fi
}
assert() { # <name> <condition: 0 = ok>
  if [ "$2" -eq 0 ]; then
    printf '  PASS  %-52s\n' "$1"
    pass=$((pass + 1))
  else
    printf '  FAIL  %-52s\n' "$1"
    fail=$((fail + 1))
  fi
}

echo "[1] pre-change-backup.sh"
"$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/MEMORY.md" >/dev/null 2>&1
check "backup a file inside the agent home" 0 $?
first="$(find "$AGENT_BACKUP_DIR" -maxdepth 1 -name 'MEMORY.md.bak.*' | head -1)"
"$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/MEMORY.md" >/dev/null 2>&1
check "rerun in the same second" 0 $?
count="$(find "$AGENT_BACKUP_DIR" -maxdepth 1 -name 'MEMORY.md.bak.*' | wc -l)"
assert "no backup was overwritten (2 copies on disk)" "$([ "$count" -eq 2 ] && echo 0 || echo 1)"
"$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/does-not-exist.md" >/dev/null 2>&1
check "missing path is reported, not fatal" 1 $?
"$SCRIPTS/pre-change-backup.sh" >/dev/null 2>&1
check "no arguments is a usage error" 2 $?
(AGENT_BACKUP_DIR="$AGENT_HOME/.backups" "$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/MEMORY.md" >/dev/null 2>&1)
check "backup dir inside the agent home is refused" 2 $?
(AGENT_BACKUP_DIR="$AGENT_SKILLS_ROOT/.backups" "$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/MEMORY.md" >/dev/null 2>&1)
check "backup dir inside the skill tree is refused" 2 $?

echo "[2] post-change-compare.py — both directions"
cp -a "$AGENT_HOME/IDENTITY.md" "$WORK/identity.bak"
sed -i 's/Voice: plain and technical, first person, no emoji, no filler\./Voice: plain, technical, first person, no emoji, and no filler./' \
  "$AGENT_HOME/IDENTITY.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/identity.bak" "$AGENT_HOME/IDENTITY.md" >/dev/null 2>&1
check "reworded sentence passes" 0 $?

cp -a "$AGENT_HOME/POINTERS.md" "$WORK/pointers.bak"
python3 - "$AGENT_HOME/POINTERS.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = [ln for ln in path.read_text(encoding="utf-8").splitlines(True)
         if "A vector index for cross-session recall" not in ln]
path.write_text("".join(lines), encoding="utf-8")
PY
python3 "$SCRIPTS/post-change-compare.py" "$WORK/pointers.bak" "$AGENT_HOME/POINTERS.md" >/dev/null 2>&1
check "deleted bullet is caught" 1 $?

python3 "$SCRIPTS/post-change-compare.py" "$WORK/pointers.bak" "$AGENT_HOME/POINTERS.md" --pool "$WORK/nothing" >/dev/null 2>&1
check "still caught when the pool is empty" 1 $?

# The report caps at 40 findings — and must say so, or a truncated list looks complete.
python3 - "$WORK/many.md" <<'PY'
import sys
from pathlib import Path
Path(sys.argv[1]).write_text("".join(f"line {i:03d} unique-token-{i:03d} port {8000 + i}\n" for i in range(45)),
                             encoding="utf-8")
PY
cp -a "$WORK/many.md" "$WORK/many.bak"
: > "$WORK/many.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/many.bak" "$WORK/many.md" >"$WORK/many-report" 2>&1
check "45 lost lines are reported" 1 $?
grep -q 'more not shown' "$WORK/many-report"
assert "a truncated report says how many it omitted" $?

echo "[3] pointers-check.py — both directions"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "pristine tree is clean" 0 $?
cp -a "$AGENT_HOME/POINTERS.md" "$WORK/pointers-clean.md"
sed -i 's/skill:example-skill/skill:no-such-skill/' "$AGENT_HOME/POINTERS.md"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "unresolvable skill pointer is caught" 1 $?
cp -a "$WORK/pointers-clean.md" "$AGENT_HOME/POINTERS.md"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "restored tree is clean again" 0 $?

echo "[4] index-audit.py — both directions"
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "pristine skill tree is clean" 0 $?
echo "# new reference" > "$AGENT_SKILLS_ROOT/example-skill/references/unlisted.md"
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "unlisted reference file is caught" 1 $?
rm -f "$AGENT_SKILLS_ROOT/example-skill/references/unlisted.md"
echo '# ghost entry row' >> "$AGENT_SKILLS_ROOT/example-skill/references/INDEX.md"
printf '| `ghost-file.md` | listed but never written |\n' >> "$AGENT_SKILLS_ROOT/example-skill/references/INDEX.md"
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "ghost index entry is caught" 1 $?
python3 - "$AGENT_SKILLS_ROOT/example-skill/references/INDEX.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = [ln for ln in path.read_text(encoding="utf-8").splitlines(True) if "ghost-file.md" not in ln]
path.write_text("".join(lines).replace("# ghost entry row\n", ""), encoding="utf-8")
PY
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "restored index is clean again" 0 $?

echo "[4b] archive-aware pointer recovery"
mkdir -p "$AGENT_SKILLS_ROOT/.archive"
mv "$AGENT_SKILLS_ROOT/another-skill" "$AGENT_SKILLS_ROOT/.archive/another-skill"
python3 "$SCRIPTS/pointers-check.py" >"$WORK/archive-report" 2>&1
check "a pointer into the archive is reported" 1 $?
grep -q 'archived' "$WORK/archive-report"
assert "the report says it is recoverable, not lost" $?
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "archived skills are skipped by the index audit" 0 $?
mv "$AGENT_SKILLS_ROOT/.archive/another-skill" "$AGENT_SKILLS_ROOT/another-skill"
rmdir "$AGENT_SKILLS_ROOT/.archive"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "restored skill resolves again" 0 $?
(AGENT_ARCHIVE_DIRS="../outside" python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1)
check "an archive dir outside the tree is a config error" 2 $?
(AGENT_ARCHIVE_DIRS="../outside" python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1)
check "the index audit refuses it too" 2 $?

echo "[4c] loadable-content check"
mkdir -p "$AGENT_SKILLS_ROOT/leftover"
echo "stray content" > "$AGENT_SKILLS_ROOT/leftover/note.md"
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "content with no SKILL.md is caught" 1 $?
rm -rf "$AGENT_SKILLS_ROOT/leftover"
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "removed again" 0 $?
mkdir -p "$AGENT_SKILLS_ROOT/.tmp"
echo "stray content" > "$AGENT_SKILLS_ROOT/.tmp/note.md"
python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1
check "a hidden directory is not audited as content" 0 $?
rm -rf "$AGENT_SKILLS_ROOT/.tmp"

echo "[4d] a non-dot archive name works the same way"
mkdir -p "$AGENT_SKILLS_ROOT/archived"
mv "$AGENT_SKILLS_ROOT/another-skill" "$AGENT_SKILLS_ROOT/archived/another-skill"
(AGENT_ARCHIVE_DIRS="archived" python3 "$SCRIPTS/pointers-check.py" >"$WORK/archived-report" 2>&1)
check "configured archive name is honoured (pointer reported)" 1 $?
grep -q 'archived' "$WORK/archived-report"
assert "the report calls it recoverable" $?
(AGENT_ARCHIVE_DIRS="archived" python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1)
check "the same archive is skipped by the index audit" 0 $?
mv "$AGENT_SKILLS_ROOT/archived/another-skill" "$AGENT_SKILLS_ROOT/another-skill"
rmdir "$AGENT_SKILLS_ROOT/archived"

echo "[4e] a multi-component archive name works too"
mkdir -p "$AGENT_SKILLS_ROOT/old/2026"
mv "$AGENT_SKILLS_ROOT/another-skill" "$AGENT_SKILLS_ROOT/old/2026/another-skill"
(AGENT_ARCHIVE_DIRS="old/2026" python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1)
check "nested archive name: pointer reported as recoverable" 1 $?
(AGENT_ARCHIVE_DIRS="old/2026" python3 "$SCRIPTS/index-audit.py" >/dev/null 2>&1)
check "nested archive name: skipped by the index audit" 0 $?
mv "$AGENT_SKILLS_ROOT/old/2026/another-skill" "$AGENT_SKILLS_ROOT/another-skill"
rm -rf "$AGENT_SKILLS_ROOT/old"

echo "[5] snapshot-context.sh"
"$SCRIPTS/snapshot-context.sh" >/dev/null 2>&1
check "snapshot writes without pruning" 0 $?
snap_count="$(find "$AGENT_BACKUP_DIR/snapshots" -mindepth 1 -maxdepth 1 -type d | wc -l)"
assert "one snapshot directory exists" "$([ "$snap_count" -eq 1 ] && echo 0 || echo 1)"
"$SCRIPTS/snapshot-context.sh" --prune abc >/dev/null 2>&1
check "non-numeric --prune is refused" 2 $?
"$SCRIPTS/snapshot-context.sh" --prune 1 >/dev/null 2>&1
check "--prune 1 keeps the newest" 0 $?

echo "[6] archive-baks.py"
python3 "$SCRIPTS/archive-baks.py" plan --keep 1 >/dev/null 2>&1
check "plan runs read-only" 0 $?
python3 "$SCRIPTS/archive-baks.py" apply --keep 1 >/dev/null 2>&1
check "apply packs what plan listed" 0 $?
archives="$(find "$AGENT_BACKUP_DIR/archives" -name '*.tar.gz' 2>/dev/null | wc -l)"
assert "an archive was written" "$([ "$archives" -ge 1 ] && echo 0 || echo 1)"
python3 "$SCRIPTS/archive-baks.py" prune-archive >/dev/null 2>&1
check "prune-archive without a day count is refused" 2 $?
python3 "$SCRIPTS/archive-baks.py" prune-archive abc --apply >/dev/null 2>&1
check "non-numeric day count is refused even with --apply" 2 $?
python3 "$SCRIPTS/archive-baks.py" prune-archive 30 >/dev/null 2>&1
check "prune-archive 30 finds nothing to delete" 0 $?

echo
printf '  %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
