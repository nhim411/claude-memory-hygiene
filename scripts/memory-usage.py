#!/usr/bin/env python3
"""PostToolUse(Read|Bash|Grep) hook: log which memory files Claude actually opens.

Appends "YYYY-MM-DD<TAB>file.md" to <memory_dir>/.usage.log. Never fails the tool call.
"""
import datetime
import json
import os
import re
import sys

MEMORY_FILE = re.compile(r"((?:~|/)[^\s'\"`]*?/\.claude/projects/[^/\s]+/memory)/([^/\s'\"`*]+\.md)")


def log_read(mem_dir, name):
    mem_dir = os.path.expanduser(mem_dir)
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
    # Read passes file_path; Bash (cat/grep/sed …) and Grep carry paths in command / path.
    text = " ".join(str(tin.get(k, "")) for k in ("file_path", "command", "path")).replace("\\", "/")
    for mem_dir, name in set(MEMORY_FILE.findall(text)):
        log_read(mem_dir, name)
except Exception:  # a logging hook must never block Claude
    pass
