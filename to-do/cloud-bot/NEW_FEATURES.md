# New features

Work after [Issues/bugs](ISSUES.md) and [Rework/optimization](REWORK_OPTIMIZATION.md).
Source-implemented features below still need their stated delivery/owner gates;
do not reimplement them solely because a checkbox is open.


- [ ] **Alis Quickshell deep performance profiler — owner request 2026-10-11:**
  Add an opt-in, bounded debug suite to trace actual Alis resource costs:
  CPU, GPU, RAM/PSS/RSS, frame pacing and QML/JavaScript/render hotspots,
  with per-module/per-popup attribution ONLY where instrumentation or
  controlled evidence permits. Existing inir doctor --perf, ResourceUsage,
  MemoryPressureService and Abyss frame/hover collector are starting points,
  not full component attribution. Distinguish **direct measurement**,
  **instrumented span**, **controlled A/B estimate**, **correlation** and
  **unavailable**; never invent exact GPU %, VRAM, RAM or CPU numbers for
  individual QML objects from a process-wide or system-wide counter.
  **Work packages, all OPEN:**
  - [ ] **P1 — Architecture and observability map:** inventory shell.qml,
    Quickshell windows and services, Qt GUI/render/audio threads, native
    helper PIDs and Niri compositor, then map Abyss/Waffle, Screen Edges,
    Panel, Popup, Dashboard, Wallpaper, Media/EQ, Weather, Notifications,
    Recording, AI and shared QML loaders. Document attribution limitations
    per resource, GPU vendor, compositor and permission level.
  - [ ] **P2 — User-initiated trace command:** expose alis debug perf
    start/status/stop/report (or equivalent under alis doctor --perf).
    Support fixed-duration sessions, cancel, caps on sample rate/memory/
    output size, machine-readable exit errors, exact source SHA and
    running qs -p config identity. Remain compatible with inir during
    brand migration. Reject stale installs, wrong instance, absent IPC
    handlers, missing receipts and empty traces instead of false success.
  - [ ] **P3 — CPU and thread scheduler timeline:** collect timestamped
    /proc and cgroup CPU times for Quickshell PID, main/render/media
    threads, child Rust/Python helpers and Niri independently. Normalize
    multicore percentages, sampler interval, PID restarts and power
    profile. Optional perf/flamegraph capture only with explicit
    authorization and hardware/kernel support, never implicit root.
  - [ ] **P4 — Memory and object lifetime:** track RSS/PSS/USS if available,
    JavaScript/GC and JSGCHeap/memfd accumulation, Loader/Window lifetime,
    image/video/texture caches and alloc/free deltas across repeat
    open/close cycles. Mark shared caches and unattributable process
    memory rather than assigning it arbitrarily to a single module.
  - [ ] **P5 — GPU and VRAM capabilities:** inspect rendering backend/
    Qt Quick RHI, driver/renderer and safe DRM fdinfo or available
    vendor engine/memory counters (NVIDIA/AMD/Intel). Separate shell,
    compositor and global GPU usage. Capture QSG/render-phase timing where
    possible. Report unsupported counters as unknown, not zero;
    global GPU busy percentage CANNOT prove one Popup's GPU cost.
  - [ ] **P6 — QML/JS lifecycle probes:** opt-in instrumented spans for
    expensive function handlers, models/bindings where feasible,
    Loader incubation, object create/destroy, timer wakeups, shaders,
    images/video decode, popup geometry and connection/hover transitions.
    Key events to module, window and output, with duration and scope;
    idle logging overhead should be nearly zero when disabled.
  - [ ] **P7 — Frame-time and input correlation:** measure per-window
    QQuickWindow frameSwapped intervals and, where available, Qt GUI/
    render phases, alongside hover/click/Popup/Recording/animation
    events. Compute p50/p95/p99/max, count and long-frame episodes.
    FrameSwapped wall-clock callbacks are NOT compositor presentation
    timestamps. Do not poll IPC while measuring the same short frame.
  - [ ] **P8 — Component cost ranking with uncertainty:** correlate
    measured thread CPU, event spans, optional stack samples and
    deliberately isolated on/off A/B traces. Report confidence, units
    and method per component, and top offenders by verified duration,
    allocation changes or associated frame spikes. Preserve GPU shared
    passes, caching and inclusive/exclusive span limitations. Use
    unavailable when reliable module attribution cannot be made.
  - [ ] **P9 — Reproducible workload scenarios:** baseline cold boot and
    stable idle, then Panel/Screen Edge hover, multi-popup Pyramid
    transitions, Notifications, Recording start/stop, Calendar/Weather,
    Dashboard/Music/EQ, wallpaper/video, fullscreen, multi-output,
    fractional scaling and low-power state. Record exact source SHA,
    system/Qt/Quickshell/Niri version, GPU driver, monitor and
    profile settings and capture overhead. Compare matched baselines.
  - [ ] **P10 — Reports and optional debug UI:** export compact JSON,
    optionally CSV/HTML, chronological hot spans, CPU thread timeline,
    RAM growth, GPU support level, stutter episodes and before/after
    comparisons. An optional developer view may follow only once
    collectors are correct; no always-on debug animation or timer.
  - [ ] **P11 — Privacy/security and safety budget:** disabled by default;
    no upload, unsolicited persistent logging or sudo. Redact
    notifications, credentials, window titles, note text, clipboard,
    file paths, network names and access tokens. Bound runtime/buffers/
    disk size; recover cleanly from cancel/crash/restart and quantify
    profiler perturbation. Never modify user content, graphics quality
    or physical input to gather metrics.
  - [ ] **P12 — Correctness and native validation:** test counter
    wraparound, timebase, nested spans, PID changes, absent GPU sensors,
    permission failures, missing/mismatched IPC, output switches and
    privacy redaction. Verify native Quickshell/Qt/Niri timings and
    on/off overhead on the same deployed SHA. A fixture pass cannot
    prove true per-module GPU costs or on-screen frame smoothness.
  - [ ] **P13 — Link performance research and existing bugs:** define
    trace schema and limitations, attach measured results to the
    canonical strict-lossless GPU/RAM/CPU audit and existing Abyss
    stutter/Notification/Recording investigations. Do not duplicate
    their bug tasks, replay consumed receipts or claim improvements
    without matched before/after evidence.

  **State:** NEW/READY for design and source audit, NOT IMPLEMENTED.
  Alis CLI/identity dependency is tracked in Rework/optimization.
  No revived Automation/MegaQML service is required.

