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

## External feature ownership

Hadalird extraction is source/package-qualified. Its optional TLP, Thinkfan and
Obsidian implementation belongs to [Hadalird](https://github.com/llocphann/Hadalird).
Host installer/state/Polkit failures stay in Hadalis Issues/bugs. Generic Notes,
AI and shell features must work with optional packages absent.

Companion requests — Aqua/Octo edge orientation, symmetrical cloud actions,
themed Obsidian icon, portals, rolling, quicksand clipping, render quality and
AI/mood/energy/schedule behavior — belong to the current Hadanion plans:

- [Design and animation](https://github.com/llocphann/Hadanion/blob/main/to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md).
- [Local AI](https://github.com/llocphann/Hadanion/blob/main/to-do/cloud-bot/WULL_LOCAL_AI.md).

Keep Hadalis' optional host/shared AI APIs; preserve concurrent Hadanion work
and the owner's Companion enablement preference. Historical Hadalis Companion
checklists and captures do not override the owning repo's current state.
