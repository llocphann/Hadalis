# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-28
>
> **Current `dev` snapshot (2026-09-28):**
> - The qualified **Rust native workspace is the production backend**. `inir-native`, `inir-inputd`, `inir-mpdd` and `inir-theme` are built/shipped by supported install paths; Python implementations remain an explicit rollback/fail-soft path rather than the default selector.
> - **Material is the only public shell-wide Global Theme**. Legacy persisted theme/style values are migration input only and must normalize to supported Material behavior rather than reactivate retired renderers.
> - **Abyss and Waffle are the public panel families.** Material/`ii` panel values migrate to Abyss; Material remains the shared color/theme system, not a third panel family. Abyss inherits mature content and backends through one output-local liquid surface. Existing ii source is compatibility/reuse input, not permission to restore a public Material panel mode.
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

**2026-09-28 scope override:** The maintainer explicitly authorized the Abyss Screen Edge/Bar/popup rework. The historical ii geometry locks below apply to preserved ii sources, not the new Abyss field. Abyss keeps a thick, flat resting edge; optional waves, transparency and blur add presentation without replacing mature content. With these effects off, preserve the old Material layout. Waffle remains independent. Read §11–12 for current priorities.

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
- **GlobalActions setup-scan deferral:** the `globalActions` singleton remains resident at Tier 0 so IPC commands never disappear, but `scripts/setup/_scan.sh` no longer runs from `Component.onCompleted`. Setup recipe discovery is armed at Tier 3 after the first frame, and folder-change rescans stay disabled until then, removing another unconditional helper process from the critical startup window without changing action availability after deferred initialization.
- **MPRIS idle startup probing:** `MprisController` no longer runs `pw-dump` on construction when there are no application audio streams, and the `plasma-browser-integration-host`/`wtype` capability shell probe is deferred until a browser MPRIS player actually appears. Player/audio events still trigger metadata refresh immediately, while the MPD bridge startup probe remains eager because it must detect MPD sessions that bypass PipeWire via ALSA.
- **Icon-theme lazy-load runtime compatibility:** the demand-driven `ensureThemesLoaded()` path now uses an untyped default parameter (`force = false`) because the deployed Quickshell runtime rejects typed default parameters during component compilation. Enumeration remains lazy/cached; only the function signature changed, preventing the `Type annotations are not supported (yet)` startup cascade through Hyprsunset/GlobalActions/GameMode/FontSyncService.
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

## 11. Current unfinished handoff (2026-09-28)

**Current maintainer instruction supersedes the older local-only note:** GitHub-connected continuation may make atomic fast-forward commits directly on `dev` and must update this handoff at milestones. The latest maintainer request explicitly authorizes pushing unfinished checkpoints to `origin/dev` before quota exhaustion; tests are not required before those checkpoint commits/pushes. Record unrun checks and do not label an unfinished checkpoint accepted. Do not create a branch/PR, modify `stable`, rewrite history, or overwrite concurrent work. Continue in one agent context, preserve unrelated changes, and record unfinished work plus exact validation before usage becomes exhausted. Latest screenshots are defect reports, not acceptance evidence.

**Latest refinement request — 2026-09-28, after the Live Edge Editor screenshot:**

The current source baseline fetched for this continuation is `30887f08ab1caa3bdfbf1ef786ab92dee65fa0b2`, including the enabled-CAVA startup lifecycle fixes. This supersedes the earlier `beff5f8cd` checkpoint as the latest observed baseline; fetch again before every audit/write/ref update. The screenshot is a defect report, not acceptance evidence.

1. **First implementation priority: crest/ripple-only waves with breaker/whitewater.** Do not render troughs that sink the Screen Edge below its resting thickness. Round and smooth crest tips, allow taller crests and narrower bases, and remove occasional needle-shaped peaks. Add restrained breaker/whitewater at active crests. Preserve signed wave physics for same/opposite-direction interaction, but project a bounded positive crest profile into geometry/material rendering. Smooth both the sampled profile and its interpolation; avoid sharp clipping of a signed signal at zero. Reuse the shared field shader for whitewater rather than adding per-wave particles/capture/FBOs. Honor effects, shared strength, reduced motion and idle sleep; keep the no-waves resting Edge unchanged. Visual acceptance still requires recordings of isolated ripples, crossing packets, audio and strong popup emergence on all four Edges.
2. **Physical Edge thickness slider:** add a numeric px slider in Edit Abyss Layout for the selected Edge. Shared module size / Overall size are not a substitute. Preserve per-output drafts, Cancel/Done and local-versus-whole expansion for a lone module; thickness must influence inherited module sizing without breaking explicit custom sizes or body clearance.
3. **Clipboard History flickers Dashboard:** opening and closing Clipboard History must not toggle Dashboard. Trace the actual open/close ownership and focus callbacks; preserve Dashboard's prior state and clipboard interaction. Capture first/repeated open-close with Dashboard initially both closed and open before claiming a fix.
4. **IPC joins:** expose the same nearby-corner / adjacent-Edge join option for IPC targets as for module popups. Keep a persistent example while editing, save the join per kind/output, honor Cancel, and validate corner clearance, masks and readable content.
5. **Niri Reloaded popup:** migrate its shell/presentation to Abyss while retaining the mature icon, message and lifecycle. Audit the real reload IPC route, not just the generic OSD preview.
6. **Smoother ocean profile:** amplitude alone is insufficient. Qualify round, tall crests with compact shoulders, no trough erosion and readable bodies at the stronger presets; keep finite propagation, stability and resource bounds. This refines the previous ocean-scale request rather than replacing the existing interaction/strength settings.

**Additional defect reported in this continuation:**

- [ ] **Wi-Fi/Bluetooth System Tray popup text is missing.** Hover opens the shell popup, but the maintainer reports no text inside it. Check the actual embedded WifiDialog/BluetoothDialog loading, page/label visibility, foreground colors, content sizing/allocator reflow and live device/network state. Verify empty/disabled/loading states and populated lists, readable labels/actions, first hover and reopen. Preserve System Tray ownership; do not reintroduce standalone connectivity modules. The loading blocker is fixed in `134b0115a` and visible-title/native contracts pass through `2d31f06b9`; owner-session hover and populated-list visual acceptance of the report remain open.

**Refinement implementation checkpoints (a tick records implemented source; desktop acceptance is listed separately):**

