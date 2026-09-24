# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-23

## 1. Source-of-truth and workflow

Requirement precedence:

1. the maintainer's newest explicit instruction;
2. this README's active v1.0 scope and architecture constraints;
3. the current implementation on `dev`;
4. `stable` only as a behavioral/architectural comparison baseline;
5. older docs, historical notes and retired implementation details.

Working rules:

- Work directly on **`dev`**. Do not create or switch to another branch unless the maintainer explicitly requests it.
- Refetch the latest **`dev` and `stable`** before every significant group of changes and immediately before a write that may conflict with concurrent work.
- Re-read the current target file and its caller/consumer before changing architecture.
- Do **not** create a pull request unless explicitly requested.
- Do **not** depend on GitHub Actions for the current development cycle; the maintainer performs the authoritative local test pass.
- Keep commits focused and fix forward. Do not rewrite shared history.
- **Do not stack patches on top of a failed fix.** If local/runtime tests or maintainer evidence show that a fix commit did not solve the reported defect, revert that ineffective change before trying another implementation. Prefer a dedicated revert commit; if concurrent work makes a whole-commit revert unsafe, surgically revert the exact failed change set in its own commit. Re-establish the last known-good baseline, re-investigate the root cause, then implement a different approach. Never retain a disproven workaround merely as a base for another compensating patch.
- Canonical local validator: `bash scripts/validate-maintainer-local.sh`.
- A task is not release-complete merely because code exists. Runtime-sensitive items remain open until locally validated on the intended desktop environment.
- **Settings copy stays terse.** Visible helper/description text should be only a few words or one short clause; never put paragraph-length explanation on the main Settings surface. Put necessary detail in a tooltip or documentation instead.
- **Settings base surface has one owner.** In Material, paint `Appearance.colors.colLayer0` exactly once for each Settings surface, preserving its global transparency. Keep inner page/content containers transparent; do not repaint, locally alpha-tint, or stack the structural fill.

### 1.1 Fresh-chat handoff — read before editing perimeter/UI geometry

This section is the **maintainer handoff for new chat sessions**. Read it before touching Screen Edge, Bar, popup, Sidebar, Dashboard, Settings overlay or any shared perimeter primitive. If another section appears to conflict with this handoff, the maintainer's newest explicit instruction wins.

**Maintainer workflow lock (2026-09-23):** Hadalis development is `dev`-only. Do not create feature/fix branches and do not open pull requests unless the maintainer explicitly asks for them. Refetch and re-read the latest `dev` target before every write, then commit focused changes directly to `dev`.

**Failed-fix rule — no patch stacking:** when a proposed fix is shown by runtime evidence, regression testing or maintainer acceptance to be ineffective, revert that fix before attempting a replacement. Do not layer a second workaround over the failed approach. Restore the last known-good behavior, identify why the previous approach failed, then implement a materially different root-cause fix. Preserve concurrent unrelated work by reverting only the failed change set when necessary.

**Frozen / do-not-touch unless the maintainer explicitly asks:**

- **Physical Screen Edge geometry is locked.** Do not redesign, refactor or "clean up" `modules/screenCorners/ScreenEdges.qml` while working on Popup/Sidebar/Dashboard. The accepted model is one full-screen `FrameWindow`, one odd-even `ShapePath`, four circular `PathArc` corners and transparent reservation windows only.
- **Normal ii Bar/VerticalBar perimeter geometry is locked together with Screen Edge.** Do not add Bar-local `RoundCorner`, `PathArc`, rectangle, wedge, contact patch, shadow band or fallback geometry. Bar position top/bottom/left/right is represented only by changing the matching inner-frame inset to Bar/VerticalBar thickness inside the existing Screen Edge frame.
- The only approved curvature control for that physical perimeter is `appearance.screenEdge.radius` through `PerimeterTokens.frameRadius` (default **25px**, supported range **0–96px**).
- `appearance.screenEdge.physicalShadow` is the public connected-edge depth control and is shared by the physical frame, ii Bar `StyledPopup`, Dock, Sidebar and Dashboard. The older `appearance.screenEdge.shadow` key remains only for Settings/OSK compatibility paths.
- Auto-hide behavior is also frozen for current geometry work: when ii Bar auto-hide is enabled, Bar relinquishes physical-edge ownership back to `ScreenEdges.qml`. Do not reintroduce `autoHideScreenEdge` or another Bar-local physical edge.
- Waffle is a separate supported panel family. Do not change Waffle geometry as a side effect of ii perimeter work.

**Connected-surface policy — legacy round-wedge geometry retired:**

- **Physical Screen Edge geometry remains locked** to the single full-screen odd-even frame below.
- ii Bar popups keep the production iRiS SDF union through `StyledPopup`.
- Sidebar, Dashboard and Settings use `ConnectedSurfaceIrisEdgeSurface`, which adapts their real body rectangle to the same iRiS field without a standalone wedge/corner helper.
- Dashboard-owned Applications Search inherits the Dashboard `ConnectedSurfaceIrisEdgeSurface`; the embedded `SearchWidget` must not paint a second field. Dock also uses `ConnectedSurfaceIrisEdgeSurface` on top/bottom/left/right so its body is one iRiS-connected block with Screen Edge. OSK, standalone/non-cutover Search and current Waffle bodies keep direct square joined edges without auxiliary endpoint wedges.
- `ConnectedSurfaceJoinFlares`, `PerimeterCornerShadow`, common `RoundCorner`, fake screen-rounding paint and the `joinFlare*` token family are retired.
- Sidebar close translation must clear the complete native left/right host plus iRiS/shadow overflow so no visible sliver survives at Screen Edge.
- Runtime-sensitive geometry remains open until the maintainer validates left/right/top/bottom and fractional-scale behavior in the real Niri session.

**Known-good physical perimeter invariants to preserve during all future popup work:**

```text
ScreenEdges.qml
└── FrameWindow (full output, ExclusionMode.Ignore)
    └── Shape
        └── ShapePath OddEvenFill
            ├── padded outer rectangle
            └── one rounded inner workspace hole
                └── exactly 4 PathArc corners

normal ii Bar:
top/bottom  -> owned inner inset = Appearance.sizes.barHeight
left/right  -> owned inner inset = Appearance.sizes.verticalBarWidth

other sides -> inner inset = Screen Edge thickness
radius      -> PerimeterTokens.frameRadius
```

**Fresh-session procedure before a perimeter edit:**

1. Read this section and §2.1 completely.
2. Refetch current `dev` and re-read the exact target file plus its consumers immediately before writing.
3. Treat `SCREEN-EDGE-GEOMETRY-LOCK` and `BAR-SCREEN-EDGE-CORNER-LOCK` as hard guards.
4. For ii Popup work, inspect the iRiS frame/field/body-mask path. For Sidebar/Dashboard/Settings inspect `ConnectedSurfaceIrisEdgeSurface`; Dashboard-owned Applications Search shares that Dashboard field, while standalone Search/OSK/Waffle preserve direct square attachment unless explicitly migrated. Avoid editing locked physical perimeter files.
5. Update `scripts/test-shell-surface-contracts.py` whenever ownership or geometry contracts change intentionally.
6. Do not claim runtime success until the maintainer has run `inir update` / `inir restart` and visually validated the result.

### 1.2 iRiS integration phase status

The iRiS migration is complete and is now the production baseline. Before any
future perimeter/connected-surface optimization, read
`docs/IRIS_INTEGRATION_COMPLETE.md`. New work should focus on optimization,
bug fixing and refinement rather than reopening the migration.

A ready-to-use fresh-chat prompt for that phase is stored at
`docs/NEXT_CHAT_OPTIMIZATION_PROMPT.md`.

**Fullscreen Bar lifecycle lock (maintainer-approved 2026-09-19):**

