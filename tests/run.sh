#!/usr/bin/env bash
# End-to-end checks for the plugin scripts on a throwaway repo + memory dir.
set -uo pipefail
S="$(cd "$(dirname "$0")/../scripts" && pwd)"
W=$(mktemp -d); M=$(mktemp -d)
trap 'rm -rf "$W" "$M"' EXIT
pass=0; fail=0
ok() { if eval "$2"; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1"; fi; }
gitc() { git -C "$W" -c user.name=t -c user.email=t@t commit -q "$@"; }

echo "# no memory dir"
out=$(cd "$W" && bash "$S/memory-health.sh"); ok "silent when project has no memory" '[ -z "$out" ]'

echo "# fixture"
mkdir -p "$W/src"; echo 1 > "$W/src/app.py"; git -C "$W" init -q; git -C "$W" add .
GIT_COMMITTER_DATE=2020-01-01T00:00:00 gitc -m init --date=2020-01-01T00:00:00
echo "# Memory Index" > "$M/MEMORY.md"
printf -- '---\nname: a\ndescription: rule A\nmetadata:\n  type: feedback\n---\nUse `src/app.py` and `src/gone.py`.\n' > "$M/a.md"
printf -- '---\r\nname: b\r\ndescription: crlf\r\ntype: project\r\n---\r\nbody\r\n' > "$M/b.md"
printf '# Loose note\nno frontmatter\n' > "$M/c.md"
printf -- '---\nname: e\ndescription: no type\n---\nx\n' > "$M/e.md"
run() { (cd "$W" && MEMORY_HYGIENE_DIR="$M" bash "$S/memory-health.sh"); }

echo "# first session start"
out=$(run)
ok "migrates all 4 files" 'grep -q "migrated 4" <<<"$out"'
ok "rebuilds index" 'grep -q "MEMORY.md rebuilt" <<<"$out"'
ok "feedback -> source user" 'grep -q "source: user" "$M/a.md"'
ok "CRLF preserved" '[ "$(grep -c $'"'"'\r$'"'"' "$M/b.md")" -eq "$(wc -l < "$M/b.md")" ]'
ok "CRLF file got status" 'grep -q "status: active" "$M/b.md"'
ok "no-frontmatter file got one" 'head -1 "$M/c.md" | grep -q "^---$"'
ok "no-type file got metadata" 'grep -q "type: project" "$M/e.md"'
ok "all 4 indexed" '[ "$(grep -c "^- " "$M/MEMORY.md")" -eq 4 ]'
ok "broken path flagged" 'grep -q "broken-paths=1" <<<"$out"'

echo "# second session start"
out=$(run); ok "idempotent: no migrate/rebuild" '! grep -q "migrated\|rebuilt" <<<"$out"'

echo "# validity"
sed -i.bak 's#`src/gone.py`##; s/verified: .*/verified: 2020-01-02/' "$M/a.md"
echo 2 > "$W/src/app.py"; git -C "$W" add .; gitc -m change
out=$(run); ok "cited code changed since verified" 'grep -q "code-changed=1" <<<"$out"'
ok "stale > 45d" 'grep -q "stale=1" <<<"$out"'

echo "# supersede"
sed -i.bak 's/status: active/status: superseded/' "$M/a.md"
out=$(run); ok "superseded dropped from index" '! grep -q "(a.md)" "$M/MEMORY.md"'

echo "# budget"
for i in $(seq 1 50); do printf -- '---\nname: p%s\ndescription: x\nmetadata:\n  type: project\n---\n' "$i" > "$M/p$i.md"; done
out=$(run); ok "over budget flagged" 'grep -qE "over-budget=[1-9]" <<<"$out"'

echo "# cache"
out1=$(run); out2=$(run)
ok "cached result identical" '[ "$out1" = "$out2" ]'
printf -- '---\nname: z\ndescription: z\nmetadata:\n  type: project\n---\nSee `src/missing.py`.\n' > "$M/z.md"
out3=$(run); ok "cache invalidated by memory change" 'grep -q "broken-paths=1" <<<"$out3" && [ "$out3" != "$out2" ]'

echo "# usage log"
U=$(mktemp -d)/.claude/projects/x/memory; mkdir -p "$U"
printf '{"tool_input":{"file_path":"%s/a.md"}}' "$U" | python3 "$S/memory-usage.py"
printf '{"tool_input":{"file_path":"%s/MEMORY.md"}}' "$U" | python3 "$S/memory-usage.py"
printf '{"tool_input":{"file_path":"/etc/hosts"}}' | python3 "$S/memory-usage.py"
printf '{"tool_input":{"command":"grep -n foo %s/b.md %s/MEMORY.md"}}' "$U" "$U" | python3 "$S/memory-usage.py"
echo 'not json' | python3 "$S/memory-usage.py"; rc=$?
ok "logs memory file reads only" '[ "$(grep -c "a.md" "$U/.usage.log")" -eq 1 ] && [ "$(wc -l < "$U/.usage.log")" -eq 3 ]'
ok "logs reads via Bash commands" 'grep -q "b.md" "$U/.usage.log"'
ok "bad input never fails the hook" '[ "$rc" -eq 0 ]'

echo "# unused + duplicates"
D=$(mktemp -d)
mk() { printf -- '---\nname: %s\ndescription: %s\nmetadata:\n  type: project\n  status: active\n---\n%s\n' "$1" "$2" "$3" > "$D/$1.md"; }
mk used "staging deploy runbook" "deploy staging cluster with helm chart"
mk idle "printer driver quirk" "office printer needs legacy driver"
mk dupe "staging deploy steps" "deploy staging cluster using helm chart values"
old=$(python3 -c "import datetime;print(datetime.date.today()-datetime.timedelta(days=90))")
printf '# since\t%s\n%s\tused.md\n' "$old" "$(date +%F)" > "$D/.usage.log"
sig=$(python3 "$S/memory-signals.py" "$D" 60)
ok "unused memory listed" 'sed -n "/Unused/,\$p" <<<"$sig" | grep -q idle.md'
ok "used memory not listed" '! sed -n "/Unused/,\$p" <<<"$sig" | grep -q " used.md"'
ok "related pair found" 'grep -q "dupe.md ~ used.md\|used.md ~ dupe.md" <<<"$sig"'
ok "unrelated pair not found" '! grep -q "idle.md ~" <<<"$sig"'
printf '# since\t%s\n' "$(date +%F)" > "$D/.usage.log"
sig=$(python3 "$S/memory-signals.py" "$D" 60)
ok "no unused report before window elapsed" '[ -z "$(sed -n "/Unused/,\$p" <<<"$sig" | grep "^  ")" ]'

echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
