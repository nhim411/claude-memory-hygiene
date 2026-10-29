#!/usr/bin/env bash
# Audit a Claude Code memory dir: stale, missing fields, broken refs, index drift.
# Usage: memory-audit.sh [memory_dir] [repo_root] [max_age_days]
# Reports only; never edits or deletes.
set -uo pipefail
REPO="${2:-$(pwd)}"
MEM="${1:-$HOME/.claude/projects/$(printf %s "$REPO" | sed 's#[/.]#-#g')/memory}"
MAX_AGE="${3:-45}"
today=$(date +%s)

field() { sed -n '/^---$/,/^---$/p' "$2" | grep -m1 -E "^\s*$1:" | sed -E "s/^\s*$1:\s*//; s/\"//g"; }

echo "== Missing source/verified/status"
for f in "$MEM"/*.md; do
  [ "$(basename "$f")" = MEMORY.md ] && continue
  for k in source verified status; do
    [ -z "$(field $k "$f")" ] && echo "  $(basename "$f"): no $k"
  done
done

echo "== Active, verified > ${MAX_AGE}d ago (re-check against code / ADO)"
for f in "$MEM"/*.md; do
  [ "$(field status "$f")" = active ] || continue
  v=$(field verified "$f"); [ -z "$v" ] && continue
  age=$(( (today - $(date -d "$v" +%s)) / 86400 ))
  [ "$age" -gt "$MAX_AGE" ] && echo "  ${age}d  $(field type "$f")  $(basename "$f")"
done | sort -rn

echo "== Repo paths cited but missing (active only)"
for f in "$MEM"/*.md; do
  [ "$(field status "$f")" = active ] || continue
  grep -oE '`(scripts|docs|frontend|backend|database|\.claude|\.agents)/[^` ]+`' "$f" | tr -d '`' | sort -u |
    while read -r p; do
      case "$p" in *'*'*|*'<'*|*'{'*|*'…'*|*foo*) continue;; esac
      [ -e "$REPO/$p" ] || echo "  $(basename "$f"): $p"
    done
done

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

echo "== Work items cited by active project memories (check if Done)"
for f in "$MEM"/*.md; do
  [ "$(field status "$f")" = active ] && [ "$(field type "$f")" = project ] || continue
  ids=$(grep -oE '#[0-9]{4}\b' "$f" | sort -u | tr '\n' ' ')
  [ -n "$ids" ] && echo "  $(basename "$f"): $ids"
done
echo "== index size: $(wc -c < "$idx") bytes, $(grep -c '^- ' "$idx") entries"
