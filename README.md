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

> **Current source pass (2026-09-18; local runtime validation still pending):** the newest maintainer report is implemented source-side before any further cleanup. Classic Bar geometry is now authoritatively Hug from schema/defaults through runtime sizing/reservation, so stale Float/Card values can no longer remove its inverse-corner shoulders or switch shadow paths; Bar, Vertical Bar, Screen Edge and connected popups use the canonical M3 shadow ink, and popup shadows stay live while translated instead of relying on a cached effect. Connected shoulders now reuse the same `RoundCorner` primitive as Hug Bar rather than a second Canvas renderer, with outward orientation mappings matching the former flare silhouettes exactly. Shared popup motion follows Caelestia's normalized `offsetScale` model with the existing 500 ms expressive-default-spatial token, translates only on the attachment axis, reverses from the current value, and preserves the spatial curve's small overshoot while semantic reveal/input stays clamped. Settings, Dashboard, OSK, Sidebar slide and Bar auto-hide consume the same default-spatial motion token. For MPD/rmpc, Media remains MPRIS-based: Arch bundles now include `mpd-mpris`, required migration `042-mpd-mpris-bridge` adds it to existing repo-managed Arch installs, and `MprisController` probes local MPD plus the bridge, starts `mpd-mpris.service` when needed, and still reacts to MPD PipeWire streams. These are source contracts only until the maintainer completes the Niri/Quickshell live pass.

### A. Screen Edge and connected surfaces — P0

> **Latest maintainer correction (2026-09-18): connected surfaces are still visually incomplete.** A connected popup must slide *under* its owning Bar/Screen Edge, not over it; every attachment endpoint must show Caelestia-style concave/flared shoulders; and every free side must carry the same configured Screen Edge/Bar shadow language. Left/right Sidebars need the same flared endpoint treatment. Dashboard must behave as a bottom-connected popup with slide-under motion, flares and matching shadow. Do not reintroduce connector stems or private gaps.

- [ ] **Screen Edge exists both while idle and while a window is maximized.** It must not disappear simply because no maximized window is present.
- [ ] **Screen Edge width is configurable in Settings.** The setting must use one canonical configuration field, have a safe default/range and update the active edge without requiring an alternate renderer.
- [ ] **All connected surfaces use one shared direct-attachment contract.** No popup may draw a connector/stem or invent a private gap. Shared geometry owns seam overlap, joined-edge corner ownership, concave union shoulders and shadow clipping.
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

> **Latest maintainer correction (2026-09-18):** keep the existing version-compatible 10-to-32-band preset backend and reproduce Serpantinum's preset-change electricity/lightning sweep across the ten bands. Source now adds that presentation-only sweep and per-band pulse without creating a second DSP backend. Live visual/audio validation remains pending.

- [ ] The bar-attached Media Popup renders the existing **CAVA -> `PlayerControl` -> `WaveVisualizer`** path instead of an empty visualizer input.
- [ ] The same Media Popup includes a **10-band DSP Equalizer** below the player card, using the existing optional `EqualizerService` / EasyEffects backend rather than a second ad-hoc equalizer process. User-facing bands are 31/63/125/250/500/1k/2k/4k/8k/16k Hz with the Serpantinum Flat/Bass/Treble/Vocal/Pop/Rock/Jazz/Classic curves.
- [ ] Confirm the required CAVA runtime/package is present in the supported install/package paths, or document/install it where currently missing. EasyEffects + socat remain optional capabilities and must degrade gracefully when absent.
- [ ] Visualizer/equalizer lifecycle is efficient: start only when needed, stop when unused, and survive pause/resume, player switching and popup close/reopen.
- [ ] MPRIS controls, seek, volume and keyboard behavior do not regress while the visualizer/DSP controls are active.

### F. Calendar / Weather v1.0 composition — P0

> **Latest maintainer runtime finding (2026-09-18):** the hourly orbit/timeline was visually crowded. Source now reduces each hour cell from 58×72 to 52×64, uses the normal Material radius, and slightly widens the ellipse so adjacent cells retain visible separation. Live sizing/scaling validation is pending.

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

## 3.1 Latest maintainer runtime findings

The following issues were reproduced visually/runtime-side on 2026-09-18 and remain open until revalidated after source fixes:

- Bar/popup shoulders and shadow regression: the latest report showed all flare/concave corners gone and Bar/popup shadows intermittently missing. Source now removes the startup/runtime race with retired `bar.cornerStyle` geometry, fixes Material/Hug defaults to `0`, makes Hug background structural, disables detached Float/Card geometry/shadows, lets Bar/Screen Edge shadows continue beneath inverse-corner shoulders so later `RoundCorner` paint shapes the visible curved transition, renders popup shadows live above the host background, and reuses `RoundCorner` for every connected shoulder. Live top/bottom/left/right and rapid open/close validation remains.
- Caelestia-style slide motion: shared popups now use normalized `offsetScale` (1 closed → 0 open) with one expressive-default-spatial curve for enter, exit and reversal, matching Caelestia's wrapper/clip model instead of asymmetric accel/decel timing. Attachment-axis translation preserves the expressive curve's overshoot while reveal/input progress remains clamped. Settings overlays, Dashboard, OSK, Sidebar slide and Bar auto-hide now use the same spatial token. Live frame-pacing/reversal validation remains.
- MPD/rmpc Media discovery: `rmpc` remains an MPD client rather than an MPRIS provider, so Hadalis now packages `mpd-mpris` for the Arch audio/full-experience paths, required migration `042-mpd-mpris-bridge` reconciles existing repo-managed Arch installs, and Media probes local MPD at startup. When MPD is running without an MPD MPRIS object, `MprisController` starts the user `mpd-mpris.service`; PipeWire stream detection remains a second trigger and direct-ALSA MPD is covered by the process probe. Live default/custom MPD endpoint validation remains.
- Screen Edge lower corners: maintainer live-tested `818efdb9` and confirmed the lower inverse-corner geometry matches the top Bar/Screen Edge reference, then live-tested the first side-shadow continuation and still found a visible cut in both lower-corner shadows. The remaining defect is now isolated to shadow math, not corner geometry: two axis-aligned linear gradients cannot represent the constant-width shadow of a quarter-circle, so their union leaves an under-shadowed patch around the middle of each arc. The source candidate replaces those stitched corner rectangles with a `Qt5Compat.GraphicalEffects.RadialGradient` over the exact R×R corner box. Its inner stop is `(R - shadowExtent) / R`, and its center is placed at the same quarter-circle center as `RoundCorner`, so the radial profile reduces exactly to the existing straight side/bottom gradient at both tangents. Straight shadows now stop at the corner box; the radial primitive alone owns the curved segment. Live lower-left/lower-right shadow continuity validation is still required.
- Popup Bar/Screen Edge hover hand-off: the supplied recordings showed transient popup loss while crossing the seam; shared ii popups now track the complete body and wait 90 ms before hover-only retract, while Waffle's existing delayed-close path also includes full-body hover. Live high-frequency pointer crossing remains.
- Sidebar endpoint shoulders: shared flares map the nested body through `mapToItem()`, and SidebarHost no longer applies the Loader translation a second time. Live left/right flare placement during slide/drop remains.
- Compact Right Sidebar Media: the shared `EqualizerPanel` now sits immediately below `CompactMediaPlayer` and follows Sidebar presentation lifecycle. Live sizing/DSP validation remains.
- Settings surfaces: both overlay hosts are substantially larger while retaining direct bottom attachment, square joined corners and shared bottom flares. Live 16:9/16:10/scaled-output sizing remains.
- Privileged power/fan actions: the exact root-owned ThinkFan and TLP helper actions now allow only the active local session without a password prompt; inactive/non-local subjects are denied, and the state-based repo migrations refresh changed policy assets. Live installed-policy validation remains.
- Sidebar General settings: the Island selector and Use Card style switch are removed; legacy values normalize to Panel/non-card at startup and the retired Sidebar-style search entry is gone. Live Settings navigation/search validation remains.
- Media transport controls: source fix removes hover text tooltips for Previous / Pause-Play / Next; live hover validation remains.
- Media DSP: backend compatibility fix remains; source now adds the Serpantinum-style electricity/lightning sweep and per-band pulse whenever a preset apply is accepted. Live visual/audio validation remains.
- Shared popup motion: source now translates the complete body and clips at the real Bar/Screen Edge attachment boundary, so reveal/retract slides underneath rather than over the owner; live top/bottom/left/right validation remains.
- Connected popup silhouette: shared connected popups keep the Caelestia-style concave endpoint shoulders, now rendered above the body inside the fixed reveal viewport; live silhouette validation remains.
- Connected popup shadow: shared popup shadow now uses the stable radius-aware `RectangularShadow` path with the configured Screen Edge/Bar size/opacity on free sides and hard clipping on attached sides; live shadow validation remains.
- Weather center timeline: source fix reduces hour-cell size and widens the orbit slightly; live spacing/scaling validation remains.
- Left/Right Sidebars: physical-edge underlap remains; source now reserves endpoint decoration room and renders host-owned Caelestia-style concave/flared shoulders above/below the connected body. Live left/right validation remains.
- Dashboard: source now treats the bottom-connected dashboard as a popup: its body translates downward under a clipped bottom boundary, generic Overview scale/fade is disabled in dashboard presentation mode, bottom endpoint flares use the shared primitive, and free-side shadow consumes Screen Edge settings. Live open/retract validation remains.
- On-Screen Keyboard: source now snaps the visible body to the physical top/bottom display edge, underlaps the full Screen Edge band, and adds shared concave join shoulders; live drag/pin/top/bottom validation remains.

## 4. Connected-surface architecture contract

The existing popup path remains authoritative:

```text
modules/bar/StyledPopup.qml
modules/common/perimeter/ConnectedSurfaceGeometry.qml
modules/common/perimeter/ConnectedSurfaceJoinFlares.qml
modules/common/perimeter/ConnectedSurfaceFrame.qml
modules/common/perimeter/ConnectedSurfaceContentHost.qml
modules/common/perimeter/ConnectedSurfaceMask.qml
modules/common/perimeter/PerimeterTokens.qml
```

Rules:

- `StyledPopup.qml` remains the entry point for existing bar popouts.
- Shared geometry/tokens own seam overlap, placement-driven edge attachment, joined-edge corner ownership, concave union shoulders and shadow clipping.
- Consumers provide content and source ownership; they must not recreate connector/stem geometry or private edge gaps.
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

## 11. Current source-side handoff (2026-09-18)

This section records the **current source implementation state**, not local/runtime validation. Keep release-gate checkboxes above unchecked until the maintainer performs the authoritative local pass.

Source work already present on `dev`:

- the latest three-item follow-up is represented source-side: one authoritative Hug Bar geometry/shadow contract with shared `RoundCorner` shoulders, Caelestia-style normalized expressive-spatial slide/reversal across connected surfaces, and MPD/rmpc Media integration through the packaged `mpd-mpris` bridge; all three still require the maintainer's live Niri/Quickshell pass;
- the latest maintainer eight-item follow-up is represented source-side: explicit lower Screen Edge corner painting, corrected Sidebar flare coordinate mapping, Compact Right Sidebar Equalizer placement, enlarged bottom-connected Settings surfaces, active-local promptless ThinkFan/TLP polkit policies, solid connected-popup Dashboard material, retirement/normalization of Sidebar Island/Card settings, and a shared popup hover hand-off debounce/full-body hover contract; all eight still require the maintainer's live Niri/Quickshell pass;
- persistent Screen Edge surfaces exist in `modules/screenCorners/ScreenEdges.qml`; they are intended to remain visible while idle/normal/maximized and hide only for explicit fullscreen/lock cases;
- Screen Edge width is exposed through the active Bar Settings path, and the edge now paints wallpaper-facing rounded inner corners without changing the rectangular physical edge bands;
- connected popups use shared direct-body attachment geometry: seam overlap, placement-driven touched-edge joins, concave union shoulders and joined-edge shadow clipping are centralized instead of drawing connector stems;
- `modules/sidebar/SidebarHost.qml` now attaches the Left/Right sidebar body directly to the inner vertical Screen Edge boundary using the shared seam overlap; both the old standalone bridge window and the later in-window connector stem are retired;
- the broad legacy `modules/perimeter` runtime/topology/adapters have been retired and removed after caller auditing; the old cutover policy was removed as well, and regression contracts were aligned with the supported connected-surface architecture;
- the dead common perimeter host/config/cutover/route compatibility cluster has also been removed; `PerimeterTopology.qml` remains only as the small edge utility used by `ConnectedSurfaceGeometry.qml`;
- shared connected-popup primitives remain active and protected under `modules/common/perimeter/ConnectedSurface*`, `PerimeterTokens.qml`, and `modules/bar/StyledPopup.qml`; do not recreate the retired broad runtime to solve popup issues;
- Thinkfan standalone connected-surface/content files have been removed from normal UX; Thinkfan controls/state are integrated into the existing System Monitor/resources popup and Settings. Fresh repo-managed installs provision the Hadalis helper/polkit bridge, and required migration `041-thinkfan-helper-bridge` reconciles missing/outdated Hadalis-owned bridge files during repo-managed updates without modifying upstream Thinkfan package/service/config ownership;
- `modules/common/widgets/KeyboardFocusRing.qml` imports `qs.modules.common` on current `dev`, so the earlier `Appearance is not defined` warning belongs to an older runtime snapshot and must be rechecked only after the local shell updates/reloads to current source;
- `Settings > Bar` has a real supported v1.0 facade/content path instead of the previous blank route;\n- Classic Bar module visibility now has one orientation-independent source of truth: Left/Right `VerticalBarContent.qml` consumes the same `bar.modules.*` flags as Top/Bottom, including Active Window, Resources, Media, Workspaces, Clock, Utility Buttons, Battery, Weather, System Tray and both sidebar buttons. Enabling the vertical Taskbar no longer silently suppresses Resources/Media. The Top/Bottom drag-order editor is explicitly hidden while the Bar is vertical because Left/Right keeps a compact fixed order; its saved horizontal order is preserved when switching back. This is source-side only until the maintainer runs the local validator and live left/right Bar smoke pass;
- public Global Theme Settings are constrained to Material, persisted legacy style values normalize/write back to Material, and the runtime `Appearance.globalStyle` boundary is clamped to Material so a persisted legacy style cannot transiently reactivate an old Global Theme branch during startup;
- the Material-only Settings cleanup now removes the retired Global Style tab/sections/search entries and dangling legacy editor loaders from the base Themes page; the public facade retains only a narrow stale-section redirect plus persisted-value normalization, while runtime visual validation remains part of the local release pass;
- the Calendar/Weather composition has source implementation for the requested Serpantinum-inspired left/center presentation while retaining Hadalis detailed weather ownership/content on the right;
- Media Popup owns the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path and gates visualizer activity by popup presentation/playback lifecycle; the same popup now hosts a service-backed 10-band DSP panel below the media card without bypassing `EqualizerService`;
- the source-side runtime dependency audit now matches callers to packaging: CAVA is covered by distro/Nix paths plus generic guidance, Weather's hard dependency is `curl` with optional Geoclue GPS fallback, and Thinkfan remains an explicitly optional hardware capability whose upstream executable/service/config are never fabricated by Hadalis;
- the stale regression/docs audit found no positive regression dependency on retired Global Style/perimeter/Clock/guessed PanelWindow APIs across the 74 `scripts/test-*` guards; canonical architecture/performance/wallpaper/surface docs and localized READMEs now describe Material as the only Global Theme;
- tray/context-menu output ownership, popup focus lifecycle, reverse retract and exact-menu delayed-close protections remain part of the connected-surface contract.

Maintainer-reported follow-up checklist below is **source-side only**. A checked item means the source condition has been addressed or already exists on current `dev`; it does **not** mark the corresponding release/runtime gate as passed:

- [x] **Thinkfan missing helper after update:** required state-based migration reconciles `/usr/libexec/inir-thinkfan` and the Hadalis polkit action for repo-managed installs. Live update + System Monitor validation is pending.
- [x] **KeyboardFocusRing `Appearance` import:** current source already imports `qs.modules.common`. Live shell update/reload validation is pending.
- [x] **Direct Bar/Screen Edge popup composition:** shared `StyledPopup` keeps source-aware tangent placement but sets `connectorLength: 0`, overlaps the Bar by the shared seam token, and—when corner-clamped—places the body directly on the inner Screen Edge boundary instead of drawing a second connector stem. Popup free sides use the same Screen Edge shadow enable/size/opacity settings, while attached sides suppress shadow to avoid a seam. The shared frame now also fills a token-sized pair of concave endpoint shoulders on each joined edge, approximating Caelestia's smooth blob-union “góc bè” while the popup body itself remains the direct attachment. Double-joined corners suppress the redundant shoulder. Live top/bottom/left/right validation is pending.
- [x] **Shared popup slide-under reveal:** `ConnectedSurfaceGeometry` preserves full body size and now translates by the complete cross-axis extent. `ConnectedSurfaceRevealClip` fixes the visible viewport at the real Bar/Screen Edge boundary derived from the source anchor, hiding the translated portion underneath the owner; `ConnectedSurfaceMask` likewise exposes only the visible body region for input. ii `StyledPopup` and Waffle `BarPopup` both consume this path with no staged content fade. The shared frame uses radius-aware `RectangularShadow` instead of the previous `MultiEffect` shadow path, while `ConnectedSurfaceJoinFlares` renders above the body. Live top/bottom/left/right/reverse-retract validation is pending.
- [x] **System Tray connected context menu:** tray right-click menus no longer own a detached `PopupWindow`/private rounded card. `SysTrayItem` passes its real visual item into `SysTrayMenu`, which presents the existing nested menu stack through shared `StyledPopup`; physical Bar-edge normalization, placement-driven Screen Edge joins, concave shoulders, shaped input mask and outside-click ownership therefore match ordinary Bar popups. Existing submenu navigation, Escape, hover-delay close and tray focus-window identity are retained. Live pointer/keyboard/multi-output validation is pending.
- [x] **Bar taskbar connected context menu:** the taskbar's right-click menu uses a narrow `BarContextMenu` wrapper around `StyledPopup` instead of the generic detached `ContextMenu`. The menu therefore grows from the actual taskbar button and shares Bar/Screen Edge join geometry, shoulders, input mask and outside-click behavior. Generic `ContextMenu` remains intentionally available for non-Bar anchors such as text fields, Dock/sidebar content and arbitrary in-window controls. Live taskbar right-click/hover-transfer/keyboard validation is pending.
- [x] **Bar-background connected context menu:** right-clicking the broad left/right Bar zones no longer creates a synthetic 1×1 popup anchor or detached generic `ContextMenu`. `StyledPopup` now accepts an optional source-local `anchorRect` while retaining the real visual control as the ownership/output anchor, so the connected menu can emerge near the actual click point without losing physical Bar-edge normalization. Live corner/middle click-point, top/bottom Bar and multi-output validation is pending.
- [x] **Vertical Bar popup parity:** the Vertical Bar background context menu now uses `BarContextMenu` with the real clicked Bar control + source-local click rect, and Vertical Media's expanded player no longer owns a private `PopupWindow`/backdrop. Both expanded media and its wheel/hover volume HUD now use `Bar.StyledPopup` semantic visibility, shared outside-click/output ownership and the same Media focus restoration as the horizontal Bar. Live left/right Vertical Bar, Media keyboard focus and volume-HUD validation is pending.
- [x] **Waffle shared BarPopup connected presentation:** Waffle keeps its own `BarPopup` API/palette and remains a separate supported panel family, but the popup implementation no longer uses compositor `PopupWindow` + visual-margin gap geometry. It now reuses `ConnectedSurfaceGeometry/Frame/ContentHost/Mask`, direct Bar-edge overlap, Caelestia-style concave shoulders, shaped input and same-output Niri backdrop; Waffle callers retain `close()`, `grabFocus()`, `updateAnchor()`, hover-delay and focus-cleared contracts. `visualMargin` now controls free-side shadow extent instead of creating separation. The Waffle Bar-background menu also uses source-local `anchorRect` on the real Bar MouseArea instead of a synthetic 1×1 anchor, preserving click-point placement and output ownership. Live Start/Tray/Updates/context-menu validation is pending.
- [x] **Waffle task preview connected presentation:** the final Waffle Bar-specific detached `PopupWindow` in `tasks/TaskPreview.qml` is retired. Task preview now consumes `BarPopup` while preserving `WindowPreviewService` capture, 250 ms pointer bridge, delayed preview-resource release, app/toplevel tiles and panel-open dismissal. `Tasks.qml` no longer configures the removed compositor `anchor.window` API. Live hover-transfer, close/reopen, Niri capture and multi-output validation is pending.
- [x] **Workspace hover window previews:** workspace buttons now reuse `BarTaskbarPreview` and the existing `BarTaskbarWindowPreview`/WindowPreviewService capture path instead of introducing another preview shell. Niri workspace previews re-enrich authoritative Niri windows against current foreign-toplevel handles and filter by stable workspace id; Hyprland maps workspace-owned compositor toplevels back to their Wayland handles. Empty workspaces do not open a popup, the existing Dock hover-preview enable/delay settings are reused, and click/close behavior remains the shared preview behavior. Live Niri/Hyprland, multi-output and workspace-move validation is pending.
- [x] **Bar-owned popup coverage guard:** local validation now scans the supported ii horizontal/vertical Bar and Waffle Bar source trees for direct `PopupWindow` regressions, rejects generic `ContextMenu` declarations inside ii Bar callers, and asserts the known Battery/Resources/Weather/Timer/Media/Tray/task-preview surfaces stay on `StyledPopup`/connected `BarPopup`. Hover-only tooltip primitives remain outside this interactive popup/menu contract. Runtime geometry still requires live validation.
- [x] **P0 Settings reachability/search contract:** public Settings resolves Quick/Bar through the Hug-only facades, the Bar page owns the persistent Screen Edge width/shadow controls, and System owns Fan Control through `ThinkFanService`. Static search now indexes Screen Edge width/shadow before lazy page materialization and no longer advertises the retired Float/Rectangle `Corner style` selector. The Quick Hug facade also no longer hides the entire page behind its zero-delay compatibility pass, matching the blank-page fix already used by the Bar facade. A dedicated local regression guard locks these routes and prevents dead controls/readiness gates from returning. Live Settings navigation/spotlight validation is pending.
- [x] **Bar/Screen Edge overlap and color:** Screen Edge ownership now covers both ii (`iiBar`/`iiVerticalBar`) and the supported Waffle `wBar` family on the exact configured output/edge, including each family's stale-`screenList` fallback and `widgetEditMode` unmap lifecycle. The Waffle-owned edge uses `Looks.colors.bg0`; ii keeps the Material `colLayer0` contract. Same-edge Screen Edge/corner overlays are therefore suppressed for either active bar family. Live placement/color validation is pending.
- [x] **Screen Edge width + shared Bar shadow + window-gap boundary:** `appearance.screenEdge` is a typed Config/JsonAdapter object with persistent width plus shadow enable/size/opacity. The horizontal and vertical Bars now render the same inward shadow from those exact settings, so shell chrome stays visually continuous. Persistent Screen Edge bands reserve exactly their solid thickness (the shadow remains visual-only), which makes Niri Window Gap start at the inner Screen Edge/Bar boundary instead of the physical display rim. Live width/shadow/gap validation is pending.
- [x] **On-screen keyboard direct Screen Edge attachment:** the draggable OSK no longer stops at the inner Screen Edge boundary. Top snap uses `y = 0`, bottom snap uses `screenHeight - keyboardHeight`, so the visible body underlaps the complete persistent Screen Edge band; the shared `ConnectedSurfaceJoinFlares` adds Caelestia-style shoulders at the two attachment endpoints. The connector stem remains retired and shadow still consumes Screen Edge enable/size/opacity settings. Live drag/pin/top/bottom/custom-edge-width validation is pending.
- [x] **Media Popup CAVA visualizer:** the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path remains the single visualizer path. `WaveVisualizer` renders a Serpantinum-inspired rounded bar field directly in QML; the Bar Media Popup requests 64 samples, the shared CAVA service restarts/re-resolves a stalled source, and raw output pins the expected ASCII range/delimiter. Live play/pause/player-switch/reopen validation is pending.
- [x] **Media Popup 10-band DSP:** a separate DSP section sits below the media card in the same popup. It keeps the existing deferred `EqualizerService` boundary and Serpantinum's eight ±12 dB curves, but no longer depends on channel-scoped EasyEffects local-server band properties. The service persists ten gains, renders them into the same 32-band anchor map used by the Serpantinum approach, writes a private `hadalis_live_eq` EasyEffects preset, and loads it through the generic preset command; native and Flatpak preset locations are handled separately. The UI never talks to EasyEffects/socket/preset-file protocol directly. Preset activation now also triggers the Serpantinum-style 650 ms lightning sweep across the ten gain points with per-band track/handle pulse, followed by the reference-style fade tail; this is presentation-only and does not duplicate DSP state. Live EasyEffects native/Flatpak + audio-output/effect validation is pending.
- [x] **Time & Date / Weather hover composition — source fixed:** calendar, 8-hour orbital forecast center and detailed weather right now share one `panelHeight: 270` contract. The large live clock is removed entirely; the center shows only date + current weather summary, the right detail panel no longer dominates the row, and `Last refresh` remains inside the right card. Source regression forbids reintroducing `DateTime.timeDisplay` and requires all three outer panels to share the same height. Live sizing/hover validation is pending.
- [x] **Bar/VerticalBar startup type graph — source fixed:** maintainer logs showed three independent QML graph failures that prevented the Bar from materializing: `VerticalClockWidget.qml` referenced the retired/nonexistent `Bar.ClockWidgetTooltip`; `BarTaskbarPreview.qml` placed `Connections` objects directly under `StyledPopup`, whose default content property accepts only an `Item`; and both Sidebar wrappers still referenced the retired `PerimeterCutoverPolicy`. The tooltip dependency is removed, taskbar preview listeners now live inside its single visual content item, and SidebarLeft/SidebarRight instantiate `SidebarHost` directly for `targetScreens`. `test-styled-popup-content-contract.py` now guards these boot-critical QML contracts. Live shell reload is required before treating Bar/VerticalBar startup as validated.
- [x] **Left/right Sidebar direct Screen Edge attachment:** the owning SidebarHost is still a physical left/right layer surface with no connector stem, and the visible body underlaps the full Screen Edge band all the way to the physical display edge. The host reserves vertical decoration room equal to the shared flare radius and renders `ConnectedSurfaceJoinFlares` at the upper/lower endpoints. The shared flare primitive now maps the nested body into host coordinates with `mapToItem()`; SidebarHost therefore does not apply the Loader's slide/drop translation a second time. Left/default-right/compact-right surfaces expose their real surface color and keep the attached-side border/shadow suppressed. Live left/right/custom-edge-width/animation validation is pending.
- [x] **Overview Dashboard as connected popup:** Overview keeps connector/stem geometry retired and positions Dashboard at the exact bottom Bar/Screen Edge boundary. Dashboard owns a dedicated full-body reveal progress: a translated surface layer travels downward by one complete body height behind its clipped resting boundary, while Dashboard presentation mode disables the generic Overview scale/translate/fade. `ConnectedSurfaceJoinFlares` supplies both bottom shoulders, joined bottom corners remain square, and `StyledRectangularShadow` uses the configured Screen Edge shadow on free sides while suppressing bottom shadow. The outer Dashboard body now stays on solid `Appearance.colors.colLayer0` instead of allowing the generic GlassBackground panel backend to make it visually diverge from connected popups. Reverse close stays mapped through the reveal tail. Live Meta/Super+Space/open-close/search-transition validation is pending.
- [x] **System Monitor content simplification:** the monitor keeps Used/Total RAM, shortens the temperature header to **Thermal**, and reports CPU/GPU load as percentages only (no Low/Medium/High status text). ThinkFan remains one compact line, with `Fan + toggle` aligned to the RAM column, `Speed` to Thermal, and `Level` to CPU. Error feedback remains conditional below the row. Live alignment validation is pending.
- [x] **Fan Control settings + durable power-profile levels:** **Fan Control** lives in the real **Settings → System** page (with System search routing/indexing) and remains removed from Bar Settings. Power Saver/Balanced/Performance level preferences persist independently of runtime helper readiness, use an explicit serialized Config flush, and are owned by `ThinkFanService` rather than duplicated Settings-side logic. The profile-follow service now reads fan preferences through the revision-aware Config path, reacts when the standalone Settings process changes the config, reapplies the saved active-profile level after startup/status readiness, and skips privileged writes when the hardware already reports the requested level. The shell root keeps the service alive so profile following continues after Settings/System Monitor closes; busy helper operations queue the latest requested level, and leaving ThinkFan managed mode reapplies the active profile level. Runtime apply still requires the repo/package-managed `/usr/libexec/inir-thinkfan` bridge to be current and ThinkPad ACPI direct control to be available; no machine-specific ThinkFan sensor/curve configuration is rewritten.
- [x] **Thinkfan uninstall ownership symmetry:** repo-managed normal/quick uninstall now removes only the Hadalis-owned helper/policy, preserves package-manager-owned bridge files, and never removes/disables upstream Thinkfan package/service/config. Local uninstall-path validation is pending.
- [x] **Promptless active-session ThinkFan/TLP authorization:** both shipped polkit actions keep exact `/usr/libexec` helper annotations, deny `allow_any` and `allow_inactive`, and allow only `allow_active` without authentication. Required repo-managed migrations compare and resync changed policy assets, while package-managed installs remain package-owned. This removes routine password prompts without hardcoding credentials or granting a broad arbitrary-command path. Live installed-policy/pkexec validation is pending.
- [x] **Sidebar surface-option retirement:** Sidebars General no longer exposes Island or Use Card style; `SettingsPageRegistry` normalizes old `sidebar.style` / `sidebar.cardStyle` values to Panel/non-card at startup, and RegistryData no longer publishes the retired Sidebar-style search entry. Live Settings navigation/search validation is pending.
- [x] **Compact Right Sidebar Equalizer:** the compact Controls Media section imports and renders the shared `EqualizerPanel` directly below `CompactMediaPlayer`, with registration tied to panel visibility. Live compact Sidebar height/scroll/DSP validation is pending.
- [x] **Connected popup hover-transfer stabilization:** ii `StyledPopup` tracks hover on the complete frame body (not only padded content) and gives the compositor Bar↔popup window hand-off a 90 ms grace period before a hover-only retract. Waffle `BarPopup` also includes shared full-body hover in its existing delayed-close contract. The precise connected input mask remains unchanged, so transparent full-output regions are not made interactive. Live reproduction against both supplied flicker recordings remains pending.
- [x] **Larger connected Settings overlays:** rail and focus Settings hosts use substantially larger responsive width/height caps while preserving direct bottom attachment, square joined bottom corners, shared flares and Polkit layer demotion. Live scaled-output sizing validation is pending.

