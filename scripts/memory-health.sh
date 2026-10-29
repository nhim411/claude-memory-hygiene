#!/usr/bin/env bash
# SessionStart: auto-fix what is deterministic (index), nudge for what needs judgment.
# Silent when nothing is due.
proj=$(pwd | sed 's#[/.]#-#g')
MEM="$HOME/.claude/projects/$proj/memory"
[ -f "$MEM/MEMORY.md" ] || exit 0
here="$(cd "$(dirname "$0")" && pwd)"

if ! python3 "$here/memory-index.py" "$MEM" --check >/dev/null 2>&1; then
  python3 "$here/memory-index.py" "$MEM" >/dev/null 2>&1 && echo "memory-hygiene: MEMORY.md rebuilt from frontmatter."
fi

out=$(bash "$here/memory-audit.sh" "$MEM" "$(pwd)" 45 2>/dev/null)
count() { printf '%s\n' "$out" | sed -n "/^== $1/,/^==/p" | grep -c '^  '; }
stale=$(count Active); missing=$(count Missing); broken=$(count Repo); changed=$(count Cited); drift=$(count Index)
total=$((stale + missing + broken + changed + drift))
[ "$total" -eq 0 ] && exit 0
echo "Memory upkeep due: stale=$stale missing-fields=$missing broken-paths=$broken code-changed=$changed index-drift=$drift. Run the memory-hygiene skill (upkeep) when the current task allows; do not interrupt urgent work."
