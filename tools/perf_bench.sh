#!/usr/bin/env bash
# Perf probe on a fixed seed (spec §14, §16). Runs the autoplay bot with
# --perf and prints the [perf-summary] lines.
#   headless: node churn, live nodes and objects, script time per frame
#   render:   draw calls and primitives (needs a display; xvfb-run in the cloud)
# Script time only compares runs on the same machine; draw calls, primitives
# and node counts are the same everywhere. Frame rates need real hardware.
# Usage: tools/perf_bench.sh [headless|render] [wave] [frames] [quality]
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
MODE="${1:-headless}"
WAVE="${2:-1}"
FRAMES="${3:-6000}"
QUALITY="${4:-high}"
ARGS=(-- --autoplay --god --seed=1234-5678 --wave="$WAVE" --quality="$QUALITY" --perf)
if [ "$MODE" = "render" ]; then
  RUN=(xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 960x540)
else
  RUN=("$GODOT" --headless --path .)
fi
timeout 3000 "${RUN[@]}" --fixed-fps 60 --quit-after "$FRAMES" "${ARGS[@]}" 2>&1 | grep -E "^\[perf-summary\]|SCRIPT ERROR"
