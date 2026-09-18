# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-18

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
- Canonical local validator: `bash scripts/validate-maintainer-local.sh`.
- A task is not release-complete merely because code exists. Runtime-sensitive items remain open until locally validated on the intended desktop environment.

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

## 3. v1.0 release blockers

Checkboxes below are **release gates**, not an assertion that no partial implementation exists. Check an item only after source review and the relevant local/runtime validation.

### A. Screen Edge and connected surfaces — P0

- [ ] **Screen Edge exists both while idle and while a window is maximized.** It must not disappear simply because no maximized window is present.
- [ ] **Screen Edge width is configurable in Settings.** The setting must use one canonical configuration field, have a safe default/range and update the active edge without requiring an alternate renderer.
- [ ] **All connected popups use one shared connector width/thickness contract.** No popup should invent a narrower stem or a private gap value.
- [ ] **No visible gap between bar/Screen Edge and popup body.** Shared geometry must own seam overlap so fractional scaling, animation and antialiasing do not expose a slit.
- [ ] **Left and right Sidebars connect to the vertical Screen Edge**, not to the top bar or bottom screen edge.
- [ ] Connected surfaces behave correctly for top/bottom/left/right bar placement, transformed outputs and fractional scale.
- [ ] Reverse retract / hover bridge keeps the source and popup visually and interactively continuous during close/reopen transitions.

### B. Popup interaction correctness — P0

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

- [ ] The bar-attached Media Popup renders the existing **CAVA -> `PlayerControl` -> `WaveVisualizer`** path instead of an empty visualizer input.
- [ ] The same Media Popup includes a **10-band DSP Equalizer** below the player card, using the existing optional `EqualizerService` / EasyEffects backend rather than a second ad-hoc equalizer process. User-facing bands are 31/63/125/250/500/1k/2k/4k/8k/16k Hz with the Serpantinum Flat/Bass/Treble/Vocal/Pop/Rock/Jazz/Classic curves.
- [ ] Confirm the required CAVA runtime/package is present in the supported install/package paths, or document/install it where currently missing. EasyEffects + socat remain optional capabilities and must degrade gracefully when absent.
- [ ] Visualizer/equalizer lifecycle is efficient: start only when needed, stop when unused, and survive pause/resume, player switching and popup close/reopen.
- [ ] MPRIS controls, seek, volume and keyboard behavior do not regress while the visualizer/DSP controls are active.

### F. Calendar / Weather v1.0 composition — P0

Adapt the useful part of the Serpantinum reference without copying its right-side weather presentation.

- [ ] **Left:** calendar/date presentation based on the Serpantinum reference.
- [ ] **Center:** large digital time plus the hourly weather arc/timeline concept from Serpantinum.
- [ ] **Right:** use Hadalis' existing detailed weather presentation/data, not Serpantinum's simplified right panel.
- [ ] Preserve Hadalis weather data/service ownership, units, refresh behavior, location/error states and Material theme behavior.
- [ ] Layout remains usable across supported screen sizes/scales and does not depend on hard-coded screenshot dimensions.

### G. Material-only Global Theme cleanup — P0

Material is the **single canonical Global Theme** for Hadalis 1.0.

- [ ] Remove every non-Material Global Theme option from Settings, menus, previews and any user-facing theme selector.
- [ ] Remove non-Material Global Theme runtime branches, loaders, delegates, theme registries and alternate token/palette routing that are no longer required by Material.
- [ ] Remove dead non-Material theme assets and imports when no active Material path or supported panel family consumes them.
- [ ] Remove or update stale tests, docs and configuration examples that imply multiple Global Themes remain supported.
- [ ] Normalize old persisted non-Material theme values to Material safely; do not resurrect an old renderer/theme only to honor a legacy value.
- [ ] Keep only the minimal migration compatibility needed to read an old value and resolve it to Material, then delete compatibility code that no current caller needs.
- [ ] Material must remain visually correct across Bar, Screen Edge, popups, Sidebars, Overview, Settings and Waffle after the cleanup.

### H. Full `iiPerimeter` runtime cleanup — P0

The broad `iiPerimeter` composition runtime and the shared connected-popup primitives are **not the same thing**.

