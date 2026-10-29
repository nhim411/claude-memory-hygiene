# 🧠 memory-hygiene

[Tiếng Việt](README.md) | **English**

[![test](https://github.com/nhim411/claude-memory-hygiene/actions/workflows/test.yml/badge.svg)](https://github.com/nhim411/claude-memory-hygiene/actions/workflows/test.yml)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

A Claude Code plugin that keeps auto-memory **small, current and trustworthy**: it cleans itself and catches stale notes.

## Install

Run these 2 commands in Claude Code, then restart:

```text
/plugin marketplace add nhim411/claude-memory-hygiene
/plugin install memory-hygiene@nhim411-memory-hygiene
```

Done. No configuration. Works on Linux, macOS and Windows.

## Use

Work as usual. At each session start the plugin repairs the index and prints one line only when something is due.

| Command | What it does |
|---|---|
| `/memory-hygiene:clean` | clean up: Claude verifies, proposes with evidence, you approve |
| `/memory-hygiene:audit` | report only, changes nothing |
| `/memory-hygiene:promote` | turn rules you keep repeating into project rules |

## Why

Claude Code's auto-memory only grows. Over time every session loads stale, duplicated notes,
and Claude may act on a "fact" that is no longer true.

Results on a real project:

| | Before | After |
|---|---|---|
| Index loaded into every session | 60 entries, 11.8 KB | **40 entries, 7.0 KB** |
| Memories with source + verified date | 0% | **100%** |
| Wrong notes caught | — | a renamed route, a merged PR still noted as "pending" |

## Features

- 🔍 **Catches stale notes**: flags a memory when the code it cites gets new commits.
- 🧹 **Auto-fixes the certain, asks about the rest.**
- 🛡️ **Never rewrites what you told it.**
- 📉 **Keeps the index small**: size budget, reports memories nobody reads.
- ⚡ **Lightweight**: bash + Python 3 + git, no database, no network.

📖 More: [How it works](docs/how-it-works.md) · [Memory guideline](docs/memory-system.md)

## License

MIT
