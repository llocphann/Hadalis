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
> - **Material is the only public shell-wide Global Theme**. Legacy persisted theme/style values are migration input only and must normalize to supported Material behavior rather than reactivate retired renderers.
> - The **iRiS connected-surface migration is the production baseline** for ii connected presentation. Full `iiPerimeter` composition ownership remains a separate guarded cutover boundary.
> - **Waffle remains a supported independent panel family** and must not be removed or treated as legacy during ii cleanup.
> - Source/contract completion is not the same as release acceptance: runtime-sensitive gates still require the canonical local validator and live Niri/Quickshell checks on the exact candidate SHA.

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

## Equalizer implementation status

### Implemented

`EqualizerService.qml` provides the Phase 1 backend/service contract and is disabled by default. It owns the optional 10-band DSP state, EasyEffects transport boundary, preset curves and consumer-driven lifecycle without creating a second equalizer backend.

### Stabilizing

The existing backend is being stabilized around transport probing, EasyEffects lifecycle changes, state synchronization and live visual/audio validation in the Media Popup. These are hardening tasks; they do not imply that the open release gates below have already passed.

### Planned

Further equalizer presentation experiments are planned/deferred rather than current release prerequisites. The v1.0 release-blocker list below remains the authority for required source and live validation.

## 3. v1.0 release blockers

Checkboxes below are **release gates**, not an assertion that no partial implementation exists. A line explicitly labeled **source-complete** may be checked once its source/contract work is complete; runtime-sensitive acceptance remains open until the relevant local/live validation passes.

> **Current release status (2026-09-25):** current `dev` has the production Rust cutover, Material-only public Global Theme boundary, iRiS connected-surface baseline, ThinkFan integration, compact System Monitor refinements, current Calendar/Weather composition and the existing media/equalizer implementation. Rust/native has dedicated parity/contract coverage. Remaining release work is primarily live desktop acceptance, hardware/compositor validation, the known Settings/navigation defect, final active-tree residue cleanup, and exact-candidate validation. Historical implementation sequences belong in Git history / `CHANGELOG.md`, not in this active checklist.

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

**Source-complete on current `dev`:**

- [x] Public Settings/Welcome/GlobalActions Global Theme selection is Material-only.
- [x] `Appearance.globalStyle` is runtime-clamped to `material`; legacy persisted values cannot reactivate alternate shell-wide renderers.
- [x] Retired Bar renderer families and Dock style families are absent from the live runtime graph; Dock compatibility converges to `panel`.
- [x] Legacy UI locale/style compatibility is normalization-only rather than an alternate runtime path.
- [x] Material-only regression guards cover Settings, global-style routing and public documentation contracts.

**Release acceptance still open:**

- [ ] Run a final active-tree residue audit and remove any remaining live non-Material Global Theme branch/asset/doc reference that is not required by a current supported caller or migration shim.
- [ ] Validate Material rendering across Bar, Screen Edge, connected popups, Sidebars, Overview, Settings and Waffle on the exact release candidate.

### H. Legacy/compatibility cleanup — P1

- [ ] Remove active reads/routes for retired renderer/style families when they no longer serve migration compatibility.
- [ ] Keep compatibility shims only where a current supported caller still needs the type/config name.
- [ ] Do not restore retired Pill/Mascot runtime behavior, historical Dock renderer families, Orbit/workspace experiments, removed Global Themes or similar dead presentation systems.
- [ ] Old persisted values must degrade safely to the supported v1.0 behavior instead of resurrecting removed renderers or themes.
- [ ] Keep Waffle separate and supported.

## 3.1 Latest maintainer runtime findings

Only unresolved runtime findings belong here. Remove an item after the maintainer accepts the fix on the target desktop instead of retaining completed history.

