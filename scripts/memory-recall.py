#!/usr/bin/env python3
"""UserPromptSubmit hook: suggest memories relevant to the prompt (BM25), at most a few lines.

Silent unless a hit clears MEMORY_RECALL_MIN_SCORE (default 5). Each file is suggested once
per session. Suggestions are logged to <memory_dir>/.recall.log ("date<TAB>session<TAB>file")
so the audit can report how often a suggestion was then opened. MEMORY_RECALL=0 disables.
Never fails the prompt.
"""
import datetime
import json
import os
import sys

try:
    if os.environ.get("MEMORY_RECALL", "1") == "0":
        sys.exit(0)
    sys.dont_write_bytecode = True
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # cp1252 on Windows
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import memory_bm25 as bm

    data = json.load(sys.stdin)
    prompt = str(data.get("prompt", ""))
    session = str(data.get("session_id", "-"))
    mem = os.environ.get("MEMORY_HYGIENE_DIR") or bm.default_dir(data.get("cwd") or None)
    if prompt.lstrip().startswith("/") or len(set(bm.tokens(prompt))) < 3:
        sys.exit(0)
    min_score = float(os.environ.get("MEMORY_RECALL_MIN_SCORE", "5"))
    max_hits = int(os.environ.get("MEMORY_RECALL_MAX", "3"))

    log = os.path.join(mem, ".recall.log")
    seen = set()
    if os.path.exists(log):
        for line in open(log, encoding="utf-8", errors="replace"):
            parts = line.rstrip("\n").split("\t")
            if len(parts) == 3 and parts[1] == session:
                seen.add(parts[2])
    # Take the top hits first, then drop already-suggested ones, so a repeated prompt stays
    # silent instead of surfacing weaker matches.
    top = [h for h in bm.rank(bm.load(mem), prompt[:2000]) if h[0] >= min_score][:max_hits]
    hits = [h for h in top if h[1] not in seen]
    if not hits:
        sys.exit(0)
    print("memory-hygiene: possibly relevant memories (open only if useful; check `verified`):")
    for s, f, fm in hits:
        print(f"- {os.path.join(mem, f)} — {fm.get('description', '')[:120]} "
              f"[{fm.get('type', '?')}, verified {fm.get('verified', '?')}]")
    today = datetime.date.today().isoformat()
    with open(log, "a", encoding="utf-8", errors="replace") as fh:
        for _, f, _ in hits:
            fh.write(f"{today}\t{session}\t{f}\n")
except SystemExit:
    raise
except Exception:  # a prompt hook must never block the user
    pass
