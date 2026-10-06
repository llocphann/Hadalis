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


| `services/Notifications.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — fuse derived-history rebuilds.** Every list mutation currently filters the full list for popups, scans the full list for latest-per-app timestamps, scans the full list again to build groups, then scans the popup subset again for popup groups. A single ordered pass can build popupList, latest timestamps and both group maps while preserving first-icon ownership, notification ordering, critical flags and the existing quirk that popup-group time is derived from the latest notification for that app across the full history. | Low–Medium if read/order parity is oracle-tested; notification objects/actions/timers are untouched. | None. | Low transient allocation reduction; persistent history size unchanged. | 0%. |
| `modules/common/widgets/Favicon.qml` | **HIGH-CONFIDENCE CPU/process candidate — eliminate cached-hit shell spawn and coalesce duplicate misses.** Every component instance starts `/usr/bin/bash` on completion even when the favicon file already exists; uncached instances can race for the same domain and launch duplicate curl work. Research a shared resolver/in-flight map: try the local cached URL without a child process, perform one direct curl/fetch per missing domain, then fan out the resulting URL to all waiters. | Low–Medium. Must preserve failed-download semantics, file identity, user agent and retry behavior; malformed/corrupt cache handling needs an explicit contract. | Negligible. | Low direct RAM; avoids transient child-process memory. | 0%. |
| `modules/mediaControls/EqualizerPanel.qml` + `modules/sidebarRight/CompactSidebarRightContent.qml` | **HIGH-CONFIDENCE hidden-work candidate — presentation-gate the CAVA lease.** The compact sidebar keeps its base Controls section loaded permanently; when the Media subsection exists, its Equalizer uses `active: root.panelVisible` even while a different sidebar section is presented. The Canvas 33 ms animation clock becomes effectively hidden with its ancestor, but the explicit Equalizer/CAVA subscription can remain held for the whole time the sidebar is open. Research a presentation lease that retains CAVA through the controls crossfade/prewarm boundary and releases it once Controls/Media cannot contribute visible pixels. | Medium. Returning directly to Controls must not expose analyzer startup/stale-spectrum latency; crossfade timing and other CAVA consumers must remain unchanged. | Low–Medium indirect reduction when this is the last CAVA consumer. | Low. | 0% target; release only outside the visible/crossfade interval. |


| `modules/wallpaperSelector/WallpaperSkewView.qml` | **HIGH-CONFIDENCE transient CPU/process candidate — uncached color analysis.** In addition to the GPU mask candidate above, current `dev` automatically walks every non-video item after color-cache load, component completion, count changes and folder changes; uncached images are processed in batches of 20 by one Bash script that invokes ImageMagick `convert` once per image. This work happens even with default `sortMode: "date"` and no color filter selected. Research a single native/batched analyzer with parity to the current 1×1 HSL result; separately evaluate demand-driven analysis only if color-filter first-use latency is explicitly accepted. | Medium. Hue/saturation bucket output, failure handling, queue ordering and cache publication must remain stable. Cache identity is currently filename-only and collides across folders; do not optimize around that bug without defining migration/path identity. | None. | Low direct RAM; lower transient child-process memory. | 0% for native-equivalent analysis; deferred first-use analysis changes interaction latency and is not strict behavioral parity. |


| `scripts/inir` | **HIGH-CONFIDENCE startup latency/process candidate — repair the pre-QML environment cache and ABI fast path.** `_get_systemd_user_env()` mutates cache variables but both consumers capture it with command substitution, so the function runs in a subshell and its cache state does not reach the parent. `apply_qt_runtime_env()` can therefore invoke bounded `systemctl --user show-environment`, then background `ensure_systemd_graphical_env` invokes it again while QML starts. Separately, `check_qs_abi()` runs `qs --version` before consulting the mtime-keyed successful ABI cache. Populate/read environment cache in the parent shell, parse the snapshot once, and move the exact successful ABI cache check ahead of `qs --version` while retaining a full probe when binary/library identity changes. | Low–Medium. Session env recovery and ABI mismatch protection are startup-critical; fallback paths must remain byte/condition equivalent. | None. | Negligible steady RAM; lower transient process memory. | 0%; no UI behavior change. |
| `shell.qml` + `services/ThinkFanService.qml` | **HIGH-CONFIDENCE default-startup process candidate — demand-gate ThinkFan ownership.** `shell.qml` force-materializes `ThinkFanService` every session, while the shipped default is `powerProfiles.fanControl.enabled=false`. The singleton immediately runs `/usr/libexec/inir-thinkfan --status` on completion. Keep session-long ownership when profile fan control is enabled, react when it becomes enabled later, and let Settings/System Monitor materialize/refresh the service on demand otherwise. | Low–Medium. Must preserve profile-follow immediately after enable and existing managed/direct-control detection. | None. | Negligible direct RAM; avoids helper/process fan-out on default sessions. | 0%. |
| `services/Battery.qml` + `services/TlpService.qml` | **HIGH-CONFIDENCE default-startup process candidate — separate normal battery telemetry from charge-care capability.** Battery unconditionally binds many `TlpService.*` properties, which materializes `TlpService`; its completion unconditionally runs `/usr/libexec/inir-battery-charge-limit --status` even though shipped `battery.chargeLimit.enable=false`. Demand-load/prime the charge-limit adapter when charge care is enabled or the Battery/TLP Settings surface needs capability details; keep ordinary UPower battery state independent. | Medium. Settings must get authoritative capability/status immediately on first presentation, and enabled policies must reconcile on boot before any write. | None. | Negligible direct RAM; avoids helper/process fan-out on default sessions. | 0%. |
| `services/Audio.qml` + `modules/common/widgets/SoundPicker.qml` | **HIGH-CONFIDENCE settings-only startup candidate — lazy sound-theme catalog.** Audio correctly refreshes microphone state on materialization, but also always runs `sh -> ls | sed | sort` to populate `themeSounds`. Repository search shows the catalog is consumed by `SoundPicker` only, and SoundPicker is used by Settings pages. Add idempotent `ensureThemeSoundsLoaded()`; refresh on audio-theme changes only after the catalog has been demanded. | Low. Preserve first Settings presentation and post-theme-change contents/order exactly. | None. | Negligible direct RAM; removes one startup shell pipeline. | 0%. |
| `modules/common/Appearance.qml` | **HIGH-CONFIDENCE settings/explicit-backend startup candidate — demand-gate Niri blur capability probe.** Appearance runs `niri --version` whenever Niri is active. Yet `blurBackendFor()` explicitly makes `auto` fidelity-first and never selects compositor blur; `nativeBlurSupported` is otherwise used by explicit compositor selection and Effects Settings visibility. Probe only when any effective blur backend requests `compositor`, or when an Effects Settings surface asks for capability; reactively prime when config changes. | Low–Medium. Explicit compositor config present at boot must not briefly fall back to wallpaper/off due to an unresolved capability. | None. | Negligible. | 0%. |
| `modules/common/widgets/MediaArtworkResolver.qml` | **HIGH-CONFIDENCE process dedupe candidate — share in-flight artwork resolution by cache key.** Six call sites can materialize independent resolvers for the same current media. Each instance independently launches cache-existence checks, local MIME checks/copies, file-stability checks, data-URI writers or curl download/retry workers against the same deterministic cache path. Atomic publish prevents corruption but does not prevent duplicated work. Research a shared resolver keyed by normalized metadata/cache identity that owns one in-flight operation and publishes readiness to all consumers. | Medium. Preserve display-source cache-busting, local-file stability checks, retries, MIME rejection and old-art retention during metadata transitions. | None directly. | Low–Medium transient reduction from fewer concurrent helper processes and duplicated buffers. | 0%. |
| `modules/common/widgets/CliphistImage.qml` | **HIGH-CONFIDENCE transient process dedupe candidate — one decode owner per clipboard entry.** Visibility gating prevents mass decode, and atomic temp-file publication prevents corruption, but multiple clipboard/search surfaces can still see the same uncached image simultaneously and each launch a Bash + `cliphist decode` pipeline before the shared output exists. A shared per-entry in-flight lease can let one owner decode while all waiters publish the same completed path. | Low–Medium. Entry identity, failure behavior and session-cache cleanup must remain unchanged; do not make invisible rows eager. | None. | Low transient reduction. | 0%. |
| `services/ThemeService.qml` + `services/MaterialThemeLoader.qml` + `services/IconThemeService.qml` + `services/FontSyncService.qml` | **MEASURE FIRST — separate shell-internal theme readiness from external desktop synchronization.** At Config-ready, shell calls ThemeService and IconThemeService. ThemeService can queue `applycolor.sh` plus the default-enabled Vesktop palette generation; IconThemeService restores the saved theme via `gsettings set` then runs native desktop icon sync; FontSync later reconciles GTK/KDE fonts. Shell palette/icon identity should stay immediate, but external app synchronization could be coalesced/deferred until after first frame if startup traces show contention. | Medium–High. External applications may observe synchronization timing, so this is not strict behavioral parity unless the deferred boundary is proven unobservable for session startup. | None. | Low transient. | Shell visual target 0%; external-app timing requires separate acceptance. |
| `modules/common/Directories.qml` + `services/SystemInfo.qml` | **MEASURE FIRST — split critical bootstrap directories from transient cleanup and lazy GECOS display-name lookup.** Directories already consolidated fourteen child processes into one ordered Bash bootstrap, but that command still removes feature temp trees during first-frame formation. SystemInfo seeds username from `$USER` yet immediately runs `getent passwd` to resolve displayName. Measure before changing: defer only cleanup that no startup-visible feature requires, and resolve displayName on first profile/lock/settings demand while retaining NSS correctness. | Medium. Early avatar/profile consumers and stale-cache cleanup contracts must be enumerated first. | None. | Low. | 0%. |

## Promotion order

1. **Bounded wallpaper-glass capture** — `GlassBackground` family plus Bar/Dock non-native-blur paths. This attacks screen-sized offscreen layers that are often displayed only through small panel geometry.
2. **Pre-QML environment/ABI fast path** — repair the broken parent-shell environment cache and let unchanged ABI identity skip `qs --version`; highest-confidence startup latency candidate.
3. **ConnectedSurfaceIrisFrame shadow capture elimination** — first remove only the redundant post-blur capture if exact clipping parity can be proven; keep analytic-shadow replacement as a separate <1% candidate.
4. **ResourceUsage metric-demand gating** — add GPU/temperature/disk demand leases so persistent CPU/RAM-only consumers do not launch unrelated probes/processes.
5. **Default-off capability demand gating** — ThinkFan, battery charge-limit/TLP, Audio sound catalog and Niri native-blur capability should not spawn startup probes until their feature/settings demand exists.
6. **Anti-Flashbang native sampler** — high CPU/process reduction when the opt-in feature is enabled; preserve luminance/policy decisions exactly.
7. **Notification derived-state single pass** — strict-lossless CPU/allocation reduction for long histories without truncating or changing persisted history.
8. **Media artwork shared in-flight resolver** — coalesce identical cache checks/download/copy/stability work across simultaneously visible media surfaces.
9. **Favicon shared resolver/in-flight coalescing** — remove cached-hit Bash spawns and duplicate cache-miss downloads.
10. **Clipboard image decode in-flight coalescing** — keep visibility-lazy behavior but avoid duplicate decode processes for the same entry.
11. **Compact Sidebar Equalizer presentation lease** — release hidden CAVA ownership without changing visible analyzer frames.
12. **WallpaperSkew color-analysis process consolidation** — eliminate one ImageMagick process per uncached image while preserving exact color buckets.
13. **WallpaperSkewView masked delegate layers** — strong transient GPU/RAM candidate while the selector is open.
14. **AltSwitcher skew mask/blur path** — strong interactive GPU candidate with bounded lifetime.
15. **Waffle lock static-wallpaper blur + avatar mask specialization** — potentially valuable because lock screens can remain visible for long periods.
16. **DashboardLayout guarded allocation/CPU work** — strict-lossless if current-dev oracle parity is re-established.
17. **GameMode fallback watchdog research** — small CPU/wakeup candidate with no visual change.
18. **TimerService consumer-gated stopwatch presentation refresh** — only after all consumers are enumerated.

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

## Research continuation — round 4

Baseline: `dev` at `b9821ec8f3959b075e8c7a0a60d902baa8c472c0`.

### R4.1 — Notification derived-state fusion

Current source: `services/Notifications.qml` at `a05c6744c123d8ed96ee19c8d04cccdbcdeeae0e`.

The current `_updateGroups()` pipeline performs:

```text
list.filter(popup)                 ~ N
list.forEach(latest-per-app)       ~ N
_groupsForListOptimized(list)      ~ N
_groupsForListOptimized(popupList) ~ P
sort full app names                ~ G log G
sort popup app names               ~ Pg log Pg
```

where `N` is retained history length and `P` is the popup subset. The repository has no configured notification-history count/age cap, so this path scales with long-session history.

A strict-lossless replacement can traverse `root.list` once and construct:

- `popupList` in original list order;
- `latestTimeForApp`;
- full groups, preserving the first encountered `appIcon`, notification order and critical flag;
- popup groups, preserving the first popup notification's icon and popup order.

After the pass, set both full and popup group `time` from the completed **full-history** `latestTimeForApp`, because that is what the current two-stage implementation does even for popup groups. Then sort the same group-key sets with the same comparator.

Required oracle: randomized histories including duplicate app names, equal timestamps, mixed popup state, critical urgency, empty names and mutation sequences. Compare public `popupList`, `latestTimeForApp`, group object fields, notification reference identity and app-name ordering.

This candidate deliberately does **not** cap history or alter persistence; those would change user-visible/history semantics.

### R4.2 — Favicon cached-hit and duplicate-miss process churn

Current source: `modules/common/widgets/Favicon.qml` at `3d7e24e97236e53a174c977736d75e5ed850871d`.

Every component completion starts:

```text
bash -c '[ -f CACHE ] || curl ...'
```

Therefore a cache hit still creates a shell process. Multiple simultaneously materialized delegates for the same uncached domain have no shared in-flight owner and can race into duplicate shell/curl work.

Research path:

1. centralize per-domain state: `unknown / loading / ready / failed`;
2. let cached files resolve without a process spawn;
3. permit only one download owner for a domain;
4. preserve `curl -f --remove-on-error` semantics or an equivalent direct fetch failure contract;
5. publish the same cache URL to all waiting Favicon instances;
6. retain bounded/explicit retry behavior for failures and define corrupt-cache behavior rather than silently changing it.

Measure cold-cache and warm-cache child-process counts across Search, AI source chips and other multi-item surfaces. The primary claim should be process-count/CPU reduction, not GPU improvement.

### R4.3 — Compact Sidebar hidden Equalizer ownership

Current source:

- `modules/mediaControls/EqualizerPanel.qml`: `2be0c2479bd26bc259077a3a2f07e32ba0b1782a`;
- `modules/sidebarRight/CompactSidebarRightContent.qml`: `da5520299f6562a484b31fe8c3a449ab54abab73`;
- `modules/common/widgets/CavaProcess.qml`: `c8c5e5ea82181d2a28c8af4839920305edad6610`.

The compact sidebar keeps the Controls section loaded unconditionally:

```qml
active: sectionItem.isBase
    || sectionItem.isCurrent
    || Math.abs(root.activeSection - sectionItem.index) <= 1
