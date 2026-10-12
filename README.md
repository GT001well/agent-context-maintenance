# agent-context-maintenance

> A minimal, runnable reference for **layered agent context** — identity / user / memory / pointers —
> plus the maintenance toolchain that keeps those layers from rotting.

[中文说明](README.zh-CN.md) · this file is the English version

Everything in this repository is **example data**: the agent is "Alice", the user is "Sam", the host is
`example-host`. No file, path or name was taken from a live deployment; the lessons in `docs/` are the
one part that is not invented, and they carry nothing that identifies where they came from.

## Who this applies to

An agent needs this when three things are true at once: (1) files are loaded or injected when a session
starts, (2) the agent writes some of its own long-lived notes, and (3) it **compacts or summarises** its
context when the window fills. The third one is what makes the other two dangerous. When history gets
summarised, anything that lived only in the conversation becomes somebody's summary of it, while a written
file is still itself.

The ones with the most at stake are **self-maintaining**: the agent writes its own skills, keeps notes or
a diary, and reads them back in a later session. There, a compaction does not just lose a conversation, it
loses part of the agent's own working memory. Where a product's self-writing behaviour is not evident, the
table below does not claim it; the three conditions are what decide.

That shape is not specific to one product. As of this writing it describes, among others:

| Agent | Long-lived notes it loads | Writes its own notes? | How the context gets compacted |
|---|---|---|---|
| Claude Code | `CLAUDE.md`, plus memory files loaded at conversation start | — | automatic compaction as the window fills |
| Cline | `.clinerules` | — | context-window management that summarises older turns |
| Codex CLI | `AGENTS.md` | — | auto-compact at a token threshold |
| Cursor | `.cursor/rules`, saved memories | saves memories itself | conversation summarisation, memories |
| Gemini CLI | `GEMINI.md` | — | `/compress`, plus an automatic threshold |
| GenericAgent | on-disk notes and seed code | self-evolving by design | compacts what it carries, to keep decision-relevant density up |
| Hermes Agent | `SOUL.md` and curated memory files, injected every turn | maintains its own skills and memory | context compaction, resumed from a summary plus stored state |
| OpenClaw | `MEMORY.md` plus a tree of Markdown files in the workspace; daily logs read at session start | writes daily memory notes and skills | compaction near the top of the window |
| open-strix | memory blocks and files, committed to its own repository | schedules and audits its own work | managed by the harness it runs on |

Those names are examples, not a compatibility claim: the products change faster than the shape does, and
this repository is not affiliated with any of them. Check the three conditions against whatever you are
running. With only the first, the four-layer split is overkill. With all three, the layers below are the
cheapest thing that keeps the notes from rotting.

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

## The approach

1. **Split context by how often it is read, not by topic.** Injected files are a budget; on-demand files
   are an index. Grade every fact before writing it down: **A** every turn, **B** a skill plus one
   pointer, **C** recomputable (record the command, never the answer).
2. **A change is not finished until it is checkable.** Back up, edit, compare against the backup, run the
   checks. Underneath: the agent making the edit must not be the only witness to it.
3. **A check is only useful while it is trusted.** Freeze the IDs; only owned dimensions set the exit
   code; one judgement, one home; both directions tested, a harmless edit passes and a real loss fails.
4. **Pointers have three outcomes, not two** (resolves / recoverable / broken). Collapsing "filed away"
   into "lost" teaches people not to file anything away.

The details, including the counter-intuitive parts, are in `docs/`.

## Layout

```
.
├── README.md                    this file
├── README.zh-CN.md              Chinese version
├── CHANGELOG.md                 what changed, newest first
├── LICENSE                      MIT
├── .editorconfig                formatting, so an editor agrees with the repository
├── config.example.env           every knob the scripts read
├── .github/workflows/selftest.yml   the same checks, on every push
├── docs/
│   ├── design.md                why four layers, what belongs in each
│   ├── maintenance-workflow.md  the edit loop and the rules that make it work
│   ├── check-dimensions.md      how findings are numbered, and how pointers self-repair
│   ├── writing-a-check.md       the walkthrough for adding one
│   ├── incidents.md             four failures that produced the rules
│   └── pitfalls.md              twelve ways this system rots (and the fix)
├── example-agent/               a demo agent home the scripts can act on
│   ├── IDENTITY.md  USER.md  MEMORY.md  POINTERS.md
│   └── skills/
│       ├── example-skill/{SKILL.md, references/INDEX.md, references/*.md}
│       ├── another-skill/{SKILL.md, ...}
│       └── third-skill/{SKILL.md, references/INDEX.md, references/2026/03/*.md}
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

CI runs the same three commands on every push, so what the Actions tab shows and what a local run prints
mean the same thing. To add your own check, `docs/writing-a-check.md` is the walkthrough.

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

Backups land in `AGENT_BACKUP_DIR` (the script prints the path), never beside the file they protect:
`.bak` files sitting in the context directory get counted as content by every scan.

Only `compare` needs reading:

- It prints the lines that disappeared, and why it thinks so:

  ```
    L50: - A vector index for cross-session recall. Rejected for this deploym
           tokens gone: cross-session, deployment:, recall. | no phrase survives (14 checked)
  [!] 1 line(s) look lost — read them before trusting the edit
  ```

- Exit 1 means "read these", not "the edit failed". The judgement is deliberately biased toward false
  alarms: one costs a glance, a silent loss costs the content.
- If the content moved rather than went away, name the destination with `--pool DIR_OR_FILE` and the same
  line comes back green.

`check` runs two scripts that each own their exit code and print `file:line`. `snapshot` leaves a
timestamped copy of the four files behind. The full ruleset, including the counter-intuitive parts, is in
`docs/maintenance-workflow.md`.

## Provenance

This is not a port of an existing framework. The four layers, the edit loop and the check numbering were
derived from a maintenance workflow that evolved in practice around a single long-lived agent, and then
stripped of every deployment-specific part.

What it borrows are ordinary practices, used in their normal sense: write-ahead backup before editing,
golden and snapshot testing, linters that own their own exit code, a two-phase `plan` then `apply` for
anything destructive, append-never-overwrite, documentation treated as data that the checks read, and a
review that arrives carrying the previous round's fix list.

## License

MIT — see `LICENSE`.
