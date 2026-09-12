# Worked examples

Two real edits against `example-agent/`, with the comparator's actual output. Reproduce them with
`scripts/selftest.sh`, which asserts exactly these outcomes.

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
  L45: - **A vector index for cross-session recall.** Rejected for this deploym
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
[v] no content lost (47 lines compared)
```

Exit code `0`. The tokens now exist in the pool, so the deletion is read as a move. This is why the
flag exists: without it, every reorganization of content produces a wall of false alarms, and a check
that cries wolf on every reorganisation gets ignored exactly when it matters.
