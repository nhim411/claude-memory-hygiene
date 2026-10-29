---
description: Clean up this project's memory — verify, propose, apply after approval
argument-hint: "[focus, e.g. a work item id or a topic]"
---
Use the memory-hygiene skill (upkeep). Focus: $ARGUMENTS (empty = everything the audit reports).

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-audit.sh"`.
2. For each finding in scope, check it against the code / tracker / command output and decide:
   keep (bump `verified`), fix, merge, `superseded`, or `done`.
3. Show the user a table: file, finding, evidence, proposed action. Changes to `source: user`
   memories need explicit approval; agent-sourced fixes may be applied after the user agrees to the table.
4. Apply, run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/memory-index.py"`, and report index entries/bytes before → after
   plus what stays unverified.
