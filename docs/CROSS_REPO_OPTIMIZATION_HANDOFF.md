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
