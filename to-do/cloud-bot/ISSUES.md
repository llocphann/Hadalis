# Issues/bugs — fix first

Consolidated on 2026-10-10 from the [former task ledgers](../../docs/archive/chatbot/2026-10-10/README.md).
Open items include remaining acceptance of source fixes; they do not all mean
that implementation is missing. Refetch current `dev` before diagnosing.

## Current failures and owner reports

- [ ] **Popup/Edgebar closes while hovered — received 2026-10-10:** popups and
  Edgebars must stay open while the pointer is inside their actual body or the
  drawn connection to the Screen Edge. Source repaired after Dashboard slide
  `8c673129b`. Private pointer tests reproduced dismissal on painted padding and
  interactive MouseArea children. Source now uses the unjoined painted footprint
  for body/bridge input, makes that hover plane an ancestor of contents, and
  coalesces Bar hold publication after the binding turn to prevent re-entry.
  Native tests pass all four edges with sustained generic/mature body, padding
  and bridge hover, interactive children, auto-hide Bar hold/release, final leave,
  reopen, click-only actions and editor focus. Clock/Weather handoff (1,147
  samples), connected Recording and cold remount tests also pass. State: waiting
  for canonical exact-SHA validation and owner normal desktop acceptance.
  Logs: `/tmp/hadalis-popup-hover-padding-red-20261010.log`,
  `/tmp/hadalis-popup-hover-child-red-20261010.log`,
  `/tmp/hadalis-popup-hover-padding-green-20261010.log`.
  This new report reopens the relevant hover acceptance below.

- [ ] **Canonical validation:** the clean-clone strict-QML run at exact SHA
  `8b2ed6f0a1fccddade206f0060ed19d19337a5da` finished **FAIL: 334 PASS, 1 FAIL,
  1 SKIP** on 2026-10-10. `test-shell-surface-contracts.py` expects Settings at
  Top during Polkit, while the new authentication behavior yields at Bottom.
  Focused repair on 2026-10-10 exercises the production Rail host and exact
  Focus bindings in private native layer-shell windows: 65 forward/reverse
  states pass across dialog/external/shell authorization, region selection and
  Settings open state. The stale Top expectation now matches Bottom; runtime
  behavior is unchanged. State: waiting for canonical validation of the repaired
  exact SHA. Native properties do not prove owner Polkit visibility/focus.
  Logs: `/tmp/hadalis-settings-auth-bindings-20261010.log` and
  `/tmp/hadalis-canonical-8b2ed6f0a-20261010.log`. A prior SHA's PASS cannot close
  this runtime gate.

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
