---
name: memory-hygiene
description: Keep Claude Code auto-memory (~/.claude/projects/<project>/memory) small, current and trustworthy. Use when writing or updating a memory, when the SessionStart hook says "Memory upkeep due", when the user asks to clean up / audit / refactor memory ("dọn memory", "memory cũ", "audit memory", "cập nhật MEMORY.md"), when a memory contradicts the code, after closing a work item that has project memories, or when onboarding a project's memory to this scheme ("migrate memory").
---

# Memory hygiene

Full guideline: `${CLAUDE_PLUGIN_ROOT}/docs/memory-system.md` — read it before the first
memory write or cleanup of a session. Scripts take `[memory_dir]`; default is the memory dir
of the current working directory.

## Commands

| Need | Run |
|---|---|
| Onboard an existing memory dir | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-py.sh memory-migrate.py` then index |
| Rebuild `MEMORY.md` | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-py.sh memory-index.py` |
| Is the index current? | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-py.sh memory-index.py --check` |
| Find memories for a task | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-py.sh memory-search.py "<task context>"` |
| Full audit (report only) | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/memory-audit.sh [memory_dir] [repo_root] [max_age_days]` |

## Recalling

The UserPromptSubmit hook already suggests up to 3 matching memories per prompt; open one only
if it fits. Before a non-trivial task the hook may not cover, run memory-search with the task's context and read the top hits;
the index does not list everything. A hit is relevant, not proven correct: check `verified`.

## Writing a memory

1. Grep the memory dir; update an existing file instead of adding a duplicate. If the user is
   correcting something an existing memory already covers, increment `metadata.recurrences`
   (start at 2) and sharpen its `when` / wording: it failed to prevent the mistake.
2. If the fact belongs in a rule, skill or knowledge doc, put it there instead (guideline §1).
3. Frontmatter `metadata`: `type`, `source` (user only if the user said it), `verified` (today),
   `status: active`. Absolute dates. For `feedback`, add `when:` = the task context it
   applies to (e.g. "writing a migration"); search weights it highest.
4. Rebuild the index.

## Upkeep (when nudged or asked)

Run the audit, then per finding:

- **stale** / **cited code changed** → re-check against code / tracker / command output (structural claims: use the project code graph, e.g. graphify path / affected); bump `verified`, fix, or supersede.
- **broken path** → fix the path; if it names something removed, drop the backticks.
- **closed work item** → lesson left: promote it, then `status: superseded` + `superseded_by`; none: `status: done`.
- **over budget** → shorten long index lines (title + one hook, < 200 chars), then promote or supersede until under budget.
- **promote candidate** → propose moving the rule to project rules / AGENTS.md; after the user agrees, supersede the memory.
- **unused** (not opened for the window) → `feedback` never appears here; for others drop from the index by superseding, or keep if still needed soon.
- **related pair** → read both; merge into one file and supersede the other only if they state the same fact.
- **repeated correction** (`recurrences` >= 2) → propose promoting to project rules (always loaded); memory recall was not enough.
- **recall never opened** → sharpen `when` / description so it stops matching unrelated prompts.
- **feedback without `when`** → add the task context it applies to (no meaning change, allowed on `source: user`).
- **codified elsewhere** → `status: superseded`, `superseded_by: <path or skill>`.

Never delete files (non-active files are history) unless the user asks. Never change the
meaning of a `source: user` memory without asking. Finish with the index rebuild and report
counts before → after (entries, bytes) plus what stays unverified.