- Horizontal and vertical ii Bar `PanelWindow` surfaces must remain **mapped and updating while a client is fullscreen**. Do not gate Bar `visible`, `updatesEnabled`, Loader lifetime or content visibility on `GameMode.hasFullscreenOnOutput()`.
- Niri/compositor stacking naturally covers Top-layer Bar surfaces during fullscreen. Explicitly unmapping/remapping the Bar caused a confirmed regression where Bar contents stayed blank after leaving fullscreen until Quickshell was reloaded.
- The painted Screen Edge `FrameWindow` must also remain mapped and updating across fullscreen. It shares the same Top-layer stacking domain as the Bar; destroying/recreating only the frame can remap the Bar-thick physical perimeter above `BarContent` after fullscreen exits. Niri already renders focused fullscreen clients above Top-layer surfaces.
- The four transparent Screen Edge `ReservationWindow` surfaces may still unmap during fullscreen to release their exclusive work-area reservation. This reservation lifecycle must remain separate from the persistent painted frame lifecycle.


### 1.3 Runtime Diagnostics / Quickshell btop handoff (research complete 2026-09-23)

This is the canonical implementation handoff for the planned Hadalis **Runtime Diagnostics** feature: a btop-like debugger for the Hadalis/Quickshell runtime itself, not a general desktop process manager. It must diagnose Hadalis QML components, services, loaders, timers/pollers, owned subprocesses, custom widgets and other runtime resource owners. External applications such as Firefox/Discord are out of scope except where their existence affects an already-supported shell service.

#### Product locks

- **Diagnostics must not run in the background.** The expensive diagnostics sampler is active only while the Diagnostics Settings page is the current page. Hiding/caching the page is not enough: Material `SettingsPageHost` retains an LRU of recent pages, so lifecycle must be driven by explicit current-page session ownership rather than `Component.onCompleted/onDestruction`. Waffle currently keeps only the current Settings page, but it must use the same session contract.
- Any singleton/backend introduced for Diagnostics must be **passive by default**: no CPU polling, `smaps_rollup`, GPU helper, network sampler, fast timer or source scan until an active Diagnostics session exists. Leaving the page must stop those samplers immediately. Remote/standalone Settings sessions need a short TTL/heartbeat so a crashed Settings process cannot leave diagnostics running forever.
- Diagnostics must expose **CPU, RAM, Swap, GPU and Network**. It should help answer which Hadalis component/service is responsible where attribution is technically valid, but it must never manufacture fake per-QML CPU/RAM/swap/GPU numbers.
- **Workflow identity is authoritative.** Diagnostics does not own a second component catalog, display-name table or naming heuristic. A target known by Workflows as `targetId: "bar"`, label `"Bar"`, must appear as exactly that same target in Diagnostics. Metrics store IDs only; presentation resolves label/icon/source/family/parent through `CodeWorkflowRuntime` / `CodeWorkflowIr`.
- Work directly on `dev`; do not create a feature branch or PR unless explicitly requested.

#### One canonical identity model

Use stable references rather than display strings:

```text
runtime target      -> { targetId }
runtime instance    -> { targetId, instanceId }
workflow graph node -> { graphId, nodeId }
source-only node    -> { sourcePath, semanticAnchor }
```

For entities already modeled by Workflows, Diagnostics telemetry must not contain duplicate `name`/`label` fields. UI resolves those fields from the Workflow authority. A diagnostic record that references an unknown target must be treated as orphan telemetry, not rendered as a newly invented component.

Important existing identity layers must remain distinct:

- runtime target examples: `bar`, `bar/media`, `bar/clock`, `bar/resources`, `dashboard`, `sidebar/left`, `waffle/bar`;
- graph-node examples: `bar.loader`, `media.timer`, etc.;
- loader/config `panelId` values such as `iiBar` or `iiSidebarLeft` are implementation IDs, not the public runtime identity.

`CodeWorkflowRuntime.targetIdForPanel()` is a useful future-facing canonicalizer (`iiFuturePanel -> future-panel`, `wFoo -> waffle/foo`), but add collision validation. Two incompatible declarations must never silently collapse onto one target ID. Legitimate renderer/host variants that intentionally represent the same target must satisfy the same canonical identity contract.

#### Shared Workflow / Diagnostics runtime evidence

Do not build an independent Diagnostics component registry. The intended ownership is:

```text
                      canonical identity
                           |
                CodeWorkflowRuntime / IR
                           |
              +------------+------------+
              |                         |
          Workflows                Diagnostics
   structure/relations/source    telemetry/debug/resource
```

`CodeWorkflowRuntime` already owns descriptors, lifecycle state, instances, events, source paths, internal flags and remote snapshot transport. Reuse/extend that evidence path rather than duplicating it.

Standalone Material Settings and Waffle Settings are separate Quickshell processes. Diagnostics sampling must therefore execute in the **main shell process** and be exposed to Settings through IPC. Do not measure the Settings process and report it as Hadalis shell usage. The existing `codeWorkflowRuntime` remote-snapshot architecture is the model to reuse/generalize.

A future snapshot can carry diagnostics evidence without duplicating identity metadata, conceptually:

```js
{
  epoch,
  outputs,
  descriptors,
  records,
  events,
  diagnostics: {
    shell: {...},
    targets: {
      "bar": {...}
    },
    probes: {...}
  }
}
```

#### Discovery must support components that do not exist yet

Do not maintain a fixed `KnownDiagnosticsComponents` list.

Source discovery should reuse the existing Tree-sitter / Code Workflow analysis stack and index the live Hadalis source tree. Cache by source path + content hash/parser version and rescan changed files only when Diagnostics/Workflow needs the index; do not run a continuous whole-tree watcher.

The analyzer must recognize runtime/capability boundaries, including at least:

- `Loader`, `LazyLoader`, `Repeater`, `Instantiator`, `Variants`;
- `Component.createObject()`;
- `Qt.createComponent()`;
- `Qt.createQmlObject()`;
- dynamic Loader `setSource()`;
- `Timer`, `Process`, `FileView`/watchers, sockets and network-capable constructs.

Current repo examples that prove these paths matter include dynamic monitor objects in `Brightness.qml`, provider strategies in `Ai.qml`, notification/timer objects in `Notifications.qml`, AP objects in `Network.qml`, asynchronous `PolkitServiceImpl` creation, and dynamically generated MicroTeX `Process` objects in `LatexRenderer.qml`.

New creation boundaries that the analyzer sees but runtime instrumentation does not cover should be reported as **untracked runtime boundaries**, not ignored. This is the future-proofing mechanism.

#### Custom widgets are first-class future targets

Source discovery is not limited to the Git checkout. `CustomWidgets.qml` discovers user widgets under:

```text
~/.config/inir/widgets/<id>/
```

and `Background.qml` loads them dynamically using `Loader.setSource()`. The Widget SDK gives custom widgets broad QML access, including `Process` and network calls.

Use the custom-widget manifest ID as the basis for a canonical Workflow-owned namespace. Register loaded custom-widget instances at the dynamic loader boundary. Diagnostics then references that canonical target, so widgets installed after this feature ships appear without editing Diagnostics code.

#### Loader/lifecycle instrumentation

Instrument existing lifecycle ownership points instead of attaching a second observer to every component. `CodeWorkflowRuntimeDeclaration` already sits beside the loaders that decide whether major shell surfaces exist and deliberately avoids forcing `LazyLoader.item` while asynchronous loading is in progress.

Extend that path with timestamps/counters such as:

- loading start / resident / visible / hidden / unloaded transitions;
- load count and unload count;
- last/aggregate load duration;
- resident/visible durations;
- visibility transition count;
- instance attach/detach lifetime.

Only access a loader's item after it is safely ready/active. Never read `LazyLoader.item` during async loading in a way that forces synchronous completion.

Explicit `CodeWorkflowRuntimeTarget` remains useful for meaningful nested targets such as `bar/media`; root loader-owned components should not be forced to add redundant registrations merely for Diagnostics.

