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
"$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/MEMORY.md" >"$WORK/backup-out" 2>&1
check "backup a file inside the agent home" 0 $?
grep -q 'rollback: cp -a' "$WORK/backup-out"
assert "the backup prints its own rollback command" $?
first="$(find "$AGENT_BACKUP_DIR" -maxdepth 1 -name 'MEMORY.md.bak.*' | head -1)"
"$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/MEMORY.md" >/dev/null 2>&1
check "rerun in the same second" 0 $?
count="$(find "$AGENT_BACKUP_DIR" -maxdepth 1 -name 'MEMORY.md.bak.*' | wc -l)"
assert "no backup was overwritten (2 copies on disk)" "$([ "$count" -eq 2 ] && echo 0 || echo 1)"
"$SCRIPTS/pre-change-backup.sh" "$AGENT_HOME/does-not-exist.md" >"$WORK/missing-out" 2>&1
check "missing path is reported, not fatal" 1 $?
grep -q 'do not edit until the backup exists' "$WORK/missing-out"
assert "a failed backup tells the caller to stop" $?
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

# A short line of plain Latin words carries no structured token and no CJK, so the phrase signal is the
# only one available for it; anything shorter than a phrase has to fall back to word survival.
printf 'copy the draft\n' > "$WORK/short.md"
cp -a "$WORK/short.md" "$WORK/short.bak"
: > "$WORK/short.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/short.bak" "$WORK/short.md" >/dev/null 2>&1
check "a deleted short line is caught" 1 $?
printf 'copy the draft\n' > "$WORK/short-pool.md"
printf 'unrelated text\n' > "$WORK/short.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/short.bak" "$WORK/short.md" --pool "$WORK/short-pool.md" >/dev/null 2>&1
check "the same line passes when it moved into the pool" 0 $?
printf 'regenerate cache\n' > "$WORK/two-word.md"
cp -a "$WORK/two-word.md" "$WORK/two-word.bak"
printf 'completely different text\n' > "$WORK/two-word.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/two-word.bak" "$WORK/two-word.md" >/dev/null 2>&1
check "a deleted two-word line is caught too" 1 $?

# Phrases are collected per line, so a phrase can only survive inside a whole line: one that the edit
# splits across a line break is reported, and one that stays inside a line is not.
printf 'alpha beta gamma\n' > "$WORK/perline.bak"
printf 'alpha beta\ngamma\n' > "$WORK/perline.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/perline.bak" "$WORK/perline.md" >/dev/null 2>&1
check "a phrase split across two lines does not count as survival" 1 $?
printf 'x alpha beta gamma y\n' > "$WORK/perline.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/perline.bak" "$WORK/perline.md" >/dev/null 2>&1
check "the same phrase inside one line still passes" 0 $?

# A skipped line is not a passed line: the run says how many were too short to judge.
printf 'x y z\nkeep this line long enough\n' > "$WORK/short-skip.bak"
cp -a "$WORK/short-skip.bak" "$WORK/short-skip.md"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/short-skip.bak" "$WORK/short-skip.md" >"$WORK/short-skip-out" 2>&1
check "an unchanged file is clean" 0 $?
grep -q 'not judged' "$WORK/short-skip-out"
assert "and the report says how many lines it skipped" $?

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

# A pool entry that cannot be read is announced, never silently dropped.
printf '\377\376\000binary\n' > "$WORK/pool-binary.bin"
python3 "$SCRIPTS/post-change-compare.py" "$WORK/pointers.bak" "$AGENT_HOME/POINTERS.md" \
  --pool "$WORK/pool-binary.bin" >"$WORK/pool-skip-out" 2>&1
check "an unreadable pool entry still reports the loss" 1 $?
grep -q 'not readable text' "$WORK/pool-skip-out"
assert "and the skipped pool file is counted out loud" $?

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