- [ ] Audit every active consumer of the full `iiPerimeter` runtime, topology, adapters, cutover/fallback flags and configuration.
- [ ] If the full runtime no longer owns required v1.0 behavior, remove it completely: runtime wiring, dead settings, adapters, tests and stale docs.
- [ ] If a required active consumer still exists, reduce the runtime to that concrete responsibility and document why it remains.
- [ ] **Do not remove** `modules/common/perimeter/ConnectedSurface*` / `PerimeterTokens.qml` merely because the broader runtime is removed; those are shared primitives used by connected popups.
- [ ] No ordinary bar popup may depend on enabling a broad perimeter cutover.

### I. Legacy/compatibility cleanup — P1

- [ ] Remove active reads/routes for retired renderer/style families when they no longer serve migration compatibility.
- [ ] Keep compatibility shims only where a current supported caller still needs the type/config name.
- [ ] Do not restore retired Pill/Mascot runtime behavior, historical Dock renderer families, Orbit/workspace experiments, removed Global Themes or similar dead presentation systems.
- [ ] Old persisted values must degrade safely to the supported v1.0 behavior instead of resurrecting removed renderers or themes.
- [ ] Keep Waffle separate and supported.

## 4. Connected-surface architecture contract

The existing popup path remains authoritative:

```text
modules/bar/StyledPopup.qml
modules/common/perimeter/ConnectedSurfaceGeometry.qml
modules/common/perimeter/ConnectedSurfaceConnector.qml
modules/common/perimeter/ConnectedSurfaceFrame.qml
modules/common/perimeter/ConnectedSurfaceContentHost.qml
modules/common/perimeter/ConnectedSurfaceMask.qml
modules/common/perimeter/PerimeterTokens.qml
```

Rules:

- `StyledPopup.qml` remains the entry point for existing bar popouts.
- Shared geometry/tokens own connector thickness, seam overlap, corner ownership and attachment behavior.
- Consumers provide content and source ownership; they should not duplicate connector geometry.
- Keep source-aware placement and shaped input regions.
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
- [ ] Connected popups from top, bottom, left and right positions have no visible gap and use a consistent connector width.
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

## 11. Current source-side handoff (2026-09-18)

This section records the **current source implementation state**, not local/runtime validation. Keep release-gate checkboxes above unchecked until the maintainer performs the authoritative local pass.

Source work already present on `dev`:

- persistent Screen Edge surfaces exist in `modules/screenCorners/ScreenEdges.qml`; they are intended to remain visible while idle/normal/maximized and hide only for explicit fullscreen/lock cases;
- Screen Edge width is exposed through the active Bar Settings path, and the edge now paints wallpaper-facing rounded inner corners without changing the rectangular physical edge bands;
- connected popup connector width is centralized through the shared perimeter tokens/geometry instead of expanding to each source control width;
- `modules/sidebar/SidebarHost.qml` now attaches the Left/Right sidebar body directly to the inner vertical Screen Edge boundary using the shared seam overlap; both the old standalone bridge window and the later in-window connector stem are retired;
- the broad legacy `modules/perimeter` runtime/topology/adapters have been retired and removed after caller auditing; the old cutover policy was removed as well, and regression contracts were aligned with the supported connected-surface architecture;
- the dead common perimeter host/config/cutover/route compatibility cluster has also been removed; `PerimeterTopology.qml` remains only as the small edge utility used by `ConnectedSurfaceGeometry.qml`;
- shared connected-popup primitives remain active and protected under `modules/common/perimeter/ConnectedSurface*`, `PerimeterTokens.qml`, and `modules/bar/StyledPopup.qml`; do not recreate the retired broad runtime to solve popup issues;
- Thinkfan standalone connected-surface/content files have been removed from normal UX; Thinkfan controls/state are integrated into the existing System Monitor/resources popup and Settings. Fresh repo-managed installs provision the Hadalis helper/polkit bridge, and required migration `041-thinkfan-helper-bridge` reconciles missing/outdated Hadalis-owned bridge files during repo-managed updates without modifying upstream Thinkfan package/service/config ownership;
- `modules/common/widgets/KeyboardFocusRing.qml` imports `qs.modules.common` on current `dev`, so the earlier `Appearance is not defined` warning belongs to an older runtime snapshot and must be rechecked only after the local shell updates/reloads to current source;
- `Settings > Bar` has a real supported v1.0 facade/content path instead of the previous blank route;
- public Global Theme Settings are constrained to Material, persisted legacy style values normalize/write back to Material, and the runtime `Appearance.globalStyle` boundary is clamped to Material so a persisted legacy style cannot transiently reactivate an old Global Theme branch during startup;
- the Material-only Settings cleanup now removes the retired Global Style tab/sections/search entries and dangling legacy editor loaders from the base Themes page; the public facade retains only a narrow stale-section redirect plus persisted-value normalization, while runtime visual validation remains part of the local release pass;
- the Calendar/Weather composition has source implementation for the requested Serpantinum-inspired left/center presentation while retaining Hadalis detailed weather ownership/content on the right;
- Media Popup owns the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path and gates visualizer activity by popup presentation/playback lifecycle; the same popup now hosts a service-backed 10-band DSP panel below the media card without bypassing `EqualizerService`;
- the source-side runtime dependency audit now matches callers to packaging: CAVA is covered by distro/Nix paths plus generic guidance, Weather's hard dependency is `curl` with optional Geoclue GPS fallback, and Thinkfan remains an explicitly optional hardware capability whose upstream executable/service/config are never fabricated by Hadalis;
- the stale regression/docs audit found no positive regression dependency on retired Global Style/perimeter/Clock/guessed PanelWindow APIs across the 69 `scripts/test-*` guards; canonical architecture/performance/wallpaper/surface docs and localized READMEs now describe Material as the only Global Theme;
- tray/context-menu output ownership, popup focus lifecycle, reverse retract and exact-menu delayed-close protections remain part of the connected-surface contract.

Maintainer-reported follow-up checklist below is **source-side only**. A checked item means the source condition has been addressed or already exists on current `dev`; it does **not** mark the corresponding release/runtime gate as passed:

- [x] **Thinkfan missing helper after update:** required state-based migration reconciles `/usr/libexec/inir-thinkfan` and the Hadalis polkit action for repo-managed installs. Live update + System Monitor validation is pending.
- [x] **KeyboardFocusRing `Appearance` import:** current source already imports `qs.modules.common`. Live shell update/reload validation is pending.
- [x] **Direct Bar/Screen Edge popup composition:** shared `StyledPopup` keeps source-aware tangent placement but sets `connectorLength: 0`, overlaps the Bar by the shared seam token, and—when corner-clamped—places the body directly on the inner Screen Edge boundary instead of drawing a second connector stem. Popup free sides use the same Screen Edge shadow enable/size/opacity settings, while attached sides suppress shadow to avoid a seam. The shared frame now also fills a token-sized pair of concave endpoint shoulders on each joined edge, approximating Caelestia's smooth blob-union “góc bè” while the popup body itself remains the direct attachment. Double-joined corners suppress the redundant shoulder. Live top/bottom/left/right validation is pending.
- [x] **System Tray connected context menu:** tray right-click menus no longer own a detached `PopupWindow`/private rounded card. `SysTrayItem` passes its real visual item into `SysTrayMenu`, which presents the existing nested menu stack through shared `StyledPopup`; physical Bar-edge normalization, placement-driven Screen Edge joins, concave shoulders, shaped input mask and outside-click ownership therefore match ordinary Bar popups. Existing submenu navigation, Escape, hover-delay close and tray focus-window identity are retained. Live pointer/keyboard/multi-output validation is pending.
- [x] **Bar taskbar connected context menu:** the taskbar's right-click menu uses a narrow `BarContextMenu` wrapper around `StyledPopup` instead of the generic detached `ContextMenu`. The menu therefore grows from the actual taskbar button and shares Bar/Screen Edge join geometry, shoulders, input mask and outside-click behavior. Generic `ContextMenu` remains intentionally available for non-Bar anchors such as text fields, Dock/sidebar content and arbitrary in-window controls. Live taskbar right-click/hover-transfer/keyboard validation is pending.
- [x] **Bar-background connected context menu:** right-clicking the broad left/right Bar zones no longer creates a synthetic 1×1 popup anchor or detached generic `ContextMenu`. `StyledPopup` now accepts an optional source-local `anchorRect` while retaining the real visual control as the ownership/output anchor, so the connected menu can emerge near the actual click point without losing physical Bar-edge normalization. Live corner/middle click-point, top/bottom Bar and multi-output validation is pending.
- [x] **Vertical Bar popup parity:** the Vertical Bar background context menu now uses `BarContextMenu` with the real clicked Bar control + source-local click rect, and Vertical Media's expanded player no longer owns a private `PopupWindow`/backdrop. Both expanded media and its wheel/hover volume HUD now use `Bar.StyledPopup` semantic visibility, shared outside-click/output ownership and the same Media focus restoration as the horizontal Bar. Live left/right Vertical Bar, Media keyboard focus and volume-HUD validation is pending.
- [x] **Workspace hover window previews:** workspace buttons now reuse `BarTaskbarPreview` and the existing `BarTaskbarWindowPreview`/WindowPreviewService capture path instead of introducing another preview shell. Niri workspace previews re-enrich authoritative Niri windows against current foreign-toplevel handles and filter by stable workspace id; Hyprland maps workspace-owned compositor toplevels back to their Wayland handles. Empty workspaces do not open a popup, the existing Dock hover-preview enable/delay settings are reused, and click/close behavior remains the shared preview behavior. Live Niri/Hyprland, multi-output and workspace-move validation is pending.
- [x] **Bar/Screen Edge overlap and color:** Screen Edge ownership now covers both ii (`iiBar`/`iiVerticalBar`) and the supported Waffle `wBar` family on the exact configured output/edge, including each family's stale-`screenList` fallback and `widgetEditMode` unmap lifecycle. The Waffle-owned edge uses `Looks.colors.bg0`; ii keeps the Material `colLayer0` contract. Same-edge Screen Edge/corner overlays are therefore suppressed for either active bar family. Live placement/color validation is pending.
- [x] **Screen Edge width + shared Bar shadow + window-gap boundary:** `appearance.screenEdge` is a typed Config/JsonAdapter object with persistent width plus shadow enable/size/opacity. The horizontal and vertical Bars now render the same inward shadow from those exact settings, so shell chrome stays visually continuous. Persistent Screen Edge bands reserve exactly their solid thickness (the shadow remains visual-only), which makes Niri Window Gap start at the inner Screen Edge/Bar boundary instead of the physical display rim. Live width/shadow/gap validation is pending.
- [x] **On-screen keyboard direct Screen Edge attachment:** the draggable OSK now snaps its body directly onto the inner Screen Edge boundary with `seamOverlap`; the separate connector geometry/stem is removed. Its shadow consumes the same Screen Edge enable/size/opacity settings. Live drag/pin/top/bottom validation is pending.
- [x] **Media Popup CAVA visualizer:** the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path remains the single visualizer path. `WaveVisualizer` renders a Serpantinum-inspired rounded bar field directly in QML; the Bar Media Popup requests 64 samples, the shared CAVA service restarts/re-resolves a stalled source, and raw output pins the expected ASCII range/delimiter. Live play/pause/player-switch/reopen validation is pending.
- [x] **Media Popup 10-band DSP:** a separate DSP section now sits below the media card in the same popup. It uses the existing optional EasyEffects/socat `EqualizerService`, maps the fixed 31 Hz–16 kHz controls to the nearest unique discovered backend bands, keeps the user range at ±12 dB, and ports Serpantinum's eight preset curves. The service is acquired/released with popup presentation and the UI never talks to EasyEffects/socket protocol directly. Live EasyEffects/native+Flatpak validation is pending.
- [x] **Time & Date / Weather hover composition — source fixed:** calendar, 8-hour orbital forecast center and detailed weather right now share one `panelHeight: 270` contract. The large live clock is removed entirely; the center shows only date + current weather summary, the right detail panel no longer dominates the row, and `Last refresh` remains inside the right card. Source regression forbids reintroducing `DateTime.timeDisplay` and requires all three outer panels to share the same height. Live sizing/hover validation is pending.
- [x] **Left/right Sidebar direct Screen Edge attachment:** the sidebar body itself now begins at `screenEdge.width - seamOverlap`; there is no standalone or in-window connector stem. The left, default-right and compact-right outer surfaces also keep their outer border disabled, so Screen Edge owns the shared boundary even when its width is customized. Live left/right validation is pending.
- [x] **Overview direct bottom attachment:** Overview no longer renders connector geometry or a `ConnectedSurfaceConnector`. In dashboard mode the owning Overview window positions the visible dashboard body directly on the inner bottom Bar/Screen Edge boundary; the dashboard squares both joined bottom corners and its shared rectangular shadow clips at the joined bottom edge. Live Meta/Super+Space validation is pending.
- [x] **System Monitor content simplification:** the monitor keeps Used/Total RAM, shortens the temperature header to **Thermal**, and reports CPU/GPU load as percentages only (no Low/Medium/High status text). ThinkFan remains one compact line, with `Fan + toggle` aligned to the RAM column, `Speed` to Thermal, and `Level` to CPU. Error feedback remains conditional below the row. Live alignment validation is pending.
- [x] **Fan Control settings + durable power-profile levels:** **Fan Control** lives in the real **Settings → System** page (with System search routing/indexing) and remains removed from Bar Settings. Power Saver/Balanced/Performance level preferences persist independently of runtime helper readiness, use an explicit serialized Config flush, and are owned by `ThinkFanService` rather than duplicated Settings-side logic. The profile-follow service now reads fan preferences through the revision-aware Config path, reacts when the standalone Settings process changes the config, reapplies the saved active-profile level after startup/status readiness, and skips privileged writes when the hardware already reports the requested level. The shell root keeps the service alive so profile following continues after Settings/System Monitor closes; busy helper operations queue the latest requested level, and leaving ThinkFan managed mode reapplies the active profile level. Runtime apply still requires the repo/package-managed `/usr/libexec/inir-thinkfan` bridge to be current and ThinkPad ACPI direct control to be available; no machine-specific ThinkFan sensor/curve configuration is rewritten.
- [x] **Thinkfan uninstall ownership symmetry:** repo-managed normal/quick uninstall now removes only the Hadalis-owned helper/policy, preserves package-manager-owned bridge files, and never removes/disables upstream Thinkfan package/service/config. Local uninstall-path validation is pending.

