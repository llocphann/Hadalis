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

  **OWNER REGRESSION RECONFIRMED 2026-10-10 (current continuation):** after
  `6c10387` and its tests, Popup still loses hover/auto-closes while crossing
  the connector, and Abyss Panel still lags. Therefore that runtime fix is
  **INEFFECTIVE / NOT ACCEPTED**, irrespective of offline 504,005 assertions;
  those assertions only proved geometry, not compositor pointer delivery.
  Dedicated non-force revert `0d26291646bc9b4db6f0678c54b10f7a4b8c8962`
  restored `AbyssGeometry.js`, the geometry test and hover runtime fixture
  to `e6d220e` source without rewriting prior history. DO NOT reinstate the
  physical outer-edge hitbox extension or Region coalescing unchanged.
  A distinct read-only diagnosis `9c6366ee5d3557a98940637dad80b667b71bc4f0`
  expands existing `abyssHoverProbe.snapshot()` with each mature popup's
  requested/semantic/linger state, source-vs-body hover, input mask registration,
  strip count and geometry; generic popup state is also captured. No automatic
  remap, global hover padding, timer delay or input interception was added.
  `abyssHoverProbe.refreshMask/swapMask/remapWindow` remain explicit bounded
  diagnostic experiments; **do not apply them automatically**. Compare
  snapshots with the installed exact source SHA during a genuine failed
  crossing: distinguish compositor mask not delivering events, source hover
  priority, and semantic timer expiry before changing input routing. Neither
  old focused PASS nor an IPC snapshot alone is physical mouse acceptance.
  Serial native fixture and canonical results on current SHA are NOT RUN;
  preserve source/device and before/after receipts.

  **Diagnostic failure received 2026-10-10, 07:18:55 UTC:** owner uploaded
  `identity.txt` and `frame-start.txt` from collector first run. Checkout
  `dev` was `ff56015cf43b16580f0373881e8471984d9633bc`;
  `qs=/usr/bin/qs`, original `qs_config=auto`. Error:
  `Could not find "default" config directory or shell.qml in any valid config path.`
  This is the diagnostic **NOT STARTED**: neither frame intervals nor pointer
  lease samples were collected; it proves neither a product bug cause nor a
  product fix. Existing `scripts/inir` explicitly targets a running config
  through `qs -p "$config_dir" ipc call`; old collector lacked `-p`.
  Corrected collector `4dc295e7f118a2445ca5ab4d6a66de2552312532`
  selects an active iNiR instance, or an explicitly provided path, and records
  installed-QML-vs-checkout match flags without starting/restarting shell.
  The corrected collector has NOT been run on the owner's desktop. Repeat
  after pulling latest `dev`; if methods are absent inspect the installed
  vs checkout flags, never treat a matching Git checkout SHA alone as proof
  that the running shell has been updated. Preserve actual command failure
  receipts and resume native hover/canonical acceptance only with live evidence.

  **2026-10-10 collector Bash syntax regression and resolution:** the next
  owner run failed at line 32 (`syntax error near unexpected token '|'`)
  because the text-mode `qs list --all` process substitution placed a pipe
  on the following line without ending the previous line with a pipe.
  A first attempted in-place fix `10a6604` was ALSO invalid: JavaScript
  replacement expanded the `$'` sequence inside `'/shell\\.qml$'` and
  duplicated the script tail. DO NOT use that commit. Final fix
  `9ba0204b4e2254393c8518526e9ddf6496b6769d` restored the exact
  840c00d source and replaced the bad pipeline without JS substitution
  expansion. Final Git blob `12dd8dd22d521f5be9312d17580c97ef7e46f780`
  was reproduced byte-for-byte in a local test environment:
  `bash -n` **exit 0** and a mocked active `qs -p` IPC sequence completed
  `startFrames`, `stopFrames`, exactly 40 `snapshot` calls, **exit 0**.
  These checks validate collector syntax and control flow only; they are
  NOT a Quickshell/Niri live test and do not close the popup/lag issues.
  Next: owner reruns after `git pull --ff-only` and supplies new receipts.

  For a read-only owner
  capture after installing the exact `dev` source, run
  `bash scripts/collect-abyss-hover-frames.sh`: 6 seconds of bounded
  frame-swapped intervals, followed by 40 at-most-150ms-apart requested
  IPC hover snapshots, each with a timestamp and actual errors preserved.
  Reproduce opening/reversal during the first phase, the source→bridge→body
  hover loss during the second. Owner now supplies **one**
  `hadalis-abyss-hover-*.tar.gz` archive rather than three separate files.
  Archive contains the original `identity.txt`, `frame-start.txt`,
  `frame-intervals.txt`, `hover-snapshots.log` and `run-result.txt`
  (on early failure, only the evidence files already produced).
  `15f5abbb1bc19bf5377636dbee03c7f973713330` adds a bounded
  exit-handler archive on both success and nonzero IPC exits; final Git
  blob `defb45271438a80cc012d611467ce6c9451f264a` passed actual
  `bash -n` exit 0 and fake `qs -p` full 40-snapshot test (exit 0)
  plus simulated failing `startFrames` (exit 1 and valid partial archive).
  This is script/mock validation, NOT production hover acceptance.

  **Real owner capture 2026-10-10 at 07:49:30Z**, checkout
  `8fd0db31006096f738dd8a4b527a009e10649558`, on Niri
  single eDP-1 output: Quickshell config resolved to
  `/home/llocphann/.config/quickshell/inir`, installed shell,
  AbyssPerimeter and AbyssGeometry file comparisons all MATCH, 40/40
  snapshot IPC calls succeeded. However **all 40 snapshots are idle**:
  `liquidPopupsOpen=false`, generic popup resident=false,
  0 mature popup slots active, Bar hover/hold=false and no module
  hovered. Therefore this trace does NOT capture a crossing or show
  why hover is lost. To reproduce next time: when script prints
  `PHASE 2/2`, OPEN the target Popup and cross its visible connector
  during the ~7 seconds. If still all idle, investigate event/mask
  delivery separately; do not assert a closed popup is an observed
  dismissal. A checkout Git SHA alone does not verify loaded shell
  identity. The helper never remaps/refreshes the mask or changes
  configuration. **Popup hover acceptance remains OPEN.**

  **Owner archive 2026-10-10 08:04:04Z (local 15:04):**
  `hadalis-abyss-hover-20261010-150404.tar.gz` contains
  `collector_exit_status=0`, but `frame-start.txt` is actually
  `Target not found.`; `frame-intervals.txt` has `count=0`
  and all quantiles null. Checkout `dev` at
  `5896b425951a774f6b209d68b50616297f455a3c`;
  Quickshell runtime location:
  `/home/llocphann/.config/quickshell/inir`.
  The installed `shell.qml` and `AbyssGeometry.js` MATCH
  checkout, but **`AbyssPerimeter.qml` is DIFFERENT**. A
  restart without a setup sync did not put the newest QML in
  the live installed runtime. The 40 snapshot IPC responses
  were successful but all had no active Popup or module hover
  (`liquidPopupsOpen=false`, empty popup slots); not a captured
  source→connector crossing. The old collector trusted an exit
  code 0 from missing target, a false positive diagnostic result.

  **Diagnostic guard fix `faf8ad59b9336ad6d2689b20ace52b28f22a6d45`:**
  fail closed if installed `shell.qml`, `AbyssPerimeter.qml`
  or `AbyssGeometry.js` differ from checkout (exit 4);
  require actual `"started":true` IPC response even if
  `qs` exits 0 with `Target not found.` (exit 5);
  require frame-summary signature (exit 6); reject invalid
  Abyss snapshots (exit 2). Preserve original exit code and
  raw receipts in one automatic `.tar.gz`, including failures.
  **Exact committed script Git blob
  `d4f52cef9342defc1fde61d1c4dfacdd67ff4f54`** was
  byte-matched by local `git hash-object`, and passed real
  `bash -n` exit 0 and five deterministic fake-IPC cases:
  missing handler 5, malformed stop 6, malformed snapshot 2,
  valid 40 snapshots 0, stale installed QML 4. Each generated
  one valid evidence archive. No new real Niri hover test on
  this corrected SHA. From checkout run the repository-supported
  `./setup update --local`, then `inir restart`, then collector
  (supported local-sync mode skips git pull and preserves dev tracking;
  full setup still performs its managed backup/sync/validation tasks).
  This safer local-sync hint was added to the collector in
  `5f7493ace0c4c3eee0f1f7e1bd7c75103a138b9a`;
  new exact blob `b19868ae8983bced8475b5133d44fddb89f0bbad`
  has `bash -n` exit 0 and differs from the five-case tested
  script only in this human-readable remediation text.
  Do not mutate installed runtime automatically from collector.
  Keep **Popup hover user acceptance OPEN**.

  **Owner archive 2026-10-10 08:26:41Z — now source MATCH, target MISSING:**
  The single `hadalis-abyss-hover-20261010-152641.tar.gz` contains
  `run-result.txt: collector_exit_status=5`,
  `frame-start.txt: Target not found.`,
  `diagnostic-error.txt` correctly refuses a successful frame probe.
  Checkout: `dev` at `3acf9685ce7aef5e1c7e879e2437a7001ac3f874`,
  running resolver: `/home/llocphann/.config/quickshell/inir`.
  Unlike the previous run, ALL THREE installed-vs-checkout source
  comparisons `shell.qml`, `AbyssPerimeter.qml` and `AbyssGeometry.js`
  now **MATCH**. This means the installed files match the checkout,
  but it does NOT establish that the active QML tree has constructed
  `AbyssPerimeter.qml` or that its IPC handler is registered.
  There are NO frame intervals and NO hover samples in this bundle;
  do NOT infer a popup dismiss cause from these absences.

  Source review on `dev`:
  `shell.qml` activates `ShellAbyssCriticalPanels.qml` only under
  `activePanelFamily=abyss` and familyMountReady; within that critical
  host the `AbyssPerimeter.qml` LazyLoader additionally requires
  `Config.ready`, deferred readiness, `enabledPanels` containing
  `abyssPerimeter`, and no diagnostic unmount. The handler
  `abyssHoverProbe` lives INSIDE that optional Perimeter. Therefore
  candidate explanations for `Target not found.` include the
  relevant family/host/Perimeter not being mounted, or a stale/failed
  live engine instance. None are yet proven by the archive.
  Distinguish them using registry and critical-host state before
  changing lifecycle or hit regions. Quickshell documents the
  read-only `qs ipc show` target/function enumeration.

  **Collector evidence expansion
  `5462432e442048be32bf7de8e1227b892ed86e93`:**
  capture `ipc-targets.txt` from `qs -p CONFIG ipc show`,
  `abyss-host-status.txt` from existing read-only
  `abyssHostProbe status`, `hover-preflight.txt` from
  `abyssHoverProbe snapshot`, plus per-probe process statuses,
  in the SAME one-file archive before `startFrames`. Keep
  fail-closed `startFrames` recognition and now reject a
  `stopFrames` result with count=0 as non-evidence (exit 6).
  Script does NOT remount or reconfigure the desktop.
  This candidate's native run is PENDING; status remains OPEN.

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
