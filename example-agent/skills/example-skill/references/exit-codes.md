# Exit codes

Callers (a human, a shell script, an agent) act on the exit code, not on the prose. These are the
codes the scripts in this repository use.

| Script | Code | Meaning |
|---|---|---|
| `pre-change-backup.sh` | 0 | every argument was backed up |
| | 1 | at least one argument did not exist (the rest were backed up) |
| | 2 | usage error (no arguments) |
| `post-change-compare.py` | 0 | no line is suspicious |
| | 1 | one or more lines look lost — read them |
| | 2 | usage error, or a file could not be read |
| `snapshot-context.sh` | 0 | snapshots written (nothing deleted without `--prune`) |
| | 2 | no context file found, or `--prune` got a non-numeric argument |
| `archive-baks.py` | 0 | done — including "nothing to pack" and dry runs |
| | 2 | usage error / missing backup directory / invalid day count |
| | 3 | the packing subprocess failed (nothing was deleted) |
| `pointers-check.py` | 0 | every checked dimension is clean |
| | 1 | at least one owned dimension has an entry |
| | 2 | usage error / missing context directory |
| `index-audit.py` | 0 | clean |
| | 1 | at least one owned dimension has an entry |
| | 2 | usage error / missing skill tree |

## Why "owned dimensions" matters

A check prints some findings as information only — for example, an oversized `SKILL.md`, which is a
sizing opinion rather than a defect. Those never set the exit code.

The reasoning is practical: an exit code that is red every single day carries no information, so people
stop looking at it, which is strictly worse than having no exit code at all. A check must be green on a
healthy tree, and red only for things the author is expected to fix.

## Why "nothing to do" is 0 and not an error

`archive-baks.py` running out of work to do is the normal steady state, not a failure. Reserving a
non-zero code for it means every scheduled run looks like a problem report, and the code stops being
read. Only "the argument was invalid" (2) and "the work failed" (3) are codes that demand attention.
