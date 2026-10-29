#!/usr/bin/env bash
# SessionStart: auto-fix what is deterministic (missing metadata, index), nudge for what needs judgment.
# Silent when nothing is due. The audit result is cached until memory, git HEAD or the day changes.
proj=$(pwd | sed 's#[/.]#-#g')
MEM="${MEMORY_HYGIENE_DIR:-$HOME/.claude/projects/$proj/memory}"
[ -f "$MEM/MEMORY.md" ] || exit 0
here="$(cd "$(dirname "$0")" && pwd)"

mig=$(python3 "$here/memory-migrate.py" "$MEM" 2>/dev/null)
case "$mig" in "migrated 0 "*|"") ;; *) echo "memory-hygiene: $mig";; esac

if ! python3 "$here/memory-index.py" "$MEM" --check >/dev/null 2>&1; then
  python3 "$here/memory-index.py" "$MEM" >/dev/null 2>&1 && echo "memory-hygiene: MEMORY.md rebuilt from frontmatter."
fi

cache="$MEM/.hygiene-cache"
key=$( { date +%F; git rev-parse HEAD 2>/dev/null; ls "$MEM"; cat "$MEM"/*.md; cat "$here/../.claude-plugin/plugin.json"; } 2>/dev/null | cksum)
if [ -z "${MEMORY_HYGIENE_NO_CACHE:-}" ] && [ -f "$cache" ] && [ "$(head -1 "$cache")" = "$key" ]; then
  tail -n +2 "$cache"
  exit 0
fi

out=$(bash "$here/memory-audit.sh" "$MEM" "$(pwd)" 45 2>/dev/null)
count() { printf '%s\n' "$out" | sed -n "/^== $1/,/^==/p" | grep -c '^  '; }
stale=$(count Active); missing=$(count Missing); broken=$(count Repo); changed=$(count Cited)
drift=$(count "Index drift"); budget=$(count "Index over")
total=$((stale + missing + broken + changed + drift + budget))
msg=""
[ "$total" -gt 0 ] && msg="Memory upkeep due: stale=$stale missing-fields=$missing broken-paths=$broken code-changed=$changed index-drift=$drift over-budget=$budget. Run /memory-hygiene:clean when the current task allows; do not interrupt urgent work."
printf '%s\n%s\n' "$key" "$msg" > "$cache"
[ -n "$msg" ] && echo "$msg"
exit 0
