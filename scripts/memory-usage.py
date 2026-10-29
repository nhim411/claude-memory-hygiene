#!/usr/bin/env python3
"""PostToolUse(Read|Bash|Grep) hook: log which memory files Claude actually opens.

Appends "YYYY-MM-DD<TAB>file.md" to <memory_dir>/.usage.log. Never fails the tool call.
"""
import datetime
import json
import os
import re
import sys

# Quoted paths may contain spaces ("C:/Users/First Last/…"); unquoted ones end at whitespace.
QUOTED_MEMORY_FILE = re.compile(r"[\"']((?:~|/|[A-Za-z]:/)[^\"']*?/\.claude/projects/[^/\"']+/memory)/([^/\"']+\.md)[\"']")
MEMORY_FILE = re.compile(r"((?:~|/|[A-Za-z]:/)[^\s'\"`]*?/\.claude/projects/[^/\s]+/memory)/([^/\s'\"`*]+\.md)")


def native(path):
    """Map Git Bash paths (/c/Users/…) to C:/Users/… for a Windows Python."""
    path = os.path.expanduser(path)
    m = re.match(r"^/([A-Za-z])/(.*)", path)
    if os.name == "nt" and m and not os.path.isdir(path):
        return f"{m.group(1).upper()}:/{m.group(2)}"
    return path


def log_read(mem_dir, name):
    mem_dir = native(mem_dir)
    if name == "MEMORY.md" or not os.path.isdir(mem_dir):
        return
    log = os.path.join(mem_dir, ".usage.log")
    today = datetime.date.today().isoformat()
    new = not os.path.exists(log)
    with open(log, "a", encoding="utf-8") as fh:
        if new:
            fh.write(f"# since\t{today}\n")
        fh.write(f"{today}\t{name}\n")


try:
    data = json.load(sys.stdin)
    tin = data.get("tool_input") or {}
    hits = set()
    # Read passes one exact path (may contain spaces, e.g. C:\Users\First Last\…).
    fp = str(tin.get("file_path", "")).replace("\\", "/")
    m = re.search(r"(/\.claude/projects/[^/]+/memory)/([^/]+\.md)$", fp)
    if m:
        hits.add((fp[:m.start(2) - 1], m.group(2)))
    # Bash (cat/grep/sed …) and Grep carry paths inside command / path text.
    text = " ".join(str(tin.get(k, "")) for k in ("command", "path")).replace("\\", "/")
    hits.update(QUOTED_MEMORY_FILE.findall(text))
    hits.update(MEMORY_FILE.findall(text))
    for mem_dir, name in hits:
        log_read(mem_dir, name)
except Exception:  # a logging hook must never block Claude
    pass
