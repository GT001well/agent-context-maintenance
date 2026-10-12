#!/usr/bin/env python3
"""Did this edit drop anything?

Usage:
    post-change-compare.py <backup> <edited> [--pool DIR_OR_FILE ...] [--quiet]

A line from the backup is reported as **suspicious** when it no longer appears verbatim in the edited
file *and* any of these is also true:

  * one of its **structured tokens** (paths, identifiers, file names, numbers — anything containing a
    digit or one of `._/:-@`) is gone from the edited file as a whole
  * one of its runs of CJK text (2+ characters) is gone
  * none of its **3-word phrases** survives, for a line with enough words to carry one (3 or more)
  * a line too short to carry a phrase (1-2 words) where not one of its words survives anywhere

Ordinary Latin words are deliberately *not* treated as distinctive on their own: "deliberately" ->
"intentionally" is a reword, not a loss, and flagging it would make the check useless noise. Phrases
are what carry English prose, so a deleted paragraph loses every phrase it had.

Phrases are collected **per line**, from the edited file and from every pool. Flattening both sides into
one word stream (the behaviour this check shipped with) invents phrases by joining the end of one line
to the start of the next, and an invented phrase then counts as a survival — which weakens the check
exactly where it matters: the deleted line whose neighbours are untouched.

`--pool` marks content as *moved* rather than lost: a token or phrase counts as present when it exists
in the edited file or anywhere in the pool (a skill directory, for example).

Exit codes: 0 = clean, 1 = suspicious lines, 2 = usage/read error.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Set

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import pool_texts  # noqa: E402

STRUCTURED = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_./:+@-]{3,}")
CJK_RUN = re.compile(r"[\u4e00-\u9fff]{2,}")
WORD = re.compile(r"[A-Za-z0-9\u4e00-\u9fff]+")
MAX_REPORTED = 40
PHRASE_WORDS = 3


def structured_tokens(line: str) -> Set[str]:
    """Only tokens carrying structure: a digit, or a separator no plain English word has."""
    return {t for t in STRUCTURED.findall(line) if any(c.isdigit() or c in "./_:+@-" for c in t)}


def words_of(text: str) -> List[str]:
    return [w.lower() for w in WORD.findall(text)]


def phrases(words: List[str]) -> Set[str]:
    if len(words) < PHRASE_WORDS:
        return set()
    return {" ".join(words[i:i + PHRASE_WORDS]) for i in range(len(words) - PHRASE_WORDS + 1)}


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Compare a backup against the edited file.")
    parser.add_argument("backup")
    parser.add_argument("edited")
    parser.add_argument("--pool", action="append", default=[],
                        help="directory or file where moved content may now live (repeatable)")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    try:
        backup_text = Path(args.backup).read_text(encoding="utf-8")
        edited_text = Path(args.edited).read_text(encoding="utf-8")
    except OSError as exc:
        print(f"[x] cannot read: {exc}", file=sys.stderr)
        return 2
    if not backup_text.strip():
        print("[i] backup is empty; nothing to compare")
        return 0

    pools = pool_texts(args.pool)
    searchable = edited_text + "\n" + "\n".join(pools.values())
    surviving_words = set(words_of(searchable))
    surviving_phrases: Set[str] = set()
    for text in [edited_text, *pools.values()]:
        for raw_line in text.splitlines():
            surviving_phrases |= phrases(words_of(raw_line))
    edited_lines = {line.strip() for line in edited_text.splitlines() if line.strip()}

    suspicious: List[str] = []
    too_short = 0
    for number, raw in enumerate(backup_text.splitlines(), 1):
        line = raw.strip()
        if len(line) < 8 or line in edited_lines:
            if len(line) < 8:
                too_short += 1
            continue
        reasons: List[str] = []

        gone_tokens = sorted(t for t in structured_tokens(line) if t not in searchable)
        if gone_tokens:
            reasons.append("tokens gone: " + ", ".join(gone_tokens[:4]))

        gone_cjk = sorted(r for r in set(CJK_RUN.findall(line)) if r not in searchable)
        if gone_cjk:
            reasons.append("text gone: " + ", ".join(gone_cjk[:2]))

        line_words = words_of(line)
        own = phrases(line_words)
        if own:
            if not (own & surviving_phrases):
                reasons.append(f"no phrase survives ({len(own)} checked)")
        elif line_words and not any(word in surviving_words for word in line_words):
            # One or two words: too short to carry a phrase, so the only usable signal is that not a
            # single word of the line survives. Loosening this to "any word survived" would fire on
            # every short line that happens to share a word with the rest of the file.
            reasons.append(f"no word survives ({len(line_words)} checked)")

        if reasons:
            suspicious.append(f"  L{number}: {line[:72]}\n         " + " | ".join(reasons))

    if not args.quiet:
        for entry in suspicious[:MAX_REPORTED]:
            print(entry)
        if len(suspicious) > MAX_REPORTED:
            print(f"  [i] {len(suspicious) - MAX_REPORTED} more not shown (the cap is {MAX_REPORTED})")
        if too_short:
            # A skipped line is not a passed line: say how many were never judged, or a clean report
            # reads as "everything was checked".
            print(f"  [i] {too_short} line(s) under 8 characters were not judged (too little signal)")

    total_lines = len(backup_text.splitlines())
    if suspicious:
        scope = f", pool: {len(pools)} file(s)" if pools else ""
        print(f"[!] {len(suspicious)} line(s) look lost{scope} — read them before trusting the edit")
        return 1
    print(f"[v] no content lost ({total_lines} lines compared)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
