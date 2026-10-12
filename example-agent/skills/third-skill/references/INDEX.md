# References — index

The single authoritative table for the files in this directory. One line per file; a nested file is listed
by its **real path**, not by the directory that contains it.

`scripts/index-audit.py` checks both directions: every file on disk is listed here, and every row here
exists on disk. So a row written as `2026/03/` is reported twice over — once because nothing is listed for
that file, and once because the row itself points at a directory.

| File | What it contains |
|---|---|
| `quick-start.md` | the flat case: a file directly in `references/` |
| `2026/03/decision-log.md` | the nested case: listed by its real path |
