#!/usr/bin/env bash
# One matrix case only passes if ALL five real copied-page fake-only scenarios pass.
# Runs disposable Python fake dispatcher via isolated Quickshell; no MEGAcmd.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bash scripts/test-megaqml-quickshell-smoke.sh ui-shared
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-timeout
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-release
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-present
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-overlap
echo 'PASS isolated MegaQML real buttons, replay rejection, timeout, cancellation, fake-installed readiness and overlapping timeout recovery'
