# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-25
>
> **Current `dev` snapshot (2026-09-25):**
> - The qualified **Rust native workspace is the production backend**. `inir-native`, `inir-inputd`, `inir-mpdd` and `inir-theme` are built/shipped by supported install paths; Python implementations remain an explicit rollback/fail-soft path rather than the default selector.
> - **Runtime Diagnostics is implemented as a production MVP**, not a research-only plan. Material and Waffle Settings share the same compact dashboard, main-shell evidence transport and demand-driven lease/session lifecycle.
> - **Release-blocker sections A–G are maintainer-accepted as complete** and are no longer active checklist items.
> - **H. Legacy/compatibility cleanup is the only remaining lettered v1.0 blocker.**
> - **Material is the only public shell-wide Global Theme**; Waffle remains a supported independent panel family, not a legacy theme/runtime.
> - The canonical local validator and final live Niri/Quickshell smoke pass still apply to the exact release candidate as the global release gate.

## 1. Source-of-truth and workflow

Requirement precedence:

1. the maintainer's newest explicit instruction;
2. this README's active v1.0 scope and architecture constraints;
3. the current implementation on `dev`;
4. `stable` only as a behavioral/architectural comparison baseline;
5. older docs, historical notes and retired implementation details.

Working rules:

- Work directly on **`dev`**. Do not create or switch to another branch unless the maintainer explicitly requests it.
- Refetch the latest **`dev`** before every significant audit and immediately before every write/ref update. Use `stable` only when a behavioral comparison is actually needed; never merge into or mutate `stable` as part of normal development.
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

**Maintainer workflow lock (2026-09-25):** Hadalis development is `dev`-only. Do not create feature/fix branches and do not open pull requests unless the maintainer explicitly asks for them. Refetch and re-read the latest `dev` target before every write, then commit focused changes directly to `dev`. `stable` is comparison-only unless the maintainer explicitly changes that rule.

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

- Horizontal and vertical ii Bar `PanelWindow` surfaces must remain **mapped and updating while a client is fullscreen**. Never gate Bar `visible`, `updatesEnabled` or Loader lifetime on fullscreen. The horizontal Bar may suppress its exclusive zone, paint, blur and input while `GameMode.hasFullscreenOnOutput()` is true, but the native layer surface must stay alive so exiting fullscreen cannot strand Bar contents blank.
- Niri/compositor stacking naturally covers Top-layer Bar surfaces during fullscreen. Explicitly unmapping/remapping the Bar caused a confirmed regression where Bar contents stayed blank after leaving fullscreen until Quickshell was reloaded.
- The painted Screen Edge `FrameWindow` must also remain mapped and updating across fullscreen. It shares the same Top-layer stacking domain as the Bar; destroying/recreating only the frame can remap the Bar-thick physical perimeter above `BarContent` after fullscreen exits. Niri already renders focused fullscreen clients above Top-layer surfaces.
- The four transparent Screen Edge `ReservationWindow` surfaces may still unmap during fullscreen to release their exclusive work-area reservation. This reservation lifecycle must remain separate from the persistent painted frame lifecycle.


### 1.3 Runtime Diagnostics / Quickshell btop — production MVP status (2026-09-25)

Runtime Diagnostics is now an implemented Hadalis runtime debugger rather than a planned research feature. Its purpose remains narrow: explain **Hadalis shell resource behavior and runtime activity**, not replace a general desktop process manager.

#### Production ownership and lifecycle

- `services/RuntimeDiagnostics.qml` is the main-shell sampling authority. It is passive by default and samples only while at least one valid Diagnostics lease exists.
- `services/RuntimeDiagnosticsSession.qml` owns Settings-page demand. Material and Waffle use the same owner-aware current-page contract; a cached/hidden page does not keep sampling alive.
- Remote Settings processes acquire/heartbeat/release the main-shell lease through the dedicated `runtimeDiagnostics` IPC target. Lease TTL is **6 seconds**, heartbeat is **2 seconds**, the lease table is bounded, and a crashed Settings process naturally expires.
- Sampling is **1 Hz** with a bounded **60-sample** history. Slower memory/DRM/descendant work is internally decimated so expensive process traversal is not repeated on every fast sample.
- `scripts/native-dispatch diagnostics` selects the production Rust implementation in `inir-native` by default. `scripts/runtime-diagnostics-sampler.py` remains the compatible Python fallback.
- Leaving the Diagnostics page clears live sample/history state and stops the sampler. Diagnostics must not become an always-on background monitor.

#### Evidence that is implemented

The current sampler exposes provenance-bearing evidence for:

- system CPU and per-logical-core CPU from `/proc/stat`;
- load average and uptime;
- system RAM and Swap from `/proc/meminfo`;
- Hadalis shell CPU from task `schedstat`;
- shell RSS/PSS/Swap from `smaps_rollup` with `/proc/<pid>/status` fallback;
- shell disk I/O counters/rates from `/proc/<pid>/io`;
- aggregate and per-interface network counters/rates from `/proc/net/dev`;
- shell DRM/GPU client engine activity and resident memory when `drm-fdinfo` is available;
- real Hadalis child/descendant processes with PID, parent PID, command, CPU and RSS/Swap evidence;
- Workflow runtime records/events plus source-boundary reconciliation from the shared Code Workflow index.

