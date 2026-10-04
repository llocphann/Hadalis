# Dashboard editor draft checkpoint — 2026-10-05

**STOPPED AT MAINTAINER REQUEST / NOT_COMPLETE.** The maintainer asked to stop
implementation, record the remaining work and push the checkpoint. Do not resume
this continuation without a new maintainer instruction.

The base is `069d148f799f795281f3d37614a49e5fe6893a71` on `dev`. Niri/Quickshell reload success is already
committed at `159c4f79203c352f53d09747c75896b75975a143` and pushed through this
base. It enters the normal notification pipeline, preserving placement,
cooldown, hover/expiry, transient history policy and silent reload behavior.
Errors retain the existing toast copy/dismiss path.

## Preserved Dashboard draft

[dashboard-editor-draft.patch](dashboard-editor-draft.patch) preserves all
fourteen changed/new files. [checkpoint.json](checkpoint.json) records the exact
base, patch hash and candidate file hashes. The unfinished source was saved as
this patch and restored out of the live source tree before the documentation
commit. No Dashboard draft acceptance or deployment is claimed.

The candidate reuses `AbyssBodyHost` and the output's existing field, registers
an attached editor outside the owner's allocator, removes the inline Dashboard
controls, exposes both Dashboard controllers, and places the popup above with a
below fallback. Tight vertical space uses a compact toolbar. A horizontal rail
and focus scrolling preserve controls on narrow outputs. Save/Cancel use the
existing draft controller. Normal standalone/Waffle defaults remain available.

## Evidence and unresolved work

- The isolated native two-host fixture passed fixed canvas/widget dimensions,
  above-owner placement, resize/hidden-module controls, draft save/cancel and
  input release before the fixture gained actual controller/field composition.
  See [isolated native output](native-dashboard-isolated-pass.txt). This is
  focused candidate evidence, not full acceptance of the later draft.
- The later composed fixture **FAILED**. See
  [composition output](native-dashboard-composition-fail.txt). Its equality
  assertion compares the entire field record with the host record; the existing
  producer adds `mass` through a copy. Correct the test to compare the actual
  geometry contract, keeping the field composition checks. Later keyboard,
  narrow-output, image capture and lifecycle assertions were not reached.
- Pure geometry behavior passed 147 above/below/narrow/reveal layouts. Dashboard
  draft/freeform, presentation motion, common geometry/body placement and shell
  surface focused contracts passed during candidate work. The original body
  lifecycle regression passed after adding attached-host support; see
  [native body output](native-body-placement-pass.txt).
- Finish and inspect the composed fixture on both Dashboard hosts and 384px
  output: field painting, owner geometry unchanged, focus/Done visibility,
  tooltip error feedback, draft/save/cancel, input clipping and owner closure.
  Use an explicit fixed viewport for the 1100x800/depth-730 workload when the
  compositor assigns a different real window size. Do not weaken the workload.
- Check Overview search/task-view transitions and output/family lifecycle.
  Capture and inspect the actual Abyss field rendering before promoting source.
- Run `bash scripts/test-abyss-runtime-contract.sh` correctly; a mistaken Python
  invocation of this shell test did not execute the test and is not a product
  failure. Parse all changed QML and rerun appropriate focused regressions after
  the remaining corrections.
- Refetch `dev`, reread each target and check overlap before applying the archived
  patch. Apply only after `git apply --check`; do not overwrite concurrent work.
  Finish the source in one technical-purpose commit and push it.
- New exact-SHA canonical validation is **NOT_RUN**. After the completed source
  commit, run `bash scripts/validate-maintainer-local.sh --current-repo
  --strict-qml` with live automation flags unset; retain the exact SHA and raw
  output. The earlier 415 PASS / 0 FAIL / 11 SKIP applies only to
  `e6d6f9083be1e251c958e7c9fa6228fcd60bc9c7`.
- Further related bug finding/lossless optimization is unfinished. Promote only
  with behavior, read/error/dependency parity and bounded evidence. Allocation
  counts do not establish whole-app CPU/GPU/RAM/FPS percentage gains.
- Owner-session hotplug, suspend, scaling, fullscreen and input/focus acceptance
  remains **HOLD / NOT_COMPLETE**.

No automation job, profile, state or service was authored, dispatched, replayed
or controlled by this continuation. Concurrent owner automation/Cloud Storage
commits were integrated and preserved. The active task entry remains
[to-do/cloud-bot/OPTIMIZATION.md](../../../../to-do/cloud-bot/OPTIMIZATION.md).
