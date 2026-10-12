# Adding a check

`docs/check-dimensions.md` says what a dimension is and the rules for numbering one. This is the
walkthrough: the places a new dimension touches, and the order to touch them in.

The worked example is real — it produced `[1]`'s attribution rule. A context file named `skill:alice` on
a line, and backticked `references/notes.md` next to it; that file exists, but only under `skill:bob`.
The resolution ladder called the reference broken. It was not broken. It was aimed at the wrong skill.

## 0. Decide it is a check and not a hope

Ask what the code would have to read to decide it, and whether healthy input can satisfy it.

- A judgement that needs a list of words to work (markers, synonyms, "phrases that mean *when*") is a
  wording check. It will be red on prose a human wrote correctly, and a check that is red on healthy
  input is the one people turn off. Write the rule in prose instead and add it to the "deliberately left
  to the deployment" list in `docs/check-dimensions.md`. This was learned the expensive way: an anchor
  check with a marker list was written, tried against three legitimate wordings, and withdrawn the same
  day.
- A judgement that needs another system's policy (staleness, pinning, release state) belongs to whoever
  owns that policy. Take the list as input or leave the check out.

If it survives both questions, it is a check.

## 1. Put it in an existing dimension first

New IDs are forever, and renumbering is a measured cost. The attribution rule went into `[1]` rather
than becoming `[7]`: it is the same failure — a reference a reader cannot follow — with a better message.
Append a new ID only when the failure mode is genuinely new.

## 2. Declare it in the docstring

`pointers-check.py`'s docstring is the registry of record: a dimension that is not declared there does
not exist. One short paragraph per dimension, saying what it catches and why it is worth a red.

## 3. Write the narrowest function that decides it

One predicate per function, named for the decision, with a docstring that says what it deliberately does
not do. If a second script needs the same predicate, it moves to `_config.py` and both import it — the
"one rule, one home" rule is what keeps two checkers from disagreeing.

```python
def owners_of(candidate: str) -> List[str]:
    """Skill names holding a file that matches `candidate` by full relative path or by suffix."""
```

## 4. Wire it in, and keep the exit-code policy

Owned dimensions set the exit code; informational findings are printed and change nothing. If your check
can be wrong for reasons the author does not control (an upstream tree, a file that will not decode),
print it and say why it is not in the code. If it cannot read an input, say so: silence about a
degradation is how a green code comes to mean less than it claims.

## 5. Test it three ways

Add the cases to `scripts/selftest.sh`, which runs against a throwaway copy of `example-agent/`.

1. **The harmless case passes.** Reword the text the check watches; the run must stay green.
2. **The real failure is caught.** Delete or mis-aim it; the run must exit 1 and name it.
3. **Break the rule on purpose.** Put the old judgement back and confirm case 2 goes red. An assertion
   that passes in both worlds is a regression guard, not evidence — keep it, but do not count it as
   coverage of the rule. Of the eight assertions added with one round of fixes here, two turned out
   unable to tell the fix from its absence.

Then run all three of these, from the repository root:

```bash
./scripts/selftest.sh
python3 scripts/pointers-check.py
python3 scripts/index-audit.py
```

## 6. Update the tables that describe it

- `docs/check-dimensions.md`: its dimension table, and the exit-code policy if your check changed it.
- `CHANGELOG.md`: if the check can now report something it could not report before, or return a
  different code, mark the entry `[check]`. That marker is what tells a reader to distrust an older green
  run.
- `example-agent/`: if you documented a convention, make the example tree follow it. A rule that no
  example exercises is a rule nobody notices is broken; that is how the "nested files are listed by their
  real path" convention stayed unsatisfiable while the documentation kept recommending it.
