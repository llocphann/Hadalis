# Hadalis — Development Context / AI Handoff

> This README is intentionally a **working context and handoff document** for maintainers and AI coding agents. It replaces the previous project-facing README while the current UI/runtime refactor is in progress.
>
> **Last context refresh:** 2026-09-17  
> **Primary development branch:** `dev`  
> **Stable branch:** `stable`

## 1. Maintainer workflow contract

These rules are part of the task, not optional suggestions:

- Work directly on **`dev`** unless the maintainer explicitly asks for another branch.
- Treat the latest **`dev` as source of truth** for ongoing work; use `stable` only as the behavioral/architectural baseline when comparing regressions or intended behavior.
- **Refetch the latest `dev` and `stable` before every significant group of changes.** Concurrent commits frequently land on `dev`; never assume the previous SHA is still current.
- Do **not** create a pull request unless the maintainer explicitly requests one.
- Do **not** run GitHub Actions / hosted CI for the current work. The repository has exhausted its Actions usage allowance; the maintainer performs the authoritative local test pass.
- Keep commits focused and fix forward. Do not rewrite shared history.
- When using ChatGPT, continue in the current chat/GitHub workflow; do not force a Work-mode handoff unless the maintainer asks for it.
- Maintainer communication is normally in Vietnamese and prefers short progress reports.

Before editing a file, read the current caller/consumer and the current version of the target file from `dev`. Before the next significant write, refetch both branches again.

## 2. Product direction

Hadalis is a Quickshell desktop shell derived from the existing iNiR architecture. The highest priority is **UI/UX**, with Caelestia used as the visual/composition reference for connected surfaces.

The required direction is:

- preserve the existing iNiR component architecture, services, routing, state and functionality;
- make popups and edge surfaces feel physically connected to the bar/screen edge, similar to Caelestia;
- morph/extrude an existing surface from its real source control instead of presenting a detached floating card where practical;
- preserve keyboard focus, outside-click close, hover behavior, multi-monitor ownership and compositor behavior;
- prefer incremental refactors of existing components over parallel replacements.

**Do not build a second popup framework.** Existing iNiR popup/component functionality must be reused and refactored.

## 3. Visual/theme rules

Global theme dialects are supported product features and must remain intact:

- ZZZ
- Regalia
- Aurora
- Angel
- iNiR
- normal Material behavior where applicable

These global themes are **not** the retired per-component renderer/style systems.

Legacy/unwanted renderer families and presentation switches such as old Dock Style, Bar Style, Orbit/Workspace Strip-style experiments, Mascot presentation hooks and similar renderer forks should not be revived. Compatibility fields may remain only when required for migration/backward compatibility; they must be inert if the active runtime no longer supports that renderer.

Waffle is a separate supported panel family, not a Dock style and not a legacy ii renderer.

## 4. Connected popup architecture — keep using this

The current connected-popup implementation is built around the existing bar popup abstraction:

- `modules/bar/StyledPopup.qml`
- `modules/common/perimeter/ConnectedSurfaceGeometry.qml`
- `modules/common/perimeter/ConnectedSurfaceConnector.qml`
- `modules/common/perimeter/ConnectedSurfaceFrame.qml`
- `modules/common/perimeter/ConnectedSurfaceContentHost.qml`
- `modules/common/perimeter/ConnectedSurfaceMask.qml`
- `modules/common/perimeter/PerimeterTokens.qml`

`StyledPopup.qml` remains the popup entry point for existing bar popouts. It resolves placement from the **real source item/window**, owns the full-output transparent host, and uses connected geometry + shaped input regions so the visible body/connector behaves as one surface.

Do not replace this with a new detached `PopupWindow` implementation simply to solve layout or focus problems. Fix the shared connected-surface path instead when the issue belongs there.

### Popup contract and lifecycle invariants

These invariants are intentional and should be checked before changing popup code:

- Anchor a popup from the **actual visual source control / `hoverTarget`**, never from the `LazyLoader` window or another lifecycle wrapper.
- `StyledPopup.presentationWindow` is the window presented to consumers that need window-level focus/menu ownership. Keep this explicit rather than making consumers discover an implementation window indirectly.
- Placement must continue to account for output transforms and the popup window's effective `devicePixelRatio`; top/bottom/left/right bars, vertical bars, fractional scaling and transformed outputs are all supported cases.
- Keep layer-shell keyboard focus through `WlrLayershell.keyboardFocus`. Hyprland additionally uses `CompositorFocusGrab`; Niri relies on the layer-shell focus path plus the outside-click backdrop.
- `closeOnOutsideClick` uses the full-output transparent backdrop. Do not replace it with a detached popup implementation that changes click-through/input ownership semantics.
- Tray menu delayed-close handling must release focus/grab only for the **exact menu window that actually closed**. If another tray menu became active during the delay, the old close event must not tear down the new menu's grab.
- Quickshell `PanelWindow` does **not** provide the `active` / `onActiveChanged` API assumed by an earlier regression. Never add `PanelWindow.active`, `PanelWindow.onActiveChanged`, or equivalent guessed focus hooks without verifying the current Quickshell API first.
- Preserve reverse retract / hover-bridge behavior so moving between the source control and connected body does not introduce a detached-feeling close/reopen cycle.