- [x] **Crest/ripple projection + breaker/whitewater — `184b8336d`.** Signed physics/interference is retained; render-only five-tap smoothing, positive compact shoulders, soft height bound (up to 192 px/output limit), monotone cubic round tips, shared-texture whitewater and a numeric Custom control. Flat rest skips wave texture reads; no added particles/FBOs/timers. Changed Wave.js, WaveController, Field.frag/.qsb/.qml, Config/defaults, StyleSettings and solver regression. Focused solver and production offscreen GPU checks pass; balanced captures were inspected for rounded/positive crests. **NOT COMPLETE:** real desktop recordings, whitewater appearance/strength, all-Edge/audio/crossing presets and comparable CPU/GPU qualification remain open; no new canonical validator PASS.
- [x] **Selected physical Edge thickness slider — `3486b5d51`.** Edit Abyss Layout now has a 10–40 px slider plus Inherit surface, per-Edge/per-output draft/save/reset and inherited module sizing; explicit custom sizes stay independent. Empty/hidden Edges use the same selected resting thickness; lone-module local/whole expansion remains. Pure production layout tests pass. **Focused private-Niri Editor PASS after `134b0115a`:** actual all-four-Edge thickness/size bindings, draft-only changes, Cancel/Done, IPC preview and output merge were checked. Initial offscreen probe lacked PanelWindow backend, then native loading exposed the missing MonitorVisibilityConfig export fixed below. Physical pointer, owner-session masks/reservations and multiple outputs remain open.
- [x] **Clipboard History → Dashboard flash — `45e0d6654`.** Separate Clipboard/Overview hosts within the same Abyss field retain their own content during retraction; Clipboard no longer swaps its live Loader to Overview/Dashboard on close. Focus/input/Sidebar/Dock guards include the Clipboard host. `test-abyss-clipboard-lifecycle.sh` passes in private Niri with Dashboard initially closed and open, including repeat close/unload. Owner-session pointer/recording acceptance is still open.
- [ ] IPC nearby-Edge joins: still no fix for the requested target option/persistence.
- [ ] Niri Reloaded popup Abyss presentation: still no fix for the real IPC route.
- [x] **Wi-Fi/Bluetooth popup content load blocker — `134b0115a`; focused regression `2d31f06b9`.** Native diagnostics found `MonitorVisibilityConfig is not a type` inside Utilities, which made the shared AbyssPopupContent unavailable even for network/IPC examples. Exporting the existing settings component restores loading. Native network check now asserts visible Wi-Fi/Bluetooth titles with nonzero bounds/alpha, actual embedded forms and tray signal routing; it passes after correcting the test viewport. **Owner-hover/populated-list visual acceptance of the reported missing text remains open**, so do not infer all labels/hardware behavior are accepted.

**Latest quota checkpoint — code through `2d31f06b9857a2afdc66ace0af797e132860c754`:** focused solver/layout/GPU/private-Niri Editor/Clipboard/network checks passed in the scopes above. Evidence and development failures are saved in [docs/abyss/validation/2026-09-28-refinement](docs/abyss/validation/2026-09-28-refinement/README.md). No full canonical validator run, owner motion/input recording, multi-output/hardware acceptance or comparative profiling was performed for this descendant. HTTPS push lacked credentials; the configured SSH key successfully pushed the earlier `4ef5f309a` checkpoint. Use a normal SSH push to the same `dev` ref for final publication, refetch first, verify the resulting remote SHA and never force-push. Stop new feature work with weekly usage at about 97% consumed, reserve final docs/commit/push, and preserve Cargo.lock/captures/perf. Next priority is **IPC nearby-Edge joins, then Niri Reloaded toast migration**, followed by outstanding owner-visible text/wave acceptance and the broader list below.

When closing further items, add `[x]` and the exact relevant commit beside the item, plus actual evidence/limits. Leave pending acceptance or unresolved defects unchecked; do not borrow an older SHA's PASS.

**Bounded continuation and quota checkpoint plan:** update this README before implementation (done by this documentation milestone), then finish one coherent crest/whitewater change before moving to Edge thickness, Clipboard ownership, IPC joins and Niri Reloaded in that order. Keep the broader open requirements below. Recheck account usage between milestones and reserve time/tokens for the final README, atomic local commits and a normal fast-forward push to `origin/dev`; do not wait until usage is exhausted. If time/quota prevents validation, checkpoint the code with explicit **NOT YET VALIDATED / NOT COMPLETE**, list changed files, actual checks and next steps, and push as the maintainer requested. No branch, PR, force-push or stable update; preserve unrelated Cargo.lock/captures/perf files.

**Additional maintainer requirements — scheduled continuation at 06:20 on 2026-09-28 (Asia/Ho_Chi_Minh):**

The one-shot continuation started at 06:20 on 2026-09-28 and has now run. The time gate is consumed; do not schedule a daily continuation. The following instructions supersede conflicting older approaches below: Dashboard must not scroll or expand beyond its own size, and merged popups must keep their positions rather than be moved into tiers. The previous scrollable-workspace and tier-placement milestones describe existing code, not acceptance of these revised requirements.

1. **Weather hover regression:** reproduce the initial simultaneous rendering of Detailed Weather and Orbital Weather, followed by the detailed tab sliding down. Fix initialization, tab visibility/layout and transition ordering; verify first hover, repeated hover, close/reopen and a recording.
2. **Repository-wide efficiency/correctness:** audit all functions and optimize resource use with measured before/after behavior. Debug each feature using live diagnostics, screenshots/image analysis and recordings alongside regression scripts; script success alone is insufficient.
3. **Utilities Popup:** add Monitor Arrangements; Display Mode (Extend, Mirror, Second Screen only, etc.); Sound Output; and Night light/Anti Flashbang tabs. Tab indicators are circular dots at bottom-center; support sliding left/right. Complete Anti Flashbang so it works reliably, responds more sensitively and provides deeper customization. Reuse supported display/audio backends and existing content where appropriate.
4. **Finite Dashboard:** remove scrolling. Available module space is bounded by the actual Dashboard dimensions. Stop modules jumping or scrambling; fit or reject moves/resizes/restores within that space while preserving readable minimums, other cards, saved layout and empty-layout Add controls. Do not solve packed restore by growing a scrollable workspace.
5. **Editor-owned module sizing:** remove Overall module scale and Top/Left/Right/Bottom Edge module size controls from Settings; integrate sizing into Edit Abyss Layout. Fix the reported nonfunctional four-edge controls. When an Edge has only one module, provide a choice to expand only the module's part of the Edge or the entire Edge; retain explicit per-module sizing and safe config migration.
6. **Sidebar centering:** center Sidebar Left/Right on the corresponding physical Left/Right Edge, preserving custom dimensions and output ownership.
7. **Connectivity popups / ownership:** keep the mature Wi-Fi and Bluetooth popup contents with usable actions/live service state, but **do not expose Wi-Fi or Bluetooth as separate Screen Edge modules**. The System Tray already owns the built-in Wi-Fi/Bluetooth status icons; hovering those two icons opens the corresponding connected popup.
8. **Settings row backgrounds:** locate and remove the repeated row backgrounds like Show Header, Power buttons and Preload Dashboard in the Abyss Settings tab and equivalent settings elsewhere. Preserve the enclosing panel's requested fill/opacity/blur; this does not authorize removing all panel backgrounds.
9. **Persistent IPC editing target:** while editing an IPC position in Edit Abyss Layout, keep that target/example open continuously so its position is visible and adjustable, including when the real OSD's normal timeout would expire. Preserve Cancel/Done and safe preview controls.
10. **Merged popups:** keep each popup's anchor position, shrink/reflow its content only within readable limits, and combine both contents without overlap. If both still cannot fit, close the old popup and present the new one. Closing uses a sliding animation, never an abrupt disappearance. Supersedes the previous inward/lateral tier relocation strategy.
11. **Notification/Activity parity:** Activity Popup dimensions must match Notification Popup dimensions.
12. **Traveling waves:** add controls for popup-driven waves; for example, Media Popup emerging sends a configurable strong/weak ripple in both directions along the Screen Edges. Waves must interact with waves traveling in the same or opposite direction, remain stable/bounded, respect shared effects/reduced-motion settings and return to idle sleep.

