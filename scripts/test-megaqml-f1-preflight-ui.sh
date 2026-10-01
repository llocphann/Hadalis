#!/usr/bin/env bash
# One matrix case only passes if BOTH actual copied-page signal scenarios pass.
# Runs disposable Python fake dispatcher via isolated Quickshell; no MEGAcmd.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bash scripts/test-megaqml-quickshell-smoke.sh ui-shared
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-timeout
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-release
echo 'PASS isolated MegaQML real buttons, replay rejection, preflight timeout and release cancellation'
