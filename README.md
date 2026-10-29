# memory-hygiene — Claude Code plugin

Keeps Claude Code auto-memory (`~/.claude/projects/<project>/memory/`) small, current and
trustworthy across many projects. Ideas adapted from
[Dewee Memory](https://zuey.me/articles/dewee-memory-khi-ai-khong-chi-biet-nho?lang=vi):
facts carry provenance, validity and status; old facts are superseded, not overwritten;
relevant context beats more context; memory is consolidated on a schedule.

## What you get

| Part | Does |
|---|---|
| `memory-hygiene` skill | how to write, audit and clean memory; the agent loads it when needed |
| `SessionStart` hook | fills missing metadata on new memories and rebuilds `MEMORY.md` when it drifts (deterministic); one-line nudge when facts need judgment; silent otherwise |
| `scripts/memory-migrate.py` | add `source / verified / status` to existing memory files (idempotent) |
| `scripts/memory-index.py` | regenerate `MEMORY.md`: active files only, grouped by type, curated lines kept |
| `scripts/memory-audit.sh` | report stale facts, missing fields, broken repo paths, memories whose cited code changed since `verified` (git), index drift, cited work items |
| `docs/memory-system.md` | the guideline: where knowledge lives, file format, conflicts, upkeep |

Memory metadata:

```yaml
metadata:
  type: user | feedback | project | reference
  source: user | agent        # user-stated facts are never changed by the agent on its own
  verified: 2026-10-29        # last check against code / tracker
  status: active | superseded | done
  superseded_by: <slug or path>
```

## Install

```text
/plugin marketplace add nhim411/claude-memory-hygiene
/plugin install memory-hygiene@nhim411-memory-hygiene
```

Then, in each project: ask Claude to "migrate memory" (or run `memory-migrate.py` and
`memory-index.py` from the project root).

## Requirements

bash, python3, GNU coreutils (`date -d`). Tested on Linux / WSL.

## License

MIT
