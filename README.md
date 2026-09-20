# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-20

## 1. Source-of-truth and workflow

Requirement precedence:

1. the maintainer's newest explicit instruction;
2. this README's active v1.0 scope and architecture constraints;
3. the current implementation on `dev`;
4. `stable` only as a behavioral/architectural comparison baseline;
5. older docs, historical notes and retired implementation details.

Working rules:

- Work directly on **`dev`** unless the maintainer explicitly requests another branch.
- Refetch the latest **`dev` and `stable`** before every significant group of changes and immediately before a write that may conflict with concurrent work.
- Re-read the current target file and its caller/consumer before changing architecture.
- Do **not** create a pull request unless explicitly requested.
- Do **not** depend on GitHub Actions for the current development cycle; the maintainer performs the authoritative local test pass.
- Keep commits focused and fix forward. Do not rewrite shared history.
- **Do not stack patches on top of a failed fix.** If local/runtime tests or maintainer evidence show that a fix commit did not solve the reported defect, revert that ineffective change before trying another implementation. Prefer a dedicated revert commit; if concurrent work makes a whole-commit revert unsafe, surgically revert the exact failed change set in its own commit. Re-establish the last known-good baseline, re-investigate the root cause, then implement a different approach. Never retain a disproven workaround merely as a base for another compensating patch.
- Canonical local validator: `bash scripts/validate-maintainer-local.sh`.
- A task is not release-complete merely because code exists. Runtime-sensitive items remain open until locally validated on the intended desktop environment.

### 1.1 Fresh-chat handoff — read before editing perimeter/UI geometry

This section is the **maintainer handoff for new chat sessions**. Read it before touching Screen Edge, Bar, popup, Sidebar, Dashboard, Settings overlay or any shared perimeter primitive. If another section appears to conflict with this handoff, the maintainer's newest explicit instruction wins.

**Failed-fix rule — no patch stacking:** when a proposed fix is shown by runtime evidence, regression testing or maintainer acceptance to be ineffective, revert that fix before attempting a replacement. Do not layer a second workaround over the failed approach. Restore the last known-good behavior, identify why the previous approach failed, then implement a materially different root-cause fix. Preserve concurrent unrelated work by reverting only the failed change set when necessary.

**Frozen / do-not-touch unless the maintainer explicitly asks:**

- **Physical Screen Edge geometry is locked.** Do not redesign, refactor or "clean up" `modules/screenCorners/ScreenEdges.qml` while working on Popup/Sidebar/Dashboard. The accepted model is one full-screen `FrameWindow`, one odd-even `ShapePath`, four circular `PathArc` corners and transparent reservation windows only.
- **Normal ii Bar/VerticalBar perimeter geometry is locked together with Screen Edge.** Do not add Bar-local `RoundCorner`, `PathArc`, rectangle, wedge, contact patch, shadow band or fallback geometry. Bar position top/bottom/left/right is represented only by changing the matching inner-frame inset to Bar/VerticalBar thickness inside the existing Screen Edge frame.
- The only approved curvature control for that physical perimeter is `appearance.screenEdge.radius` through `PerimeterTokens.frameRadius` (default **25px**, supported range **0–96px**).
- `appearance.screenEdge.physicalShadow` is the public Screen Edge depth control and is shared by the physical frame plus ii Bar `StyledPopup` shadows. The older `appearance.screenEdge.shadow` key remains only for non-Bar connected bodies such as Sidebar/Dashboard/Settings/OSK.
- Auto-hide behavior is also frozen for current geometry work: when ii Bar auto-hide is enabled, Bar relinquishes physical-edge ownership back to `ScreenEdges.qml`. Do not reintroduce `autoHideScreenEdge` or another Bar-local physical edge.
- Waffle is a separate supported panel family. Do not change Waffle geometry as a side effect of ii perimeter work.

**Connected-surface policy — legacy round-wedge geometry retired:**

- **Physical Screen Edge geometry remains locked** to the single full-screen odd-even frame below.
- ii Bar popups keep the production iRiS SDF union through `StyledPopup`.
- Sidebar, Dashboard and Settings use `ConnectedSurfaceIrisEdgeSurface`, which adapts their real body rectangle to the same iRiS field without a standalone wedge/corner helper.
- Dashboard-owned Applications Search inherits the Dashboard `ConnectedSurfaceIrisEdgeSurface`; the embedded `SearchWidget` must not paint a second field. Dock and OSK are direct edge-attached bodies with square owner seams and the same slide-only `SurfaceMotion`; standalone/non-cutover Search and current Waffle bodies also keep direct square joined edges without auxiliary endpoint wedges.
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

