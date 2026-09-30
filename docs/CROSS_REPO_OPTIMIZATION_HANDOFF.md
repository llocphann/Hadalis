# Cross-repo optimization handoff — Hadalis ⇄ iNiR prerelease

> Scope: **optimization only**. This document exists so a future chat/agent can continue improving Hadalis by studying proven patterns from iNiR or other repositories without re-auditing everything from zero.
>
> This is **not** a feature-parity roadmap, a visual redesign plan, or an instruction to blindly merge upstream.

## 1. Audit snapshot

Audit date: 2026-09-28.

### Source refs

- Hadalis target branch: `llocphann/Hadalis@dev`
- Hadalis head at audit start: `2874ff988c08817057e7bfde63141347a0bbbc15`
- Hadalis head after audit reconciliation / handoff base: `f6b479bbe86a305d6a57bacc0d240e6e82d8c747`
- iNiR comparison branch: `snowarch/iNiR@prerelease`
- iNiR comparison head: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

Hadalis moved by two commits during the audit. The delta from `2874ff9` to `f6b479b` is limited to Abyss popup/perimeter motion work:

- `modules/abyss/AbyssBodyHost.qml`
- `modules/abyss/AbyssPerimeter.qml`
- `modules/abyss/AbyssSurfaceController.qml`
- new `scripts/test-abyss-multi-styled-popup.sh`

That delta does not invalidate the optimization findings below.

### Repo-wide inventory notes

The initial recursive-tree comparison covered the full source trees, then performance-relevant subsystems were read in depth.

At the initial snapshot:

- Hadalis: ~2310 blobs.
- iNiR prerelease: ~2353 blobs.
- Paths existing in both repos: 1799.
- Byte-identical shared blobs: 1036.
- Same path but changed content: 763.
- Hadalis-only paths: 511.
- iNiR-only paths: 554.

The divergence is large enough that **commit/pattern archaeology is more useful than bulk copying files**.

Important structural difference:

- Hadalis has a production Rust workspace under `native/` plus parity/benchmark infrastructure.
- iNiR prerelease does not have Hadalis' native cutover architecture.
- Hadalis also has the Abyss family and substantial lifecycle/regression tests that upstream does not share verbatim.

## 2. Decision vocabulary

Every optimization imported from another repository MUST be classified before implementation:

| Status | Meaning |
|---|---|
| **ADAPT** | Good idea, but must be rewritten around Hadalis architecture and measured. |
| **ALREADY / SUPERSEDED** | Hadalis already contains the optimization or a stronger version. Do not port it again. |
| **INVESTIGATE** | Plausible win, but no implementation until a local profile proves the cost exists. |
| **DO NOT PORT** | Conflicts with Hadalis architecture, duplicates current work, or trades correctness/UX for a synthetic win. |
| **REJECTED AFTER MEASURE** | Tested locally and not beneficial. Keep the rationale here so a later agent does not retry it. |

Optimization work is evidence-driven. Upstream commit messages are useful leads, not proof that the same bottleneck exists in Hadalis.

---

## 3. Verified upstream optimizations already present or superseded in Hadalis

These are **regression guards**, not backlog items.

### 3.1 Split critical shell from deferred/heavy panels — ALREADY / SUPERSEDED

Relevant iNiR commit:

- `692ff528361fa12860a4405210eddf0ef788ee3a` — `perf(startup): reduce QML scan and split critical panels`

Hadalis already has:

- `ShellIiPanels.qml`
- `ShellWafflePanels.qml`
- `ShellAbyssPanels.qml`
- `modules/ii/critical/ShellIiCriticalPanels.qml`
- `modules/waffle/critical/ShellWaffleCriticalPanels.qml`
- `modules/abyss/critical/ShellAbyssCriticalPanels.qml`
- deferred `Shell*PanelsImpl.qml` roots
- source/URL boundaries and asynchronous deferred loading
- `scripts/test-critical-panel-isolation.sh`
- `scripts/test-critical-panel-isolation-regression.sh`

Hadalis also has on-demand panel lifetimes in ii/Waffle and demand-loaded specialist surfaces in Abyss. Do not replace these with a simpler upstream loader model.

### 3.2 Visible-consumer resource polling — ALREADY / SUPERSEDED

Relevant iNiR commit:

- `1c94fc74bf035b6942e337524160c668b92038a0` — `perf(resources): scope polling to visible consumers`

Hadalis already goes further:

- `modules/common/widgets/ServiceLease.qml` provides acquire/update/release symmetry.
- `modules/common/widgets/ResourceUsageMonitor.qml` leases ResourceUsage based on visibility/window state.
- It separately tracks history and network demand.
- `services/ResourceUsage.qml` has transient consumers, persistent consumers, auto-stop, expensive GPU poll throttling, and retry-safe initialization.

Do not regress this to a simple boolean `keepAlive()`.

### 3.3 Hidden/reduced-motion animation gating — ALREADY / SUPERSEDED

Relevant iNiR commit:

- `580aca0ca4c1bd03d6f5c37944235c867a882517` — `perf(widgets): stop hidden and reduced-motion indicator animations`

Verified in Hadalis:

- `CircularProgress.qml` gates animation on item visibility, containing window visibility, and `Appearance.animationsEnabled`.
- `MaterialLoadingIndicator.qml` does the same and resets rotation when stopped.

Rule: any new infinite animation must follow this visibility/window/reduced-motion pattern.

### 3.4 Shared second-aligned timer clock — ALREADY / SUPERSEDED

Relevant iNiR commit:

- `ddc3058f85a91d63f794bdd186efffbc2df364a4` — `perf(timers): share a second-aligned clock for countdowns`

Hadalis `services/TimerService.qml` already uses one `SystemClock.Seconds` source for Pomodoro + countdown and keeps the stopwatch on its intentional higher cadence.

Hadalis also has stronger pause/restore persistence semantics. Do not re-port upstream TimerService.

### 3.5 Levenshtein workspace reuse / redundant search work — ALREADY

Relevant iNiR commit:

- `4f28d2197269d5eba878e87b200a817a91a35eea` — `perf(search): reuse edit-distance workspace and skip redundant work`

Hadalis `modules/common/functions/levendist.js` already:

- reuses two row buffers in `partialRatio()`
- fast-paths substring hits
- avoids per-window row allocation

Treat this as a regression guard.

### 3.6 Lazy settings page cache + Qt QML disk cache — ALREADY, but section-level work remains possible

Relevant iNiR commit:

- `32d61a38f7042a190e56f3fe4c1b49c9f833200c` — `perf(settings): cache lazy QML pages`

Hadalis `modules/settings/SettingsPageHost.qml` is already more sophisticated:

- LRU retained pages with `cacheLimit`
- current + pending page residency
- asynchronous non-current page incubation
- request-generation invalidation to prevent stale callbacks
- transition-aware teardown
- conversion of absolute page paths to `file://` so Qt can reuse compiled QML cache

Do not replace the page host with upstream's simpler implementation.

### 3.7 Wallpaper/video/blur lifetime fixes — ALREADY / SUPERSEDED

Relevant upstream history:

- `716da4c942ad59e11572248e1dd577905299873a` — release hidden wallpaper effects
- `1ac86c13f63477dffcf0162223220549f47f8e5e` — stop inactive family decoding video wallpaper
- earlier VRAM/blur work including `c1ebe00648d62e5b4f7c2fab9b043ccd17ecaa2a`

Verified in current Hadalis:

- `Background.qml` has `_familyOwnsScreen` and clears video `source` when the family no longer owns the screen.
- `WaffleBackground.qml` mirrors the ownership guard.
- `shouldPlay` is also family/visibility gated.
- blur `layer.enabled` is visibility/effects gated.
- static wallpaper source is cleared when no active path/blur consumer needs it.
- `WallpaperCrossfader.qml` uses `cache: false` for full wallpaper slots.
- the inactive wallpaper slot clears `source` after transition.
- wallpaper size/identify cache is bounded to 64 entries.
- Waffle only retains a static texture when the wallpaper itself or local blur needs it.

These fixes are especially important during family switches. Keep them covered by regression tests when touching Abyss/Waffle/ii transitions.

### 3.8 Bounded Wallhaven/transient result caches — ALREADY

Relevant iNiR history:

- `3d5a2ee95b4795d9c0e213a499f068ec999df43d` — `perf(models): bound transient result lifetimes`

Verified in Hadalis `services/Wallhaven.qml`:

- response limit: 20
- tag suggestion cache: 64
- wallpaper tag cache: 256
- tag count cache: 256
- evicted QObjects are destroyed after publication
- bounded insertion helper is present

Verified in `services/deferred/LauncherSearch.qml`:

- launcher result data is built as plain JS objects rather than transient QObjects.

Do not recreate the older QObject-heavy launcher-result model.

### 3.9 Window preview cache budgeting — HADALIS-SPECIFIC, already strong

`services/WindowPreviewService.qml` has a bounded decoded warm cache:

- `overviewWarmLimit: 12`
- decode size: 768×512
- explicit destroy on replacement/eviction/session change
- LRU ordering
- cache refresh only for bounded visible windows

Guarded by `scripts/test-window-preview-cache-behavior.sh`.

Any future upstream preview-cache idea must beat this design under measurement rather than replacing it by default.

### 3.10 malloc arena optimization — IDENTICAL

`sdata/migrations/014-malloc-arena-optimization.sh` is byte-identical between the audited snapshots.

No action.

---

## 4. Real optimization opportunities to investigate/adapt

### P0 — Family/consumer-aware deferred service materialization

**Status: ADAPT**

This is the clearest remaining upstream architecture idea.

Current Hadalis `shell.qml` staggers services by time, but Tier 3/4 still materialize several services globally.

Tier 3 currently forces, among others:

- `GameMode`
- `WindowPreviewService`
- `Weather`
- `VoiceSearch`
- `CavaTheme`

Tier 4 forces, among others:

- `ShellUpdates`
- `Autostart`
- `CalendarSync`
- `FontSyncService`

iNiR prerelease added family-aware helpers in `shell.qml` that skip services not needed by iRiS. **Do not copy its hard-coded `family !== "iris"` rule.**

Hadalis adaptation must instead build a consumer matrix for **Abyss / Waffle / ii compatibility** and for enabled panels/features.

Required implementation sequence:

1. Identify which services own required IPC targets and therefore need a lightweight always-live router.
2. Identify which services have background processes, network requests, file watchers, timers, or large caches.
3. Map each service to real consumers and feature flags.
4. Materialize expensive implementation only when at least one consumer exists.
5. Preserve the IPC contract across family switches and config reloads.
6. Measure cold startup, idle CPU, thread count, process count and PSS before/after.

Do not gate a service merely because its UI is hidden. Some services collect session history or own IPC.

### P0 — Re-audit heavy visual ownership whenever Abyss family boundaries change

**Status: INVESTIGATE / continuous guard**

Hadalis already fixed the classic inactive-family video/blur leaks, but Abyss is under active development and shares `Background.qml` plus connected perimeter rendering.

Every change to family transitions, Abyss host ownership, popup hosts, backgrounds, or blur topology must verify:

- only one family decodes a video wallpaper after transition completion
- no outgoing family retains a fullscreen static wallpaper source without a consumer
- no hidden layer retains an unnecessary FBO
- infinite animations stop when the window/item is not rendered
- family transition overlays unload after the transition
- popup reveal/eviction animations do not keep an otherwise dead heavy tree resident

This is a regression class, not a request to rewrite the current background stack.

### P1 — Section-level lazy residency inside very large Settings pages

**Status: ADAPT after profiling**

iNiR prerelease has the former SettingsTaskLoader component:

- heavy section is created only when requested
- it stays resident briefly (~600 ms) after deselection to avoid rapid destroy/recreate thrash
- visibility/enabled state is separated from residency

Hadalis already caches whole pages, but some pages are individually very large. Candidate pages should be selected by compile/incubation/profile evidence, not file size alone.

Likely places to profile include large settings pages such as Desktop Widgets, Niri, Background, Interface, Services, etc.

Hadalis constraints that an adapted section loader MUST preserve:

- Settings search / `SettingsSearchRegistry`
- deep-link section activation
- focus/editor state
- navigation retry behavior for lazily created controls
- no Loader feedback loop
- no writes triggered merely by page construction
- quick back/forward navigation should not churn expensive sections

Start with one measured page. Do not mass-convert every `SettingsGroup`.

### P1 — Audit shared media artwork resolution cache

**Status: INVESTIGATE**

iNiR prerelease adds a small bounded MediaArtworkCache component (64 entries) that remembers the last resolved artwork URL per track so a later-created player can show the same cover immediately without resolving again.

Hadalis does not currently have this exact singleton.

Before adapting it:

1. trace Hadalis' media/YTMusic/local music artwork resolution paths
2. count repeated URL/path resolution and image placeholder churn during real panel open/close
3. verify Qt image caching is not already enough
4. define the cache key so stale art cannot be shown for reused metadata
5. bound the cache and clear it on relevant library/session changes

Only implement if it removes measurable repeated resolution, decode or subprocess/network work.

### P1 — Shader early rejection for Abyss/perimeter effects

**Status: INVESTIGATE; conceptual port only**

Relevant iNiR commit:

- `064c18b4da5279d261d2a3dcc3710c9eb61f0a55` — `perf(organic): reduce screen edge fragment cost`

The iNiR shader optimization rejects fragments before expensive SDF/trig/audio-band work and computes corner masking only near corners.

Hadalis should **not port the OrganicScreenEdge shader**. Instead use the principle when profiling Abyss/perimeter shaders:

- reject outside active edge/segment bounds as early as possible
- avoid per-fragment functions for values that can be prepared as uniforms
- avoid corner SDF work away from corners
- avoid full-screen fragment work for thin perimeter effects
- preserve exact connected geometry and visual output

Any shader change needs GPU/frame-time evidence and visual comparison at multiple resolutions/scales.

### P1 — Search for remaining unbounded caches and transient QObjects

**Status: INVESTIGATE**

Wallhaven, launcher results, window previews and key wallpaper caches are already bounded. Continue the pattern repo-wide:

- cache must have an explicit capacity, lifecycle, or both
- QObject cache eviction must call `destroy()` when ownership requires it
- plain result data should prefer plain JS objects over QObjects
- hidden visual caches should have a documented memory budget
- caches keyed by paths/URLs must account for revision/staleness

Prioritize services whose state grows with user activity: thumbnails, icons, notifications/history, search results, generated media, preview objects, and plugin/web content.

Do not add arbitrary limits without understanding user-visible retention semantics.

### P2 — Nix runtime source filtering

**Status: ADAPT; build/package optimization, not shell runtime**

iNiR prerelease has `nix/runtime-source-filter.nix` driven by:

- `sdata/runtime-exclusions.json`
- `sdata/runtime-payload-dirs.txt`
- `sdata/runtime-root-files.txt`

Hadalis already has those runtime payload manifests, but `nix/package.nix` currently uses:

```nix
src = lib.cleanSource ../.;
```

for the shell derivation.

Candidate improvement: adapt a source filter so Nix does not hash/copy source-only docs, tests, tooling, artifacts and unrelated paths into the derivation input.

Constraints:

- Hadalis packages the Rust workspace separately, so do not accidentally filter files needed by native build/install.
- runtime payload generated/validated by Hadalis scripts remains authoritative.
- package parity must be tested on NixOS/Home Manager paths.
- this is expected to improve derivation/source handling, not runtime FPS/RSS.

### P2 — Re-check EasyEffects status polling only if it becomes hot

**Status: INVESTIGATE, low priority**

iNiR commit:

- `6217367019babac8d038c1d897ff9b5f10b7ee61` replaced a shell pipeline with direct `pgrep -x easyeffects`.

Hadalis' audio/EQ path has diverged substantially and includes native/default behavior plus explicit EasyEffects integration. Do not overwrite it from upstream.

If process sampling shows repeated shell pipelines or redundant status polling, simplify the probe locally while preserving Flatpak/native detection and preset behavior.

### P2 — Cava rendering lessons only where Hadalis still pays duplicated paint cost

Relevant iNiR commit:

- `97e9521459bdac8d038c1d897ff9b5f10b7ee61` — shared/snapshotted bar spectrum frames

Hadalis already has its own `BarCavaVisualizer.qml`, Cava service/subscription logic and optimization guidance. Treat upstream as a profiling reference only.

Measure:

- number of Cava processes
- number of active subscribers
- Canvas repaint rate while hidden
- per-monitor duplicated render cost
- CPU/GPU impact of bar spectrum modes

Do not replace Hadalis' current Cava architecture just because file shapes differ.

---

## 5. Patterns explicitly NOT to port blindly

1. **Hard-coded iRiS family conditions.** Hadalis' family graph is different; use an actual consumer matrix.
2. **Bulk iRiS / Orbit / Pill / M3 feature trees.** Feature parity is outside this handoff.
3. **Upstream loader code that is simpler than Hadalis' current lifecycle primitives.** Keep `ServiceLease`, current `SettingsPageHost`, current panel ownership rules, and current window-preview budgeting unless measurement proves a defect.
4. **Python-first backend rewrites.** Rust is Hadalis' production backend.
5. **“Optimization” by permanently disabling animations/effects/features.** Respect user config, reduced-motion and low-power modes; optimize lifecycle and work instead.
6. **Blanket asynchronous Loaders.** IPC targets, required properties, input focus and exit transitions can break if an implementation is moved behind the wrong async boundary.
7. **Visibility-only optimization for heavyweight sources.** `visible: false` does not necessarily release decoded images, media decoders, processes or caches. Clear/deactivate the actual resource.
8. **Unbounded “performance caches.”** A faster hot path that grows forever is not an optimization.
9. **Removing resident state without preserving user context.** Heavy visual trees may be disposable; navigation/editor/session state often is not.

---

## 6. Rust native vs Python fallback policy

Hadalis production default is Rust. The selector is `scripts/native-dispatch`; `scripts/native-backend rust|python|status` exists for controlled cutover/rollback.

Current native command ownership includes:

- `inir-inputd`: input lock / physical-key listener
- `inir-native`: Niri helpers, clipboard filter, desktop icon sync
- `inir-mpdd`: MPD compatibility/daemon/subscription/lyrics
- `inir-theme`: theme generation
- Python implementations remain explicit fallback paths for supported commands

Optimization rules:

1. Benchmark normal Hadalis behavior in **Rust production mode** first.
2. A QML/UI optimization does not require touching Python fallback unless it changes a shared protocol/contract.
3. A Rust backend behavior change must keep Python parity where a documented fallback exists.
4. Do not “optimize” by silently sending production traffic back to Python.
5. Persistent Rust-only services such as the MPD daemon/subscription must not be modeled as Python equivalents if no fallback contract exists.
6. If an external-repo optimization targets a Python helper that Hadalis has already replaced with Rust, port the **algorithmic idea** to the Rust implementation only if profiling proves it is still relevant.

When native code or selector semantics change, run the existing native parity/benchmark gates.

---

## 7. Benchmark and regression protocol

No optimization is “done” because code got smaller.

### 7.1 Baseline before each optimization batch

Record:

- exact Hadalis commit SHA
- exact comparison repo/ref SHA
- active panel family
- enabled panels/features relevant to the test
- monitor count/resolution/scale
- wallpaper type: static / GIF / video
- animation/effects/low-power settings
- native backend mode

### 7.2 Startup

Use the existing boot-phase data written to:

- `~/.cache/inir/last-boot.json`

Compare cold and warm runs where relevant:

- shell Component completion
- Config ready
- first shell entry
- deferred services
- late features

Do not claim startup improvement from one run.

### 7.3 Idle/runtime footprint

Measure at minimum:

- shell RSS and preferably PSS from `/proc/<pid>/smaps_rollup`
- user service/cgroup memory
- thread count
- child/subprocess count
- idle CPU over a fixed window
- GPU/VRAM or compositor/GPU engine use when the hardware exposes it

For family-switch tests, measure after transitions settle and verify outgoing media/process resources are gone.

### 7.4 Interaction scenarios

At minimum:

- open/close/reopen heavy panels rapidly
- switch ii/Waffle/Abyss where supported
- settings rapid page navigation + search/deep-link
- static → static wallpaper
- static → video and video → video
- multi-monitor open/close/switch
- overview/task view preview warm/reopen
- reduced motion and effects disabled
- lock/unlock if touched subsystem participates

### 7.5 Existing Hadalis gates to reuse

Run the smallest relevant set first, then the maintainer-local suite before landing a broad lifecycle change.

Useful existing guards include:

- `bash scripts/test-performance-lifecycle.sh`
- `bash scripts/test-resource-usage-lifecycle.sh`
- `bash scripts/test-window-preview-cache-behavior.sh`
- `bash scripts/test-window-preview-lifecycle.sh`
- `bash scripts/test-appsearch-binding-cache.sh`
- `bash scripts/test-critical-panel-isolation.sh`
- `bash scripts/test-critical-panel-isolation-regression.sh`
- `bash scripts/validate-maintainer-local.sh --current-repo`

When native/backend behavior is touched:

- `bash scripts/native-cutover-benchmark.sh`
- `bash scripts/benchmark-python-vs-rust.sh`

Use the native scripts' parity gates rather than comparing only wall-clock time.

---

## 8. Risk matrix

| Optimization area | Main breakage risk | Required guard |
|---|---|---|
| Deferred service materialization | missing IPC target, no history before UI opens, stale service after family switch | IPC smoke + family switch + service consumer matrix |
| On-demand panel unloading | lost editor/navigation state, broken exit animation, focus/grab leak | rapid reopen + keyboard/mouse + state retention |
| Settings section lazy loading | search target absent, deep-link retry failure, Loader churn | search/deep-link + rapid navigation + focus |
| Wallpaper source release | flicker/black frame, stale transition, wrong monitor | static/video transitions on multi-monitor |
| Video ownership | duplicate decoder or outgoing-family audio/video leak | family switch + process/thread/CPU measurement |
| Blur/FBO gating | visual mismatch, stale texture, rectangular artifact | effects on/off + all style/topology variants |
| Cache bounds | stale data or excessive re-fetch after eviction | long session + revisit + invalidation tests |
| Shader early reject | clipping/seams, resolution/scale-specific artifacts | screenshots/frame capture across scales |
| Nix source filtering | missing runtime file in package | build + install + smoke through Nix/Home Manager |
| Rust optimization | protocol/parity regression | native parity suite + rollback test |

---

## 9. Recommended execution order

### P0 — Measure and reduce always-live background work

1. Build the Tier 0/3/4 service consumer matrix.
2. Measure startup + idle with each Hadalis family.
3. Adapt family/feature-aware service loading where evidence supports it.
4. Re-run IPC and family-switch tests.

### P1 — Reduce expensive UI creation only where profiling proves it

1. Profile large Settings pages.
2. Pilot section-level short-residency loader on one heavy section.
3. Verify Settings search/deep-link/focus.
4. Audit remaining unbounded caches/transient QObjects.
5. Profile Abyss/perimeter shader fragment cost before attempting early rejection.

### P2 — Packaging and secondary hot paths

1. Adapt Nix runtime source filtering.
2. Investigate media artwork resolution cache.
3. Re-check EasyEffects/Cava only if live traces show they are hot.

---

## 10. How to audit another repo later

When adding a third optimization source, append a record with:

- repository + branch/tag/commit
- exact optimization commit(s) or file(s)
- subsystem affected
- measured problem that exists in Hadalis
- Hadalis architecture conflict(s)
- classification: ADAPT / ALREADY / INVESTIGATE / DO NOT PORT
- benchmark before
- benchmark after
- regressions discovered
- final disposition

Do not add a candidate merely because the source repo calls it `perf:`.

---

## 11. Handoff maintenance rule

This file is the canonical handoff for **cross-repo optimization work only**.

After every meaningful optimization milestone:

1. Refetch current `Hadalis/dev` and source-repo refs.
2. Record the new exact SHAs.
3. Move the item to one of:
   - validated/adopted
   - superseded
   - rejected after measurement
   - still pending
4. Add benchmark evidence, not just a code summary.
5. Record any correctness/UX regression found during the attempt.
6. Keep rejected rationale; do not erase it.
7. If native/backend behavior changed, record which Rust binary and which Python fallback contract were touched.
8. Do not mix unrelated feature work, visual redesigns, or bug backlogs into this file.

### Next concrete task

Start with **P0 family/consumer-aware deferred services** in `shell.qml`.

Before changing code, produce a table of every forced Tier 0/3/4 singleton with:

- why it must exist
- IPC target ownership, if any
- family consumers
- enabled-panel/feature consumers
- timers/processes/watchers/network activity
- whether it can be represented by a lightweight router
- current startup/idle cost

Then change only the highest-cost service(s), one batch at a time, and benchmark.


---

## 12. Audit round 2 — unread-area coverage expansion (2026-09-28)

### Snapshot

- Hadalis ref audited during this round: `llocphann/Hadalis@dev`
- Hadalis head reconciled before this handoff update: `9aa1de046befd75f7b05f19e342ae60e28623480`
- iNiR comparison ref: `snowarch/iNiR@prerelease`
- iNiR head: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

Hadalis advanced repeatedly while this audit was running. The intervening commits were reconciled before updating this document. They primarily touched Abyss popup/focus/corner/wallpaper behavior plus related tests and documentation. The optimization conclusions below were checked against the current `dev` tree rather than the older handoff base.

### Coverage added in this round

This pass expanded the previous audit across areas that had not been read deeply enough:

- remaining common/core services and deferred services
- production native Rust workspace:
  - `inir-native`
  - `inir-inputd`
  - `inir-mpdd`
  - `inir-theme`
- Python fallback daemons and `scripts/native-dispatch`
- large Settings pages and section residency patterns
- shader sources, especially Abyss full-screen composition
- launcher/systemd/session environment lifecycle
- Nix packaging and runtime-payload policy
- migration differences after the common historical migration set
- clipboard watcher contracts
- cache/lifetime patterns
- notification, recorder, EasyEffects, thumbnail and sidebar lifecycle paths
- current iNiR perf/fix history relevant to these subsystems

The full repository is still too large to claim that every source file was read line-by-line. The audit method is now coverage-driven: every major runtime subsystem has been inventoried, and hot-path candidates are read in depth before classification.

---

## 13. Newly verified findings

### 13.1 Window preview eager prewarming is a real startup/runtime tradeoff — INVESTIGATE / likely P0 experiment

Hadalis currently force-instantiates `WindowPreviewService` in Tier 3 and the service immediately calls `_startPrewarming()`.

That path:

- initializes preview storage
- observes the current Niri window set
- queues screenshot capture for newly observed windows before Overview/TaskView/hover is opened
- pre-decodes captured/session-cached images into a bounded warm cache

This behavior is deliberate and covered by Hadalis tests such as the eager/incremental preview contract. It was added to remove first-hover latency.

Current iNiR prerelease has moved in the opposite direction:

- `WindowPreviewService` initializes only when a consumer requests previews
- window changes mark metadata dirty but do not automatically start screenshot work
- the service is also skipped for iRiS by family-aware Tier 3 loading

This is not a safe one-line port because Hadalis intentionally values instant first presentation.

**Required experiment:** compare three policies on the same session/window count:

1. current eager Tier-3 prewarm
2. pure consumer-lazy initialization
3. hybrid delayed/idle prewarm only when preview-capable surfaces are enabled

Measure:

- boot phase timing
- CPU/I/O and child processes during T+500ms to T+5s
- clipboard churn during preview capture
- time-to-first-preview for dock/taskbar/overview
- RSS/PSS including the bounded decoded-image cache

Do not remove eager prewarming without preserving a measured first-preview UX budget.

### 13.2 Tier 3/4 service consumer matrix is now partially classified

Current forced services and preliminary ownership:

| Service | IPC owner | Background work when instantiated | Current classification |
|---|---|---|---|
| `GameMode` | `gamemode` | fullscreen state + Niri animation policy | **KEEP forced for now**; global policy/IPC owner |
| `WindowPreviewService` | none | eager screenshot/predecode lifecycle | **INVESTIGATE P0** |
| `Weather` | none | delayed location + network fetch when enabled | **ADAPT candidate**; feature/consumer-aware |
| `VoiceSearch` | `voiceSearch` | mostly idle until invoked | **KEEP unless IPC router split is justified** |
| `CavaTheme` | none | cover-art theme work only when configured | **ADAPT candidate**; do not force while feature disabled |
| `ShellUpdates` | `shellUpdate` | repo/update timers and git checks when enabled | **KEEP unless lightweight IPC router is introduced** |
| `Autostart` | `autostart` | startup-file load/watch | **KEEP unless lightweight IPC router is introduced** |
| `CalendarSync` | none | cache load; periodic network work only if enabled | **ADAPT candidate**; instantiate only for enabled sync or active consumer |
| `FontSyncService` | none | debounced GTK/KDE sync; initial sync when enabled | **ADAPT candidate**; feature-gate on system-font sync |

Important details:

- `Weather`, `CavaTheme`, `CalendarSync` and `FontSyncService` do not need permanent IPC ownership.
- `CalendarSync` is disabled by default but is still force-materialized in Tier 4.
- `CavaTheme` is force-materialized even when wallpaper/Cava theming is disabled.
- `Weather` is enabled by default, so any change must preserve expected background refresh semantics.
- `VoiceSearch`, `GameMode`, `ShellUpdates` and `Autostart` own IPC targets; simply removing their forced instantiation can break CLI/keybind calls.

Next P0 implementation planning should finish this matrix with exact family/feature consumers and measured costs before editing `shell.qml`.

### 13.3 Reactive GameMode can remove fallback polling, but only with the NiriService prerequisite — ADAPT

iNiR commit:

- `3893d68da5` — `fix(game-mode): keep fullscreen state reactive`

Upstream now exposes:

- `NiriService.liveWindows` = pending window snapshot while UI batching is still outstanding
- GameMode fullscreen state derived directly from this reactive list
- no debounced `_autoActive` cache
- no periodic GameMode fallback timer

Hadalis still has the older debounced/polled path.

However, current Hadalis `NiriService` also lacks later correctness fixes from iNiR:

- full `WindowsChanged` snapshots do not update `_latestFocusedWindowId`
- a newly opened/changed window with `is_focused === true` does not update that focus ID
- several workspace map updates compare object keys from `for ... in` (strings) directly against numeric Niri IDs

Relevant iNiR follow-up:

- `a2d96ba5ac` — `fix(niri): notice every fullscreen on a workspace`

Therefore the safe adaptation is a single batch:

1. add `liveWindows`
2. port the focus freshness semantics
3. fix string-vs-numeric workspace-key comparisons where applicable
4. switch GameMode fullscreen reads to `liveWindows`
5. remove the debounce/fallback polling only after regression tests pass

Required tests:

- fullscreen enter/exit without focus change
- fullscreen window opened already focused
- multi-monitor active workspaces
- window moved between workspaces while fullscreen
- GameMode notification/visualizer suppression
- family surfaces hiding/showing correctly

### 13.4 Settings section residency is a broader gap than the first audit showed — ADAPT / P1

Hadalis already has strong page-level LRU behavior in `SettingsPageHost`, and `DesktopWidgetsConfig.qml` has a local asynchronous short-residency `LazySection`.

However, comparison with iNiR prerelease shows that most other large Settings pages still instantiate all section trees in Hadalis and only toggle `visible`.

Examples where iNiR uses `SettingsTaskLoader` but Hadalis currently does not include:

- `QuickConfig.qml`
- `InterfaceConfig.qml`
- `ServicesConfig.qml`
- `ThemesConfig.qml`
- `MonitorVisibilityConfig.qml`
- `AiConfig.qml`
- `ModulesConfig.qml`
- `ToolsConfig.qml`
- `SidebarsConfig.qml`
- `WaffleConfig.qml`
- `AdvancedConfig.qml`
- `AutostartConfig.qml`
- `DashboardConfig.qml`
- `EffectsConfig.qml`
- `BackgroundConfig.qml`
- parts of `DesktopWidgetsConfig.qml`

The largest Hadalis pages are very large even before embedded child pages:

- `DesktopWidgetsConfig.qml` ~252 KB
- `NiriConfig.qml` ~134 KB
- `BackgroundConfig.qml` ~127 KB
- `QuickConfig.qml` ~112 KB
- `InterfaceConfig.qml` ~110 KB
- `ServicesConfig.qml` ~105 KB
- `ThemesConfig.qml` ~86 KB

Already adopted/superseded pieces must remain:

- page-level `SettingsPageHost` LRU
- `NiriConfig` active-section refresh
- `BackgroundConfig` monitor-preview gating
- `DesktopWidgetsConfig` short-residency loader
- asynchronous Control Panel sections
- batched `SettingsSearchRegistry` entry flush

Pilot section residency on one heavy page first, then measure page open latency, RSS and deep-link/search correctness. Do not mass-convert all pages in one patch.

### 13.5 Abyss full-screen field shader has a concrete fragment-cost target — INVESTIGATE / high-value P1

`AbyssPerimeter.qml` mounts one full-output `AbyssField` per screen and `AbyssField.qml` fills the whole PanelWindow.

Current `AbyssField.frag`:

- evaluates the perimeter/hole field
- samples the wave texture four times
- evaluates up to 40 body records through SDF `roundedBox`/smooth fuse logic
- only after all of that does it reject fragments with `if (d > 24.0)`

Thus large interior workspace regions can still pay most of the expensive field evaluation before becoming transparent.

Relevant upstream idea:

- `064c18b4da5279d261d2a3dcc3710c9eb61f0a55` — `perf(organic): reduce screen edge fragment cost`

Do **not** copy the Organic shader. Adapt the technique:

- cheap spatial reachability/AABB rejection before expensive SDF work
- skip records whose expanded bounds cannot affect the current fragment
- avoid corner-distance math outside corner regions
- keep derivatives valid by not placing derivative evaluation behind unsafe divergent control flow

Abyss has different semantics: full-screen perimeter, animated wave displacement, body welds, wallpaper refraction and up to 40 records.

Required evidence before/after:

- GPU utilization/frame time with 0, typical and worst-case body counts
- 1080p/1440p/4K
- fractional scaling
- multi-monitor
- static and animated wave states
- pixel-diff/visual seam checks around welds, corners, shadow/glow and refraction

### 13.6 Clipboard text watcher is missing upstream's no-newline fix — ADAPT / P1 correctness + churn reduction

iNiR migration:

- `042-cliphist-no-synthetic-newline.sh`

adds `wl-paste --no-newline` to the text-history watcher.

Hadalis migration `051-cliphist-single-watchers.sh` correctly deduplicates watcher ownership and routes text through `native-dispatch clipboard-store`, but the canonical command is currently:

`wl-paste --type text --watch ...`

without `--no-newline`.

This matters because both Hadalis implementations intentionally preserve non-HTML plain text byte-for-byte:

- Rust: `native/inir-native/src/clipboard.rs`
- Python fallback: `scripts/clipboard-store.py`

Therefore a newline synthesized by `wl-paste` is not removed later. Re-selecting a history item can accumulate payload differences and defeat cliphist deduplication.

Adaptation should update together:

- default Niri startup config
- legacy dots fallback if still supported
- migration after 051
- `scripts/test-clipboard-watcher-contract.py`
- any documentation showing canonical watcher commands

Do not trim arbitrary copied user text inside Rust/Python. The correct boundary is the watcher option, preserving the existing byte-for-byte payload contract.

### 13.7 Window-preview clipboard pollution migration from upstream is superseded — ALREADY / SUPERSEDED

iNiR migration 038 routes preview screenshots through a preview-aware clipboard filter.

Hadalis already has a more specific capture lifecycle in `scripts/capture-windows.sh`:

- saves the user's clipboard
- hashes generated preview files
- deletes only cliphist entries whose decoded bytes match generated previews
- preserves unrelated user copies made during capture
- restores the prior clipboard only if Niri still owns it with one of the generated screenshots
- bounds the capture lifecycle with timeout
- atomically publishes preview PNGs

Do not replace this with the simpler upstream migration.

### 13.8 Media artwork resolver cache remains a valid small optimization candidate — INVESTIGATE

iNiR has a MediaArtworkCache component:

- 64-entry bounded singleton
- remembers `metadataKey -> {base, source}`
- lets a newly created `MediaArtworkResolver` immediately adopt the last published source instead of repeating file/process resolution behind a placeholder

iNiR's current `MediaArtworkResolver.qml` integrates this cache. Hadalis' resolver does not.

Hadalis currently instantiates `MediaArtworkResolver` from multiple independent surfaces/services, including media controls, bar media, player base, YtMusic card and CavaTheme.

Potential benefit:

- fewer repeated file existence/MIME/stability checks
- less transient placeholder flashing when the same track appears in a newly created surface

Keep it **INVESTIGATE** until process counts/latency show repeated resolver work. If adopted, retain the bounded 64-entry lifecycle and Hadalis' existing cache-busting correctness.

### 13.9 Production native backends are mostly event-driven — ALREADY / good architecture

The Rust workspace was read for polling/lifetime behavior.

Verified:

- `inir-inputd` uses evdev blocking reads plus inotify for hotplug rather than a 5-second device-rescan loop.
- Python input daemons still contain 5-second refresh loops, but they are fallback paths selected only when Rust is unavailable/forced off.
- `inir-mpdd` uses MPD `idle` subscriptions rather than frequent polling.
- the persistent daemon binds lifetime to the shell through parent-death handling.
- Niri helper operations are request-driven.
- theme generation is request-driven.

Do not spend production optimization effort on Python polling unless fallback parity itself is the task.

One native cache to profile later:

- `inir-mpdd::ArtLookup` keeps folder and artwork-key HashMaps for daemon lifetime.
- growth is naturally related to visited library folders/albums but there is no explicit eviction/invalidation policy.

Classification: **INVESTIGATE only if long-session MPD daemon memory grows with library churn.**

### 13.10 RecorderStatus and EasyEffects polling are already stronger than old upstream perf patches — ALREADY / SUPERSEDED

`RecorderStatus.qml` now:

- uses 15s idle polling by default / 30s in low-power mode
- switches to 1s only under explicit fast UI demand
- uses 1s active polling while recording
- uses bounded quick checks after a start/stop action

This is stronger than the old iNiR 5s idle polling optimization.

`services/deferred/EasyEffects.qml` now:

- probes with direct `pgrep -x easyeffects`
- uses demand-aware cadence
- polls slowly when only background active-state verification is needed

Do not re-port older perf commits for either subsystem.

### 13.11 Thumbnail and clipboard model work are already optimized — ALREADY / SUPERSEDED

Verified current Hadalis:

- `ThumbnailImage.qml` no longer spawns one magick/ffmpeg process per delegate; it uses Wallpapers' serialized thumbnail queue.
- already-loaded thumbnails skip regeneration paths.
- ii and Waffle clipboard models update only while their panel is open.
- `Cliphist.qml` caches prepared search/filter data by revision and caps loaded entries.
- unchanged cliphist list reads do not emit a false `entriesChanged`.

Keep these as regression guards.

### 13.12 Nix source filtering remains valid, but runtime-payload code should not be replaced — ADAPT / P2

The previous P2 conclusion is confirmed.

iNiR filters the shell derivation input with `nix/runtime-source-filter.nix`.

Hadalis still uses:

`src = lib.cleanSource ../.;`

for the shell derivation, while native Rust is built separately from `../native`.

However, Hadalis' `sdata/lib/runtime-payload.py` has diverged in useful ways and is not behind upstream. It includes additional installed-tree cleanup and symlink safety logic.

Adapt only the Nix **source filter**, driven by Hadalis' existing runtime manifests/policy. Do not replace the runtime payload implementation.

### 13.13 Niri-owned session environment lifecycle is interesting but not portable wholesale — INVESTIGATE / DO NOT PORT wholesale

iNiR prerelease now starts the service explicitly after `niri.service` and treats Niri/systemd as the authority for:

- `WAYLAND_DISPLAY`
- `NIRI_SOCKET`
- `DISPLAY`

It no longer manufactures those compositor-owned values by scanning runtime/X sockets.

Hadalis still has:

- `wait_for_wayland_socket`
- Wayland socket discovery
- `niri.wayland-*.sock` discovery
- X socket discovery
- systemd environment repair/export logic

Upstream's model is architecturally cleaner for a Niri-only shell, but Hadalis intentionally supports both Niri and Hyprland and its Nix module can wire either compositor.

Classification:

- **DO NOT PORT** the Niri-only service unit wholesale.
- **INVESTIGATE** whether the Niri branch can use authoritative `niri.service` environment resolution first and reserve socket probing only for manual/recovery/Hyprland paths.
- measure startup complexity/reliability before calling this a performance optimization.

---

## 14. Revised priority after audit round 2

### P0 experiments

1. Finish exact Tier 3/4 consumer matrix and benchmark forced-service cost.
2. Benchmark WindowPreview eager prewarming versus lazy/hybrid policy.
3. Only then change `shell.qml` service materialization.

### P1 candidates

1. Reactive GameMode + complete NiriService freshness/focus prerequisite batch.
2. Settings section residency pilot on one large page, then staged rollout.
3. Abyss fragment early-rejection/AABB optimization after GPU baseline.
4. Clipboard `wl-paste --no-newline` watcher contract.
5. Media artwork bounded handoff cache if resolver profiling justifies it.
6. Continue cache audit, with MPD ArtLookup as a low-priority long-session measurement target.

### P2

1. Nix derivation source filter using Hadalis runtime manifests.
2. Niri-specific session-environment simplification only if reliability/startup measurements justify it.

### Updated next concrete task

Before implementation, produce two baselines on current `dev`:

1. **Tier 3/4 startup baseline**
   - child processes from T+0 to T+5s
   - CPU/PSS at T+0.5s, T+1.5s and settled idle
   - whether WindowPreview capture starts and how many windows it captures
   - Weather/Calendar/FontSync/ShellUpdates background actions

2. **Abyss GPU baseline**
   - idle perimeter with no open bodies
   - typical bar+dock
   - one large body
   - many simultaneous records
   - same scenarios at multiple output resolutions/scales

Use those baselines to choose the first code patch rather than modifying several subsystems at once.


---

## 15. Audit round 3 — service lifetime, cache growth and family-capability matrix (2026-09-28)

### Snapshot

- Hadalis audited/refetched head: `7ff6eff1d6bc5f3f17911dd78754cabbc59db2d0`
- iNiR comparison head: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

Concurrent Hadalis work since the previous audit milestone was reconciled before this update. The new commits retire standalone Abyss Wi-Fi/Bluetooth modules in favor of shared system-tray popups and fix the desktop context-menu route into the Abyss layout editor. Those changes do not invalidate the optimization findings below.

### 15.1 Tier 3/4 materialization must be capability-aware, not family-name-aware — REFINED P0

The previous audit correctly identified iNiR's family-aware deferred loading as a useful pattern, but a direct `family !== "iris"` port remains unsafe.

New consumer tracing shows:

- `WindowPreviewService`
  - direct consumers exist in ii/shared bar+dock, Waffle taskview/taskbar/alt-switcher and Overview.
  - Abyss has no direct import, but `AbyssBarModule.qml` reuses `Shared.BarTaskbar`, so Abyss can indirectly require preview support when the taskbar module is placed.
  - current Hadalis intentionally eager-prewarms captures; this is a latency-vs-startup tradeoff, not a dead service.
- `Weather`
  - used by ii/shared bar, Waffle, background widgets, dashboard/sidebar/lock surfaces.
  - Abyss indirectly uses it through `WeatherBar` in `AbyssBarModule.qml`.
  - enabled by default and intentionally starts location/weather work after a 3-second internal delay.
- `VoiceSearch`
  - owns the `voiceSearch` IPC target and feeds OSD/AI/quick-toggle surfaces.
  - removing forced materialization without a router can break external invocation.
- `CavaTheme`
  - owns no IPC.
  - cover-art resolver and quantizer are already internally feature-gated.
  - default color source is theme, so the forced singleton mostly creates reactive palette state until a visualizer consumes it.
  - good candidate for consumer-driven materialization.
- `CalendarSync`
  - owns no IPC.
  - external sync is disabled by default.
  - UI consumers naturally instantiate it when calendar/agenda surfaces are used.
  - good candidate for feature/consumer-driven materialization.
- `FontSyncService`
  - owns no IPC, but `syncWithSystem` defaults to true and the service deliberately reconciles GTK/KDE fonts on each shell start.
  - safe optimization is to skip construction only when system-font sync is disabled; do not lazily defer the enabled path until Settings is opened.
- `ShellUpdates`
  - owns `shellUpdate` IPC.
  - performs update-resume recovery after shell restart and periodic background checks/notifications.
  - keep materialized unless a lightweight IPC/background router is introduced for a measured reason.
- `Autostart`
  - owns `autostart` IPC.
  - watches the Niri startup file for external edits and reflects them into Settings.
  - it is Niri-specific semantically; possible future optimization is to avoid materializing it on non-Niri sessions, but do not simply remove it from Tier 4.
- `GameMode`
  - owns `gamemode` IPC and global rendering/notification policy.
  - keep forced until the reactive Niri/GameMode batch from §13.3 is implemented and validated.

**Implementation rule:** introduce feature/capability predicates (weather enabled, taskbar/preview surfaces enabled, calendar sync enabled, font sync enabled, compositor type) rather than hard-coded ii/Waffle/Abyss exclusions.

### 15.2 Startup contention is now a measurable aggregate hypothesis — BENCHMARK P0

Several services are individually deferred correctly but their internal work still clusters during the first few seconds:

- `WindowPreviewService`: Tier 3 at ~T+500ms, may immediately begin capture/predecode.
- `ConflictKiller`: delayed conflict probe at ~1.5s after Config readiness.
- system `Updates`: commonly materialized by normal UI and schedules its first `checkupdates` at +1.5s.
- `FontSyncService`: Tier 4 construction followed by a 500ms sync debounce when enabled.
- `Weather`: Tier 3 construction followed by its own 3s startup delay when enabled.
- `ShellUpdates`: Tier 4 construction followed by a 5s update-check delay.

No single timer is obviously wrong. The risk is cumulative process, filesystem and network contention during startup.

Extend the Tier 3/4 baseline to record a process timeline from T+0 to T+8s, including:

- preview capture helpers
- `checkupdates`
- font-sync helper
- weather curl/geocoder calls
- shell update git processes
- conflict probe

Only stagger or conditionally suppress work when the timeline shows real overlap/cost.

### 15.3 Session/lock/Waffle hidden-surface concerns were mostly false positives — CLOSED / ALREADY

A visual scan initially suggested several hidden trees might remain resident, but the outer family loaders change the conclusion.

Verified:

- ii/Waffle `SessionScreen` is wrapped in an outer `OnDemandPanelLoader`; the whole component is released after close grace.
- Waffle notification center is also wrapped in an outer `OnDemandPanelLoader`; critical-dot infinite animations therefore do not remain a permanent idle cost after the center closes.
- ii/Waffle lock surfaces are created only while `GlobalStates.screenLocked`.
- lock wallpaper images use `cache: false`; animated/video playback is gated by lock visibility/state.
- Cheatsheet destroys at the outer on-demand boundary when closed. It does instantiate both of its two pages while open, but that is an in-panel cost, not an idle-session leak.
- notification popups use 450ms residency grace and destroy after popup history leaves the popup list.

Do not optimize these by adding another nested unload layer unless profiling proves an in-use cost.

### 15.4 Shared CAVA architecture is already stronger than the upstream historical perf patches — SUPERSEDED

Hadalis now has one shared `CavaService`:

- consumers hold `ServiceLease` subscriptions
- one CAVA subprocess serves all visualizers
- teardown is debounced by 800ms
- bar spectrum rendering uses scene-graph primitives rather than a hot Canvas path
- main consumers gate leases by panel visibility, playback, widget power state and/or effects state

Checked consumers include:

- lock media
- Control Panel media
- Media Controls
- sidebar media/YT Music
- local music
- bar spectrum
- background visualizer/media widgets

No unconditional idle CAVA subscriber was found in this pass.

Classification: **ALREADY / SUPERSEDED**. Preserve lifecycle tests as regression guards.

### 15.5 Niri and desktop-widget power optimizations are already incorporated and extended — SUPERSEDED

Relevant historical iNiR ideas are already present in Hadalis:

- noncritical Niri events are skipped during GameMode while preserving the extra event types needed for fullscreen correctness
- Niri window-list publishing is throttled with a normal/GameMode cadence
- window ordering has a separate signal to avoid rebuilds on title-only churn
- WidgetPowerManager exists and is output-aware
- WidgetSurface releases blur/FBO work when hidden or power-suspended
- SineCookie/rotating widget animation respects widget power state

Do not re-port older commits such as `d85e23a4b7` or `a69031cb4f` wholesale.

### 15.6 LatexRenderer has an unbounded in-session result registry — LOCAL CACHE DEBT / P2, raise if reproduced

`services/deferred/LatexRenderer.qml` keeps:

- `processedHashes`
- `processedExpressions`
- `renderedImagePaths`

for every unique expression rendered in the session.

Successful entries are never evicted. The generated SVGs are hash-addressed under the LaTeX output directory and this service has no cleanup policy.

The service is deferred, so this is not a startup problem. It becomes relevant for long AI/chat sessions with many unique formulas.

Upstream currently has the same basic unbounded design, so this is **not a port gap**.

Preferred fix if profiling/reproduction justifies it:

- bounded LRU for in-memory registries
- retain completed disk cache independently from in-memory residency
- never evict an in-flight hash
- avoid reintroducing duplicate render races
- add a long-session test with many unique formulas

### 15.7 Notification history is unbounded and rewrites the whole JSON history — LOCAL LONG-SESSION DEBT / P1-P2

`Notifications.qml` correctly destroys popup timers and discarded notification QObjects, but the persisted history list has no count/age cap.

For every received notification:

- a wrapper QObject is appended to `root.list`
- the entire list is serialized
- the full JSON file is rewritten

Timed-out popups remain in history by design.

Consequences in very long sessions or noisy environments:

- resident QObject count grows with history
- grouping/search work grows with history
- each persistence write becomes larger
- startup reload grows with the persisted file

Current iNiR prerelease has the same debt, so this is also **not an upstream port candidate**.

If addressed, prefer a configurable bounded history policy (count and/or age) that:

- never drops active popup state unexpectedly
- destroys evicted Notif/timer objects
- preserves critical/unread semantics as defined by product behavior
- compacts persisted JSON in the same transaction
- has migration/backward compatibility for existing history files

### 15.8 MPRIS player grace map is tiny but unbounded — P2 cache hygiene

`MprisController._playerGrace` stores `dbusName -> timestamp` entries to bridge metadata gaps during track transitions.

No removal was found when a player disappears.

The retained value is tiny, so this is not a current hot-path issue. Long-running browser/media sessions with many unique MPRIS instance names can still grow the map indefinitely.

Low-risk future cleanup:

- delete the player's grace entry on delegate destruction/player removal
- optionally prune timestamps older than the grace window during rebuild

Do not prioritize ahead of startup, Settings, Abyss shader or notification-history work.

### 15.9 Small-service audit: mostly event-driven / one-shot — CLOSED

This pass also checked smaller singleton/deferred services.

Verified:

- `BluetoothStatus`: Quickshell Bluetooth signals; no polling process.
- `DeviceStatePersistence`: event-driven state tracking; restore timers are one-shot timeouts.
- `TaskbarApps`: short debounce on compositor/AppSearch changes, not a repeating poller.
- `AppCatalog`: 5s timer is a one-shot refresh after install/remove operations, not a permanent 5s poll.
- `DankSocket`: exponential reconnect timer only while a requested socket connection is down.
- `SessionWarnings`: process checks only when `refresh()` is requested.
- `KeyringStorage`, `SongRec`, `Ydotool`: demand-driven.
- `Updates`: upstream also polls system package updates periodically; Hadalis improves startup by using `checkupdates` itself as the availability probe instead of spawning a separate `which` helper.
- `KeyboardIndicators`: prefers event-driven evdev/file watches; LED discovery polling is fallback discovery and backs off when stable.
- `Brightness`: the 5s/30s timers observed in the file are helper timeouts, not permanent polling loops.

No new P0 issue was found in this group.

---

## 16. Revised priority after audit round 3

### P0

1. Capture a real T+0..T+8 startup process/CPU/PSS timeline.
2. Benchmark eager WindowPreview prewarm vs consumer-lazy vs hybrid idle-prewarm.
3. Use the measurements to implement capability-aware Tier 3/4 materialization.
4. Keep GameMode, IPC owners and enabled startup-reconciliation services resident until equivalent semantics are proven.

### P1

1. Reactive GameMode + Niri freshness/focus prerequisite batch.
2. Settings section-residency pilot and staged rollout.
3. Abyss field shader early rejection / record AABB skip.
4. Clipboard watcher `wl-paste --no-newline`.
5. Bound notification history if long-session reproduction confirms growth is material.
6. Media artwork resolver handoff cache only if resolver profiling shows repeated work.

### P2

1. Nix source filtering.
2. LatexRenderer bounded in-memory registry.
3. MPRIS grace-map cleanup.
4. MPD artwork/folder-cache long-session profiling.
5. Niri-specific session-environment simplification only after reliability measurements.

### Next concrete task

The audit is now broad enough to stop expanding by file count and move to evidence-driven implementation.

Preferred next step:

1. run the startup baseline on current `dev`
2. choose **one** of:
   - WindowPreview prewarm policy
   - capability-aware Tier 3/4 materialization
   - Settings section residency
   - Abyss shader early rejection
3. implement one batch
4. run its focused regression tests
5. update this handoff with before/after evidence and the new exact Hadalis SHA

Avoid bundling multiple optimization classes into one patch.


---

## 17. First adopted cross-repo fix — clipboard text payload preservation (2026-09-28)

### Status: ADOPTED / STATICALLY VERIFIED

Hadalis adapted iNiR's no-synthetic-newline clipboard watcher fix at the correct boundary: `wl-paste`.

Relevant upstream reference:

- iNiR migration `042-cliphist-no-synthetic-newline.sh`

Hadalis implementation commits:

- `2c22d37e3abe5a16696980364e74764503dae5ba` — default Niri startup watcher
- `d88dd9606a56fee183eb101b7ef89c582cc0c3a6` — monolithic/legacy Niri fallback
- `ec1e50b345f2f1dc4627860a4a5ae16c96fece20` — migration 051 canonical watcher updated
- `a436b0f9abc28b11ffe76687d85f2a70e08941aa` — autostart documentation
- `beac1348f1dc02481811de83df32175d9b99cbdc` — new migration 054
- `70514f92bd4781d9f53a2fa1bb55714fc8f52206` — regression contract expansion
- `c2aa9eae6307ee5cb57d54aedca57c0da6073fe3` — migration 054 executable mode

The current `dev` head at the last pre-handoff reconciliation was `283f4431412d7ec55d42a45988e9dd5ccccbecff`, which contains the clipboard patch. The intervening commits after `c2aa9eae` were documentation-only connectivity-ownership updates.

### What changed

Canonical text watcher is now:

`exec wl-paste --no-newline --type text --watch ~/.config/quickshell/inir/scripts/native-dispatch clipboard-store`

Updated together:

- `defaults/niri/config.d/50-startup.kdl`
- `dots/.config/niri/config.kdl`
- `sdata/migrations/051-cliphist-single-watchers.sh`
- `docs/AUTOSTART.md`

New migration:

- `sdata/migrations/054-cliphist-no-synthetic-newline.sh`

Migration 054:

- upgrades already-migrated users whose watcher was installed before this fix
- checks both split Niri startup config and the legacy monolithic fallback
- ignores commented/disabled watcher lines
- accepts active `--type text` and `--type text/plain` forms
- inserts `--no-newline` only at the `wl-paste` boundary
- records session impact because the existing long-running watcher keeps its old argv until the next login
- is executable (`100755`)

### Native/fallback contract

No Rust or Python clipboard payload transformation was changed.

Specifically, this fix intentionally does **not** trim data inside:

- Rust clipboard-store path under `native/inir-native`
- `scripts/clipboard-store.py`

Both paths should continue to preserve the payload they receive. The synthetic byte is prevented where it is introduced by `wl-paste`.

### Regression coverage

`scripts/test-clipboard-watcher-contract.py` now covers:

- canonical default watcher
- canonical legacy/dots watcher
- migration 051 duplicate cleanup still producing exactly one text + one image watcher
- migration 054 upgrade from the old text watcher
- migration 054 on the monolithic fallback
- deliberately disabled clipboard history remaining disabled

The canonical maintainer validator automatically discovers every tracked `test-*.py` through its regression glob, so this test is part of the normal CI lane even though its filename is not hard-coded in `validate-maintainer-local.sh`.

Verification completed in this audit session:

- refetched all affected files from `dev`
- confirmed the old canonical command is absent from default and legacy configs
- confirmed the new command is present in default, legacy and migration 051
- confirmed migration 054 metadata/session-impact contract
- confirmed migration 054 mode is `100755`
- reviewed the expanded Python regression source for structural/syntax consistency

CI note:

- runs directly attached to the clipboard commits were cancelled by newer rapid pushes because CI uses `cancel-in-progress: true`
- a later CI run on a descendant containing this patch was also superseded while validation was executing
- therefore this handoff does **not** claim a completed runtime CI pass yet

Classification remains **ADOPTED / STATICALLY VERIFIED** until a non-cancelled canonical validator run completes on a descendant containing the patch.

### User/session impact

Existing sessions keep the old `wl-paste` process arguments until Niri starts the watcher again.

After migration 054 applies, log out and back in before judging duplicate/newline behavior.

Existing cliphist entries are intentionally left untouched.

### Priority update

Remove the clipboard no-newline item from P1 pending work.

Next evidence-driven optimization remains:

1. startup process/CPU/PSS baseline
2. WindowPreview eager-vs-lazy/hybrid prewarm experiment
3. capability-aware Tier 3/4 materialization based on those measurements

Do not bundle these three into one patch.


---

## 18. Audit round 4 — upstream archaeology, service coverage and concurrent startup adoption (2026-09-28)

### Snapshot

- Hadalis head reconciled before this update: `4203be378b1a9e7b9fbcc80b5ca047130d5c98cc`
- iNiR comparison head remains: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

Concurrent work after the round-3 snapshot was reconciled before this update. The intervening Abyss work is focused on IPC indicator geometry/editor behavior and does not invalidate the service/runtime conclusions below.

### 18.1 Capability-aware deferred service materialization has started landing — ADOPTED / STATIC CONTRACT PRESENT

The P0 consumer-matrix work from §15.1 has already produced a first implementation batch on `dev`:

- `243776e9b3f06e9ab1fec8a581a14225e99ea6bd` — `perf(startup): gate optional deferred services`
- `ed731e901a5583d5a69949d89390c21ac76850cf` — `test(startup): guard deferred service materialization`
- `f87ddf96de9afc79f6cd7a583abd8ced91f80df8` — `fix(startup): preserve enabled CAVA theme lifecycle`
- `30887f08ab1caa3bdfbf1ef786ab92dee65fa0b2` — `test(startup): guard enabled CAVA theme lifecycle`

Current behavior:

- `Weather` is shell-forced only when the weather feature is enabled.
- `CalendarSync` is shell-forced only when external sync is enabled.
- `FontSyncService` preserves its startup reconciliation when `syncWithSystem` is enabled, but is not materialized for users who disable that feature.
- `CavaTheme` is not globally forced for ordinary palette consumers, but remains resident when the explicit external CAVA wallpaper-theming side effect is enabled.
- `Todo` and `Notepad` are no longer force-read/watched by Tier 4; their real consumers instantiate them.
- `GameMode`, `WindowPreviewService`, `VoiceSearch`, `ShellUpdates` and `Autostart` remain eager for the previously documented policy/IPC/latency reasons.
- config changes re-run the feature ensure helpers so enabling a feature after startup still materializes its service.

Regression guard:

- `scripts/test-deferred-service-materialization-contract.py`

Important validation status:

- Nix package workflow is green on the current descendant `4ca071d729...` that contains this patch.
- the current descendant has failing canonical static/regression, packaging-contract and documentation-contract workflows.
- this audit could identify the failing workflow steps but not retrieve their complete Actions logs through the connector, so it does **not** attribute those failures to the startup patch.
- therefore classify this batch as **ADOPTED / STATIC CONTRACT PRESENT / FULL GREEN CI PENDING**, not fully validated.

Do not reimplement this batch. The remaining P0 question is measurement: whether further materialization changes or startup staggering produce a real before/after win.

### 18.2 Startup work should now be measured as a timeline, not optimized from timer names — P0 BENCHMARK

The new feature gating removes some unconditional singleton construction, but enabled services still intentionally cluster work in the first seconds.

The next startup experiment should record T+0..T+8 with:

- process start/exit timeline
- CPU and PSS samples
- WindowPreview capture/predecode count
- `checkupdates`
- font synchronization
- Weather network/geolocation work
- ShellUpdates git work
- ConflictKiller probe
- native backend daemon/subscription state

The audit found several timers that looked suspicious by static search but are actually one-shot timeouts, debounce timers or sparse safety checks. Do not optimize by interval value alone.

Examples already classified as low/no concern:

- `Brightness`: 5s/30s helper timeouts, not permanent polling.
- `KeyboardIndicators`: event-driven evdev/FileView path; periodic LED discovery is fallback and backs off.
- `TlpSettingsService` and `TlpRuntimeCapabilities`: 30-minute safety refresh after the feature is materialized.
- `PowerProfilePersistence`: 30-minute tlp-pd ownership safety probe plus event-driven stale re-probe.
- `ThinkFanService`: intentional profile-follow service, 30s active / 5-minute idle safety cadence.
- `MemoryPressureService`: 5-minute in-process `/proc/self/maps` read; no shell/grep subprocess.
- `LocalMusic`: Rust MPD subscription is primary; fallback status poll is 30s when closed and 900ms only while the sidebar is open.

### 18.3 ShellExec transient service optimization is intentionally NOT portable to Hadalis — DO NOT PORT

Relevant iNiR optimization:

- `51a5fb01eabe` — `perf(processes): detach launched apps from shell service`

That upstream commit changed app launch from `systemd-run --scope` to a transient service with `Type=exec`.

Hadalis **did adopt that commit historically**, then intentionally reverted the launch model:

- `bd27609c299c` — `fix(launcher): run apps in a transient scope instead of a service`

Reason recorded in Hadalis history:

- launchers such as Zed/VS Code can fork the real process and let the initial launcher exit
- a transient service can treat that first process exit as unit completion and kill the remaining cgroup
- a scope remains alive as long as processes remain in it

Later Hadalis commits also added live session/input-method/environment reconstruction around this scope launch path.

Therefore:

- do not re-port upstream `Type=exec` merely for process accounting
- if shell-cgroup helper retention is measured as a real problem, solve it without regressing fork-and-exit launchers
- any alternative must test at least VS Code/Zed/Electron, Steam/Wine/X11, native Wayland and working-directory launches

This is a concrete example where the newer upstream perf shape is not automatically correct for Hadalis.

### 18.4 Recent upstream perf commits rechecked — mostly already incorporated/superseded

The following upstream optimizations were explicitly compared against current Hadalis and are already present or superseded:

- `6997f63d6ae4` — frozen video backdrop uses cached representative frame and releases FFmpeg when animation is disabled.
- `d223b485762c` — AI message QObjects are destroyed on remove/clear.
- `8e64f872c03a` — Hotspot/WARP 5s status polling runs only while the relevant quick-toggle panel is visible.
- `4c57f0f6578f` — no per-stripe `Behavior on color` remains in `ZzzDiagonalPattern`.
- `a001976bd948` — `SidebarHost` has bounded idle content residency/unload.
- `224df59789ef` / `93d8dc5db833` / `81c36be2e38b` — inactive panel/visual branches are bounded or unloaded, no-visual AltSwitcher routing exists, and icon caches are bounded.
- the QSG atlas reduction to 1024×1024 is already applied in the launcher.
- `6f62221556a4` — Control Panel heavy sections already use asynchronous Loader incubation.
- `c6da2a5312a1`, `841f7ffdebeb`, `9a1b509e5207` — Settings page incubation, loading overlay and page LRU infrastructure are already present.
- AI/YT Music current-state review did not reveal a new unbounded transient-QObject leak; YT Music caps recent/liked/search collections and AI destroys replaced/cleared message/model objects.

Do not reopen these as port tasks unless a new regression is reproduced.

### 18.5 Settings gap is now narrowed to section-level adoption, not infrastructure — P1

The Settings infrastructure itself is current.

The remaining opportunity is to apply short-residency asynchronous section loading to measured heavy pages that still instantiate all section trees and merely hide inactive ones.

Keep the rollout rule from §13.4:

1. pick one page with a measured construction/RSS cost
2. preserve static search/deep-link/focus contracts
3. use short residency to avoid back/forward churn
4. benchmark before/after
5. only then expand to additional pages

Do not add another page-cache layer; `SettingsPageHost` already owns that concern.

### 18.6 Additional long-session cache review — low-priority local hygiene

No new P0 leak was found, but two small Hadalis-local growth patterns are worth recording:

- `Wallpapers.videoFirstFrames` and `_knownThumbnailOutputs` are string maps that can grow with the number of distinct video wallpapers/thumbnails touched during a session.
  - this is bounded naturally by the user's wallpaper library/use, not by time
  - values are small path strings, not decoded image QObjects
  - classify **P2 / measure only for very large wallpaper libraries**
- TLP Settings/Runtime capability singletons continue sparse 30-minute safety refreshes after first materialization.
  - classify **intentional low-frequency consistency behavior**
  - do not add unload complexity without evidence

The earlier higher-value local long-session debts remain:

- notification history growth
- LatexRenderer in-memory registries
- MPRIS grace-map cleanup
- MPD artwork/folder cache measurement

### 18.7 Coverage conclusion after round 4

At this point the audit has read or structurally classified every major runtime subsystem and the remaining large service files have been sampled specifically for:

- repeating timers
- subprocess lifetime
- file watchers
- network requests
- cache growth
- QObject creation/destruction
- feature/visibility demand gating
- native Rust vs Python fallback ownership

Further value is now much higher from runtime measurement than from continuing a blind line-count sweep.

### Revised next task

1. obtain a green canonical validation baseline on a descendant containing the startup/clipboard patches, or identify the unrelated failing contract first
2. capture the T+0..T+8 startup process/CPU/PSS timeline
3. benchmark WindowPreview eager vs lazy/hybrid prewarm
4. choose one measured implementation batch:
   - WindowPreview policy
   - one Settings section-residency pilot
   - reactive GameMode/Niri correctness batch
   - Abyss shader optimization after the current Abyss visual work stabilizes

Do not combine these optimization classes in one patch.


---

## 19. Audit round 5 — large visual modules and script hot-path review (2026-09-28)

### Snapshot

- Hadalis head before this checkpoint: `8a5dca1add43bf9c57a8b34e37cd71f785149e6d`
- iNiR comparison head: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

This pass moved beyond singleton/service inventory into the largest visual modules and the scripts they invoke. The focus was not file size by itself, but whether hidden/resident QML can keep decoders, CAVA consumers, Canvas repaint loops or helper processes alive.

### 19.1 WallpaperSkewView eagerly analyzes the entire uncached folder — INVESTIGATE / P1

Current `modules/wallpaperSelector/WallpaperSkewView.qml` loads a persistent color DB and immediately calls `_analyzeUncachedColors()`.

That function:

- scans every non-directory entry in the current wallpaper folder
- skips videos but queues every uncached image/GIF
- runs ImageMagick `convert ... -resize 1x1 -colorspace HSL`
- batches 20 files into one shell process, then immediately runs the next batch until the queue is empty
- is triggered on cache load/failure, component completion, folder changes and count changes

This happens even when the user never selects color sorting or a color filter.

Current iNiR prerelease has the same eager behavior, so this is a **shared debt**, not an upstream port gap.

Potential adaptation:

1. load the existing color cache immediately
2. only analyze missing colors when color sort/filter is requested
3. optionally precompute a small visible/current neighbourhood during idle instead of the whole folder
4. stop/clear queued work when the view is destroyed or switches folder
5. benchmark large folders before deciding whether background idle prefill is worthwhile

Correctness issue discovered at the same boundary:

- the color DB is keyed by `fileName`, not normalized full path/content identity
- two folders containing the same filename can reuse the wrong color metadata
- replacing an image in place with the same filename can leave stale color metadata

If this path is changed, use a stable path-aware key and consider mtime/content invalidation. Do not add a second unbounded cache.

### 19.2 Equalizer Canvas has redundant fixed-rate repaint demand — ADAPT / P1-low-risk

`modules/mediaControls/EqualizerPanel.qml` already has event-driven repaint sources:

- CAVA `pointsChanged`
- CAVA normalization-ceiling changes
- DSP band changes
- width/height/visibility changes
- band-drag preview changes
- preset sweep animation property changes
- lightning/highlight animation property changes

Despite that, the analyzer Canvas also contains:

`Timer { interval: 33; running: root.active && analyzerCanvas.visible; repeat: true; onTriggered: analyzerCanvas.requestPaint() }`

The shared CAVA service is configured around 30 FPS and emits `pointsChanged` only when frame values actually change. Therefore the fixed timer:

- duplicates repaint requests while spectrum frames are changing
- forces Canvas repaint wakeups even when CAVA is producing stable/silent values
- redraws the response curve even when no DSP/animation property changed

This Equalizer implementation is Hadalis-specific; current upstream Equalizer uses a different module structure and does not provide a directly portable fix.

Safe experiment:

1. remove the fixed 33ms repaint timer
2. retain all existing event-driven `requestPaint()` paths
3. verify spectrum motion at configured CAVA framerates
4. verify silence/paused audio settles without stale graphics
5. verify band drag, preset sweep and lightning animations still repaint smoothly
6. measure render-thread/CPU while the Equalizer is open

### 19.3 Compact sidebar can keep Equalizer/CAVA demand alive for the whole open panel — INVESTIGATE / P1

The compact right sidebar instantiates the Media section as part of its Controls content and currently binds:

`EqualizerPanel.active: root.panelVisible`

Consequences:

- opening the compact right sidebar registers an EqualizerService consumer even if the user is not looking at the Media row
- `CavaProcess.active` follows `EqualizerPanel.active`, so the shared CAVA process can be kept alive for the whole sidebar-open lifetime
- the Canvas timer itself is visibility-gated, but service/CAVA demand is broader than the actual media viewport

Do not blindly bind this to QML `visible`: a Flickable child can remain `visible === true` while outside the viewport.

Possible fix requires a real presentation/viewport demand signal, or a narrower Loader around the Equalizer section. Measure whether opening Compact sidebar alone starts CAVA before changing the layout.

### 19.4 CustomImageWidget pauses media but retains decoder/source while power-suspended — INVESTIGATE / P1 memory/GPU

`CustomImageWidget` already does several things correctly:

- rotation timer stops when `powerActive=false`
- GIF `playing` is gated by power/visibility/animations
- video playback pauses under power suspension
- stale transition slot sources are cleared
- static images use bounded decode size and `cache:false`
- Hadalis improved upstream by constructing `MediaPlayer` only for slots that actually own video

However, when `WidgetPowerManager` suspends a widget for GameMode/fullscreen/output-disabled state:

- `AnimatedImage.source` remains assigned
- video `MediaPlayer` Loader remains active because it is keyed only to `slot.isVideo && sourcePath.length > 0`
- the decoder is paused but retained

`WidgetPowerManager` explicitly exists to pause expensive desktop-widget operations while the desktop is covered. This makes decoder release a valid memory/GPU experiment.

Do not clear media merely because the user manually pauses it; manual pause still displays the widget.

A safe design would distinguish:

- **user pause while desktop visible**: retain decoded frame/source
- **power suspension because desktop is covered/output disabled**: release heavy decoder/source, then reconstruct on resume

For video, consider retaining a cheap representative frame if resume/first-frame black flash becomes visible. Benchmark reopen latency and decoder memory before adopting.

### 19.5 Config write path is a profile target, not yet a bug — INVESTIGATE / P2

`modules/common/Config.qml` is startup-critical and correctly coalesces writes with a 50ms debounce.

Static review found no polling loop, but every write can still involve:

- custom-widget data cloning through JSON stringify/parse
- full mirror JSON serialization
- adapter write/reload coordination
- a config-wide `revision` / `configChanged` fan-out

This may become noticeable when:

- config is large
- custom desktop-widget data is large
- a Settings slider emits writes repeatedly while dragged

Current evidence is insufficient to change the global debounce or write semantics.

Before modifying Config:

- measure serialized config size
- measure write duration and UI frame time while dragging representative sliders
- count `configChanged` fan-out
- test external file edits and write-flight recovery

Do not trade correctness/external-edit preservation for a speculative micro-optimization.

### 19.6 Script hot-path review — Python fallback is not the main issue

The large script inventory was checked for frequently invoked production paths.

Verified:

- Equalizer apply helper launches Python only on committed slider release/preset apply, not on every slider movement.
- `least_busy_region.py` / OpenCV runs only for explicit auto-placement or opt-in position color adaptation; it is not a periodic background loop.
- LocalMusic production state follows the Rust MPD subscription path; Python polling remains fallback.
- theme generation continues to route through the Rust native dispatcher; Python theme generation is fallback.
- large color/editor/SDDM generators are one-shot theme/setup work, not idle shell loops.

Therefore keep the native policy from §9: do not rewrite one-shot Python helpers into Rust unless profiling shows a user-visible hot path.

### 19.7 Visual module sweep — no new leak in several large surfaces

The following large paths were checked and did not reveal a new higher-priority lifecycle issue:

- YtMusic view: infinite sync rotation is gated by sync state + left-sidebar open; ListViews reuse items.
- Wallpaper coverflow/gallery: view Loader is destroyed after close grace; image decode sizes are bounded.
- AbstractBackgroundWidget: expensive placement/color helpers are debounce/on-demand, not repeating background work.
- RegionSelection: screenshot image source is cleared with visibility and `cache:false`; heavy mask exists only while the overlay is active.
- CompactMediaPlayer: artwork effects are gated by sidebar open/visibility.
- SystemMonitorWidget: resource demand follows widget power/visibility.
- CAVA common widgets: shared-process lease architecture remains the correct baseline.

### Revised priority additions

Add to P1 investigation queue:

1. WallpaperSkew demand-driven/path-safe color analysis
2. Equalizer event-driven Canvas repaint
3. Compact sidebar Equalizer/CAVA presentation demand
4. CustomImageWidget decoder release under widget power suspension

These should come **after** the current P0 startup baseline unless a profiler immediately identifies one as dominant.

### Next coverage target

Continue with:

- remaining large wallpaper/dashboard/sidebar visual files
- common Canvas/Shape widgets for hidden infinite animation/repaint
- script entrypoints invoked by user interactions rather than setup/theme one-shots
- then switch from static audit to runtime measurement, because the remaining static candidates are increasingly workload-dependent.


---

## 20. Audit round 6 — Canvas/Shape closure, delegate process churn and static-coverage stop rule (2026-09-28)

### Snapshot

- Hadalis head reconciled before this checkpoint: `c52e5c4bf063d59978ee1641b3f7026d73bd0f66`
- iNiR comparison head remains: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

Concurrent work between the previous audit snapshots and this checkpoint was reconciled before writing this section. It included Abyss refinement plus the already-recorded startup/clipboard optimization work; those changes are not reclassified here.

### 20.1 Common Canvas/Shape sweep found no new high-priority hidden repaint loop — CLOSED / ALREADY

The remaining Canvas/Shape-heavy common widgets were checked for:

- fixed-rate repaint timers
- infinite animations
- ancestor/window visibility gating
- CAVA-driven repaint cadence
- repaint on property changes versus repaint every frame

Verified examples:

- `WavyLine.qml` paints the waveform once and animates the cached Canvas texture in X. Its infinite animation is gated by `root.animate`, item visibility, window visibility and nonzero geometry.
- `CavaWavyLine.qml` repaints only on CAVA point changes while visible.
- `StatusRings.qml` repaints only when progress/color values change.
- `WeatherPopupContent.qml` updates its local clock every 30 seconds only while the popup has visible geometry.
- `DotGridCanvas`, `Graph`, `ShapeCanvas` and connected-surface Canvas helpers are property/event driven rather than timer driven.
- `SineCookie.qml` constructs `FrameAnimation` only when `constantlyRotate && WidgetPowerManager.widgetsActive`. The current Cookie clock path performs its normal face rotation outside that component and does not accidentally start a second always-on SineCookie frame loop.

The Equalizer fixed 33 ms Canvas timer from §19.2 remains the meaningful repaint candidate. Do not create a broad “replace Canvas” task from this sweep.

### 20.2 Favicon delegates spawn a shell process even on disk-cache hits — SHARED DEBT / P1-low to P2

`modules/common/widgets/Favicon.qml` is currently byte-identical between Hadalis and iNiR prerelease.

Every Favicon instance does this on `Component.onCompleted`:

1. constructs a `Process`
2. starts `/usr/bin/bash -c`
3. checks `[ -f <cached favicon> ]`
4. only if missing, invokes curl

Therefore the persistent disk cache avoids network traffic but **does not avoid process creation**.

Favicon is instantiated from delegate-heavy/user-churn paths including:

- Overview/Search URL results
- Clipboard URL entries
- AI citation/source buttons
- media/browser metadata paths
- Wallhaven/plugins surfaces

A recycled/recreated delegate for an already-cached domain can still pay a shell-process launch merely to prove that the file exists.

This is not yet a P0 issue. Measure it under workloads with many URL-bearing clipboard/search/AI items.

Preferred design direction if the process count is material:

- centralize favicon resolution/download ownership in a bounded singleton/service, or
- maintain an in-memory known-good/known-missing domain state for the shell session, backed by the existing disk cache,
- coalesce concurrent requests for the same domain,
- keep failed-download retry semantics bounded so a bad domain does not become a permanent poisoned cache entry.

Do not replace the current `curl -f --remove-on-error` correctness fix with a simpler downloader that caches HTML error pages.

Secondary micro-cost:

- every Favicon also enables an `OpacityMask` layer.
- the images are small, so do not optimize this before process churn is measured.

### 20.3 Large dashboard/sidebar/background follow-up did not reveal another unconditional hot loop — CLOSED

Additional large visual paths were structurally checked after round 5.

Verified:

- Dashboard card content uses visibility-driven Loaders rather than a new periodic worker.
- Screen Time and weather detail refresh through service/event paths rather than a local high-frequency loop.
- Sidebar media position refresh is gated by sidebar-open + window-visible + actively-playing.
- Quick Wallpaper scans when its sidebar content is constructed/opened; thumbnail delegates use bounded decode sizes and their mask layer is gated by the open sidebar.
- CAVA consumers remain presentation/playback/power gated.
- lock/notification/OSD paths retain their existing bounded residency behavior already recorded in earlier rounds.

No new higher-priority visual lifecycle leak was found here.

### 20.4 Long-session debt review remains valid; notification history is the strongest static candidate

The previous classifications were rechecked rather than duplicated:

- notification history remains unbounded and serializes/rewrites the full JSON history on ingress/removal
- LatexRenderer keeps expression/path registries for the shell lifetime and leaves rendered SVG output for reuse
- MPRIS grace entries are tiny but stale names are not explicitly pruned
- Rust MPD artwork/folder lookup maps have no explicit eviction but are naturally tied to visited music folders/art keys

Of these, notification history has the clearest scaling behavior because growth increases:

- live QML wrapper count
- group rebuild work
- JSON serialization work
- persistence write size

If runtime long-session testing shows meaningful growth, prefer a user-visible history cap plus debounced/coalesced persistence rather than only optimizing the JSON loop.

### 20.5 Static-audit stop rule

After rounds 1–6, every major runtime subsystem has now been either:

- read in depth,
- structurally classified for timers/processes/cache/lifetime, or
- compared against the relevant upstream perf/fix history.

Continuing a blind line-by-line sweep has diminishing value. Remaining candidates are increasingly workload dependent.

From this checkpoint, static reading should be triggered by runtime evidence or by a concrete subsystem change.

### Revised next task

Move to runtime measurement on a current descendant:

1. capture T+0..T+8 process/CPU/PSS timeline after the adopted startup gating
2. record exactly which deferred services/processes appear at T+0.5/T+1.5/T+3/T+5
3. benchmark WindowPreview eager prewarm versus lazy/hybrid policy
4. capture idle/open-panel CPU for:
   - Equalizer open and silent
   - compact sidebar open with Media section outside/inside viewport
   - notification history at small and large history sizes
   - URL-heavy clipboard/search list to count favicon helper process launches
5. capture GPU/frame-time baseline for Abyss only after the current visual refinement work stabilizes

Choose one implementation batch from measured evidence. Do not combine startup, Equalizer, notification-history, favicon and Abyss changes in one patch.


---

## 21. Audit round 7 — migrations, setup, packaging and non-QML cross-repo deltas (2026-09-28)

### Snapshot

- Hadalis head before this checkpoint: `33fa5695e66fe1967ce254d9d8134f3a67585313`
- iNiR comparison head: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

This pass compared repository areas outside the main QML/service runtime:

- migration inventories
- distro setup/dependency installers
- systemd/session environment policy
- runtime payload/install contracts
- Nix packaging
- upstream-only helper scripts that might represent a missing performance pattern

### 21.1 Setup/install precompiled-package optimization is already incorporated — SUPERSEDED

Relevant historical iNiR optimization:

- `f14c004cbc` — `perf(setup): use official repo packages instead of AUR compilation`

Current Hadalis Arch installer already:

- prefers official repo `quickshell`
- installs official `niri`, `cliphist`, `gum`, `xwayland-satellite` and related runtime packages
- detects/replaces conflicting `quickshell-git` / `quickshell-bin`
- resolves PKGBUILD dependency arrays through `pacman -T`
- installs only missing dependencies rather than blindly reinstalling every dependency
- falls back to the AUR helper only for dependencies not available through pacman

Do not reopen the old AUR-compilation optimization as a port task.

### 21.2 Runtime payload policy is not behind upstream; source filtering remains the packaging gap — RECONFIRMED P2

iNiR has a dedicated `scripts/test-runtime-payload.py` suite.

Hadalis does not have that exact filename, but equivalent delivery-boundary coverage is distributed across:

- `scripts/test-local-distribution.sh`
- `scripts/test-runtime-orphan-cleanup.sh`
- `scripts/test-update-lifecycle.sh`
- `scripts/test-packaging-contract.sh`
- `scripts/test-nix-module-contract.sh`

Current Hadalis tests validate canonical payload manifests, excluded tooling, make-install behavior, update/orphan cleanup and installed paths.

Therefore the remaining packaging optimization is still the previously recorded one:

- adapt `nix/runtime-source-filter.nix`-style derivation input filtering to Hadalis' existing runtime manifests

Do not replace Hadalis' stronger runtime-payload implementation merely to match upstream test/file layout.

### 21.3 Upstream USB snapshot helper is not a Hadalis optimization gap — NOT APPLICABLE

iNiR has `scripts/devices/usb-snapshot.py`, which reads sysfs once to classify connected USB devices.

Current Hadalis does not expose the corresponding USB-device announcement/model feature that would otherwise require repeated `lsusb`/shell probing.

There is no hot Hadalis USB polling path to replace with this helper.

Do not port feature-specific helpers without their consumer/use case.

### 21.4 Visualizer app-filter migration is not portable as-is — NOT APPLICABLE

iNiR migration 041 changes a specific `appearance.cava.allowedApps` allowlist into `blockedApps` exclusion semantics.

Current Hadalis has no matching `allowedApps` / `blockedApps` CAVA config contract.

This is a feature-semantics migration, not a generic CAVA performance optimization.

### 21.5 SDDM backend ownership divergence found during the audit — CORRECTNESS, NOT PERFORMANCE

This is intentionally recorded outside the optimization priority list because it is a correctness/portability issue discovered while comparing migrations.

Current Hadalis `scripts/sddm/install-pixel-sddm.sh` still writes a high-priority drop-in containing:

```ini
[General]
DisplayServer=x11
InputMethod=

[Theme]
Current=ii-pixel
```

Current iNiR prerelease changed the installer to write only:

```ini
[Theme]
Current=ii-pixel
```

and ships:

- `039-sddm-preserve-greeter-backend.sh`

The upstream rationale is that a theme installer should not override the distro/user's SDDM greeter backend. Forcing X11 can break systems whose installed SDDM provider is Wayland and where Xorg is absent.

Hadalis also lacks an equivalent migration that removes its historical `DisplayServer=x11` / empty `InputMethod` keys.

**Action:** track this as a separate correctness fix, not as an optimization win. If adopted, update both the installer and existing-user migration path, and test Arch plus any supported non-Arch SDDM provider configuration.

### 21.6 Niri session-environment helper remains an architecture idea, not a direct port — RECONFIRMED

iNiR's `scripts/lib/niri-session-env.sh` resolves the authoritative Niri service PID and exactly one matching Niri/Wayland socket.

Hadalis still has broader recovery/session-environment logic because it supports Niri, Hyprland, manual launch and XWayland reconstruction.

Keep the previous classification:

- do not wholesale replace Hadalis session setup with the Niri-only upstream path
- a future Niri-specific fast path may consult `niri.service` first
- preserve fallback/recovery behavior unless startup/reliability measurements prove it redundant

### 21.7 Non-QML static coverage conclusion

The remaining upstream-only scripts are predominantly feature-specific:

- mascot packs
- OCR/translation helpers
- Japanese dictionary/study tooling
- anime/media wrappers
- iRiS-specific visual tests

They do not represent missing generic performance primitives for current Hadalis.

After this pass, the only still-open generic packaging/runtime ideas from unread non-QML areas are already in the handoff:

- Nix derivation source filtering
- measured Niri session-environment simplification
- runtime measurement of startup/process churn

The SDDM item above is important but belongs to correctness work, not the optimization scorecard.

### Next step

Static cross-repo coverage is now sufficient to stop broad archaeology.

Use runtime evidence to select the next optimization batch. The highest-value measurement order remains:

1. startup T+0..T+8 process/CPU/PSS timeline
2. WindowPreview eager/lazy/hybrid A/B
3. Equalizer/compact-sidebar CAVA CPU
4. notification-history scaling
5. favicon delegate process churn
6. Abyss GPU/frame time after visual stabilization

Do not add new static candidates unless a runtime trace, regression or concrete subsystem change points to them.

---

## 22. Audit round 8 — runtime-measurement readiness and evidence gap (2026-09-28)

### Snapshot

- Hadalis head reconciled immediately before this checkpoint: `96e08140d33f666314c99b88ee18dfe22dca97d9`
- iNiR comparison head: `bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`

The requested continuation point from the older audit snapshot was reconciled against current `dev` before this pass. From `4ca071d729118524b9c63894a6e1b91921b24ecc` to the head above there are seven commits. The only runtime-source changes are the Abyss IPC-indicator/editor refinements in `e9a20bad47` and `dc1cce16f7`; the remaining commits are audit/validation documentation. None changes WindowPreview policy, the Equalizer repaint loop, notification persistence, Favicon ownership, or `AbyssField.frag`, so the pending measurement candidates below remain current.

### 22.1 The next blocker is measurement infrastructure, not another static optimization candidate — INVESTIGATE / tooling

The broad static audit stop rule from §20–21 remains valid.

Current Hadalis has strong contract/regression coverage, but it does **not** yet have a dedicated runtime harness for the measurements that now gate optimization decisions.

Verified current coverage:

- `shell.qml` writes `~/.cache/inir/last-boot.json` with Component/Config/shell-entry/Tier-3/Tier-4 timestamps and deltas.
- `setup status` correlates that cache with the current service/Quickshell process start when both describe the same run.
- `scripts/native-cutover-benchmark.sh` contains useful `/proc/<pid>/smaps_rollup`, RSS and CPU-tick sampling, but `proc_metrics()` launches and owns the process being sampled. It is for isolated native/Python backend comparison, not a T+0..T+8 live-shell descendant trace.
- `scripts/test-performance-lifecycle.sh` is a large static contract guard. It does not measure live CPU/PSS/process creation.
- iNiR prerelease also lacks a reusable live-shell profiler; its `scripts/test-iris-performance-contract.py` is structural/contract testing rather than a runtime benchmark.

Therefore do not treat a green contract test as evidence that startup, panel-open CPU, notification scaling, favicon process churn or Abyss GPU cost improved.

### 22.2 Startup T+0..T+8 baseline — PARTIALLY READY, live trace still missing

The existing boot cache is sufficient to identify phase boundaries, but not to answer the current P0 hypothesis.

Still missing from one coherent run:

- child-process start/exit timeline
- main-shell PSS/RSS/thread count sampled across the same timeline
- CPU ticks over fixed windows
- which helpers overlap around Tier 3/Tier 4
- counts for WindowPreview capture, `checkupdates`, font sync, Weather/geocoder/curl, ShellUpdates/git and ConflictKiller work

The first runtime report should sample at a fixed cadence from service restart through at least T+8s and preserve the exact `last-boot.json` from that same shell PID. Repeat runs before drawing conclusions; do not compare a hot-reload cache against an older service/process birth.

Classification: **INVESTIGATE / measurement required before more startup code changes.**

### 22.3 WindowPreview eager-vs-lazy/hybrid A/B is not runnable on one current SHA

Current tests intentionally lock the eager policy:

- `scripts/test-window-preview-eager-capture.sh` asserts pre-capture before Overview/hover.
- `WindowPreviewService.qml` calls `_startPrewarming()` from `Component.onCompleted`.
- newly observed Niri windows are queued for capture and completed previews are pre-decoded into the bounded warm cache.

There is no current config/env experiment selector for:

1. eager prewarm
2. pure consumer-lazy
3. delayed/idle hybrid prewarm

So the A/B requested in earlier rounds cannot be performed fairly on one unchanged runtime build today.

If implementation work is authorized, prefer a narrow experiment-only policy selector or isolated reversible commits so all three modes share the same capture/cache code. Do not first rewrite the service and then compare across unrelated revisions.

Classification remains **INVESTIGATE P0**; eager behavior is still the production baseline.

### 22.4 Equalizer and compact-sidebar candidate remains current; profiling is manual today

Current source still contains:

`EqualizerPanel.qml`:

`Timer { interval: 33; running: root.active && analyzerCanvas.visible; repeat: true; onTriggered: analyzerCanvas.requestPaint() }`

Current compact right Sidebar still renders the shared Equalizer with:

`active: root.panelVisible`

inside the Media section.

Therefore the round-5 hypotheses remain valid:

- fixed Canvas repaint can duplicate event-driven CAVA/DSP/animation repaint requests
- compact-sidebar lifetime can keep Equalizer/CAVA demand broader than the actual media viewport

But there is no dedicated benchmark that drives:

- sidebar closed
- sidebar open with Media outside viewport
- Media in viewport
- Equalizer open with active audio
- Equalizer open during silence/paused playback

and samples the same shell CPU/PSS/CAVA child-process state.

Classification remains **ADAPT experiment / P1** for the fixed repaint timer and **INVESTIGATE / P1** for viewport-scoped demand.

### 22.5 Notification-history and Favicon scaling candidates remain structurally reproducible but unmeasured

Current notification ingress/removal still calls `stringifyList(root.list)` and rewrites the notification JSON file, while history has no count/age cap.

Current `Favicon.qml` still starts a `Process` on every component completion and runs a shell `[ -f ... ] || curl ...` command even when the favicon is already present on disk.

These are suitable for controlled runtime tests because their workloads can be generated deterministically:

- notifications: compare small/medium/large history counts and measure ingress latency, persistence-write size/time, QML object count proxy and shell CPU/PSS
- favicons: prewarm disk cache, then repeatedly create URL-bearing delegates and count shell/curl process launches

No current script automates either measurement.

Classification remains **INVESTIGATE P1–P2**. Do not add a cache/history cap until scaling is measured against product retention semantics.

### 22.6 Abyss GPU candidate remains valid; neither repo provides the needed GPU/frame-time harness

Current `AbyssField.frag` still evaluates wave contribution plus the perimeter/body field before the final `d > 24.0` transparent rejection. The field still supports up to 40 body records.

The source-level optimization idea therefore remains valid, but the acceptance requirement is hardware/runtime-specific:

- 1080p / 1440p / 4K
- fractional scale
- one and multiple outputs
- 0 / typical / worst-case body-record counts
- waves/effects off and on
- frame time/GPU utilization plus visual seam checks

Neither current Hadalis tooling nor iNiR's structural performance test supplies this data.

Classification remains **INVESTIGATE P1**. Do not modify the shader from static reasoning alone.

### 22.7 Measurement-readiness conclusion

Static cross-repo archaeology is complete enough for the current codebase. The highest-value next work is to collect one coherent runtime evidence bundle rather than discover more candidates.

Required order:

1. live startup T+0..T+8 process/CPU/PSS trace on the exact current `dev` SHA
2. WindowPreview three-policy A/B after a minimal experiment mechanism exists
3. Equalizer/compact-sidebar CPU + CAVA-demand scenarios
4. notification-history scaling
5. cached-favicon delegate process churn
6. Abyss GPU/frame-time matrix after current visual work is stable

Do not combine fixes from these categories. Pick the first implementation only after its measurement identifies a material cost.

### Next concrete task

On the maintainer machine, capture the startup evidence bundle first. The report must include:

- exact Git SHA and native backend mode
- active panel family, enabled relevant features, monitor resolution/scale and wallpaper type
- service/main-shell PID identity
- `last-boot.json` from the same PID/run
- fixed-cadence PSS/RSS/thread/CPU samples from T+0 through T+8s
- descendant process command lines with start/exit timing
- at least several repeated runs so cold/warm variance is visible

Until that report exists, another broad static sweep would add lower-confidence work than the already documented candidates.

---

## 23. Audit round 9 — post-round-8 delta and Abyss CPU-side lossless candidates (2026-09-28)

### Snapshot

- Hadalis head at this checkpoint: `3ad44f2b3036ed5d1b434b1cafc8e98537de87b5`
- Previous runtime-readiness checkpoint: `96e08140d33f666314c99b88ee18dfe22dca97d9`
- Delta: 93 commits.
- The delta is concentrated in Abyss popup/perimeter/editor/layout work plus focused Dashboard/Dock/UI refinements and regression contracts.
- This round intentionally does **not** reopen the broad static archaeology stopped in §20–22. It audits only the new runtime delta and CPU-side work that the earlier shader-focused pass did not classify.

The existing pending candidates remain current unless superseded below:

- startup T+0..T+8 runtime evidence
- WindowPreview eager/lazy/hybrid experiment
- Equalizer fixed-rate repaint / compact-sidebar CAVA demand
- notification-history scaling
- Favicon process churn
- Abyss fragment/GPU cost

### 23.1 Wave mass recomputation runs while Abyss waves are disabled — ADAPT / P1 low-risk lossless candidate

Current default configuration has:

- `abyss.waves.enabled = false`
- `abyss.quality = "balanced"`, so `AbyssWaveController.sampleCount = 256`

Current `modules/abyss/AbyssWaveController.qml` behavior:

- `Component.onCompleted: reset()` always creates the simulation.
- `onRecordsChanged: if (simulation) Wave.setMass(simulation,records)` runs whenever body records change.
- `Wave.setMass()` clears the whole mass array, then for every active record iterates the full sample array and evaluates the Gaussian mass contribution.
- `integrationAllowed` is false when waves/audio integration is disabled, but it does not currently gate `onRecordsChanged`.

Current `AbyssBodyHost` reveal/retract changes `record.progress` across the presentation animation, so ordinary popup/sidebar/body motion can repeatedly change `AbyssSurfaceController.records` even when the wave solver is not running.

That means the default waves-off path can still pay repeated JavaScript work whose result cannot affect the rendered wave field.

**Lossless optimization direction:**

1. Do not recompute solver mass while `integrationAllowed === false`.
2. Mark mass state dirty instead.
3. Refresh mass synchronously when integration becomes allowed and before the first impulse/spectrum step can consume it.
4. Preserve the exact current `Wave.setMass()` calculation and record values when waves are enabled.

This is a stronger candidate than another generic static cleanup because disabled-wave sessions have no wave output whose fidelity could change. Acceptance still needs a QML-profiler comparison during repeated Abyss body open/close with waves disabled and enabled.

Do not remove the simulation or change the wave model in this optimization; the target is only unnecessary recomputation while there is no consumer.

### 23.2 Abyss record packing and 40 shader-uniform bindings can multiply one geometry change into repeated JS allocation — INVESTIGATE / P1

This is CPU/QML-side work distinct from the existing §13.5 / §22.6 fragment-shader candidate.

Current `modules/abyss/AbyssSurfaceController.qml` publishes:

- `records: moduleRecords.concat(Object.keys(participants).map(... Object.assign(...)))`
- `inputBounds` through another full participant map/filter
- `bodyPlacements` through a participant map/filter into the allocator

The hot path is `records`: a live body reveal/retract changes its geometry repeatedly, which invalidates the aggregate list and rebuilds/clones participant record objects.

Current `modules/abyss/looks/AbyssField.qml` then exposes forty independent bindings:

- `rect0` through `rect39`
- each calls `root.packed(index)`
- each `packed()` constructs a new `Qt.vector4d(...)`

Because every `rectN` depends on `root.records`, one records-array change can re-run all forty packing bindings even when only a small number of records are active.

Qt's QML performance guidance explicitly treats frequently reevaluated complex bindings and JavaScript allocation as profile targets. This path therefore deserves CPU/QML-profiler measurement in addition to the already-planned GPU/frame-time shader measurement.

**Lossless optimization directions to test, not implement blindly:**

- avoid cloning inactive/zero-area participant records on every geometry frame;
- keep slot order/capacity stable while updating only changed packed values;
- avoid rebuilding all forty vector values when one record changes, if QML/ShaderEffect binding semantics allow a stable packed representation;
- preserve byte-equivalent numeric uniform values, record ordering, `capacity = 40`, and all current connected geometry.

Do **not** collapse this into the fragment early-rejection task. One is QML/JS/uniform-update cost; the other is per-pixel GPU cost.

### 23.3 New generic Abyss popup hosting is not an eager-content regression — CLOSED / current lifecycle is sound

The new generic popup path was checked specifically because the post-round-8 delta added several popup components.

Verified:

- `AbyssGenericPopupPresenter` owns one semantic popup body per output and retracts before switching kind.
- `AbyssBodyHost` only activates its content Loader when `residentContent || open || progress > 0.001` and deferred panels are ready.
- `AbyssPopupContent` uses one Loader whose `sourceComponent` selects only the active semantic popup kind.
- Utilities internally retain only the current SwipeView page and immediate neighbours.
- New launcher/dock-menu/network popup components do not introduce an unconditional background timer or process loop.

Therefore there is no reason to replace the current popup host with another loader layer merely for performance. Keep the existing lifecycle as a regression guard.

### 23.4 Abyss editor deep-copy and relocation work is interaction-scoped — CLOSED unless profiling says otherwise

`AbyssEdgeEditor.qml` performs JSON deep copies when entering/resetting edit state and uses a 90 ms debounce timer for toolbar relocation while editing.

The drag path also updates draft placement and periodically emits liquid impulses, but this work exists only while the editor is visible and the user is actively manipulating layout.

No always-idle lossless optimization was found here. Do not complicate the editor state model to remove one-shot JSON copies without profiler evidence.

### 23.5 Dashboard/Dock delta did not add a new unconditional hot loop — CLOSED / retain existing guards

The large Dashboard/Dock changes in the 93-commit delta were checked for new fixed-rate timers, eager heavy loaders and always-on rendering.

Findings:

- Dashboard widget content remains behind per-card Loaders.
- When Dashboard is hosted by Abyss, `AbyssBodyHost` releases non-resident content after close/retraction.
- Dock rebuild work is already debounced; its drag timers are gesture-scoped.
- New utility buttons are individually Loader-gated by configured utility presence.
- No new unconditional `Canvas.requestPaint()` loop comparable to the existing Equalizer candidate was introduced.

The existing Dashboard/Dock lifecycle optimizations should remain regression guards rather than new rewrite targets.

### 23.6 Revised lossless research priority after the post-round-8 delta

The current order is:

1. **Measure and, if confirmed, gate waves-off `Wave.setMass()` recomputation** — smallest new lossless candidate with a clear no-consumer state.
2. **Profile Abyss QML record/uniform churn together with the existing GPU matrix** — separate CPU/QML and GPU numbers.
3. **Collect startup T+0..T+8 evidence** before further service materialization changes.
4. **Run the existing Equalizer/CAVA scenarios.**
5. **Measure notification-history scaling and cached-Favicon process churn.**
6. **Run WindowPreview policy A/B only after an experiment selector/reversible comparison mechanism exists.**

Static work should remain delta-driven. Do not resume a blind full-tree search after every UI commit; re-audit newly added/changed runtime primitives and use profiler/runtime evidence to promote candidates.

### Next concrete task

For Abyss specifically, the next evidence bundle should compare repeated popup/body open-close cycles on the same current SHA with:

- waves disabled (current default)
- waves enabled, balanced quality

Capture at least:

- QML/JavaScript time in `AbyssSurfaceController.records`, `AbyssField.packed()` and `Wave.setMass()`
- binding reevaluation counts for `rect0..rect39`
- frame time during reveal/retract
- JavaScript allocation/GC activity if available
- the number of active records during the trace

If the waves-disabled trace confirms repeated `Wave.setMass()` cost, that becomes the first implementation candidate. The implementation must preserve current enabled-wave numerics and visual output exactly.

---

## 24. Audit round 10 — Pyramid v2 foundation, startup fan-out and lossless hot-path refinement (2026-09-28)

### Snapshot

- Hadalis head reconciled immediately before this checkpoint: `faec121b6b83ead6b3455fa96ff0a03d88b5a166`
- Previous optimization-note commit: `cdf6c587aec4a78468c72917d0aa3f33492d50cd`
- Runtime delta since the prior audit: two Abyss Pyramid v2 foundation commits, affecting `AbyssBodyHost.qml`, `AbyssBodyPlacement.js`, a new `AbyssPyramidMotion.js`, launcher-control sizing and focused tests.
- This round also re-opened startup work ownership and two long-session/process-churn candidates where §22–23 had evidence gaps.
- No runtime/source implementation was changed during this research round. Only this handoff is updated.

### 24.1 Pyramid v2 motion helper currently has zero live runtime cost — CLOSED for current HEAD / future design guard

The new `modules/abyss/looks/AbyssPyramidMotion.js` contains:

- placement/record cloning helpers
- collapsed-record construction
- record/rect interpolation helpers

At current HEAD, no live runtime component imports or calls this helper. The accompanying contract test only establishes the allocator/presentation ownership boundary.

Therefore:

- do **not** count Pyramid v2 helper allocation as a current performance regression;
- do **not** optimize the helper before it has a consumer;
- when Pyramid v2 presentation wiring lands, profile the first runtime call site before accepting a per-frame binding.

Important future guard: `cloneRect()`, `cloneRecord()`, `interpolateRect()` and `interpolateRecord()` all allocate fresh JavaScript objects. Calling them from a binding driven directly by animation progress would create main-thread JS allocation and binding work every frame.

Qt's QML performance guidance explicitly warns that animation-dependent bindings are reevaluated as their dependencies change and recommends avoiding complex JavaScript work during animations. The QML profiler can separately expose Binding, JavaScript, memory-allocation and animation activity.

Reference:

- https://doc.qt.io/qt-6/qtquick-performance.html
- https://doc.qt.io/qtcreator/creator-qml-performance-monitor.html

### 24.2 Abyss reveal has a multi-stage per-frame allocation cascade — REFINED P1 profiling target

§23.2 identified `AbyssSurfaceController.records` and `AbyssField.rect0..rect39`. The upstream source chain is now clearer.

For a normal `AbyssBodyHost` reveal/retract:

1. `availabilityProgress` is animated.
2. `progress` changes from that animation.
3. `record` reevaluates:
   - `Geometry.placedPanel(... progress ...)`
   - `Geometry.panel()` constructs new `content` and `surface` objects plus the returned record object.
   - `Geometry.joinCorner()` may clone the surface/record again.
4. `AbyssParticipant.geometry` changes.
5. `AbyssSurfaceController.records` rebuilds the aggregate list and clones participant geometry with `Object.assign(...)`.
6. `AbyssField` sees `records` change; `rect0..rect39` all depend on that property and each `packed()` call constructs a `Qt.vector4d`.
7. With the current waves-off bug from §23.1, `AbyssWaveController.onRecordsChanged` can additionally run `Wave.setMass()`, iterating the 256-sample mass array for active records even though integration is disabled.

The allocator is **not** the main per-frame problem: `placementRequest.record` uses `requestedRecord` at full progress, so ordinary reveal progress does not intentionally animate allocator truth. Keep that separation.

This creates a concrete CPU/QML profile target:

- per-host `Geometry.panel/placedPanel/joinCorner` JavaScript time
- `AbyssSurfaceController.records` binding time/allocation
- `rect0..rect39` reevaluation count
- `Wave.setMass()` time with waves disabled/enabled
- JS heap allocation/GC during repeated reveal/retract

Lossless work should attack redundant propagation/allocation, not change geometry numerics, record ordering or the single-field visual model.

### 24.3 Tier-0 MemoryPressure prime may block on `/proc/self/maps` — INVESTIGATE / startup P1-low

Earlier rounds correctly classified `MemoryPressureService` as a sparse 5-minute in-process monitor rather than a shell polling problem. One startup detail was missed.

Current startup ownership:

- `shell.qml` force-instantiates `MemoryPressureService` at Tier 0 to keep the `memory` IPC target available.
- `MemoryPressureService.Component.onCompleted` uses `Qt.callLater()` to perform an immediate first `_checkMemoryPressure()`.
- the FileView for `/proc/self/maps` uses `blockLoading: true`.
- `_checkMemoryPressure()` calls `reload()`, then immediately `text()`, then splits and scans the full maps text for `JSGCHeap`.

Quickshell documents that a `FileView.text()` call with `blockLoading: true` can block the UI thread if the content is not loaded yet and explicitly warns about stutter from blocking reads after shell windows begin loading.

Reference:

- https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView/

This is not yet proven material because preload may often finish first and the scan is sparse. It should nevertheless be added to the startup trace.

Lossless directions to evaluate if it appears in the profile:

- keep the lightweight IPC owner alive but defer the first automatic scan until after shell entry/deferred startup;
- make an IPC `stats` request trigger an immediate scan if no sample exists yet;
- or process the preload asynchronously on `loaded` rather than forcing an immediate blocking read.

Do not reduce the 5-minute monitoring semantics or warning threshold merely to improve startup.

### 24.4 External theming creates a concrete T+0.6s process fan-out overlapping Tier 3 — P0 BENCHMARK / ADAPT only after trace

The previous startup checklist named WindowPreview, updates, font sync, Weather and ConflictKiller, but did not explicitly include the external theme reconciliation wave.

Current default startup behavior:

- `shell.qml` calls `ThemeService.applyCurrentTheme()` via `Qt.callLater()` once Config is ready.
- Config schema default is `appearance.theme = "auto"`.
- auto theme calls `MaterialThemeLoader.reapplyTheme()`.
- with external application enabled in the main shell, it also calls `MaterialThemeLoader.requestExternalApply()`.
- `delayedExternalApply` fires after **600 ms** and runs `scripts/colors/applycolor.sh`.
- `ThemeService` separately launches `system24_palette.sh` when Vesktop theming is enabled; that option defaults to true.

The default `applycolor.sh` target set currently enables approximately seven module processes before installation-specific early exits:

- terminals
- GTK/KDE
- editors
- Zed
- Chromium
- SDDM
- Pear Desktop

`applycolor.sh` deliberately caps module parallelism to 2–4 jobs and uses nice/ionice, but this still creates a real process/CPU/I/O wave.

Timing matters:

- shell-entry delay is ~200 ms when animations are enabled;
- Tier 3 starts 500 ms after shell entry, around the same ~T+700 ms window;
- external theming is scheduled for ~T+600 ms from its request.

Therefore the external theme fan-out can overlap directly with Tier 3 service materialization and WindowPreview work.

This is a **measurement candidate**, not permission to skip theme reconciliation. Reasserting persisted theme state after external edits/upgrades is an intentional behavior.

The next startup trace must identify:

- `applycolor.sh`
- each theming-module child
- `system24_palette.sh` / its Go or Python generator
- their CPU/PSS/process lifetime relative to Tier 3
- whether cold-start variance changes when external theming inputs are already up to date

Potential lossless directions after evidence:

- stagger/reorder the reconciliation wave so it no longer competes with first-interaction services while still running once per session;
- consolidate redundant startup helper processes;
- add proven per-target no-op detection without removing reconciliation semantics.

### 24.5 Icon/font desktop reconciliation belongs in the same startup evidence bundle — REFINED, not a separate blind rewrite

Two adjacent startup paths should be measured together with §24.4.

#### IconThemeService

Fresh defaults persist `appearance.iconTheme = "WhiteSur-dark"`. `IconThemeService.ensureInitialized()` therefore does not merely read the current desktop theme; it reasserts the saved theme on startup:

1. runs `gsettings set org.gnome.desktop.interface icon-theme ...`;
2. on the production Rust backend, launches `native-dispatch desktop-icons`;
3. the Rust helper reads KDE/Qt5/Qt6/GTK3/GTK4 config files and atomically writes only files whose content actually differs.

Important correction: the native helper already compares `updated != base`, so this is **not** five unconditional file rewrites. Remaining cost is process creation, config reads/parsing and any genuinely required writes.

Treat as INVESTIGATE, because reasserting the configured theme after external changes is a real product contract.

#### FontSyncService

This candidate is already documented, but its timing belongs in the same trace:

- default `syncWithSystem = true`;
- service materializes only when enabled;
- it waits 500 ms, then runs `sync-system-fonts.sh`;
- that helper may invoke gsettings, Python and kwriteconfig6 while taking the shared app-theme lock.

Do not optimize icon, font and palette reconciliation independently before seeing whether their overlap is the actual startup problem.

### 24.6 Notification history write cost is main-thread serialization, not blocking FileView I/O — REFINED P1 long-session candidate

Current notification persistence does:

`notifFileView.setText(stringifyList(root.list))`

on every notification ingress and individual discard.

`stringifyList()` performs:

1. `list.map(notifToJSON)`
2. `.filter(...)`
3. `JSON.stringify(..., null, 2)`

over the entire retained history.

Quickshell `FileView.setText()` uses non-blocking writes unless `blockWrites` is enabled; this FileView does not enable `blockWrites`. Therefore the clearly synchronous portion is the construction of the full JSON string on the QML/JS thread before `setText()` is called.

Reference:

- https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView/
- https://doc.qt.io/qt-6/qtquick-performance.html

This strengthens the existing history-scaling hypothesis:

- ingress/discard CPU grows with total retained history;
- every write allocates a new mapped array plus serialized string;
- pretty-printing increases serialized bytes and formatting work;
- no history cap means the cost grows over a long session.

Lossless directions, in increasing complexity:

1. measure compact vs pretty JSON for this internal state file;
2. preserve full retention but avoid remapping unchanged QObject entries when possible;
3. if still material, move serialization/journaling off the interaction-critical QML path while preserving atomic/durable semantics.

Do not introduce a retention cap under the label “lossless”; a cap changes user-visible history semantics.

### 24.7 Favicon cache hits still spawn a shell process per component — ADAPT / P1-low to P2, now a stronger lossless candidate

Current `modules/common/widgets/Favicon.qml` creates one `Process` per component and starts it in `Component.onCompleted`.

The command is:

`bash -c '[ -f cache/domain.ico ] || curl ...'`

So a disk-cache hit avoids `curl`, but still pays:

- QML Process object creation
- one Bash process start/exit
- shell parsing and filesystem stat

for every Favicon delegate instance.

Live consumers include search/clipboard URL rows, AI annotation sources and wallpaper/source UI. Recreating delegates can therefore create repeated shell churn even with a fully warm favicon cache.

This is one of the clearest lossless process candidates because cache-hit output is already known and no network work is required.

Research direction:

- use a shared/in-process favicon resolver/cache state so a known warm domain can publish its local URL without creating a process;
- reserve the downloader process/network request for a cache miss;
- keep failed-download cleanup and stale/corrupt-cache handling explicit.

Acceptance should count child-process launches while repeatedly creating the same cached URL delegates. The expected steady-state cache-hit target is zero shell/curl children.

### 24.8 False positives closed in this round

Several suspicious-looking static hits were checked and should **not** enter the backlog:

- `SystemInfo.qml` has a 1 ms Timer, but it is `repeat: false`; it is startup deferral, not 1 kHz polling.
- `Network.qml` uses a persistent `nmcli monitor` subscriber plus debounced state reads; the 30s timer is only a rescan timeout, not periodic polling.
- `Directories.qml` already consolidated the old many-process cleanup/bootstrap into one ordered shell invocation.
- production Rust desktop-icon sync already avoids rewriting unchanged INI files.
- Pyramid v2's new motion helper is not imported at current HEAD.

Keep these as regression knowledge so future static greps do not reopen them.

### 24.9 Revised evidence order

The highest-value next measurements are now:

1. **Startup T+0..T+8 process/CPU/PSS trace**, explicitly including:
   - Material/applycolor fan-out
   - system24/Vesktop generation
   - IconTheme reconciliation
   - MemoryPressure initial maps scan
   - Tier 3 WindowPreview/VoiceSearch/GameMode work
   - Tier 4 FontSync/Autostart/ShellUpdates construction
   - ConflictKiller
2. **Abyss reveal CPU/QML profile**:
   - `Geometry.placedPanel/joinCorner`
   - controller aggregate `records`
   - `rect0..rect39`
   - waves-off `Wave.setMass()`
3. **Notification history scaling** with small/medium/large retained histories.
4. **Warm-cache Favicon delegate churn** with child-process counting.
5. Existing Equalizer/CAVA and WindowPreview policy experiments.

Do not implement any of these from static evidence alone except where the maintainer separately authorizes code changes. This handoff remains research-only.

---

## 25. Audit round 11 — active Pyramid v2, demand gating, cache/process dedup and Config invalidation fan-out (2026-09-28)

### Snapshot

- Hadalis runtime/documentation HEAD reconciled immediately before this checkpoint: `96bd4562783befae30bf7ede8ddc965e2ccee755`
- Previous optimization-note commit: `68b59a4f43169395a8dc85d7c81f65e92756361d`
- Delta since Audit round 10: two Pyramid v2 follow-up commits touching `AbyssBodyHost.qml`, `AbyssGenericPopupPresenter.qml`, tests and documentation.
- Important correction to §24.1: Pyramid v2 motion is no longer foundation-only. `AbyssBodyHost.qml` now imports and executes `AbyssPyramidMotion.js` in the live presentation path.
- No runtime/source implementation was changed during this round. Only this handoff is updated.

### 25.1 Pyramid v2 allocation warning is now a live runtime hot-path candidate — PROMOTE to P1 PROFILE

Audit round 10 recorded `AbyssPyramidMotion.js` as a future design guard because it had no live importer at that snapshot. That conclusion is now obsolete.

Current `AbyssBodyHost.qml`:

- imports `looks/AbyssPyramidMotion.js`;
- enables Pyramid motion for `stackPolicy === "pyramid"` hosts using external reveal progress;
- computes `rawPresentationRecord` with `PyramidMotion.interpolateRecord(..., root.progress)`;
- snapshots/restores placements and records through `clonePlacement()` / `cloneRecord()`;
- uses `AbyssPyramidCoordinator` to freeze/reconcile same-anchor peers during close/reopen.

The new path is semantically well separated from resting allocation, but it is allocation-heavy.

For one `interpolateRecord(from,to,progress)` evaluation alone:

- `cloneRecord(to)` creates a record object plus cloned `surface` and `content` objects;
- two `interpolateRect()` calls create two more objects;
- therefore at least roughly five fresh JS objects are created before `joinCorner()`, aggregate-record cloning or shader uniform packing.

When a peer placement moves, `capturePyramidRestingState()` can additionally clone the placement and resting record.

This now composes directly with the previously documented reveal chain:

1. reveal `progress` changes;
2. Pyramid interpolation creates presentation record objects;
3. `AbyssParticipant.geometry` changes;
4. `AbyssSurfaceController.records` rebuilds/clones aggregate records;
5. `AbyssField.rect0..rect39` repack from the new records list;
6. waves-off sessions may still invoke `Wave.setMass()` through `onRecordsChanged`.

Do not optimize away the Pyramid transaction model or frozen-peer semantics. Profile allocation/binding cost first.

Required profile additions:

- JS calls/time for `PyramidMotion.interpolateRecord`, `cloneRecord`, `clonePlacement`;
- allocation/GC during one popup open, close and mid-close reversal;
- same-anchor two/three-popup reflow;
- `AbyssSurfaceController.records` and `AbyssField.packed()` in the same trace;
- compare Pyramid popup reveal to a non-Pyramid body reveal of similar size.

The lossless goal is to reduce redundant temporary-object propagation while preserving identical per-frame geometry.

### 25.2 Compact Sidebar keeps Equalizer/CAVA live while the Controls section is hidden — ADAPT / P1 strong lossless candidate

The earlier Equalizer candidate needed a more precise lifecycle audit.

Current `EqualizerPanel.qml` has:

- an `active` lease into `EqualizerService`;
- a `CavaProcess { active: root.active }`;
- a 33 ms analyzer repaint timer while `root.active && analyzerCanvas.visible`.

The 33 ms timer is **not globally redundant**. `onPaint` deliberately uses `Date.now()` to animate the electric-wire/noise trace, so replacing it with event-only repaint would change motion semantics. Keep that distinction explicit.

The clear lossless bug is in compact-sidebar ownership.

Current `CompactSidebarRightContent.qml`:

- keeps the `controls` section loaded because it is the base section;
- creates the reordered control subsections through a Repeater;
- the media subsection Loader is active whenever its model item is `"media"`;
- its `EqualizerPanel` currently uses only `active: root.panelVisible`.

When the compact sidebar is open on Calendar, Events, or another non-Controls section:

- the Controls section is opacity 0 / not visible;
- its media Equalizer still remains constructed;
- `EqualizerPanel.active` remains true because the overall panel is visible;
- EqualizerService demand, shared CAVA demand and the analyzer repaint timer continue even though the surface cannot be seen.

This is a strong lossless demand-gating target.

Acceptance requirements:

- no Equalizer/CAVA lease when the Controls section is not the current visible section;
- opening/switching back to Controls restores the same analyzer state/visual behavior;
- do not change the 33 ms cadence while the analyzer is actually visible;
- verify rapid section switching and sidebar close/reopen.

A second, lower-confidence optimization can later test viewport visibility inside the scrollable Controls section, but do not conflate that with the already-proven section-level hidden case.

### 25.3 Bar media can keep non-current PlayerControl timers alive — INVESTIGATE / P2

`BarMediaPopup` constructs one `PlayerControl` per visible MPRIS player to support tab sliding.

Non-current delegates are positioned off viewport and disabled, but they remain `visible: true`.

`PlayerControl.presentationActive` is:

`root.visible && root.QsWindow.window.visible`

and its 1 Hz MPRIS position timer uses `presentationActive`, not current-tab ownership.

Therefore with several simultaneously playing MPRIS players, opening Bar Media can leave position timers running for offscreen non-current delegates. Those delegates also retain artwork resolver / color-quantizer state.

This is not a priority rewrite because the resident delegates intentionally support smooth tab changes. Profile only under multiple-player scenarios and prefer narrowing time-based work over unloading the delegates.

### 25.4 WindowPreview Fish compatibility wrapper adds one avoidable interpreter launch per capture — ADAPT / P2 clear lossless candidate

The WindowPreview eager-vs-lazy policy remains an A/B question because changing prewarm timing can change first-hover latency.

A smaller lossless overhead is now confirmed.

`WindowPreviewService._doCapture()` chooses Fish when available:

- Fish path: `scripts/capture-windows.fish`
- fallback path: `scripts/capture-windows.sh`

Current `capture-windows.fish` contains no independent capture behavior. It immediately:

`exec /usr/bin/bash .../capture-windows.sh $argv`

Therefore a Fish-capable system pays Fish startup/parsing only to replace itself with the Bash implementation that all actual behavior already uses.

Lossless direction:

- invoke `capture-windows.sh` directly for this path;
- retain the Fish file only if it is still a public compatibility entry point for external callers.

Acceptance is simple:

- identical arguments/exit status/stdout `PREVIEW_READY` protocol;
- identical clipboard/capture cleanup behavior;
- one fewer interpreter process on every internal capture.

Do not treat this as evidence for lazy WindowPreview initialization; it is independent of prewarm policy.

### 25.5 MediaArtworkResolver warm-cache path pays redundant process/stability checks — ADAPT / P1 process-churn candidate

`MediaArtworkResolver.qml` is used from multiple media surfaces, including `CavaTheme`, `MediaArtwork`, `PlayerControl`, `BarMediaPlayerItem`, `PlayerBase` and `YtMusicPlayerCard`.

Its own cache publishers are atomic:

- local-file cache copy: copy to temp then rename;
- data-URI decode: write temp then rename;
- remote download: curl to temp, validate MIME, then rename.

However a warm internal cache hit still performs this lifecycle:

1. spawn `/usr/bin/test -s <cached path>`;
2. call `_setReadySource(file://...)`;
3. wait on a 120 ms publish timer;
4. spawn Bash;
5. Bash checks size, runs `stat`, sleeps 200 ms, runs `stat` again and requires the size to remain stable.

The stability check is justified for arbitrary external local files that may be actively written, but it is redundant for a resolver-owned cache file that was already atomically published.

This creates both child-process churn and avoidable warm-cache display latency.

Lossless direction:

- distinguish trusted resolver-owned cache entries from arbitrary external local files;
- trusted warm cache: publish directly after an in-process/shared cache-validity check;
- external local source: keep the current stability contract.

Measure:

- child-process count and time-to-display when repeatedly constructing the same warm cached artwork;
- remote/local/data-URI behavior separately;
- corrupt/zero-byte cache recovery.

### 25.6 MediaArtworkResolver has no shared in-flight miss deduplication — INVESTIGATE / P1

Each resolver instance owns independent `artExistsChecker` and `artworkDownloader` processes.

Several simultaneously visible shell surfaces can resolve the same track metadata and therefore the same cache path. On a cold cache miss they can race:

1. each runs its own `test -s`;
2. each observes the miss;
3. each starts its own Bash/curl download;
4. each writes a process-specific temp file;
5. multiple successful downloads may rename to the same logical cache target.

Atomic rename prevents a partial final file, so this is primarily duplicated network/process/CPU work rather than a correctness bug.

A shared in-flight registry keyed by final cache identity is a potentially lossless service-level optimization:

- first resolver owns download;
- peers subscribe to its completion;
- all publish the identical final cached bytes/path afterward.

Acceptance must include owner destruction mid-download, failure/retry, and track changes while an old request is in flight.

### 25.7 Config.getNestedValue creates global binding invalidation for unrelated keys — INVESTIGATE / P1 broad fan-out candidate

`Config.qml` already debounces persistence for 50 ms and uses non-blocking FileView writes by default. The more important cost is reactivity.

Every `setNestedValue()` / `setNestedValues()`:

1. mutates the requested config value;
2. updates the JSON mirror;
3. restarts the write debounce;
4. increments one global `Config.revision`;
5. emits one global `Config.configChanged()`.

`Config.getNestedValue()` deliberately reads `root.revision` before traversing the requested path. This means every active QML binding using `getNestedValue()` depends on one global revision regardless of its actual key.

Current repository search returns at least:

- 41 files containing direct `Config.getNestedValue(...)` calls;
- 88 occurrences in the returned search snippets alone.

The concentration is especially high in persistent desktop widgets and media presets:

- clock and Cookie-clock children;
- battery;
- visualizer;
- calendar;
- system monitor;
- Japanese typography;
- background layout/edit helpers;
- media-control presets;
- custom widget helpers.

Therefore changing an unrelated config value can cause these bindings to reevaluate even when their final value is unchanged. QML may suppress downstream property propagation when the result compares equal, but the binding traversal/JS call itself has already happened.

This matters because config updates are not rare one-shot events. Several sliders call `Config.setNestedValue()` from `onMoved`, including night-light temperature, widget opacity/layout parameters and other live editors.

Profile scenario:

- keep several desktop widgets resident;
- drag an unrelated settings slider for several seconds;
- record Binding + JavaScript time and reevaluation counts;
- identify how many `getNestedValue()` bindings fire per revision.

Potential lossless architecture:

- schema-backed config should rely on narrow QML property notifications where reliable;
- dynamic/custom-widget paths need a scoped revision or key/path invalidation mechanism rather than one global revision;
- preserve the current correctness fallback for JsonAdapter/list/var cases that motivated the revision dependency.

Do not remove `Config.revision` globally without a binding-correctness matrix; it exists to cover real nested-notify gaps.

### 25.8 Global configChanged also triggers several broad consumers; MPRIS and Background are the strongest current targets — INVESTIGATE

Repository search currently finds roughly sixteen source files with `onConfigChanged` handlers.

Most are low-cost guards or debounce triggers. Two are materially broader.

#### MprisController

On every config change it currently calls:

- `_updateMpvCache()`;
- `_rebuildPlayerList()`.

The rebuild is debounced by 50 ms, which is good, but the eventual work:

- iterates every MPRIS player;
- executes the large `isRealPlayer()` metadata/filter heuristic;
- runs `_filterYtMusicDuplicates()`;
- duplicate grouping contains a pairwise player comparison loop.

The config inputs that materially affect player membership are much narrower, principally:

- `media.filterDuplicatePlayers`;
- `sidebar.ytmusic.enable`.

Changing wallpaper opacity, widget size, night-light temperature, etc. should not require a full media-player refilter.

This is a clean narrow-invalidation candidate if profiler traces show meaningful rebuild activity during unrelated settings interaction.

#### Background

Each output-local Background instance:

- increments `_zoneRevision` on every Config change;
- recomputes zone occupancy over fifteen built-in widget definitions plus custom widgets;
- reads widget state through `DesktopWidgetLayout`, which itself ultimately uses `Config.getNestedValue()` for base values;
- schedules every custom-widget Loader's `_syncLoaded()` on every Config change.

This can multiply global config traffic by output count and custom-widget count.

Lossless direction is to invalidate zone/layout ownership only when relevant background-widget configuration changes, while preserving output override and dynamic custom-widget reactivity.

### 25.9 Lower-priority global Config consumers closed/deprioritized

This round also checked several superficially broad handlers:

- **TlpService:** any Config change schedules `apply()`, but `_matchesRequestedPolicy()` and enabled/managed guards usually return before spawning a privileged helper. Keep it below MPRIS/Background.
- **WallpaperListener:** any Config change restarts an 80 ms debounce; refresh rebuilds the per-output wallpaper map and JSON-compares it before publishing. This is avoidable unrelated work, but it is small relative to the stronger fan-out candidates.
- **AppLauncher:** its private config revision is currently consumed by Niri Settings app-command controls rather than the whole shell; low priority.
- **ThemeService:** global changes restart a debounce, but the live-regeneration signature check prevents unrelated settings from launching the heavy theme pipeline.

These can be narrowed later if a profiler points at them; do not expand the backlog simply because they subscribe globally.

### 25.10 Equalizer repaint classification correction

Preserve this correction for future agents:

- **Do not** describe the Equalizer 33 ms analyzer timer as obviously redundant.
- It is intentionally time-driven because the wire trace uses `Date.now()`.
- The lossless win is currently hidden-surface demand gating, especially Compact Sidebar.
- An event-only repaint conversion is a visual/motion behavior change unless the animated noise is reproduced through an equivalent scene-graph mechanism.

### 25.11 Revised research priority after round 11

The evidence order is now:

1. **Startup T+0..T+8 trace** from §24, because process contention can dominate all micro-optimizations.
2. **Abyss/Pyramid QML allocation profile** on current HEAD, including the newly live `PyramidMotion.interpolateRecord` chain and the existing records/uniform/waves-off paths.
3. **Config invalidation trace during live settings interaction**:
   - global `revision` / `getNestedValue`;
   - MPRIS rebuilds;
   - Background zone/custom-loader fan-out.
4. **Compact Sidebar hidden Equalizer/CAVA demand test.**
5. **MediaArtworkResolver warm-cache process count + cold-cache duplicate-download test.**
6. **Notification-history serialization scaling.**
7. **Favicon warm-cache process count.**
8. **WindowPreview internal Fish-wrapper removal can be treated as a small independent lossless cleanup after authorization; eager/hybrid policy still needs A/B evidence.**
9. Existing WindowPreview eager/hybrid, Equalizer visible-render cost and Abyss GPU/frame-time experiments.

Do not implement any candidate from this research-only handoff unless the maintainer separately authorizes code changes.

---

## 26. Audit round 12 — startup state-vs-maintenance ownership split (2026-09-28)

### Snapshot

- Hadalis HEAD reconciled immediately before this checkpoint: `1fa3558e51e907d0edacc7b1453f46e88ce89ff4`
- Previous optimization-note commit: `36d893c2662fcac2ef32f025790a09a3e9aadf44`
- Runtime delta after round 11 contains Pyramid v2 correctness fixes, including zero-motion close handling and allocator-target entry origins.
- The active Pyramid allocation candidate from §25.1 remains valid: `rawPresentationRecord` still evaluates `PyramidMotion.interpolateRecord(..., root.progress)` on the live reveal path. The new `pyramidAllocatorRecord` is allocator-target-derived rather than reveal-progress-derived, so it does not replace the per-frame profile target.
- This round verifies startup optimization notes against current source rather than copying README commentary verbatim.
- No runtime/source implementation was changed. Only this research handoff is updated.

### 26.1 General rule: separate singleton residency from maintenance side effects — P0/P1 architecture principle

Several current services legitimately need their reactive state or IPC ownership early, but their `Component.onCompleted` also launches optional process work.

Trying to lazy-load the whole singleton can break:

- IPC targets;
- first-frame reactive state;
- restoration ordering;
- existing direct QML singleton references.

The safer lossless direction is:

1. keep the state/API owner resident when required;
2. move optional probing/enumeration/reconciliation behind an idempotent demand/deferred function;
3. explicitly request that work from the startup tier or first real consumer;
4. preserve immediate work when an enabled feature actually depends on it.

This principle applies strongly to GameMode, MPRIS enrichment and Audio below, and also helps reason about ThinkFan/TLP.

### 26.2 GameMode is effectively startup-resident before its nominal Tier 3 assignment — RECLASSIFY residency, optimize only Niri reconciliation

`shell.qml` declares `_gameModeService` as a Tier-3 deferred slot, but `Appearance.qml` directly binds:

- `GameMode.active`;
- `GameMode.disableEffects`;
- `GameMode.disableAnimations`;
- `GameMode.minimalMode`.

`shellEntryTimer.interval` itself reads `Appearance.animationsEnabled`, so GameMode can materialize as part of the startup appearance dependency graph before `root._gameModeService = GameMode` runs.

Do not spend effort trying to make the singleton itself truly Tier 3 unless all ubiquitous Appearance dependencies are redesigned.

The stronger lossless target is its startup Niri animation reconciliation.

Current `GameMode.qml`:

- starts an init timer on component completion;
- after state load, starts a 900 ms `startupNiriSyncTimer`;
- that timer always calls `setNiriAnimations(!active)` when Niri animation control is enabled;
- current implementation runs Bash;
- Bash executes `sed -i` on the animation config and then always runs `niri msg action reload-config`.

The normal inactive-session desired state is animations enabled. If the file already represents that state, rewriting/reloading the compositor produces no user-visible improvement.

**Lossless direction:**

- retain startup reconciliation so external/manual config changes are repaired;
- detect whether the target file actually needs mutation;
- only rewrite and reload Niri when the desired animation state differs;
- preserve the current queued/rerun semantics for real state transitions.

Measure process lifetime and compositor reload count on an unchanged normal boot.

### 26.3 MprisController runs optional MPD/PipeWire discovery during ordinary media startup — ADAPT / P1

The default Bar enables the media module, so ordinary MPRIS state is legitimately early data.

Current `MprisController.Component.onCompleted` nevertheless always:

- starts `_mpdMprisProbeProc`;
- the probe runs Bash with `command -v mpd-mpris` plus `pgrep -x mpd`;
- if `Audio.outputAppNodes` is non-empty, schedules `pw-dump`;
- `pw-dump` output is parsed into `_streamMetadataById`.

Current source use of `_streamMetadataById` is specifically `_mpdPlaybackStreamPresent()`, used to decide whether an MPD→MPRIS bridge should be started. Standard MPRIS player display does not need this PipeWire metadata map.

Therefore state ownership and optional enrichment can be separated losslessly:

- keep MPRIS player tracking/active-player state resident for the Bar;
- defer MPD bridge capability/process discovery until:
  - LocalMusic explicitly requests an MPD session;
  - an MPD player/process/stream signal provides evidence;
  - or a deferred post-first-frame reconciliation is intentionally retained for direct-ALSA MPD discovery;
- do not run `pw-dump` merely because unrelated audio output-app nodes exist unless MPD enrichment has a consumer.

Preserve automatic discovery of already-running MPD, including direct ALSA configurations. The optimization target is timing/demand, not removal.

### 26.4 ThinkFan is force-instantiated even when its shipped profile-follow feature is disabled — ADAPT / P1 strong lossless candidate

Current `shell.qml` startup-critical properties include:

`property var _thinkFanService: ThinkFanService`

The stated reason is to keep per-power-profile fan following alive.

However shipped defaults have:

`powerProfiles.fanControl.enabled = false`

and `ThinkFanService.Component.onCompleted` immediately calls `refresh()`, which starts:

`/usr/libexec/inir-thinkfan --status`

even when the profile-follow feature is disabled.

Other real consumers already exist in:

- Resources/System Monitor popup;
- Settings.

So an ordinary session that never enabled fan control should not need the helper status probe solely because the shell started.

**Lossless direction:**

- keep ThinkFan resident for the whole session when `powerProfiles.fanControl.enabled` is true;
- when false, allow Settings/Resources to instantiate/refresh it on demand;
- retain a lightweight shell config hook that instantiates it if fan-control becomes enabled through a config change later in the session.

Do not reduce polling cadence or remove managed-control detection when the feature is actually enabled.

### 26.5 Default Battery visibility pulls TlpService charge-limit detection into startup even though charge care is disabled — ADAPT / P1 strong lossless candidate

Shipped defaults have:

- Bar `modules.battery = true`;
- `battery.chargeLimit.enable = false`.

`Battery.qml` provides ordinary UPower telemetry, but also unconditionally re-exports many `TlpService` properties:

- available/supported/adjustable;
- current limit/state;
- managed status;
- limit kind/range/step/allowed values.

That direct dependency materializes `TlpService` whenever Battery materializes.

`TlpService.Component.onCompleted` immediately runs:

`/usr/libexec/inir-battery-charge-limit --status`

even though normal battery percentage/charging telemetry does not consume charge-limit capability.

The helper is intentionally substantial because it must detect TLP/vendor/plugin capability correctly. The optimization must not weaken it.

**Lossless direction:**

- separate normal UPower Battery state from charge-limit capability/status ownership;
- demand-load or demand-refresh charge-limit status when:
  - `battery.chargeLimit.enable` is true;
  - Battery charge-care UI opens;
  - TLP Settings opens;
  - or another explicit charge-limit consumer requests it.

Disabled-default Bar battery telemetry should not pay the TLP/helper probe.

### 26.6 Audio startup mixes critical microphone restoration with Settings-only sound catalog enumeration — ADAPT / P1

`DeviceStatePersistence` legitimately needs Audio microphone state early for persisted mute restoration.

Current `Audio.Component.onCompleted` does both:

1. `_refreshMicState()`;
2. `themeSoundsProc.running = true`.

`themeSoundsProc` runs:

`sh -c 'ls .../stereo | sed ... | sort -u'`

to build `Audio.themeSounds`.

Repository search shows `Audio.themeSounds` is consumed by `SoundPicker.qml`, and SoundPicker is currently used by the classic and Waffle Settings pages.

No ordinary Bar/audio-state consumer needs the complete sound-name catalog.

**Lossless direction:**

- preserve early microphone-state refresh;
- expose an idempotent `ensureThemeSoundsLoaded()` / equivalent demand hook;
- enumerate theme sounds only when a SoundPicker/settings consumer becomes resident;
- after first demand, continue to refresh the catalog when `audioTheme` changes.

This removes one shell pipeline from normal startup without changing sound playback or settings results.

### 26.7 PowerProfilePersistence startup probe can be state-gated when there is no restore candidate — INVESTIGATE / P1-low

`shell.qml` force-instantiates `PowerProfilePersistence` as startup-critical.

Current service immediately probes TLP-PD ownership once Config is ready:

`sh -c 'systemctl is-active --quiet tlp-pd.service || systemctl is-enabled --quiet tlp-pd.service'`

This guard is correctness-critical before restoring a persisted power profile: shell-owned restore must not fight `tlp-pd`.

However shipped defaults have:

- `powerProfiles.restoreOnStart = true`;
- `powerProfiles.preferredProfile = ""`.

With an empty preferred profile there is nothing to restore, but the ownership process still runs.

A lossless experiment can make startup probing conditional on actual need:

- if a persisted preferred profile exists and restore is enabled, probe immediately before restore;
- otherwise defer ownership discovery until the first relevant PowerProfiles change or Settings/feature demand;
- preserve the existing stale-ownership re-probe and 30-minute safety net after the service begins ownership tracking.

This needs a state-machine test because the service also uses ownership knowledge to decide whether later profile changes should be persisted.

### 26.8 SystemInfo always resolves GECOS display name even though startup username is already seeded — INVESTIGATE / P2

`SystemInfo.username` is seeded from `$USER`, which is enough for startup path construction such as avatar locations.

Nevertheless its one-shot startup timer calls `refreshIdentity()`, which normally launches:

`getent passwd $USER`

to obtain the GECOS display name.

Direct `displayName` consumers are profile/lock/dashboard/settings/user-card surfaces, not the basic startup path needed to derive the username.

Lossless direction:

- keep username seeded immediately;
- preserve `getent` as the authoritative NSS-aware display-name resolver;
- run display-name resolution on first profile/lock/settings consumer or in a later noncritical tier.

This is small and should only be implemented if startup process traces show value.

### 26.9 Persistent timer state is not a high-frequency write problem — CLOSED

A targeted audit checked whether `TimerService` caused `states.json` serialization every stopwatch tick.

It does not.

- Stopwatch’s 33 ms timer updates the in-memory `stopwatchTime` property.
- Persistent timestamp/lap/running fields are mutated on start/pause/reset/lap transitions, not every tick.
- `Persistent.qml` debounces adapter writes for 100 ms and writes asynchronously.

Do not add stopwatch persistence to the optimization backlog.

### 26.10 Niri event path is already substantially demand/batch optimized — P2 only if profiler points there

Current `NiriService`:

- consumes the native event stream;
- batches window publication at 50 ms normally / 200 ms in GameMode;
- distinguishes `windowOrderChanged` from title-only churn;
- skips nonessential event types during GameMode;
- `CompositorService` computes sorted foreign-toplevel state only while a sorting consumer lease exists.

One residual cost is that a batched update still calls `sortWindowsByLayout(_pendingWindows)` even when `_windowOrderDirty` is false, so title/focus-only batches can still map/enrich/sort the full list.

This is a plausible small lossless optimization, but window counts are normally low and the current batching is already strong. Keep it below the startup/Config/Abyss candidates unless a compositor-event profile shows it materially hot.

### 26.11 Booru warm-preview shell guard is the same pattern as Favicon, but lower priority

For several providers, `BooruImage.qml` sets `manualDownload` and runs a Bash command of the form:

`mkdir -p ... && [ -f preview ] || curl ...`

A warm preview therefore still creates a Bash process even though curl is skipped.

This is lossless process churn, but it is limited to specific sidebar providers and is less broadly reused than Favicon/MediaArtworkResolver. Keep it P2 unless actual wallpaper/anime browsing traces show high process counts.

### 26.12 Startup measurement bundle should now distinguish required state from optional work

Add explicit attribution for these source owners to the existing T+0..T+8 trace:

- GameMode singleton construction versus Niri animation rewrite/reload;
- ordinary MPRIS state versus MPD probe and `pw-dump`;
- ThinkFan disabled/default status helper;
- Battery UPower state versus TlpService charge-limit helper;
- Audio mic-state restore versus theme-sound catalog enumeration;
- PowerProfilePersistence ownership probe with/without a preferred profile;
- SystemInfo env/file identity versus `getent` display-name lookup.

The acceptance question is not “can the process be removed?” but:

> Does first-frame/session correctness require this exact side effect at this exact time?

Where the answer is no, defer or demand-gate the side effect while keeping the state owner intact.

### 26.13 Revised candidate tiers after round 12

**Highest confidence lossless / implementation candidates after measurement:**

- waves-disabled `Wave.setMass()` gating;
- Compact Sidebar hidden Equalizer/CAVA demand gating;
- Favicon warm-cache shell avoidance;
- MediaArtworkResolver trusted-cache/in-flight dedup;
- WindowPreview Fish→Bash wrapper elimination;
- ThinkFan default-disabled helper gating;
- Battery→TLP charge-limit capability gating;
- Audio Settings-only theme-sound enumeration gating.

**Strong profiling targets:**

- active Pyramid v2 JS allocation + aggregate record/uniform churn;
- global Config revision / `getNestedValue()` fan-out;
- MPRIS rebuilds on unrelated config changes;
- Background zone/custom-loader config fan-out;
- notification-history full serialization;
- startup external-theme process fan-out;
- MPRIS optional MPD/PipeWire enrichment timing.

**Lower-priority measurement candidates:**

- PowerProfilePersistence empty-restore probe;
- SystemInfo GECOS lookup;
- Niri title-only re-sort;
- Bar Media offscreen PlayerControl timers;
- Booru warm-preview shell guard.

No runtime implementation is authorized by this handoff.

## 27. Audit round 13 — Settings interaction-signal feedback writes (2026-09-29)

This round is documentation/research only. No runtime source was changed.

The round follows the broad static stop rule: it records one newly isolated cross-cutting source of Config churn that directly amplifies the already-known global `Config.revision` / `configChanged` fan-out. It does not reopen unrelated static archaeology.

### 27.1 Settings property-change handlers can write Config for programmatic state changes — ADAPT / P1 strong lossless candidate

Hadalis already contains the right interaction-only pattern in several places, but it is not used consistently.

Representative Classic Bar code currently does:

```qml
ConfigSpinBox {
    value: Config.options?.bar?.height ?? 40
    onValueChanged: Config.setNestedValue("bar.height", value)
}

SettingsSwitch {
    checked: Config.options?.bar?.borderless ?? true
    onCheckedChanged: Config.setNestedValue("bar.borderless", checked)
}
```

Representative Waffle Bar code does the same with `WSettingsSwitch` and `WSettingsSpinBox`.

This matters because QML property-change handlers are not user-action signals. A binding update, initialization/clamping/normalization, or another programmatic assignment can emit the property change and run the Config write path.

The repository already demonstrates the safer contract:

- `ConfigSwitch.qml` exposes `toggledByUser(bool checked)` and emits it only from its click path;
- direct `StyledSpinBox` consumers in Desktop Widgets already use Qt Quick Controls' `onValueModified`, which is interaction-only;
- `WSettingsSlider.qml` already exposes a `moved()` signal from the underlying slider interaction.

However:

- file-level search finds the `ConfigSwitch` + `onCheckedChanged` + `Config.setNestedValue` pattern across at least eight Classic Settings files;
- the analogous `WSettingsSwitch` pattern appears across at least thirteen Waffle Settings files;
- `ConfigSpinBox` + `onValueChanged` + Config writes co-occur across at least nineteen Classic Settings files;
- `WSettingsSpinBox` + `onValueChanged` + Config writes co-occur across at least eleven Waffle Settings files.

These are file-level coverage counts, not a claim that every matching handler is semantically wrong. Some guarded handlers intentionally react to programmatic state and must be reviewed individually.

The amplification is larger than disk I/O alone. `Config.setNestedValue()` currently performs, synchronously for every call:

1. nested adapter/mirror mutation;
2. `fileWriteTimer.restart()`;
3. global `_bumpRevision()`;
4. global `configChanged()`.

The 50 ms file-write debounce can coalesce physical writes, but it does **not** coalesce the revision bump or `configChanged` fan-out. Therefore a Settings page that writes because a bound control merely synchronized its state can trigger the global invalidation paths documented in §25.7–25.9 even when no user setting actually changed.

This also explains why fixing the source event is preferable to optimizing each downstream consumer first.

**Lossless direction:**

- Classic `SettingsSwitch` / `ConfigSwitch`: migrate persistence handlers from `onCheckedChanged` to the existing `onToggledByUser` where persistence is intended only for user interaction.
- Classic `ConfigSpinBox`: forward the underlying `SpinBox.valueModified()` as an explicit wrapper signal, then migrate persistence handlers from `onValueChanged` to that interaction signal where appropriate.
- Waffle `WSettingsSwitch` and `WSettingsSpinBox`: add explicit user-modified signals emitted only by their click/increment/decrement interaction paths, then migrate persistence handlers.
- Waffle sliders: prefer the already-existing `moved()` contract over `onValueChanged` for persistence.
- Preserve guarded/property-change handlers where programmatic changes are intentionally part of the feature contract.
- Do **not** globally replace every `on*Changed` mechanically.

Qt's own QML/Qt Quick guidance recommends explicit interaction signals over value-change signals for backend writes because value-change handlers can fire from automatic/programmatic changes and create event cascades. Qt Quick Controls `SpinBox.valueModified()` specifically exists for touch/mouse/wheel/key user modification.

### 27.2 Central same-value suppression is secondary, not the first fix — INVESTIGATE / P2

`Config.setNestedValue()` currently bumps revision and emits `configChanged` even when a caller supplies a value equal to the current value.

A central no-op guard could catch residual duplicate writes, but it is a broader semantic change than fixing the Settings interaction source. Some call sites may currently (intentionally or accidentally) use a same-value write as a refresh/notification pulse.

Therefore:

1. first migrate clearly user-owned controls to interaction-only signals;
2. instrument Config call counts and global revision/configChanged counts while opening Settings pages and editing controls;
3. only then audit whether a primitive/safely-comparable same-value fast path can be introduced without breaking refresh semantics.

Do not use JSON stringify/deep comparison on every Config write as a supposed optimization; that can merely exchange binding fan-out for serialization cost.

### 27.3 Measurement acceptance for this candidate

Add a focused Settings trace before implementation and repeat it after the interaction-signal migration:

- open Classic Settings Bar/Interface/Background pages without changing anything;
- open the equivalent Waffle Settings pages without changing anything;
- count `Config.setNestedValue(s)`, revision increments and `configChanged` emissions;
- then modify one spinbox, switch and slider deliberately and confirm exactly the intended persistence events occur;
- verify the saved config bytes and visible Settings state are identical to baseline after the same user actions;
- include a page containing guarded handlers (Themes/Battery/Ai) to ensure intentional programmatic synchronization is not removed.

**Expected result for a successful lossless patch:** opening/synchronizing a Settings page should not itself create unrelated Config persistence/invalidation traffic; deliberate user edits should still persist immediately with the existing 50 ms disk-write coalescing behavior.

### 27.4 Priority interaction with rounds 11–12

Promote this candidate into the first Config-focused measurement batch, ahead of redesigning `getNestedValue()` revisions.

Reason: it attacks avoidable invalidation at the source and can reduce all of these simultaneously:

- global `Config.revision` reevaluation;
- `Config.configChanged` consumers such as MPRIS/Background/Workspaces;
- file-write timer restarts;
- Settings feedback loops.

Revised Config order:

1. **P1 — measure and migrate Settings persistence to interaction-only signals where semantics are user-owned;**
2. **P1 — profile remaining global `getNestedValue()` revision fan-out after that noise is removed;**
3. **P1/P2 — narrow expensive `configChanged` consumers such as MPRIS/Background if still material;**
4. **P2 — consider central same-value suppression only after call-site semantics are audited.**

No runtime implementation is authorized by this handoff.

## 28. Audit round 14 — warm-cache delegate processes and residency revalidation (2026-09-29)

This round is documentation/research only. No runtime source was changed.

### 28.1 CliphistImage still launches Bash on every first-visible image delegate even when the decoded file is already warm — ADAPT / P1-low to P2

`modules/common/widgets/CliphistImage.qml` correctly avoids eager decode storms by waiting until the image delegate becomes visible, and it publishes newly decoded output through a per-process temporary file plus atomic `mv`.

However, first visibility still does:

```qml
decodeImageProcess.running = true
```

and the process always launches Bash whose first operation is effectively:

```sh
if [ -s <session decoded path> ]; then
    exit 0
fi
```

Therefore a decoded image that is already present in `Directories.cliphistDecode` still pays one child-process launch for every new `CliphistImage` instance.

Live consumers include:

- Overview search clipboard-image results;
- classic Clipboard rows;
- Waffle Clipboard rows.

The shared decoded path is keyed by the numeric cliphist entry id, and writers already publish atomically. That makes this the same lossless warm-cache ownership class as Favicon and MediaArtworkResolver, but with a clipboard-specific cache.

**Lossless direction:**

- move known-decoded ownership into `Cliphist` or another shared lightweight resolver;
- once a decoded path has been verified/published in the session, new delegates should consume it without spawning Bash;
- deduplicate an in-flight decode for the same cliphist id so two surfaces cannot both start the same decode work;
- preserve the existing atomic temp-file publication and image-byte behavior.

Acceptance target: after prewarming decoded clipboard images, repeatedly recreating/scrolling image delegates should produce **zero decode/check child processes** for already-known entries.

### 28.2 ThumbnailImage eliminated per-item magick/ffmpeg generation, but a warm disk cache can still create one `test -f` process per delegate — ADAPT / P1-low

The earlier audit correctly closed the expensive thundering-herd generator problem: `ThumbnailImage.qml` now sends generation work through Wallpapers' shared/serialized thumbnail queue.

A narrower warm-cache cost remains.

For a thumbnail not yet present in the in-memory `Wallpapers._knownThumbnailOutputs` map, every `ThumbnailImage` instance starts its own `Process`:

```qml
_thumbnailCheckProc.command = ["test", "-f", targetPath]
_thumbnailCheckProc.running = true
```

Only after that process succeeds does the delegate call `Wallpapers.rememberThumbnail()`.

Consequences:

- the first gallery/picker open in a new shell session can launch many tiny `test` processes even when the thumbnail disk cache is already fully warm from a previous session;
- the shared known-output map prevents repeat checks only **after** each path has been individually discovered in the current session;
- generation itself is serialized, but existence discovery is still per delegate.

Current QML consumers span multiple wallpaper/settings surfaces, including Quick Wallpaper, Wallpaper Directory/Coverflow/Skew/Gallery and Waffle quick-wallpaper UI.

**Lossless direction:**

- centralize disk-cache discovery in `Wallpapers` rather than giving every visual delegate its own existence process;
- prefer one directory/batch discovery or another shared bounded existence mechanism that seeds `_knownThumbnailOutputs`;
- keep the existing source path/hash semantics and current thumbnail-generation queue;
- do not reintroduce parallel magick/ffmpeg generation.

Acceptance target: with a fully prewarmed thumbnail cache, opening a directory containing N visible/cached thumbnails should not create O(N) `test` child processes.

### 28.3 The old five-minute `retainAfterUse` concern is stale at current HEAD — CLOSED for general panel loaders

A revalidation was necessary because GitHub code-search results can still surface an older indexed commit containing:

- `retainAfterUse`;
- `retainIdleMs: 5 * 60 * 1000`.

Current live `modules/ii/ShellIiPanelsImpl.qml` and `modules/waffle/ShellWafflePanelsImpl.qml` no longer use that five-minute policy for ordinary on-demand panels.

The current contract is:

- become resident when opened;
- remain resident only through a short close grace (roughly 250–300 ms, or animation-derived equivalent);
- unload after the close/settle window.

Therefore do **not** create a new optimization project around five-minute retention for Overview, Wallpaper Selector/Launcher/Coverflow, Start Menu or Action Center based on stale search-index snippets.

### 28.4 Dashboard is the deliberate residency exception; hidden heavy work is already substantially gated — P2 memory/reactivity measurement only

The detached ii Dashboard intentionally becomes session-resident after first use:

```qml
keepLoaded: (Config.options?.dashboard?.keepLoaded ?? false) || used
```

This is not the removed generic five-minute retention policy. It exists to keep the fullscreen layer-shell surface mapped and avoid compositor map/unmap effects masking the Dashboard's own slide transition.

Current hidden-state guards are substantial:

- `PanelWindow.updatesEnabled` drops after the exit animation;
- Dashboard content becomes invisible after the exit slide;
- `DashSystem` uses `ResourceUsageMonitor`, whose lease sleeps when the target/native window is hidden;
- `DashWeather`'s 30 s timer runs only while visible;
- `DashMedia` gates its active media/equalizer work with `presentationActive`;
- `DashGithub` refreshes only when visible and has a one-hour cache.

Residual cost after close is therefore primarily retained memory plus reactive model trees such as notification/calendar/agenda state, not an obvious fixed-rate CPU/GPU loop.

Keep Dashboard residency as **P2 measurement only** unless heap/VRAM or notification/calendar mutation traces show material hidden cost. Do not blindly unload it and reintroduce the compositor transition regression.

### 28.5 Add two process-count scenarios to the measurement bundle

Alongside Favicon and MediaArtworkResolver warm-cache tests, add:

1. **Cliphist image warm cache:** predecode several image entries, recreate/scroll the corresponding delegates, count Bash/cliphist/native-dispatch processes.
2. **Thumbnail warm disk cache:** pre-generate a wallpaper directory's thumbnails, restart the shell, open the relevant picker/gallery and count `test` processes before any new thumbnail generation is needed.

These tests distinguish “heavy generation was fixed” from “warm cache is actually process-free.”

No runtime implementation is authorized by this handoff.

## 29. Audit round 15 — desktop auto-placement startup work, Niri route dedup and Pyramid overlap delta (2026-09-29)

This round is documentation/research only. No runtime source was changed.

The live branch moved from the previous audit checkpoint \`c17cd56b85a7fd9b92f69838ee0a4557265626bb\` to \`673f15f786aa9b1df8409eb653ecb3b19804f4ff\` while research continued. The four-commit runtime delta is confined to Pyramid v2 tangent-overlap grouping/transactions plus tests/docs. That delta was re-read before the broader findings below.

### 29.1 Desktop clock auto-placement is a real early-session OpenCV path once a wallpaper is configured — PROMOTE / P0 trace, P1 lossless candidate

Round 5 (§19.6) classified \`least_busy_region.py\` as an explicit auto-placement path rather than a periodic idle loop. That remains true, but the priority assessment was incomplete.

Current defaults also say:

- \`background.widgets.clock.enable = true\`;
- \`background.widgets.clock.placementStrategy = "leastBusy"\`.

The pristine default \`background.wallpaperPath\` is empty, so a brand-new untouched config does not run the analysis. However, once a normal user has selected/persisted a wallpaper, the critical Background tree creates one ClockWidget per eligible output and the clock's inherited \`AbstractBackgroundWidget\` resolves to \`leastBusy\` on every shell session.

This matters because Abyss loads \`Background.qml\` from the critical family host, not from the deferred Tier-3/Tier-4 service wave. The auto-placement helper can therefore compete with first-paint/startup work before the later startup phases measured in §24/§26.

The current path is:

\`ClockWidget -> AbstractBackgroundWidget.refreshPlacementIfNeeded() -> least-busy-region-venv.sh -> Python -> OpenCV/NumPy\`.

This is not a reason to remove least-busy placement. It is a reason to add it to the P0 startup process/CPU trace.

### 29.2 The least-busy request path has no request signature/in-flight serialization and can restart equivalent work — ADAPT / P1

\`AbstractBackgroundWidget\` has several independent paths that can request placement analysis:

- \`Component.onCompleted\` synchronizes \`placementStrategy\` and schedules \`applyPlacementFromConfig()\`;
- \`onPlacementStrategyChanged\` schedules the same apply path;
- wallpaper changes restart a 500 ms placement debounce;
- width/height/safe-area changes restart a 120 ms geometry debounce, which calls \`refreshPlacementIfNeeded()\` for auto-placement.

For \`leastBusy/mostBusy\`, \`refreshPlacementIfNeeded()\` currently does:

\`\`\`qml
leastBusyRegionProc.running = false
leastBusyRegionProc.running = true
\`\`\`

There is no:

- last-completed request signature;
- in-flight request signature;
- queued-latest request;
- result-generation check.

The neighboring color-only path already contains an explicit warning that stop/restart did not reliably prevent the old result from landing, and it therefore serializes work with \`_colorRerunQueued\` plus launch-time geometry snapshots.

Quickshell's Process contract says setting \`running = false\` sends SIGTERM to the tracked process. The tracked executable here is the Bash wrapper; the wrapper starts Python as a child rather than replacing itself with \`exec\`. Therefore the least-busy path should not assume that toggling the wrapper's \`running\` state is a complete cancellation protocol for the Python/OpenCV work.

**Lossless direction:**

1. define an exact request signature from wallpaper identity/revision, screen dimensions, widget dimensions, padding, screen mode and least/busiest mode;
2. if the same signature is already complete, reuse the result;
3. if a request is running, keep only the newest distinct pending signature instead of stop/restart churn;
4. apply a result only if its launch signature still matches the desired signature;
5. if cancellation is retained, make the wrapper/process ownership unambiguous (for example by ensuring the tracked process is the actual Python worker), but serialization/dedup is still preferred.

Acceptance target: a stable configured wallpaper + stable clock geometry should produce one analysis per unique signature, not one per QML initialization trigger.

### 29.3 One least-busy invocation decodes/resizes the same wallpaper three times — CONFIRMED static duplication / P1

\`scripts/images/least_busy_region.py\` currently performs three separate image-read/scale paths in the normal least-busy mode:

1. \`find_least_busy_region()\`:
   - \`cv2.imread(..., IMREAD_GRAYSCALE)\`;
   - resize/crop;
   - float64 conversion;
   - two integral images;
   - sliding-window variance search.
2. \`get_dominant_color()\`:
   - reads the image again in color;
   - resizes/crops again;
   - runs deterministic K-means on the selected region.
3. \`get_region_brightness()\`:
   - reads the image again in grayscale;
   - resizes/crops again;
   - computes mean/std-dev.

The output is deterministic for a fixed request (the K-means RNG is explicitly seeded), so there is no semantic need for three independent decodes of unchanged bytes.

**Lossless direction:**

- load/resize/crop one canonical color image once;
- derive grayscale from that already-resized image;
- reuse the same color/grayscale arrays for variance search, dominant color and brightness;
- preserve the current interpolation, crop rules, stride, K-means seed and JSON values within an agreed numerical tolerance.

Do not estimate a percentage from source alone. Benchmark representative 1080p/1440p/4K wallpapers before and after any authorized implementation.

### 29.4 Background wallpaper-size cache is bounded but lacks cross-output in-flight dedup — P2

\`Background.qml\` already has a shared bounded 64-entry \`_wallpaperSizeCache\` for \`magick identify\` results. This correctly makes later requests for a known wallpaper process-free.

A narrower multi-output startup race remains:

- each Background variant owns its own \`getWallpaperSizeProc\`;
- each checks the shared cache;
- if two outputs request the same uncached wallpaper before either result lands, both can launch \`magick identify\`;
- the shared cache is populated only after one process finishes.

This is much smaller than the OpenCV auto-placement path, but it is the same shared-cache ownership pattern as the warm-cache candidates in §28.

Lossless direction if traces show it: add a shared in-flight registry/fan-out at the Background scope so one identify request publishes the dimensions to every waiting output.

### 29.5 Niri output startup query is NOT currently safe to remove; wallpaper picker focused-output query is a narrower steady-state dedup candidate

A source-only read initially suggested that \`NiriService.fetchOutputs()\` on event-stream connection might be redundant because niri documents its event stream as providing complete initial state.

Further verification closes that idea for the current compatibility target:

- the public \`niri_ipc::Event\` schema currently documents workspace/window/keyboard/overview/config/cast events but no \`OutputsChanged\` variant;
- independent niri 26.04 probing likewise reports no output event in the stream;
- Hadalis needs \`niri msg -j outputs\` for output geometry/scale used by fullscreen detection and display-scale state.

Therefore **do not remove** the initial \`fetchOutputs()\` process based on the generic “complete state” wording. The existing \`OutputsChanged\` handler should be treated as compatibility/future-event support unless the deployed niri version is proven to emit it.

A separate route remains worth adapting:

\`WallpaperSelectorRouter._openOnFocusedMonitor()\` launches:

\`niri msg -j focused-output\`

for every Niri picker open that lacks an explicit monitor.

But Hadalis already maintains \`NiriService.currentOutput\` from the focused workspace and exposes \`GlobalStates.focusedScreen\` from that value. This gives a safe lossless shape:

- use the already-live \`NiriService.currentOutput\` / \`GlobalStates.focusedScreen\` when it is non-empty/valid;
- retain the one-shot \`focused-output\` process only as a readiness/failure fallback.

Acceptance target: after NiriService has reached normal steady state, repeated Wallpaper Selector/Launcher/Coverflow opens should spawn zero \`niri msg focused-output\` children while selecting the same output as before.

### 29.6 ii SidebarHost still has a separate five-minute content residency policy; hidden fixed-rate work is mostly gated — P2 memory/reactivity only

Round 14 correctly closed the old generic five-minute \`retainAfterUse\` policy for ordinary on-demand panels. A separate policy still exists inside \`modules/sidebar/SidebarHost.qml\`:

\`contentIdleUnloadMs = 300000\`

After an ii sidebar has been presented once, its content tree can remain resident for five minutes after close.

This does **not** apply to the native Abyss sidebar host: \`AbyssBodyHost\` unloads \`AbyssLeftContent/AbyssRightContent\` after semantic close + reveal completion unless content is explicitly resident.

Targeted hidden-work checks on the ii sidebar are reassuring:

- \`SidebarHost\` disables window render updates after the exit settle;
- SysMon's \`ResourceUsageMonitor\` lease is gated by \`GlobalStates.sidebarRightOpen\`;
- LocalMusic CAVA is gated by sidebar open state;
- News/Anime loading spinners are gated by sidebar open state;
- the right-sidebar entrance cascade is finite and completes once.

Residual cost is therefore primarily retained object/model memory and reactive bindings, not a newly found fixed-rate CPU loop.

Do not shorten the five-minute policy blindly: unloading can affect local UI state and reopen latency. Measure heap/PSS and reopen latency with representative heavy tabs before deciding.

One related P2 interaction note: \`SidebarLeftContent\` keeps current + previous + next SwipeView loaders active. If an adjacent enabled tab is News or Anime Schedule, its \`Component.onCompleted\` network fetch can occur before the user explicitly selects that tab. If network/process traces show this matters, separate “preload visual tree” from “activate remote fetch” rather than removing adjacent-page preload outright.

### 29.7 New Pyramid tangent-overlap grouping does not create a new material per-frame regression — CLOSED pending profile

The four-commit delta to \`673f15f7...\` changes Pyramid grouping from near-identical anchor centers to transitive tangent overlap/proximity neighborhoods.

Static cost changes include:

- \`AbyssBodyPlacement._orderedRequests()\` now builds a small union-find over open requests with an O(n²) pair comparison;
- \`AbyssPyramidCoordinator\` builds transitive neighborhood candidate sets during entry/close/reopen transaction work;
- descriptors/cloned placement/record objects remain small JS allocations.

This is not currently a reason to optimize the new grouping:

- allocator requests use full resting records rather than reveal-progress geometry;
- the grouping work is tied to semantic placement/transaction changes, not the 60/120 Hz reveal fraction itself;
- live popup/body counts are small;
- the already-known per-frame risk remains \`AbyssBodyHost.rawPresentationRecord\` / geometry interpolation and the downstream records/uniform/wave cascade from §23–§25.

Add the new grouping functions to the multi-popup QML profile, but do not trade away the new transitive-overlap correctness for speculative micro-optimization.

### 29.8 Revised near-term evidence order

Promote the desktop region analyzer into the existing startup measurement bundle.

1. **Startup T+0..T+8 process/CPU/PSS trace**
   - count \`least-busy-region-venv.sh\` and Python/OpenCV children per output;
   - record start/end times and overlap with first paint, theming, MemoryPressure and Tier 3/4;
   - repeat with one, two and three outputs where available;
   - compare unchanged warm wallpaper vs wallpaper switch.
2. **Region-analysis isolated benchmark**
   - representative 1080p, 1440p and 4K images;
   - record wall time, CPU time and peak RSS;
   - count image decodes/resizes per request;
   - test repeated identical QML triggers and verify dedup target.
3. **Niri wallpaper-picker process count**
   - after event-stream/workspace state is ready, repeatedly open each picker mode and count \`niri msg focused-output\` children.
4. Keep the existing Config/Abyss/notification/warm-cache scenarios from §§25–28.

The highest-confidence new static optimization in this round is **not** a rendering trick: it is eliminating duplicate/restarted heavyweight wallpaper-region analysis while preserving identical placement/color semantics.

No runtime implementation is authorized by this handoff.

## 30. Audit round 16 — region-analysis request ownership, unused outputs and exact-lossless decode rules (2026-09-29)

This round is documentation/research only. No runtime source was changed.

There was no runtime delta after round 15: research continued from \`d497cc7108622108bd0ee987709e2f8ad9c40be6\`.

This round deepens the desktop region-analysis finding and corrects one overly aggressive optimization direction from §29.3.

### 30.1 Default ii auto-placement computes color/brightness that QML deliberately discards — CONFIRMED static waste / P1

The default ii desktop clock is:

- enabled;
- \`placementStrategy = "leastBusy"\`;
- loaded once per allowed output through \`Background.qml\`.

At the same time, \`Config.background.widgets.adaptColorsToWallpaperPosition\` defaults to **false** and the Settings UI describes it as an explicit opt-in.

For every least/most-busy result, \`AbstractBackgroundWidget.qml\` does:

- always consume \`center_x/center_y\` for placement;
- consume \`dominant_color\`, \`brightness\` and \`brightness_std\` **only when** \`positionColorAdaptationEnabled\` is true.

But \`least_busy_region.py\` unconditionally performs all three stages:

1. grayscale decode/resize + variance search;
2. color decode/resize + K-means dominant color;
3. second grayscale decode/resize + mean/std brightness.

Therefore the normal default ii path pays for stages 2 and 3 even though their output is thrown away by QML.

This is stronger than a profile hypothesis: the extra work is statically unnecessary for the default semantic result.

**Lossless direction:**

- make the request declare which outputs are required;
- for ii auto-placement with \`positionColorAdaptationEnabled === false\`, request **position only**;
- the worker then performs exactly the existing grayscale placement search and returns the same center/variance without K-means or brightness work.

Operation-count target for this path:

- image decode/resize passes: **3 -> 1**;
- K-means calls: **1 -> 0**.

This is an operation-count reduction, **not** a claim of 66% total wall-time improvement. Imports, variance scanning and process startup remain and must be measured separately.

### 30.2 Waffle has an additional unused-output split — P1 when Waffle clock is enabled

The Waffle clock is disabled by default, so it is not part of the default startup cost. When enabled, however, it uses the same worker and currently consumes only:

- \`center_x/center_y\`;
- \`dominant_color\`.

It never consumes \`brightness\` or \`brightness_std\`.

Therefore:

- Waffle \`colorMode = "adaptive"\`: brightness/std computation is always unnecessary;
- Waffle \`colorMode = "accent"\` or \`"plain"\`: dominant color is also unused, so the request can be position-only.

The worker API should therefore express required products rather than treating “least busy” as an inseparable position+color+brightness bundle.

### 30.3 Correction to §29.3: do NOT derive grayscale from the color decode under an exact-lossless requirement

Section 29.3 proposed loading one canonical color image and deriving grayscale from it.

That is too aggressive for this project's “lossless” constraint.

OpenCV documents that \`IMREAD_GRAYSCALE\` may use a codec's internal grayscale conversion and that its pixel values can differ from applying \`cvtColor()\` to a color decode.

The current placement algorithm and brightness calculation both use \`cv2.imread(..., IMREAD_GRAYSCALE)\`. Replacing that with color decode + \`cvtColor\` could therefore alter:

- local variance;
- tie/order of least-busy candidates;
- selected center;
- brightness/std.

**Exact-safe consolidation when color is required:**

1. keep one \`IMREAD_GRAYSCALE\` decode;
2. resize/crop it once;
3. reuse that exact grayscale array for both variance search and selected-region brightness/std;
4. keep one color decode/resize for K-means.

This reduces the normal position+color+brightness path from **3 decode/resize passes to 2** while preserving the existing grayscale conversion route.

Do not derive brightness directly from the search's integral variance if exact output matching is required unless corpus tests prove the rounded JSON is identical. Reusing the selected slice and the existing \`np.mean/np.std\` operations is the safer contract.

### 30.4 The current stop/restart pattern does not own the actual heavy worker — CONFIRMED ownership defect / P1

Both ii and Waffle currently restart region analysis with:

\`\`\`qml
leastBusyRegionProc.running = false
leastBusyRegionProc.running = true
\`\`\`

Quickshell documents that setting \`Process.running = false\` sends SIGTERM to the process it tracks.

The tracked process here is \`least-busy-region-venv.sh\`, not Python. The wrapper:

1. activates the venv;
2. launches \`python3 least_busy_region.py ...\` as a normal foreground child;
3. runs \`deactivate\` after Python exits.

It does **not** \`exec\` Python.

This is exactly the wrong ownership shape for cancellation. Sending SIGTERM to the Bash wrapper does not establish that the Python/OpenCV child received the same signal. The source already contains empirical evidence of this class of bug immediately beside the color-only path: its comment records that \`running=false; running=true\` did not discard the old analysis and stale output could still land.

The repository already uses the safer pattern in \`scripts/thumbnails/thumbgen-venv.sh\`, where the wrapper ends with \`exec ... python3 ...\`.

**Lossless direction:**

- after resolving/activating the venv, replace the wrapper with the Python worker using \`exec\`;
- no \`deactivate\` is needed after \`exec\` because the wrapper process no longer resumes;
- still add request serialization/stale-result rejection: correct process ownership makes cancellation reliable, but deduplication is preferable to repeatedly killing useful work.

Acceptance target: cancelling/replacing a region request leaves no old Python/OpenCV worker consuming CPU after the tracked Process changes generation.

### 30.5 Least-busy results are not generation-checked; current properties can be mixed with old output — correctness prerequisite for optimization

The color-only path snapshots:

- x/y;
- widget width/height;
- screen width/height;
- wallpaper path;

and rejects a stale result before applying it.

The least-busy path does none of this.

Its Process command is bound to current geometry/path properties, but a process already started continues with the arguments from its launch. If the wallpaper or geometry changes while it runs, \`onStreamFinished\` parses the old result and applies it against the **current** root state.

Potential mismatches include:

- old wallpaper result applied after a wallpaper change;
- old widget width/height center applied after content size changes;
- old screen dimensions applied after output geometry changes;
- old least/most-busy mode result applied after strategy changes.

The request-signature work from §29.2 is therefore not only a performance optimization. It is the correctness boundary required before caching/dedup can be trusted.

Required signature fields should include at least:

- effective wallpaper identity;
- screen width/height;
- requested region width/height;
- horizontal/vertical padding;
- fill/fit mode;
- least vs busiest;
- requested output products (position/color/brightness).

A completed result must be applied only to the matching generation/signature.

### 30.6 Main ii clock currently analyzes the global wallpaper path, not the effective per-output wallpaper — correctness blocker for cross-output caching

\`Background.qml\` correctly resolves the displayed wallpaper per output:

- when multi-monitor wallpaper mode is enabled, it reads \`WallpaperListener.effectivePerMonitor[monitorName]\`;
- it passes that through \`Wallpapers.internalPreviewFor()\`;
- the resulting \`bgRoot.wallpaperPath\` is the effective displayed source.

But \`ClockWidget\` does not receive that path.

Its inherited \`AbstractBackgroundWidget.wallpaperPath\` instead reads:

\`Config.options.background.wallpaperPath\`

(or the global thumbnail for video).

Consequently, on an ii multi-monitor setup with different wallpapers, clock auto-placement/color analysis can analyze the global wallpaper rather than the wallpaper actually displayed on that output.

Waffle does not have this mismatch: \`WaffleBackground.qml\` passes its resolved per-monitor \`wallpaperSourceRaw\`/thumbnail into \`WaffleBackgroundClock.wallpaperPath\`.

This must be fixed conceptually **before** introducing a shared cross-output cache. Otherwise a cache could make the wrong global-source result more efficiently reusable.

For future implementation, the request source should be the same effective preview/source that the corresponding Background instance paints.

### 30.7 One analysis owner can deduplicate identical multi-output requests, but only after §30.6

\`Background.qml\` is a \`Variants\` tree over \`Quickshell.screens\`, and the default ii clock is enabled for all outputs unless \`screenList\` restricts it.

Today every clock instance owns its own Process.

For outputs that resolve to the same:

- effective wallpaper;
- screen dimensions;
- widget dimensions;
- padding;
- least/busiest mode;
- requested output products;

the worker result is identical before output-local clamping. Those requests can safely share one in-flight/completed result.

Do **not** key this cache only by wallpaper path. Geometry and requested products are part of the semantic input.

A bounded in-session cache plus an in-flight map is lower-risk than a persistent disk cache because it needs no file-mtime/hash invalidation contract.

### 30.8 Intrinsic clock size is a real request trigger; Waffle has no debounce

Qt's Item/Loader sizing rules mean implicit content size can propagate to the loaded clock's effective width/height.

That matters because:

**ii \`AbstractBackgroundWidget\`:**
- every width/height change restarts a 120 ms geometry debounce;
- if placement is least/most-busy, the debounce launches region analysis;
- this is at least coalesced and is suppressed while the edit resize gesture is active.

**Waffle \`WaffleBackgroundClock\`:**
- \`width: implicitWidth\`, \`height: implicitHeight\`;
- \`onWidthChanged\` and \`onHeightChanged\` call \`refreshPlacementIfNeeded()\` immediately;
- there is no debounce;
- wallpaper, placement strategy, enable state, Config-ready and **every DesktopWidgetLayout.records change** also call the same function.

Because clock implicit size is derived from time/date/status text, style and font metrics, non-user semantic changes can become heavyweight OpenCV request triggers. A minute tick is not guaranteed to change width for every font/time string, so do not claim a fixed once-per-minute process rate without runtime evidence; however, any actual intrinsic-size change is sufficient to launch/restart the worker.

For Waffle, add a request debounce/signature guard before considering any deeper algorithm optimization.

### 30.9 Existing debug hooks are enough to measure request amplification without changing runtime code

The ii path already logs, when \`INIR_REGION_DEBUG=1\`:

- each \`refreshPlacementIfNeeded()\`;
- each least-busy result landing.

The existing \`background clockDebug*\` IPC methods can manipulate diagnostic clock state while preserving/restoring config.

Therefore the next runtime evidence pass does **not** require adding instrumentation first.

Suggested capture:

1. start the supervised shell with \`INIR_REGION_DEBUG=1\`;
2. record timestamps for \`[Region] ... refresh\` and \`LEAST-BUSY landed\`;
3. simultaneously record the Bash/Python process tree and CPU/RSS;
4. test 1/2/3 outputs;
5. test stable startup, wallpaper switch, font/style change, resize, lock/unlock and output geometry change;
6. explicitly check for Python workers that outlive the tracked Bash wrapper;
7. for Waffle, enable the clock only for the isolated scenario and count requests caused by width/height and unrelated \`DesktopWidgetLayout.records\` changes.

### 30.10 Revised implementation priority after static proof

If runtime implementation is later authorized, preserve this order:

1. **Correct request identity/source**
   - effective per-output wallpaper;
   - launch-time signature/generation;
   - stale-result rejection.
2. **Fix process ownership**
   - wrapper \`exec\` so the tracked PID is the heavy worker.
3. **Stop computing unused products**
   - default ii position-only;
   - Waffle skip brightness; position-only for non-adaptive color modes.
4. **Serialize/deduplicate**
   - one in-flight request per signature;
   - latest-distinct pending request;
   - bounded in-session result cache;
   - cross-output fan-out for identical signatures.
5. **Consolidate exact-safe image work**
   - one grayscale resize reused for placement + brightness;
   - separate color resize only when dominant color is required.
6. Only then benchmark whether the remaining Python sliding-window/import cost justifies vectorization, a persistent worker, or native implementation.

Do not start with a Rust rewrite. The current source contains cheaper, behavior-preserving eliminations before algorithm/language replacement becomes necessary.

No runtime implementation is authorized by this handoff.

## 31. Audit round 17 — Hyprland IPC fan-out and fuzzy-search cache lifetime (2026-09-29)

This round is documentation/research only. No runtime/source implementation is authorized.

### Snapshot

- Hadalis `dev` at the start of this round: `926005f6a5efc5fa3c58820c601cb089f7e8d3a8`.
- Delta from the previous handoff commit `d497cc7108622108bd0ee987709e2f8ad9c40be6` is one documentation-only commit touching only this handoff.
- Runtime/source therefore remained unchanged while the findings below were verified.

### 31.1 HyprlandData refreshes five independent IPC snapshots for every raw Hyprland event — CONFIRMED / P1

`services/HyprlandData.qml` connects to `Hyprland.rawEvent` and unconditionally calls `updateAll()`.

One `updateAll()` requests:

1. `hyprctl clients -j`
2. `hyprctl monitors -j`
3. `hyprctl layers -j`
4. `hyprctl workspaces -j`
5. `hyprctl activeworkspace -j`

Hadalis has already improved this over iNiR by serializing each query type and keeping only one queued rerun while that query is in flight, but that only bounds overlap. It does not remove semantically unrelated queries.

Hyprland's event socket distinguishes focused-window, workspace, monitor, layer, fullscreen, config and other event classes. A normal focus/window event therefore does not semantically require refreshing every one of the five snapshots.

This is a process-count optimization candidate, not a request to weaken event correctness.

### 31.2 The explicit `workspaces -j` snapshot currently has no repository consumer — CONFIRMED lossless elimination candidate / P1

The `HyprlandData` properties populated by `getWorkspaces` are:

- `workspaces`
- `workspaceIds`
- `workspaceById`

Repository-wide consumer tracing found no external reads of these properties. Their references are confined to `services/HyprlandData.qml` itself.

At the same time, the shell already imports and uses Quickshell's native Hyprland workspace model elsewhere (`Hyprland.workspaces`, `HyprlandMonitor.activeWorkspace`, etc.).

Therefore the current `hyprctl workspaces -j` process contributes no observable Hadalis result at this snapshot.

Exact acceptance requirement before any authorized removal:

- repository search remains consumer-free;
- no IPC/reflection contract exposes these fields externally;
- Hyprland overview/workspace/lock regression tests remain identical.

Operation-count effect inside the current HyprlandData event wave: **5 -> 4 child queries (20% fewer)** before considering any other candidate below.

### 31.3 `activeworkspace -j` duplicates already-live Quickshell Hyprland state for its only current consumers — HIGH CONFIDENCE / P1

`HyprlandData.activeWorkspace` currently has only two repository consumers:

- `modules/bar/ActiveWindow.qml`
- `modules/lock/Lock.qml`

The data they need is already exposed by Quickshell:

- `Hyprland.focusedMonitor`
- `Hyprland.focusedWorkspace`
- `HyprlandMonitor.activeWorkspace`

The bar only needs to know whether the focused monitor matches the bar's monitor and which workspace is active. The lock path needs the active workspace id when selecting floating windows.

Quickshell's documented Hyprland model exposes those values directly and the repository already relies on the same native monitor/workspace objects in Overview, Workspaces, Background, Region Selector and focused-screen routing.

Lossless direction:

- migrate those two consumers to the live native Hyprland objects;
- then retire the separate `hyprctl activeworkspace -j` snapshot.

Do not remove the process before verifying lock-time focus semantics and multi-monitor behavior.

Combined with §31.2, the steady event wave can become **5 -> 3 queries (40% fewer)**.

### 31.4 `layers -j` has one narrow consumer and is currently refreshed while that UI is absent — HIGH CONFIDENCE / P1

Repository-wide tracing found one external consumer of `HyprlandData.layers`:

- `modules/regionSelector/RegionSelection.qml`

The region selector uses the layer snapshot to exclude/target top layer surfaces.

No other normal bar/background/overview/sidebar path consumes `layers`, yet `HyprlandData.updateAll()` currently runs `hyprctl layers -j` on every raw Hyprland event for the entire session.

Lossless direction:

- make layer snapshot ownership consumer-aware;
- refresh when a region-selector consumer becomes active;
- while active, refresh only for layer/monitor/config events that can change the needed geometry;
- keep the last snapshot or clear it after the consumer is gone according to measured memory needs.

With the selector closed, combining §§31.2–31.4 reduces the current HyprlandData event wave from **5 queries to 2 (60% fewer child processes)** without yet touching the required clients snapshot or monitor raw metadata.

This percentage is an operation-count reduction for this service only, not a claim about total shell CPU.

### 31.5 `monitors -j` should not refresh on every event; most monitor state already exists natively — HIGH CONFIDENCE, needs compatibility matrix / P1

The explicit monitor JSON is used mainly by:

- `ActiveWindow.qml`
- `OverviewWidget.qml`

`ActiveWindow` only needs active-workspace/focus information that is already available on `HyprlandMonitor`.

`OverviewWidget` additionally consumes raw monitor fields such as `transform` and `reserved`, so the monitor query cannot simply be deleted from static evidence alone.

However Quickshell's `HyprlandMonitor` already exposes dedicated reactive properties for:

- id/name
- x/y
- width/height
- scale
- focused
- activeWorkspace

and exposes `lastIpcObject` plus `Hyprland.refreshMonitors()` for raw fields without dedicated properties.

Therefore the current policy — launching a separate `hyprctl monitors -j` after every window/focus/workspace/layer event — is broader than the actual semantic invalidation set.

Lossless directions to benchmark:

1. refresh monitor raw metadata only on monitor/layout/config/layer changes;
2. refresh on Overview presentation if raw `reserved/transform` freshness is required;
3. preferably reuse Quickshell's native monitor refresh/model rather than maintaining a second independent monitor snapshot when parity tests permit it.

If this query can be removed from ordinary window/focus events, the normal closed-region-selector wave becomes **5 -> 1 query (80% fewer)**, leaving only the raw client snapshot.

Do not claim the 80% path as implementation-safe until Overview transform/reserved behavior is tested across rotated outputs, reserved areas, monitor hotplug and config reload.

### 31.6 `clients -j` remains the required snapshot for now — DO NOT REMOVE from this round

Unlike workspaces/activeWorkspace, `HyprlandData.windowList` has many consumers and uses raw Hyprland fields including geometry/floating/workspace/pid/focus-history data.

Quickshell's native Hyprland toplevel model now exposes many dedicated fields plus `lastIpcObject`, so a future migration may be possible, but this round does not prove full parity for all consumers.

Keep `hyprctl clients -j` as the conservative remaining query until a field-by-field contract matrix proves otherwise.

### 31.7 Event-specific invalidation is the broader lossless architecture candidate — HIGH CONFIDENCE / needs runtime count

Hyprland's event stream provides distinct event names for workspace, focused monitor, active window, fullscreen, monitor add/remove, window open/close/move, layer open/close, config reload and other changes.

Current Hadalis treats all of them as invalidating all five snapshots.

A safer optimization order than adding a generic debounce is:

1. remove snapshots with no consumer (§31.2);
2. replace duplicated native state (§31.3);
3. demand-gate specialist snapshots (§31.4);
4. map remaining query families to the events that can actually invalidate them;
5. retain a conservative full refresh for unknown/future event names if compatibility requires it.

This keeps eventual data freshness explicit and avoids trading correctness for an arbitrary timer window.

Runtime benchmark target:

- count `hyprctl clients/monitors/layers/workspaces/activeworkspace` children during 60 seconds of normal focus/workspace/window activity;
- repeat with Overview closed/open and Region Selector closed/open;
- record event names alongside query starts;
- verify output state after monitor hotplug, layer changes, window moves, fullscreen changes and config reload.

### 31.8 Fuzzysort search-query cache grows for the shell lifetime and the wrapper exposes no cleanup — CONFIRMED structure / P2 memory, needs benchmark

`modules/common/functions/fuzzysort.js` has two module-global Maps:

- `preparedCache`
- `preparedSearchCache`

Entries up to 999 characters are inserted without a capacity/TTL policy.

The library does contain `cleanup()`, but `modules/common/functions/Fuzzy.qml` exposes only:

- `go()`
- `prepare()`

so current QML consumers cannot call the cleanup function.

The stronger concern is `preparedSearchCache`: every distinct fuzzy query string is retained for the life of the QML JS library. Current user-input paths include AppSearch, Cliphist, Emojis, AI suggestions and Anime/provider suggestions.

This is deterministic cached preparation, so eviction is semantically lossless: an evicted query is simply prepared again if reused.

Preferred direction only if memory profiling shows material growth:

- put a small bounded/LRU policy on prepared search strings, or
- expose a controlled cleanup/invalidation hook tied to search-session/dataset lifecycle.

Do not blindly clear target preparation on every keystroke; the cache exists to avoid repeated preparation work.

### 31.9 False-positive closure: ImageDownloaderProcess is not a shared media-download bottleneck

`modules/common/utils/ImageDownloaderProcess.qml` looked like a possible shared artwork/download dedup target because it validates images with ImageMagick.

Current repository tracing shows its actual runtime consumer is the floating-image overlay path. Media artwork uses the separate `MediaArtworkResolver` pipeline already covered in §13.8 and §§25.5–25.6.

Therefore do **not** create a repo-wide media dedup task around `ImageDownloaderProcess` from its generic name alone.

No runtime implementation is authorized by this handoff.

## 32. Audit round 18 — Hyprland client-derived work and exact duplicate shell IPC/image probes (2026-09-29)

This round is documentation/research only. No runtime/source implementation is authorized.

### Snapshot

- Hadalis `dev` at round start: `1f8d8942e77c48cfd80a08b071ad143834ef1dcb`.
- No runtime/source delta was introduced before this round.

The governing constraint for this round is stricter than “looks equivalent”: only eliminate work when the same semantic result can be preserved. Event throttling, stale snapshots, changed selection order, changed image decode paths or changed compositor timing are not accepted as lossless.

### 32.1 `clients -j` consumer matrix is now narrow enough to reason about field parity — HIGH CONFIDENCE inventory

Current `HyprlandData.windowList` consumers and raw fields are:

- `modules/background/Background.qml`
  - `monitor`, `workspace.id`
  - used for per-output workspace range and “windows on active workspace” presence.
- `modules/bar/Workspaces.qml`
  - `workspace.id`, `size`, `class`
  - used by `biggestWindowForWorkspace()` for workspace icon selection.
- `modules/bar/ActiveWindow.qml`
  - same biggest-window helper plus `class/title` fallback semantics.
- `services/ScreenTime.qml`
  - `focusHistoryID`, `class`
  - scans the snapshot on its Hyprland poll tick.
- `modules/overview/OverviewWidget.qml`
  - `address`, `monitor`, `workspace.id`, `at`, `floating`, `title`, `class`, `xwayland` and related raw geometry.
- `modules/regionSelector/RegionSelection.qml`
  - `floating`, `workspace.id`, `at`, `size`, `class`, `title`.
- `modules/lock/Lock.qml`
  - `floating`, `workspace.id`, `address`, `at`.
- `modules/common/functions/Session.qml`
  - `pid` only, and only when session actions close windows.

This confirms that raw client JSON is still semantically useful, but most consumers do not need every field and several are demand-only.

### 32.2 Quickshell can carry the same raw toplevel JSON without a child `hyprctl` process — HIGH CONFIDENCE candidate, parity proof required

Current Quickshell Hyprland API exposes:

- `Hyprland.toplevels`;
- `Hyprland.activeToplevel`;
- `Hyprland.refreshToplevels()`;
- `HyprlandToplevel.lastIpcObject`, documented as the last JSON returned for that toplevel.

Hadalis already uses `lastIpcObject` in `CompositorService.qml` for raw fields such as:

- `monitor`;
- `workspace.id`;
- `at`.

Therefore a plausible exact-safe architecture is:

1. preserve the same refresh points initially;
2. ask Quickshell to refresh toplevels in-process;
3. rebuild Hadalis' raw snapshot/indexes from `lastIpcObject`;
4. compare field-for-field against `hyprctl clients -j` under the same compositor state.

This would remove the external child-process spawn while retaining an IPC refresh. It is **not yet classified CONFIRMED** because ordering, XWayland coverage, object publication timing and every raw field used by Overview/Lock/Session must match.

Required parity corpus:

- native Wayland + XWayland;
- tiled/floating/pinned/special workspace;
- title/class changes;
- move/resize/workspace move;
- fullscreen;
- monitor move/hotplug;
- lock transition;
- window open/close during refresh.

Do not replace `clients -j` until the raw snapshots agree for every field consumed above.

### 32.3 `biggestWindowForWorkspace()` repeats full-window scans for every workspace button — CONFIRMED pure-QML lossless candidate / P1-P2

The helper currently does:

1. `windowList.filter(w => w.workspace.id == workspaceId)`;
2. `reduce()` by `size[0] * size[1]`.

`Workspaces.qml` instantiates one `biggestWindow` binding per rendered workspace button. The configured fallback workspace count is 10. `ActiveWindow.qml` also calls the same helper.

When `windowList` is replaced, each dependent binding can independently scan the entire list and allocate its filtered array.

Exact-safe direction:

- while publishing one raw client snapshot, compute `biggestWindowByWorkspaceId` in a single pass;
- preserve the current strict `>` area comparison so equal-area tie behavior remains first-in-snapshot;
- make `biggestWindowForWorkspace(id)` an O(1) lookup.

For 10 workspace buttons, the biggest-window portion changes from approximately ten full list filters/reduces per bar refresh to one shared O(N) indexing pass. This is an operation-count estimate only, not a shell-wide CPU percentage.

### 32.4 Background repeats per-output filter + sort even though it only needs range/presence — CONFIRMED pure-QML lossless candidate / P1-P2

Every Hyprland `Background.qml` output currently derives:

`windowList.filter(win => win.monitor == monitor.id && win.workspace.id >= 0).sort(...workspace id...)`

The resulting array is only used to obtain:

- first workspace id;
- last workspace id;
- whether the active workspace contains at least one window;
- fallback “any relevant window” presence.

The full sorted arrays are not otherwise consumed.

Exact-safe direction:

During the same single pass that receives the client snapshot, build per-monitor derived state:

- min non-negative workspace id;
- max non-negative workspace id;
- occupied workspace-id set/count.

This preserves the current result without per-output filtered-array allocation or sorting.

Alternative after Quickshell parity is proven: derive the same values from `Hyprland.workspaces`, whose workspace objects already expose monitor association and toplevel membership. Do not mix the two routes in one implementation step; first preserve current client-snapshot semantics exactly.

### 32.5 `addresses` is dead derived state; `windowByAddress` is Overview-only but built globally — CONFIRMED / P2

`HyprlandData.qml` currently allocates after every client snapshot:

- `windowByAddress`: one object map over all windows;
- `addresses`: one array mapping all window addresses.

Repository tracing shows:

- `addresses` has no effective consumer. `OverviewWidget.qml` copies it into `windowAddresses`, but that property is never read afterward.
- `windowByAddress` is externally consumed only by `OverviewWidget.qml`.

Lossless opportunities:

- remove the dead `addresses/windowAddresses` derived allocation;
- either materialize `windowByAddress` only while Overview has a consumer, or derive it inside the Overview residency boundary.

This is smaller than IPC elimination but is static, behavior-preserving allocation removal.

### 32.6 ScreenTime performs a window-list scan every Hyprland poll tick — CONFIRMED subwork / P2

Hyprland ScreenTime polls at:

`(Config.options.sidebar.screenTime.pollIntervalSeconds ?? 5) * 1000`.

Each tick scans `HyprlandData.windowList` until `focusHistoryID === 0`, then reads `class`.

Exact-safe low-risk direction independent of Quickshell migration:

- when the existing client snapshot is parsed, store the same first `focusHistoryID === 0` record/class;
- ScreenTime reads that O(1) derived value.

This preserves the exact source/order semantics of the current snapshot and removes repeated scans between compositor refreshes.

A later native `Hyprland.activeToplevel` migration may be cleaner, but class/app-id equivalence across Wayland/XWayland must be proven before using it as a lossless replacement.

### 32.7 `switchwall.sh` performs two immediate `hyprctl monitors -j` calls for one resolution result — CONFIRMED / P2 user-action latency

`get_max_monitor_resolution()` currently executes:

- one `hyprctl monitors -j` to compute max width;
- a second immediately afterward to compute max height.

The same monitor JSON can provide both values in one query.

Operation count for this function's Hyprland branch:

- compositor queries: **2 -> 1**;
- 50% fewer `hyprctl monitors` child invocations in this step.

Preserve the existing semantics that width and height are independently the maxima across all monitor records.

Do not broaden this into a script-wide long-lived monitor cache: separate later queries currently have fresh-snapshot semantics and monitor state could change during a long wallpaper operation.

### 32.8 `switchwall.sh` decodes image metadata twice for width/height — CONFIRMED / P2

For non-video upscale checks, current code executes:

- `identify -format "%w" "$img"`;
- `identify -format "%h" "$img"`.

Both target the same unchanged file back-to-back.

One ImageMagick invocation can return both dimensions while preserving the same selected image/frame semantics.

Operation count:

- ImageMagick identify processes: **2 -> 1** for this check.

This is independent of the larger OpenCV region-analysis work and should not be conflated with it.

### 32.9 Several Niri script routes probe an IPC command and immediately run it again — CONFIRMED / P2

Static duplicates found:

**`switchwall.sh`**

- `get_max_monitor_resolution()`:
  - probe `niri msg outputs >/dev/null`;
  - run `niri msg outputs` again for parsing.
  - exact-safe target: capture output + exit status from one invocation.

- `get_focused_monitor_name()`:
  - probe `niri msg -j focused-output >/dev/null`;
  - run the identical JSON request again.
  - exact-safe target: one JSON request.

**`scripts/videos/record.sh`**

- `getactivemonitor()` probes `niri msg focused-output`, then immediately runs it again.
- target: **2 -> 1** focused-output IPC calls.

**`scripts/colors/random/random_osu_wall.sh` and `random_konachan_wall.sh`**

Focused output:
- probe `niri msg outputs`;
- run `niri msg -j outputs`.
- target: one JSON outputs request.

Workspace range:
- probe `niri msg workspaces`;
- run `niri msg -j workspaces` once for first workspace;
- run the identical JSON request again for last workspace.

The first/last range can be extracted from one successful JSON snapshot while preserving the existing sorted idx semantics.

Operation count for the random-script workspace range route:

- Niri workspace queries: **3 -> 1** (about 67% fewer).

These are user-action paths rather than permanent idle costs, but they are unusually safe because the duplicate calls are adjacent and semantically intended to inspect one state.

### 32.10 DesktopWidgetLayout write-amplification suspicion is mostly CLOSED

`services/DesktopWidgetLayout.qml` was re-read specifically for unnecessary Config revisions.

Verified safeguards:

- `setValues()` compares every requested value and returns without writing if nothing changed;
- clear functions return without writing when nothing is removed;
- `Background.initializeOutputWidgetLayout()` checks `outputLayoutMatches()` plus missing local geometry and returns before initialization when neither condition requires work.

Therefore there is no evidence of an unconditional layout write loop.

A broad `Config.revisionChanged` connection does restart the 1.4 s output-layout timer, so unrelated config edits can still cause a later read/geometry check. That belongs under the already-known global Config invalidation fan-out candidate (§25.7), not a new persistence/write candidate.

Do not optimize DesktopWidgetLayout by suppressing required geometry initialization or by changing persisted layout semantics.

### 32.11 Revised lossless priority from this round

Highest-confidence no-behavior-change targets now split into two classes:

**Work elimination requiring no compositor semantic change**
1. remove unused `HyprlandData.addresses`;
2. precompute biggest-window/workspace and Background per-monitor indexes once per client snapshot;
3. precompute focused raw window for ScreenTime;
4. collapse adjacent duplicate `hyprctl` / `niri msg` / ImageMagick calls in wallpaper/record scripts.

**Potentially larger process elimination requiring parity proof**
1. replace external `hyprctl clients -j` ownership with Quickshell `refreshToplevels()` + `lastIpcObject`;
2. continue the workspaces/activeWorkspace/layers/monitors elimination/demand-gating from §31.

Do not trade freshness, ordering, tie behavior, XWayland coverage or raw-field parity for a lower process count.

No runtime implementation is authorized by this handoff.

## 33. Audit round 19 — Hyprland compatibility boundary and process-free transport candidates (2026-09-29)

This round is documentation/research only. No runtime/source implementation is authorized.

### Snapshot and source-delta note

- Hadalis `dev` at round start: `5f4940a3c487c1b7c81e56456907af5126372042`.
- Since research handoff commit `ed0d91ac645172c15631f6d9c2abed2013109223`, one runtime commit landed:
  - `refactor(abyss): reflow pyramid survivors during close`
- That runtime commit is Abyss/pyramid-specific and does not modify the Hyprland service files audited below.
- Nevertheless, all conclusions in this round were re-read against current `dev`, not assumed from the previous snapshot.

The stricter rule for this round is:

> A core-repository search returning zero consumers is **not** sufficient proof that a `qs.services` property is unused.

Lossless means preserving observable behavior for core modules **and user-loaded shell extensions/custom widgets**.

### 33.1 Critical correction: `HyprlandData` is an extension-visible service boundary — CONFIRMED

`services/HyprlandData.qml` is registered in `services/qmldir`.

Hadalis documentation explicitly treats services as stability boundaries, and the custom-widget SDK states that:

- custom widgets run inside the same QML engine as the shell;
- widgets may `import qs.services`;
- service singletons expose reactive properties directly.

`services/CustomWidgets.qml` also scaffolds user widgets with `import qs.services`.

Therefore a user-installed widget can legally reference `HyprlandData` properties even if no checked-in core QML file references that exact property.

For strict lossless work, treat the currently exposed `HyprlandData` surface as compatibility-sensitive:

- `windowList`
- `addresses`
- `windowByAddress`
- `workspaces`
- `workspaceIds`
- `workspaceById`
- `activeWorkspace`
- `monitors`
- `layers`
- `biggestWindowForWorkspace()`

Preserve property names, value shape, ordering where observable, update/freshness behavior and error-state behavior unless an explicit breaking API change is separately authorized.

### 33.2 Supersede earlier “unused property/query removal” classifications

The following earlier conclusions are **not implementation-safe under the strict lossless requirement** and are superseded by this section:

- §31.2: “`workspaces -j` has no repository consumer, therefore eliminate it.”
- §31.3: retiring the `activeWorkspace` snapshot by removing its public state.
- §31.4: demand-gating `layers -j` solely because Region Selector is the only checked-in core consumer.
- §31.5: demand-gating monitor data solely from checked-in core consumers.
- §31.7: narrowing refresh events in a way that changes the observable freshness cadence of existing `HyprlandData` properties.
- §32.5: deleting public `HyprlandData.addresses` because the checked-in Overview binding is otherwise dead.

These remain useful evidence about **core usage**, but not proof that the public service work can be removed.

Safe optimization must keep the public service result equivalent.

### 33.3 No Hyprland subsystem cleanup candidate: real consumers remain — CONFIRMED closure

A fresh repository-wide inventory confirms active consumers for Hyprland-specific functionality including:

- `HyprlandKeybinds`:
  - cheatsheet;
  - settings shortcut page.
- `HyprlandXkb`:
  - keyboard indicators;
  - bar/vertical-bar indicator;
  - ii and Waffle lock surfaces.
- `HyprlandFocusGrab`:
  - compositor-aware popup/sidebar focus handling.
- native `Hyprland.focusedMonitor`, `monitorFor()`, `workspaces`, `toplevels`:
  - Background;
  - Overview;
  - Workspaces;
  - taskbar previews;
  - wallpaper selectors;
  - media/focused-screen routing;
  - brightness;
  - session screen;
  - screen corners.
- Hyprland dispatch/keyword behavior:
  - workspace navigation;
  - reload;
  - screen zoom;
  - lock pseudotile/blur workaround;
  - DPMS;
  - cursor warp handling;
  - lock refocus hack.

Do **not** remove or disable these paths as “legacy Hyprland code.” They implement current features.

### 33.4 Stronger lossless architecture: preserve all five HyprlandData queries but remove external `hyprctl` process creation — HIGH CONFIDENCE, needs live parity

The previous rounds focused on eliminating whole query families. Under the extension-compatibility constraint, a safer architecture is to preserve the exact query set and refresh cadence and optimize only the transport.

Current `HyprlandData.updateAll()` issues:

- `hyprctl clients -j`
- `hyprctl monitors -j`
- `hyprctl layers -j`
- `hyprctl workspaces -j`
- `hyprctl activeworkspace -j`

Hyprland's request socket protocol is what `hyprctl` itself uses. Upstream `hyprctl` opens `.socket.sock`, writes the request string and reads the reply until the server closes the connection.

Equivalent JSON request strings are:

- `j/clients`
- `j/monitors`
- `j/layers`
- `j/workspaces`
- `j/activeworkspace`

Quickshell exposes:

- `Hyprland.requestSocketPath`;
- the generic `Quickshell.Io.Socket` Unix-socket type.

Lossless transport candidate:

1. preserve `updateAll()` on the same raw-event cadence initially;
2. preserve one-in-flight + queued-rerun behavior for each query family;
3. send the exact request strings to `Hyprland.requestSocketPath`;
4. parse the raw JSON reply exactly as current collectors do;
5. preserve public arrays/objects and their ordering;
6. preserve current parse/failure fallback values;
7. add a timeout equivalent to `hyprctl`'s current 5-second receive timeout.

Potential effect:

- compositor IPC requests: **still 5** per full refresh wave;
- external `hyprctl` child processes from this service: **5 -> 0** per full wave.

This is deliberately a process-spawn optimization, not an IPC-query elimination claim.

Compatibility gate:

Hadalis packaging does not currently pin an explicit minimum Quickshell API version in the audited package metadata. Before implementation, verify that every supported Quickshell package/version exposes `Hyprland.requestSocketPath` and the required `Socket` semantics, or retain the current `hyprctl` path as a compatibility fallback.

### 33.5 Quickshell object models are NOT yet a lossless replacement for raw public HyprlandData arrays

Upstream Quickshell source confirms:

- `Hyprland.refreshToplevels()` sends `j/clients`;
- `Hyprland.refreshWorkspaces()` sends `j/workspaces`;
- `Hyprland.refreshMonitors()` sends `j/monitors`;
- each object's `lastIpcObject` contains the raw JSON object returned by the compositor.

However, Quickshell stores those objects in its own object models.

Important ordering issue:

- the raw `j/clients` response is an array;
- `HyprlandData.windowList` currently exposes that parsed response array directly;
- `Hyprland.toplevels` is an object model with object lifecycle/insertion semantics, not a documented mirror of every future `j/clients` response-array order;
- Quickshell explicitly sorts the workspace object model by id.

Therefore reconstructing public `HyprlandData.windowList/workspaces` from Quickshell model iteration is **not proven lossless**, even if each `lastIpcObject` has identical fields.

Keep this route at “needs parity/contract proof.” Do not use it merely to save a subprocess.

### 33.6 Quickshell Socket completion semantics require a runtime test before transport migration

Quickshell's `Socket` is suitable for Unix-domain requests, but its implementation differs from `Process + StdioCollector` in an important detail:

- `Socket` feeds received chunks into its parser on `readyRead`;
- on socket disconnect it clears the DataStream buffer;
- it does not call `DataStreamParser.streamEnded()` in the same way a Process stdout stream ends.

A `StdioCollector` with default `waitForEnd: true` therefore cannot simply be transplanted and expected to emit the same `streamFinished` contract.

A safe implementation would need to prove:

- complete reply collection across partial reads;
- completion detection on server disconnect;
- no lost final bytes;
- timeout/error handling;
- no stale reply from an older request after a rerun is queued.

This keeps §33.4 at **High confidence / needs live parity**, not Confirmed implementation.

### 33.7 Preserve public properties while eliminating repeated derived traversals — CONFIRMED architectural direction

The extension boundary does **not** invalidate the pure-QML derived-index optimization from §32 if public properties remain unchanged.

On every successful client snapshot, current code already traverses `windowList` to build `windowByAddress`, then separately maps it to build `addresses`.

One single snapshot pass can preserve those exact public results while also deriving private indexes:

- `windowByAddress`;
- `addresses` in original `windowList` order;
- biggest window per workspace;
- per-monitor min/max non-negative workspace id;
- per-monitor occupied workspace ids/count;
- first raw record with `focusHistoryID === 0`.

Then:

- keep `biggestWindowForWorkspace(id)` as the same public function but make it an O(1) lookup;
- Background can consume private per-monitor derived state instead of per-output `filter().sort()`;
- ScreenTime can consume the precomputed focused raw record instead of rescanning every poll.

Lossless invariants:

- do not reorder `windowList`;
- preserve `addresses` order;
- preserve `windowByAddress` key/value shape;
- biggest-window tie remains strict `>`, so equal-area windows retain “first in snapshot wins” behavior;
- no public field disappears.

### 33.8 Animated screen zoom can spawn one `hyprctl` process per animation update — HIGH CONFIDENCE / P1 burst candidate

`GlobalStates.qml` currently has:

- `screenZoom` with a `Behavior on screenZoom`;
- the behavior is a `NumberAnimation`;
- every `onScreenZoomChanged` executes:
  `hyprctl keyword cursor:zoom_factor <value>`.

The default fast animation preset is around 200 ms before user speed/profile scaling.

Therefore one logical zoom step can produce multiple intermediate `screenZoom` values, and each property update can launch a separate detached `hyprctl` process.

Do **not** debounce to only the final zoom value: that would remove compositor-side intermediate zoom updates and alter the visible animation.

Strict-lossless direction:

- keep every animated `screenZoom` update;
- keep the same numeric values and animation;
- replace only the child-process transport for `keyword cursor:zoom_factor ...` with an in-process request-socket path;
- preserve request ordering.

Expected benefit is concentrated but potentially large during zoom transitions: **O(animation updates) child-process spawns -> 0 child processes**, while the same number of compositor keyword updates remain.

Needs runtime trace to count actual starts per zoom action and verify request ordering.

### 33.9 HyprlandXkb must remain; two transport/file-read optimizations are lossless-shaped — HIGH CONFIDENCE / P2

`services/deferred/HyprlandXkb.qml` is actively consumed by lock screens and keyboard indicators.

Do not remove it or suppress its current event logic.

Two narrower candidates:

**A. devices query transport**

Current startup/config-refresh route uses:

`hyprctl -j devices`

The equivalent raw request is `j/devices`.

A direct request-socket transport can preserve:

- exact JSON response;
- main-keyboard selection;
- `layoutCodes`;
- `currentLayoutName`;
- existing `configreloaded -> next activelayout` refresh timing.

This removes one external `hyprctl` process per devices refresh, not the refresh itself.

**B. `base.lst` lookup**

For a previously unseen layout description, `getLayoutProc` launches:

`cat /usr/share/X11/xkb/rules/base.lst`

and then performs all matching in QML.

An in-process `FileView` read/reload at the same trigger can remove the `cat` child while preserving the exact matching algorithm and cache behavior.

To remain lossless, do not replace it with a permanently stale one-time preload; package updates to `base.lst` during a shell session must retain equivalent visibility when a new lookup occurs.

### 33.10 HyprlandKeybinds parser can skip work only when its exact input file is unchanged — HIGH CONFIDENCE / P2

`services/deferred/HyprlandKeybinds.qml` is actively consumed by:

- Cheatsheet;
- Settings > Shortcuts.

On every Hyprland `configreloaded`, it launches two parser processes:

- default keybind file;
- user keybind file.

`scripts/hyprland/get_keybinds.py` is deterministic with respect to the file passed via `--path`:

- it reads that file;
- sourcing is explicitly unsupported;
- the resulting JSON is derived from that content.

Lossless candidate:

- maintain an exact content fingerprint/snapshot for each of the two input files;
- on `configreloaded`, rerun the parser only for files whose exact content changed since the last successful parse;
- keep current parser/output behavior for changed files.

Thus an unrelated Hyprland config reload can become:

- **2 -> 0 parser launches** if neither keybind file changed;
- **2 -> 1** if exactly one changed;
- still **2** if both changed.

Do not substitute a time debounce or assume that “config reload” means keybind files are unchanged.

### 33.11 Hyprsunset state probe has a redundant shell wrapper — CONFIRMED small candidate / P3

`services/Hyprsunset.qml` probes Hyprland night-light state with:

`/usr/bin/bash -c "hyprctl hyprsunset temperature"`.

Elsewhere the shell already invokes `hyprctl` directly through Quickshell `Process`, proving executable resolution through the Process API is an established repo pattern.

The bash layer performs no expansion, pipeline, redirection or sequencing needed by this command.

Lossless direction:

- keep the same `hyprctl hyprsunset temperature` command, stdout checks, exit-code handling and 5-second timeout;
- eliminate only the intermediate bash process.

Per probe, process chain becomes approximately:

- current: QProcess -> bash -> hyprctl;
- candidate: QProcess -> hyprctl.

Do not alter the owned/external hyprsunset lifecycle logic.

### 33.12 Lock Hyprland commands are functional, not dead work

`modules/lock/Lock.qml` still intentionally uses Hyprland-specific operations for:

- `dwindle:pseudotile`;
- window pseudo/floating restoration;
- exact position restore;
- `addreserved` blur workaround;
- delayed special-workspace refocus after unlock.

These commands must remain semantically intact.

A future request-socket transport could remove `hyprctl` child creation for individual `keyword` commands while keeping the command itself, but the delayed unlock batch should **not** be rewritten merely for process count:

- it has an explicit 200 ms delay;
- two dispatches are intentionally ordered;
- changing its execution mechanism risks lock/focus behavior.

Keep the unlock hack unchanged unless a dedicated behavior trace proves parity.

### 33.13 Lossless Hyprland priority after this correction

The safe order is now:

1. **Preserve every existing Hyprland feature and `HyprlandData` public property.**
2. Eliminate repeated pure-QML traversals while keeping public arrays/functions byte/shape/order-equivalent.
3. Replace high-frequency `hyprctl` child creation with exact request-socket transport only after Socket completion/version parity is proven.
4. Prioritize animated screen zoom because it can create a child per animation update.
5. Apply content-identity gating to deterministic keybind parsing.
6. Remove trivial subprocess wrappers such as `bash -c` around a single `hyprctl` invocation.
7. Do **not** narrow `HyprlandData` refresh/query families based only on checked-in core consumers.

No runtime implementation is authorized by this handoff.

## 34. Audit round 20 — Settings world-clock child fan-out and saved-theme polling (2026-09-29)

This round is documentation/research only. No runtime/source implementation is authorized.

### Snapshot

- Hadalis `dev` at round start: `cfa920d8b2e74afd1d5e8154da0425b160c62cfa`.
- No runtime/source delta preceded this round; HEAD was the round-19 documentation commit.
- Hyprland compatibility conclusions from §33 remain unchanged. This round intentionally moved away from risky Hyprland feature elimination and looked for exact subprocess duplication elsewhere.

### 34.1 World Clock Settings preview spawns one external `date` child per configured timezone — CONFIRMED / P1-settings process churn

`modules/settings/InterfaceConfig.qml` contains a live preview for the sidebar World Clock.

While the Widgets settings section is active and the World Clock subsection is visible:

- a repeating timer runs every **20 seconds**;
- `triggeredOnStart: true`;
- every Config change while that section is active also calls `refreshLiveTimes()`.

For `N` configured timezone rows, `refreshLiveTimes()` builds one Bash command containing `N` command substitutions of this shape:

`$(TZ='<zone>' date '+<time-format>|%:z')`

Therefore one refresh currently creates approximately:

- 1 Bash process;
- N external `date` processes.

Child-process count per refresh is **N + 1**.

Hadalis already contains a behaviorally stronger precedent in `modules/sidebarLeft/widgets/WorldClockWidget.qml`:

- timezone names are passed as argv, not interpolated into shell source;
- one Bash process loops over all zones;
- Bash builtin `printf '%(...)T'` obtains timezone-aware time/offset data;
- the widget explicitly uses this to avoid one `date` child per timezone.

Lossless-shaped direction for the Settings preview:

1. preserve the current 20-second timer and current Config-triggered refreshes initially;
2. preserve configured timezone order;
3. keep one Bash process;
4. obtain every zone's time and `%z` offset through Bash builtin `printf %T`;
5. convert the offset to the current `%:z` display shape without external per-zone commands.

Static operation impact:

- N+1 child processes -> 1 per preview refresh;
- removes exactly N process creations per refresh;
- for four configured zones: **5 -> 1**, or **80% fewer child processes for that refresh**.

This percentage is process-count reduction for this narrow operation only, not a whole-shell CPU estimate.

Do not narrow the current refresh triggers merely to save work until UI freshness semantics are separately proven.

### 34.2 Sidebar World Clock itself is already batched, but seconds mode still creates one Bash process per second — NEEDS PARITY / P2 conditional

`modules/sidebarLeft/widgets/WorldClockWidget.qml` is already much better than the Settings preview:

- all timezones share one Bash process per refresh;
- no per-zone `date` children exist;
- refresh is gated by `GlobalStates.sidebarLeftOpen`.

Its timer cadence is:

- `showSeconds == true`: every 1 second;
- otherwise: every 30 seconds.

Thus seconds mode creates up to **60 Bash processes per minute while Sidebar Left is open**, while normal minute-resolution mode creates roughly two per minute.

A fully in-process timezone renderer could eliminate this remaining process churn, but it is **not yet proven lossless**:

- current output uses libc/Bash `strftime` formatting;
- timezone/DST boundaries must match exactly;
- date/day-of-year/day-delta behavior must remain identical;
- 12/24-hour text and locale-sensitive date formatting must retain existing output.

Do not replace it with offset caching alone: a cached offset can be stale across a DST transition.

Keep this as a parity/benchmark target, not an authorized implementation candidate.

### 34.3 Themes page runs saved-theme subprocess polling every two seconds across all task tabs — CONFIRMED / P1 hidden process churn

`modules/settings/ThemesConfig.qml` owns `savedThemesProcess`.

Its current command is effectively:

- 1 login Bash;
- for each `*.json` saved theme:
  - 1 external `basename`;
  - 1 external `jq`.

For `N` saved themes, one inventory refresh therefore creates approximately:

**1 + 2N child processes.**

The refresh timer is:

- interval: 2000 ms;
- repeat: true;
- `triggeredOnStart: true`;
- `running: root.visible && customThemeEditorSection.expanded`.

The important residency fact is that `customThemeEditorSection.expanded` is statically `true`, while the section itself is only visible for `activeSection === "advanced"`.

Therefore, whenever the **Themes page itself is visible**, this 2-second process poll remains active not only in Advanced but also while the user is on:

- Colors;
- Type;
- Motion.

Saved presets are displayed on the Colors tab, so simply gating polling to Advanced would not preserve current behavior. On Type/Motion, however, the same inventory work is still performed even though saved-theme UI is not visible.

Static process rate:

- refreshes: about 30 per minute while the Themes page remains visible;
- child creations: about `30 * (1 + 2N)` per minute.

Examples:

- N=0: ~30 Bash children/minute;
- N=4: ~270 children/minute;
- N=10: ~630 children/minute.

These are operation counts derived from source cadence, not CPU-time estimates.

### 34.4 Per-theme `basename` in ThemesConfig is independently removable without changing refresh policy — CONFIRMED small sub-candidate

Within the existing Bash `for f in .../*.json` loop, the theme name is derived by launching:

`/usr/bin/basename "$f" .json`

The loop already owns the full path in shell variable `f`.

Shell parameter expansion can derive the basename and remove the known `.json` suffix without changing:

- file enumeration;
- loop ordering;
- `jq` behavior;
- invalid-JSON handling;
- timer cadence;
- saved-theme object shape.

Therefore the narrow process-count reduction is:

**1 + 2N -> 1 + N** per poll,

removing exactly one external process per saved theme while preserving the current `jq`-per-file parser behavior.

This is useful even if the larger polling architecture is not changed.

### 34.5 Saved-theme polling has an event-driven lossless architecture available in the existing stack — HIGH CONFIDENCE / needs ordering + atomic-replace parity

Hadalis already ships and uses `Qt.labs.folderlistmodel` in production paths such as Wallpapers and GlobalActions.

Qt's current FolderListModel implementation confirms:

- it uses `QFileSystemWatcher` when available;
- it exposes `fileName`, `filePath`, `fileBaseName`, `fileModified`, etc.;
- directory updates can emit model `dataChanged`;
- additions/removals update the model.

Hadalis' `FileView` already provides `watchChanges: true` for file-content changes.

Therefore a lossless-shaped replacement for the 2-second process poll is available without inventing a new daemon:

- FolderListModel owns the `*.json` directory membership;
- one watched FileView per current theme file owns content changes;
- QML `JSON.parse` can preserve the current skip-invalid-file behavior;
- add/remove/replace/edit events rebuild only affected saved-theme state;
- idle steady state creates **zero periodic saved-theme scan processes**.

Why this remains High confidence rather than Confirmed implementation:

- current Bash glob order must be compared against the chosen model/order so preset ordering is pixel-equivalent;
- atomic-save/rename behavior must be tested;
- invalid JSON followed by later repair must recover identically;
- an externally edited file must become visible at least as reliably as the current <=2 s poll.

If those parity tests pass, the steady-state process reduction for this path is essentially:

**~30 * (1 + 2N) child creations per visible Themes-page minute -> 0 periodic scan children.**

Event-triggered work still occurs when the directory/files actually change.

### 34.6 CustomThemeEditor performs a second saved-theme inventory when Advanced is materialized — HIGH CONFIDENCE / P2 duplication

`ThemesConfig.qml` and `CustomThemeEditor.qml` independently enumerate the same directory:

`\${Directories.shellConfig}/themes`.

When the user switches to Advanced:

- the `CustomThemeEditor` Loader becomes active;
- `Component.onCompleted` starts `mkdir -p`;
- after that it calls `loadThemesList()`;
- its separate inventory command is:
  - Bash;
  - `ls`;
  - `xargs`;
  - one `basename` per theme under the current `xargs -I` contract.

At the same time, the page-level `ThemesConfig` 2-second saved-theme poll continues.

The editor only needs the theme names for its chips, while ThemesConfig already materializes names plus parsed theme contents.

Lossless architecture:

- one saved-theme inventory owner should feed both the Colors preset list and Advanced editor name list;
- save/delete/external changes invalidate that one owner;
- preserve current filename ordering and invalid-file semantics required by each consumer.

Even without centralization, the editor's list pipeline can retain the existing `ls` ordering while removing `xargs + one basename process per file` through shell builtins, reducing its one-shot enumeration process fan-out.

### 34.7 System Monitor search false positive closed

A broad timer/process search surfaced `modules/sidebarRight/sysmon/SysMonWidget.qml` as if it still contained a 2-second network subprocess.

Current `dev` does not.

It now uses:

`ResourceUsageMonitor { network: true; active: GlobalStates.sidebarRightOpen }`

and consumes `ResourceUsage.networkRxBytesPerSec/networkTxBytesPerSec`.

Do not reopen a `SysMonWidget` per-2-second-process optimization task from stale search snippets.

### 34.8 Revised next measurement order

Add these to the existing benchmark queue:

1. Themes page, 0/4/10 saved themes:
   - process starts/minute on Colors, Type, Motion and Advanced;
   - confirm the static `30 * (1 + 2N)` model.
2. World Clock Settings with 1/4/10 configured zones:
   - child process count per 20-second tick and per unrelated Config change.
3. Sidebar World Clock with seconds on/off:
   - process starts/minute while sidebar is open;
   - compare against an in-process timezone prototype only after exact DST/format parity tests.
4. Continue existing MediaArtworkResolver cold-miss and warm-cache process tests from §§25.5–25.6; current source still has no shared in-flight request owner.

No runtime implementation is authorized by this handoff.

## 35. Audit round 21 — prompt multi-output reactivity and Config fan-out refinement (2026-09-29)

> **Historical / retired runtime:** the Abyss Confirmation, prompt-anchor, Polkit-in-Abyss and semantic-vacancy experiments discussed in the prompt-related subsections below were removed from active runtime by `7d787fbf97da3dd5992fa9a41978643131da2994`. Preserve these findings only as historical research; see [the retired-experiments archive](archive/ABYSS_RUNTIME_EXPERIMENTS_2026-09-29.md).

This round is documentation/research only. No runtime/source implementation is authorized.

### Snapshot and runtime delta

- Hadalis `dev` at round close: `71dd854524a0d909fbb09401e1ac856ca8a4b324`.
- Since the previous research handoff `bd3d73fcb792e30b9b937372b451929266597510`, runtime work has concentrated on the new Abyss confirmation/Polkit popup path and associated anchor/auth-flow correctness.
- The existing OpenCV, Hyprland, Themes, World Clock, MPRIS and Config hot paths audited below were re-read against current `dev`.
- No runtime/source implementation is authorized by this section.

The strict rule remains: preserving visible output is not enough. A candidate is only called lossless when it also preserves public service contracts, ordering, refresh/freshness behavior, authentication semantics and extension-visible state.

### 35.1 Confirmation prompt payload is propagated into one full content tree per output although only one output can present — CONFIRMED hidden-work duplication / P2 multi-monitor

At the time of this audit, `AbyssPerimeter.qml` created one retired Abyss Confirmation presenter inside every output-local PanelWindow.

Each presenter correctly computes a single-output ownership condition:

`ConfirmationService.targetOutputName === root.outputName`

and only the owner can make its StyledPopup visible.

However every presenter still binds:

`request: ConfirmationService.currentRequest`

and passes that same request to its eagerly-created `AbyssConfirmationContent`.

Therefore one confirmation request is observed by every output's content tree even though only one of those trees is eligible to present.

The content work includes:

- title/message/details/action derived properties;
- three top-level `TextMetrics`;
- one action `Repeater`;
- one additional `TextMetrics` per action delegate;
- `onRequestChanged` state reset plus a queued `forceActiveFocus()`.

For `S` outputs, request-specific QML work therefore scales approximately O(S) while visible presentation remains O(1).

Lossless direction:

- retain one presenter per output and retain the current ownership/anchor/popup contract;
- propagate request-specific model work only into the current owner;
- non-owner presenters remain structurally present but hold a neutral request/model state;
- if ownership can change before presentation, synchronously materialize the current request into the new owner before it becomes visible.

Acceptance:

- same output/anchor selection;
- same request id and action order;
- same width/height/text metrics on the owner;
- same focus and Escape/Enter behavior;
- no intermediate popup on a non-owner output.

Expected impact is an operation-count reduction from O(S) prompt-content updates to O(1). No shell-wide percentage is claimed.

### 35.2 Abyss Polkit presenter optimization — CLOSED / SUPERSEDED

The Abyss Polkit integration described by the earlier Round-21 audit has been reverted from current `dev`. Polkit is back on its legacy renderer/service path and is outside the active Abyss Confirmation optimization scope.

The former multi-output presenter/model findings in this subsection therefore no longer describe the live tree. Do not reintroduce Abyss-specific Polkit presenters, source anchoring, prompt-host routing, or AuthFlow presentation changes as an optimization.

### 35.3 Prompt content residency itself is a separate, weaker candidate — NEEDS BENCHMARK / P2 memory

`StyledPopup` lazily owns its native presentation surface, but its `default property Item contentItem` is supplied as a direct QML child.

Therefore the Confirmation presenter eagerly instantiates its content tree once per output even when there is no prompt.

A Loader could reduce dormant prompt-content residency from O(S) trees toward zero/one, but this is **not yet strict-lossless** because first-request construction may alter:

- first-open latency;
- focus timing;
- TextMetrics readiness;
- the exact frame at which popup geometry becomes available.

Keep owner-only Confirmation request propagation (§35.1) separate from lazy content construction. The former is statically safer; the latter needs first-open latency and focus parity measurement.

### 35.4 Config global invalidation is larger than the earlier search count, but direct-binding replacement is NOT proven lossless — REFINED INVESTIGATE / P1

§25.7 recorded at least 41 files / 88 returned search occurrences using `Config.getNestedValue(...)`.

A current-`dev` manual audit of only 28 runtime QML files now verifies at least **153 fixed-literal call sites**.

The first 15 desktop-widget files alone account for 129 calls:

- clock/Cookie-clock family: 45;
- BatteryWidget: 7;
- VisualizerWidget: 23;
- CalendarUpcomingWidget: 5;
- SystemMonitorWidget: 11;
- JapaneseTypographyWidget: 38.

Thirteen additional media/settings/recorder files add at least 24 fixed-schema reads.

These are a lower bound, not a whole-repository count.

The important correction is that fixed schema does **not** automatically mean a direct `Config.options....` binding is equivalent.

Current `Config._applyNestedKey()` walks JsonObjects through JavaScript bracket notation and writes:

`obj[lastKey] = convertedValue`.

The repository itself documents why `Config.revision` exists: nested writes through this path have not always generated the narrow QML property notifications required for reliable live bindings. The changelog and `Appearance.qml` both preserve explicit revision dependencies for this reason.

Therefore:

- do not globally replace `Config.getNestedValue()` with direct typed-property reads;
- do not remove global `Config.revision`;
- do not assume typed JsonAdapter schema proves notification parity.

The valid architecture target is still **scoped/path-aware invalidation with a global compatibility fallback**:

1. preserve public `Config.revision` and `configChanged()`;
2. preserve dynamic/custom-widget paths on the current global fallback;
3. provide a narrow revision/subtree invalidation mechanism for internal call sites whose dependency set is known;
4. ensure `setNestedValue`, `setNestedValues`, external file reload, migrations and adapter reconstruction all update the same scoped revision contract;
5. migrate call sites only after focused binding tests prove that the exact key/subtree remains reactive.

This finding strengthens the scale of the problem while narrowing the safe solution.

### 35.5 AbstractBackgroundWidget shows why scoped revisions are preferable to deleting revision dependencies — REFINED / P1

Every live desktop widget inherits `AbstractBackgroundWidget`.

Its `desktopPersistentZ` currently depends on:

- `Config.revision`;
- `Config.getNestedValue("background.widgets.layerOrder", ...)`, which itself already depends on `Config.revision`.

Thus every unrelated config revision can make every live desktop widget recalculate its persistent stacking lookup, although its logical Config input is only `background.widgets.layerOrder`.

A dedicated layer-order/subtree revision can preserve exact behavior while avoiding unrelated wakeups.

By contrast, `overlappingLayerCount` also reads `Config.revision` before scanning sibling geometry. That broad dependency may currently be compensating for geometry/lifecycle changes that the binding cannot otherwise observe.

Do **not** remove the latter dependency unless Background/WidgetCanvas first exposes a dedicated overlap/layout generation that changes on every relevant widget:

- add/remove;
- geometry move/resize;
- persistent layer-order change;
- output-layout change.

This distinction is the model for future Config work: narrow only dependencies whose full invalidation set is known.

### 35.6 MPRIS Config handler contains one statically dead O(P) scan, but the whole rebuild trigger must remain — CONFIRMED small lossless candidate / P2

Current `MprisController` handles every `Config.configChanged` by:

1. `_updateMpvCache()`;
2. `_rebuildPlayerList()`.

A full dependency audit shows only three Config reads in this service:

- `media.filterDuplicatePlayers`;
- `sidebar.ytmusic.enable`;
- `osd.mediaEnabled` for feedback only.

It is tempting to suppress the whole rebuild when the first two keys did not change. Under the strict-lossless rule, **do not do that**.

`_filterYtMusicDuplicates()` compares live player title/position/length/URL. An unrelated Config event can currently cause that dynamic grouping to be reevaluated at that moment. Removing that trigger changes refresh timing even if it is accidental.

The narrower confirmed waste is `_updateMpvCache()`.

That function only scans `Mpris.players.values` and derives two booleans from player DBus names:

- whether an `mpv.instance...` player exists;
- whether the base `org.mpris.MediaPlayer2.mpv` player exists.

Those values depend on **player membership/name**, not Config, playback position, Plasma capability or YtMusic metadata.

Player construction/destruction paths already call `_updateMpvCache()`.

Therefore the extra calls from:

- every Config change;
- `hasPlasmaIntegrationChanged`;
- `YtMusic.mpvPlayerChanged`;

are redundant with respect to the cache's own input.

Lossless direction:

- retain every current `_rebuildPlayerList()` trigger;
- retain membership-triggered `_updateMpvCache()`;
- remove only cache scans caused by events that cannot change MPRIS DBus-name membership.

For `P` live players and `K` unrelated Config changes, this removes roughly O(K*P) immediate scans plus the same number of fresh two-field cache-object allocations. This is a small CPU/allocation win, not a process-count win.

### 35.7 Themes hidden-tab polling cannot be gated away by visibility alone under strict lossless semantics — CORRECTION / keep §34.5 High confidence

Static consumer tracing confirms `savedThemePresets` is only rendered by the Colors section.

However the current two-second poll continues while Type/Motion/Advanced is active, which means an external theme-file edit can be preloaded before the user switches back to Colors.

Simply stopping the poll on hidden tabs would make the first Colors frame potentially show stale saved-theme state until a new subprocess finishes.

Therefore tab visibility alone is **not** sufficient for a strict-lossless implementation.

The safe direction remains §34.5:

- event-driven directory/file watching with ordering/atomic-replace parity; or
- another design that guarantees refreshed state before Colors is presented.

The already-confirmed per-theme `basename` process removal (§34.4) is unaffected.

### 35.8 World Clock preview must retain the global Config-trigger refresh unless time freshness is replaced equivalently — CORRECTION

`InterfaceConfig.qml` World Clock preview derives its subprocess command from:

- configured timezone list;
- 12/24-hour format.

But its `onConfigChanged` handler also refreshes the **current wall-clock value** immediately.

An unrelated Config change can therefore advance preview time before the next 20-second periodic tick.

Signature-gating that handler only on timezone/format keys would change the timing/freshness contract.

Do not remove the current Config-trigger refresh merely because unrelated keys do not affect the command template.

The confirmed optimization remains §34.1:

- preserve every current trigger;
- preserve timezone order and displayed values;
- batch all timezone formatting into one Bash process using builtins instead of one external `date` child per zone.

### 35.9 MediaArtworkResolver in-flight sharing remains High confidence, not Confirmed under the strict byte-equivalence rule

Current source confirms separate resolver instances can target the same hashed cache path and independently start HTTP downloads into separate temp files before atomically replacing the final cache file.

That is real duplicate network/process work.

However two simultaneous requests to a dynamic HTTP origin are not mathematically guaranteed to return identical bytes. A shared in-flight owner would force peers to consume the first response, changing a race-edge behavior that exists today.

Similarly, the local-file path validates the source and later validates it again before copy; merging the two stages changes the filesystem mutation race window.

Therefore:

- keep remote shared in-flight dedup at High confidence / needs cache-contract definition;
- keep local validate+copy fusion at High confidence;
- do not promote either to strict Confirmed merely from duplicate-process evidence.

Warm-cache process avoidance from §25.5 remains a separate candidate.

### 35.10 Notification-history serialization remains a benchmark/contract candidate, not a Confirmed cache rewrite

Current notification persistence still maps/filters/pretty-serializes the full retained history on relevant writes.

The synchronous O(N) JS/allocation cost is real.

But a per-notification serialized cache is not automatically equivalent because notification QObjects may mutate after ingress; the current later serialization observes their then-current fields.

Likewise pretty -> compact JSON changes the persisted byte representation even if parsing results match.

Under the exact-lossless rule:

- measure this path;
- do not introduce a retention cap;
- do not cache serialized notification state unless mutation invalidation is complete;
- do not change persistence representation without an explicit contract decision.

### 35.11 Round-21 priority update

Newly promoted/strongest safe work from this round:

1. **Confirmation owner-only request/content propagation** — Confirmed multi-output hidden-work elimination.
2. **Retired Abyss Polkit optimization** — Closed after the Polkit integration revert; do not implement against the legacy path.
3. **MPRIS `_updateMpvCache()` membership-only refresh** — Confirmed small CPU/allocation cleanup.
4. **Config scoped invalidation** — stronger scale evidence (>=153 fixed call sites in a partial audit), but still Investigate because global revision covers real notification gaps.

Corrections that must prevent accidental non-lossless implementation:

- do not replace fixed `getNestedValue` calls with direct bindings wholesale;
- do not stop saved-theme polling solely based on hidden task-tab visibility;
- do not signature-gate World Clock's current Config refresh without preserving time freshness;
- do not suppress the whole MPRIS rebuild on unrelated Config changes;
- do not call MediaArtwork remote in-flight dedup byte-equivalent until the cache contract explicitly permits one response to represent concurrent requests.

No runtime implementation is authorized by this handoff.

## 36. Audit round 22 — connected-preview hidden reactivity and registry/DBus false-positive closure (2026-09-29)

This round is documentation/research only. No runtime/source implementation is authorized.

### Snapshot

- Hadalis `dev` at round close before this documentation update: `85d2470ae496b3c623177fdb68c522bd63961f1e`.
- Runtime commits since §35 concentrated on Confirmation queue/reopen/live-anchor correctness and Abyss prompt presentation.
- All preview/registry conclusions below were re-read against that current source rather than assumed from the earlier handoff snapshot.

The strict lossless rule remains: hidden work may be removed only if the same state is synchronously reconstructed before it becomes observable and all opening/retract/freshness semantics are preserved.

### 36.1 BarTaskbarPreview keeps compositor-model refresh listeners active after the popup is fully closed — CONFIRMED hidden reactive work / P1-P2

`modules/bar/BarTaskbarPreview.qml` is a `StyledPopup`.

Unlike the native popup surface, its direct visual `Item previewContent` is eagerly instantiated and remains alive while the popup surface is closed.

Inside that retained content are four live listener groups:

1. `ToplevelManager.toplevels.onValuesChanged` -> `_refreshPreviewToplevels()`;
2. `CompositorService.onSortedToplevelsChanged` -> app preview refresh;
3. Niri:
   - `onWindowsChanged`;
   - `onAllWorkspacesChanged`;
4. Hyprland:
   - `Hyprland.toplevels.onValuesChanged`.

After an **app preview** has been used once, `appEntry` remains stored after close. Hidden refreshes can therefore execute `_refreshAppToplevels()`, which:

- selects the current sorted/foreign-toplevel array;
- filters the whole list;
- runs `AppSearch.resolveWindowIdentity()` for candidates;
- allocates a fresh result array;
- may clone/update `appEntry`.

After a **workspace preview** has been used once, `workspaceId` remains stored after close. Hidden refreshes can execute:

- Niri: `NiriService.sortToplevels(...)` plus workspace filtering;
- Hyprland: a full loop over `Hyprland.toplevels.values` and workspace/raw-object lookup.

The component is instantiated in at least two independent Bar paths:

- `modules/bar/BarTaskbar.qml` for app previews;
- `modules/bar/Workspaces.qml` for compact workspace previews.

Therefore a bar/output containing both modules can retain two independent closed preview listeners after those previews have been exercised.

#### Strict-lossless direction

Do **not** merely gate on `previewOpen`, and do not simply gate on `presentationActive`.

A close has a visual retract tail, and there is also a small semantic-open -> surface-active transition.

A safer contract is:

1. immediately before semantic open, synchronously call the same current refresh function for the selected mode;
2. enable compositor listeners while:
   - `requestedVisible`, **or**
   - `presentationActive`;
3. keep them enabled through the entire retract tail;
4. disable them only after the popup is fully closed/unpresented.

This preserves:

- latest state before first visible frame;
- all events between semantic open and surface materialization;
- live add/remove/move updates while visible;
- close-on-last-window behavior;
- current state through the reverse slide/retract tail.

When fully closed, compositor events no longer need to rebuild a hidden preview model because the same authoritative snapshot is reconstructed synchronously on the next open.

Expected effect:

- fully-closed preview model scans: **event-driven O(N) -> 0**;
- no compositor subscription/backend is removed;
- no whole-shell CPU percentage is claimed until event-rate profiling is available.

### 36.2 Retained Bar preview delegates keep thumbnail/Image/layer objects after close — HIGH CONFIDENCE memory candidate, needs repeat-open latency parity

`BarTaskbarPreview.close()` currently only sets:

`previewOpen = false`.

It does **not** clear `previewToplevels`.

Because the direct StyledPopup content tree is retained, the Repeater therefore keeps one `BarTaskbarWindowPreview` delegate per last-previewed window after the popup closes.

Each delegate owns, among other objects:

- application `IconImage`;
- preview `Image`;
- a thumbnail decode target of roughly 2x drawn size;
- `layer.enabled: true`;
- `OpacityMask`;
- shimmer placeholder animation while the Image is not ready.

This retained UI memory is separate from `WindowPreviewService`'s intentional global warm cache.

The service explicitly owns an independent bounded cache:

- max 12 warm decoded images;
- 768x512 decode size;
- documented at roughly 18 MiB raw pixel data;
- explicit destroy/eviction/session cleanup.

Therefore releasing Bar delegates would not require deleting the shared preview cache or recapturing screenshots.

There is already a lifecycle precedent in:

`modules/waffle/bar/tasks/TaskPreview.qml`

which keeps preview content through close grace, then after 250 ms:

- sets `contentResident = false`;
- unloads its Loader;
- clears `appEntry`.

However applying the same policy to ii Bar is **not yet strict-lossless**:

- currently a second hover can reuse already-instantiated delegates, Images and masks;
- unloading them changes repeat-open construction/decode timing even when the PNG remains cached.

Required benchmark:

- first open;
- immediate close/reopen;
- reopen after 250 ms / 1 s / 5 s;
- 1, 4, 10 preview windows;
- CPU/GPU allocation and RSS/PSS;
- time to fully painted preview.

Keep this as a memory/retained-object experiment rather than a Confirmed implementation.

### 36.3 BarWorkspaceOverview already has the correct presentation-lifetime ownership — CLOSED / no optimization needed

`modules/bar/BarWorkspaceOverview.qml` is also a retained StyledPopup wrapper, but its expensive Overview renderer is correctly nested under:

`Loader { active: root.presentationActive }`

The comment and behavior explicitly preserve content through the reverse slide and unload it when presentation ends.

Therefore the heavy:

- `OverviewNiriWidget`;
- `OverviewWidget`;

do not remain materialized after the connected popup is fully closed.

Do not create a generic “lazy all StyledPopup content” refactor based on the Bar preview finding. The existing Overview path demonstrates that lifecycle must be chosen per content contract.

### 36.4 PopupAnchorRegistry performance finding — RETIRED / HISTORICAL

The PopupAnchorRegistry experiment was removed from active runtime with the Confirmation retirement. The analysis below records why a generic pruning/index rewrite was not justified while that experiment existed; it is not an active optimization target.

At the time, the source also exposed:

`isUsable(item)`

and Confirmation continuously derives:

`resolvedAnchorUsable`.

If a previously resolved retained source becomes non-presented without being destroyed, Confirmation force-cancels the request rather than teleporting it to fallback.

Core registration paths audited in this round also pair registration with destruction-time unregister.

This makes two tempting “optimizations” unsafe:

1. pruning every currently invalid/hidden registry entry;
2. replacing the ordered list with a simpler keyed map.

Why:

- retained Abyss content is intentionally allowed to become temporarily non-presented and later reappear;
- alias providers are dynamic functions;
- output preference and kind priority participate in scoring;
- equal-score behavior currently depends on stable registration/list order.

The registry is request-scoped rather than a hot per-frame/event loop. Keep it unchanged unless profiling proves resolve cost material with unusually large extension-provided anchor sets.

### 36.5 Broad “DBus fan-out per output” hypothesis is mostly CLOSED for current service models

A repository sweep of:

- SystemTray;
- MPRIS;
- Bluetooth;
- network/service consumers;

shows that many repeated QML imports/Connections are consumers of shared Quickshell/service models.

Multiple Bar/output widgets therefore do **not** by themselves prove multiple backend D-Bus subscriptions.

The valid optimization target is local repeated QML work on those shared signals, not a generic “centralize all D-Bus subscriptions” project.

Examples already classified separately:

- MPRIS redundant local cache scan (§35.6);
- prompt per-output model propagation (§§35.1–35.2);
- Bar preview hidden compositor-model refresh (§36.1).

Only reopen backend-subscription consolidation when a concrete service is shown to create one independent bus watcher/proxy per visual instance.

### 36.6 SysTray overflow content is eagerly resident, but unloading it is a latency/memory tradeoff — NEEDS BENCHMARK / P2

`modules/bar/SysTray.qml` supplies its overflow `StyledPopup` with a direct `GridLayout` containing a Repeater over `unpinnedItems`.

Thus the unpinned `SysTrayItem` delegate objects exist even when the overflow popup surface is closed.

Those delegates retain:

- icon/UI objects;
- menu wiring;
- item bindings.

A Loader could release them when the overflow is fully closed, but this is not yet strict-lossless because current retained delegates make the first/repeated overflow open immediate and keep item/menu state warm.

Before considering unloading, measure:

- 0/5/20 unpinned tray items;
- first-open and reopen latency;
- resident QML object count and RSS;
- menu-open behavior after reload;
- tray item appearance/disappearance while overflow is closed.

Do not disable the shared SystemTray backend itself.

### 36.7 Bar media shows the same eager-content/prewarm tradeoff; do not classify it as dead work

`BarMediaPopup` is retained StyledPopup content and creates PlayerControl trees for its visible players.

PlayerControl correctly gates its 1-second position timer on actual presentation/window visibility, and EqualizerPanel is also presentation-gated.

However MediaArtworkResolver remains active with track metadata while the popup is hidden, so artwork/cache state can be prepared before the user opens the surface.

That hidden work overlaps the already-audited MediaArtworkResolver candidates (§§25.5–25.6, §35.9), but suppressing it solely because the popup is closed would change prewarm/first-open behavior.

Do not create a new “disable media resolver while hidden” Confirmed item.

### 36.8 Round-22 priority update

New strongest item from this round:

1. **BarTaskbarPreview closed-state compositor refresh gating with synchronous pre-open refresh** — CONFIRMED lossless direction.

Measurement-only follow-ups:

2. ii Bar preview delegate/Image release after visual tail;
3. SysTray overflow delegate residency.

Closed/avoid:

4. PopupAnchorRegistry pruning/index work is retired with the Confirmation experiment;
5. no generic D-Bus centralization based only on multiple QML consumers;
6. no generic lazy-loading of all StyledPopup content.

No runtime implementation is authorized by this handoff.

## 37. Audit round 23 — notification aggregation, per-output Dock/Tray derivation, and focused-window scan dedup (2026-09-29)

This round is research/documentation only. No runtime/source implementation is authorized.

### Snapshot

- Hadalis `dev` at round close before this documentation update: `b4d1296f8a77da5bf9a15309f86f5aa78c17cf0d`.
- Commits after §36 were re-audited first. They affect CloseConfirm / Abyss Polkit/confirmation lifecycle and do not modify the Notification, Dock, SysTray, NiriService, or color-module paths classified below.

Strict lossless rule remains unchanged: preserve publication order, list order, focus freshness, per-output historical ordering, visual phase, and failure/race behavior.

### 37.1 Notifications group rebuild currently traverses history 3N + P times; one-pass construction can preserve exact output — CONFIRMED / P1

Path:

- `services/Notifications.qml`

Every debounced `_updateGroups()` currently does:

1. `root.list.filter(...popup...)` -> **N** visits;
2. `root.list.forEach(...latestTime...)` -> **N** visits;
3. `_groupsForListOptimized(root.list)` -> **N** visits;
4. `_groupsForListOptimized(root.popupList)` -> **P** visits, where P is popup/unread notifications.

Then it sorts all-app and popup-app group keys.

The four traversals can be constructed in one loop over `root.list`:

- append popup notifications to a local `newPopupList`;
- update `newLatestTime[appName]`;
- create/append the all-history group in first-seen order;
- create/append the popup group only when `notif.popup`;
- update `hasCritical`;
- keep popup-group `time` synchronized with the latest all-history time for that app, including later non-popup records.

This preserves current semantics:

- `popupList` order remains the original history order filtered by `popup`;
- all-group insertion order remains first appearance in `root.list`;
- popup-group insertion order remains first popup appearance;
- notification order inside each group is unchanged;
- group `time` remains the latest time for the app across **all** history, not only popup records;
- critical flags remain identical;
- final app-name sorting remains unchanged.

To preserve observable QML publication order, build all local structures first, then assign root properties in the same current sequence:

1. `popupList`;
2. `latestTimeForApp`;
3. all-group cache;
4. popup-group cache;
5. all app-name list;
6. popup app-name list.

QML/JS execution is single event-loop work here, so the source list cannot interleave a mutation in the middle of the local loop.

Traversal effect for this grouping step:

- current: **3N + P** element visits before group-key sorts;
- candidate: **N** history visits, with the existing group-key sorts retained.

For `0 <= P <= N`, that is approximately **66.7% to 75% fewer list-element visits** in the grouping phase.

This is not a whole-shell CPU percentage.

### 37.2 Dock notification badges repeatedly scan every popup app group — CONFIRMED index candidate / P1-P2

Paths:

- `services/Notifications.qml`;
- `modules/dock/DockAppButton.qml`.

`Notifications.countForApp(identifiers)` currently:

1. normalizes the requested identifiers;
2. iterates every key in `popupGroupsByAppName`;
3. normalizes each group app name;
4. returns the first group whose normalized name matches any requested key.

The only runtime consumer found is `DockAppButton.notificationCount`.

Therefore every Dock button, on every output, can repeat the same popup-group scan when notification grouping changes.

Lossless direction:

while §37.1 constructs popup groups, also build an index keyed by normalized app name containing:

- the current first-match group count;
- the group's original enumeration/order rank.

For `countForApp(keys)`:

- normalize the requested keys as today;
- look up candidates directly;
- choose the candidate with the **lowest original group order**.

The order field matters. The current function loops groups on the outside and identifiers on the inside, so identifier-array order must not replace group-order precedence.

For normalized-name collisions, first-write-wins in the index preserves the current first matching group.

To preserve reactive timing, `countForApp()` can continue to read `popupGroupsByAppName` as its QML dependency while using the already-prepared index for the lookup; publish the new index before publishing the new popup-group cache.

Workload:

- current per button: O(G) group scan plus repeated normalization;
- candidate per button: O(K), where the current Dock consumer supplies about two identifiers;
- index construction: O(G) once per notification-group rebuild.

With D Dock buttons on M outputs, the repeated badge portion moves from roughly O(M x D x G) to O(G + M x D x K).

### 37.3 ii SysTray repeats identical global filtering independently on every output — CONFIRMED shared-derived-state candidate / P1-P2

Paths:

- `modules/bar/SysTray.qml`;
- `modules/bar/Bar.qml`;
- `modules/verticalBar/VerticalBar.qml`;
- `services/TrayService.qml`.

Every `SysTray` instance derives from the same singleton `SystemTray.items.values`:

1. `fcitxItems` -> full filter;
2. `itemsInUserList` -> full filter;
3. `itemsNotInUserList` -> full filter;
4. then `pinnedItems/unpinnedItems` are composed from those arrays.

Horizontal and vertical Bar surfaces are instantiated per eligible screen, so this work scales with the number of live `SysTray` instances.

None of those three filters uses screen/output state.

Strict-lossless direction:

compute the **ii Bar-specific** tray lists once in shared service state and let every SysTray instance consume the same ordered arrays.

Preserve exactly:

- `Config.options.bar.tray.*` rather than Waffle's separate `Config.options.tray.*`;
- Fcitx always-visible handling;
- the Spotify passive-status exception;
- `filterPassive`;
- `invertPinnedItems`;
- original `SystemTray.items.values` order.

Do **not** simply reuse current `TrayService.pinnedItems/unpinnedItems`: that service currently follows the Waffle/global `tray.*` configuration and does not have identical filtering semantics.

For M live ii SysTray instances:

- current filter passes per invalidation: **3M**;
- shared derived state: **3**.

Reduction in this filter subwork is `1 - 1/M`:
- 2 outputs: 50%;
- 3 outputs: 66.7%.

No backend D-Bus subscription is removed; this is exactly the local shared-signal work distinguished in §36.5.

### 37.4 DockApps repeats the same expensive toplevel grouping on every Dock output — HIGH CONFIDENCE lossless subwork, keep local historical order

Paths:

- `modules/dock/Dock.qml`;
- `modules/dock/DockApps.qml`;
- `services/CompositorService.qml`.

`Dock.qml` creates Dock surfaces per eligible screen. Each surface has one enabled `DockApps` instance for its current orientation.

Each enabled instance owns an 80 ms rebuild debounce and, on rebuild, independently performs the same global-source work:

- choose `CompositorService.sortedToplevels` / ToplevelManager fallback;
- build the Hyprland live-toplevel cross-check count map when required;
- iterate all selected toplevels;
- call `AppSearch.resolveWindowIdentity(toplevel)`;
- apply the same ignored-app regexes;
- build `runningAppsMap` grouped by normalized app identity.

These inputs are not output-specific.

`CompositorService.sortedToplevels` itself is already shared and lease/refcounted. Multiple Dock `acquireSortingConsumer()` calls do **not** create one sorting pipeline per output. Do not optimize the lease mechanism as if it were duplicate sorting.

The output-local semantic that must remain local is:

`_runningAppOrder`.

It preserves first-seen running-app history inside each DockApps instance. A monitor created later can therefore have a different historical order from an older Dock.

Strict-lossless architecture:

1. share only the output-independent toplevel validation/identity/grouping snapshot;
2. preserve each DockApps instance's own `_runningAppOrder`;
3. perform pinned/separator/local-order composition per output as today;
4. preserve the existing 80 ms publication/debounce contract unless a separate parity test proves otherwise.

For M Dock outputs, the expensive global toplevel grouping pass can move from M copies to one shared pass; the local O(app-count) composition remains per output.

This is a stronger direction than making the entire Dock model global, which would silently erase existing per-output order history.

### 37.5 DockApps has three exact-safe local algorithmic reductions — CONFIRMED / P2

Within `_doRebuildDockItems()`:

#### A. Running-order extension

Current:

- filter old `_runningAppOrder`;
- for every current app, call `runningOrder.includes(lowerAppId)`.

Worst-case membership work is O(A²).

Exact-safe replacement:

- build a `Set` from the filtered `runningOrder`;
- append only unseen map keys while updating the Set.

Order is identical because iteration and append order do not change.

Target: O(A).

#### B. Sort rank lookup

Current running-app sort comparator repeatedly calls:

`root._runningAppOrder.indexOf(appId)`.

All current running IDs have already been inserted into that order and are unique, so there are no equal-rank ties to preserve.

Exact-safe replacement:

- build `orderIndex = Map(appId -> rank)` once;
- comparator reads two O(1) ranks.

This changes worst-case rank lookup from repeated O(A) scans inside O(A log A) comparisons to one O(A) index build plus O(A log A) sorting.

#### C. Pinned membership

In the `separatePinnedFromRunning` branch every running app evaluates:

`pinnedApps.some(p => p.toLowerCase() === lowerAppId)`.

Exact-safe replacement:

- build `pinnedLowerSet` once from `pinnedApps`;
- use `has(lowerAppId)`.

This changes that subwork from O(A x P) repeated lowercasing/membership to O(P + A).

These are small-list optimizations, so no whole-shell percentage is claimed, but they multiply with the per-output duplication in §37.4.

### 37.6 BarTaskbarButton and DockAppButton scan an app's toplevels twice for the active app — CONFIRMED / P2

Paths:

- `modules/bar/BarTaskbarButton.qml`;
- `modules/dock/DockAppButton.qml`.

Both components implement the same pattern:

- `appIsActive`: scan `toplevels` until `_toplevelIsActive()`;
- `focusedWindowIndex`: if active and more than one window, scan `toplevels` again to find the same record.

Exact-safe direction:

derive one `activeToplevelIndex`:

- first matching index, or -1;
- `appIsActive = activeToplevelIndex >= 0`;
- `focusedWindowIndex = activeToplevelIndex >= 0 ? activeToplevelIndex : 0`.

This preserves:

- first-match behavior;
- single-window index 0;
- inactive index 0;
- all current Niri/Hyprland active-window matching logic.

For an active multi-window app, matching scans fall from about **2T -> T**.

### 37.7 Niri focused-window lookup is repeated across many visual instances — CONFIRMED shared-derived-state candidate / P1-P2

Paths include:

- `services/NiriService.qml`;
- `services/GameMode.qml`;
- `modules/bar/ActiveWindow.qml`;
- `modules/bar/BarTaskbarButton.qml`;
- `modules/dock/DockAppButton.qml`;
- `modules/waffle/taskview/WindowThumbnail.qml`.

Several consumers independently run the equivalent of:

`NiriService.windows.find(window => window.is_focused)`.

The most expensive multiplication is Bar/Dock buttons: the same global Niri window list can be scanned once per app button per output.

NiriService already normalizes focus flags in `_normalizeWindowFocus()` before publishing the batched `windows` array.

Lossless shared-state direction:

expose two derived values in NiriService:

1. a **list-authoritative** value equivalent to:
   `windows.find(w => w.is_focused) ?? null`;
2. a **list-first fallback** value equivalent to:
   `focusedWindowFromList ?? activeWindow`.

Then migrate consumers according to their existing semantics:

- ActiveWindow and Waffle WindowThumbnail use list-authoritative;
- BarTaskbarButton, DockAppButton and GameMode use list-first fallback;
- ScreenTime must **not** be mechanically migrated because its current order is `activeWindow ?? windows.find(...)`;
- workspace-local `find(is_focused)` calls must remain local because they operate on a subset, not the global list.

This preserves the reason the current UI reads `windows` first: a focus flag carried by a fresh WindowsChanged/layout batch must win over a stale `activeWindow` fallback.

The shared derived binding performs the global list scan once per `windows` publication instead of once per consumer instance.

### 37.8 Dock/Bar preview shimmer can remain logically running while its popup is hidden — CONFIRMED structure, NEEDS BENCHMARK / not strict-lossless to stop blindly

Paths:

- the former DockWindowPreview component;
- `modules/bar/BarTaskbarWindowPreview.qml`.

Both preview delegates contain:

- a shimmer background visible while the preview Image is not Ready;
- `SequentialAnimation on x`;
- `loops: Animation.Infinite`;
- `running: shimmerBg.visible`.

The running condition does not include Dock popup visibility or StyledPopup presentation state.

Both preview systems retain delegates after close in at least some paths, so a not-yet-ready thumbnail can leave an infinite animation logically running after the popup is hidden.

Qt's Animation contract states that `Animation.Infinite` continues until explicitly stopped. A hidden QQuickWindow stops rendering, but that does not rewrite the QML animation's `running` condition.

Reference:
- https://doc.qt.io/qt-6/qml-qtquick-animation.html

Do **not** yet gate this as a Confirmed lossless implementation.

Why:

- the current animation advances while hidden;
- stopping/pausing it changes shimmer phase if the user reopens before the image becomes Ready;
- that is a visible pixel difference on reopen.

Required benchmark/parity experiment:

- force a slow/missing preview Image;
- close while shimmer is active;
- measure GUI/render wakeups while closed;
- reopen at 100 ms / 1 s / 5 s;
- compare first visible shimmer phase and Image transition.

Waffle TaskView already gates its comparable shimmer with `GlobalStates.waffleTaskViewOpen`, but that precedent does not by itself prove phase parity for ii/Dock.

### 37.9 Cava cover mode executes the same cover-color extraction twice in one generation — HIGH CONFIDENCE duplicate, not yet strict-lossless under source races

Path:

- `scripts/colors/modules/90-cava.sh`.

For `colorSource=cover`, `generate_managed_block()` calls:

`refresh_cover_colors "$gradient_count"`

before the mode switch.

It then enters `build_gradient_cover()`, whose first operation is again:

`refresh_cover_colors "$count" || true`.

No gradient consumes the first extraction result between those two calls.

Each refresh can:

- find the current cover art;
- launch `extract_cover_colors.py`;
- rewrite/remove the cover-color cache.

Under a stable cover source, the extraction process count for this step is plainly **2 -> 1**.

Do not classify the direct deletion as strict-lossless yet because media artwork can change during the first extraction. The current second call intentionally/accidentally samples later in time; a single earlier sample can therefore choose a different track cover.

The correct next step is to define the generation's cover-source identity/freshness contract first. Only then can the duplicate be collapsed without changing which cover wins during a track transition.

### 37.10 Terminal palette module launches 16 jq processes against one generated palette — HIGH CONFIDENCE process candidate; concurrency contract required

Path:

- `scripts/colors/modules/10-terminals.sh`.

`apply_term_sequences()` loops `i=0..15` and for every iteration launches:

`jq -r --arg k "term$i" '.[$k] // empty' "$TERMINAL_FILE"`.

Thus one terminal OSC application currently launches **16 jq processes** against `terminal.json`.

One jq invocation can emit all 16 ordered values, reducing this local parser process count:

- **16 -> 1**;
- **93.75% fewer jq children** for that step.

However this is not yet strict-lossless in the repository's current concurrency model.

`terminal.json` is atomically replaced by `switchwall.sh`, while external theming is launched separately/detached by MaterialThemeLoader. There is no applycolor-wide generation lock proving the palette cannot be replaced during those 16 reads.

Current behavior can therefore observe a mixed old/new palette during a concurrent theme generation. A one-shot read would instead observe one snapshot.

The one-shot behavior is cleaner, but under the user's strict lossless rule it is a semantics change until theming-generation ownership/snapshot identity is specified.

Do not implement this batching in isolation. Pair it with a generation snapshot/serialization contract first.

### 37.11 Waffle Notification Center critical pulse suspicion is CLOSED

Critical Waffle notification-center delegates have infinite pulse animations keyed to critical state rather than the global open flag.

However `ShellWafflePanelsImpl.OnDemandPanelLoader` unloads `WaffleNotificationCenter` after the default 250 ms close grace.

Therefore this is not a steady-state hidden animation tree.

Do not create a notification-center residency optimization from this observation.

### 37.12 Round-23 lossless priority update

New strongest Confirmed directions:

1. one-pass Notification aggregation (§37.1);
2. indexed Dock notification counts preserving group-order semantics (§37.2);
3. shared ii SysTray derived lists across outputs (§37.3);
4. shared output-independent Dock toplevel grouping while retaining local `_runningAppOrder` (§37.4);
5. DockApps Set/Map algorithmic cleanup (§37.5);
6. one active-toplevel scan per Bar/Dock app button (§37.6);
7. shared Niri focused-window derived state (§37.7).

Measurement/parity only:

8. hidden preview shimmer (§37.8);
9. duplicate Cava cover extraction (§37.9);
10. 16 -> 1 terminal palette jq batching (§37.10).

Closed:

11. Waffle Notification Center hidden critical-pulse suspicion (§37.11).

No runtime/source implementation is authorized by this handoff.

## 38. Round 24 — window/app identity duplicated derivation

Research baseline for this round was repeatedly re-fetched from `dev`; the
final pre-write HEAD was `e367881ad35adad26d0ed9c4cd2142035f09b276`.

Runtime commits that landed during the round touched Abyss/Polkit/confirmation
presentation and contracts, not AppSearch/taskbar/preview identity paths. Those
changed-file sets were checked before continuing this round.

### 38.1 Empty app-identity rules still serialize on every resolution — CONFIRMED / P1

Paths:

- `services/AppSearch.qml`;
- `modules/common/Config.qml`;
- `defaults/config.json`.

`windows.appIdentityRules` is empty by default.

Today every non-empty window app id still enters:

`AppSearch._parseIdentityRules()`

which executes:

`JSON.stringify(Config.options?.windows?.appIdentityRules ?? [])`

before discovering that the cached key is still `"[]"`.

This means the normal/default no-rules configuration pays one rules-array
serialization for every `resolveWindowIdentity()` call across Dock, Bar,
AltSwitcher, previews, TaskView and Waffle taskbar derivation.

Exact-safe direction:

1. read the current rules sequence;
2. if its length is zero, preserve the exact current internal state:
   - `_identityRules = []` on the transition to empty;
   - `_identityRulesKey = "[]"`;
3. on steady-state empty rules, return the already-empty parsed list without
   calling `JSON.stringify()`;
4. keep the existing non-empty path unchanged.

This preserves the observable result, first-match contract, malformed-rule
handling and the existing private key value.

For the default no-rules state, rules serialization for this substep is:

- **1 per identity resolution -> 0**;
- **100% fewer `JSON.stringify` calls** for this identity-rules subwork.

No whole-shell percentage is claimed.

### 38.2 Repeated regex identity resolution can be memoized by exact semantic signature — CONFIRMED / P1

Verified current consumers include:

- `services/TaskbarApps.qml`;
- `modules/dock/DockApps.qml`;
- `modules/bar/BarTaskbar.qml`;
- `modules/bar/BarTaskbarPreview.qml`;
- the former DockWindowPreview component;
- `modules/altSwitcher/AltSwitcher.qml`;
- `modules/altSwitcher/AltSwitcherNoVisual.qml`;
- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

For non-empty identity rules, `resolveWindowIdentity()` is a pure function of:

- reported `appId` / `app_id`;
- window `title`;
- the serialized identity-rules key.

The compiled regexes use only the case-insensitive `i` flag, not stateful
`g` / `y` flags.

Therefore a bounded memo keyed by the exact tuple:

`(reportedAppId, title, _identityRulesKey)`

can preserve the current result exactly.

Lossless requirements:

- still call the existing rules parser/key check before a memo hit, so in-place
  rules changes that the current `JSON.stringify` detects remain detectable;
- include title, so title-driven PWA remaps cannot go stale;
- include the exact serialized rules key;
- bound the cache because browser/media titles can generate many signatures;
- eviction may affect performance only, never output;
- keep the empty-rules fast path separate.

For C repeated calls for one semantic window signature under one rules key,
regex traversal changes from about:

`C x R -> R`

plus C bounded-map lookups.

For the regex-traversal component alone:

- 2 repeated consumers: ~50% fewer repeated traversals;
- 3: ~66.7%;
- 4: ~75%.

This matters because Dock/Bar can repeat the same derivation per output,
AltSwitcher prewarms identities, and TaskView search can re-resolve the same
synthetic window records across query changes.

### 38.3 Internal synchronous window passes can snapshot parsed rules once — CONFIRMED / P1

Several internal paths resolve identity inside one synchronous loop/filter over
a known compositor-owned window array, including:

- DockApps rebuild;
- BarTaskbar rebuild;
- Waffle `TaskbarApps.computeApps()`;
- visual AltSwitcher snapshot build;
- no-visual AltSwitcher snapshot build;
- Bar taskbar preview app refresh;
- Waffle TaskView cache refresh.

There is no event-loop yield between elements in these loops. External config
changes therefore cannot interleave between element 1 and element N of the same
pass.

A private/internal batch resolver can safely:

1. parse/snapshot current rules once at the start of a non-empty pass;
2. apply the same first-match regex logic to every window in that pass;
3. return the same per-window strings and ordering as today's repeated calls.

For N windows with non-empty rules, rules-key serialization in that pass drops:

`N -> 1`

or `(N - 1) / N` fewer serializations for that subwork.

Do not expose this as a semantic replacement for arbitrary extension-provided
iterables without defining their mutation/reentrancy contract. The Confirmed
scope is the repository's current synchronous internal compositor-window
passes.

This composes with §38.2: snapshot rules once for a pass, then memo exact window
signatures across repeated consumers/passes.

### 38.4 `guessIcon()` repeats the same heuristic desktop lookup after a synchronous miss — CONFIRMED / P2

Path:

- `services/AppSearch.qml`.

Current `guessIcon(str)` first executes:

`DesktopEntries.heuristicLookup(str)`.

If that returns null, it then calls:

`lookupDesktopEntry(str)`.

But `lookupDesktopEntry()` starts by executing the same
`DesktopEntries.heuristicLookup(appId)` again before trying AppSearch's
reverse maps and token-overlap fallback.

There is no asynchronous boundary between the first miss and the second
heuristic call.

Exact-safe direction:

- factor the post-heuristic reverse-map/token logic into an internal fallback
  helper;
- `lookupDesktopEntry()` keeps its public behavior: heuristic first, then the
  fallback helper;
- `guessIcon()`, after its already-observed heuristic miss, calls only that
  fallback helper.

Do **not** naively replace the two current branches with a single
`lookupDesktopEntry()` return: the current code treats a heuristic entry with
an empty icon differently from a reverse-map entry whose icon is empty.
Preserve those truthiness/null semantics.

On the heuristic-miss branch this changes built-in heuristic lookups:

- **2 -> 1**;
- **50% fewer `DesktopEntries.heuristicLookup()` calls** for that branch.

### 38.5 Global `lookupDesktopEntry()` memo is HIGH CONFIDENCE, not yet Confirmed because of QML binding dependencies

`lookupDesktopEntry(appId)` is otherwise an attractive memo target:

- same app ids are requested repeatedly by Dock, Bar, Waffle taskbar,
  AltSwitcher, previews, ScreenTime, desktop items and MPRIS;
- the expensive fallback can normalize strings and scan tokenized reverse maps;
- AppSearch already has a 500 ms DesktopEntries rebuild epoch.

However a function-level memo can change QML dependency tracking.

A binding that currently misses the heuristic path may read
`_startupClassMap`, `_execBasenameMap` and/or `_desktopIdStemMap`.
A future cache hit that returns before those property reads can drop the
binding dependency, so a later desktop-entry rebuild might no longer
re-evaluate that consumer at the same time.

Therefore do not call this strict-lossless yet.

Required parity contract before promotion:

1. desktop entry added while shell is running;
2. desktop entry removed;
3. startup class / executable / desktop-id fallback match changes;
4. positive and negative cached lookups;
5. QML property bindings using `lookupDesktopEntry()`;
6. preserve the current 500 ms reverse-map publication timing;
7. immediate procedural lookups after `DesktopEntries.applications.values`
   changes must not become staler than today.

A safe implementation may need an explicit reactive epoch read on every cache
hit, but adding or moving that epoch also needs timing parity tests.

### 38.6 Do not collapse raw app id, effective identity and compositor class into one global identity — CLOSED architecture shortcut

Priority 1 initially suggested sharing one app/window identity result everywhere.
The current pixel/behavior contract has observable differences:

- the former DockWindowPreview component resolves
  `AppSearch.resolveWindowIdentity(root.toplevel)` before icon lookup;
- `BarTaskbarWindowPreview.qml` uses the raw
  `root.toplevel?.appId`;
- Waffle bar `tasks/WindowPreview.qml` also guesses from raw
  `toplevel.appId`;
- `OverviewWindow.qml` resolves its icon from Hyprland
  `windowData.class`.

With an `appIdentityRules` remap, forcing all of those surfaces onto one
"effective app id" can change icon/pixel output.

Do not implement a single destructive normalized identity field.

A lossless shared snapshot, if introduced later, must expose distinct fields
such as:

- raw compositor app id/class;
- effective grouping/display identity;
- normalized lowercase grouping key;

and each existing consumer must keep selecting the semantic field it uses
today.

### 38.7 Round-24 priority update

New Confirmed directions:

1. zero-serialization empty identity-rules fast path (§38.1);
2. exact-signature bounded identity-rule memo (§38.2);
3. one parsed-rules snapshot per synchronous internal window pass (§38.3);
4. eliminate the duplicate heuristic lookup inside `guessIcon()` (§38.4).

Needs binding/parity proof:

5. cross-consumer `lookupDesktopEntry()` memo (§38.5).

Closed unsafe shortcut:

6. one universal normalized identity for all preview/overview surfaces (§38.6).

No runtime/source implementation is authorized by this handoff.
## 39. Round 25 — thumbnail coordinator, cache-root parity, preview residency and hidden polling

Research baseline was repeatedly re-fetched from `dev`. The final pre-write
runtime baseline was `4a19fee978be43bd1385832c5f9c2db802ee9935`.

Concurrent commits during this round touched CloseConfirm/Polkit/Abyss prompt
presentation and related contracts, not the wallpaper thumbnail, WindowPreview,
TLP or GameMode paths audited below. Those changed-file sets were checked before
continuing.

One additional concurrent commit, `4747ee62f0c0c501074b43af473fae806f3effee`, landed between the final pre-write fetch and the docs write. The docs commit therefore has that commit as its parent. Its changed-file set was audited immediately afterward and was limited to Confirmation/Abyss confirmation presentation + tests; it did not touch any Round-25 research path.

### 39.1 Wallpaper batch thumbnail scheduling has a split coordinator — CONFIRMED correctness blocker

Paths:

- `services/Wallpapers.qml`;
- `modules/common/widgets/ThumbnailImage.qml`;
- current batch callers in Settings, WallpaperSelector, Coverflow and
  WallpaperLauncher.

The current batch state is not one state machine:

- `thumbnailGenerationRunning` is only `thumbgenProc.running`;
- the Python primary process can fall back to `thumbgenFallbackProc`;
- the fallback is not included in the public busy flag;
- single-thumbnail work has its own queue/process;
- `thumbgenDebounce` only checks the primary process.

This creates several concrete races.

**Busy request loss**

`generateThumbnail()` updates `_pendingThumbnailSize` and
`_pendingThumbnailDir`, then restarts the 300 ms debounce.

When the debounce fires during a primary batch it executes:

`if (thumbgenProc.running) return`

and no primary/fallback exit path re-arms that pending request. A folder or size
request arriving while the primary is busy can therefore be dropped entirely.

This is reachable through normal UI paths: folder changes, selector/coverflow
size changes, background Settings pages and explicit library refresh all call
`generateThumbnail()`.

**Fallback is not busy**

While `thumbgenFallbackProc` is running,
`thumbnailGenerationRunning === false`.

Consequences include:

- `ThumbnailImage._ensureThumbnail()` may start serial single-thumbnail jobs
  against outputs the fallback is already generating;
- WallpaperSelector progress/ready state can report the batch as stopped;
- WallpaperLauncher `loading` can become false while fallback work is active.

**Fallback borrows mutable primary metadata**

`thumbgenFallbackProc` has no directory/size snapshot of its own. Its exit
handler emits:

`thumbnailGenerated(thumbgenProc.directory)`.

Because a new primary can start while the fallback is running, the mutable
`thumbgenProc.directory` may already describe a later request. The fallback can
therefore finish directory A but emit directory B.

Required coordinator contract before further thumbnail optimization:

1. define one batch-busy state covering primary **and** fallback;
2. snapshot directory + size onto the active job, including the fallback;
3. retain/coalesce a pending batch request while busy and drain it after the
   active primary/fallback chain completes;
4. make the public `thumbnailGenerationRunning` reflect that coordinator state;
5. prevent single-thumbnail work from duplicating an active fallback batch;
6. add a two-directory failure test: primary A -> fallback A, request B while A
   is active, assert A emits A and B is replayed afterward rather than dropped.

This is primarily a correctness prerequisite, not a percentage optimization.

### 39.2 Single-thumbnail exit code 1 aliases success and tool failure — CONFIRMED correctness/resource bug

Path:

- `services/Wallpapers.qml`.

The serial single-thumbnail shell command intentionally uses:

- exit 0: output already existed;
- exit 1: `magick` / `ffmpeg` generated the output successfully.

But the external tools' ordinary failure exit can also be 1. The wrapper does
not remap tool failure to a distinct code.

The QML exit handler currently treats:

- exit 0 or 1 as a valid thumbnail and calls `rememberThumbnail()`;
- exit 1 as newly generated and emits `thumbnailGeneratedFile()`.

A real ImageMagick/ffmpeg failure with code 1 can therefore be published as a
successful thumbnail even when the output file does not exist.

For `ThumbnailImage`, this can become repeated churn:

1. false-success signal triggers reload;
2. known-output lookup supplies the missing path;
3. `Image.Error` forgets it;
4. the file test misses;
5. generation is enqueued again.

Exact-safe repair direction:

- preserve 0 for cache hit if desired;
- wrap the tool in an explicit `if tool; then ...; else ...; fi` so generated
  success and tool failure are mapped to different shell exit codes;
- only remember/emit on the two true-success states;
- always clear the pending key and drain the queue on failure.

Required test: a fake generator that exits 1 without creating the output must
never be remembered or emitted as generated.

### 39.3 Freedesktop thumbnail cache root is split under custom XDG cache — CONFIRMED correctness bug

Paths:

- `modules/common/widgets/ThumbnailImage.qml`;
- `services/Wallpapers.qml`;
- `scripts/thumbnails/thumbgen.py`;
- `scripts/thumbnails/generate-thumbnails-magick.sh`.

The code claims these implementations calculate the same thumbnail path, but
they do not under a custom XDG cache root.

`ThumbnailImage.thumbnailPath` uses:

`Directories.genericCache + "/thumbnails/..."`

while:

- `Wallpapers.getExpectedThumbnailPath()` hard-codes
  `$HOME/.cache/thumbnails`;
- `thumbgen.py` uses `~/.cache/thumbnails`;
- the Magick fallback uses `$HOME/.cache/thumbnails`.

Therefore when `XDG_CACHE_HOME != $HOME/.cache` the visual consumer checks one
path while all current producers/resolvers can write another.

This can amplify into repeated generation: a generated-file signal arrives, but
`ThumbnailImage` still cannot find the file at its XDG-aware path.

Lossless repair contract:

1. choose one authoritative cache root;
2. QML and every helper must receive/use that exact root;
3. preserve the current Freedesktop URI encoding + md5 + size-directory layout;
4. test with a temporary `HOME` and a different temporary
   `XDG_CACHE_HOME`, including a non-ASCII filename;
5. assert batch Python, Magick fallback, single-thumbnail generation and
   `ThumbnailImage` all resolve the identical output path.

Prefer passing the authoritative root to helpers rather than independently
reconstructing it in four places.

### 39.4 Window preview cache has the same XDG split — CONFIRMED correctness bug

Paths:

- `services/WindowPreviewService.qml`;
- `scripts/capture-windows.sh`;
- `scripts/capture-windows.fish`.

The QML service uses:

`Directories.genericCache + "/inir/window-previews"`.

The Bash capture helper instead uses:

`$HOME/.cache/inir/window-previews`.

The fish entry point merely execs the Bash helper, so both launch paths share
the mismatch.

Under a custom `XDG_CACHE_HOME`, the helper can successfully write and print
`PREVIEW_READY <id>` in the HOME cache while
`WindowPreviewService._publishCapturedPreview()` records a URL beneath the XDG
cache root. The published preview path may therefore not exist.

Required repair:

- pass the service's exact `previewDir` to the capture helper, preferably via
  one explicit environment value/argument;
- keep a fallback only for supported standalone helper invocation;
- add an XDG contract test that runs with
  `XDG_CACHE_HOME != $HOME/.cache` and verifies the file reported by the
  helper is exactly the file published by the service.

This should be fixed before making deeper WindowPreview cache optimizations.

### 39.5 WindowPreview init can likely remove one helper process per initialization — HIGH CONFIDENCE, failure-contract test required

Path:

- `services/WindowPreviewService.qml`.

Current initialization always runs:

1. `mkdir -p previewDir`;
2. read the session marker;
3. then either:
   - `ls -1 previewDir` for the same session, or
   - `find previewDir ... -delete` for a new/missing session.

Thus the normal pre-capture initialization uses two process-backed helpers:

- warm same-session: `mkdir + ls`;
- cold/new-session: `mkdir + find`.

A narrower design can read the session marker first:

- if the marker is valid, its existence already proves the parent directory
  exists, so proceed directly to the scan;
- if the marker is missing/mismatched, let the reset helper create the
  directory and clear old PNGs in one process.

Local process count becomes:

- warm: **2 -> 1**;
- cold/new session: **2 -> 1**.

Do not mark implementation Confirmed yet because current tests explicitly guard
the standalone directory-helper startup-failure path. Before changing it, inject
and compare:

- missing directory;
- permission-denied directory;
- helper fails to start;
- session marker load failure;
- reset failure;
- subsequent capture request queued during initialization.

The XDG cache-root bug in §39.4 should be fixed first so this test exercises the
real authoritative directory.

### 39.6 Removing or releasing WindowPreview's decoded Overview warm cache is CLOSED under the current contract

Paths:

- `services/WindowPreviewService.qml`;
- `modules/overview/OverviewNiriWidget.qml`;
- `scripts/test-window-preview-lifecycle.sh`.

The service deliberately keeps up to 12 parentless decoded Images at
768 x 512 and Overview uses the same decode dimensions.

The lifecycle contract explicitly requires:

`WindowPreviewService.warmForOverview(windowItems.map(record => record.id))`

so decoded previews survive popup teardown and the next Overview presentation
can reuse the Qt image cache.

Therefore both tempting memory reductions are **not lossless** today:

- do not lazy-create decoded warm Images only after the first Overview open;
- do not clear them merely because Overview closes.

Either changes first-open/reopen decode latency and is directly contrary to the
current regression guard.

The nominal upper bound documented in source is about 18 MiB of decoded pixel
data (12 x 768 x 512 x 4). Reducing the limit/size is a benchmark/product tradeoff,
not an absolute-lossless optimization.

### 39.7 TLP hidden safety polling has real process cost, but demand-gating is not yet strict-lossless — HIGH CONFIDENCE / freshness parity required

Paths:

- `services/TlpRuntimeCapabilities.qml`;
- `services/TlpSettingsService.qml`;
- `modules/settings/TlpPowerSettings.qml`;
- `modules/waffle/settings/pages/WTlpPage.qml`;
- `modules/settings/GeneralConfig.qml`.

Both TLP presentation variants already demand-refresh capabilities/settings when
they become visible.

However the singleton services retain 30-minute safety timers after first
materialization:

- runtime capability tick starts one GPU shell probe and one RDW shell probe;
- settings tick starts one config-status helper.

That is at least **3 top-level process launches per 30 minutes**, or:

- **6 per hour**;
- **144 per 24 hours**

after both singletons have been materialized, excluding subprocesses launched
inside the GPU/RDW shell probes.

The hidden static `TlpPowerSettings` subtree in `GeneralConfig` can
materialize these services even when the System page is currently on Audio.

The repository already has a suitable lifecycle primitive,
`modules/common/widgets/ServiceLease.qml`, with symmetric release on both
visibility changes and component destruction.

Nevertheless, simply gating the 30-minute timers on visible UI is **not**
strict-lossless under this project's freshness rule.

Counterexample:

1. TLP page becomes hidden for longer than 30 minutes;
2. firmware/TLP/runtime capability changes externally;
3. current code may have a fresh snapshot from the background safety tick;
4. a demand-gated version refreshes only when the page becomes visible;
5. because refresh is asynchronous, the first visible frame can briefly show
   an older snapshot.

Thus keep this as a parity/benchmark candidate. Promotion requires an explicit
first-visible freshness contract, not just proof that the page calls
`refresh()` on open.

### 39.8 GameMode 10-second fallback rereads cached Niri state; event-complete replacement is attractive but not strict-lossless yet

Paths:

- `services/GameMode.qml`;
- `services/NiriService.qml`.

GameMode's fallback timer does not query the compositor. It merely schedules
`_doCheckFullscreen()`, which rereads `NiriService.windows/workspaces/outputs`.

NiriService already republishes those inputs on its event stream:

- window list/layout changes are batched then assigned to `windows`;
- workspace updates assign a new `workspaces` map;
- output updates assign a new `outputs` map.

GameMode currently listens to only:

- `activeWindowChanged`;
- `windowsChanged`.

It does not listen to workspace/output changes even though
`isWindowFullscreen()` and `hasVisibleFullscreenWindow` depend on them.

So a fully event-complete implementation is plausible and the 10-second scan is
not a true self-healing compositor poll.

However replacing the timer with workspace/output handlers changes timing.
Today stale `_autoActive` can be cleared on the next periodic phase, anywhere
from roughly 0 to 10 seconds later. An event handler would generally clear it
after the 300 ms debounce.

That timing difference is outside absolute-lossless scope.

Safe next experiments:

- add instrumentation for which fallback ticks actually change
  `_autoActive/_focusedIsFullscreen`;
- test workspace-only fullscreen enter/leave, output hotplug and transient
  WindowLayoutsChanged-before-workspace ordering;
- only then decide whether to retain the timer as sparse safety, guard proven
  no-op states, or replace it with event-complete derivation.

The default interval is 10 seconds, so a normal Niri session currently schedules
up to 360 fallback checks per hour. Do not claim all are removable until the
timing contract is resolved.

### 39.9 Skew wallpaper color analysis decodes every frame of animated images although only the first result is consumed — HIGH CONFIDENCE, malformed-file parity required

Path:

- `modules/wallpaperSelector/WallpaperSkewView.qml`.

The color analyzer skips videos but invokes ImageMagick on image paths without a
frame selector:

`convert <path> -resize 1x1! -colorspace HSL -format ... info:`

For animated GIF/WebP/other multi-frame images this can decode/process multiple
frames.

The parser, however, ultimately consumes only the first three numeric fields for
a filename. Extra frame output does not contribute to the stored hue/saturation
bucket.

That makes a first-frame selector such as `[0]` a strong CPU/I/O candidate,
consistent with the thumbnail generator's existing first-frame treatment.

Do not call it strict-lossless yet. A partially corrupt animation whose first
frame is valid but a later frame fails can have different command exit/output
behavior when only frame 0 is decoded.

Required parity set:

- valid single-frame image;
- valid animated GIF;
- valid animated WebP if supported by installed ImageMagick;
- truncated/corrupt later frame;
- filenames with shell-sensitive and non-ASCII characters.

For valid animations, benchmark total decode CPU/read bytes before and after.

### 39.10 Round-25 priority update

**Correctness blockers to fix before deeper thumbnail/preview optimization:**

1. unify thumbnail primary/fallback/pending coordinator state (§39.1);
2. separate single-thumbnail generated-success from tool failure (§39.2);
3. unify Freedesktop thumbnail cache root under custom XDG (§39.3);
4. unify WindowPreview service/helper cache root under custom XDG (§39.4).

**Performance candidates requiring parity/failure proof:**

5. WindowPreview initialization helper **2 -> 1** (§39.5);
6. TLP hidden safety polling demand/freshness design (§39.7);
7. GameMode event-complete fallback redesign (§39.8);
8. Skew animated-image first-frame color analysis (§39.9).

**Closed under the current lossless contract:**

9. dropping/lazying the resident decoded WindowPreview Overview warm cache
   (§39.6).

No runtime/source implementation is authorized by this handoff.

## 40. Round 26 — icon resolution, stream identity and fullscreen derivation

The final pre-write runtime baseline was
`0219a2ff0337ff03ed05f6044f5c08e1cdf23b4a`.

During this round `dev` moved repeatedly. The changed-file sets were inspected
before continuing. One concurrent series materially changed Dock hover
architecture:

- the former DockPreview component was removed;
- the former DockWindowPreview component was removed;
- Dock hover now exposes the app context menu rather than the retired preview.

Therefore no Round-26 recommendation relies on the deleted Dock preview files.
The surviving DockAppButton identity/icon path was re-audited after that source
change. Later concurrent changes were limited to CloseConfirm/Polkit/Abyss
confirmation presentation and did not touch the Round-26 paths below.

### 40.1 Deduplicate repeated icon-name candidates inside one `guessIcon()` call — CONFIRMED / P1

Path:

- `services/AppSearch.qml`.

After desktop-entry and substitution handling, `guessIcon(str)` checks these
icon-theme candidates in order:

1. the original string;
2. lowercased string;
3. reverse-domain tail;
4. lowercased reverse-domain tail;
5. kebab-normalized string;
6. underscore-to-kebab string;
7. reverse-domain prefix guesses;
8. later fuzzy-result icon candidates.

For common simple lowercase ids without spaces/dots/underscores, the first six
values are identical. A miss such as a simple `"firefox"`-shaped key can
therefore call `iconExists()` six times for the same string. Each
`iconExists()` resolves the icon through `Quickshell.iconPath()`.

Exact-safe direction:

- keep the current candidate order;
- keep a synchronous local `Set` of icon names already tested;
- skip only exact duplicate strings in the same call;
- do not memoize across calls.

Local reduction for a simple lowercase miss:

- icon existence/theme-resolution probes: **6 -> 1**;
- **83.3% fewer** probes across that normalization block.

A mixed-case simple id generally collapses to two unique names rather than six,
or about **66.7% fewer** probes in that block.

This is independent of Round 24's confirmed duplicate
`heuristicLookup()` miss.

### 40.2 `lookupDesktopEntry()` repeats exact same map probes — CONFIRMED / P1

Path:

- `services/AppSearch.qml`.

The direct stage currently probes:

`startup[lowered] -> exec[lowered] -> id[lowered] -> exec[kebab] -> id[kebab]`.

When the id contains no whitespace, `kebab === lowered`. On a miss, the exact
same exec/id keys are therefore read twice:

- current direct-stage map reads: **5**;
- unique exact key+map reads: **3**;
- local reduction: **40%**.

The aggressive-normalization stage has the same class of duplication:

- `joinedNoSuffix === joined` when no removable suffix exists;
- `reversedNoSuffix === reversed` in the same case;
- `segClean === seg` for ordinary segments, causing exec/id/startup probes for
  that exact key to repeat.

Lossless rule:

- dedupe only an **exact key + exact map** probe;
- preserve the existing precedence between startup/exec/desktop-id maps;
- preserve the current candidate ordering between distinct normalized keys.

### 40.3 Precompute tokenized reverse-map keys for hard desktop-entry fallback — HIGH CONFIDENCE / benchmark

Path:

- `services/AppSearch.qml`.

The last-resort token-overlap fallback re-runs regex replacement, trim and split
for every key in:

- `_desktopIdStemMap`;
- `_startupClassMap`.

Those key strings change only when AppSearch rebuilds its reverse maps.

A revision-scoped prepared array can retain each key's token list and associated
entry, while preserving:

- desktop-id map scan before startup-class map scan;
- current `score > bestScore` tie behavior;
- current 0.5 threshold.

This removes **100% of repeated candidate-key regex/split allocations** from
steady-state hard lookups; query-token construction remains.

Benchmark memory before promoting to implementation because the prepared token
arrays trade a bounded amount of resident memory for fewer allocations/CPU.

### 40.4 Bar taskbar window preview performs one redundant desktop-entry traversal — CONFIRMED / P1

Path:

- `modules/bar/BarTaskbarWindowPreview.qml`.

Current icon binding:

1. `lookupDesktopEntry(appId)`;
2. if no declared icon, `guessIcon(appId)`;
3. `guessIcon()` itself performs desktop-entry resolution.

The local `de` object is not otherwise used in this component.

Using `AppSearch.guessIcon(appId)` directly preserves the same icon selection
order because `guessIcon()` already prefers the desktop entry's declared icon
before substitutions/theme guesses.

On a true desktop-entry miss:

- full desktop-entry fallback traversals: **2 -> 1**;
- local reduction: **50%**.

Round 26 originally found the same pattern in DockWindowPreview, but that file
was concurrently removed before this handoff was written. Do not reintroduce
that obsolete finding.

### 40.5 Waffle window preview resolves the same app icon twice — CONFIRMED / P1

Path:

- `modules/waffle/bar/tasks/WindowPreview.qml`.

The same delegate uses:

`AppSearch.guessIcon(root.toplevel.appId)`

for both:

- the 16 px header app icon;
- the 64 px fallback icon shown while/no window preview is available.

Both are icon **name** resolution for the same toplevel; requested paint size is
handled by the downstream icon component.

A root/delegate readonly resolved icon name shared by both consumers gives:

- `guessIcon()` calls: **2 -> 1**;
- **50% fewer** icon-name resolutions per binding reevaluation.

### 40.6 Waffle taskbar already owns the desktop entry but resolves it again for the icon — CONFIRMED / P1

Path:

- `modules/waffle/bar/tasks/TaskAppButton.qml`.

The component already keeps:

`desktopEntry: AppSearch.lookupDesktopEntry(appEntry.appId)`

for launch, actions, menu and tooltip behavior.

Its icon still uses:

`AppSearch.guessIcon(appEntry.appId)`.

Exact-safe direction:

`desktopEntry?.icon || AppSearch.guessIcon(appEntry.appId)`.

When the resolved desktop entry has an icon, the common hit path changes from:

- desktop-entry resolution for the property;
- another desktop-entry/heuristic resolution inside `guessIcon()`;

to reusing the entry already required by the component.

That common branch is approximately **2 -> 1 desktop/heuristic resolutions**
(**50% fewer**). Missing-icon behavior keeps the existing `guessIcon()`
fallback unchanged.

### 40.7 Autostart delegates call the complete icon resolver twice with identical arguments — CONFIRMED / P1

Paths:

- `modules/settings/AutostartConfig.qml`;
- `modules/waffle/settings/pages/WAutostartPage.qml`.

Each app delegate calls the exact same expression twice:

`AppSearch.getIconSource(modelData.icon, modelData.name)`

for:

- the `Image.source`;
- fallback-icon visibility.

A delegate-level readonly resolved-source property preserves all existing QML
dependencies and fallback behavior while changing:

- complete icon-resolution calls: **2 -> 1**;
- local reduction: **50%**.

Do not combine this performance change with fallback-visibility redesign.

### 40.8 Re-resolving a candidate after `iconExists()` is a real duplicate, but needs an internal resolver contract — HIGH CONFIDENCE

Paths:

- `services/AppSearch.qml`;
- `modules/waffle/actionCenter/volumeControl/VolumeEntry.qml`;
- `services/MprisController.qml`;
- `modules/waffle/looks/WIcons.qml`.

`iconExists(name)` already calls `Quickshell.iconPath(name, true)`.

A successful normalized branch in `guessIcon()` can therefore:

1. resolve the theme path inside `iconExists()`;
2. return only the icon name;
3. make `getIconSource()` resolve the same name again.

`VolumeEntry` can add another explicit `AppSearch.iconExists(guessed)`
before calling `Quickshell.iconPath(guessed, "")`, giving up to three theme
resolutions for one successful candidate path.

Do not change public `guessIcon()` semantics from icon-name to source-path.
A safer design would add a private/internal resolver that can return both
`{name, source/existence result}` so callers that need a final source can reuse
the lookup while name-only APIs remain unchanged.

Theme changes are live before shell restart, so any cross-call cache must include
theme invalidation; per-call reuse is substantially safer.

### 40.9 MPRIS stream desktop-entry resolution retries the exact binary hint — CONFIRMED / P1

Path:

- `services/MprisController.qml`.

`streamDesktopEntry(node)` first tries a non-generic
`application.process.binary`.

If that misses, the later id list is:

`[application.id, binary, application.name]`

and therefore tries the same cleaned binary again.

Each `_desktopEntryForHint()` miss can:

1. call `AppSearch.lookupDesktopEntry()`;
2. scan all `DesktopEntries.applications.values`;
3. normalize and score up to five fields per entry.

A local ordered set of already-attempted cleaned hints removes the exact repeat
without changing precedence.

For the duplicated binary miss:

- full hint fallback scans: **2 -> 1**;
- **50% fewer** scans for that hint.

### 40.10 Stream display-name resolution repeats player matching and desktop-entry hints — CONFIRMED duplicate work

Path:

- `services/MprisController.qml`.

`streamDesktopEntry(node)` calls `playerForStreamNode(node)`.

When no desktop entry is returned, `streamDisplayName(node)` calls
`playerForStreamNode(node)` again.

That player scan is non-trivial: for each displayed MPRIS player,
`_streamMatchScore()` compares three player identities against up to eleven
node identities and repeatedly performs key/token normalization.

A shared per-call resolver carrying the already-computed player changes the
player-match pass:

- **2 -> 1**;
- **50% fewer** player scans on this miss path.

There is a second duplicate layer: when a player existed but its
`player.desktopEntry` / `player.identity` hints failed in
`streamDesktopEntry()`, `playerDisplayName()` may immediately try the same
two desktop-entry hints again.

Preserve the current matching threshold and browser-name special cases; share
resolved intermediates rather than replacing heuristics.

### 40.11 Volume mixer delegates repeat the whole stream presentation resolver — CONFIRMED / P1

Paths:

- `modules/sidebarRight/volumeMixer/VolumeMixerEntry.qml`;
- `modules/ii/sidebarRight/volumeMixer/VolumeMixerEntry.qml`.

The first delegate invokes stream identity through:

- icon -> `streamIconName(node)` -> `streamDesktopEntry(node)`;
- visible label -> `streamDisplayName(node)` -> `streamDesktopEntry(node)`;
- accessible label -> `streamDisplayName(node)` again.

That can produce **3 desktop-entry presentation passes per delegate**.

The ii variant performs icon + display-name resolution, i.e. **2 passes**.

A reactive per-delegate presentation snapshot can reduce:

- first variant: **3 -> 1**, about **66.7% fewer** stream-entry resolution passes;
- ii variant: **2 -> 1**, **50% fewer**.

A minimal first step is to share only `streamDisplayName(node)` between text and
Accessibility in the first variant.

Because PipeWire node properties and MPRIS metadata are reactive, add a binding
parity test before centralizing the full `{entry,player,name,icon}` snapshot.

### 40.12 Precompute immutable desktop-entry scoring metadata inside MPRIS — HIGH CONFIDENCE / P1 benchmark

Path:

- `services/MprisController.qml`.

When direct AppSearch lookup misses, `_desktopEntryForHint()` scans the full
desktop-entry collection. For every candidate entry it repeatedly normalizes up
to:

- id;
- name;
- generic name;
- StartupWMClass;
- command basename/path.

These candidate-side strings are invariant until DesktopEntries changes.

One `streamDesktopEntry()` can attempt roughly six hints on a full miss.
Without prepared candidate metadata, the candidate-side normalization budget can
approach:

`6 x D x 5`.

With metadata prepared once per DesktopEntries publication:

`1 x D x 5`

for the invariant candidate side, or up to about **83.3% fewer candidate
normalization operations** across a six-hint full miss.

Important freshness constraint:

**do not reuse `AppSearch._cachedList` for this.**

AppSearch deliberately publishes its rebuild after a 500 ms debounce, while
MPRIS currently reads `DesktopEntries.applications.values` directly. Reusing
the AppSearch list would introduce a new stale window. MPRIS needs an immediate
DesktopEntries-aware epoch/index if this optimization is implemented.

### 40.13 AltSwitcher icon caches can remain stale after live DesktopEntries changes — CONFIRMED freshness bug

Paths:

- `modules/altSwitcher/AltSwitcher.qml`;
- `modules/waffle/altSwitcher/WaffleAltSwitcher.qml`;
- `services/AppSearch.qml`.

Both visual switchers keep a bounded icon cache keyed by:

`appId || appName || title`

and store `AppSearch.getIconSource(key)`.

Neither cache has a DesktopEntries/AppSearch invalidation hook.

The visual ii switcher is kept resident by its family-level LazyLoader while ii
visual mode is active. The Waffle visual switcher is likewise kept resident
while its visual mode loader is active.

Thus a desktop entry/icon installed or changed after a cache entry is warm can
leave the old icon source resident for the rest of that component lifetime.

Icon-theme setters generally queue a shell restart, but live DesktopEntries
changes do not.

Fix direction:

- expose a coherent AppSearch desktop-entry publication epoch;
- clear only the switcher's icon source cache when that epoch changes;
- retain the existing 100-entry bounded/LRU behavior.

### 40.14 AppSearch's current `_cacheRevision` is not a safe external publication barrier — CONFIRMED design constraint

Path:

- `services/AppSearch.qml`.

Current rebuild order is:

1. publish new cached list/name arrays;
2. increment `_cacheRevision`;
3. build the new startup/exec/desktop-id reverse maps;
4. publish those maps.

An external cache that reacts immediately to
`_cacheRevisionChanged`, clears itself and resolves an icon can therefore see:

- the new list revision;
- the old reverse maps.

The existing revision is sufficient for AppSearch's internal lazy fuzzy arrays,
but it should not be treated as a coherent external desktop-entry epoch.

If Round 26/27 adds icon-cache invalidation, either:

- move a dedicated publication revision increment to after all reverse maps are
  assigned; or
- introduce a separate `desktopEntryRevision` at the end of the rebuild.

Existing `scripts/test-appsearch-binding-cache.sh` tests lazy fuzzy-cache reuse
and deferred QML publication only. It does not cover coherent external cache
invalidation.

### 40.15 Merge GameMode global any/visible fullscreen derivation into one pass — CONFIRMED / P1

Path:

- `services/GameMode.qml`.

Current global derivation performs two separate scans of the same Niri window
snapshot:

- `checkAnyFullscreenWindow()`;
- `hasVisibleFullscreenWindow`.

Both call `isWindowFullscreen()`.

A single snapshot result `{ any, visible }` can preserve the exact distinction:

- `any`: fullscreen on any workspace;
- `visible`: fullscreen on an active workspace.

It can stop once both values are true.

Local reductions:

- no fullscreen: **2N -> N** fullscreen checks = **50% fewer**;
- first fullscreen is active at position k: **2k -> k** = **50% fewer**;
- background fullscreen before active fullscreen: current is approximately
  `i + j`, shared pass needs only the later active result `j`, never more.

Keep Hyprland/non-Niri public behavior unchanged.

### 40.16 Memoize per-output fullscreen result on demand by Niri snapshot identity — CONFIRMED / P1 for ii/Waffle surfaces

Paths:

- `services/GameMode.qml`;
- `services/NiriService.qml`;
- current callers in ScreenEdges, ScreenCorners, Background, WaffleBackground,
  SidebarHost and WidgetPowerManager.

`hasFullscreenOnOutput(outputName)` currently scans the Niri window list on
every caller evaluation.

NiriService was audited for mutation semantics:

- window publications assign new arrays;
- workspace changes assign new maps;
- output changes assign new maps;
- `sortWindowsByLayout()` returns a new array;
- no in-place `windows[i] =`, `workspaces[id] =` or `outputs[name] =`
  mutation was found for these published state containers.

Therefore an on-demand memo can key one generation by the exact references:

- `windows`;
- `workspaces`;
- `outputs`;
- compositor/Niri mode;

then cache `outputName -> bool`.

This keeps the first call on a new snapshot exactly as expensive/fresh as today
and makes repeated same-output queries O(1). It avoids the possible regression
of eagerly computing every output for families such as Abyss that do not
currently use this API.

Concrete ii example:

`ScreenEdges.qml` creates four ReservationWindows per output, and each has the
same `GameMode.hasFullscreenOnOutput(outputName)` binding.

For that cluster alone:

- current: roughly **4N** window scans;
- on-demand memo: **N** for the first caller + three O(1) lookups;
- **75% fewer full-window scans**.

Other same-output callers can reuse the same result.

### 40.17 Preserve GameMode fallback timing while skipping deterministic repeated scans — HIGH CONFIDENCE / parity required

Paths:

- `services/GameMode.qml`;
- `services/NiriService.qml`.

Round 25 rejected simply replacing the 10-second fallback timer with new event
handlers because that changes activation/deactivation timing.

A narrower design can retain the current phase:

1. keep `fallbackTimer` and its configured interval unchanged;
2. keep the timer scheduling the 300 ms `checkDebounce` exactly as today;
3. maintain a revision covering all fullscreen inputs
   (windows, workspaces, outputs, active-window/focus relevant publication,
   autoDetect/compositor state);
4. at the debounce trigger, compare that input revision with the revision last
   actually processed;
5. run `_doCheckFullscreen()` only if the input revision changed.

Do **not** skip starting the debounce at the 10-second timer itself. An input
event may arrive during that 300 ms window; current code would observe the new
state at the scheduled trigger.

Once Niri state is stable, this can reduce fallback-induced full-window scans
from up to **360 per hour -> 0 per hour**, while retaining the timer and debounce
wakeups/timing.

Parity matrix must include:

- workspace-only activation change;
- output hotplug/layout change;
- F11/layout update with unchanged focus;
- autoDetect toggle;
- compositor initialization;
- input change arriving during the fallback's 300 ms debounce window.

### 40.18 WidgetPowerManager computes the same pure pause decision twice — CONFIRMED / P1

Paths:

- `services/WidgetPowerManager.qml`;
- `modules/background/widgets/AbstractBackgroundWidget.qml`.

Global properties currently evaluate:

- `widgetsActive = !shouldPauseForOutput("")`;
- `reducedMode = shouldPauseForOutput("")`.

A shared readonly `globalPaused` result gives:

- **2 -> 1** full decisions;
- **50% fewer** global decision evaluations.

Every AbstractBackgroundWidget repeats the same pattern per output:

- `powerActive = widgetsActiveForOutput(outputName)`;
- `powerReduced = reducedModeForOutput(outputName)`.

Those wrappers are direct inverses around the same pure
`shouldPauseForOutput()`.

A widget-local `powerPaused` binding with:

- `powerActive = !powerPaused`;
- `powerReduced = powerPaused`;

changes per-widget full decisions from:

- **2 -> 1**;
- **50% fewer**.

The decision function has no side effects, so this does not depend on a
cross-event cache.

### 40.19 WidgetPowerManager also checks output eligibility twice on the allowed path — CONFIRMED / P2

Path:

- `services/WidgetPowerManager.qml`.

For a non-empty allowed output, `shouldPauseForOutput()` first calls
`DesktopWidgetLayout.outputAllowed(scopedOutput)` for its early-return guard.

Then `_triggersForOutput()` computes `outputDisabled` by calling the same
function again.

Preserve the current early return so disabled outputs do not pay fullscreen or
window-presence work, but pass the already-computed eligibility into the
internal trigger builder.

Allowed path:

- `outputAllowed()` calls: **2 -> 1**;
- **50% fewer**.

### 40.20 Conditional window-presence memo for widget power saving — HIGH CONFIDENCE / P2

Path:

- `services/WidgetPowerManager.qml`.

When `pauseWhenWindowsPresent=true`,
`_hasWindowsOnActiveWorkspace(outputName)`:

- enumerates/filter active workspaces;
- scans windows;
- for each window may search the active-workspace collection.

After §40.18 removes the same-widget double evaluation, multiple widgets on the
same output can still repeat that work.

An on-demand memo keyed by the published `windows/workspaces` references and
output name can share the answer across widgets.

Default `pauseWhenWindowsPresent` is false, so this is conditional/P2 rather
than a default-path priority.

Keep its semantics separate from Background dynamic opacity: Background counts
any window on the active workspace, while WidgetPowerManager intentionally
filters minimized windows.

### 40.21 Lazy `windowForId` map for published Niri snapshots — HIGH CONFIDENCE / P2

Paths:

- `services/NiriService.qml`;
- `modules/waffle/bar/tasks/TaskAppButton.qml`;
- `services/MinimizedWindows.qml`.

No published window-id index currently exists.

Two consumers show repeated linear lookup patterns:

**Waffle taskbar**

For an app with A toplevels,
`TaskAppButton.focusedWindowIndex` performs
`NiriService.windows.find(id)` inside the A-item loop:

- current complexity approximately `A x N`;
- lazy per-snapshot id map: `N + A`.

For A=2 and large N, this approaches ~50% fewer comparisons; A=5 approaches
~80%.

**MinimizedWindows**

`stashWorkspaceForOutput()` loops M minimized ids and calls
`liveWindows.find(id)` for each:

- current: `M x N`;
- lazy map: `N + M`.

Use a demand-built map keyed by the published windows-array reference so a
session with no id lookups does not pay the map build.

Do not replace NiriService's own handlers that deliberately inspect
`_pendingWindows`; the helper is for consumers of the published snapshot.

### 40.22 Round-26 priority update

**Confirmed, local, lowest-risk:**

1. AppSearch per-call duplicate icon candidate suppression (§40.1);
2. AppSearch exact map-probe suppression (§40.2);
3. Bar preview redundant lookup removal (§40.4);
4. Waffle WindowPreview shared icon name (§40.5);
5. Waffle TaskAppButton desktop-entry icon reuse (§40.6);
6. Autostart per-delegate resolved icon source (§40.7);
7. MPRIS exact duplicate hint suppression (§40.9);
8. GameMode global any/visible one-pass derivation (§40.15);
9. GameMode on-demand per-output snapshot memo (§40.16);
10. WidgetPower duplicate pause-decision and outputAllowed suppression (§40.18-40.19).

**Confirmed duplicate work but implementation needs a reactive snapshot contract:**

11. MPRIS stream display/player intermediate sharing (§40.10);
12. VolumeMixer per-delegate stream presentation sharing (§40.11);
13. AltSwitcher DesktopEntries-driven icon cache invalidation (§40.13-40.14).

**High confidence / benchmark or parity required:**

14. AppSearch prepared token-overlap keys (§40.3);
15. reuse resolved icon-path existence within a call (§40.8);
16. MPRIS prepared desktop-entry scoring metadata (§40.12);
17. GameMode stable-revision fallback scan suppression (§40.17);
18. WidgetPower window-presence memo (§40.20);
19. lazy Niri published-window id map (§40.21).

**Closed by concurrent architecture change:**

20. any DockWindowPreview-specific optimization from the early Round-26 audit;
    that runtime was removed before this handoff was committed.

No runtime/source implementation is authorized by this handoff.

## 41. Round 27 — Niri snapshot hot paths, Task View indexing and stream matching

The final pre-write runtime baseline was
`fd01e20c9a805f51bdd7ca245ccce363dd4bf682`.

One additional concurrent commit, `6f7f706d6a905aac106c54fe4b21762dac24d6df`, landed between the final pre-write fetch and the docs write and therefore became the actual parent of the Round-27 handoff commit. Its changed-file set was audited immediately afterward and was limited to the now-retired Abyss confirmation content component plus its confirmation contract test; it did not touch any Round-27 research path.

`dev` moved during this round, but every concurrent delta was audited before
continuing. The commits after the initial Round-27 baseline touched
CloseConfirm/Polkit and their tests only; none changed NiriService, Task View,
Overview, MPRIS, Session, AppSearch or the workspace/background paths described
below.

Current defaults matter for priority:

- `panelFamily` is `"abyss"`;
- the legacy/ii QuickLaunch widget is disabled by default
  (`sidebar.widgets.launch=false`);
- Bar workspace app icons are disabled by default
  (`bar.workspaces.showAppIcons=false`, `shown=5`);
- `compositor.autoExpandSingleTilingWindow=false`.

Do not present conditional ii/Waffle costs below as stock-Abyss idle costs.

### 41.1 Niri WindowLayoutsChanged performs C linear ID searches — CONFIRMED / P1

Path:

- `services/NiriService.qml`.

`handleWindowLayoutsChanged()` clones the current window list, then for every
layout change performs:

`updatedWindows.findIndex(w => w.id === windowId)`.

For N windows and C changed layouts this is approximately:

`C x N`

ID comparisons in the miss/worst path.

Exact-safe direction:

1. clone the list exactly as today;
2. build `windowId -> first index` once from that cloned list;
3. apply each layout change through the index;
4. preserve existing list order and `scheduleWindowsUpdate()` timing.

Complexity becomes:

`N + C`.

When C ~= N, this changes a quadratic-shaped lookup phase from about `N²` to
about `2N`.

If defensive duplicate IDs are considered, store only the first index so the
map matches current `findIndex()` semantics.

### 41.2 Niri WindowClosed scans the same list twice — CONFIRMED / P1

Path:

- `services/NiriService.qml`.

Current close handling:

1. `find()` the closing window to capture `workspace_id`;
2. `filter()` the same list to remove the window.

That is close to **2N -> N** list visits.

A single pass can:

- capture the first matching window/workspace;
- append every nonmatching window to the replacement list.

This preserves the current publication order and still removes every duplicate
ID defensively if one somehow exists.

Local reduction: approximately **50% fewer window-list visits** in this phase.

### 41.3 Focus normalization allocates an N-element throwaway array on the common no-change path — CONFIRMED / P1

Path:

- `services/NiriService.qml`.

`_normalizeWindowFocus()` currently uses `windowList.map(...)` unconditionally
after a focused-window id has been observed.

If every `is_focused` flag is already correct, the function ultimately returns
the original `windowList`, but the full mapped array was already allocated and
filled.

Use lazy copy-on-first-mismatch:

- scan the original array;
- if no flag differs, return the original list with **zero replacement-array
  allocation**;
- on the first mismatch, allocate/copy once and clone only windows whose focus
  flag must change.

This preserves the existing important identity contract: unchanged input still
returns the original array.

On no-change calls the temporary N-element array allocation changes from:

**1 -> 0**.

### 41.4 Positional fast path before `_windowOrderDiffers()` builds an ID map — HIGH CONFIDENCE / benchmark

Path:

- `services/NiriService.qml`.

For equal-length lists, `_windowOrderDiffers()` currently always builds a
`Map(window.id -> previousWindow)`, even when every window remains in the same
position and only title/focus/non-order fields changed.

A safe fast path can compare the two arrays positionally first:

- if ids are equal at each position, compare the existing order-relevant fields
  directly and return;
- only if a positional id differs, fall back to the current map-based algorithm.

This preserves the exact reorder definition and avoids the map allocation for
the common same-order case.

Keep this benchmark-gated because the savings depend on actual Niri event mix.

### 41.5 Single-window auto-expand only needs 0 / 1 / >1 matches — CONFIRMED / P2 conditional

Path:

- `services/NiriService.qml`.

`_applySingleWindowPolicy()` currently filters the full window list into an
array of tiling windows for a workspace.

Its decisions require only:

- zero matching tiling windows;
- exactly one matching window and that object;
- more than one matching window.

A streaming scan can retain the first match and stop on the second, eliminating
the filtered-array allocation and potentially stopping early.

The feature is disabled by default, so this is conditional/P2 rather than a
stock idle-path priority.

### 41.6 Centralize the focused window from the published Niri window snapshot — CONFIRMED / P1

Paths:

- `services/NiriService.qml`;
- `modules/dock/DockAppButton.qml`;
- `modules/bar/BarTaskbarButton.qml`;
- Waffle Task View consumers.

Every published Niri window batch already contains `is_focused`.

NiriService itself calculates the focused object once when publishing the batch,
but every Dock button and every Bar taskbar button independently executes:

`NiriService.windows.find(window => window.is_focused)`.

Do not replace those bindings with the imperative `activeWindow` property
blindly, because publication order between `windows` and `activeWindow`
notifications is part of first-frame freshness.

Exact-safe direction:

- expose one readonly derived property whose binding directly reads the
  published `windows` array and performs the same `find(is_focused)`;
- all consumers read that derived value.

A QML readonly binding is invalidated by `windows` itself, so it retains the
same-snapshot semantic while centralizing the scan.

For D Dock delegates and B Bar delegates, repeated focused-window scanning can
drop from roughly:

`(D + B) x N`

to one shared `N` scan plus O(1) reads.

Waffle Task View (§41.10) can reuse the same result.

### 41.7 Add a demand-scoped active-workspace/workspaces-by-output derivation — HIGH CONFIDENCE / P2

Paths include:

- `modules/background/Background.qml`;
- `modules/waffle/background/WaffleBackground.qml`;
- `services/WidgetPowerManager.qml`;
- `modules/bar/Workspaces.qml`;
- `modules/overview/Overview.qml`;
- `modules/overview/OverviewNiriWidget.qml`.

Multiple consumers independently convert/filter the same Niri workspace map to
answer:

- active workspace for output X;
- all workspaces for output X.

NiriService publishes a fresh `workspaces` map when workspace state changes, so
an on-demand cache can key by the exact map reference and output name.

Prefer demand-scoped lookup over an eagerly rebuilt global structure so a family
that never asks for the data does not pay unnecessary work.

Any helper called from a QML binding must still read the published
`root.workspaces` property before returning a memoized answer, so the binding
retains the proper dependency.

### 41.8 `allWorkspaces` is already sorted; Overview sorts filtered subsets again — CONFIRMED / P1 when Task View/Overview is active

Paths:

- `services/NiriService.qml`;
- `modules/overview/OverviewNiriWidget.qml`;
- `modules/overview/Overview.qml`.

All three assignments to `NiriService.allWorkspaces` explicitly sort by
`workspace.idx`.

JavaScript `filter()` preserves source order.

Therefore these are redundant:

- `OverviewNiriWidget.workspacesForOutput.filter(...).sort(idx)`;
- Niri Left key handler in `Overview.qml`;
- Niri Right key handler in `Overview.qml`.

Removing the secondary sort preserves ordering exactly.

This is relevant to the current default Abyss family: `AbyssOverviewContent`
loads `OverviewNiriWidget` for Niri Task View.

### 41.9 Waffle Task View refresh scans all windows once per workspace — CONFIRMED / P1 when Waffle Task View is used

Path:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

`refreshCache()` loops W workspaces and for each one runs:

`NiriService.windows.filter(window => window.workspace_id === ws.id)`.

Membership work is therefore approximately:

`W x N`.

Build `workspace_id -> windows[]` once in a single N-window pass, then sort each
bucket with the current X-position comparator.

Grouping preserves source order within each bucket, and the same subsequent
sort preserves current presentation ordering.

Membership scanning becomes:

`N`.

For five workspaces, this is roughly **5N -> N**, or **80% fewer membership
visits**.

### 41.10 Every Waffle WindowThumbnail independently scans for the same focused window — CONFIRMED / P1

Path:

- `modules/waffle/taskview/WindowThumbnail.qml`.

Every thumbnail evaluates:

`NiriService.windows.find(w => w.is_focused)`

only to obtain the same focused window id.

With I visible/cached window thumbnails this repeats the same global lookup I
times.

Use the shared published focused-window derivation from §41.6 or pass one
focused id from the parent.

Worst-shaped comparison work changes from approximately:

`I x N -> N + I O(1) reads`.

If I=N, the repeated-scan shape falls from N² toward N.

### 41.11 Waffle Task View repeatedly derives per-slot counts/emptiness from the same cached item list — CONFIRMED / P1

Path:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

For cached items I and workspaces W, current bindings include:

- `previewCounts`: W full `filter()` passes;
- each workspace `isEmpty`: W `some()` passes;
- `isLastEmpty`: up to one extra `some()`;
- bottom-dot `windowCount`: W more `filter()` passes;
- `getWindowsInSlot()`: another filter whenever keyboard navigation asks.

Persistent derivation is therefore on the order of roughly:

`(3W + 1) x I`

item visits before interaction-specific calls.

Build once per `cachedWindowItems` publication:

- `itemsBySlot`;
- `countBySlot`;
- optionally `itemByWindowId`.

Then count/empty/window-list reads are O(1).

Drag preview semantics can remain exact. Current logic removes
`draggingWindowId` from every slot count and adds one to the target slot.
Starting from base counts, subtract one from the dragged item's actual slot if
present, then add one to the target.

### 41.12 Waffle Task View resolves an already-resolved app identity a second time — CONFIRMED correctness bug

Path:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

During `refreshCache()`, the cached window stores:

`app_id: AppSearch.resolveWindowIdentity(rawWindow)`.

Later search filtering calls:

`AppSearch.resolveWindowIdentity(w.window)`

on that already-remapped cached object.

Identity rules are first-match rules, not declared idempotent transformations.
With rules such as:

- raw `foo -> bar`;
- `bar -> baz`;

the display cache stores `bar`, while search can remap the cached record again
to `baz`.

Search/display identity can therefore diverge.

Fix contract:

- resolve raw compositor identity exactly once when building the Task View
  snapshot;
- search the cached effective identity directly.

This also removes unnecessary rule parsing/regex work per search item.

### 41.13 Precompute Task View lowercase search fields once per cache refresh — CONFIRMED / P1

Path:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

Every typed search character currently lowercases both:

- cached window title;
- app identity;

for every cached item.

Those strings are already snapshot data.

Store lowercase search fields when `refreshCache()` builds the record.

For a K-character query over I items, candidate-side lowercasing changes from
roughly:

`2 x K x I -> 2 x I`.

At K=5 this is about **80% less candidate-side lowercase work**.

Combine this with §41.12 so the cached app field is the single effective
identity.

### 41.14 Waffle Task View count-only cache invalidation misses meaningful count-preserving updates — CONFIRMED correctness prerequisite

Path:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

While Task View is open, `onWindowsChanged` refreshes the snapshot only when:

`NiriService.windows.length !== cachedWindowItems.length`.

A count-preserving update can change:

- title;
- app id / effective identity;
- workspace ownership;
- layout/tile size;
- scrolling position.

The cached search text, workspace slot and geometry may therefore remain stale.

There is also no general workspace-state connection that refreshes this cache.

Do **not** simply refresh on every `windowsChanged`: the current code
deliberately avoids focus-only rebuild churn.

Required design is a meaningful Task-View structural/content revision or
signature that distinguishes:

- focus-only state that can update cheaply;
- identity/title/layout/workspace changes that require rebuilding snapshot data.

Fix this correctness/freshness contract before relying on more aggressive
Task-View caches.

### 41.15 Waffle WindowThumbnail resolves the same icon path twice — CONFIRMED / P1

Path:

- `modules/waffle/taskview/WindowThumbnail.qml`.

Both the title-bar icon and large fallback icon use the exact expression:

`Quickshell.iconPath(windowData.app_id, "application-x-executable")`.

Their paint/decode sizes differ, but the source path is identical.

Share one readonly icon-source property:

- theme path resolutions: **2 -> 1**;
- **50% fewer** source resolutions per thumbnail reevaluation.

### 41.16 Waffle Task View move-window CLI has an exact persistent-socket action available — HIGH CONFIDENCE / transport parity required

Paths:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`;
- `services/NiriService.qml`.

Both `moveWindowToWorkspace()` and `moveWindowToNewWorkspace()` spawn:

`niri msg action move-window-to-workspace --window-id ... --focus false ...`.

NiriService already exposes `moveWindowToWorkspace(windowId, workspaceIndex,
focus)` with the same:

- explicit window id;
- workspace Index reference;
- `focus:false`;

through the persistent request socket.

Normal connected-path child-process count can therefore change:

**1 -> 0 per drag move**.

Keep this HIGH CONFIDENCE rather than absolute Confirmed because transient
transport semantics differ: an independently spawned CLI may connect during a
moment when NiriService's persistent request socket is disconnected. Add
connected/reconnect parity tests before replacing the CLI.

The existing post-action refresh timers must remain unchanged.

### 41.17 Waffle Task View `executeNiriAction()` is not current runtime cost — CLOSED

Paths:

- `modules/waffle/taskview/WaffleTaskViewContent.qml`;
- `modules/waffle/taskview/WindowThumbnail.qml`.

The parent owns an `executeNiriAction()` path that would spawn two Niri
processes.

Current `WindowThumbnail.qml` declares the `niriAction` signal but never
emits it.

Do not count these processes in runtime savings.

Dead signal/handler/function removal is a separate API/extension-surface cleanup
question.

### 41.18 Overview delegates linearly search `windowItems` by id — CONFIRMED / P1, including default Abyss Task View

Paths:

- `modules/overview/OverviewNiriWidget.qml`;
- `modules/overview/NiriOverviewModel.js`;
- `modules/abyss/content/AbyssOverviewContent.qml`.

The ScriptModel intentionally exposes primitive compositor window IDs so
delegate identity remains stable.

Each delegate then calls:

`findWindowRecord(records, windowId)`

whose implementation is:

`records.find(record => record.id === windowId)`.

For N records in model order, total comparisons are approximately:

`N(N+1)/2`.

Preserve the primitive-ID model but build `recordById` once per
`windowItems` publication.

Examples by rough primitive-operation count:

- N=10: ~55 linear comparisons becomes ~10 inserts + 10 O(1) reads;
- N=20: ~210 comparisons becomes ~20 inserts + 20 reads, about **81% less**
  by this simple operation count.

This path matters for current default Abyss because Abyss Task View embeds
`OverviewNiriWidget`.

### 41.19 Overview maps the same window-item list to IDs up to three times — CONFIRMED / P1

Path:

- `modules/overview/OverviewNiriWidget.qml`.

The exact mapping:

`windowItems.map(record => record.id)`

is performed for:

- warm Overview previews;
- refresh/capture visible previews;
- `ScriptModel.values`.

Expose one readonly `windowIds` snapshot derived from `windowItems`.

Normal preview-warm path:

- ID-list mappings: **3 -> 1**;
- **66.7% fewer** full-list mappings.

Branches without warm still commonly become **2 -> 1**.

### 41.20 MPRIS stream scoring normalizes the same node identities three times per player/node pair — CONFIRMED / P1

Path:

- `services/MprisController.qml`.

`_streamMatchScore()` has up to:

- 3 player identity values;
- 11 node identity values.

For each player value, every node value reruns:

- `_volumeKey()`;
- `_volumeTokens()`.

Thus the same 11 node values can be normalized three times inside one
synchronous pair comparison.

Prepare node `{key,tokens}` values once for the call:

- node-side candidate normalizations: **33 -> 11**;
- **66.7% fewer**.

The match score, thresholds, token overlap and state bonus remain unchanged.

### 41.21 Prepare the invariant side once across MPRIS player/node matching loops — CONFIRMED / P1

Path:

- `services/MprisController.qml`.

`playerForStreamNode(node)` compares one node against P displayed players.

After §41.20's per-pair cleanup, the same prepared node identities can be reused
for every player in that one synchronous function call.

Rough node-side normalization count:

- current-shaped: up to `33 x P`;
- prepared once: `11`.

Examples:

- P=2: ~66 -> 11, about **83.3% fewer** node-side normalizations;
- P=3: ~99 -> 11, about **88.9% fewer**.

The inverse `streamNodeForPlayer(player)` can similarly prepare player-side
identity/title data once before scanning M PipeWire nodes.

Keep this per-call. A cross-event memo would need metadata/player epochs and is
not required for these savings.

### 41.22 `mixerAppNodes` filters then loops the same PipeWire node list — CONFIRMED / P1

Path:

- `services/MprisController.qml`.

Current derivation:

1. `Audio.outputAppNodes.filter(_streamIsBound)`;
2. loop the filtered array to deduplicate by app key and choose the more-audible
   representative.

Fold the bound test into the existing dedupe loop.

Node visits:

- **2N -> N**;
- about **50% fewer** passes;
- temporary filtered array removed.

Preserve first-seen key order and existing `_streamIsMoreAudible()` tie logic.

The current `pw-dump` metadata refresh is event-driven through a 120 ms
debounce, not a periodic hidden poll. Do not claim process savings there without
proving Quickshell PipeWire properties are metadata-equivalent.

### 41.23 Session hibernate monitor-off duplicates compositor action transport — HIGH CONFIDENCE / transport parity required

Paths:

- `modules/common/functions/Session.qml`;
- `services/CompositorService.qml`;
- `services/NiriService.qml`.

The hibernate monitor-off timer currently spawns:

- Niri: one `niri msg action power-off-monitors` process;
- Hyprland: one `hyprctl dispatch dpms off` process.

CompositorService already exposes `powerOffMonitors()`:

- Niri -> persistent Niri request socket;
- Hyprland -> `Hyprland.dispatch("dpms off")`.

Normal connected-path process count can therefore change:

**1 child process -> 0**.

Keep this HIGH CONFIDENCE because the Niri CLI can create a new connection
during a transient persistent-socket outage. Test disconnected/reconnecting
behavior before calling the transport swap absolute-lossless.

The analogous commands embedded into `swayidle` in `services/Idle.qml` are
not directly replaceable this way: those callbacks run in the external
swayidle process, outside QML.

### 41.24 GameMode animation reload transport is CLOSED for strict-lossless substitution

Path:

- `services/GameMode.qml`.

The animation mutation helper executes:

1. sed mutation;
2. `niri msg action reload-config`;

inside one shell process.

The Process exit code therefore reflects the final Niri reload command.

Replacing only the reload command with `NiriService.send()` would change:

- error observability;
- process exit status;
- rerun/failure timing.

Do not count this as a confirmed child-process elimination. It requires an
explicit error-contract redesign.

### 41.25 QuickLaunch repeated running-state scans are conditional, not stock-default — HIGH CONFIDENCE / P2

Path:

- `modules/sidebarLeft/widgets/QuickLaunch.qml`.

When enabled, each shortcut independently scans every Niri window and lowercases
app-id/title candidates.

The configured shortcut list defaults to four entries, so a full miss can repeat
window normalization/scanning four times.

A per-window-snapshot prepared lowercase identity list can turn candidate-side
lowercasing from roughly:

`2 x 4 x N -> 2 x N`;

about **75% less candidate-side lowercasing** for four shortcuts.

Scope carefully:

- current default family is Abyss;
- `sidebar.widgets.launch=false` by default.

This is not a stock-default idle hotspot.

### 41.26 Bar workspace app-icon window filtering is also conditional — HIGH CONFIDENCE / P2

Path:

- `modules/bar/Workspaces.qml`.

Occupancy state is already efficiently built with a one-pass Set.

When per-workspace app icons are enabled, each workspace button independently
filters all Niri windows for its workspace.

A one-pass `windowsByWorkspaceId` index can reduce membership scanning from:

`W x N -> N`.

The current default has `showAppIcons=false`, so do not count this as default
shell savings without runtime evidence that hidden bindings still evaluate.

### 41.27 Test coverage required before implementation

Existing regression coverage protects some presentation/resource contracts:

- Task View shimmer stops while closed;
- preview/wallpaper decode sizes remain bounded;
- GameMode polling minimum and state persistence remain guarded.

It does **not** currently test:

- Waffle Task View identity-rule idempotence/search consistency;
- count-preserving Task View title/layout/workspace refresh;
- per-slot Task View counts during drag;
- Overview `recordById` parity;
- Niri WindowLayoutsChanged multi-change parity;
- focused-window shared-snapshot publication;
- MPRIS stream-match score parity.

Any implementation round touching these paths should add focused fixtures before
or with the optimization.

### 41.28 Round-27 priority update

**Correctness prerequisites:**

1. stop double-resolving effective identity in Waffle Task View (§41.12);
2. repair Task View count-only cache invalidation (§41.14).

**Confirmed, high-value local optimizations:**

3. Niri WindowLayoutsChanged id->index pass (§41.1);
4. Niri WindowClosed one-pass removal (§41.2);
5. no-change focus-normalization allocation elimination (§41.3);
6. shared published focused-window derivation (§41.6);
7. remove redundant Overview workspace sorts (§41.8);
8. Waffle Task View windows-by-workspace grouping (§41.9);
9. Waffle shared focused id (§41.10);
10. Waffle per-slot item/count index (§41.11);
11. precomputed Waffle search fields (§41.13);
12. Waffle shared thumbnail icon source (§41.15);
13. Overview recordById map (§41.18);
14. Overview shared windowIds (§41.19);
15. MPRIS prepared stream-match identities (§41.20-41.21);
16. MPRIS mixer one-pass filtering/dedup (§41.22).

**Conditional / parity / benchmark:**

17. Niri positional order fast path (§41.4);
18. single-window-policy early stop (§41.5);
19. active-workspace/workspaces-by-output demand memo (§41.7);
20. Waffle move-window persistent socket (§41.16);
21. Session monitor-off compositor transport (§41.23);
22. QuickLaunch prepared running-state input (§41.25);
23. Bar workspace windows-by-workspace index (§41.26).

**Closed as current runtime savings:**

24. dead Waffle `executeNiriAction()` process path (§41.17);
25. direct GameMode reload socket substitution under the current error contract
    (§41.24).

No runtime/source implementation is authorized by this handoff.

---

## 42. Round 28 — WindowPreview capture breadth and helper process cost (2026-09-29)

### Snapshot / concurrent reconciliation

- Current `dev` HEAD immediately before this docs-only write: `a4ac98bb164b67adf3d8777744921dfccf341f9c` (`feat(abyss): borrow semantic perimeter vacancy on hover`).
- Relative to the Round-28 research baseline `2340742c78266379ba1c1ba833d77786a898358b`, current `dev` is 62 commits ahead.
- The last concurrent commit `a4ac98bb164b67adf3d8777744921dfccf341f9c` changes only Abyss vacancy-borrowing runtime/tests. It does **not** touch `services/WindowPreviewService.qml`, `scripts/capture-windows.sh`, `scripts/capture-windows.fish`, or the preview consumers audited below.
- The broader concurrent changed-file set since the Round-28 baseline also does not touch this WindowPreview/capture subsystem, so the source proofs below remain current.
- `modules/dock/DockApps.qml` did change earlier in the concurrent range. The running-order membership and rank-lookup findings already recorded in §37.5 still exist; pinned membership is now already represented by `pinnedIds` / `hiddenPinnedIds` Sets. Do not reopen the Round-28 Dock A1/A2/A3 notes as new findings.
- Existing WindowPreview findings are not duplicated here: Fish->Bash trampoline (§25.4), XDG cache-root mismatch (§39.4), and initialization helper-process reduction (§39.5) remain authoritative.

### 42.1 `_observeWindowSet()` traverses the same Niri snapshot about three times — CONFIRMED / P1

Path:

- `services/WindowPreviewService.qml`.

Current publication path:

1. `map(window => window.id)` over `NiriService.windows`;
2. `filter()` invalid IDs;
3. build `previousIds`;
4. `filter()` the valid ID array again to derive newly observed IDs.

The two output arrays have distinct purposes and must be preserved:

- `observedWindowIds` keeps all current valid IDs in compositor order;
- `newIds` keeps only IDs absent from the previous publication, in that same order.

One loop over the current window snapshot can validate each ID once, append it to `ids`, and append it to `newIds` only when the previous-ID Set does not contain it.

Local work:

- list traversal: about **`3N -> N`**, roughly **66.7% fewer visits**;
- no change to `cleanupTimer.restart()`, cached-preview warmup, `captureForTaskView(newIds)`, ordering, or invalid-ID filtering.

Regression coverage should include invalid IDs, duplicate IDs, authoritative empty publication, and new-window ordering.

### 42.2 Capture-all pending check builds an unnecessary ID array — CONFIRMED / P2

Path:

- `services/WindowPreviewService.qml::_pendingRequestNeedsCapture()`.

When `captureAllRequested` is true, current code:

1. maps every live window to an ID array;
2. loops that array until a missing preview is found.

The same early-return semantics are obtained by looping `NiriService.windows` directly and testing `previewCache[window.id]`.

Local work on the all-windows branch:

- **`2N -> N`** visits;
- removes one N-element temporary array;
- preserves the exact first missing-cache early exit.

### 42.3 Selective `_doCapture()` can select and test cache policy in one pass — CONFIRMED / P1

Path:

- `services/WindowPreviewService.qml::_doCapture()`.

Selective mode currently:

1. filters all `N` windows into a selected array of `M` records;
2. loops those `M` records again to apply forced-ID / `needsCapture()` policy.

A single loop can keep the same `requestedIds` / `forcedIds` Sets and append a window ID only when:

- it belongs to the selective request; and
- it is forced or the cache needs capture.

Because iteration still follows the authoritative `NiriService.windows` order, capture ordering remains identical.

Local work:

- selective mode: **`N + M -> N`** visits;
- removes the temporary selected-window array;
- maximum list-visit reduction approaches **50%** when most windows are selected.

The all-windows branch is already one effective pass for cache selection and does not need a separate optimization.

### 42.4 Per-preview publication has O(B^2) requested/published bookkeeping — CONFIRMED core; live-ID index needs parity

Path:

- `services/WindowPreviewService.qml::_publishCapturedPreview()`.

For each `PREVIEW_READY <id>` in a batch of `B`, current code performs:

- `idsToCapture.includes(id)`;
- `publishedIds.includes(id)`;
- `publishedIds = publishedIds.concat([id])`.

Across a full batch, the two membership scans plus growing-array copies are O(B^2)-shaped.

Exact-safe core direction:

- keep `idsToCapture` as the ordered batch array used by clean-exit recovery;
- additionally build one requested-ID Set when the batch starts;
- keep one published-ID Set for duplicate rejection;
- if an ordered `publishedIds` array is still useful for tests/debugging, append with `push()` instead of `concat()`.

This changes requested/published bookkeeping from O(B^2) to O(B) while preserving:

- duplicate `PREVIEW_READY` rejection;
- unrequested-ID rejection;
- clean-exit replay ordering;
- per-window immediate publication timing.

The remaining live-window guard is separate:

`(NiriService.windows ?? []).some(window => window.id === windowId)`

That is O(N) per ready record and intentionally prevents publishing a PNG for a window that closed during capture. Replacing it with O(1) membership is **HIGH CONFIDENCE**, but only if the Set is an exact current-publication index, not a batch-start snapshot.

Required race fixture before that part is promoted:

- start capture for ID X;
- remove X from the published Niri window snapshot;
- then deliver `PREVIEW_READY X`;
- assert no cache revision / `previewUpdated(X)` occurs.

Existing eager-capture tests already cover duplicate, unrequested, stale-batch, old-session and buffered-at-exit records; the close-between-capture-and-ready race is the missing case.

### 42.5 App hover previews have a real targeted set, but global first-open parity blocks CONFIRMED — HIGH CONFIDENCE / P1 when recovery capture is needed

Paths:

- `modules/waffle/bar/tasks/TaskPreview.qml`;
- `modules/waffle/bar/tasks/WindowPreview.qml`;
- `modules/bar/BarTaskbarPreview.qml`;
- `modules/bar/BarTaskbarWindowPreview.qml`;
- `services/WindowPreviewService.qml`.

Waffle is the clearest source proof:

- `TaskPreview.captureAppPreviews()` computes `windowIds` for exactly the app's current toplevels using `niriWindowId` with `NiriService.findNiriWindow()` fallback;
- it checks `windowIds.length > 0`;
- then discards the list and calls `captureForTaskView()` with no IDs;
- `WindowPreview.qml` resolves and reads preview URLs by the same Niri window identity.

Bar app/workspace preview similarly renders only `previewToplevels`, while both `show()` and `showWorkspace()` currently issue a no-ID capture request.

Surface-local capture breadth could therefore change from:

- app preview: **`N -> A`** windows, where `A` is that app's visible preview set;
- workspace hover: **`N -> W`** windows, where `W` is the hovered workspace preview set.

However `captureForTaskView()` with no IDs has an additional shell-wide side effect: during the 100 ms debounce it opportunistically repairs **any** missing preview in the current Niri snapshot. Passing only the popup IDs can leave an unrelated missing preview uncaptured until its own later demand, changing first-open latency for another surface after an earlier prewarm/capture failure.

Therefore this is **not strict-lossless yet** under the project requirement, even though the current popup itself has an exact subset.

Parity options to research before implementation:

1. preserve the global repair/prewarm request separately while allowing the user-triggered popup batch to be targeted; or
2. prove by regression/runtime evidence that the global repair side effect is already guaranteed independently before these callers run.

Do not claim shell-wide savings from `N -> A/W`; it is conditional on there being missing/stale work at hover time.

### 42.6 AltSwitcher and full Waffle Task View do not gain capture-breadth savings from targeted IDs — CLOSED as a breadth optimization

Paths:

- `modules/altSwitcher/AltSwitcher.qml`;
- `modules/waffle/altSwitcher/WaffleAltSwitcher.qml`;
- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

Both AltSwitcher skew implementations build their item snapshot from the complete current `NiriService.windows` set. Passing that snapshot's IDs would normally request the same breadth as no-ID capture, while freezing the request to an earlier snapshot can change the 100 ms debounce race.

Waffle Task View likewise builds its full cached workspace/window model before calling the no-ID capture path. Its high-value work remains the Round-27 grouping/indexing and invalidation fixes, not a nominal targeted-capture conversion.

Do not spend an implementation round replacing these calls merely to pass an ID array.

`OverviewNiriWidget` is already the good pattern: it derives the visible `windowItems` list and calls targeted `refreshForOverview(ids)` / `captureForTaskView(ids)`.

### 42.7 `refreshForOverview()` re-bounds an already bounded list — CONFIRMED / P2 micro

Paths:

- `services/WindowPreviewService.qml`;
- `services/WindowPreviewPolicy.js`.

`refreshForOverview(windowIds)` first calls:

`PreviewPolicy.boundedWindowIds(windowIds, overviewWarmLimit)`

then passes that already validated/deduplicated result to `warmForOverview(ids)`, which calls `boundedWindowIds()` again.

Because `overviewWarmLimit` is 12, this is deliberately only a micro candidate. A private helper accepting already bounded IDs can remove the second validation pass while keeping the public `warmForOverview()` defensive contract unchanged.

Local work: second pass **`K -> 0`**, with `K <= 12`.

### 42.8 Capture helper can skip `mkdir -p` when its directory already exists — CONFIRMED local process reduction

Path:

- `scripts/capture-windows.sh`.

The helper currently runs external:

`mkdir -p "$preview_dir"`

on every invocation.

Strict-safe guard:

`[[ -d "$preview_dir" ]] || mkdir -p "$preview_dir"`

keeps standalone/missing-directory recovery and error behavior while making the normal existing-directory path use only the Bash builtin test.

Local normal-path process count:

- **`1 child process -> 0`** for this directory check.

This is independent of the broader service-init helper reduction in §39.5. The cache-root correctness bug in §39.4 remains a prerequisite for treating service/helper directory ownership as unified; do not use this micro optimization to paper over that mismatch.

### 42.9 SHA-256 parsing launches one unnecessary `cut` per hash — CONFIRMED

Path:

- `scripts/capture-windows.sh`.

Current generated-preview, decoded-entry and current-clipboard hashes use:

`sha256sum <file> | cut -d' ' -f1`

GNU `sha256sum` already places the digest in the first field. Capturing the command output and extracting the prefix in Bash preserves the digest while removing `cut`.

Let:

- `H` = successfully generated preview files hashed after capture;
- `E` = successfully decoded cliphist entries hashed across cleanup passes;
- `C` = 0 or 1 current clipboard image hash.

Local external-process reduction:

- `cut` processes: **`H + E + C -> 0`**.

Tests must preserve `set -euo pipefail` failure propagation from `sha256sum`; do not replace the pipeline with parsing that accidentally turns a hash failure into success.

### 42.10 MIME and first-entry selection use avoidable `grep` / `head` helpers — CONFIRMED

Path:

- `scripts/capture-windows.sh`.

Current `select_clipboard_mime()` obtains one `wl-paste -l` snapshot, then performs exact-line `grep -Fqx` probes in this order:

1. `text/plain;charset=utf-8`;
2. `text/plain`;
3. `UTF8_STRING`;
4. `image/png`;
5. otherwise first MIME line via `head -1`.

Later, clipboard-restore safety performs another fresh `wl-paste -l | grep -Fqx image/png` check. That second list read must remain fresh because clipboard ownership may have changed during capture.

Pure Bash line parsing can preserve exact full-line matching, preference order, empty-list behavior and first-line fallback while removing:

- between **2 and 6 external `grep`/`head` processes per capture**, depending on the initial MIME match;
- the associated pipeline forks for builtin `printf`.

Separately, `before_id` uses:

`cliphist list | head -1`

A Bash `read` from the same `cliphist list` stream preserves first-entry/empty-history semantics and removes another **1 `head` process per capture**.

Do not reduce the number/timing of `wl-paste` snapshots in this change.

### 42.11 Clipboard cleanup repeats hash scans and forks builtin `printf` pipelines — CONFIRMED core

Path:

- `scripts/capture-windows.sh`.

Two independent exact-safe reductions exist inside the required two-pass cleanup.

#### A. Preview-hash membership

`hash_matches_preview()` currently loops all `H` generated preview hashes for every successfully decoded history entry and again for the current clipboard hash.

Because equality is exact SHA-256 string equality, an associative hash Set built once preserves membership semantics.

Worst-case comparisons:

- **`(E + C) x H -> H + E + C`**.

Duplicate preview hashes may collapse in the Set without changing membership truth.

#### B. Feeding cliphist entries

Current decode/delete calls use:

`printf '%s\n' "$entry" | cliphist decode`

and, for matched preview entries:

`printf '%s\n' "$entry" | cliphist delete`.

`printf` is a Bash builtin but a pipeline places that segment in its own process. A here-string / equivalent direct stdin feed can supply the same line plus newline without the producer pipeline process.

Let `D` be decode attempts and `M` be matched preview deletions.

Local fork reduction:

- producer-side shell pipeline processes: **`D + M -> 0`**;
- the actual `cliphist decode/delete` processes remain unchanged.

Required fixture: an entry containing spaces, tabs and shell metacharacters must decode/delete byte-identically; no `eval` or word splitting is acceptable.

### 42.12 Requested-ID validation in the Bash helper is R x N — CONFIRMED

Path:

- `scripts/capture-windows.sh`.

After querying live Niri window IDs, selective mode validates every requested ID by linearly scanning the full live-ID array.

For `R` requested IDs and `N` live windows:

- current worst case: **`R x N`** string comparisons;
- build one associative live-ID Set and retain the existing requested-ID loop: **`N + R`** membership work.

Preserve exact current semantics:

- requested order;
- duplicate requested IDs;
- string equality (for example a noncanonical `001` must not silently become live ID `1`);
- per-ID missing-window stderr;
- `requested_missing` exit behavior.

Do not remove the Niri live-window query merely because screenshot IPC would later fail: that would change early validation, diagnostics and timing.

### 42.13 Screenshot readiness polling may spawn up to 40 `sleep` children per preview — NEEDS BENCHMARK / PARITY

Path:

- `scripts/capture-windows.sh`.

After `niri msg action screenshot-window` returns, each capture worker polls the temp PNG up to 40 times:

- test `[[ -s "$tmp" ]]`;
- otherwise `sleep 0.05`.

The file test is builtin, but `sleep` is an external process. Therefore one preview can launch **0..40 sleep children** before the 2-second readiness bound is reached.

This may be the largest helper-process hot spot when Niri returns before the PNG is ready, but the wait exists for a documented race and `PREVIEW_READY` timing is user-visible.

Before changing it, measure:

- retry-count histogram per preview;
- Niri IPC-return -> nonempty-file latency;
- process count under 1/2 concurrent captures;
- failed/slow compositor behavior.

Any replacement must preserve the same maximum readiness window, atomic rename, partial-batch failure propagation and earliest-safe `PREVIEW_READY` publication. No static rewrite is authorized yet.

### 42.14 Second clipboard-cleanup pass can repeat decode/hash work for surviving user entries — HIGH CONFIDENCE / parity required

Path:

- `scripts/capture-windows.sh`.

The two passes and their 0.5 s / 0.3 s timing are correctness behavior: historical fixes added them to catch late screenshot clipboard entries. Do not remove or merge the passes.

A non-preview user entry newer than `before_id` can survive pass 1, then be decoded and hashed again in pass 2. Caching `entry_id -> content hash` could avoid that repeated work for unchanged IDs.

Do not promote this until the cliphist ID immutability/reuse contract is proven. If an ID could refer to changed bytes between passes, reusing the old hash would change the rule 'delete only bytes that match one of our generated previews'.

### 42.15 Round-28 regression matrix before implementation

Extend the existing WindowPreview tests rather than weakening their current lifecycle guards.

Required QML/service fixtures:

- `_observeWindowSet()` valid/invalid/duplicate/order parity;
- capture-all pending check parity;
- selective `_doCapture()` order and forced-ID parity;
- duplicate/unrequested/stale-session `PREVIEW_READY` behavior after Set-backed bookkeeping;
- **window closes after capture start but before `PREVIEW_READY` => never publish**;
- new window arriving during a batch remains queued for the next batch;
- targeted app-preview tests must prove the popup receives all of its visible IDs.

Required shell-helper fixture with fake binaries:

- missing/existing/unwritable preview directory;
- current MIME preference order and empty list;
- first cliphist entry / empty history;
- hash success/failure under `set -euo pipefail`;
- requested live/missing IDs including duplicate and noncanonical numeric strings;
- cliphist decode/delete stdin bytes;
- user clipboard entry survives both cleanup passes;
- generated preview entry is deleted;
- helper exit code and `PREVIEW_READY` order remain unchanged.

### 42.16 Round-28 priority update

**Confirmed local reductions:**

1. one-pass `_observeWindowSet()` (§42.1);
2. direct all-window pending-cache check (§42.2);
3. one-pass selective capture selection (§42.3);
4. Set-backed requested/published batch bookkeeping (§42.4 core);
5. remove double Overview ID bounding (§42.7);
6. existing-directory `mkdir` guard (§42.8);
7. remove per-hash `cut` (§42.9);
8. Bash-native MIME/first-entry parsing (§42.10);
9. preview-hash Set + direct cliphist stdin feed (§42.11);
10. requested-ID live Set (§42.12).

**Parity / benchmark:**

11. exact current-live-ID index for publication (§42.4 live guard);
12. app/workspace hover targeted capture without losing global repair/first-open behavior (§42.5);
13. replace or reduce per-preview readiness `sleep` processes (§42.13);
14. reuse pass-1 cliphist decode hashes only after ID immutability proof (§42.14).

**Closed / already handled:**

15. AltSwitcher / full Waffle Task View targeted-ID conversion as a breadth optimization (§42.6);
16. Overview visible-window targeting is already present;
17. Fish trampoline, XDG cache-root mismatch and service-init helper ownership remain in §§25.4, 39.4 and 39.5 rather than being duplicated here.

No runtime/source implementation is authorized by this handoff.

---

## 43. Round 29 — WindowPreview contract closure, non-Niri gating and validation debt (2026-09-29)

### Snapshot / concurrent reconciliation

- Current `dev` HEAD immediately before this docs-only write: `d550b3d03342974fcede6deb70687de935bf8802` (`docs(confirmation): make abyss popup scope explicit`).
- Since the Round-28 docs commit `0346f37ad3d7302afc2175977b3f4e9f18da650b`, concurrent work has landed in Abyss geometry/tests and Confirmation/Polkit scope.
- The reconciled changes do **not** touch WindowPreview, NiriService, clipboard capture, or the preview consumers audited below.
- The optimization handoff itself remained unchanged through this concurrent work.
- No Round-28 WindowPreview source finding was carried forward without re-reading current `dev`.

### 43.1 WindowPreview consumer-identity regression test references a deliberately retired Dock file — CONFIRMED correctness prerequisite

Paths/history:

- `scripts/test-window-preview-consumer-identity.sh`;
- `scripts/validate-maintainer-local.sh`;
- retired `modules/dock/DockWindowPreview.qml`;
- retirement commit `5bc76fe6f2678eb81750f2dfe9aa3641b422136b` — `refactor(dock): replace hover previews with app popups`.

Current `dev` no longer contains `DockPreview.qml` or `DockWindowPreview.qml`. Their removal is intentional:

- the retirement commit removes both files and their `qmldir` exports;
- Dock hover now opens the app popup/context menu;
- `scripts/test-dock-abyss-hover-orientation-contract.py` explicitly asserts the legacy Dock preview surfaces remain retired.

`scripts/test-window-preview-consumer-identity.sh`, however, still starts its consumer list with:

`modules/dock/DockWindowPreview.qml`

and reads every entry with `fs.readFileSync(...)`.

Therefore the tracked test fails on the removed file before it can validate the remaining live WindowPreview consumers.

This is not an optional cleanup. `scripts/validate-maintainer-local.sh` enumerates every tracked `test-*.sh` and runs it as a shell regression, so the stale path breaks the maintainer validation suite.

**Required before any WindowPreview implementation batch:** update the contract fixture to the current live consumer inventory while preserving the reactive cache-revision assertions for the remaining consumers.

Do not restore Dock preview runtime merely to satisfy this test.

### 43.2 Targeted app/workspace capture cannot reduce total screenshot work while preserving the current global-repair contract — CLOSED as strict-lossless breadth optimization

Round 28 §42.5 left caller-level targeted capture open pending parity analysis. Current source plus current tests close that question.

`captureForTaskView()` has two distinct contracts:

- passing explicit IDs queues only those IDs;
- passing no IDs sets `captureAllRequested`, so `_pendingRequestNeedsCapture()` and `_doCapture()` repair **every currently missing preview** in the authoritative Niri window set.

The no-ID side effect is not accidental test noise. Current `scripts/test-window-preview-lifecycle.sh` explicitly requires:

- `BarWorkspaceOverview` to call `WindowPreviewService.captureForTaskView()`;
- Waffle `TaskPreview` to call `WindowPreviewService.captureForTaskView()`;

with the stated purpose of preserving the shared capture lifecycle.

Therefore changing app/workspace hover from no-ID to an app/workspace subset has only two possibilities:

1. **drop global repair:** total screenshot work can fall, but a missing unrelated preview may stay missing until later demand, changing first-open behavior; or
2. **keep global repair separately:** popup IDs can be prioritized, but the same missing unrelated previews are still captured, so total screenshot work does not fall and timing/order changes.

Under the project's absolute lossless requirement, there is no strict-lossless `N -> A/W` total-work win here.

Keep targeted capture only where the existing contract is already targeted (`OverviewNiriWidget.refreshForOverview(ids)` / task-view visible IDs), or revisit app/workspace targeting only as an explicit product/latency contract change.

### 43.3 Waffle TaskPreview resolves all app window IDs but only consumes one Boolean — CONFIRMED local CPU reduction

Path:

- `modules/waffle/bar/tasks/TaskPreview.qml`.

`captureAppPreviews()` currently:

1. allocates `windowIds = []`;
2. walks every app toplevel;
3. reads `tl.niriWindowId` or falls back to `NiriService.findNiriWindow(tl)`;
4. pushes every valid ID;
5. consumes only `windowIds.length > 0`;
6. then issues the no-ID/global capture request.

Because §43.2 closes targeted caller capture under the current contract, the exact useful result of this loop is only: **does at least one valid Niri window identity exist?**

Strict-safe direction:

- stop at the first valid ID;
- keep the same no-ID `captureForTaskView()` call;
- do not allocate or populate an ID array.

For `A` app toplevels:

- common path becomes up to **`A -> 1`** identity checks when the first item is valid;
- worst case remains `A` when no valid ID exists.

When a toplevel lacks `niriWindowId`, the avoided checks are more valuable because `NiriService.findNiriWindow()` itself linearly scans the Niri window list.

Also, the explicit `WindowPreviewService.initialize()` immediately before `captureForTaskView()` is redundant: `captureForTaskView()` already executes `if (!initialized) initialize()` before any session/capture decision.

### 43.4 Non-Niri preview surfaces can defeat WindowPreviewService's intentional Niri-only initialization gate — CONFIRMED conditional process debt / P1

Paths:

- `shell.qml`;
- `services/WindowPreviewService.qml`;
- `modules/bar/BarTaskbarPreview.qml`;
- `modules/bar/BarWorkspaceOverview.qml`;
- `modules/waffle/bar/tasks/TaskPreview.qml`;
- `modules/waffle/bar/tasks/WindowPreview.qml`.

The intended service lifecycle is clear:

- `shell.qml` materializes `WindowPreviewService` at deferred Tier 3 (~T+500 ms);
- the singleton's `Component.onCompleted` calls `_startPrewarming()`;
- `_startPrewarming()` immediately returns unless `CompositorService.isNiri`;
- only Niri normally proceeds to `initialize()` and preview-cache/session helpers.

Current consumers bypass that guard:

- `BarTaskbarPreview.show()` calls `captureForTaskView()` unconditionally;
- `BarTaskbarPreview.showWorkspace()` does the same even though it has a separate Hyprland model branch;
- `BarWorkspaceOverview.showWorkspace()` calls it before choosing Niri `OverviewNiriWidget` versus Hyprland `OverviewWidget`;
- Waffle parent `TaskPreview.captureAppPreviews()` correctly returns on non-Niri, but every `WindowPreview.qml` delegate still runs `Component.onCompleted: WindowPreviewService.initialize()` unconditionally.

`captureForTaskView()` itself initializes the service when needed. On a normal non-Niri session `NiriService.socketPath` / `sessionKey` is empty, so initialization does:

1. external `mkdir -p previewDir`;
2. session-marker read;
3. marker cannot qualify as the current Niri session because `sessionKey.length > 0` is false;
4. `sessionResetProcess` runs external `find ... -delete`;
5. no Niri screenshot can subsequently be useful.

Thus first use of these non-Niri preview surfaces can pay at least the directory/reset helper work that the singleton's own Niri gate deliberately avoided.

Strict-lossless-shaped direction:

- guard Bar/BarWorkspace capture requests with `CompositorService.isNiri`;
- remove Waffle delegate's explicit `initialize()`; Niri service creation already self-starts through `_startPrewarming()`, and the Niri parent capture path independently calls `captureForTaskView()` which initializes if needed;
- retain all Hyprland live-preview/fallback presentation paths.

Regression fixture before implementation:

- fresh Hyprland session, preview cache directory absent/present;
- hover Bar app preview, compact workspace preview, connected workspace Overview, and Waffle task preview;
- assert WindowPreview `mkdir/find/capture` helpers never start;
- assert Hyprland preview/fallback UI, focus, close and hover behavior is unchanged;
- repeat on Niri and assert first-use cached/missing preview behavior remains identical.

### 43.5 Exact current-live-ID publication index must be tied to `NiriService.windows`, not WindowPreview's observed/batch state — HIGH CONFIDENCE design closure

Round 28 §42.4 correctly rejected a batch-start Set for this guard:

`(NiriService.windows ?? []).some(window => window.id === windowId)`

The source-of-truth constraint can now be stated precisely.

`NiriService.windows` is the published authoritative snapshot. Its normal batched publication assigns:

`windows = nextWindows`

and `WindowPreviewService` separately keeps `observedWindowIds` only for prewarm/new-window bookkeeping.

These are **not interchangeable**:

- a batch-start requested-ID Set becomes stale if a window closes during capture;
- `observedWindowIds` is explicitly cleared when `windowListReady` becomes false, while the current `.some(...)` guard tests the current `windows` property itself;
- therefore using either would change close/disconnect race semantics.

The correct shared direction is the already-open §40.21 idea: publish or lazily derive an ID-index/`windowForId` view from the exact current `NiriService.windows` snapshot and reuse that exact publication for:

- `_publishCapturedPreview()` live membership;
- `cleanupOrphans()` membership;
- other ID lookups already identified in the Niri hot-path audit.

This can turn the per-ready O(N) `.some(...)` check into O(1) **without creating a second independently maintained liveness truth**.

Do not promote implementation until the following event-order fixture passes:

- capture ID X;
- publish a Niri window snapshot without X;
- then deliver `PREVIEW_READY X`;
- assert X is rejected;
- separately exercise `windowListReady=false` without inventing semantics different from the existing `windows` snapshot.

### 43.6 Current cliphist/bbolt semantics remove the normal-operation ID-reuse blocker for pass-2 hash reuse — blocker narrowed, still HIGH CONFIDENCE

Round 28 §42.14 left a question: can one cliphist entry ID refer to different bytes between cleanup pass 1 and pass 2?

Current upstream `sentriz/cliphist` master inspected at `daa99daef3ed37dc37013b1fae381fe626025a13` shows:

- store first deduplicates old matching entries, then obtains a **new** key from Bolt `NextSequence()`, then writes payload/metadata under that new ID;
- delete/deduplicate/wipe remove keys rather than reassigning another payload to an existing ID;
- decode reads the payload directly by the extracted ID;
- bbolt compaction preserves bucket sequence state, so normal compacting does not reset the ID counter.

Therefore within a normal live cliphist database, an ID that survives from pass 1 to pass 2 represents the same stored payload; a newly stored entry receives a new ID.

This removes the normal supported-operation reason to re-decode an unchanged surviving ID on pass 2.

Why this remains **HIGH CONFIDENCE**, not strict CONFIRMED:

- an out-of-band replacement/recreation of the cliphist database between the two cleanup passes can create a new database identity and potentially reuse low sequence values;
- current capture code does not snapshot/verify database identity.

If implementation wants absolute parity even under external DB replacement, key the reuse cache by both entry ID and stable database identity/generation, or re-decode when identity cannot be proven unchanged.

Do **not** remove the two cleanup passes or their timing; this finding only narrows repeated decode/hash work within the existing correctness schedule.

### 43.7 Core preview consumers no longer need `captureComplete` / `previewUpdated` handlers, but the exported service API blocks strict-lossless signal removal — CLOSED for compatibility

Historical commit:

- `4bfc4d0767ebae8461f590529324e9db6108c37d` — `fix(preview): bind all consumers to window identity and cache revision`.

That commit intentionally moved canonical snapshot consumers from imperative `WindowPreviewService` signal handlers to reactive bindings on `previewCache`/window identity.

Re-reading current `dev` confirms zero `onCaptureComplete` and zero `onPreviewUpdated` handlers in the live canonical consumers audited here:

- Bar taskbar window preview;
- Waffle task preview window;
- Niri Overview;
- Waffle Task View thumbnail;
- ii AltSwitcher skew preview;
- Waffle AltSwitcher skew preview.

`WindowPreviewService` still declares/emits both signals, and `scripts/test-window-preview-lifecycle.sh` still guards `captureComplete()` as part of the service lifecycle.

Do not remove or suppress the signals as a strict-lossless optimization:

- `WindowPreviewService` is exported as `singleton WindowPreviewService 1.0` in `services/qmldir`;
- user/plugin QML may legally depend on those signals even when checked-in canonical consumers no longer do.

Keep the compatibility surface unless a versioned/deprecation policy explicitly permits API removal.

### 43.8 Readiness `sleep 0.05` loop remains runtime-measurement-only — STATIC SEARCH CLOSED

Round 28 §42.13 remains correctly classified.

The helper uses external `sleep` because a static substitution does not provide a proven equivalent delay while preserving the same simple timeout/readiness semantics. Candidate substitutions either add another external dependency/process or alter the 50 ms polling / 2 s maximum readiness window.

Historical preview fixes also show that Niri screenshot/clipboard side effects can settle after IPC return, so this wait is correctness-sensitive.

Do not spend more static-audit time trying to syntactically replace `sleep`.

Next evidence must be runtime:

- retry histogram;
- IPC-return -> nonempty PNG latency;
- process count;
- slow/failing compositor behavior.

### 43.9 Shared published-window index also subsumes two smaller WindowPreview array allocations — FOLLOW-ON / do not split into separate patch

Current `WindowPreviewService` independently creates ID collections in several places:

- `_primeCachedPreviews()` maps the whole Niri window list to IDs before applying a maximum resident budget of 12;
- `cleanupOrphans()` builds `new Set(windows.map(w => w.id))`.

Both can consume the exact published-window ID/index representation from §43.5 once that architecture exists.

Do not create separate micro patches first. The value is to avoid multiple independent ID derivations while preserving one liveness truth.

### 43.10 Round-29 priority update

**Correctness / validation prerequisite:**

1. repair the stale consumer-identity regression fixture that still references retired `DockWindowPreview.qml` (§43.1).

**Confirmed lossless local work:**

2. stop Waffle TaskPreview identity search at the first valid ID and remove its redundant explicit `initialize()` (§43.3);
3. preserve WindowPreviewService's Niri-only process lifecycle by gating non-Niri Bar/Workspace calls and removing per-Waffle-delegate explicit initialization (§43.4).

**High-confidence shared architecture / parity:**

4. reuse one exact `NiriService.windows` publication index for live-ID membership and existing ID lookup candidates (§43.5);
5. pass-2 cliphist hash reuse is safe under normal upstream ID semantics, with only out-of-band DB replacement left to guard (§43.6);
6. fold `_primeCachedPreviews()` / `cleanupOrphans()` ID derivation into that shared publication rather than separate micro patches (§43.9).

**Closed under strict-lossless scope:**

7. app/workspace targeted capture as a total screenshot-work optimization while the no-ID global-repair contract remains (§43.2);
8. removing `captureComplete` / `previewUpdated` from the exported WindowPreviewService API (§43.7);
9. further static replacement of the readiness `sleep` loop (§43.8).

Round-28 confirmed helper/process reductions remain valid. No runtime/source implementation is authorized by this handoff.

---

## 44. Round 30 — capture-helper stale-hash correctness and Waffle taskbar local reductions (2026-09-29)

### Snapshot / concurrent reconciliation

- Current `dev` HEAD immediately before this docs-only write: `95d5729e0678767f0c87f73514a519b5a8b27ebe` (`fix(abyss): use rendered body hover for vacancy borrowing`).
- Since Round 29 (`48353bc52624d9625672c19f1fa06bd5be39b0a7`), concurrent work did two relevant things:
  - `d7d7f0c1f58e3884633bca32496a64e299f5f857` updated this handoff to close the obsolete Abyss-Polkit optimization after the Polkit revert;
  - `95d5729e0678767f0c87f73514a519b5a8b27ebe` changed Abyss vacancy-hover ownership/runtime tests.
- Neither concurrent commit changed `scripts/capture-windows.sh`, Waffle taskbar files, `TaskbarApps.qml`, WindowPreviewService, or NiriService.
- The Abyss vacancy-hover runtime mentioned here was later retired by `7d787fbf97da3dd5992fa9a41978643131da2994`; keep this snapshot note only as historical context.
- The Round-29 WindowPreview findings remain present in the reconciled handoff.

### 44.1 Failed refreshes can put a stale old PNG hash into the current capture's cleanup set — CONFIRMED correctness bug / prerequisite

Path:

- `scripts/capture-windows.sh`.

The helper intentionally preserves an old good preview when a refresh fails:

- each worker writes a `.part.png`;
- only a successful nonempty temp file is atomically renamed over `window-<id>.png`;
- on failure the temp file is removed while the prior `window-<id>.png` remains;
- `capture_failed` records the failed worker and the helper exits nonzero.

That publication rule is correct.

The later clipboard-cleanup hash set, however, does **not** use current-run success. After all workers finish it does:

`for id in "${windows_to_capture[@]}"; ... if [[ -s "$path" ]]; then sha256sum "$path" ...`

So if ID X fails to refresh but an older `window-X.png` already exists, the old file is still nonempty and its digest enters `preview_hashes` as though the current invocation generated it.

This violates the helper's own cleanup contract:

- the cleanup comment says it deletes only cliphist entries whose bytes match a **generated preview**;
- the final restore comment says a newer user copy must win;
- the stale-file comment near the final exit already recognizes that an old PNG must not make a failed refresh look successful.

Current exit/publication logic protects the QML cache revision, but it does not protect clipboard classification.

Concrete failure case:

1. old `window-X.png` with digest H exists from an earlier successful capture;
2. current refresh of X fails, so the old PNG is intentionally retained;
3. during the current capture window the user copies image bytes whose digest is H;
4. `preview_hashes` incorrectly includes H from the old PNG;
5. the new user cliphist entry can be deleted as if it were screenshot pollution;
6. if the user's current clipboard still contains H, the final hash check can restore the pre-capture clipboard over that newer user intent.

This is possible even when **no** current X screenshot was successfully published.

Strict-safe correction direction:

- track the IDs that successfully completed the current invocation's atomic rename;
- build `preview_hashes` only from those current-success IDs;
- keep old preview files for failed IDs exactly as today;
- preserve partial-batch success, `PREVIEW_READY` timing/order, the two cleanup passes, clipboard timing and the final nonzero batch exit.

The already-emitted `PREVIEW_READY` event uses the same semantic success boundary, but shell-side cleanup should keep its own reliable current-success bookkeeping rather than infer success from file existence.

Required fake-binary regression cases:

- stale old PNG + failed refresh + user copies identical bytes => user cliphist entry survives and current clipboard is not restored over it;
- one successful ID + one failed ID with an old PNG => only the successful current PNG hash is eligible for cleanup;
- all-success batch => existing cleanup/restore behavior remains unchanged;
- failed refresh still leaves the old PNG intact and still exits nonzero.

Round-28 §42.11's hash-Set optimization should operate on this corrected **current-success** hash set. Removing `cut` (§42.9) may co-land but does not by itself fix the membership bug.

### 44.2 Waffle `Tasks.qml` partitions the same app list with two full filter passes — CONFIRMED / P2

Path:

- `modules/waffle/bar/tasks/Tasks.qml`.

Current bindings independently evaluate:

`TaskbarApps.apps.filter(app => app.pinned && app.toplevels.length === 0)`

and:

`TaskbarApps.apps.filter(app => app.toplevels.length > 0)`.

For `K` taskbar app records this performs two full source traversals and allocates both output arrays separately.

Exact-safe direction:

- derive one shared partition from one read of `TaskbarApps.apps`;
- in one loop append to `running` when `toplevels.length > 0`, otherwise append to `pinned` only when `app.pinned` is true;
- expose the two arrays from that shared partition.

This preserves current semantics exactly:

- pinned-only apps remain in the first Repeater;
- any app with live toplevels remains in the running Repeater even when also pinned;
- the synthetic separator remains excluded from both;
- relative order inside each group remains source order.

Local source-list visits: **`2K -> K`**.

### 44.3 Waffle `TaskAppButton` scans for the focused toplevel repeatedly — CONFIRMED / P2

Path:

- `modules/waffle/bar/tasks/TaskAppButton.qml`.

The same semantic value is currently rediscovered several times:

- `active` runs `appEntry.toplevels.some(t => t.activated)`;
- when active with multiple windows, `focusedWindowIndex` runs `find(t => t.activated === true)`;
- the Niri click path runs another `find(t => t.activated)` before minimizing the active window.

Strict-safe direction:

- keep one reactive `focusedToplevel` derived with the same first-activated-window rule;
- derive `active` from whether that value exists;
- reuse it in `focusedWindowIndex` and the click path.

For an active multi-window app this removes at least one full/partial toplevel scan from ordinary indicator evaluation, and removes another lookup on the focused-app click path.

This is independent of §40.21's Niri `windowForId` index. §40.21 still removes the inner `NiriService.windows.find(id)` work used to obtain layout columns.

Regression parity:

- zero/one/multiple visible windows;
- no activated window;
- activated window at first/middle/last position;
- Niri minimize-on-click still targets the same exact active ID;
- indicator index/order unchanged.

### 44.4 `TaskbarApps.computeApps()` double-probes the Map and rematerializes every final record — CONFIRMED / P1-P2

Path:

- `services/TaskbarApps.qml`.

Two local costs are coupled in the current aggregation.

#### A. Running-app Map probe

For every accepted source toplevel:

`if (!map.has(lowerAppId)) map.set(...)`

is followed by:

`map.get(lowerAppId).toplevels.push(toplevel)`.

Existing keys therefore perform `has + get`; new keys perform `has + set + get`.

Exact-safe direction:

- perform one `get(lowerAppId)`;
- if absent, create/store the record once;
- append through the local record reference.

This removes one Map lookup for every accepted running toplevel.

#### B. Final Map -> array rematerialization

After all grouping is complete, the function does a second pass across the whole Map and creates a new public object for every entry solely to add `appId`:

`{ appId: key, toplevels: value.toplevels, pinned: value.pinned }`.

Instead, create the final-shape record at first insertion:

`{ appId, toplevels, pinned }`

store that same record in the Map, and push it once into an ordered `values` array at first insertion.

Because JavaScript Map iteration order is first-insertion order, pushing at the same first-insertion sites preserves the exact current output order:

- resolved pins first;
- optional `SEPARATOR` at its current position;
- newly encountered running identities after that;
- later windows only mutate the already-owned `toplevels` array.

Local effect for `K` final app records:

- final Map traversal: **`K -> 0`**;
- final wrapper-object allocations: **`K -> 0`** (the grouping record itself becomes the returned record);
- plus one Map membership lookup removed per accepted running toplevel.

`scripts/test-taskbar-app-model-contract.py` already locks the important pin/case/filter/order/authoritative-Niri behavior and is the natural regression base for this change.

### 44.5 Waffle preview `findNiriWindow()` fallback is defensive on the normal taskbar path, not a primary hot path — ALREADY / CLOSED as standalone optimization

Paths:

- `services/TaskbarApps.qml`;
- `services/CompositorService.qml`;
- `services/NiriService.qml`;
- `modules/waffle/bar/tasks/TaskPreview.qml`;
- `modules/waffle/bar/tasks/WindowPreview.qml`.

On Niri, `TaskbarApps.computeApps()` intentionally consumes only `CompositorService.sortedToplevels`.

`CompositorService.sortedToplevels` is produced through `NiriService.sortToplevels(...)`, and the enriched object created by NiriService contains the exact `niriWindowId` / `niriWorkspaceId`. Unmatched foreign-toplevel handles are deliberately dropped as stale/ghost handles.

Therefore normal Waffle taskbar app entries already carry `niriWindowId`; the later `findNiriWindow()` calls in TaskPreview/WindowPreview are fallback/defensive compatibility paths rather than the normal source of identity.

Do not create a standalone patch whose only purpose is deleting that fallback. The meaningful hot-path wins are:

- Round 29 §43.3: stop after the first valid identity instead of resolving every app window;
- Round 29/26 shared published-window index work where real repeated ID lookups remain.

### 44.6 Deferring the initial clipboard snapshot until after live-ID validation is attractive but not strict-lossless yet — NEEDS PARITY

Path:

- `scripts/capture-windows.sh`.

The helper currently saves the clipboard before querying/validating live Niri window IDs. As a result, requests that later discover no usable windows can still pay initial `wl-paste -l` plus a MIME paste even though no screenshot will run.

Moving the clipboard snapshot after `windows_to_capture` validation would remove that work on no-window/all-missing requests.

However this changes the time boundary at which the user's clipboard is sampled for a real capture. A user copy racing with the Niri window query can therefore change which selection is later restored.

Under the absolute-lossless rule, do **not** promote this as a static reorder optimization without a race contract/fixture defining the intended saved-selection boundary.

### 44.7 Round-30 priority update

**Correctness prerequisite:**

1. restrict helper cleanup hashes to PNGs successfully generated by the current invocation (§44.1).

**Confirmed lossless local reductions:**

2. one-pass Waffle pinned/running partition (§44.2);
3. shared focused toplevel in Waffle `TaskAppButton` (§44.3);
4. single-probe + direct final-record construction in `TaskbarApps.computeApps()` (§44.4).

**Closed / already explained:**

5. deleting Waffle `findNiriWindow()` fallback as a standalone optimization (§44.5).

**Parity required:**

6. moving the initial clipboard snapshot later to avoid work on no-op requests (§44.6).

Round-28/29 confirmed WindowPreview/helper reductions remain valid after the concurrent Abyss/Polkit handoff updates. No runtime/source implementation is authorized by this handoff.

---

## 45. Round 31 — MinimizedWindows query specialization, taskbar sort parity and clipboard race closure (2026-09-29)

### Snapshot / concurrent reconciliation

- Current \`dev\` HEAD immediately before this docs-only write: \`5120b7bd7c588c6fe3e52618cd74df1fdd74dcdf\` (\`docs(perf): audit capture hashes and waffle taskbar\`).
- The branch is identical to the Round-30 handoff commit; there is no concurrent delta to reconcile in this round.
- Runtime/source remained research-only. This round audits \`services/MinimizedWindows.qml\`, Waffle \`TaskAppButton.qml\`, \`scripts/capture-windows.sh\`, and the exact Niri/Qt invariants needed to distinguish safe reductions from parity-changing ones.
- Round-26 §40.21 remains the owner of the proposed lazy published-\`windows\` ID index. The MinimizedWindows findings below intentionally do not duplicate its \`M x N -> N + M\` live-window lookup claim.

### 45.1 Persistent stash recovery uses quadratic duplicate membership — CONFIRMED / P2 startup-recovery

Path:

- \`services/MinimizedWindows.qml\`.

\`recoverPersistentState()\` already builds a \`Set\` for live Niri IDs, but duplicate suppression for restored stash IDs still uses the growing array:

\`ids.includes(id)\`.

For P valid persisted entries, all-distinct or late-duplicate input can therefore perform approximately:

\`1 + 2 + ... + (P - 1)\`

array comparisons, i.e. an O(P²)-shaped duplicate-check phase.

Exact-safe direction:

- retain the current ordered \`ids\` array as the public/persisted order;
- add a local \`seenIds\` Set used only for duplicate membership;
- after JSON parse and live-ID validation, reject an ID if \`seenIds.has(id)\`;
- otherwise add it to the Set, assign the restored record and append the ID exactly once.

This preserves the current important semantics:

- invalid JSON is skipped;
- non-live IDs are skipped;
- the **first** persisted occurrence of a duplicate ID wins;
- restored ID order is unchanged;
- the same record is persisted again after recovery.

Duplicate membership changes from O(P²) worst-shaped array scanning to O(P) Set operations.

This is a startup/recovery optimization rather than a steady-state shell hotspot, so P2 is appropriate.

### 45.2 Count/latest MinimizedWindows queries materialize full filtered arrays unnecessarily — CONFIRMED / P2

Path:

- \`services/MinimizedWindows.qml\`.

The general-purpose helpers \`getMinimizedForApp()\` and \`getMinimizedForOutput()\` are useful when a caller genuinely needs every matching ID.

Three current callers need less information:

1. \`countMinimizedForApp(appId)\` calls \`getMinimizedForApp(appId).length\`;
2. \`restoreLatestForApp(appId)\` materializes all matches, then reads the last one;
3. \`restoreLatestForOutput(outputName)\` materializes all matches, then reads the last one.

Exact-safe specialization:

- **count:** scan \`minimizedIds\` once and increment for the exact existing predicate;
- **latest app:** scan \`minimizedIds\` from the end and stop at the first ID whose stored \`appId.toLowerCase().includes(pattern)\` predicate matches;
- **latest output:** scan from the end and stop at the first stored \`originalOutput\` exact match.

A reverse scan returns exactly the same element as \`filter(...)[length - 1]\` because \`filter()\` preserves source order.

Benefits:

- \`countMinimizedForApp\`: one O(M) scan remains, but the temporary matching-ID array disappears;
- both latest helpers: matching-array allocation disappears and common cases can stop before scanning all M minimized IDs;
- Waffle \`TaskAppButton\` calls \`countMinimizedForApp\` per app button, so this also removes one temporary array per button reevaluation without changing the indicator count.

Keep \`getMinimizedForApp()\` itself because \`restoreApp()\` legitimately needs the complete ordered match set.

### 45.3 \`restoreWorkspace()\` filters and sorts a subset that NiriService already publishes in index order — CONFIRMED / P2

Paths:

- \`services/MinimizedWindows.qml\`;
- \`services/NiriService.qml\`.

Every current publication of \`NiriService.allWorkspaces\` explicitly sorts by ascending \`workspace.idx\`.

\`restoreWorkspace(info, true)\` then:

1. checks exact \`originalWorkspaceId\`;
2. filters \`allWorkspaces\` to the original output;
3. sorts that subset by ascending \`idx\` again;
4. looks for exact original \`idx\`;
5. otherwise reduces to the nearest \`idx\`, updating only on a **strictly** smaller distance.

Because \`filter()\` preserves source order, the secondary ascending sort is redundant.

A stronger one-pass implementation can preserve the full fallback contract:

- scan the already ordered \`allWorkspaces\` once;
- ignore other outputs;
- immediately return an exact \`idx\` match;
- otherwise keep the first candidate and replace it only when absolute distance is strictly smaller.

The current strict-closer rule means equal-distance ties keep the earlier item. Since the filtered source is already ascending, that is the lower-\`idx\` candidate; the one-pass scan preserves the same tie.

Local work changes from roughly:

- O(W) filtering + O(K log K) sorting + another K lookup/reduce,
- to one O(W) scan,

while removing the filtered array and sort allocation entirely.

The separate exact-\`originalWorkspaceId\` check must remain first.

### 45.4 \`stashWorkspaceForOutput()\` can avoid two temporary collections, but the max-index selection is HIGH CONFIDENCE rather than absolute-confirmed — HIGH CONFIDENCE / P2

Path:

- \`services/MinimizedWindows.qml\`.

Two independent collection-building steps exist.

#### A. Existing minimized workspace lookup

Current code starts with:

\`for (const id of getMinimizedForOutput(output))\`

which first allocates the full filtered ID list and then iterates it in the same \`minimizedIds\` order.

The same behavior can be obtained by iterating \`minimizedIds\` directly and applying the exact \`originalOutput\` predicate inline.

This removes one temporary ID array while preserving first-match order.

When §40.21's shared published-window ID index exists, the per-ID \`liveWindows.find(...)\` can then use that index without changing this ordering contract.

#### B. Empty workspace selection

After building the occupied-workspace Set, current code does:

- filter \`allWorkspaces\` to matching-output, unoccupied workspaces;
- sort descending by \`idx\`;
- return the first entry.

Under normal Niri semantics, workspace \`idx\` is a positional index on its output, so a single pass retaining the greatest \`idx\` selects the same workspace and removes:

- one filtered array;
- one O(K log K) sort.

Keep this **HIGH CONFIDENCE** rather than absolute-confirmed because QV4's normal JavaScript Array \`sort()\` is not stable. A malformed snapshot containing duplicate same-output \`idx\` values could therefore give the current descending sort a tie order that a simple first-max scan would not be required to reproduce.

Do not trade away that defensive parity merely to claim a confirmed micro-optimization. A fixture that establishes unique \`idx\` per output (or intentionally defines duplicate tie behavior) is enough to promote this direction.

### 45.5 Replacing Waffle focused-window sorting with O(A) rank counting is CLOSED under strict-lossless parity

Path:

- \`modules/waffle/bar/tasks/TaskAppButton.qml\`.

After §40.21 removes repeated global window-ID scans and §44.3 shares the focused toplevel, one apparent remaining optimization is to avoid:

\`windowPositions.sort((a, b) => a.col - b.col)\`

and compute the focused window's rank in one pass.

That is **not** a static lossless substitution.

Qt's QV4 JavaScript Array implementation was checked directly in upstream \`qtdeclarative\`:

- a normal populated JS Array enters \`ArrayData::sort()\`;
- \`ArrayData::sort()\` calls QV4's custom \`sortHelper\`;
- \`sortHelper\` is a swap-based quicksort helper, not a stable sort.

Equal-column comparisons return zero, so the current result does not promise original-index ordering for ties.

Equal columns are not purely theoretical here:

- multiple windows can share a layout column;
- windows with no usable layout position all receive the same sentinel \`999999\`.

Therefore an O(A) rank formula that introduces deterministic original-index tie ordering can change which indicator slot is considered focused.

Status:

- **CLOSED** as an absolute-lossless standalone optimization;
- §40.21's published-window ID index remains valid and independent;
- §44.3's shared \`focusedToplevel\` remains valid and independent;
- only revisit the sort itself if product behavior explicitly defines a deterministic tie contract and regression tests lock it.

### 45.6 A user copy between the saved snapshot and the first screenshot can still be overwritten by an older clipboard — CONFIRMED correctness bug / supersedes §44.6

Path:

- \`scripts/capture-windows.sh\`.

Round 30 §44.6 treated moving the initial clipboard snapshot after live-ID validation as a timing-sensitive optimization.

History and the full race show a stronger result: there is a current correctness gap in the explicit **newer user intent wins** contract.

Current order is:

1. save one clipboard representation;
2. query Niri windows;
3. validate requested IDs;
4. capture cliphist \`before_id\`;
5. run screenshot-window actions, each of which changes the clipboard;
6. if the final clipboard hash matches a generated preview, restore the saved clipboard.

Concrete race:

1. clipboard initially contains user value **A**;
2. helper saves A;
3. during Niri preflight, before the first screenshot, the user copies newer value **B**;
4. a screenshot later replaces the live clipboard with preview bytes **S**;
5. final clipboard hash matches a preview;
6. helper restores saved A.

The newer B may remain in cliphist, but the **current selection** has still been rolled back from B to older A.

That contradicts the intent documented when hash-based cleanup/restore was introduced:

- user copies made during capture must survive;
- if the user copied something else while capture ran, that newer intent wins.

So §44.6 should be read as **SUPERSEDED**:

- moving the saved snapshot after the no-window/request validation is directionally correct, removes unnecessary initial \`wl-paste -l\` / MIME paste work for no-op requests, and narrows this race window;
- but that reorder alone does **not** fully solve the race, because a user can still copy between the later snapshot and the first screenshot.

A strict fix needs a selection-generation/ownership contract that can distinguish:

- the selection value the helper intentionally displaced;
- a newer user selection created after capture began;
- Niri's screenshot selections.

Do not solve this by restoring “the latest cliphist entry” blindly; cliphist ingestion is asynchronous and the helper already has explicit two-pass timing because screenshot entries can arrive late.

Required fake-binary race fixture:

- start with current clipboard A;
- after the helper's saved read but before the first screenshot, mutate fake user clipboard to B;
- screenshot action changes it to S;
- final expected current clipboard is B, not A;
- B's history entry must also survive cleanup.

This correctness race is separate from §44.1's stale-old-preview hash bug. Both must be covered.

### 45.7 Regression requirements before MinimizedWindows implementation

There is no focused MinimizedWindows runtime contract test today.

A new harness should lock at least:

- persistent recovery rejects dead IDs and malformed JSON;
- duplicate persisted IDs keep the first record and first occurrence order;
- \`countMinimizedForApp\` preserves the current lowercase-substring predicate exactly;
- app/output “latest” helpers return the same result as current filter-then-last behavior;
- restore-to-original prefers exact workspace ID before index fallback;
- exact original \`idx\` wins;
- nearest-index fallback keeps the current equal-distance tie behavior;
- stash reuses the first already-minimized live workspace for the output before searching for an empty one;
- occupied workspaces are excluded;
- highest available output-local workspace index is selected only after the tie/uniqueness contract is locked.

For the helper, extend the fake-binary matrix from §44.1 with the A -> B -> screenshot clipboard race from §45.6.

### 45.8 Round-31 priority update

**Correctness prerequisites:**

1. fix the stale-old-PNG hash membership bug from §44.1;
2. close the newer-user-clipboard race from §45.6 rather than treating snapshot timing as a performance-only concern.

**Confirmed lossless local reductions:**

3. \`recoverPersistentState()\` duplicate membership Set (§45.1);
4. specialized count/latest MinimizedWindows scans without filtered-array materialization (§45.2);
5. one-pass \`restoreWorkspace()\` nearest/exact selection (§45.3).

**High confidence / parity fixture first:**

6. one-pass max-index stash workspace selection after eliminating the safe filtered-ID allocation (§45.4).

**Closed under absolute-lossless scope:**

7. replacing \`TaskAppButton\`'s current JS sort with a deterministic O(A) rank formula (§45.5).

Round-30 Waffle taskbar reductions (§44.2-§44.4), Round-29 WindowPreview contract closures and the earlier published-window ID-index work remain valid.

No runtime/source implementation is authorized by this handoff.

---

## 46. Round 32 — Niri enrichment cache, Hyprland sorter reductions and taskbar regex churn (2026-09-29)

### Snapshot / concurrent reconciliation

- Round 32 started from \`05957cbade951ab835db6f1ee44b9e5061e84c9e\`.
- Before the docs write, \`dev\` advanced by one concurrent commit:
  \`3728bef41e70ce3b7dc4745da82dfd553384362d\`
  (\`feat(abyss): auto-borrow semantic vacancy\`).
- That concurrent commit changes only:
  - \`modules/abyss/looks/AbyssVacancyBorrowing.js\`;
  - \`scripts/test-abyss-vacancy-borrowing-runtime.sh\`;
  - \`scripts/test-abyss-vacancy-borrowing.py\`.
- It does not touch \`NiriService.qml\`, \`CompositorService.qml\`,
  \`TaskbarApps.qml\`, WindowPreview/capture code or this handoff.
- The vacancy-borrowing runtime in that concurrent commit was later retired by `7d787fbf97da3dd5992fa9a41978643131da2994`; the commit remains relevant only as historical audit context.
- Those target files were re-read from the new exact HEAD immediately before
  this docs-only write.

This round deliberately corrects one attractive but unsafe inference found
during the audit: published \`NiriService.windows\` is usually spatially sorted,
but a later \`WorkspacesChanged\` event can alter the workspace/output metadata
used by the comparator without republishing the \`windows\` array. Therefore
\`sortToplevels()\` cannot simply stop sorting and assume the published order is
always current.

### 46.1 Memoize Niri spatial window sorting by the exact published state references — CONFIRMED / P1 when sorting consumers are active

Paths:

- \`services/NiriService.qml\`;
- \`services/CompositorService.qml\`;
- \`modules/bar/BarTaskbarPreview.qml\`.

\`NiriService.sortToplevels()\` currently begins every call with:

\`sortWindowsByLayout(windows)\`.

That helper performs:

1. one N-element \`map()\` creating sort records;
2. one N log N sort;
3. one N-element \`map()\` back to the original window objects.

The result depends only on the published references:

- \`windows\`;
- \`workspaces\`;
- \`outputs\`.

Round 26 §40.16 already audited the mutation contract for exactly these three
containers:

- window publications assign new arrays;
- workspace updates assign new maps;
- output updates assign new maps;
- no in-place \`windows[i] =\`, \`workspaces[id] =\` or \`outputs[name] =\`
  publication mutation was found.

That makes a private on-demand memo exact-safe:

- read the three published references on every call;
- if all three are identical to the references used for the cached sort, reuse
  the cached sorted window array;
- otherwise recompute with the **existing**
  \`sortWindowsByLayout()\`, then cache the result plus those exact references.

This preserves the important \`WorkspacesChanged\` case that prevents the naïve
optimization:

- a workspace can change \`idx\` or output ownership while \`windows\` itself
  remains the same array;
- the new \`workspaces\` reference invalidates the memo and forces the required
  re-sort.

It also preserves output geometry changes through the \`outputs\` reference.

The memo is private to the enrichment/order pipeline; do not change the public
\`sortWindowsByLayout(windowList)\` API or return semantics.

Local effect after the first request for one exact snapshot:

- repeated sort-record maps: **2N -> 0**;
- repeated N log N sort: **1 -> 0**;
- subsequent same-snapshot callers receive O(1) cache lookup plus iteration of
  the already sorted windows.

This matters because the same snapshot can be requested by:

- \`CompositorService.computeSortedToplevels()\`;
- Bar workspace-preview refreshes that call \`NiriService.sortToplevels()\`
  directly;
- multiple event/listener paths coalescing around the same published state.

The first request on a genuinely new \`windows/workspaces/outputs\` snapshot
still performs the exact current sort.

### 46.2 Niri toplevel matching scans candidates that can only score zero — CONFIRMED / P1

Path:

- \`services/NiriService.qml\`.

After spatial ordering, \`sortToplevels()\` loops each Niri window and scans the
full foreign-toplevel list until it finds the best unused match.

\`matchToplevelToWindow()\` has an exact first guard:

\`if (toplevel.appId !== niriWindow.app_id) return 0\`.

So a candidate with another app ID can never beat any positive same-app match,
and a window with no positive same-app candidate is rejected at the end anyway.

Exact-safe direction:

1. build \`appId -> ordered toplevel[]\` once from the input sequence;
2. preserve the original toplevel order inside every bucket;
3. for each already-spatially-ordered Niri window, scan only its exact app-ID
   bucket;
4. keep the existing \`usedToplevels\` rule;
5. keep the existing score calculation and strict \`score > bestScore\` update;
6. keep the early break on score 3;
7. keep unmatched foreign handles dropped exactly as today.

This preserves:

- exact-title score 3 precedence;
- substring score 2 precedence;
- same-app score 1 fallback;
- first-candidate tie behavior inside the original input order;
- one-to-one toplevel usage;
- ghost-handle rejection;
- final spatial Niri window order.

Candidate matching changes from worst-shaped approximately:

\`N x T\`

to:

\`T + sum(T_app for each Niri window)\`.

If windows/toplevels are evenly distributed across A app IDs, the comparison
term approaches roughly \`N x T / A\` after the one T-item grouping pass.
The all-windows-same-app worst case remains unchanged, which is correct.

Required matching fixture:

- multiple windows from the same app;
- duplicate/similar titles;
- exact score-3 match after an earlier score-1/2 candidate;
- substring score-2 fallback;
- score-1 fallback;
- already-used candidate;
- different-app candidates before/between same-app candidates;
- unmatched stale foreign handle.

### 46.3 Do not remove workspace re-sorts by merely preserving prior \`allWorkspaces\` order — CLOSED under strict-lossless parity

Path:

- \`services/NiriService.qml\`.

\`handleWorkspaceActivated()\` and \`handleWorkspaceUrgencyChanged()\` rebuild:

\`Object.values(updatedWorkspaces).sort((a, b) => a.idx - b.idx)\`.

Because those events do not normally change \`idx\`, it is tempting to map over
the previous \`allWorkspaces\` array and avoid the sort.

That is **not** a static lossless substitution.

Niri's \`workspace.idx\` is an index on an output, not a globally unique key.
Multiple outputs can therefore have the same \`idx\`.

The current comparator has no output/id tie-breaker, and QV4's populated JS
Array sort uses its swap-based \`sortHelper\`, which is not stable.

Therefore a same-\`idx\` cross-output tie can be permuted by the existing sort.
Simply retaining the previous array order would impose a different tie contract.

Status:

- **CLOSED** as an unconditional lossless sort removal;
- a future deterministic comparator can be a product/behavior cleanup, but it
  would define new ordering semantics and must not be disguised as a no-op
  optimization.

This is distinct from §45.3, where \`restoreWorkspace()\` first filters to one
specific output before relying on ascending workspace index order.

### 46.4 Hyprland sorter builds a full snapshot, then traverses it again only to group it — CONFIRMED / P1-P2 on Hyprland

Path:

- \`services/CompositorService.qml\`.

\`sortHyprlandToplevelsSafe()\` currently:

1. loops H toplevels and builds \`snap\`;
2. loops all H \`snap\` records again to group by monitor/workspace;
3. for each record performs \`groups.has(key)\` and then \`groups.get(key)\`;
4. loops the final Map again to create one wrapper group object per group.

The group wrapper copies metadata from \`arr[0]\`, i.e. the **first** item seen
for that key.

All of this can be fused into the original source loop while preserving exact
first-seen semantics:

- compute the existing snapshot record exactly as today;
- derive the same group key immediately;
- do one \`groups.get(key)\`;
- if absent, create the final-shape group record from this first item, store it
  in the Map and append it once to \`groupList\`;
- append the item to \`group.items\`.

Preserved behavior:

- first item still supplies group monitor/order metadata;
- group insertion order is unchanged;
- the later \`groupList.sort(...)\` comparator is unchanged;
- every item still participates in the same per-group column/y/title/address
  ordering.

Local reductions for H live toplevels and G groups:

- source/grouping traversals: **2H -> H**;
- temporary \`snap\` array: removed;
- one Map membership probe per item: removed (\`has + get -> get\`);
- final Map traversal: **G -> 0**;
- separate G wrapper allocations: removed because the stored group is already
  the final group shape.

### 46.5 Two additional Hyprland collection passes can be collapsed without changing ordering — CONFIRMED / P2

Path:

- \`services/CompositorService.qml\`.

Two independent local reductions remain after §46.4.

#### A. Finite X-coordinate preparation

Current per-group code executes:

\`arr.map(it => it.x).filter(x => Number.isFinite(x)).sort(...)\`.

The sort itself is required.

A single loop can append only finite \`it.x\` values to \`xs\`, then run the
same numeric sort.

Before the sort:

- source traversals: **2K -> K** for a K-item group;
- mapped intermediate array: removed.

#### B. Final wayland result

Current code:

- appends every sorted snapshot record into \`ordered\`;
- then returns
  \`ordered.map(x => x.wayland).filter(w => w !== null && w !== undefined)\`.

Null-wayland records must still participate in all grouping/column/sort logic,
because removing them earlier can change the order of surviving records.

But after each group has been sorted, the final emission can append only the
non-null \`it.wayland\` value directly to the result array in that exact sorted
order.

This removes:

- the intermediate all-record \`ordered\` array;
- one full \`map\`;
- one full \`filter\`.

Presentation order and final membership remain identical.

A further binary-search nearest-column implementation is mathematically
possible because \`colCenters\` is sorted and the current strict \`<\`
comparison gives equal-distance ties to the lower/earlier center. Keep that
micro-optimization below the pass/allocation removals unless profiling shows
many columns.

### 46.6 Persistent missing Hyprland coordinates can form a self-sustaining refresh loop — CONFIRMED conditional correctness/performance debt

Path:

- \`services/CompositorService.qml\`.

Current sequence for a toplevel with:

- nonempty \`address\`;
- no usable \`lastIpcObject.at\`;
- no cached coordinate for that address;

is:

1. mark \`missingAnyPosition = true\`;
2. mark \`hasNewWindow = true\`;
3. assign sentinel coordinates;
4. call \`scheduleRefresh()\`;
5. 40 ms refresh timer runs \`Hyprland.refreshToplevels()\`;
6. it clears \`_refreshScheduled\` and schedules another sort;
7. if the refreshed toplevel still has no usable coordinates/cache entry, the
   next sort repeats steps 1-6.

There is no per-address or per-generation retry cap in the current source.

Historical source also carried a \`_hasRefreshedOnce\` property, but it was only
written, never read as a guard; its later removal did not create this loop.

Therefore the algorithm has a confirmed unbounded retry shape **if** a live
supported toplevel remains positionless across refreshes.

Do not blindly restore the dead historical boolean.

Strict correction requires a generation/identity-aware retry contract, for
example:

- at most one forced refresh for a given missing address within one underlying
  Hyprland toplevel generation;
- clear/rearm when real coordinates appear or when authoritative toplevel
  membership changes in a way that represents a new candidate.

Required runtime/fake-model cases:

- transient new window: one refresh obtains coordinates;
- position remains missing after refresh: no periodic 40/100 ms self-loop;
- a later genuine Hyprland change rearms a refresh attempt;
- multiple simultaneous new missing windows coalesce into the existing one
  refresh timer;
- sorting demand off still performs no refresh work.

Do not claim stock-session CPU savings until runtime prevalence of persistent
positionless toplevels is measured.

### 46.7 Hyprland coordinate cache grows with historical addresses and has no prune path — CONFIRMED resident-state debt / fix needs lifecycle parity

Path:

- \`services/CompositorService.qml\`.

Whenever a toplevel exposes valid coordinates and a nonempty address:

\`_coordCache[addr] = { x: atX, y: atY }\`.

Repository search and current source audit found:

- reads from \`_coordCache[addr]\`;
- writes for valid coordinates;
- **no delete, clear or live-address prune path**.

Thus retained cache cardinality follows the number of distinct addresses seen
during the shell lifetime, not the number of currently live windows.

The entry size is small, so this is not a top RSS target, but it is unbounded by
current live state.

A live-address prune is plausible, but keep the fix parity-gated because the
cache intentionally bridges snapshots where one existing window temporarily
lacks \`at\`. A prune policy must distinguish:

- a genuinely closed address;
- a transiently absent/refreshing representation;
- a later address reuse/new window.

This also matters to §46.6: a stale retained address can suppress
\`hasNewWindow\` for a future same-address observation because a cache hit is
treated as known coordinates.

### 46.8 Waffle TaskbarApps recompiles five invariant system regexes on every model rebuild — CONFIRMED / P2

Path:

- \`services/TaskbarApps.qml\`.

Every \`computeApps()\` creates:

\`systemIgnored = ["^$", "^portal$", "^x-run-dialog$", "^kdialog$", "^org.freedesktop.impl.portal.*"]\`

and then passes user patterns plus all five system patterns through:

\`new RegExp(pattern, "i")\`.

The five system expressions are immutable for the singleton lifetime.

This differs from existing Bar/Dock taskbar implementations, which already keep
an ignored-regex cache.

Strict-safe minimal direction:

- precompile **only the five fixed system regexes** once;
- continue normalizing and compiling user-configured patterns on each
  \`computeApps()\` exactly as today;
- concatenate the user compiled results with the precompiled system list.

Why not cache user patterns in the first lossless patch?

\`TaskbarApps._compileRegexes()\` currently logs every invalid user regex on
every rebuild. Caching user compilation would change that diagnostic cadence
unless invalid-pattern warnings were explicitly replayed.

With the default \`ignoredAppRegexes=[]\`:

- regex constructions per \`computeApps()\`: **5 -> 0**.

This path can rebuild on sorted-toplevel changes, ToplevelManager changes,
AppSearch publication and dock config changes, so the fixed compile churn can
repeat during ordinary Waffle window activity.

### 46.9 Named sorting-consumer count can update by delta instead of rescanning the private registry — CONFIRMED / P3

Path:

- \`services/CompositorService.qml\`.

\`setSortingConsumer(name, active)\` already computes:

\`prev = !!root._sortingConsumers[name]\`

and returns when \`prev === active\`.

When the value really changes, it then writes the one key and loops every key in
\`_sortingConsumers\` merely to recount active entries.

Repository search found no other writer of the private registry or count.

Therefore after the existing equality guard:

- false -> true: increment \`_sortingConsumersCount\`;
- true -> false: decrement it.

This preserves:

- the private registry values;
- \`sortingActive\` truth;
- zero-crossing behavior passed to \`_handleSortingDemandChanged()\`;
- named consumer semantics.

Count recomputation changes from O(C) over every historical named consumer to
O(1).

Current named-consumer cardinality is small, so this is a completeness/P3 item,
not a priority ahead of the Niri/Hyprland sorter work.

### 46.10 Regression requirements before implementation

Niri enrichment needs a focused behavior harness. Existing tests prove taskbar
aggregation and preview lifecycle contracts, but they do not lock the
Niri-window/foreign-toplevel pairing algorithm.

Add parity cases for:

- §46.1 cache invalidation on independent changes to each of
  \`windows/workspaces/outputs\`;
- same exact snapshot reuses one sorted result;
- workspace \`idx/output\` change with unchanged \`windows\` forces a new sort;
- §46.2 score 3/2/1 matching and source-order ties;
- no foreign toplevel is reused;
- unmatched ghosts remain dropped.

Hyprland sorter tests should lock:

- group first-item metadata;
- monitor/workspace group order;
- column threshold behavior;
- equal-distance column tie;
- y-jitter/title/address ordering;
- null-wayland items still influence sorting but are absent from final output;
- transient vs persistent missing-coordinate refresh behavior;
- coordinate-cache lifecycle/reuse.

TaskbarApps should retain the existing invalid-user-regex warning behavior while
proving fixed system regexes are not recompiled on repeated model rebuilds.

### 46.11 Round-32 priority update

**Correctness/performance prerequisite on the conditional Hyprland path:**

1. bound the persistent missing-coordinate refresh cycle with an explicit
   generation/identity contract (§46.6).

**Confirmed lossless high-value reductions:**

2. exact-snapshot memo for Niri spatial window sorting (§46.1);
3. app-ID candidate buckets for Niri toplevel matching (§46.2);
4. one-pass Hyprland snapshot/group construction (§46.4);
5. Hyprland finite-X and final-result pass/allocation removal (§46.5).

**Confirmed but lower priority:**

6. precompile the five invariant Waffle taskbar system regexes (§46.8);
7. O(1) named sorting-consumer count update (§46.9).

**Confirmed debt / parity-gated remediation:**

8. unbounded historical Hyprland coordinate cache (§46.7).

**Closed under absolute-lossless scope:**

9. simply retaining prior \`allWorkspaces\` order instead of the current
   same-\`idx\` unstable sort (§46.3).

Round-31 clipboard correctness prerequisites (§44.1 / §45.6) remain above all
pure performance work in implementation priority.

No runtime/source implementation is authorized by this handoff.

---

## 47. Round 33 — ii taskbar cache correctness, Bar collection costs and Settings search preparation (2026-09-30)

### Snapshot / concurrent reconciliation

Round 33 began after the Round-32 docs commit
\`88be345a44b917440bcb30c8f76895e9e85e82d9\`.

The branch moved several times while this audit was in progress:

- \`ea8c93466db0d8ccdf9b8a1ae67e9f7fb0e5b630\`
  — \`fix(abyss): auto-expand newest semantic surface\`;
- \`7d787fbf97da3dd5992fa9a41978643131da2994\`
  — \`revert(abyss): retire prompt and vacancy experiments\`;
- \`828fe8e2ad36edffe014e688a999604bd76a935c\`
  — \`docs(abyss): mark retired experiments historical\`.

The retirement commit is broad and was explicitly reconciled before this
write. It removes the experimental Confirmation/prompt/vacancy runtime and also
removes the corresponding prompt-anchor registration lines from
\`BarTaskbarButton.qml\` and \`DockAppButton.qml\`.

It does **not** remove or materially change:

- \`BarTaskbar.qml\` model derivation;
- \`DockApps.qml\` model derivation;
- the existing Dock SystemTray association in \`DockAppButton.qml\`;
- \`SettingsSearchRegistry.qml\`;
- the Niri matching/filtering functions audited below.

The follow-up handoff edit only marks retired Abyss findings historical.

All overlapping target files plus \`AGENTS.md\` were re-read from exact HEAD
\`828fe8e2...\` before this docs-only write. Retired Abyss findings are not
reopened by this round.

### 47.1 Bar/Dock ignore-regex cache skips all built-in system filters on a default-empty first run — CONFIRMED correctness bug / prerequisite

Paths:

- \`modules/bar/BarTaskbar.qml\`;
- \`modules/dock/DockApps.qml\`;
- \`services/TaskbarApps.qml\` as the working Waffle comparison;
- \`modules/common/Config.qml\`.

Both ii taskbar implementations initialize:

\`_cachedIgnoredRegexes = []\`

and:

\`_lastIgnoredRegexStrings = []\`.

Their cache refresh condition is:

\`JSON.stringify(ignoredRegexStrings) !== JSON.stringify(_lastIgnoredRegexStrings)\`.

The shipped/default config is:

\`ignoredAppRegexes: []\`.

Therefore the first normal call evaluates:

\`JSON.stringify([]) === JSON.stringify([])\`

and does **not** enter the compile block.

The five built-in patterns inside that block are consequently absent from the
cache:

- \`^$\`;
- \`^portal$\`;
- \`^x-run-dialog$\`;
- \`^kdialog$\`;
- \`^org.freedesktop.impl.portal.*\`.

The empty-app case is independently rejected by other Bar/Dock checks, but the
portal/dialog patterns are not.

The cache becomes correct only after the configured user list changes to a
different value at least once. If it later changes back to empty, that
transition also compiles the system patterns because the previous cached string
list is then nonempty.

This is a long-standing bug; historical BarTaskbar source back to the original
cached implementation has the same empty/empty initialization.

Waffle's \`TaskbarApps.computeApps()\` does not have this bug because it
concatenates and compiles the five system patterns on every rebuild.

Strict correction:

- add an explicit cache-initialized flag, or use an impossible initial sentinel;
- first \`_getIgnoredRegexes()\` call must compile the system patterns even when
  the user list is empty;
- subsequent calls may reuse the cache only after one successful initialization.

This correctness prerequisite should be fixed before measuring the regex-cache
micro-optimizations below, because a benchmark of the current default path is
currently benchmarking a cache that is missing intended work.

Required tests:

1. fresh/default \`ignoredAppRegexes=[]\`: portal, x-run-dialog, kdialog and
   freedesktop portal IDs are excluded on the **first** model build;
2. nonempty user list: user + system patterns are both active;
3. nonempty -> empty transition: system patterns remain active;
4. Bar and Dock produce the same system-ignore result;
5. Waffle behavior remains unchanged.

### 47.2 One invalid configured app regex can abort ii Bar/Dock model rebuilds; Waffle already degrades safely — CONFIRMED robustness gap

Paths:

- \`modules/bar/BarTaskbar.qml\`;
- \`modules/dock/DockApps.qml\`;
- \`services/TaskbarApps.qml\`.

Bar and Dock compile with:

\`allIgnored.map(pattern => new RegExp(pattern, "i"))\`

without a per-pattern exception guard.

\`ignoredAppRegexes\` is typed as \`list<string>\`, but no repository-side regex
syntax validator was found for the configured strings.

A malformed expression therefore throws during \`_getIgnoredRegexes()\` and can
abort the current taskbar/Dock rebuild.

Waffle already defines the safer intended family behavior in
\`TaskbarApps._compileRegexes()\`:

- compile each pattern independently;
- catch invalid patterns;
- log the invalid pattern;
- continue with all valid patterns.

This is not a performance optimization by itself, but it is a correctness
prerequisite for making the ii regex cache robust.

When fixing §47.1, align Bar/Dock invalid-pattern handling with Waffle rather
than caching a failed whole-list compilation.

Required parity cases:

- one invalid user pattern between two valid patterns;
- system patterns still active;
- valid user patterns still active;
- invalid pattern does not empty/freeze the model;
- changing the invalid list to a valid list rebuilds normally.

### 47.3 BarTaskbar pinned-order sorting repeatedly rescans the entire pinned list inside its comparator — CONFIRMED / P1-P2 when Bar taskbar is enabled

Path:

- \`modules/bar/BarTaskbar.qml\`.

The shipped Bar taskbar module is disabled by default, so this is a conditional
hot path rather than default-session work.

When \`separatePinnedFromRunning\` is enabled, the current running-app sort calls:

- \`pinnedApps.findIndex(...)\` for A;
- \`pinnedApps.findIndex(...)\` for B;

inside every comparator invocation.

After sorting, every running app again calls:

\`pinnedApps.some(...)\`

to populate its \`pinned\` field.

For:

- P configured pinned IDs;
- R running app groups;

the pinned-order part is approximately:

- O(P) per comparator side across O(R log R) comparisons;
- plus another O(R x P) membership pass.

Exact-safe direction:

1. build one \`lowercase appId -> first pinned index\` Map in original config
   order;
2. insert only when the lowercase key is absent, because current
   \`findIndex()\` uses the **first** matching occurrence when config contains
   duplicates/case variants;
3. comparator reads the Map in O(1);
4. the later \`pinned\` field uses \`map.has(lowerAppId)\`.

This preserves:

- first configured duplicate wins for pinned ordering;
- pinned apps precede unpinned running apps;
- unpinned alphabetical order;
- all existing case-insensitive matching.

The pinned-order component changes from roughly:

\`O(R log R x P + R x P)\`

to:

\`O(P + R log R)\`.

Do not replace the final running-app sort itself; its alphabetical and
configured-pin ordering is visible behavior.

### 47.4 BarTaskbar and DockApps repeat Map membership + lookup for every accepted toplevel — CONFIRMED / P2

Paths:

- \`modules/bar/BarTaskbar.qml\`;
- \`modules/dock/DockApps.qml\`.

Both ii model builders currently use the same pattern:

1. \`runningAppsMap.has(lowerAppId)\`;
2. maybe \`set(...)\`;
3. \`runningAppsMap.get(lowerAppId).toplevels.push(...)\`.

Round 30 §44.4 already identified this in Waffle \`TaskbarApps\`; the same
reduction applies independently to the ii Bar and Dock implementations.

Exact-safe form:

- \`entry = runningAppsMap.get(lowerAppId)\`;
- if absent, create/store the exact current record and keep it in \`entry\`;
- append through that local record.

Map insertion order is unchanged because creation still occurs at the first
accepted toplevel for each lowercase app ID.

Effect:

- one Map probe removed per accepted running toplevel;
- no ordering, identity, pin or ghost-filter semantics change.

This can co-land with the larger Dock §37.5 / Waffle §44.4 collection work but
does not depend on those changes.

### 47.5 Horizontal Bar overflow trimming has three avoidable collection allocations/passes — CONFIRMED / P2

Path:

- \`modules/bar/BarTaskbar.qml\`.

This path runs only when the horizontal taskbar model is wider than its granted
slot.

Three local reductions are exact-safe.

#### A. Focused/rest partition

When \`keep.length >= maxFit\`, current code runs:

- \`keep.filter(focused)\`;
- \`keep.filter(not focused)\`;
- \`focused.concat(rest).slice(...)\`.

One loop can append to \`focused\` or \`rest\` while preserving the exact source
order of both partitions, then keep the same concat/slice selection.

Visits over \`keep\` change from **2K -> K** before the same selection.

#### B. Original-order Map construction

Current code creates:

\`new Map(items.map((it, i) => [it.uniqueId, i]))\`.

A direct loop that calls \`orderOf.set(uniqueId, i)\` removes the temporary
N-element pair array.

If duplicate \`uniqueId\` values ever occur, repeated \`set()\` preserves the
current \`Map(items.map(...))\` behavior: the **last** index wins.

#### C. Final separator filter is currently unreachable work

The first partition loop explicitly executes:

\`if (it.section === "separator") continue\`.

Therefore neither \`keep\` nor \`droppable\` can contain a separator, and every
possible \`result\` is assembled exclusively from those two arrays.

The final:

\`result.filter(...separator...)\`

can consequently never remove an element on the current overflow path.

Removing it preserves the exact existing behavior, including the perhaps
surprising current rule that **all separators disappear whenever horizontal
overflow trimming activates**.

Do not “fix” that presentation rule inside a performance patch; that would be a
separate UI behavior change.

### 47.6 Bar/Dock regex-cache comparison serializes two string lists on every model rebuild — CONFIRMED after §47.1 / P2

Paths:

- \`modules/bar/BarTaskbar.qml\`;
- \`modules/dock/DockApps.qml\`.

After the initialization bug is corrected, the cache-change check still performs:

- \`JSON.stringify(currentList)\`;
- \`JSON.stringify(previousList)\`;

on every model rebuild.

The config schema is a typed \`list<string>\`.

An exact sequence comparison can instead:

1. compare lengths;
2. compare each string at the same index;
3. stop on the first difference.

Order and duplicates remain significant exactly as they are under JSON array
serialization.

This removes two serialization strings/JSON traversals from every unchanged
model rebuild.

Keep this below §47.1: simply optimizing the current comparison without fixing
first-call initialization would make the broken default behavior faster.

### 47.7 Dock tray association creates avoidable temporary arrays and nested callbacks for every candidate tray item — CONFIRMED local reduction / P2

Path:

- \`modules/dock/DockAppButton.qml\`.

The Confirmation retirement removed only the retired prompt-anchor registration
from this component. The existing \`appTrayItem\` association remains active.

For every Dock app delegate, the binding currently:

1. creates a four-element identity array;
2. \`map()\` normalizes all four values;
3. \`filter()\` removes low-entropy values;
4. scans \`SystemTray.items.values.find(...)\`;
5. for every tray candidate, creates a one-element \`trayKeys\` array;
6. filters that array;
7. runs nested \`trayKeys.some(... appKeys.some(...))\`.

The tray side has exactly one identity source:

\`item.id\`.

Therefore the inner one-element array/filter/some structure is unnecessary.

Exact-safe local direction:

- build \`appKeys\` with one explicit loop, preserving current source order and
  duplicates;
- for each tray item compute one scalar normalized tray key;
- reject it immediately when length < 3;
- loop the prepared app keys and retain the exact current match rule:
  - equality, or
  - minimum entropy >= 5 and either suffix direction;
- stop on the first matching tray item, preserving \`find()\` first-item
  precedence.

This removes the per-candidate tray array/filter/some allocations without
changing which SNI item wins.

A second-stage shared normalized-tray snapshot could avoid re-normalizing the
same SNI ID independently in every Dock delegate/output, but keep that
**HIGH CONFIDENCE / demand-gated** rather than bundling it into the local patch:
eagerly moving tray preparation into an always-live singleton could create work
when Dock is absent.

### 47.8 SettingsSearchRegistry lowercases and joins immutable entry metadata again for every typed query — CONFIRMED / P1-P2 while Settings search is active

Path:

- \`modules/common/widgets/SettingsSearchRegistry.qml\`.

\`registerOption()\` creates each entry with:

- page index/name;
- section;
- label;
- description;
- keywords.

Repository audit found no metadata-update path afterward:

- entries are registered;
- later they are removed/compacted;
- no code mutates \`entry.label\`, \`entry.description\`, page/section or
  keywords in place.

The current search loop nevertheless recomputes for every active entry on every
query:

- label lowercase;
- description lowercase;
- page-name lowercase;
- section lowercase;
- keyword \`join(" ")\` + lowercase.

This is repeated on each typed search update and is shared by ii/Waffle settings
surfaces through \`SettingsSearchRegistry.buildResults()\`.

Exact-safe direction:

- keep the public entry object shape unchanged;
- create a **private** prepared record keyed by entry ID at registration time,
  containing the five normalized search strings plus the already-derived
  section-group display string;
- remove that private record when the entry is unregistered/compacted/cleared;
- \`buildResults()\` reads the prepared strings but continues using the original
  entry for public result fields and control ownership.

Because current metadata is already frozen at registration, this changes only
when the string transformations happen, not what they contain.

For E live registered controls, each query removes approximately:

- four lowercase transformations;
- one keyword join;
- one additional keyword lowercase;

per entry before scoring.

The scoring loop, matched-term behavior, highlighting and final ordering remain
unchanged.

### 47.9 Settings auto-keyword de-duplication is quadratic per registered control — CONFIRMED / P3

Path:

- \`modules/common/widgets/SettingsSearchRegistry.qml\`.

\`_generateKeywords()\` currently de-duplicates words with:

\`unique.indexOf(word) === -1\`.

For W generated words this is O(W²) worst-shaped membership work.

A local Set can preserve exact output order:

- if unseen, add to Set and append to \`unique\`;
- otherwise skip.

The returned keyword array remains first-occurrence ordered exactly as today.

Registration is much colder than per-keystroke search, so this is P3 and should
normally co-land with §47.8 rather than receive a standalone patch.

### 47.10 Replacing SettingsSearchRegistry's full result sort with a custom top-50 selector is CLOSED under strict-lossless parity

Path:

- \`modules/common/widgets/SettingsSearchRegistry.qml\`.

After scoring, current code sorts every match by:

1. descending score;
2. ascending page index;
3. comparator returns zero when both are equal;

then returns \`slice(0, 50)\`.

A heap/incremental top-50 implementation is attractive when many controls match,
but it must decide which entries survive at the 50-item boundary when score and
page index tie.

As established in §45.5/§46.3, QV4's populated JS Array sort is not stable.
A custom top-K structure would therefore impose a deterministic tie rule that
the current algorithm does not promise.

Status:

- **CLOSED** as an absolute-lossless standalone optimization;
- §47.8's prepared immutable search strings and §47.9's registration Set remain
  safe and independent.

### 47.11 Sharing BarTaskbar's output-independent model derivation is plausible, but publication timing keeps it HIGH CONFIDENCE rather than confirmed

Paths:

- \`modules/bar/BarTaskbar.qml\`;
- \`modules/bar/BarContent.qml\`;
- \`modules/verticalBar/VerticalBarContent.qml\`.

Horizontal/vertical BarTaskbar instances are output-local UI objects, but
\`_doRebuildDockItems()\` itself does not use:

- screen/output identity;
- bar position;
- orientation;
- local width/height;
- preview state.

Its model inputs are global:

- compositor/toplevel state;
- pinned/ignored config;
- app-identity rules;
- focused app.

Only \`visibleDockItems\` is genuinely local because it depends on the granted
horizontal width; vertical presentation also owns its local scrolling/height.

Thus multiple live BarTaskbar instances can repeat the same global model
derivation before doing local presentation.

A strict architecture should **not** simply replace every instance timer with a
new singleton publication, because current instances each use their own 80 ms
debounce and \`_dockItemsEqual()\` publication guard. Centralizing publication
can alter initial-load/event timing.

Safer research direction:

- preserve each instance's existing timer and local \`dockItems\` publication;
- share only a pure/prepared global derivation snapshot, or use an exact-input
  memo that the local timer queries;
- leave overflow trimming, preview state and rendering local.

This is most useful on multi-output setups and only when the Bar taskbar module
is enabled. The shipped default is \`bar.modules.taskbar = false\`.

Promote only after a multi-output fixture proves:

- identical first-load timing;
- identical focus/pin/config update timing;
- identical local overflow behavior;
- no stale model on reveal/hotplug.

### 47.12 Hidden BarTaskbar sorting demand remains a parity experiment, not a confirmed optimization

Paths:

- \`modules/bar/BarTaskbar.qml\`;
- Bar host visibility/auto-hide paths;
- \`services/CompositorService.qml\`.

Current BarTaskbar acquires one sorting-consumer lease on construction and holds
it until destruction.

Historical commits:

- \`3100fe6f57c35a233775b7b5efed0f49421378f4\`
  added \`presentationActive\` model gating;
- \`ff2bf88d3284200cb5524daea3a0cdadb2110af2\`
  released sorting demand while hidden;
- both were later removed by the broad
  \`5835279535d286bc14be551a2a5aae43c09b51e1\`
  post-Rust-baseline restore.

That broad restore is not evidence that the optimization itself was wrong, but
the current source no longer has a presentation-lifetime contract that can be
reapplied mechanically.

A lossless design must preserve first-reveal freshness through Bar auto-hide,
fullscreen/minimal transitions and animation tails.

Keep this **NEEDS PARITY / P2 conditional**:

- taskbar is disabled by default;
- if reintroduced, use synchronous/current-state refresh before reveal and keep
  sorting demand through any visible transition tail;
- prove no stale first frame before releasing hidden demand.

Do not resurrect the historical patch verbatim.

### 47.13 \`filterCurrentWorkspace()\` matching optimization has no checked-in runtime consumer today — CLOSED as a current performance target

Paths:

- \`services/NiriService.qml\`;
- \`services/CompositorService.qml\`.

The function contains another copy of the Niri-window/foreign-toplevel matching
loop plus a temporary \`windows.filter(...workspace...)\`.

The same app-ID bucketing from §46.2 would be valid if this API became hot.

However repository search found no checked-in runtime caller of:

- \`NiriService.filterCurrentWorkspace(...)\`;
- \`CompositorService.filterCurrentWorkspace(...)\`.

The methods remain exported service API, so removing them is not justified, but
optimizing their internal loops produces no demonstrated current shell saving.

Status:

- **CLOSED** as a present runtime optimization target;
- if a future caller appears, reuse the tested matching primitive from §46.2
  rather than maintaining a third independent matcher.

### 47.14 Round-33 regression / priority update

**New correctness prerequisites:**

1. initialize Bar/Dock ignore-regex caches correctly on the default empty user
   list (§47.1);
2. make invalid user regexes degrade safely instead of aborting ii model rebuilds
   (§47.2).

These join, but do not outrank, the capture-helper correctness prerequisites in
§44.1 and §45.6.

**Confirmed lossless local reductions:**

3. Bar pinned-order first-index Map (§47.3);
4. one Map lookup per accepted ii running toplevel (§47.4);
5. Bar horizontal-overflow pass/allocation removal (§47.5);
6. elementwise Bar/Dock regex-cache comparison after correct initialization
   (§47.6);
7. Dock tray-association local loop preparation (§47.7);
8. prepared immutable Settings-search fields (§47.8);
9. Set-backed Settings auto-keyword uniqueness (§47.9).

**High confidence / parity first:**

10. shared output-independent BarTaskbar model derivation (§47.11);
11. hidden BarTaskbar sorting-demand release (§47.12);
12. shared/demand-gated normalized tray snapshot beyond §47.7.

**Closed under current strict-lossless/runtime scope:**

13. custom Settings top-50 selection that invents a tie contract (§47.10);
14. optimizing currently unused \`filterCurrentWorkspace()\` matching (§47.13).

Round-32 Niri/Hyprland sorter findings remain valid after the concurrent Abyss
retirement.

No runtime/source implementation is authorized by this handoff.

---

## 48. Round 34 — Settings static-search work, action search, app-list derivation and AI catalog collections (2026-09-30)

### Snapshot / scope

Round 34 started its source audit on:

`d24482584e1ec69cd83b94738d3b08661d936793`
— `docs(perf): audit taskbar caches and settings search`.

The exact-parent guard caught one concurrent commit before any Round-34 commit
was created:

`df76b95905c82b0fcfb924affff5d6bd480c58ad`
— `feat(abyss): restore independent semantic vacancy borrowing`.

That commit changes only Abyss runtime/geometry plus its focused regression
test. It does not touch Settings/search, GlobalActions, Notifications, All Apps,
AI catalog paths or this handoff. The Round-34 source conclusions were therefore
reconciled unchanged, and the docs tree was rebuilt on exact parent
`df76b959...`.
This round intentionally does **not** repeat:

- notification grouping/index findings from §37.1-§37.2;
- dynamic control search preparation from §47.8-§47.9;
- AppSearch fuzzy-query work already covered in §40;
- taskbar work from §47.

The new focus is the still-independent static Settings index, search-loop local
work, GlobalActions, All Apps derivation and AI catalog collection passes.

External contract checks used only where repository source depends on
Quickshell semantics:

- Quickshell \`DesktopEntries.applications\` is documented as containing
  Application entries that are not Hidden or NoDisplay;
- Quickshell \`Notification.appName\`, \`summary\` and \`body\` are documented
  readonly;
- QML property bindings are reactive and re-evaluate when dependencies change.

Those checks support classification below; no runtime/source implementation is
performed in this round.

### 48.1 SettingsPageRegistry rebuilds/reroutes a 213-entry static index for every search recomputation — CONFIRMED / P1

Paths:

- \`modules/settings/SettingsPageRegistry.qml\`;
- \`modules/settings/SettingsPageRegistryData.qml\`;
- \`settings.qml\`;
- \`modules/settings/SettingsOverlay.qml\`;
- \`modules/settings/SettingsFocus.qml\`.

The current generated static Settings index contains **213 entries**.

Every call to \`SettingsPageRegistry.searchIndex()\` currently:

1. calls \`Data.searchIndex()\`;
2. filters retired feature pages;
3. maps every surviving entry;
4. calls \`FamilyPolicy.settingsRoute(...)\` for each entry;
5. allocates a replacement object for every redirected route.

Repository search found exactly three checked-in callers, all search surfaces:

- \`settings.qml\`;
- \`SettingsOverlay.qml\`;
- \`SettingsFocus.qml\`.

None mutates the returned index entries.

The routing inputs are not query text. They are effectively generation-level
Settings state:

- the Data static index / translation generation;
- \`Config.options?.panelFamily\`;
- \`root.abyssFamily\`;
- retired-page policy.

Therefore the routed index can be a reactive/cached SettingsPageRegistry
property that is rebuilt only when one of those actual inputs changes.

\`searchIndex()\` can remain as the compatibility API and return that current
prepared routed array.

This removes, from every ordinary query recomputation:

- one traversal/filter over ~213 static rows;
- one map traversal over the surviving rows;
- ~213 family-route calls;
- redirected wrapper allocations.

The query-specific scoring loop remains exactly where it is.

Required invalidation cases:

- translation/index regeneration;
- ii -> Waffle -> Abyss family transitions;
- Abyss-family changes;
- retired-page policy remains excluded;
- redirected Bar/Abyss routes keep the exact current page/section/label.

This is separate from §47.8, which prepares dynamically registered live
controls rather than the static section index.

### 48.2 Main Settings and SettingsOverlay rescan the page registry for WaffleConfig on every query even though isPageApplicable already encodes the same family rule — CONFIRMED / P1-P2

Paths:

- \`settings.qml\`;
- \`modules/settings/SettingsOverlay.qml\`;
- \`modules/settings/SettingsPageRegistry.qml\`;
- \`modules/settings/SettingsPageRegistryData.qml\`.

Both main Settings and the overlay define a local
\`getWaffleSettingsPageIndex()\` that linearly scans their page list looking for:

\`modules/settings/WaffleConfig.qml\`.

The generated page list places that page at zero-based index **11**.

But \`SettingsPageRegistry.isPageApplicable(index)\` already has the canonical
family policy:

- classic/ii excludes page 11;
- Waffle allows page 11 and excludes the classic-only pages;
- Abyss excludes page 11 and its own incompatible page set.

Both search implementations already call \`isPageApplicable()\` before their
extra Waffle-page test.

Therefore the later logic:

- scanning all pages to rediscover the Waffle index;
- computing \`isWaffleActive\`;
- rejecting \`entry.pageIndex === wafflePageIndex\` again;
- filtering dynamic widget results by the same Waffle page again;

is redundant under the current canonical applicability contract.

Strict-safe direction:

- keep \`SettingsPageRegistry.isPageApplicable()\` as the single family gate;
- remove the local Waffle page scan and duplicate Waffle-only exclusions from
  these two search implementations;
- do not hard-code page 11 into the callers.

This removes one page-list scan per query plus duplicate family checks/filtering,
and reduces the chance that search policy drifts from navigation policy later.

Regression matrix:

- classic: WaffleConfig absent;
- Waffle: WaffleConfig searchable;
- Abyss: WaffleConfig absent;
- Easy Mode still applies its existing \`essential\` filter after family
  applicability;
- dynamic widget results obey the same family policy.

### 48.3 Static Settings scorers repeat identical indexOf work for the same field/term — CONFIRMED / P1-P2

Paths:

- \`settings.qml\`;
- \`modules/settings/SettingsOverlay.qml\`;
- \`modules/settings/SettingsFocus.qml\`;
- \`modules/waffle/settings/WSettingsContent.qml\`.

This is independent of §48.1.

For one term, main Settings and the overlay currently use repeated expressions
such as:

- \`label.indexOf(term)\` in the match predicate;
- \`label.indexOf(term)\` again for prefix score;
- \`label.indexOf(term)\` again for contains score;
- \`kw.indexOf(term)\` in match/scoring paths;
- \`section.indexOf(term)\` in match/scoring paths.

Waffle repeats the same shape across its **192-entry** static index.

\`SettingsFocus\` builds one haystack but still recomputes the label index for
its label-specific bonus.

Exact-safe local direction:

- compute each field's index at most once per term;
- preserve the existing short-circuit shape so fields not needed for matching
  are not eagerly searched;
- reuse the cached integer for score decisions.

For main Settings/overlay, an efficient exact order is:

1. compute label/keyword/section indices because scoring needs them even after a
   match;
2. only if all three miss, probe description/page as needed to establish
   whether the term matches at all;
3. apply the unchanged score constants using the saved indices.

This reduces repeated string scans without storing any persistent normalized
cache.

Do **not** combine fields into one permanent haystack in the lossless patch;
field-specific prefix/position scores must remain exact.

### 48.4 Persistent lowercase copies for every static Settings row are a CPU-memory tradeoff, so keep them out of the strict no-tradeoff set

Paths:

- same static Settings search surfaces as §48.3.

It is mechanically possible to pre-store lowercase label/description/page/
section/keywords for all 213 ii rows and all 192 Waffle rows.

That would remove per-query lowercase/join work, similar to the already
documented dynamic-control preparation in §47.8.

However it also deliberately retains duplicate normalized strings for the
lifetime of the Settings surface/registry.

Qt's own performance guidance explicitly treats this class of caching as a
memory-vs-processing tradeoff.

Status for this round:

- **NEEDS BENCHMARK / excluded from the strict no-tradeoff implementation set**;
- §48.1 cached routing and §48.3 one-query local index reuse do not require that
  persistent string cache.

This distinction keeps the handoff aligned with the owner's requirement to
prefer optimizations that do not buy CPU by simply retaining more resident
data.

### 48.5 GlobalActions fuzzyQuery repeats query tokenization per action and allocates score records for guaranteed misses — CONFIRMED / P1-P2 during action search

Path:

- \`services/GlobalActions.qml\`.

The file currently contains **59 literal built-in action IDs**, plus optional
user-script actions.

For every nonempty query, \`fuzzyQuery()\` currently:

1. \`map()\`s every action;
2. lowercases action fields;
3. inside that per-action callback executes
   \`q.split(/\\s+/)\`;
4. for multiword queries allocates
   \`words.filter(...)\`;
5. returns \`{ action, score }\` even when score is zero;
6. filters zero-score records afterward;
7. sorts matches;
8. maps sorted records back to actions.

The query word list is invariant across all actions.

Strict-safe no-persistent-cache direction:

- split \`q\` once before the action loop;
- use one ordinary loop over \`allActions\`;
- keep the exact current field normalization and scoring;
- for multiword scoring, count matching words with a loop rather than
  allocating \`words.filter(...)\`;
- append a \`{action, score}\` record only when \`score > 0\`;
- keep the exact current score sort;
- return actions in that sorted order.

For A actions and W query words this removes:

- **A -> 1** query-token array constructions;
- up to A temporary word-filter arrays;
- score-record allocation for every zero-score action;
- the full post-map zero-score filter pass.

No persistent normalized-action cache is required.

A persistent lowercase action index is possible, but like §48.4 it retains
duplicate strings and should remain benchmark/tradeoff-gated rather than being
bundled into this lossless local reduction.

### 48.6 Waffle All Apps maintains a full flattened app array only to launch its first element — CONFIRMED / P2

Path:

- \`modules/waffle/startMenu/AllAppsContent.qml\`.

\`groupedApps\` already contains every filtered/sorted app in exact display
order, partitioned by first letter.

A second bound property \`flatApps\` then traverses every group and every app to
reconstruct the same global order.

Repository search found only one consumer of \`flatApps\`:

\`activateFirst()\`.

That function uses only:

\`flatApps[0]\`.

The exact same first app is:

\`groupedApps[0]?.apps[0]\`.

Therefore \`flatApps\` can be removed entirely and \`activateFirst()\` can read
the first app of the first group directly.

This removes one complete app-reference flatten traversal and one persistent
derived array every time \`groupedApps\` changes, while preserving:

- first-result activation;
- display grouping;
- search filtering;
- sort order;
- letter navigation.

No new cache or data structure is introduced.

### 48.7 Reusing one pre-sorted Waffle All Apps list across queries is NOT yet a strict-lossless substitution — CLOSED / parity reason

Path:

- \`modules/waffle/startMenu/AllAppsContent.qml\`.

The current algorithm:

1. filters the current DesktopEntries sequence for the current query;
2. sorts that filtered subset by \`entry.name.localeCompare(...)\`;
3. groups the resulting order.

It is tempting to sort the full app list once and only filter it for each query.

For names where \`localeCompare()\` returns zero, however, this changes which
array length/content is presented to QV4's sort implementation.

Earlier rounds already established that the current QV4 populated-array sort
must not be assumed stable for strict parity.

Status:

- **CLOSED** as an unconditional lossless sort removal;
- keep the current subset sort unless a deterministic tie contract is
  intentionally introduced as product behavior.

The upstream Quickshell contract does confirm that
\`DesktopEntries.applications\` already excludes Hidden/NoDisplay entries, so
the local \`!entry.noDisplay\` predicate is semantically redundant under the
supported upstream API. Removing the entire filter pass still also relies on
the ObjectModel-values non-null contract and changes array identity, so keep
that separate from the confirmed §48.6 reduction.

### 48.8 OverviewAllAppsGrid computes both presentation-mode derivations from every app-list update — CONFIRMED / P2

Path:

- \`modules/overview/OverviewAllAppsGrid.qml\`.

The component has two independent reactive derived properties:

- \`groupedApps\` for minimal/alphabetical mode;
- \`categorizedApps\` for folder/category mode.

Both depend on the same \`appList\`.

Only one is consumed for presentation at a time:

- the minimal Repeater reads \`groupedApps\` only when mode is not \`folder\`;
- the folder Repeater reads \`categorizedApps\` only when mode is \`folder\`;
- the empty-state check also selects only the active one.

Strict-safe direction:

- make each derivation return an empty/inert result immediately when its mode is
  inactive;
- include \`mode\` as a dependency so switching modes synchronously computes the
  newly active derivation;
- keep the current grouping/category algorithms and model shapes unchanged.

This avoids maintaining the inactive presentation model on app-list changes.

Folder categorization can also be reduced from nested folder/category scans to
a precomputed priority map, but that introduces another retained index. Keep
that below the no-new-cache mode gate unless profiling shows category rebuilds
are material.

### 48.9 Notification history search repeats case normalization, but caching it is a deliberate resident-memory tradeoff — NEEDS BENCHMARK / excluded from strict set

Paths:

- \`services/Notifications.qml\`;
- \`modules/common/widgets/NotificationListView.qml\`;
- \`modules/waffle/notificationCenter/NotificationPaneContent.qml\`.

\`Notifications.appNamesMatching(query)\` is used by both ii/common and Waffle
history search.

For each nonempty query it currently lowercases:

- every candidate app-name key;
- notification summary;
- notification body;

until a group matches.

Quickshell documents incoming \`Notification.appName\`, \`summary\` and \`body\`
as readonly. Persisted historical notification wrappers are also created from
static saved values in Hadalis.

Therefore cached lowercase search fields are correctness-plausible.

But retaining lowercase copies of potentially long notification bodies is a
direct resident-memory-for-CPU exchange.

Status:

- **NEEDS BENCHMARK / excluded from the strict no-tradeoff set**;
- do not add body/summary lowercase copies merely because the search loop is
  easy to optimize;
- if history-search profiling later proves material, measure notification
  history size and retained-string cost first.

This does not affect §37.1-§37.2 notification grouping/count indexes, which
remain confirmed and independent.

### 48.10 Notification persistence serialization has a safe local pass reduction — CONFIRMED / P3

Path:

- \`services/Notifications.qml\`.

\`stringifyList(list)\` currently executes:

\`list.map(notifToJSON).filter(x => x !== null)\`

before \`JSON.stringify()\`.

A single loop can:

- skip null notification objects;
- call \`notifToJSON()\` once for each surviving object;
- append non-null JSON records in the same source order;
- stringify the resulting record array exactly as today.

This changes the pre-stringify collection work from two list traversals plus a
mapped intermediate array to one traversal.

The file write and JSON serialization still dominate, so this is P3.

The same shape exists during lazy history load:

- map saved rows to created notification objects;
- filter failed/null creations;
- then traverse the resulting list again to find \`maxId\`.

Creation and \`maxId\` tracking can be fused into one loop while preserving
saved-row order and null-create handling.

Do not debounce/coalesce notification file writes under the strict-lossless
scope: that changes persistence/durability timing and is a separate tradeoff.

### 48.11 AiProviderCatalog repeatedly recopies the merged prefix while combining provider catalogs — CONFIRMED / P2

Path:

- \`services/ai/AiProviderCatalog.qml\`.

\`_publishModels()\` currently does:

\`merged = merged.concat(providerModels)\`

once per provider key.

\`concat()\` creates a new array, so each iteration recopies the already merged
prefix before adding the next provider's models.

The current preset catalog contains 11 providers; the number of live model rows
can be much larger than provider count.

Exact-safe direction:

- keep one \`merged=[]\`;
- for each provider key in the exact current \`Object.keys()\` order, append that
  provider's model references with a normal inner loop;
- keep the current final comparator/sort unchanged.

This preserves:

- provider enumeration order before sort;
- model reference identity;
- the exact final sort input sequence;
- the exact final sort itself.

It removes all intermediate concatenated arrays and repeated prefix copying.

Do not use one giant \`push(...providerModels)\` as the required implementation;
an ordinary inner loop avoids JavaScript argument-count limits for unexpectedly
large catalogs.

### 48.12 Ai._syncExtraModels creates two full temporary arrays before the Set it actually needs — CONFIRMED / P2

Path:

- \`services/Ai.qml\`.

Current code computes live provider membership as:

\`[...new Set(models.map(model => model.providerId).filter(id => id && id.length > 0))].sort()\`.

A single loop can populate the same Set directly from
\`AiProviderCatalog.models\`, then materialize/sort the unique IDs once.

Preserved semantics:

- empty IDs excluded;
- duplicate provider IDs collapsed;
- final lexical sort unchanged;
- the JSON signature remains byte-equivalent for the same provider set.

Removed work:

- one full \`map\` result array;
- one full \`filter\` result array;
- their callback/allocation churn.

This path can run on broad config saves as well as catalog membership changes,
so the reduction is more useful than a one-time initialization micro.

### 48.13 Ai._syncCatalogModels can use invocation-local provider/loaded-ID indexes without retaining new cache state — CONFIRMED / P2

Path:

- \`services/Ai.qml\`;
- \`modules/common/AiProviderPresets.qml\`;
- \`services/ai/AiProviderCatalog.qml\`.

For every live catalog model, \`_syncCatalogModels()\` currently calls:

\`AiProviderCatalog.providerById(entry.providerId)\`.

That function linearly scans the provider preset list with \`.find()\`.

The same model loop also tests:

\`root._loadedCatalogModelIds.includes(id)\`

when a model ID already exists.

The loaded-ID array grows during the same invocation.

No persistent cache is needed to remove these scans.

Exact-safe invocation-local direction:

1. build one \`providerId -> provider\` Map from the current provider list before
   the model loop;
2. build one local Set tracking IDs appended to
   \`_loadedCatalogModelIds\` during this invocation;
3. use the Map for provider lookup;
4. use the Set for the existing “already loaded by this catalog sync” test;
5. continue publishing the existing \`_loadedCatalogModelIds\` array in the same
   order for cleanup/compatibility.

For P providers and M catalog models, provider lookup changes from roughly:

\`M x P -> P + M\`.

The growing loaded-ID membership check changes from O(M) per relevant collision
to O(1), while preserving the distinction between:

- a pre-existing non-catalog model ID, which must still block replacement;
- an ID already loaded by this same catalog sync, which follows the current
  duplicate handling path.

Required fixture:

- duplicate catalog IDs;
- collision with an existing non-catalog/custom model;
- multiple providers;
- policy-2 local-only filtering;
- exact \`_loadedCatalogModelIds\` order unchanged.

### 48.14 Round-34 priority update

**Confirmed no-persistent-cache / no-behavior-tradeoff reductions:**

1. cache/reactively publish the 213-row routed static Settings index instead of
   rerouting it per query (§48.1);
2. remove duplicate Waffle page scans/gates after canonical
   \`isPageApplicable()\` (§48.2);
3. reuse per-term \`indexOf\` results in all static Settings scorers (§48.3);
4. GlobalActions one-tokenization / one-pass score collection (§48.5);
5. remove Waffle All Apps \`flatApps\` derivation (§48.6);
6. gate Overview All Apps derivation to the active presentation mode (§48.8);
7. one-pass notification serialization/history-load collection (§48.10);
8. one-buffer AI catalog merge (§48.11);
9. one-loop live-provider Set construction (§48.12);
10. invocation-local provider/loaded-ID indexes during catalog sync (§48.13).

**Explicitly excluded from the strict no-tradeoff set unless benchmark evidence
justifies retained memory:**

11. persistent lowercase copies for the 213/192 static Settings rows (§48.4);
12. persistent lowercase notification body/summary search copies (§48.9);
13. persistent normalized GlobalActions search strings beyond the local
    §48.5 reduction.

**Closed under strict parity:**

14. pre-sorting the full Waffle All Apps catalog and filtering that order instead
    of sorting each filtered subset (§48.7).

The Round-31 capture-helper correctness prerequisites (§44.1 / §45.6) and
Round-33 Bar/Dock regex correctness prerequisites (§47.1 / §47.2) remain above
all pure performance work.

No runtime/source implementation is authorized by this handoff.

---

## 49. Round 35 — strict-lossless desktop placement, calendar query specialization and cold-path collection reductions (2026-09-30)

### Snapshot / stricter acceptance rule

Round 35 was audited against exact \`dev\` HEAD:

\`6437275f73b9d611c442c1a0db3fa151271ebaea\`
— \`docs(perf): audit search and catalog collection costs\`.

No concurrent commit landed between the Round-35 opening refetch and the
pre-write refetch.

The owner explicitly re-stated that optimization must be **lossless**. For this
round, a candidate is marked CONFIRMED only when source-level equivalence can
preserve all of the following relevant contracts:

- returned values and ordering;
- duplicate/tie behavior;
- visible UI/UX;
- mutation and persistence timing;
- process/IPC side effects;
- QML reactive dependencies/change-signal behavior where those signals have
  consumers;
- failure/fallback semantics.

Consequences:

- no debounce/batching is promoted merely because it is faster;
- no persistent cache is promoted merely because it saves CPU;
- no sort replacement is promoted if tie behavior is not exact;
- no shared reactive model is promoted if it can broaden change signals;
- local ephemeral Set/Map use is allowed where membership semantics are exact
  and no state survives the invocation/binding evaluation.

Qt/QML supports the standard JavaScript \`Set\`/ \`Map\` built-ins. The ID/key
cases below are strings, so replacing repeated \`Array.includes/indexOf\`
membership with a local Set preserves equality semantics while retaining output
order through the original result array.

### 49.1 DesktopItems arrangePosition materializes/copies unrelated desktop items before occupancy checks — CONFIRMED / P1-P2 during drag/drop/reconcile

Paths:

- \`services/DesktopItems.qml\`;
- \`modules/background/desktopItems/DesktopItemDelegate.qml\`;
- \`modules/background/desktopItems/DesktopDropCoordinator.qml\`;
- \`docs/DESKTOP_ITEMS.md\`.

The documented placement contract is:

- snap to the desktop-widget edit grid;
- choose the nearest free cell;
- skip occupied cells so icons do not overlap.

Current \`arrangePosition()\` builds \`occupied\` as:

1. \`listForOutput(output)\`;
2. \`listForOutput()\` first calls \`listItems()\`;
3. \`listItems()\` enumerates **every** desktop item and creates a shallow copy
   with its ID;
4. \`listForOutput()\` filters those copies by output;
5. \`arrangePosition()\` filters that output list again to exclude the moving
   item.

The occupancy loop only reads:

- item ID for exclusion;
- item output;
- item x/y.

No consumer outside \`DesktopItems.qml\` currently calls \`listForOutput()\`, so
its compatibility API can remain unchanged while \`arrangePosition()\` takes a
strictly local direct path.

Exact-safe direction:

- enumerate \`Object.keys(root.items)\` once;
- skip \`excludeItemId\` by key before any copy;
- read the original record;
- append only same-output records to the local \`occupied\` list, or perform the
  same overlap checks directly against those records;
- do not mutate any record.

Because JavaScript execution here is synchronous, using the original record for
read-only x/y checks cannot observe an intervening DesktopItems mutation that
the shallow-copy version could have isolated.

Preserved behavior:

- other-output items remain ignored;
- excluded moving item remains ignored;
- same-output occupancy rectangle math is unchanged;
- \`listItems()\` / \`listForOutput()\` public behavior remains unchanged;
- nearest-cell ordering is untouched.

Removed work for I total items and O same-output occupied items:

- I shallow item-copy allocations;
- one full filter pass over I copied records;
- one second filter pass over O records.

The remaining occupancy list can contain references rather than copies.

### 49.2 DesktopItems has an exact zero-distance fast path before allocating/sorting the whole candidate grid — CONFIRMED / P1 common drag/drop case

Path:

- \`services/DesktopItems.qml\`.

Current snapped placement always:

1. enumerates every grid candidate;
2. allocates \`{x,y,distance}\` for every candidate;
3. sorts the full candidate array by:
   - squared distance;
   - then y;
   - then x;
4. checks candidates in that order until one is free.

But when both \`anchorX\` and \`anchorY\` are actual grid coordinates generated
by the existing loops, the anchor is the unique candidate with squared distance
zero.

Therefore, if that anchor cell is free, the current algorithm must return it
first.

Strict-safe fast path:

1. build occupancy exactly as today / §49.1;
2. verify the clamped anchor is actually representable by the candidate loops:
   - \`anchorX % pitchX === 0\`;
   - \`anchorY % pitchY === 0\`;
3. if representable and \`isFree(anchorX, anchorY)\`, return it immediately;
4. otherwise run the existing candidate generation, comparator, sort and scan
   unchanged.

The representability guard matters because clamping can produce \`maxX/maxY\`
values that are not pitch multiples; such a clamped anchor is not necessarily
present in the current candidate list.

For the common free snapped cell, this changes:

- G candidate-object allocations -> 0;
- one G-element sort -> 0;
- one occupancy check remains.

Do **not** replace the occupied-anchor fallback with an unsorted full-grid
minimum scan as part of this patch. Although value-equivalent algorithms exist,
their cost shape differs and the existing explicit distance/y/x comparator is
already a clear product contract.

### 49.3 Calendar month cells allocate full event arrays for count/presence-only questions — CONFIRMED / P1 while calendar is visible

Paths:

- \`services/Events.qml\`;
- \`services/CalendarSync.qml\`;
- \`modules/sidebarRight/calendar/CalendarWidget.qml\`;
- \`modules/waffle/notificationCenter/CalendarWidget.qml\`.

Both calendar presentations repeatedly ask count/presence questions per visible
day cell.

Current count path:

- \`Events.getEventsForDate(date).length\`;
- \`CalendarSync.getEventsForDate(date).length\`.

Current local-dot presence path additionally does:

- \`Events.getEventsForDate(date)\`;
- test \`.length > 0\`.

Each service function currently filters its complete event list and allocates an
array of matching event references even when the caller needs only an integer or
boolean.

Exact-safe specialization:

- add \`Events.countEventsForDate(date)\` using the exact existing local-event
  predicate;
- add \`Events.hasEventsForDate(date)\` using the exact same predicate and stop
  at the first match;
- add \`CalendarSync.countEventsForDate(date)\` using the exact current external
  predicate;
- retain both existing \`getEventsForDate()\` functions for callers that
  genuinely need ordered event objects.

Important parity rules that must be copied verbatim, not reinterpreted:

Local Events:

- date source remains \`event.startDate || event.dateTime\`;
- notified timed events remain excluded;
- notified all-day events remain visible for their day.

CalendarSync:

- all-day start/end normalization remains local-midnight based;
- RFC 5545 all-day \`DTEND\` remains exclusive;
- missing/non-forward end keeps the current single-day fallback;
- timed events retain the current local-date comparison.

For N local events and E external events, each count-only day cell still visits
the same records but allocates **zero match arrays**.

For local color presence, \`hasEventsForDate()\` can stop at the first matching
event instead of filtering all N records.

This is deliberately narrower than a persistent date-index cache: no additional
resident event index is introduced.

### 49.4 CalendarSync source-color query can scan matching events directly instead of filter-then-scan — CONFIRMED / P1-P2

Path:

- \`services/CalendarSync.qml\`.

\`getSourceColorsForDate(date)\` currently:

1. calls \`getEventsForDate(date)\`, which scans all external events and
   allocates a matching-event array;
2. scans that array again;
3. uses a local Set to deduplicate \`sourceId\`;
4. appends \`sourceColor\` in first-matching-event order.

Exact-safe direction:

- factor the current “event occurs on target day” predicate into a private
  helper, or reproduce it byte-for-byte in the source-color loop;
- scan \`root.events\` once;
- skip nonmatching events;
- retain the existing local \`seen\` Set;
- append the first color for each source ID in the same root.events order.

Result ordering is identical because Array.filter preserves source order and the
second current loop consumes that filtered order unchanged.

Removed work:

- the temporary day-events array;
- the second traversal over the matching subset.

The same private predicate can be shared by §49.3 count/list/color functions,
but it must not change date parsing or all-day semantics.

### 49.5 Notepad tab-ID normalization has quadratic duplicate membership with an exact Set replacement — CONFIRMED / P2 cold load/migration

Path:

- \`services/Notepad.qml\`.

\`_normalizeTabs()\` currently keeps:

\`const seenIds = []\`

and uses \`seenIds.includes(id)\`:

- once for each loaded valid tab;
- repeatedly inside the generated-ID collision loop.

For T valid tabs, duplicate membership is O(T²) worst-shaped.

All IDs are normalized to strings before membership checks.

Strict-safe direction:

- replace only the membership structure with a local \`Set\`;
- preserve the separate \`normalized\` output array;
- on first occurrence:
  - \`seenIds.add(id)\`;
  - append the normalized tab;
- for missing/duplicate IDs:
  - keep calling the existing \`_allocateTabId()\`;
  - repeat while \`seenIds.has(id)\`;
  - then add/append.

Preserved behavior:

- invalid records are skipped in the same order;
- first duplicate occurrence keeps its original ID;
- later duplicates receive generated IDs;
- generated-ID collision retry remains;
- normalized tab order is unchanged;
- \`_normalizedTabsNeedSave\` behavior is unchanged.

This is the same lossless membership pattern already accepted for other ordered
recovery paths, but applied to a previously unaudited service.

### 49.6 FirstRunExperience can select the exact same wallpaper while streaming discovery instead of storing/copying/sorting all candidates — CONFIRMED / P3 cold first-run

Path:

- \`services/FirstRunExperience.qml\`.

Current wallpaper discovery:

- \`find\` emits image paths from one wallpaper directory with \`-maxdepth 1\`;
- every path is stored in \`_candidates\`;
- completion clones the full array;
- default \`.sort()\` lexicographically sorts it;
- it prefers the first path ending in \`/qs-niri.jpg\`;
- otherwise it takes the lexicographically first path.

Because discovery is limited to one directory, there can be only one filesystem
entry with the exact basename \`qs-niri.jpg\`.

The same selection can be computed while stdout is read:

- \`preferredCandidate\`: remember the \`/qs-niri.jpg\` path if seen;
- \`fallbackCandidate\`: remember the lexicographically smallest nonempty path;
- completion chooses \`preferredCandidate || fallbackCandidate\`.

Default JavaScript string sort and relational string comparison both use
lexicographic UTF-16 code-unit ordering, so the fallback value is identical.
Duplicate identical lines, if ever emitted, also cannot change the selected
string value.

This removes:

- retention of all W candidate strings;
- one W-element array copy;
- O(W log W) default sort work.

Failure/start behavior must remain exact:

- reset both streaming candidates when the Process actually starts;
- if Process start fails, completion still proceeds with no wallpaper and the
  current welcome fallback;
- do not change marker/welcome sequencing.

### 49.7 Layout editors repeatedly concat zone arrays and use linear placed-membership for every available ID — CONFIRMED / P2-P3 edit-mode

Paths:

- \`modules/common/widgets/BarModuleOrderEditor.qml\`;
- \`modules/dashboard/DashLayoutEditor.qml\`.

Both editors have the same local pattern.

Placed IDs:

- start with \`[]\`;
- repeatedly execute \`s = s.concat(zone)\` for each zone.

Availability:

- filter all known IDs;
- call \`placed.indexOf(id)\` for each candidate.

Strict-safe local direction:

1. build \`placed\` once with nested loops / \`push\`, preserving zone order and
   duplicate entries exactly;
2. build an invocation-local \`Set(placed)\`;
3. filter known IDs with \`placedSet.has(id)\`.

Bar-specific contract:

- \`spacer\` remains reusable and must bypass placed membership exactly as now.

Dashboard-specific contract:

- output \`availableIds\` remains in \`allIds\` order.

No persistent index is introduced.

For Z zones containing P total placed IDs and A known IDs:

- repeated concat prefix copying is removed;
- availability membership changes from O(A x P) to O(P + A).

The current lists are modest, so this is not a top runtime priority, but it is
fully lossless and useful while edit mode is active.

### 49.8 AndroidQuickPanel duplicate/availability checks can use invocation-local Sets without changing toggle order — CONFIRMED / P3

Path:

- \`modules/sidebarRight/quickToggles/AndroidQuickPanel.qml\`.

Two derived paths repeat linear membership:

\`unusedToggles\`:

- for every one of 19 available toggle types, calls
  \`toggles.some(...type...)\`.

\`toggleRowsForList()\`:

- calls \`availableToggleTypes.indexOf(type)\`;
- calls growing \`seenTypes.indexOf(type)\`;
- appends first valid occurrence only.

Exact-safe direction:

- build a local Set of configured toggle types for \`unusedToggles\`;
- build a local Set of the 19 valid types plus a local \`seenTypes\` Set in
  \`toggleRowsForList()\`;
- keep the original arrays/row construction for output ordering.

Preserved behavior:

- first configured duplicate wins;
- invalid toggle types remain skipped;
- row packing and clamped size are unchanged;
- unused toggles remain in \`availableToggleTypes\` order.

These Sets exist only during the binding/function evaluation.

### 49.9 Waffle font search performs featured-font membership work even when search mode never consumes it — CONFIRMED with dependency-preservation rule / P2 per keystroke

Path:

- \`modules/waffle/settings/WSettingsFontSelector.qml\`.

The ListView model currently does, in this order:

1. lowercase search text;
2. call \`Qt.fontFamilies()\`;
3. compute \`featured = root.featuredFonts.filter(f => allFonts.indexOf(f) !== -1)\`;
4. if search is nonempty, ignore \`featured\` and filter all fonts by search;
5. only the empty-search branch uses \`featured\` to put preferred fonts first.

Therefore every typed search recomputation performs up to five full
\`allFonts.indexOf()\` scans that cannot affect the search result.

Strict-lossless direction:

- keep a local reference/read of \`root.featuredFonts\` before the branch so the
  QML binding retains the same featured-font dependency;
- when search is nonempty, perform only the existing all-font search filter;
- compute \`featured\` only in the empty-search branch.

The explicit dependency preservation matters because \`featuredFonts\` is an
assignable component property and at least one caller binds it to Waffle theme
font state.

Do not cache \`Qt.fontFamilies()\` across queries under the strict-lossless
scope: the current implementation asks Qt for a fresh family list on every model
recomputation, and there is no equivalent invalidation contract in this
component.

### 49.10 GlobalStates screen-disconnect cleanup can avoid repeated connected-array membership with an invocation-local Set — CONFIRMED / P3 rare topology change

Path:

- \`GlobalStates.qml\`.

On every \`Quickshell.screensChanged\`, current code:

- maps all screens to a temporary connected-name array;
- uses \`connected.includes(...)\` for notification-center hover ownership;
- repeats \`connected.includes(...)\` for every Bar popup hover lease;
- allocates \`Object.keys(nextLeases)\` and \`Object.keys(oldLeases)\` only to
  determine whether an own lease was removed.

Safe partial reduction:

- build one invocation-local Set of connected screen-name strings while
  retaining any array only if another consumer actually needs ordered names;
- use \`Set.has\` for hover/lease membership;
- keep the existing \`for...in\` lease traversal and current assignment timing.

For the final “did own-lease count change?” test, be conservative:

- either retain the current \`Object.keys\` comparison;
- or replace it only with own-property counters that exactly mirror
  \`Object.keys\` semantics.

Do **not** use a generic “saw a rejected for-in property” boolean: inherited
enumerable properties would make that subtly different from the current
\`Object.keys\` count contract.

This is P3 because monitor topology changes are rare, but the local Set itself
is lossless.

### 49.11 Naively collapsing Audio's four PipeWire filters into one shared reactive partition is NOT authorized as absolute-lossless — CLOSED pending signal parity

Paths:

- \`services/Audio.qml\`;
- \`services/MprisController.qml\`.

Current Audio publishes four independent reactive list properties:

- output app streams;
- input app streams;
- output devices;
- input devices.

They each filter \`Pipewire.nodes.values\`.

A one-pass shared partition looks attractive, but in QML changing the
intermediate dependency graph can broaden which final list properties are
re-evaluated/changed.

That matters here because \`MprisController\` has:

\`Connections { target: Audio; function onOutputAppNodesChanged() ... }\`

and that handler can restart the PipeWire metadata refresh debounce, which can
lead to \`pw-dump\` work.

Therefore “same final array contents” is not sufficient proof.

Status:

- **CLOSED as a blind one-shared-partition optimization**;
- a future two-partition or imperative publication design must prove exact
  \`outputAppNodesChanged\` / \`inputAppNodesChanged\` signal parity under:
  - node insert/remove;
  - \`isSink\` changes;
  - \`isStream\` changes;
  - \`audio\` null/non-null changes;
  - unrelated input-side changes;
- no implementation should land solely on the basis of fewer filter passes.

This is an example of the stricter Round-35 lossless rule: reactive side effects
count as behavior.

### 49.12 Full-grid “scan every cell and keep the best free candidate” is value-equivalent but not automatically a performance win — NEEDS BENCHMARK, not part of the confirmed patch set

Path:

- \`services/DesktopItems.qml\`.

After §49.2, an occupied anchor still falls back to full candidate
materialization/sort.

A tempting alternative is:

- scan every grid coordinate;
- test occupancy immediately;
- keep the best free candidate according to the exact
  \`distance -> y -> x\` comparator.

That can preserve the returned coordinate exactly.

However its cost shape changes:

Current fallback:

- generate/sort all G candidates;
- occupancy-test only until the first free candidate in sorted order.

One-pass best-free scan:

- removes sort/all candidate objects;
- but occupancy-tests **every** grid coordinate.

When the nearest few cells are occupied sparsely, either side can win depending
on G and occupied count.

Status:

- **NEEDS BENCHMARK**, despite value parity;
- §49.2's free-anchor fast path is confirmed independently and should land first.

### 49.13 Round-35 regression requirements

Before implementing the confirmed Round-35 batch, add focused parity coverage.

DesktopItems:

- snapping disabled returns the exact current clamp;
- free grid-representable anchor returns the same anchor;
- clamped non-grid anchor does not take the new fast path;
- occupied anchor retains distance/y/x fallback order;
- moving item exclusion remains exact;
- items on another output never block;
- same-output overlap rectangles remain unchanged.

Calendar:

- timed local notified event excluded from active day count;
- notified all-day local event retained;
- external all-day event with exclusive DTEND spans exactly the same dates;
- missing/equal DTEND remains single-day;
- source-color order follows first matching event order;
- duplicate source IDs emit one color;
- count/list/color predicates agree on the same fixture.

Notepad:

- first duplicate ID wins;
- later duplicate gets generated ID;
- whitespace-trimmed IDs still set save-needed;
- generated-ID collision retries;
- normalized output order unchanged.

First run:

- \`qs-niri.jpg\` always wins;
- without it, lexicographically smallest path wins;
- empty output;
- Process start failure;
- Process success with one/many paths.

Layout/quick toggles:

- duplicate IDs;
- reusable Bar spacer;
- invalid Android toggle types;
- first Android duplicate wins;
- row packing unchanged.

Waffle font search:

- empty search keeps featured-first order;
- nonempty search result order unchanged;
- changing bound \`featuredFonts\` while search is nonempty still causes the
  model binding to retain its prior dependency/re-evaluation contract.

### 49.14 Revised strict-lossless priority

**Confirmed, no persistent cache and no intended observable behavior change:**

1. DesktopItems direct same-output occupancy collection (§49.1);
2. DesktopItems free-anchor zero-distance fast path (§49.2);
3. Events/CalendarSync count/has specializations (§49.3);
4. CalendarSync one-pass source colors (§49.4);
5. Notepad duplicate-ID Set (§49.5);
6. FirstRun streaming preferred/min fallback selection (§49.6);
7. Bar/Dashboard layout-editor local push + Set membership (§49.7);
8. AndroidQuickPanel local membership Sets (§49.8);
9. Waffle font search branch-local featured work **with dependency preservation**
   (§49.9);
10. GlobalStates screen-disconnect local Set (§49.10).

**Not authorized as lossless yet:**

11. one shared Audio PipeWire partition (§49.11);
12. full-grid best-free scan replacing DesktopItems sort (§49.12);
13. persistent calendar date indexes;
14. cached \`Qt.fontFamilies()\`;
15. any debounce/coalescing of event/notepad persistence.

Earlier correctness prerequisites remain above pure performance work:

- capture-helper stale-preview hash / newer-user clipboard races (§44.1,
  §45.6);
- Bar/Dock first-run ignore-regex correctness (§47.1-§47.2).

No runtime/source implementation is authorized by this handoff.


---

## 50. Round 36 — strict-lossless service parsing, planner and invocation-local reductions (2026-09-30)

### Snapshot / concurrent reconciliation

Round 36 opened on `dev` HEAD `b8c2937990ddb9996852cda9716b5816dea6f674`
(`docs(perf): audit strict-lossless local reductions`).

Before this write, `dev` advanced to
`f24e7cbd52f00617a107527b9a321414f8116995`
(`fix(abyss): borrow only across real peer gaps`). That concurrent commit changes
only `modules/abyss/looks/AbyssVacancyBorrowing.js` and
`scripts/test-abyss-vacancy-borrowing.py`; it does not touch this round's
candidate cluster. The handoff and every source path below were re-read at exact
`f24e7cbd52f00617a107527b9a321414f8116995` before this update.

Round-35's strict rule remains in force: CONFIRMED requires identical observable
output/order/identity where relevant, side effects, publication/event timing,
failure/persistence behavior and malformed-input behavior, with no persistent
CPU-for-resident-memory cache.

### 50.1 Network can parse and group one nmcli scan in one pass — CONFIRMED / P1-P2 interactive refresh

Paths:

- `services/Network.qml`;
- current Wi-Fi consumers under sidebarRight, Waffle action center and Abyss.

`getNetworks` currently:

1. trims/splits stdout;
2. maps every line to a network object;
3. filters empty SSIDs;
4. traverses the full `allNetworks` array again to group by SSID;
5. reconciles the selected rows with existing `WifiAccessPoint` QObjects.

The grouping rule is deterministic: first valid SSID fixes Map insertion
position; active replaces inactive; two inactive rows replace only on strictly
stronger signal; an existing active blocks later inactive rows; equal inactive
strength keeps the earlier row.

Exact-safe direction:

- preserve the exact current split and escaped-colon parser;
- parse each line once and reject the same falsy/empty SSIDs immediately;
- apply the same grouping rule directly to `networkMap`;
- only retain a parsed object when that row becomes the selected representative;
- leave `existingByKey`, `nextKeys`, reverse stale-row removal, QObject
  update/create order and destruction timing unchanged.

`Map.set(existingKey, replacement)` does not move an existing key, so
`Array.from(networkMap.values())` preserves current SSID order.

This remains O(L), but removes the full `allNetworks` array, one complete pass,
and allocations for duplicate rows that never win. No nmcli/debounce/rescan/
publication/failure timing changes are authorized here.

Regression parity: empty/malformed output, escaped-colon BSSID, duplicate SSIDs
(active/inactive, stronger/equal signal), exact SSID order and exact QObject
reuse/removal behavior.

### 50.2 Autostart Settings sort can memoize the pure on/off predicate lazily per invocation — CONFIRMED / P1

Paths:

- `services/Autostart.qml`;
- `modules/settings/AutostartConfig.qml`;
- `modules/waffle/settings/pages/WAutostartPage.qml`.

Both Settings pages filter `AppSearch.list`, then sort the survivors. Every
comparator call executes `Autostart.isAppOn(a)` and `isAppOn(b)`.
`isAppOn` can linearly scan managed entries and then external spawn lines, so
the same app may rescan identical state many times during one sort.

Strict-safe direction:

- create an invocation-local `Map` inside `getFilteredApps()`;
- use a **lazy** helper from the comparator: on first encounter of that exact app
  object call `Autostart.isAppOn(app)`, cache the bool, then reuse it;
- keep enabled-first comparison and the existing
  `(name || "").localeCompare(...)` expression unchanged.

The cache must be lazy. For empty/single-result arrays current `sort()` need not
run its comparator, so eager precomputation could broaden QML dependency reads.
For compared apps the current code already reads the same state; memoization only
removes repeated reads in that synchronous invocation.

Use object identity as the key, not desktop ID, so duplicate IDs represented by
distinct objects are not conflated. No state survives evaluation. Approximate
predicate work changes from O(C x (E+X)) comparator scans to at most
O(A x (E+X)) for A surviving apps.

This is independent of §40.7's already-recorded duplicate icon resolution.

### 50.3 Autostart parser can reuse its original line array — CONFIRMED / P2-P3 reload/edit path

Path: `services/Autostart.qml`.

`_applyParsed(content)` already creates `lines = content.split("\n")`, but
then reconstructs `managedText` by slice/join and splits it again, and later
constructs `head + "\n" + tail` and splits again to find external spawn rows.

Exact-safe direction:

- retain the exact first-begin / first-end marker discovery;
- keep constructing `_head` and `_tail` exactly as today for writeback;
- parse managed lines directly from original indices
  `beginIdx + 1 .. endIdx - 1`;
- parse external lines directly before `beginIdx` and after `endIdx`;
- when the marker pair is invalid/absent, parse all original lines as external.

The current synthetic newline between head/tail can only introduce blank rows,
which `_spawnTokens()` ignores, so external row objects/order/raw strings remain
the same. Preserve duplicate/reversed-marker semantics; do not reinterpret
malformed files while optimizing.

Fixtures: no markers, normal/empty section, duplicate markers, end-before-begin,
decorative invalid lines, enabled/commented spawn rows, and byte-equivalent
head/tail writeback. No FileView/write/mkdir/durability timing change.

### 50.4 DisplayModePlan has repeated normalization and avoidable collection chains — CONFIRMED / P2

Paths:

- `services/DisplayModePlan.js`;
- `services/DisplayMode.qml`.

This planner had no previous handoff finding.

`normalizedNames()` currently does
`Array.from(...).map(String...).filter(...)`. Keep `Array.from(names || [])`
so iterable/array-like behavior is unchanged, then stringify/filter/append in one
indexed loop. Critically, retain the current plain-object `seen = {}` semantics;
do not silently alter malformed/prototype-looking key behavior in a performance
patch.

`activeNames()` can keep `Object.keys`, append only logical outputs to one
array, then run the exact same default `.sort()`. No sort replacement is
authorized.

`plan()` normalizes names, then calls `primary()` which normalizes them again,
then calls `orderedActions()` which normalizes names and already-validated
targets again. `restore()` has the same repeated-normalization shape.

Exact-safe architecture:

- keep exported `primary()` and `orderedActions()` arbitrary-input contracts;
- add internal helpers for already-normalized names/validated unique targets;
- use them only from `plan()` / `restore()`;
- construct action objects in two ordered loops: enabled targets first, then
  remaining connected names;
- an invocation-local Set is safe only after names are normalized to strings.

Preserve every error string, enabled-action order, disabled connected-name order,
duplicate/empty normalization and default sort behavior. This removes repeated
passes plus filter/map/concat intermediate arrays without touching process timing.

### 50.5 DisplayMode.normalizeSelections can remove two filtered arrays and repeated membership scans — CONFIRMED / P2

Path: `services/DisplayMode.qml`.

`connectedOutputs` is already a normalized unique string array. Current
`normalizeSelections()` creates `secondaryNames` and `mirrorTargets` via
filters, then repeatedly calls `includes()`.

Exact-safe direction:

- build one invocation-local `Set(names)`;
- validate existing selections with `Set.has`;
- replace `secondaryNames[0]` with
  `names.find(name => name !== primaryOutput)`;
- replace `mirrorTargets[0]` with
  `names.find(name => name !== mirrorSource)`;
- retain explicit source/target exclusions, assignment order and the current
  `stopMirror()` position.

The same local principle may be used in `setMirrorSource()` only while preserving
its first-non-source fallback and assignment sequence. No shared reactive state is
introduced.

### 50.6 PackageSearch installed mode can avoid parse-then-clone — CONFIRMED / P2 interactive removal search

Paths:

- `services/deferred/PackageSearch.qml`;
- `modules/overview/ActionModeView.qml`.

Installed search currently parses to one array, then maps every row through
`Object.assign({}, pkg, { installed: true })`. The first parsed objects are
invocation-local and never published.

Exact-safe direction: give the private parser a defaulted `forceInstalled=false`
mode (or equivalent private helper). Keep one-argument behavior exact; forced
mode creates each result with `installed: true` directly and publishes that
same ordered result array.

Preserve malformed-line handling, indented-description consumption, all fields,
field/property values and normal-search installed-marker behavior.

The installed-marker expression also tests both `/\[installed\]/i` and
`/\[Installed\]/i`; the latter is strictly redundant because the former is
already case-insensitive.

For R installed results, this removes one R-element mapped array and R object
copies. Debounce/request-generation/timeout/publication timing stays untouched.

### 50.7 TrayService pin membership can use local Sets — CONFIRMED / P2 tray/config changes

Path: `services/TrayService.qml`.

Both `itemsInUserList` and `itemsNotInUserList` traverse
`SystemTray.items.values` and call `_pinnedItems.includes(i.id)` for each valid
non-Fcitx item.

Within each binding evaluation, build an invocation-local Set from the same pins
and use `has(i.id)`. Array `includes` and Set membership both use SameValueZero,
so duplicate/non-string pin behavior is preserved. Keep the source traversal,
Fcitx handling, passive filtering and output arrays unchanged.

Membership changes from O(N x P) to O(P + N) per evaluation. Do not turn this
into a retained pin index merely to avoid the second small local Set, and do not
combine the three reactive tray partitions; earlier §37.3 covers separate ii
per-output tray derivation work.

### 50.8 Tray smart activation can normalize problematic-app patterns once per operation — CONFIRMED / P3 click path

Path: `services/TrayService.qml`.

After the same problematic-app record is selected, smart activation/toggle scans
toplevels. Each toplevel appId/title is lowercased, then `matchesApp()`
lowercases those strings again and lowercases every static pattern for each
field/toplevel.

Strict-safe local direction:

- keep public `matchesApp()` unchanged;
- once per smart click, build the selected record's ordered lowercased pattern
  array;
- lowercase each toplevel appId/title once and scan that local pattern array;
- preserve first matching toplevel precedence and all focus/launch fallbacks.

No persistent normalized pattern cache is needed. Pattern normalization falls
from roughly O(W x P) repetitions to O(P) for that operation.

### 50.9 BluetoothStatus count-only binding does not need a filtered device array — CONFIRMED / P2-P3 event-driven

Path: `services/BluetoothStatus.qml`.

Current `activeDeviceCount` is
`devices.values.filter(device => device.connected).length`.

A direct count over the same device sequence returns the same zero for no
adapter, reads the same `connected` values in order and removes the temporary
connected-device array.

Do not merge `firstActiveDevice` and count into one shared reactive snapshot in
this strict patch; changing QML dependencies/change signals needs separate proof.

### 50.10 Updates can count checkupdates lines without split allocation — CONFIRMED / P3

Path: `services/Updates.qml`.

After the same `.trim()`, current nonempty stdout count is
`t.split("\n").length`, exactly `1 + number of "\n" code units`.
An indexed newline count therefore preserves empty, single-line, LF, CRLF and
interior-blank-line behavior while removing the split array. Process/package
manager work dominates, so priority remains P3.

### 50.11 DisplayMode queue cursor is not promoted under strict signal parity — HIGH CONFIDENCE / NEEDS PARITY

Path: `services/DisplayMode.qml`.

`_runNextAction()` currently advances with `_queue = _queue.slice(1)`. A
cursor could preserve command order while removing repeated shrinking arrays,
but each current assignment also emits `_queueChanged`. No runtime consumer was
identified in this cluster, yet QML publication/signal behavior remains
observable until proven otherwise.

Status: **HIGH CONFIDENCE / NEEDS QML SIGNAL PARITY**, not CONFIRMED. Promote only
after proving no `_queueChanged` consumer and identical action/rollback/failure/
completion sequence and timing.

### 50.12 Audited no-go boundaries

This cluster also re-read nearby service code and intentionally did not promote:

- persistent Wi-Fi SSID/index caches;
- changes to Network debounce, nmcli monitor/rescan or process sequence;
- shared Bluetooth first/count reactive snapshots without signal parity;
- shared Tray partitions solely to reduce three filters;
- persistent Tray pin/pattern caches;
- Autostart write batching/debounce;
- PackageSearch debounce/generation/timeout changes;
- DisplayMode action batching/parallelism.

`Translation.qml`, `Zettelkasten.qml` and `InternalTodoBackend.qml` were
also checked; their dominant work is already demand-driven/single-pass or bound
to persistence/helper semantics, so no practical strict-lossless finding was
promoted from them.

### 50.13 Round-36 regression requirements

Before implementation:

- Network: empty/malformed rows, escaped colon, all duplicate-SSID precedence
  combinations, exact order and QObject reuse/destruction.
- Autostart sort: 0/1/many results, managed/external combinations, duplicate IDs
  as distinct objects, equal names/ties, exact identity/order.
- Autostart parse: absent/valid/duplicate/reversed markers, invalid rows,
  enabled/commented directives, exact outside-section writeback.
- DisplayMode: empty/duplicate/falsy/prototype-looking names, all modes/errors,
  rollback/disconnect, exact action order and selection fallback.
- PackageSearch: normal/forced-installed parsing, casing, AUR metadata,
  descriptions, malformed/blank rows, exact result values/order.
- Tray/Bluetooth/Updates: duplicate/non-string pins, Fcitx/passive behavior,
  first toplevel match, adapter/device edge cases, and empty/LF/CRLF/blank-line
  update output.

### 50.14 Revised strict-lossless priority

**New CONFIRMED, no persistent cache/tradeoff:**

1. Network one-pass parse + SSID grouping (§50.1);
2. lazy invocation-local Autostart sort memo (§50.2);
3. Autostart original-line parser reuse (§50.3);
4. DisplayModePlan pass/intermediate-array reductions (§50.4);
5. DisplayMode selection local Set/first-match reductions (§50.5);
6. PackageSearch forced-installed direct parse (§50.6);
7. TrayService local pin Sets (§50.7);
8. TrayService per-operation normalized patterns (§50.8);
9. Bluetooth direct connected count (§50.9);
10. Updates direct newline count (§50.10).

**Not promoted:** DisplayMode queue cursor pending QML signal parity (§50.11),
persistent indexes/caches, shared reactive partitions that can broaden signals,
and any persistence/debounce/process-timing change.

Earlier correctness prerequisites remain above pure performance work:

- capture-helper stale-preview hash / newer-user clipboard races (§44.1, §45.6);
- Bar/Dock first-empty ignored-regex initialization and invalid-regex robustness
  (§47.1-§47.2).

No runtime/source implementation is authorized by this handoff.


---

## 51. Round 37 — strict-lossless layout, clock and utility collection reductions (2026-09-30)

### Snapshot / concurrent reconciliation

Round 37 opened on exact `dev` HEAD:

`4504362a13058cf04c0e8c955015d9ff62cd237b`
— `docs(perf): audit service and planner reductions`.

During the audit, `dev` advanced by one concurrent runtime commit to:

`ba776dce819a08f137b882e48f642fdb6a3da1c0`
— `fix(abyss): stabilize automatic paired vacancy`.

That commit changes only:

- `modules/abyss/AbyssCorners.qml`;
- `modules/abyss/AbyssSurfaceController.qml`;
- `modules/abyss/looks/AbyssVacancyBorrowing.js`;
- `modules/notificationCenter/NotificationCenterPopup.qml`;
- `scripts/test-abyss-vacancy-borrowing.py`.

It does not touch this round's candidate cluster. The handoff and all source
paths used below were re-read at exact
`ba776dce819a08f137b882e48f642fdb6a3da1c0` before this docs update.

Round-35/36 strictness remains unchanged: CONFIRMED means identical observable
results, order, relevant identity, QML/publication behavior, process/event
sequence, persistence/failure behavior and malformed-input behavior. No
persistent CPU-for-RAM cache is promoted merely because it is faster.

### 51.1 ShellLayoutController internal reads serialize/parse static descriptors unnecessarily — CONFIRMED / P1-P2 layout/edit paths

Paths:

- `services/ShellLayoutController.qml`;
- `services/ShellEditSession.qml`;
- `modules/common/widgets/ShellLayoutEditorWindow.qml`;
- `modules/settings/ShellLayoutConfig.qml`.

`ShellLayoutController.descriptor(surfaceId)` intentionally returns a deep
clone:

`JSON.parse(JSON.stringify(found))`.

That public isolation contract should remain unchanged: external callers can
receive a mutable descriptor copy without being able to corrupt the controller's
private descriptor table.

However, five controller-internal paths call the same public cloning API only to
read descriptor fields:

- `currentState()`;
- `legalSlots()`;
- `validatePlacement()`;
- `setProperty()`;
- `resetSurface()`.

The descriptor table is a private readonly static array of JSON-safe records, and
repository search found no external access to `_descriptors`.

Strict-safe direction:

- add a private `_descriptorRef(surfaceId)` returning the same first matching
  private record without cloning;
- keep public `descriptor()` exactly clone-returning;
- use the private reference only in controller-internal read-only code;
- for `legalSlots()`, return `desc.slots.slice()` so the caller still receives
  a fresh ordered array and cannot mutate the static descriptor.

This removes repeated JSON stringify/parse work from live state/validation paths
without changing the public identity/ownership contract.

Required parity includes all five surfaces, unknown IDs, inactive families,
invalid slots and mutation of values returned by public `descriptor()` /
`legalSlots()`.

### 51.2 ShellLayoutController clones fresh unescaped result objects before returning them — CONFIRMED / P2 edit mutations

Path: `services/ShellLayoutController.qml`.

Two mutation paths deep-clone objects that were just created locally and have
not escaped:

- `moveSurface()` clones its fresh `validation` before setting
  `changed=true` and appending `persisted=true`;
- sidebar/dock `resetSurface()` clones the fresh object returned by its own
  `moveSurface()` call before appending `reset=true`.

Strict-safe direction:

- mutate those local result objects directly;
- do not change any early return;
- keep Config writes and `Config.flushWrites()` in the exact current order;
- assign the same fields in the same sequence.

The current `changed` key already exists, so reassigning it does not alter
property order. `persisted` and `reset` remain appended at the same points as
today. No external alias exists before the return.

This removes full JSON stringify/parse cycles from successful placement/reset
operations.

### 51.3 surfacesForFamily can fuse filter -> deep-clone map without changing clone isolation — CONFIRMED / P2 edit-mode

Path: `services/ShellLayoutController.qml`.

Current `surfacesForFamily()`:

1. filters all private descriptors by family;
2. allocates the filtered reference array;
3. maps that array through the existing deep clone.

The descriptors are private static JSON-safe data and the clone is pure.

Exact-safe direction:

- iterate `_descriptors` once in source order;
- for each matching descriptor append `root._clone(item)`;
- retain one fresh deep clone per returned descriptor.

Output order, duplicate behavior, returned identity/isolation and active-family
fallback remain exact. The filtered intermediate array disappears.

### 51.4 ShellLayoutController output fallback membership can use a local Set after the same early returns — CONFIRMED / P3 topology/layout calculation

Path: `services/ShellLayoutController.qml`.

`_outputEnabled(configuredOutputs, outputName)` currently:

1. returns true for non-array/empty config;
2. returns true when the requested output is explicitly listed;
3. only then maps connected screen names;
4. evaluates
   `!configuredOutputs.some(name => currentNames.includes(name))`.

The final membership shape is O(C x S) for configured names C and connected
screens S.

Strict-safe direction:

- preserve both early returns **before reading `Quickshell.screens`**, so QML
  dependency reads are not broadened;
- after those returns, build one invocation-local
  `Set(currentNames)`;
- retain `configuredOutputs.some(name => connectedSet.has(name))`.

Array `includes` and Set membership both use SameValueZero. Retaining
`some()` also preserves sparse-array visitation semantics. No state is cached
between calls.

This is P3 because monitor lists are normally small, but it is an exact local
asymptotic reduction.

### 51.5 ShellEditSession diagnostic snapshot computes each interaction mode twice — CONFIRMED / P2-P3 IPC/edit diagnostics

Path: `services/ShellEditSession.qml`.

`_interactionSnapshot()` currently writes, per surface:

- `mode: root.interactionMode(surfaceId)`;
- `blocksNormalActions: root.blocksNormalActions(surfaceId)`.

But `blocksNormalActions()` immediately calls
`interactionMode(surfaceId)` again.

This is an imperative synchronous IPC-status path, so no event can interleave
between the two computations.

Exact-safe direction:

- compute `mode` once per surface;
- store the same mode;
- derive `blocksNormalActions` with the exact existing set of mode string
  comparisons;
- keep public `blocksNormalActions()` unchanged for all other callers.

This changes interaction-mode/descriptor resolution from 2 -> 1 per diagnostic
surface while preserving the exact serialized status object.

### 51.6 WorldClock normalization and label helpers have exact one-pass/string-scan reductions — CONFIRMED / P2-P3

Path: `services/WorldClock.qml`.

Three independent local reductions are strict-safe.

**Configured timezones**

Current array input uses:

`configured.map(String+trim).filter(nonempty)`.

Because Config arrays are JSON-derived, a single indexed loop can perform the
same String/nullish conversion and trim once, appending nonempty values in the
same order. Non-array fallback to `defaultTimezones` remains unchanged.

**Timezone labels**

`labelFor()` splits the complete timezone string only to read the first and
last slash-separated components.

An exact `indexOf("/")` + `lastIndexOf("/")` + `slice()` implementation
preserves:

- no-slash names;
- multiple slashes;
- leading/trailing slashes;
- the same first component as region;
- the same last component as city;
- underscore replacement.

**Offset output**

`offsetProc.onExited` currently calls
`offsetCollector.text.trim()` twice before optionally splitting it.

Read/trim once into a local string, then preserve the same empty/nonempty branch
and `/\r?\n/` split.

No timezone cache or retained normalized copy is introduced.

### 51.7 WorldClock.entries constructs the same city Date twice per timezone per minute — CONFIRMED / P2 visible widget

Path: `services/WorldClock.qml`.

Each `entries` row currently calls:

- `timeStringFor(i)` -> `cityDate(i)` -> one `new Date`;
- `isDaytimeFor(i)` -> `cityDate(i)` -> a second `new Date`.

Both use the same `root.now` and offset during one synchronous binding
evaluation.

Strict-safe direction:

- construct one city Date per row;
- use private date-based helpers for the existing time-string and daytime logic;
- retain public `timeStringFor(index)` and `isDaytimeFor(index)` wrappers
  unchanged;
- derive the displayed city-name prefix with exact first-`" ("` index/slice
  semantics instead of `labelFor(tz).split(" (")[0]`.

This changes Date allocations from 2 -> 1 per timezone for each `entries`
recomputation while preserving 12/24-hour text, AM/PM casing, minute value,
offset text and 06:00/18:00 daytime boundaries.

No offset caching beyond the existing service state is added.

### 51.8 LocalMusic MPD changed-event subsystem handling can avoid map + includes scans — CONFIRMED / P2 event path

Path: `services/LocalMusic.qml`.

For a native MPD `changed` event, current code:

1. converts every subsystem to String with `.map()`;
2. tests `.includes("database")`;
3. if necessary tests `.includes("stored_playlist")`.

The event came from JSON parsing, so subsystem values are JSON values.

Exact-safe direction:

- scan the original subsystem array once;
- String-convert **every** element in source order, even after a matching value
  has been seen;
- accumulate booleans for database/stored_playlist;
- only after the complete scan perform the same rescan-timer branch.

Not early-breaking matters: current `.map()` converts every element before any
membership branch, so a strict replacement must preserve that evaluation shape.

The temporary normalized array and one/two membership scans disappear; event
type, payload application and fallback refresh timing remain unchanged.

### 51.9 YtMusic quick-connect browser ordering can use a local Set — CONFIRMED / P3 user action

Path: `services/YtMusic.qml`.

On first quick-connect attempt, `_tryNextBrowser()` builds a deduplicated browser
list with growing `browsers.includes(b)`.

The source is a typed `list<string>`.

Strict-safe direction:

- keep the existing test that the default browser is actually detected;
- if selected, append it first and add it to a local Set;
- traverse `detectedBrowsers` in the same order and append only first
  occurrences using `Set.has`.

This preserves default-first preference and first-occurrence ordering while
changing growing duplicate membership from O(B²) to O(B).

No persistent browser index is introduced.

### 51.10 Bounded recent/liked arrays create a second array only to truncate a fresh local array — CONFIRMED / P3

Paths:

- `services/YtMusic.qml`;
- `services/ThemeService.qml`.

Examples:

- YtMusic recent searches: filter -> unshift -> optional
  `slice(0, maxRecentSearches)`;
- YtMusic liked songs: spread copy -> unshift -> optional
  `slice(0, maxLikedSongs)`;
- recent themes: filter -> unshift -> optional `slice(0, 4)`.

In every case the array being truncated is a fresh invocation-local ordinary
array that has not escaped.

Under the existing `if (length > cap)` guard, assigning the local array's
`length = cap` preserves the exact prefix, order and final published identity
semantics while removing the second copied array.

For YtMusic recent-search duplicate removal, the query lowercase value can also
be computed once before the existing filter; `query` is the already-trimmed
string passed internally by `search()`.

Do not change persistence call order or cap values.

### 51.11 Emoji data loading can replace slice -> filter -> map with one exact loop — CONFIRMED / P3 load/reload

Path: `services/deferred/Emojis.qml`.

After locating the data marker, current `updateEmojis()` executes:

`lines.slice(dataIndex + 1).filter(line => line.trim() !== "").map(line => line.trim())`.

`lines` came directly from String `split("\n")`, so every entry is a primitive
string.

Exact-safe direction:

- iterate from `dataIndex + 1`;
- trim each line once;
- append nonempty trimmed strings in the same order.

Missing-marker warning behavior and the previous list-retention behavior on that
failure path remain unchanged.

This removes the sliced array, filtered array and duplicate trim on surviving
rows. Do not add retained lowercase emoji copies under strict no-tradeoff rules.

### 51.12 Weather forward-geocode scoring reallocates the same city-type list for every candidate — CONFIRMED / P3 network completion

Path: `services/Weather.qml`.

Nominatim lookup currently requests at most five results. Inside the result loop
it recreates:

`["city","town","village","municipality","hamlet","suburb","county","administrative"]`

for every candidate only to test `includes(type)`.

Move that immutable list outside the loop as an invocation-local constant (or
use an exact direct comparison chain). Keep:

- result iteration order;
- current score weights;
- `score > bestScore`, not `>=`, so first equal-score result continues to win;
- all fallback/error/network behavior.

The saving is small because the server limit is five, but it is fully lossless.

### 51.13 AppLauncher network-settings fallback can build the exact same shell chain in one pass — CONFIRMED / P3 click path

Path: `services/AppLauncher.qml`.

`launchNetworkSettings()` currently:

1. repeatedly computes `command.split(" ")[0]`;
2. filters fallback commands by executable;
3. concatenates configured command + fallbacks;
4. filters empty commands;
5. maps every command to a shell fragment;
6. joins with `" || "`.

Exact-safe direction:

- compute configured command's first-space token once;
- append its shell fragment only when the command is nonempty;
- iterate static fallbacks in current order;
- compute each fallback token once;
- skip exactly those whose token equals the configured command token;
- append the exact existing fragment text;
- join with the same delimiter and call `ShellExec.execCmd()` once.

Do not alter command tokenization from literal `split(" ")`, quoting, fallback
order or shell selection in this performance patch.

### 51.14 ShellUpdates progress/status parsing can avoid repeated full split arrays — CONFIRMED / P2-P3 while updating

Path: `services/ShellUpdates.qml`.

The 2-second update progress path and resume/watchdog readers repeatedly parse
markers of the form:

`progress:STEP:TOTAL:MESSAGE`

with `split(":")` and then reconstruct MESSAGE with
`slice(3).join(":")`.

Exact-safe direction:

- locate the first/second/third colon with `indexOf`;
- slice STEP and TOTAL from the same boundaries;
- MESSAGE is the substring after the third colon, preserving every later colon;
- in the live progress reader, keep the current requirement equivalent to
  `parts.length >= 4`: if a third colon does not exist, do not update fields;
- preserve `parseInt(...) || 0`;
- preserve the resume reader's looser missing-field defaults;
- for failed markers, if optimized, preserve exactly
  `split(":")[1] || "unknown"`.

No polling cadence, child-process count, watchdog restart timing or publication
timing changes.

### 51.15 ShellUpdates local-modification result parsing can fuse split + filter — CONFIRMED / P3 detail fetch

Path: `services/ShellUpdates.qml`.

After `.trim()`, nonempty local-modification stdout currently uses:

`raw.split("\n").filter(l => l.length > 0)`.

A single loop over the split lines can append the same nonempty strings in the
same order and remove the filtered intermediate array. CR characters, if any,
remain untouched exactly as today because the delimiter remains `"\n"`.

The manifest checksum process and detail-fetch sequence remain unchanged.

### 51.16 IconThemeService path-name extraction and exclusions allocate avoidable per-line arrays — CONFIRMED / P3 cold enumeration

Path: `services/IconThemeService.qml`.

For every directory emitted by `find`, current code:

- splits the full path by `"/"` only to take the last component;
- creates an exclusion-array literal and calls
  `includes(name)`.

Exact-safe direction:

- derive basename with `lastIndexOf("/")` + `slice()`;
- keep the same empty-name rejection;
- replace the four-name exclusion literal with exact string comparisons;
- keep the separate `cursors` rejection;
- append accepted names in the same discovery order.

The existing completion behavior remains untouched:

`Array.from(new Set(themes)).sort()`.

Therefore duplicate removal and final default lexical ordering are unchanged.

### 51.17 Gowall theme enumeration copy growth is not strict-lossless if publication is batched — CLOSED under current contract

Path: `services/deferred/GowallService.qml`.

`listThemesProc` currently publishes each discovered nonempty theme line
immediately as:

`root.availableThemes = [...root.availableThemes, theme]`.

This repeatedly copies the growing prefix and can become O(N²) allocation work.

Accumulating privately and assigning once on process exit would be cheaper, but
it would also change:

- the number/timing of `availableThemesChanged` emissions;
- when bound Settings consumers can observe partial discovery results.

That violates this audit's event/publication-timing rule.

Status:

- **CLOSED as a blind batch-publication optimization**;
- only reopen if the product contract is explicitly changed or exact
  signal/publication parity can be retained by another mechanism.

### 51.18 LocalMusic playQueue filter + URI map is not promoted because fusing changes read timing — NEEDS PARITY

Path: `services/LocalMusic.qml`.

`playQueue()` first filters valid track objects, publishes/uses that ordered
`valid` array to update playback state, and only later maps those tracks to URI
strings for the queued native request.

A fused pass that stores both the valid track and URI looks cheaper, but it
moves the second `track.uri ?? track.path` property read earlier — before
`activeQueue`, current track and related state assignments that currently
occur between filter and map.

For normal plain snapshot objects the values are expected to be identical, but
strict malformed/reactive-object behavior is not proven.

Status: **NEEDS PARITY**, not CONFIRMED. Keep the current two-stage read timing
unless a plain-immutable track contract is established.

### 51.19 ShellUpdates resume-helper subprocess cleanup remains compatibility-sensitive — NEEDS COMPATIBILITY, not strict set

Path: `services/ShellUpdates.qml`.

The startup resume probe invokes external `date`, `printf`, `cut`, `stat`
and `cat` inside one Bash script. Some of these can be replaced with Bash
builtins/parameter expansion.

That may reduce children, but missing-tool/failure behavior would differ from
today. Under the strict rule, this is not automatically lossless.

Keep it outside the confirmed batch until runtime dependency assumptions and
failure-path fixtures explicitly cover missing/failed helper commands.

### 51.20 Round-37 regression requirements

Before implementing the confirmed Round-37 batch:

Shell layout/edit:

- public descriptor remains a fresh deep clone;
- mutating returned descriptor/legalSlots cannot alter static descriptors;
- currentState/validation/legalSlots JSON exact for every surface/family;
- move/reset success, no-change and failure paths;
- exact Config mutation and flush ordering;
- `_outputEnabled` with empty/non-array lists, explicit target hit, target miss,
  connected/disconnected configured outputs, duplicates and sparse arrays;
- diagnostic interaction snapshot exact under normal/selected/lifted/preview/
  confirmation states.

WorldClock:

- no slash, multiple slash, leading/trailing slash and underscore labels;
- non-array/empty/mixed configured timezone input;
- empty/nonempty offset output;
- exact entries in 12h/24h formats, AM/PM casing, offset/day-boundary fixtures;
- Date/DST boundary corpus proving one-date reuse produces the same row.

LocalMusic/YtMusic:

- changed events with no/non-array subsystems;
- database/stored_playlist at first/middle/last position and no match;
- duplicate/default browser ordering;
- recent/liked arrays at cap, cap+1 and duplicate cases;
- persistence calls remain in the same order.

Utilities:

- emoji missing marker, blanks, whitespace-only rows and trailing newline;
- Weather equal-score fixture proving first tie still wins;
- AppLauncher exact generated shell strings for empty/configured/fallback-same-bin
  cases and commands containing arguments;
- ShellUpdates malformed/partial/extra-colon progress and failed markers;
- IconTheme paths with normal/trailing slash, ignored names and duplicate final
  sort behavior.

### 51.21 Revised strict-lossless priority after Round 37

**New CONFIRMED, no persistent cache/tradeoff:**

1. private read-only descriptor refs while preserving public clone isolation
   (§51.1);
2. remove deep clones of fresh local layout mutation results (§51.2);
3. fuse surfacesForFamily filter + clone (§51.3);
4. preserve early returns then use local connected-output Set (§51.4);
5. reuse one ShellEdit interaction-mode result per snapshot surface (§51.5);
6. WorldClock normalization/string-scan reductions (§51.6);
7. WorldClock one Date per entries row (§51.7);
8. LocalMusic one-pass subsystem classification (§51.8);
9. YtMusic local browser Set (§51.9);
10. local in-place truncation of fresh bounded arrays (§51.10);
11. one-pass emoji data extraction (§51.11);
12. Weather invocation-local city-type list (§51.12);
13. AppLauncher one-pass fallback command construction (§51.13);
14. ShellUpdates delimiter-index status parsing (§51.14);
15. ShellUpdates split/filter fusion for local modifications (§51.15);
16. IconTheme path/exclusion per-line reductions (§51.16).

**Not promoted:**

17. Gowall one-shot publication because it changes observable publication timing
    (§51.17);
18. LocalMusic playQueue filter/map fusion pending property-read timing parity
    (§51.18);
19. ShellUpdates helper-child elimination pending failure/compatibility proof
    (§51.19);
20. any persistent label/theme/browser/layout index introduced only to exchange
    resident memory for CPU.

Earlier correctness prerequisites remain above pure performance work:

- capture-helper stale-preview hash / newer-user clipboard races (§44.1, §45.6);
- Bar/Dock first-empty ignored-regex initialization and invalid-regex robustness
  (§47.1-§47.2).

No runtime/source implementation is authorized by this handoff.


---

## 52. Round 38 — iNiR prerelease delta audit after `bbd304b3` (2026-09-30)

### Snapshot / scope

This round is a targeted cross-repo refresh after the upstream iNiR prerelease
moved beyond the snapshot previously audited by this handoff.

Previous upstream comparison SHA:

`bbd304b3ba1662ff0f41a2898b1b1b91cf02f071`.

Current upstream `snowarch/iNiR:prerelease` HEAD, refetched immediately before
this write:

`d851c1a71b5ebd6aeb5c8a8ec63736e1d39d52ec`
— `docs(release): a plainer note on where iRiS stands`.

GitHub reports 66 commits in the upstream delta.

Hadalis `dev` remained stable throughout this audit at:

`eb74adec6265f508b9c27819c4d2f637ca09353a`
— `docs(perf): audit layout and utility reductions`.

The audit inspected the new upstream performance/correctness work rather than
blindly comparing file names. The most relevant new commits are:

- `7433eb355cff8c5f55ba910d31c294f4f91479b6`
  — `perf(common): moving content draws in a surface of its own`;
- `ea7c9752b0d2181f303e4104e7153f59371e78b8`
  — `perf(background): the Visualizer widget moves out of the desktop`;
- `39f429b3361735f1935c9c9548ab87be5a5d6da3`
  — `perf(iris): visualizers and pulses stop repainting the chassis`;
- `714653592dde75aef1d072c23ba507603acace2a`
  — `fix(background): the wallpaper is decoded at the size it is drawn`;
- `2d1bc803a59e85a0d8817a483663cc0949e7ce26`
  — `fix(theme): apps follow the shell's mode and material`;
- `7de501d3ab6e401078632a731a3f646984ee17e3`
  — `fix(widgets): deferred placement dies with the widget`.

Important reconciliation: upstream video-playback proxy/transcode support
(`Wallpapers.videoPlaybackPath()`) already existed at the previously audited
`bbd304b3...` snapshot. It is therefore **not** a new Round-38 upstream
finding and is not counted below.

### 52.1 LiveLayer introduces a real compositor-damage optimization, but it is not strict-lossless by inspection — NEEDS VISUAL/COMPOSITOR PARITY + BENCHMARK / TRADEOFF

Upstream paths:

- `modules/common/widgets/LiveLayer.qml`;
- background Visualizer changes from `ea7c9752...`;
- iRiS visualizer/pulse changes from `39f429b3...`.

Hadalis paths inspected:

- `modules/background/Background.qml`;
- `modules/background/widgets/visualizer/VisualizerWidget.qml`.

The upstream idea is materially different from ordinary QML micro-optimization.

A full-output layer surface that contains one continuously moving small child can
cause the full host surface to be presented/damaged every frame. Upstream
`LiveLayer` therefore:

1. draws the moving content normally inside its host while the host itself is
   moving/fading/restacking;
2. waits for the host to become geometrically/compositionally calm;
3. creates/uses a small input-inert `PanelWindow` over the same pixels;
4. waits until that surface has produced a frame;
5. switches drawing to the detached small surface;
6. immediately returns drawing to the host if position, size, opacity, clipping,
   effects, host epoch or eligibility changes.

The content contract also has a `drawing` boolean so the hidden duplicate
instance stops its own CAVA/timer/animation work.

This is highly relevant to current Hadalis because the desktop
`VisualizerWidget` is a child of the full-output Background and its
`CavaSpectrum` continuously redraws while music is active.

However this cannot be classified CONFIRMED under Hadalis' strict rules.

Hadalis-specific parity blockers include:

- desktop widgets have `desktopStackZ` and can overlap; a detached layer surface
  can escape the original sibling z-order and appear above a widget that should
  cover it;
- WidgetSurface blur/masks/effects and transformed/opacity ancestors must remain
  pixel-identical;
- edit mode, shell-layout edit mode, lock state, parallax/opacity transitions and
  family transitions can move or cover the widget;
- fractional coordinates / DPI scaling can alter sampling when content moves
  between scene-graph and layer-surface coordinates;
- an additional `PanelWindow` plus a second component instance is retained while
  eligible, so this is not automatically a free CPU-for-RAM trade;
- the upstream implementation intentionally has a settle/handoff lifecycle, so
  frame/publication/render timing needs explicit proof;
- compositor benefit may differ across Niri/Hyprland and driver stacks.

Status:

**NEEDS VISUAL/COMPOSITOR PARITY + BENCHMARK / TRADEOFF**, not strict CONFIRMED.

If investigated, start with **only the desktop Visualizer**, not a generic mass
port.

Required benchmark/parity bundle:

- compositor/GPU and QSG render cost with the same Visualizer idle vs active;
- one-output and multi-output;
- Niri and Hyprland separately;
- retained QML objects, mapped layer surfaces and PSS before/after;
- exact pixel/z-order checks with overlapping higher/lower `desktopStackZ`
  widgets;
- edit drag/resize, free/zone placement, opacity animation, blur/effects,
  screen lock, parallax and family transition;
- no input region / keyboard focus changes;
- no one-frame disappearance or duplicate drawing on detach/reattach;
- CAVA process/subscriber count unchanged.

The upstream iRiS pulse conversions are the same architectural idea, not a
separate Hadalis finding. Hadalis has no iRiS family, so do not port those
components merely because they exist upstream.

### 52.2 Output-sized static wallpaper decode is a good upstream optimization but is already present in Hadalis — ALREADY / SUPERSEDED

Upstream commit:

`714653592dde75aef1d072c23ba507603acace2a`.

The upstream change adds `Image.sourceSize` / crossfader source sizing so large
static wallpaper files are decoded near their actual draw dimensions instead of
at full file resolution.

Current Hadalis already has this class of optimization:

- main `Background.qml` `WallpaperCrossfader` decodes at screen dimensions x
  monitor scale and explicitly avoids parallax-scale CPU upscaling;
- `WaffleBackground.qml` already supplies screen-sized `sourceSize`;
- ii and Waffle backdrops already supply bounded source sizes;
- blurred backdrop paths go further and decode at half output dimensions while
  blur is active.

Therefore this new upstream commit does **not** create a new Hadalis backlog
item. Preserve Hadalis' current fill/parallax/DPI semantics rather than copying
upstream's exact sizing expression mechanically.

Status: **ALREADY / SUPERSEDED by current Hadalis implementation**.

### 52.3 ThemeService misses signature priming when instantiated after Config is already ready — CORRECTNESS PREREQUISITE / P0-P1 avoidable regeneration

Upstream commit:

`2d1bc803a59e85a0d8817a483663cc0949e7ce26`.

The relevant upstream change factors signature initialization into
`_primeLiveRegen()` and calls it from both:

- `Config.onReadyChanged`;
- `Component.onCompleted`.

Current Hadalis only primes:

- `_lastLiveRegenSignature`;
- `_lastPanelFamily`

inside `Config.onReadyChanged`.

Its `Component.onCompleted` branch for an already-ready Config runs
`normalizeGlobalStyle()` and restarts the schedule refresh, but **does not
prime those two fields**.

This matters because Hadalis shell startup explicitly handles the case where
`Config.ready` was already true before the shell root was built: it
`Qt.callLater()` calls `ThemeService.applyCurrentTheme()`. If ThemeService is
first instantiated after readiness, its own `onReadyChanged` never fires.

Then the first later `Config.onConfigChanged` can reach
`_tryLiveRegenerateFromConfig()` with:

- current nonempty `liveRegenSignature`;
- stale initial `_lastLiveRegenSignature = ""`;
- stale `_lastPanelFamily = ""`.

For auto theme this can make an unrelated first Config change look like a
live-theme delta and launch the expensive regeneration path.

This is a correctness/lifecycle initialization bug with performance
consequences. Preventing that phantom regeneration changes current observable
side effects, so it is **not** labeled a strict-lossless optimization.

Required fix contract:

- when ThemeService is created with Config already ready, immediately prime the
  exact current signature/family;
- keep existing Config-ready behavior when readiness occurs later;
- do not remove the intentional startup `applyCurrentTheme()` reconciliation;
- a genuinely relevant signature change must still regenerate;
- a family change must still force family-aware regeneration;
- manual-theme and standalone-settings behavior must remain unchanged.

Regression fixture:

1. instantiate with `Config.ready=true`;
2. record no theme regeneration from an unrelated Config mutation;
3. mutate a field included in `liveRegenSignature` and verify one regeneration;
4. change panel family and verify existing family-change behavior;
5. repeat with Config becoming ready after ThemeService construction.

This finding refines, but does not invalidate, §24.4: upstream still intentionally
requests external theme application from `applyCurrentTheme()`; this is about
preventing an additional phantom live regeneration, not deleting startup
reconciliation.

### 52.4 Deferred widget-placement callLater can outlive the widget — CORRECTNESS PREREQUISITE / lifecycle

Upstream commit:

`7de501d3ab6e401078632a731a3f646984ee17e3`.

Current Hadalis
`modules/background/widgets/AbstractBackgroundWidget.qml` still uses:

- `Qt.callLater(root.applyPlacementFromConfig)` from `Component.onCompleted`;
- the same `Qt.callLater(...)` from `onPlacementStrategyChanged`.

Upstream replaced that with a zero-interval Timer owned by the widget and
restarts the Timer from those paths. If the widget is destroyed before the
deferred callback, the owned Timer disappears with it instead of retaining a
callback into the dead widget context.

This is a correctness prerequisite, especially around dynamic widget
load/unload, output changes and edit/config transitions.

It is **not** a pure strict-lossless performance optimization:

- Timer restart may coalesce multiple pending requests that separate
  `Qt.callLater` calls would have delivered;
- exact event-loop timing needs parity review;
- eliminating callbacks after destruction intentionally changes an erroneous
  lifecycle behavior.

Required fixture before adapting:

- create then destroy a widget before the deferred placement turn;
- multiple placement-strategy changes in one event-loop turn;
- Config-ready-before/after component construction;
- free vs zone placement;
- leastBusy/mostBusy request count and final geometry;
- no stale OpenCV placement helper launch after widget destruction.

The existing §29.2 least-busy request serialization/dedup work remains a
separate optimization problem; do not use this lifecycle fix as a substitute for
its request-signature/in-flight correctness.

### 52.5 The upstream video playback proxy is intentionally not re-counted and is outside strict-lossless anyway — PREVIOUS-UPSTREAM / TRADEOFF

`Wallpapers.videoPlaybackPath()` and the tiered cached
`video-playback-copy.sh` mechanism were already present at upstream
`bbd304b3...`, so Round 38 does not count them as newly learned work.

For completeness, it also does not satisfy this project's strict-lossless bar:

- large videos may be transcoded to H.264 at a smaller resolution;
- small consumer tiers may cap playback at 30 FPS;
- source handoff/cache build timing changes;
- encoded color/quality/frame timing can differ;
- persistent disk/cache state is added.

It may be a valid product-level CPU/GPU optimization under an explicit quality
tradeoff, but it does not belong in the strict no-visual/no-animation-change
batch.

### 52.6 Round-38 upstream-delta conclusion

For the **new** iNiR delta after `bbd304b3...`:

**CONFIRMED strict-lossless new ports:**

- none promoted from this upstream delta.

That is intentional, not a failed audit. The strongest new upstream performance
idea changes rendering surface topology and needs parity/tradeoff evidence.

**ALREADY / no new Hadalis work:**

1. bounded static wallpaper decode size (§52.2).

**High-value candidate requiring evidence:**

2. isolate continuously moving desktop Visualizer damage into a small surface
   only if Hadalis-specific z-order/effects/compositor parity and RAM costs are
   proven (§52.1).

**New correctness prerequisites discovered from upstream:**

3. prime ThemeService live-regeneration signature when constructed after
   Config-ready (§52.3);
4. replace destruction-unsafe deferred widget placement ownership after lifecycle
   parity is defined (§52.4).

**Explicitly excluded from new findings:**

5. tiered video-playback proxy existed before the previous upstream snapshot and
   is not strict-lossless (§52.5);
6. iRiS-specific pulse/chassis work has no direct Hadalis family target and is
   only evidence for the LiveLayer architecture;
7. no upstream change in this delta authorizes altering animation cadence,
   visual quality, stacking, event timing or cache residency under the strict
   optimization contract.

Earlier correctness prerequisites remain active and still outrank pure
performance work:

- capture-helper stale-preview hash / newer-user clipboard races (§44.1, §45.6);
- Bar/Dock first-empty ignored-regex initialization and invalid-regex robustness
  (§47.1-§47.2).

No runtime/source implementation is authorized by this handoff.


---

## 53. Round 39 — `awesome-niri` ecosystem source audit (2026-09-30)

### Snapshot / source selection

This round treats `niri-wm/awesome-niri` as a **source index**, not as
optimization evidence by itself.

Index snapshot:

`niri-wm/awesome-niri:main`
`946bc74bb8606bbe2958a0b1722ed90693a6f231`
— `add wl-freeze to "Window and Workspace Management"`.

The highest-value runtime sources selected from that index were:

- `AvengeMedia/DankMaterialShell:master`
  `2fb0cfee604ac4955da1933e2e4c49a405df55bd`;
- current Noctalia repository `noctalia-dev/noctalia:main`
  `1f39c3d14d9a71460980af570aeda2b39d090bea`;
- `imiric/qml-niri:main`
  `93e603901bed2c4465d5675ae43fd52b7f7c4adf`;
- `Antiz96/oniri:main`
  `82e45605eeed896f6f0fa82a3e4fbf4123fe5769`;
- smaller event-stream utilities:
  `druskus20/eww-niri-workspaces`,
  `Kirottu/system76-scheduler-niri`, and
  `ews/noctalia-niri-ribbon`.

The `awesome-niri` Noctalia link still points at the historical
`Ly-sec/Noctalia` location. The current repository was resolved before
auditing; do not assume every curated-list URL is current.

For the direct-Quickshell-IPC finding below, the private wire contract was also
checked against current Quickshell mirror master:

`quickshell-mirror/quickshell:master`
`41651d7dcd62a9400eb6f4f8a8580efe00901efb`.

Hadalis baseline remained stable throughout this audit at:

`fb57e0bd31c849421a553b806d1212746db5ecee`
— `docs(perf): audit latest iNiR optimization delta`.

No runtime/source implementation is authorized by this round.

### 53.1 DMS bypasses the heavy `qs ipc call` child through Quickshell's Unix socket — HIGH CONFIDENCE / P1 interactive-latency benchmark + compatibility guard

Primary source:

DMS commit
`c3fd526698e0bf04db7160389aaf83a911745abe`
— `perf(ipc): call Quickshell directly (#3081)`.

Current DMS implementation:

- `core/internal/qsipc/client.go`;
- `core/cmd/dms/shell.go`;
- `scripts/benchmark-ipc.sh`.

DMS sends Quickshell's StringCall wire message directly to:

`${XDG_RUNTIME_DIR}/quickshell/by-pid/<pid>/ipc.sock`

instead of launching:

`qs ... ipc call <target> <function> ...`

for every normal CLI action.

Its important safety shape is not "replace qs and hope":

1. identify the exact running shell PID;
2. attempt the direct socket call;
3. decode Quickshell's indexed response;
4. on **any** direct-call failure, fall back to the normal `qs ipc call`
   implementation.

DMS also ships a benchmark that first checks direct-vs-`qs` output equality
before timing the two paths.

The current Quickshell source still matches the relevant DMS assumptions:

- StringCall remains a distinct IPC command;
- the response alternatives remain ordered as:
  no-current-generation, target-not-found, entry-not-found,
  argument-parse-failed, completed;
- completed responses carry void/non-void state plus the returned string;
- the runtime instance directory still has the `by-pid/<pid>` path.

#### Why this is relevant to Hadalis

Current `scripts/inir` uses the heavy child path for both:

- generic `inir ipc <target> <function> ...`;
- every registry-backed `inir <target> <function> ...` command through
  `run_ipc_target_command()`.

After instance/config resolution and startup handling, both common paths execute:

`"$qs_bin" -p "$config_dir" ipc call ...`

and retry with another `qs` invocation after the existing startup grace if
the first call fails.

This path is used by frequent shell/keybind commands, so process startup and
Qt initialization can be part of interaction latency even though the actual
QML handler is already resident.

Hadalis also already has a natural implementation host:

`native/inir-native`

is a small Rust one-shot helper with an existing subcommand framework. A
`qs-ipc-call` primitive could therefore be benchmarked without introducing
another daemon.

Important correction versus DMS:

**Hadalis cannot copy DMS's "zero additional child" result literally.**

DMS's CLI is already a compiled Go process, so the socket client runs inside
the existing CLI process. Hadalis' `inir` is Bash. If Bash invokes
`inir-native qs-ipc-call`, the heavy Qt `qs` child is replaced by a much
smaller native child, but a child process still exists.

The expected win to test is therefore:

- lower child startup latency;
- lower transient RSS/PSS;
- less Qt/plugin initialization work;

not automatically "one fewer process".

#### Strict-safe experiment shape

Do **not** rewrite the launcher or remove its current instance/startup logic.

A safe experiment is:

1. keep current `resolve_config_dir()`,
   `ensure_running_instance_for_ipc()`, registry validation and startup grace;
2. use direct IPC only when the **exact** shell PID/socket for the selected
   config can be identified unambiguously;
3. let a small native helper implement Qt-compatible UTF-16 QString
   serialization and StringCall response decoding;
4. on socket missing, timeout, protocol mismatch, generation-not-ready,
   target/function/argument error, ambiguous instance or any other failure,
   execute the current `qs ipc call` path unchanged;
5. keep metadata/show/dev-audit paths on `qs` unless separately proven;
6. do not remove `qs` as a dependency merely because the fast path exists.

Required parity cases:

- void-return and string-return functions;
- empty, ASCII, Unicode and non-BMP arguments;
- zero/multiple arguments;
- missing target/function;
- argument count/type mismatch;
- shell hot reload / no current generation;
- handler deferred during startup;
- one shell instance and multiple Quickshell instances/configs;
- stale PID/socket;
- shell stopped;
- direct helper absent;
- stdout, stderr and exit-code behavior at the public `inir` boundary.

Required benchmark:

- current `qs ipc call` vs native direct path;
- warm shell, repeated keybind-sized calls;
- wall time distribution, child lifetime and peak transient PSS/RSS;
- no measurable shell-side CPU/memory regression;
- fallback path excluded from claimed fast-path savings but tested separately.

Classification:

**HIGH CONFIDENCE / P1 interactive-latency benchmark + compatibility guard**.

It is not promoted to CONFIRMED strict-lossless yet because the protocol is an
internal Quickshell wire contract and Hadalis' Bash launcher architecture is
different from DMS's compiled CLI.

### 53.2 DMS lazy QtMultimedia construction is already present in Hadalis' main video crossfader — ALREADY

DMS perf commit:

`3630b46ee32e268b3a05790cc49ac6179209d064`
— `perf(shell): cut idle RAM by a lot`.

One of its explicit changes is to avoid constructing QtMultimedia players at
shell startup when no multimedia feature needs them.

This initially looked like a direct Hadalis candidate because
`Background.qml` constructs `VideoCrossfader` even while a static wallpaper
is active.

Full-source reconciliation closes that gap.

Current Hadalis `modules/common/widgets/VideoCrossfader.qml` already has:

- `readonly property bool _decoderActive: root.source !== ""`;
- `playerALoader.active: root._decoderActive`;
- `playerBLoader.active: root._decoderActive`;
- the two `MediaPlayer` objects inside those Loaders.

The source comment explicitly records that MediaPlayer construction has
measurable startup/teardown cost and that the visual shell stays resident while
decoder pipelines exist only for requested video.

Therefore static wallpaper does **not** retain the two decoder objects merely
because the crossfader component exists.

Status: **ALREADY**.

Do not create another "lazy VideoCrossfader" task.

### 53.3 DMS lazy modal residency is also already the shape of CloseConfirm — ALREADY for the audited confirmation path

The same DMS perf commit converts multiple always-resident modals to
`LazyLoader` instances.

Current Hadalis confirmation ownership already follows the equivalent split:

- `CloseConfirm.qml` keeps the lightweight IPC/lifecycle `Scope` resident;
- the fullscreen keyboard-exclusive `PanelWindow` is under
  `Loader { active: root.dialogVisible }`;
- family-specific confirmation content is created only inside that visible
  window.

This is especially important because CloseConfirm must keep its IPC owner alive
even while no prompt is visible.

Status for this audited path: **ALREADY**.

This does not authorize a generic "lazy every modal" rewrite. Existing handoff
guidance against blind generic popup lazy-loading still applies.

### 53.4 DMS allocator tuning may reduce idle memory, but is explicitly a memory/allocator-policy experiment — CONDITIONAL BENCHMARK / TRADEOFF

The DMS shell-launch environment sets, when the user has not already supplied
one:

`MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000`

and describes the goal as reducing Quickshell idle memory / jemalloc extent and
arena overhead.

Hadalis currently sets no `MALLOC_CONF`.

However this cannot be promoted as strict-lossless from source inspection:

- it changes allocator arena/reclamation/THP behavior;
- memory reduction can trade against allocation/reuse latency or CPU;
- it only matters when the running `qs` actually uses jemalloc;
- Hadalis supports different Quickshell builds.

In particular, Hadalis' custom WebEngine Quickshell build scripts explicitly
compile with:

`-DUSE_JEMALLOC=OFF`

so the DMS variable is ineffective for that build. Other distro/system
Quickshell packages may differ; dependency presence alone does not prove the
running binary uses jemalloc.

Safe experiment:

1. detect the allocator used by the **actual running qs process** first
   (binary linkage or process maps);
2. benchmark stock allocator settings vs the DMS policy only on jemalloc builds;
3. record idle and post-interaction PSS/RSS over time;
4. record shell CPU, allocation-heavy interaction latency and frame times;
5. exercise Settings, Overview/Task View, wallpaper changes, notification bursts,
   large launcher searches and repeated open/close cycles;
6. preserve a user-supplied `MALLOC_CONF`;
7. do not inject the setting on non-jemalloc builds.

Status:

**CONDITIONAL BENCHMARK / TRADEOFF**, not a strict-lossless default.

### 53.5 DMS's old redundant wallpaper-FBO pattern does not match current Hadalis — CLOSED / NOT APPLICABLE

DMS's same idle-RAM commit removed unconditional/manual
`currentWallpaper.layer.enabled` / `nextWallpaper.layer.enabled` toggling
around wallpaper transitions, eliminating redundant offscreen framebuffer
ownership in that implementation.

Current Hadalis `WallpaperCrossfader.qml` is materially different.

Its two wallpaper Image layers are enabled only when all of these are true:

- a transition is active;
- effects are enabled;
- transition type is `blurFade`;
- that Image is the outgoing slot.

The attached `MultiEffect` then performs the actual blur.

The ordinary crossfade/slide/wipe/etc. transitions do not retain those Image
layers.

Removing this conditional layer would remove the blur effect rather than merely
drop a redundant FBO.

Status: **CLOSED / NOT APPLICABLE**.

### 53.6 Noctalia confirms one Niri event-stream owner + internal fan-out; Hadalis already has this architecture — ALREADY

Current Noctalia's native Niri runtime owns one event-stream socket and fans
parsed events to its backend handlers. It keeps canonical workspace/window/output
state and uses a separate request path for actions.

The smaller `eww-niri-workspaces` and `system76-scheduler-niri` utilities
also keep one long-lived Niri event stream and mutate local state from events
instead of polling compositor snapshots continuously.

Current Hadalis already has the equivalent top-level transport architecture:

- one `eventStreamSocket` subscribed to `"EventStream"`;
- one resident `requestSocket` for typed Niri actions;
- `handleNiriEvent()` fans events into canonical shell state.

Do not create a generic "persistent Niri event socket" task.

Existing narrower Niri findings remain valid, especially §40.21 and §41.1-§41.7.

Status: **ALREADY**.

### 53.7 qml-niri demonstrates role-level/stable-object publication, but migrating Hadalis to it is an architecture change — NEEDS PROFILE / ARCHITECTURE, not a strict-lossless port

`qml-niri` provides a useful contrast to Hadalis' JavaScript-array publication
model.

Its native `WindowModel` is a `QAbstractListModel` of stable `Window`
objects:

- an existing `WindowOpenedOrChanged` mutates the existing object in place;
- only changed roles are emitted through targeted `dataChanged()`;
- a close removes one row;
- urgency/layout changes notify only the affected row/roles;
- full `WindowsChanged` remains an authoritative model reset;
- held QML window handles remain valid across ordinary updates.

Current Hadalis intentionally batches Niri window updates, but publication is
still:

`windows = nextWindows`

with a new JS array snapshot. Every binding depending on
`NiriService.windows` is therefore invalidated on each published batch even
when only one window title/focus/layout field changed.

This suggests a possible long-term direction if profiling shows QML invalidation
fan-out remains dominant **after** the confirmed local Round-27 optimizations.

It is not a strict-lossless port by inspection.

A stable model migration can change:

- object identity;
- `windowsChanged` notification semantics and ordering;
- atomic-snapshot behavior;
- consumer use of JS `.find/.filter/.map`;
- first-frame publication timing;
- sorting/reorder behavior;
- API shape for every Bar/Dock/Overview/Task View/background consumer;
- dependency/build/runtime surface if implemented as a native QML plugin.

Priority rule:

Implement/measure the narrower §41 Niri list/index/allocation reductions before
considering a canonical-model rewrite. If those remove the measured hot path,
do not add this architecture.

Status:

**NEEDS PROFILE / ARCHITECTURE**, not a current strict-lossless optimization.

### 53.8 Noctalia's incremental state maps reinforce existing Hadalis candidates rather than creating new ones — SUPERSEDED BY EXISTING BACKLOG

Noctalia maintains native maps such as:

- workspace id -> workspace state;
- window id -> window state;
- workspace id -> output.

It avoids recomputing occupancy when an event only changes unrelated layout
fields and resolves several lookups directly from canonical maps.

Those ideas are already represented more narrowly in the current Hadalis
research backlog:

- lazy/published window id map (§40.21);
- WindowLayoutsChanged id->index pass (§41.1);
- focused-window centralization (§41.6);
- demand-scoped active-workspace/workspaces-by-output derivation (§41.7);
- Task View workspace/window grouping (§41.9 and later).

Do not add parallel "copy Noctalia maps" tasks.

Status: **SUPERSEDED BY EXISTING BACKLOG**.

### 53.9 oniri's persistent workspace->window membership map is not preferable to the current strict-safe Hadalis candidate — CLOSED under current defaults

`oniri` implements essentially the same optional behavior as Hadalis'
`compositor.autoExpandSingleTilingWindow`: react when a workspace reaches
0/1/>1 tiling windows.

It maintains a persistent:

`workspace -> Vec<window_id>`

map incrementally from Niri events, making count decisions cheap.

For Hadalis that is not automatically the better optimization:

- the feature is disabled by default;
- the new retained index creates another state/invalidation contract;
- window moves require old/new workspace correctness;
- layout/floating changes and event ordering must stay synchronized;
- the existing §41.5 candidate needs no persistent state: scan until the second
  matching tiling window, then stop.

Under the strict no-hidden-tradeoff rule, keep §41.5 as the preferred first
optimization.

Status: **CLOSED as a new persistent-cache task under current defaults**.

### 53.10 `noctalia-niri-ribbon` is a useful negative example: event-driven wakeup with snapshot refetch is still process-heavy — DO NOT PORT

The ribbon helper starts one:

`niri msg -j event-stream`

process, but on each relevant event its recalculation calls
`get_niri_state()`, which launches three more commands:

- `niri msg -j windows`;
- `niri msg -j workspaces`;
- `niri msg -j outputs`.

Therefore it uses events only as invalidation signals, then refetches full
snapshots through subprocesses.

Hadalis' resident `NiriService` is already architecturally better for live
shell state.

This negative example reinforces two existing rules:

- consume authoritative event payloads/state when available;
- do not add compositor-query subprocesses merely because an event says
  "something changed".

Status: **DO NOT PORT**.

### 53.11 Round-39 conclusion

New work learned from the `awesome-niri` ecosystem:

**High-value new candidate:**

1. benchmark a direct Quickshell StringCall fast path for external
   `inir <target> <function>` / `inir ipc` calls, using the existing
   `inir-native` helper and retaining current `qs` behavior as the universal
   fallback (§53.1).

**Conditional resource experiment:**

2. jemalloc policy benchmark only on builds proven to use jemalloc; do not make
   it a default without memory + CPU/latency/frame-time evidence (§53.4).

**Already present in Hadalis:**

3. lazy QtMultimedia decoder construction in `VideoCrossfader` (§53.2);
4. lazy visual ownership for CloseConfirm (§53.3);
5. one Niri event-stream owner plus a resident action socket (§53.6).

**Architecture/reference only:**

6. stable native role-level Niri models from `qml-niri` (§53.7);
7. Noctalia incremental canonical maps (§53.8).

**Closed / not applicable / negative examples:**

8. DMS redundant wallpaper FBO removal does not match Hadalis' effect-required
   conditional layers (§53.5);
9. oniri's persistent workspace-window count cache is not justified for the
   default-disabled feature before the stateless §41.5 optimization (§53.9);
10. event-triggered triple `niri msg` snapshot refetch in
    `noctalia-niri-ribbon` is specifically a pattern Hadalis should avoid
    (§53.10).

No source/runtime implementation is authorized by this handoff.

---

## 54. Round 40 — Niri event classification and newer shell lifecycle cross-checks (2026-09-30)

### Snapshot / scope

Round 40 source inspection started from
`37cb85f10648b5d3fcbfb1e4869e856312b07250`
(`docs(perf): audit awesome-niri optimization sources`).

The exact-parent and post-write guards observed these concurrent automation-only
commits while Round 40 was being written:

- `6a0829db12aaf213fb05634cd6d8c5863558a282` —
  `automation: add deterministic chat bridge protocol`;
- `d0c21c4bf1b0da2039d80500ffe489310e9701f6` —
  `automation: add ChatGPT desktop CDP driver`;
- `cd60998ee4a06740454346eda46c0a56ebfc1ccc` —
  `automation: complete desktop response observation`;
- `45752e7fc7f99eb5e617ca67b50ff232ed62fb6f` —
  `automation: add deterministic desktop bridge CLI`.

Every observed concurrent changed-file set through `45752e7...` is confined
to `automation/*` and `scripts/test-hadalis-chat-bridge.py`. None touches
NiriService, AppSearch, popup/surface code, Bluetooth UI, external-IPC launcher
paths or the Round-40 findings. The research conclusions therefore remain
unchanged after those delta audits.

This remains **strict-lossless research only**. No runtime/source implementation
is authorized by this round.

New upstream references inspected include current `nirimap`,
`waybar-niri-windows`, `piri`, `vibepanel`, `ashell`, `Glimpse`,
and DMS PR #3081. The tempting workspace-sort removal remains closed by §46.3
and is not reopened here.

### 54.1 Focus-only Niri events can skip the generic order-diff pass entirely — CONFIRMED / P1

Path: `services/NiriService.qml`.

`handleWindowFocusChanged()` currently calls
`scheduleWindowsUpdate(currentList)`, and that generic scheduler runs
`_windowOrderDiffers(previousWindows, normalizedWindows)` unless an already
true dirty flag short-circuits the JavaScript `||`.

For a focus event, the only field `_normalizeWindowFocus()` can change is
`is_focused`. The current order-diff predicate does not inspect that field.
It inspects only list length/membership, `app_id`, `workspace_id`,
`is_floating`, and scrolling-layout column/row.

Therefore a `WindowFocusChanged` event cannot turn a previously-false
`_windowOrderDirty` true.

Exact-safe rule:

- preserve an already-true `_windowOrderDirty` from an earlier event in the
  same batch;
- normalize focus exactly as today;
- skip the new generic order-diff for this focus-only update.

This is stronger than §41.4's positional fast path: §41.4 can avoid the
temporary ID Map but still compares N windows. The focus-specific rule removes
the entire order-diff pass.

When the prior dirty flag is false, removed work is up to N Map inserts, N Map
lookups and N order-field comparison sets per focus event.

`nirimap` and `waybar-niri-windows` also model focus as a dedicated state
mutation rather than a layout/membership mutation. That is supporting evidence;
the lossless proof comes from Hadalis' own current diff predicate.

Required parity cases include focus A->B, focus->null, missing focused id,
title-only pending update then focus, order-changing pending update then focus,
focus followed by another order-changing event before publish, GameMode's
200 ms batch interval, and identical `windowOrderChanged` emission behavior.

### 54.2 The published-batch `activeWindow` lookup can be fused into the final sorted projection — CONFIRMED / P1-P2

Path: `services/NiriService.qml`.

Every dirty-batch publish currently:

1. calls `sortWindowsByLayout(_pendingWindows)`;
2. builds and sorts the enriched records;
3. maps every enriched record back to the final ordered window array;
4. assigns `windows = nextWindows`;
5. scans that array again with
   `nextWindows.find(window => window.is_focused)`;
6. assigns `activeWindow`.

The final projection in step 3 already visits every window in exactly the final
sorted order used by the later `.find()`.

A private snapshot helper can therefore return the same ordered array while
capturing only the first focused window during that existing projection.

Keep the public `sortWindowsByLayout()` array-returning contract unchanged:
the output-refresh path also calls it and currently does not republish
`activeWindow`.

The timer can assign `windows` first and `activeWindow` second exactly as
today, preserving the current notification order and first-focused semantics.

Local reduction per published dirty batch:

- extra post-sort focused-window visits: **N -> 0**.

This is separate from §41.6, which centralizes repeated consumer scans of the
already-published snapshot.

### 54.3 Niri event dispatch allocates an Object.keys array only to read one enum key — CONFIRMED / P3

Path: `services/NiriService.qml`.

Every parsed event begins with:

`const eventType = Object.keys(event)[0]`.

The object came directly from `JSON.parse()`; Niri's externally tagged event
enum supplies one variant key. A first-own-enumerable-key loop can preserve the
same property enumeration order and first-key behavior without allocating the
temporary keys array.

Do not replace it with a dispatch scheme that changes malformed multi-key
precedence; preserve "first enumerable own key wins".

Local reduction:

- temporary keys arrays: **1 -> 0 per Niri event**.

This is intentionally P3: exact and event-hot, but much smaller than the
N-window work in §54.1-§54.2.

### 54.4 GameMode rebuilds the same critical-event array for every Niri event — CONFIRMED / P2 conditional

Path: `services/NiriService.qml`.

While `GameMode.active`, every Niri event constructs the same 13-string
`criticalEvents` array and then calls `.includes(eventType)`.

An allocation-free helper/switch can return the exact same boolean for the same
string literals, removing both the per-event array allocation and linear
membership walk without retaining a mutable cache.

Keep the whitelist exactly unchanged. In particular `WindowsChanged` and
`WindowLayoutsChanged` must remain critical because the current code
documents that GameMode fullscreen-exit detection needs their size updates.

Status: **CONFIRMED / P2 conditional** because this cost exists only in
GameMode.

### 54.5 DMS supplies a real latency measurement for the direct Quickshell IPC candidate — EVIDENCE UPGRADE, still HIGH CONFIDENCE / benchmark

This strengthens §53.1; it does not turn the Hadalis candidate into a guaranteed
percentage.

DMS PR #3081, merged as
`c3fd526698e0bf04db7160389aaf83a911745abe`, reports a local
`spotlight toggle` benchmark:

- old `qs ipc call`: approximately **336 ms ± 130 ms**;
- direct Quickshell Unix socket: approximately **210.5 ms ± 88.7 ms**.

That is about **37.4% lower mean latency** in DMS' measured setup.

DMS commit `dce1095f8daeb60f30862e05305f94f88c39f1f7` separately
documents roughly 15 ms of CLI startup cost from one Go dependency
initialization, further supporting that short IPC commands can be dominated by
launcher/helper startup overhead.

Do not transfer 37.4% to Hadalis. DMS runs the socket client inside its compiled
Go CLI; Hadalis enters through Bash and the proposed fast path would normally
spawn the smaller `native/inir-native` helper. Bash/config/PID/helper startup
still remains.

Therefore §53.1 stays **HIGH CONFIDENCE / P1 benchmark + compatibility guard**.
The upstream number raises benchmark priority; it is not a Hadalis estimate.

### 54.6 nirimap's queue drain/coalescing is not a generic strict-lossless port for Hadalis — CLOSED as a blanket optimization

`nirimap` commit
`ce28bf670693e7db7c407f7e95b6be4397dca91d` drains its complete
pending IPC queue each UI tick, keeps only the latest repeated
`WindowChanged` per window, and lets a full-state snapshot supersede older
queued updates.

That is valid for nirimap's own state/publication contract, but Hadalis event
handlers can perform per-event work before the 50/200 ms window publish:

- MRU focus updates;
- workspace `active_window_id` maintenance;
- single-window-policy scheduling;
- `_windowOrderDirty` accumulation;
- pending-window state read by internal actions before publication.

Dropping or moving arbitrary intermediate events can therefore alter timing or
state even if the final published `windows` array matches.

A future narrow coalescer for one proven side-effect-free subtype may be studied
with explicit interleaving tests. There is no generic strict-lossless
"coalesce Niri events" task.

Status: **CLOSED as a generic port**.

### 54.7 vibepanel's popover surface-height freeze does not apply to the current connected Waffle BarPopup path — CLOSED for that path

`vibepanel` commit
`7c5c806a75b3664cd78dbdbd12b7f76f7d03ba83` freezes a
layer-shell popover's native height while a revealer animates, avoiding a
native surface resize every frame.

Current `modules/waffle/bar/BarPopup.qml` has a different contract:

- its `PanelWindow` is anchored top/bottom/left/right and covers the output;
- open/close animates `revealProgress`, not native window height;
- connected geometry, reveal clipping and the input mask animate inside that
  fixed output-sized surface.

So the current connected BarPopup does not contain the per-frame native
height-resize pattern vibepanel removed. Do not add a second freeze abstraction
there.

This conclusion is scoped to connected Waffle BarPopup. Detached tooltip,
context-menu or other popup surfaces should be profiled separately before a
broader claim.

Status: **CLOSED for current Waffle BarPopup**.

### 54.8 ashell's off-UI-thread icon-index warmup is architecture evidence, not a direct QML port — SUPERSEDED / ARCHITECTURE

`ashell` commit
`c863d5eb298d77d577a5a697fbb73f910e4207d6` warms native
filesystem icon/desktop indexes on a blocking worker only when an icon consumer
is active.

Hadalis' analogous work is at another layer:

- `AppSearch.qml` consumes Quickshell `DesktopEntries` QML objects;
- its reverse maps are built in QML by `_rebuildCache()`;
- moving those QML-object reads to a worker is not a local thread-safe
  substitution;
- publication timing/binding constraints are already documented in §38.5 and
  §40.14;
- local normalization/preparation reductions already exist in §40.1-§40.3.

Do not create a generic "move AppSearch cache build to worker thread" task from
ashell. A native catalog/index service would be an architecture change requiring
profile evidence after the existing local AppSearch work.

Status: **SUPERSEDED / ARCHITECTURE**.

### 54.9 Glimpse exposes a Bluetooth discovery ownership bug class in Hadalis, but fixing it is not a lossless optimization — OUT OF STRICT-LOSSLESS SCOPE

`Glimpse` commit
`45475432682217a3de0344c91d8a00598aaf97cf` changed Bluetooth
discovery to claim-based ownership: BlueZ Start/Stop occurs only on transitions
between zero and one-or-more active claims.

The comparison uncovered a current Hadalis lifecycle issue:

- Waffle `BluetoothControl.qml` sets global
  `Bluetooth.defaultAdapter.discovering` on construction/destruction;
- both right-sidebar variants set the same global property when their Bluetooth
  dialog opens/closes;
- unexpectedly, Waffle `NightLightControl.qml` imports
  `Quickshell.Bluetooth` and also starts/stops Bluetooth discovery on its own
  lifecycle despite being an eye-protection page.

Discovery ownership is therefore not centralized. One surface can stop scanning
while another logical owner still wants it, and Night Light can trigger
unrelated Bluetooth scanning.

A claim/refcount service and removal of the Night Light side effect are
plausible correctness fixes, but both alter current externally observable
Bluetooth behavior. They must not be counted or implemented as strict-lossless
performance work.

Status: **OUT OF STRICT-LOSSLESS SCOPE — correctness/lifecycle follow-up only**.

### 54.10 Round-40 conclusion

New strict-lossless findings:

1. skip the complete generic window-order diff for focus-only Niri events
   (§54.1, **CONFIRMED / P1**);
2. capture `activeWindow` during the existing final sorted projection
   (§54.2, **CONFIRMED / P1-P2**);
3. remove the per-event `Object.keys(event)` temporary array
   (§54.3, **CONFIRMED / P3**);
4. remove the per-event constant GameMode critical-event array/membership scan
   (§54.4, **CONFIRMED / P2 conditional**).

Evidence upgrade:

5. DMS reports about **37.4% lower mean latency** for its direct Quickshell IPC
   benchmark, strengthening Hadalis' guarded §53.1 benchmark priority without
   implying the same percentage (§54.5).

Closed / architecture / non-lossless findings:

6. no generic nirimap event coalescing (§54.6);
7. no vibepanel height-freeze layer for the already output-sized connected
   Waffle BarPopup (§54.7);
8. no worker-thread port of QML `DesktopEntries` cache construction merely
   from ashell's native-index design (§54.8);
9. Bluetooth discovery ownership/Night Light side effects require correctness
   review but are excluded from strict-lossless optimization (§54.9).

No source/runtime implementation is authorized by this handoff.

---

## 55. Round 41 — Bar utility derivation, AI model partition and mic-state duplication (2026-09-30)

### 55.1 Bar UtilButtons recomputes the same active utility set/index for every delegate — CONFIRMED / P1-P2

Path:

- `modules/bar/UtilButtons.qml`.

The default utility order has 11 ids.

Current derivation is split across:

- `visibleUtilityCount`, which filters the full order through
  `utilityActive(id)`;
- each Loader's `active` binding, which calls `utilityActive(id)` again;
- `utilityIndex(id)`, which filters the **full utility order again** through
  `utilityActive(candidate)`, allocates that filtered array, then calls
  `.indexOf(id)`;
- every utility delegate has one selected-axis layout binding that calls
  `utilityIndex()` (row in vertical mode or column in horizontal mode).

The source contains 11 utility delegates and 22 row/column textual
`utilityIndex()` call sites; because the ternary selects only one axis at a
time, one index calculation per delegate is active for a given orientation.

A full-shaped reevaluation can therefore perform roughly:

- 11 `utilityActive()` calls for the count;
- 11 direct Loader-active calls;
- 11 x 11 `utilityActive()` calls inside the 11 index filters;

or about **143 utilityActive evaluations**, plus 11 temporary filtered arrays,
to derive one 11-item layout.

Exact-safe direction:

1. build one reactive `utilityLayout` snapshot from the existing
   `utilityOrder`;
2. traverse ids in the exact current order;
3. call the existing `utilityActive(id)` once per id;
4. store the enabled boolean and, for enabled ids, the current compact index;
5. expose count from the same snapshot;
6. make Loader-active and row/column index bindings read that snapshot.

Preserved behavior:

- the existing `utilityActive()` rules and all config/service dependencies;
- configured utility order;
- disabled-item omission;
- compact indices of enabled items;
- inactive/unknown index fallback to 0;
- vertical/horizontal placement;
- no public component API change is required.

Worst-shaped utility predicate work becomes approximately:

**143 -> 11**

for the current 11-item order, about **92.3% fewer predicate evaluations**,
while eliminating the per-delegate filtered-array allocations.

Do not replace the predicate rules themselves in this optimization; centralize
only the repeated derivation.

### 55.2 UtilButtons owns one completely unused mic-in-use binding — CONFIRMED / P3

Path:

- `modules/bar/UtilButtons.qml`.

The mic Loader declares:

`readonly property bool micInUse: Privacy.micActive || (Audio?.micBeingAccessed ?? false)`

but no expression in that Loader references `micInUse`.

The Loader's `active` state calls `root.utilityActive("mic")`, and the actual
button separately declares its own `isInUse` binding.

Therefore the Loader-level `micInUse` property contributes no visual,
accessibility, action or layout value.

Removing only that unused property is strict-lossless and also removes one
otherwise-live dependency on both mic-state properties.

Status: **CONFIRMED / P3**. It is small and composes with §55.1.

### 55.3 AI computes runnable and locked model lists with two complementary full scans — CONFIRMED / P1-P2

Path:

- `services/Ai.qml`.

Current properties are:

`runnableModelList = modelList.filter(id => modelCanRun(models[id]))`

and:

`lockedModelList = modelList.filter(id => !modelCanRun(models[id]))`.

`modelCanRun()` is pure in the current source: it checks policy/local status
and, when needed, keyring/public-credential state.

The two lists are exact complements over the same ordered `modelList`.

A single reactive partition pass can therefore:

1. iterate `modelList` once in its existing order;
2. resolve `model = models[id]`;
3. call `modelCanRun(model)` once;
4. append the id to either runnable or locked;
5. publish the two arrays from that partition.

Preserved behavior:

- `modelList` order inside each result;
- every id appears in exactly one of the same two lists as today;
- policy and keyring dependencies remain reactive;
- public `runnableModelList` / `lockedModelList` APIs remain arrays;
- repository search found no `onRunnableModelListChanged` or
  `onLockedModelListChanged` side-effect handler.

For M models:

- model-list visits: **2M -> M**;
- `modelCanRun()` calls: **2M -> M**;
- approximately **50% fewer** model eligibility evaluations.

This becomes more valuable as live provider catalogs increase model count.

### 55.4 Privacy and Audio independently scan the exact same PipeWire links for microphone use — HIGH CONFIDENCE / signal-parity required

Paths:

- `services/Privacy.qml`;
- `services/Audio.qml`;
- `modules/bar/UtilButtons.qml`;
- `modules/waffle/bar/SystemButton.qml`.

`Privacy.micActive` and `Audio.micBeingAccessed` currently contain the exact
same `Pipewire.links.values.some(...)` predicate.

The checked-in consumers then OR those two equivalent booleans together.

Steady-state value duplication is therefore clear: when both singletons are
instantiated, the same PipeWire link list can be scanned twice for the same
answer, and Bar consumers can read both results repeatedly.

However this round does **not** promote a shared property/alias as absolute
lossless yet.

Reason: §49.11 established the stricter rule that QML reactive publication and
signal timing count as behavior. Replacing two independently bound properties
with one upstream binding/alias can change dependency and changed-signal
ordering even when steady-state booleans are identical.

Required parity before promotion:

1. mic stream appears;
2. mic stream disappears;
3. unrelated PipeWire link insert/remove;
4. source/target object becomes temporarily null during PipeWire churn;
5. Bar and Waffle indicators change on the same frame as today;
6. no consumer relies on `Privacy.micActiveChanged` timing;
7. extension/public singleton compatibility remains intact.

Status:

**HIGH CONFIDENCE / benchmark + signal-parity test**, not yet Confirmed.

Do not delete the public `Privacy` singleton merely because checked-in
consumers are currently narrow.

### 55.5 Round-41 conclusion

New strict-lossless candidates:

1. one reactive Bar utility-layout snapshot instead of repeated full
   `utilityActive/filter/indexOf` derivation (§55.1, **CONFIRMED / P1-P2**);
2. remove the unused Loader-level mic-in-use binding (§55.2,
   **CONFIRMED / P3**);
3. partition AI model ids into runnable/locked in one pass (§55.3,
   **CONFIRMED / P1-P2**).

Not yet promoted:

4. centralize the duplicate Privacy/Audio PipeWire mic-use scan only after
   reactive signal/frame parity is proven (§55.4).

The Audio four-way node partition remains closed as a blind optimization under
§49.11; Round 41 does not reopen it.

No runtime/source implementation is authorized by this handoff.
---

## 56. Round 42 — collection/allocation cleanup, new confirmation-path audit and upstream re-check (2026-09-30)

### Snapshot / concurrency safety

Research began from dev at bff6e035586e40076631fe193fd1f582969cc475.

Before this round was written, dev advanced first by 10 commits to
a53b71905d02cf6c177ef7313a58e03bebfa4eb8, then by another 8 commits to
3852876957f6987e200d0dfcc676369c70a5c38b.

Both compares were clean fast-forwards from the research snapshot. The first
delta changed the automation bridge, confirmation/popup ownership and a small
set of Abyss/Bar/Dock files. The second delta was automation/agent work plus one
PopupAnchorRegistry update. Neither delta touched these candidate source paths:
services/AppCatalog.qml, services/ScreenTime.qml,
services/MprisController.qml, services/RecorderStatus.qml,
services/ai/OpenAiApiStrategy.qml, services/Brightness.qml or
services/ai/AiProviderCatalog.qml.

The first delta did add services/ConfirmationService.qml, so that new service
was audited on the new HEAD rather than ignored. The second delta did not modify
it. Sections 56.8 and 56.9 are findings from that concurrent source.

No runtime/source implementation is authorized by this round.

### 56.1 AppCatalog can fuse category + text filtering only when both are active — CONFIRMED / P2 while SoftwareView search is active

Path:

- services/AppCatalog.qml.

Current filteredCatalog keeps an important zero-filter fast path: with category
"all" and an empty search query it returns root.catalog itself.

When both a non-all category and a non-empty query are active, however, it
currently executes two consecutive filters:

1. filter the full catalog by category, producing an intermediate category
   array;
2. filter that intermediate array by name/description/tags.

An exact-safe specialization is to fuse only that two-condition case into one
filter whose category check short-circuits before the existing text predicate.
The one-condition and zero-condition cases should remain unchanged.

Proof of losslessness:

- the catalog is loaded from JSON into plain records;
- output order remains source catalog order;
- an app failing the category test is still never evaluated by the text test;
- every app passing category sees the exact same name/description/tag
  predicate;
- the no-filter path still returns the original root.catalog reference;
- the existing read of root.installedPackages must remain even though its local
  value is not otherwise used, because it intentionally keeps the binding
  dependent on installed-state publication;
- no sort/tie/publication/action behavior changes.

Exact local saving when both filters are active:

- filter loops: 2 -> 1 outer traversal;
- intermediate category-result array: 1 -> 0;
- category predicate evaluations remain N;
- text predicate evaluations remain C, where C is the category-matching count.

This is an allocation/traversal win, not a claim of a fixed percentage for the
whole shell.

### 56.2 ScreenTime history merge can trim each raw section once and skip the filter array — CONFIRMED / P2 on history load

Path:

- services/ScreenTime.qml, _mergeDays().

Current code splits on "---DELIM---", filters with repeated trim calls, then
calls trim() again on every retained section immediately before JSON.parse().

An exact-safe loop is:

1. keep the same delimiter and split order;
2. trim each raw section once;
3. continue for the same empty-string and "{}" cases;
4. JSON.parse the already-trimmed string inside the same per-section try/catch;
5. keep all existing merge order, AppSearch fallback lookup and hourly
   accumulation logic untouched.

Proof of losslessness:

- trim is a pure string operation;
- the skip predicates are identical after trimming;
- retained JSON text is byte-for-byte the same string currently passed to
  JSON.parse after the extra trim;
- malformed JSON is still ignored by the same per-section catch;
- section processing order and all accumulation order remain unchanged.

Exact local saving:

- retained-section filter result array: 1 -> 0;
- for a normal non-empty, non-"{}" section, trim calls: 3 -> 1;
- for "{}" sections, trim calls: 2 -> 1;
- split-array creation remains unchanged.

The 3 -> 1 trim reduction is local to qualifying history sections and must not
be converted into an end-to-end Hadalis percentage without measurement.

### 56.3 MPRIS duplicate filtering performs a guaranteed-redundant final falsy filter — CONFIRMED / P2

Path:

- services/MprisController.qml, _filterYtMusicDuplicates().

The classification loop currently pushes every input value into either
ytMusic or nonYtMusic. _isYtMusicRelated() immediately returns false for a
falsy player, so every falsy value can only enter nonYtMusic.

Later the function builds the concatenated player list and filters it again only
for truthiness.

Exact-safe direction:

- add the same falsy guard at the top of the existing classification loop;
- do not append a falsy player to either bucket;
- keep all YtMusic classification/preference logic unchanged;
- form allPlayers directly from the two already-clean buckets, without the
  trailing truthiness filter.

Proof of losslessness:

- _isYtMusicRelated() has no side effect before its existing !player return;
- falsy values never enter ytMusic today;
- the final allPlayers sequence for every truthy player is unchanged;
- YtMusic-first ordering and non-YtMusic relative order are unchanged;
- duplicate grouping, title/position/URL matching and cover-art choice remain
  untouched;
- no preference .find() rewrite is included here.

Exact local saving per dedupe rebuild:

- one full allPlayers truthiness scan -> 0;
- one filter result array allocation -> 0.

This path is rebuilt on player lifecycle/state/metadata changes, so it has
better frequency than the one-shot setup candidates in this round.

### 56.4 RecorderStatus can derive fastDemandCount while rebuilding the owner snapshot — CONFIRMED / P3

Path:

- services/RecorderStatus.qml, setFastStatusDemand().

The function already rebuilds a new owner object from current owners whose
value is exactly true. After publishing that new object it currently performs a
second Object.keys(next).length solely to compute fastDemandCount.

Count the copied true owners during the existing rebuild instead, then adjust
that local count for the requested add/remove.

Important parity requirements:

- keep the current early return when alreadyActive === active;
- continue dropping any non-true stray values during a real rebuild;
- for activation, increment only after adding the requested owner;
- for deactivation, the requested owner is known true, so copy it, delete it
  exactly as today, and decrement the local count;
- publish root._fastDemandOwners first and root.fastDemandCount second, in the
  current order;
- do not replace the count with old fastDemandCount +/- 1 because that would
  lose the current self-healing behavior if the private map/count ever became
  inconsistent.

Exact local saving for every actual ownership change:

- second Object.keys(next) temporary key array: 1 -> 0;
- second full next-object key traversal: K -> 0.

The first current-owner traversal remains because it performs the snapshot
rebuild itself.

### 56.5 OpenAI streamed tool-call flush can preserve first-key semantics without materializing Object.keys — CONFIRMED / P3

Path:

- services/ai/OpenAiApiStrategy.qml, flushPendingToolCall().

Current code allocates all pending keys with Object.keys(pendingToolCalls), then
consumes only the first key before clearing pendingToolCalls.

An exact-safe replacement is to obtain the first own enumerable key with an
allocation-free enumeration loop, guarded with
Object.prototype.hasOwnProperty.call(...), and break immediately.

Why this is strict-lossless for the current ordinary object:

- pendingToolCalls is initialized and reset to {};
- tool-call indexes are written as ordinary enumerable own properties;
- ordinary own-property enumeration preserves the same integer-key-first then
  string-key order used by Object.keys;
- inherited enumerable properties are explicitly ignored by the own-property
  guard;
- empty input still returns {};
- multi-index input still flushes only the same first key and then resets the
  whole pending object, preserving the current first-call behavior rather than
  "fixing" it.

Exact local saving per flush boundary:

- full keys array allocation: 1 -> 0;
- for non-empty input, key enumeration can stop after the first own key instead
  of materializing all K keys.

This is analogous to the already-confirmed Niri event first-key cleanup in
§54.3, but it is a separate source path and publication contract.

### 56.6 Brightness monitor reconciliation can use retained-object membership instead of repeated next.includes scans — CONFIRMED / P3 topology path

Path:

- services/Brightness.qml, _syncMonitors().

After constructing next, the current cleanup loops prev and runs next.includes(m)
for every previous monitor before destroying disconnected objects.

Build an invocation-local Set of the monitor objects retained in next and use
retained.has(m) during the existing prev-order destruction loop.

Proof of losslessness:

- membership is object identity in both Array.includes and Set.has;
- duplicate references in next, if malformed screen naming ever produces them,
  still have the same boolean membership result;
- root.monitors publication stays before destruction;
- prev iteration/destruction order remains unchanged;
- creation/reuse matching and existing.screen reassignment are untouched;
- no monitor lifecycle timing is otherwise moved.

For P previous monitors and N next monitors, the membership portion changes
from up to P x N identity comparisons to N Set inserts plus P membership
lookups.

Monitor counts are usually small, so this is deliberately P3 and no
end-to-end percentage is claimed.

### 56.7 Brightness DDC block parsing can avoid map(trim) plus two independent find scans — CONFIRMED / P3 probe path

Path:

- services/Brightness.qml, ddcProc stdout SplitParser.

For each ddcutil display block the current parser:

1. splits on newline;
2. maps trim over all lines, creating a second line array;
3. finds the first "Monitor:" line;
4. independently finds the first "I2C bus:" line.

A single loop over the split lines can trim each visited line once, retain the
first line for each exact prefix, and stop after both have been found.

Proof of losslessness:

- the same first matching Monitor and I2C lines are selected;
- whitespace normalization is the same trim();
- malformed-block warning behavior remains the same if either field is absent;
- subsequent model/bus parsing, numeric validation, _ddcNext append order and
  ddcMonitors publication are untouched;
- lines after both required records currently have no semantic use.

Exact local saving per parsed display block:

- trimmed-lines map result array: 1 -> 0;
- two prefix-search traversals -> one combined traversal;
- each visited line is trimmed once.

This is demand/topology probe work, not a permanent polling-hot-path claim.

### 56.8 ConfirmationService default selection can retain first-default / first-fallback in one pass — CONFIRMED / P3

Path:

- services/ConfirmationService.qml, newly added in the concurrent delta.

defaultActionId() currently performs two finds:

1. first usable action marked isDefault or role "default";
2. first usable action that is not a cancel action.

One pass can retain the first usable non-cancel fallback while scanning and
return immediately on the first usable preferred action.

Proof of losslessness:

- normalized actions are plain snapshots created by Object.assign in
  _normalizeActions();
- _actionUsable() remains unchanged;
- preferred priority remains absolute over fallback priority;
- first preferred action in list order still wins;
- if no preferred action exists, the first usable non-cancel action in list
  order still wins;
- empty/no-usable input still returns "";
- no queue state, callback execution or publication timing moves.

Worst-case action visits when no preferred action exists:

- up to 2A -> A.

Confirmation action lists are intentionally small, hence P3 despite the clean
proof.

### 56.9 ConfirmationService duplicate action-ID normalization can use a Set — CONFIRMED / P3

Path:

- services/ConfirmationService.qml, _normalizeActions().

The newly-added normalizer stores used IDs in an array and executes
usedIds.includes(id) inside the duplicate-suffix loop.

All IDs have already been converted to strings, so a Set can preserve the
exact same membership contract:

- requested non-empty ID remains the base;
- empty ID still becomes action-<index>;
- duplicate suffix sequence still starts at 2 and advances until unused;
- first action keeps the unsuffixed ID;
- output action order and labels are unchanged.

For A actions, membership lookup changes from a growing linear scan to Set
membership. The worst-shaped unique-ID bookkeeping changes from quadratic
comparison growth to linear inserts/lookups, while duplicate suffix iterations
themselves remain exactly as required by the existing naming contract.

Status: CONFIRMED / P3 because action lists are normally tiny.

### 56.10 AiProviderCatalog count bindings can count directly instead of materializing throwaway arrays — CONFIRMED / P2 allocation cleanup

Path:

- services/ai/AiProviderCatalog.qml.

Four public numeric bindings currently materialize arrays only to take length:

- freeModelCount uses models.filter(...).length;
- localModelCount uses models.filter(...).length;
- healthyProviderCount uses Object.values(providerStates).filter(...).length;
- browseableProviderCount uses
  Object.values(providerStates).filter(...).length.

Do not centralize these four properties into one shared reactive stats object in
this optimization; that could change dependency/signal publication structure.

Instead, keep each existing public binding independent and count matches with a
local loop.

Proof of losslessness:

- each property still depends directly on the same root models or
  providerStates property;
- predicates are identical;
- counts are order-independent;
- models are normalized catalog records;
- providerStates is replaced with a fresh plain object by _setProviderState(),
  so a guarded own-key loop observes the same published snapshot;
- each public property remains an int with its own existing changed signal;
- no model/provider list ordering or catalog publication changes.

Exact local saving across one reevaluation of all four counters:

- free/local filter-result arrays: 2 -> 0;
- healthy/browseable Object.values arrays: 2 -> 0;
- healthy/browseable filter-result arrays: 2 -> 0;
- total throwaway arrays across the four counters: 6 -> 0.

The model/provider scans remain; combining those scans is a separate reactive
signal-parity question and is intentionally not claimed here.

### 56.11 Piri raw-window / batched-action performance work does not create a new strict-lossless Hadalis process-spawn win — ALREADY / CLOSED

External evidence inspected:

- Asthestarsfalll/piri commit
  591049763c2803b758d047872e155c96a9615284.

That change includes two relevant ideas:

1. keep raw Niri windows to avoid repeated workspace-name remapping;
2. send multiple related Niri actions over one socket/blocking task.

For current Hadalis:

- NiriService already keeps/publishes the Niri window snapshot itself rather
  than rebuilding a workspace-name projection for every consumer;
- NiriService.send() already writes actions to a resident requestSocket;
- normal shell actions therefore do not spawn niri msg per action.

So piri's action batching is not transferable as a process-spawn elimination.
Bundling multiple Hadalis requests could also change compositor request/event
interleaving and observable timing.

Status:

- raw-window idea: ALREADY / architecture evidence;
- blanket action batching: CLOSED for strict-lossless without a narrower
  request-sequence proof.

### 56.12 Latest iNiR LiveLayer/sourceSize work is already covered; do not duplicate Round 38 — SUPERSEDED

Re-checked upstream commits:

- 7433eb355cff8c5f55ba910d31c294f4f91479b6 — moving continuous content to a
  small surface;
- 714653592dde75aef1d072c23ba507603acace2a — decode wallpaper at draw size.

The handoff already covers these exactly:

- §52.1: LiveLayer is a real compositor-damage optimization but needs
  visual/stacking/compositor parity and benchmark;
- §52.2: output-sized static wallpaper decode is already present in Hadalis.

No new optimization is counted here.

### 56.13 Wallhaven Commons map fusion is deliberately closed under malformed-response strictness

Path:

- services/Wallhaven.qml, Commons response mapping.

The expression that first maps page keys to page objects and then maps page
objects to normalized image records looks like an obvious intermediate-array
removal.

However the second callback currently contains a fallback that references key,
even though key belongs to the first callback and is not in scope there.

A natural fused rewrite would bring the real page key into scope and therefore
change malformed-response/error behavior when pageid is absent. That would be a
correctness fix as well as an allocation change.

Because strict-lossless includes malformed/fallback/error behavior, this round
does not count or authorize that fusion.

Status: CLOSED as a strict-lossless optimization until the correctness contract
is handled separately.

### 56.14 Round-42 conclusion

New strict-lossless findings:

1. AppCatalog category + text filter fusion only for the two-filter case
   (§56.1, CONFIRMED / P2);
2. ScreenTime one-trim-per-section history merge without the filter array
   (§56.2, CONFIRMED / P2);
3. remove MPRIS's guaranteed-redundant final falsy-player filter
   (§56.3, CONFIRMED / P2);
4. derive RecorderStatus fastDemandCount during the existing owner rebuild
   (§56.4, CONFIRMED / P3);
5. flush the first pending OpenAI tool-call key without Object.keys allocation
   (§56.5, CONFIRMED / P3);
6. use retained-monitor identity membership for Brightness reconciliation
   (§56.6, CONFIRMED / P3);
7. parse each DDC display block in one trimmed-line pass (§56.7,
   CONFIRMED / P3);
8. select ConfirmationService preferred/fallback default action in one pass
   (§56.8, CONFIRMED / P3);
9. use Set membership for ConfirmationService action-ID normalization
   (§56.9, CONFIRMED / P3);
10. count AiProviderCatalog model/provider states without throwaway arrays
    (§56.10, CONFIRMED / P2).

Not counted as new optimizations:

11. piri raw-window/action-batching ideas are already present or do not map to a
    strict-lossless process-spawn win (§56.11);
12. latest iNiR LiveLayer/sourceSize work is already covered by §52
    (§56.12);
13. the tempting Wallhaven Commons two-map fusion is closed because the natural
    rewrite would also change malformed fallback/error behavior (§56.13).

No percentage above is an end-to-end Hadalis speedup. Every numeric reduction
is a source-proven local operation/allocation count unless explicitly stated
otherwise.

No runtime/source implementation is authorized by this handoff.
---

## 57. Round 43 — launcher/search hot paths, local Niri derivation and reintroduced Confirmation audit (2026-09-30)

### Snapshot / concurrent reconciliation

This round started from dev at
`a664517ef70f0d4711724c450490546139558902`.

Before write, dev advanced first to
`9d2de679b8db89e39a397829e2913b8565f73ad6` and then to
`a106b27940f8e89a59b89caefcfa9fb7e62f19be`.

Both compares are clean fast-forwards. The concurrent delta contains only
automation queue/result records plus a chat-bridge test adjustment. It does not
touch any source path audited below or this handoff. Candidate source
conclusions were therefore reconciled unchanged against the new exact parent.

No runtime/source implementation is authorized by this round.

### 57.1 WidgetPowerManager can derive active workspace membership without two temporary arrays or nested linear membership — CONFIRMED / P2 conditional

Path:

- `services/WidgetPowerManager.qml`, `_hasWindowsOnActiveWorkspace()`.

Current function-local work is:

1. `Object.values(NiriService.workspaces)` -> one array of all workspace objects;
2. `.filter(...is_active/output...)` -> a second array;
3. for every candidate non-minimized window, run
   `activeWorkspaces.some(workspace => workspace.id === window.workspace_id)`.

This is distinct from §40.20, which proposes memoizing the complete answer
across callers/snapshots. This section is a narrower single-call reduction and
adds no persistent cache.

Exact-safe direction:

- enumerate the current workspace snapshot once;
- retain active/output-matching workspace ids in a local `Set`;
- preserve the false return when that Set is empty;
- scan windows in current order with the exact minimized predicate;
- replace nested workspace `.some()` with `activeIds.has(window.workspace_id)`;
- retain existing compositor guards and try/catch;
- use an own-property guard so enumeration matches `Object.values()`.

Proof:

- result is only a boolean;
- active-workspace order is unobservable;
- duplicate workspace ids have the same membership truth value;
- the window scan and first-success return remain in the same order;
- no service property, signal or persistent cache is introduced.

For W workspaces, A active/matching workspaces and N windows:

- temporary workspace arrays: **2 -> 0**;
- nested membership comparisons: up to **N x A -> N Set.has()** after W workspace visits.

This matters only when
`background.widgets.powerSaving.pauseWhenWindowsPresent=true`, so priority is
conditional.

### 57.2 GameMode fullscreen queries have two exact local lookup/allocation reductions — CONFIRMED / P2-P3

Path:

- `services/GameMode.qml`.

These refine the current per-call path and compose with the older §40.16 memo
candidate.

#### A. Reuse the workspace already resolved by hasFullscreenOnOutput() — CONFIRMED / P2

`hasFullscreenOnOutput()` resolves
`NiriService.workspaces?.[w.workspace_id]` to test active/output membership.
For a candidate that passes, it calls `isWindowFullscreen(w)`. On the
size-based fallback path, that function resolves the same workspace key again.

Strict-safe direction:

- keep public `isWindowFullscreen(window)` as the compatibility wrapper;
- use a private helper that can receive an already-resolved workspace;
- preserve early returns for null/non-Niri, explicit `is_fullscreen`, and
  missing `window_size`;
- from `hasFullscreenOnOutput()`, pass the workspace already read;
- all other callers use the wrapper exactly as today.

One duplicate workspace-map lookup disappears for each candidate that reaches
the geometry fallback after active/output filtering.

#### B. Single-output fallback does not need Object.values() — CONFIRMED / P3 conditional

When workspace -> output resolution is temporarily missing,
`isWindowFullscreen()` materializes
`Object.values(NiriService.outputs ?? {})` solely to accept the value when
there is exactly one output.

An own-property loop can retain the first output and stop at the second.

Parity:

- zero outputs -> no fallback;
- exactly one -> same sole output;
- two or more -> no fallback;
- logical-size comparison and 2px tolerance remain unchanged.

Local saving on this race path:

- output-values array: **1 -> 0**;
- enumeration can stop at the second output.

### 57.3 LauncherSearch clipboard and emoji branches perform guaranteed-redundant truthiness filters — CONFIRMED / P2 during prefixed search

Path:

- `services/deferred/LauncherSearch.qml`.

Both Clipboard and Emoji prefix branches:

1. request at most 24 source entries;
2. map every entry to a result object;
3. call `.filter(Boolean)`.

Neither map callback has a falsy return path.

Therefore the filter cannot remove an item.

Strict-safe change:

- return the mapped array directly;
- keep source limits, result fields, closures, icons/types and ordering unchanged.

Per prefixed query:

- one full truthiness pass over up to 24 results -> 0;
- one filtered-array allocation -> 0.

### 57.4 LauncherSearch action results can be collected directly into the unpublished result array — CONFIRMED / P1-P2 during launcher search

Path:

- `services/deferred/LauncherSearch.qml`.

Current ordinary-query action work:

1. `root.allActions.map(...)` returns a result object or null for every action;
2. `.filter(Boolean)` allocates the matching subset;
3. `result = result.concat(actionResults)` allocates/copies another array.

The local `result` has not yet been published.

Exact-safe direction:

- iterate `root.allActions` once in current order;
- compute the same `actionStr`;
- skip on the same two prefix predicates;
- construct the same result object only for matches;
- push it directly into local `result`.

Proof:

- action evaluation and matching order are unchanged;
- closure creation still occurs only for matches;
- existing app/math/shell/web results stay before action results;
- no intermediate local mutation is externally published.

For A actions and M matches:

- A-element map array: **1 -> 0**;
- M-element filtered array: **1 -> 0**;
- subsequent concat result copy: **1 -> 0**;
- predicate visits remain A.

This is separate from §48.5, which optimizes the scorer inside
`GlobalActions.fuzzyQuery()`.

### 57.5 TaskbarApps string-sequence normalization can eliminate the second result array without changing Array.from semantics — CONFIRMED / P3

Path:

- `services/TaskbarApps.qml`, `_stringArray()`.

Current code intentionally supports Config's QML sequence with:

`Array.from(value, normalize).filter(nonempty)`.

Do not replace Array.from with assumptions about QML iterator behavior.

Strict-safe reduction:

1. keep the current `Array.from(value, item => String(...).trim())`;
2. compact that fresh JS Array stably in place with a read/write cursor using
   the same `item.length > 0` predicate;
3. set the final length and return the same array.

This preserves Array.from sequence semantics, normalized values and order.

Exact saving:

- second filter result array: **1 -> 0**;
- normalization array and second predicate traversal remain.

The helper is used for pinned apps and ignored regex strings on taskbar rebuilds,
plus pin mutation.

### 57.6 Cliphist superpaste can stop after the requested prefix and build reverse commands without clone/reverse/map — CONFIRMED / P2 action path

Paths:

- `services/deferred/Cliphist.qml`;
- checked-in caller: `services/GlobalActions.qml`.

Current `superpaste(count, isImage)`:

1. filters the full clipboard history (service cap: 400);
2. slices the first `count` matches;
3. clones the bounded array with spread;
4. reverses the clone;
5. maps it to command strings.

`entryIsImage()` is pure string/regex classification.

The checked-in GlobalActions caller passes a non-negative integer parsed from
decimal digits.

Strict-safe contract:

- for the normal non-negative-integer path, scan source entries in order and
  stop when `count` matches have been collected;
- `count === 0` yields the same empty command list without running a pure
  classifier;
- for unsupported direct-call count shapes (negative/non-integer), retain the
  current filter/slice compatibility path;
- build command strings by iterating the selected entries from last to first and
  pushing them, rather than clone + reverse + map;
- do not mutate selected entries.

Preserved behavior:

- same first K matches;
- same reverse execution order;
- same `wlCopyCommand()`, delay and paste-key strings;
- same one detached Bash process.

Normal-path saving:

- full-history filter result becomes a bounded K-entry collection;
- K-entry slice array -> 0;
- K-entry reverse clone -> 0;
- image mode can stop at the K-th match instead of classifying the remainder.

### 57.7 Events and CalendarSync upcoming sorts can reuse start timestamps parsed during the same invocation — CONFIRMED / P2

Paths:

- `services/Events.qml`, `getUpcomingEvents()`;
- `services/CalendarSync.qml`, `getUpcomingEvents()`.

Both functions parse each event's start date during filtering, then sort retained
event references with comparators that create two new Date objects per
comparison.

Exact-safe direction:

- keep returned arrays as the original event references;
- during current filtering/collection, save the exact raw start timestamp number
  in an invocation-local Map keyed by event object;
- sort retained events using
  `startTimes.get(a) - startTimes.get(b)`.

CalendarSync parity detail:

- its all-day filter mutates local `start` to midnight;
- the current sort parses raw `event.startDate`;
- therefore capture raw `start.getTime()` before the midnight mutation.

Parity:

- filter predicates/membership unchanged;
- comparator numeric values unchanged;
- equal timestamps still return 0;
- invalid timestamps still produce NaN subtraction;
- same Array.sort receives the same event sequence, preserving existing
  tie/stability behavior.

For C comparator calls:

- comparator Date constructions: **2C -> 0**;
- one invocation-local timestamp Map is added and discarded before return.

### 57.8 Wallpaper search wildcard construction can remove filter/map intermediate arrays — CONFIRMED / P2-P3 while searching

Path:

- `services/Wallpapers.qml`, `FolderListModelWithHistory.nameFilters`.

Ordinary search currently computes:

`query.split(" ").filter(nonempty).map(segment => "*" + segment + "*").join("")`.

Strict-safe direction:

- keep current `trim().toLowerCase()`;
- keep valid `.ext` shortcut unchanged;
- keep literal-space splitting semantics exactly; do not change to `/\s+/`;
- iterate the split segments once and append `*segment*` only for nonempty
  segments;
- retain final `root.extensions.map(...)`, which is the required output list.

Per reevaluation:

- nonempty filter array: **1 -> 0**;
- wildcard map array: **1 -> 0**;
- split array and final extension-output array remain.

Generated glob strings are identical.

### 57.9 ConfirmationService queue advance can copy only the retained tail instead of slice-all + shift — CONFIRMED / P3

Path:

- `services/ConfirmationService.qml`, `_activateNext()`.

Current:

1. clone whole dense queue with `slice()`;
2. `shift()` first request, relocating remaining elements;
3. publish tail;
4. activate removed request.

The queue is internally constructed through append/filter snapshots and is
dense.

Exact-safe direction:

- `request = root.queue[0]`;
- `next = root.queue.slice(1)`;
- publish `root.queue = next`;
- call `root._activate(request)` in the same order.

Preserved:

- same first request;
- same tail references/order;
- one new queue array publication;
- queue publication remains before activation;
- no cursor or persistent representation change.

For queue length Q, work changes from copying Q then relocating Q-1 to copying
only the retained Q-1 elements.

### 57.10 Abyss target-screen checks can avoid repeated Quickshell.screens name-array materialization — CONFIRMED / P1-P2 multi-output/reactive path

Paths:

- `modules/abyss/AbyssPerimeter.qml`;
- pure policy `modules/abyss/looks/AbyssGeometry.js::targets()`.

AbyssPerimeter has **eight textual** calls shaped as:

`Geometry.targets(name, screenList, Quickshell.screens.map(s => s.name))`.

They gate Bar, sidebar reveal, Dock, notifications, OSD and Reservation state.
Reservation is instantiated for four edges per screen, so its one textual site
has multiple live instances per output.

Current `Geometry.targets()` means:

- empty target list -> true;
- explicitly listed current output -> true;
- otherwise true only when no connected output appears in the configured list.

The connected-name array is used only for this membership test.

Exact-safe direction:

- use a pure helper that accepts/reads the live screen sequence directly;
- preserve the first two short-circuits;
- only when connected-screen testing is needed, loop screens and perform the same
  configured-list `indexOf(screen.name)`;
- stop on the first configured connected screen;
- do not introduce a cached/shared screen-name property.

The empty-list case may also short-circuit before touching screens. Today the
third argument `Quickshell.screens.map(...)` is evaluated before
`Geometry.targets()` can return true. Removing that irrelevant dependency
cannot change the true result; when screenList later becomes nonempty, its Config
dependency triggers reevaluation and the live screen sequence is read then.

Per target check:

- S-entry name array: **1 -> 0**;
- S map callbacks: **S -> 0**;
- the subsequent `.some()` callback is replaced by the same direct loop;
- empty configured lists skip screen enumeration entirely.

### 57.11 Historical §35.1 Confirmation multi-output duplication is live again, but blanket optimization needs the strengthened lifecycle rule — REACTIVATED / HIGH CONFIDENCE, not counted new

Current paths:

- `modules/abyss/AbyssPerimeter.qml`;
- `modules/abyss/AbyssConfirmationPresenter.qml`;
- `modules/abyss/content/AbyssConfirmationContent.qml`;
- `modules/bar/StyledPopup.qml`.

The Round-21 observation was marked historical when an earlier Confirmation
experiment was removed. Current runtime has reintroduced the same shape:

- one presenter exists inside every output-local Abyss PanelWindow;
- every presenter binds `ConfirmationService.currentRequest`;
- only target-output presenter owns/presents the request;
- StyledPopup lazily creates its detached native PanelWindow, but its default
  `contentItem` is a direct QML child;
- `AbyssConfirmationContent` is therefore eagerly instantiated per output and
  every tree observes request changes;
- content owns TextMetrics, visible-action derivation/delegates,
  `Component.onCompleted: forceActiveFocus()`, and `onRequestChanged`
  state/focus work.

Thus the duplication observation is active again.

However the current strict contract includes lifecycle/focus semantics. A
blanket Loader or owner-only request substitution can change hidden child
creation/destruction and `forceActiveFocus()` timing.

Therefore:

- reactivate §35.1 as an active target/evidence item;
- do not count it as a new optimization;
- do not restore its old blanket implementation direction as CONFIRMED without
  lifecycle/focus fixtures;
- a narrower future patch may preserve request/onRequestChanged behavior on all
  trees while suppressing only proven-pure non-owner work.

Status: **REACTIVATED / HIGH CONFIDENCE — lifecycle/focus parity required**.

The old §35.3 dormant-content Loader idea is also live again but remains a
benchmark/lifecycle candidate.

### 57.12 Noctalia native Settings paint-subtree culling is architecture evidence, not a direct Quickshell port — SUPERSEDED / ARCHITECTURE

Upstream inspected:

- `noctalia-dev/noctalia@9cb4073448b75cb21cf74a13e1674662e8e04d13`
  — `perf(settings): cull scroll view subtrees and avoid excessive rebuild`.

It adds a native renderer `paintContained` contract for off-clip node culling
and narrows native Settings rebuild scopes.

Hadalis does not own that renderer/node API. Its relevant layer is QML object
residency and binding/process ownership.

Existing handoff already has:

- page-level SettingsPageHost LRU/asynchronous incubation (§3.6);
- section-level residency gap (§13.4 / §18.5);
- Settings search/index reductions (§48).

Do not invent a QML `paintContained` port or second page-cache layer.

Status: **SUPERSEDED / ARCHITECTURE evidence** for existing section-residency
work.

### 57.13 Noctalia removal of 5-second DDC polling does not map to current Hadalis; noverify/readback changes are not strict-lossless — CLOSED / ALREADY

Upstream inspected:

- `noctalia-dev/noctalia@246284bff47f8d57b013b8335f8d521247f790de`
  — `perf(ddcutil): remove constant polling, only fetch on shell startup and
  display_tab open + bring back some of the optimizations from v4`.

Current Hadalis has no equivalent repeating DDC refresh:

- detection runs on monitor-list changes;
- DDC monitor initialization runs on creation/bus change;
- 30s timer is one-shot process timeout;
- 800ms DDC timer is one-shot wake/restore retry;
- writes are coalesced by one-shot 300ms set timer.

So timer removal is **ALREADY / NOT APPLICABLE**.

The upstream commit also adds `--noverify` and removes post-write readback.
Those alter verification/failure/observed-state semantics and are not
strict-lossless speedups.

Status:

- polling removal: **ALREADY / CLOSED**;
- noverify/readback removal: **OUT OF STRICT-LOSSLESS SCOPE** unless product
  behavior is intentionally changed.

### 57.14 Round-43 conclusion

New strict-lossless candidate groups:

1. WidgetPowerManager local active-workspace Set (§57.1,
   **CONFIRMED / P2 conditional**);
2. GameMode workspace reuse + allocation-free single-output fallback (§57.2,
   **CONFIRMED / P2-P3**);
3. redundant LauncherSearch Clipboard/Emoji truthiness filters (§57.3,
   **CONFIRMED / P2**);
4. direct one-pass LauncherSearch action-result collection (§57.4,
   **CONFIRMED / P1-P2**);
5. in-place TaskbarApps normalized-list compaction (§57.5,
   **CONFIRMED / P3**);
6. bounded Cliphist superpaste selection + reverse command construction (§57.6,
   **CONFIRMED / P2**);
7. upcoming-event start timestamp reuse across sort comparisons (§57.7,
   **CONFIRMED / P2**);
8. wallpaper wildcard segment fusion (§57.8,
   **CONFIRMED / P2-P3**);
9. Confirmation queue tail copy without slice-all + shift (§57.9,
   **CONFIRMED / P3**);
10. allocation-free Abyss connected-screen target gating (§57.10,
    **CONFIRMED / P1-P2 multi-output**).

Reactivated but not counted new:

11. historical Confirmation per-output request/content duplication is live
    again, but blanket suppression/loading requires lifecycle/focus parity
    (§57.11).

External evidence/closures:

12. Noctalia native Settings paint culling is architecture evidence for existing
    Hadalis section-residency work (§57.12);
13. Noctalia DDC polling removal does not match current Hadalis, and noverify /
    readback removal changes behavior (§57.13).

No number above is an end-to-end Hadalis speedup. Numeric reductions are local
source-derived operation/allocation counts only.

No runtime/source implementation is authorized by this handoff.
---

## 58. Round 44 — Abyss aggregate pipelines, popup-anchor resolution and Niri focus micro-path (2026-09-30)

### Snapshot / concurrent reconciliation

Research continued from Round-43 commit
`57165ab09be6530d670a5e073b1f50c37fe76b26`.

Before this write, dev advanced one commit to
`88a01eaf7d09cc2f82c47cad292038560b6f9fe2`.

The delta is a single automation result file
(`automation/results/JOB-MAINTAINER-VALIDATE-001.json`). It does not touch
runtime source or this handoff, so all findings below remain based on the same
audited source.

No runtime/source implementation is authorized by this round.

### 58.1 AbyssSurfaceController aggregate array pipelines have a strict one-pass specialization — PROMOTED from §23.2 to CONFIRMED / P1-P2

Paths:

- `modules/abyss/AbyssSurfaceController.qml`;
- participant contract checked in
  `modules/abyss/AbyssParticipant.qml` and
  `modules/abyss/AbyssBodyHost.qml`.

Section §23.2 correctly identified aggregate record/input allocation as a hot
profile target but intentionally left broad stable-slot/incremental-model ideas
at INVESTIGATE.

A narrower local specialization is now provable without changing that
architecture.

Current bindings include:

`placementRequests`

- `Object.keys(participants)`;
- `.map(key => participants[key]?.placementRequest)`;
- `.filter(request => request !== null && request !== undefined)`.

`records`

- `Object.keys(participants)`;
- `.map(... Object.assign({}, geometry, {mass}) ...)`;
- `.filter(rec => rec && rec.surface.width > 0 && rec.surface.height > 0)`;
- `moduleRecords.concat(...)`.

`inputBounds`

- `Object.keys(participants)`;
- `.map(key => participants[key]?.inputBounds)`;
- `.filter(rect => rect && rect.width > 0 && rect.height > 0)`.

The participant fields involved are ordinary QML properties:

- `geometry`: var snapshot;
- `placementRequest`: var snapshot;
- `inputBounds`: rect;
- `mass`: real.

Strict-safe direction:

1. keep `Object.keys(participants)` as the authoritative enumeration list so
   key ordering is byte-for-byte the same as today;
2. allocate exactly the required public result array;
3. iterate keys once and append only values passing the existing predicate;
4. for `records`, initialize the result as a shallow copy of
   `moduleRecords`, then append participant records;
5. preserve the current `Object.assign({}, geometry, {mass})` clone **before**
   applying the current nonzero-surface predicate, so clone/getter behavior for
   zero-area geometry is not silently changed.

This does **not** introduce shared derived state, stable slots, mutation-in-place
of published arrays or incremental participant publication.

Proof:

- the same Object.keys order is retained;
- the same participant property values are read synchronously;
- result element object identity is unchanged where current code passes through
  placement/input objects;
- participant record clones remain fresh objects with the same mass override;
- module records remain first, in the same order;
- filtering predicates and record ordering are unchanged;
- each readonly binding still publishes one fresh JS result array per
  reevaluation, preserving its existing changed-signal shape.

Exact local array/pass saving per reevaluation:

`placementRequests`:

- keys + map-result + filter-result arrays -> keys + final-result arrays;
- participant value passes: **2 -> 1**.

`inputBounds`:

- keys + map-result + filter-result arrays -> keys + final-result arrays;
- participant value passes: **2 -> 1**.

`records`:

- keys + map-result + filter-result + concat-result arrays -> keys +
  final-result arrays;
- participant record passes: **2 -> 1**;
- `Object.assign` record clone count is deliberately unchanged.

Because `records` and `inputBounds` can react during connected-body
geometry/reveal changes, this is the strict-lossless implementation subset of
the broader §23.2 P1 profile target.

Do not treat this promotion as authorization for the still-unproven stable-slot
or selective ShaderEffect-uniform architecture changes in §23.2.

### 58.2 Abyss popup-slot derived state has three allocation/iteration reductions with exact order parity — CONFIRMED / P2

Path:

- `modules/abyss/AbyssSurfaceController.qml`.

The controller supports at most four simultaneous popup slots, but several
derived bindings reevaluate with popup geometry/focus state.

#### A. popupInputBounds map/filter fusion

Current:

- `popupSlots.map(...inputBounds-or-null...).filter(validRect)`.

A single indexed loop can append only the same valid rects.

Preserved:

- slot-index order;
- rect object/value identity;
- `rect.width > 0 && rect.height > 0` predicate;
- one fresh published result array.

Saving:

- intermediate mapped array: **1 -> 0**;
- slot traversals: **2 -> 1**.

#### B. popupFocusOwner does not need slice().reverse()

Current binding clones `popupEntries`, reverses the clone, then scans newest to
oldest.

Iterating `popupEntries` by index from `length - 1` to 0 visits the exact
same entries in the exact same priority order without mutating the source.

Saving per reevaluation:

- reverse-scan clone: **1 array -> 0**;
- reverse relocation/swaps -> 0.

All keyboard-focus predicates, slot lookup and input-bounds tests stay
unchanged.

#### C. dismissPopups can preserve its mutation-safe snapshot without reversing it

`dismissPopups()` currently does:

`activePopups.slice().reverse().forEach(...dismiss...)`.

The `slice()` snapshot is **load-bearing** because dismissing a popup can
synchronously change controller popup state. Do not remove it.

The strict-safe reduction is only:

- keep `const popups = activePopups.slice()`;
- iterate that snapshot from the last index down to zero;
- invoke the same `dismissPresentation()`.

This preserves the current newest-to-oldest snapshot semantics while removing
the in-place reverse pass and callback dispatch.

Status for the group: **CONFIRMED / P2**. Capacity is small, but
`popupFocusOwner` / input-bounds derivation can participate in active popup
geometry/focus reevaluation.

### 58.3 PopupAnchorRegistry can reuse per-entry item context and per-controller active hover-target snapshots within one resolve() — CONFIRMED / P1-P2 for implicit confirmation resolution

Path:

- `services/PopupAnchorRegistry.qml`.

Current implicit `resolve(source)` does, for each registered entry:

1. `_validItem(item)`, which resolves both its QsWindow and liquid ancestor;
2. if valid, `_activeSourcePopup(item)`, which walks the ancestor chain again
   to recover the same liquid controller and scans that controller's
   `popupEntries`;
3. after a positive identity match, `_windowFor(item)` is called again to
   obtain output name.

Many Bar/Dock/Tray anchors on one output share one
`AbyssSurfaceController`, while `popupEntries` has a maximum capacity of
four.

Exact-safe direction:

- keep public `isUsable(item)` / `_validItem(item)` behavior unchanged;
- add a private resolve-only context helper that performs the same validity
  checks in the same order but also returns the already-resolved `window` and
  `liquidAnchor/controller`;
- reuse that context rather than repeating the ancestor/window lookups;
- create an invocation-local Map keyed by liquid controller;
- the first time a controller is encountered, scan its current
  `popupEntries` once and build a Set of `hoverTarget` items whose popup has
  `presentationActive === true`;
- later entries sharing that controller use `activeTargets.has(item)`;
- discard both Map/Sets when `resolve()` returns.

Why strict-lossless:

- `resolve()` is synchronous and does not yield to the event loop;
- it does not itself mutate popup presentation state;
- controller popup entries and QML parent/window references are therefore one
  logical snapshot for the call;
- resolve only needs the boolean fact that an active popup has
  `hoverTarget === item`; duplicate popup entries do not change Set
  membership;
- entry iteration order, identity scoring, output scoring, ambiguity handling
  and selected result remain unchanged;
- no persistent cache/invalidation lifecycle is introduced.

For E valid registered items sharing a controller with P popup entries:

- repeated popup-entry scans: up to **E x P -> P + E Set.has()**;
- liquid-ancestor resolution for valid entries: **2 -> 1 per entry**;
- matched-entry QsWindow resolution: **2 -> 1**.

This is intentionally invocation-local; do not resurrect the generic persistent
registry indexing/pruning approach retired in §36.4.

### 58.4 PopupAnchorPolicy can normalize each captured source candidate once; alias-provider hoisting is not yet strict by API contract — CONFIRMED partial / P2 + HIGH CONFIDENCE remainder

Paths:

- `services/PopupAnchorRegistry.qml`;
- `services/PopupAnchorPolicy.js`.

`_sourceAliases(source)` captures up to five raw source identity values into
the `wanted` array before entry matching.

Inside nested matching, every pair currently calls:

`AnchorPolicy.matchScore(candidate, alias)`

and `matchScore()` normalizes **both** arguments each time:

- String conversion;
- trim;
- lower-case;
- optional `.desktop` removal;
- regex removal of non-alphanumeric characters.

The captured `candidate` primitive cannot change during the synchronous
resolve call.

Therefore source-side normalization can be hoisted exactly once per wanted
candidate and an exact scoring helper can accept a pre-normalized left side
while continuing to normalize the alias at the current call site.

Proof:

- `normalize()` is pure and deterministic;
- raw wanted values are already captured before entry iteration;
- equality, entropy length and suffix-match arithmetic use the exact same
  normalized string;
- scoring/ties/ordering are unchanged;
- no alias-provider invocation count changes.

Source-side candidate normalization therefore changes from once per candidate /
entry / alias pair to **once per source candidate per resolve()**.

Status: **CONFIRMED / P2** for this partial hoist.

A more tempting optimization is to move:

`const aliases = root._aliases(entry)`

outside the source-candidate loop.

All current checked-in providers are simple arrow functions that only read live
QML fields:

- BarTaskbarButton: originalAppId/appId/desktopEntry id/startupClass;
- DockAppButton: the same four identity fields;
- SysTrayItem: tray item id.

For current providers, one snapshot per entry would produce the same values
within one synchronous resolve call and would remove repeated provider arrays.

However `registerAnchor()` accepts an arbitrary `aliasProvider` function and
the service currently does **not** declare provider purity or invocation-count
semantics. Extension/custom callers could theoretically supply a stateful or
throw-once provider.

Under the strict extension/lifecycle rule, do not change provider invocation
count until the registry contract explicitly guarantees a pure snapshot
provider or all external registration surfaces are proven closed.

Status for provider hoisting: **HIGH CONFIDENCE / provider-purity contract
required**, not counted as CONFIRMED.

### 58.5 Niri MRU focus update can prepend directly instead of relocating the completed array with unshift — CONFIRMED / P2 focus hot path

Path:

- `services/NiriService.qml`, `handleWindowFocusChanged()`.

Current MRU maintenance:

1. allocate `newOrder = []`;
2. scan old MRU ids and push every id not equal to the newly focused id;
3. `newOrder.unshift(focusedWindowId)`.

The final unshift relocates every retained element one position to the right.

Exact-safe direction:

- initialize `newOrder = [focusedWindowId]`;
- scan the old MRU list in the same order;
- append every id not equal to `focusedWindowId`.

Parity:

- newly focused id remains first;
- all prior occurrences of that id are still removed;
- all other ids retain the same relative order;
- if the id was not previously present, it is still inserted once at front;
- assignment to `mruWindowIds` occurs at the same point in the focus handler;
- no event coalescing or MRU publication cadence changes.

For R retained previous ids:

- final `unshift` relocation of R elements -> 0;
- MRU scan count and one result-array allocation remain unchanged.

Focus changes are event-hot, so this small operation composes with the larger
Niri focus-path findings.

### 58.6 Capture the focused window during the existing focus-normalization pass — CONFIRMED stronger specialization of §§41.3/54.1, not a separate backlog count

Path:

- `services/NiriService.qml`, `handleWindowFocusChanged()`,
  `_normalizeWindowFocus()`.

Current focus handler:

1. records `_latestFocusedWindowId`;
2. calls `scheduleWindowsUpdate(currentList)`, whose normalization logic walks
   the window list;
3. then runs a second:
   `currentList.find(window => window.id === focusedWindowId)`
   to obtain the same focused window for workspace `active_window_id`
   maintenance.

Existing findings already establish:

- §41.3: avoid the throwaway normalization array when focus state is already
  correct;
- §54.1: a focus-only event must preserve any pre-existing
  `_windowOrderDirty === true` but can skip the generic order-diff pass.

When implementing that focus-specific normalization path, retain the original
window whose id matches `focusedWindowId` while the pass is already visiting
it, and feed that reference to the existing workspace update code.

The workspace update only needs `workspace_id`; focus normalization does not
change that field.

Exact additional saving:

- post-normalization focused-window linear scan: up to **N -> 0**.

No additional persistent index/cache is required.

This is a **stronger implementation specialization** of the existing
focus-event backlog, not a new independently counted optimization. The
focus-specific implementation should preserve:

- prior dirty-order state;
- normalized window objects/publication;
- MRU update timing;
- workspace `active_window_id` publication timing;
- window update timer cadence.

### 58.7 Waves-disabled mass recomputation remains a strong candidate but is not promoted without enable-transition ordering proof — STATUS UNCHANGED

Paths rechecked:

- `modules/abyss/AbyssWaveController.qml`;
- §23.1.

Current source still has:

- `Component.onCompleted: reset()`;
- `onRecordsChanged: if (simulation) Wave.setMass(simulation, records)`;
- `integrationAllowed = motionAllowed || audioAllowed`;
- `onIntegrationAllowedChanged: if (!integrationAllowed) reset()`.

Thus the old observation remains true: waves/audio disabled sessions can
recompute mass on record churn even though no integration step consumes it.

The proposed dirty-mass deferral still looks valuable, but strict parity
requires proving that when integration becomes enabled, mass is refreshed before
any ticker/impulse/spectrum consumer can observe stale mass under QML signal /
binding ordering.

Do not promote merely because the disabled state has no visual wave.

Status remains **ADAPT / P1 candidate requiring transition-order fixture**.

### 58.8 Round-44 conclusion

New or newly-promoted strict-lossless groups:

1. one-pass Abyss participant aggregate pipelines for placementRequests,
   records and inputBounds (§58.1, **PROMOTED / CONFIRMED P1-P2**);
2. popup-slot input/focus/dismiss local allocation reductions (§58.2,
   **CONFIRMED / P2**);
3. resolve-local PopupAnchor item-context reuse and per-controller active-target
   Set (§58.3, **CONFIRMED / P1-P2**);
4. normalize captured PopupAnchor source candidates once per request (§58.4,
   **CONFIRMED / P2 partial**);
5. prepend Niri MRU focus order without unshift relocation (§58.5,
   **CONFIRMED / P2**).

Backlog/evidence refinement, not counted new:

6. capture the focused window during the existing focus-specific normalization
   pass, strengthening §§41.3/54.1 (§58.6, **CONFIRMED stronger
   specialization**).

Not promoted:

7. hoisting arbitrary PopupAnchor aliasProvider calls needs an explicit purity
   contract (§58.4);
8. waves-disabled mass deferral still needs enabled-transition ordering proof
   (§58.7).

No numeric reduction above is an end-to-end Hadalis speedup. All counts are
local operation/allocation reductions derived from current source.

No runtime/source implementation is authorized by this handoff.
---

## 59. Round 45 — calendar presentation, request-build pipelines and reactive array cleanup (2026-09-30)

### Snapshot / concurrency safety

Research continued from Round-44 docs commit
`6fd7042767dc88f13c3e0e0e27f1ea40386b6aa5`.

During this round `dev` advanced through multiple clean fast-forwards to exact
write parent `b7896b671791ba67ef8d38df458ce8e24af2191f`. All concurrent changed
files audited since Round 44 are under `agent/*`, `automation/*`, or live
transport/test paths. None touches the runtime sources below or this handoff.

Six attempted docs writes were stopped by exact-parent guards before blob/commit
creation as concurrent automation advanced the branch. No stale ref update or
force push was attempted.

No runtime/QML/native implementation is authorized by this round.

### 59.1 Sidebar month-calendar cells resolve the same Date three times — CONFIRMED / P1 visible calendar

Path: `modules/sidebarRight/calendar/CalendarWidget.qml`.

`monthCells` already resolves `date = _getDateForCell(...)`, but
`getEventCountForDay()` and `getSourceColorsForDay()` each resolve the same
cell Date again.

Keep both existing helpers as compatibility wrappers with their current
`_eventsTrigger` / `_externalTrigger` reads. Add private date-based
count/color helpers and let `monthCells`, which already touches both triggers,
pass its existing Date.

Events/CalendarSync copy the incoming Date and do not mutate it. Count then color
call order remains unchanged.

Full 6x7 grid:

- cell Date resolutions/constructions: up to **126 -> 42**;
- event scans remain separate work owned by §49.3/§49.4.

### 59.2 Waffle Calendar can assemble merged event arrays directly — CONFIRMED / P1-P2 visible calendar

Path: `modules/waffle/notificationCenter/CalendarWidget.qml`.

Selected-day path maps local events to fresh clones, then concatenates that array
with external references.

Strict-safe direction:

1. call local Events first;
2. allocate the final array;
3. append the exact same `Object.assign` clones in source order;
4. only then call CalendarSync;
5. append external references unchanged;
6. retain the exact comparator.

This removes the mapped array and concat-copy stage.

For each of three upcoming days, current code creates local and external mapped
clone arrays, then a concatenated `dayEvents` array. Build the required
`dayEvents` directly: locals first, external call/clones second, then exact
current sort.

Retain all three days, `events.push(...dayEvents)`, and final
`slice(0, 5)`. Early-stop could skip service/property/error work and is not
needed.

Per day:

- local mapped result: **1 -> 0**;
- external mapped result: **1 -> 0**;
- concat-copy stage: removed.

Do not combine this with eager timestamp caching: all-day comparisons can return
before timestamp fields are read, so property-read timing remains a separate
parity question.

### 59.3 AbyssPerimeter obstacle derivation can use one result buffer — CONFIRMED / P1-P2 multi-output reactive path

Path: `modules/abyss/AbyssPerimeter.qml`.

`sideObstacles` currently uses
`[leftPanel,rightPanel].filter(progress).map(record)`.

A strict one-result loop reads both progress values first, then records for
passing bodies in left/right order, matching filter-then-map phase order.

Arrays per evaluation: **3 -> 1**.

Dock obstacles chain two `concat()` calls with singleton/empty arrays.
Preserve evaluation order: capture side obstacles; evaluate notification
condition/record; copy once and append it; then evaluate popup condition/record
and append it.

Maximum combination arrays after sideObstacles: **4 -> 1**.

Notification non-center obstacles similarly become one side-array copy plus an
optional popup append: up to **2 -> 1** arrays. Center mode must return `[]`
before reading side/popup state.

Obstacle order, record identity, thresholds and allocator semantics remain
unchanged.

### 59.4 AI message history lookup/filter can use one ordered pass — CONFIRMED / P1-P2 per request

Path: `services/Ai.qml`.

Current:

`messageIDs.map(id => messageByID[id]).filter(message => ...)`.

`messageByID` is a plain JS map and values are `AiMessageData` QtObjects;
`role` and `requestFailed` are ordinary scalar properties. This is
imperative request construction, not a reactive binding.

Allocate only the filtered result and loop IDs once, applying the same predicate
and appending the same references in the same order.

Do **not** add a null guard: current code throws when a missing mapping is
dereferenced, so corruption must not be silently skipped.

For M IDs:

- M-element intermediate array: **1 -> 0**;
- visits: **2M -> M**.

### 59.5 AI Content-Type header pipeline is statically constant — CONFIRMED / P2-P3 per request

Path: `services/Ai.qml`.

`requestHeaders` contains only `"Content-Type": "application/json"`.
Whole-file exact-source search found no mutation/use before
`Object.entries -> filter -> map -> join`. Authorization is built separately.

The result is always:

`-H 'Content-Type: application/json'`.

Use that byte-identical string and leave auth, endpoint, quoting and curl order
unchanged.

Removed per request:

- header object;
- Object.entries array;
- filter array;
- map array;
- collection traversal/join.

### 59.6 GlobalStates connected-output names can compact the fresh map result in place — CONFIRMED / P2 broad presentation path

Path: `GlobalStates.qml`.

`connectedOutputNames()` currently maps screens to string names, filters
empties, then when allowlisted filters again.

Keep the initial `Quickshell.screens.map(...)` exactly. Stable-compact that
fresh JS array in place. Only afterward perform the same allowlist test and,
when needed, build one enabled array with the same ordered
`allowedOutputs.includes(name)`.

Allocations:

- no allowlist: **2 -> 1** arrays;
- allowlist: **3 -> 2** arrays.

Do not alter requested/focused/primary short-circuit selection in this patch;
its conditional reads belong to reactive dependency timing.

### 59.7 Audio PwObjectTracker can publish the same nodes from one fresh array — CONFIRMED / P2

Path: `services/Audio.qml`.

Current:

`[rawSink,sink,source].concat(outputAppNodes).concat(inputAppNodes).filter(node => node)`.

Keep independent public `outputAppNodes` / `inputAppNodes` properties
unchanged.

Strict-safe local construction reads base nodes, appends all output refs, then
all input refs, then stable-compacts falsy values in that same fresh array.

Order, duplicates, truthiness and public AppNode signals remain unchanged.

Fresh arrays: **4 -> 1**.

### 59.8 Overview empty-output fallback can reuse one Object.keys result — CONFIRMED / P3

Path: `modules/overview/OverviewNiriWidget.qml`.

Empty-output fallback currently calls `Object.keys(outputs)` once for length
and again for the first key.

Keep the direct nonempty-output path. On fallback, compute one keys array and
return `keys.length > 0 ? outputs[keys[0]] : outputs[outputName]`.

The empty-map result remains the current `outputs[""]` result.

Fallback key arrays/enumerations: **2 -> 1**.

### 59.9 Confirmation acceptDefault can resolve the already-selected action — CONFIRMED / P3

Path: `services/ConfirmationService.qml`.

After §56.8 one-pass default selection, `acceptDefault()` still obtains the
default ID and `resolve(id)` scans actions again.

Every enqueued request passes through `_normalizeActions()`, which guarantees
unique action IDs by suffixing collisions.

Factor a private selector returning the same selected action object, keep public
`defaultActionId()` as a string wrapper, and have `acceptDefault()` pass the
object directly to existing `_resolveAction(action, false)`.

`_resolveAction` preserves request/usability/empty-ID guards and callback /
publication ordering. Public `resolve(id)` remains unchanged.

Second action-list scan: up to **A -> 0**.

### 59.10 CustomThemeEditor quick adjustments can fuse key filtering into the color-transform loop — CONFIRMED / P1-P2 slider interaction

Path: `modules/settings/CustomThemeEditor.qml`.

The three Saturation/Brightness/Temperature sliders restart a 50 ms debounce.
Each `applyQuickAdjustments()` currently:

1. `Object.keys(originalColors)`;
2. filters keys to `m3*` values that are strings beginning with `#`;
3. loops the filtered key array;
4. reads `originalColors[key]` again for each retained key;
5. computes/publishes the same Config update map.

`originalColors` is created once for the interaction with
`JSON.parse(JSON.stringify(customTheme))`: a plain JSON snapshot, not a live
QML object with getter side effects.

Strict-safe direction:

- retain `Object.keys(originalColors)` to preserve exact own-key order;
- loop those keys once;
- read `const original = originalColors[key]`;
- apply the exact current key/type/hash predicate;
- for passing keys, run the unchanged Qt.color/HSL transform and append the same
  update key/value;
- keep `Config.setNestedValues(updates)` and `applyToShell()` even for an
  empty update map, preserving current call behavior.

Per debounced slider application:

- filtered key array: **1 -> 0**;
- key visits for qualifying colors: **2 passes -> 1**;
- qualifying `originalColors[key]` reads: **2 -> 1**.

This is interaction-scoped but can run repeatedly while dragging, so it ranks
above one-shot Settings cleanup.

### 59.11 Noctalia one-minute Screen Time checkpoint is not a strict-lossless Hadalis port — CLOSED / ARCHITECTURE EVIDENCE

Fresh upstream:

- `noctalia-dev/noctalia@7a9b4e271958aae2aecfa0c4cd3b46e95d331425`
  — `perf(screen-time): checkpoint once a minute instead of every five seconds`
  (2026-09-29).

Hadalis has a different contract:

- persistence is separately throttled to 30 seconds;
- Niri focus is event-driven plus a 30-second heartbeat;
- Hyprland's ~5-second poll also observes focused-app state;
- ticks publish session/today data;
- `elapsed > 60` is special-cased.

One-minute ticks would change attribution/publication/durability timing.

Status: **CLOSED direct port / ARCHITECTURE EVIDENCE**.

### 59.12 Network O(N²) search hit is stale — ALREADY / regression guard

A repository search index surfaced the old
`oldNetworks.filter(!wifiNetworks.find(...))` shape.

Exact current `services/Network.qml` already uses `existingByKey` Map,
`nextKeys` Set, reverse stale-row removal and keyed reuse/create.

Do not reopen it from stale search snippets; this is consistent with §50.1.

### 59.13 Incremental screenshot annotation is already substantially present — ALREADY / regression architecture

Fresh screenshot/capture upstream work was compared with
`RegionSelection.qml` and `AnnotationEditor.qml`.

Hadalis annotation already separates committed history from the hot pointer
path:

- committed strokes are Shape delegates;
- only current in-progress stroke is in `liveCanvas`;
- `Canvas.Threaded` is used;
- pointer moves request only that live Canvas;
- point insertion is distance-throttled by `minPointStep`.

There is no static evidence for a direct new incremental-raster port. Further
dirty-rect/frame coalescing requires runtime profile and visual-latency parity.

### 59.14 Round-45 conclusion

New strict-lossless groups:

1. Sidebar cell Date reuse (§59.1, **CONFIRMED / P1**);
2. Waffle Calendar direct event-array assembly (§59.2,
   **CONFIRMED / P1-P2**);
3. Abyss obstacle-array construction (§59.3,
   **CONFIRMED / P1-P2**);
4. AI history one-pass filtering (§59.4,
   **CONFIRMED / P1-P2**);
5. constant AI Content-Type header (§59.5,
   **CONFIRMED / P2-P3**);
6. GlobalStates connected-output compaction (§59.6,
   **CONFIRMED / P2**);
7. Audio PwObjectTracker one-buffer construction (§59.7,
   **CONFIRMED / P2**);
8. Overview one-key-array fallback (§59.8, **CONFIRMED / P3**);
9. Confirmation default accept without second ID scan (§59.9,
   **CONFIRMED / P3**);
10. CustomThemeEditor quick-adjustment key-loop fusion (§59.10,
    **CONFIRMED / P1-P2 interaction**).

Closed/not promoted:

11. eager Waffle timestamp caching remains a property-read parity question;
12. Noctalia minute Screen Time cadence is not direct-lossless (§59.11);
13. old Network quadratic reconciliation is already fixed (§59.12);
14. incremental annotation architecture is already present (§59.13).

No number above is an end-to-end Hadalis speedup. Numeric reductions are local
source-derived operation/allocation counts only.

No runtime/source implementation is authorized by this handoff.
---

## 60. Round 46 — bounded notification models, overview search and interaction hot paths (2026-09-30)

### Snapshot / concurrency safety

Research continued after Round-45 docs commit
`f9d72ba16e2cd7df32506c2a5330422cc294f716`.

The first exact Round-46 runtime baseline was
`8f4f0209700e45b5e32335ad93d536768ea01317`. Concurrent work continued
throughout the audit. Every delta reconciled before this write was a clean
fast-forward and remained confined to `agent/*`, `automation/*`, or
Hadalis automation/live-transport test/install scripts. None touched the runtime
sources below or this handoff.

Several attempted writes were rejected by exact-parent guards before any
blob/commit creation as concurrent automation advanced `dev`. The final write
uses the then-current HEAD as its explicit parent and rechecks the branch before
the ref update.

No runtime/QML/native implementation is authorized by this round.

### 60.1 NotificationGroup collapsed model construction can be O(1) in group size — CONFIRMED / P1-P2

Path: `modules/common/widgets/NotificationGroup.qml`.

Current:

`expanded ? notifications.slice().reverse()
          : notifications.slice().reverse().slice(0, 2)`.

Notification groups are ordinary JS arrays of notification-object references.

Collapsed mode only needs the two newest entries, but currently copies and
reverses all N references first.

Strict-safe direction:

- collapsed: create the final array from `notifications[N-1]` and, when
  present, `notifications[N-2]`;
- expanded: create the final array by reverse-index appends;
- never mutate `root.notifications`.

Collapsed local work:

- full-group clone/reverse: **O(N) -> O(min(N, 2))**;
- full-size temporary reversed array: **1 -> 0**.

Expanded mode stays O(N) but removes the separate reverse-relocation phase.
Fresh ScriptModel array identity, newest-first ordering, delegate indices and
notification references remain unchanged.

### 60.2 PhysicalKeyboardFeedback can publish one fresh array per real key transition — CONFIRMED / P1-P2 conditional

Path: `modules/onScreenKeyboard/PhysicalKeyboardFeedback.qml`.

Current press uses `current.concat([keycode])`.
Current release uses
`current.slice(0, index).concat(current.slice(index + 1))`.

`pressedKeycodes` is an internally maintained dense array of numeric evdev
codes; duplicate/missing-event guards already run first.

Strict-safe direction:

- press: clone once, `push(keycode)`, publish;
- release: clone once, `splice(index, 1)`, publish.

Fresh arrays:

- press: **2 -> 1**;
- release: **3 -> 1**.

Key order, duplicate suppression, no-op paths and changed-signal timing remain
unchanged.

### 60.3 Overview Search Clipboard/Emoji truthiness filters are redundant — CONFIRMED / P2

Path: `modules/overview/SearchWidget.qml`.

This is distinct from `services/deferred/LauncherSearch.qml` and does not
duplicate §57.3.

Clipboard and Emoji prefixed branches both execute:

`fuzzyQuery(...).map(entry => ({...})).filter(Boolean)`.

Both map callbacks always return an object.

Publish the map result directly.

Per evaluation:

- truthiness pass: **N -> 0**;
- filter-result array: **1 -> 0**.

Result objects, ordering and fresh `cachedResults` publication are identical.

### 60.4 Overview Search action matching/result composition can collect directly — CONFIRMED / P1-P2

Path: `modules/overview/SearchWidget.qml`.

Default search currently:

1. maps every action to result-or-null;
2. filters nulls;
3. optionally pushes one explicit math/shell/web result;
4. concatenates app results;
5. concatenates action results;
6. appends remaining default rows.

Strict-safe direction:

- iterate actions once in current order, using the same action-string and prefix
  predicates, and append only matches;
- preserve the current point at which action objects are built;
- append app results and action results directly into the unpublished local
  `result`;
- retain all current leading/trailing special/default-row rules.

Final ordering stays:

explicit special -> apps -> actions -> remaining defaults.

Removed:

- action map/null array: **1 -> 0**;
- map/filter second traversal;
- two concat result arrays/full-prefix copies: **2 -> 0**.

### 60.5 Background fullscreen-workspace derivation can remove nested result arrays without narrowing QML dependencies — CONFIRMED / P1-P2 Hyprland path

Path: `modules/background/Background.qml`.

`activeWorkspaceWithFullscreen` currently uses an outer
`workspacesForMonitor.filter(...)[0]` and an inner
`workspace.toplevels.values.filter(fullscreen)[0]`.

A simple nested `find()/some()` is not strict enough because early exits could
stop observing later fullscreen properties and narrow the binding dependency
set.

Strict-safe loop:

- visit every workspace;
- visit every toplevel of every workspace and read every existing fullscreen
  property;
- retain only a scalar `hasFullscreen` instead of an inner array;
- read `workspace.active` only when `hasFullscreen`, matching the existing
  `&&` short circuit;
- remember the first matching workspace but continue later visits.

Output and reactive read breadth remain identical.

Removed:

- outer filtered workspace array: **1 -> 0**;
- inner fullscreen result arrays: **up to W -> 0**.

Traversal count is intentionally unchanged.

### 60.6 AppSearch launch preparation has two strict local reductions — CONFIRMED / P1-P2 per launch

Path: `services/AppSearch.qml`.

#### A. Compact the fresh Array.from result in place

Both `launchEntry()` and `launchDesktopAction()` use:

`Array.from(commandLike).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)`.

Keep `Array.from` because command input may be QML-list-like. It returns a
fresh JS array, which can be normalized and stable-compacted in place.

Preserve exactly:

- `String(arg ?? "")`;
- empty-string removal;
- argument order;
- fresh final command array.

Removed:

- map-result array: **1 -> 0**;
- filter-result array: **1 -> 0**.

#### B. Inspect Ventoy frontend flags only for Ventoy

Ordinary `launchEntry()` currently always evaluates:

`command.slice(1).some(arg =>
    /^--(gtk[234]|qt[456])$/.test(arg.toLowerCase()))`.

That result is consumed only by
`isVentoyGui && !hasVentoyFrontend`.

For non-Ventoy apps the scan cannot affect behavior.

Strict-safe direction:

- only if `isVentoyGui`, scan indices 1..N-1 with the exact same predicate;
- do not allocate `command.slice(1)`.

Normal non-Ventoy launch:

- tail copy: **1 -> 0**;
- frontend checks: **N-1 -> 0**.

Ventoy keeps identical first-match behavior while also dropping the tail copy.
Privileged-launch and `--qt5` behavior remain unchanged.

### 60.7 Wallpapers Niri workspace range needs only one min/max pass — CONFIRMED / P2 user-action path

Path: `services/Wallpapers.qml`, `detectNiriWorkspaceRange()`.

Current code collects every matching `ws.idx`, sorts numerically, and returns
only first/last.

Current upstream Niri IPC schema was checked:
`Workspace.idx` is `u8` and is explicitly the workspace index on its
monitor. There is no string/NaN ordering case hidden by the numeric sort.

Strict-safe direction:

- keep the same workspace-map traversal and output-name predicate;
- update scalar min/max for matching workspaces;
- zero matches still return `null`;
- otherwise return the same `{first, last}`.

For K target-output workspaces:

- K-element temporary array: **1 -> 0**;
- numeric sort: **K log K -> 0**.

This is distinct from §32.9's external IPC-query reduction.

### 60.8 WindowPreview warm-LRU touch can append to the filtered final array — CONFIRMED / P2

Path: `services/WindowPreviewService.qml`,
`_touchOverviewWarmImage()`.

Current:

`overviewWarmOrder =
    overviewWarmOrder.filter(id => id !== windowId).concat([windowId])`.

The filter is required because it removes every previous occurrence while
preserving all other relative order.

Strict-safe direction:

- keep the filter as the final fresh array;
- `next.push(windowId)`;
- publish `next`;
- retain the existing capacity/eviction loop.

Per touch:

- singleton concat argument array: **1 -> 0**;
- concat result/full retained-prefix copy: **1 -> 0**.

LRU order, fresh-array publication and eviction semantics remain identical.

### 60.9 ChatHistoryPanel can derive identical ordered names with one initial pass — CONFIRMED / P2

Path: `modules/sidebarLeft/aiChat/ChatHistoryPanel.qml`.

Current `chatNames`:

1. maps all saved paths to basenames;
2. filters `lastSession`;
3. sorts and reverses;
4. separately runs `names.includes("lastSession")`;
5. conditionally creates a singleton prefix;
6. concatenates prefix + rest.

Strict-safe direction:

- iterate `Ai.savedChats` once;
- derive basename with the exact existing expression;
- remember whether `lastSession` occurred;
- append all other names to `rest`;
- retain `rest.sort().reverse()` exactly;
- if present, `rest.unshift("lastSession")`.

Do not add malformed-path guards.

Final semantics stay:

- at most one `lastSession`, always first;
- duplicate ordinary chat names preserved;
- same default-JS descending lexical order.

Removed:

- all-names intermediate array: **1 -> 0**;
- separate includes pass: **N -> 0**;
- singleton prefix + concat-result arrays: **up to 2 -> 0**.

### 60.10 DMS ripple-mask VRAM rewrite is not a direct strict-lossless Hadalis port — NEEDS BENCHMARK / VISUAL TRADEOFF

Upstream:

- `AvengeMedia/DankMaterialShell@13ef1efa7b32adaacdcf091320859811474dcee8`.

DMS replaced a ripple offscreen masking path and reported substantial NVIDIA
VRAM savings.

Hadalis `RippleButton.qml` also has an `OpacityMask`, but:

`layer.enabled: ripple.opacity > 0`.

So Hadalis does not retain that offscreen layer for every idle button; it is
transient during an active ripple.

The upstream change also accepts a possible rounded-edge smoothness difference.
A direct mask-to-clip change therefore is not inspection-proven strict-lossless.

Status:

- no mechanical port;
- profile transient FBO/VRAM cost under click-heavy UI if needed;
- require visual/pixel parity before promotion.

### 60.11 Round-46 conclusion

New strict-lossless groups:

1. NotificationGroup bounded reverse model (§60.1,
   **CONFIRMED / P1-P2**);
2. PhysicalKeyboardFeedback one-array state transitions (§60.2,
   **CONFIRMED / P1-P2 conditional**);
3. Overview Search Clipboard/Emoji filter removal (§60.3,
   **CONFIRMED / P2**);
4. Overview Search direct action/result collection (§60.4,
   **CONFIRMED / P1-P2**);
5. Background fullscreen derivation without nested result arrays (§60.5,
   **CONFIRMED / P1-P2**);
6. AppSearch command compaction + Ventoy-only argument scan (§60.6,
   **CONFIRMED / P1-P2**);
7. Wallpapers one-pass Niri workspace range (§60.7,
   **CONFIRMED / P2**);
8. WindowPreview warm-LRU filter+push (§60.8,
   **CONFIRMED / P2**);
9. ChatHistoryPanel one-pass name derivation (§60.9,
   **CONFIRMED / P2**).

Not promoted:

10. DMS ripple-mask rewrite remains a measured VRAM/visual-parity experiment
    (§60.10).

No number above is an end-to-end Hadalis speedup. Numeric reductions are local
source-derived operation/allocation counts only.

No runtime/source implementation is authorized by this handoff.
---

## 61. Round 47 — pin mutations, AppSearch scoring and monitor-arrangement collection cleanup (2026-09-30)

### Snapshot / concurrency safety

This round continued immediately after Round-46 docs commit
`113013b8f83e835a4509a9b7c2c39698ab7fd49e`.

Any branch movement after that commit is accepted only when an in-transaction
compare proves the delta is a clean fast-forward limited to the already-audited
`agent/*`, `automation/*`, or Hadalis automation/live-transport test/install
paths. Runtime or handoff changes abort the write.

No runtime/QML/native implementation is authorized by this round.

### 61.1 TaskbarApps and TrayService toggle paths can decide/remove/append in one pass — CONFIRMED / P2 interaction

Paths:

- `services/TaskbarApps.qml`;
- `services/TrayService.qml`.

#### TaskbarApps.togglePin()

Current taskbar mutation starts from
`root._stringArray(Config.options?.dock?.pinnedApps)`, so `pinned` is already
a fresh normalized JS array.

It then:

1. scans with `some(id => id.toLowerCase() === key)`;
2. if found, scans again with `filter(... !== key)`;
3. otherwise copies again with `concat([normalized])`.

Strict-safe direction:

- allocate `next = []`;
- visit every normalized pinned ID once;
- compute the same lowercase comparison;
- remember whether any match occurred;
- append only nonmatching IDs;
- if no match occurred, append `normalized`;
- call the same `Config.setNestedValue` once.

Important duplicate semantics are preserved:

- the existence test remains case-insensitive;
- when pinned, **all** case-insensitive duplicates are removed, matching current
  `filter`;
- when unpinned, existing order is preserved and the normalized app ID is
  appended once.

Unpin comparison work changes from up to roughly **2N -> N**.
The pin branch removes the concat copy/result allocation.

#### TrayService.togglePin()

Current toggle:

1. scans `_pinnedItems.includes(itemId)`;
2. calls `unpin()` or `pin()`;
3. those helpers reread/copy and, respectively, filter or run another
   `includes()`.

For the toggle API specifically, a single ordered pass over the current pinned
snapshot can:

- retain all nonmatching exact IDs;
- remember whether an exact match existed;
- remove all exact duplicates when found;
- append `itemId` when not found;
- publish one final array through the same Config path.

Keep public `pin()` and `unpin()` behavior unchanged for their direct callers.

This removes the duplicate membership pass and reduces the toggle to one
collection build while preserving exact-ID semantics.

### 61.2 AppSearch sloppy/unlimited scoring can skip the full pre-filter score array — CONFIRMED / P1 search interaction

Path:

- `services/AppSearch.qml`, `fuzzyQuery()`.

The bounded sloppy-search branch is already optimized with incremental top-K
insertion.

The **unlimited** sloppy branch still does:

1. `_cachedList.map(...)` to create a score record for every app;
2. `.filter(item => item.score > scoreThreshold)`;
3. sort retained score records;
4. decorate the sorted entries.

Overview Search calls `AppSearch.fuzzyQuery(appQuery)` without a limit, so this
is a real debounced search path rather than a dormant compatibility branch.

Strict-safe direction:

- allocate only `results = []`;
- iterate every cached app/name pair in the same order;
- compute Levenshtein score and the same startsWith/word/contains boosts;
- clamp score exactly as today;
- append `{entry, score}` only when it passes the current strict
  `score > scoreThreshold` predicate;
- retain the exact current descending score sort and final decoration pass.

The current filter preserves source order before sort; ordered pushes preserve
the same sort input, including tie order presented to QV4's existing comparator.

For N cached apps:

- full N-element pre-filter score array: **1 -> 0**;
- separate filter traversal: **N -> 0**;
- score computations remain exactly N.

No top-K behavior, threshold, scoring or final sort is changed.

### 61.3 CalendarSync updateSource can capture the first matching index while cloning — CONFIRMED / P2 Settings action

Path:

- `services/CalendarSync.qml`.

Current `updateSource(sourceId, updates)`:

1. clones every source with
   `root.sources.map(source => Object.assign({}, source))`;
2. scans the cloned array again with
   `findIndex(s => s.id === sourceId)`;
3. replaces the first matching clone and publishes the full cloned source list.

The full clone is important and should remain: it preserves the current
snapshot/publication behavior.

Strict-safe direction:

- during that same mandatory map, create the clone first;
- if no earlier match has been recorded and
  `clone.id === sourceId`, retain that index;
- return every clone exactly as today;
- after the complete clone pass, apply `updates` to the retained first index
  and publish exactly as current source does.

This preserves:

- all source objects being cloned before Config publication;
- first-duplicate-ID wins;
- no Config write when no ID matches;
- clone order and update merge semantics.

For S sources:

- second `findIndex` scan: **up to S -> 0**.

### 61.4 MonitorVisibilityConfig can reduce two repeated name-enumeration patterns without introducing shared cache state — CONFIRMED / P1-P2 while monitor arrangement is active

Path:

- `modules/settings/MonitorVisibilityConfig.qml`.

#### A. connectedScreenNames(): Set membership with ordered array output

Current function visits `Quickshell.screens`, normalizes every screen name with
`String(...)`, then suppresses duplicates using growing
`names.includes(name)`.

For S distinct connected names this has quadratic-shaped membership comparisons.

Because every candidate is already converted to a string, `Array.includes`
and `Set.has` have the same relevant SameValueZero membership behavior.

Strict-safe direction:

- keep the ordered `names` result;
- add an invocation-local `seen` Set;
- on every nonempty name, append only if `!seen.has(name)`, then add it.

First-seen order and duplicate suppression remain identical.

Membership changes from worst-shaped **O(S²) -> O(S)**.

#### B. niriOutputNames(): reuse and compact the already-created key array

Current function first executes:

`Object.keys(monitorLayoutSnapshot).length > 0`

to choose between staged layout and live Niri outputs.

It then executes:

`Object.keys(source).filter(validOutput).sort(existingComparator)`.

When the staged snapshot is active, the same object's keys are enumerated
twice. In both staged/live cases, `filter()` also allocates a second names
array.

Strict-safe direction:

- retain `snapshotKeys = Object.keys(monitorLayoutSnapshot)`;
- choose the same source from `snapshotKeys.length`;
- if staged source is selected, reuse `snapshotKeys`; otherwise create the one
  live-source key array;
- stable-compact that fresh key array in place with the exact current
  `logical !== undefined || width !== undefined` predicate;
- run the exact existing geometry comparator on the compacted array.

No persistent output cache/property is introduced; every call still observes
the current staged/live state.

Fresh arrays per call:

- staged snapshot: **3 -> 1** for key/filter collection stages;
- live fallback: **3 -> 2**.

This matters beyond page initialization because `niriOutputNames()` is called
from monitor-overlap/touch/candidate calculations and several drag-related
bindings while the arrangement UI is active.

### 61.5 Round-47 conclusion

New strict-lossless groups:

1. Taskbar/Tray one-pass toggle-pin mutation (§61.1,
   **CONFIRMED / P2 interaction**);
2. AppSearch sloppy/unlimited direct score collection (§61.2,
   **CONFIRMED / P1 search interaction**);
3. CalendarSync updateSource index capture during mandatory clone (§61.3,
   **CONFIRMED / P2**);
4. MonitorVisibility connected/output-name collection reductions (§61.4,
   **CONFIRMED / P1-P2 arrangement path**).

Rejected as new findings during this sweep:

- MinimizedWindows temporary collections already belong to §45.1-§45.4;
- Dock running-order Set/Map cleanup already belongs to §37.5;
- Dashboard available-ID Set membership already belongs to §49.7;
- AiProviderCatalog repeated concat already belongs to §48.11;
- Keyring argument reduction has only two fixed properties and is not worth
  promoting over the hotter paths above;
- Session `map(pid).forEach` is a logout-only micro and remains below the
  research priority threshold.

No number above is an end-to-end Hadalis speedup. Numeric reductions are local
source-derived operation/allocation counts only.

No runtime/source implementation is authorized by this handoff.
---

## 62. Round 48 — shared launch normalization and hidden debug-argument work (2026-09-30)

### Snapshot / concurrency safety

This round continues from Round-47 docs commit
56d2a0264c60dda18093cbf7c34237eea86505f1.

Any concurrent branch movement is accepted only after an in-transaction
fast-forward compare proves it is limited to the already-audited agent,
automation, or Hadalis live-transport test/install paths. Runtime or handoff
changes abort the write.

No runtime/QML/native implementation is authorized by this round.

### 62.1 ShellExec can normalize the fresh Array.from result in place — CONFIRMED / P1-P2 broad launch path

Path:

- modules/common/functions/ShellExec.qml, execDetachedArgs().

Current shared launch helper starts with:

Array.from(args ?? [])
  .map(arg => String(arg ?? ""))
  .filter(arg => arg.length > 0)

Keeping Array.from is important because callers may pass QML list-like values,
not only native JS arrays.

But the result of Array.from is already a fresh JS array.

Strict-safe direction:

- retain that exact Array.from conversion;
- walk the fresh array with read/write indices;
- compute String(arg ?? "") exactly once;
- keep only strings with length > 0;
- truncate the same array to retained length;
- keep the existing empty-command early return and all systemd/environment
  launch logic untouched.

Per call:

- map-result array: **1 -> 0**;
- filter-result array: **1 -> 0**;
- normalization/filter order and final argv order are unchanged.

This is the shared-helper analogue of §60.6's AppSearch-local command cleanup
and reaches every ShellExec.execDetachedArgs() caller.

### 62.2 YtMusic computes JSON strings that its logger can never consume — CONFIRMED / P2

Path:

- services/YtMusic.qml.

YtMusic's logger is a single-parameter function:

function _log(msg) { if (root.verbose) console.log(msg) }

Two browser-detection paths nevertheless pass extra arguments including
JSON.stringify(root.detectedBrowsers).

JavaScript evaluates all call arguments before invoking the function, so the
browser list is serialized even though _log(msg) discards that value both when
verbose is false and when verbose is true.

Strict-safe direction:

- remove the ignored extra arguments from those two calls;
- retain the first string argument exactly.

Observable log output is byte-identical because only that first string has ever
been printed by this logger.

Removed:

- up to two full JSON.stringify(detectedBrowsers) operations per auto-connect
  detection lifecycle.

### 62.3 Debug-disabled callers should not materialize key arrays / JSON strings before _log() — CONFIRMED / P2

Paths:

- services/MaterialThemeLoader.qml;
- services/WindowPreviewService.qml;
- modules/settings/SidebarsConfig.qml.

These files use a variadic logger whose body checks:

Quickshell.env("QS_DEBUG") === "1"

before printing.

However JavaScript evaluates call arguments before entering _log().

Current examples therefore perform work even with QS_DEBUG disabled:

- MaterialThemeLoader: Object.keys(json).length before the applying-color log;
- WindowPreviewService: Object.keys(previewCache).length after cache scan;
- SidebarsConfig: several JSON.stringify(current) calls during right-sidebar
  widget mutation.

Strict-safe direction:

- guard only these expensive diagnostic-value constructions with the exact same
  QS_DEBUG condition, or move construction into a helper evaluated only after
  that condition passes;
- retain current diagnostic content and evaluation point when debug is enabled;
- leave non-diagnostic state work untouched.

With debug disabled:

- theme JSON key enumeration/allocation: **1 -> 0** per apply;
- preview-cache key enumeration/allocation: **1 -> 0** per scan completion;
- sidebar widget-array JSON serialization: **up to several -> 0** per mutation.

Debug-enabled output remains unchanged.

### 62.4 SidebarsConfig setWidget can resolve membership/index once — CONFIRMED / P2 Settings interaction

Path:

- modules/settings/SidebarsConfig.qml.

setWidget(widgetId, active) first copies the configured right-sidebar widget
array.

Current remove path then does:

1. current.includes(widgetId);
2. current.indexOf(widgetId);
3. splice(index, 1).

Both membership operations use exact equality and search the same unchanged
local snapshot.

Strict-safe direction:

- compute const index = current.indexOf(widgetId) once;
- add when active && index === -1;
- remove with splice(index, 1) when !active && index !== -1;
- retain the same no-change branch and Config publication.

Remove interaction:

- linear membership scans: **up to 2 -> 1**.

Add semantics, first-match removal and final ordering are unchanged.

### 62.5 TlpService allowed-limit normalization can filter and round in one pass — CONFIRMED / P2 detect/refresh path

Path:

- services/TlpService.qml.

When detector JSON is applied, current source computes:

data.allowedLimits
  .filter(value => typeof value === "number" && isFinite(value))
  .map(value => Math.round(value))

Strict-safe direction:

- allocate one result array;
- iterate source values in order;
- apply the exact current type + finite predicate;
- append Math.round(value) only for passing values;
- assign that final array exactly where current source does.

Preserved:

- non-array input still publishes [];
- invalid/nonfinite values are excluded;
- valid values retain source order and duplicates;
- rounding behavior is unchanged.

For L supplied limits:

- filtered intermediate array: **1 -> 0**;
- second traversal over retained values is folded into the first pass.

### 62.6 Round-48 conclusion

New strict-lossless groups:

1. ShellExec fresh-array argument compaction (§62.1,
   **CONFIRMED / P1-P2 broad launch path**);
2. YtMusic ignored extra debug arguments (§62.2,
   **CONFIRMED / P2**);
3. lazy construction of expensive debug-only arguments (§62.3,
   **CONFIRMED / P2**);
4. Sidebars right-widget one-index mutation (§62.4,
   **CONFIRMED / P2 interaction**);
5. TLP allowed-limit filter/round fusion (§62.5,
   **CONFIRMED / P2**).

No numeric reduction above is an end-to-end Hadalis speedup. Values are local
source-derived operation/allocation reductions only.

No runtime/source implementation is authorized by this handoff.

---

## 63. Round 49 — autocomplete, task models and local collection compaction (2026-09-30)

### Snapshot / concurrency safety

This docs-only round continues from §62. Exact parent: `bac7d7d54015ce486136e1571b19711efe005d80`.

Concurrent movement was accepted only when compare proved a clean fast-forward
limited to audited `agent/*`, `automation/*`, or Hadalis automation
test/install paths. The branch is checked again before the non-forced ref
update. No runtime/QML/native implementation is authorized.

### 63.1 AiChat specialized autocomplete can parse prefix state once per keystroke — CONFIRMED / P1-P2 interaction

Path: `modules/sidebarLeft/AiChat.qml`.

The `model`, `prompt`, `save`, `load` and `tool` branches recompute
`messageInputField.text.trim().split(" ").length == 1` inside every result
callback. Keep branch/`suggestionQuery`/`Fuzzy.go` ordering, then compute that
same invariant once immediately before row construction.

For R fuzzy results, trim/split work is **R -> 1**.

The model branch also maps every fuzzy result to row-or-null and then filters
nulls for missing `Ai.models[model.target]`. Append only resolved rows directly
to one final array in source order. This removes one R-element row/null array
and the second filter traversal without changing surviving rows/order.

### 63.2 Three command-suggestion UIs can collect matching rows directly — CONFIRMED / P2 per-keystroke

Paths:

- `modules/sidebarLeft/AiChat.qml`;
- `modules/sidebarLeft/Anime.qml`;
- `modules/sidebarLeft/WallhavenView.qml`.

Each uses
`allCommands.filter(cmd => cmd.name.startsWith(query)).map(cmd => row)`.
`allCommands` is a local JS array and every passing command maps to one row.

One ordered loop can apply the identical predicate and append the identical row.
The filtered command array is **1 -> 0**, and the second traversal is folded
into the source pass. No persistent command/query cache is introduced.

### 63.3 TodoWidget can clone only tasks that survive each tab predicate — CONFIRMED / P1-P2 sidebar interaction

Path: `modules/sidebarRight/todo/TodoWidget.qml`.

Both tabs currently clone every `Todo.list` item with `originalIndex`, then
filter clones by `done`.

Source proof:

- `InternalTodoBackend` normalizes tasks into object literals;
- both Obsidian backends publish task arrays from JSON helper payloads.

Therefore these are plain data records, not live QML objects whose skipped
`Object.assign` getter reads carry reactive dependencies.

Each tab can scan source order, evaluate the same done predicate, and clone only
passing rows while retaining the **source index** as `originalIndex`.

Across the two independently-derived tabs, shallow task clones are roughly
**2N -> N**. Ordering, mutation targeting, indices and row isolation are
unchanged.

### 63.4 OverlayContent can skip its map/null/filter staging array — CONFIRMED / P2 overlay interaction

Paths:

- `modules/ii/overlay/OverlayContent.qml`;
- `modules/ii/overlay/OverlayContext.qml`.

Current ScriptModel values map each open identifier through
`availableWidgets.find(...)`, then filter null/undefined.

`availableWidgets` is a readonly literal list of plain descriptor objects.
Keep the same per-identifier `find` call, preserving first-match and
short-circuit behavior, and append only non-null results to one final array.

Removed: one mapped descriptor/null array and the O(open) filter traversal.
Open order, duplicates, missing-widget suppression and descriptor identity are
unchanged. No persistent Map is required.

### 63.5 Both recording Settings families can build audio-source options in one array — CONFIRMED / P2 Settings interaction

Paths:

- `modules/settings/ToolsConfig.qml`;
- `modules/waffle/settings/pages/WInterfacePage.qml`.

Both duplicate system-audio and microphone helpers that currently create an
Auto row, `filter` detected sources, `map` option objects, then `concat`
before `ensureOption(...)`.

Start with the same Auto row, scan sources once, apply the exact current
`.monitor` predicate and push the identical option object only for passing
sources. Keep `ensureOption` at the same point.

Per helper: filtered array **1 -> 0**, mapped staging array **1 -> 0**, concat
result/full-prefix copy **1 -> 0**. Keep the two helpers independent rather than
adding shared cached partition state.

### 63.6 TlpSettingsService can reuse already-fresh arrays while preserving filter/map phases — CONFIRMED / P2 Settings path

Path: `services/TlpSettingsService.qml`.

The schema is loaded by `JSON.parse`; local groups are plain JS objects.

For `settingsForCategory()`, `root._array(...)` already returns a fresh
`Array.from` result. Stable-compact that array in place with the exact
`settingAvailable` predicate, then retain the existing adaptation map. This
preserves the current phase rule that all availability checks finish before
adaptation and removes one filtered-settings array.

For `groupsForCategory()`, keep the complete existing final map over
`orderedIds`, then stable-compact that fresh mapped array in place with the
same `group.settings.length > 0` predicate. This removes one filter-result
array while preserving group/query/clone/order semantics.

### 63.7 Themes favorite-first sorting can use invocation-local Set membership — CONFIRMED / P2 theme search/filter interaction

Path: `modules/settings/ThemesConfig.qml`.

`filteredPresets` calls `favorites.includes(a.id)` and
`favorites.includes(b.id)` inside every sort comparator invocation.
The schema defines `favoriteThemes` as `list<string>`.

Build one invocation-local Set and use `has(id)` in the unchanged comparator.
Array `includes` and Set membership use SameValueZero for this contract, and
the comparator still returns the same favorite-rank difference, preserving
equal-rank tie behavior.

Cost shape changes from repeated linear favorite-list scans inside O(N log N)
comparator work to one O(F) Set construction plus constant membership checks.
No persistent favorite cache is introduced.

### 63.8 Stale-search closures — ALREADY / CLOSED

Exact current source shows that:

- `services/deferred/Emojis.qml` sloppy unlimited scoring already
  direct-collects passing records;
- `services/deferred/Cliphist.qml` already does the same;
- `modules/sidebarRight/sysmon/SysMonWidget.qml` no longer parses
  `/proc/net/dev` itself and uses `ResourceUsageMonitor`, consistent with
  §34.7.

Do not reopen those stale search snippets.

### 63.9 Round-49 conclusion

New strict-lossless groups:

1. AiChat invariant prefix parsing + resolved-model collection (§63.1,
   **CONFIRMED / P1-P2 interaction**);
2. direct command suggestions across AiChat/Anime/Wallhaven (§63.2,
   **CONFIRMED / P2**);
3. Todo clone-only-matching models (§63.3,
   **CONFIRMED / P1-P2 sidebar interaction**);
4. Overlay one-array widget model (§63.4, **CONFIRMED / P2**);
5. recording audio-source direct construction in both Settings families
   (§63.5, **CONFIRMED / P2**);
6. TLP fresh-array compaction (§63.6, **CONFIRMED / P2**);
7. Themes favorite-membership Set (§63.7, **CONFIRMED / P2 interaction**).

Old Emoji/Cliphist scoring and SysMon parsing snippets are closed as stale
(§63.8).

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived operation/allocation reductions.

No runtime/source implementation is authorized by this handoff.



## 64. Round 50 — bounded result construction and local lookup indexing (2026-09-30)

Research base for this round was re-fetched from `dev` immediately before the
documentation write:

- current audited `dev` HEAD: `b7af2105c02541994c6999578048ef38f1c511de`;
- previous research commit: `621f94f98f27d57d413a724d9b8c1231da54856d`
  (Round 49);
- the 30 intervening commits were audited in two compare windows
  (`621f94f..60872fc` and `60872fc..b7af2105`);
- those intervening changes touch only `agent/`, `automation/` and related
  automation test/install scripts, not runtime QML/native/services and not this
  handoff.

Before promotion, the handoff was searched for each path/shape below. Existing
ownership such as GlobalActions §48.5, Notifications §48.10, Overview §41.8,
CompositorService §46.4-§46.5, AI §48.12-§48.13/§55.3/§59.4-§59.5 and Network
§50.1/§59.12 was not re-counted.

### 64.1 World-clock timezone suggestions can stop exactly at the UI cap — CONFIRMED / P1-P2 Settings interaction

Path:

- `modules/settings/InterfaceConfig.qml`, `worldClockSection.filteredTimezones()`.

The current catalog is a readonly literal array of **58** plain JS records.
Every suggestion evaluation currently performs:

`timezoneCatalog.filter(predicate).slice(0, 10)`

where the predicate is:

`!current.includes(e.tz) && e.tz.toLowerCase().includes(q)`.

The UI can consume at most the first ten passing entries, but `filter()`
continues across all 58 records and materializes every match before `slice()`
allocates the capped result.

Strict-lossless direction:

1. keep the current `q` normalization and `current` read at the same point;
2. allocate one fresh result array;
3. scan `timezoneCatalog` in source order;
4. keep the exact `current.includes(e.tz)` test rather than replacing the
   Config QML sequence with a different membership representation;
5. preserve the current short-circuit order, so `toLowerCase().includes(q)`
   is read only after the entry is not already configured;
6. append the same catalog object reference when it passes;
7. stop immediately when result length reaches 10.

Why the early exit is strict here, unlike a generic `filter().slice()`
rewrite:

- every catalog row is a literal plain JS object defined in this component;
- the skipped suffix therefore has no getters/callbacks/QML property reads whose
  evaluation is observable;
- the reactive dependencies on input text, Config timezones and
  `timezoneCatalog` are all captured before/during the same executed prefix;
- `current.includes()` semantics, duplicate handling, source order and object
  identity are unchanged;
- the function still publishes a fresh array on every evaluation.

With no configured timezone and a broad query that admits at least ten rows,
predicate visits are **58 -> 10** (82.8% fewer for that local case). Other
queries stop at the tenth actual match or still scan all 58 when fewer than ten
match. The filter-result array and subsequent slice array become one bounded
result array.

### 64.2 AI catalog IPC can avoid the unbounded filtered-match array while preserving malformed-cache errors — CONFIRMED / P2

Paths:

- `services/Ai.qml`, IPC target `ai`, method `catalog(query)`;
- `services/ai/AiProviderCatalog.qml`.

Current code does:

`AiProviderCatalog.models.filter(predicate).slice(0, 100)`

and then maps those at-most-100 model references to the JSON response shape.

A tempting optimization is to stop scanning after the hundredth match. That is
**OUT OF STRICT-LOSSLESS** for the current malformed-state contract: cached
catalog data is loaded from JSON without per-record validation, and for a
nonempty query the current filter still reads
`providerId/remoteId/displayName` on every later model. A malformed later
record can therefore throw even after 100 valid matches; an early break could
hide that error.

There is still a strict local reduction:

1. read the current models sequence and normalized query exactly as today;
2. scan every model in the same order;
3. evaluate the exact current predicate for every model, including the suffix
   after 100 matches;
4. append a matching model reference only while the result contains fewer than
   100 entries;
5. keep the existing response-object map and `JSON.stringify` unchanged.

This preserves:

- the full predicate/property-read and throw behavior for nonempty queries;
- the empty-query behavior, where the predicate returns true without reading
  model fields;
- first-100 membership and order;
- duplicate model records and reference identity;
- mapping/serialization error behavior for records that actually enter the
  response.

For N catalog records and K matches, predicate work remains N by design, but
temporary match storage changes from an array of K references plus a second
up-to-100 slice array to one array bounded by **min(K, 100)**. This is
particularly useful for broad/empty IPC catalog requests against large provider
catalogs without weakening malformed-state parity.

### 64.3 Theme Quick Access can resolve IDs through one first-wins local preset index — CONFIRMED / P2-P3 Settings interaction

Paths:

- `modules/settings/ThemesConfig.qml`, `quickAccessSection.quickAccessItems`;
- `modules/common/ThemePresets.qml`;
- `modules/common/Config.qml`.

After constructing favorite IDs plus at most four non-favorite recent IDs, the
current binding performs one full/partial:

`ThemePresets.presets.find(p => p.id === ids[i])`

for every ID.

Current `ThemePresets.presets` is a readonly literal array of **49** plain
preset records. Config defines both `recentThemes` and `favoriteThemes` as
`list<string>`.

Strict-lossless direction:

- preserve the existing favorite/recent ID construction exactly;
- if `ids.length === 0`, return the same fresh empty result without touching
  preset membership work;
- otherwise read `ThemePresets.presets` at the same phase and build one local
  `Map` from preset ID to preset reference;
- use **first-wins** insertion (`if (!map.has(id)) map.set(id, preset)`) so
  future duplicate preset IDs retain the current `.find()` first-match
  contract;
- walk `ids` in its existing order, append the resolved reference when
  present, and skip missing IDs exactly as today.

For this string-only contract, strict equality used by the current
`.find()` and Map membership cannot diverge on the configured IDs; order,
duplicates in the requested ID list, missing-ID suppression and returned
preset identity remain unchanged. No persistent cache or additional resident
preset copy is introduced.

Cost changes from up to O(I*P) preset-ID comparisons for I Quick Access IDs and
P presets to O(P+I) local work. At the current P=49 this is modest for the
usual small favorite list, but it prevents lookup cost from multiplying as
favorites and the built-in preset catalog grow.

### 64.4 Round-50 conclusion

New strict-lossless groups:

1. bounded World Clock timezone suggestion collection (§64.1,
   **CONFIRMED / P1-P2 interaction**);
2. bounded AI catalog IPC result storage while retaining full malformed-input
   predicate scanning (§64.2, **CONFIRMED / P2**);
3. first-wins local Theme Quick Access preset indexing (§64.3,
   **CONFIRMED / P2-P3 interaction**).

The superficially faster AI “break after 100 matches” variant is explicitly
**OUT OF STRICT-LOSSLESS** and must not be substituted for §64.2 without adding
and proving a stronger validated-model invariant first.

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived operation/allocation reductions.

No runtime/source implementation is authorized by this handoff.


## 65. Round 51 — pointer-hot Dashboard geometry and bounded clipboard/render staging (2026-09-30)

This round was researched from and revalidated against current `dev` HEAD
`51e331d52b40ff3ca8b19eebb4477c087e811a4e` (Round 50). No intervening
commit existed immediately before this documentation write.

The handoff was searched before promotion for `DashboardCanvas.qml`,
`_smartAlignMove`, `_smartAlignResize`, `ClipboardPanel.qml`,
`navigateMode`, `LiquidOrbitalField.qml`, `traceClosed` and the relevant
reverse-array shapes. Existing generic reverse-scan findings such as §58.2 and
§60.1 concern different ownership/data-flow contracts and are not counted here.

### 65.1 Dashboard smart alignment can remove per-neighbour anchor arrays and fuse corner-resize axis scans — CONFIRMED / P1 interaction-hot

Path:

- `modules/dashboard/DashboardCanvas.qml`.

`updateInteraction()` calls:

- `_smartAlignMove()` on every drag pointer update;
- `_smartAlignResize()` on every resize pointer update.

The interaction baseline is captured by `_snapshotVisibleRects()` as plain
numeric rectangle objects before direct manipulation begins.

#### Move path

`_smartAlignMove()` currently allocates:

- one three-element `activeXs` array;
- one three-element `activeYs` array;
- for every neighbour, one three-element `otherXs` array;
- for every neighbour, one three-element `otherYs` array.

Those arrays exist only to execute the fixed 3x3 anchor comparisons.

Strict-safe direction:

- keep the same neighbour traversal;
- compare the three active anchors and three neighbour anchors as scalar values;
- preserve the **exact current comparison order**:
  active left/center/right outer order, neighbour left/center/right inner order;
- retain the strict `distance < best.distance` replacement rule so equal-distance
  ties continue to select the same earliest comparison;
- retain the later equal-spacing and diagonal passes exactly as separate passes.

The final point matters. The diagonal guide uses `fitted` **after**
equal-spacing can modify `fitted.x` / `fitted.y`. Therefore fusing the
equal-spacing and diagonal passes would change the geometry basis and is **not**
authorized by this finding.

For O neighbours, the move path removes **2 + 2O short anchor arrays per pointer
update** while retaining the same comparison count and all three neighbour
passes.

#### Resize path

`_smartAlignResize()` currently:

- for west/east edges, scans all O neighbours and allocates a two-element
  horizontal target array per neighbour;
- for north/south edges, independently scans all O neighbours and allocates a
  two-element vertical target array per neighbour.

For a corner resize both branches run, so the same neighbour list is traversed
twice.

Strict-safe direction:

- derive the same two horizontal and/or vertical target scalars directly;
- for a corner edge, visit each neighbour once and evaluate the horizontal pair
  and vertical pair independently;
- preserve each axis' target order and strict `distance < best.distance` tie
  rule;
- keep guide creation, min-size clamping, `_fitRectToCanvas()`,
  `_smartSnapAxes`, downstream feasible-layout resolution and preview
  publication in their current order.

The rectangle snapshots are plain numeric data, so interleaving the independent
X/Y comparisons per neighbour does not reorder QML property getters, callbacks
or side effects.

For corner resize:

- neighbour visits: **2O -> O**;
- target arrays: up to **2O -> 0**.

For one-axis resize the visit count remains O, but its O target arrays are still
removed.

No persistent geometry cache is introduced.

### 65.2 Clipboard navigate-search can remember the first matching row while building the ListModel — CONFIRMED / P1-P2 search interaction

Path:

- `modules/clipboard/ClipboardPanel.qml`.

The ii Clipboard panel debounces search by 70 ms. In
`hasSearch && navigateMode`, `updateFilteredModel()`:

1. clears the model;
2. appends all pinned rows in pin order, marking `isMatch`;
3. appends all clipboard rows in history order, marking `isMatch`;
4. counts matches;
5. publishes `totalCount` and `matchCount`;
6. when at least one match exists, scans `filteredClipboardModel` again with
   `get(i).isMatch` until the first match, then focuses/centres that row.

The service caps clipboard history at 400 entries; pins precede history rows.

Strict-safe direction:

- keep all current hit predicates and append calls unchanged;
- maintain one local output-row index while rows are appended;
- the first time a row with `hit === true` is about to be appended in navigate
  mode, record that row index;
- continue building the full model and counting every match exactly as today;
- keep `totalCount` then `matchCount` publication in the same order;
- call the same `currentIndex` assignment and
  `positionViewAtIndex(..., ListView.Center)` using the recorded index.

This preserves:

- pin-before-history order;
- every row object and `isMatch` value;
- all match predicates and their evaluation order;
- duplicate entries/pins;
- full-model publication before focus/scroll;
- match count;
- first-match precedence.

It removes the post-build ListModel lookup pass. With P pins and N history
entries, that pass changes from up to **P + N `ListModel.get()` calls -> 0**
per debounced navigate-search rebuild.

Waffle Clipboard does not have this navigate-mode second scan and is therefore
not included in this finding.

### 65.3 LiquidOrbitalField Canvas fallback can trace reverse contours without clone+reverse arrays — CONFIRMED / P1-P2 conditional per-frame

Path:

- `modules/bar/weather/LiquidOrbitalField.qml`.

The shader is the preferred backend. While the shader is unavailable, compiling
or has failed, the threaded Canvas fallback repaints from `FrameAnimation`.

Every fallback frame constructs dense point arrays and then performs three
reverse contour calls:

- `inner.slice().reverse()` for the main body;
- `sheetInner.slice().reverse()` for sheet 0;
- `sheetInner.slice().reverse()` for sheet 1.

The clones exist only to feed `traceClosed()` in reverse point order; the
original arrays are not mutated.

Strict-safe direction:

- retain the existing dense point construction and all draw-call order;
- extend the tracing helper (or add a reverse helper) so reverse mode indexes
  the original point array from `count - 1` down to zero;
- for every logical trace index, map the current `p0/p1/p2/p3` cyclic
  Catmull-Rom-to-Bezier neighbours to the exact indices they would have in the
  reversed clone;
- keep the same `moveTo`, `bezierCurveTo`, close/fill operations and
  floating-point arithmetic on point coordinates;
- do not call `reverse()` on the original arrays.

Because `inner` and both `sheetInner` arrays are freshly built, dense arrays
of plain `{x,y}` records within the same `onPaint` invocation, reverse-index
reads have no getter, reactive or mutation-order difference from reading a
`slice().reverse()` clone.

For sample count S, this removes per fallback frame:

- **3 arrays of S point references**;
- three S-element clone copies;
- three reverse relocation passes.

It does not change `liquidSample()` count, Canvas path complexity, shader
behavior, frame cadence or rendered geometry.

Status is conditional only because normal systems that reach
`ShaderEffect.Compiled` stop using the Canvas renderer; when fallback is
active, this is genuinely per-frame.

### 65.4 Cheatsheet conflict lookup persistent indexing is not promoted — CLOSED under current strict reactive contract

Paths:

- `modules/settings/CheatsheetConfig.qml`;
- `services/deferred/NiriKeybinds.qml`.

The add/edit key-combination fields currently use a first-match
`NiriKeybinds.allBinds.find(...)` on text changes.

A persistent `key_combo -> bind` index would reduce repeated scans, but it
would add retained state and change the QML dependency/publication graph between
the field binding and `allBinds`. Under the current strict standard, equal
steady-state text is insufficient proof for changed-signal/dependency parity.

Building a new local Map on every keystroke is O(N) like the existing first
match and adds allocation, so it is not a useful strict local optimization.

Do not reopen this static hit as a confirmed optimization unless an imperative
index publication design proves exact `allBinds` replacement/change ordering
or profiling establishes a reason to accept a different architecture contract.

### 65.5 Round-51 conclusion

New strict-lossless groups:

1. Dashboard pointer-hot smart-alignment allocation reduction plus corner-resize
   scan fusion (§65.1, **CONFIRMED / P1 interaction-hot**);
2. Clipboard navigate-search first-match tracking (§65.2,
   **CONFIRMED / P1-P2 search interaction**);
3. Liquid weather Canvas fallback reverse-contour tracing without clone/reverse
   staging (§65.3, **CONFIRMED / P1-P2 conditional per-frame**).

Cheatsheet persistent conflict indexing is explicitly closed under the current
reactive contract (§65.4) rather than counted.

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived operation/allocation reductions.

No runtime/source implementation is authorized by this handoff.


## 66. Round 52 — wallpaper navigation duplicate work and color-sort lookup locality (2026-09-30)

This round continued immediately after Round 51. Before documentation, `dev`
advanced from the Round-51 commit
`9062b9ba329f04ef6ffe8656996e690f28115b84` to
`1816942a3868af612cf819ff798996dbc47aa82b`.

The two intervening commits were audited with a direct compare. Their net tree
delta is limited to the automation manager and its scripts/tests; they do not
touch runtime QML, wallpaper services or this handoff. The candidate source
files were then re-fetched from current `dev`.

The handoff was searched before promotion for
`WallpaperCoverflowGallery.qml`, `_prefetchAroundIndex`,
`ensureThumbnailForPath`, `WallpaperSkewView.qml`,
`_rebuildIndexMaps`, the color-sort comparator and related ownership.
Historical Skew color-analysis work (§19.1/§39.9) concerns process/decode
policy, not the comparator lookup work below.

### 66.1 Coverflow navigation executes the same thumbnail prefetch window twice — CONFIRMED / P1-P2 navigation interaction

Paths:

- `modules/wallpaperSelector/WallpaperCoverflowGallery.qml`;
- `services/Wallpapers.qml`.

For a real index change, `_goToIndex()` currently:

1. assigns `currentIndex = bounded`;
2. the QML `onCurrentIndexChanged` handler immediately calls
   `_prefetchAroundIndex(currentIndex)`;
3. control returns to `_goToIndex()`, which calls the same
   `_prefetchAroundIndex(currentIndex)` again;
4. the focus pulse is then restarted when animations are enabled.

The prefetch radius is 4 in preview mode and 8 normally, so one prefetch visits
up to 9 or 17 model positions respectively. Each surviving position performs:

- directory-role lookup;
- path-role lookup;
- path normalization/validation in `ensureThumbnailForPath()`;
- expected-thumbnail-path derivation;
- key construction and pending-key check.

The first call synchronously marks a new request in
`Wallpapers._singleThumbPending` before enqueueing/starting the process. That
pending key is cleared only from the asynchronous Process exit path. Therefore
the immediate second call cannot enqueue a duplicate thumbnail job: for every
key just requested by the first pass it reaches the pending guard and returns.
Keys already pending before navigation are rejected by both passes identically.

Strict-lossless direction:

- retain `onCurrentIndexChanged: _prefetchAroundIndex(currentIndex)` as the
  sole index-change prefetch owner;
- remove only the explicit duplicate call inside `_goToIndex()`;
- keep the index assignment, keyboard-guide state change and focus-pulse call in
  their existing logical order;
- keep `updateThumbnails()` prefetching intact, because size changes and
  explicit thumbnail refresh are a separate trigger.

Parity details:

- the same index-change signal still owns the first prefetch in the same event
  loop turn;
- prefetch center/radius/order are unchanged;
- directory/empty-path suppression is unchanged;
- request key, queue order, process command and thumbnail publication are
  unchanged;
- no callback/process exit can interleave between the two current synchronous
  passes, so removing the second pass does not remove a possible enqueue;
- animation configuration/duration and signal ordering are unchanged.

For a normal full-radius interior navigation, prefetch model-position visits are
**34 -> 17**. For preview mode they are **18 -> 9**. This is a local duplicate
work reduction; actual file/process work was already deduplicated by
`_singleThumbPending`.

### 66.2 Skew color sorting can lazily memoize comparator metadata within one rebuild — CONFIRMED strict-lossless / P1-P2 when color sort is active

Path:

- `modules/wallpaperSelector/WallpaperSkewView.qml`,
  `_rebuildIndexMaps()`.

After filtering, color sort currently runs this work on every comparator call:

1. `folderModel.get(a, "fileName")`;
2. `folderModel.get(b, "fileName")`;
3. hue lookup for A;
4. hue lookup for B;
5. if both normalized hue buckets tie, saturation lookup for B then A.

The same model index is therefore re-read many times across an O(N log N)
sort. The color database is loaded through `JSON.parse` and updated with plain
data records; it has no accessor/callback semantics.

A strict-safe invocation-local direction is to use lazy metadata caches scoped
only to this one `_rebuildIndexMaps()` color sort:

- cache file name by model index only on the first comparator encounter;
- cache hue only when the current comparator reaches its hue-read point;
- cache saturation only when the current comparator reaches the existing
  equal-bucket branch;
- keep comparator evaluation order exactly:
  filename A, filename B, hue A, hue B, then (only on a tie) saturation B,
  saturation A;
- keep the existing hue normalization and numeric subtraction unchanged;
- discard all caches when `_rebuildIndexMaps()` returns.

Why this remains within the strict contract:

- `_rebuildIndexMaps()` is invoked imperatively from filter/sort/folder/color
  update paths, not as a QML binding expression whose dependency capture would
  be narrowed by memoization;
- `FolderListModel.get()` role reads are side-effect-free observations of the
  same model during the synchronous sort; model change events cannot interleave
  inside that JavaScript sort call;
- the color cache contains plain JSON-derived records, so repeated field reads
  have no getter side effects;
- lazy population means empty/singleton arrays do not gain reads that
  `Array.sort()` currently skips;
- saturation is still unread for non-tied hue buckets;
- comparator return values, source references, stable/tie ordering and final
  integer `_imageIndexMap` publication are unchanged;
- no persistent CPU-for-resident-memory cache is introduced.

For C comparator calls over M distinct compared entries:

- `fileName` QML role reads change from **2C -> at most M**;
- hue metadata reads change from **2C -> at most M**;
- saturation reads change from twice every tied-bucket comparison to at most
  once per entry that actually participates in a tied-bucket comparison.

The tradeoff is temporary O(M) lookup state for the duration of the rebuild,
not retained shell memory. No end-to-end percentage is claimed; the benefit
grows with wallpaper-folder size and is limited to color-sort rebuilds.

### 66.3 Similar-looking debounce restart in WallpaperLauncherList is not promoted — CLOSED under exact timing semantics

Path:

- `modules/wallpaperLauncher/WallpaperLauncherList.qml`.

`syncCurrentIndexAndPreview()` restarts `previewDebounce` after
`syncCurrentIndex()`, while a changed index also triggers
`onCurrentIndexChanged: previewDebounce.restart()`.

Unlike §66.1, the second operation here is not a pure pending-key rejection: a
second Timer restart changes the debounce deadline. Removing one restart can
therefore change when a static/animated wallpaper preview begins, even if only
slightly.

Because preview timing is observable and animated previews intentionally use a
different 500 ms debounce, this is **CLOSED** for strict-lossless optimization.
Do not treat generic duplicate-restart greps as no-op work.

### 66.4 Round-52 conclusion

New strict-lossless groups:

1. remove Coverflow's duplicate index-change thumbnail prefetch pass (§66.1,
   **CONFIRMED / P1-P2 interaction**);
2. use only invocation-local lazy metadata reuse for Skew color sort (§66.2,
   **CONFIRMED strict-lossless / P1-P2 when active**).

The superficially similar WallpaperLauncher duplicate debounce restart is
explicitly closed because it changes an observable timer deadline (§66.3).

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived operation/read reductions.

No runtime/source implementation is authorized by this handoff.


## 67. Round 53 — compact-calendar range batching and LocalMusic interaction paths (2026-09-30)

This round was researched and revalidated against current `dev` HEAD
`14c2e30db6bb5f48471e19fc3a5d08a0984f0d40` (Round 52). No intervening
commit existed immediately before this documentation write.

Before promotion, the handoff was searched for
`CompactSidebarRightContent.qml`, `CalendarSync.getEventsForDate`,
`upcomingEvents`, `LocalMusicView.qml`, `resolveSelectedTracks`,
`selectedFolderPaths` and `applyRangeSelection`. Existing calendar ownership
in §49.3-§49.4 and §57.7 is narrower/different: count/presence/source-color
single-day queries and timestamp reuse inside the service's own upcoming sort.
Those findings do not cover the 14-day full-object Compact consumer below.

### 67.1 Compact Upcoming can derive fourteen CalendarSync day buckets from one source pass — CONFIRMED / P1-P2 while Compact calendar is active

Paths:

- `modules/sidebarRight/CompactSidebarRightContent.qml`;
- `services/CalendarSync.qml`.

The Compact Upcoming binding currently builds its external-event portion by
calling:

`CalendarSync.getEventsForDate(d)`

once for each of the next **14** local calendar days.

Each service call independently filters the complete `CalendarSync.events`
array. For every external event, each call reparses date state:

- timed event: one `Date(event.startDate)`;
- all-day event: normalized start plus end Date;
- then a fresh matching-event array is returned for that day.

The caller then traverses each day array in day-major order, applies its own
`evtTime >= now || (e.allDay && evtTime >= startDay)` rule, clones passing
rows, merges local events and sorts.

A direct substitution with `CalendarSync.getUpcomingEvents(14)` is **not**
lossless and must not be used:

- its horizon differs from the Compact caller's exact today..today+13 date
  buckets;
- its timed-event cutoff is range-based rather than the per-day membership
  contract;
- most importantly, the Compact code intentionally/observably emits a multi-day
  all-day event once for **each** overlapping day bucket before the final sort.

Strict-safe direction:

1. preserve the exact fourteen target dates produced from `startDay` with the
   current local-time `setDate()` semantics;
2. add a private/batch CalendarSync query that creates fourteen fresh buckets;
3. read the current `root.events` snapshot once and traverse events in source
   order;
4. for a timed event, parse/normalize its start day once and append the original
   event reference to the matching target bucket, if any;
5. for an all-day event, parse/normalize start/end once, then apply the exact
   current per-target predicate:
   - non-forward/missing end uses the same single-day fallback;
   - forward `DTEND` stays exclusive;
6. append to each matching bucket in source order;
7. in Compact, keep the existing outer day loop and existing per-event
   `evtTime` filter/clone logic unchanged.

Why the final `ext` sequence remains identical:

- each bucket contains exactly the same references that fourteen independent
  `filter()` calls would have returned;
- bucket order is target-day order;
- within each bucket, source-event order is unchanged;
- multi-day all-day events still appear in every overlapping bucket;
- the Compact post-filter still rejects the same already-started all-day rows;
- all public row clones, local/external merge order, final comparator and
  publication remain unchanged.

CalendarSync events come from ICS parser output or JSON cache load, so they are
plain data objects rather than getter-bearing QML objects. The binding still
captures the same `CalendarSync.events` dependency; no persistent date index
is introduced.

For E external events:

- complete source-array predicate traversals: **14E -> E**;
- timed start-Date constructions in the service query: **14 per event -> 1**;
- all-day start/end Date constructions: **up to 28 per event -> 2**;
- target-day numeric overlap checks remain bounded by fourteen for an all-day
  span, which is required to preserve per-day duplication.

The caller's later Date construction, cloning and final sort are deliberately
left unchanged.

### 67.2 LocalMusic search can remove two four-element staging arrays per track — CONFIRMED / P1-P2 per keystroke

Paths:

- `modules/sidebarLeft/LocalMusicView.qml`;
- `services/LocalMusic.qml`.

For every nonempty search query, `filteredTracks` currently evaluates every
library track with:

`[title, artist, album, folder].map(String/lowercase).join(" ")`.

That creates, per track:

1. a four-element raw-field array;
2. a four-element normalized-string map result;
3. then the joined haystack string.

`LocalMusic.libraryTracks` is published from the native MPD snapshot after
`JSON.parse()`, so library rows and their fields are plain JSON data. No
getter/callback/reactive-object semantics are hidden inside the four fields.

Strict-safe one-result-array direction:

- retain the empty-query fast path that returns `LocalMusic.libraryTracks`
  itself;
- for a nonempty query, allocate one fresh result array;
- for each track, first read raw `title`, `artist`, `album`, `folder`
  in that exact order, matching the current array-literal property-read phase;
- then String-convert/lowercase those four captured values in the same order;
- concatenate them with the same three literal spaces;
- apply the same `haystack.includes(root.query)` predicate;
- append the original track reference only on a match.

This preserves:

- source traversal and result order;
- original-reference identity;
- fresh-array publication for nonempty search;
- empty-query alias behavior;
- exact nullish-to-empty String conversion;
- field read and conversion order, including malformed JSON scalar/object/array
  values.

For N library tracks per query update:

- four-element raw arrays: **N -> 0**;
- four-element mapped arrays: **N -> 0**;
- the final matched-track array remains exactly one, as today.

No retained lowercase library cache is introduced.

### 67.3 LocalMusic Shift-range selection can replace growing string-array membership scans with local Sets — CONFIRMED / P2 large-range interaction

Path:

- `modules/sidebarLeft/LocalMusicView.qml`,
  `applyRangeSelection()`.

The current Shift-range path clones the existing selected-track and
selected-folder arrays, then walks the sliced visible entry range.

For every candidate it currently checks duplicate membership with growing:

- `folders.includes(path)`;
- `tracks.includes(key)`.

Both values are strings produced by `normalizedFolder()` / `trackKey()`.
As the selected range grows, repeated membership becomes quadratic in the
worst-shaped interaction.

Strict-safe direction:

1. keep the existing `root.songEntries.slice(from, to + 1)` exactly, so
   current range slicing and malformed index behavior are not reinterpreted;
2. keep the current cloned `tracks` and `folders` output arrays;
3. construct invocation-local Sets from those clones;
4. for each folder/track row, compute the same path/key in the same branch;
5. replace only `.includes(value)` with `Set.has(value)`;
6. when a new value is accepted, push to the existing output array **and** add
   it to the matching Set;
7. publish `selectedTrackKeys` then `selectedFolderPaths` in the same order
   as today.

Parity:

- Array `includes` and Set membership are both SameValueZero; for the actual
  string keys/paths they are identical;
- existing duplicates in malformed/preexisting selection arrays are not
  removed, because the output arrays start as unchanged clones;
- new duplicates are suppressed at the same first encounter;
- range entry order and final selection-array order are unchanged;
- unknown entry types remain ignored;
- no persistent selection index is retained.

For a range of R entries with S preexisting selected strings, the growing
membership component changes from worst-shaped roughly
**O(R x (S + R)) -> O(S + R)** local Set construction/lookups while retaining
the same public arrays.

### 67.4 Nearby attractive hits intentionally not promoted

Two static shapes were checked and closed for this strict round:

- `services/ObsidianTodoBackend.qml` performs `_taskById()` before queuing a
  mutation and again after the asynchronous capability probe. The second scan
  is a deliberate stale-reference revalidation across an async boundary; fusing
  or caching it can authorize a task that disappeared while the probe ran.
- `modules/wallpaperSelector/WallpaperCoverflowView.qml` independently scans
  its FolderListModel for `imageCount` and `folderCount`. Sharing one
  intermediate reactive partition can alter changed-signal/dependency
  publication, while deriving one as `totalCount - otherCount` changes
  malformed non-boolean `fileIsDir` behavior. Do not promote that apparent
  two-scan duplicate without a stronger typed-role/signal contract.

### 67.5 Round-53 conclusion

New strict-lossless groups:

1. one-pass external CalendarSync range bucketing for Compact Upcoming (§67.1,
   **CONFIRMED / P1-P2 while active**);
2. allocation-light LocalMusic library search (§67.2,
   **CONFIRMED / P1-P2 per keystroke**);
3. Set-backed LocalMusic Shift-range duplicate membership (§67.3,
   **CONFIRMED / P2 large-range interaction**).

Obsidian async task revalidation and CoverflowView shared type-count derivation
are explicitly closed rather than counted (§67.4).

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived operation/allocation reductions.

No runtime/source implementation is authorized by this handoff.


## 68. Round 54 — automation event-pipeline allocation and calendar merge staging (2026-09-30)

Research continued from Round 53 commit
`a1a1f2b7be100e07db7f4c81466e13339dfedfdb`.

Before this round, `dev` advanced to
`fbbca3d24591cd41db0f2016cb852661d86c9f6d`. The four intervening commits
were audited before reusing prior findings.

The concurrent delta is primarily automation-manager/desktop-driver work and
adds the new Settings page `modules/settings/AutomationConfig.qml`. It does
not touch the Round-53 Calendar/LocalMusic paths. The only other runtime QML
delta is a two-line `ConfigSpinBox.qml` change plus Settings page registry
wiring.

The handoff was searched before promotion for `AutomationConfig.qml`,
`automation/manager/store.py`, `EVENT_LIMIT`, Recent Activity ownership,
the event-merge surfaces below and the existing CalendarSync day-bucket work.
No ownership exists for the automation event-allocation paths. Calendar range
bucketing itself remains owned by §67.1 and is not counted again below.

### 68.1 Automation event history can remove redundant bounded-list copies across Python state and QML presentation — CONFIRMED / P2 active automation Settings

Paths:

- `automation/manager/store.py`;
- `modules/settings/AutomationConfig.qml`.

Automation operational history is bounded by:

`EVENT_LIMIT = 100`.

Three independent stages currently allocate more arrays/lists than their final
contract requires.

#### State normalization

`normalize_state()` currently executes:

`events[-EVENT_LIMIT:]`

and then a list comprehension filtering dictionaries.

That creates:

1. one up-to-100 element suffix slice;
2. one final normalized event list.

Strict-safe direction:

- compute the same suffix start index;
- scan the original JSON-loaded list from that index to the end;
- append only dictionaries to one fresh result list;
- publish that result exactly as today.

The source is JSON-decoded Python data. There are no custom element getters or
callbacks, and the final event order is unchanged.

Per normalization:

- temporary suffix list: **1 -> 0**;
- final normalized list remains one fresh list.

This matters on every Automation Settings status refresh because
`read_snapshot()` normalizes state before returning it.

#### Event append / cap

`event()` currently assigns:

`state["events"] = (state["events"] + [newEvent])[-EVENT_LIMIT:]`.

That creates a one-element list, a concatenated growing list and the final
bounded slice when the cap is reached.

A strict-safe fresh-list implementation can:

- allocate one new result list;
- copy exactly the last `EVENT_LIMIT - 1` existing references when already at
  cap, otherwise copy all existing references;
- append the new plain event dictionary;
- assign that one fresh list back to `state["events"]`.

This preserves:

- a fresh list assignment rather than changing list identity in place;
- existing event-reference identity/order;
- exact cap 100;
- oldest-first retention and newest-at-tail ordering;
- serialized JSON content.

No caller observes intermediate Python list identity; state is lock-local and
written only after the mutator completes.

For a capped event append, consumer-visible result construction changes from
multiple bounded-list allocations to **one fresh <=100 element result list**.

#### QML Recent Activity model

The new Settings page currently binds:

`events.filter(predicate).slice().reverse()`.

`filter()` already returns a fresh array, so the subsequent `slice()` is a
pure duplicate clone before in-place `reverse()`.

Strict-safe direction:

`events.filter(predicate).reverse()`.

Parity is exact:

- predicate still executes in forward source order;
- all 100 possible JSON event records are tested exactly as today;
- the filtered array is fresh, so reversing it cannot mutate the status
  snapshot;
- duplicate events, selected-profile filtering and newest-first display order
  are unchanged.

Per model reevaluation:

- matching-event arrays: **2 -> 1**.

The page's 4-second status timer is already correctly gated by `root.visible`;
do not describe this finding as hidden-page polling elimination.

### 68.2 Calendar/event presentation can build final merge arrays directly instead of map + staging + concat — CONFIRMED / P1-P2 when event surfaces recompute

Paths include:

- `modules/sidebarRight/events/EventsWidget.qml`;
- `modules/background/widgets/calendar/CalendarUpcomingWidget.qml`;
- `modules/sidebarRight/CompactSidebarRightContent.qml`;
- `modules/sidebarRight/calendar/CalendarDayDetail.qml`;
- `modules/waffle/notificationCenter/CalendarWidget.qml`.

These consumers repeatedly use the same structural pattern:

1. obtain a fresh local Events query result;
2. `map()` it to public clone objects;
3. obtain/build an external-event collection;
4. create a third merged array with `concat()`;
5. sort/group that merged array.

Waffle upcoming additionally creates, for each of three days:

- a mapped local array;
- a mapped external array;
- a concat result array;
- then appends the sorted result into the outer event list.

Source proof:

- local Events rows are either object literals created by `addEvent()` or
  plain JSON records loaded from disk;
- CalendarSync rows come from the ICS parser or JSON cache;
- neither source contains getter-bearing QML objects.

Strict-safe direction for each surface:

- keep the same service-query call order;
- create the final sortable/groupable array before cloning local rows;
- iterate the local query result in source order and push the exact same
  `Object.assign()` clone into that final array;
- only after all local clones are built, perform the external query/work at the
  same point it occurs today;
- append external references or the exact same external clones in current order;
- retain the existing sort/group code unchanged.

This ordering requirement is deliberate. For example, CalendarDayDetail and
Waffle selected-day paths currently finish every local clone before invoking
`CalendarSync.getEventsForDate()`; the lossless version must keep that phase
order rather than categorizing local rows early.

Concrete consumer-owned array reductions:

- EventsWidget / CalendarUpcomingWidget / Compact Upcoming:
  local mapped array + external staging array + concat result
  **3 -> 1 final merge array**;
- CalendarDayDetail selected day:
  local mapped array + concat result
  **2 -> 1 merge array** before time grouping;
- Waffle selected day:
  local mapped array + concat result
  **2 -> 1 sortable array**;
- Waffle three-day upcoming:
  per day, local mapped + external mapped + concat
  **3 -> 1 day array**, i.e. **9 -> 3** consumer-owned staging arrays across
  the three-day build.

Service-return arrays themselves are not counted as removed by this finding.

The clones themselves are still required wherever current UI row isolation
depends on them; this finding only removes arrays that hold the same references
temporarily.

### 68.3 §67.1 CalendarSync day-bucket batching applies to additional callers, but is not a new factor — ALREADY OWNED / coverage expansion

Two additional surfaces have the same independent-day-query shape as Compact
Upcoming:

- `EventsWidget.qml`: 30 calls to `CalendarSync.getEventsForDate()`;
- `CalendarUpcomingWidget.qml`: 30 calls to the same function;
- Waffle calendar upcoming additionally performs three per-day calls.

The parameterized batch-day helper described by §67.1 can serve these callers
while preserving each caller's exact day-major duplication semantics.

Do **not** count this as another optimization factor. It is broader consumer
coverage of the already-owned §67.1 primitive.

Each caller still needs its own horizon/post-filter parity audit before runtime
implementation.

### 68.4 Automation service-state batching is not promoted under strict timing semantics — CLOSED

Paths:

- `modules/settings/AutomationConfig.qml`;
- `automation/manager/control.py`.

While Automation Settings is visible, `status()` runs every four seconds and
`service_states()` executes three sequential:

`systemctl --user show <unit> ...`

subprocesses.

A single multi-unit `systemctl show` call would reduce child-process count,
but it changes the observation contract:

- current units are sampled sequentially at three distinct instants;
- per-unit start/timeout/OSError handling is independent;
- multi-unit command partial-output/exit semantics differ when one unit is
  missing or systemd state changes during the query.

Under this project's exact observable-state/timing rule, that is not a
CONFIRMED lossless optimization.

Status:

- **CLOSED as a blind 3 -> 1 subprocess rewrite**;
- may be revisited only with an explicitly accepted snapshot-semantics change
  or a transport that proves equivalent per-unit observation/failure behavior.

Also, the QML 4-second polling Timer is already `running: root.visible`;
there is no hidden-resident polling leak to claim.

### 68.5 WidgetManagerPanel combined count caching remains unpromoted — NEEDS PARITY

Path:

- `modules/background/widgets/WidgetManagerPanel.qml`.

The panel independently derives active/builtin-visible/custom-visible counts,
so some DesktopWidgetLayout/Config lookups repeat across bindings.

Combining them into one cached aggregate appears cheaper, but can change:

- which readonly properties emit changed signals;
- binding dependency capture on Config/DesktopWidgetLayout sources;
- reevaluation timing for consumers that read only one count.

No persistent/shared aggregate is promoted without signal/dependency parity.
Invocation-local helper cleanup inside one binding remains possible, but no
material standalone strict win was proven in this round.

### 68.6 Round-54 conclusion

New strict-lossless groups:

1. automation bounded event-history allocation reduction across state
   normalization, event append and Recent Activity presentation (§68.1,
   **CONFIRMED / P2**);
2. direct final-array construction for calendar/event merge consumers (§68.2,
   **CONFIRMED / P1-P2 when active**).

Not counted new:

3. §67.1 batch-day CalendarSync helper applies to more event surfaces
   (§68.3, **ALREADY OWNED / coverage expansion**).

Closed/held:

4. multi-unit systemctl batching changes sampling/failure semantics (§68.4);
5. WidgetManagerPanel cross-binding aggregate caching lacks signal/dependency
   parity (§68.5).

No numeric reduction above is an end-to-end Hadalis speedup; all numbers are
local source-derived allocation/process-shape counts.

No runtime/source implementation is authorized by this handoff.


## 69. Round 55 — YtMusic large-queue membership and lyrics JSON collection (2026-09-30)

Research continued from Round-54 docs commit
`d353745ce115f948b6bdbcfba4d1ee4269bb2a17`.

Immediately before this write, `dev` advanced one commit to
`094559d3fa0271ee04e1aca3db0237a45c862b31`. The direct compare was audited:
the delta only changes `automation/chat_bridge/desktop_driver.mjs` and
`scripts/test-hadalis-desktop-marker-scan.mjs`. It does not touch YtMusic,
LyricsService or this handoff.

The handoff was searched before promotion for `YtMusicView.qml`,
`addToPlaylist`, Save Queue / playlist creation, `LyricsService.qml`,
`payload.lines` and synced-lyrics collection. Existing YtMusic findings in
§51 cover changed-event classification, browser ordering and bounded
recent/liked collections; they do not own the queue-to-playlist path below.

### 69.1 Saving a YtMusic queue as a playlist can replace growing duplicate scans with one invocation-local membership Set while preserving every publication — CONFIRMED / P2 large-queue user action

Paths:

- `modules/sidebarLeft/YtMusicView.qml`;
- `services/YtMusic.qml`.

The Save Queue action currently:

1. calls `YtMusic.createPlaylist(name)`, which publishes/persists the new
   empty playlist;
2. takes the new playlist index;
3. walks `YtMusic.queue` in order;
4. calls `addToPlaylist(newIdx, queue[i])` for every queue item.

Each `addToPlaylist()` call currently:

- validates index and truthy `item.videoId`;
- shallow-copies the complete `root.playlists` array;
- linearly searches the growing target `items` array with
  `.find(i => i.videoId === item.videoId)`;
- for a unique ID, shallow-copies the growing item prefix, appends the same
  normalized item record, publishes `root.playlists`, then calls
  `_persistPlaylists()`.

For N valid distinct queue tracks, duplicate-membership comparisons alone are
approximately:

`0 + 1 + ... + (N - 1) = N(N - 1) / 2`.

A strict-safe specialization for **this Save Queue operation** can keep one
invocation-local Set of IDs already accepted into the newly created empty
playlist.

Required sequence:

1. keep `createPlaylist()` unchanged, including its first
   `playlistsChanged` publication and Config write;
2. preserve the dynamic source-order loop over the live `root.queue`;
3. keep the same truthy-`videoId` rejection;
4. test the accepted ID in the local Set;
5. for a duplicate, skip it exactly as the existing `.find()` branch does;
6. for a unique item, perform the **same** root-playlists shallow copy, the
   same target-items prefix copy, the same item-record construction/property
   reads, the same `root.playlists = p` assignment and the same
   `_persistPlaylists()` call before moving to the next queue item;
7. only then add the accepted ID to the local Set.

Repository parity evidence:

- persisted queue/playlist state is Config/JSON data;
- yt-dlp and InnerTube tracks are JSON-decoded/plain object records;
- InnerTube's stream collector stores `JSON.parse()` objects directly;
- repository search finds no assignment to `YtMusic.playlists` outside the
  service;
- the current `onPlaylistsChanged` consumer in YtMusicView only rebuilds its
  ListModel and does not mutate the service playlist;
- YtMusic itself has no Config-change handler that reloads playlists between
  these synchronous iterations.

Membership semantics also remain exact. Current comparison is strict equality;
Set uses SameValueZero. For accepted `videoId` values the only primitive
difference, `NaN`, cannot pass the existing truthy check, while object values
retain identity comparison and +/-0 remain equal under both rules.

Do **not** use the cached ID in place of the existing item-property reads when
constructing the published playlist record if exact malformed-object read
behavior is desired; the Set is only a membership accelerator.

For N distinct valid tracks:

- duplicate-membership comparisons:
  **N(N - 1) / 2 -> N Set lookups**;
- every current unique-item prefix copy remains;
- every `playlistsChanged` publication remains;
- every Config persistence call remains.

For duplicate queue entries, the specialized path can additionally avoid the
currently useless shallow `root.playlists` copy that is created before
`.find()` discovers the duplicate.

This finding deliberately does **not** claim that the complete Save Queue action
becomes linear: the required per-track prefix copies/publications/persistence
remain under strict parity.

### 69.2 Batch-publishing an entire saved YtMusic queue is outside the current strict-lossless contract — CLOSED

Same paths as §69.1.

It is tempting to build the full new playlist once, assign `root.playlists`
once and persist once. That would remove far more work.

It would also change observable behavior:

- current `playlistsChanged` fires after creation and after each accepted
  unique track;
- the library ListModel can observe every growing prefix;
- `Config.setNestedValue("sidebar.ytmusic.playlists", ...)` is invoked after
  each prefix;
- prior published item arrays are fresh prefix snapshots.

Therefore a one-publication/one-write bulk conversion is **CLOSED under the
current strict contract**. §69.1 is intentionally narrower: optimize only
duplicate membership while retaining the exact publication/write sequence.

### 69.3 LyricsService can fuse JSON-line filter + map into one ordered collection before the same sort — CONFIRMED / P2 lyrics completion

Path:

- `services/LyricsService.qml`.

After the helper response is parsed with `JSON.parse(raw)` and protocol/request
IDs are validated, the successful path currently executes:

`(payload.lines ?? []).filter(validTime).map(toLine).sort(byTime)`.

For a normal array of L helper records this creates:

1. one filtered-reference array;
2. one mapped `{time,text}` array;
3. two full ordered traversals before the existing sort.

Valid records also read `line.t` twice: once in the filter and once in the
map.

Strict-safe direction for the normal protocol array:

- keep the exact payload/request/status validation before this point;
- allocate one result array;
- traverse source order once;
- read `line.t`;
- if `typeof t !== "number"`, skip exactly as today;
- otherwise append
  `{ time: t, text: line.text ?? "" }`;
- run the **same** `sort((a,b) => a.time - b.time)` on the resulting array;
- keep empty-result failure and deferred success publication unchanged.

Source proof:

- the payload is produced by `JSON.parse(raw)`;
- line records therefore have no JS getters/callbacks or QML reactive property
  reads;
- preserving source traversal and the same final Array.sort preserves duplicate
  timestamps and comparator tie behavior.

Malformed-container parity must not be accidentally broadened. Current code
will throw when a truthy non-array `payload.lines` does not provide the
expected Array `filter()` method. A strict implementation should retain the
current chain as a compatibility/error path for non-arrays, and use the fused
loop only when `Array.isArray(payload.lines ?? [])` is true. Nullish
`payload.lines` continues to behave as an empty array.

For a valid L-line array with V accepted records:

- filtered intermediate arrays: **1 -> 0**;
- pre-sort traversals: **2 -> 1**;
- `line.t` reads for valid rows: **2V -> V**;
- the mapped result array and final sort remain exactly one each.

### 69.4 Nearby reactive partition hits are not promoted

Two apparent static wins were checked and intentionally left out of the strict
set:

- `modules/dashboard/DashTodo.qml` exposes `indexedTasks`,
  `unfinishedTasks` and `doneTasks` as separate readonly properties. A
  fused internal partition would require removing/changing the public
  `indexedTasks` publication or introducing shared aggregate signal
  dependencies. That is not equivalent to §63.3's private TodoWidget
  derivation.
- `modules/settings/NiriConfig.qml` independently publishes actionable and
  informational custom-config arrays. One shared partition could reduce a
  second source scan, but it changes readonly-property dependency/change
  topology. No strict promotion without signal parity.

### 69.5 Round-55 conclusion

New strict-lossless groups:

1. Save Queue invocation-local duplicate membership while preserving every
   YtMusic playlist publication/write (§69.1, **CONFIRMED / P2**);
2. one-pass valid-line collection in LyricsService before the unchanged sort
   (§69.3, **CONFIRMED / P2**).

Explicitly closed/held:

3. one-shot bulk YtMusic playlist publication/persistence changes observable
   intermediate state (§69.2);
4. DashTodo/NiriConfig shared reactive partitions lack property/signal parity
   (§69.4).

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived comparison/allocation counts.

No runtime/source implementation is authorized by this handoff.


## 70. Round 56 — keyboard LED state fusion and Anime schedule collection (2026-09-30)

This round continued from Round-55 docs commit
`9a7ef4efd32d44ef2163e8c608165a096b235c6a`. Current `dev` was unchanged
immediately before this documentation write.

The handoff was searched for `KeyboardIndicators.qml`,
`_hasKnownState`, `_recomputeLockState`, `AnimeService.qml`,
schedule filtering, Booru/Awww ownership and the nearby service areas audited
below. Existing KeyboardIndicators handoff notes classify its lifecycle/fallback
polling, but do not own the per-event state-scan reduction below. No existing
AnimeService optimization item was found.

### 70.1 KeyboardIndicators can compute known-state and any-on state in one internal pass — CONFIRMED / P2 lock-state event path

Path:

- `services/KeyboardIndicators.qml`.

In the non-evdev LED-file fallback, every lock-file state update eventually
calls `_recomputeLockState(kind, allowPopup)`.

Current logic uses the same `paths` and plain state map twice:

1. when `paths.length > 0`,
   `_hasKnownState(paths, states)` scans with `.some()` until the first
   non-null/non-undefined state;
2. if at least one state is known, a second
   `paths.some(path => states[path] === true)` starts again from the first
   path and searches for an enabled LED.

The state containers are internal plain JS objects:

- `_setLockPaths()` rebuilds them as object literals;
- `_setLockState()` / `_clearLockState()` publish fresh
  `Object.assign(...)` objects;
- the path arrays are sorted string paths derived from the service's own LED
  discovery.

`_recomputeLockState()` is an imperative callback, not a QML binding.

Strict-safe direction:

- keep the public/private helper `_hasKnownState()` unchanged so no method
  surface disappears;
- inside `_recomputeLockState()`, replace only its two internal scans with one
  ordered loop;
- maintain two scalars:
  - whether any non-null/non-undefined value has been observed;
  - whether any value is exactly `true`;
- stop immediately on the first exact `true`, because that simultaneously
  proves that a known state exists;
- if the complete nonempty path list contains no known value, retain the same
  early return;
- keep every downstream CapsLock/NumLock reliability assignment, popup
  decision and `allowPopup` ordering unchanged.

Important edge parity:

- empty path list still produces `nextValue=false` and reaches the current
  empty-path NumLock reset branch;
- all-null/undefined state maps still return without publishing a lock change;
- known-false plus later unknown values still scans to the end and publishes
  false exactly as today;
- duplicate paths, if present, are read in the same order;
- no QML dependency capture changes because this is imperative state handling.

For P paths, state-map reads change from a worst-shaped **up to 2P -> at most
P** per recomputation. Cases that already return after one all-unknown pass
remain P -> P.

No discovery cadence, FileView ownership or evdev path is changed.

### 70.2 AnimeService schedule filtering can normalize matching GraphQL rows directly into the final array — CONFIRMED / P2 network completion

Path:

- `services/deferred/AnimeService.qml`,
  schedule GraphQL completion.

After a successful GraphQL response, the schedule path currently executes:

1. `(data.Page?.media ?? []).filter(...)`;
2. for every row with `nextAiringEpisode`, constructs an airing Date and maps
   weekday number through a seven-string literal;
3. retains rows whose airing weekday equals `targetDay`;
4. `filtered.map(anime => root._normalizeAnime(anime))`;
5. publishes that normalized array into both the target-day cache and
   `root.schedule`.

The GraphQL response arrives through JSON parsing, so media/anime records are
plain JSON data rather than QML objects/getter-bearing values.

Strict-safe normal-array direction:

- allocate only the final normalized array;
- traverse media in source order once;
- keep the same `!anime.nextAiringEpisode` short-circuit;
- construct the same Date only for rows that pass that guard;
- derive the same lowercase weekday string and compare to the same
  `targetDay`;
- call `_normalizeAnime()` only for rows whose predicate passes, exactly as
  today;
- append normalized rows in source order;
- publish the same final array reference to
  `_scheduleCache[targetDay]` and then `root.schedule`;
- retain `_updateCache(cacheKey)` in the same position.

The seven-element weekday lookup can also be represented without constructing
a new literal array for each predicate call (for example an exact numeric
switch), while retaining the same seven strings and Date `getDay()`
semantics.

Malformed-container parity must be preserved. Current code expects the
nullish-defaulted media value to expose Array `filter()`; a truthy non-array
helper response can therefore throw. A strict implementation should keep the
current filter/map compatibility/error path for non-arrays and use the fused
collector only when the media value is an actual array.

For L media rows and V matching rows:

- filtered intermediate arrays: **1 -> 0**;
- media/reference traversals before publication: **L + V -> L**;
- `_normalizeAnime()` calls remain exactly V;
- result membership/order and cache/publication sequence are unchanged.

### 70.3 Booru/Awww service sweep did not produce another material strict item

Paths audited:

- `services/Booru.qml`;
- `services/Wallhaven.qml`;
- `services/AwwwBackend.qml`;
- `services/deferred/InnerTube.qml`;
- `services/DailyNoteTodoBackend.qml`;
- `services/ThinkFanService.qml`.

Items intentionally **not promoted**:

- Booru waifu.im request building has a small `filter().forEach()` tag staging
  array, but user tag lists are short and removing it is a P3 request-builder
  micro-optimization.
- waifu.im image mapping also creates a tag-name array before `join(" ")`;
  replacing Array.join with incremental string concatenation is not an
  unconditional performance win.
- Booru/Wallhaven delayed QObject destruction filters references into a fresh
  snapshot before `Qt.callLater`. Reusing the originally published array
  would require proving that no holder mutates that array before deferred
  destruction; the allocation alone is not worth weakening snapshot semantics.
- Awww's output/signature arrays directly encode deterministic multi-output
  state and are not redundant staging.
- InnerTube's JSONL `StreamCollector` intentionally publishes the accumulated
  buffer reference and then replaces its internal buffer; cloning/fusing that
  lifecycle would change reference/publication semantics.
- DailyNoteTodoBackend's task lookup occurs once per toggle/delete before the
  helper's document-hash conflict check; there is no duplicated reconciliation
  scan to eliminate.
- ThinkFan's dominant work remains the previously documented lifecycle/process
  policy rather than local collection churn.

### 70.4 Round-56 conclusion

New strict-lossless groups:

1. one-pass KeyboardIndicators known/on state classification (§70.1,
   **CONFIRMED / P2 event path**);
2. direct Anime schedule predicate + normalization collection (§70.2,
   **CONFIRMED / P2 network completion**).

No lower-value Booru/Awww/InnerTube/DailyNote micro-hit is counted (§70.3).

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived reads/traversals/allocations.

No runtime/source implementation is authorized by this handoff.


## 71. Round 57 — Equalizer band-commit allocation and TLP token parsing (2026-09-30)

This round continued from Round-56 docs commit
`066c4cd79c121314c620bb2a626cf7d3ade61057`. Current `dev` was unchanged
immediately before this documentation write.

The handoff was searched before promotion for
`services/deferred/EqualizerService.qml`, `_normalizeGains`,
`setDspBandGain`, `TlpRuntimeCapabilities.qml`, `_tokens` and the
surrounding lifecycle findings. Existing Equalizer/CAVA work covers service
demand/render ownership; it does not own the local band-commit allocation below.
Existing TLP work covers 30-minute safety-process freshness, not token parsing.

### 71.1 Equalizer single-band commit can normalize the already-required private clone in place — CONFIRMED / P2 interactive commit path

Path:

- `services/deferred/EqualizerService.qml`.

`setDspBandGain(index, gain)` currently:

1. converts/validates index and gain;
2. requires `dspControlAvailable`;
3. clones the ten-element `_dspGains` array with `.slice()`;
4. writes the requested clamped band into that fresh clone;
5. passes the clone to `_applyState(next, "Custom")`;
6. `_applyState()` calls `_normalizeGains(next)`, which allocates a second
   ten-element array while repeating Number/isFinite/clamp over every element;
7. that second array becomes `_pendingGains` and feeds the process command.

The first clone is required for isolation: directly mutating `_dspGains` before
a successful backend apply would change live/public state.

The second clone is not required if normalization mutates **only that fresh,
unpublished first clone**.

Strict-safe design:

- keep the existing public `_applyState(gains, presetName)` contract unchanged,
  including argument behavior for extension callers;
- add a private/common dispatcher whose normalizer is selected by the caller,
  or a distinct private path used only by `setDspBandGain()`;
- run all current backend guards in the exact same order and at the exact same
  phase as `_applyState()`;
- for the single-band path, normalize the local clone in place:
  - preserve the exact length check;
  - read elements in the same index order;
  - perform the same `Number()`;
  - fail on the same first non-finite value;
  - write the same min/max clamp result back to that local clone;
- only after successful normalization run the existing preset-label validation,
  `_pendingGains` assignment, error clear, command construction and Process
  start in the same order;
- generic `_applyState()` callers, including shared preset-curve literals,
  must continue using the existing copy-producing normalizer and must never be
  mutated in place.

Why failure semantics remain exact:

- partial in-place normalization on an invalid band affects only the fresh local
  `next` clone, which has not been published or stored anywhere;
- the same `invalid-dsp-state` branch occurs after the same backend guards and
  before label publication/process work;
- `setDspBandGain()` already validates the newly requested scalar, but the
  full ten-element validation must still run so malformed externally modified
  state fails exactly as today.

Do **not** remove the second normalization on successful `applyProc` exit:

`_normalizeGains(root._pendingGains)`

creates the fresh array assigned to `_dspGains` and also protects final
publication from any mutation of pending state. That publication boundary is
not part of this finding.

Per accepted/rejected single-band commit reaching `_applyState`:

- ten-element local arrays before Process start: **2 -> 1**;
- Number/isFinite/clamp count and order remain unchanged;
- process command, signal/publication sequence and backend calls remain
  unchanged.

### 71.2 TlpRuntimeCapabilities token parsing can avoid filter-after-whitespace-split — CONFIRMED / P3 capability refresh

Path:

- `services/TlpRuntimeCapabilities.qml`, `_tokens()`.

Current helper:

`String(...).replace(/[\[\]]/g, "").trim().split(/\s+/).filter(nonempty)`.

After `.trim()`:

- a nonempty string split by `/\s+/` cannot contain empty tokens;
- the only special case is an empty trimmed string, whose split result is
  `[""]` and whose filter result is `[]`.

Strict-safe direction:

1. perform the same String conversion;
2. perform the same bracket removal;
3. perform the same trim;
4. if the cleaned string is empty, return one fresh empty array;
5. otherwise return `cleaned.split(/\s+/)` directly.

Parity:

- token text/order is identical;
- bracket removal and whitespace semantics are unchanged;
- empty/whitespace/bracket-only input still returns a fresh `[]`;
- String-conversion exceptions/side effects occur at the same point;
- no token callback had side effects beyond the guaranteed
  `token.length > 0` predicate.

The helper is used by sysfs capability reads such as governors and mem-sleep
modes. It is a cold/safety-refresh path, so priority remains P3.

For a nonempty input with T tokens:

- split array + filtered array: **2 -> 1**;
- token traversal after split: **T -> 0**.

### 71.3 Nearby service audit did not justify broader changes

Also audited during this round:

- `services/deferred/CavaService.qml`;
- `services/ai/GeminiApiStrategy.qml`;
- `services/VoiceSearch.qml`;
- `services/CustomWidgets.qml`;
- `services/DesktopWidgetLayout.qml`;
- `services/Hyprsunset.qml`;
- `services/deferred/GowallService.qml`;
- `services/IconThemeService.qml`;
- `services/MaterialThemeLoader.qml`.

No new factor is counted from them:

- Cava frame publication is already one-pass for peak/sum/change and the shared
  process/lifecycle architecture is already owned.
- Gemini request/annotation maps are final API/output data rather than staging
  arrays.
- service/custom-widget boundaries remain extension-visible, so apparently dead
  public derivations cannot be removed based only on core-repo consumers.
- DesktopWidgetLayout broad invalidation belongs to the existing scoped Config
  invalidation research rather than a new local optimization.
- Hyprsunset's redundant shell wrapper is already owned by §33.11.
- Gowall incremental theme publication is intentionally closed under current
  signal timing.
- IconTheme and MaterialThemeLoader local work is already owned by §51.16 and
  §62.3 respectively.

### 71.4 Round-57 conclusion

New strict-lossless groups:

1. normalize Equalizer's already-required single-band private clone in place
   while keeping the generic/public apply contract unchanged (§71.1,
   **CONFIRMED / P2 interactive**);
2. direct nonempty TLP token split with explicit empty-string handling (§71.2,
   **CONFIRMED / P3**).

No broader service/publication/lifecycle change is counted (§71.3).

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived allocation/traversal counts.

No runtime/source implementation is authorized by this handoff.


## 72. Round 58 — Abyss vacancy role selection and blocker-scan fusion (2026-09-30)

This round continued from Round-57 documentation commit
`22109ec47cd6add6bd1b7019c6fca29f84b24c66`.

Before this write, current `dev` is
`40fdace6cb730504293783ecc6f7743a9052c260`
(`fix(automation): wait for busy chats and start in target project`).

Three commits landed after Round 57 and were audited before relying on prior
findings:

- `d078b855cc11def937386ecec5c13cb264e6ff8a` —
  `fix(abyss): expand connectivity dialogs into vacancy`;
- `4ad6191c6bd1e4b26424cf2e408c7c06386afb5b` —
  `fix(connectivity): reflow content into borrowed space`;
- `40fdace6cb730504293783ecc6f7743a9052c260` —
  `fix(automation): wait for busy chats and start in target project`.

The first two modify the vacancy/connectivity runtime audited below, so no
pre-change vacancy conclusion was reused. The current
`AbyssVacancyBorrowing.js`, `AbyssSurfaceController.qml`,
`AbyssParticipant.qml`, `AbyssBodyHost.qml` and
`AbyssBodyPlacement.js` were re-read from exact current `dev`.
The automation commit does not touch these runtime paths.

The handoff was searched before promotion for
`AbyssVacancyBorrowing`, `_vacancyBestCandidate`,
`_vacancyBlockerExtent`, `_vacancyCollides`, semantic-vacancy role
selection, blocker/collision scans, `parallelEnvelope` and
`connectivityDialog`. Historical vacancy commits are mentioned in earlier
reconciliation notes, but no existing optimization item owns either reduction
below.

### 72.1 Vacancy pair role winners can be selected in one metadata pass instead of six filter/sort pipelines — CONFIRMED / P1-P2 reactive layout path

Paths:

- `modules/abyss/looks/AbyssVacancyBorrowing.js`;
- `modules/abyss/AbyssSurfaceController.qml`;
- `modules/abyss/AbyssBodyHost.qml`;
- `modules/abyss/looks/AbyssBodyPlacement.js`.

Current `resolve()` has three fixed semantic pairs. For every evaluation it
calls `_vacancyMemberForRole()` twice per pair:

1. `featureSidebar`;
2. `quickNotes`;
3. `systemSidebar`;
4. `notificationCenter`;
5. `systemSidebar` again;
6. `connectivityDialog`.

Each call currently:

- runs `metadata.filter(...)` across the complete metadata array;
- creates one filtered array;
- sorts every eligible member by descending request `order`, then ascending
  string `id` with the existing `localeCompare`;
- returns only the first sorted member.

The live inputs are already snapshot data before the resolver runs:

- `vacancyParticipants` is rebuilt from `Object.keys(participants).map(...)`
  into plain `{id, role}` JS objects;
- each `placementRequest` is a fresh JS object literal produced by
  `AbyssBodyHost`;
- `AbyssBodyPlacement.arrange()` produces a plain result object containing
  plain placement/content object literals.

Therefore the six resolver scans do not capture independent QML property
dependencies, invoke user callbacks, or observe getter-backed mutable records.
They repeatedly read the same synchronous snapshots.

Strict-safe direction:

- keep construction of `requestById` exactly where it is today;
- traverse `metadata` once in its existing order;
- for each item, evaluate the exact current eligibility:
  - role string;
  - matching request exists and `req.open === true`;
  - placement exists;
  - `p.visible !== false`;
  - `p.content` is present;
- maintain the best eligible member for each of the five role strings used by
  `_vacancyPairs`;
- compare candidates with the exact current ordering:
  - higher normalized request order wins;
  - on equal order, smaller `String(id).localeCompare(...)` wins;
- on a comparator-zero tie, retain the first encountered item. This matches
  the current stable-sort first element and also preserves defensive duplicate
  metadata behavior;
- construct the same member shape
  `{id, role, meta, request, placement}`;
- run the existing pair/candidate/plan logic unchanged.

All six current member lookups are unconditional inside the pair loop, so this
does not skip a lookup that was previously protected by a short-circuit.

For M metadata entries, with K_r eligible entries for each role:

- full metadata traversals: **6M -> M**;
- filtered temporary arrays: **6 -> 0**;
- role-ranking work: up to
  **sum sort(K_r) -> one best-member comparison per eligible row**;
- the duplicate `systemSidebar` lookup becomes one winner computation.

No pair priority, request-order tie, role ownership, placement identity or
published `bodyPlacements` array/object behavior changes.

### 72.2 Blocker limiting and final collision validation can be proven in one ordered placement scan — CONFIRMED / P1-P2 reactive layout path

Path:

- `modules/abyss/looks/AbyssVacancyBorrowing.js`,
  `_vacancyBestCandidate()`.

For every candidate direction that survives peer-gap and safe-bound checks,
current code can traverse all `placements` twice:

1. first scan:
   - skip owner and, for parallel-envelope growth, the semantic peer;
   - normalize each visible `p.content` with `_vacancyRect()`;
   - reduce `max` through `_vacancyBlockerExtent(..., gap)`;
   - stop if `max < .5`;
2. create the grown rectangle;
3. second scan:
   - apply the same owner/parallel-peer exclusions;
   - normalize every visible blocker rectangle again;
   - reject if `_vacancyCollides(grown, blocker, gap-.01)`.

The second scan is redundant once one additional boolean is derived during the
first scan.

Strict-safe one-scan direction:

- preserve the exact `for ... in placements` enumeration and exclusions;
- normalize each visited blocker rectangle once;
- apply the current `_vacancyBlockerExtent(..., gap)` and the existing
  `max < .5` break at the same point;
- only when that break did not fire, record whether the **base** content already
  collides with this blocker under the second pass's exact
  `gap-.01`;
- after the scan:
  - if `max < .5`, reject exactly as today;
  - if any base collision was recorded, reject;
  - otherwise grow the rectangle and omit the second placement scan.

Why the omitted grown-rectangle scan is equivalent for every normalized
rectangle:

1. Growth changes only the chosen axis. Orthogonal projection never changes.
   A blocker that does not overlap the base projection under `gap-.01`
   cannot become an orthogonal collision after growth.
2. If a blocker lies ahead in the growth direction,
   `_vacancyBlockerExtent(..., gap)` caps `max` so the grown edge remains at
   least the full `gap` away. The later collision predicate uses the slightly
   smaller `gap-.01`, so that blocker cannot collide.
3. If a blocker is not ahead and the base rectangle does not collide, it must
   be separated on the opposite side of the growth axis. Growth leaves that
   opposite edge unchanged, so it cannot create a new collision.
4. If the base rectangle already collides, every grown rectangle contains that
   base rectangle. The current second scan therefore necessarily rejects it;
   the recorded base-collision boolean rejects the same candidate.
5. Width/height and non-finite geometry already pass through
   `_vacancyRect()` normalization before either test, so the proof applies to
   the same normalized malformed numeric state as current code.

Runtime inputs are the plain placement snapshots returned by
`AbyssBodyPlacement.arrange()`; eliminating the duplicate second read therefore
does not change QML binding dependency capture or observable getter/callback
ordering.

For a direction that currently reaches the second phase with P placement
entries:

- placement enumerations: **up to 2P -> P**;
- blocker `_vacancyRect()` normalizations: **up to 2P -> P**;
- candidate direction, `max`, grown geometry, gain, priority and tie ordering
  remain unchanged.

Directions that already terminate because `max < .5` retain the existing
early break and do not gain extra post-break reads.

### 72.3 Nearby Abyss aggregation changes are not promoted again

Two adjacent ideas were checked and intentionally not counted:

- `placementRequests`, `records` and `inputBounds` one-pass aggregate
  construction is already owned by §58.1. Round 58 does not duplicate it.
- Sharing one `Object.keys(participants)` result or one aggregate object across
  independent `placementRequests` / `vacancyParticipants` readonly bindings
  would change binding dependency/publication topology and fresh-array behavior.
  It is not required for §§72.1-72.2 and is not promoted under strict parity.
- The newly-added Wi-Fi/Bluetooth `adaptiveDelegateHeight` bindings are O(1)
  arithmetic over list geometry/count and do not justify a separate
  optimization factor.

### 72.4 Round-58 conclusion

New strict-lossless groups:

1. select all semantic vacancy role winners in one metadata pass instead of six
   full filter/sort pipelines (§72.1, **CONFIRMED / P1-P2 reactive layout**);
2. fuse blocker limiting and collision validation into one ordered placement
   scan per eligible vacancy direction (§72.2,
   **CONFIRMED / P1-P2 reactive layout**).

No runtime/source implementation is authorized by this handoff.

No numeric reduction above is an end-to-end Hadalis speedup; all values are
local source-derived traversal/allocation reductions.

## 73. Round 59 — Dashboard fallback geometry and responsive collision-scan research (2026-09-30)

### Snapshot, concurrent delta, ownership search

- Authoritative dev at audit and immediately before this documentation write: 480a3b3d1d0881944b31d0b3fd16265afc8f7c54.
- Latest preceding optimization round: Round 58 at 5ad09b2dde61df5c3adefcda46cf12c9b2b090f0.
- Exactly one intervening commit, 480a3b3 (automation: preserve pending response across Desktop view changes), touched automation/chat_bridge/desktop_cli.mjs, automation/chat_bridge/desktop_driver.mjs, automation/manager/daemon.py and two automation tests; none changes Dashboard geometry or the handoff. AGENTS.md was re-read.
- Current exact-dev modules/dashboard/DashboardCanvas.qml was read. Full handoff searches for DashboardCanvas, _fallbackPlacement, _candidateScore, _bestSideCandidate, _resolveNeighbour, _layoutHasOverlap, responsiveWorkspace and CavaSpectrum found §65.1 as the nearby Dashboard smart-alignment owner, but no previous owner for the two distinct collision-scan directions below. Existing notification aggregation §37.1, Overview delegate lookup §41.18 and WindowPreview bookkeeping §42.4 were excluded from promotion.

### 73.1 Avoid a second obstacle traversal after an exhaustive collision-free fallback candidate check — CONFIRMED / P1-P2 complex resize/drop fallback

Path: modules/dashboard/DashboardCanvas.qml, _fallbackPlacement() (around lines 1221–1278), _candidateScore() (around 1173–1191).

For every viable candidate in the finite obstacle-edge search, the caller first traverses every obstacle in order, using _rectsOverlap(candidate, obstacle, gap). If any result is true it marks blocked, breaks, and skips the score. Only after the *entire* traversal proves that no obstacle overlaps does it call _candidateScore(candidate, base, obstacles), which repeats the same complete obstacle traversal merely to increment an overlap count. Thus that count is exactly zero for every candidate arriving at this call.

Strict-safe direction: preserve all candidate generation, xs/ys lists including duplicates, width/height nesting, the blocking pass and its early break. Add an optional internal knownNoOverlap=false argument to _candidateScore(). Preserve the existing null-candidate guard. Only when the flag is true, initialize overlaps=0 but skip its obstacle-count loop; retain the **unchanged** score expression and arithmetic order, including its leading overlaps * 1000000000. Pass true only from _fallbackPlacement after the complete first scan returned !blocked. Keep the ordinary three-argument calls from _bestSideCandidate and all other callers intact.

Parity evidence and full strict-contract checks:

- The obstacle array is invocation-local and populated from ordinary plain rectangle snapshots by _resolveLayout(); _fitRectToCanvas() creates the candidate as a plain object. _rectsOverlap() is a pure sequence of numerical comparisons, with no writes, callbacks, allocations or events that could alter either scan's input.
- The local gap read in _fallbackPlacement and the root.collisionGap reads inside the scorer are the same stable readonly arithmetic derivation of gridSize within this synchronous imperative gesture call. Removing redundant scorer property reads does not remove a QML-binding dependency: this solver is called through updateInteraction()/finishInteraction(), not an evaluated readonly binding.
- The first scan throws at the same point on malformed obstacles; no failed candidate reaches the scorer. If non-finite geometry makes every overlap comparison false, both passes still count zero. The existing score expression preserves JS NaN/Infinity behavior and floating-point operation order.
- First-strict-less-than score selection, first-wins ties, duplicate candidate coordinates, array order, short-circuit behavior, call and error order for all blocked candidates, object identities, signal/callback order, focus, rendered geometry, publication and fallback behavior are preserved. No change to QML sequence conversion, Set/SameValueZero versus strict equality, or fresh-array publication is involved. The public default three-argument scorer remains unchanged.
- For C viable candidates and O obstacles, redundant scorer overlap tests are **C × O -> 0**. The required preceding blocking traversal is retained, including its early exit. This is only a local worst-case operation reduction; the fallback is used when the regular side-placement solver cannot resolve the neighbour. No whole-Hadalis speedup percentage is inferred.

### 73.2 Responsive Abyss bisection could check active-versus-other overlaps only — HIGH CONFIDENCE / requires malformed-state oracle; not a confirmed count

Path: modules/dashboard/DashboardCanvas.qml, _resolveFeasibleLayout() (around lines 1426–1474), _layoutHasOverlap() (around lines 1393–1415).

The responsiveWorkspace branch applies to Abyss. Its initial fixed map is Object.assign({}, baselineRects), with only fixed[activeId] replaced. All 12 binary-search probes do exactly the same: only the active rectangle changes. For ordinary finite geometry, every pair not involving activeId is unchanged relative to baseline, so the existing legacy-overlap exemption suppresses it. Current generic _layoutHasOverlap nevertheless attempts up to V(V-1)/2 unordered visible-ID pairs on each of these 13 evaluations.

Candidate: specialize only this responsive caller, preserving the exact visible-ID membership, active baseline-equivalence exemption and active/other collision predicate while testing at most V-1 relevant pairs. Retain the generic all-pair routine for the nonresponsive solver and as a fallback whenever the fast-path preconditions cannot be proven.

Do **not** promote this yet: with non-finite fields (NaN or Infinity), even _sameRect(r,r) can be false, so an apparently unchanged other-other pair may still affect the generic result; the visible-ID list can also change mid-gesture, leaving an ID without a captured baseline. A naive active-only check is NOT strict-lossless under these states. Required deterministic oracle: original generic routine versus a guarded specialized routine across finite, missing, non-finite, duplicate-key, preexisting legacy overlaps, active-hidden and mid-gesture visibility-change fixtures. Check QML property-read dependencies, side effects, collision pair order and publication as well. Until that oracle and guarded proof, this remains HIGH CONFIDENCE, NOT CONFIRMED and not implementation-authorized.

### 73.3 Nearby canvas sweep — no separate factor

modules/common/widgets/CavaSpectrum.qml already retains per-instance selected, smooth, primary, secondary and baseline frame scratch arrays. Its frequency smoother already uses a rolling sum, so a generic smoothing-reallocation claim is stale. Hoisting a few fillRatio property reads alone lacks material significance. Dashboard pointer-hot smart-alignment anchor work is already owned by §65.1 and is not re-counted.

### 73.4 Conclusion / next checkpoint

New confirmed optimization groups this round: **one** (§73.1). One additional distinct high-confidence lead (§73.2) remains outside confirmed counts. No product/runtime files were edited; no local oracle or runtime patch was executed. Next audit should re-fetch dev, reconcile concurrent changes, then inspect another interaction-hot or per-frame area such as modules/dashboard/DashboardLayout.js projection, without duplicating §65.1 or §73.1. All quantities here count only local operations, not shell performance.

## 74. Round 60 — Dashboard projection's repeated X-axis collision work (2026-09-30)

### Snapshot and ownership audit

- Audited the current dev HEAD d25caf4f31b093328075fb64f11a73ad56261867 immediately after the Round-59 research commit. No intervening commit was present.
- Re-read modules/dashboard/DashboardLayout.js at this exact ref. Full handoff search for DashboardLayout.js, freeRect, X-axis prefilter, DashboardCanvas, _fallbackPlacement and other collision ownership found no prior owner for this separate projection-path calculation. Round 59 §73.1 owns DashboardCanvas fallback's redundant *second whole obstacle loop*, not the repeated X comparisons inside DashboardLayout.freeRect().
- This is research only. No runtime or packaging change is authorized.

### 74.1 Reuse an X-axis overlap subset across all Y candidates for each fixed X — CONFIRMED mathematical parity for guarded numeric, plain-snapshot path / P1-P2 reactive workspace projection

Path: modules/dashboard/DashboardLayout.js, freeRect() (lines 10–32) and its internal overlaps() predicate (lines 6–9), called from project() (lines 33–48).

Current freeRect() enumerates the same widths/heights, then xs and ys in nested source order. For every in-bounds candidate rectangle at a fixed x, the obstacles.some callback reevaluates two *identical* X-axis overlap comparisons against each obstacle even though neither condition depends on y:

1. x < other.x + other.width + gap - .001;
2. other.x < x + w + gap - .001.

Only after both hold does the original overlaps() check the two Y-axis comparisons. The current callback may short-circuit at the first complete X+Y collision.

Strict-safe scoped direction:

- Keep the original candidate-object creation, bounds guard, nested widths/heights/xs/ys iteration, cost expression, score comparison (strict less-than), tie winner, duplicate coordinates, chosen rect and output publication unchanged.
- For a fixed (w,h,x), lazily build an ordered invocation-local subset of obstacle **indices**, containing exactly those for which the above two existing numeric X predicates both hold. Build it only after the first Y candidate passes the exact existing bounds guard. Do not deduplicate; keep source obstacle order.
- For each such valid Y, check the original two Y-axis expressions over that subset, stopping at the first matching obstacle just as the old some() call stops. A full overlap exists iff both X predicates and both Y predicates hold; the subset proof is algebraic, and no floating-point reassociation of either individual comparison is required.
- Preserve freeRect()'s existing generic route for caller-visible inputs with possible coercion side effects: the fast branch must require primitive-number w, h and gap, plus plain, primitive-number fields in the *internally created* obstacle rectangles. Public/direct freeRect() use must retain its original default path. project() creates desired coordinates using Math.min/Math.max and the bounded() conversion, and every accepted obstacle is the ordinary {x,y,width,height} candidate literal; if any field is not a primitive number, use the original loops. Avoid getter-backed/callable/mutable external state in the hoisted comparisons.
- Non-finite primitive-number values still take the same literal comparisons (false in the same NaN branches); negative/positive zero comparisons also stay identical. Null or exotic malformed inputs that would throw/coerce through the old path must continue to use it, with the old error/short-circuit behavior. Do not move entry.visible, minimum-size, QML config or other reactive reads across project()'s current iteration.
- The x subset lives only inside one (w,h,x) invocation, never as a retained cache. Since it depends only on new plain local objects and the primitive numeric gap already read as a project binding argument, it changes no QML dependency capture, external callback, object/array publication, signal, focus, animation, ordering, or extension-facing API. No Set/SameValueZero substitution is introduced.

Local work: if O obstacles produce X x-values and Y y-values at a fixed size, up to **2 * X * Y * O** repeated X-axis comparisons are reduced to at most **2 * X * O** (often less because the subset is lazy and out-of-bounds candidates skip it). Y-axis work remains proportional to the actual x-matching subset and can still be cubic in a densely overlapping worst case; do **not** describe the *entire* freeRect search as generally O(O²). With O obstacles the enumerated lists each contain 3+2O entries before any bounds guard. This is only a local comparison reduction for reactive Dashboard layout projection, **not** a measured whole-shell performance percentage.

The guard is important to the CONFIRMED classification: an unguarded rewrite of arbitrary public freeRect inputs can alter getter/coercion counts or error order and is **OUT OF STRICT-LOSSLESS**. Before eventual implementation, add deterministic old-versus-new oracle fixtures for ordinary disjoint/colliding rectangles, ties, duplicate x/y positions, empty obstacles, NaN/Infinity/-0 and nonprimitive coercion fallback; no such implementation/test was performed in this research round.

### 74.2 Nearby non-factors / checkpoint

- Do not also promote project() entries.filter(...).forEach(...) as a casual fuse: reading every entry.visible before all placement work is its present evaluation sequence, and interleaving those reads with placement can change property-read order for external entry objects.
- bounded() repeating Number(value) is not automatically lossless for coercible objects with observable valueOf/getters; its scalar micro-saving is not an independent material item.
- Round 59's DashboardCanvas responsive active-only pair scan remains HIGH CONFIDENCE pending malformed-state oracle (§73.2); the projection's X-axis proof does not resolve it.

**New CONFIRMED group: one** (§74.1, explicitly guarded numeric/plain-snapshot path). No runtime/product files edited and no local job submitted. Next research should re-fetch current dev and diversify beyond Dashboard into a distinct render or user-interaction hot path.
