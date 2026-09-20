# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-19

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

### 1.1 Fresh-chat handoff — read before editing perimeter/UI geometry

This section is the **maintainer handoff for new chat sessions**. Read it before touching Screen Edge, Bar, popup, Sidebar, Dashboard, Settings overlay or any shared perimeter primitive. If another section appears to conflict with this handoff, the maintainer's newest explicit instruction wins.

**Frozen / do-not-touch unless the maintainer explicitly asks:**

- **Physical Screen Edge geometry is locked.** Do not redesign, refactor or "clean up" `modules/screenCorners/ScreenEdges.qml` while working on Popup/Sidebar/Dashboard. The accepted model is one full-screen `FrameWindow`, one odd-even `ShapePath`, four circular `PathArc` corners and transparent reservation windows only.
- **Normal ii Bar/VerticalBar perimeter geometry is locked together with Screen Edge.** Do not add Bar-local `RoundCorner`, `PathArc`, rectangle, wedge, contact patch, shadow band or fallback geometry. Bar position top/bottom/left/right is represented only by changing the matching inner-frame inset to Bar/VerticalBar thickness inside the existing Screen Edge frame.
- The only approved curvature control for that physical perimeter is `appearance.screenEdge.radius` through `PerimeterTokens.frameRadius` (default **25px**, supported range **0–96px**).
- Physical Screen Edge shadow ownership is separate and already established: `appearance.screenEdge.physicalShadow` controls only the physical frame. Never reuse `appearance.screenEdge.shadow` for the physical frame; that older key remains for connected-surface body shadows.
- Auto-hide behavior is also frozen for current geometry work: when ii Bar auto-hide is enabled, Bar relinquishes physical-edge ownership back to `ScreenEdges.qml`. Do not reintroduce `autoHideScreenEdge` or another Bar-local physical edge.
- Waffle is a separate supported panel family. Do not change Waffle geometry as a side effect of ii perimeter work.

**Current active perimeter task — connected surfaces only:**

- The maintainer's current focus is **Popup / Sidebar / Dashboard / Settings / OSK contact geometry** where a connected body physically meets Screen Edge or normal ii Bar.
- Desired visual result: the attached body edge stays **square at the seam**, while each endpoint grows an **outward flattened/concave shoulder** into Screen Edge/Bar, matching the supplied Caelestia references. The curve must bulge/flatten **outside** the popup body; never round the attached body corner inward.
- Legacy Sidebar/Dashboard/OSK/Waffle outward shoulders still follow `appearance.screenEdge.radius` through `PerimeterTokens.joinFlareRadius = frameRadius`. ii `StyledPopup` no longer uses that Canvas/flare geometry: its contact is the G1/G2-validated iRiS SDF union, with popup free-corner radius kept by the popup token.
- This must be implemented in the **connected-surface layer only**. Do not solve it by changing `ScreenEdges.qml`, Bar/VerticalBar geometry, the locked physical frame, or by painting a second physical-edge overlay.
- ii Bar popups stay on the single `StyledPopup` framework and its production `ConnectedSurfaceIrisFrame` + `ConnectedSurfaceBodyMask` path. `ConnectedSurfaceFrame` + `ConnectedSurfaceJoinFlares` remain shared only by Waffle/non-cutover Sidebar/Dashboard/OSK surfaces. Do not create per-popup patches or a second popup framework.
- The rejected implementation rounded the attached popup body corner inward. That is explicitly wrong. The clean baseline keeps attached body corners at radius 0 and lets the fill-only flare outside the body own the contact curvature.
- Caelestia's real implementation uses `BlobRect` surfaces in the same smoothed `BlobGroup` as `BlobInvertedRect`; Hadalis approximates that smooth union across separate layer-shell surfaces with an outward Bezier/ellipse shoulder. Do not replace it with standalone inward `PathArc` patches.
- Any connected-surface implementation is **not considered complete until runtime screenshots validate Popup, Sidebar, Dashboard and Settings contact corners** at the relevant Bar/Screen Edge positions.

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
4. For ii Popup work, first inspect `ConnectedSurfaceIrisFrame.qml`, `ConnectedSurfaceIrisField.qml`, `ConnectedSurfaceBodyMask.qml`, `ConnectedSurfaceGeometry.qml` and the calling surface. For Sidebar/Dashboard/OSK/Waffle, inspect the legacy shared frame/flares they still consume. Avoid editing locked physical perimeter files.
5. Update `scripts/test-shell-surface-contracts.py` whenever ownership or geometry contracts change intentionally.
6. Do not claim runtime success until the maintainer has run `inir update` / `inir restart` and visually validated the result.

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
- **ii connected popup contacts are SDF unions, not corner patches.** `StyledPopup` keeps Bar/Screen Edge owner rectangles in exact iRiS v2.31.0 SDF math and clips Overlay paint/shadow/input at the real owner boundaries. The accepted split-composition uses `irisFuseDepth = 30` and `irisWeldDepth = 3`; no `ConnectedSurfaceJoinFlares`, connector stem or connector-strip input mask remains in the ii popup path. Legacy Sidebar/Dashboard/OSK/Waffle surfaces still use their shared outward-shoulder primitive until separately cut over.
- Caelestia's border defaults are preserved: Screen Edge thickness defaults to **10px**, corner radius defaults to **25px**, and the outer path extends **50px** beyond the window so the compositor clips the physical screen boundary rather than exposing antialiasing on an outer shape edge. Radius is user-adjustable through Settings without changing renderer ownership.
- The full-screen visual `FrameWindow` follows Caelestia's layer-shell placement contract: it is anchored to all four physical output edges and uses `ExclusionMode.Ignore` without setting an `exclusiveZone`, so edge reservations cannot inset the painted frame. The four thin `ReservationWindow` surfaces are transparent compositor reservations only; they set the positive edge `exclusiveZone` and otherwise remain in normal exclusion semantics. They never paint Screen Edge pixels and therefore cannot change the frame silhouette.
- Physical Screen Edge shadow is allowed only as **one effect attached directly to the locked frame Shape**. It must not introduce an Item wrapper, edge/corner renderer, gradient band, radial patch, wedge, rectangle or second painted geometry. Defaults match Caelestia ContentWindow: Material `m3shadow`, `blurMax = 15`, alpha `0.70`.
- Physical and connected-surface shadow ownership are intentionally separate. `appearance.screenEdge.physicalShadow` controls only the physical perimeter. The older `appearance.screenEdge.shadow` contract remains internal to connected popup/Sidebar/Dashboard/Settings/OSK body shadows and must never be read by `ScreenEdges.qml`.
- When the ii Bar uses auto-hide, it relinquishes physical-edge ownership to `ScreenEdges.qml`; there is no `autoHideScreenEdge` substitute inside Bar/VerticalBar.
- `scripts/test-shell-surface-contracts.py` is the regression gate. It locks the single-frame Shape/ShapePath, four PathArc corners, all four Bar-aware inset formulas, the shared radius owner, and the absence of any Bar-local corner primitive. Do not restore `CornerWindow`, painted `EdgeWindow`, Bar-local `RoundCorner`/`PathArc` geometry, separate physical shadow geometry or shared shadow ownership.

