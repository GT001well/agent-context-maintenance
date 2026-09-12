# Check dimensions and pointer self-repair

The most reusable idea in this repository is not a script — it is how the checks are *organised*: every
finding belongs to a numbered dimension, and pointers are given three outcomes instead of two.

## Why findings carry IDs

A report line reads `[C] path/to/references/INDEX.md — entry 'ghost-file.md' is not on disk`. The ID is
the durable part:

- a backlog item, a commit message and a review comment can all name `[C]` and mean the same check,
  even after the message text is reworded;
- an ID survives the code being rewritten, moved between files, or merged into another checker;
- "which dimensions are red right now?" becomes a question with an answer.

The cost of renumbering is what makes this rule stick: in one real deployment, changing a dimension
name meant updating 40+ references scattered through documentation, backlogs and script comments. The
conclusion was "the benefit does not justify it — freeze the IDs and append new ones instead." Renumbering
is a decision with a price tag, not a tidy-up.

Two namespaces are used, and they never mix:

| Namespace | Layer | Example |
|---|---|---|
| bracketed numbers `[1]`… | pointers, links, cross-references between context files | `[4] archived target` |
| letters `A`… | the skill tree and its index tables | `[G] content with no SKILL.md` |

A reader must be able to tell which checker a finding came from without reading the whole report.

## The registry of record is the docstring

Each checker declares its dimensions at the top of the file, with one line per dimension. A dimension
that is not declared there does not exist — which keeps "what does this actually check?" answerable
without running anything.

## Exit-code policy

- **Owned dimensions** set the exit code (1).
- **Informational findings** are printed and never affect the code — a sizing opinion, or a condition
  in a file the author does not control. A code that is red every day carries no information, and a
  check nobody reads is worse than no check.
- **"Nothing to do" is 0**, not an error. A scheduled job that reports failure whenever there is
  nothing to pack trains everyone to ignore its output.

## Pointer self-repair

A pointer registry is only worth having if a broken pointer *says so*. Two outcomes — resolves / does
not resolve — are not enough, so this repository uses three.

### 1. Resolution ladder

A reference is resolved by trying, in order:

1. relative to the file that contains it
2. relative to the agent home
3. relative to the repository root
4. **suffix match anywhere in the repository** — because that is how people actually write references in
   prose: a bare file name (`post-change-compare.py`) or a partial path (`references/INDEX.md`)
5. the archive pass (below)

Without step 4 the checker reports correct writing as broken, and a checker that cries wolf gets
disabled.

### 2. Three outcomes, and why the third matters

| Outcome | Meaning | What the reader does |
|---|---|---|
| resolves | fine | nothing |
| `[4] archived …` | the target left the live tree but still exists in an archive directory | restore it, or re-point the pointer |
| `[1] … does not resolve` | genuinely gone | rewrite or delete the pointer |

Collapsing the middle case into "broken" destroys the most useful information available: *recoverable*
versus *lost* are different problems with different fixes. Filing content away is a normal operation,
and a system where archiving produces the same alarm as deletion is a system where archiving is
avoided.

### 3. Allow-list before accusation

Legitimate non-path forms are exempt by construction: templates with `<placeholders>`, globs, URLs, and
command lines. And when a judging rule is tightened, the legitimate forms must be re-checked in the
same pass — narrowing a matcher to path boundaries once flagged five perfectly reasonable spellings in
one run. **Tightening and "which forms are allowed" change together, then the check is re-run against
real data.**

### 4. Documentation is data

The scanner reads your docs, so an example written casually becomes a finding: a path in backticks that
does not exist, a skill name with its reference prefix, a quoted phrase right after a heading name. Write
examples in a non-triggering form (`2026/03/<file>.md`), or your own documentation becomes the first
false alarms — and false alarms are how a check gets ignored.

### 5. Cross-references between injected files

When several files are all injected every turn, they must name each other: *N* files produce *N×(N−1)*
edges. This is not decoration — the file that is *not* injected (the pointer registry) is discoverable
only through a line in an injected file. Trimming injected text for size is exactly what deletes those
lines, so the edge check is a guard on the trimming, not on the content. Symptom to watch for: after a
size-reduction pass, the "every file names the others" check starts failing, and the non-injected layer
has silently stopped being read.

### 6. One registration point

Pointers are registered in one file. Other files carry a single line pointing *to* that registry, never
a copy of its contents. Anything stored only in a memory-style file can be compacted away — and if the
pointers were embedded there, they go with it, silently, because nothing was checking them.

### 7. Orphan index

An index table that its own skill never references is unreachable: the file exists, the entries are
correct, and nothing will ever read it. Cheap to check, invisible otherwise.

## The dimensions shipped here

| Checker | ID | Dimension |
|---|---|---|
| `pointers-check.py` | `[1]` | broken `skill:` reference or unresolvable path |
| | `[2]` | a context file that does not name the others |
| | `[3]` | `references/INDEX.md` no SKILL.md points at |
| | `[4]` | target only present in an archive (recoverable) |
| `index-audit.py` | `[A]` | frontmatter `name` missing or mismatched |
| | `[B]` | three or more references but no index table |
| | `[C]` | index entry with no file on disk (ghost) |
| | `[D]` | file on disk missing from the index table |
| | `[E]` | duplicate skill directory name (ambiguous lookup) |
| | `[F]` | unclosed code fence |
| | `[G]` | directory with content but no SKILL.md |
| | `[i]` | informational: oversized SKILL.md (never sets the exit code) |

## Numbering your own checks

1. **List the failure modes you have actually hit.** Not the ones you can imagine — imagined checks
   never get wired to anything and rot.
2. Give each a stable ID and declare it in the checker's docstring.
3. Split owned from informational, then wire only owned dimensions into the exit code.
4. Test every check in both directions: a harmless edit must pass, a real loss must be caught. A check
   that has only ever run against healthy input proves nothing.
5. Freeze the IDs. Append new ones; renumber only if you have measured what renumbering costs.