```

Inside Controls, the Media subsection materializes an `EqualizerPanel` with:

```qml
active: root.panelVisible
```

The Equalizer's CAVA wrapper holds a shared service lease whenever `active` is true. Its Canvas clock is `running: root.active && analyzerCanvas.visible`; ancestor visibility can suppress paint, but it does not release the explicit CAVA lease.

A candidate should therefore target **subscription ownership**, not delete the 33 ms visual clock. That clock intentionally drives the electric-wire `Date.now()` motion while the analyzer is visible.

Strict-lossless boundary: keep the subscription through any period in which Controls can contribute pixels during the section crossfade. If direct navigation can jump from a distant section to Controls, prove that pre-acquisition still supplies the same first visible spectrum frame; otherwise classify the release as a tiny presentation-latency tradeoff rather than strict-lossless.

### R4.4 — Existing optimizations confirmed, not re-promoted

- `AppSearch.qml` already has a limited-result top-N path that avoids allocating/sorting the full score-record set, and lazy prepared-name/icon arrays are revision-cached.
- `MprisController.qml` already moved `pw-dump` behind relevant stream state, matching earlier research.
- Niri window updates already use pending/published batching for presentation churn. The remaining GameMode live-state idea is already tracked in this audit and must preserve the batching contract rather than bypass it globally.
- Notification timer/object destruction on explicit discard is already correct; the new target is repeated derived-state traversal, not orphan cleanup.

## Research continuation — round 5

Baseline: `dev` at `481f9f44cef96e21178b741eb27c743fba4c4cd2`.

### R5.1 — WallpaperSkew color-analysis process consolidation

Current source: `modules/wallpaperSelector/WallpaperSkewView.qml` at `5357519b2dfb96cf2fa7bc52cb239df11d30b974`.

The current color path is still present on current `dev`:

- `_analyzeUncachedColors()` is called after cache load/failure, component completion, count changes and folder changes;
- default mode remains `sortMode: "date"` and `colorFilter: -1`, so uncached color work is not demand-gated by actual color sorting/filtering;
- each batch contains at most 20 images;
- one Bash process is created for the batch, but that script invokes `convert` once for every image:

```text
for each uncached image:
    convert IMAGE -resize 1x1! -colorspace HSL
        -format '%[fx:hue*360] %[fx:saturation] %[fx:lightness]' info:
```

For a folder with `N` uncached non-video images, the current design therefore performs approximately `ceil(N/20)` Bash launches plus `N` ImageMagick child executions.

The preferred strict-lossless direction is **process consolidation**, not simply delaying work:

1. create one helper invocation per batch (or one long-lived bounded request) that reads all batch images itself;
2. emit the same `name<TAB>hue saturation lightness` logical records;
3. preserve sequential result association, per-image failure isolation and current bucket rules;
4. compare against ImageMagick over representative JPEG/PNG/WebP/GIF/static-frame inputs and threshold-boundary HSL values;
5. retain asynchronous batching so UI navigation is not blocked.

A native implementation can be considered only if decoder/color-space behavior is qualified against the current ImageMagick reference. Merely replacing HSL math with an approximate formula is not sufficient for a strict-lossless claim.

### R5.2 — Cache identity prerequisite

The color database is currently addressed by bare `fileName` rather than normalized full path. Two different folders containing the same filename can therefore reuse one color record.

This is a correctness constraint for any optimization:

- a new analyzer must not make the filename collision harder to migrate;
- a path-aware or content-aware key should be evaluated as a separate correctness change;
- performance measurements must distinguish analysis avoided by a valid cache hit from analysis incorrectly skipped because of a filename collision.

The optimization table does not count correcting this identity bug as a resource gain.

### R5.3 — High-frequency timer sweep

A targeted 16/33 ms timer sweep did not justify additional generic timer consolidation:

- `AbyssWaveController` already sleeps when the simulation settles;
- `Audio` 16 ms timers are bounded queue/ramp control;
- `EqualizerPanel` uses its 33 ms clock for intentional continuously animated electric-wire geometry via `Date.now()`; deleting the clock would change pixels;
- common slider/search/background timers found in this pass are interaction/debounce/safety timers rather than unconditional idle animation loops.

Therefore timer count alone remains a rejected optimization heuristic. The higher-value action is to release the owning presentation/service lease when a surface cannot contribute visible pixels.

## Research continuation — round 6

Baseline: `dev` at `5cfb6cc9cc6cb1a4b782362b3137343e4fa8d83e`.

### R6.1 — Pre-QML environment cache is not actually shared

Current source: `scripts/inir` at `5cf6ca0ef112cf0f98ee28f23cc618cbb34d5018`.

The launcher declares:

```bash
_cached_systemd_env=""
_cached_systemd_env_fetched=false