# A backup name is not a cross-reference: `IDENTITY.md.bak.20260101_000000` contains the string, and a
# substring test accepted it as one.
cp -a "$AGENT_HOME/USER.md" "$WORK/user-clean.md"
python3 - "$AGENT_HOME/USER.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("IDENTITY.md", "IDENTITY.md.bak.20260101_000000"),
                encoding="utf-8")
PY
python3 "$SCRIPTS/pointers-check.py" >"$WORK/bak-ref-out" 2>&1
check "a backup name is not a cross-reference" 1 $?
grep -q 'does not mention IDENTITY.md' "$WORK/bak-ref-out"
assert "and the report names the missing edge" $?
cp -a "$WORK/user-clean.md" "$AGENT_HOME/USER.md"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "restored cross-reference is clean again" 0 $?

# A reference aimed at the wrong skill: the file exists, just not where the line says it does.
mkdir -p "$AGENT_SKILLS_ROOT/another-skill/references"
printf '# shared notes\n' > "$AGENT_SKILLS_ROOT/another-skill/references/shared-notes.md"
printf '\nThe notes are in `references/shared-notes.md` under skill:example-skill.\n' >> "$AGENT_HOME/IDENTITY.md"
python3 "$SCRIPTS/pointers-check.py" >"$WORK/misaimed-out" 2>&1
check "a reference aimed at the wrong skill is caught" 1 $?
grep -q 'lives under skill:another-skill' "$WORK/misaimed-out"
assert "and the report names the skill that holds it" $?
python3 - "$AGENT_HOME/IDENTITY.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("under skill:example-skill",
                                                         "under skill:another-skill"), encoding="utf-8")
PY
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "naming the skill that holds it is clean" 0 $?

# A full stop after a skill name is punctuation, not part of the name — and stripping it must not make a
# name that really is absent resolve.
printf '\nMissing on purpose: skill:no-such-skill. See above.\n' >> "$AGENT_HOME/IDENTITY.md"
python3 "$SCRIPTS/pointers-check.py" >"$WORK/dot-skill-out" 2>&1
check "a skill name followed by a full stop still resolves" 1 $?
grep -q 'skill:no-such-skill — no such skill' "$WORK/dot-skill-out"
assert "and a genuinely missing name is still caught" $?
rm -f "$AGENT_SKILLS_ROOT/another-skill/references/shared-notes.md"
python3 - "$AGENT_HOME/IDENTITY.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text("".join(ln for ln in path.read_text(encoding="utf-8").splitlines(True)
                        if "shared-notes.md" not in ln and "no-such-skill" not in ln), encoding="utf-8")
PY
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "clean again after removing the mis-aimed line" 0 $?

echo "[3b] debt sentences and the opt-in absolute-path check"
cp -a "$AGENT_HOME/IDENTITY.md" "$WORK/identity-clean.md"
printf '\n## Recovery\n\nThe recovery section is TODO: write it later.\n' >> "$AGENT_HOME/IDENTITY.md"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "a debt sentence is reported" 1 $?
printf 'See `TODO` and `待建` for the wording that is exempt.\n' >> "$AGENT_HOME/IDENTITY.md"
python3 "$SCRIPTS/pointers-check.py" >"$WORK/debt-out" 2>&1
check "quoted debt wording is still a debt when unquoted elsewhere" 1 $?
cp -a "$WORK/identity-clean.md" "$AGENT_HOME/IDENTITY.md"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "clean again after removing it" 0 $?
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "absolute paths are NOT checked by default" 0 $?
(AGENT_CHECK_ABSOLUTE_PATHS=1 python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1)
check "absolute paths are checked when enabled" 1 $?

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
printf 'almost nothing\n' > "$AGENT_SKILLS_ROOT/example-skill/references/tiny.md"
printf '| `tiny.md` | a reference with almost no content |\n' >> "$AGENT_SKILLS_ROOT/example-skill/references/INDEX.md"
python3 "$SCRIPTS/index-audit.py" >"$WORK/tiny-out" 2>&1
check "an effectively empty reference does NOT fail the audit" 0 $?
grep -q 'effectively empty' "$WORK/tiny-out"
assert "but it is reported as an informational note" $?
rm -f "$AGENT_SKILLS_ROOT/example-skill/references/tiny.md"
python3 - "$AGENT_SKILLS_ROOT/example-skill/references/INDEX.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text("".join(ln for ln in path.read_text(encoding="utf-8").splitlines(True)
                        if "tiny.md" not in ln), encoding="utf-8")
