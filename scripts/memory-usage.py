#!/usr/bin/env python3
"""PostToolUse(Read) hook: log which memory files Claude actually opens.

Appends "YYYY-MM-DD<TAB>file.md" to <memory_dir>/.usage.log. Never fails the tool call.
"""
import datetime
import json
import os
import sys

try:
    data = json.load(sys.stdin)
    path = (data.get("tool_input") or {}).get("file_path") or ""
    parts = path.replace("\\", "/").split("/")
    if (path.endswith(".md") and "memory" in parts and ".claude" in parts
            and "projects" in parts and os.path.basename(path) != "MEMORY.md"):
        log = os.path.join(os.path.dirname(path), ".usage.log")
        today = datetime.date.today().isoformat()
        new = not os.path.exists(log)
        with open(log, "a", encoding="utf-8") as fh:
            if new:
                fh.write(f"# since\t{today}\n")
            fh.write(f"{today}\t{os.path.basename(path)}\n")
except Exception:  # a logging hook must never block Claude
    pass
