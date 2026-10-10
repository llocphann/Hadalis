# Issues/bugs — fix first

Consolidated on 2026-10-10 from the [former task ledgers](../../docs/archive/chatbot/2026-10-10/README.md).
Open items include remaining acceptance of source fixes; they do not all mean
that implementation is missing. Refetch current `dev` before diagnosing.

## Current failures and owner reports

- [ ] **Popup/Edgebar closes while hovered — received/updated 2026-10-10:**
  NEW OWNER REPRO 2026-10-10: moving the pointer across the gap/connection
  between a Popup and its Screen Edge still loses hover/focus and automatically
  dismisses the Popup. Owner supplied `2026-10-10_13.34.50.mp4` (31.93 s,
  1920x1200, ~30 fps) in the conversation, showing multiple edge-attached
  panels; the clip is not independently frame-timing evidence or an attached
  repo fixture. Do not count the previous probe correction as a product fix.
  Preserve native/Qt pointer focus and hover separately from keyboard focus;
  require deliberate pointer transfer (physical frame → connector → body),
  sustained dwell, fast reversal, all four edges, generic and StyledPopup,
  Bar auto-hide leases and click-through to blank workspace.
  body and painted Screen Edge connections must retain hover. Pushed source
  `10311cd96892d86d86870d327d28b27e32df8fbd` repairs padding/interactive-child
  hover and coalesces Bar hold publication; its focused four-edge checks passed.
  A further composite-mask candidate for SDF shoulders, physical Edge bridges,
  source-module pointer priority and Recording input is saved **WIP / HOLD** in
  this stop checkpoint. Final shoulder geometry, Clock/Weather (1,156 samples),
  cold mount and Recording fixtures pass; final generic/mature hover fixture
  **FAILS** at left bridge x=14,y=200. That point overlaps the source anchor;
  inspect actual requested/anchor/body leases before deciding whether this is a
  probe error or runtime dismissal. Cloud continuation on 2026-10-10 committed
  test-only qualification change `c499fb3ecdb07250c710bac82f483272c42e46c2`:
  `scripts/test-popup-anchor-hover-runtime.py` now searches SDF-painted
  bridge pixels outside both source input regions and content, asserts the
  resulting point belongs to the native/hover footprint, and preserves all
  four edges, Bar leases and 900ms dwell. This removes one ambiguous oracle;
  **runtime NOT RUN, result UNKNOWN**, and no source runtime fix or product
  acceptance is claimed. Next: execute the corrected fixture on this exact
  commit with a stable private output, inspect requested/anchor/body leases
  if it fails, then run geometry/Weather/cold/Recording checks sequentially.
  Resolve failures before exact-SHA canonical clean-clone validation. Do not
  weaken all-edge dwell/input tests. Owner cold/normal hover, connected input,
  click-through and multi-output acceptance remain separate.
  Serial local validation order (preserve full logs, actual exit codes and exact
  source SHA): `python3 scripts/test-abyss-geometry-contract.py`,
  `python3 scripts/test-popup-anchor-hover-runtime.py`,
  `python3 scripts/test-popup-cold-start-lifecycle-runtime.py`,
  `python3 scripts/test-weather-popup-handoff-runtime.py`, then
  `python3 scripts/test-recording-abyss-runtime.py`. Stop on a real failure
  and diagnose rather than interpreting older PASS logs as new results.
  Once focused failures are resolved, execute
  `bash scripts/validate-maintainer-local.sh` on a clean exact-SHA checkout;
  then request independent owner desktop/multi-output acceptance.
  [Durable receipt and logs](../../docs/evidence/abyss-product/20261010-hover-checkpoint/README.md).
  The earlier maintainer stop/save/push was honored at the checkpoint.
  **NEW source candidate 2026-10-10:** `6c10387d18aa1793d7ad2f2ef20eb37020d69abf`
  extends only the popup's tangent-bounded painted input to the physical
  Screen Edge (previously stopped at its inner seam); no output-wide mask.
  It also coalesces exactly adjacent equal-span SDF strips to reduce live
  Region/Instantiator churn while retaining every covered input pixel.
  Contract additions: `38437f56` (physical seam/strict SDF occupancy) and
  `5a2cb977` (four-edge physical rim → connector → content and reverse,
  sustained 900ms, generic/StyledPopup, Bar lease, click-through, focus).
  Offline V8 execution of the repository geometry test body passed
  **504,005 assertions**, source/test blob SHAs `3d6953ae`/`372ff060`,
  with equivalent assertion and readFile stubs; 576 independent strip-union
  comparisons showed identical occupied pixels. **This is not a Qt/Quickshell
  run; runtime, exact-SHA canonical and owner session are NOT VALIDATED.**
  Next: perform the serial native commands above at fresh HEAD, preserve
  focus/lease/Region evidence on any failure, compare owner hover behavior,
  then canonical and physical multi-output acceptance. Keep issue OPEN.

