#!/usr/bin/env bash
# Unit-only Phase 2p contracts; no Qt application or vendor executables.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
bash -n scripts/test-megaqml-race-repeat.sh
bash -n scripts/test-megaqml-phase2-local.sh
bash -n scripts/test-megaqml-f1-preflight-ui.sh
python3 scripts/test-megaqml-race-repeat-contract.py
node scripts/test-megaqml-race-stage-guard.mjs
python3 scripts/test-megaqml-phase2p-history-guard-contract.py
python3 scripts/test-megaqml-evidence-push-retry-contract.py
# CLI validation is side-effect free: reject unknown publish modes before Git IO.
invalid_mode="$(bash scripts/test-megaqml-phase2-local.sh "$(printf '0%.0s' {1..40})" --invalid 2>&1)" && {
  echo 'FAIL local-mode unknown-argument accepted'
  exit 1
}
[[ "$invalid_mode" == 'INVALID_PUBLICATION_MODE' ]] || {
  echo 'FAIL local-mode unknown-argument wrong rejection'
  exit 1
}
invalid_sha="$(bash scripts/test-megaqml-phase2-local.sh NOT_A_SHA --local-only 2>&1)" && {
  echo 'FAIL local-only invalid SHA accepted'
  exit 1
}
[[ "$invalid_sha" == 'INVALID_SOURCE_SHA' ]] || {
  echo 'FAIL local-only invalid SHA wrong rejection'
  exit 1
}
echo 'PASS MegaQML repeatability, strict ancestry and guarded publication unit contracts'
