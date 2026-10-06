# Strict-lossless GPU / RAM / CPU optimization audit

Audit baseline: `dev` at `1155e37093781a27e64a9caa100a52ac1ab60d15`.

Scope: find remaining optimization opportunities that are either strict-lossless or can be held to a measured visual deviation below 1%. This is research only. It does not authorize runtime changes by itself.

Rules:

- Do not claim whole-Hadalis CPU/GPU/RAM/FPS percentages without before/after measurement.
- Preserve runtime behavior, read/dependency order, lifecycle, input/focus, output ownership and fallbacks.
- A visual-change candidate must have a deterministic or owner-session A/B oracle and stay below 1% normalized visual error before promotion.
- Prefer lifecycle/allocation/render-pass removal over changing animation timing or fidelity.
- `Gain GPU` / `Gain RAM` below are qualitative unless an exact structural metric is shown.
- Lexical occurrence counts are evidence of code shape, not proof of runtime cost.

## Audit table

| File | Issue | Risk | Gain GPU | Gain RAM | Visual risk |
|-|-|-|-|-|-|
| `modules/screenCorners/ScreenEdgeField.qml` + `ScreenEdgeField.frag` | **IMPLEMENTED / REFERENCE BASELINE.** Healthy Screen Edge path already removed MultiEffect, ShaderEffectSource capture and blur-pyramid intermediates. Adaptive four-tile rasterization covers only the proven non-transparent perimeter. | Low for current implementation; live compositor acceptance remains separate. | **High structural reduction already landed.** Documented raster footprint is <9.7% of output at 1920x1080 and <4.9% at 3840x2160 for the default geometry; this is not a whole-GPU speedup %. | Medium structural reduction from removal of capture/blur intermediates and fallback binding compaction. | Intended global normalized MAE <=1%; owner-session A/B still required for live visual acceptance. |
| `modules/altSwitcher/AltSwitcher.qml` | **CANDIDATE — GPU/render passes.** Current `dev` contains 3 `MultiEffect` occurrences, 1 `ShaderEffectSource`, 4 `layer.enabled` sites and 2 `layer.effect` sites. The skew path uses a blurred layer plus an offscreen masked image layer with MSAA. Research replacing the mask/capture path with analytic geometry or a cheaper single-pass mask, while keeping the exact skew silhouette and current high-load fallbacks. | Medium. Mask AA, blur appearance, focus/navigation and rapid-switch lifecycle must remain identical. | Medium–High while the skew switcher is visible; zero expected idle gain when closed. | Low–Medium from fewer offscreen layer/mask surfaces. | Target 0% for mask-only replacement; otherwise <1% with raster A/B. |
| `modules/wallpaperSelector/WallpaperSkewView.qml` | **CANDIDATE — GPU + transient texture RAM.** Current `dev` contains 3 `MultiEffect`, 2 `ShaderEffectSource`, 3 `layer.enabled` sites. The front skew image keeps `layer.enabled: true`; the flipped back face allocates another masked effect only while flipped; a separate shadow MultiEffect is also present. Investigate analytic parallelogram clipping/masking and current-item/visible-range layer materialization. | Medium–High. Must preserve skew AA, flip face, video-preview behavior, delete UI, shadow and rapid navigation. | **High local potential** while the wallpaper selector is open, especially with multiple delegates. | Medium potential from avoiding per-delegate offscreen layer/mask textures. | Target <1%; requires front/back raster comparison including animation frames. |
| `modules/waffle/lock/WaffleLockSurfaceSafe.qml` | **CANDIDATE — lock-screen rendering.** Current `dev` contains 4 `MultiEffect`, 1 `ShaderEffectSource` and 9 Loaders. Full-screen wallpaper blur and avatar masking deserve separate measurement. For static wallpaper, investigate a frozen/cached blur path; keep GIF/video wallpaper dynamic. Avatar mask may be replaceable with a cheaper clip/analytic path. | Medium. Lock reliability and authentication UI take priority over savings; dynamic wallpapers must not freeze. | Medium while locked if the background blur is currently recomputed/materialized more often than needed. | Low–Medium from avoiding persistent mask/capture intermediates. | Target 0% for avatar clipping; <1% for any blur-path substitution. |
| `modules/overview/Overview.qml` | **MEASURE FIRST — conditional full-scene effect.** Current `dev` has one conditional `layer.enabled` + `ShellDesaturationEffect`; its three primary Loaders are already lifecycle-gated. Profile the desaturation path before changing it. Do not disturb the lazy-loader work that is already present. | Medium–High because the effect applies to a composed scene and Overview has input/transition ownership. | Low–Medium only when desaturation is enabled; otherwise none. | Low–Medium if a full-size layer buffer can be avoided. | Target 0%; no candidate should be promoted without capture parity. |
| `modules/abyss/AbyssWaveController.qml` | **MEASURE FIRST — CPU-to-texture update path.** The controller already sleeps when `mode === "SLEEPING"`, uses 128/256 samples, lowers idle disturbance cadence to 100 ms and updates one 1-pixel-high texture. Active mode still advances at 16/33 ms and repaints Canvas samples. Profile JS/Canvas cost before considering a native/image-buffer path. | High. The wave solver, spectrum response, settling and fresh-texture timing are visible behavior. | Low/uncertain; moving work can trade CPU for GPU rather than reduce total GPU. | Negligible–Low. | 0% preferred. Do not alter sample count/cadence unless a <1% perceptual oracle is added. |
| `modules/abyss/AbyssPerimeter.qml` | **LOW-PRIORITY / CURRENTLY CLEAN RENDER GRAPH.** Current `dev` has no MultiEffect, ShaderEffectSource, layer effect or persistent Loader in this file; only bounded interaction timers were found. Continue allocation/read-order research rather than adding another visual renderer. | Low for research; high if reactive topology is changed. | Low expected from renderer changes because the major composition is already centralized. | Low–Medium possible only through proven temporary-array/binding removal. | 0%; avoid visual-path churn. |
| `modules/dashboard/DashboardLayout.js` | **CANDIDATE — CPU/allocation, existing research lineage.** Existing optimization notes identify a guarded X-axis subset and responsive-overlap work. Re-run against current `dev`, preserve malformed-state behavior, candidate ordering/ties and read order, then promote only with oracle parity. | Medium. Geometry ordering and malformed layouts are contract-sensitive. | None directly. | Low from fewer temporary candidate arrays/objects if the guarded subset still exists. | 0%; layout coordinates must remain identical for the strict-lossless path. |
| `modules/dashboard/DashboardCanvas.qml` | **MEASURE FIRST — interactive CPU/binding pressure.** Current file has no MultiEffect/ShaderEffectSource/layer effect and no timers; it has one Loader, one Repeater and several Behaviors. Focus on drag/resize binding churn and object allocation rather than GPU effects. | Medium. Pointer geometry, draft commit/cancel and collision constraints are sensitive. | Low. | Low. | 0%; interaction geometry must be identical. |
| `services/GameMode.qml` | **CANDIDATE — CPU wakeups, not GPU.** Niri window changes already trigger event-driven fullscreen checks, but a recurring fallback timer also runs while auto-detect is active. Research watchdog semantics: reset the fallback only after a trustworthy event-driven check while preserving the maximum detection bound when events are missed. | Medium. The fallback exists for correctness; removing it outright is unsafe. | None. | None. | 0% visual; behavioral latency must remain within the current bound. |
| `services/TimerService.qml` | **CANDIDATE — CPU wakeups, subscription-gated refresh.** Stopwatch refresh runs every 33 ms whenever the stopwatch is running, independent of whether a visible consumer currently needs frame-rate updates. Research deriving elapsed time from the stored start timestamp and using a consumer/visibility lease for presentation refresh without changing persisted time semantics. | Medium–High. Hidden consumers, IPC and exact stopwatch behavior must be audited first. | None. | Negligible. | 0% visual for visible consumers; no timing/semantic drift allowed. |
| `services/Audio.qml` | **LOW PRIORITY / ALREADY BOUNDED.** Two 16 ms dispatch timers are one-shot queue coalescers; the 16 ms repeating ramp timer runs only during protected volume ramps. Do not merge or slow these without evidence because they encode device/protection behavior. | Medium for tiny expected gain. | None. | Negligible. | 0%; audio behavior is functional, not cosmetic. |
| `services/MemoryPressureService.qml` | **NO ACTION / ALREADY OPTIMIZED.** Checks are every 5 minutes, use `FileView` on `/proc/self/maps`, disable file watching and avoid spawning shell+grep. This is already a low-overhead design. | High downside / negligible upside. | None. | Negligible. | 0%. |
| `services/Network.qml` | **LOW PRIORITY / MOSTLY EVENT DRIVEN.** Uses `nmcli monitor`, a 200 ms debounce and bounded restart/rescan timers instead of constant short-interval polling. Keep unless profiling shows subscriber churn or process-spawn cost. | Medium. Connectivity state correctness is more important than micro-savings. | None. | Negligible. | 0%. |
| `modules/common/widgets/FadeLoader.qml` | **NO ACTION / GOOD LIFECYCLE BASELINE.** Loader is active only while shown or animating out, and visibility follows opacity. Preserve this pattern and compare other heavy Loaders against it. | Low. | Indirect only. | Low–Medium savings already realized by unloading hidden content. | 0%. |