- [ ] **Canonical validation — updated 2026-10-10:** exact committed SHA
  `10311cd96892d86d86870d327d28b27e32df8fbd` finished **FAIL: 327 PASS, 8 FAIL,
  1 SKIP**. Failures: keyboard sizing, Dashboard Music, Dashboard warm readiness,
  Equalizer presentation, Weather handoff, Abyss editor, OSD and shared content.
  [Full logs and failure details](../../docs/evidence/abyss-product/20261010-hover-checkpoint/README.md)
  are preserved. The warm fixture had a 757x852 canvas; a larger private-Niri
  output probe is recorded, but not all failures are proven environment-only.
  No retry was run after the explicit stop. The checkpoint's WIP source was
  not part of this clean-clone run and has no canonical result. Next: resolve
  affected focused failures, then validate the exact new committed SHA.
  Earlier `8b2ed6f0a` FAIL 334/1/1 remains historical; `a349d1a0c` corrected its
  stale Settings Top expectation to Bottom with 65 native forward/reverse states.
  Current canonical passes that contract; owner Polkit/focus acceptance is open.
  A previous or focused PASS never closes the overall gate.

- [ ] **New boot/runtime warnings:** owner's log runs `0ea54cc09` and reaches
  the first frame; no startup Type-unavailable failure is shown. Investigate
  `qt.svg` unresolved paint server `a`, oversized SVG buffer, DelegateModel cancel
  `18 0`, repeated Wayland text-input disable and portal app-ID registration.
  Do not hide log categories as a fix. A bounded Qt audit reproduces missing
  paint references in WhiteSur's Obsidian icon and oversized filters in some
  WhiteSur icons even at 128px; exact attribution of the owner's `<input>:1:5634`
  and buffer messages remains open. Trace the model reset and popup/text-field
  focus lifecycle independently; preserve the redacted Weather location.

- [ ] **Weather popup overlap:** reproduce the video at
  `/home/llocphann/Videos/2026-10-10_00.19.58.mp4`, especially rapid Clock/other
  module → Weather transfer. The actual four-edge fixture passed 1,148 geometry
  samples at `0ea54cc09`; it did not change Weather production code or prove
  owner visual acceptance. Verify first hover, repeated reversal, Orbit/Details
  clipping, exit and reopen with the actual installed source identity.

- [ ] **Orbital Weather light-mode text:** hourly times/labels must use readable
  theme foreground colors. Qualify light and dark mode with the owner's image
  `/tmp/codex-clipboard-f953ac4b-1666-4bb5-8c16-b22920b1ee93.png`; remove the
  redundant hover tooltip instead of repeating the wheel's information.

- [ ] **Hover popups sometimes require clicks or stay open:** qualify cold
  boot and ordinary hover independently of Edit Layout and Waffle → Abyss
  remount. Verify every affected module, source-to-body transfer, reentry and
  final leave. Connected bridge input is repaired at `be8902259`; cold hover and
  delayed anchor callbacks have focused evidence in the archived ledger.
  Preserve click-only actions, keyboard focus and empty-space click-through.

- [ ] **Wi-Fi/Bluetooth popup text missing:** the loading blocker is fixed at
  `134b0115a`, and visible-title fixtures pass through `2d31f06b9`. Confirm actual
  owner populated/empty/loading/disabled states and actions. System Tray owns
  these icons; do not reintroduce standalone Wi-Fi/Bluetooth edge modules.

- [ ] **Music fails to play:** source `8b2ed6f0a` fixes queue/transport ordering,
  repeated payload stalls and failed-write retry. Real QML passes Python/Rust
  protocol fixtures; private real MPD plays synthetic WAV/FLAC and recovers from
  decoder failure using a null output. Confirm audible owner PipeWire playback,
  Stop → long idle → Play, queue/delete, Shuffle/Repeat and actual problematic
  FLAC files. Do not alter owner music bytes, queue or output routing as a test.

