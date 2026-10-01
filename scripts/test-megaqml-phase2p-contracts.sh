#!/usr/bin/env bash
# Unit-only Phase 2p contracts; no Qt application or vendor executables.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bash -n scripts/test-megaqml-race-repeat.sh
python3 scripts/test-megaqml-race-repeat-contract.py
node scripts/test-megaqml-race-stage-guard.mjs
python3 scripts/test-megaqml-phase2p-history-guard-contract.py
echo 'PASS MegaQML repeatability and strict ancestry unit contracts'