| `modules/common/widgets/GlassBackground.qml` + `AngelBackground.qml` + `RicelinSurface.qml` + `ZzzGlassWash.qml` | **HIGH-CONFIDENCE CANDIDATE — bound wallpaper-glass rendering to the visible surface.** These helpers position a screen-sized wallpaper behind a usually much smaller panel, then enable a `MultiEffect` layer on that screen-sized item and mask/clip the result back to the panel. `GlassBackground.qml` explicitly notes that hiding the layer releases roughly 16 MiB per instance. Research a padded, screen-aligned local capture/sourceRect whose bounds are only the panel plus exact blur reach. Keep the original decoded wallpaper cache and sampling transform. | Medium. Crop coordinates, PreserveAspectCrop mapping, fractional scale and corner masks must be exact. | **High local/persistent potential** for visible glass panels because the offscreen blur area can fall from screen area to panel+padding area. | **High local potential** from smaller FBO/effect intermediates; decoded source cache may remain shared. | 0% is plausible for a sourceRect/crop-only path if blur padding and sampling coordinates are exact; otherwise require <1% raster A/B. |
| `modules/bar/BarContent.qml` + `modules/dock/Dock.qml` | **HIGH-CONFIDENCE CANDIDATE — full-screen wallpaper layer used to paint only a thin Bar/Dock slice.** Both Aurora/Angel fallback paths create an Image sized to the whole output, then enable `MultiEffect` blur while the parent clips to Bar/Dock geometry. Research capture-before-blur: retain the same screen-aligned wallpaper transform but materialize only the visible strip/body plus `blurMax` support. Native-blur paths stay unchanged. | Medium. All four Dock edges, Bar top/bottom ownership, PreserveAspectCrop and blur-edge support must be exact. | **High local potential** on non-native-blur Aurora/Angel paths; structural work scales with cropped area rather than full output. | **High local potential**: a full-screen RGBA8 layer is ~7.9 MiB at 1920×1080 and ~31.6 MiB at 3840×2160 before effect intermediates; the candidate should allocate only strip/body+padding textures. These are texture-size calculations, not measured RSS savings. | Target 0%; exact crop oracle should compare every visible pixel including 64 px blur reach. |
| `modules/common/perimeter/ConnectedSurfaceIrisFrame.qml` | **HIGH-CONFIDENCE CANDIDATE — connected shadow has a 4-stage render chain.** Current path renders a second `ConnectedSurfaceIrisField` as a shadow mask, captures it with `ShaderEffectSource`, blurs via `MultiEffect`, then captures the blurred result again with another `ShaderEffectSource` to enforce owner-side clipping. First investigate eliminating only the second capture with an exact clipped presentation item; separately evaluate an analytic SDF shadow integrated with the field as a <1% visual candidate. | Medium for capture elimination; Medium–High for analytic shadow. Owner-side scissoring, tangent weld rules and fractional scale are locked contracts. | Medium–High while connected popups/OSD/toasts/clipboard/edge surfaces are visible; savings multiply because this frame is reused by multiple surface families. | Medium from removing one or more transient shadow textures. | 0% target for second-capture removal; analytic replacement requires <1% global/edge-band A/B and existing shadow contract parity. |
| `services/ResourceUsage.qml` + `modules/common/widgets/ResourceUsageMonitor.qml` | **HIGH-CONFIDENCE CANDIDATE — metric-demand gating.** Lifecycle is already good for history/network, but every active lease still initializes/polls GPU and starts `diskPollTimer` regardless of whether the consumer displays GPU/disk. Default process-backed GPU cadence is 6 s (15 s in Low Power) and disk launches `df -B1 /` every 30 s. Add independent GPU/temperature/disk demand bits, prime each metric when demand appears, and preserve existing defaults for callers until all consumers are annotated. | Low–Medium. Must preserve immediate freshness when a metric becomes visible and existing retry/startup semantics. | None directly; may reduce dGPU/process activity and system power rather than rendering work. | Negligible direct RAM. | 0%. |
| `modules/background/Backdrop.qml` + `modules/waffle/backdrop/WaffleBackdrop.qml` | **MEASURE FIRST — full-screen blur is inherently full-screen, but animated branches remain expensive.** Static Aurora already decodes/renders at half resolution in the ii backdrop; GIF/video blur is gated by animation/effects/battery state and frozen-video frames release the decoder. Do not duplicate the Bar/Dock crop strategy here because the visible result is the whole output. Profile animated blur and transition overlap before proposing further visual compromise. | High for small expected gain unless profiling identifies a dominant branch. | Potentially high only during animated blurred wallpapers; otherwise current gating is already strong. | Medium transient during crossfade/animated blur. | 0% preferred; any temporal/downsample change requires <1% visual metric plus motion acceptance. |
| `modules/lock/LockSurface.qml` | **MEASURE FIRST — many small effect layers plus one full-screen safe blur.** Current file contains one safe `MultiEffect` wallpaper blur and numerous conditional DropShadow layers on lock-screen text/icons. The focus retry timer is bounded by attempts and is not an idle-loop target. Profile effect-node/FBO residency while locked before considering group-shadow consolidation. | High because lock readability/authentication reliability outrank micro-savings. | Medium only while locked if many individual shadow layers are simultaneously materialized. | Low–Medium. | Target 0%; do not change legibility or focus timing. |


