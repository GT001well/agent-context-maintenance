---
name: another-skill
description: "Use when writing a new skill for this agent, or when a skill's trigger never fires. Covers the frontmatter contract and the reference-index convention."
version: 1.0.0
---

# Another skill — writing skills

Demonstrates the "fewer than three references" case: this skill has one reference file, so there is no
`references/INDEX.md` — the single reference is mentioned inline, in context, instead of getting a table
of its own. Tables for a one-line directory are overhead.

## Trigger rules

- The trigger is the first thing in `description`, because the skill list shows a truncated prefix.
- Write triggers as **state + timing**, not as judgement calls: "Use when a file is edited by an agent"
  fires; "Use when appropriate" does not.
- A skill cannot trigger itself. Defaults and boundaries belong in the injected identity file; the
  skill carries the detail once it is loaded.

## Body rules

- Imperative rules with the reason attached, one rule per item. A rule without its reason gets
  "simplified" away by the next editor.
- No changelogs, no dates, no incident narration. The lesson, not the story.
- Long lists of examples go into `references/`, not inline.

## Reference layout

| References in the skill | Convention |
|---|---|
| 3 or more files | one `references/INDEX.md` table; the skill body carries a one-line pointer to it |
| fewer than 3 files | no table; mention each file inline where it is relevant |
| nested directories | the index table lists the real path (`2026/03/<file>.md`, not `2026/`) |

The contract for the `description` field, including what to do when a skill is adopted from elsewhere,
is in `references/frontmatter-contract.md`.