- **Rust production backend:** source cutover is complete. Rust is the default selector and supported install/package paths ship `inir-inputd`, `inir-mpdd`, `inir-native` and `inir-theme`; Python remains explicit rollback/fail-soft compatibility. Do not treat benchmark selector state as the production contract.
- **Settings navigation indicator:** still unresolved. Expanding/collapsing **Headings** can make the active task-tab indicator jump downward. The previous attempt is not accepted; re-audit/replace the failed geometry or lifecycle approach rather than stacking another workaround.
- **System Monitor popup refinement:** source-side two-digit CPU Load width reservation and RPM/Level Material icons are present; live-validate that one/two-digit CPU changes no longer resize the popup and fan metrics remain aligned/readable.
- **Shell boot integrity:** the installed/runtime shell must remain free of `Type ... unavailable`, duplicate-identifier and singleton-construction failures on the exact candidate.
- **Connected-surface acceptance:** Popup, Left/Right Sidebar, Dashboard, Settings, Dock and OSK still require live Niri validation for contact geometry, seam/gap behavior, edge ownership, hover transfer/retract, fractional scale and multi-output.
- **Screen Edge / Bar lifecycle:** validate idle/maximized visibility, width/radius/shadow settings, auto-hide ownership and fullscreen enter/exit without stranded or blank Bar content.
- **Music/media:** validate Local Music Stop -> long idle -> Play, bulk folder/track selection, queue operations and unified Shuffle/Repeat/CAVA behavior. CAVA/EasyEffects DSP lifecycle still needs live audio/player-switch/reopen validation.
- **Dashboard/Overview:** ii Overview now releases its heavy multi-output tree after the configured exit animation plus a small safety grace instead of inheriting the five-minute retained-surface cache; Dashboard keeps its separate mapped-retained contract. Live-validate Overview cold open/reopen and Dashboard/Overview motion without the rejected whole-Dashboard scene-graph cache; artwork/controls must not flash cyan, rebuild or disappear during open/close.
- **Heavy panel residency:** the generic five-minute `retainAfterUse`/`retainIdle` policy has been removed from both ii and Waffle on-demand loaders. Surfaces now use finite close grace tied to their visible exit lifecycle, while ii Dashboard keeps its separate explicit `keepLoaded || used` mapped-residency contract. Overview, Waffle Action Center, Clipboard, Wallpaper Launcher and Coverflow therefore release their expensive trees promptly after closing; Waffle Start Menu and grid WallpaperSelector already self-unload their inner windows and no longer keep even the outer wrapper alive for five minutes. The current source lifecycle pass found no further retained heavy tree that justifies a source-only residency change.
- **Recorder polling lifecycle:** global external `wf-recorder` detection keeps the existing slow 15s/30s safety probe when no recorder UI needs immediacy. Visible/pinned ii Recorder controls and the open Waffle Widgets recorder action temporarily request 1s reconciliation, while the existing bounded 350 ms action quick-check remains the fastest path after shell-issued start/stop commands. The retained ii Overlay recorder pulse also sleeps whenever that widget is hidden, so an active recording does not keep an invisible animation running. This preserves external-recorder correctness without restoring permanent fast polling.
- **Retained Overlay lifecycle:** the ii Overlay remains intentionally mapped after first use for pinned-widget behavior, but hidden retained visuals now sleep explicitly: the Angel taskbar releases its wallpaper source, mask and blur layers after the exit fade; Floating Image pauses animated-image playback and its mask FBO while hidden; and the Resources graph mask FBO is enabled only while the widget/native Overlay window is visible. This keeps the retained interaction/state contract without paying invisible rendering/decoder work.
- **Local Music fallback polling:** native MPD subscription remains the preferred event path. If that subscription is unavailable, status fallback stays responsive at 900 ms while the left sidebar is open, drops to 30 s while hidden, and refreshes immediately on reopen; this removes the previous process-spawn loop that could run every 900 ms for the whole session.
- **Calendar/Weather:** validate responsive Calendar interaction and the fixed-footprint two-tab Weather wheel/slide behavior across supported scaling.
- **ThinkFan/TLP:** validate installed helper/polkit reconciliation, profile-follow synchronization, active-session authorization and uninstall ownership on maintainer hardware.
- **Material-only cleanup:** the public/runtime boundary is source-complete; only intentional migration compatibility may remain. Finish the final active-tree residue audit and live visual acceptance before closing the gate.
- **Performance lifecycle source gate:** current `dev` has completed the source-only pass across on-demand residency, retained Dashboard/Overlay work, recorder polling, media/CAVA ownership, Local Music fallback polling, Screen Time, privacy/PipeWire state and periodic service probes. No additional high-impact lifecycle patch is justified from source inspection alone; remaining acceptance is runtime/environment-dependent.
- **Power-profile ownership polling:** the always-live `PowerProfilePersistence` no longer spawns a `systemctl` ownership probe every five minutes while idle. A 30-minute safety probe covers silent package/service changes, while any relevant profile change demand-refreshes ownership once the cached result is older than five minutes before persisting state. This preserves the previous freshness bound when correctness matters while cutting idle ownership probes from 12/hour to 2/hour.
- **Memory-pressure monitoring:** the always-instantiated `MemoryPressureService` now reads `/proc/self/maps` directly through Quickshell `FileView` and parses JSGCHeap mappings in-process. The five-minute cadence, thresholds, IPC and notification behavior are unchanged, but the old `sh + grep` helper spawn is eliminated on every sample (12 child-process launches/hour avoided while monitoring is enabled).
- **Keyboard sysfs fallback discovery:** when native evdev lock-state monitoring is unavailable, LED discovery now stays at the existing 30 s cadence only until at least one sysfs LED path is found, then backs off to a 5-minute safety scan (10 minutes in low-power mode) while `FileView` watches the known values directly. If a watched path disappears, discovery is re-triggered immediately. Stable fallback sessions therefore cut discovery shell spawns from up to 120/hour to 12/hour without slowing lock-state updates.
- **Icon theme enumeration:** `IconThemeService.ensureInitialized()` no longer runs `find` across system/user icon directories during shell startup. Theme enumeration is now triggered only when `IconThemeSelector` is actually opened and is cached for the session; current-theme restore and GTK/KDE/Qt synchronization semantics are unchanged.
- **Shell-update startup freshness:** successful remote fetches now persist a lightweight timestamp. Automatic startup checks within the fresher of the configured interval or 30 minutes rebuild update state from the already-fetched `origin/*` refs instead of issuing another network fetch; manual checks and the normal periodic timer still fetch immediately. This removes redundant git/network work during quick restarts and development hot-reload cycles without weakening explicit freshness requests.
- **Scheduled-theme wakeups:** theme scheduling no longer polls once per minute. It applies immediately when scheduling/config changes, computes the next day/night boundary, then arms a single-shot timer directly to that transition and re-arms afterward. Normal schedules drop from 60 scheduler wakeups/hour to roughly two transition wakeups/day, while switches happen at the configured boundary instead of up to a minute late.
- **Shell-update startup process churn:** startup metadata reads for `version.json`, `.inir-manifest`, and `VERSION` now use in-process `FileView` reads instead of spawning `cat`/bash pipelines. The update-resume helper is also gated by a direct status-file read, so the expensive staleness process is not launched on normal starts with no update in progress. Git commands remain unchanged because they provide repository state rather than plain file I/O.
- **ThinkFan adaptive status polling:** `ThinkFanService` keeps the existing 30-second cadence while ThinkFan is active/busy, but profile-follow-only sessions now fall back to a five-minute safety poll. Power-profile and fan-config changes remain event-driven and demand-refresh helper status whenever the cached result is older than 30 seconds before applying configured fan intent, preserving responsive correctness without a permanent 120 status-process launches/hour in the idle profile-follow case.
- **Voice-search lazy backend discovery:** `VoiceSearch` still instantiates at Tier 3 so its IPC target is always available, but it no longer launches the Python local-backend probe or loads keyring data just because the shell started. Backend discovery begins only when a configured voice toggle, AI/voice settings page, AiChat dictation surface, manual refresh, or IPC start/toggle actually needs it; first-use recording waits for both the probe and keyring before proceeding.
- **System-update single-process probing:** `Updates` no longer launches a separate `/bin/sh -c 'command -v checkupdates'` helper before every availability retry. The real `checkupdates` process now establishes availability on successful spawn and returns the update count in the same operation; failed spawns still fail closed, the 120-second execution watchdog remains, and periodic retries continue to detect a later pacman-contrib installation.
- **First-run marker startup I/O:** normal shell startup no longer forks `/usr/bin/test -f` just to determine whether the first-run marker exists. `FirstRunExperience` now reloads that marker through `FileView`; only a genuinely missing marker proceeds to the existing wallpaper discovery/welcome path, so normal boots lose one unconditional child-process launch without changing first-run behavior.
- **Font-sync startup deferral:** `FontSyncService` moved from Tier 3 (T+500 ms display/interaction) to Tier 4 (T+1500 ms background work). GTK/KDE font reconciliation still runs on every enabled shell start exactly as before, but its helper process no longer competes with Window Preview, Weather, Voice Search IPC registration, Cava theming and the first interactive-frame window.
- **Weather shared minute clock:** Weather sun progress, sun state and moon age now depend on the shared `DateTime.clock.minutes` signal instead of owning another 60-second timer. The dependency is conditional on Weather being enabled, so disabled Weather remains asleep while enabled Weather keeps the same minute-level freshness with one fewer timer wakeup source.
- **DateTime uptime shared clock:** uptime formatting no longer owns a second always-running 60-second timer. `/proc/uptime` is refreshed once at singleton creation and then from the existing `SystemClock.minutes` signal, preserving minute-level freshness while removing another global timer source.
- **TLP RDW capability probe:** runtime RDW detection now checks `/usr/bin/tlp-rdw` executability and `NetworkManager-dispatcher.service` enablement in one bounded helper process instead of a two-process chain. The 30-minute safety cadence and 5-second timeout remain unchanged, but each successful RDW refresh now launches one child process instead of two.
- **GameMode state persistence:** manual GameMode state now writes through an atomic `FileView` with a coalesced last-write queue, using the shared `Directories.stateUserPath`. This removes the duplicate `mkdir` process from every GameMode startup and the bash/echo helper from every manual toggle/activate/deactivate while preserving rapid-toggle persistence semantics.
- **Directory bootstrap consolidation:** `Directories` no longer launches fourteen detached `rm`/`mkdir` commands during singleton construction. Transient trees are cleaned first and all required state/cache directories are then recreated by one ordered bootstrap command, cutting startup process fan-out sharply and removing the old cleanup/recreate race between independently detached commands.
- **Directory bootstrap argument fix:** the consolidated bootstrap now forwards the full `$5..$14` creation set, including `userActions`, and the regression guard locks the complete argument span so a required directory cannot silently fall out of the batch.
- **Directory bootstrap positional fix:** Bash positional parameters above nine now use `${10}`…`${14}` explicitly; this prevents high-index directory arguments from being mis-expanded as `$1` plus a digit while preserving the single ordered bootstrap process.
- **TLP demand-driven refresh:** `TlpRuntimeCapabilities` and `TlpSettingsService` now use a 30-minute background safety cadence instead of permanent five-minute polling after first use. Both Material and Waffle TLP pages refresh capabilities/status immediately once per visible session, while apply/reset/status paths keep their existing direct refresh behavior. This cuts hidden TLP helper wakeups from 12/hour to 2/hour per singleton without making the settings UI stale when reopened.
- **Conflict detection startup fan-out:** `ConflictKiller` now uses one `/proc/*/comm` probe to classify `kded6`, `mako`, and `dunst` conflicts instead of launching separate `pidof` helpers. Auto-kill and dialog behavior are unchanged, while startup conflict detection drops from two helper processes to one.
- **Todo/Notepad first-use loading:** Tier 4 no longer force-instantiates `Todo` and `Notepad`. Neither singleton owns an IPC/background obligation; forcing them only started storage reads, file watches and Todo backend setup on sessions that may never open those surfaces. Existing widgets/actions still instantiate the same singletons on first demand, while `ShellUpdates`, `Autostart` and `CalendarSync` remain eagerly initialized for their real background contracts.
- **Font-sync file churn:** startup font reconciliation remains enabled so GTK/KDE settings can recover from external edits, but the helper now compares generated GTK/xsettings content with the existing file before doing the atomic replacement. Already-correct files no longer get rewritten just because the shell restarted, avoiding needless disk writes and downstream file-watch churn without weakening drift correction.
- **Maintainer validation repair pass:** the source/test regressions reported by the `2c4bee3d` validation run have been reconciled with the current Dashboard/iRiS/notification/media/settings architecture, and Window Preview predecode now refuses IDs without an existing cached snapshot. Re-run the maintainer validator on the new SHA; strict QML parsing still requires a real Qt `qmlformat >= 6.8` on the validation host.
- **Maintainer validation follow-up:** the next local run reached 154/160 checks with only five source/regression failures plus the known host `qmlformat 1.0` capability failure. The five remaining failures were stale assertions around Dashboard formatting, shared popup radius ownership, safe Notepad tab deletion, Window Preview eager predecode accounting and the conditional workspace hover timer; those contracts are now aligned with the live source and require one final validator rerun.
- **Maintainer validation convergence:** the following local run reached 155/160 checks; the four remaining source/regression failures were stale contracts for adaptive Dashboard task height, SysTrayMenu's shared StyledPopup ownership, shared Quick Notes settings routing, and Window Preview's FileView-backed session-marker migration. Those contracts are now aligned; the only expected remaining validator failure is the host `qmlformat 1.0 < 6.8` capability check, pending a final rerun.
- **Maintainer validation near-clean pass:** validation on `ff99c119` reached 157/160 checks. The only source-side failures were two stale assertions: DashCard still expected the retired `colSurfaceContainerHigh` token instead of the current shared `colLayer1` surface, and VerticalBar simultaneously forbade and required the retired `showBarBackground` flag. Both contracts are now aligned without changing runtime visuals; rerun once more to confirm that only the host `qmlformat 1.0 < 6.8` capability gate remains.
- **Maintainer validation source-clean candidate:** validation on `3d385ea8` reached 158/160 checks. The sole remaining source regression was a stale WeatherBar literal-color assertion after the component moved to an orientation-aware `foregroundColor` (`colOnLayer0` vertically, `colOnLayer1` horizontally). The contract is now aligned without changing runtime behavior; the only expected remaining failure is the host `qmlformat 1.0 < 6.8` capability gate.
- **Maintainer validation final contract candidate:** validation on `5ef5e049` again reached 158/160 checks. The sole source-side failure was a stale BarMediaPopup contract that still required outer `colLayer0`/border/text chrome even though `modules/bar/Media.qml` now owns that connected surface through shared `StyledPopup`; BarMediaPopup remains the content plane. The contract is now aligned without changing runtime visuals. A final rerun should leave only the host `qmlformat 1.0 < 6.8` capability failure.
- **Maintainer validation parser/runtime follow-up:** validation on `78e95974` reached 159 passing checks with one stale BarTaskbarWindowPreview conditional-color assertion and one strict parser capability failure because the host exposed qmlformat's tool version but no Qt version via qtpaths/qmake. The preview contract now follows its hover error/subtext mapping, and Qt runtime detection also falls back to the sibling `qml --version` runtime without lowering the Qt 6.8 requirement.
- **Maintainer validation detector hardening:** validation on `02615551` ran 161 checks and exposed three remaining validation-side issues: SettingsOverlay still referenced the retired `overlaySearchResultsOverlay`/inner surface color contract, the Qt detector regression test leaked the host `qml` runtime, and strict capability probing still could not identify Qt from qmlformat alone. The Settings contract now follows `overlayLiveSearch` plus transparent inner content, the detector test is hermetic, and Arch package ownership is a final Qt-version fallback without lowering the Qt 6.8 gate.
- **Maintainer validation final-detector follow-up:** validation on `a4c9b9ff` still had three validation-side failures: standalone `settings.qml` retained retired root/search-result assertions, the detector's negative test could still see absolute host QML tools, and Arch package ownership was queried after canonicalizing the qmlformat path. The contract now follows `windowBaseSurface` + shared `SettingsLiveSearchResults`; detector tests disable system fallbacks; and `pacman` ownership uses the original invoked qmlformat path before canonical fallback.
- **Maintainer validation direct-parser follow-up:** the next validation on `b353504c` reached CHECK 113 before the uploaded log was truncated. Two failures were visible before truncation: the compact right-sidebar contract still expected retired `IslandPanel`/`ClassicQuickPanel`/notification-history actions, and strict parser capability still stopped when qmlformat's Qt version metadata was unavailable. The compact contract now follows `RicelinSurface`, inline classic quick toggles and DND-only notification ownership; strict validation now permits version-unknown qmlformat only if it successfully parses the full project, while non-strict behavior still skips unknown parser versions.
- **Release gate:** run `bash scripts/validate-maintainer-local.sh` plus Niri/Quickshell live smoke tests on the exact candidate SHA before closing runtime-sensitive P0 gates.

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