## 5. Full Connected Perimeter runtime

Hadalis also contains the broader `iiPerimeter` composition runtime with topology, per-output placement, module adapters and guarded cutover/fallback policy.

Important distinction:

- **Connected bar popups** already use the shared connected-surface primitives and do not depend on broad `iiPerimeter` ownership.
- The **full perimeter composition cutover** remains guarded until it has enough parity with the legacy panel graph.

Do not couple ordinary bar-popup behavior to the full perimeter cutover.

## 6. Current implementation status

### Connected bar popups

The shared connected geometry is active in `StyledPopup.qml`. The host supports top/bottom/left/right attachment, source-aware placement, reveal/retract morphing, seam overlap and shape-aware input masking.

Continue improving visual continuity toward the Caelestia reference, but keep the existing popup contents and behaviors.

### Compatibility-only type shims

Two compatibility types currently exist only to keep surviving callers loadable while retired feature runtimes stay removed:

- `modules/pill/IslandPanel.qml` is a minimal alias to `RicelinSurface` and is exported by `modules/pill/qmldir`. It exists for legacy callers such as sidebar/overview paths that still import the old type name. **Do not rebuild the former Pill architecture around it.**
- `services/MascotChaos.qml` is a disabled no-op singleton (`enabled: false`) exported by `services/qmldir`. It preserves the old signal/function surface for background-widget callers only. **Do not restore mascot state, physics, presentation or runtime behavior.**

If another `Type X is unavailable` error appears, trace the dependency chain to the concrete missing/invalid type first. Add only the narrowest compatibility shim necessary for compilation; do not revive a retired subsystem.

### Settings > Bar compatibility route

`SettingsPageRegistry.qml` deliberately routes the public Bar page to `modules/settings/BarConfigHugOnly.qml`. The older `BarConfig.qml` remains only as a compatibility implementation for persisted configuration parsing. Hug is the sole supported Classic Bar surface geometry; retired Float/Rectangle/Card controls must not reappear through Settings routing.

### Media popup equalizer

The bar-attached Media Popup previously rendered `PlayerControl` with:

```qml
visualizerPoints: []
```

while the dock/global media path already fed live CAVA points into the same `PlayerControl`/`WaveVisualizer` implementation.

This has now been corrected on `dev` in commit **`577839ec`** (`fix(media): restore equalizer in bar popup`):

- `BarMediaPopup.qml` owns a `CavaProcess` while media is playing;
- the process is inactive when the popup/player does not need visualization;
- `PlayerControl.visualizerPoints` receives the live CAVA point stream;
- the existing `WaveVisualizer` remains the renderer, so no duplicate equalizer component was added.

This still requires the maintainer's local/live desktop validation.

### Dock cleanup

The old user-facing Dock renderer/style choices were removed/neutralized. The active Dock runtime should not switch among Pill/macOS/Island/M3 renderer families based on `dock.style`. Compatibility data may exist for migration, but it must not reactivate those renderers.

### Settings/runtime performance

Settings already uses asynchronous page loading/LRU-style residency in `SettingsPageHost.qml`. Preserve lazy/deferred loading and avoid rebuilding large settings pages eagerly when fixing UI issues.

### Sidebars

Sidebar roles use the shared `SidebarHost` path and are content-sized. Preserve role routing, open/close state, compositor ownership, resize/edit behavior and fallback semantics while adjusting visuals.

## 7. Current priorities

Work in this order unless the maintainer changes priorities:

1. **UI/UX correctness of connected surfaces** — popups should visually read as a continuation of the bar/screen edge, not a nearby independent card.
2. **Media Popup validation** — confirm the newly restored equalizer/CAVA stream works in the bar popup, including pause/resume, player switching and popup close/reopen.
3. **Popup interaction regressions** — keyboard focus, outside click, hover transfer, reverse close/open morph, tray menus and multi-monitor anchoring.
4. **Surface continuity** — remove visible gaps, detached stems, clipping, incorrect corner ownership and fractional-scale seams.
5. **Settings responsiveness** — keep page construction incremental/lazy and avoid regressions from large synchronous component trees.
6. **Compatibility cleanup** — remove active reads of retired renderer/style features without breaking migrations or supported global themes.