Still open / must be treated as unfinished until audited or locally validated:

1. **Material-only active-tree residue is now outside Settings chrome.** `SettingsOverlay.qml` and the standalone `settings.qml` no longer contain legacy `Appearance.*Everywhere` presentation branches. The internal `Appearance.qml` cleanup has now collapsed blur style gates, top-level hover/active aliases, warning/success tokens, canonical rounding and font dispatch to their Material paths while retaining public aliases for caller compatibility. The public motion preset API and the central `Appearance.colors` palette API are now collapsed to their existing Material/contextual fallbacks while preserving property names. The six legacy `Appearance.*Everywhere` names are now inert `false` compatibility constants; popup reveal and the remaining ZZZ-only behavior no longer route through them. `SysTrayMenu.qml` and the shared `ContextMenu.qml` have also been collapsed to their Material chrome while preserving the existing focus/input/close lifecycle; their shared `GlassBackground`/`StyledRadioButton` primitives now follow the same Material-only fallback without removing caller-facing compatibility properties. The shell-wide `RippleButton.qml` renderer is likewise collapsed to its existing Material fallback while retaining caller-facing knobs such as `cookieMorphing`. `StyledComboBox.qml` is now also collapsed to its existing Material fallback while preserving ComboBox/search integration and shared sizing/interaction behavior. The active `FontSelector.qml` and `IconThemeSelector.qml` popup chrome now uses the same Material-only surface tokens directly, `ConfigSelectionArray.qml` no longer routes spacing through the inert Regalia predicate, and the shell-wide `StyledRectangularShadow.qml` renderer now uses only its existing Material blur-shadow fallback while preserving caller-facing shadow knobs. Active Bar callers have also been collapsed where their Material fallback was directly provable: `WeatherBar.qml`, `BarMediaPopup.qml`, `BatteryIndicator.qml`, `ClockWidget.qml`, `NotificationUnreadCount.qml`, `ActiveWindow.qml`, `Resource.qml`, `ClippedProgressBar.qml`, `TimerIndicator.qml`, `ShellUpdateIndicator.qml`, `UtilButtons.qml`, `LeftSidebarButton.qml`, the inline right-sidebar button in `BarContent.qml`, `SysTray.qml`, `BarGroup.qml`, `CircleUtilButton.qml`, `ScrollHint.qml`, `BarTaskbarButton.qml` and `BarTaskbarWindowPreview.qml`. Active Settings/shared primitives now also include Material-only `ConfigSpinBox.qml`, `StyledSpinBox.qml`, `SettingsSwitch.qml`, `SettingsNote.qml`, `SettingsCardSection.qml`, `SettingsGroup.qml`, `StyledTextInput.qml`, `StyledSlider.qml` and the active media `StyledProgressBar.qml`. `Workspaces.qml` has likewise been collapsed to its Material renderer while preserving its independent `forceMaterialStyle` compatibility knob plus workspace switching, occupancy, scroll and app-icon semantics. The active media `PlayerControl.qml` has now been collapsed component-wide to its Material fallback as well, while preserving MPRIS/YtMusic control, artwork resolution/cross-slide, CAVA visualization, seek/progress behavior and public caller properties. The active Control Panel tree is now collapsed to Material Global Theme fallbacks: `ControlPanelContent.qml` plus `DateTimeHeader.qml`, `WallpaperSection.qml`, `WeatherSection.qml`, `SlidersSection.qml`, `SystemSection.qml`, `ProfileHeader.qml`, `QuickActionsSection.qml` and `MediaSection.qml` no longer route through the inert legacy Global Theme predicates. The explicit Ricelin island skin remains independent and supported; section enable flags, lazy loaders, entrance cascade/scroll, date/time, wallpaper, weather, sliders, system status, profile/session actions, Quick Actions, artwork-derived media colors, CAVA, seek/progress and MPRIS behavior are retained. Overview's active source tree is now collapsed component-by-component to Material Global Theme presentation. `SearchBar.qml`, `SearchItem.qml`, `SearchWidget.qml`, `ActionModeView.qml`, `OverviewAllAppsGrid.qml`, Hyprland `OverviewWidget.qml` and primary Niri `OverviewNiriWidget.qml` retain their search/action/package/app/workspace/window/preview behavior without legacy Global Theme routing. `OverviewDashboard.qml`, the final Overview residue cluster, now also uses direct Material card/media/weather/system tokens; its newer bottom-connected popup contract is explicitly preserved and regression-guarded: full-body slide-under translation, reveal clipping, bottom-square attachment, shared flares and configured Screen Edge shadow remain intact. Outside Overview, the caller audit has now also collapsed the shared ii/Waffle On-Screen Keyboard body/control/keycap chrome to Material while preserving Ydotool delivery, physical-key feedback, drag/snap behavior and the existing Screen Edge underlap/flares/shadow contract. ScreenCorners is now also collapsed to its Material fake-rounding path while preserving sidebar/orbit hot-corner and brightness/volume interactions for both ii and Waffle. VerticalBar cleanup is now source-complete for the active chrome audited so far: the shared clock/date leaves use Material text/stroke tokens, and `VerticalBarContent.qml` no longer routes through legacy Global Theme predicates/palettes. Its supported islands/cornerStyle/cardStyle behavior, Material compositor blur, connected BarContextMenu, workspaces/taskbar/sys-tray and brightness/volume/sidebar interactions remain intact. Sidebar cleanup now covers `SidebarLeftContent.qml`, the default `SidebarRightContent.qml`, and compact `CompactSidebarRightContent.qml`: their normal shell/card/navigation/action chrome is Material-only while the explicit Ricelin island skin and physical-edge connected geometry remain intact. Left tab reorder/content routes, default-right section reorder/resize/dialog/profile/classic/android flows, and compact-right rail navigation, control ordering, notifications, dialogs, calendar/weather and quick actions remain preserved. The next Material-only step is a fresh active-tree caller audit outside these Sidebar surfaces rather than deleting compatibility aliases blindly.
2. **Connected-surface source contract is placement-driven; live validation is still blocking closure.** Every Bar module popup always joins its Bar-facing edge and automatically joins any Screen Edge its resting body actually reaches after placement/clamping; System Monitor has no module-specific edge opt-in. Attached edges are square, suppress shadow, and use shared concave join shoulders so the transition into Bar/Screen Edge has the Caelestia-style flared silhouette without a connector stem. Free corners retain radius. Shared popup shadow is generated from the same asymmetric rounded body silhouette and clipped at joined edges. OSK, Sidebars and Overview keep their direct-edge rules. System Tray menus, ii Bar/Vertical Bar context menus and both horizontal/vertical Media popouts consume the connected popup path. Waffle keeps its separate `BarPopup` entrypoint but that entrypoint now consumes the same shared connected-surface primitives. Generic non-Bar `ContextMenu` remains detached by design. Workspace hover now reuses the existing connected Bar taskbar preview path.
3. **No authoritative local pass has been run for this source state.** Calendar/Weather sizing/scaling, Thinkfan bridge reconciliation, CAVA lifecycle, 10-band DSP/EasyEffects behavior, Screen Edge behavior and compositor interactions still require the maintainer's local validator plus live Niri/Hyprland smoke checks.

