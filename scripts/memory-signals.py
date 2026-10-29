#!/usr/bin/env python3
"""Audit signals that need the whole memory set: possible duplicates and unused memories.

Usage: memory-signals.py <memory_dir> [unused_days]
Prints two "== " sections in the same format as memory-audit.sh.
"""
import datetime
import itertools
import os
import re
import sys

MEM = sys.argv[1]
UNUSED_DAYS = int(sys.argv[2]) if len(sys.argv) > 2 else 60
DUP_THRESHOLD = float(os.environ.get("MEMORY_DUP_THRESHOLD", "0.4"))
STOP = set("a an the and or of to in on for with is are be by as at from not no it this that "
           "when use used via into than then must should only all any new old".split())


def frontmatter(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    fm = {"_body": text[m.end():m.end() + 600] if m else text[:600]}
    for line in (m.group(1) if m else "").splitlines():
        kv = re.match(r"\s*([a-z_]+):\s*(.*)", line)
        if kv and kv.group(1) not in fm:
            fm[kv.group(1)] = kv.group(2).strip().strip('"')
    return fm


def words(fm):
    text = f"{fm.get('name', '')} {fm.get('description', '')} {fm['_body']}".lower()
    return {w for w in re.split(r"[^a-z0-9぀-ヿ一-鿿]+", text)
            if len(w) > 3 and w not in STOP}


active = {}
for f in sorted(os.listdir(MEM)):
    if f.endswith(".md") and f != "MEMORY.md":
        fm = frontmatter(os.path.join(MEM, f))
        if fm.get("status", "active") == "active":
            active[f] = fm

# Informational: lexical overlap is a hint, not proof (related != duplicate).
print("== Related pairs: possible duplicates (read both; merge only if they say the same thing)")
for (a, fa), (b, fb) in itertools.combinations(active.items(), 2):
    wa, wb = words(fa), words(fb)
    if wa and wb:
        score = len(wa & wb) / min(len(wa), len(wb))
        if score >= DUP_THRESHOLD:
            print(f"  {score:.2f}  {a} ~ {b}")

# Informational: needs a usage log older than the window, else every file looks unused.
print(f"== Unused: active, not opened in {UNUSED_DAYS}d (drop from index or supersede)")
log = os.path.join(MEM, ".usage.log")
if os.path.exists(log):
    lines = [l.rstrip("\n").split("\t") for l in open(log, encoding="utf-8") if "\t" in l]
    since = next((l[1] for l in lines if l[0] == "# since"), None)
    cutoff = (datetime.date.today() - datetime.timedelta(days=UNUSED_DAYS)).isoformat()
    if since and since <= cutoff:
        recent = {l[1] for l in lines if l[0] != "# since" and l[0] >= cutoff}
        for f, fm in active.items():
            if f not in recent and fm.get("type") != "feedback":
                print(f"  {f}")
