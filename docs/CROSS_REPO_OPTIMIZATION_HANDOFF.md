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
