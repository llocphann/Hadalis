#!/usr/bin/env bash
# Unit-only Phase 2p contracts; no Qt application or vendor executables.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bash -n scripts/test-megaqml-race-repeat.sh
bash -n scripts/test-megaqml-phase2-local.sh
python3 scripts/test-megaqml-race-repeat-contract.py
node scripts/test-megaqml-race-stage-guard.mjs
python3 scripts/test-megaqml-phase2p-history-guard-contract.py
python3 scripts/test-megaqml-evidence-push-retry-contract.py
echo 'PASS MegaQML repeatability, strict ancestry and guarded publication unit contracts'