#### Diagnostics session lifecycle

Introduce an explicit session/lease protocol:

```text
Diagnostics page becomes current
  -> begin/acquire session
  -> shell samplers ON

Diagnostics page stops being current
  -> end/release session
  -> all expensive samplers OFF
```

Material page caching means `visible == false` or object destruction is not a sufficient lifecycle signal. Standalone Settings must acquire/release over IPC. Use TTL/heartbeat cleanup for abnormal client disappearance.

Normal mode should remain cheap and mostly event-driven. High-frequency property sampling/tracing is enabled only for a selected target in Target Debug Mode.

#### Resource metric truth model

Every metric should internally carry provenance such as:

```text
scope       system | shell-process | child-process | target
method      proc-stat | schedstat | smaps-rollup | drm-fdinfo | tracked-request | load-delta | ...
confidence  kernel | exact-child | attributed | experimental
```

Never render kernel-exact data and experimental attribution as if they were equivalent.

##### CPU

- System CPU: reuse/align with existing `ResourceUsage` `/proc/stat` data.
- Main Quickshell CPU: calculate from the shell PID using process CPU time (prefer `/proc/<pid>/schedstat` or equivalent delta-based process accounting).
- Owned subprocess CPU: exact per PID, including descendant process tree where appropriate.
- QML component CPU: **not directly measurable as a kernel percentage** because QML targets share a process/engine. Do not display fake `Bar 3.2%` style values. Instead show meaningful target activity: timer wakeups, polls, event/signal counts, callback durations, process work, and optionally a clearly labeled controlled CPU-impact delta. Deep binding/function attribution belongs to Qt QML Profiler integration, not invented telemetry.

##### RAM and Swap

- System RAM/swap: reuse `/proc/meminfo`.
- Main Quickshell memory: while Diagnostics is open, prefer `/proc/<pid>/smaps_rollup` for RSS/PSS/Anon/File/Shmem/private/shared and Swap/SwapPss; existing `scripts/inir` already demonstrates `VmRSS`/`VmSwap` process reads.
- Owned subprocess memory/swap: exact per PID.
- QML component RAM/swap: Linux cannot assign shared QML engine/JS heap/scenegraph/cache memory to one component. Do not claim exact per-component RAM/swap.
- Provide an explicit **Controlled Footprint Measurement** for safely loadable/unloadable targets: sample before load, after settle, after unload, optionally with a user-requested GC stabilization step. Report results as `Load Δ PSS`, `Retained Δ PSS`, `Load Δ Swap`, etc., never as `Component RAM = ...`.
- `MemoryPressureService` already exposes JSGCHeap mapping counts and manual GC; reuse it as supporting evidence. Do not run forced GC in the normal sampler.

##### GPU

- System GPU: reuse current `ResourceUsage` AMD/NVIDIA/Intel paths where appropriate.
- Quickshell GPU: capability-detect Linux DRM per-client `/proc/<pid>/fdinfo/*` counters (`drm-engine-*`, resident/total/active memory) where the driver exposes them; fall back gracefully to supported vendor tooling.
- Owned GPU child processes can be attributed when driver/process APIs expose them.
- Pure QML component GPU percentage/VRAM is not exact. Use activity evidence or controlled load/VRAM deltas and label their provenance.

##### Network

`SysMonWidget.qml` currently reads `/proc/net/dev`, which is **system/interface traffic**, not Quickshell traffic. Keep this as SYSTEM network only.

Per-component/service network requires attribution at Hadalis-owned request boundaries:

- track request owner using canonical `TargetRef`;
- record start/end, bytes up/down, status and duration;
- migrate direct `XMLHttpRequest` users toward a shared tracked request wrapper;
- for `curl`/helper requests, use request/process telemetry such as curl upload/download byte accounting where practical;
- source discovery must detect network-capable but uninstrumented paths and report attribution coverage rather than claiming complete coverage.

Known direct XHR users currently include `Booru`, `AnimeService`, `NewsService` and `DashGithub`. Other network activity is performed through `Process`/curl/helper paths, remote media/images and future WebEngine/WebSocket paths. Do not claim 100% network ownership until those routes are instrumented.

The disabled/future `WebAppView.qml` is especially important: when WebEngine support returns it may keep audio/WebSocket activity alive in background and QtWebEngine uses child processes. It must be discovered as a resource owner without adding a hardcoded Diagnostics entry.

#### Process ownership

Hadalis uses `Quickshell.Io Process` extensively. `Process.processId` makes owned child-process CPU/RAM/swap/IO attribution valuable and much more exact than QML-level estimates.

Create a shared tracked-process ownership contract over time:

```text
canonical TargetRef
  -> Process PID
     -> descendants
        -> CPU/RSS/PSS/Swap/IO/threads/faults
```

Do not require a whole-repo migration in the first commit. The source analyzer can mark bare `Process` usage as process-capable/unattributed, while standard tracked process wrappers provide full telemetry for migrated/new code.

`Quickshell.execDetached()` is intentionally untracked after launch; only commands worth diagnosing should migrate to an owner-aware launcher/wrapper. Trivial actions such as notifications need not be migrated first.

#### Target Debug Mode

Selecting a runtime target should allow an explicit high-detail debug session without turning the entire shell into a continuous profiler. Planned capabilities:

- live lifecycle/instance/output/source inspector;
- source-declared primitive property watch;
- before/after snapshot and diff;
- lifecycle/event timeline;
- timer/poller/wakeup and signal/activity trace;
- service/lease dependency view;
- owned subprocess tree and exact child resources;
- tracked network request view;
- load/unload history;
- source navigation and `Open in Workflow`;
- target highlight/picker where geometry authority exists;
- controlled memory/swap/GPU footprint measurement;
- bounded trace capture;
- runtime invariant checks for churn/orphan activity/hidden wakeups/lease mismatches.

Use the same `CodeWorkflowSession.selectedTargetId` where practical so Diagnostics -> Workflow navigation preserves the exact canonical target.

Source-declared properties can be discovered by the existing analyzer, allowing new components to expose watchable properties without Diagnostics knowing their names in advance. Serialize only safe primitive values; do not recursively serialize arbitrary QObject/model/JS graphs.

#### Picker / deep-inspection boundary

Do not promise arbitrary live QObject picking in the pure-QML MVP. Existing Workflow hit-testing/geometry is reliable for registered runtime targets and can be generalized for those targets. Source-only objects remain inspectable structurally.

A future native Qt meta-object inspector could enumerate arbitrary QObject children/properties and become another runtime evidence provider. Do not introduce a native plugin merely to complete MVP, and do not change TargetRef/Workflow identity if native inspection is added later.

#### Services, timers, watchers and resource leases

The service audit found extensive `Timer`, `Process`, `FileView` and dynamic activity across both `services/qmldir` and `services/deferred/qmldir`. Important examples include Audio, Brightness, GameMode, MprisController, LocalMusic, Network, ResourceUsage, ShellUpdates, Wallpapers, Weather, YtMusic, CavaService, Cliphist, EasyEffects, InnerTube, LauncherSearch and PackageSearch.

Therefore wakeups, process spawns and file/socket activity are first-class diagnostics capabilities. A useful component/service row can report:

```text
wakeups/min
polls/min
process spawns
active child count
consumer/lease count
last activity
```

Where services currently expose only a numeric consumer count, gradually move toward canonical owner IDs so Diagnostics can show who is keeping a service alive. Example: `ResourceUsage` should eventually explain which targets hold its lease rather than only reporting `2 consumers`.

#### Resource Owners view

In addition to a target list, provide reverse attribution views such as:

```text
NETWORK OWNERS
Weather              ...
Dashboard / GitHub   ...

PROCESSES
CavaService
  -> cava PID ...

RESOURCE LEASES
ResourceUsage
  -> Bar · Resources
  -> Sidebar Right
```

