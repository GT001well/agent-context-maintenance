---
name: example-skill
description: "Use when backing up and comparing files before and after an agent edit. Demonstrates the skill format, the frontmatter contract, and the reference-index convention used in this repository."
version: 1.0.0
---

# Example skill — backup and compare

A skill is a small, self-contained procedure with a trigger. The first 57 characters of `description`
are what an agent sees in the skill list, so the trigger has to be at the start: `Use when <trigger>.`

## When to use it

- before editing a file that an agent, rather than a human, is about to rewrite
- when an edit's result needs to be checked rather than trusted
- when content may have *moved* rather than been deleted

## Procedure

1. Take the backup first, as a physical action:

   ```bash
   ./scripts/pre-change-backup.sh <file>
   ```

2. Make the edit. Keep it minimal — a diff that touches formatting everywhere cannot be compared.
3. Compare, and read the exit code:

   ```bash
   python3 scripts/post-change-compare.py <backup> <file>
   ```

4. If content legitimately moved elsewhere, re-run with the destination as a pool:

   ```bash
   python3 scripts/post-change-compare.py <backup> <file> --pool skills/
   ```

## What "suspicious" means

A line is reported when it is missing verbatim **and** any of these also holds: a structured token
(identifier, path, number) is gone from the file as a whole, a run of CJK text is gone, or none of the
line's three-word phrases survives. Rewording passes; deletion does not. `--pool DIR_OR_FILE` marks
content as moved rather than lost.

Two limits to know about: lines shorter than 8 characters are not judged (too little signal), and the
report prints at most 40 findings, then says how many it omitted.

## Related references

- `references/INDEX.md` — the index table for this skill's references
- `references/worked-examples.md` — one reworded edit and one destructive edit, with real output
- `references/exit-codes.md` — what each script's exit code means