The following requirements remain open unless an exact local commit and behavior/runtime evidence below explicitly close them:

1. **Dashboard correctness first:** resize the modules inside Dashboard (not merely its outer frame). Keep editing/add controls accessible after hiding every widget. Moving into occupied space must resolve safely or reject/clamp the move when no space exists; never scramble or overlap other widgets. Preserve saved layout, minimum sizes, cancel, undo/reset and both Dashboard/Overview routes.
2. **Inherited feature parity:** restore Quick Notes, To-do and Timers at bottom left plus Notifications and Activities from mature Material content. Audit actual routes and enabled/hidden state before claiming a missing backend.
3. **Ocean-scale waves:** raise safe amplitude/strength limits and make Calm/Balanced/Fluid/Deep presets visibly distinct. Show detailed wave controls only for Custom. Keep waves optional/default off, finite propagation, bounded stability and idle sleep. Audio spectrum must visibly drive the same Screen Edge and have a numeric strength readout.
4. **One wave-strength control:** combine popup/Dashboard/IPC/Settings/etc. strength controls into one shared setting with migration from old per-surface keys. Adjust small control ripples sensibly using that shared setting.
5. **Numeric settings:** sliders display their current value at the right, with meaningful units (% for opacity/scale, px for dimensions/blur, etc.), including audio strength. Reuse a common control instead of special-casing every page.
6. **Surface placement/composition:** simultaneous popup/Dashboard/IPC/Settings bodies keep their positions and shrink/reflow readable contents when space permits; otherwise slide-close the older body and show the newer one. Fit/reflow each content allocation to avoid content overlap while merging outer geometry. Preserve focus, hit masks, close behavior and reopen state.
7. **Edge/module sizing:** Screen Edge width also influences module sizing on that Edge, respecting shared Edge size and explicit per-module overrides. Keep the resting physical edge flat and thick, not permanently indented by modules.
8. **Material presentation:** add opacity/blur controls for module/popup backgrounds. Remove thin borders around transparent, unfilled controls/results/context-menu rows; use coherent Abyss fills. Main Settings tabs have no border; subsidiary choice buttons have a wave shape and ripple on click, honoring shared wave/reduced-motion settings.
9. **Sidebar/hot-corner parity:** inherit mature hot-corner hover settings; restore custom Sidebar width and height. Keep left/right reveal at the middle of physical edges and no sidebar icon modules. Remove the redundant Desktop & Layout Sidebars page; retain the Abyss route and shared feature preferences.
10. **Settings navigation:** remove Easy mode and its toggle; there is one mode. Put one Edit Abyss Layout icon beside the lock at top right in the old mode-toggle location. Remove scattered duplicate editor buttons/pages. Abyss is a heading with focused tabs, not one giant tab containing every setting. Audit/merge overlapping Abyss and Desktop & Layout pages and similar settings. Fix heading removal, drag/drop persistence, duplicate Abyss headings and repeated generated More groups. Preserve custom navigation without losing settings.
11. **Live Editor:** support representative popup/IPC previews and position edits, including near-corner joins. Smooth module dragging and resizing; avoid reloading heavy content or persisting the whole config every pointer event. Preserve guide/snapping/start-center-end alignment, per-output profiles, custom size and Cancel/Done.
12. **Tray/app interaction:** hovering ordinary system-tray/application icons opens the actionable menu normally shown on right click, instead of a name tooltip. The built-in System Tray Wi-Fi/Bluetooth status icons are the deliberate exception: they hover-open the shell Wi-Fi/Bluetooth popup instead of an applet menu. Preserve dismissal, keyboard/pointer access and application actions.
13. **Dock motion:** opening/closing a popup must retain Dock content size; remove shrinking/jitter while preserving normal autohide, previews and menu input.
14. **Acceptance still open:** native motion/layout/gesture videos, multiple outputs/hotplug/suspend/fractional scaling, fullscreen/lock lifecycle and apples-to-apples CPU/RSS/frame evidence. Do not infer completion from solver idle sleep alone. Validate media idle resume/queue/Shuffle/Repeat/CAVA and ThinkFan/TLP hardware authorization. Recheck Settings active-indicator behavior and System Monitor widths/alignment. Keep lock/polkit/region-selection critical native hosts safe.

**Earlier GitHub-connected UI checkpoint through `beff5f8cd9765030053012c61c899314239b356b` (latest refinement commits and limits are recorded above):**

A later GitHub-connected continuation re-fetched remote `dev` at `e02e211e13d13f02b3de4528ef60f6e9f2bf11d8` and advanced it through the Utilities commits `dc07b35b6` / `009498c2d` / `43045179a` / `ac4923f3e`, the README handoff `7afebf42d`, anchored composition `2874ff988`, simultaneous StyledPopup ownership `84a53ee4d`, popup eviction/reveal separation `f6b479bbe`, the cross-repo optimization handoff `fca92fb6a`, Abyss material wallpaper sampling/transparency `4a2143b68`, focus/Quick Notes/corner cleanup through `55bb439a6`, and the actual Niri hot-corner overview wallpaper restoration `7f795a0e5` plus executable-contract correction `9aa1de046`. These commits are on remote `dev`; no branch/PR/stable change was made. The connector-only continuation cannot run the owner's Niri/Wayland session, so the previous **204/0/2** canonical PASS at `f721b4c7d` does **not** automatically cover this descendant.