Still open / must be treated as unfinished until audited or locally validated:

1. **Material-only active-tree residue is now outside Settings chrome.** `SettingsOverlay.qml` and the standalone `settings.qml` no longer contain legacy `Appearance.*Everywhere` presentation branches. The internal `Appearance.qml` cleanup has now collapsed blur style gates, top-level hover/active aliases, warning/success tokens, canonical rounding and font dispatch to their Material paths while retaining public aliases for caller compatibility. The public motion preset API and the central `Appearance.colors` palette API are now collapsed to their existing Material/contextual fallbacks while preserving property names. The six legacy `Appearance.*Everywhere` names are now inert `false` compatibility constants; popup reveal and the remaining ZZZ-only behavior no longer route through them. `SysTrayMenu.qml` and the shared `ContextMenu.qml` have also been collapsed to their Material chrome while preserving the existing focus/input/close lifecycle; their shared `GlassBackground`/`StyledRadioButton` primitives now follow the same Material-only fallback without removing caller-facing compatibility properties. The shell-wide `RippleButton.qml` renderer is likewise collapsed to its existing Material fallback while retaining caller-facing knobs such as `cookieMorphing`. `StyledComboBox.qml` is now also collapsed to its existing Material fallback while preserving ComboBox/search integration and shared sizing/interaction behavior. The active `FontSelector.qml` and `IconThemeSelector.qml` popup chrome now uses the same Material-only surface tokens directly, `ConfigSelectionArray.qml` no longer routes spacing through the inert Regalia predicate, and the shell-wide `StyledRectangularShadow.qml` renderer now uses only its existing Material blur-shadow fallback while preserving caller-facing shadow knobs. Active Bar callers have also been collapsed where their Material fallback was directly provable: `WeatherBar.qml`, `BarMediaPopup.qml`, `BatteryIndicator.qml`, `ClockWidget.qml`, `NotificationUnreadCount.qml`, `ActiveWindow.qml`, `Resource.qml`, `ClippedProgressBar.qml`, `TimerIndicator.qml`, `ShellUpdateIndicator.qml`, `UtilButtons.qml`, `LeftSidebarButton.qml`, the inline right-sidebar button in `BarContent.qml`, `SysTray.qml`, `BarGroup.qml`, `CircleUtilButton.qml`, `ScrollHint.qml`, `BarTaskbarButton.qml` and `BarTaskbarWindowPreview.qml`. Active Settings/shared primitives now also include Material-only `ConfigSpinBox.qml`, `StyledSpinBox.qml`, `SettingsSwitch.qml`, `SettingsNote.qml`, `SettingsCardSection.qml`, `SettingsGroup.qml`, `StyledTextInput.qml`, `StyledSlider.qml` and the active media `StyledProgressBar.qml`. `Workspaces.qml` has likewise been collapsed to its Material renderer while preserving its independent `forceMaterialStyle` compatibility knob plus workspace switching, occupancy, scroll and app-icon semantics. `PlayerControl.qml` remains a proven active residue cluster with legacy presentation branches across artwork/surface/buttons/seek chrome; audit it component-wide before collapse rather than patching isolated tokens. Continue auditing the remaining exact non-Settings callers before deleting the inert compatibility aliases outright, and retire unused legacy curves/palette objects only when no supported component imports them.
2. **Connected-surface source contract is placement-driven; live validation is still blocking closure.** Every Bar module popup always joins its Bar-facing edge and automatically joins any Screen Edge its resting body actually reaches after placement/clamping; System Monitor has no module-specific edge opt-in. Attached edges are square, suppress shadow, and use shared concave join shoulders so the transition into Bar/Screen Edge has the Caelestia-style flared silhouette without a connector stem. Free corners retain radius. Shared popup shadow is generated from the same asymmetric rounded body silhouette and clipped at joined edges. OSK, Sidebars and Overview keep their direct-edge rules. System Tray menus, ii Bar/Vertical Bar context menus and both horizontal/vertical Media popouts consume the connected popup path; generic non-Bar `ContextMenu` remains detached by design. Workspace hover now reuses the existing connected Bar taskbar preview path.
3. **No authoritative local pass has been run for this source state.** Calendar/Weather sizing/scaling, Thinkfan bridge reconciliation, CAVA lifecycle, 10-band DSP/EasyEffects behavior, Screen Edge behavior and compositor interactions still require the maintainer's local validator plus live Niri/Hyprland smoke checks.

