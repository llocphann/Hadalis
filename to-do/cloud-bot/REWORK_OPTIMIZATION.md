# Rework/optimization

Work after actionable [Issues/bugs](ISSUES.md), unless the maintainer changes
the immediate priority. [The canonical audit](../../docs/optimization/STRICT_LOSSLESS_GPU_RAM_CPU_AUDIT.md)
holds technical research; this file holds pending outcomes.

## Resource use and responsiveness

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