- **Utilities Popup source milestone:** `AbyssUtilitiesPopup.qml` now provides four horizontally swipable/lazy pages with bottom-center circular indicators and left/right keys: Monitor Arrangement, Display Mode, Sound Output and Eye Protection. Monitor Arrangement reuses the existing `MonitorVisibilityConfig.qml` implementation through `embeddedArrangementOnly` rather than duplicating its arrangement/readback/persist code. Sound Output uses `Audio.outputDevices`, `friendlyDeviceName()`, `setDefaultSink()`, mute and sink volume. Eye Protection embeds the mature `NightLightDialog`, including the improved Anti Flashbang controls. `DisplayMode.qml` is a shell-lifetime singleton: it plans output power changes with targets enabled before any disables, rolls back to the previous active set on failure, re-reads Niri output state, and keeps `wl-mirror` alive independently of popup lifetime. Mirror is unavailable until the helper probe succeeds; Hadalis does not fake mirroring by overlapping coordinates. Existing `utilButtons` remain supported; a separate `utilities` Abyss Edge module opens the popup. Pure planning was sanity-checked outside the repo runtime, but the new canonical/QML/native tests have **not** been executed in this GitHub-only continuation. Multi-output/hotplug/rollback, real `wl-mirror`, PipeWire switching, Night Light/Anti Flashbang and all four Edge placements still require owner-session acceptance.
- **Anchored composition / simultaneous StyledPopup source milestone:** `2874ff988` replaces lateral anchor relocation with anchor-center retention, inward partitioning, readable-minimum reflow and last-resort eviction while retaining loaded draft state. `84a53ee4d` replaces the single `activePopup` ownership bottleneck with simultaneous mature StyledPopup composition, and `f6b479bbe` separates popup reveal motion from allocator eviction/recovery so a popup can retract without corrupting the semantic open state. `35fdf061d` then aligns shared-field keyboard arbitration with mature `StyledPopup`: the newest visible popup that actually requests focus owns the mode, ordinary `keyboardFocus` remains OnDemand, Exclusive requires `exclusiveKeyboardFocus`, and closing the newer popup restores the older focus lease. `scripts/test-abyss-body-placement.py/.sh` and `scripts/test-abyss-multi-styled-popup.sh` are the focused contracts. This materially supersedes the older "single active popup / lateral tiers" handoff, but cross-output Quick Notes leases, mixed Settings/Dashboard/Sidebar/IPC combinations, small outputs and physical keyboard/pointer acceptance remain open.
- **Wallpaper-facing material + actual Niri hot-corner overview restoration:** `4a2143b68` remains the Abyss-field material fix: it removes the temporary 35% surface-alpha floor and uses `WallpaperListener.wallpaperUrlForScreen()` for output-aware/image-safe wallpaper sampling without adding per-corner capture/FBOs. A second audit of the supplied screenshot found the large gray region is the **Niri built-in Overview backdrop**, not merely the 16px Abyss field. Stable kept a separate `Backdrop.qml` Background-layer surface (`quickshell:iiBackdrop`) and Niri placed that namespace `within-backdrop`; the Abyss cutover had folded `iiBackdrop` into `abyssBackground` but stopped loading that renderer. `7f795a0e5` restores the stable path under the `abyssBackground` gate, keeps Waffle untouched, preserves the historical namespace so existing Niri rules continue to match, and updates the Niri config comments/contracts to reflect that `backdrop-color` is opaque while wallpaper comes from `place-within-backdrop`. `scripts/test-perimeter-family-contracts.sh` now guards the Abyss backdrop loader + layer namespace/rule, and `9aa1de046` restores its executable bit after the Git-data commit. `1695ee969` adds required append-only migration `052-abyss-overview-backdrop-layer-rule`: existing installs that skipped the old optional backdrop migration now self-heal missing `iiBackdrop`/`wBackdrop` Niri rules, targeting an existing modular `80-layer-rules.kdl` when present and otherwise the monolithic config; the focused contract exercises commented-rule detection, monolithic repair, modular repair and idempotence. `ffe46cbae` then ports mature `ScreenCorners` ownership into `AbyssCorners`: every Quick Notes, Notification Center or Sidebar corner now yields its input region when `NiriService` says that exact output/corner belongs to Niri Overview. This prevents an Abyss corner interaction from competing with the compositor hot corner, including custom per-output/multi-corner Niri configurations. Source review is complete; live acceptance still needs the owner session: trigger Niri Overview from the configured hot corner and Mod+Tab, confirm the city wallpaper fills the formerly gray backdrop, then check corner activation with Sidebar corner-open both on/off, backdrop blur/dim, video wallpaper and multi-output behavior.

- **Desktop context-menu live editor parity:** `7ff6eff1d` fixes the right-click desktop **Edit shell layout** action. Under Abyss it now calls the same `GlobalStates.startAbyssEditing(...)` path as the top-right Settings **Edit Abyss layout** button, scoped to the desktop/output that was right-clicked; non-Abyss families continue through `ShellEditSession.enter(outputName)`. `beff5f8cd` then hardens the shared Abyss entrypoint itself: stale generic Shell Layout edit state and desktop-widget edit state are cleared before Abyss editing starts, so Settings, desktop context-menu and IPC entry cannot stack/toggle competing editors. The focused settings contract guards both routing and mutual exclusion. Live pointer acceptance is still required on the owner session.

**06:20 evidence history retained below (validated only through the named older SHA):**

Runtime code is committed through `f721b4c7d942dc202eecca32018866af1e31b1b4` (36 local commits ahead of the last fetched remote `dev`, `28b3f5112de8d3101d4593588ad9d38225f071d8`). This run started at `5cd6c0aa3c907d6d334795cc8804d273ea9c2b29`. No push/branch/PR/stable update was performed. Development stopped with about 5% of the five-hour usage window remaining so evidence and the next prompt could be saved. This is not full product acceptance.