_get_systemd_user_env() {
    if [[ "$_cached_systemd_env_fetched" == true ]]; then
        printf '%s' "$_cached_systemd_env"
        return 0
    fi
    _cached_systemd_env_fetched=true
    _cached_systemd_env="$(timeout 3s systemctl --user show-environment 2>/dev/null)" || true
    printf '%s' "$_cached_systemd_env"
}
```

but both main consumers use command substitution:

```bash
_qs_sys_env="$(_get_systemd_user_env)"
sys_env="$(_get_systemd_user_env)"
```

Bash executes command substitution in a subshell. Therefore `_cached_systemd_env_fetched=true` and the snapshot assignment do not persist to the parent shell. On both the normal path and session-boot path, `apply_qt_runtime_env()` can perform the first bounded `systemctl --user show-environment`; the subsequently backgrounded `ensure_systemd_graphical_env &` inherits the parent state in which the cache is still unfetched and can perform the second call while Quickshell is starting.

Strict-lossless research direction:

1. add a parent-shell population function that mutates the two cache variables without command substitution;
2. let consumers read `$_cached_systemd_env` directly after population;
3. parse the multiline snapshot once into presence/value helpers rather than repeatedly spawning `grep | head | cut` and `grep -q`;
4. preserve all existing fallback socket/environment detection and the 3 s fail-open deadline;
5. add a shell contract test with a fake `systemctl` that counts calls and proves both consumers observe the same snapshot.

This is a structural correctness fix to the intended cache contract as well as a startup optimization.

### R6.2 — ABI cache lookup occurs after an avoidable process

The same launcher calls `qs --version` at the beginning of `check_qs_abi()`, then computes the mtime-keyed `v2:<qs_mtime>:<qt_mtime>` cache and returns immediately when that cache matches.

On an unchanged successful installation, the expensive `strings` scan is correctly skipped, but the `qs --version` process has already been launched.

A safe fast path can compute exact binary/library identity first, compare the successful cache, and return before `qs --version` only when both identities match the previously validated pair. Any changed/missing identity falls through to the current full mismatch checks. The cache must remain **success-only**; never cache or bypass a prior mismatch.

### R6.3 — Default-off feature probes are still startup-owned

Verified current source identities:

- `shell.qml`: `aae76205a819e9b098f6a4be7fb6d56e14ff4900`;
- `ThinkFanService.qml`: `943082413a143df3e642ee3d60587093dda1ec02`;
- `Battery.qml`: `e276ddc01dcbe01977e1f285ed2c7dc46e5928d2`;
- `TlpService.qml`: `4e0ef4fba76eb00df7ddc54941e205029dde07ec`;
- `Audio.qml`: `03e2286f1e4035113ba33523c196aca27904cdcc`;
- `SoundPicker.qml`: `c9f041163d1572230dee136e48efc735bc01a65c`;
- `Appearance.qml`: `55480307855a511518206c8dbea5e5eb20d76c33`.

The four ownership splits are independent:

**ThinkFan**
- shell has `property var _thinkFanService: ThinkFanService`;
- default `powerProfiles.fanControl.enabled=false`;
- `ThinkFanService.Component.onCompleted: root.refresh()`;
- detector command is `/usr/libexec/inir-thinkfan --status`.

**Battery charge care**
- default `battery.chargeLimit.enable=false`;
- ordinary Battery singleton binds `TlpService.available/supported/.../statusReason` unconditionally;
- `TlpService.Component.onCompleted` calls `_detect()`;
- detector command is `/usr/libexec/inir-battery-charge-limit --status`.

**Audio theme sound catalog**
- Audio's microphone state refresh is legitimate startup work;
- the same completion handler also starts `themeSoundsProc`;
- that process is `/bin/sh -c 'ls ... | sed ... | sort -u'`;
- repository search finds `Audio.themeSounds` consumed only by `SoundPicker`, whose call sites are Settings surfaces.

**Niri native blur capability**
- Appearance unconditionally runs `niri --version` on Niri;
- default `performance.blurBackend="auto"`;
- `blurBackendFor()` explicitly returns wallpaper/off for `auto`, never compositor blur;
- `nativeBlurSupported` is otherwise a capability input for explicit compositor blur and Settings visibility.

These should be tested as four small demand gates rather than one large lifecycle rewrite.

### R6.4 — Media artwork work is atomic but not coalesced

Current `MediaArtworkResolver.qml`: `801d6422216b4b5f8e1ed31111b27010b963006e`.

The resolver is instantiated by at least six repository call sites, including the shared media artwork widget, Bar media, PlayerBase/PlayerControl, YT Music card and CavaTheme.

For one deterministic cache identity, every resolver instance owns its own:

- `/usr/bin/test -s` cache check;
- local `file` MIME check;
- local copy-to-cache pipeline;
- file-size stability checker with two `stat` calls and a 200 ms sleep;
- base64 decode writer;
- remote curl/MIME-validation pipeline;
- retry timer.

The cache file publication is atomic, so concurrent writers should converge safely, but duplicate operations still occur before one wins. A shared resolver should own the in-flight state while each visual consumer retains its own presentation generation/display-source state. This distinction avoids coupling UI transitions to another surface's lifecycle.

Required oracle should cover: remote success/failure/retry, simultaneous identical consumers, source switch during in-flight download, local file initially incomplete then stable, non-image local source, data URI, consumer destruction, and old-art retention.

### R6.5 — Clipboard decode has the same atomic-without-dedupe pattern

Current `CliphistImage.qml`: `d210fa7c52aba17fddec09909cc464fe034ffa03`.

The component correctly waits for visibility before decoding and uses a process-unique temporary file followed by atomic `mv`. Its own comment explicitly notes that multiple clipboard surfaces can render the same entry concurrently.

For an uncached entry, simultaneous Clipboard/Search/Waffle presentation can therefore launch more than one:

```text
bash
  -> cliphist decode ENTRY
  -> temporary file
  -> atomic mv to shared session cache
