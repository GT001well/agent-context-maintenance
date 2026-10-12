---
name: third-skill
description: "Use when a reference set has outgrown a flat directory. Demonstrates a nested references/ layout and how the index names a nested file."
version: 1.0.0
---

# Example skill — a nested reference set

This skill exists to show one layout rule and nothing else: when `references/` grows subdirectories, the
index table lists the **real path** of a file (`2026/03/<file>.md`), never the directory that holds it. A
directory is not a file, so an index row naming one is not a pointer to anything.

## When to use it

- a reference set organised by month, quarter or topic
- the flat directory has stopped being readable without opening it

## Procedure

1. Keep undated material at the top of `references/`; put dated material in `YYYY/MM/`.
2. List every file in `references/INDEX.md` by its real path, one row per file.
3. Point at the index once from the body, as below, so the audit can see the table is reachable.
4. Run `python3 scripts/index-audit.py`: it checks both directions, so a missing row and a row for a file
   that is not there are both failures.

## Related references

- `references/INDEX.md` — the index table for this skill's references
- `references/quick-start.md` — the flat case, listed by its name
- `references/2026/03/decision-log.md` — the nested case, listed by its real path