## 3. v1.0 release blockers

Checkboxes below are **release gates**, not an assertion that no partial implementation exists. Check an item only after source review and the relevant local/runtime validation.

> **Current source pass (2026-09-19; local runtime validation still pending):** Classic Bar geometry is authoritatively Hug from schema/defaults through runtime sizing/reservation, and the physical Screen Edge remains one locked inverted frame per output. Normal horizontal and vertical Bar runtimes paint only their body; external wedges, contact rectangles, Bar-local shadow rectangles and the entire `autoHideScreenEdge` fallback remain removed. `ScreenEdges.qml` still owns exactly one antialiased odd-even `ShapePath`: padded outer screen rectangle minus one rounded inner workspace rectangle using the shared `appearance.screenEdge.radius` value (25px by default). The Caelestia-style shadow is attached directly to that Shape with one `MultiEffect`, using the dedicated `appearance.screenEdge.physicalShadow` owner (defaults enabled, 15px, 70%). Connected popup/Sidebar/Dashboard/Settings/OSK shadows continue to use the separate legacy `appearance.screenEdge.shadow` contract, so the public Screen Edge controls cannot alter them. The only remaining per-edge layer surfaces are transparent exclusive-zone reservations. With ii Bar auto-hide enabled, this exact single geometry owns the visible perimeter. The failed inward-rounded contact-corner experiment remains reverted. The ii `StyledPopup` path now renders the accepted exact iRiS SDF union with split-composition owner clipping; `PerimeterTokens.irisFuseDepth` and `irisWeldDepth` preserve the validated field relation without repainting Bar/Screen Edge owners. Legacy Sidebar/Dashboard/OSK/Waffle surfaces continue to use the shared Canvas/Bezier outward-shoulder approximation and its `joinFlareRadius` / `joinFlareCrossScale` tokens. Normal ii Bar geometry remains unchanged: the single physical inverted frame uses Bar/VerticalBar thickness on the owned edge, so Bar endpoint corners stay inside the locked Screen Edge renderer. Shared ii surface presentation is locked to the immutable `SurfaceMotion` contract: Popup, Sidebar, Dashboard and Settings use a fixed 300 ms `InOutCubic` slide with no scale/fade/bounce/overshoot and no runtime theme/profile/curve override. Popup still uses Caelestia's normalized `offsetScale` lifecycle and reverses from its current value; Sidebar may still opt into instant opening, which disables rather than replaces the slide. OSK and Bar auto-hide retain their independent existing motion contracts. For MPD/rmpc, Media remains MPRIS-based: Arch bundles now include `mpd-mpris`, required migration `042-mpd-mpris-bridge` adds it to existing repo-managed Arch installs, and `MprisController` probes local MPD plus the bridge, starts `mpd-mpris.service` when needed, and still reacts to MPD PipeWire streams. Device session state is now also source-persistent: the last confirmed Wi-Fi radio, Bluetooth adapter and microphone mute states are written to `Persistent.states.deviceState` and restored at shell startup; explicit "known" flags make the first run after upgrade snapshot reality instead of forcing defaults. Left Sidebar music is now local-only and MPD/MPRIS-backed: the old YT Music tab/settings route is replaced by `LocalMusic`; MPD owns songs, saved playlists and the active queue, while `mpd-mpris` exposes that same session to the shell's normal MPRIS surfaces; direct MPD commands are limited to database/queue operations MPRIS does not expose, and existing `ytmusic` enabled/tab-order state migrates to the new `music` key. Song rows now use desktop-player double-click semantics: a double click appends with MPD `addid` and starts that exact appended entry with `playid`, preserving the existing queue instead of replacing it on the first click. Queue editing is now MPD-owned too: each compact song row can remove its exact queued item through `deleteid`, and Queue exposes an MPD `clear` action. Library rows now render QML-safe cover URLs: folder artwork is used directly, while missing covers are filled from MPD `albumart`/`readpicture` into a per-user cache without creating a second player backend. These are source contracts only until the maintainer completes the Niri/Quickshell live pass.