| `services/AntiFlashbangSampler.qml` + `services/Brightness.qml` | **HIGH-CONFIDENCE FEATURE-ENABLED CPU/process candidate.** Anti-Flashbang is disabled by default, but when enabled each output samples at 500 ms by default by spawning `timeout -> bash -> grim -> magick`; event-triggered requests can add samples around window/workspace changes. Research a native streaming PPM mean-luminance helper or direct native capture/reducer that removes shell/ImageMagick process churn while preserving the current brightness policy and failure/backoff semantics. | Medium–High. This is a safety/comfort feature: sample meaning, timeout, fallback-to-1 after failures and policy thresholds must not drift. | None directly. | Low direct RAM; meaningful transient process/allocation reduction while enabled. | 0% visual-policy target. Any luminance numerical difference must be bounded tightly enough that threshold/multiplier decisions remain identical across an oracle corpus. |
| `services/WindowPreviewService.qml` | **MEASURE FIRST — bounded warm decoded preview cache.** The service intentionally retains up to 12 decoded 768×512 images, documented in-source as ~18 MiB of CPU pixel data, so Overview/hover previews open without decode latency. This is bounded rather than a leak. Research pressure-aware eviction only if RSS evidence shows value; keep disk snapshots and recapture policy unchanged. | Medium. Eviction can trade RAM for first-presentation latency even if pixels remain identical. | None. | Up to the bounded warm-cache footprint can be reclaimed under pressure; no baseline saving should be claimed unless the cache policy changes. | 0% pixels, but UX latency risk means this is not strict behavioral parity. |
| `services/RecorderStatus.qml` | **NO ACTION / BOUNDED FALLBACK.** External `wf-recorder` discovery uses `pgrep` every 15 s (30 s Low Power) only when not recording and no fast UI demand; visible recorder UI owns a separate 1 s demand poll and action-triggered checks are bounded. Existing regression explicitly protects this split. | High downside for tiny idle saving unless an equally reliable event source replaces external-recorder discovery. | None. | Negligible. | 0%. |
| `services/MprisController.qml` | **NO NEW CANDIDATE FROM THIS PASS.** The previously identified unconditional PipeWire enrichment debt has already been adapted: `pw-dump` is now scheduled from audio-stream/player-relevant events rather than an unconditional construction-time call. MPD bridge probing remains a separate compatibility path for ALSA/direct MPD. | Medium. Media discovery compatibility is broad. | None. | Negligible. | 0%. |