- **Weather first reveal:** `495ec4772` makes Orbital/Detailed positions follow one tab animation; initial height changes and rehosting no longer animate two independent tab positions. Native first reveal, tab switch, resize/rehost, repeated transitions and reduced motion pass. Before/after images and a usable 6.4-second after recording are saved. `9b7541d7b`/`db2ff1094` reconcile the two stale composition assertions; the mature Orbital design still needs the requested visual adaptation.
- **Finite Dashboard:** `91a03b1a1` removes the Abyss workspace scroll/growth, retains a fixed viewport and stable reveal content, and clamps only the card being dragged/resized against an immutable neighbour baseline. Packed Add gives no-room feedback without changing other cards; overflow/catalog items remain accessible. Both Dashboard/Overview, resize persistence and remove-all/Add restore pass. Real virtual-pointer input resized Notes by about 96×66 px, then dropped it over System: Notes clamped and System stayed unchanged in a 1345×671 canvas. Video is 8.833 seconds. Dense all-card layouts, cancel/undo/reset and multi-output acceptance remain open; Waffle's existing arrangement behavior is retained.
- **Sizing and IPC preview:** `9bd91c355` moves shared/per-output sizing into Edit Abyss Layout and removes the five Settings sizing controls. A lone module can expand locally or along the whole Edge; explicit module overrides remain. `4fd340798` fixes a pixels-versus-multiplier error in local depth. `ed04f8500` accounts for local module clearance in popup/IPC placement and removes a resulting width/height binding cycle. Physical Editor input enlarges the Clock; the Volume target remains visible below it after the real OSD timeout. Draft/Cancel/Done and preservation of another output's profile pass.
- **Sidebar/Activity/input:** `507f0331f` centers Sidebars while keeping custom dimensions and makes Activity use the Notification footprint with bounded metric rows. Actual left/right hover and the Activity tab click were exercised. `92196721d` puts the native outside-click catcher below field input, fixing tab clicks being swallowed as outside dismissals. Corner backend/Notes leases and real focus transfers still need broader acceptance.
- **Settings rows:** `317326397` removes repeated ConfigSwitch/SettingsSwitch row fills for Abyss, retaining the enclosing surface. The full audit of overlapping settings, duplicate opacity controls, remaining fills and units is still open.
- **Traveling waves/performance:** `3887fad85` adds Custom-only popup-travel control and two signed packets per emergence/retraction in the same physical field. Packet budget is 16; all four Edges receive motion, same/opposite signs reinforce/cancel, disabled/reduced/hidden effects clear packets and settling stops integration. Native GPU tests plus a 5.467-second real Media recording pass; the live field sleeps after the final close. Cached corner classification reduces **Node solver CPU only**, from 1246.857 to 169.522 ms mean across six paired AB/BA runs of the same 256-sample, 1920×1200, 2400-step ordinary-impulse workload. Every frame's displacement hash matches (`90f9035b48073f19bdb249aeff05d7c1fb425416d2c09f8c8cd05670c2ac0a00`). The first cache attempt regressed and its report is retained; a real cache change was qualified afterward. The 548.685 ms packet-storm run has different output/work and is not a parity comparison. These results do not establish whole-shell CPU/GPU/RSS/frame efficiency.
- **Wi-Fi/Bluetooth ownership corrected:** `23003bf61` originally added dedicated Abyss Edge modules plus connected popups. The 28/09 follow-up requirement supersedes that duplication because the System Tray already contains built-in Wi-Fi/Bluetooth status icons. `1e782a2e2` removes `wifi`/`bluetooth` from the Abyss module catalog/runtime and adds required migration 053 to strip old global/per-output placements without touching other modules. `6ef3d4756` routes hover from the actual built-in `BarStatusIndicators` Wi-Fi/Bluetooth icons through the System Tray module into the existing `AbyssNetworkPopup`; generic application SNI hover remains the mature actionable right-click-menu behavior and is not hijacked by connectivity matching. Hover-open is idempotent for the already-open same popup, so re-entering the icon does not toggle it closed. Actual association/password/pairing, pointer transfer into the popup, nested dialogs, Details dismissal and hardware service failures remain live-acceptance gates.
- **Anti Flashbang:** `f721b4c7d` replaces the old potentially amplifying curve with finite dim-only threshold/strength/floor policy. Small in-memory PPM captures run periodically and on focus/workspace changes; requests coalesce, both stdout completion and process exit are required, generations reject late results, and owned capture jobs have timeout/cancellation/backoff. Lock/sleep/disable resets gain; repeated failures restore base brightness. Deep controls show threshold/strength/floor/capture scale in %, sampling/response in ms and night temperature in K, inside a bounded scrollable form. Real captures track bright/dark content in the same application. The actual Brightness service passes dim/base-preservation/lock/sleep/wake/disable with **fake brightnessctl/ddcutil**, including bounded writes and restoration to 50. No owner backlight/DDC or night-light state was changed. Real hardware latency and deeper sensitivity tuning remain open.
- **Fixture correction:** `9f84330bb` gives native popup/Dock tests an explicit logical viewport and matching controller dimensions. The owner's Niri assigned 1868×1111 instead of the requested 1100×800; two large bodies then legitimately fit laterally. Corrected tests pass without changing runtime to satisfy the old assertion. The runtime tier strategy still conflicts with the newer anchored-composition requirement and must be replaced.

Evidence is committed under [docs/abyss/validation/2026-09-28-0620](docs/abyss/validation/2026-09-28-0620/README.md), with SHA-256 manifest, native states/logs, before/after screenshots, three usable recordings and paired solver reports. These use private QA configuration and sometimes fallback gray wallpaper; they are not visual approval against the supplied city reference. Invalid blank/stale captures, the unusable Weather-before recording and the initially obscured Night controls were excluded from accepted evidence. Reusing a private nested compositor after full-shell restarts produced stale/blank captures; restarting the isolated compositor yielded working image/capture evidence. Investigate that harness lifecycle rather than counting the invalid probes as acceptance. Owner Niri/Quickshell were preserved.

**Latest canonical validation: PASS — 204 passed / 0 failed / 2 skipped**, exact runtime code `f721b4c7d942dc202eecca32018866af1e31b1b4`; command `bash scripts/validate-maintainer-local.sh --current-repo`, private Wayland/Niri environment. Full log is committed as `docs/abyss/validation/2026-09-28-0620/validator-f721b4c7d.log`; unavailable modern QML parser and deferred Nix are separate skips. This checkpoint commit only adds README/evidence after that validated code SHA; it is not full desktop/hardware acceptance. The previous scheduled-run snapshot `23003bf619c10e3a8c93548b454dd7ba002f3bd7` had **199 pass / 2 fail / 2 skip**; both native viewport failures are explained above and fixed in `9f84330bb`. Earlier `91a03b1a1` had 198 pass / 2 stale Weather contract failures / 2 skip, reconciled by the named contract commits. Full logs remain available; native evidence is separate from canonical/static acceptance.

