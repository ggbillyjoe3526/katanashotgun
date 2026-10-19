#!/usr/bin/env bash
# Seed check (spec §7.5, seeds are law): the autoplay bot plays the same seed
# twice. The bot's own moves are unseeded, so the two runs play out
# differently, yet every wave both runs reach must have the same plan
# (mutator, boss, line-up) and every augment offer both runs saw must be the
# same cards. Fails on any difference, on script errors, or if the runs are
# too short to compare.
# Usage: tools/seed_check.sh [SEED] [FRAMES]   (GODOT=/path/to/godot to override;
#        SEED_ARGS="--cans" adds game flags, e.g. to check the soda cans too)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
SEED="${1:-1234-ABCD}"
FRAMES="${2:-24000}"
MIN_WAVES=5 # past the first boss and into the waves the old bug changed
LOG_A="${SEED_LOG:-seed}_a.log"
LOG_B="${SEED_LOG:-seed}_b.log"

if [ ! -d .godot ]; then
  "$GODOT" --headless --path . --import > import.log 2>&1
fi

# --fixed-fps runs the game faster than real time: FRAMES / 60 game seconds
run() {
  timeout 900 "$GODOT" --headless --path . --fixed-fps 60 --quit-after "$FRAMES" -- --autoplay --god --seed="$SEED" ${SEED_ARGS:-} > "$1" 2>&1
}
run "$LOG_A" &
run "$LOG_B"
wait

for log in "$LOG_A" "$LOG_B"; do
  if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$log"; then
    grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$log" | head -5
    echo "FAIL: script errors during a seed check run (see $log)"; exit 1
  fi
done

fail=0
# compares the lines both runs printed, up to the shorter run's count
compare() {
  local what="$1" pattern="$2" na nb n
  grep -E "$pattern" "$LOG_A" > "$LOG_A.$what" || true
  grep -E "$pattern" "$LOG_B" > "$LOG_B.$what" || true
  na=$(wc -l < "$LOG_A.$what")
  nb=$(wc -l < "$LOG_B.$what")
  n=$(( na < nb ? na : nb ))
  echo "$what: comparing $n (run A printed $na, run B $nb)"
  if ! diff <(head -n "$n" "$LOG_A.$what") <(head -n "$n" "$LOG_B.$what"); then
    echo "FAIL: the same seed gave different $what"; fail=1
  fi
  rm -f "$LOG_A.$what" "$LOG_B.$what"
  COMPARED=$n
}
compare plans "^\[plan\]"
waves=$COMPARED
compare offers "^\[offer\]"
compare cans "^\[cans\] wave" # soda cans (only with SEED_ARGS=--cans)

if [ "$waves" -lt "$MIN_WAVES" ]; then
  echo "FAIL: only $waves waves to compare, need $MIN_WAVES (raise FRAMES)"; exit 1
fi
# the runs should have played out differently (different scores, levels)
end_a=$(grep "^\[t=" "$LOG_A" | tail -1 | grep -oE "wave=[0-9]+|lvl=[0-9]+|score=[0-9]+" | tr '\n' ' ')
end_b=$(grep "^\[t=" "$LOG_B" | tail -1 | grep -oE "wave=[0-9]+|lvl=[0-9]+|score=[0-9]+" | tr '\n' ' ')
echo "run A ended at $end_a"
echo "run B ended at $end_b"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "PASS: seed $SEED gave the same $waves wave plans in two differently played runs"