This is the semantic equivalent of btop's “what is consuming resources?” workflow.

#### Runtime anomaly checks

Diagnostics may flag evidence-backed conditions such as:

- rapid load/unload churn;
- hidden/resident targets with unexpected fast wakeups;
- orphan target instances;
- service consumer/owner mismatch;
- owned child process surviving target destruction;
- network activity after owner unload;
- canonical identity collisions;
- stale/ambiguous semantic anchors;
- untracked dynamic creation/network/process boundaries.

Only guaranteed invariant violations should be called errors. Heuristics should be labeled `Investigate`, not asserted as bugs.

#### Settings integration

Material currently uses persisted positional page indices and ends with Workflow at index 30. Append Diagnostics at **index 31**; do not insert it in the middle.

Waffle Settings maintains a separate positional page array and currently ends at index 18. If Diagnostics is exposed there, append it at **index 19**. Do not force Material/Waffle numeric indices to match; use the semantic page key `diagnostics` for cross-renderer navigation.

Settings-visible explanatory copy must remain terse. Put metric provenance/details in tooltips/inspectors rather than paragraph-length page text.

#### Performance policy

The feature must not become the source of the problem it measures.

Normal Diagnostics session:
- shell/system CPU/network sampling around 1s is a reasonable starting point;
- expensive memory/GPU probes can run at a slower cadence;
- target lifecycle/activity should be event-driven where possible;
- no whole-QObject-tree polling;
- no source-tree reparse every sample;
- bounded histories/ring buffers only.

Target Debug Mode may temporarily increase sampling for one selected target. Stop all high-frequency work when the target/session closes.

Exact intervals are implementation tuning and must be benchmarked on the maintainer's actual environment before being treated as fixed.

#### Workflow polling follow-up

Standalone `CodeWorkflowRuntime` currently has a periodic remote snapshot refresh path. As Diagnostics introduces explicit consumer sessions, consider moving Workflow remote refresh to the same consumer/lease model so Workflows does not poll when neither Workflow nor Diagnostics needs runtime evidence. Do this only when it can preserve current Workflow behavior; it is a follow-up, not a reason to fork the runtime transport.

#### Implementation order

1. Add canonical `TargetRef` / identity collision contracts and regression tests; explicitly prevent Diagnostics-owned labels for Workflow entities.
2. Add on-demand Diagnostics session IPC with client TTL/heartbeat and prove sampler work is zero when the page is not current.
3. Add exact shell/system samplers: CPU, RSS/PSS, Swap, IO, system network and capability-detected GPU.
4. Expand source discovery for dynamic creation APIs, capabilities and custom widgets; report untracked boundaries.
5. Extend existing Workflow runtime declarations/targets with lifecycle timing/counters instead of adding parallel loader observers.
6. Add tracked process ownership and descendant resource accounting.
7. Add tracked network ownership for XHR/curl/helper paths plus explicit attribution-coverage reporting.
8. Build the Diagnostics Settings UI: system/shell overview, target table, provenance, Resource Owners and process tree.
9. Add Target Debug Mode: property watches, snapshots/diffs, timelines/traces, leases, footprint measurement and anomaly checks.
10. Consider native QObject/network inspection and Qt QML Profiler integration only after the pure-QML/runtime-evidence MVP is stable.

#### Validation contracts required before calling the feature complete

Add regression coverage that proves at least:

- `bar -> Bar`, `bar/media -> Bar · Media`, `dashboard -> Dashboard`, `sidebar/left -> Sidebar Left`, `waffle/bar -> Waffle Bar` resolve through Workflow identity and cannot be renamed by Diagnostics;
- a synthetic future panel is discovered without adding it to a Diagnostics catalog;
- a new/untracked `LazyLoader` or dynamic creation boundary is reported;
- a custom widget installed after build can be discovered and registered;
- a new singleton/service entry is discoverable without Diagnostics hardcoding its name;
- standalone Settings measures the main shell, not the Settings process;
- leaving Diagnostics stops all Diagnostics-owned fast timers/processes/samplers even while the page remains cached;
- identity collisions and orphan telemetry fail/report rather than inventing a second target;
- multi-output instances remain distinct under one canonical target;
- reload/family-switch stale generations cannot be mistaken for the new generation;
- metric UI preserves provenance so kernel-exact values are never presented as component-exact estimates.

Research is complete for the architecture. Remaining unknowns such as real `smaps_rollup` cost, DRM driver coverage and sampler overhead are implementation-time runtime benchmarks, not unresolved architecture questions.

## 2. v1.0 product direction

Hadalis remains a Quickshell desktop shell built on the existing iNiR architecture. The v1.0 priority is **UI/UX quality without throwing away working iNiR behavior**.

Required direction:

- preserve existing iNiR services, state, routing, popup contents and proven interaction behavior;
- use **Caelestia as the visual/composition reference** for connected edge surfaces;
- make popups appear to grow/morph from their real source surface instead of looking like detached floating cards;
- keep keyboard focus, Escape close, outside-click close, hover transfer, multi-output ownership and compositor behavior intact;
- prefer shared fixes in existing abstractions over per-popup forks;
- **do not build a second popup framework**;
- Niri remains the primary compositor target; preserve existing Hyprland compatibility;
- Waffle remains a supported separate panel family and must not be removed as part of ii/perimeter cleanup;
- **Material is the only supported Global Theme for v1.0.** All other Global Theme families, selectors, runtime branches and stale compatibility paths must be removed unless a narrow migration shim is required only to normalize old persisted values to Material.

Retired per-component renderer/style experiments must not be revived merely to preserve obsolete configuration values.

### 2.1 Locked ownership contract — single Caelestia-style inverted frame

The maintainer requires the physical Screen Edge corners to match Caelestia without painted edge/corner patches, wedges or overlay geometry.

**Four-corner geometry lock (maintainer-approved 2026-09-19):** the live-validated inverted-frame construction is the canonical visual reference for Hadalis. The maintainer subsequently approved one controlled degree of freedom: `appearance.screenEdge.radius` may change the radius of that same quarter-circle geometry (default **25px**, range **0–96px**). Future Bar, popup, reservation, scaling, refactor or compositor work must preserve the same single-path construction, concentric placement and exact circular corner primitive. If a later change deforms, offsets, double-rounds or replaces those arcs with a second renderer, restore the locked `ScreenEdges.qml` model rather than compensating elsewhere.

**Bar + Screen Edge corner lock (maintainer-approved 2026-09-19):** the current top/bottom/left/right normal ii Bar endpoint corners and the four Screen Edge corners are one canonical perimeter geometry. The Bar is not allowed to own a second corner renderer. Its owned edge only changes the corresponding inner-frame inset from Screen Edge thickness to Bar/VerticalBar body thickness; the same `PerimeterTokens.frameRadius` and the same four `PathArc` segments continue to define the visible corners. Future work must restore this exact model if the Bar or Screen Edge corners regress. Only the existing radius setting may intentionally change their curvature.