**Historical implementation before this scheduled continuation (superseded where stated):**

Development stopped before account usage was exhausted. All feature work is committed locally on `dev`; nothing was pushed. The remote baseline last fetched was `28b3f5112de8d3101d4593588ad9d38225f071d8`. Re-fetch and inspect the actual tree rather than assuming this snapshot is still current.

- **Dashboard:** `56f7037e6` and `0783e6e70` reserve the embedded edit toolbar, keep add controls after hiding all cards, reject infeasible drag/resize against an immutable baseline, and project overlapping/packed saved layouts into a readable, collision-free scrollable workspace. Main files: `modules/dashboard/DashboardCanvas.qml`, `DashboardLayout.js`, `DashboardContent.qml`, `modules/overview/OverviewWidget.qml`. Pure collision/workspace tests and `scripts/test-abyss-dashboard-editing.sh` pass scripted resize, persistence, both hosts and empty-layout restore. Dense physical-pointer acceptance remains open.
- **Waves/numbers:** `dc65e6e11` adds amplitude up to 4, substantially different presets, Custom-only detailed controls, 0–400% audio strength, one migrated surface strength, and numeric slider units. The same field renders bounded ocean-scale motion; audio uses the shared analyzer. Wave solver, GPU wave runtime and shader lifecycle tests pass finite settling, spectrum response, reduced motion and fallback. Visual approval of preset differences remains open.
- **Settings/navigation:** `eb1325778`, `5bc7507e7`, `931a48c6e` preserve mature route indices, migrate focused Abyss pages, merge duplicate Abyss/More groups, allow nonempty heading removal without losing pages, and remove Easy rendering/config/helpers. One header Edit Layout action remains per chrome. Navigation behavior and embedded Settings route tests pass; the remaining content-overlap audit is listed below.
- **Edge modules/Sidebars:** `01e70af25`, `2dae091a9` retain module identity during dragging, scale shared module sizes with Edge thickness while preserving explicit overrides, and inherit custom Sidebar width/height through the existing controller. Editor identity/size tests and Sidebar dimension checks pass. No new heavy content reload or config persistence is introduced on each drag event.
- **Corner parity:** `cef174584` reuses mature Quick Notes/To-do/Timers and Notifications/Activity content and existing hover/corner settings. It corrects embedded focus guards, input regions, timer imports and the To-do dialog parent. `scripts/test-abyss-corner-content.sh` passes; actual cross-output focus/keyboard transfer remains open.
- **Controls/fills:** `7a61d6b0d` adds finite vector wave choice buttons using shared wave/reduced-motion settings, fills controls/dropdowns and removes idle Abyss borders. `4459e3d11` adds `abyss.content` opacity/blur/card-opacity settings and filled Dashboard/Settings/search layers through the existing shared shader, without per-card capture/FBOs. `scripts/test-abyss-choice-motion.sh` and `scripts/test-abyss-content-material.sh` pass. GPU captures demonstrate body alpha 0.3→1 while Edge alpha remains independent, blur changes wallpaper samples, and disabled effects release their sources.
- **Body placement:** `8d127b235` adds `modules/abyss/looks/AbyssBodyPlacement.js` and output-local target allocation. Ordered inward/lateral tiers preserve requested content sizes; insufficient space hides the older body, releases its input/focus and retains loaded drafts for restoration. Placement does not repack on animated progress. Pure and native `test-abyss-body-placement` tests pass four-edge/perpendicular collision, exact content/input bounds, draft retention and restoration. This does not yet cover every popup system or tiny-screen reflow.
- **Dock/app hover:** `2eac73b3d` fixes Dock content size across reveal/reversal/unload; `555f1930b` exposes actionable tray/app menus on hover, keeps explicit keyboard/right-click grabs and fills generic menu rows. Dock reveal and app-hover native tests pass. Real system-tray DBus menus and full production pointer bridges still need acceptance.
- **Popup/IPC Editor:** `e6d6fc4d3` adds `modules/abyss/content/AbyssLayoutPreview.qml`, real mature popup/IPC example content, safe disabled preview controls, position drafts, physical-edge dragging and numeric Editor sliders. Done merges only touched kind/output positions into current config; Cancel discards them. `scripts/test-abyss-editor-runtime.sh` passes actual Volume preview loading/drag/save/cancel and preserves a concurrent position on another output. Other examples and small-output editor fitting need live checks.
- **Search/runtime tests:** `f96ebb821` removes real AppSearch lazy-index binding loops. `48560ce41`, `0718b2d02`, `413b848b1` gate native tests on config readiness, allow bounded cold startup, and preserve live test scenes until an external deadline. Assertions and QML diagnostic rejection remain mandatory; an early crash or timeout without the completion marker is a failure.

**Historical validation before the 06:20 continuation (not current acceptance):**

- Last fully green canonical snapshot: `5bc7507e7`, **194 passed / 0 failed / 2 skipped**; log `/tmp/hadalis-maintainer-validation-20260928-022206.log`. It predates subsequent features.
- Latest full clean-clone run: exact source `931a48c6eac02653f4a88179d6cea662ac920480`, **195 passed / 4 failed / 2 skipped**, log `/tmp/hadalis-maintainer-validation-20260928-031355.log`. One stale Dashboard material assertion rejected the intentional new Abyss layer. Three native scripts (`test-abyss-popup-layout.sh`, `test-abyss-styled-popup.sh`, `test-abyss-utility-content.sh`) reached their 8-second deadline without completing assertions.
- Follow-up `413b848b1e4c37e1d7e62c8a99e3800787ff0230` reconciles the material assertion with GPU evidence and gives those three native scripts readiness gates and a 20-second deadline. **All four targeted checks pass**; native logs are `/tmp/hadalis-abyss-sep28/{popup-layout,styled-popup,utility-content}-final.log`. The full canonical validator has **not** been rerun on this descendant.
- Run **`bash scripts/validate-maintainer-local.sh --current-repo`** for unpublished local work. Without `--current-repo`, the validator defaults to cloning remote `dev` and would test the wrong tree. A PASS applies only to the exact printed SHA. Nix and unavailable modern QML-parser checks are deferred/skipped separately; runtime import/render tests are not a substitute for parser coverage.
- Private native evidence is under `/tmp/hadalis-abyss-sep28`, including material captures `material-evidence/{clear,blurred,opaque}.png`. Scripts live in the repo; temporary evidence may disappear. Native probes run sequentially in a separate Niri session; re-discover its display/socket if continuing. Do not kill or reconfigure the owner's desktop.
- Older `/tmp/hadalis-abyss-liquid/evidence/interaction.mp4` stopped at a failed Calendar hover and is incomplete. It is **not** full desktop acceptance. Previous cold-start/lifecycle failures are retained in validator logs, not waived as successful assertions.
- Preserve unrelated `native/Cargo.lock`, `hadalis-code-workflow-capture-*` and `perf.data*`; none is included in these local commits.