## Promotion order

1. **Bounded wallpaper-glass capture** — `GlassBackground` family plus Bar/Dock non-native-blur paths. This attacks screen-sized offscreen layers that are often displayed only through small panel geometry.
2. **ConnectedSurfaceIrisFrame shadow capture elimination** — first remove only the redundant post-blur capture if exact clipping parity can be proven; keep analytic-shadow replacement as a separate <1% candidate.
3. **ResourceUsage metric-demand gating** — add GPU/temperature/disk demand leases so persistent CPU/RAM-only consumers do not launch unrelated probes/processes.
4. **Anti-Flashbang native sampler** — high CPU/process reduction when the opt-in feature is enabled; preserve luminance/policy decisions exactly.
5. **WallpaperSkewView masked delegate layers** — strong transient GPU/RAM candidate while the selector is open.
6. **AltSwitcher skew mask/blur path** — strong interactive GPU candidate with bounded lifetime.
7. **Waffle lock static-wallpaper blur + avatar mask specialization** — potentially valuable because lock screens can remain visible for long periods.
8. **DashboardLayout guarded allocation/CPU work** — strict-lossless if current-dev oracle parity is re-established.
9. **GameMode fallback watchdog research** — small CPU/wakeup candidate with no visual change.
10. **TimerService consumer-gated stopwatch presentation refresh** — only after all consumers are enumerated.