- **Normal Bar mode owns only the Bar body.** Horizontal and vertical Bar runtimes must not paint `roundDecorators`, Screen Edge contact rectangles, Bar-local Screen Edge fallback bands, physical-edge shadow rectangles, `RoundCorner` wedges, or any synthetic perimeter extension outside the body.
- **`ScreenEdges.qml` is the only physical Screen Edge renderer.** Each output has exactly one painted full-screen frame surface.
- The frame is one odd-even path: a padded outer rectangle minus one rounded inner workspace rectangle. This mirrors the isolated geometry of Caelestia's `BlobInvertedRect` instead of approximating it with four strips plus four corner patches.
- **Normal ii Bar is treated as a thicker side of that same frame.** This follows Caelestia `ContentWindow.qml`: when Bar owns top/bottom, the matching inner-frame inset becomes `Appearance.sizes.barHeight`; when VerticalBar owns left/right it becomes `Appearance.sizes.verticalBarWidth`. The other three sides remain the Screen Edge thickness. Therefore the two inward Bar endpoint corners are produced by the same locked rounded workspace hole, not by Bar-local patches.
- **Connected curvature is iRiS-owned, not patch-owned.** `StyledPopup` and the shared edge adapter use the exact iRiS SDF path. Sidebar/Dashboard/Settings consume `ConnectedSurfaceIrisEdgeSurface`; Dashboard-owned Applications Search shares the Dashboard field, while standalone Search/OSK/Waffle keep direct square seams. No standalone round-wedge painter remains.
- Caelestia's border defaults are preserved: Screen Edge thickness defaults to **10px**, corner radius defaults to **25px**, and the outer path extends **50px** beyond the window so the compositor clips the physical screen boundary rather than exposing antialiasing on an outer shape edge. Radius is user-adjustable through Settings without changing renderer ownership.
- The full-screen visual `FrameWindow` follows Caelestia's layer-shell placement contract: it is anchored to all four physical output edges and uses `ExclusionMode.Ignore` without setting an `exclusiveZone`, so edge reservations cannot inset the painted frame. The four thin `ReservationWindow` surfaces are transparent compositor reservations only; they set the positive edge `exclusiveZone` and otherwise remain in normal exclusion semantics. They never paint Screen Edge pixels and therefore cannot change the frame silhouette.
- Physical Screen Edge shadow is allowed only as **one effect attached directly to the locked frame Shape**. It must not introduce an Item wrapper, edge/corner renderer, gradient band, radial patch, wedge, rectangle or second painted geometry. Defaults match Caelestia ContentWindow: Material `m3shadow`, `blurMax = 15`, alpha `0.70`.
- Screen Edge and ii Bar popup depth are synchronized: `appearance.screenEdge.physicalShadow` drives the locked physical frame and every ii `StyledPopup`, using the same Material `m3shadow` ink. The older `appearance.screenEdge.shadow` contract remains internal to Sidebar/Dashboard/Settings/OSK and must never be read by `ScreenEdges.qml`.
- When the ii Bar uses auto-hide, it relinquishes physical-edge ownership to `ScreenEdges.qml`; there is no `autoHideScreenEdge` substitute inside Bar/VerticalBar.
- `scripts/test-shell-surface-contracts.py` is the regression gate. It locks the single-frame Shape/ShapePath, four PathArc corners, all four Bar-aware inset formulas, the shared radius owner, and the absence of any Bar-local corner primitive. Do not restore `CornerWindow`, painted `EdgeWindow`, Bar-local `RoundCorner`/`PathArc` geometry, separate physical shadow geometry or shared shadow ownership.

## Equalizer implementation status

### Implemented

`EqualizerService.qml` provides the Phase 1 backend/service contract and is disabled by default. It owns the optional 10-band DSP state, EasyEffects transport boundary, preset curves and consumer-driven lifecycle without creating a second equalizer backend.

### Stabilizing

The existing backend is being stabilized around transport probing, EasyEffects lifecycle changes, state synchronization and live visual/audio validation in the Media Popup. These are hardening tasks; they do not imply that the open release gates below have already passed.

### Planned

Further equalizer presentation experiments are planned/deferred rather than current release prerequisites. The v1.0 release-blocker list below remains the authority for required source and live validation.

## 3. v1.0 release blockers

Checkboxes below are **release gates**, not an assertion that no partial implementation exists. Check an item only after source review and the relevant local/runtime validation.

> **Current release status (2026-09-23):** completed source-side work is removed from this README once it is no longer active work; historical implementation detail belongs in Git history / `CHANGELOG.md`. The release gates below remain open until their required source audit and authoritative local/runtime validation are complete. Current `dev` already contains the source-side Dashboard/Search crossfade, SongRec geometry cleanup, redesigned Dashboard System Monitor, horizontal Available Modules row, Local Music stop/resume fallback, unified media controls/CAVA work, connected-surface/iRiS implementation, Material-only public theme boundary, ThinkFan integration, broad legacy perimeter-runtime removal and the compact System Monitor popup refinement that reserves a two-digit CPU Load width and adds RPM/Level icons. Material-only cleanup is still actively collapsing remaining live surfaces and is not complete until the active-tree residue audit plus local/runtime validation pass. Those implementations are not repeated as completed tasks below; only unresolved validation or cleanup work remains listed.

### A. Screen Edge and connected surfaces — P0

> **Latest perimeter correction:** the legacy round-wedge/corner renderer family is retired. Curved connected contact is iRiS-owned; otherwise the joined body edge stays square. Horizontal/vertical Bar PanelWindows and the canonical Screen Edge frame remain independently owned and mapped across fullscreen.

- [ ] **Screen Edge exists both while idle and while a window is maximized.** It must not disappear simply because no maximized window is present.
- [ ] **Bar survives fullscreen enter/exit without reload.** Horizontal and vertical ii Bar native surfaces and the painted Screen Edge `FrameWindow` stay mapped/updating; fullscreen coverage is owned by compositor stacking, not `visible`/`updatesEnabled` gates. Transparent reservation-only windows may release their exclusive zones independently. Leaving fullscreen must restore all Bar contents immediately without `inir restart` or shell reload.
- [ ] **Screen Edge width is configurable in Settings.** The setting must use one canonical configuration field, have a safe default/range and update the active edge without requiring an alternate renderer.
- [ ] **Screen Edge corner radius is configurable in Settings and defines the physical ii Bar/Screen Edge.** Default is 25px. Direct-attached surfaces do not derive a second legacy wedge radius from it; iRiS contact remains independently tokenized.
- [ ] **All connected surfaces use one direct-attachment contract.** No popup may invent a private gap or auxiliary round-wedge patch. Shared geometry/iRiS owns seam overlap, joined-edge ownership and shadow/input clipping.
- [ ] **No visible gap between bar/Screen Edge and popup body.** Shared geometry must own seam overlap so fractional scaling, animation and antialiasing do not expose a slit.
- [ ] **Left and right Sidebars connect to the vertical Screen Edge**, not to the top bar or bottom screen edge.
- [ ] Connected surfaces behave correctly for top/bottom/left/right bar placement, transformed outputs and fractional scale.
- [ ] Reverse retract / hover bridge keeps the source and popup visually and interactively continuous during close/reopen transitions.

### B. Popup interaction correctness — P0

> **Latest maintainer correction (2026-09-18):** direction-only translation is insufficient. During reveal/retract the popup body must remain full-size, translate toward/away from the owning edge, and be clipped at the resting attachment boundary so the hidden portion is visually underneath the Bar/Screen Edge. The connected body must not scale/shrink.

- [ ] Existing bar popups continue to use `modules/bar/StyledPopup.qml` and the shared connected-surface primitives.
- [ ] Popup placement anchors from the real visual source control / `hoverTarget`, not a loader or lifecycle wrapper.
- [ ] Keyboard focus, initial focus, Escape close and compositor focus-grab behavior remain correct.
- [ ] Outside-click close works without stealing input from transparent regions.
- [ ] Full-output click-catchers are owned by the same output as their popup on multi-monitor setups.
- [ ] Tray menu delayed-close logic cannot release the focus/grab of a newer active tray menu.
- [ ] No guessed `PanelWindow.active` / `onActiveChanged` style APIs are introduced without verifying the current Quickshell API.

### C. Thinkfan + System Monitor — P0

- [ ] **Thinkfan UI is integrated into the existing System Monitor popup** instead of living as a separate standalone popup.
- [ ] **Thinkfan settings are exposed in Settings** in the appropriate system-monitor/thermal area.
- [ ] Reuse the existing Thinkfan helper/service path; do not create a duplicate fan-control backend.
- [ ] Unsupported/missing Thinkfan environments fail gracefully and do not break System Monitor or Settings loading.
- [ ] Fan status/control state stays synchronized between Settings and the System Monitor popup.

