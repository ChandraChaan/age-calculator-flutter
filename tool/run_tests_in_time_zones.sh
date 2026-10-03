#!/usr/bin/env bash
# Runs the test suite once per time zone. Calendar-date results must be
# identical in every zone, so every run must pass.
#
# Usage: tool/run_tests_in_time_zones.sh [extra flutter test arguments]
set -euo pipefail

cd "$(dirname "$0")/.."

zones=(UTC Asia/Kolkata Europe/London America/New_York America/Los_Angeles)

for zone in "${zones[@]}"; do
  echo "=== TZ=${zone}"
  TZ="${zone}" flutter test "$@"
done

echo "All time zones passed: ${zones[*]}"
