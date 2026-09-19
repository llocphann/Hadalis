# Code Workflow Phase 0 — desktop to online continuation

Updated 2026-09-20. Read AGENTS.md and refetch current `dev` before audit/writes.
Work directly on `dev`, preserve concurrent work, commit atomic milestones,
never mutate `stable`. This note is explicitly requested by the maintainer.

## Current result

**C, D and E pass within the isolated live prototype scope.**
The complete matrix passes 40 checks on nested Niri and 44 on two-output headless
Sway, with actual Quickshell 0.3.1 and Hadalis Bar/Media/Clock/Settings components.

- C: semantic/output-qualified IDs, allowlisted snapshots, resident/unloaded
  transitions, explicit stale events and no dormant LazyLoader activation.
- D: actual Overlay picker, compositor input, click isolation, Settings
  teardown/restore, viewport, auto-hide presentation hold, right-click cancel,
  top/bottom geometry, shell-lock signal and closed-Bar behavior. Two real
  wl_outputs at scale 1/1.25 cover removal/reconnection and selected-output state.
- E: three source-triggered ordinary Quickshell reloads per backend; selection
  and viewport survive new QQmlEngine/QObject generations. Actual old Media
  destruction is observed. Unloaded selection remains static through reload.

[Niri evidence](evidence/code-workflow/spike-cde.niri.json) and
[Sway evidence](evidence/code-workflow/spike-cde.sway.json) pin source revision,
QML/driver/binary hashes, assertions, snapshots and protocol lifetimes. The first
C milestone is `dddae31695f1a6d73e4a8025821da68839148c48`. Its generated-import
regression was independently fixed in `b8ab566d5138d5dbcc18217b956f45f560a45817`;
that fix and its guard tests are retained.
The D/E implementation checkpoint is
`2171f6d69fe05e4106f79f8a95495c81c39b21f7`.
The strengthened state/lifetime checkpoint and final tested implementation is
`997caa0f8453bcbc9b4b6fe37f21676185d03845`. Both current runtime JSON reports
were run from that exact committed revision: C 10 + D 21 + E 9 checks on Niri,
and C 10 + D 25 + E 9 on Sway. The protocol assertions cover 5 and 14 transient
picker surface lifetimes respectively.

The final evidence-only publication preserves concurrent `dev` work through
`6248def18705e28a3049b0f36991365637566fcc` (Weather/VerticalBar).
Validation below applies to `997caa0f`, not later concurrent changes.

A already passed the parser corpus at `2289105d686f38a7a682cef0b781f3bc0ee781c6`:
1,006 QML files, no-op byte preservation, incremental CST equality and prefix
anchor stability; 16 native tests. It is a CST/range candidate, not resolved IR.
B has 18 passing input checks and Geometry/Curve 20–250 node measurements, but
profiling, long memory soak, hardware touchpad and platform acceptance remain open.

**Do not start production editor UI or source-writing transforms yet.** C–E
do not close B's remaining gate or make the whole repository green.

## Critical implementation lessons

1. Keep runtimeRef ephemeral. PersistentProperties should contain primitive
   semantic IDs and JSON strings, not QObject/QJSValue objects from the old engine.
2. Wait for persistence loaded before applying state to the recreated runtime.
3. Geometry is QML-owned and output-local. The probe explicitly models horizontal
   Bar anchors; do not generalize mapToGlobal into cross-layer-shell authority.
4. Picker input surfaces exist only during picking. Wait for Settings teardown,
   consume the entire click, destroy surfaces, then restore Settings and selection.
5. None keyboard interactivity plus right-click cancel is the proven path.
   Do not change this to Exclusive. Trace evidence checks each surface lifetime,
   because Wayland object IDs can later be reused by Settings or popup surfaces.
6. Fixture config changes use Config.setNestedValue so the JSON mirror agrees.
   Virtual pointer device lifetime must span the hover experiment on headless seats.
7. Never treat a QObject address as a lifetime ID: allocators reuse addresses.
   The qualified probe uses an object-owned birth marker plus destruction signal.
   Restore tests use non-default Settings page 2 and custom viewport values.

## Reproduce

See [probe README](../scripts/code-workflow/README.md) for dependencies and exact
commands. `run-runtime.py --spikes CDE` stages a new committed Git export and
instruments only that temporary copy. The installed shell, user config and
desktop IPC are untouched. Supply a new --work-dir and the built pointer helper.
Optional --sway selects the two-output headless matrix. Finally cleanup stops
only processes started by the runner; JSON and logs remain in its work directory.

Read [the full evidence/limits](CODE_WORKFLOW_FEASIBILITY.md) and
[the design](CODE_WORKFLOW_EDITOR.md). Lock tests drive GlobalStates.screenLocked;
they do not prove PAM/compositor-lock security. Headless output lifecycle is not
physical hotplug or Niri multi-monitor testing. Popup focus-grab interactions and
other shell surfaces are outside the first picker scope. Existing Settings and
Media warnings are reported, not silently treated as probe failures or fixes.

An online environment without Wayland can review and extend the code and run
static tests, but must not claim new live runtime validation.

## Next work

Close B with targeted edge invalidation/profiling and a longer memory/rebuild
soak, retaining the measured workload. Resolve relevant baseline failures before
production integration. Then qualify the supported platform/input matrix and
design the first source transaction against real diagnostics, not CST success
alone. No runtime dependency/packaging choice or source-writing authorization
follows from these prototypes.

## Final validation and committed files

Canonical validation at `997caa0f8453bcbc9b4b6fe37f21676185d03845` reports
**80 passed, 21 failed, one deferred Nix check**. Baseline
`b8ab566d5138d5dbcc18217b956f45f560a45817` has the same totals and all 21 failure
labels. The only normalized failure-body changes remove a probe Config warning;
fatal counts do not increase. These are local results, not CI or a whole-repo PASS.

- [Exact implementation validation log](evidence/code-workflow/validation.997caa0f.txt)
- [Baseline validation log](evidence/code-workflow/validation.b8ab566d.txt)
- [Machine-readable comparison and full failure labels](evidence/code-workflow/validation-comparison.json)

The implementation lives in `scripts/code-workflow/prepare-runtime.py`,
`run-runtime.py`, `runtime/*.qml`, `virtual-pointer.c` and `build-pointer.sh`.
The probe README documents reproduction. Design/feasibility/this handoff live in
`docs/CODE_WORKFLOW_*.md`; tracked JSON reports and canonical logs are under
`docs/evidence/code-workflow/`. No production editor UI or production runtime
registration was added; instrumentation only changes temporary exported copies.

For online continuation, start with this file on freshly fetched `dev`, then
read the full feasibility report and probe README. All required implementation,
results and baseline logs are in the repository; no desktop chat attachment is
needed. Preserve existing evidence and do not weaken contracts to improve status.
