# Frontmatter contract

The frontmatter is not decoration — a missing or malformed field makes the skill invisible or
mis-triggering, and nothing reports an error.

```yaml
---
name: example-skill          # must match the directory name, lowercase, hyphens
description: "Use when ..."  # trigger first; the skill list shows ~57 characters
version: 1.0.0               # bump by hand when the body changes materially
---
```

## Field rules

- `name` — must match the directory name. A mismatch produces two skills that look like one, or one
  that cannot be loaded by name.
- `description` — starts with the trigger phrase. Assume everything after the first ~57 characters is
  visible only after the skill is opened.
- `version` — optional but useful: it is the only signal that a skill's body changed in a way the
  trigger does not describe.

## Adopting a skill written elsewhere

Record the origin (repository plus the commit or version) in the body, not in the frontmatter, and note
whether it is expected to receive upstream updates. A skill that has been edited locally will normally
stop being updated by whatever sync mechanism brought it in — that is worth writing down once, in the
place a future editor will read, because it is otherwise discovered only after a confusing divergence.
