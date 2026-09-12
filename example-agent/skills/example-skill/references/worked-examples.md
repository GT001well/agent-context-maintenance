# Worked examples

Two real edits against `example-agent/`, with the comparator's actual output. `scripts/selftest.sh`
exercises the same cases against a throwaway copy and asserts the exit codes; the numbers below were
captured by running the commands by hand.

## Example 1 — rewording a sentence (must pass)

```bash
export AGENT_HOME=.../example-agent AGENT_BACKUP_DIR=.../backups
scripts/pre-change-backup.sh "$AGENT_HOME/IDENTITY.md"
sed -i 's/no emoji, no filler\./no emoji, and no filler./' "$AGENT_HOME/IDENTITY.md"
python3 scripts/post-change-compare.py "$AGENT_BACKUP_DIR/IDENTITY.md.bak.<stamp>" "$AGENT_HOME/IDENTITY.md"
```

Output:

```
[v] no content lost (35 lines compared)
```

Exit code `0`. The word `filler` survived, the phrases around it survived, and the substituted words are
ordinary English — so the line counts as reworded, not lost. This is the case that a naive "line no
longer present verbatim" check gets wrong, and the reason ordinary Latin words are not treated as
distinctive.

## Example 2 — deleting a bullet (must be caught)

```bash
scripts/pre-change-backup.sh "$AGENT_HOME/POINTERS.md"
# delete the bullet starting with "A vector index for cross-session recall"
python3 scripts/post-change-compare.py "$AGENT_BACKUP_DIR/POINTERS.md.bak.<stamp>" "$AGENT_HOME/POINTERS.md"
```

Output:

```
  L50: - **A vector index for cross-session recall.** Rejected for this deploym
         tokens gone: cross-session, deployment:, recall. | no phrase survives (14 checked)
[!] 1 line(s) look lost — read them before trusting the edit
```

Exit code `1`, with the line number, the structured tokens that vanished, and the fact that none of the
line's 14 three-word phrases survives anywhere. Three independent signals agree — which is what makes
this a finding rather than a guess.

## Example 2b — the same deletion, but the content *moved* (must pass)

If the bullet was promoted into a skill instead of deleted, say so with `--pool`:

```bash
python3 scripts/post-change-compare.py "$AGENT_BACKUP_DIR/POINTERS.md.bak.<stamp>" "$AGENT_HOME/POINTERS.md" \
    --pool skills/
```

Output:

```
[v] no content lost (52 lines compared)
```

Exit code `0`. The tokens now exist in the pool, so the deletion is read as a move. This is why the
flag exists: without it, every reorganization of content produces a wall of false alarms, and a check
that cries wolf on every reorganisation gets ignored exactly when it matters.

## Example 3 — a pointer whose target was archived (recoverable, not lost)

Move `skills/another-skill/` into `skills/.archive/` (the default archive directory) and run the
pointer check:

```bash
mkdir -p "$AGENT_SKILLS_ROOT/.archive"
mv "$AGENT_SKILLS_ROOT/another-skill" "$AGENT_SKILLS_ROOT/.archive/another-skill"
python3 scripts/pointers-check.py
```

Output:

```
[4] .../POINTERS.md:22  skill:another-skill — archived at .../skills/.archive/another-skill; restore it or re-point (recoverable)
[!] 1 pointer problem(s) — [1] broken, [4] recoverable (archived)
```

Exit code `1`, but the message says *recoverable*: the fix is "restore it or re-point the pointer",
not "the content is gone". Separately, the index audit stays clean while the skill is archived:

```
[v] skill tree ok (1 skill(s), 0 informational note(s))
```

Archived directories are not live skills, so they are not audited as if they were. Without that
distinction, filing something away would produce the same alarm as deleting it — and the response to a
noisy check is to stop running it.
