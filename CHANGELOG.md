# Changelog

Newest first. Written for someone who has a clone and wants to know what changed since they last pulled;
anything older than this file is in `git log`.

Entries marked **`[check]`** change what a checker reports or which exit code it returns. Read those
before trusting a green run you took earlier.

## New：2026-10-12

- **`[check]` Comparator: phrases are collected per line, and skipped lines are counted.** The phrase
  signal was built from one flattened word stream, so a phrase could "survive" by being formed from the
  end of one line and the start of the next, and a line of one or two words was skipped before it was
  counted. A three-word line of plain Latin text could be deleted outright and the run stayed green.
  Now: phrases are per line on both sides, three-word lines are judged, one- and two-word lines fall
  back to "not one of its words survives", and the report says how many lines were too short to judge.
- **`[check]` `archive-baks.py --keep` refuses a malformed value** instead of quietly using the default,
  and no longer accepts `0` (which packed and then deleted every backup of a source). The usage line
  mentions `--force`.
- **`[check]` `pointers-check.py`:** `[2]` no longer accepts a backup name as a cross-reference; `[1]`
  resolves a path against the skill named on the same line, so a reference that lives under a different
  skill is reported as mis-aimed rather than missing; and a skill name followed by a full stop
  (`skill:example-skill.`) is no longer read as a skill that does not exist.
- **`[check]` `index-audit.py` accepts a nested reference listed by its real path.** The table parser kept
  only the file name, so `2026/03/decision-log.md` was read as `decision-log.md` and reported as missing:
  the convention `docs/design.md` describes could not be satisfied by any spelling.
- A pool file that cannot be read is counted out loud instead of being dropped in silence, and the
  exit-code policy states the rule: a degradation is announced, and either enters the code or says why
  it does not.
- `example-agent/skills/third-skill/` demonstrates a nested `references/` layout; the self-test now
  covers `[B]` (three references and no index) and the nested-path rules.
- Documentation: the comparator's judgement now lives in three homes instead of five (its docstring,
  `docs/maintenance-workflow.md`, the example skill), and `worked-examples.md` was re-captured against the
  current output; both READMEs open with a "who this applies to" section, so a reader can tell in ten
  seconds whether the shape matches their agent.
- The two READMEs lost the parts that repeated `docs/`: the distilled rules list is gone (the short list
  above already states those rules) and the scope section is gone (the opening paragraph states it).
  Headings no longer carry parenthetical glosses; the meaning moved into the title or the first line of
  prose.
- New files: `docs/writing-a-check.md`, `docs/incidents.md`, `.editorconfig`, and CI that runs the same
  checks on every push.

## Earlier：2026-09-12, first publication

Summarised from `git log`; the commits are the record.

- Four context files (`IDENTITY` / `USER` / `MEMORY` / `POINTERS`) with a runnable example agent home.
- The maintenance toolchain: backup, compare, pointer check, index audit, snapshot, archive.
- Frozen dimension IDs; owned dimensions own the exit code; pointers with three outcomes (resolves /
  recoverable / broken).
- Five rounds of external review folded in, then the rename to `agent-context-maintenance`.
