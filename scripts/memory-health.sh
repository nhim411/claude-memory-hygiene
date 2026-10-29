#!/usr/bin/env bash
# SessionStart nudge: one line when the project's memory needs upkeep, silent otherwise.
proj=$(pwd | sed 's#[/.]#-#g')
MEM="$HOME/.claude/projects/$proj/memory"
[ -f "$MEM/MEMORY.md" ] || exit 0
out=$("$(dirname "$0")/memory-audit.sh" "$MEM" "$(pwd)" 45 2>/dev/null)
count() { printf '%s\n' "$out" | sed -n "/^== $1/,/^==/p" | grep -c '^  '; }
stale=$(count Active); missing=$(count Missing); broken=$(count Repo); drift=$(count Index)
idx=$("$(dirname "$0")/memory-index.py" "$MEM" --check >/dev/null 2>&1 || echo 1)
total=$((stale + missing + broken + drift))
[ "$total" -eq 0 ] && [ -z "$idx" ] && exit 0
echo "Memory upkeep due: stale=$stale missing-fields=$missing broken-paths=$broken index-drift=$drift${idx:+ index-out-of-date}. Run the memory-hygiene skill (upkeep) when the current task allows; do not interrupt urgent work."