### A. Screen Edge and connected surfaces — P0

> **Latest maintainer correction (2026-09-19):** connected Popup/Sidebar/Dashboard/Settings/OSK contacts must flare **outward** into Screen Edge/Bar. The attached body corners stay square; inward rounding is explicitly rejected. The outward shoulder follows the same user-controlled Border Radius as Screen Edge/Bar, while the locked Screen Edge/Bar renderer itself remains untouched. Horizontal/vertical Bar PanelWindows must also remain mapped across fullscreen so leaving fullscreen never strands Bar contents blank.

- [ ] **Screen Edge exists both while idle and while a window is maximized.** It must not disappear simply because no maximized window is present.
- [ ] **Bar survives fullscreen enter/exit without reload.** Horizontal and vertical ii Bar native surfaces and the painted Screen Edge `FrameWindow` stay mapped/updating; fullscreen coverage is owned by compositor stacking, not `visible`/`updatesEnabled` gates. Transparent reservation-only windows may release their exclusive zones independently. Leaving fullscreen must restore all Bar contents immediately without `inir restart` or shell reload.
- [ ] **Screen Edge width is configurable in Settings.** The setting must use one canonical configuration field, have a safe default/range and update the active edge without requiring an alternate renderer.
- [ ] **Screen Edge corner radius is configurable in Settings and defines the physical ii Bar/Screen Edge plus legacy connected shoulders.** Default is 25px. Sidebar/Dashboard/OSK/Waffle flare tangent width still follows `PerimeterTokens.joinFlareRadius = frameRadius`; ii `StyledPopup` contact morphology is now owned by the independent iRiS field tokens and popup radius.
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

- Left Sidebar Music: the user-facing YT Music tab and YT-specific Settings controls are replaced source-side by a local-only MPD frontend. MPD owns songs, saved playlists and the live queue; normal transport uses endpoint-matched mpd-mpris/MPRIS while queue replacement/database update use MPD protocol. Songs and Queue now use denser 50 px desktop-player rows; Queue exposes per-row removal by stable MPD song id plus a Clear action backed by MPD `clear`. Song covers now resolve folder art to QML-safe file URLs and fall back to MPD `albumart`/`readpicture` cached per album/folder when no cover file is present. The Songs search control remains constrained to one compact row and Songs / Playlists / Queue expose explicit scrollbars, so the library viewport cannot be swallowed by ToolbarTextField's toolbar-oriented fill-height default. The now-playing footer reuses the exact Media-popup `PlayerControl` + CAVA path against `MprisController.mpdPlayer` instead of maintaining a second player UI. A fourth Lyrics tab reads only same-name local `.lrc`/`.txt` sidecars and synchronizes timed LRC lines to the MPD/MPRIS playback position. The default localhost:6600 endpoint retains the distro `mpd-mpris.service`; custom endpoints use the Hadalis-named bridge. Live MPD database, playlists/queue editing, shared PlayerControl sizing, scrolling, local-lyrics synchronization and MPRIS bridge behavior still require maintainer validation.
- Latest visual follow-up: the physical Screen Edge has been restored from the failed shared-shadow experiment to the locked single-frame baseline, then given a clean dedicated shadow owner. `ScreenEdges.qml` is still the only physical-edge renderer, including while ii Bar auto-hide is enabled; the shadow is one `MultiEffect` attached directly to the locked Shape and reads only `appearance.screenEdge.physicalShadow`. Connected Popup/Sidebar/Dashboard/Settings/OSK shadows remain on their separate `appearance.screenEdge.shadow` contract. Live validation of the physical perimeter shadow remains required.
- Connected-corner follow-up: the standalone exact-`PathArc` flare experiment remains reverted. Source review of Caelestia `ContentWindow.qml` shows the panel `BlobRect` itself stays rounded and is then smooth-unioned with `BlobInvertedRect`. Hadalis now mirrors that composition more faithfully: existing smooth-union shoulders stay intact, while the actual attached body corners inherit `appearance.screenEdge.radius`. The physical Screen Edge/Bar geometry lock is unchanged. Live Popup/Sidebar/Dashboard/Settings/OSK validation remains.
- Caelestia-style slide motion: shared popups now use normalized `offsetScale` (1 closed → 0 open) with one expressive-default-spatial curve for enter, exit and reversal, matching Caelestia's wrapper/clip model instead of asymmetric accel/decel timing. Attachment-axis translation preserves the expressive curve's overshoot while reveal/input progress remains clamped. Settings overlays, Dashboard, OSK, Sidebar slide and Bar auto-hide now use the same spatial token. Live frame-pacing/reversal validation remains.
- MPD/rmpc Media discovery: `rmpc` remains an MPD client rather than an MPRIS provider, so Hadalis now packages `mpd-mpris` for the Arch audio/full-experience paths, required migration `042-mpd-mpris-bridge` reconciles existing repo-managed Arch installs, and Media probes local MPD at startup. When MPD is running without an MPD MPRIS object, `MprisController` starts the user `mpd-mpris.service`; PipeWire stream detection remains a second trigger and direct-ALSA MPD is covered by the process probe. Live default/custom MPD endpoint validation remains.
- Screen Edge corner reconstruction: the rejected `4 EdgeWindow + 4 CornerWindow` composition remains retired. The visible Screen Edge is one full-screen odd-even frame geometry: padded outer rectangle minus one rounded inner workspace rectangle. The geometry primitive remains locked and its radius is configurable (25px default, 0–96px). A normal ii Bar changes only the inset of its owned side to Bar thickness. Connected-surface **body contact corners** may read this radius but cannot write or repaint the physical perimeter; their 20px smooth-union shoulders remain a separate connected-surface approximation. The physical shadow remains an effect on the same Shape. Live validation at native and fractional scale is required.
- Bar/Screen Edge intersection cleanup: repeated top/bottom/left/right tests showed that overlapping Bar and Screen Edge geometry made the result depend on orientation/layer ordering. Bar-owned corner/contact/shadow geometry and the auto-hide Screen Edge fallback are now removed from both Bar runtimes. In ii auto-hide mode the Bar explicitly gives the physical edge back to `ScreenEdges.qml`, leaving one renderer for the full perimeter. Live validation is pending.
- Popup Bar/Screen Edge hover hand-off: the supplied recordings showed transient popup loss while crossing the seam; shared ii popups now track the complete body and wait 90 ms before hover-only retract, while Waffle's existing delayed-close path also includes full-body hover. Live high-frequency pointer crossing remains.
- Sidebar endpoint shoulders: shared flares map the nested body through `mapToItem()`, SidebarHost no longer applies the Loader translation a second time, and the native host now reserves the larger of flare radius or its connected-surface shadow extent so the curved endpoint shadow cannot be clipped. Live left/right flare placement and shadow continuity during slide/drop remain.
- Compact Right Sidebar Media: the shared `EqualizerPanel` now sits immediately below `CompactMediaPlayer` and follows Sidebar presentation lifecycle. Live sizing/DSP validation remains.
- Settings surfaces: both overlay hosts remain substantially larger and directly bottom-attached with square joined corners. Their old full-overlay endpoint flares are intentionally removed because those shapes were positioned beside the centered card inside the scrim and appeared as floating round wedges. Live 16:9/16:10/scaled-output sizing remains.
- Privileged power/fan actions: the exact root-owned ThinkFan and TLP helper actions now allow only the active local session without a password prompt; inactive/non-local subjects are denied, and the state-based repo migrations refresh changed policy assets. Live installed-policy validation remains.
- Sidebar General settings: the Island selector and Use Card style switch are removed; legacy values normalize to Panel/non-card at startup and the retired Sidebar-style search entry is gone. Live Settings navigation/search validation remains.
- Media transport controls: source fix removes hover text tooltips for Previous / Pause-Play / Next; live hover validation remains.
- Media DSP: backend compatibility fix remains; the EQ curve now carries a persistent compact electric current. Preset and direct band edits brighten the same fixed-width trace, then return to the lower resting luminance. Live visual/audio validation remains.
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