## 8. Functionality that must not regress

When changing UI geometry or presentation, retain existing behavior wherever it already exists:

- MPRIS player switching, play/pause, previous/next, seek and volume;
- CAVA/visualizer behavior where currently supported;
- keyboard navigation/focus and Escape close;
- click-outside close;
- hover-open/hover-transfer behavior;
- system tray and nested tray-menu behavior;
- drag/reorder flows in Dock/task surfaces;
- multi-output routing and correct source-screen ownership;
- fullscreen, lock, suspend/resume and compositor transitions;
- Niri as the primary compositor target, with existing Hyprland compatibility preserved;
- global style dialect behavior.

## 9. Reference strategy

Caelestia is a **behavior and composition reference**, not a codebase to merge wholesale.

Useful Caelestia concepts include:

- one coherent edge/window composition;
- popouts that deform/grow from the bar instead of appearing detached;
- shared surface/background ownership;
- connected geometry that remains attached throughout enter/exit animation.

Hadalis must keep its own services, state model, feature components, configuration and lifecycle.

## 10. Validation policy

For the current development cycle:

- **Do not rely on GitHub Actions.**
- The maintainer will perform a local test pass after the implementation batch is complete.
- Static reasoning/source inspection is still expected before committing.
- A change is not considered live-validated merely because the QML is structurally correct.

High-value local checks include:

- open **Settings > Bar** and confirm the Hug-only page loads without exposing retired corner-style renderers;
- open **Sidebar Left**, **Sidebar Right**, **Overview** and **Waffle** entry paths and confirm no `Type ... unavailable` dependency failure;
- open connected popups from **top, bottom, left and right** bar positions, with extra attention to bottom-right anchors;
- verify connector/body remain visually joined throughout animation and reverse retract;
- confirm transparent full-output popup regions remain click-through while outside-click close still works;
- exercise keyboard focus/Escape/outside-click behavior on both **Niri** and **Hyprland**;
- open tray context menus, switch directly between tray items, reopen menus, and confirm a delayed close from an old menu cannot release the current menu's focus grab;
- verify Media Popup equalizer starts/stops with playback, switch MPRIS players, close the popup, then reopen it via keyboard and confirm initial focus is usable;
- test multi-monitor ownership, fractional scaling, transformed outputs and vertical bars;
- exercise fullscreen, suspend/resume and lock/unlock;
- verify supported themes still render correctly.

## 11. AI-agent checklist before every change

1. Fetch the latest `dev` and `stable` branch SHAs.
2. Treat current `dev` as source of truth and `stable` only as behavioral/architectural baseline.
3. Read the current target file from `dev`.
4. Read its caller/consumer or the nearest shared abstraction before changing architecture.
5. Make the smallest coherent change that advances the requested UX.
6. Commit directly to `dev`.
7. Refetch both branches before starting the next significant change.
8. Do not open a PR unless explicitly asked.
9. Do not run hosted CI while the current usage-limit instruction remains in effect.
10. Report the changed file(s), commit SHA and practical effect concisely.

## 12. Historical integration note

A large cleanup/refactor batch was previously merged from `dev` to `stable` through PR #12. The stable merge commit was `8bfbce8c`. Treat that only as historical context; **always inspect current `dev`** for ongoing work because development continues after that merge.

## 13. Source map for the current task

```text
modules/bar/Media.qml
    -> opens existing StyledPopup for bar-mode media

modules/bar/StyledPopup.qml
    -> shared source-anchored connected popup host
    -> ConnectedSurfaceGeometry / Frame / Mask / ContentHost

modules/mediaControls/BarMediaPopup.qml
    -> content for bar-attached expanded media
    -> now owns live CavaProcess points for equalizer

modules/mediaControls/PlayerControl.qml
    -> existing player UI and WaveVisualizer renderer

modules/mediaControls/MediaControls.qml
    -> dock/global media presentation
    -> useful reference for CavaProcess lifecycle

modules/common/perimeter/
    -> shared connected-surface geometry/render/input primitives

modules/settings/SettingsPageRegistry.qml
    -> public Settings routing; Bar page points to BarConfigHugOnly.qml

modules/settings/SettingsPageHost.qml
    -> lazy/asynchronous settings page residency

modules/sidebar/SidebarHost.qml
    -> shared sidebar host / role routing / content-sized surface

modules/pill/IslandPanel.qml
    -> compatibility alias only; do not restore the retired Pill runtime

services/MascotChaos.qml
    -> disabled compatibility singleton only; do not restore mascot runtime
```

If this document conflicts with the maintainer's newest explicit instruction, **the newest maintainer instruction wins**. Otherwise, use this README as the project handoff context before making changes.
