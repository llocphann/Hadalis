# Rework/optimization

Work after actionable [Issues/bugs](ISSUES.md), unless the maintainer changes
the immediate priority. [The canonical audit](../../docs/optimization/STRICT_LOSSLESS_GPU_RAM_CPU_AUDIT.md)
holds technical research; this file holds pending outcomes.

## Resource use and responsiveness

- [ ] **Abyss Panel motion stutter — received/updated 2026-10-10:**
  Owner reports visible judder/jank while Abyss panels/Popups appear, disappear
  and transfer across edges; supplemental video `2026-10-10_13.34.50.mp4`
  is in the request (31.93 s at ~30 fps capture), not a frame-time/CPU/GPU
  trace and not committed to this repo. This is a concrete responsiveness
  acceptance under existing Connected presentation / strict-lossless research,
  not a new render-quality tier or permission to lower visual fidelity.
  Priority after actionable hover/correctness Issues. Profile cold/warm
  open, close, reversing mid-animation, rapid multi-edge switching and
  simultaneous/pyramidal panels; record actual frame time distribution
  (p50/p95/p99/dropped frames), main-thread CPU, compositor/GPU and
  allocations on comparable exact-SHA owner output sessions. Candidate:
  `AbyssGeometry.popupShoulders` produces per-scanline native input Regions
  during animations; investigate lossless adjacent-strip compaction and
  Instantiator/Region churn without dropping painted pixels, reordering
  input-source ownership or altering shader/animation cadence. Require
  pixel-union oracle, native pointer dwell/focus/click-through checks,
  visual parity and measured before/after; keep open until owner confirms
  perceptibly smooth transitions. Candidate `6c10387d18aa1793d7ad2f2ef20eb37020d69abf`
  now coalesces contiguous same-span SDF mask strips at construction, preserving
  pixel union and reducing native Region/Instantiator objects. Across 576
  independent 4-edge/scale/softness/radius/progress cases, static mask instances
  fell from 22,752 to 10,080 (55.7% fewer **Region rectangles only**, not FPS,
  CPU, GPU or RAM). Geometry contract test additions `38437f56` and native
  hover fixture additions `5a2cb977` are committed; an offline V8 run of the
  geometry test body passed 504,005 assertions with stubs. Source has **not**
  passed Quickshell/native compositor, canonical exact-SHA or owner visual
  acceptance. Next: serial native hover/geometry test first (Issues), then
  collect comparable before/after frame pacing and cost on installed source;
  if still visibly jerky, profile allocator/animation/ShaderEffect/wave frame
  paths before proposing another lossless candidate. Do not conflate Region
  reduction with a confirmed user-visible jank fix.

  **Owner still reports jank after `6c10387`, 2026-10-10:** that Region
  compaction/physical-mask patch was reverted in `0d26291646bc9b4db6f0678c54b10f7a4b8c8962`
  as ineffective. The earlier 55.7% rectangle reduction is now **historical
  only, NOT a current resource saving**. Do not stack another workaround on
  it. New independent strict-math hot-path candidate
  `b50c3b8064317fd8feb1ccd20303315765b2f2c8` reuses the immutable
  workspace rectangle and single popup record in `popupShoulders`, avoiding
  per-pixel object allocation/record-array traversal while preserving exactly
  the same SDF operations. Direct before/after V8 tests compared full
  shoulder rectangle arrays in **720 edge/scale/softness/radius/progress cases:
  identical**. Isolated loops of 2,000 calls measured 824→621ms at softness 24
  and 1,694→1,303ms at softness 48 (single V8 environment; not a whole-shell
  FPS/CPU/GPU/memory result). Native Qt/Quickshell has NOT been tested.
  To identify actual jank instead of guessing, opt-in diagnostics
  `1633a6e1d909de0c93e8a33999cccab1b78dcac3` adds
  `abyssHoverProbe.startFrames()` / `stopFrames()`: per-output bounded
  600 QQuickWindow `frameSwapped` wall-clock interval samples with
  p50/p95/p99 and interval gaps. Disabled until explicitly called, no
  recurring profiler/timer; results can include idle gaps and are NOT
  compositor-present timestamps or hardware GPU counters. Next: collect
  installed exact-SHA source, a real captured output/frame interval sample
  during slow open/reverse/multi-edge transitions, and CPU/GPU compositor
  evidence where available. Diagnose spikes in mask rebuild, allocator
  movement, ShaderEffect/waves, or focus/remount from evidence first.
  **USER-EXPERIENCE ACCEPTANCE REMAINS OPEN.** Exact source at
  `0ded4c9b388b407506add4029a7eb8985dc426fe` passed a second
  **offline V8** run of the current repository Node geometry test body:
  518,945 assertions, same predicate/serialization checks, using emulated
  Node asserts/readFile; still NOT Qt/Quickshell or canonical. A single
  read-only collection helper
  [`scripts/collect-abyss-hover-frames.sh`](../../scripts/collect-abyss-hover-frames.sh)
  captures frame interval samples without IPC polling and then separate
  timestamped hover state samples (no native compositor mask refresh).
  After installing the new exact source, run it while reproducing motion
  and transfer, preserve the three receipts and source/installed SHA. Do
  not report whole-shell FPS gain from V8 microbench timings, and do not
  call the previous Region-count reduction current after its revert.
  **First owner measurement attempt 2026-10-10 07:18:55 UTC was BLOCKED**:
  uploaded `frame-start.txt` reports Quickshell could not find its
  `default` configuration. It contains no frame intervals or FPS; uploaded
  `identity.txt` pins only the dev checkout `ff56015cf` and
  `qs_config=auto`, not the installed shell. This was caused by the original
  collector omitting the config path, whereas the Hadalis launcher uses
  `qs -p "$config_dir" ipc call`. Fixed diagnostic collector in
  `4dc295e7f118a2445ca5ab4d6a66de2552312532` to select the live iNiR
  instance and report installed/source parity. Corrected collector still
  requires owner rerun. **Jank cause and performance acceptance UNKNOWN/OPEN**;
  no percent/fps gain inferred from the failed capture.

  **Owner's second capture (2026-10-10 07:49:30Z), Niri/eDP-1:**
  `startFrames` succeeded and `stopFrames` returned 363 intervals,
  but recorded min/p50/p95/p99/max/mean all approx
  **1,791,001,362,433–1,791,001,362,477 ms** and all
  363 intervals were flagged over16/33/100 ms. These timings
  are **INVALID**, not evidence of low FPS: the old diagnostic
  stored `Date.now()` (~1.791e12 epoch milliseconds) in a
  signed 32-bit QML `property int _frameProbePreviousMs`,
  truncating the prior timestamp before subtraction. Example
  `1791618576306 - 617213874 = 1791001362432`;
  the spurious interval magnitude is explained by that exact
  integer overflow. Since the capture time is known and the 6-second
  window cannot cross the next signed-modulo epoch boundary, the constant
  offset is exactly `417 * 4294967296 = 1791001362432 ms`; subtracting
  this from the stored summary statistics recovers **approximate Qt
  frameSwapped intervals**: min=1ms, p50=17ms, p95=18ms, p99=41ms,
  max=45ms, mean=16.573ms (363 intervals). This DOES show a slow
  upper tail in *Qt wall-clock frameSwapped events*, but cannot
  assign cause to SDF/mask/GPU/compositor, cannot reconstruct threshold
  counts from the summary, and cannot prove the user's specific
  lag reproduction overlapped these frames. Thus raw counters
  `over16ms/over33ms/idleGapsOver100ms=363` remain INVALID.
  Diagnostic-only commit
  `b8be0fcb551a319fbff0b6c2a65c062f955c5ead` changes
  that property to QML `real`, not shell rendering itself.
  User-visible Panel lag remains **OPEN/UNMEASURED**.
  Commit `15f5abbb1bc19bf5377636dbee03c7f973713330`
  makes the collector auto-package complete/partial receipts into
  **one `.tar.gz`**, preserving original IPC exit status.
  Exact committed collector blob
  `defb45271438a80cc012d611467ce6c9451f264a`
  passed real `bash -n` (exit 0) and a fake `qs -p` run:
  success with 40 snapshots and one archive (exit 0), plus an
  explicit `startFrames` failure (exit 1, partial archive).
  Those are script tests, not Niri/Qt acceptance. Next: ensure
  running shell loads the updated QML, animate in PHASE 1,
  and provide the single archive with true bounded samples.

  **Owner second one-file capture 2026-10-10 08:04:04Z:**
  `hadalis-abyss-hover-20261010-150404.tar.gz` has
  `run-result.txt exit 0` but raw `frame-start.txt`
  is `Target not found.`, the stop reply has count=0 and
  null min/p50/p95/p99/max. On the actual owner-installed
  configuration `~/.config/quickshell/inir`, the
  `AbyssPerimeter.qml` file was **DIFFERENT from checkout**
  SHA `5896b425951a774f6b209d68b50616297f455a3c`.
  The other sampled source files matched. Thus latest frame
  timing probe was **NOT actually started**; the previous
  collector falsely accepted `qs` exit code 0 on a missing
  handler. No new frame-pacing values, FPS or root-cause
  conclusions were obtained from this archive.
  `faf8ad59b9336ad6d2689b20ace52b28f22a6d45`
  now refuses mismatched installed QML and invalid IPC
  replies and still emits one uploadable archive. Exact
  Git blob `d4f52cef9342defc1fde61d1c4dfacdd67ff4f54`
  passed `bash -n` and five mocked CLI cases with
  expected status 5/6/2/0/4 and valid archives.
  Synchronize with `./setup update` from `dev`
  before `inir restart`, confirm on-disk parity and
  run the probe during actual panel animations.
  **Owner lag confirmation remains OPEN.**

  **2026-10-10 08:26:41Z additional owner archive:** the QML installation
  now matches checkout `3acf9685ce7aef5e1c7e879e2437a7001ac3f874`
  for all three sampled files, but the live Quickshell IPC call to
  `abyssHoverProbe.startFrames()` still prints `Target not found.`.
  The bounded collector correctly aborted with exit 5 and packaged
  `run-result.txt`, `frame-start.txt`, `diagnostic-error.txt`,
  `identity.txt`. NO frame/hover samples were taken. A matching
  installed file is not proof the active Perimeter instance is mounted.
  Source gating requires Abyss family critical host, deferred
  readiness, and enabled `abyssPerimeter` module; active-state
  cause cannot be determined without live IPC inventory and host status.
  The read-only collector expansion `5462432e442048be32bf7de8e1227b892ed86e93`
  now includes `qs ipc show` and `abyssHostProbe.status()`
  diagnostic outputs within the same ONE archive; it also refuses
  a zero-count frame summary. No QML lifecycle or render
  settings were changed. Jank root cause and acceptance remain OPEN.

