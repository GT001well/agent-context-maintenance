# POINTERS.md — where things live

*Not injected. This is the index layer: read it on demand. `IDENTITY.md` carries the one-line
direction that makes it findable at all.*

## 一、What this file is

The single registry of pointers. Anything that needs to be findable later is registered here once and
referenced from elsewhere — never re-listed in the other three files. The other three carry their own
short "related" lines (`IDENTITY.md`, `USER.md`, `MEMORY.md`) so that each file knows the others exist.

## 二、Pointer registry

| What | Where | Notes |
|---|---|---|
| Maintenance loop and rules | `docs/maintenance-workflow.md` | the five steps, and why each exists |
| Context layer design | `docs/design.md` | what belongs in which layer, A/B/C grading |
| Check dimensions and pointer repair | `docs/check-dimensions.md` | why findings are numbered, and the three pointer outcomes |
| Known failure modes | `docs/pitfalls.md` | read before changing anything structural |
| Backups, snapshots and archives | `/home/sam/agent-backups` | outside the agent home on purpose |
| Skill: backup and compare helpers | skill:example-skill | walkthrough with worked examples |
| Skill: writing a new skill | skill:another-skill | frontmatter and the index convention |

## 三、Grades and conventions

- **A** — needed every turn (identity, user, environment facts). Lives in an injected file.
- **B** — real content for a class of tasks. Lives in a skill; registered here as a pointer.
- **C** — reproducible on demand (versions, counts, command output). Registered nowhere; re-run the
  command instead of caching the number.

Pointers are written once. When content moves, the pointer is updated in the same session, then
`scripts/pointers-check.py` is run — an unresolvable pointer fails silently otherwise.

## 四、Backlog

Housekeeping (see `docs/check-dimensions.md`, §9): when an item is finished it moves *out* of this file,
into a log or nowhere. This file is read on every maintenance pass, so finished text costs attention
forever and gets re-read as if it were still open.

- [ ] Add a worked example of `--pool` (content moved into a skill rather than deleted) to
      `docs/maintenance-workflow.md`.
- [ ] Decide whether `snapshot-context.sh` should also snapshot a skill tree, or stay context-only.
      Open question: it currently only covers the four files named in `config.example.env`.

### Evaluated, deliberately not changed — do not re-open

- **Automatic pruning of old snapshots.** Rejected: deletion as a side effect of creating a snapshot has
  exactly one failure mode (an empty snapshot directory) and it is only discovered when the snapshot is
  needed. Pruning stays a separate command with an explicit argument.
- **A vector index for cross-session recall.** Rejected for this deployment: four files plus a small
  skill tree are searchable with `grep`, and the index would add a service to keep alive. Re-open only
  if the corpus grows past what a keyword search can handle.
