# Hadalis — v1.0 Release Plan / Development Contract

> This README is the current product and execution contract for completing **Hadalis 1.0**.
> It intentionally contains only active requirements, release blockers, architecture constraints and validation gates. Historical implementation notes, one-off commit hashes and stale migration narratives belong in Git history / `CHANGELOG.md`, not here.
>
> **Target:** `1.0`  
> **Primary development branch:** `dev`  
> **Stable baseline:** `stable`  
> **Scope refresh:** 2026-09-17

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

## 11. Current source-side handoff

This section records the **current source implementation state**, not local/runtime validation. Keep release-gate checkboxes above unchecked until the maintainer performs the authoritative local pass.

Source work already present on `dev`:

- persistent Screen Edge surfaces exist in `modules/screenCorners/ScreenEdges.qml`; the intended behavior is visible while idle/normal/maximized and hidden only for the explicit fullscreen/lock cases;
- Screen Edge width is exposed through the active Bar Settings path rather than a retired renderer path;
- connected popup connector width is centralized through the shared perimeter tokens/geometry instead of expanding to each source control width;
- `modules/sidebar/SidebarEdgeConnectors.qml` connects Left/Right Sidebar presentation to the corresponding vertical Screen Edge, independent of top/bottom Bar placement;
- the critical ii shell no longer boots the broad `PerimeterRuntime` cutover to own Bar/VerticalBar/Dock;
- Thinkfan standalone connected-surface/content files have been removed from normal UX and Thinkfan controls/state are integrated into the existing System Monitor/resources popup path, with a dedicated regression contract;
- `Settings > Bar` has a real supported v1.0 facade/content path instead of the previous blank route;
- public Global Theme Settings are constrained to Material, with legacy style UI hidden and persisted legacy values normalized through the supported Material path;
- the Calendar/Weather composition has source implementation for the requested Serpantinum-inspired left/center presentation while retaining Hadalis detailed weather ownership/content on the right;
- Media Popup owns the existing CAVA -> `PlayerControl` -> `WaveVisualizer` path and now gates visualizer activity by popup presentation/playback lifecycle; a regression contract protects that lifecycle;
- tray/context-menu output ownership, popup focus lifecycle, reverse retract and exact-menu delayed-close protections remain part of the connected-surface contract.

Still open / must be treated as unfinished until audited or locally validated:

1. **Broad `modules/perimeter` cleanup.** `PerimeterRuntime` ownership was retired from the critical shell, but the broad module still contains self-contained topology/adapters/settings/test residue. Do not delete it wholesale until exact current callers are re-audited. In particular, recent Weather work still touched `modules/perimeter/WeatherConnectedSurface.qml`, so verify whether that adapter is active or residue before removal.
2. **Perimeter Settings residue.** Re-check `ShellLayoutConfig.qml` and all `test-perimeter-*` contracts. Any user-facing “Connected Perimeter runtime” switch with no active runtime effect must be removed, and stale tests that require the retired cutover must be rewritten or removed in the same cleanup.
3. **Shared primitives must survive cleanup.** Never remove `modules/common/perimeter/ConnectedSurface*`, `PerimeterTokens.qml`, or other shared geometry/routing pieces that still have active popup/sidebar consumers merely because the broad runtime is being retired.
4. **Material-only runtime cleanup is not finished merely because the selector is hidden.** Continue searching for non-Material runtime branches/assets/imports and remove only those with no supported caller; retain only narrow persisted-value migration to Material.
5. **CAVA packaging/dependency still needs confirmation.** Source lifecycle is wired, but the supported install/package path must ensure `cava` is actually available or document/install it explicitly.
6. **Calendar/Weather and Thinkfan need live UX validation.** Source contracts exist, but sizing, scaling, missing-service behavior and interaction must be tested in the maintainer's environment.
7. **No authoritative local pass has been run for this source state.** Do not claim completion until `bash scripts/validate-maintainer-local.sh` plus the live Niri/Hyprland smoke matrix has been run by the maintainer.

Recommended next source-side sequence:

1. refetch `dev` and `stable`;
2. inspect commits that landed since the previous turn before editing anything;
3. finish the broad `iiPerimeter` audit/cleanup, beginning with dead Settings UI and stale `test-perimeter-*` contracts, while preserving shared connected-surface primitives and any proven active Weather/System Monitor caller;
4. audit all current Python/shell regression contracts for assumptions about retired APIs/runtime, fixing tests to match supported behavior rather than changing runtime to satisfy stale tests;
5. audit packaging/install manifests for `cava`, Thinkfan helper/runtime requirements and weather dependencies;
6. perform final source review for Material-only live references, popup connector consistency and Settings routing;
7. hand the resulting exact candidate SHA to the maintainer for the single authoritative local test pass.

