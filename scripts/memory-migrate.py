#!/usr/bin/env python3
"""Add source/verified/status metadata to memory files that lack it (idempotent).

verified = file mtime, source = user for feedback/user types, agent otherwise.
Usage: memory-migrate.py [memory_dir]
"""
import datetime
import os
import re
import sys

MEM = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.claude/projects/" + re.sub(r"[/.]", "-", os.getcwd()) + "/memory")
changed = 0
for f in sorted(os.listdir(MEM)):
    path = os.path.join(MEM, f)
    if not f.endswith(".md") or f == "MEMORY.md":
        continue
    text = open(path, encoding="utf-8", newline="").read()
    head = re.match(r"---\n(.*?)\n---", text, re.S)
    if not head or re.search(r"^\s*status:", head.group(1), re.M):
        continue
    m = re.search(r"^(\s*)type:\s*(\S+)\s*$", text, re.M)
    if not m:
        print(f"skip (no type): {f}")
        continue
    indent, typ = m.group(1), m.group(2)
    stat = os.stat(path)
    day = datetime.date.fromtimestamp(stat.st_mtime).isoformat()
    source = "user" if typ in ("feedback", "user") else "agent"
    extra = f"\n{indent}source: {source}\n{indent}verified: {day}\n{indent}status: active"
    open(path, "w", encoding="utf-8", newline="").write(text[:m.end()] + extra + text[m.end():])
    os.utime(path, (stat.st_atime, stat.st_mtime))
    changed += 1
print(f"migrated {changed} file(s) in {MEM}")