The kernel sampler intentionally **does not emit `targetId`, component CPU or component RAM**. Quickshell QML objects share the shell process, so Linux does not provide truthful per-QML CPU/RAM ownership.

#### Canonical identity and QML activity

`CodeWorkflowRuntime` remains the canonical identity/runtime-evidence authority. Diagnostics consumes its target catalog, records and lifecycle events rather than maintaining a second component registry.

The compact **QML activity** table is therefore lifecycle evidence only:

- resident instances;
- visible instances;
- recent lifecycle event counts.

It is explicitly labeled **“lifecycle · not CPU/RAM”**. Do not convert those counters into fake resource percentages or attach shell-process metrics to individual QML components without a reviewed attribution mechanism.

Unknown source/runtime boundaries remain discovery/coverage problems, not permission to invent a new Diagnostics identity.

#### Current Settings presentation

Both Settings families use the shared widgets under `modules/settings/widgets/` and the same `BtopDashboard.qml`:

- Material: `modules/settings/RuntimeDiagnosticsConfig.qml`;
- Waffle: `modules/waffle/settings/pages/WDiagnosticsPage.qml`.

The production compact view keeps one-viewport observability density: CPU, Memory, GPU and Network summaries; QML lifecycle activity; real shell helper processes; and a compact Hadalis runtime strip. Error provenance is surfaced explicitly for lease, bridge, evidence and sampler failures.

Presentation may continue to evolve toward the maintainer's modern observability/resource-suspects concept, but the evidence boundaries above are hard contracts. UI refinement must not reintroduce fake per-component resources, background sampling or a second identity catalog.

#### Regression coverage already in-tree

Focused contracts include:

- `scripts/test-runtime-diagnostics-session-contract.py`;
- `scripts/test-runtime-diagnostics-btop-contract.py`;
- `scripts/test-runtime-diagnostics-core-history.py`;
- `scripts/test-runtime-diagnostics-page-state.py`;
- `scripts/test-runtime-diagnostics-remote-lease.py`;
- `scripts/test-runtime-diagnostics-source-boundaries.py`;
- `scripts/test-runtime-diagnostics-sampler.py`;
- `native/scripts/check-diagnostics-parity.py`.

These contracts are source-level evidence, not a substitute for the exact-SHA maintainer validator or live desktop acceptance.

#### Remaining Diagnostics work

The old research plan included deeper Target Debug Mode, broader ownership inference and profiler-style inspection. Those ideas are **not automatically current release blockers** now that the production MVP exists. Promote them only when the maintainer explicitly makes them active scope.

Current open work is narrower:

1. refine the Settings presentation into a modern observability/resource-suspects console without breaking the truthful evidence model;
2. keep Material and Waffle presentation behavior aligned where they share Diagnostics primitives;
3. validate real sampler overhead, DRM-driver availability and stale/error behavior on the maintainer runtime;
4. preserve demand-driven lifecycle while future Workflow/runtime instrumentation evolves.

## 2. v1.0 product direction

Hadalis remains a Quickshell desktop shell built on the existing iNiR architecture. The v1.0 priority is **UI/UX quality without throwing away working iNiR behavior**.

Required direction:

- preserve existing iNiR services, state, routing, popup contents and proven interaction behavior;
- use **Caelestia as the visual/composition reference** for connected edge surfaces;
- make popups appear to grow/morph from their real source surface instead of looking like detached floating cards;
- keep keyboard focus, Escape close, outside-click close, hover transfer, multi-output ownership and compositor behavior intact;
- prefer shared fixes in existing abstractions over per-popup forks;
- **do not build a second popup framework**;
- Niri is the sole supported compositor target; do not add alternate compositor runtime paths;
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

The v1.0 Media Popup equalizer work is complete and accepted. `EqualizerService.qml` remains the single optional 10-band DSP backend/service contract with EasyEffects transport, preset curves and consumer-driven lifecycle. CAVA/EasyEffects capability handling must continue to degrade gracefully when optional dependencies are absent.

Further equalizer presentation experiments are post-v1.0/non-blocking unless the maintainer explicitly promotes them back into active scope.

## 3. v1.0 release blockers

Sections **A–G are maintainer-accepted as complete and have been removed from the active blocker list**. Do not re-open them from stale checklists or historical notes unless a new regression is observed.

The only remaining lettered v1.0 blocker is:

### H. Legacy/compatibility cleanup — P1

