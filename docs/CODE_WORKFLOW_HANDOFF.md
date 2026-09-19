# Code Workflow Phase 0 — continuation

Updated 2026-09-20. Work directly on `dev`; refetch before audit/writes, preserve
concurrent work, atomic commits, never mutate `stable`. No production editor UI
or source-writing transforms until A–E pass. The maintainer explicitly requested
this technical continuation note for moving from desktop to online chat.

## Current evidence

- A: parser corpus proven at `2289105d686f38a7a682cef0b781f3bc0ee781c6`:
  1,006 QML files preserve bytes, incremental CST and prefix-shift anchors;
  16 native tests. Semantic resolution/runtime helper packaging remain open.
- B: 18 input checks pass; Geometry/Curve 20–250 node benchmark exists. Profiling,
  long memory soak, actual touchpad and platform/scaling coverage remain open.
- C: 10 checks on actual ii Bar objects in isolated Quickshell/Niri pass.
  [Full pinned report](evidence/code-workflow/spike-c.niri.json).
- D: next — real transient picker, click isolation, Settings hide/restore,
  presentation hold, output removal and lock cancellation.
- E: next — ordinary Quickshell reload, replacement QObject, persistent semantic
  selection and static fallback when Media is unloaded.

## Reproduce / continue

Read [the design](CODE_WORKFLOW_EDITOR.md),
[evidence and limits](CODE_WORKFLOW_FEASIBILITY.md), and
[probe commands](../scripts/code-workflow/README.md).
`python3 scripts/code-workflow/run-runtime.py --work-dir /tmp/hadalis-cde-new`
requires a real Wayland desktop with Niri/Quickshell/dbus-run-session. The runner
creates a committed Git export with narrowly scoped temporary instrumentation;
it never patches the installed shell or sends it IPC. New destinations only.
Source/harness hashes are part of the JSON evidence. Do not count a mock reload
or synthetic screen model as a real Quickshell/compositor lifecycle pass.

The current host has one physical screen. Nested Niri supports proving actual
input/layer-shell behavior without disturbing the main shell; multi-output and
output removal need a separate controlled compositor/output experiment.
An online chat without a Wayland runtime can review/build/extend the harness,
but must leave those runtime checks explicitly pending.

## Validation boundary

Canonical validation at `2289105d`: 80 pass, 21 fail, 1 Nix deferred; the clean
parent `9f531a6d` has the same 21 failure labels. One added nonfatal hardcoded-color
warning is from the standalone graph sandbox. Later concurrent Vertical Bar and
Overview commits are not covered by that old validation. Run the canonical local
validator on the exact new commit; do not translate focused probe success into a
whole-repository PASS. Never weaken unrelated contracts to make this spike green.