- the latest five-item visual follow-up is represented source-side: rounded/radial perimeter shadows, shadowed Caelestia-style connected shoulders using live Screen Edge settings, untinted Dashboard + Dashboard Equalizer, 2×5 left-aligned TLP category navigation with Battery care merged above, and Screen Edge fallback during Bar auto-hide; all remain runtime-pending;
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
- [x] **Direct Bar/Screen Edge popup composition:** ii `StyledPopup` keeps source-aware tangent placement and no connector stem, but now uses the exact iRiS field for contact morphology. The SDF body welds 3 logical px under joined owners while Overlay paint/shadow/input are clipped at their real boundaries; corner clamps therefore share one field calculation without repainting physical Screen Edge pixels. Live production top/bottom/left/right validation remains pending.
- [x] **Shared popup slide-under reveal:** `ConnectedSurfaceGeometry` preserves full body size and translates only on the attachment axis; `ConnectedSurfaceRevealClip` fixes the viewport at the real owner seam. ii `StyledPopup` now pairs that lifecycle with `ConnectedSurfaceBodyMask` and owner-clipped iRiS field/shadow rendering, while Waffle `BarPopup` intentionally retains `ConnectedSurfaceMask` + the legacy shared frame/flares. Live production top/bottom/left/right/reverse-retract validation is pending.
- [x] **System Tray connected context menu:** tray right-click menus no longer own a detached `PopupWindow`/private rounded card. `SysTrayItem` passes its real visual item into `SysTrayMenu`, which presents the existing nested menu stack through shared `StyledPopup`; physical Bar-edge normalization, placement-driven Screen Edge joins, concave shoulders, shaped input mask and outside-click ownership therefore match ordinary Bar popups. Existing submenu navigation, Escape, hover-delay close and tray focus-window identity are retained. Live pointer/keyboard/multi-output validation is pending.
- [x] **Bar taskbar connected context menu:** the taskbar's right-click menu uses a narrow `BarContextMenu` wrapper around `StyledPopup` instead of the generic detached `ContextMenu`. The menu therefore grows from the actual taskbar button and shares Bar/Screen Edge join geometry, shoulders, input mask and outside-click behavior. Generic `ContextMenu` remains intentionally available for non-Bar anchors such as text fields, Dock/sidebar content and arbitrary in-window controls. Live taskbar right-click/hover-transfer/keyboard validation is pending.
- [x] **Bar-background connected context menu:** right-clicking the broad left/right Bar zones no longer creates a synthetic 1×1 popup anchor or detached generic `ContextMenu`. `StyledPopup` now accepts an optional source-local `anchorRect` while retaining the real visual control as the ownership/output anchor, so the connected menu can emerge near the actual click point without losing physical Bar-edge normalization. Live corner/middle click-point, top/bottom Bar and multi-output validation is pending.
- [x] **Vertical Bar popup parity:** the Vertical Bar background context menu now uses `BarContextMenu` with the real clicked Bar control + source-local click rect, and Vertical Media's expanded player no longer owns a private `PopupWindow`/backdrop. Both expanded media and its wheel/hover volume HUD now use `Bar.StyledPopup` semantic visibility, shared outside-click/output ownership and the same Media focus restoration as the horizontal Bar. Live left/right Vertical Bar, Media keyboard focus and volume-HUD validation is pending.
- [x] **Waffle shared BarPopup connected presentation:** Waffle keeps its own `BarPopup` API/palette and remains a separate supported panel family, but the popup implementation no longer uses compositor `PopupWindow` + visual-margin gap geometry. It now reuses `ConnectedSurfaceGeometry/Frame/ContentHost/Mask`, direct Bar-edge overlap, Caelestia-style concave shoulders, shaped input and same-output Niri backdrop; Waffle callers retain `close()`, `grabFocus()`, `updateAnchor()`, hover-delay and focus-cleared contracts. `visualMargin` now controls free-side shadow extent instead of creating separation. The Waffle Bar-background menu also uses source-local `anchorRect` on the real Bar MouseArea instead of a synthetic 1×1 anchor, preserving click-point placement and output ownership. Live Start/Tray/Updates/context-menu validation is pending.
- [x] **Waffle task preview connected presentation:** the final Waffle Bar-specific detached `PopupWindow` in `tasks/TaskPreview.qml` is retired. Task preview now consumes `BarPopup` while preserving `WindowPreviewService` capture, 250 ms pointer bridge, delayed preview-resource release, app/toplevel tiles and panel-open dismissal. `Tasks.qml` no longer configures the removed compositor `anchor.window` API. Live hover-transfer, close/reopen, Niri capture and multi-output validation is pending.
- [x] **Workspace hover window previews:** workspace buttons now open a dedicated `BarWorkspaceOverview` built on the shared `StyledPopup` Bar-attachment shell; it embeds the existing Niri/Hyprland Overview renderers and keeps `BarTaskbarPreview` only as a compatibility fallback when Overview hover is disabled. Niri workspace previews re-enrich authoritative Niri windows against current foreign-toplevel handles and filter by stable workspace id; Hyprland maps workspace-owned compositor toplevels back to their Wayland handles. Empty workspaces can still open the Overview, hover open/close delays live under the dedicated Overview config, and the popup stays physically joined to the Bar through the shared connected-surface geometry. Drag/drop now explicitly restores the thumbnail x/y bindings that `MouseArea.drag.target` breaks, and stages the target workspace while compositor metadata catches up, preventing moved windows from remaining vertically offset outside the destination preview. Close animation keeps the embedded Overview alive for the complete StyledPopup retract tail, so disappearance is the same opaque reverse slide under the Bar rather than an early content fade/clear. Focused-workspace motion is gated until the connected reveal completes, preventing its x/y/corner tween from composing into a diagonal entrance; focus changes after reveal still animate normally. Live Niri/Hyprland, multi-output and workspace-move validation is pending.
- [x] **Bar-owned popup coverage guard:** local validation now scans the supported ii horizontal/vertical Bar and Waffle Bar source trees for direct `PopupWindow` regressions, rejects generic `ContextMenu` declarations inside ii Bar callers, and asserts the known Battery/Resources/Weather/Timer/Media/Tray/task-preview surfaces stay on `StyledPopup`/connected `BarPopup`. Hover-only tooltip primitives remain outside this interactive popup/menu contract. Runtime geometry still requires live validation.
- [x] **P0 Settings reachability/search contract:** public Settings resolves Quick/Bar through the Hug-only facades, the Bar page owns the persistent Screen Edge width/shadow controls, and System owns Fan Control through `ThinkFanService`. Static search now indexes Screen Edge width/shadow before lazy page materialization and no longer advertises the retired Float/Rectangle `Corner style` selector. The Quick Hug facade also no longer hides the entire page behind its zero-delay compatibility pass, matching the blank-page fix already used by the Bar facade. A dedicated local regression guard locks these routes and prevents dead controls/readiness gates from returning. Live Settings navigation/spotlight validation is pending.
- [x] **Bar/Screen Edge overlap and color:** Screen Edge ownership now covers both ii (`iiBar`/`iiVerticalBar`) and the supported Waffle `wBar` family on the exact configured output/edge, including each family's stale-`screenList` fallback and `widgetEditMode` unmap lifecycle. The Waffle-owned edge uses `Looks.colors.bg0`; ii keeps the Material `colLayer0` contract. Same-edge Screen Edge/corner overlays are therefore suppressed for either active bar family. Live placement/color validation is pending.
- [x] **Screen Edge width/radius + shadow ownership + window-gap boundary:** `appearance.screenEdge` is a typed Config/JsonAdapter object with persistent width, Screen Edge/Bar radius, connected-surface shadow settings and a separate physical-frame shadow owner. Persistent Screen Edge reservations still reserve exactly the solid thickness, so Niri Window Gap starts at the inner Screen Edge/Bar boundary. The radius defaults to 25px and drives the physical frame plus normal ii Bar/VerticalBar endpoint corners; connected Popup/Dashboard/Sidebar shoulders remain deliberately decoupled. Live width/radius/shadow/gap validation is pending.
- [x] **On-screen keyboard direct Screen Edge attachment:** the draggable OSK no longer stops at the inner Screen Edge boundary. Top snap uses `y = 0`, bottom snap uses `screenHeight - keyboardHeight`, so the visible body underlaps the complete persistent Screen Edge band; the shared `ConnectedSurfaceJoinFlares` adds the same configurable inverse quarter-circle used by the Screen Edge at both attachment endpoints. The connector stem remains retired. Live drag/pin/top/bottom/custom-edge-width/radius validation is pending.
- [x] **Compact status OSD direct Bar/Screen Edge attachment:** Volume, Brightness, Mic and keyboard/touchpad status no longer paint a detached pill below the Bar. The ii OSD host now uses the shared `ConnectedSurfaceGeometry/Frame/ContentHost/Mask` path with zero connector length, square joined edge, outward flares and shadow suppressed on the contact side. On each output it attaches to the real horizontal/vertical ii Bar thickness when that Bar owns the configured edge; otherwise it falls back to the persistent Screen Edge thickness. The old value/keyboard cards switch to content-only mode under this host so their inner radius/shadow cannot recreate a visual gap. Media and Voice Search retain their specialized card presentation. Live top/bottom/left/right, Bar-disabled, auto-hide and touchpad/hardware-key validation is pending.
- [x] **Media Popup CAVA visualizer:** the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path remains the single visualizer path. `WaveVisualizer` renders a Serpantinum-inspired rounded bar field directly in QML; the Bar Media Popup requests 64 samples, the shared CAVA service restarts/re-resolves a stalled source, and raw output pins the expected ASCII range/delimiter. Live play/pause/player-switch/reopen validation is pending.
- [x] **Media Popup 10-band DSP:** Multiple MPRIS sources now occupy one compact player viewport as vertical sliding tabs, with Weather-style circular tab indicators aligned on the right; wheel navigation now uses the same clamped edge semantics as Weather so repeated high-resolution touchpad packets cannot wrap a source back to the previous tab, and choosing a dot also updates the central active MPRIS player. A separate DSP section sits below the media card in the same popup. It keeps the deferred `EqualizerService` boundary and Serpantinum's eight ±12 dB curves, renders ten gains into the 32-band EasyEffects preset map and loads private `hadalis_live_eq` through EasyEffects' local server. The helper now uses Python's AF_UNIX socket directly—the same transport model exercised by EasyEffects upstream tests—so missing `socat` no longer disables DSP. Native/Flatpak preset locations remain separate. The UI never talks to backend/socket/preset-file protocol directly. The persistent compact electric trace is mapped from each Slider handle's actual rendered center via `mapToItem`, eliminating the previous gain-to-canvas y drift. Direct band edits still use a whole-curve luminance response, while preset activation now launches a dedicated ~860 ms charge sweep from 31 Hz to 16 kHz with a short luminous tail; the sweep redraws the exact same sampled path at the exact same 5.5/2.4/1 px widths, so the effect gets brighter as it travels left→right without making the current physically larger. Boot/reload transport probing now distinguishes an unchecked transport from a verified failure and retries probe completions invalidated by an EasyEffects lifecycle-generation change, so first presentation no longer depends on closing/re-hovering the Media surface. Live EasyEffects audio-routing/effect validation remains pending.
- [x] **Clock Calendar + Sidebar Calendar style unification — source fixed:** Clock popup and Sidebar/Dashboard month calendars consume one shared `ObsidianMonthCalendar` presentation. The `MMM YYYY` title now aligns to the visible MON label itself (not merely the first cell boundary). Clock keeps compact 30px cells; Sidebar/Dashboard opt into responsive cells up to 42px with wider spacing so the grid uses the available panel width without creating a second style. Textual `TODAY`, chevrons, Monday-first uppercase weekdays, dim adjacent-month dates and accent-today styling stay shared. Sidebar retains event dots, day-detail interaction and its separate Upcoming/event area. Weather remains a stable two-tab popup with the right-edge dot rail and clipped vertical slide transition. Live responsive sizing/event-dot/day-detail and Weather wheel/slide validation remain pending.
- [x] **Bar/VerticalBar startup type graph — source fixed:** maintainer logs showed three independent QML graph failures that prevented the Bar from materializing: `VerticalClockWidget.qml` referenced the retired/nonexistent `Bar.ClockWidgetTooltip`; `BarTaskbarPreview.qml` placed `Connections` objects directly under `StyledPopup`, whose default content property accepts only an `Item`; and both Sidebar wrappers still referenced the retired `PerimeterCutoverPolicy`. The tooltip dependency is removed, taskbar preview listeners now live inside its single visual content item, and SidebarLeft/SidebarRight instantiate `SidebarHost` directly for `targetScreens`. `test-styled-popup-content-contract.py` now guards these boot-critical QML contracts. Live shell reload is required before treating Bar/VerticalBar startup as validated.
- [x] **Left/right Sidebar direct Screen Edge attachment:** the owning SidebarHost remains a physical left/right layer surface with no connector stem and underlaps the full Screen Edge band. Its endpoint shoulders are restored to the prior shared `ConnectedSurfaceJoinFlares` baseline; the exact Screen Edge-corner experiment is deferred. Live left/right/custom-edge-width/animation validation is pending.
- [x] **Overview Dashboard as connected popup:** Overview keeps connector/stem geometry retired and positions Dashboard at the exact bottom Bar/Screen Edge boundary. Dashboard remains on the prior shared `ConnectedSurfaceJoinFlares` baseline after the exact Screen Edge-corner experiment was reverted. Its depth stack is explicit (`shadow z=0`, body `z=1`, endpoint flares `z=5`) so the `RectangularShadow` interior cannot composite over the Dashboard body/content. Search now cancels the exact facing wrapper insets so its painted bar touches the Dashboard body, while non-empty search becomes a bottom-connected Applications surface with square Screen Edge contact corners and shared outward flares. The workspace-hover surface is output-centered while retaining Bar ownership. Workspace Overview is now a separate Settings page and the old full-screen workspace renderer is reserved for explicit Task View; normal workspace Overview presentation is Bar-hover attached. Overview settings are reduced to workspace-hover/layout/content essentials; compact launcher Dashboard ownership lives under Dashboard Settings, and saved v4 navigation layouts migrate Overview into the Shell group. Reverse close stays mapped through the reveal tail. Live Meta/Super+Space/open-close/search-transition, Applications bottom attachment and surface-color parity validation is pending.
- [x] **System Monitor content simplification:** the monitor keeps Used/Total RAM, shortens the temperature header to **Thermal**, and reports CPU/GPU load as percentages only (no Low/Medium/High status text). ThinkFan remains one compact line, with `Fan + toggle` aligned to the RAM column, `Speed` to Thermal, and `Level` to CPU. Error feedback remains conditional below the row. Live alignment validation is pending.
- [x] **Fan Control settings + durable power-profile levels:** **Fan Control** lives in the real **Settings → System** page (with System search routing/indexing) and remains removed from Bar Settings. Power Saver/Balanced/Performance level preferences persist independently of runtime helper readiness, use an explicit serialized Config flush, and are owned by `ThinkFanService` rather than duplicated Settings-side logic. The profile-follow service now reads fan preferences through the revision-aware Config path, reacts when the standalone Settings process changes the config, reapplies the saved active-profile level after startup/status readiness, and skips privileged writes when the hardware already reports the requested level. The shell root keeps the service alive so profile following continues after Settings/System Monitor closes; busy helper operations queue the latest requested level, and leaving ThinkFan managed mode reapplies the active profile level. Runtime apply still requires the repo/package-managed `/usr/libexec/inir-thinkfan` bridge to be current and ThinkPad ACPI direct control to be available; no machine-specific ThinkFan sensor/curve configuration is rewritten.
- [x] **Thinkfan uninstall ownership symmetry:** repo-managed normal/quick uninstall now removes only the Hadalis-owned helper/policy, preserves package-manager-owned bridge files, and never removes/disables upstream Thinkfan package/service/config. Local uninstall-path validation is pending.
- [x] **Promptless active-session ThinkFan/TLP authorization:** both shipped polkit actions keep exact `/usr/libexec` helper annotations, deny `allow_any` and `allow_inactive`, and allow only `allow_active` without authentication. Required repo-managed migrations compare and resync changed policy assets, while package-managed installs remain package-owned. This removes routine password prompts without hardcoding credentials or granting a broad arbitrary-command path. Live installed-policy/pkexec validation is pending.
- [x] **Sidebar surface-option retirement:** Sidebars General no longer exposes Island or Use Card style; `SettingsPageRegistry` normalizes old `sidebar.style` / `sidebar.cardStyle` values to Panel/non-card at startup, and RegistryData no longer publishes the retired Sidebar-style search entry. Live Settings navigation/search validation is pending.
- [x] **Compact Right Sidebar Equalizer:** the compact Controls Media section imports and renders the shared `EqualizerPanel` directly below `CompactMediaPlayer`, with registration tied to panel visibility. Live compact Sidebar height/scroll/DSP validation is pending.
- [x] **Connected popup hover-transfer stabilization:** ii `StyledPopup` tracks hover on the complete iRiS body (not only padded content) and gives the compositor Bar↔popup window hand-off a 90 ms grace period before a hover-only retract. Its compositor Region is now the conservative owner-clipped visible body only, so SDF fillets and transparent full-output regions cannot steal input. Waffle retains its existing delayed-close/shared-mask contract. Live reproduction against both supplied flicker recordings remains pending.
- [x] **Larger connected Settings overlays:** rail and focus Settings hosts use substantially larger responsive width/height caps while preserving direct bottom attachment, square joined bottom corners and Polkit layer demotion. Direct full-overlay join flares are retired for Settings because their endpoint geometry sat outside the centered card but inside the scrim, producing floating round wedges. Live scaled-output sizing validation is pending.