- [ ] **Strict-lossless CPU/RAM/GPU reductions:** re-audit latest `dev` and
  promote high-value findings only after behavior, read/dependency order,
  identity/NOTIFY and lifecycle parity. Keep hidden services/lightweight warm
  surfaces fast to reopen, with heavy unused work asleep. Prefer strict lossless
  or one measured <1% trade for a large benefit; do not accumulate small trades.
  Measure comparable cold/warm/idle/active CPU, RSS, GPU/frames and latency;
  allocation or operation counts are not whole-shell resource percentages.

- [ ] **Audio Spectrum processing:** investigate the Round 49 profile-factor
  reuse candidate. Source count/profile/stereo/clamped strength are frame-invariant
  until configuration or shape changes. A candidate is prepared only in
  [the stop checkpoint's unpromoted candidate](../../docs/evidence/abyss-product/20261010-hover-checkpoint/unpromoted/bar-cava-candidate.qml)
  (copied from `/tmp/hadalis-bar-cava-candidate.qml`); product code is unchanged. Require actual
  QV4 exact sample/level parity, unchanged scratch/NOTIFY, strict render comparison
  and measured cost before implementing. Preserve upstream-like bounce, CAVA
  ownership, warm reopen and every animation/frame cadence.

- [ ] **Remaining optimization candidates:** read the current audit tail,
  distinguish CONFIRMED/HIGH CONFIDENCE from hypotheses and retire duplicates.
  Recent Notepad normalization, Overview record lookup and shared Search prefix
  findings still require their native reactivity/identity and measurement gates.
  Preserve filter-before-map observable reads in existing Abyss reductions.

- [ ] **Frozen visual qualification:** G0 `dc4d5ecfe118` remains
  `INCONCLUSIVE_CAPTURE_VARIANCE`. Analyze only saved receipt/PNG data offline;
  do not replay consumed lineage or lower strict RGBA. Do not change quality
  tiers on an unexplained translucent-pixel variance. Owner multi-output and
  whole-session resource acceptance remain separate.

## Existing UI and layout

- [ ] **Edit Dashboard toolbar slide — received/updated 2026-10-10:** pushed
  `8c673129b58dbde73bf31c82df25c1085bf63e15` slides full-size connected controls
  from the attachment using the shared motion token. Input follows the clipped
  reveal; exit retains its footprint and releases input immediately. Native
  16 Dashboard/Overview × edge × size cases, reversal, complete exit, reduced
  motion, stable canvas and Undo/Cancel/Done pass. Its focused check also passes
  in the exact `10311cd96` canonical run, whose overall result is FAIL 327/8/1.
  State: source/focused-qualified; owner appearance acceptance still pending.
  [Durable focused evidence](../../docs/evidence/abyss-product/20261010-hover-checkpoint/hadalis-dashboard-toolbar-slide-motion-20261010.log).

- [ ] **Abyss Waves:** verify round crest-only geometry, no trough erosion or
  needle peaks, restrained breaker/whitewater, continuous distance attenuation,
  stable same/opposite-direction interaction and idle sleep. Preserve one shared
  wave-strength control/migration, optional/default-off waves and reduced motion.
  Calm stays below Balanced (the former Calm); Fluid/Deep should be distinct and
  restrained. Detailed wave controls belong to Custom; show numeric audio strength.

- [ ] **Screen Edge/module editor:** verify separate 0px-capable widths on all
  four edges, thickness-only versus inherited module sizing, per-module overrides,
  joined nearby modules when width does not affect them, nearest-corner joins
  and adjustable module curvature. Editor owns sizing with one-module partial/
  whole-edge choice, guides/snapping and saved per-output drafts. Dragging should
  not reload heavy content or persist the full config on each pointer event.

- [ ] **Connected presentation:** finish owner appearance acceptance for Popup,
  Sidebar, Dock, Dashboard, Settings, OSK and IPC on every edge and scale. Keep
  anchored full-size reveal/retract, readable reflow and older-body slide-close
  when allocation cannot fit. Center Sidebars on physical left/right edges;
  preserve custom dimensions and hot corners. Dock content must not shrink/jitter.
  Remove redundant tooltips, stray borders and repeated row fills while retaining
  intended enclosing-panel opacity/blur and click ripples.

- [ ] **Settings refinement:** compact iOS-like parent/child navigation, Abyss
  before Waffle, no duplicate destinations/headings or generated More groups,
  one editor entry beside Lock, stable order/search/deep links and complete lazy
  pages. Keep meaningful slider units and avoid multiplying Dashboard opacity
  twice. Qualify System Monitor two-digit widths/RPM icons and OSK content-sized
  footprint. Waffle remains supported; historical ii/
  style values serve safe migration/content reuse, not a removed live theme.

- [ ] **Dashboard Music presentation:** qualify horizontal page slide and
  centered dots on the controls/uptime row; Genre/Folders tabs and multi-selection,
  folder drilldown and combined result column, shared Media/EQ DSP, bottom-anchored
  upward Queue expansion, Lyrics auto-hide and responsive remaining widths.
  Source/focused native tests already cover these behaviors; owner video/input
  acceptance is pending. Playback correctness is tracked only in Issues/bugs.

- [ ] **Recording presentation:** `fafb4687b` connects one shared control set
  to the Abyss field/allocator/input mask while retaining ii/Waffle presentation.
  Native tests pass four-edge controls, drag, connection hover, auto-hide/recovery,
  Stop callback and idle/secondary-output allocation. Confirm owner appearance
  and an actual recording/stop. No owner recording was started/stopped in fixtures.

- [ ] **Wallpaper picker polish and live theme preview:** qualify the connected
  thumbnail selector against the supplied reference, restrained search icon,
  borderless action buttons and Abyss-styled tooltips. Remove `>wallpaper`,
  `(grid)` and `(overflow)` labels from the retired picker. Preview Edge/Panel/
  Popup colors while browsing images, restore on cancel and retain the chosen
  palette on apply. Actual wallpaper application is tracked in Issues/bugs.
  References: `/tmp/codex-clipboard-c5723427-ceae-4515-a739-3010f8a551fa.png`,
  `/tmp/codex-clipboard-3baf8385-6e63-4e7b-8306-0e0ec31f3be9.png`.

## Documentation maintenance

- [x] **Categorized tasks and shared AI workflow — completed 2026-10-10:**
  three active lists replace chronological/duplicate ledgers; 26 superseded
  documents are archived with evidence/current research preserved. AGENTS and
  all current entry points apply the same policy to Local and Cloud AI: classify
  on receipt, merge/split outcomes, select by category then impact/actionability,
  record dependencies and continue independent authorized work. Completion and
  seven-day archiving preserve unverified gates and concurrent status edits.
  Documentation contracts, Material-only docs, shared workflow links and diff
  checks pass. This is documentation validation, not runtime/desktop acceptance.
  Retain this recent completion until 2026-10-17, then move it to the dated
  chatbot archive.