## 11. Current unfinished handoff (2026-09-25)

This section contains **unfinished work only**. Source-complete migrations/features belong in the status sections above; completed history belongs in Git / `CHANGELOG.md`.

1. **Settings task-tab indicator:** Headings expand/collapse can still move the active indicator downward. Re-audit the failed geometry/lifecycle approach before making another fix.
2. **System Monitor popup:** live-validate CPU width stability and ThinkFan RPM/Level alignment.
3. **Connected surfaces:** complete live acceptance for iRiS/direct-seam contact across ii Popups, Left/Right Sidebar, Dashboard, Settings, Dock and OSK on top/bottom/left/right ownership, fractional scale and multi-output. Preserve locked physical Screen Edge/Bar geometry.
4. **Screen Edge / Bar lifecycle:** verify idle/maximized visibility, configurable width/radius/shadow, auto-hide ownership, fullscreen enter/exit, lock/unlock and output transitions without blank/stranded surfaces.
5. **Music/media:** live-test Local Music idle resume, bulk selection/queue operations and unified Shuffle/Repeat/CAVA. Validate EasyEffects DSP/CAVA lifecycle through pause/resume, player switch and reopen.
6. **Dashboard/Overview + Calendar/Weather:** finish live motion/layout/gesture smoke tests across supported scaling without reintroducing the rejected whole-surface cache or a second date/weather backend.
7. **ThinkFan/TLP:** validate helper/polkit reconciliation, profile-follow synchronization, active-session authorization and uninstall ownership on supported hardware.
8. **Material-only final audit:** public/runtime Material-only routing is in place; remove only proven-dead residue outside intentional migration compatibility, then perform live visual acceptance.
9. **Release validation:** run the canonical maintainer validator plus Niri live smoke tests on the exact candidate SHA. Rust/native source contracts do not waive this gate.

