#!/usr/bin/env python3
"""BM25 search over memory files, so memories outside MEMORY.md can still be found.

Usage: memory-search.py [--dir memory_dir] [-k N] [--all] <query words...>
Ranks active memories (all statuses with --all); see memory_bm25.py for weighting.
Relevance is not correctness: check `verified` / `source` before relying on a hit.
"""
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import memory_bm25 as bm  # noqa: E402

args = sys.argv[1:]
mem, k, include_all, words = None, 5, False, []
i = 0
while i < len(args):
    a = args[i]
    if a == "--dir" and i + 1 < len(args):
        mem = args[i + 1]; i += 1
    elif a == "-k" and i + 1 < len(args):
        k = int(args[i + 1]); i += 1
    elif a == "--all":
        include_all = True
    else:
        words.append(a)
    i += 1
if not words:
    print(__doc__.strip().splitlines()[2]); sys.exit(2)

docs = bm.load(mem or bm.default_dir(), include_all)
if not docs:
    print("no memories"); sys.exit(0)
hits = bm.rank(docs, " ".join(words))
if not hits:
    print("no match"); sys.exit(0)
for s, f, fm in hits[:k]:
    meta = " ".join(f"{key}={fm[key]}" for key in ("type", "source", "verified", "status") if fm.get(key))
    print(f"{s:5.2f}  {f}  [{meta}]")
    print(f"       {fm.get('description', '')[:150]}")
    if fm.get("when"):
        print(f"       when: {fm['when'][:150]}")