### D. Settings correctness — P0

- [ ] **Settings > Bar renders real content** and no longer presents an empty page.
- [ ] Bar settings expose only supported v1.0 behavior; retired Dock/Bar renderer switches must not reappear through routing.
- [ ] Settings page loading remains lazy/deferred enough to avoid large synchronous rebuilds.
- [ ] Screen Edge width and Thinkfan controls are reachable through the normal Settings navigation.
- [ ] No user-facing setting remains that points to a removed runtime with no effect.
- [ ] Global Theme UI exposes **Material only**; no removed theme can still be selected, previewed or routed through Settings.

### E. Media Popup equalizer — P0

> **Latest maintainer correction (2026-09-19):** the DSP curve keeps a compact electric current visible at rest. Preset changes and direct band edits brighten the same current without increasing stroke width or jitter amplitude; the old oversized transient sweep/per-band growth is retired. This remains presentation-only and does not create a second DSP backend. Live visual/audio validation remains pending.

- [ ] The bar-attached Media Popup suppresses `PlayerControl`'s decorative `WaveVisualizer`; its **10-band DSP Equalizer** is the only live CAVA/analyzer surface in that popup. Other `PlayerControl` owners may still use the optional wave visualizer.
- [ ] The same Media Popup includes a **10-band DSP Equalizer** below the player card, using the existing optional `EqualizerService` / EasyEffects backend rather than a second ad-hoc equalizer process. User-facing bands are 31/63/125/250/500/1k/2k/4k/8k/16k Hz with the Serpantinum Flat/Bass/Treble/Vocal/Pop/Rock/Jazz/Classic curves.
- [ ] Confirm the required CAVA runtime/package is present in the supported install/package paths, or document/install it where currently missing. EasyEffects + socat remain optional capabilities and must degrade gracefully when absent.
- [ ] Equalizer/analyzer lifecycle is efficient: the bar popup owns no redundant decorative CAVA subscriber; the DSP analyzer starts only while the popup is presented and survives pause/resume, player switching and popup close/reopen.
- [ ] MPRIS controls, seek, volume and keyboard behavior do not regress while the visualizer/DSP controls are active.

### F. Clock Calendar / Weather composition — P0

> **Latest maintainer direction (2026-09-19):** Calendar is owned by Clock as a dedicated Obsidian-inspired connected popup. Weather is a separate two-tab connected popup: tab 1 is the 8-hour orbital forecast and tab 2 is detailed weather. Two circular indicators sit vertically centered on the popup's right edge; mouse-wheel/touchpad vertical scrolling moves between tabs. Tab content transitions vertically in the same direction as the navigation gesture using the shared element-move timing/easing, while the popup geometry itself remains fixed.

- [ ] **Clock hover:** horizontal Clock and the vertical Clock+Date cluster open the dedicated Calendar popup.
- [ ] **Weather tabs:** orbital forecast and detailed weather share one stable popup footprint and switch by wheel or the right-edge dot indicators.
- [ ] **Vertical slide transition:** the two pages move as a clipped vertical stack using the shared element-move motion token; scrolling down advances upward to Details, scrolling up returns downward to Orbit, and the popup body itself never resizes or translates.
- [ ] Preserve Hadalis DateTime/Weather service ownership, units, refresh behavior, location/error states and Material theme behavior.
- [ ] Calendar and Weather layouts remain usable across supported screen sizes/scales and do not depend on screenshot-specific dimensions.

### G. Material-only Global Theme cleanup — P0

Material is the **single canonical Global Theme** for Hadalis 1.0.

- [ ] Remove every non-Material Global Theme option from Settings, menus, previews and any user-facing theme selector.
- [ ] Remove non-Material Global Theme runtime branches, loaders, delegates, theme registries and alternate token/palette routing that are no longer required by Material.
- [ ] Remove dead non-Material theme assets and imports when no active Material path or supported panel family consumes them.
- [ ] Remove or update stale tests, docs and configuration examples that imply multiple Global Themes remain supported.
- [ ] Normalize old persisted non-Material theme values to Material safely; do not resurrect an old renderer/theme only to honor a legacy value.
- [ ] Keep only the minimal migration compatibility needed to read an old value and resolve it to Material, then delete compatibility code that no current caller needs.
- [ ] Material must remain visually correct across Bar, Screen Edge, popups, Sidebars, Overview, Settings and Waffle after the cleanup.

### H. Legacy/compatibility cleanup — P1

- [ ] Remove active reads/routes for retired renderer/style families when they no longer serve migration compatibility.
- [ ] Keep compatibility shims only where a current supported caller still needs the type/config name.
- [ ] Do not restore retired Pill/Mascot runtime behavior, historical Dock renderer families, Orbit/workspace experiments, removed Global Themes or similar dead presentation systems.
- [ ] Old persisted values must degrade safely to the supported v1.0 behavior instead of resurrecting removed renderers or themes.
- [ ] Keep Waffle separate and supported.

## 3.1 Latest maintainer runtime findings

Only unresolved runtime findings belong here. Remove an item after the maintainer accepts the fix on the target desktop instead of retaining a completed-history checklist.

- **Settings navigation indicator:** still unresolved. Expanding/collapsing **Headings** can make the active task-tab indicator jump downward. The latest source attempt improved stability but did not eliminate the defect, so it is not accepted. Do not stack another workaround on top; re-audit and remove/replace the failed geometry/lifecycle approach before the next implementation.
- **System Monitor popup refinement:** the source-side two-digit CPU Load width floor and RPM/Level Material icons are on `dev`; live-validate that CPU changes across one/two digits no longer resize the popup and that the fan metrics remain aligned/readable.
- **Shell boot integrity:** the duplicate `bindingPhase` declaration in `CodeWorkflowTransaction.qml` has a source fix, but the installed/runtime shell must still be updated and confirmed to start without `Type ... unavailable`, duplicate-identifier or Code Workflow singleton construction failures.
- **Connected-surface acceptance:** Popup, Left/Right Sidebar, Dashboard, Settings and OSK still require live Niri validation for outward contact geometry, no seam/gap, correct edge ownership, hover transfer/retract and fractional-scale/multi-output behavior. If a visual fix fails acceptance, revert it before trying a different geometry strategy.
- **Screen Edge / Bar lifecycle:** validate idle/maximized visibility, width/radius/shadow settings, auto-hide ownership and fullscreen enter/exit without stranded or blank Bar content.
- **Music/media:** validate Local Music Stop -> long idle -> Play, bulk folder/track selection, Play Selection/Add to Queue, and unified Shuffle/Repeat/CAVA behavior across popup/sidebar/dashboard. CAVA and EasyEffects DSP lifecycle still need live audio/player-switch/reopen validation.
- **Dashboard/Overview:** the mapped warm lifecycle and tuned 32px/360ms `OutCubic` entrance + 260ms `InCubic` exit remain, but the transient whole-Dashboard scene-graph cache was runtime-rejected because it nested around PlayerControl artwork/mask layers and could snapshot a cyan/partial media frame. That cache is removed. Dashboard Media now keeps the shared PlayerControl visual tree resident while only CAVA/Equalizer activity sleeps when hidden, and standalone `presentationActive` remains true through the complete exit slide. Live-validate that media artwork/controls never flash cyan, rebuild or disappear during open/close, while the slide remains smooth.
- **Calendar/Weather:** validate responsive Calendar sizing/event interaction and the fixed-footprint two-tab Weather wheel/slide behavior across supported scaling.
- **ThinkFan/TLP:** validate the installed helper/polkit bridge, profile-level synchronization, promptless active-session authorization and uninstall ownership on the maintainer's hardware.
- **Material-only cleanup:** source cleanup is actively progressing across remaining leaf/widget/plugin/overlay surfaces. The latest pass removed retired Global Style entry points from Waffle Settings, Welcome and GlobalActions; collapsed WindowDialog, StyledOverlayWidget, shared chip/button/navigation/dialog primitives, anime/plugin surfaces and multiple Sidebar leaf widgets to their Material fallbacks; and expanded regression guards around those paths. Run a fresh active-tree residue audit and remove any remaining live non-Material Global Theme branches/assets/docs outside intentional migration compatibility before calling this gate complete.
- **Release gate:** run `bash scripts/validate-maintainer-local.sh` and the Niri/Quickshell live smoke pass on the exact candidate SHA before closing any runtime-sensitive P0 gate.