Recommended next source-side sequence:

1. refetch `dev` and `stable`, inspect every concurrent commit, and re-read README/targets on the latest HEAD before editing;
2. first reload the shell and confirm Bar + VerticalBar instantiate without `Type ... unavailable`, `ClockWidgetTooltip`, `QQuickItem*`/direct-`Connections`, or `PerimeterCutoverPolicy` errors; boot integrity takes precedence over visual validation;
3. once the shell type graph is healthy, preserve and live-validate the direct-body/no-stem placement contract; the newer source-side Caelestia follow-ups (concave shoulders, connected System Tray/Bar-taskbar menus, workspace-specific hover previews) should not receive speculative geometry churn before that result;
4. keep Weather composition frozen unless live validation finds a defect; do not reintroduce the center live clock;
5. hand the exact candidate SHA to the maintainer for `bash scripts/validate-maintainer-local.sh` plus live smoke tests. Do not mark release gates complete before that result exists.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Hãy đọc `README.md` trên branch `dev` trước vì đó là development contract + handoff hiện tại. Làm trực tiếp trên `dev`, không tạo PR trừ khi tôi yêu cầu. Trước mỗi nhóm thay đổi quan trọng và ngay trước mỗi write có khả năng conflict, phải refetch cả `dev` và `stable`, kiểm tra commit mới, rồi đọc lại target file/caller trên đúng HEAD mới nhất. Repo có thể có commit concurrent nên tuyệt đối không sửa dựa trên snapshot cũ, không force push và không rewrite shared history.

