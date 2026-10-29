#!/usr/bin/env python3
"""Add source/verified/status metadata to memory files that lack it (idempotent).

verified = file mtime, source = user for feedback/user types, agent otherwise.
Files without frontmatter get one (type project). Line endings are preserved.
Usage: memory-migrate.py [memory_dir]
"""
import datetime
import os
import re
import sys

MEM = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.claude/projects/" + re.sub(r"[^A-Za-z0-9]", "-", os.getcwd()) + "/memory")


def migrate(path):
    raw = open(path, encoding="utf-8", newline="").read()
    eol = "\r\n" if "\r\n" in raw else "\n"
    text = raw.replace("\r\n", "\n")
    stat = os.stat(path)
    day = datetime.date.fromtimestamp(stat.st_mtime).isoformat()
    head = re.match(r"---\n(.*?)\n---\n?", text, re.S)

    if not head:
        name = os.path.basename(path)[:-3]
        first = next((l.strip("# ").strip() for l in text.splitlines() if l.strip()), name)
        desc = first[:120].replace('"', "'")
        fm = (f'---\nname: {name}\ndescription: "{desc}"\nmetadata:\n  type: project\n'
              f"  source: agent\n  verified: {day}\n  status: active\n---\n\n")
        new = fm + text
    else:
        block = head.group(1)
        if re.search(r"^\s*status:", block, re.M):
            return False
        m = re.search(r"^(\s*)type:\s*(\S+)\s*$", block, re.M)
        if m:
            indent, typ, at = m.group(1), m.group(2), head.start(1) + m.end()
        else:  # no type: add a metadata block at the end of the frontmatter
            indent, typ, at = "  ", "project", head.end(1)
            added = "\nmetadata:\n  type: project"
            text = text[:at] + added + text[at:]
            at += len(added)
        source = "user" if typ in ("feedback", "user") else "agent"
        extra = f"\n{indent}source: {source}\n{indent}verified: {day}\n{indent}status: active"
        new = text[:at] + extra + text[at:]

    open(path, "w", encoding="utf-8", newline="").write(new.replace("\n", eol))
    os.utime(path, (stat.st_atime, stat.st_mtime))
    return True


changed = 0
for f in sorted(os.listdir(MEM)):
    if f.endswith(".md") and f != "MEMORY.md" and migrate(os.path.join(MEM, f)):
        changed += 1
print(f"migrated {changed} file(s) in {MEM}")