```

The optimization is not to make decoding earlier. Keep the current visibility gate, but centralize `entryNumber -> loading/ready/failed` ownership so one visible consumer triggers the decode and other visible consumers await the result.

### R6.6 — Theme/icon synchronization remains measurement-gated

Current source confirms the older startup concern still exists:

- shell invokes `ThemeService.applyCurrentTheme()` and `IconThemeService.ensureInitialized()` as soon as Config is ready;
- auto theme queues external `applycolor.sh` after 600 ms and default-enabled Vesktop generation;
- saved icon theme restoration starts `gsettings set` and then native desktop-icon synchronization;
- FontSyncService separately reconciles desktop fonts later.

This can create startup process waves, but moving them changes **when external applications** observe the persisted theme. Do not classify deferral as strict-lossless until a startup trace shows material contention and acceptance defines the external synchronization boundary. Shell-internal color/icon identity must remain available immediately.

### R6.7 — Bootstrap cleanup / identity lookup stay measure-first

`Directories.qml` at `0fb9ae0b8ce77bb5b280c3aef16c9b3d22d73f27` already made the important improvement: many independent cleanup/create processes became one ordered Bash invocation. Do not split it back into process fan-out.

`SystemInfo.qml` at `d62d67334070ac34070d113d6316d4d0152327e5` seeds `username` from `$USER` but still schedules `getent passwd USER` immediately for the GECOS display name. Both this lookup and transient feature-directory cleanup are lower priority unless a startup trace attributes measurable delay/I/O to them.

### R6.8 — Current ranking implication

This round changes the audit emphasis: before implementing more low-frequency QML micro-optimizations, obtain a startup trace around the pre-QML launcher and default-off probes. The environment-cache defect has a bounded **seconds-scale worst case**, whereas many later candidates save only a handful of short child processes. That makes it the highest-value CPU/startup candidate found after the rendering work.