Không chạy/check GitHub Actions/CI vì usage limit đã hết. Tôi sẽ chạy `bash scripts/validate-maintainer-local.sh` và live-test Niri/Quickshell một lượt cuối trên máy local. Không được nói test/release đã pass nếu chưa có local result từ tôi.

Mục tiêu UI/UX: giữ kiến trúc/functionality iNiR hiện có nhưng làm connected surfaces theo hướng Caelestia. Không build popup framework mới. Existing bar popups vẫn đi qua `modules/bar/StyledPopup.qml` + `modules/common/perimeter/ConnectedSurface*` + `PerimeterTokens.qml`. Không reintroduce guessed `PanelWindow.active/onActiveChanged`, Pill/Mascot runtime, retired Bar/Dock renderers, Orbit/workspace experiments hay non-Material Global Themes. Waffle vẫn là panel family được support.

Trạng thái source hiện tại đã có:
- persistent Screen Edge + width setting; Screen Edge có wallpaper-facing rounded inner corners;
- direct attachment dùng shared seam/join/shadow contract; không có connector stem trong normal popup UX;
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
1. Connected popup geometry phải liền trực tiếp với Bar/Screen Edge kiểu Caelestia: không connector stem; edge tiếp xúc không radius và không shadow; chỉ các cạnh ngoài mới giữ radius/shadow.
2. Nếu Bar chiếm một edge thì không render Screen Edge trên cùng edge đó; Screen Edge dùng cùng surface color contract với Bar.
3. Media Popup phải thực sự hiển thị Equalizer/CAVA.
4. Bỏ hover popup riêng của Time & Date; merge hover vào Weather/Calendar và làm frontend left/center sát Serpantinum hơn, vẫn giữ detailed Hadalis weather ở right.
5. Left/Right Sidebar connector hiện có source nhưng runtime report không thấy nối vào vertical Screen Edge; tìm root cause geometry/visibility.
6. Overview/dashboard mở bằng Super/Meta+Space phải nối vào bottom Screen Edge.
7. Thinkfan uninstall ownership symmetry: repo-managed uninstall chỉ dọn Hadalis helper/policy khi đúng context; không remove/disable upstream Thinkfan package/service/config và không phá package-manager ownership.
8. Packaging/runtime dependency audit đã có source contract và common-perimeter dead runtime cluster đã được dọn; tiếp tục stale regression/docs audit ngoài cluster này mà không biến Thinkfan thành hard dependency hoặc tự tạo fan config.

Sau mỗi nhóm thay đổi: refetch trước write, giữ patch nhỏ/atomic, commit trực tiếp lên `dev`, cập nhật checklist source-side trong README, xác nhận HEAD sau commit và báo root cause/goal, file đã đổi, SHA, source-level contract thay đổi và phần local/runtime validation còn lại.
```
