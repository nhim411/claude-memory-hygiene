# Memory system — guideline

How Claude Code memory is kept useful across sessions, for any project.
Principles adapted from Dewee Memory (zuey.me, 2026): every fact has provenance, validity
and status; old facts are superseded, not silently overwritten; less but relevant context
beats more context; memory is consolidated on a schedule, not only appended.

## 1. Where knowledge lives (pick the most durable home)

| Kind of knowledge | Home | Loaded |
|---|---|---|
| Rule that always applies to the repo | `AGENTS.md` / `.claude/rules/` | every session |
| Technique for a kind of task | a skill (project or user skills) | when the skill triggers |
| Project lesson / failure pattern / domain constraint | the project's knowledge docs (e.g. `docs/knowledge/`) | by intake/review skills |
| Decision with tradeoffs | `docs/decisions/` (ADR) | on demand |
| User preference, correction not yet codified, live project context, external pointer | **memory** (`~/.claude/projects/<proj>/memory/`) | index every session |
| What happened (history) | git, PRs, ADO | on demand |

Memory is a **staging area**. Once a fact is codified in a rule, skill or knowledge doc,
mark the memory `superseded` with `superseded_by` pointing at that home.

## 2. File format

```markdown
---
name: <kebab-slug>
description: <one line, used for relevance>
metadata:
  type: user | feedback | project | reference
  source: user | agent        # user = stated by the user; the agent never edits/removes it on its own
  verified: YYYY-MM-DD        # last time checked against code / ADO / the system
  status: active | superseded | done
  superseded_by: <slug or path>   # only when superseded
---
<the fact; feedback/project add **Why:** and **How to apply:**; link [[other-slug]]>
```

- `superseded`: replaced by a newer memory or codified elsewhere. `done`: project context
  whose work item / PR is closed and left no reusable lesson.
- Non-active files stay on disk as history (soft delete) and drop off the index.
  Delete a file only when the user asks, or when it is wrong and has no history value.
- Conflicts: a `source: user` fact wins over an agent inference, even if the inference is newer.
  When code contradicts a memory, trust code, fix or supersede the memory in the same turn.

## 3. Index (`MEMORY.md`)

Generated, grouped by type, active files only:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/memory-index.py            # rebuild (keeps existing curated hook lines)
${CLAUDE_PLUGIN_ROOT}/scripts/memory-index.py --check    # exit 1 when out of date
```

Budget: index ≤ 8 KB, ≤ 45 entries, each line ≤ 200 chars (env `MEMORY_INDEX_MAX_*`). Each line = title + one hook;
detail lives in the file. Over budget → shorten lines, then promote or supersede.

## 4. Writing a memory (every session)

1. Search existing files first (`grep -ril <keyword> memory/`); update instead of duplicating.
2. Prefer the more durable home from §1; memory only if none fits yet.
3. Fill all metadata; `verified` = today; `source: user` only for what the user actually said.
4. Absolute dates, no "yesterday / next sprint".
5. Run `memory-index.py`.

## 5. Upkeep (regular update mechanism)

- **Automatic fixes + nudge:** a `SessionStart` hook fills missing metadata and rebuilds the index, then runs `${CLAUDE_PLUGIN_ROOT}/scripts/memory-health.sh`.
  It prints one line only when something is due (stale > 45 days, missing fields, broken
  repo paths, index drift). Silent otherwise.
- **When nudged** (and the current task is not urgent), run:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/memory-audit.sh [memory_dir] [repo_root] [max_age_days]
  ```
  and for each finding:
  | Finding | Action |
  |---|---|
  | stale | re-check the claim (grep code, ADO state, run the command); bump `verified`, or fix, or supersede |
  | broken path | update the path, or rewrite the mention without backticks if it describes something removed |
  | work item now Done | lesson left → promote to knowledge docs, then `superseded`; none → `done` |
  | codified elsewhere | `superseded` + `superseded_by` |
  Then `memory-index.py`. Never change a `source: user` memory's meaning without asking.
- **After finishing a work item / PR:** mark its project memory `done` or promote it.
- **Monthly:** read the index top to bottom; anything you would not want in every session goes.

## 6. Applying to another project

Scripts are project-agnostic: pass that project's memory dir and repo root. The hook derives
both from the session cwd, so it already works for every project with a `MEMORY.md`.
Migrating an old memory dir: add `source/verified/status` to each file (verified = file mtime),
then run the audit and the index generator.

## 7. Memory and knowledge graphs (graphify etc.)

Memory is **not** stored in or indexed into a knowledge graph. Reasons:

- Scale: a memory dir is tens of files; grep and the generated index find anything instantly.
  A graph earns its cost on thousands of code/doc nodes, not here.
- Trust: graph edges from memory text to code would be name-matched (`INFERRED`), the weakest
  edge type; memory would then inherit graph staleness on top of its own.
- One source of truth: the graph already covers code + design docs. Memory holds what neither has
  (user preferences, live context), so duplicating it into the graph adds no answers.

What *was* worth taking from the graph idea is **validity tracking against code**, done with git:
`memory-audit.sh` lists active memories whose cited repo paths received commits after their
`verified` date ("Cited code changed since verified"). That is the cheap, exact signal that a
fact may be stale.

Use the graph *from* upkeep only when a memory makes a structural claim (call chain, "X is the
only caller of Y"): re-check it with the graph's path / impact query, then bump `verified`.
Knowledge that grows into a reusable lesson should be promoted to the project's docs, which the
graph does index.