- [ ] **Edit Abyss Layout Screen Edge module multi-selection — owner request 2026-10-10:**
  Add an explicit multiple-selection mode for Screen Edge modules while
  **Edit Abyss Layout** is active. Show which modules are selected, support
  add/remove/clear selection and coherent subsequent edits when several targets
  are selected. Keep normal non-edit behavior intact; define guarded batch
  actions instead of silently changing unrelated modules. Test horizontal and
  vertical edges, cross-edge/per-output selection, drag/snapping and Cancel/
  Undo/Done/save semantics; coordinate with compact toolbar redesign in
  [Rework](REWORK_OPTIMIZATION.md). State: NEW, design/implementation and owner
  input acceptance pending.

- [ ] **Quick Notes image delivery:** Hadalis `add29d6f8` implements shared
  paste/import, original-byte storage, Markdown persistence and preview with
  stable asynchronous note ownership. Hadalird `b0c975a7f40bdf531012be326bc728f5c014b696`
  (0.2.1) exports referenced images to the selected Obsidian vault's configured
  attachment location. Core/optional synthetic filesystem and real QML tests
  pass, including delayed tab switching, selection, restart and collisions.
  Confirm installed versions and explicit owner paste/export with source/drafts
  retained. No fixture writes to a personal vault or reads personal clipboard.

- [ ] **Utilities feature delivery:** source already provides Monitor
  Arrangement, Display Mode, Sound Output and Night Light/Anti Flashbang pages
  with bottom-centered dots/swipe and existing display/audio backends. Verify
  actual Extend/Primary/Second-only/Mirror, hotplug/failure rollback, `wl-mirror`
  lifetime, PipeWire default sink and Night Light/Anti Flashbang sensitivity.
  Do not claim real Mirror from a synthetic fixture or introduce a second backend.

- [ ] **Non-Arch optional system gateway:** add trusted distro-owned
  provisioning beyond Arch for Hadalird helpers. Keep root gateway/policy separate
  from user-owned optional payloads and require explicit native authorization.
  Prove package ownership, removal and failure behavior per supported distro;
  never use a user-checkout installer as root or claim untested distro support.

- [ ] **Power-profile render quality delivery:** qualify Abyss automatic quality
  following and manual mode through live profile changes without reload or lost
  preferences. Hadanion owns Companion's two levels: Performance and Quality
  (former Balanced), safe old-tier migration and shared AI behavior. Hadalis
  retains the Launcher effective-quality indicator and optional host API.
  Do not silently lower manual quality as part of strict-lossless optimization.

## Alis-Companion — centralized features and permissions