## 3. v1.0 release blockers

Checkboxes below are **release gates**, not an assertion that no partial implementation exists. Check an item only after source review and the relevant local/runtime validation.

> **Current release status (2026-09-20):** completed source-side work is removed from this README once it is no longer active work; historical implementation detail belongs in Git history / `CHANGELOG.md`. The release gates below remain open until their required source audit and authoritative local/runtime validation are complete. Current `dev` already contains the source-side Dashboard/Search crossfade, SongRec geometry cleanup, redesigned Dashboard System Monitor, horizontal Available Modules row, Local Music stop/resume fallback, unified media controls/CAVA work, connected-surface/iRiS implementation, Material-only public theme boundary, ThinkFan integration and broad legacy perimeter-runtime removal. Those implementations are not repeated as completed tasks below; only unresolved validation or cleanup work remains listed.

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

- [ ] The bar-attached Media Popup renders the existing **CAVA -> `PlayerControl` -> `WaveVisualizer`** path instead of an empty visualizer input.
- [ ] The same Media Popup includes a **10-band DSP Equalizer** below the player card, using the existing optional `EqualizerService` / EasyEffects backend rather than a second ad-hoc equalizer process. User-facing bands are 31/63/125/250/500/1k/2k/4k/8k/16k Hz with the Serpantinum Flat/Bass/Treble/Vocal/Pop/Rock/Jazz/Classic curves.
- [ ] Confirm the required CAVA runtime/package is present in the supported install/package paths, or document/install it where currently missing. EasyEffects + socat remain optional capabilities and must degrade gracefully when absent.
- [ ] Visualizer/equalizer lifecycle is efficient: start only when needed, stop when unused, and survive pause/resume, player switching and popup close/reopen.
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

- **Shell boot integrity:** the duplicate `bindingPhase` declaration in `CodeWorkflowTransaction.qml` has a source fix, but the installed/runtime shell must still be updated and confirmed to start without `Type ... unavailable`, duplicate-identifier or Code Workflow singleton construction failures.
- **Connected-surface acceptance:** Popup, Left/Right Sidebar, Dashboard, Settings and OSK still require live Niri validation for outward contact geometry, no seam/gap, correct edge ownership, hover transfer/retract and fractional-scale/multi-output behavior. If a visual fix fails acceptance, revert it before trying a different geometry strategy.
- **Screen Edge / Bar lifecycle:** validate idle/maximized visibility, width/radius/shadow settings, auto-hide ownership and fullscreen enter/exit without stranded or blank Bar content.
- **Music/media:** validate Local Music Stop -> long idle -> Play, bulk folder/track selection, Play Selection/Add to Queue, and unified Shuffle/Repeat/CAVA behavior across popup/sidebar/dashboard. CAVA and EasyEffects DSP lifecycle still need live audio/player-switch/reopen validation.
- **Dashboard/Overview:** validate that SongRec no longer leaves stray geometry, the first mapped Dashboard frame performs the same bottom-owner slide as later opens, Dashboard <-> Applications uses a debounce-aware fade-through as one visual surface without a blank intermediate model/height bounce, the redesigned System Monitor remains readable at compact sizes, Available Modules stay horizontal with overflow scrolling instead of vertical stacking, and Niri Overview drag/drop moves only the captured window while preserving the currently focused workspace across A -> B -> A reverse drags.
- **Calendar/Weather:** validate responsive Calendar sizing/event interaction and the fixed-footprint two-tab Weather wheel/slide behavior across supported scaling.
- **ThinkFan/TLP:** validate the installed helper/polkit bridge, profile-level synchronization, promptless active-session authorization and uninstall ownership on the maintainer's hardware.
- **Material-only cleanup:** run a fresh active-tree residue audit and remove remaining live non-Material Global Theme branches/assets/docs outside intentional migration compatibility.
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

## 11. Current unfinished handoff (2026-09-20)

This section contains **unfinished work only**. When an item is source-complete *and* its required local/runtime acceptance has passed, delete it from this section rather than leaving a checked task or a historical implementation narrative.

