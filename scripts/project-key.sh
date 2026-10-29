#!/usr/bin/env bash
# Print Claude Code's memory dir for a project path (default: cwd).
# Claude names it after the absolute path with every non-alphanumeric char turned into "-";
# on Windows Git Bash `pwd -W` gives the C:/… form Claude itself sees.
p="${1:-$(pwd -W 2>/dev/null || pwd)}"
printf '%s/.claude/projects/%s/memory\n' "$HOME" "$(printf %s "$p" | sed 's/[^A-Za-z0-9]/-/g')"