PY

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

echo "[4f] a file referenced BY PATH that was archived"
mkdir -p "$AGENT_SKILLS_ROOT/.archive/example-skill/references"
echo "# only in this agent home" > "$AGENT_SKILLS_ROOT/example-skill/references/only-here.md"
printf '\n- `references/only-here.md` — a reference local to this skill\n' >> "$AGENT_SKILLS_ROOT/example-skill/SKILL.md"
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "a reference that resolves is clean before archiving" 0 $?
mv "$AGENT_SKILLS_ROOT/example-skill/references/only-here.md" \
   "$AGENT_SKILLS_ROOT/.archive/example-skill/references/only-here.md"
python3 "$SCRIPTS/pointers-check.py" >"$WORK/path-archive-out" 2>&1
check "the same reference is reported once archived" 1 $?
grep -q '\[4\]' "$WORK/path-archive-out"
assert "and it is classified as recoverable, not broken" $?
mv "$AGENT_SKILLS_ROOT/.archive/example-skill/references/only-here.md" \
   "$AGENT_SKILLS_ROOT/example-skill/references/only-here.md"
rm -rf "$AGENT_SKILLS_ROOT/.archive"
rm -f "$AGENT_SKILLS_ROOT/example-skill/references/only-here.md"
python3 - "$AGENT_SKILLS_ROOT/example-skill/SKILL.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text("".join(ln for ln in path.read_text(encoding="utf-8").splitlines(True)
                        if "only-here.md" not in ln), encoding="utf-8")
PY
python3 "$SCRIPTS/pointers-check.py" >/dev/null 2>&1
check "clean again after the cleanup" 0 $?

echo "[5] snapshot-context.sh"
"$SCRIPTS/snapshot-context.sh" >/dev/null 2>&1
check "snapshot writes without pruning" 0 $?
snap_count="$(find "$AGENT_BACKUP_DIR/snapshots" -mindepth 1 -maxdepth 1 -type d | wc -l)"
assert "one snapshot directory exists" "$([ "$snap_count" -eq 1 ] && echo 0 || echo 1)"
"$SCRIPTS/snapshot-context.sh" --prune abc >/dev/null 2>&1
check "non-numeric --prune is refused" 2 $?
"$SCRIPTS/snapshot-context.sh" --prune 1 >/dev/null 2>&1
check "--prune 1 keeps the newest" 0 $?
"$SCRIPTS/snapshot-context.sh" >/dev/null 2>&1
"$SCRIPTS/snapshot-context.sh" >/dev/null 2>&1
snap_count="$(find "$AGENT_BACKUP_DIR/snapshots" -mindepth 1 -maxdepth 1 -type d | wc -l)"
assert "back-to-back snapshots never overwrite each other (3 dirs)" "$([ "$snap_count" -eq 3 ] && echo 0 || echo 1)"
"$SCRIPTS/snapshot-context.sh" --prune 99999 >/dev/null 2>&1
check "--prune refuses an absurd keep count" 2 $?

echo "[6] archive-baks.py"
python3 "$SCRIPTS/archive-baks.py" plan --keep abc >/dev/null 2>&1
check "--keep with a non-numeric value is refused" 2 $?
python3 "$SCRIPTS/archive-baks.py" plan --keep 0 >/dev/null 2>&1
check "--keep 0 is refused (it would pack everything)" 2 $?
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