## Explicit non-candidates from this pass

- Do not reopen Screen Edge renderer optimization until live acceptance/measurement provides a new bottleneck; the current path is already aggressively reduced.
- Do not rewrite `AbyssPerimeter.qml` rendering just because it is large; the current file does not show the MultiEffect/capture pattern targeted by this audit.
- Do not optimize `MemoryPressureService.qml` polling: five-minute direct `FileView` reads are already bounded and cheaper than the previous process-spawn pattern.
- Do not merge Audio timers merely to reduce timer count; they are short-lived functional coalescers/ramp control, not idle polling.
- Do not infer cost from Timer/Loader counts alone. Runtime residency, repaint invalidation and source dirtiness must be measured.

## Required evidence before implementation

For every promoted candidate, record:

1. exact parent `dev` SHA;
2. source file/blob SHA;
3. current behavior/lifecycle contract;
4. focused oracle or deterministic regression covering malformed/edge states where applicable;
5. before/after process CPU, RSS and GPU evidence when the candidate claims resource improvement;
6. visual A/B evidence for any visual-path substitution, with normalized global error below 1%;
7. canonical `bash scripts/validate-maintainer-local.sh` result for the exact committed candidate SHA;
8. owner-session compositor validation separately when the change depends on live Niri/Quickshell behavior.

This document is a prioritized research map, not a claim that every candidate will produce a measurable whole-application improvement.

## Research continuation — 2026-10-07

Baseline for this continuation: `7308011b38035c9c3c5f5374bbbea874e6ef1d3b`.

### R2.1 — Bounded wallpaper-glass capture

Source evidence:

- `modules/common/widgets/GlassBackground.qml` blob `0df61709dc3ab6f1667196ca66a1c85c188dd960` uses an Image with `width: root.screenWidth`, `height: root.screenHeight`, then enables a `MultiEffect` layer while the component itself is panel-sized and masked.
- `AngelBackground.qml`, `RicelinSurface.qml` and `ZzzGlassWash.qml` repeat the same screen-aligned wallpaper pattern.
- `BarContent.qml` blob `3afa7aa5e27c069ceed6c3db71d34f1e7ef445d1` and `Dock.qml` blob `a42cff209c3f9239ad0818987af7f50a00e1f645` each create a full-output wallpaper Image and attach a blur `MultiEffect`, while parent geometry clips the visible result to a narrow Bar/Dock body.

Research direction:

1. keep one normal decoded/cached wallpaper source;
2. preserve the exact screen-space PreserveAspectCrop transform;
3. capture/materialize only `visibleSurfaceBounds + exactBlurReach`;
4. blur that bounded texture;
5. crop/mask to the existing body exactly.

The strict-lossless oracle must compare the old/new result for all screen edges, arbitrary panel coordinates, fractional scale, multiple source aspect ratios and blur disabled/enabled. No implementation should rely on a guessed fixed 64 px padding when the effective kernel or scale changes.

### R2.2 — Connected iRiS shadow pass reduction

`modules/common/perimeter/ConnectedSurfaceIrisFrame.qml` blob `e703046f2a527ad30afc1a83ccd71f5e5a78cba7` currently contains:

```text
ConnectedSurfaceIrisField (shadowMaskField)
  -> ShaderEffectSource (shadowTextureSource)
  -> MultiEffect blur (blurredShadow)
  -> ShaderEffectSource crop (isolatedShadow)
  -> visible ConnectedSurfaceIrisField
```

The first promotion candidate is intentionally narrow: prove that `isolatedShadow` can be replaced by exact rectangular clipping/presentation without changing blur sampling or owner-side cutoffs. That would remove one capture texture/pass while leaving the accepted mask field and MultiEffect blur untouched.

A second, separate candidate may adapt the Screen Edge analytic-shadow technique to the iRiS SDF and remove the mask/capture/blur chain entirely. That is not strict-lossless by assumption; it requires a <=1% raster budget plus edge-band and maximum-channel-delta checks.

### R2.3 — ResourceUsage metric leases

`services/ResourceUsage.qml` blob `1d8e8693c230ee7450072366557b6070d433af58` already demand-gates history arrays and network parsing. The remaining lease is coarse:

- first consumer initializes GPU source detection and hybrid-GPU detection even if it needs only CPU/RAM;
- while the service is alive, `diskPollTimer` runs every 30 s and launches `/usr/bin/df -B1 /`;
- process-backed GPU usage may launch `nvidia-smi` or `intel_gpu_top` every 6 s by default (15 s minimum in Low Power);
- `ResourceUsageMonitor.qml` currently exposes only `histories` and `network` demand bits.

Strict-lossless direction: extend the lease with independent `gpu`, `temperature` and `disk` demand. Consumers that display those metrics opt in; when a demand transitions 0 -> 1, prime that metric immediately so the UI never shows a stale value. Existing callers can default to current behavior until every built-in consumer is annotated and contract-tested.

This is especially relevant to persistent Bar/VerticalBar consumers: their monitor already sets `network: false` and `histories: false`, but the service still performs disk polling and GPU work even when the corresponding indicators are disabled.

### R2.4 — Findings deliberately not promoted

- `MemoryPressureService.qml`: already uses a five-minute direct `FileView` read with no watch and no shell process.
- `KeyboardIndicators.qml`: primary state is event-driven through the native input-lock monitor; the recurring LED discovery timer is fallback-only while evdev is unavailable.
- `Battery.qml`: cycle-count refresh is only every 15 minutes.
- `Audio.qml`: 16 ms timers are short-lived queue/ramp control, not idle periodic polling.
- `Backdrop.qml`: static Aurora already uses half-resolution source/effect textures and frozen-video paths release decoders; further work needs measurement rather than generic timer/effect deletion.

