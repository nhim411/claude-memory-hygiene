#!/usr/bin/env bash
# Audit a Claude Code memory dir: stale, missing fields, broken refs, index drift.
# Usage: memory-audit.sh [memory_dir] [repo_root] [max_age_days]
# Reports only; never edits or deletes.
set -uo pipefail
REPO="${2:-$(pwd)}"
MEM="${1:-$(bash "$(dirname "$0")/project-key.sh")}"
MAX_AGE="${3:-45}"
today=$(date +%s)

# Frontmatter value (CRLF-safe); status defaults to active like the index generator.
field() {
  local v
  v=$(tr -d '\r' < "$2" | sed -n '1{/^---$/!q;};/^---$/,/^---$/p' | grep -m1 -E "^[[:space:]]*$1:" | sed -E "s/^[[:space:]]*$1:[[:space:]]*//; s/\"//g")
  [ -z "$v" ] && [ "$1" = status ] && v=active
  printf '%s' "$v"
}
# Epoch seconds for YYYY-MM-DD (GNU date, BSD date, or python).
to_epoch() { date -d "$1" +%s 2>/dev/null || date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || python -c "import datetime,sys;print(int(datetime.datetime.strptime(sys.argv[1],'%Y-%m-%d').timestamp()))" "$1"; }

echo "== Missing source/verified/status"
for f in "$MEM"/*.md; do
  [ "$(basename "$f")" = MEMORY.md ] && continue
  for k in source verified; do
    [ -z "$(field $k "$f")" ] && echo "  $(basename "$f"): no $k"
  done
done

echo "== Active, verified > ${MAX_AGE}d ago (re-check against code / ADO)"
for f in "$MEM"/*.md; do
  [ "$(field status "$f")" = active ] || continue
  v=$(field verified "$f"); [ -z "$v" ] && continue
  age=$(( (today - $(to_epoch "$v")) / 86400 ))
  [ "$age" -gt "$MAX_AGE" ] && echo "  ${age}d  $(field type "$f")  $(basename "$f")"
done | sort -rn

# Backticked repo-relative paths whose first segment is a top-level entry of the repo.
repo_paths() {
  grep -oE '`[A-Za-z0-9_.][^` ]*/[^` ]*`' "$1" | tr -d '`' | sort -u | while read -r p; do
    case "$p" in .*|*'*'*|*'<'*|*'{'*|*'…'*|*foo*|http*|*://*) continue;; esac
    [ -e "$REPO/${p%%/*}" ] && echo "$p"
  done
}

echo "== Repo paths cited but missing (active only)"
for f in "$MEM"/*.md; do
  [ "$(field status "$f")" = active ] || continue
  repo_paths "$f" | while read -r p; do
    [ -e "$REPO/$p" ] || echo "  $(basename "$f"): $p"
  done
done

echo "== Cited code changed since verified (active only; re-check the claim)"
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  for f in "$MEM"/*.md; do
    [ "$(field status "$f")" = active ] || continue
    v=$(field verified "$f"); [ -z "$v" ] && continue
    paths=$(repo_paths "$f" | while read -r p; do [ -e "$REPO/$p" ] && echo "$p"; done)
    [ -z "$paths" ] && continue
    # shellcheck disable=SC2086
    n=$(git -C "$REPO" log --oneline --since="$v 23:59" -- $paths 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && echo "  $n commits  $(basename "$f")"
  done | sort -rn
fi

echo "== Index drift"
idx="$MEM/MEMORY.md"
for f in "$MEM"/*.md; do
  b=$(basename "$f"); [ "$b" = MEMORY.md ] && continue
  st=$(field status "$f")
  if grep -q "($b)" "$idx"; then
    [ "$st" != active ] && echo "  indexed but $st: $b"
  else
    [ "$st" = active ] && echo "  active but not indexed: $b"
  fi
done
grep -oE '\(([^)]+\.md)\)' "$idx" | tr -d '()' | while read -r b; do
  [ -f "$MEM/$b" ] || echo "  index points to missing file: $b"
done

bash "$(dirname "$0")/run-py.sh" memory-signals.py "$MEM" "${MEMORY_UNUSED_DAYS:-60}"

MAX_BYTES="${MEMORY_INDEX_MAX_BYTES:-8000}"
MAX_ENTRIES="${MEMORY_INDEX_MAX_ENTRIES:-45}"
MAX_LINE="${MEMORY_INDEX_MAX_LINE:-200}"
echo "== Index over budget (loaded every session; promote or supersede)"
bytes=$(wc -c < "$idx"); entries=$(grep -c '^- ' "$idx")
[ "$bytes" -gt "$MAX_BYTES" ] && echo "  size ${bytes}B > ${MAX_BYTES}B"
[ "$entries" -gt "$MAX_ENTRIES" ] && echo "  entries $entries > $MAX_ENTRIES"
awk -v max="$MAX_LINE" '/^- / && length($0) > max { match($0, /\(([^)]+\.md)\)/); print "  long line (" length($0) " chars): " substr($0, RSTART+1, RLENGTH-2) }' "$idx"

# Informational only (not counted by the SessionStart nudge).
echo "== Promote candidates: user rules stable > 30d (move to project rules / AGENTS.md, then supersede)"
find "$MEM" -name '*.md' ! -name MEMORY.md -mtime +30 | sort | while read -r f; do
  [ "$(field status "$f")" = active ] && [ "$(field type "$f")" = feedback ] && echo "  $(basename "$f")"
done

echo "== Work items cited by active project memories (check if Done)"
for f in "$MEM"/*.md; do
  [ "$(field status "$f")" = active ] && [ "$(field type "$f")" = project ] || continue
  ids=$(grep -oE '#[0-9]{4}\b' "$f" | sort -u | tr '\n' ' ')
  [ -n "$ids" ] && echo "  $(basename "$f"): $ids"
done
echo "== index size: $(wc -c < "$idx") bytes, $(grep -c '^- ' "$idx") entries"
