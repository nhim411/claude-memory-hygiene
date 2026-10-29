#!/usr/bin/env bash
# Run a plugin python script with whichever interpreter exists (python3 / python / py -3).
# Exits 0 silently when none works, so hooks never break a session.
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/$1"; shift
for py in python3 python "py -3"; do
  # The Windows Store "python3" stub exists but fails; probe it before use.
  if $py -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" >/dev/null 2>&1; then
    exec $py "$script" "$@"
  fi
done
exit 0