1. **Boot integrity:** update/reload the maintainer runtime and confirm the Code Workflow Binding lifecycle fix eliminates the startup crash chain through `CodeWorkflowTransaction -> CodeWorkflowSession -> CodeWorkflowRuntime -> CodeWorkflowPicker`. Any new boot blocker takes precedence over visual polish.
2. **Connected surfaces:** complete live acceptance for iRiS/direct-seam contact geometry across normal ii Popups, Left/Right Sidebar, Dashboard, Settings, Dock and OSK on top/bottom/left/right ownership, fractional scale and multi-output. Preserve the locked physical Screen Edge/Bar geometry.
3. **Screen Edge / Bar lifecycle:** verify idle/maximized visibility, configurable width/radius/shadow, auto-hide ownership, fullscreen enter/exit, lock/unlock and output transitions without blank or stranded surfaces.
4. **Music/media:** live-test Local Music Stop/resume after long idle, bulk selection actions, queue operations and the unified Shuffle/Repeat/CAVA surfaces. Validate the 10-band EasyEffects DSP and CAVA lifecycle through pause/resume, player switching and reopen.
5. **Dashboard/Overview:** visually accept SongRec geometry cleanup, Dashboard <-> Search Applications crossfade, the redesigned System Monitor, the horizontal Available Modules row including narrow-width overflow behavior, and Niri Overview window drag/drop with exact-window ownership and focus-stable A -> B -> A reverse moves.
6. **Calendar/Weather:** finish responsive layout and gesture/transition smoke tests without introducing a second date/weather backend or screenshot-specific geometry.
7. **ThinkFan/TLP:** validate installed helper/polkit reconciliation, profile-follow synchronization, active-session authorization and uninstall ownership on supported hardware.
8. **Material-only cleanup:** continue the active-tree residue audit outside intentional migration shims; remove live non-Material theme branches/assets/docs only when their callers are proven dead.
9. **Release validation:** run the canonical local validator plus Niri live smoke tests on the exact candidate SHA; keep Hyprland as a compatibility smoke pass.

**Failure-handling requirement:** do not fix a failed fix with another patch on top. Once a commit is demonstrated to be ineffective, revert that failed change first (or revert only its exact change set if unrelated concurrent work shares the commit range), then investigate and implement a different root-cause approach.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Đọc `README.md` trên branch `dev` trước vì đó là development contract + handoff hiện tại. Làm trực tiếp trên `dev`, không tạo PR trừ khi tôi yêu cầu. Trước mỗi nhóm thay đổi quan trọng và ngay trước mỗi write có khả năng conflict, phải refetch cả `dev` và `stable`, kiểm tra commit concurrent, rồi đọc lại target file/caller trên đúng HEAD mới nhất. Không force push và không rewrite shared history.

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
2. Live-validate connected surfaces Popup/Sidebar/Dashboard/Settings/OSK: đúng edge, không gap, outward contact geometry, hover/retract, fractional scale và multi-output.
3. Validate Screen Edge/Bar lifecycle: idle/maximized, width/radius/shadow, auto-hide, fullscreen enter/exit, lock/unlock.
4. Live-test Local Music Stop -> chờ lâu -> Play, bulk selection/Play Selection/Add to Queue, queue ops, Shuffle/Repeat/CAVA trên mọi media surface; validate CAVA + EasyEffects DSP lifecycle.
5. Visually accept Dashboard: SongRec không còn geometry thừa, Dashboard <-> Search Applications crossfade liền mạch, System Monitor layout mới, Available Modules luôn horizontal và scroll ngang khi thiếu chỗ.
6. Validate Calendar/Weather responsive layout và wheel/slide behavior.
7. Validate ThinkFan/TLP helper/polkit/profile sync/uninstall ownership trên hardware thật.
8. Tiếp tục audit active-tree Material-only residue ngoài migration compatibility.
9. Chạy canonical local validator + Niri live smoke trên exact candidate SHA; Hyprland chỉ cần compatibility smoke.

Sau mỗi nhóm thay đổi: refetch trước write, giữ commit atomic, cập nhật README chỉ với việc còn mở, xác nhận HEAD sau commit và báo root cause/goal, file đổi, SHA, source contract và phần local/runtime validation còn lại.
```