**Failure-handling requirement:** do not fix a failed fix with another patch on top. Once a change is demonstrated ineffective, revert that failed change first (or surgically revert its exact change set when unrelated concurrent work shares the commit), then re-investigate and implement a materially different root-cause fix.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Làm trực tiếp trên branch `dev`; không tạo branch/PR mới và không merge/chỉnh `stable` trừ khi tôi yêu cầu rõ ràng. Trước mỗi audit quan trọng và ngay trước mọi write/ref update, refetch HEAD mới nhất của `dev`, rồi đọc lại target file/caller để tránh overwrite thay đổi concurrent. Fix forward, không force-push/rewrite shared history.

Không patch chồng patch. Nếu runtime evidence/regression test xác nhận một fix không hiệu quả, revert fix/change-set đó trước rồi điều tra lại root cause.

Baseline hiện tại:
- Rust native workspace là production backend mặc định: `inir-native`, `inir-inputd`, `inir-mpdd`, `inir-theme`; Python chỉ là rollback/fail-soft path.
- Material là Global Theme public duy nhất; legacy values chỉ được normalize, không revive renderer cũ.
- iRiS connected surfaces là production baseline; physical Screen Edge/normal ii Bar geometry đang locked.
- Waffle là panel family riêng được support đầy đủ, không phải legacy.

Ưu tiên unfinished hiện tại:
1. sửa Settings task-tab indicator;
2. live-validate connected surfaces + Screen Edge/Bar lifecycle;
3. live-validate media/equalizer, Dashboard/Overview, Calendar/Weather và ThinkFan/TLP;
4. final Material-only residue audit;
5. chạy `bash scripts/validate-maintainer-local.sh` và live Niri/Quickshell smoke test trên exact candidate SHA.

Không coi GitHub Actions hay source-only test là bằng chứng release cuối cùng.
```