- [ ] **Volume +/- and DSP crackle:** qualify the existing relative-volume
  queue against actual default/output routing and repeated keypresses. Verify
  selecting non-flat EQ then opening any popup/Sidebar/Dashboard does not resend
  the preset, restart the analyzer or cause crackle. CAVA warm/lifecycle fixtures
  are bounded evidence; actual EasyEffects/player-switch audio remains open.

- [ ] **Edit Widgets / Dashboard Layout offset:** verify the connected toolbar
  stays outside the workspace with real widget dimensions. Exercise desktop
  and Dashboard/Overview editors, all/hidden widgets, occupied moves/resizes,
  packed restores, small viewport, Add, Cancel/Undo/Reset and save/reopen.
  Keep a finite workspace, readable minimums and unaffected neighboring cards.
  Owner reference: `/tmp/codex-clipboard-e908c001-f054-442e-a2bf-73cd2e70cd64.png`.

- [ ] **Modules cannot reach corners / IPC editing joins:** verify corner
  placement and edge clearance with modules, IPC previews and nearby surfaces.
  Keep the preview open despite normal OSD timeout; check Cancel/Done and
  per-output persistence. Source fixes do not replace physical input acceptance.

- [ ] **Clipboard and pinned Notes/Timers:** confirm copied images render
  correctly after refresh/reopen; Clipboard History must not toggle or flicker
  Dashboard whether it was initially open or closed. Verify Notes/Timers pin,
  add/remove and editor ownership across outputs. Native image/pin fixtures
  pass; owner's interactive acceptance remains distinct.

- [ ] **Wallpaper does not change on normal desktop:** source has repaired
  wallpaper ownership and live color preview. Confirm actual desktop application
  and Overview separately, rapid selection/cancel, output targeting, still/video
  image readiness and transition priming. A palette change alone is not proof
  that the selected wallpaper was applied.

- [ ] **Cheatsheet close opens Update popup:** qualify the repaired independent
  close/visibility ownership through first and repeated slide-out. No unrelated
  Update popup should appear or dismiss over it.

- [ ] **Notification timeout and retained history:** verify expiry, hover pause,
  resume and history refresh without resetting an existing timeout or pin.
  Preserve freely positioned notifications; retire obsolete Anchor controls.
  Niri reload success was subsequently retired and must remain silent; failures
  stay actionable. Verify Notification/Activity dimensions and existing Notes/
  To-do/Timers/Activities routes without duplicating their backends.

- [ ] **Hadalird helper/package state and Polkit focus:** extraction is
  source/package-qualified; owner reported helper status ready. Verify compact
  Settings status, restart/refresh, explicit install/reinstall/update/rollback/
  remove and retained data. Verify Polkit above embedded/native/Waffle Settings,
  success/cancel/focus restore and double authorization on a first install.
  Missing receipt must reconcile state, not retry a possibly successful install.
  No implicit privileged install or TLP/Thinkfan/charge-policy change.

## Correctness and release acceptance

- [ ] **Lifecycle/input on the installed candidate:** boot without unavailable
  types/duplicate IDs; cold/warm open, fullscreen enter/exit, lock/unlock,
  suspend/resume, output removal/hotplug and fractional/transformed outputs.
  Keep Overlay input limited to real interactive bodies; no transparent blocker
  or late callback invoking destroyed objects. Native debug Niri stays unfocused
  except for required image evidence and must have dark first-frame backgrounds.
  Verify normal tray/app hover menus, nested menus and newer-menu focus ownership,
  desktop context-menu close/reopen, Quick Notes editor leases, configured hot
  corners and Overview priority. Keep Calendar/Weather responsive at small scales.

- [ ] **Feature/package identity and failure behavior:** exact installed/source
  SHA, relocatable install/update/uninstall, required runtime dependencies and
  optional absence/error recovery. Exercise missing/offline/incompatible optional
  packages, actual selected TLP/Thinkfan/Obsidian behavior after user enablement,
  and Waffle separately. Nix-specific validation remains deferred/non-blocking.

No older canonical FAIL, STOPPED run, missing receipt or consumed G0 result is
upgraded to PASS by this consolidation. Their original boundaries are archived.