## 4. Connected-surface architecture contract

The existing connected-surface paths remain authoritative:

```text
ii Bar popups:
modules/bar/StyledPopup.qml
  -> modules/common/perimeter/ConnectedSurfaceGeometry.qml
  -> modules/common/perimeter/ConnectedSurfaceRevealClip.qml
  -> modules/common/perimeter/ConnectedSurfaceIrisFrame.qml
       -> modules/common/perimeter/ConnectedSurfaceIrisField.qml
  -> modules/common/perimeter/ConnectedSurfaceContentHost.qml
  -> modules/common/perimeter/ConnectedSurfaceBodyMask.qml
  -> modules/common/perimeter/PerimeterTokens.qml

feature-owned Screen Edge bodies:
Sidebar / Dashboard / Settings
  -> modules/common/perimeter/ConnectedSurfaceIrisEdgeSurface.qml
  -> modules/common/perimeter/ConnectedSurfaceIrisFrame.qml

direct square-seam compatibility:
Waffle -> ConnectedSurfaceFrame.qml + ConnectedSurfaceMask.qml
Dock / Search / OSK -> feature-owned body geometry, no auxiliary wedge painter
```

Rules:

- `StyledPopup.qml` remains the entry point for existing ii Bar popouts.
- Curved connected contact is owned by iRiS; direct-seam surfaces keep square joined body edges.
- `ConnectedSurfaceJoinFlares`, `PerimeterCornerShadow`, common `RoundCorner` and the `joinFlare*` token family are retired and must not be recreated.
- Consumers provide content and source ownership; they must not recreate connector/stem geometry, private edge gaps or standalone corner wedges.
- Keep source-aware placement, owner clipping and shaped input regions.
- Preserve top/bottom/left/right attachment and output ownership.
- Fix shared geometry when the defect is systemic; do not paper over the same seam bug in every popup.

## 5. Required functionality that must not regress

- MPRIS player switching, play/pause, previous/next, seek and volume;
- CAVA / visualizer behavior where supported;
- keyboard navigation, initial focus and Escape close;
- click-outside close and transparent-region click-through semantics;
- hover-open / hover-transfer behavior;
- system tray and nested tray menus;
- Dock/task drag and reorder flows;
- Sidebar role routing, resize/edit behavior and open/close state;
- multi-output routing and source-screen ownership;
- fullscreen, lock, suspend/resume and compositor transitions;
- Niri primary behavior and existing Hyprland compatibility;
- Material theme tokens, palette and component rendering;
- Waffle family routing.

## 6. v1.0 hardening tasks — P1

- [ ] Audit every `StyledPopup` consumer for connector, anchor, focus and mask consistency.
- [ ] Test bottom-right and vertical-bar anchors explicitly; these expose clipping/placement errors easily.
- [ ] Remove fractional-scale seams and one-pixel antialiasing gaps without per-popup magic numbers.
- [ ] Confirm Settings remains responsive while visiting all heavy pages repeatedly.
- [ ] Confirm no `Type ... unavailable` failures through Sidebar Left/Right, Compact Sidebar, Overview, Waffle and Settings routes.
- [ ] Verify fullscreen transparent surfaces never land on the wrong output.
- [ ] Verify suspend/resume, lock/unlock and output hotplug do not leave stale popup/focus state.
- [ ] Audit packaging/runtime dependencies required by media visualization, Thinkfan and weather.
- [ ] Search the active tree for removed Global Theme names and eliminate live references outside intentional migration code/history.

## 7. Local release validation — P0 gate

The maintainer's local pass is authoritative. At minimum, validate the exact candidate SHA with:

```bash
bash scripts/validate-maintainer-local.sh
```

Then perform live desktop checks:

- [ ] Screen Edge visible when idle and maximized; width setting updates correctly.
- [ ] Connected popups from top, bottom, left and right positions have no visible gap; attached edges are square and shadow-free, while only unattached outer corners remain rounded and shadowed.
- [ ] Left/right Sidebars connect to the correct Screen Edge.
- [ ] Settings > Bar renders; Thinkfan and Screen Edge controls are reachable.
- [ ] System Monitor contains Thinkfan functionality and no duplicate Thinkfan popup remains in normal UX.
- [ ] Media Popup equalizer works through play/pause, player switch, close/reopen and keyboard open.
- [ ] Calendar/Weather composition matches the intended left/center structure while keeping Hadalis detailed weather on the right.
- [ ] Only **Material** is available as a Global Theme; an old persisted non-Material value resolves safely to Material.
- [ ] Material renders correctly across Bar, Screen Edge, popups, Sidebars, Overview, Settings and Waffle.
- [ ] Tray/context menus work on a non-primary output.
- [ ] Multi-monitor, fractional scaling, transformed outputs and vertical bars are usable.
- [ ] Niri full pass; Hyprland compatibility smoke test.
- [ ] Fullscreen, lock/unlock and suspend/resume do not leave broken shell surfaces.

## 8. v1.0 definition of done

Hadalis can be called **1.0** only when:

- every P0 release blocker above is completed and locally validated;
- no known empty/broken Settings route remains for supported features;
- connected surfaces visually read as one coherent bar/edge continuation, not detached cards;
- no required behavior depends on a dead/half-enabled renderer or undocumented migration path;
- **Material is the only active Global Theme**, with non-Material values removed from normal runtime/UI and legacy values safely normalized;
- the broad `iiPerimeter` runtime is either removed or retained only for a clearly documented active responsibility;
- media visualization, Thinkfan and weather dependencies are packaged/documented correctly;
- supported panel families, the Material theme and compositor targets pass the release smoke matrix;
- release notes / `CHANGELOG.md` describe user-visible 1.0 behavior after the implementation stabilizes.

## 9. Explicit non-goals for 1.0

Do not spend the 1.0 cycle on:

- a new popup framework parallel to `StyledPopup`;
- reviving retired renderer/style experiments;
- rebuilding the old Pill or Mascot runtime;
- preserving or reintroducing multiple Global Theme families after the Material-only cleanup;
- copying Serpantinum's right-side weather panel;
- cosmetic documentation history that does not help implement or validate 1.0;
- hosted-CI cleanup while Actions usage is intentionally not part of the maintainer validation loop.

## 10. Documentation hygiene

To avoid future contradictions:

- keep this README focused on **current** v1.0 requirements, invariants and release gates;
- treat the Material-only Global Theme rule as canonical anywhere older documentation still describes multiple Global Themes;
- do not pin transient implementation status to old commit hashes here;
- put historical changes in `CHANGELOG.md` / Git history;
- when code removes a feature/runtime/theme, remove or update its user-facing setting and stale documentation in the same change where practical;
- when an older document conflicts with the newest maintainer instruction or this active v1.0 contract, update/remove the stale statement instead of maintaining two competing rules.

If the maintainer gives a newer explicit instruction, that instruction supersedes this document and this README should be refreshed to match it.

## 11. Current unfinished handoff (2026-09-23)

This section contains **unfinished work only**. When an item is source-complete *and* its required local/runtime acceptance has passed, delete it from this section rather than leaving a checked task or a historical implementation narrative.

