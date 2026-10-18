#!/usr/bin/env bash
# Movement test (scripts/debug_movement.gd): a scripted course on real physics
# that checks the jump and double jump heights, ledge climbing (and that walls
# too tall to grab are never climbed) and the plunge. Fails on any failed
# check or script error.
# Usage: tools/movement_test.sh         (GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="${MOVE_LOG:-movement.log}"

if [ ! -d .godot ]; then
  "$GODOT" --headless --path . --import > import.log 2>&1
fi

timeout 300 "$GODOT" --headless --path . --fixed-fps 60 -- --movetest 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG"; then
  echo "FAIL: script errors during the movement test (see $LOG)"; exit 1
fi
if [ "$status" -ne 0 ] || ! grep -q "^\[movetest\] PASS" "$LOG"; then
  echo "FAIL: movement checks failed (exit $status, see $LOG)"; exit 1
fi
echo "PASS: movement test"
