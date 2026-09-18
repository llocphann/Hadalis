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
- [ ] Confirm the required CAVA runtime/package is present in the supported install/package paths, or document/install it where currently missing.
- [ ] Visualizer lifecycle is efficient: start only when needed, stop when unused, and survive pause/resume, player switching and popup close/reopen.
- [ ] MPRIS controls, seek, volume and keyboard behavior do not regress while the visualizer is active.

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
- `modules/sidebar/SidebarHost.qml` now owns the Left/Right vertical Screen Edge bridge inside the same native sidebar surface; the old standalone bridge window has been retired so output/lifecycle/stacking cannot drift;
- the broad legacy `modules/perimeter` runtime/topology/adapters have been retired and removed after caller auditing; the old cutover policy was removed as well, and regression contracts were aligned with the supported connected-surface architecture;
- shared connected-popup primitives remain active and protected under `modules/common/perimeter/ConnectedSurface*`, `PerimeterTokens.qml`, and `modules/bar/StyledPopup.qml`; do not recreate the retired broad runtime to solve popup issues;
- Thinkfan standalone connected-surface/content files have been removed from normal UX; Thinkfan controls/state are integrated into the existing System Monitor/resources popup and Settings. Fresh repo-managed installs provision the Hadalis helper/polkit bridge, and required migration `041-thinkfan-helper-bridge` reconciles missing/outdated Hadalis-owned bridge files during repo-managed updates without modifying upstream Thinkfan package/service/config ownership;
- `modules/common/widgets/KeyboardFocusRing.qml` imports `qs.modules.common` on current `dev`, so the earlier `Appearance is not defined` warning belongs to an older runtime snapshot and must be rechecked only after the local shell updates/reloads to current source;
- `Settings > Bar` has a real supported v1.0 facade/content path instead of the previous blank route;
- public Global Theme Settings are constrained to Material, persisted legacy style values normalize/write back to Material, and the runtime `Appearance.globalStyle` boundary is clamped to Material so a persisted legacy style cannot transiently reactivate an old Global Theme branch during startup;
- the Material-only Settings cleanup now removes the retired Global Style tab/sections/search entries and dangling legacy editor loaders from the base Themes page; the public facade retains only a narrow stale-section redirect plus persisted-value normalization, while runtime visual validation remains part of the local release pass;
- the Calendar/Weather composition has source implementation for the requested Serpantinum-inspired left/center presentation while retaining Hadalis detailed weather ownership/content on the right;
- Media Popup owns the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path and gates visualizer activity by popup presentation/playback lifecycle;
- the source-side runtime dependency audit now matches callers to packaging: CAVA is covered by distro/Nix paths plus generic guidance, Weather's hard dependency is `curl` with optional Geoclue GPS fallback, and Thinkfan remains an explicitly optional hardware capability whose upstream executable/service/config are never fabricated by Hadalis;
- tray/context-menu output ownership, popup focus lifecycle, reverse retract and exact-menu delayed-close protections remain part of the connected-surface contract.

Maintainer-reported follow-up checklist below is **source-side only**. A checked item means the source condition has been addressed or already exists on current `dev`; it does **not** mark the corresponding release/runtime gate as passed:

- [x] **Thinkfan missing helper after update:** required state-based migration reconciles `/usr/libexec/inir-thinkfan` and the Hadalis polkit action for repo-managed installs. Live update + System Monitor validation is pending.
- [x] **KeyboardFocusRing `Appearance` import:** current source already imports `qs.modules.common`. Live shell update/reload validation is pending.
- [x] **Connected popup geometry:** shared `StyledPopup` keeps each control's tangent center/extent but normalizes the cross-axis attachment to the real horizontal/vertical Bar surface (`barHeight` / `verticalBarWidth`), so differently sized controls grow from one physical edge while retaining the canonical connector width/seam tokens. Live top/bottom/left/right validation is pending.
- [x] **Bar/Screen Edge overlap and color:** current source suppresses the Screen Edge and its adjacent corner overlay on the exact output/edge owned by the horizontal or vertical ii Bar, mirrors the Bar's stale-`screenList` fallback, and uses the Material Bar `colLayer0` surface token. Live placement/color validation is pending.
- [x] **Media Popup equalizer:** source now forwards the shared CAVA service's adaptive `normalizationCeiling` into `PlayerControl` instead of scaling the wave against a fixed 1000; this preserves the existing CAVA lifecycle while making normal 20–100-range playback peaks occupy a visible waveform range. Live play/pause/player-switch/reopen validation is pending.
- [ ] **Time & Date / Weather hover:** remove the redundant separate Time & Date hover surface, route hover into the Weather/Calendar composition, and tighten the Serpantinum-inspired frontend while retaining Hadalis detailed weather ownership on the right.
- [x] **Left/right Sidebar connectors:** the connector now lives inside the owning `SidebarHost` PanelWindow, shares its output/centering/lifecycle, overlaps the physical edge-to-card gap through `PerimeterTokens.seamOverlap`, and uses the sidebar's Material/card surface token. Live left/right validation is pending.
- [x] **Overview bottom connector:** the dashboard's visible `dashContainer` now exposes its exact body rect/color and the owning Overview window draws a shared `ConnectedSurfaceConnector` from that body to the inner boundary of the bottom Screen Edge using the canonical width/seam tokens. Live Meta/Super+Space validation is pending.
- [x] **Thinkfan uninstall ownership symmetry:** repo-managed normal/quick uninstall now removes only the Hadalis-owned helper/policy, preserves package-manager-owned bridge files, and never removes/disables upstream Thinkfan package/service/config. Local uninstall-path validation is pending.