**Central task intake 2026-10-11:** implementation owners are
[Alis-Companion](https://github.com/llocphann/Alis-Companion) main
(source snapshot 732136ef65bb3c84d9339207210c955759a85b76)
and [Alis-Intergration](https://github.com/llocphann/Alis-Intergration) main
(source snapshot b0c975a7f40bdf531012be326bc728f5c014b696).
These source SHAs identify the import, **not** the installed release or
acceptance. Alis dev holds the ONLY authoritative TODO status; package code,
test scripts and historical receipts remain in each source repository.


**Visual source:** [active snapshot](https://github.com/llocphann/Alis-Companion/blob/732136ef65bb3c84d9339207210c955759a85b76/to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md).
**AI source:** [active snapshot](https://github.com/llocphann/Alis-Companion/blob/732136ef65bb3c84d9339207210c955759a85b76/to-do/cloud-bot/WULL_LOCAL_AI.md).
All statuses below represent remaining tasks; previously implemented
source, synthetic fixtures and staged 3D previews must NOT be rebuilt.

- [ ] **AC-F01 — Opt-in semantic host event bridge (VIS-02):**
  Alis dev owns authenticated, versioned, bounded semantic event reduction
  and consent; Companion owns the already staged receiving schema, existing
  WullPresence, WullCuriosity, WullMotion and Director arbitration.
  Validate stale/order/unknown/replay rejection, one visual clock/epoch,
  focus, 45-second permission grace, background lock/fullscreen/security
  priority, direct chat/drag/modal, portal/cowork and disconnect/revoke.
  Synthetic protocol QML fixtures already qualified; no live host
  transport, sensors or agent hooks authorized. State: SOURCE-READY,
  LIVE BLOCKED_APPROVAL.

- [ ] **AC-F02 — Original 3D cowork laptop (VIS-04):**
  The Aqua and Octo original Blender scenes, 8 added performances per
  cast, interruption-safe controller and private native previews exist;
  they are STAGING, not a shipped working actor. Finish ONE actor runtime
  asset/material for laptop_open -> typing/thinking/agent/pause -> close,
  uninterrupted across short focus changes and interrupted safely by
  cast/drag/chat/portal. Respect theme, original liquid/limbs/cups,
  4-rim connection, corners, hit-regions, scaling, accessibility,
  disabled/reduced motion and GPU budget. Do not open portal or spawn
  another actor on mere laptop appearance. Require native owner approval.
  State: PARTIAL SOURCE, LIVE OPEN.

- [ ] **AC-F03 — Focus cowork and bounded ambient reactions (VIS P1):**
  Reuse the Alis Focus timer/session for optional reading, book,
  coffee/sip and quiet thoughts; use permitted coarse idle/battery/
  MPRIS/search/success/failure categories with cooldown, permission
  and opt-out, not raw app content or a second clock. Favor existing
  clips before new authored gestures. State: NEW/consent gated.

- [ ] **AC-F04 — User-initiated Pocket plus visual regression authoring (VIS P1):**
  Prove Wayland drag/drop, selected original-file-safe bounded metadata,
  explicit user permission and existing Alis/Vault interfaces before
  attaching Pocket; never auto-ingest documents, edit originals or
  trigger a portal by default. Maintain four-rim pointer/one-shot/
  focus/clip/cast/disabled lifecycle regression matrix. Defer extra
  props/easter eggs until core value and cost are accepted. State:
  NEW/permissions and native proof required.

- [ ] **AC-F05 — Non-punitive bond/dialogue (VIS P1):**
  Optional familiarity, mood and preference are separate; no guilt,
  streak decay, surveillance, false intimacy or copied third-party
  character assets/catchphrases. Require clear settings and user consent.
  State: NEW, UX/privacy contract first.

- [ ] **AC-F06 — User-consented memory with inspect/edit/forget (AI P1):**
  Existing bounded SQLite consent prototype is DORMANT. Specify identity
  and device boundary, source=explicit_user, per-cast vs shared scope,
  TTL/quota, UI for viewing/editing/forgetting, migration/revoke and
  WAL/backups/external Obsidian/chat deletion semantics. Never infer
  memory silently or promise secure disk erasure from SQL DELETE alone.
  State: NEW/BLOCKED_APPROVAL.

- [ ] **AC-F07 — Optional proactive policy (AI P1):**
  Existing fake-clock policy prototype is DORMANT; require explicit
  enable, quiet hours, no wakes, ignored/dismissed backoff, event and
  daily quotas, manual mode, Focus, chat/modal, lock, fullscreen,
  idle, reduced motion and shared presentation budget. No background
  model loading or notifications until owner authorizes. State:
  NEW/BLOCKED_APPROVAL.

- [ ] **AC-F08 — Grounded Todo/Obsidian reminders (AI P1):**
  Only read typed user-authorized tasks and chosen rows; retain existing
  byte-safe explicit Mood/Energy note writes with real confirmation.
  Never promote vault text to prompt instructions, fabricate scheduled
  reminders or claim user journal was saved from a synthetic fixture.
  The optional Integration journal may not be installed. State:
  SOURCE PARTIAL/INSTALL + PERMISSION GATES.

- [ ] **AC-F09 — Shared persona expression without extra movement owner (AI P1):**
  AI may propose bounded text/expression but cannot decide scene
  location, move actor, open Popup, trigger portal or view raw content;
  use existing visual Director and generic Alis AI provider. Character
  animations must work with AI off or unavailable. State: NEW,
  depends on semantic host contract.

- [ ] **AC-F10 — Typed local tools / conditional RAG research (AI P2):**
  Start with read-only typed existing state/repo/doc metadata; any
  user-approved edits/actions need allowlisted capability, explicit
  confirmation, receipts, timeout, cancel/idempotence and rollback.
  Consider RAG and 2-model Reflex/Brain routing only if real workload
  measurements establish value and privacy. Archived suggested GGUF
  models are not assumed installed. **Distillation, SFT/LoRA, autonomous
  diary, self-modifying persona, Discord/MCP, aggressive sensors and
  broad coding-agent automation remain DEFERRED / OUT OF SCOPE.**
  State: RESEARCH ONLY, further authorization required.

## Alis-Intergration — centralized optional package features

**Central task intake 2026-10-11:** implementation owners are
[Alis-Companion](https://github.com/llocphann/Alis-Companion) main
(source snapshot 732136ef65bb3c84d9339207210c955759a85b76)
and [Alis-Intergration](https://github.com/llocphann/Alis-Intergration) main
(source snapshot b0c975a7f40bdf531012be326bc728f5c014b696).
These source SHAs identify the import, **not** the installed release or
acceptance. Alis dev holds the ONLY authoritative TODO status; package code,
test scripts and historical receipts remain in each source repository.


There was NO active TODO directory in the integration repository; these
outcomes come from its manifest, README, source and outstanding Alis
host acceptance, not from an invented prior roadmap.

- [ ] **AI-F01 — TLP/Battery existing optional feature acceptance:**
  [Owner: Alis-Intergration main] Verify source-implemented TLP worker,
  vendor probes, charge limits, Radio Device Wizard, permission-scoped
  helpers and Classic/Waffle settings; no root action or profile
  overwrite at install or without user permission. State: IMPLEMENTED
  IN SOURCE, HOST/NATIVE ACCEPTANCE OPEN.

- [ ] **AI-F02 — Thinkfan existing optional feature acceptance:**
  [Owner: Alis-Intergration main] Verify worker status/rpm/sensors,
  permissions, fail-safe fan control and disabled/missing package
  recovery; never install/enable/change fan service automatically.
  State: SOURCE PRESENT, OWNER HARDWARE QA OPEN.

- [ ] **AI-F03 — Obsidian optional theme, Todo and Zettelkasten delivery:**
  [Owner: Alis-Intergration main] Verify theme, path settings,
  managed/Daily Note task backend, Quick Notes, Zettelkasten images/
  attachments and correct safe vault writes in synthetic fixtures,
  then consented live Obsidian. Keep notes untouched when disabled
  and generic host Todo/Notes available without optional package.
  State: SOURCE PRESENT, OWNER VAULT QA OPEN.

- [ ] **AI-F04 — Versioned package lifecycle and host delivery:**
  [Owner: Alis-Intergration main] Qualify release manifest/API,
  sourceSha-pinned atomic current-link install/update/rollback/
  uninstall, lazy worker lifetime, explicit refresh and helper
  install separated from ordinary package. Run make test and
  cross-repo Alis tests, multi-family QML, DESTDIR/PREFIX and
  absent-dependency cases. Related bugs tracked in Issues, not
  recreated here. State: SOURCE PRESENT, RELEASE GATES OPEN.

## Cross-repository code ownership

All task selection, classification, status, progress and completion for
Alis core, Alis-Companion and Alis-Intergration now belong to these
THREE Alis dev lists. Implementation, tests and technical evidence remain
in their respective source repositories. Historical satellite TODOs are
import baselines only, not separate active queues. Respect optional
default-off state, source identity, explicit permission and all
owner/desktop release gates. Do not mutate Alis stable.
