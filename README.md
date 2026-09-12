# agent-context-maintenance

> A minimal, runnable reference for **layered agent context** — identity / user / memory / pointers —
> plus the maintenance toolchain that keeps those layers from rotting.

[中文说明](README.zh-CN.md) · this file is the English version

Everything in this repository is **fictional example data**: the agent is "Alice", the user is "Sam",
the host is `example-host`. Nothing here was copied from a real deployment. See [Scope](#scope).

## Why

Long-lived agents accumulate four kinds of written context, and they age differently:

| Layer | File | Injected every turn? | Ages by |
|---|---|---|---|
| Identity | `IDENTITY.md` | yes | drifting away from the deployed behavior |
| User | `USER.md` | yes | growing until it eats the context budget |
| Memory | `MEMORY.md` | yes | filling with facts that belonged in a task skill |
| Pointers | `POINTERS.md` | **no** — read on demand | going stale, silently |

Two failure modes kill these files, and neither is "the agent forgot to write something down":

1. **Silent link rot.** A pointer that stops resolving produces no error, so the agent simply stops
   finding the content — and nobody notices for weeks.
2. **Unverified edits.** An agent rewrites a file, loses three lines it meant to keep, and reports
   success. Without a pre-edit backup and a post-edit comparison, "looks fine" is the only signal.

This repo is the smallest thing that addresses both: four context files with a written contract,
a skill tree with an index convention, and six scripts that make edits and links *checkable*.

## The approach, in one screen

1. **Split context by how often it is read, not by topic.** Identity, user and memory are injected every
   turn, so they are a budget; pointers are read on demand, so they are an index. Grade every fact before
   writing it down: **A** (needed every turn) / **B** (needed for a class of tasks → a skill, plus one
   pointer) / **C** (recomputable → record the command, never the answer).
2. **A change is not finished until it is checkable.** Back up first (a physical action, not an
   intention), edit, compare against the backup, run the checks, snapshot. The rule underneath: *the
   agent making the edit must not be the only witness to it.*
3. **A check is only useful while it is trusted.** Freeze the finding IDs, give the exit code only to the
   dimensions you own, keep each judgement in exactly one place, re-check the legitimate spellings
   whenever a rule is tightened, and test in both directions: a harmless edit passes, a real loss fails.
4. **Pointers have three outcomes, not two** — resolves / recoverable (archived) / broken. Collapsing
   "filed away" into "lost" is how people learn not to file anything away.

The details, including the counter-intuitive parts, are in `docs/`.

## Layout

```
.
├── README.md                    this file
├── README.zh-CN.md              Chinese version
├── LICENSE                      MIT
├── config.example.env           every knob the scripts read
├── docs/
│   ├── design.md                why four layers, what belongs in each
│   ├── maintenance-workflow.md  the edit loop and the rules that make it work
│   ├── check-dimensions.md      how findings are numbered, and how pointers self-repair
│   └── pitfalls.md              twelve ways this system rots (and the fix)
├── example-agent/               a demo agent home the scripts can act on
│   ├── IDENTITY.md  USER.md  MEMORY.md  POINTERS.md
│   └── skills/
│       ├── example-skill/{SKILL.md, references/INDEX.md, references/*.md}
│       └── another-skill/{SKILL.md, ...}
└── scripts/
    ├── _config.py               shared path resolution (one home for the path rules)
    ├── _config.sh               the same, for the shell scripts
    ├── pre-change-backup.sh     back up before editing (never overwrites)
    ├── post-change-compare.py   did the edit drop anything?
    ├── snapshot-context.sh      timestamped snapshots of the four files
    ├── archive-baks.py          pack old backups, keep the newest N
    ├── pointers-check.py        do the pointers and cross-references resolve?
    ├── index-audit.py           do the skill indexes match the disk?
    └── selftest.sh              copy the demo tree to /tmp and run all of the above
```

## Quick start

No install. Dependencies: `bash`, `python3` (3.8+), coreutils, `tar`, and GNU `findutils` (the snapshot
script uses `find -printf`).

```bash
git clone <this repo>
cd agent-context-maintenance
./scripts/selftest.sh          # runs every script against a throwaway copy of example-agent/
```

To point the scripts at your own agent home instead:

```bash
export AGENT_HOME=/path/to/your/agent/home     # holds the four .md files
export AGENT_SKILLS_ROOT=$AGENT_HOME/skills    # the skill tree
export AGENT_BACKUP_DIR=/path/outside/the/tree # backups never land inside what they protect
```

## The edit loop

```
backup → edit → compare → check → snapshot
```

```bash
./scripts/pre-change-backup.sh example-agent/MEMORY.md
$EDITOR example-agent/MEMORY.md
python3 scripts/post-change-compare.py .backups/MEMORY.md.bak.<stamp> example-agent/MEMORY.md
python3 scripts/pointers-check.py
./scripts/snapshot-context.sh
```

Every backup lands in `AGENT_BACKUP_DIR` (printed by the backup script), never beside the file it
protects: a pile of `.bak` files in the context directory is how a scanner starts counting backups as
content.

The point is not ceremony. It is that the agent performing the edit cannot be the only witness to it:

- `post-change-compare.py` exits **1** when a line from the backup no longer appears in the new file
  *and* any of these is also true: a structured token (path, identifier, number) is gone from the whole
  file, a run of CJK text is gone, or none of the line's three-word phrases survives. It is a heuristic,
  deliberately biased toward false alarms: a false alarm costs one glance, a silent loss costs content.
  Plain Latin words are not distinctive on their own, so rewording a sentence still passes. Lines under
  8 characters are not judged at all, and the report caps at 40 findings (it says how many it omitted).
- `pointers-check.py` exits **1** on its own dimensions and reports `file:line`; `index-audit.py` exits
  **1** on its own dimensions and reports paths. Either way, "the checks are green" is a machine claim,
  not a feeling.
- `--pool DIR_OR_FILE` tells the comparison that content was *moved*, not lost (into a skill, another
  file).

Full rules, including the ones that are counter-intuitive, are in `docs/maintenance-workflow.md`.

## Design rules distilled

1. **The backup is the first physical action, not the first idea.** "I remembered to back up" is not a backup.
2. **Injection is a budget.** Everything in `IDENTITY.md`, `USER.md`, `MEMORY.md` is paid for on every
   turn. Detail belongs in a skill, referenced by a pointer.
3. **A pointer that cannot be checked will rot.** Register pointers in one place; make them resolvable.
4. **Nothing important lives only in `MEMORY.md`.** Memory gets compacted; procedures belong in skills.
5. **One rule, one home.** The same judgement written in two scripts drifts; the second copy imports the first.
6. **Scripts only add, never overwrite.** Same-second reruns must not eat the previous backup.
7. **Number your findings and freeze the IDs.** `[C]` means the same check forever; renumbering is a
   measured cost, not tidying. Owned dimensions set the exit code, informational ones never do.
8. **Pointers get three outcomes, not two** — resolves / recoverable (archived) / broken. Collapsing
   "filed away" into "lost" throws away the part that makes a report actionable.
9. **A checker needs its own exit code** — but only for the dimensions it owns, or the code becomes noise.
10. **Self-test in both directions.** "Reworded text passes" and "deleted text is flagged" are two different tests.

## Scope

- All content is example content. The agent ("Alice"), the user ("Sam"), the host name, the paths,
  the skills and every fact in `example-agent/` are invented for demonstration.
- The scripts are self-contained rewrites of a workflow that evolved elsewhere; they carry no
  deployment-specific configuration and read every path from `config.env` (copied from
  `config.example.env`) or from the environment.
- Tested on Linux (bash 5, Python 3.8+) only.

## Provenance

This is not a port of an existing framework, and it names none: the four layers, the edit loop and the
check numbering were derived from a maintenance workflow that evolved in practice around a single
long-lived agent, and then stripped of every deployment-specific part.

What it borrows are ordinary practices, used in their normal sense: write-ahead backup before editing,
golden and snapshot testing, linters that own their own exit code, a two-phase `plan` then `apply` for
anything destructive, append-never-overwrite, documentation treated as data that the checks read, and a
review that arrives carrying the previous round's fix list.

## License

MIT — see `LICENSE`.