1. **Boot integrity:** update/reload the maintainer runtime and confirm the Code Workflow Binding lifecycle fix eliminates the startup crash chain through `CodeWorkflowTransaction -> CodeWorkflowSession -> CodeWorkflowRuntime -> CodeWorkflowPicker`. Any new boot blocker takes precedence over visual polish.
2. **Settings task-tab indicator:** the Headings expand/collapse path still makes the indicator jump downward. The previous fix is not accepted; before another attempt, re-audit and remove/replace the failed indicator geometry/lifecycle approach instead of stacking a compensating patch.
3. **System Monitor popup:** source refinement is present on `dev` (two-digit CPU Load width floor plus RPM/Level icons). Live-validate that one/two-digit CPU changes no longer resize the popup and that the fan row remains aligned.
4. **Connected surfaces:** complete live acceptance for iRiS/direct-seam contact geometry across normal ii Popups, Left/Right Sidebar, Dashboard, Settings, Dock and OSK on top/bottom/left/right ownership, fractional scale and multi-output. Preserve the locked physical Screen Edge/Bar geometry.
5. **Screen Edge / Bar lifecycle:** verify idle/maximized visibility, configurable width/radius/shadow, auto-hide ownership, fullscreen enter/exit, lock/unlock and output transitions without blank or stranded surfaces.
6. **Music/media:** live-test Local Music Stop/resume after long idle, bulk selection actions, queue operations and the unified Shuffle/Repeat/CAVA surfaces. Validate the 10-band EasyEffects DSP and CAVA lifecycle through pause/resume, player switching and reopen.
7. **Dashboard/Overview:** live-validate the mapped warm Dashboard lifecycle and tuned motion with no whole-surface motion FBO: no widget-tree rebuild after first use; native surface mapped with empty input/render sleep while closed; entrance 32px/360ms `OutCubic`, exit 260ms `InCubic`, no opacity/scale fade. Dashboard Media must keep its PlayerControl visual state resident, preserve artwork/palette/masks across reopen, stay fully drawn through exit, and only suspend CAVA/Equalizer after the visible slide completes.
8. **Calendar/Weather:** finish responsive layout and gesture/transition smoke tests without introducing a second date/weather backend or screenshot-specific geometry.
9. **ThinkFan/TLP:** validate installed helper/polkit reconciliation, profile-follow synchronization, active-session authorization and uninstall ownership on supported hardware.
10. **Material-only cleanup:** continue the active-tree residue audit outside intentional migration shims. Recent source work has already removed retired Global Style selectors/actions, dead Welcome/overlay style render trees, and a broad set of shared controls plus Sidebar/plugin/anime leaf branches; focused regression guards now cover those paths. Keep removing remaining live non-Material theme branches/assets/docs only when their callers are proven dead, and do not delete the inert compatibility aliases until the caller audit reaches zero.
11. **Runtime Diagnostics / Quickshell btop:** architecture research is complete in §1.3. Implement it without creating a second identity/catalog beside Workflows. Diagnostics must be on-demand only while its tab is current; provide CPU/RAM/Swap/GPU/Network with exact-vs-attributed provenance; future QML components/services/custom widgets/dynamic creation boundaries must be discoverable without hardcoded names; start with canonical identity/session contracts and tests before UI.
12. **Release validation:** run the canonical local validator plus Niri live smoke tests on the exact candidate SHA; keep Hyprland as a compatibility smoke pass.

**Failure-handling requirement:** do not fix a failed fix with another patch on top. Once a commit is demonstrated to be ineffective, revert that failed change first (or revert only its exact change set if unrelated concurrent work shares the commit range), then investigate and implement a different root-cause approach.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Đọc `README.md` trên branch `dev` trước vì đó là development contract + handoff hiện tại. Làm và commit trực tiếp trên `dev`; KHÔNG tạo branch khác và KHÔNG tạo PR trừ khi tôi yêu cầu rõ ràng. Trước mỗi nhóm thay đổi quan trọng và ngay trước mỗi write có khả năng conflict, phải refetch cả `dev` và `stable`, kiểm tra commit concurrent, rồi đọc lại target file/caller trên đúng HEAD mới nhất. Không force push và không rewrite shared history.

TUYỆT ĐỐI không patch chồng patch. Nếu local/runtime test hoặc tôi xác nhận một commit fix không giải quyết được lỗi, phải revert commit/change-set fix không hiệu quả đó trước, khôi phục baseline tốt gần nhất, phân tích lại root cause rồi chọn hướng triển khai khác. Nếu commit chứa cả thay đổi concurrent không liên quan thì revert chính xác phần change-set thất bại bằng một commit riêng; không được giữ workaround sai rồi bồi thêm workaround thứ hai.

Không được coi GitHub Actions là bằng chứng release cuối cùng. Authoritative gate là `bash scripts/validate-maintainer-local.sh` và live-test Niri/Quickshell trên exact candidate SHA. Không nói release/runtime đã pass nếu chưa có kết quả local tương ứng.

Các invariant phải giữ:
- physical Screen Edge geometry trong `ScreenEdges.qml` và normal ii Bar/VerticalBar perimeter đang locked; không tạo wedge/corner/contact patch renderer mới;
- normal ii connected popups dùng `modules/bar/StyledPopup.qml` + `modules/common/perimeter/ConnectedSurface*` + `PerimeterTokens.qml`; không dựng popup framework thứ hai;
- broad legacy perimeter runtime/cutover đã retire; không dựng lại;
- Material là Global Theme public duy nhất; migration shim chỉ được normalize legacy state về Material;
- Waffle vẫn là panel family riêng được support;
- ThinkFan phải reuse `ThinkFanService` + helper/polkit hiện có, không tự tạo backend/config fan thứ hai;
- Local Music dùng MPD/mpd-mpris/MPRIS làm backend hiện hành; không thêm player backend cạnh tranh.

Việc còn mở:
1. Xác nhận shell boot sạch sau fix Code Workflow Binding lifecycle; không còn `Type ... unavailable` hoặc duplicate identifier.
2. Fix dứt điểm Settings task-tab indicator: expand/collapse Headings vẫn làm indicator nhảy xuống dưới; fix trước chưa được accept, không patch chồng lên nó.
3. Live-validate System Monitor popup refinement: CPU Load đổi giữa 1/2 chữ số không còn làm popup co giãn; RPM/Level icon và alignment đúng.
4. Live-validate connected surfaces Popup/Sidebar/Dashboard/Settings/OSK: đúng edge, không gap, outward contact geometry, hover/retract, fractional scale và multi-output.
5. Validate Screen Edge/Bar lifecycle: idle/maximized, width/radius/shadow, auto-hide, fullscreen enter/exit, lock/unlock.
6. Live-test Local Music Stop -> chờ lâu -> Play, bulk selection/Play Selection/Add to Queue, queue ops, Shuffle/Repeat/CAVA trên mọi media surface; validate CAVA + EasyEffects DSP lifecycle.
7. Live-validate Dashboard mapped warm reopen + smooth motion: không rebuild widget tree; surface vẫn mapped nhưng input rỗng/render sleep khi đóng; mở 32px/360ms `OutCubic`, đóng 260ms `InCubic`, không opacity/scale fade và không whole-surface motion FBO. Dashboard Media phải giữ PlayerControl/artwork/palette/mask resident, không chớp cyan/blank hay biến mất trong slide; CAVA/Equalizer chỉ ngủ sau khi exit slide kết thúc.
8. Validate Calendar/Weather responsive layout và wheel/slide behavior.
9. Validate ThinkFan/TLP helper/polkit/profile sync/uninstall ownership trên hardware thật.
10. Tiếp tục audit active-tree Material-only residue ngoài migration compatibility.
11. Chạy canonical local validator + Niri live smoke trên exact candidate SHA; Hyprland chỉ cần compatibility smoke.

Sau mỗi nhóm thay đổi: refetch trước write, giữ commit atomic, cập nhật README chỉ với việc còn mở, xác nhận HEAD sau commit và báo root cause/goal, file đổi, SHA, source contract và phần local/runtime validation còn lại.
```