**Concrete remaining work, in priority order:**

1. **Utilities Popup is source-complete but not runtime/hardware accepted.** Remote `dev` now contains the four lazy pages, focused embedded Monitor Arrangement, safe session Display Mode service, real PipeWire Sound Output selection, embedded Night Light/Anti Flashbang, bottom-center dots, horizontal swipe/keys and a dedicated Abyss Edge module. Added contracts are `scripts/test-abyss-display-mode.py`, `scripts/test-abyss-utilities-popup.sh` and the updated popup-presentation regression. Run the canonical validator on the exact current SHA, then validate four-Edge placement, small/fractional outputs, real multi-output Extend/Primary/Second-only, hotplug during a transition, rollback after a failed Niri action, `wl-mirror` start/stop/disconnect, real PipeWire default-sink changes, and Night Light/Anti Flashbang input/scroll behavior. Do not claim the old 204/0/2 result covers these commits; do not fake Mirror.
2. **Anchored composition/focus is source-implemented through allocator + simultaneous StyledPopup ownership, but not accepted yet.** `2874ff988` retains anchors, partitions inward, reflows to readable minima and evicts only when necessary; `84a53ee4d` supports simultaneous mature StyledPopups; `f6b479bbe` separates reveal from eviction motion; `35fdf061d` makes newest focus-requesting popup arbitration/restoration match native StyledPopup OnDemand/Exclusive semantics. Do not revert to lateral relocation or single-active ownership. Next, qualify physical focus/input ordering for Settings/Dashboard/IPC/Sidebar/corner combinations on all edges and small/fractional outputs, including a newer popup forcing an older one to slide-close and later restore without losing draft/keyboard state. Generic native menus/Recording HUD remain outside field allocation.
3. **Dashboard/Editor coverage:** exercise packed restored layouts, every widget, hidden overflow/Add, viewport shrink, cancel/undo/reset and save/reopen with physical input. No scroll/growing workspace or neighbour scrambling. Verify real Calendar/Weather/Media/Resources/network examples, small/fractional Editor toolbar fit, joins, per-output/latest-config merges and persistent IPC targets. Measure drag frame cost; identity retention and a two-card video alone do not prove smoothness everywhere.
4. **Inherited interaction, wallpaper/hot-corner Overview and connectivity:** `4a25474f9` ports the mature cross-output Quick Notes editor lease into Abyss: editor ownership is compare-and-set by output, non-owner Notes/Notification Center corner triggers stay dormant while the lease is held, and monitor removal releases a stale owner. `55bb439a6` removes the retired Orbit hot-corner path, and `ffe46cbae` gives Niri Overview configured-corner priority over all remaining Abyss Quick Notes/Notification/Sidebar corner input on each output. The focused corner contract guards both source rules; real two-output keyboard/pointer focus is still an acceptance gate. Next qualify Sidebar custom dimensions/hot corners on multiple outputs. Validate both wallpaper paths: `4a2143b68` for field material alpha/blur/output-aware video stills, and `7f795a0e5` for Niri built-in Overview backdrop wallpaper from hot-corner/Mod+Tab activation. Confirm no gray compositor backdrop remains with the default enabled backdrop, and verify blur/dim, disabled-backdrop behavior, video and multiple outputs. Connectivity ownership is now the System Tray only: migration 053 removes old Wi-Fi/Bluetooth Edge placements and `6ef3d4756` makes the built-in status icons hover-open the mature connection popup. Live-check Wi-Fi→popup, Bluetooth→popup, transfer from icon into popup, switching between the two, same-icon re-entry, real association/pairing/device removal/service errors, plus ordinary tray DBus nested menus/app actions/keyboard access. Real backlight/DDC/night-light sensitivity, latency and failure behavior remain separate from fake-hardware tests.
5. **Settings/public design audit:** finish overlap/deduplication across Abyss, Desktop Panels and shared widgets; consolidate Dashboard card-opacity multiplying global content opacity. Audit all units, remaining result/media/Sidebar/native-menu fills, borderless navigation and active indicators, ordinary button wave faces and readable preset differences. Finish Orbital Weather appearance. Confirm the final public Abyss/Waffle-only migration, historic Material aliases and flat opaque/no-effects inheritance without deleting supported Waffle or dropping mature features.
6. **Whole repo efficiency/product gates:** debug each function with real diagnostics/images/recordings and comparable CPU/RSS/frame/GPU measurements. Solver-only speedup is not shell parity. Qualify multi-output/hotplug/suspend/fractional/transformed/fullscreen/lock/polkit/region-selection behavior, Waffle, media idle resume/queue/Shuffle/Repeat/CAVA and ThinkFan/TLP actual permissions. Investigate duplicate private helper/restart lifetime symptoms before assigning a product root cause; terminate only explicitly owned QA processes. Preserve unrelated Cargo.lock/captures/perf data.
7. **Final closure:** run canonical validation for new runtime changes on their exact local SHA, preserve failures, complete native acceptance and keep every requirement group above until proven. This checkpoint stops for usage, not completion. Continue in one agent on dev; the latest request authorizes normal checkpoint pushes to origin/dev before quota exhaustion, without branch, PR, force-push or stable changes. Update this README again before the next quota stop and explicitly record skipped/unrun validation. No daily automation should be created.

## 12. New-conversation continuation prompt

Copy/paste this prompt into the next conversation:

