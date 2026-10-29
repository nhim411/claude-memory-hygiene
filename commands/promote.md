---
description: Turn stable memory rules into project rules (drafts for approval)
---
Use the memory-hygiene skill.

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-audit.sh"` and take the "Promote candidates" section
   (plus any memory the user names).
2. For each, find the right home in this repo (AGENTS.md / CLAUDE.md, `.claude/rules/`, a skill, or the
   project's knowledge docs) — prefer one that is committed and shared. Check it is not already there.
3. Draft the rule text (short, imperative, with the why) and show draft + target path. Do not write yet.
4. After approval: write it, mark the memory `status: superseded` with `superseded_by: <path>`,
   rebuild the index. Note whether the target is committed (team-wide) or local-only.
