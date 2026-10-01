#!/usr/bin/env bash
# One matrix case only passes if BOTH actual copied-page signal scenarios pass.
# Runs disposable Python fake dispatcher via isolated Quickshell; no MEGAcmd.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bash scripts/test-megaqml-quickshell-smoke.sh ui-shared
bash scripts/test-megaqml-quickshell-smoke.sh ui-preflight-timeout
echo 'PASS isolated MegaQML real shared buttons, replay rejection and preflight timeout'