Still open / must be treated as unfinished until audited or locally validated:

1. **Material-only active-tree residue is now outside Settings chrome.** `SettingsOverlay.qml` and the standalone `settings.qml` no longer contain legacy `Appearance.*Everywhere` presentation branches. The internal `Appearance.qml` cleanup has now collapsed blur style gates, top-level hover/active aliases, warning/success tokens, canonical rounding and font dispatch to their Material paths while retaining public aliases for caller compatibility. The public motion preset API and the central `Appearance.colors` palette API are now collapsed to their existing Material/contextual fallbacks while preserving property names. The six legacy `Appearance.*Everywhere` names are now inert `false` compatibility constants; popup reveal and the remaining ZZZ-only behavior no longer route through them. `SysTrayMenu.qml` and the shared `ContextMenu.qml` have also been collapsed to their Material chrome while preserving the existing focus/input/close lifecycle; their shared `GlassBackground`/`StyledRadioButton` primitives now follow the same Material-only fallback without removing caller-facing compatibility properties. The shell-wide `RippleButton.qml` renderer is likewise collapsed to its existing Material fallback while retaining caller-facing knobs such as `cookieMorphing`. `StyledComboBox.qml` is now also collapsed to its existing Material fallback while preserving ComboBox/search integration and shared sizing/interaction behavior. The active `FontSelector.qml` and `IconThemeSelector.qml` popup chrome now uses the same Material-only surface tokens directly, `ConfigSelectionArray.qml` no longer routes spacing through the inert Regalia predicate, and the shell-wide `StyledRectangularShadow.qml` renderer now uses only its existing Material blur-shadow fallback while preserving caller-facing shadow knobs. Active Bar callers have also been collapsed where their Material fallback was directly provable: `WeatherBar.qml`, `BarMediaPopup.qml`, `BatteryIndicator.qml`, `ClockWidget.qml`, `NotificationUnreadCount.qml`, `ActiveWindow.qml`, `Resource.qml`, `ClippedProgressBar.qml`, `TimerIndicator.qml`, `ShellUpdateIndicator.qml`, `UtilButtons.qml`, `LeftSidebarButton.qml`, the inline right-sidebar button in `BarContent.qml`, `SysTray.qml`, `BarGroup.qml`, `CircleUtilButton.qml`, `ScrollHint.qml`, `BarTaskbarButton.qml` and `BarTaskbarWindowPreview.qml`. Active Settings/shared primitives now also include Material-only `ConfigSpinBox.qml`, `StyledSpinBox.qml`, `SettingsSwitch.qml`, `SettingsNote.qml`, `SettingsCardSection.qml`, `SettingsGroup.qml`, `StyledTextInput.qml`, `StyledSlider.qml` and the active media `StyledProgressBar.qml`. `Workspaces.qml` has likewise been collapsed to its Material renderer while preserving its independent `forceMaterialStyle` compatibility knob plus workspace switching, occupancy, scroll and app-icon semantics. The active media `PlayerControl.qml` has now been collapsed component-wide to its Material fallback as well, while preserving MPRIS/YtMusic control, artwork resolution/cross-slide, CAVA visualization, seek/progress behavior and public caller properties. The active Control Panel tree is now collapsed to Material Global Theme fallbacks: `ControlPanelContent.qml` plus `DateTimeHeader.qml`, `WallpaperSection.qml`, `WeatherSection.qml`, `SlidersSection.qml`, `SystemSection.qml`, `ProfileHeader.qml`, `QuickActionsSection.qml` and `MediaSection.qml` no longer route through the inert legacy Global Theme predicates. The explicit Ricelin island skin remains independent and supported; section enable flags, lazy loaders, entrance cascade/scroll, date/time, wallpaper, weather, sliders, system status, profile/session actions, Quick Actions, artwork-derived media colors, CAVA, seek/progress and MPRIS behavior are retained. Overview's active source tree is now collapsed component-by-component to Material Global Theme presentation. `SearchBar.qml`, `SearchItem.qml`, `SearchWidget.qml`, `ActionModeView.qml`, `OverviewAllAppsGrid.qml`, Hyprland `OverviewWidget.qml` and primary Niri `OverviewNiriWidget.qml` retain their search/action/package/app/workspace/window/preview behavior without legacy Global Theme routing. `OverviewDashboard.qml`, the final Overview residue cluster, now also uses direct Material card/media/weather/system tokens; its newer bottom-connected popup contract is explicitly preserved and regression-guarded: full-body slide-under translation, reveal clipping, bottom-square attachment, shared flares and configured Screen Edge shadow remain intact. Outside Overview, the caller audit has now also collapsed the shared ii/Waffle On-Screen Keyboard body/control/keycap chrome to Material while preserving Ydotool delivery, physical-key feedback, drag/snap behavior and the existing Screen Edge underlap/flares/shadow contract. ScreenCorners is now also collapsed to its Material fake-rounding path while preserving sidebar/orbit hot-corner and brightness/volume interactions for both ii and Waffle. VerticalBar cleanup is now source-complete for the active chrome audited so far: the shared clock/date leaves use Material text/stroke tokens, and `VerticalBarContent.qml` no longer routes through legacy Global Theme predicates/palettes. Its supported islands/cornerStyle/cardStyle behavior, Material compositor blur, connected BarContextMenu, workspaces/taskbar/sys-tray and brightness/volume/sidebar interactions remain intact. Sidebar cleanup now covers `SidebarLeftContent.qml`, the default `SidebarRightContent.qml`, and compact `CompactSidebarRightContent.qml`: their normal shell/card/navigation/action chrome is Material-only while the explicit Ricelin island skin and physical-edge connected geometry remain intact. Left tab reorder/content routes, default-right section reorder/resize/dialog/profile/classic/android flows, and compact-right rail navigation, control ordering, notifications, dialogs, calendar/weather and quick actions remain preserved. The next Material-only step is a fresh active-tree caller audit outside these Sidebar surfaces rather than deleting compatibility aliases blindly.
2. **Connected-surface outward contact flares remain runtime-pending outside Settings.** The failed inward-rounded/standalone-`PathArc` experiments stay reverted. `ConnectedSurfaceFrame` plus direct Sidebar/Dashboard/OSK bodies keep the attached edge square (radius 0); `ConnectedSurfaceJoinFlares` paints their outward shoulder outside the body. Settings is intentionally excluded until the contact renderer can operate in card-local geometry without producing floating shapes inside its full-screen overlay. Its tangent radius follows `PerimeterTokens.joinFlareRadius = frameRadius`, so the Screen Edge Border Radius setting affects the flare without modifying the locked Screen Edge/Bar renderer. Free body corners retain their existing component radii.
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
