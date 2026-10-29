# memory-hygiene

[Tiếng Việt](README.md) | **English**

A Claude Code plugin that keeps auto-memory **small, current and trustworthy**, in every project.

Claude Code already writes memories on its own (`~/.claude/projects/<project>/memory/`).
Left alone, they pile up: stale facts, duplicates, paths that no longer exist, and an index
that is loaded into *every* session. This plugin keeps that in check with almost no effort from you.

## Quick start

```text
/plugin marketplace add nhim411/claude-memory-hygiene
/plugin install memory-hygiene@nhim411-memory-hygiene
```

Restart Claude Code, then in each project say once:

> migrate memory

That's it. From then on:

| You | The plugin |
|---|---|
| work normally | fixes the index and missing metadata at every session start, silently |
| see `Memory upkeep due: …` | nothing required; act on it when you have a minute |
| say **"clean up memory"** / **"dọn memory"** | audits, re-checks stale facts, proposes changes, rebuilds the index |
| say **"remember …"** | stores it with the right type, source and date |

## How it works

```
session start ─► fill missing metadata ─► rebuild MEMORY.md ─► audit ─► 1-line nudge (only if due)
                        (automatic, deterministic)                       (you / Claude decide)
```

Each memory file carries a little metadata:

```yaml
metadata:
  type: user | feedback | project | reference
  source: user | agent      # what you said is never rewritten by Claude on its own
  verified: 2026-10-29      # last check against the code / tracker
  status: active | superseded | done
```

Only `active` memories appear in `MEMORY.md`. Superseded and done files stay on disk as history.

The audit flags:

- **stale**: not verified for 45 days
- **code changed**: a file the memory cites got commits after `verified` (via git)
- **broken path**: a cited repo path no longer exists
- **over budget**: index > 8 KB, > 45 entries, or a line > 200 chars
- **promote candidates**: your rules that have been stable for a month and belong in project rules

## Design: why it is efficient

1. **Small index, loaded always.** Only what matters in *every* session goes in `MEMORY.md`;
   the rest is opened on demand.
2. **Memory is a staging area.** Stable rules move to `AGENTS.md` / project rules, techniques
   to skills, lessons to docs. Memory keeps only what has no better home yet.
3. **Supersede, don't overwrite.** Old facts keep their history; what you said beats what
   Claude inferred.
4. **Automate the deterministic, nudge for judgment.** Scripts never change a fact's meaning.
5. **Validity from git, not from a graph.** Tens of files do not need a knowledge graph;
   "cited code changed since verified" is the exact staleness signal.

Full guideline: [`docs/memory-system.md`](docs/memory-system.md).

## Settings (optional env vars)

| Variable | Default |
|---|---|
| `MEMORY_INDEX_MAX_BYTES` | 8000 |
| `MEMORY_INDEX_MAX_ENTRIES` | 45 |
| `MEMORY_INDEX_MAX_LINE` | 200 |
| `MEMORY_HYGIENE_DIR` | memory dir derived from the current directory |

## Manual commands

```bash
python3 scripts/memory-migrate.py [memory_dir]                 # add metadata (idempotent)
python3 scripts/memory-index.py   [memory_dir] [--check]       # rebuild / check MEMORY.md
bash    scripts/memory-audit.sh   [memory_dir] [repo] [days]   # full report, changes nothing
```

Requires bash, python3, git, GNU `date`. Tested on Linux / WSL.

## License

MIT