Recommended next source-side sequence:

1. refetch `dev` and `stable`, inspect every concurrent commit, and re-read README/targets on the latest HEAD before editing;
2. preserve the direct-body/no-stem placement contract; the newer source-side Caelestia follow-ups (concave shoulders, connected System Tray/Bar-taskbar menus, workspace-specific hover previews) are implemented and now require local/live validation rather than further speculative geometry churn;
3. keep Weather composition frozen unless live validation finds a defect; do not reintroduce the center live clock;
4. hand the exact candidate SHA to the maintainer for `bash scripts/validate-maintainer-local.sh` plus live smoke tests. Do not mark release gates complete before that result exists.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Hãy đọc `README.md` trên branch `dev` trước vì đó là development contract + handoff hiện tại. Làm trực tiếp trên `dev`, không tạo PR trừ khi tôi yêu cầu. Trước mỗi nhóm thay đổi quan trọng và ngay trước mỗi write có khả năng conflict, phải refetch cả `dev` và `stable`, kiểm tra commit mới, rồi đọc lại target file/caller trên đúng HEAD mới nhất. Repo có thể có commit concurrent nên tuyệt đối không sửa dựa trên snapshot cũ, không force push và không rewrite shared history.

Không chạy/check GitHub Actions/CI vì usage limit đã hết. Tôi sẽ chạy `bash scripts/validate-maintainer-local.sh` và live-test Niri/Quickshell một lượt cuối trên máy local. Không được nói test/release đã pass nếu chưa có local result từ tôi.