## 12. New-conversation continuation prompt

Copy/paste the following into a new conversation when continuing Hadalis work:

```text
Bạn đang tiếp tục phát triển repo GitHub `llocphann/Hadalis` cho Hadalis 1.0.

Hãy đọc README.md trên branch `dev` trước vì đó là development contract + handoff hiện tại. Làm trực tiếp trên branch `dev`, không tạo PR trừ khi tôi yêu cầu. Trước mỗi nhóm thay đổi quan trọng và ngay trước mỗi write có khả năng conflict, phải refetch cả `dev` và `stable`, rồi đọc lại target file/caller trên đúng HEAD mới nhất. Repo có thể có commit concurrent nên tuyệt đối không sửa dựa trên snapshot cũ.

Không chạy/check GitHub Actions/CI vì usage limit đã hết. Tôi sẽ chạy `bash scripts/validate-maintainer-local.sh` và live-test một lượt cuối trên máy local. Không được nói rằng test đã pass nếu chưa thực sự có local result từ tôi.

Mục tiêu UI/UX: giữ kiến trúc/functionality iNiR hiện có nhưng làm connected surfaces theo hướng Caelestia. Không build popup framework mới. Existing bar popups vẫn đi qua `modules/bar/StyledPopup.qml` + `modules/common/perimeter/ConnectedSurface*` + `PerimeterTokens.qml`. Không reintroduce `PanelWindow.active/onActiveChanged`, Pill/Mascot runtime, retired Bar/Dock renderers, Orbit/workspace experiments hay non-Material Global Themes. Waffle vẫn là panel family được support.

Trạng thái source hiện tại đã có:
- persistent Screen Edge + width setting;
- connector width dùng shared contract;
- Left/Right Sidebar có edge connector riêng;
- critical ii shell không còn boot full `PerimeterRuntime` cutover;
- Thinkfan đã tích hợp vào System Monitor/resources popup, standalone Thinkfan connected surface/content đã được bỏ khỏi normal UX;
- Bar Settings có facade/content thật;
- public Global Theme Settings là Material-only và legacy style value được normalize về Material;
- Calendar/Weather đã có composition Serpantinum-inspired cho left/center nhưng giữ detailed Hadalis weather ở right;
- Media Popup dùng CAVA -> PlayerControl -> WaveVisualizer và lifecycle đã được gate theo popup presentation/playback;
- tray/context-menu output ownership và popup focus/close contracts đã được sửa trước đó.

Việc ưu tiên tiếp theo:
1. Audit và hoàn tất cleanup broad `modules/perimeter`: runtime cutover đã retire nhưng topology/adapters/settings/tests residue còn tồn tại. Bắt đầu từ `ShellLayoutConfig.qml` và toàn bộ `test-perimeter-*`. Xóa user-facing Connected Perimeter switch nếu không còn effect. Chỉ xóa broad runtime/adapters sau khi chứng minh không còn active caller. Recent Weather work có chạm `modules/perimeter/WeatherConnectedSurface.qml`, nên phải kiểm tra exact caller trước khi xóa.
2. TUYỆT ĐỐI giữ `modules/common/perimeter/ConnectedSurface*`, `PerimeterTokens.qml` và shared routing/geometry còn consumer; full iiPerimeter runtime và shared popup primitives là hai thứ khác nhau.
3. Tiếp tục Material-only cleanup ở runtime/assets/imports, nhưng chỉ xóa non-Material code không còn supported caller; giữ migration shim tối thiểu để normalize persisted legacy value về Material.
4. Audit regression tests để tìm contract stale (đặc biệt assumptions về retired runtime/API). Sửa test theo supported runtime, không làm runtime regress chỉ để chiều test cũ.
5. Audit package/install dependency cho `cava`, Thinkfan helper/runtime và weather; source wiring không đủ nếu package thiếu.
6. Rà final connector/settings routing và chuẩn bị source state cho một local test duy nhất của tôi.

Luôn ưu tiên root cause, patch nhỏ/atomic, commit trực tiếp lên `dev`, và báo cáo ngắn gọn sau mỗi nhóm thay đổi. Nếu không tìm thấy bug/source inconsistency cụ thể thì đừng churn UI/speculative code.
```
