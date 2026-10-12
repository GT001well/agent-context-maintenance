# Incidents

Four failures from one long-lived practice, anonymised. Each one produced a rule that is already stated
as a rule elsewhere in `docs/`; what is here is the shape of the failure, because the shape is what makes
the rule stick.

The common thread: none of these were found by reading the code, and none of them announced themselves.

## 1. The dimension that could never fire

A pointer that no longer resolved from the live tree, but did resolve inside an archive directory, was
supposed to be reported as *recoverable* rather than *broken*. The branch existed, the message was
written, the tests passed.

It had never printed once. The resolution ladder ends with a suffix match over the repository, and that
index included archived and hidden paths. So an archived file always "resolved somewhere", the
recoverable branch was unreachable, and a pointer into the archive was reported as broken — the one thing
the branch existed to prevent.

**Why it hid:** a dimension that never fires looks exactly like a dimension with nothing to report. Both
are silence, and silence reads as healthy.

**What it left behind:** the index excludes non-live paths on purpose, and the self-test has to exercise
the *positive* case of every dimension. "It has never complained" is not evidence.

## 2. The comparison that invented its own evidence

An edit-diff check flagged a line from the backup when the line was gone *and* one of three signals fired.
The third signal was phrase survival, and the phrases were generated from both files flattened into a
single word stream. A phrase could therefore be "found" by joining the end of one line to the start of the
next: a deleted line whose neighbours were untouched could look like it had survived.

The same check skipped lines shorter than eight characters *before* counting them. A line of three plain
words has no structured token and no CJK run, so it was skipped, uncounted and unmentioned. Deleting such
a line reported "no content lost".

**Why it hid:** both defects were in the direction of saying less. The report was clean, the exit code was
zero, and the only witness was the person who made the edit.

**What it left behind:** phrases are collected per line on both sides; skipped lines are counted and
printed; and every rule added to this check since has been tested by putting the old judgement back and
watching the new case go red.

## 3. The convention the checker refused

`docs/design.md` states that when a reference set grows subdirectories, the index table lists the real
path (`2026/03/<file>.md`) rather than the directory that contains it.

Nobody could comply. The table parser kept only the last path component, so the entry was read as
`decision-log.md`, and the ghost-entry check then looked for `references/decision-log.md`, did not find
it, and reported the correctly written row as an entry with no file. The convention had been recommended
for as long as it had been impossible.

**Why it hid:** the documentation was right, the checker was wrong, and no example followed the
convention — so the disagreement had nowhere to surface until someone tried to ship one.

**What it left behind:** the example tree now contains a nested reference set, and every convention that
has an example is a convention that gets exercised.

## 4. The promise that was only in prose

"Backups never land beside the file they protect." It was true of the design, written in the docstring,
and repeated in the README. The script implemented it by choosing a destination, and would happily write
into a backup directory configured *inside* the tree it was protecting.

The first real deployment did exactly that. Every index check started counting `.bak` files as content,
and a directory-level backup under the skill tree made a skill name ambiguous, so the skill stopped
loading by its plain name.

**Why it hid:** the rule was stated as a guarantee, so it was read as one. Nothing enforced it, and the
person running it had no reason to suspect their configuration.

**What it left behind:** the script refuses to run when the backup directory resolves inside the home or
the skill tree, and the self-test asserts both refusals. A rule with no enforcement is a wish.
