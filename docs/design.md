# Design: four layers of agent context

The whole idea is to separate context by **how often it is read** and **how it ages**. Mixing those
two questions is what produces the usual outcome: one enormous notes file that is paid for on every
turn, mostly containing things that were relevant once.

## The four layers

### 1. Identity — `IDENTITY.md`

**Injected every turn.** Read it as: "if this were missing, the agent would immediately behave wrong."

Belongs here:

- who the agent is: name, voice, register (terse vs. chatty, formal vs. familiar)
- hard rules that cannot wait for a skill to load ("never do X", "always check Y first")
- a one-line direction to the pointers file, because that file is *not* injected

Does **not** belong here: procedures, checklists, long examples, anything that is only relevant to one
kind of task. Those are skills.

### 2. User — `USER.md`

**Injected every turn.** Who the human is, in the form the agent needs it:

- stable facts (name, role, environment they work in)
- preferences and corrections, phrased as facts ("prefers plain text, no emoji") not as orders
- what "stop" means to them, and which topics need permission first

Write preferences as **declarative facts, not instructions to yourself**. An injected imperative
("always answer in one word") gets re-read as a directive in later sessions and can override what the
human is asking for right now. A fact ("Sam prefers one-word answers for lookups") ages correctly.

### 3. Memory — `MEMORY.md`

**Injected every turn**, and therefore the narrowest layer. Environment facts and short operational
notes only:

- paths, ports, hardware, credentials *locations* (never secrets themselves)
- standing conventions that have no task-shaped home
- short pointers to where the detail lives

Two hard limits:

- **It gets compacted.** Anything stored only here can vanish. Procedures belong in a skill.
- **It is a budget.** Every character is re-sent on every request. When it grows, the fix is to move
  content into a skill and leave a pointer, not to shorten the facts.

### 4. Pointers — `POINTERS.md`

**Not injected.** Read on demand, because it is the index, not the content.

- one registry of "where things live" (which skill, which file, which section)
- the maintenance backlog: what is pending, what was evaluated and deliberately *not* changed
- a short "how to find this file" line in `IDENTITY.md`, or the file will never be read at all

Pointers are the layer most likely to rot silently, which is why `scripts/pointers-check.py` exists:
unresolvable pointers are reported (with `file:line`) instead of being discovered weeks later.

## A/B/C grading — where does a given fact go?

| Grade | Meaning | Home |
|---|---|---|
| **A** | needed every turn; losing it breaks behaviour immediately | `IDENTITY.md` / `USER.md` / `MEMORY.md` |
| **B** | real content, needed for a whole class of tasks | a skill (`SKILL.md` + `references/`), plus one pointer |
| **C** | reproducible on demand (versions, counts, command output) | nowhere; re-run the command instead of recording the number |

Grade C is the one people get wrong. "Current version is 4.2.1" is not knowledge, it is a cache. It
goes stale silently and then misleads. Record *how to ask*, never the answer.

## Injection vs. on-demand: the rule that decides everything

If a rule must apply **before the agent has decided what it is doing**, it has to be injected. If it
only applies once a task type is known, it belongs in a skill that loads with that task.

Corollary: a skill cannot trigger itself. "This skill is the default style" is useless as a trigger,
because nothing loads the skill in order to read that line. Defaults and boundaries live in
`IDENTITY.md`; the skill carries the detail once it is loaded.

## Writing triggers that actually fire

Triggers written as judgement calls do not fire — the agent decides it is "not working yet" and skips
them. Write them as **state + timing**:

- weak: "read the backlog when you start working"
- strong: "at session start, before the first reply, if the backlog's content is not already visible,
  read it once"

The strong version names an observable state ("content visible or not"), not a mood ("started working"),
and it survives context compaction because it does not depend on remembering that a read happened.
