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

iNiR prerelease has `modules/common/widgets/SettingsTaskLoader.qml`:

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

iNiR prerelease adds `modules/common/MediaArtworkCache.qml`, a small bounded cache (64 entries) that remembers the last resolved artwork URL per track so a later-created player can show the same cover immediately without resolving again.

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

iNiR has `modules/common/MediaArtworkCache.qml`:

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