Mục tiêu UI/UX: giữ kiến trúc/functionality iNiR hiện có nhưng làm connected surfaces theo hướng Caelestia. Không build popup framework mới. Existing bar popups vẫn đi qua `modules/bar/StyledPopup.qml` + `modules/common/perimeter/ConnectedSurface*` + `PerimeterTokens.qml`. Không reintroduce guessed `PanelWindow.active/onActiveChanged`, Pill/Mascot runtime, retired Bar/Dock renderers, Orbit/workspace experiments hay non-Material Global Themes. Waffle vẫn là panel family được support.

Trạng thái source hiện tại đã có:
- persistent Screen Edge + width setting; Screen Edge có wallpaper-facing rounded inner corners;
- connector width dùng shared contract;
- broad legacy `modules/perimeter` runtime/topology/adapters và cutover policy đã được retire/xóa; TUYỆT ĐỐI không dựng lại broad perimeter runtime;
- shared connected-surface primitives đang active ở `modules/common/perimeter/ConnectedSurface*`, `PerimeterTokens.qml` và `modules/bar/StyledPopup.qml`;
- Thinkfan đã tích hợp vào System Monitor/resources popup + Settings; fresh repo-managed install provision helper/polkit bridge và required migration `041-thinkfan-helper-bridge` tự reconcile bridge bị thiếu/outdated trên repo-managed update mà không chạm upstream Thinkfan package/service/config;
- `KeyboardFocusRing.qml` trên current dev đã import `qs.modules.common`; warning `Appearance is not defined` từ runtime cũ cần recheck sau update/reload;
- Bar Settings có facade/content thật;
- public Global Theme là Material-only; runtime boundary đã clamp Material và migration shim vẫn normalize/write-back persisted legacy values;
- Calendar/Weather có composition Serpantinum-inspired cho left/center nhưng giữ detailed Hadalis weather ở right;
- Media Popup giữ source path CAVA -> PlayerControl -> WaveVisualizer và đã có thêm DSP Equalizer 10-band trong cùng popup qua EqualizerService/EasyEffects; cả visualizer lẫn DSP vẫn cần live validation;
- System Tray right-click menu và Bar taskbar context menu đã chuyển sang shared connected `StyledPopup`; generic non-Bar `ContextMenu` vẫn giữ detached semantics có chủ đích;
- workspace hover preview đã reuse `BarTaskbarPreview` + `BarTaskbarWindowPreview` + WindowPreviewService cho cả Niri/Hyprland, không dựng preview framework mới.

Maintainer-reported việc còn phải sửa:
1. Connected popup geometry phải liền với Bar/Screen Edge kiểu Caelestia; connector/body phải align đúng.
2. Nếu Bar chiếm một edge thì không render Screen Edge trên cùng edge đó; Screen Edge dùng cùng surface color contract với Bar.
3. Media Popup phải thực sự hiển thị Equalizer/CAVA.
4. Bỏ hover popup riêng của Time & Date; merge hover vào Weather/Calendar và làm frontend left/center sát Serpantinum hơn, vẫn giữ detailed Hadalis weather ở right.
5. Left/Right Sidebar connector hiện có source nhưng runtime report không thấy nối vào vertical Screen Edge; tìm root cause geometry/visibility.
6. Overview/dashboard mở bằng Super/Meta+Space phải nối vào bottom Screen Edge.
7. Thinkfan uninstall ownership symmetry: repo-managed uninstall chỉ dọn Hadalis helper/policy khi đúng context; không remove/disable upstream Thinkfan package/service/config và không phá package-manager ownership.
8. Packaging/runtime dependency audit đã có source contract và common-perimeter dead runtime cluster đã được dọn; tiếp tục stale regression/docs audit ngoài cluster này mà không biến Thinkfan thành hard dependency hoặc tự tạo fan config.

Sau mỗi nhóm thay đổi: refetch trước write, giữ patch nhỏ/atomic, commit trực tiếp lên `dev`, cập nhật checklist source-side trong README, xác nhận HEAD sau commit và báo root cause/goal, file đã đổi, SHA, source-level contract thay đổi và phần local/runtime validation còn lại.
```