Still open / must be treated as unfinished until audited or locally validated:

1. **Regression/docs residue is narrowed but still open.** `docs/PERIMETER.md` now documents only the supported connected-surface architecture and explicitly marks the broad `modules/perimeter` runtime as retired; continue auditing source-only common-perimeter compatibility helpers and any other stale docs/tests before deleting code. Do not change supported runtime behavior merely to satisfy stale tests.
2. **Maintainer-reported connected-surface/UI issues remain open.** Popup connector geometry, Media visualizer visibility and Time/Date+Weather hover composition still require concrete source fixes; Overview bottom attachment is source-fixed but needs live validation; Sidebar connector ownership is source-fixed but needs live validation; same-edge Screen Edge ownership/color is source-fixed but still needs live validation.
3. **No authoritative local pass has been run for this source state.** Calendar/Weather sizing/scaling, Thinkfan bridge reconciliation, CAVA lifecycle, Screen Edge behavior and compositor interactions still require the maintainer's local validator plus live Niri/Hyprland smoke checks.

Recommended next source-side sequence:

1. refetch `dev` and `stable`, inspect every concurrent commit, and re-read README/targets on the latest HEAD before editing;
2. live-validate the source-fixed connected-surface cluster later; do not rebuild the retired broad perimeter runtime;
3. live-validate the source-fixed Media Popup CAVA/WaveVisualizer scaling later;
4. merge Time & Date hover behavior into the Weather/Calendar popup and tighten its Serpantinum-inspired left/center frontend while keeping Hadalis detailed weather on the right;
5. finish the remaining source-only common-perimeter compatibility audit and remove/update any other stale regression contracts/docs that still describe retired runtime/theme behavior;
6. hand the exact candidate SHA to the maintainer for `bash scripts/validate-maintainer-local.sh` plus the live desktop smoke matrix. Do not mark release gates complete before that result exists.

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
- Media Popup có source path CAVA -> PlayerControl -> WaveVisualizer, nhưng maintainer report runtime vẫn chưa thấy Equalizer;
- tray/context-menu output ownership và popup focus/close contracts đã được harden.

Maintainer-reported việc còn phải sửa:
1. Connected popup geometry phải liền với Bar/Screen Edge kiểu Caelestia; connector/body phải align đúng.
2. Nếu Bar chiếm một edge thì không render Screen Edge trên cùng edge đó; Screen Edge dùng cùng surface color contract với Bar.
3. Media Popup phải thực sự hiển thị Equalizer/CAVA.
4. Bỏ hover popup riêng của Time & Date; merge hover vào Weather/Calendar và làm frontend left/center sát Serpantinum hơn, vẫn giữ detailed Hadalis weather ở right.
5. Left/Right Sidebar connector hiện có source nhưng runtime report không thấy nối vào vertical Screen Edge; tìm root cause geometry/visibility.
6. Overview/dashboard mở bằng Super/Meta+Space phải nối vào bottom Screen Edge.
7. Thinkfan uninstall ownership symmetry: repo-managed uninstall chỉ dọn Hadalis helper/policy khi đúng context; không remove/disable upstream Thinkfan package/service/config và không phá package-manager ownership.
8. Packaging/runtime dependency audit cho CAVA, Thinkfan và Weather đã có source contract; tiếp tục dọn common-perimeter residue + stale regression/docs mà không biến Thinkfan thành hard dependency hoặc tự tạo fan config.

Sau mỗi nhóm thay đổi: refetch trước write, giữ patch nhỏ/atomic, commit trực tiếp lên `dev`, cập nhật checklist source-side trong README, xác nhận HEAD sau commit và báo root cause/goal, file đã đổi, SHA, source-level contract thay đổi và phần local/runtime validation còn lại.
```
