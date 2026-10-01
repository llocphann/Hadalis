# Wull — nested Niri real pointer acceptance design

Status: **underlay fixture and inert target contract staged; no physical pointer test executed**.
Scope: the existing actual `AbyssPerimeter` PanelWindow with production
`AbyssCompanion`, not a synthetic standalone mascot or an offscreen rectangle.

## Existing evidence and boundary

The October 1 production geometry receipts on `336726d7...` and
`fca39532...` both recorded four-edge containment of the actual centered
production QML. Focused native/perimeter qualification recorded 8/8 PASS
on `c10b669f...`. The new nested-Niri receipts
`docs/wull-nested-niri-20261001T152505Z-d938e783-24af1766f3eb.json`
and
`docs/wull-production-layer-20261001T152511Z-c5413658-24af1766f3eb.json`
both recorded PASS on exact source
`24af1766f3eb7fc7abb2a381efba962ea51ed42d`.
Those nested receipts established an owned private compositor, one active
output, real production layer mapping, default-off isolation, single owned
Rust backend when enabled, keyboard-focus constraints and full cleanup.
**They did not send a mouse event or qualify any compositor hit region.**

The existing production input mask deliberately includes the entire
`AbyssCompanion` host. The smaller rotated body is the click receiver. A
source-level rectangle is not proof that a Wayland compositor will route
an actual pointer event as intended. Do not change production mask yet.

## Staged groundwork (safe, no live run)

- `scripts/wull-fixtures/pointer-underlay/shell.qml` is a separate,
  full-output `WlrLayer.Bottom` PanelWindow with namespace
  `hadalis:wull-pointer-underlay`, no keyboard focus and a click witness.
  It has no production loader, Wull enablement or virtual input capability.
  Its `WULL_POINTER_UNDERLAY_PRESS` coordinates appear only in private
  test logs. It must be launched only inside an owned nested Niri socket.
- `scripts/wull-pointer-targets.py` computes **candidate** top-edge
  production bounds and three points from the reviewed default
  configuration, real shared host-policy placement equation and
  production mapped body dimensions: a body center, an empty host margin
  and an exterior control. It enforces a bounded output/geometry and
  avoids the default bar's top 40 logical pixels. Estimates do not
  constitute a hit-test or a screenshot-based visual acceptance.
- `scripts/test-wull-pointer-underlay-contract.py` is an inert automated
  regression: fixture layering and marker contracts, default-off and
  unchanged whole-host mask, actual production click wiring, and
  deterministic target calculations across small and large viewports.
  Its new code still requires execution evidence on an exact source SHA.

## Implementation gate for a controlled real click runner

1. **Isolation**: from a clean, fast-forward-only `dev`, verify permitted
   origin, owner-created private diagnostics outside the repository and
   audited production/fixture blobs. Start one nested Niri inside the
   host's regular Wayland window with a private empty `NIRI_CONFIG`.
   Verify *distinct* nested `WAYLAND_DISPLAY` and `NIRI_SOCKET` and
   zero preexisting production/underlay namespace collisions. Abort
   before launching any pointer actor if identity cannot be proved.
2. **Underlay**: start only the dedicated private underlay on the nested
   display. Confirm its explicit QML-ready marker AND compositor layer
   inventory (one bottom layer on the expected nested output).
   Never run underlay on the real host display.
3. **Production**: run the real unchanged Abyss production fixture with
   its own isolated XDG directories and D-Bus, pinned private release
   `inir-companiond`, default-off and temporarily enabled phases.
   For pointer tests only, explicitly set
   `abyss.companion.interactive=true`, `edge=top`, `along=.72`,
   `size=1`, and a known nested output. Do not persist any user config.
   Verify compositor-visible layer ownership and exact private daemon
   count. The prior production probe uses `interactive=false` and
   therefore cannot qualify click reception on its own.
4. **Input provenance**: permit only a Wayland-native virtual-pointer
   client bound to the **verified nested socket**. A native
   `wlr-virtual-pointer` backend may be used if installed and shown to
   work on the exact local nested Niri instance. Do not use host-global
   `ydotool`/`uinput`, root input, uncontrolled desktop tools or any
   fallback that can inject into the live compositor. Do not silently
   download or install an input tool as a test side effect. Missing
   backend or unavailable protocol => **INCONCLUSIVE**, not PASS.
5. **Acceptance matrix**: require an *observed* underlay click at the
   body-center candidate with Wull disabled (negative control), then
   an observed underlay click outside the host when enabled (pass-through
   control). With Wull enabled, click the actual body center: require
   the underlay receives **no** click **and** independent private evidence
   that production Wull's click was delivered to its real Rust bridge.
   Absence of an underlay click alone is not enough: an unrelated top
   UI region or absent input could yield the same result. Measure the
   host-empty-margin point separately; the current whole-host mask may
   capture it, and that is an **observation** rather than a reason to
   call pass-through successful. Count clicks using distinct bounded
   time windows, exclude startup/animation settle windows, and check
   the current top bar is not covering any test point.
6. **No conflation**: the first controlled top-edge matrix is separate
   from four-edge *physical* input behavior; later extend the validated
   approach to bottom/left/right, and then test pointer passthrough
   before/after any proposed inner-body-only Region change. Niri
   layer inventory does not report per-pixel input masks. A screenshot
   command succeeding does not prove visual quality.
7. **Cleanup/publication**: bound each process and whole milestone;
   terminate only owned live process groups and the exact private
   daemon binary, verify underlay and production layers unmap, verify
   nested socket disappearance and unchanged host-output inventory.
   Log raw QML events and coordinates locally only. Publish a unique
   SHA-pinned allowlisted JSON receipt with per-case status, preflight
   reason, exact source blobs and cleanup evidence; no raw screenshots,
   device names, host sockets, paths or logs. If publication is blocked,
   retain local evidence and print a short STOP; never rewrite shared
   Git history or fall back to an active desktop test.

## Decision after evidence

Only consider replacing the whole-host Wull `Region` after the real
underlay/body matrix, followed by a separate candidate-mask test
on the same compositor with unchanged click/hover behavior. Keep
`abyss.companion.enabled=false` by default. Canonical-wide validation,
physical multi-output/hotplug, long-run **whole-shell** resources,
session reload/suspend and maintainer visual/motion approval remain
independent outstanding gates.