- [ ] Remove active reads/routes for retired renderer/style families when they no longer serve migration compatibility.
- [ ] Keep compatibility shims only where a current supported caller still needs the type/config name.
- [ ] Do not restore retired Pill/Mascot runtime behavior, historical Dock renderer families, Orbit/workspace experiments, removed Global Themes or similar dead presentation systems.
- [ ] Old persisted values must degrade safely to the supported v1.0 behavior instead of resurrecting removed renderers or themes.
- [ ] Keep Waffle separate and supported.

Exact-candidate local validation remains part of the global v1.0 definition of done even though A–G are no longer active blocker sections.

## 3.1 Latest maintainer runtime findings

Only unresolved work belongs here. A–G acceptance is complete and must not be duplicated as pending runtime findings.

- **Runtime Diagnostics UI:** the backend/session/evidence path and compact shared dashboard are source-complete. Current work is presentation refinement toward a modern observability/resource-suspects console. Preserve demand-driven sampling, main-shell measurement, explicit error provenance and the “QML lifecycle, not CPU/RAM” truth boundary.
- **Legacy/compatibility cleanup:** this is the remaining v1.0 blocker. Remove only proven-dead retired runtime/style paths while preserving narrowly required migration normalization and the independently supported Waffle family.
- **Release gate:** run `bash scripts/validate-maintainer-local.sh` plus the final Niri/Quickshell smoke pass on the exact candidate SHA before calling v1.0 release-ready.

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
- Niri-only compositor behavior and IPC contracts;
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

The qualified Rust workspace is now the **production native backend**. The canonical selector defaults to Rust, supported source/package/Nix install paths ship the native binaries, and migration `050-rust-native-default` promotes existing installs. Python implementations remain an explicit rollback/fail-soft path. Native production/parity checks and benchmark history are documented in [native/README.md](native/README.md), but they do not replace this repository-wide gate or live desktop validation.

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
- [ ] Niri full compositor/runtime pass.
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

## 11. Current unfinished handoff (2026-09-25)

This section contains **unfinished work only**. Maintainer-accepted A–G work is complete and intentionally absent.

1. **Runtime Diagnostics presentation:** keep the implemented lease/session/native-evidence architecture and refine the Settings surface toward the agreed modern observability/resource-suspects console. Do not add background sampling, a second component catalog or fake per-QML CPU/RAM.
2. **Legacy/compatibility cleanup (H):** continue the active-tree caller audit and remove only proven-dead retired renderer/style routes. Preserve narrow migration normalization and keep Waffle fully supported.
3. **Release validation:** run the canonical maintainer validator plus the final Niri/Quickshell smoke pass on the exact candidate SHA.

**Failure-handling requirement:** do not fix a failed fix with another patch on top. Once a change is demonstrated ineffective, revert that failed change first (or surgically revert its exact change set when unrelated concurrent work shares the commit), then re-investigate and implement a materially different root-cause fix.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Làm trực tiếp trên branch `dev`; không tạo branch/PR mới và không merge/chỉnh `stable` trừ khi tôi yêu cầu rõ ràng. Trước mỗi audit quan trọng và ngay trước mọi write/ref update, refetch HEAD mới nhất của `dev`, rồi đọc lại target file/caller để tránh overwrite thay đổi concurrent. Fix forward, không force-push/rewrite shared history.

Không patch chồng patch. Nếu runtime evidence/regression test xác nhận một fix không hiệu quả, revert fix/change-set đó trước rồi điều tra lại root cause.

Baseline hiện tại:
- Rust native workspace là production backend mặc định: `inir-native`, `inir-inputd`, `inir-mpdd`, `inir-theme`; Python chỉ là rollback/fail-soft path.
- Runtime Diagnostics đã có production MVP: demand-driven lease/session, main-shell sampling, Rust diagnostics mặc định + Python fallback, CPU/RAM/Swap/GPU/Network + real child processes, Workflow identity/lifecycle evidence, shared compact Material/Waffle dashboard.
- Diagnostics tuyệt đối không được giả per-QML CPU/RAM; QML activity chỉ là resident/visible/lifecycle events.
- Material là Global Theme public duy nhất; legacy values chỉ được normalize, không revive renderer cũ.
- iRiS connected surfaces là production baseline; physical Screen Edge/normal ii Bar geometry đang locked.
- Waffle là panel family riêng được support đầy đủ, không phải legacy.

Ưu tiên unfinished hiện tại:
1. refine Diagnostics thành modern observability/resource-suspects console mà không phá truth/lifecycle contracts;
2. hoàn tất H. Legacy/compatibility cleanup bằng caller audit, chỉ xóa code retired đã chứng minh không còn caller; giữ migration normalization cần thiết và Waffle;
3. chạy `bash scripts/validate-maintainer-local.sh` và final Niri/Quickshell smoke test trên exact candidate SHA.

A–G đã được maintainer xác nhận hoàn tất và đã xóa khỏi active release-blocker list; không resurrect chúng từ checklist/docs cũ trừ khi xuất hiện regression mới.

Không coi GitHub Actions hay source-only test là bằng chứng release cuối cùng.
```
