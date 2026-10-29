#!/usr/bin/env python3
"""Rebuild MEMORY.md from memory frontmatter: active files only, grouped by type.

Keeps the existing curated hook line of each indexed file; new active files get
their `description`. Usage: memory-index.py [memory_dir] [--check]
--check exits 1 (and writes nothing) when the index is out of date.
"""
import os
import re
import sys

args = [a for a in sys.argv[1:] if not a.startswith("--")]
CHECK = "--check" in sys.argv
MEM = args[0] if args else os.path.expanduser(
    "~/.claude/projects/" + re.sub(r"[/.]", "-", os.getcwd()) + "/memory")
IDX = os.path.join(MEM, "MEMORY.md")

HEADER = [
    "# Memory Index",
    "",
    "Guide: memory-hygiene skill. Only status: active files are listed; "
    "source: user = do not edit on my own. Regenerate: /memory-hygiene index",
    "",
]
GROUPS = [
    ("user", "## About the user"),
    ("feedback", "## Rules from the user (always apply)"),
    ("reference", "## References"),
    ("project", "## Project context (re-verify before relying on it)"),
]


def frontmatter(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    if not m:
        return None
    fm = {}
    for line in (m.group(1) if m else "").splitlines():
        kv = re.match(r"\s*([a-z_]+):\s*(.*)", line)
        if kv and kv.group(1) not in fm:
            fm[kv.group(1)] = kv.group(2).strip().strip('"')
    return fm


old = open(IDX, encoding="utf-8").read() if os.path.exists(IDX) else ""
curated = {}
for line in old.splitlines():
    m = re.match(r"- \[.*?\]\(([^)]+)\)", line)
    if m:
        curated[m.group(1)] = line

buckets = {k: [] for k, _ in GROUPS}
for f in sorted(os.listdir(MEM)):
    if not f.endswith(".md") or f == "MEMORY.md":
        continue
    fm = frontmatter(os.path.join(MEM, f))
    if fm is None:  # not a memory file (no frontmatter); migrate adds one
        continue
    if fm.get("status", "active") != "active":
        continue
    line = curated.get(f) or f"- [{fm.get('name', f[:-3])}]({f}) — {fm.get('description', '')[:150]}"
    buckets.get(fm.get("type"), buckets["project"]).append(line)

out = list(HEADER)
for key, title in GROUPS:
    if buckets[key]:
        out += [title] + buckets[key] + [""]
new = "\n".join(out)

if new.strip() == old.strip():
    print("MEMORY.md up to date")
    sys.exit(0)
if CHECK:
    print("MEMORY.md out of date — run memory-index.py")
    sys.exit(1)
open(IDX, "w", encoding="utf-8").write(new)
print(f"MEMORY.md rebuilt: {sum(map(len, buckets.values()))} entries, {len(new.encode())} bytes")
