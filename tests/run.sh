#!/usr/bin/env bash
# End-to-end checks for the plugin scripts on a throwaway repo + memory dir.
set -uo pipefail
S="$(cd "$(dirname "$0")/../scripts" && pwd)"
# Windows Git Bash: hand native Python C:/… paths, as Claude Code does.
tmpd() { local d; d=$(mktemp -d); command -v cygpath >/dev/null && d=$(cygpath -m "$d"); echo "$d"; }
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
U=$(tmpd)/.claude/projects/x/memory; mkdir -p "$U"
SPQ="$(tmpd)/A B/.claude/projects/y/memory"; mkdir -p "$SPQ"
printf '{"tool_input":{"file_path":"%s/a.md"}}' "$U" | python3 "$S/memory-usage.py"
printf '{"tool_input":{"file_path":"%s/MEMORY.md"}}' "$U" | python3 "$S/memory-usage.py"
printf '{"tool_input":{"file_path":"/etc/hosts"}}' | python3 "$S/memory-usage.py"
printf '{"tool_input":{"command":"grep -n foo %s/b.md %s/MEMORY.md"}}' "$U" "$U" | python3 "$S/memory-usage.py"
printf '{"tool_input":{"command":"cat \\"%s/q.md\\""}}' "$SPQ" | python3 "$S/memory-usage.py"
SP="$(tmpd)/First Last/.claude/projects/C--p/memory"; mkdir -p "$SP"
printf '{"tool_input":{"file_path":"%s"}}' "$(printf %s "$SP/s.md" | sed 's#/#\\\\#g')" | python3 "$S/memory-usage.py"
if command -v cygpath >/dev/null; then
  printf '{"tool_input":{"command":"cat \\"%s/g.md\\""}}' "$(printf %s "$U" | sed -E 's#^([A-Za-z]):/#/\L\1/#')" | python3 "$S/memory-usage.py"
  ok "Git Bash /c/… path logged (Windows)" 'grep -q "g.md" "$U/.usage.log"'
fi
echo 'not json' | python3 "$S/memory-usage.py"; rc=$?
ok "logs memory file reads only" '[ "$(grep -c "a.md" "$U/.usage.log")" -eq 1 ] && [ "$(grep -vc "g.md" "$U/.usage.log")" -eq 3 ]'
ok "logs reads via Bash commands" 'grep -q "b.md" "$U/.usage.log"'
ok "quoted path with spaces in Bash command" 'grep -q "q.md" "$SPQ/.usage.log"'
ok "Windows-style path with spaces logged" 'grep -q "s.md" "$SP/.usage.log"'
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

echo "# search"
Q=$(mktemp -d)
printf -- '---\nname: intro\ndescription: video opening\nmetadata:\n  type: feedback\n  status: active\n  when: mở đầu video kỹ thuật\n---\nShow the situation before the definition.\n' > "$Q/intro.md"
printf -- '---\nname: dialog\ndescription: narration style\nmetadata:\n  type: feedback\n  status: active\n---\nOne idea per sentence in video narration.\n' > "$Q/dialog.md"
printf -- '---\nname: old\ndescription: video opening old\nmetadata:\n  type: feedback\n  status: superseded\n---\nx\n' > "$Q/old.md"
r=$(python3 "$S/memory-search.py" --dir "$Q" mo dau video)
ok "search ranks when-match first, diacritics folded" '[ "$(sed -n 1p <<<"$r" | awk "{print \$2}")" = intro.md ]'
ok "search skips non-active" '! grep -q old.md <<<"$r"'
ok "search --all includes non-active" 'python3 "$S/memory-search.py" --dir "$Q" --all opening | grep -q old.md'
ok "search folds plurals and slug words" 'python3 "$S/memory-search.py" --dir "$Q" -k 1 dialogs | grep -q dialog.md'
printf '\xff\xfe bad' > "$Q/bin.md"
ok "search survives non-UTF-8 file" 'python3 "$S/memory-search.py" --dir "$Q" video | grep -q intro.md'
ok "search no match" '[ "$(python3 "$S/memory-search.py" --dir "$Q" kubernetes)" = "no match" ]'
a=$(bash "$S/memory-audit.sh" "$Q" "$W" 2>/dev/null)
ok "audit lists feedback without when" 'sed -n "/without/,/^==/p" <<<"$a" | grep -q dialog.md && ! sed -n "/without/,/^==/p" <<<"$a" | grep -q intro.md'

