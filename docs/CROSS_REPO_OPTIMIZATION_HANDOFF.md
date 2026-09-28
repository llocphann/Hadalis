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
