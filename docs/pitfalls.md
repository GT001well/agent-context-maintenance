# Pitfalls

Ten ways this system rots. Each one was observed, and each one is cheap to prevent and expensive to
diagnose later.

## 1. Triggers written as judgement calls never fire

"Weak: read the backlog before starting work." The agent decides it has not started work yet and skips
it — a bare greeting is enough to defer the read forever. Write triggers as **state + timing**: "at
session start, before the first reply, if the backlog content is not already visible, read it once."

## 2. The same rule written in two places drifts

Two checkers each carrying their own copy of "what counts as a backup file" will disagree within two
weeks (one skips a name pattern the other does not). Pick one implementation, import it everywhere else.
The measurement that proves it: after consolidating, the real output should be **byte-identical**.

## 3. A checker without an exit code is a printed opinion

If every run ends "0", the only witness that a check failed is a human reading the report — and nobody
reads it. Give the check an exit code. But only count the dimensions it owns: a display-only warning
about a file the author does not control will turn the code red every day, and a permanently red check
is the same as no check.

## 4. Compressing injected text can delete the wiring

Injected files usually cross-reference each other ("details in `POINTERS.md`"). When trimming them for
size, those references look like the cheapest thing to cut — and then the pointers layer silently stops
being found, because nothing points at it any more. Symptom: after a size-reduction pass, a check that
verifies "every file names the other three" starts failing. Trim descriptions, not directions.

## 5. Backups inside the tree they protect

A backup directory under the skill tree gets scanned as content by every index check (inflating counts
and adding orphan entries), and a *directory-level* backup inside the tree can make a loader report the
skill name as ambiguous — the skill stops loading by its plain name. Rule: backups go outside the tree;
the backup script should enforce it rather than trusting the caller.

## 6. The editor is the only witness

The agent that edits is the agent that would have to notice it lost content. It will not, because it
believes it succeeded — the success signal it gets back is "the file was written". An external artifact
(pre-edit backup) plus an external judgement (post-edit comparison) is the only thing that makes loss
observable.

## 7. Documentation that trips the scanner that reads it

Documentation is data to a checker, so examples written casually become false positives. Two real ones
from this repository, both hit while building it:

- a backticked path used as an illustration (`2026/03/notes.md`) resolves nowhere, so it is reported as a
  broken link. Fixed by writing the placeholder form (`2026/03/<file>.md`) — a form the checker is told to
  skip.
- a skill that *discusses* not having a `references/INDEX.md` mentions the path in backticks, and the
  mention is indistinguishable from a real reference. Fixed by describing it in words.

Both were legitimate text and both would have been "fixed" by disabling the check — which is the real
danger: a check that fires on correct writing gets turned off, and then it protects nothing. Write
examples in a form that cannot trigger the check, and keep the trigger narrow.

Also worth knowing: the checkers here read the four context files and live `SKILL.md` files only. A
checker that also reads `README.md` and `docs/` will collect many more sentences that look like
references, and needs the same discipline plus a wider allow-list.

## 8. Snapshot and archive scripts that delete as a side effect

"Keep the newest 20" implemented as an implicit part of taking a snapshot can empty the directory on a
clock skew, a bad `sort`, or an unset variable. Deletion is a separate, explicit, argument-requiring
operation — and it prints what it will delete before doing it.

## 9. Thresholds without samples

A "suspicious if fewer than 60% of tokens survive" rule looks reasonable and is effectively always
true for short lines, while silently passing real losses in long ones. Every number in a check needs a
sample on either side of it. If you have no samples, use the strict rules (any distinctive token gone, no
phrase surviving), accept the false alarms, and let a human glance at them.

## 10. Config pointing at something that no longer exists

Deleting a tool, provider or backend while leaving its name in the configuration produces no error at
all: the feature is simply unavailable, and the only symptom is a status indicator that stays
"unavailable" with no explanation. When a component is removed, grep the configuration for its name in
the same session. If a check exists that resolves configured names, wire it in — "is the configured
provider actually registered?" is a one-line check that saves an hour of debugging the wrong layer.