echo "# recall hook"
rc() { python3 -c 'import json,sys;print(json.dumps({"prompt":sys.argv[1],"session_id":sys.argv[2]}))' "$1" "$2" | MEMORY_HYGIENE_DIR="$Q" MEMORY_RECALL_MIN_SCORE=0.5 python3 "$S/memory-recall.py"; }
r=$(rc "viết mở đầu video kỹ thuật mới" s1)
ok "recall suggests matching memory" 'grep -q intro.md <<<"$r"'
ok "recall logs suggestion" 'grep -q "s1	intro.md" "$Q/.recall.log"'
ok "recall silent on repeat in same session" '[ -z "$(rc "viết mở đầu video kỹ thuật mới" s1)" ]'
ok "recall again in a new session" 'rc "viết mở đầu video kỹ thuật mới" s2 | grep -q intro.md'
ok "recall silent on short prompt" '[ -z "$(rc "ok video" s3)" ]'
ok "recall silent on slash command" '[ -z "$(rc "/memory-hygiene:audit video opening intro" s3)" ]'
ok "recall disabled by env" '[ -z "$(MEMORY_RECALL=0 rc "viết mở đầu video kỹ thuật mới" s4)" ]'
ok "recall silent below threshold" '[ -z "$(python3 -c "import json;print(json.dumps({\"prompt\":\"viết mở đầu video kỹ thuật\",\"session_id\":\"s5\"}))" | MEMORY_HYGIENE_DIR="$Q" MEMORY_RECALL_MIN_SCORE=99 python3 "$S/memory-recall.py")" ]'
echo "bad" | MEMORY_HYGIENE_DIR="$Q" python3 "$S/memory-recall.py"; ok "recall never fails on bad input" '[ $? -eq 0 ]'
for i in 1 2 3; do printf '%s\tx%s\tdialog.md\n' "$(date +%F)" "$i" >> "$Q/.recall.log"; done
printf '# since\t%s\n%s\tintro.md\n' "$(date +%F)" "$(date +%F)" > "$Q/.usage.log"
sig=$(python3 "$S/memory-signals.py" "$Q" 60)
ok "recall stats count opened suggestions" 'grep -qE "Recall: [0-9]+ suggestions.*[1-9][0-9]* opened" <<<"$sig"'
ok "never-opened suggestion listed" 'sed -n "/Recall/,\$p" <<<"$sig" | grep -q "3x  dialog.md"'
sed -i.bak 's/  status: active/  status: active\n  recurrences: 3/' "$Q/dialog.md" 2>/dev/null; python3 - "$Q/dialog.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read().replace("  status: active\n","  status: active\n  recurrences: 3\n",1); open(p,"w").write(s)
PY
a=$(bash "$S/memory-audit.sh" "$Q" "$W" 2>/dev/null)
ok "audit lists repeated corrections" 'sed -n "/Repeated/,/^==/p" <<<"$a" | grep -q "3x  dialog.md"'

echo "# non-UTF-8 memory file"
B=$(mktemp -d); echo "# Memory Index" > "$B/MEMORY.md"; printf '\xff\xfe bad' > "$B/bin.md"
printf -- '---\nname: a\ndescription: a\nmetadata:\n  type: user\n---\nx\n' > "$B/a.md"
out=$(cd "$W" && MEMORY_HYGIENE_DIR="$B" MEMORY_HYGIENE_NO_CACHE=1 bash "$S/memory-health.sh" 2>&1)
ok "health still rebuilds index" 'grep -q "(a.md)" "$B/MEMORY.md"'
ok "undecodable file left untouched" '[ "$(head -c 2 "$B/bin.md" | od -An -tx1 | tr -d " ")" = fffe ]'
ok "no traceback" '! grep -q Traceback <<<"$out"'

echo "# project key"
ok "linux path" '[ "$(HOME=/h bash "$S/project-key.sh" /home/a/my_app.v2)" = "/h/.claude/projects/-home-a-my-app-v2/memory" ]'
ok "windows path with spaces" '[ "$(HOME=/h bash "$S/project-key.sh" "C:/Users/LE HOAI NAM/proj")" = "/h/.claude/projects/C--Users-LE-HOAI-NAM-proj/memory" ]'
ok "python launcher runs" '[ "$(bash "$S/run-py.sh" memory-index.py "$M" --check >/dev/null 2>&1; echo $?)" -le 1 ]'

echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