## Research continuation — round 3

Baseline: `dev` at `7f6a735269980d0f40ff12fbb4f5799b2e180d11`.

### R3.1 — Anti-Flashbang process-chain removal

Current source identity:

- `services/AntiFlashbangSampler.qml`: `eecb90a0aedd07a4376772883d2b46010fa3a533`;
- `services/Brightness.qml`: `2a67e59a2aaca66e915f9d4bd3ab9ca06cb95e80`;
- default config keeps `light.antiFlashbang.enable=false`, `sampleInterval=500`, `sampleScale=0.10`.

The current sampler invokes, per active output and periodic sample:

```text
timeout
  -> /bin/bash -o pipefail
       -> grim -o OUTPUT -s SCALE -t ppm -
       -> magick ppm:- -colorspace Gray -format '%[fx:mean*100]' info:
```

This is intentionally not classified as a default-idle Hadalis cost because the feature ships disabled. Once enabled, however, it is a high-frequency process pipeline and therefore a high-confidence optimization target.

Strict-lossless research path:

1. keep output selection, scale, timeout, generation, pending/debounce and failure backoff unchanged;
2. replace only the shell/ImageMagick reduction portion with a small native streaming PPM reducer, or a direct native capture path if the existing compositor API can provide identical sampled pixels;
3. build a corpus oracle containing generated RGB frames, gradients, near-threshold frames, real `grim` captures and malformed/truncated PPM;
4. compare native mean against the current ImageMagick result and then run both through `antiFlashbangPolicy.js`;
5. require identical policy branch/multiplier results at every threshold-boundary case before calling it strict-lossless.

Do not optimize by merely increasing `sampleInterval` or reducing `sampleScale`; those are behavior/quality changes and belong to a separate user-controlled tradeoff, not this strict-lossless program.

### R3.2 — Warm preview cache is bounded, not a leak

`services/WindowPreviewService.qml` at `2bfca7368179e3f6cbaff32ac0375daa49ab8a38` explicitly caps decoded warm previews at 12 images of 768×512 and documents approximately 18 MiB of CPU pixel residency. It also destroys entries as the LRU-style order exceeds that limit.

Conclusion: do not classify this as an unbounded RAM bug. A pressure-aware eviction hook could reclaim RAM while keeping disk snapshots, but it changes first-open decode latency and therefore is only a conditional RAM/latency tradeoff. Measure RSS and presentation latency before promotion.

### R3.3 — Existing process-polling work that should not be rediscovered

- `RecorderStatus.qml` at `7e221f7168f42c5348f4b07fe7ae8a0827c6a946` already separates slow 15 s/30 s external-recorder discovery from 1 s UI-demand polling and bounded action checks.
- `MprisController.qml` at `3a8184f9308f0816ea395ea26f182bb5a3fbcf15` no longer performs unconditional construction-time `pw-dump`; stream metadata refresh is triggered by relevant audio/player state. This matches the earlier optimization research and should not be promoted again.
- `TlpRuntimeCapabilities`, `PowerProfilePersistence` and `ThinkFanService` use sparse safety cadences and/or feature/runtime demand. Historical startup notes must be checked before any new promotion so removed/evolved startup debt is not counted twice.

### R3.4 — Cache sweep conclusion

The cache sweep did not find a new high-confidence unbounded core RAM cache:

- AltSwitcher/Waffle icon caches are capped at 100 entries.
- Window preview warm decode is capped at 12 entries.
- Settings page retention is capped.
- Wallhaven tag/suggestion caches have explicit limits.
- Background wallpaper-size metadata cache is capped.
- Anime schedule cache has a small finite day-key space.
- AppSearch caches are proportional to the installed DesktopEntry set and intentionally avoid repeated fuzzy-preparation work.

`NewsService` keeps feed responses by feed URL for the lifetime of the deferred singleton, but its practical key space is tied to a small fixed topic/mode set. It is lower priority than the render-pass and process-spawn candidates above unless RSS evidence shows otherwise.

