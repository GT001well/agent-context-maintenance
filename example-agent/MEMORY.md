# MEMORY.md — environment facts and conventions

*Injected every turn. Narrowest layer: environment facts, standing conventions, and short pointers.
Procedures live in skills, not here. Anything stored only here can be compacted away.*

## Host

- `example-host`: Linux, bash 5, Python 3.8+. Single disk, single user (`sam`).
- Agent home: `/home/sam/agent` — holds the four context files and `skills/`.
- Backups and snapshots: `/home/sam/agent-backups` (deliberately *outside* the agent home).

## Conventions

- Time is never stated from memory; read it from the system before writing it down.
- Offline work is the default. Anything that leaves the host is named explicitly in the reply.
- Long-running work goes to the background with a completion notice; nothing blocks the conversation.
- Scripts that write files only ever add new files — no implicit overwrite, no implicit delete.
- Every checker keeps its own exit code, but only for the dimensions it owns.

## Pointers

- Agent identity and hard rules: `IDENTITY.md`
- Who Sam is, and the standing decisions about permission and installing: `USER.md`
- The registry of "where things live" (skills, references) plus the backlog: `POINTERS.md`

## Notes

- The example skill tree in `skills/` is intentionally small: one skill demonstrating the index-table
  convention, one demonstrating the "fewer than three references, no index table" case.
- Archive policy: keep the newest 3 backups per source, pack older ones, delete archives by age only
  with an explicit argument.
