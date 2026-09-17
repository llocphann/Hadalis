# Hadalis — Development Context / AI Handoff

> This README is intentionally a **working context and handoff document** for maintainers and AI coding agents. It replaces the previous project-facing README while the current UI/runtime refactor is in progress.
>
> **Last context refresh:** 2026-09-17  
> **Primary development branch:** `dev`  
> **Stable branch:** `stable`

## 1. Maintainer workflow contract

These rules are part of the task, not optional suggestions:

- Work directly on **`dev`** unless the maintainer explicitly asks for another branch.
- **Refetch the latest `dev` before every significant group of changes.** Concurrent commits frequently land on this branch; never assume the previous SHA is still current.
- Do **not** create a pull request unless the maintainer explicitly requests one.
- Do **not** run GitHub Actions / hosted CI for the current work. The repository has exhausted its Actions usage allowance; the maintainer performs the authoritative local test pass.
- Keep commits focused and fix forward. Do not rewrite shared history.
- When using ChatGPT, continue in the current chat/GitHub workflow; do not force a Work-mode handoff unless the maintainer asks for it.
- Maintainer communication is normally in Vietnamese and prefers short progress reports.

Before editing a file, read the current caller/consumer and the current version of the target file from `dev`. Before the next significant write, refetch `dev` again.

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

- open connected popups from top, bottom, left and right bar positions;
- verify connector/body remain visually joined throughout animation;
- confirm transparent full-output popup regions remain click-through;
- verify Media Popup equalizer starts/stops with playback and does not spawn unnecessary CAVA work while inactive;
- switch MPRIS players while the Media Popup is open;
- test multi-monitor and fractional scaling;
- exercise tray menus, fullscreen, suspend/resume and lock/unlock;
- verify supported themes still render correctly.

## 11. AI-agent checklist before every change

1. Fetch the latest `dev` branch SHA.
2. Read the current target file from `dev`.
3. Read its caller/consumer or the nearest shared abstraction before changing architecture.
4. Make the smallest coherent change that advances the requested UX.
5. Commit directly to `dev`.
6. Refetch `dev` before starting the next significant change.
7. Do not open a PR unless explicitly asked.
8. Do not run hosted CI while the current usage-limit instruction remains in effect.
9. Report the changed file(s), commit SHA and practical effect concisely.

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

modules/settings/SettingsPageHost.qml
    -> lazy/asynchronous settings page residency

modules/sidebar/SidebarHost.qml
    -> shared sidebar host / role routing / content-sized surface
```

If this document conflicts with the maintainer's newest explicit instruction, **the newest maintainer instruction wins**. Otherwise, use this README as the project handoff context before making changes.
