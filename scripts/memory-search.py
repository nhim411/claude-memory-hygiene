#!/usr/bin/env python3
"""BM25 search over memory files, so memories outside MEMORY.md can still be found.

Usage: memory-search.py [--dir memory_dir] [-k N] [--all] <query words...>
Ranks active memories (all statuses with --all) by text relevance. Fields are weighted:
`when` (the task context the memory applies to) x3, name/description x2, body x1.
Matching ignores case and diacritics (Vietnamese "mở đầu" == "mo dau").
Relevance is not correctness: check `verified` / `source` before relying on a hit.
"""
import math
import os
import re
import sys
import unicodedata

args = sys.argv[1:]
MEM, K, ALL, words = None, 5, False, []
i = 0
while i < len(args):
    a = args[i]
    if a == "--dir":
        MEM = args[i + 1]; i += 1
    elif a == "-k":
        K = int(args[i + 1]); i += 1
    elif a == "--all":
        ALL = True
    else:
        words.append(a)
    i += 1
if not words:
    print(__doc__.strip().splitlines()[2]); sys.exit(2)
MEM = MEM or os.path.expanduser(
    "~/.claude/projects/" + re.sub(r"[^A-Za-z0-9]", "-", os.getcwd()) + "/memory")
STOP = set("a an the and or of to in on for with is are be by as at from it this that "
           "la va cua cho cac nhung mot khi thi de co khong duoc".split())
WEIGHTS = {"when": 3, "name": 2, "description": 2, "_body": 1}


def fold(s):
    s = unicodedata.normalize("NFD", s.lower().replace("đ", "d"))
    return "".join(c for c in s if not unicodedata.combining(c))


def stem(t):
    # Light English plural folding so "migrations" matches "migration".
    if len(t) > 4 and t.endswith("ies"):
        return t[:-3] + "y"
    if len(t) > 3 and t.endswith("s") and not t.endswith("ss"):
        return t[:-1]
    return t


def tokens(s):
    return [stem(t) for t in re.findall(r"[a-z0-9]+", fold(s)) if t not in STOP and len(t) > 1]


def parse(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    fm = {"_body": text[m.end():] if m else text}
    for line in (m.group(1) if m else "").splitlines():
        kv = re.match(r"\s*([a-z_]+):\s*(.*)", line)
        if kv and kv.group(1) not in fm:
            fm[kv.group(1)] = kv.group(2).strip().strip('"')
    return fm


docs = []
for f in sorted(os.listdir(MEM)) if os.path.isdir(MEM) else []:
    if not f.endswith(".md") or f == "MEMORY.md":
        continue
    try:
        fm = parse(os.path.join(MEM, f))
    except (OSError, UnicodeDecodeError):
        continue
    fm["name"] = fm.get("name", "") + " " + f[:-3]  # slug words count too
    if not ALL and fm.get("status", "active") != "active":
        continue
    toks = []
    for field, w in WEIGHTS.items():
        toks += tokens(fm.get(field, "")) * w
    docs.append((f, fm, toks))

if not docs:
    print("no memories"); sys.exit(0)
q = set(tokens(" ".join(words)))
N = len(docs)
avgdl = sum(len(t) for _, _, t in docs) / N or 1
df = {t: sum(1 for _, _, d in docs if t in d) for t in q}
k1, b = 1.2, 0.75
scored = []
for f, fm, d in docs:
    s = 0.0
    for t in q:
        tf = d.count(t)
        if tf:
            idf = math.log(1 + (N - df[t] + 0.5) / (df[t] + 0.5))
            s += idf * tf * (k1 + 1) / (tf + k1 * (1 - b + b * len(d) / avgdl))
    if s > 0:
        scored.append((s, f, fm))
scored.sort(key=lambda x: (-x[0], x[1]))
if not scored:
    print("no match"); sys.exit(0)
for s, f, fm in scored[:K]:
    meta = " ".join(f"{k}={fm[k]}" for k in ("type", "source", "verified", "status") if fm.get(k))
    print(f"{s:5.2f}  {f}  [{meta}]")
    print(f"       {fm.get('description', '')[:150]}")
    if fm.get("when"):
        print(f"       when: {fm['when'][:150]}")
