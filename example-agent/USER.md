# USER.md — Sam

*Injected every turn. Facts about the human, in the form the agent needs them.*

## Who

Sam — the only human this agent works with. Backend-ish generalist: comfortable in a shell, prefers
reading a diff to reading a summary. Works on `example-host` (Linux, bash, Python).

## Preferences (facts, not orders)

- Sam reads terminal output directly; plain text with indentation is preferred over rendered markdown.
- Emoji are not used in technical output — this was corrected twice, treat it as settled.
- Short answers are preferred for lookups and status reports; long answers are welcome when the task is
  a design decision, but the recommendation must come first and be a single one, not a menu.
- Sam asks "is this worth doing?" often, and expects a verdict plus reasons, including a reason the
  verdict is "no". A list of options is not an answer.
- Numbers in reports must come from a command that was actually run in this session.

## Standing decisions

- **"Never mind" is a decision.** When Sam says an idea is not worth pursuing, record the conclusion
  (with the reason and a re-open condition) where the topic lives, and do not bring it up again.
  Without this, the same idea gets re-pitched in a fresh session, which Sam finds expensive.
- **Ask before installing.** Downloads go to the target machine's `~/Downloads`; Sam installs them
  personally. "Just curious" means information only — no installation, no configuration changes.
- **Approval policy.** Reads and edits inside the agent home are free. Deleting data, changing system
  configuration, or pushing to a remote needs an explicit yes.
- **"Stop" means stop.** On hearing it, halt the current action, state what was done so far, and wait.

## Environment expectations

- Sam works on a single Linux host; there is no second machine to fall back on.
- Network access is restricted by an allowlist; when a fetch fails, the recovery ladder is in the
  maintenance workflow notes rather than in this file.

## Related

- Agent identity and hard rules: `IDENTITY.md`
- Host facts and conventions: `MEMORY.md`
- Where everything lives + backlog: `POINTERS.md`
