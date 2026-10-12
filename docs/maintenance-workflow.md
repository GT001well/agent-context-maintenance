# The maintenance workflow

```
backup → edit → compare → check → snapshot → (archive)
```

Each step exists because a specific failure was observed, not to be thorough. Skipping a step is
allowed; skipping it *silently* is what costs content.

## 0. Backup — the first physical action

```bash
./scripts/pre-change-backup.sh example-agent/MEMORY.md
```

- Backups never overwrite: a same-second rerun gets `-1`, `-2`, … This matters more than it sounds —
  "make a quick copy first" with `cp` silently eats the previous copy on a rerun.
- Every backup lands in `AGENT_BACKUP_DIR`, never beside the file it protects. A directory full of
  `.bak` files is scanned as content by every index check, and a *directory-level* backup inside the
  skill tree can make the loader report the skill name as ambiguous, so the skill stops loading by its
  plain name. The backup script enforces this rather than trusting the caller.
- The step is performed by the same agent that is about to edit. Which is exactly why it must be a
  *physical* action with an on-disk result: "I remembered to back up" cannot be verified afterwards.

## 1–2. Edit

Nothing special, except: keep the diff minimal. If a change touches formatting across the whole file,
the comparison in step 3 cannot tell a deliberate rewrite from a loss. The test is: *if this were rolled
back, could you name the exact lines that change back?* If not, the edit is doing too much at once.

## 3. Compare

```bash
python3 scripts/post-change-compare.py <backup> <edited>
python3 scripts/post-change-compare.py <backup> <edited> --pool "$AGENT_SKILLS_ROOT"   # content moved, not lost
```

The comparator reports a line as **suspicious** when it no longer appears verbatim **and** any of these
is also true:

1. a structured token of the line (identifier, path, file name, number) is gone from the edited file as a
   whole, or
2. a run of CJK text from the line is gone, or
3. none of the line's three-word phrases survives anywhere, or
4. the line is too short to carry a phrase (one or two words) and not one of its words survives anywhere.

Condition 1 alone is not enough — ordinary Latin words are deliberately not treated as distinctive, so
"deliberately" → "intentionally" is a reword, not a loss. Condition 3 is what carries English prose: a
deleted paragraph loses every phrase it had, while a reworded sentence keeps most of them. Condition 4 is
the narrow fallback for lines with nothing else to match on; requiring *every* word to be gone is what
keeps it from firing on every short line that happens to share a word with the rest of the file. The
signals together catch "this content is no longer anywhere" without turning every edit into a report.

Phrases are collected **per line**, on both sides (the edited file and each pool). Concatenating both
sides into one word stream — what this check did at first — invents phrases that join the end of one line
to the start of the next, and an invented phrase then counts as a survival. The failure that hides is the
one that matters most: a deleted line whose neighbours are untouched.

One consequence is worth knowing rather than discovering: re-wrapping a paragraph moves words across a
line break, so the phrases that used to sit inside one line no longer exist as written and those lines
are reported. That is the same limitation step 1–2 names — a change that reformats the file cannot be
told apart from a loss — so keep the diff minimal.

Exit code 1 means "look at these". It is deliberately biased toward false alarms: a false alarm costs a
glance, an unnoticed loss costs the content. One consequence is worth stating rather than discovering: a
three-word line has exactly one phrase, so any change to it is reported. Three-word lines in prose are
rare, and the alternative (silence) is the failure this check exists to prevent.

Two known limits, both documented rather than hidden: lines shorter than 8 characters are not judged at
all (too little signal), and the report prints at most 40 findings, adding a line saying how many were
omitted. The run also says how many lines were skipped for being short — a skipped line is not a passed
line, and a silent skip reads as full coverage.

**Do not** replace this with a ratio threshold
("60% of tokens still present") — ratios look reasonable, are effectively always true on short lines,
and silently pass real losses on long ones. Thresholds need samples behind them; if you have no
samples, prefer the strict rules above.

`--pool DIR_OR_FILE…` handles the legitimate case where content was moved (a paragraph promoted from
`MEMORY.md` into a skill). Pool text is searched with the same rules as the edited file, so a token, a
CJK run *or* a three-word phrase found in the pool counts as "still present". Weaker versions of this
check ("the longest run is in the pool") are satisfied by generic phrases and let real losses through.

A pool path that does not resolve is reported (`[!] pool path not found`) and skipped, so the run gets
*stricter*, never looser: a stale path shows up as false alarms rather than as silence. Pass a path that
resolves from wherever you run the script (`"$AGENT_SKILLS_ROOT"`, not a bare `skills/`).

## 4. Check

```bash
python3 scripts/pointers-check.py    # links, cross-references, index coverage
python3 scripts/index-audit.py       # skill tree vs. index tables
```

Design rules these scripts follow:

- **One rule, one home.** If the same judgement is written in two scripts, they drift. The second copy
  imports the first. (Observed three times before this became a rule.)
- **A checker gets its own exit code — but only for the dimensions it owns.** Dimensions that depend on
  upstream files the author does not control are printed as information and excluded from the code;
  otherwise the check reports red every day and the code stops meaning anything.
- **Tightening a rule requires re-checking the legitimate cases.** When a match was narrowed from
  substring to path-boundary, the first run flagged five legitimate spellings. Narrowing and "which
  forms are allowed" have to change together, then be re-run against real data.
- **Destroying arguments: invalid means refuse.** A destructive flag with a missing or malformed value
  prints usage and exits 2. No implicit default — "one typo deletes the archive" is not a risk worth
  taking. Also check the extremes: a "days" argument of 0 deletes everything, upper-plane digits parse
  as octal in shell, and huge values overflow the date arithmetic.

## 5. Snapshot

```bash
./scripts/snapshot-context.sh            # writes a timestamped copy of the four files
./scripts/snapshot-context.sh --prune 20 # delete beyond the newest 20 (explicit only)
```

Snapshots are cheap and timestamped; pruning is explicit and prints what it will delete first.
Never make "keep the last N" an implicit side effect of taking a snapshot: the failure mode (an empty
snapshot directory) is discovered exactly when it is needed.

## 6. Archive, occasionally

```bash
python3 scripts/archive-baks.py plan                      # show what would be packed
python3 scripts/archive-baks.py apply                     # pack, keep AGENT_ARCHIVE_KEEP per source
python3 scripts/archive-baks.py prune-archive 90 --apply  # delete archives older than 90 days
```

`plan` is read-only. `apply` is the only thing that packs; `prune-archive --apply` is the only thing that
deletes. Old archives are removed only with `--apply`, and the accompanying file list is deleted with the
archive, so no orphan lists accumulate.

## Testing a checker

A check that has only ever been run on a healthy file proves nothing. Test it in **both directions**:

1. make a harmless edit (reword a sentence) → the check must pass
2. delete a paragraph → the check must exit 1 and name the missing content

Then **break the rule on purpose**: put the old judgement back and confirm the case that covers it goes
red. An assertion that passes in both worlds is a regression guard, not evidence that the rule works —
keep it, but do not count it as coverage. This is measured, not theoretical: of the eight assertions
added along with three fixes here, two turned out unable to tell the fix from its absence, and that is
only visible by trying to make them fail.

If none of the three directions behaves, the check is decoration. `scripts/selftest.sh` does this against
a throwaway copy of `example-agent/`.