```text
Tiếp tục hoàn thiện Hadalis Abyss trong repo hiện tại đến khi toàn bộ yêu cầu và kiểm thử nghiệm thu hoàn tất. Đọc AGENTS.md và README §11 trước; kiểm tra git status, HEAD và remote thật. Context mới nhất thắng snapshot cũ. Kiểm tra trạng thái commit/push thật; các mốc trước đã được cập nhật lên remote dev, không giả định tất cả còn local. Đọc evidence và phần còn lại, không làm lại những mốc đã hoàn tất.

Làm single-agent trực tiếp trên dev. Fetch origin dev trước audit và ngay trước mỗi write/ref update; đọc lại target/caller, giữ thay đổi concurrent. Commit atomic trực tiếp trên dev; Yêu cầu mới nhất cho phép commit và push checkpoint chưa hoàn thiện lên origin/dev trước khi quota cạn; không bắt buộc test trước checkpoint commit/push nhưng phải ghi rõ chưa validated/chưa hoàn tất. Cập nhật README trước, làm crest/ripple-only + breaker/whitewater đầu tiên, rồi slider độ dày Edge trong Editor, Clipboard flicker Dashboard, IPC join Edge và Niri Reloaded shell. Không tạo branch/PR, không sửa stable, không rewrite history. Không tự động thêm Cargo.lock/capture/perf của người dùng.

Abyss kế thừa nội dung/design/backends Material và rework Screen Edge/Bar/Popup/Dashboard qua một output-local liquid field. Public panel families chỉ Abyss và Waffle. Tắt transparency/blur/waves phải giữ layout Material cũ. Geometry locks của ii cũ không cấm rework Abyss đã được tôi cho phép; Waffle vẫn là family độc lập được support.

Lịch một lần 06:20 sáng 28/09/2026 đã được thực hiện; không còn time gate và không lập lịch hằng ngày. Tiếp tục ngay khi nhận prompt này. Đọc đầy đủ 12 yêu cầu bổ sung trong README §11: chúng thắng phần cũ mâu thuẫn. Dashboard KHÔNG SCROLL, không mở rộng workspace ngoài khung; sửa jumping/resize/Add trong không gian hữu hạn. Popups kết hợp giữ nguyên vị trí, thu nhỏ/reflow tới giới hạn đọc được; không đủ chỗ thì slide-close popup cũ để hiện popup mới. Sửa Weather hover render kép; bổ sung Utilities/Wi-Fi/Bluetooth, Editor sizing và IPC target luôn mở, Sidebar căn giữa, Notification/Activity đồng kích thước, bỏ nền hàng settings và sóng từ popup chạy hai hướng tương tác. Audit/optimize/debug cả repo bằng live diagnostics, ảnh và recording có bằng chứng, bên cạnh scripts. Tiếp theo xử lý composition/focus, StyledPopup single-active ownership, cross-output Notes leases, tray hover thật, Editor previews/small-screen fitting/smoothness, Settings trùng lặp/opacity/units/fills và Orbital Weather như danh sách cụ thể README §11. Không bỏ sót bất cứ nhóm yêu cầu nào.

Refinement đã cập nhật code qua 2d31f06b9857a2afdc66ace0af797e132860c754: crest-only/whitewater 184b8336d; px Edge Editor 3486b5d51; popup import 134b0115a; Clipboard flash 45e0d6654; connectivity text/viewport contract 2d31f06b9. Đọc dấu tick, evidence mới và giới hạn nghiệm thu phía trên. IPC join Edge và Niri Reloaded vẫn chưa triển khai. 30887f08a là baseline CAVA đầu run, beff5f8cd là mốc UI cũ. Luôn fetch và đọc HEAD thật. Canonical PASS gần nhất vẫn chỉ áp dụng exact runtime SHA f721b4c7d942dc202eecca32018866af1e31b1b4; xem manifest/evidence trong README §11 và không kế thừa PASS đó cho descendant. Utilities Popup đã source-complete nhưng chưa live-accepted. Anchored allocator + simultaneous StyledPopup ownership đã được triển khai qua 2874ff988/84a53ee4d/f6b479bbe; 35fdf061d đã sửa focus arbitration theo popup focus-requesting mới nhất và giữ đúng OnDemand/Exclusive semantics; 4a25474f9 đã thêm lease Quick Notes giữa outputs, nhưng focus/input restoration vẫn cần live qualification. Wallpaper có hai mốc cần phân biệt: 4a2143b68 sửa material alpha/sampling của AbyssField; 7f795a0e5 mới là fix trực tiếp vùng xám của Niri built-in hot-corner Overview, bằng cách phục hồi shared Backdrop.qml dưới abyssBackground để namespace quickshell:iiBackdrop tiếp tục đi qua place-within-backdrop như stable. 9aa1de046 chỉ sửa executable bit của focused contract; 1695ee969 thêm migration 052 bắt buộc/idempotent để các install đã bỏ qua migration backdrop cũ tự có lại `place-within-backdrop`; ffe46cbae làm các corner input của Abyss nhường đúng corner cho Niri Overview giống mature ScreenCorners. Hai yêu cầu UI mới đã source-complete: 1e782a2e2 + migration 053 bỏ module Wi-Fi/Bluetooth riêng khỏi Screen Edge, 6ef3d4756 nối hover của chính hai status icon sẵn có trong System Tray tới popup tương ứng mà không phá generic tray-menu hover; 7ff6eff1d làm menu chuột phải desktop mở đúng Abyss live editor như nút Settings, theo output vừa click; beff5f8cd làm entrypoint đó loại trừ editor generic/widget đang stale trước khi mở Abyss editor. Cần live-check các đường này và kiểm tra trực tiếp wallpaper city trong ảnh người dùng bằng hot corner/Mod+Tab, Sidebar corner-open, blur/dim, video và nhiều màn hình. Chạy bash scripts/validate-maintainer-local.sh --current-repo trên exact current SHA khi có owner checkout; PASS chỉ áp dụng SHA in trong run đó. Không đổi behavior chỉ để chiều stale grep assertions; giữ regression meaningful và kiểm tra QML diagnostics ngay cả khi process exit 0.

Native input/video, nhiều outputs/fractional scaling/fullscreen/hardware và CPU/RSS/frame comparison vẫn là gates riêng; đừng báo hoàn tất từ scripted/static checks. Dùng private harness, không kill/reconfigure desktop của người dùng.

Theo dõi usage; trước khi gần hết, ghi rõ files/commit trên dev, tests/evidence, failures chưa giải quyết và bước tiếp theo vào repo/README để chatbot khác tiếp tục. Đánh dấu [x] cho phần code đã xử lý và ghi commit kế bên; ghi riêng acceptance chưa xong. Bổ sung lỗi mới: popup Wi-Fi/Bluetooth từ System Tray hiện không có text bên trong, cần debug embedded content/labels/colors/size/lifecycle và kiểm tra thực tế. Khi đạt milestone hoặc quota gần cạn, cập nhật dev/README, commit atomic và push origin/dev theo yêu cầu mới nhất; không cần chờ tests của bản chưa hoàn thiện, nhưng phải ghi rõ tests chưa chạy và việc còn lại. Vẫn không tạo branch/PR hay sửa stable.
```
