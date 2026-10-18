#!/usr/bin/env bash
# Headless smoke test (spec S5): imports the project, lets the autoplay bot
# play for 3000 frames in god mode, and fails if Godot logged any script error.
# Usage: tools/smoke_test.sh            (GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="${SMOKE_LOG:-smoke.log}"

"$GODOT" --headless --path . --import > import.log 2>&1
if grep -E "SCRIPT ERROR|Parse Error" import.log; then
  echo "FAIL: script errors while importing (see import.log)"; exit 1
fi

timeout 600 "$GODOT" --headless --path . --quit-after 3000 -- --autoplay --god 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG"; then
  echo "FAIL: script errors during the autoplay run (see $LOG)"; exit 1
fi
if ! grep -q "^\[t=" "$LOG"; then
  echo "FAIL: the autoplay bot never reported (exit $status)"; exit 1
fi
echo "PASS: autoplay ran with zero script errors"
