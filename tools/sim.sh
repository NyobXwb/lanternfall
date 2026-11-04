#!/usr/bin/env bash
# Parallel balance sweep: tools/sim.sh RUNS [extra sim args]
# Splits RUNS seeds per class across all cores and prints one line per chunk.
set -e
GODOT="${GODOT:-godot}"
RUNS="${1:-200}"; shift || true
JOBS=$(nproc)
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
for c in guard cutpurse adept; do
  per=$(( (RUNS + JOBS - 1) / JOBS ))
  for j in $(seq 0 $((JOBS - 1))); do
    s=$(( 1 + j * per ))
    timeout 1800 "$GODOT" --headless --path . -s tools/sim.gd -- --runs "$per" --seed "$s" --class "$c" --verbose "$@" > "$TMP/$c.$j" 2>&1 &
  done
  wait
  cat "$TMP/$c".* | grep -E "^(guard|cutpurse|adept) seed="
done
