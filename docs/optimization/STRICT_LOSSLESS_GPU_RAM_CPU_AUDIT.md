# Strict-lossless GPU / RAM / CPU optimization audit

Audit baseline: `dev` at `1155e37093781a27e64a9caa100a52ac1ab60d15`.

Scope: find remaining optimization opportunities that are either strict-lossless or can be held to a measured visual deviation below 1%. This is research only. It does not authorize runtime changes by itself.

**Canonical status:** this is the sole active optimization research ledger. See [the optimization index](README.md). Superseded handoffs and dated implementation journals live under [`docs/archive/optimization/`](../archive/optimization/); do not append new research to them.

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


| `services/MprisController.qml` | **HIGH-CONFIDENCE session-growth cleanup — prune expired player-grace keys during existing lifecycle updates.** `_playerGrace` stores `dbusName -> timestamp`; behavioral grace expires after 2 s, but stale keys are never deleted. Every metadata-valid update clones the entire map with `Object.assign`, so many unique browser/mpv instance names slowly increase retained JS data and clone cost. When updating/rebuilding existing player state, retain only unexpired/current entries; do not add a polling timer. | Low. The only observable contract is the existing 2 s grace; pruning entries older than that cannot extend or shorten a valid grace window if the comparison uses the same timestamp boundary. | None. | Low but truly cumulative session RAM/JS-object reduction. | 0%. |
| `modules/abyss/looks/AbyssField.frag` + `AbyssField.qml` | **MEASURE/PROVE FIRST — guaranteed-transparent interior rejection before wave/SDF work.** Every presented full-screen Abyss field currently evaluates `waveProfile()`, water interaction and an SDF union with up to 40 rounded-rect records before the existing `d > 24` transparent exit. A conservative per-edge maximum inward-reach bound, expanded by connection smoothing, shadow/glow, current `crestPeak`, contact/ripple displacement and AA safety, could reject center fragments before wave texture reads and record SDF evaluation. | High until the geometric bound is formally conservative. Large utility/dialog surfaces can legitimately extend far into the workspace; derivative rules and corner joins must remain valid. | **Potentially high** on large outputs because rejected center pixels avoid wave texture sampling and dozens of SDF/fuse operations. | Negligible. | Exact 0% target for all accepted pixels; any false rejection is unacceptable. |
| `services/deferred/LatexRenderer.qml` | **MEASURE FIRST — intentional unbounded session cache, not a simple leak.** Every successful unique expression remains in `processedHashes`, `processedExpressions` and `renderedImagePaths`. The expression/path maps are actively consumed by `MessageTextBlock` to replace rendered LaTeX and replay duplicate completion, so they cannot simply be dropped after render. Consider count/byte-bounded LRU only if long AI sessions show meaningful JS/RSS growth; eviction trades RAM for MicroTeX re-render work. | Medium. Evicted expressions can incur re-render latency/process cost and must not break existing rendered messages. | None. | Potentially medium only in unusually LaTeX-heavy long sessions. | Pixels can remain 0%; latency/resource behavior changes. |
| `modules/background/widgets/CustomImageWidget.qml` | **MEASURE FIRST — paused video pipeline residency.** Transition-stale media slots are already cleared, and playback stops when hidden/power-suspended, but the active video slot keeps its `MediaPlayer` Loader active and source attached while merely paused. Benchmark PSS/GPU decoder residency versus resume latency before considering delayed unload/recreate on WidgetPowerManager suspension. | Medium–High for UX latency; unloading can change resume frame/timing even if eventual pixels are identical. | Low–Medium possible decoder/GPU residency reduction while suspended. | Medium possible multimedia-buffer reduction. | Not strict behavioral parity unless an exact preserved-frame/resume contract is proven. |
| `modules/settings/BarConfig.qml` | **MEASURE FIRST — section-level Settings residency.** Classic Bar page sections are all instantiated and switched with `visible`; host-level Settings residency is already bounded elsewhere. If page-open allocation profiling justifies it, use a short-residency/lazy section wrapper for inactive Appearance/Spectrum/Behavior/Modules content rather than redesigning the whole Settings host. | Medium. Section switch latency, focus/search navigation and config binding initialization are user-visible. | Low local potential. | Low–Medium while Bar Settings is open. | 0% visual result, but interaction latency must be accepted. |
| `services/PowerProfilePersistence.qml` | **MEASURE FIRST — ownership probe timing, not probe removal.** The shell keeps this service startup-resident; Config readiness immediately launches a shell that checks `systemctl is-active/is-enabled tlp-pd.service` before deciding whether persisted shell-owned power profile may be restored. The ownership check is correctness-critical. Measure moving only reconciliation after first frame; reject if delayed restore changes thermal/power/user-visible profile behavior. | High relative to expected saving. | None. | Negligible. | UI 0%, but power-profile timing is observable system behavior. |
| `scripts/capture-windows.sh` + `services/WindowPreviewService.qml` | **MEASURE FIRST — preview capture concurrency 2 vs 1.** Capture helper defaults to bounded two-way concurrency (override 1–4) and atomically publishes each result. Serial capture may reduce compositor/clipboard contention but increases total refresh time; current implementation already has timeout, stale-file, clipboard restoration and bounded warm-cache safeguards. Benchmark rather than assume. | Medium. First-preview/Overview freshness latency changes even if final images are identical. | Potentially lower transient compositor pressure. | Low transient. | Final pixels 0%; latency tradeoff. |


| `services/GameMode.qml` | **HIGH-CONFIDENCE correctness/startup-process candidate — make Niri animation reconciliation Config-ready-safe and separately owned from reactive GameMode state.** GameMode is effectively startup-resident through Appearance. Its 200 ms init schedules a 900 ms Niri reconciliation without checking `Config.ready`; before config loads, `controlNiriAnimations` falls back to `true`, so a slow boot can mutate/reload Niri even if the user's final config disables that behavior. Keep fullscreen/manual state resident, but arm animation reconciliation only once Config is authoritative; if Config is not ready when the timer would fire, queue exactly one reconciliation for the ready transition. | Low–Medium for the Config-ready fix; higher for any later no-op reload suppression. Must preserve crash-recovery reconciliation and manual/auto GameMode semantics. | None. | Negligible. | 0%. |
| `shell.qml` + `services/Weather.qml` + `services/ShellUpdates.qml` | **NO IMMEDIATE OPTIMIZATION — tier comments do not equal singleton materialization, but expensive work is already internally delayed.** Critical Bar bindings can instantiate Weather/ShellUpdates before shell's Tier 3/4 assignments. Weather nevertheless delays initial network work 3 s; ShellUpdates delays repo work 5 s and performs only update-resume state restoration at ~1 s. Treat future tiers as explicit expensive-work ownership, but do not add Loader indirection merely to delay singleton state. | Medium if timing is changed. | None. | Negligible. | 0%. |
| `services/MprisController.qml` | **MEASURE FIRST — direct-ALSA MPD compatibility probe remains eager.** Standard MPRIS state is needed early, and `pw-dump` is already event-gated, but `Component.onCompleted` still launches a Bash probe for `mpd-mpris` + `pgrep mpd` so an MPD session that bypasses PipeWire can become visible automatically. Moving only this probe after first frame could reduce startup fan-out, but can delay an already-playing MPD indicator. | Medium; direct-ALSA MPD discovery timing is user-visible. | None. | Negligible. | 0% pixels; presentation timing tradeoff. |
| `services/YtMusic.qml` | **NO ACTION — feature is already correctly self-gated despite early singleton references.** MprisController references YtMusic, but YtMusic's completion path calls `_initialize()` only when `sidebar.ytmusic.enable` is true; dependency probes, orphan-mpv cleanup, browser detection, data loads and OAuth checks remain dormant otherwise. | — | None. | None beyond resident declarative state. | 0%. |


| `services/Wallpapers.qml` | **HIGH-CONFIDENCE dead-cache removal — stop rebuilding the unused `wallpapers` list.** The service already exposes `folderModel` directly to every live selector/settings consumer. Repository-wide search finds no reader of `Wallpapers.wallpapers`; inside the service it is only cleared and repopulated in 64-item batches from `folderModel`. Remove `wallpapers`, `_wallpaperCacheIndex`, `_wallpaperCacheBuilder`, `_wallpaperCacheBatchesSincePublish`, `rebuildWallpapersCache()`, `appendWallpapersCacheBatch()`, the zero-delay cache timer and the `onCountChanged` rebuild hook. | Low. Preserve the public `folderModel`/directory/search/history contract; verify no external documented IPC/SDK surface promises `Wallpapers.wallpapers`. | None. | Low–Medium on large wallpaper folders by avoiding duplicate path strings, repeated array copies and batch timer churn. | 0%. |
| `services/AppSearch.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — revision-keyed memo for `lookupDesktopEntry(appId)`.** Taskbar, dock, media, icon, ScreenTime and desktop-item surfaces repeatedly resolve stable app IDs. Direct misses currently fall through aggressive normalization and token-overlap loops over `_desktopIdStemMap`/`_startupClassMap` every call. Cache both hits and misses by exact input for the current `_cacheRevision`; invalidate atomically whenever DesktopEntries rebuild. | Low. The memo must key on input plus current revision and never survive a DesktopEntries rebuild; malformed/empty inputs remain uncached or preserve current null semantics. | None. | Low–Medium JS allocation/CPU reduction on repeated unknown/Electron/AppImage IDs. | 0%. |
| `services/Wallpapers.qml` + `FolderListModelWithHistory.qml` | **MEASURE FIRST — lazy wallpaper catalog residency.** `Wallpapers` is startup-resident through theme/background state, and its `FolderListModelWithHistory` immediately points at `~/Pictures/Wallpapers` (or configured directory), even though ordinary desktop rendering only needs the configured current path. Random-wallpaper actions and selector/settings pages need the catalog. Measure directory metadata/RSS cost with 100/1k/10k entries before deciding whether catalog ownership should activate only on selector/settings/random/auto-wallpaper demand. | Medium. Random shortcut currently has immediate access to `folderModel.count`; lazy loading introduces first-use latency unless a separate on-demand picker is used. Directory history/search semantics must survive activation/deactivation. | None directly. | Potentially medium with very large libraries. | 0% final pixels; first-use latency is the acceptance risk. |
| `services/GlobalActions.qml` + `scripts/setup/_scan.sh` | **LOW-PRIORITY / MEASURE FIRST — setup recipe scan.** Tier 3 always runs one Bash scanner; today the shipped directory has only one non-private recipe, so the scanner starts Bash plus one AWK process and reads at most 60 lines of that script. It also enables reactive rescans on folder mutation. This is real process fan-out but currently too small to justify complicating IPC/search availability. | Low technically, but setup actions are part of the globalActions catalog/IPC after Tier 3. | None. | Negligible. | 0%. |
| `services/RecorderStatus.qml` | **MEASURE FIRST — global external-recorder discovery cadence.** The service already does the right thing for visible controls: keyed fast-demand leases and bounded quick checks. When idle with no UI demand it still runs a global status probe every 15 s (30 s in low-power mode) to discover externally launched recorders. Replacing or further delaying this changes discovery latency; only revisit if process-wakeup traces show measurable cost. | Medium because external recorder detection latency is observable. | None. | Negligible. | 0%. |
| `services/AwwwBackend.qml` | **NO IMMEDIATE OPTIMIZATION — capability probe is required by the default backend contract.** Static wallpapers default to awww when both optional client/daemon binaries are available; the service must discover availability before deciding whether the external renderer or internal fallback owns the visible wallpaper. One startup Bash capability probe is therefore legitimate until an equivalent in-process executable lookup is available without PATH semantic loss. | — | None. | Negligible. | 0%. |


| `services/WallpaperListener.qml` | **HIGH-CONFIDENCE reactive CPU/allocation candidate — narrow the global Config safety net to the one list it exists to protect.** `Config.configChanged` has no path and fires after every `setNestedValue(s)`. WallpaperListener already has direct bindings for multi-monitor enable/global path and a dedicated `onWallpapersByMonitorRefChanged`; the broad listener exists only as a fallback for nested/list propagation. On every unrelated setting edit it currently restarts an 80 ms timer, reconstructs the per-screen map and serializes both old/new maps before concluding nothing changed. Track a serialized `wallpapersByMonitor` safety key and schedule the fallback refresh only when that key changes; keep all direct triggers and screen hotplug behavior. | Low. The safety fingerprint must be updated on initial/direct refresh and must still catch list replacement/reload cases that fail to emit the QML property change. | None. | Low CPU/allocation reduction during settings-heavy sessions; scales with output count and config edit rate. | 0%. |
| `services/ThemeService.qml` | **HIGH-CONFIDENCE reactive wakeup candidate — drive live-theme debounce from `liveRegenSignature`, not every Config change.** The 260 ms handler ultimately returns immediately when `liveRegenSignature === _lastLiveRegenSignature`. That signature already includes every config/wallpaper input capable of changing the regeneration result. Replace the global `Config.onConfigChanged -> liveRegenerateDebounce.restart()` trigger with the signature's own change signal, retaining Config-ready priming and explicit theme/apply paths. | Low. Keep startup signature priming, `setTheme()`'s explicit delayed auto regeneration, family-change semantics and cooldown behavior unchanged. | None directly. | Low timer/JSON/config churn reduction while editing unrelated settings. | 0%. |
| `services/MprisController.qml` | **HIGH-CONFIDENCE reactive CPU candidate — rebuild player filtering only when its two config inputs change.** The global Config listener currently calls both `_updateMpvCache()` and debounced `_rebuildPlayerList()` after every setting edit. Config affects `isRealPlayer()` only through `media.filterDuplicatePlayers` and `sidebar.ytmusic.enable`; `_updateMpvCache()` depends on live MPRIS membership, not Config. Use a small derived filter signature/change handler for those two values and leave player/YtMusic lifecycle signals as the cache/rebuild owners. | Low. Verify filter-toggle and YtMusic enable/disable produce the same membership/order and empty-list grace behavior. | None. | Low CPU/allocation reduction; avoids repeated MPRIS scans during unrelated settings changes. | 0%. |
| `services/ThinkFanService.qml` | **HIGH-CONFIDENCE opt-in process/wakeup candidate — replace global Config profile-follow events with derived fan-intent changes.** When profile fan control is enabled, every unrelated Config change calls `_handleProfileFollowEvent()`; stale status can trigger a helper refresh, while fresh status schedules an apply check. The actual config intent is fully represented by `profileFanControlEnabled` and `configuredActiveFanLevel`, with PowerProfiles already owning profile changes. Trigger profile-follow only from those derived values plus PowerProfiles. | Low–Medium. Preserve enable/disable behavior, active-profile level edits, post-startup arming and stale-status refresh before privileged writes. Existing tests that assert a generic `onConfigChanged` must be rewritten around the narrower contract. | None. | Low normally; meaningful process/wakeup reduction only for users with profile fan control enabled. | 0%. |
| `services/TlpService.qml` | **HIGH-CONFIDENCE opt-in reactive candidate — reconcile charge policy from `enabled`/`effectiveRequestedLimit` changes instead of every Config write.** The current global listener calls `apply()` after every Config mutation. `apply()` has strong no-op guards, so unrelated writes usually do not spawn `pkexec`, but they still schedule reconciliation. The desired charge policy is represented by the two Config-derived properties; hardware/status changes already flow through detector/apply completion. | Low. Preserve Config-ready detection, supported/discrete normalization and disable-owned-policy cleanup. | None. | Low CPU/event-loop reduction; avoids unnecessary apply comparisons on unrelated setting edits. | 0%. |
| `modules/background/Background.qml` | **NO CURRENT CHANGE — revision invalidations are live, not dead.** Full-file verification shows `_zoneRevision` is consumed by `_computeZoneOccupants()`, and `_imageRouteRevision` is consumed by the dynamic image-converter `Connections.target`. Search snippets initially obscured those reads. Do not remove either counter without a replacement dependency contract. | — | None. | None. | 0%. |


| `modules/bar/Workspaces.qml` | **HIGH-CONFIDENCE multi-output CPU candidate — skip workspace config/occupancy refresh when the workspace config snapshot is unchanged.** Every Workspaces instance listens to global `Config.configChanged`; `syncWorkspaceConfig()` then calls `updateWorkspaceOccupied()`, whose debounced worker builds a Set from every Niri window and derives occupied state for each shown workspace. Unrelated settings changes therefore cause O(outputs × windows) work. Keep the broad reliability signal if desired, but compare a signature/snapshot of only `bar.workspaces` fields before assigning properties or scheduling occupancy work. | Low. Relevant workspace config changes must still refresh immediately; Niri/Hyprland workspace/window signals remain the authoritative occupancy triggers. | None. | Low–Medium CPU/allocation reduction during settings edits, larger with more outputs/windows. | 0%. |
| `services/Ai.qml` | **NO IMMEDIATE MODEL-REBUILD BUG — global Config listener already has a semantic signature guard.** `_syncExtraModels()` serializes AI policy/extraModels/provider membership and returns before destroying/recreating AiModels when unchanged. A narrower Config trigger could save signature allocations when Ai is resident, but model churn is already prevented. | — | None. | Low possible allocation cleanup only. | 0%. |
| `services/TimerService.qml` | **NO IMMEDIATE OPTIMIZATION — broad Pomodoro sync is intentionally cheap.** Every Config change copies four validated integers into service properties. No process, file I/O, model rebuild or list scan follows solely from that sync. Keep the simple reliable listener unless profiling identifies it. | — | None. | Negligible. | 0%. |
| `shell.qml` deferred-feature Config listener | **NO IMMEDIATE OPTIMIZATION — broad checks are idempotent feature admission, not repeated heavy work.** On Config changes shell re-evaluates ScreenTime/Weather/CavaTheme/CalendarSync/FontSync eligibility; assignments are one-way singleton materialization and expensive service work retains its own lifecycle. Narrow only if a runtime trace shows this bookkeeping itself matters. | — | None. | Negligible. | 0%. |

| `modules/common/widgets/CliphistImage.qml` + `Favicon.qml` + `modules/settings/QuickWallpaperItem.qml` + `NotificationAppIcon.qml` + taskbar preview images | **HIGH-CONFIDENCE CANDIDATE — replace simple non-inverted rounded-mask FBOs with scene-graph clipping.** These leaf/image paths still enable an `OpacityMask` whose mask is only a same-bounds rounded rectangle/circle. The repository already treats `Quickshell.Widgets.ClippingRectangle` as the preferred no-mask-FBO primitive for equivalent media/thumbnail clipping. Start only with masks that have no inversion, transformed mask, blur contribution outside the clip, or topology-dependent shape. | Low–Medium. Edge antialiasing, subpixel/fractional-scale coverage, animated radius and ready/error transitions need raster parity; do not bulk-convert complex masks. | Medium aggregate on list/grid/preview surfaces; structurally removes one offscreen mask/effect layer per visible converted instance. | Low–Medium transient/persistent texture reduction depending on delegate count and lifetime. | Target 0%; if edge raster differs, require <1% global normalized error plus explicit edge-band/max-channel checks before promotion. |
| `modules/sidebarLeft/SidebarLeftContent.qml` and other lifecycle-gated full-surface rounded clips | **SECOND-PHASE CANDIDATE — extend the same scene-graph clipping proof to large content surfaces.** The left Sidebar SwipeView currently keeps a same-bounds rounded `OpacityMask` only while the panel is visible. If the leaf oracle proves `ClippingRectangle` parity, test the full-sidebar case separately; one avoided full-panel FBO is structurally larger than an icon mask. Do not remove child masks merely because a parent also clips until every alternate host is proven. | Medium. SwipeView transitions, current/adjacent Loader ownership, animated radius, pointer clipping and alternate embedding paths are behavior contracts. | Medium–High local potential while such a panel is open; zero idle gain when its current lifecycle gate is closed. | Medium local texture potential from removing a panel-sized offscreen layer. | Target 0%; require open/close, swipe-transition, fractional-scale and rounded-edge raster/input parity. |

| `services/NiriService.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — reuse the already-sorted workspace projection on activation/urgency events.** `handleWorkspaceActivated()` and `handleWorkspaceUrgencyChanged()` rebuild `root.workspaces`, then call `Object.values(updatedWorkspaces).sort((a,b) => a.idx-b.idx)` even though those event types do not change workspace membership or `idx`. Build the same updated workspace objects/map, then project them through the existing `allWorkspaces` order; fold focused-index discovery into that pass. Keep full sort only for authoritative `WorkspacesChanged`/topology events. | Low–Medium. Must preserve stable equal-`idx` tie order, per-record object identity choices, malformed/missing workspace behavior, property-notify timing and current-output quirks. | None directly. | Low transient allocation reduction; persistent state unchanged. CPU gain scales with workspace-switch frequency and workspace count by removing an O(W log W) sort plus a temporary `Object.values` array on activation/urgency. | 0%. |

| `services/NiriService.qml` + AltSwitcher consumers | **ORACLE-REQUIRED CPU/allocation candidate — suppress provably no-op MRU republish on duplicate focus events.** `handleWindowFocusChanged()` always constructs and assigns a fresh `mruWindowIds` array for every non-null focus event. When the focused id is already first and has no duplicate later in the array, the value produced by the current filter+unshift algorithm is element-for-element identical, yet the fresh `var` assignment can notify `onMruWindowIdsChanged` consumers and trigger AltSwitcher snapshot rebuild work. Guard only this canonical no-op case; keep all window/workspace focus normalization and duplicate cleanup unchanged. | Medium until notification parity is proven. The value is identical, but current consumers can observe the change signal itself; repeated same-id focus events must not be an intentional refresh channel. | None. | Low transient allocation reduction plus avoided AltSwitcher rebuild allocation/CPU on duplicate focus events; persistent RAM unchanged. | 0%. |

| `services/CalendarSync.qml` + `modules/dashboard/DashAgenda.qml` + Waffle notification-center Calendar | **HIGH-CONFIDENCE CPU/allocation candidate — finish migration from per-day external-event scans to the existing batch bucket helper.** Current `CalendarSync._getEventBucketsForDates()` already preserves per-day inclusion semantics and is used by several 14/30-day consumers, but DashAgenda still calls `getEventsForDate()` once for each of 14 days and Waffle upcoming events does the same for 3 days. Build the identical ordered date list once, call the existing batch helper once, then keep all later filtering/cloning/sorting/caps unchanged. | Low. Must preserve RFC5545 exclusive-DTEND behavior, repeated appearance of multi-day all-day events in every matching day bucket, today/past filtering and output order. | None. | Low transient allocation reduction; persistent RAM unchanged. CPU gain removes repeated full external-event list scans/date parsing from these view rebuilds. | 0%. |
| `modules/sidebarRight/calendar/CalendarWidget.qml` + `modules/waffle/notificationCenter/CalendarWidget.qml` + `services/Events.qml` / `CalendarSync.qml` | **HIGH-CONFIDENCE local CPU candidate — build one bounded visible-date metadata snapshot instead of scanning both event lists twice per day cell.** Classic Sidebar materializes 42 cells; each count/color pair performs 2 local-list scans and 2 external-list scans. Waffle's shared CalendarView materializes 10 weeks × 7 days = 70 delegates, with the same query shape, so one full invalidation can drive up to 140 local and 140 external full-list scans before rendering dots/counts. Build exact local/external buckets once for the visible dates, then derive count/color metadata with O(1) cell lookup. | Low–Medium. Preserve local notified/all-day semantics, external multi-day inclusion, unique source-color encounter order, previous/current/next-month dates and the existing event/month invalidation boundary. | None. | Low bounded metadata RAM in exchange for large transient allocation/date-object reduction; persistent event storage unchanged. | 0%. |
| `scripts/scan-widgets.sh` | **HIGH-CONFIDENCE strict-lossless process candidate — remove three avoidable child processes per custom-widget manifest.** The scanner is already one bounded shell owner, but its loop executes external `dirname`, `basename` and `cat` for every `widget.json`. The glob shape makes directory/id extraction expressible with Bash parameter expansion, and Bash's `$(<file)` reads the manifest without spawning `cat`. Preserve the same unreadable-file `continue`, trailing-newline command-substitution behavior and JSON text. | Low. Oracle unusual paths, unreadable manifests and exact output bytes before changing the script. | None. | Low transient process-memory reduction. CPU/process gain is exactly up to 3 fewer child processes per discovered manifest while retaining the single scanner process. | 0%. |

| `services/LocalMusic.qml` | **HIGH-CONFIDENCE RAM-retention candidate — stop retaining dead `folderCollections` state in QML.** Current snapshot application stores `payload.tracks`, `payload.playlists` and `payload.folders`, but the live Songs browser derives folder navigation directly from `LocalMusic.libraryTracks`; current repository search finds no consumer of `LocalMusic.folderCollections`. Remove the property and assignment only, leaving native/Python snapshot shape unchanged. | Low. Re-run a dev-wide reference search and LocalMusic navigation/selection/playback oracle immediately before implementation. | None. | Medium potential for large libraries because the parsed `payload.folders` subtree duplicates track metadata by folder and can become collectible after snapshot application instead of being retained. Exact RSS needs measurement. | 0%. |
| `native/inir-mpdd/src/main.rs` + `scripts/local_music_mpd.py` | **COMPATIBILITY-GATED higher-value follow-up — stop constructing/serializing the duplicate `folders` snapshot field only if the stable MPD snapshot contract is intentionally revised or a lean mode is added.** Rust currently clones track objects into folder buckets; Python emits the equivalent second representation. The shell does not need it after the QML dead-retention cleanup, but current deep benchmark contracts explicitly include `folders` among stable snapshot fields. | Medium–High contract risk. Do not silently remove from only one backend or break native/Python parity/manual callers. | None. | Potentially medium transport/transient RAM reduction for large libraries; also removes folder grouping/cloning/serialization CPU. No credit until compatibility is resolved. | 0%. |

| `services/MinimizedWindows.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — replace workspace filter+sort selection with stable one-pass extrema/nearest selection.** `stashWorkspaceForOutput()` filters eligible workspaces, sorts descending by `idx`, then returns element 0. `restoreWorkspace()` filters one output, sorts ascending, then either finds exact `idx` or reduces to the nearest. Both sorts are unnecessary if the one-pass selector reproduces current stable-sort tie behavior explicitly. | Low. Tie behavior is the proof boundary: descending stash selection keeps the first source-order workspace among equal max `idx`; restore exact-`idx` keeps first source-order duplicate; nearest fallback must prefer lower `idx` on equal distance because the current ascending stable sort presents it first. | None. | Low transient allocation reduction plus O(W log W) -> O(W) CPU on minimize/restore fallback paths; persistent RAM unchanged. | 0%. |
| `services/MinimizedWindows.qml` + `modules/waffle/bar/tasks/TaskAppButton.qml` | **HIGH-CONFIDENCE micro-candidate — count minimized windows without allocating a filtered ID array.** `countMinimizedForApp()` currently calls `getMinimizedForApp(appId).length`, allocating a temporary array. Waffle binds this count once per task-app delegate. Use a direct counter loop with the exact same case-insensitive substring predicate; keep `getMinimizedForApp()` for callers that actually need IDs. | Very low. Preserve null/error behavior for malformed app records and exact substring semantics. | None. | Low transient allocation/CPU reduction proportional to visible task-app delegates × minimized-state invalidations. | 0%. |
| `services/TrayService.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — promote the archived one-pass tray partition into the canonical ledger.** The service independently filters `SystemTray.items.values` three times for Fcitx, pinned-user-list and unpinned-user-list outputs, repeating Fcitx normalization and linear pin membership tests. One ordered pass plus a membership Set can produce the same three arrays. | Low. Preserve source order, passive filtering asymmetry, raw-id equality, duplicate pin semantics and final invertPins composition. | None. | Low transient allocation/CPU reduction on tray source/status/pin invalidation; persistent RAM essentially unchanged. | 0%. |
| `modules/bar/SysTray.qml` | **HIGH-CONFIDENCE separate Material-tray candidate — collapse three local SystemTray scans into one private partition snapshot.** Material does not simply consume `TrayService` outputs: it uses `bar.tray` config and has a Spotify exception that keeps passive Spotify visible. It currently performs its own Fcitx filter plus pinned/unpinned filters over the same source list. Build one local partition preserving the Material-specific pin namespace and Spotify rule rather than incorrectly reusing the generic/Waffle result. | Low–Medium. The Spotify passive exception, Fcitx ownership, bar-specific pin list, invertPins and overflow-close behavior are hard contracts. | None. | Low transient allocation/CPU reduction on every Material tray invalidation; avoids repeated lowercase/classification work. | 0%. |

| `services/Network.qml` | **HIGH-CONFIDENCE process candidate — remove shell/head/awk wrappers from connected-network detail refresh while preserving current row-order semantics.** Network is already event-driven via `nmcli monitor` + 200 ms debounce, but active-link detail refresh still runs `sh -c "nmcli ... | head -1"` for connection name and `sh -c "nmcli ... | awk ..."` for Wi-Fi signal. Run the same two `nmcli` queries directly and move the trivial text selection into QML. | Low–Medium. Name must remain first active-connection line. Signal parser must reproduce the current awk+SplitParser semantics: every row beginning `*` is emitted in source order and the **last emitted active row wins** if more than one appears. Preserve failure/stale-clear behavior and do not alter the monitor cadence. | None. | Low transient process-memory reduction; up to **4 intermediary child processes removed per connected-Wi-Fi detail refresh** (two shells + `head` + `awk`) while the two required nmcli queries remain. | 0%. |

| `services/AppSearch.qml` + all `resolveWindowIdentity()` consumers | **HIGH-CONFIDENCE CPU/allocation candidate — invalidate compiled identity rules on the narrow config signal instead of serializing the entire rule list for every window lookup.** `_parseIdentityRules()` currently computes `JSON.stringify(Config.options.windows.appIdentityRules)` on every call, even cache hits. `resolveWindowIdentity()` is invoked inside Taskbar, Dock, Bar preview, both AltSwitchers and Waffle Task View collection passes. Keep the compiled rule array resident and rebuild on initial use/Config-ready plus `appIdentityRulesChanged`. | Low–Medium. Must preserve first-match ordering, malformed-rule skip behavior, nested JsonObject replacement/reload handling and lazy desktop-entry resolution. | None. | Low transient allocation + CPU reduction multiplied by window count × number of consumers; persistent RAM unchanged except the already-retained compiled rules. | 0%. |
| `modules/bar/BarTaskbar.qml` | **HIGH-CONFIDENCE CPU candidate — precompute first-occurrence pinned rank once per rebuild.** In separate-pinned mode the running-app sort comparator performs `pinnedApps.findIndex(...)` for both operands on every comparison, then publication performs another `pinnedApps.some(...)` per running group. Build one lowercase rank Map that preserves the **first** case-insensitive occurrence, use it for comparator rank and membership, and keep the current alphabetical fallback for unpinned apps. | Low. Duplicate/case-variant pins are the key oracle: naïve Map overwrite would retain the last rank and change order. | None. | Low CPU/allocation reduction; removes repeated O(P) scans from O(R log R) comparisons and final O(R·P) membership checks. | 0%. |
| `services/TaskbarApps.qml` | **STRICT-LOSSLESS companion cleanup — remove the dead `_identityRulesRevision` read/counter after AppSearch owns rule invalidation.** The revision is incremented on `appIdentityRulesChanged` and read into a local inside imperative `computeApps()`, but the value is never consumed; the same handler already restarts the refresh timer. | Very low. Keep the actual refresh restart and AppSearch invalidation intact. | None. | Negligible standalone; removes dead state/read and avoids presenting it as a required dependency token. | 0%. |

| `services/GameMode.qml` + fullscreen consumers | **HIGH-CONFIDENCE CPU candidate — derive fullscreen state once per Niri snapshot and answer per-output queries from a cached snapshot.** Current `hasAnyFullscreenWindow`, `hasVisibleFullscreenWindow` and `hasFullscreenOnOutput()` independently rescan `NiriService.windows`, and `hasFullscreenOnOutput()` is consumed by many simultaneously resident Bar/ScreenEdge/Background/Sidebar/Abyss/WidgetPowerManager paths. Build one derived `{any, visible, activeOutputs}` snapshot from the same windows/workspaces/output semantics and make reads O(1). | Low–Medium. Preserve the current distinction where “any fullscreen” may use the single-output fallback even when workspace metadata is temporarily missing, while visible/per-output queries require a resolved active workspace. | None. | Low transient allocation + potentially meaningful CPU reduction on window/workspace/layout publications: O(C·N) repeated scans -> one O(N) derivation + O(1) consumer reads. | 0%. |
| `services/DesktopItems.qml` + `modules/background/Background.qml` | **HIGH-CONFIDENCE RAM/allocation candidate — publish one read-only cloned item-list snapshot per items revision instead of cloning the complete item set once per output.** `DesktopItems.listItems()` clones every item into a fresh array; Background calls it from each output's desktop-item model and then filters by output. With M outputs and I items, one revision can allocate roughly M·I cloned records before filtering. Maintain a shared presentation snapshot rebuilt only when `items` changes and let Background perform only the per-output filter. | Low–Medium. Must preserve item order, invalid-record hiding, stale-output/focused-output fallback and the defensive-copy contract for callers that still require mutable results. | None. | Low–Medium transient RAM/allocation reduction on multi-output desktops; persistent RAM adds one bounded shared read snapshot but removes repeated per-output clones. | 0%. |

| `services/NiriService.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — maintain a private layout-sorted window view and stop re-running `sortWindowsByLayout(windows)` inside every `sortToplevels()` call.** Public `windows` is already layout-sorted on normal window publication and output-geometry changes, but workspace topology changes can alter sort keys without reassigning `windows`; that is why a naïve direct iteration is not strict-lossless. Refresh a private sorted view on every actual sort-key source change and keep public signal counts unchanged. | Low–Medium. Must preserve `windowsChanged` / `windowOrderChanged` counts, workspace idx/output topology effects and output geometry order. | None. | Low transient allocation + CPU reduction: removes one repeated map→sort→map preparation per compositor toplevel sort pass. | 0%. |
| `modules/common/widgets/SettingsSearchRegistry.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — pre-normalize immutable search fields at registration.** `registerOption()` already snapshots label/description/page/section/keywords, but every keystroke lowercases/join-normalizes all of them again for every live entry. Store private normalized fields beside the existing raw fields once per registration and keep scoring/order unchanged. | Low. Registry lifecycle/re-registration and translated text-at-registration semantics must remain identical. | None. | Low transient allocation + CPU reduction proportional to registry size × keystrokes. | 0%. |
| `modules/common/widgets/SettingsSearchRegistry.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — generate highlight markup only after score/sort/top-50 selection.** Current search creates highlighted label/description strings for every match before sorting, then discards everything after the first 50. Highlight markup does not influence score or ordering, so retain raw text + matched terms through ranking and call the same highlighter only for the selected top 50. | Low. Preserve exact matched-term order, overlap markup, scores, tie order and every returned field. | None. | Low–Medium transient string/allocation reduction for broad queries with >50 matches. | 0%. |
| `modules/settings/ThemesConfig.qml` | **HIGH-CONFIDENCE process candidate — collapse saved-theme polling fan-out to one Bash + one jq per poll.** While the custom-theme editor is expanded, the 2 s poll starts one Bash and then one external `basename` plus one `jq` per saved JSON file. Derive basename with shell parameter expansion and invoke one jq over the ordered file list while preserving one compact output object per input file. | Low–Medium. Preserve glob order, invalid-file warning/skip behavior, filenames with spaces/dots and same model reset/publication timing. | None. | Low transient RAM/CPU process reduction. Per poll, process count changes from roughly `1 + 2T` to `2` for T saved themes. | 0%. |

| `services/WorldClock.qml` | **HIGH-CONFIDENCE lifecycle/RAM candidate — lazy-materialize the full timezone picker catalog only when a picker needs it.** Runtime clock rendering needs only configured timezones/offsets/entries, but WorldClock eagerly builds the complete IANA timezone list plus a second `{label,tz,icon}` combo model whenever the singleton materializes. Current consumers of the full catalog are picker/editor surfaces only. | Low–Medium. Picker must still have the complete model on its first visible frame; preserve Intl fallback, labels and selected-timezone behavior. | None. | Low–Medium persistent/transient RAM reduction for sessions that display World Clock without opening timezone editors; avoids full catalog label construction. | 0%. |
| `modules/sidebarLeft/LocalMusicView.qml` | **HIGH-CONFIDENCE CPU candidate — prepare exact lowercase search haystacks once per active search session.** Current `filteredTracks` lowercases title/artist/album/folder and concatenates a haystack for every track on every query edit. Build `[{track, searchText}]` lazily when query becomes non-empty, reuse while `libraryTracks` identity is unchanged, invalidate on library change and release when query clears. | Low. Preserve exact String/null fallback, spacing, substring semantics, result identity/order and immediate updates on library rescans. | None. | Low bounded transient RAM while search is active in exchange for materially lower per-keystroke CPU/string allocation on large libraries. | 0%. |
| `services/NiriService.qml` + classic/Waffle Background | **HIGH-CONFIDENCE CPU candidate — centralize active-workspace occupancy instead of recomputing it per output/family.** Classic and Waffle backgrounds independently materialize `Object.values(workspaces)`, find the active workspace for an output, then scan all Niri windows for occupancy. Derive `activeWorkspaceIdByOutput` and `occupiedWorkspaceIds` once from authoritative Niri snapshots and expose a reactive O(1) helper/map. | Low–Medium. Preserve non-Niri/unknown-output/no-active-workspace false behavior and exact invalidation on window/workspace topology changes. | None. | Low transient allocation + CPU reduction: repeated O(M·(W+N)) background scans become shared O(W+N) derivation plus O(1) per-output reads. | 0%. |
| `modules/background/Background.qml` | **HIGH-CONFIDENCE Hyprland CPU/allocation candidate — replace `relevantWindows.filter(...).sort(...)` plus later `some()` with one summary pass.** The sorted array is only used for min workspace id, max workspace id and current-workspace occupancy. Derive `{first,last,hasCurrent}` directly in one scan while preserving the existing falsy-id fallback semantics. | Low. Workspace id 0 is currently permitted by the filter but then treated as falsy by `|| 1/10`; preserve that quirk rather than “fixing” it here. | None. | Low transient allocation + CPU reduction: remove one filtered array, O(N log N) sort and later O(N) occupancy scan per relevant update/output. | 0%. |
| `modules/background/Background.qml` + `modules/screenCorners/ScreenCorners.qml` | **HIGH-CONFIDENCE secondary Hyprland candidate — replace nested fullscreen `filter().filter()[0]` allocations with one `find/some` pass.** Both paths only ask whether this monitor's active workspace contains a fullscreen Wayland window. | Low. Preserve loose monitor-name equality, active-workspace requirement, Wayland-only fullscreen detection and false/undefined behavior when data is absent. | None. | Low transient allocation/CPU reduction on Hyprland workspace/toplevel updates. | 0%. |

| `services/AppSearch.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — memoize final `lookupDesktopEntry(appId)` hit/miss per DesktopEntries epoch.** The helper already has reverse maps, but every call restarts heuristic lookup, normalization candidates, suffix stripping and potentially token-overlap scans. Many Taskbar/Dock/AltSwitcher/settings/media paths ask for the same ids repeatedly. Cache exact-input `DesktopEntry|null`, distinguish cached miss, and invalidate immediately on DesktopEntries change. | Low–Medium. Immediate invalidation must occur before the existing 500 ms reverse-map rebuild so a newly installed/removed desktop entry is observable with today's timing. | None. | Low transient allocation + potentially meaningful CPU reduction for repeated misses/unusual Electron/AppImage ids. Small bounded memo RAM. | 0%. |
| `services/MprisController.qml` | **HIGH-CONFIDENCE CPU/allocation candidate — memoize the final MPRIS-specific `_desktopEntryForHint()` result after AppSearch fallback.** Direct AppSearch misses currently fall into a full DesktopEntries fuzzy scan/tokenization path, and the same cleaned hint can be resolved repeatedly by player/stream display-name/icon helpers. Cache final `DesktopEntry|null` by exact cleaned hint and invalidate immediately on DesktopEntries changes. | Low–Medium. Preserve every score/tie/threshold rule and direct-AppSearch precedence. | None. | Low transient allocation + CPU reduction, especially for repeated hints that miss AppSearch and enter the catalog-wide fallback. | 0%. |
| `services/Notifications.qml` + `modules/dock/DockAppButton.qml` | **HIGH-CONFIDENCE CPU candidate — derive normalized notification-badge lookup once per popup-group rebuild.** Each Dock button currently normalizes caller ids, then scans all popup groups and normalizes every group app name. Build a private normalized key→{first-rank,count} index alongside `_cachedPopupGroupsByAppName`, preserving the current “first group in object order matching any caller id wins” semantics. | Low. Do not sum collisions or let caller-identifier order replace current popup-group order. | None. | Low CPU/allocation reduction scaling from roughly D×G normalized group scans to small per-button key lookups after each group snapshot rebuild. | 0%. |

| `services/Notifications.qml` | **HIGH-CONFIDENCE CPU candidate — reuse notification objects already owned by timeout/read callers instead of re-looking them up by ID.** `timeoutNotification()` does one `findIndex` then calls `cancelTimeout(id)`, which scans again; `timeoutAll()` already iterates `popupList` objects but calls the ID helper for each; `markReadForApp()` already has each matching object but triggers another list scan. Add a private object-based timer cancel helper and keep the public ID helper for external callers. | Very low. Preserve timer stop/destroy/null, timeout signal count/order, popup mutation phase ordering and final `triggerListChange()`. | None. | Low transient allocation/CPU reduction; removes P×N lookup work from timeout-all/read-heavy histories. | 0%. |
| `services/Weather.qml` | **HIGH-CONFIDENCE process candidate — execute primary wttr.in curl directly instead of through Bash.** The primary request constructs one URL and runs `bash -c "curl ..."`; no shell feature is required, while fallback/AQI paths already use direct curl argv. | Very low. Preserve URL construction, query encoding, request-generation ownership, retry/failover counters and empty/error parsing. | None. | Low transient RAM/CPU; exactly one fewer Bash process per primary weather request/retry. | 0%. |
| `services/ScreenTime.qml` | **HIGH-CONFIDENCE startup process candidate — use the already-owned `todayFileView` for the startup day read instead of `bash -c 'test -f && cat || echo'`.** The service already persists today's file through FileView. Route startup `Loaded` / `FileNotFound` into the existing `_finishStartupRead()` contract while retaining all other failure behavior. | Low–Medium. FileView error/timing parity, reentrancy and startup-before-first-write assumptions must be covered. Do not replace the batched history range reader. | None. | Low transient process-memory/CPU; removes one Bash plus cat/test pipeline on ScreenTime initialization. | 0%. |
| `modules/regionSelector/RegionSelection.qml` | **HIGH-CONFIDENCE process/quoting candidate — remove avoidable outer `bash -c` layers for recording and content-region detection.** Recorder start can exec `record.sh --region <region> [--sound]` directly; content-region detection can invoke `bash find-regions-venv.sh --image ...` as interpreter+script argv, retaining one required Bash for the wrapper but removing the extra command-string parser. | Low. Preserve exact region/image argv, wrapper startup failure, RecorderStatus quick-check timing and current detached-process behavior. Do not touch screenshot/copy/OCR/search/edit branches that use real shell composition. | None. | Low transient process/CPU reduction on explicit region actions; removes one shell from recorder start and one extra `-c` shell layer from region detection. | 0%. |
| MPRIS position-refresh producers across Bar / media controls / Sidebar / Lock / Waffle / VolumeMixer | **MEASURE THEN ADAPT — share one demand-leased position ticker per player identity instead of independent surface timers.** Current source still has ten `positionChanged()` occurrences: nine producer-style timers plus LyricsService listener. Producers request 500 ms, 1 s or configured ~3 s cadences and can target the same `MprisPlayer`. A per-player lease owner can run at the minimum requested interval while any consumer is active. | Medium–High timing risk. Raw `positionChanged()` signal phase/count is observable and `triggeredOnStart` semantics matter. Requires trace/oracle before promotion to strict-lossless. | None directly. | Potentially meaningful wakeup/CPU reduction when multiple media surfaces for the same player coexist; RAM negligible. | Expected pixels 0%; event timing changes unless explicitly normalized. |

| Cloudflare WARP quick toggles (common/Waffle + Classic + Android) | **HIGH-CONFIDENCE process candidate — execute `warp-cli status` directly instead of `/bin/sh -c`.** All three implementations use a fixed executable path and no shell syntax, yet every 5 s status refresh while the relevant surface is open forks an intermediate shell. | Very low. Preserve status parsing, availability/daemon/toggled state, panel-open gating and action-triggered refresh timing. | None. | Low transient RAM/CPU; one fewer shell process per status refresh per live toggle instance. | 0%. |
| `services/Hyprsunset.qml` | **HIGH-CONFIDENCE low-frequency process candidate — execute `hyprctl hyprsunset temperature` directly.** The probe uses Bash only for argv tokenization; timeout, stdout, state publication and pending-toggle control already live in QML. | Very low. Preserve PATH/spawn-failure, 5 s timeout, empty/error/6500 parsing and pending action state. | None. | Low transient RAM/CPU; one fewer Bash process per Hyprsunset state probe. | 0%. |
| `services/ResourceUsage.qml` | **HIGH-CONFIDENCE companion candidate — remove Bash from recurring NVIDIA/Intel process-backed GPU samples.** NVIDIA can run `nvidia-smi` directly and select the first non-empty row in QML; Intel can run `/usr/bin/timeout 1 intel_gpu_top -J -s 500` directly. Preserve stderr suppression, first-GPU ownership, timeout and existing parser semantics. | Low–Medium. Multi-GPU first-row behavior and malformed/timeout/error cases are the key oracle. | None. | Low transient process-memory/CPU; one shell removed per expensive GPU sample that remains after metric-demand gating. | 0%. |
| `modules/settings/InterfaceConfig.qml` | **HIGH-CONFIDENCE process candidate — collapse Settings World Clock preview from one Bash + N external `date` children to one Bash.** Current 20 s visible-section refresh invokes `date` once per configured timezone. Sibling WorldClock implementations already pass timezones as argv and use Bash builtin `printf '%(...)T'`. Preserve cadence, namespace and `timezone|time|offset` protocol. | Low–Medium. Valid IANA zones are straightforward; malformed shell-significant timezone strings require an explicit safe-argv contract decision rather than preserving accidental shell parsing. | None. | Low transient RAM/CPU; removes N external processes per preview refresh for N configured zones. | 0%. |
| `modules/sidebarLeft/widgets/WorldClockWidget.qml` | **HIGH-POTENTIAL / ORACLE-GATED — separate sparse timezone metadata refresh from in-process display ticking.** The visible sidebar clock currently starts one Bash every 30 s, or every second when seconds are enabled, to obtain time/offset/date/day-of-year/hour data. Reuse sparse offset metadata and advance display time locally; align minute-only updates to boundaries. | Medium–High temporal/locale risk until deterministic old-vs-new oracle exists. DST, quarter-hour zones, midnight/year rollover, clock jumps and locale formatting must match. | None. | Potentially meaningful process/wakeup reduction while the sidebar clock is visible; seconds mode can eliminate nearly one shell spawn per second. | Expected pixels 0%; time-format/event semantics must be proven. |

| Direct media-art `Image` / `StyledImage` paths in media presets, Waffle Action Center/Widgets/Lock and VolumeMixer | **HIGH-CONFIDENCE RAM/GPU candidate within the <1% visual budget — bound decode size to conservative presentation resolution instead of decoding arbitrary original cover dimensions.** Hadalis already uses a 2× presentation-size `sourceSize` policy in `MediaCrossSlideImage.qml`, but several direct cover-art paths still have no sourceSize and use `cache:false`. Start with small foreground slots (48/96/104/108 px) at a 2× or DPR-proven bound; separately tune card-sized blurred sources with enough oversampling to preserve blur/filtering. | Medium. This is not exact pixel-lossless by assumption: source downscaling can change filtering/blur slightly. Require <1% global/edge-detail error at 1.0/1.25/1.5/2.0 DPR plus visual sharpness review. | Low–Medium GPU/texture residency reduction when large covers are shown on several surfaces; may also reduce upload/decode pressure. | Potentially medium steady image RAM for large source artwork; illustrative 2000×2000 RGBA is ~16 MB versus ~0.18 MB for a 216×216 2× decode target, before backend-specific overhead. | <1% measured visual budget; reject or raise decode target if exceeded. |

| `services/Wallpapers.qml` | **HIGH-CONFIDENCE JS allocation candidate — mutate private thumbnail pending/known maps in place instead of cloning the complete map on every insert/delete.** Current `_singleThumbPending` and `_knownThumbnailOutputs` are private imperative sets; repository-wide search finds no binding, change handler or external consumer of their property identity. Enqueue/drain/remember/forget currently copy all keys with `Object.assign`. Preserve membership answers and queue order while mutating the private objects directly. | Very low. Final proof is that no `...Changed` signal is used as a wakeup and repeated/distinct key behavior is identical. | None. | Low–Medium transient JS allocation/GC reduction when browsing large wallpaper sets; avoids quadratic-ish cumulative key copying while filling/draining private sets. | 0%. |
| `scripts/thumbnails/thumbgen.py` + `services/Wallpapers.qml` + `ThumbnailImage.qml` | **HIGH-CONFIDENCE protocol candidate — publish per-file READY/FAILED from the batch generator so delegates can skip post-batch `test -f` child processes.** Generation is already centralized, but each `ThumbnailImage` may still spawn its own existence check. Extend machine progress so Python reports whether the expected output actually exists after each result; only READY enters the shared known-thumbnail set. | Low–Medium. Current `PROGRESS ... FILE` token is not a success signal; fresh-cache and failure can both return false. Preserve retry/fallback behavior and do not mark failed outputs known. | None. | Low transient process-memory/CPU; can remove one per-delegate `test -f` process after successful/fresh batch work across large galleries. | 0%. |
| `services/Wallpapers.qml` | **HIGH-CONFIDENCE tiny session-RAM cleanup — clear `_ffPending[videoPath]` after successful first-frame cache publication.** Success already stores `videoFirstFrames[videoPath]`, so the stale pending key no longer influences behavior because success cache wins first. Failure-side deletion is intentionally excluded because it would change current no-retry-for-session behavior. | Very low for success path. Do not alter failure semantics without a separate correctness/backoff decision. | None. | Low cumulative JS map reduction for sessions visiting many distinct video wallpapers. | 0%. |
| `services/Wallhaven.qml` | **HIGH-CONFIDENCE JS allocation candidate — mutate private bounded tag caches/order lists in place.** The 64/256-entry suggestion/count/tag caches currently clone the whole cache object and key-order array on every insertion/update/eviction. Repository search shows the structures are private and read imperatively. Preserve exact first-occurrence removal, append-newest ordering, TTL and eviction semantics. | Very low. Verify no property-change signal consumer and exact LRU order for same-key refresh/past-limit eviction. | None. | Low–Medium transient JS allocation/GC reduction during tag enrichment; avoids O(K) copies per insert and O(K²) cumulative filling work at K up to 256. | 0%. |
| `modules/background/Background.qml` | **HIGH-CONFIDENCE low-priority companion — mutate the private 64-entry wallpaper-size LRU in place.** `cacheWallpaperSize()` clones cache + key list for every successful `magick identify`; repository search finds no external/binding consumer of their identities. | Very low. Preserve lookup answers and exact LRU ordering/eviction. | None. | Low transient JS allocation reduction; smaller leverage than Wallhaven because writes are sparse and limit is 64. | 0%. |
| `services/CompositorService.qml` + `services/NiriService.qml` | **MEASURE / PROVE FIRST — focus-only enriched-toplevel refresh.** Niri `onActiveWindowChanged` currently schedules the same full `sortToplevels()` matching path as structural window-order changes. A pure focus change should only flip `activated` in the already matched ordered array, but Quickshell may also emit `ToplevelManager.valuesChanged` on focus transitions. Instrument trigger coalescing first; only add a focus-only fast path when no structural full sort is pending. | Medium due undocumented external signal behavior. Never let the fast path supersede a pending structural sort or membership/title/app/workspace change. | None. | Potential low–medium CPU/allocation reduction on frequent focus switching if active-window events commonly arrive without foreign-toplevel structural changes. | 0% visual; event/update timing must remain equivalent. |

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
18. **Wallpapers dead catalog-cache removal** — remove the unused duplicated path list/batch rebuild while preserving the public FolderListModel.
19. **GameMode Config-ready-safe Niri reconciliation** — preserve startup-resident GameMode state but prevent pre-config mutation/reload based on fallback defaults.
20. **AppSearch revision-keyed desktop-entry lookup memo** — avoid repeated O(n)-style fallback scans for stable unknown/Electron/AppImage IDs.
21. **Domain-specific Config invalidation narrowing** — WallpaperListener, ThemeService and MPRIS are the cleanest first cuts; ThinkFan/TLP follow with feature-specific regression updates.
22. **Workspace config snapshot guard** — prevent every unrelated Config write from scheduling per-output O(windows) occupancy reconstruction.
23. **MPRIS expired grace pruning** — low-risk cumulative session cleanup; fold pruning into existing lifecycle updates with no timer.
24. **TimerService consumer-gated stopwatch presentation refresh** — only after all consumers are enumerated.
25. **Niri workspace ordered-projection reuse** — remove redundant all-workspace re-sorts from activation/urgency events while preserving record identity and equal-index ordering.
26. **Niri MRU no-op publish suppression** — only after proving duplicate same-id focus events do not intentionally use `mruWindowIdsChanged` as a refresh signal.
27. **Calendar remaining-view batch migration** — reuse the existing `_getEventBucketsForDates()` helper for DashAgenda/Waffle upcoming paths with exact multi-day all-day parity.
28. **Calendar visible-date metadata snapshot** — collapse the 42/70-cell repeated local/external list scans only after count/color/invalidation parity is oracle-covered.
29. **Custom-widget scanner shell builtins** — remove per-manifest `dirname`/`basename`/`cat` child processes after byte/output oracle coverage.
30. **LocalMusic dead `folderCollections` retention** — remove the QML-retained duplicate after a final current-dev reference/behavior oracle.
31. **LocalMusic lean snapshot mode / schema revision** — only if stable `folders` compatibility is explicitly preserved or versioned.
32. **MinimizedWindows stable one-pass workspace selection** — remove two sort-based selectors after tie-breaking oracle coverage.
33. **TrayService one-pass partition** — migrate the revalidated archived tray classifier into current canonical work.
34. **Material SysTray one-pass partition** — independently preserve `bar.tray` + Spotify semantics; do not alias it blindly to the Waffle/generic service result.
35. **Minimized app-count allocation removal** — low-risk micro follow-up after the larger MinimizedWindows selector proof.
36. **Network direct-argv detail refresh** — remove shell/head/awk wrappers only after row-order and failure-state parser parity is covered.
37. **AppSearch identity-rule signal invalidation** — remove per-window JSON serialization after config-reload/replacement parity is proven.
38. **BarTaskbar first-occurrence pinned-rank Map** — eliminate comparator-time pinned-list scans while preserving duplicate/case ordering.
39. **TaskbarApps dead identity revision cleanup** — fold into #37; do not treat as an independent performance project.
40. **GameMode fullscreen derived snapshot** — collapse repeated per-consumer Niri fullscreen scans while preserving any/visible/output fallback distinctions.
41. **DesktopItems shared presentation snapshot** — stop cloning the entire item set once per output on every items revision.
42. **Niri private layout-sorted window view** — remove redundant sort preparation from `sortToplevels()` without changing public window notification behavior.
43. **Settings search normalized registration fields** — eliminate repeated lowercase/join normalization on every keystroke.
44. **Settings search post-top-50 highlighting** — avoid generating discarded highlight markup.
45. **Saved-theme catalog process batching** — reduce `1 + 2T` child processes per visible-editor poll to one Bash + one jq.
46. **WorldClock lazy timezone catalog** — avoid full IANA picker-model allocation unless an editor/picker is actually opened.
47. **LocalMusic active-search haystack cache** — trade bounded search-session RAM for lower per-keystroke normalization/allocation.
48. **Niri active-workspace occupancy snapshot** — share output occupancy across classic/Waffle Background instead of rescanning windows/workspaces per output.
49. **Hyprland Background one-pass workspace summary** — replace filter+sort+some with one scan while preserving id-0 fallback behavior.
50. **Hyprland active-fullscreen find/some** — secondary allocation cleanup for Background/ScreenCorners.
51. **AppSearch DesktopEntry hit/miss memo** — cache exact lookup results per DesktopEntries epoch with immediate invalidation.
52. **MPRIS desktop-entry hint memo** — cache the expensive post-AppSearch fuzzy resolver by cleaned hint.
53. **Notification badge normalized-group index** — move app-name normalization/group scanning to the popup-group rebuild boundary.
54. **Notification object-reference timer cancellation** — remove redundant ID scans inside callers that already own the notification object.
55. **Weather primary direct curl argv** — remove one Bash process from every wttr.in primary request/retry.
56. **ScreenTime startup FileView read** — retire the one-shot test/cat shell while keeping range-history batching unchanged.
57. **Region Selector direct argv cleanup** — remove avoidable outer shells only from recorder/content-region branches.
58. **MPRIS per-player demand-leased position ticker** — MEASURE/ADAPT only until signal timing/freshness contract is defined.
59. **WARP direct status argv** — remove one shell from every open-surface status refresh across all three implementations.
60. **Hyprsunset direct probe argv** — low-risk companion cleanup for explicit/deferred state probes.
61. **ResourceUsage direct GPU argv** — remove Bash from NVIDIA/Intel samples while retaining metric-demand gating as the larger owner.
62. **Settings World Clock one-Bash preview** — eliminate one external `date` process per configured timezone on every 20 s preview refresh.
63. **Sidebar World Clock split metadata/display cadence** — oracle-gated, higher leverage when seconds are enabled.
64. **Media artwork conservative decode bounds** — start with repeated small foreground slots, then card-sized blur sources under a <1% raster/resource oracle.
65. **Wallpaper private thumbnail-map in-place mutation** — remove whole-map copies from pending/known sets after notification-observer proof.
66. **Thumbnail batch READY/FAILED protocol** — let successful batch outputs seed the shared known set and eliminate delegate `test -f` fan-out.
67. **Video first-frame successful-pending cleanup** — delete stale success-side `_ffPending` keys only; leave failure retry policy unchanged.
68. **Wallhaven bounded-cache in-place mutation** — remove O(K) cache/order cloning for private 64/256-entry caches.
69. **Background wallpaper-size cache in-place mutation** — same safe class, lower leverage.
70. **Niri focus-only enriched refresh** — MEASURE/PROVE FIRST; instrument Niri + foreign-toplevel triggers before any fast path.

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

## Research continuation — round 7

Baseline: `dev` at `22b0a5fc4039c4f8baee3feb4f3ae781da035cd2`.

### R7.1 — MPRIS grace state has real stale-key growth

Current `services/MprisController.qml`: `3a8184f9308f0816ea395ea26f182bb5a3fbcf15`.

The grace contract is only:

```qml
const graceTime = _playerGrace[name]
return graceTime && (Date.now() - graceTime) < 2000
```

but each valid metadata update does:

```qml
let nextGrace = Object.assign({}, _playerGrace)
nextGrace[name] = Date.now()
_playerGrace = nextGrace
```

No source path deletes expired names. Long-running browser sessions, transient mpv instances and other players with unique D-Bus instance names therefore leave behaviorally dead entries behind. Those entries cost both retained JS memory and clone time on every later grace update.

Strict-lossless direction:

1. during an existing rebuild/grace update, construct the next map from entries whose timestamp is still inside the same 2 s window and/or whose current player is still relevant;
2. update the current player timestamp as today;
3. do not introduce a cleanup timer;
4. add a deterministic clock-based test that compares `_isInGracePeriod` before/after for boundary timestamps and proves stale keys disappear.

This is lower absolute value than startup/render candidates, but unlike speculative cache trimming it has no useful stale-data hit to preserve.

### R7.2 — LaTeX session cache is semantically active

Current sources:

- `services/deferred/LatexRenderer.qml`: `7447b36177da576b25aba5018560ccfaad519d00`;
- `modules/sidebarLeft/aiChat/MessageTextBlock.qml`: `e877c5c8e90a9a0ab06ead0c8bf687141d4721ba`.

A first static read suggested three unbounded structures might duplicate data. Cross-reference disproves a simple deletion:

- `processedHashes` deduplicates in-flight/completed requests;
- `renderedImagePaths[hash]` is read when applying the generated Markdown image;
- `processedExpressions[hash]` is read on `renderFinished` to replace the original expression and is also needed for duplicate completion handling.

Therefore these structures are an intentional session cache, not dead retention. The SVG output directory is reset on shell startup by `Directories`, so growth does not persist across sessions.

Only promote an LRU/count-byte bound after measuring a long LaTeX-heavy chat. The oracle must include already-rendered visible messages, revisiting an old expression after eviction, simultaneous duplicate requests and render failure/retry. The expected tradeoff is lower RAM versus additional MicroTeX process work.

### R7.3 — CustomImageWidget suspension keeps the current video pipeline

Current `CustomImageWidget.qml`: `cc9e05d2775713489a58146d38c4044adedd8267`.

The existing lifecycle is already careful:

- folder rotation stops when `!powerActive` or invisible;
- stale transition slot clears `sourcePath` after the transition;
- GIF playback is gated by visibility/power/animation policy;
- a MediaPlayer is only constructed for slots that actually own a video.

For the **current** video slot, however:

```qml
Loader {
    active: slot.isVideo && slot.sourcePath.length > 0
    sourceComponent: MediaPlayer { source: ... }
}
```

remains active during power suspension. `syncVideoPlayback()` pauses the player once a frame exists rather than clearing the source or destroying the loader.

This may intentionally preserve decoder state and instant resume. Before changing it, record PSS/RSS, render-node/decoder threads and resume-to-first-frame for:

- visible playing video;
- power-suspended for 5 s / 60 s;
- hidden desktop/widget;
- resume after each duration.

A delayed teardown (for example only after sustained suspension) is a RAM/latency policy candidate, not currently a strict-lossless optimization.

### R7.4 — Abyss full-screen fragment early rejection needs a proof, but potential is large

Current sources:

- `AbyssField.frag`: `98719594e2752d5938a02540d47aab0523ebd5d0`;
- `AbyssField.qml`: `e90297e341430c8745b53cc7ade05410092bb819`;
- `AbyssWaveController.qml`: `43f066c05d75d49adff40fdd45343515c69eec97`.

Current shader order:

```text
waveProfile(p)
  -> potentially up to 4 waveAt paths
waterInteraction(p)
field(p)
  -> workspace-hole SDF
  -> up to 40 record() roundedBox/fuse evaluations
dFdx/dFdy/fwidth
if d > 24 -> transparent
material/wallpaper/specular/shadow work
```

The Wave controller already computes `crestPeak`; however `AbyssField.qml` currently passes only wave texture width/active state/effects in `waveMaterial`, not crest height. Surface records carry exact rectangles but there is no precomputed per-edge maximum inward reach uniform.

A safe experiment can compute on the CPU/QML side, whenever records/insets/wave/contact state change:

```text
topReach, rightReach, bottomReach, leftReach
    = maximum inward extent of all active edge-attached records
    + connection/smooth-union radius
    + maximum active wave crest
    + bounded water-contact/ripple displacement
    + 24 px existing shadow/glow exit band
    + AA/refraction safety
```

Then a fragment whose distance from **every** physical edge exceeds the matching conservative reach is guaranteed to remain transparent and may exit before wave sampling/SDF union. This must be proven against corner joins, center/large utility surfaces, editor previews, max-size popups and water interactions. If any content class is not edge-bounded, disable the fast reject for that frame instead of guessing.

Because the ShaderEffect covers the full output, a correct reject could save work over a large fraction of 1440p/4K pixels. No resource percentage is claimed until GPU/frame-time measurement.

### R7.5 — Classic Bar Settings is a local residency opportunity only

Current `BarConfig.qml`: `13857cee12d5d1616476cc0e86fce7b714160df9`.

The page uses an `activeSection` selector, but the large `SettingsCardSection` trees are instantiated normally and only hidden with `visible`. This is distinct from `SettingsPageHost`, which is already bounded and should not be redesigned.

Measure QML object count/RSS/page-open time first. If material, a section loader should:

- instantiate the selected section synchronously enough that search/task navigation remains responsive;
- optionally keep the previous section for a short bounded residency window;
- preserve every config binding and `SettingsTaskNavigator` target;
- unload all section content when the host unloads the page.

This is lower priority because cost exists only while that Settings page is resident.

### R7.6 — PowerProfilePersistence cannot simply be delayed under strict-lossless rules

Current `PowerProfilePersistence.qml`: `b014a90512ad93e94a4e43ffb38aa121f64c309d`.

It probes TLP-PD ownership immediately at Config readiness, because applying a persisted profile before knowing ownership could fight `tlp-pd`. Conversely, deferring the entire probe delays shell-owned profile restoration when `tlp-pd` is absent.

Therefore the process is not equivalent to the default-off ThinkFan/TLP-charge probes from round 6. Moving it after first frame is a timing/power-policy change. Keep this as measurement-only unless the ownership answer can be obtained through a cheaper equivalent event/state source without changing restore timing.

### R7.7 — Window preview concurrency remains an A/B benchmark, not a static conclusion

Current capture helper `1375bd607bb522dca1218ddc581e638829ed25e5` defaults:

```bash
max_concurrent="${INIR_WINDOW_PREVIEW_CAPTURE_CONCURRENCY:-2}"
[[ ! "$max_concurrent" =~ ^[1-4]$ ]] && max_concurrent=2
```

The lifecycle regression explicitly requires bounded two-way default concurrency. Serializing to one capture may smooth compositor/clipboard pressure, but necessarily lengthens a multi-window refresh if individual captures are independent.

Benchmark concurrency 1 and 2 with identical window sets and collect:

- total batch time;
- first-preview publication latency;
- compositor/GPU spikes;
- clipboard restoration duration;
- failed/closed-window behavior.

Do not change the default on static reasoning alone.

## Research continuation — round 8

Baseline: `dev` at `01a898d046e4e33c99f4e1d1e1268d4d27cf9e62`.

### R8.1 — Service residency and expensive-work residency are separate contracts

Current `shell.qml` still documents Tier 3/Tier 4 service assignment, but QML dependencies can materialize a singleton earlier:

- `Appearance` references GameMode, so GameMode cannot be considered truly delayed until the Tier 3 assignment.
- Classic/Abyss bar components can reference `Weather` and `ShellUpdates` before shell assigns `_weatherService`/`_shellUpdatesService`.
- this is not itself a bug: reactive state may legitimately be needed before the expensive background task.

The useful contract is therefore:

```text
singleton may exist early
heavy maintenance/network/process work has a separate idempotent owner/arm point
```

Do not wrap ubiquitous state singletons in fragile Loaders only to satisfy tier comments. Instead, when a service still has expensive eager work, expose an explicit `startDeferredWork()`/lease only for that work and make shell tiering own the call.

### R8.2 — Weather is early-resident but its heavy work is already delayed

Current `Weather.qml`: `53ef5db3a161e6df18a29b1e6a7c6192d2e35a79`.

Shipped Bar weather is enabled, so Weather can be instantiated by first-frame Bar bindings before `_ensureDeferredFeatureServices()`. The service itself, however, does not immediately resolve IP/GPS/location or fetch weather. It owns a 3000 ms `startupDelayTimer` and only begins location/weather work when enabled, Config-ready and not already initialized.

This already keeps the network/process burst away from first-frame formation. Replacing it merely because the singleton appears before Tier 3 would add complexity without a demonstrated saving.

### R8.3 — ShellUpdates is early-resident, but separates resume-state and remote work

Current `ShellUpdates.qml`: `51e7eff2300e169ee0021673757dc9f4f79556d9`.

The update indicator can materialize this singleton before Tier 4. Current work naturally splits into:

- ~1 s: restore an in-progress update marker so a shell restart during `setup update` can recover the progress indicator;
- ~5 s: load/resolve repository and perform the normal shell-update check;
- configured periodic checks later.

The 1 s resume path is correctness/continuity work, not generic background maintenance. The remote/repo path is already delayed beyond first frame. No source-only reason currently justifies moving either path.

### R8.4 — GameMode has a real Config-readiness race

Current `GameMode.qml`: `692f3e200b7c46835f44f152c88f231e2d0bd2b5`.

Initialization starts a 200 ms init timer; on Niri that starts a further 900 ms `startupNiriSyncTimer`. The reconciliation has no `Config.ready` prerequisite. Meanwhile:

```qml
readonly property bool controlNiriAnimations:
    Config.options?.gameMode?.disableNiriAnimations ?? true
```

so a sufficiently slow Config load can execute Niri mutation under fallback `true`, even when the user's eventual value is false.

Safe direction:

1. keep state-file loading/fullscreen observation early;
2. add a one-shot startup Niri reconciliation request;
3. if Config is not ready, mark pending and do not mutate;
4. on Config ready, consume pending exactly once and evaluate final `controlNiriAnimations`;
5. if disabled, finish without a process;
6. if enabled, retain current reconciliation semantics.

### R8.5 — Do not skip Niri reload solely because file text already matches

Current `setNiriAnimations()` applies `sed -i` and then runs `niri msg action reload-config`.

A compositor can remain alive while the shell restarts. The file can already hold the desired value while Niri runtime state is stale because an earlier external edit was never reloaded or a reload failed. Therefore “file unchanged” does not prove “runtime reconciled.”

Only suppress reload if authoritative runtime animation state becomes queryable or another startup owner guarantees a reload from the same snapshot.

### R8.6 — MPRIS optional enrichment has one remaining eager probe

Current `MprisController.qml`: `3a8184f9308f0816ea395ea26f182bb5a3fbcf15`.

`pw-dump` is no longer unconditional, but completion still starts `_mpdMprisProbeProc`, which runs Bash to test `mpd-mpris` and `pgrep -x mpd`. This supports direct-ALSA MPD, where PipeWire cannot trigger discovery.

First-frame deferral is plausible but changes when an already-running MPD player becomes visible, so retain as A/B research rather than strict-lossless promotion.

### R8.7 — YtMusic dependency probes are already correctly gated

Current `YtMusic.qml`: `063ef1bd591d222d9a60b240dec218c1c4171213`.

Despite direct singleton references from MprisController, YtMusic only calls `_initialize()` when `sidebar.ytmusic.enable` is true. Its orphaned-mpv cleanup, dependency probes, browser detection, data load and OAuth/session restoration therefore remain dormant when the feature is disabled.

This is the desired state-vs-expensive-work pattern and should be preserved.

## Research continuation — round 9

Baseline: `dev` at `05f7e7f75416545f16ab67eca6ec017c5dc1bc43`.

### R9.1 — Wallpapers builds a dead duplicate catalog on every folder count change

Current `services/Wallpapers.qml`: `162dc98dcb742d7dec918a1da01659ef64265330`.

The service exposes the live `FolderListModelWithHistory` directly:

```qml
property alias directory: folderModel.folder
property alias folderModel: folderModel
readonly property bool folderModelReady: ...
```

and all repository consumers use `Wallpapers.folderModel`, `folderModelReady`, `effectiveDirectory`, `searchQuery` or direct helper methods.

Separately, the service owns:

```qml
property list<string> wallpapers: []
property int _wallpaperCacheIndex: 0
property var _wallpaperCacheBuilder: []
property int _wallpaperCacheBatchesSincePublish: 0
```

plus `rebuildWallpapersCache()`, `appendWallpapersCacheBatch()` and a zero-delay `wallpaperCacheTimer`. `folderModel.onCountChanged` always starts this batch copy.

Repository-wide search finds **no read of `Wallpapers.wallpapers`**. Inside the file, the property is only cleared and assigned from `builder.slice()`.

That makes this a strict-lossless source cleanup for current repo behavior:

1. remove the unused path-list property and its builder/index counters;
2. remove both rebuild functions and the zero-delay batch timer;
3. remove only the `onCountChanged: root.rebuildWallpapersCache()` side effect;
4. keep the actual `FolderListModelWithHistory` and all navigation/search/history behavior untouched.

For a directory with N items, this avoids copying every file path into a second JS/QML list and avoids repeated partial `slice()` publications every four 64-item batches.

### R9.2 — The wallpaper directory model itself is a separate, larger residency question

Current model implementation: `modules/common/models/FolderListModelWithHistory.qml` at `2aeb3e712dbf3f3ad9e7c0d67a1250b7373fa0ca`.

`Wallpapers.defaultFolder` resolves to `Directories.wallpapersPath`, which defaults to `~/Pictures/Wallpapers`. The `FolderListModelWithHistory` is constructed as soon as Wallpapers is resident and immediately points at that directory.

Yet startup-critical wallpaper rendering does not need the directory catalog. It needs current configured paths, per-monitor mapping and video-first-frame helpers. The catalog is consumed by:

- Wallpaper Selector/Coverflow;
- Quick/Background Settings wallpaper grids;
- random-from-current-folder actions;
- auto-wallpaper cycling.

This suggests a larger memory/I/O opportunity: separate “current wallpaper state/apply helpers” from “directory catalog ownership.”

Do **not** promote this from static reading alone. A lazy model changes the first random/selector interaction unless an on-demand catalog can be primed fast enough. Benchmark at least 100, 1,000 and 10,000 files and record:

- shell startup CPU/I/O;
- RSS before selector open;
- first selector-open latency;
- random shortcut latency;
- folder-history/search behavior after close/reopen.

If the directory model is material, prefer a demand lease such as `selector/settings/random/autoWallpaper` rather than keeping it permanently alive solely for `randomFromCurrentFolder()`.

### R9.3 — AppSearch has a safe memo boundary around expensive fallback identity matching

Current `services/AppSearch.qml`: `74ea3c9e92860af62f10850c89118d79b7837543`.

At startup `_rebuildCache()` builds three reverse maps:

- StartupWMClass -> DesktopEntry;
- executable basename -> DesktopEntry;
- desktop-id stem -> DesktopEntry.

The maps are required early because Taskbar/Dock/IconThemeService/MPRIS and other visible surfaces call `lookupDesktopEntry(appId)`.

For simple IDs, Quickshell heuristic lookup or direct map lookup is cheap. For an unknown/scoped/Electron/AppImage ID, the function can continue through:

- scoped/path segment normalization;
- suffix stripping;
- token extraction;
- `Object.entries(_desktopIdStemMap)` scan with per-key tokenization;
- `Object.entries(_startupClassMap)` scan with per-key tokenization.

The same stable app IDs are resolved repeatedly by taskbar buttons, previews, dock buttons, media-node icon matching and other bindings. There is currently no result memo.

Strict-lossless direction:

```text
lookupMemoRevision
lookupMemo: exact input string -> DesktopEntry | explicit MISS sentinel
```

At the start of `lookupDesktopEntry`:

1. empty input preserves current null result;
2. if memo revision equals `_cacheRevision` and the exact input is present, return cached hit/miss;
3. otherwise execute the current lookup byte-for-byte;
4. cache the final result;
5. when `_rebuildCache()` increments `_cacheRevision`, clear or logically invalidate the memo.

Caching misses is important: strange app IDs are precisely the path that pays the two fallback map scans.

Add a focused contract covering: normal heuristic hit, StartupWMClass hit, exec hit, scoped Electron normalization, token-overlap fallback, cached miss, and invalidation after a synthetic DesktopEntries revision.

### R9.4 — Do not lazy-build the whole AppSearch catalog yet

The full `_rebuildCache()` also sorts DesktopEntries and builds `_cachedList`/`_cachedNameLowers`. Only launcher/settings/all-apps surfaces need the alphabetical list, while taskbar identity needs the reverse maps.

Splitting those ownership domains could save startup sort/allocation work, but the current list also participates in reactive `list` semantics and several Settings pages. This is plausible but lower-confidence than lookup memoization.

Measure desktop-entry counts and `_rebuildCache()` duration before introducing a second lazy list lifecycle. The existing fuzzy prepared-name/icon indices are already lazy and should remain so.

### R9.5 — GlobalActions setup scan is real but currently tiny

Current sources:

- `services/GlobalActions.qml`: `30c88a1edf2c6f70a2f6471631585e9b8fc566bd`;
- `scripts/setup/_scan.sh`: `a8047db9398e1df52e91d94d6114f522bb3b8b23`.

Tier 3 unconditionally calls `refreshSetupActions()`, which starts one Bash process. The scanner then starts one AWK per non-private setup recipe and reads only the first 60 lines for `@meta` headers.

At this baseline, `scripts/setup/` contains only one public recipe (`spotify.sh`). Therefore this wave is currently one Bash + one AWK, not a large startup fan-out.

Keep reactive folder rescanning and immediate post-Tier-3 action availability unless a future recipe count grows enough for measurement to justify a different metadata format.

### R9.6 — RecorderStatus is already demand-tiered where it matters

Current `services/RecorderStatus.qml`: `7e221f7168f42c5348f4b07fe7ae8a0827c6a946`.

The service has already avoided the bad design of one-second global polling:

- visible recorder controls acquire keyed fast-status demand;
- start/stop actions use a bounded 350 ms quick-check loop;
- active recording uses a 1 s tick for elapsed time and stop detection;
- idle/no-demand mode polls every 15 s, or 30 s in low-power mode.

Only the last path remains unconditional once the service is resident, because it discovers externally launched `wf-recorder` instances.

Turning it off would change external-recorder detection semantics. Treat it as a runtime wakeup measurement target, not a source-only optimization.

### R9.7 — Awww startup capability detection is part of the default wallpaper renderer decision

Current `services/AwwwBackend.qml`: `fb5fc38ebe2735a1d97201990e555c40a2c82779`.

The backend is intentionally enabled by default and static wallpaper ownership depends on:

```qml
readonly property bool available: clientAvailable && daemonAvailable
readonly property bool active: enabled && available
```

The startup probe checks explicit standard paths and then PATH fallback for both `awww` and `awww-daemon`. When available, it triggers sync; when unavailable, Background/Waffle fall back to the internal renderer.

Thus this process cannot simply be demand-gated behind Settings or wallpaper selection: it determines the initial visible rendering engine. Only replace it if Quickshell/native code can perform an equivalent executable lookup without losing non-standard PATH support.

## Research continuation — round 10

Baseline: `dev` at `4c1932c0616ea8a4b91a188270c21d0072649228`.

### R10.1 — Config's global invalidation signal has no path information

Current `modules/common/Config.qml`: `3543ed88ddfa5408b1191b76e2c13499caaf67f7`.

Both mutation APIs end by bumping one global revision and emitting the same zero-argument signal:

```qml
function setNestedValue(nestedKey, value) {
    ...
    root._bumpRevision()
    root.configChanged()
}

function setNestedValues(updates) {
    ...
    if (paths.length > 0) {
        ...
        root._bumpRevision()
        root.configChanged()
    }
}
```

This is a valid compatibility mechanism for nested JsonAdapter values, but listeners must treat it as a broad invalidation, not evidence that their own domain changed.

The audit should prefer this pattern:

```text
Config.revision keeps derived values reactive
derived domain signature/property expresses actual intent
onDerivedValueChanged owns domain work
global configChanged remains only where no narrower reliable signal exists
```

No Config API redesign is required for the first optimization pass.

### R10.2 — WallpaperListener's safety net can preserve its purpose without rebuilding on every setting edit

Current `services/WallpaperListener.qml`: `ff0253becd4b3f5b2df24c65d003fb0236304e9a`.

The per-monitor map changes only from:

- `background.multiMonitor.enable`;
- `background.wallpapersByMonitor`;
- `background.wallpaperPath`;
- connected screen changes.

Those already have direct reactive handlers. The additional broad listener is explicitly documented as a safety net for `wallpapersByMonitor` list propagation.

Current unrelated-config path:

```text
Config.configChanged
 -> restart 80 ms timer
 -> create result object for every screen
 -> JSON.stringify(result)
 -> JSON.stringify(effectivePerMonitor)
 -> usually return unchanged
```

Strict-lossless narrowing:

1. keep a canonical `_wallpapersByMonitorSafetyKey` reflecting the last list snapshot incorporated by `refresh()`;
2. on global Config change, stringify only the current `background.wallpapersByMonitor` value;
3. restart the safety debounce only when that key differs;
4. keep direct `onWallpapersByMonitorRefChanged`, global path/mode handlers and `Quickshell.onScreensChanged` intact;
5. focused test: mutate unrelated setting -> no fallback refresh; replace monitor list -> refresh; simulate a missed list property notify but emit `configChanged` -> fallback still refreshes.

`globalAnimationEnabled` and `globalFillMode` are also currently declared in WallpaperListener but have no repository readers and are not used by `refresh()`. They are dead aliases at this baseline and can be removed separately after a QML import/smoke check; the saving is negligible.

### R10.3 — ThemeService already contains the exact signature needed to eliminate broad wakeups

Current `services/ThemeService.qml`: `b73e3ae8060d41fb15d39221ad78111668d8be7c`.

`liveRegenSignature` serializes the actual regeneration inputs: theme, panel family, Waffle wallpaper ownership, palette type, theming wallpaper, external-target toggles, terminal adjustments, soften-colors and auto dark/light behavior.

Yet every Config change currently does:

```qml
function onConfigChanged() {
    liveRegenerateDebounce.restart()
}
```

260 ms later `_tryLiveRegenerateFromConfig()` begins with:

```qml
if (!Config.ready) return
if (root.liveRegenSignature === root._lastLiveRegenSignature) return
```

Therefore unrelated Config mutations already have an explicit semantic no-op proof. Triggering the same debounce from `onLiveRegenSignatureChanged` removes only the redundant timer/wakeup path.

Preserve:

- Config-ready signature priming;
- `currentTheme` explicit apply behavior;
- `setAutoRegenTimer`;
- family-aware regeneration;
- `Wallpapers._applyInProgress` duplicate suppression;
- cooldown/coalescing.

### R10.4 — MPRIS filtering depends on two Config values, not the entire configuration

Current `services/MprisController.qml`: `3a8184f9308f0816ea395ea26f182bb5a3fbcf15`.

Global Config handler:

```qml
function onConfigChanged() {
    root._updateMpvCache()
    root._rebuildPlayerList()
}
```

Source-wide Config references inside this service show player-list membership depends on:

- `Config.options.media.filterDuplicatePlayers`;
- `Config.options.sidebar.ytmusic.enable`.

The other Config reference, `osd.mediaEnabled`, controls action OSD emission and does not require player-list rebuild.

`_updateMpvCache()` scans live `Mpris.players.values` only; it has no Config input.

A strict replacement is a derived filter signature, for example:

```text
filterDuplicatePlayers + "|" + ytmusicEnabled
```

whose change schedules `_rebuildPlayerList()`. Existing MPRIS player lifecycle and YtMusic connections continue to own mpv cache refreshes and metadata-driven rebuilds.

Oracle: same membership/order/trackedPlayer before and after toggling either relevant option, including the 1.8 s empty-list grace; unrelated Config writes must not invoke the rebuild path.

### R10.5 — ThinkFan's broad Config listener can become a real helper spawn when the opt-in feature is enabled

Current `services/ThinkFanService.qml`: `943082413a143df3e642ee3d60587093dda1ec02`.

The global handler sends every Config edit through `_handleProfileFollowEvent()`. When profile fan control is enabled:

- status newer than 30 s -> schedule configured active-level reconciliation;
- status older than 30 s -> immediately `refresh()`, starting `inir-thinkfan --status`.

The periodic status timer is intentionally sparse (5 min) when profile-follow is enabled but ThinkFan is not actively managed, so unrelated Settings edits can become the event that forces a stale-status process.

The actual desired fan intent is already exposed as reactive properties:

```qml
profileFanControlEnabled
activePowerProfileKey
configuredActiveFanLevel
```

PowerProfiles already has its own `onProfileChanged`.

Promotable direction:

- `onProfileFanControlEnabledChanged -> _handleProfileFollowEvent()`;
- `onConfiguredActiveFanLevelChanged -> _handleProfileFollowEvent()`;
- retain `PowerProfiles.onProfileChanged`;
- remove generic Config follow event.

Do not trigger inactive-profile level edits immediately; current runtime only needs the active profile level, and a later power-profile change re-evaluates it.

### R10.6 — TLP charge reconciliation has the same broad-listener smell but stronger no-op guards

Current `services/TlpService.qml`: `4e0ef4fba76eb00df7ddc54941e205029dde07ec`.

Every Config change schedules `root.apply()`. Unlike ThinkFan, `apply()` first checks the already-detected hardware/ownership state and usually returns without spawning anything. Therefore this is primarily event-loop/CPU churn, not a routine process-spawn bug.

Config intent is represented by:

- `enabled`;
- `requestedLimit` / normalized `effectiveRequestedLimit`.

Hardware capability/current ownership are detector-owned state.

Use derived-property changes to request `apply()`, while preserving:

- initial Config-ready detection;
- detector completion reconciliation;
- allowed/discrete limit normalization;
- disabling a policy still owned by Hadalis.

This optimization becomes more valuable after Round 6 demand-gates TlpService itself, because the service can then remain completely absent for default charge-care-off sessions.

### R10.7 — Background revision counters were rechecked and are not dead

Current `modules/background/Background.qml`: `29bd40236ba9579077d361fb1012d4f994ef4a3a`.

A repository search snippet initially exposed only the declaration/increment of `_zoneRevision`, which looked removable. Full-file verification found the reads:

- `_zoneRevision` is explicitly consumed inside `_computeZoneOccupants()`;
- `_imageRouteRevision` is explicitly consumed while resolving the dynamic image-converter `Connections.target`.

Both are deliberate dependency bridges around imperative helper functions. Do not remove them under the current strict-lossless audit.

A later optimization could narrow `_zoneRevision` to widget-layout-related changes, but that requires a domain signature or path-aware Config event and is lower confidence than the service-level cuts above.

## Research continuation — round 11

Baseline: `dev` at `2b66fce9e5b58b801757b581b7029f3f309fb043`.

### R11.1 — Workspaces turns an unrelated Config write into per-output window scanning

Current `modules/bar/Workspaces.qml`: `f7c51bb42b984ba8d3da078652a36ca75bd2db71`.

Every instance owns:

```qml
Connections {
    target: Config
    function onConfigChanged(): void {
        syncWorkspaceConfigTimer.restart()
    }
}
```

The zero-delay timer runs `syncWorkspaceConfig()`, which copies the `bar.workspaces` settings and unconditionally calls:

```qml
root.updateWorkspaceOccupied()
```

That starts a 50 ms debounce whose Niri path does:

```text
iterate NiriService.windows
 -> build Set(workspace_id)
 -> derive occupied state for every shown workspace
```

The shared Workspaces component is instantiated by Classic horizontal/vertical bars and Abyss bar modules, so the cost scales with the number of presented output bars.

Nothing about a change such as theme color, audio setting, notification preference or unrelated widget option changes workspace occupancy.

Strict-lossless direction:

1. compute a canonical snapshot from the fields copied by `syncWorkspaceConfig()`:
   `showAppIcons`, `alwaysShowNumbers`, `useNerdFont`, `monochromeIcons`, `numberMap`, `perMonitor`, `scrollBehavior`, `dynamicCount`, `shown`, `wrapAround`, `scrollSteps`, `invertScroll`;
2. if the snapshot equals the last applied snapshot, return before assignments and before `updateWorkspaceOccupied()`;
3. preserve Config-ready initial sync;
4. preserve Niri/Hyprland workspace/window/focus signals as the normal occupancy owners;
5. if `syncGlobalWorkspaceConfig=false`, do not use unrelated Config changes as an occupancy clock.

Focused regression should count `doUpdateWorkspaceOccupied()` calls across two synthetic outputs: unrelated Config change -> zero new occupancy work; relevant workspace setting -> one per instance after debounce; Niri window/workspace change -> unchanged behavior.

### R11.2 — AI model synchronization already protects the expensive part

Current `services/Ai.qml`: `91496b093b137b77bed6ffbd9bfffeba201684e3`.

Ai still receives every Config change, but `_syncExtraModels()` builds:

```text
policy | JSON(extraModels) | JSON(sorted live provider IDs)
```

and returns when that signature matches `_extraModelsSignature`.

The destructive part — destroying old extra `AiModel` objects, recreating them and rebuilding `modelList` — therefore does not happen for unrelated Config changes.

A later micro-optimization could move the call behind derived `policy/extraModels` changes and let `AiProviderCatalog.onCatalogUpdated` remain the provider owner. That would only save temporary arrays/Set/sort/JSON serialization while Ai is resident, so it ranks below Workspaces and Round 10 services.

### R11.3 — TimerService's broad Config sync is cheap enough to leave alone

Current `services/TimerService.qml`: `00f1733dc6f9b0ef822557dfb8524800af104ff2`.

The global listener calls `_syncPomodoroConfig()`, which validates and assigns four integer values:

- focus duration;
- break duration;
- long-break duration;
- cycles before long break.

It does not launch a process, persist state, rebuild a model or start a timer merely because those assignments occur.

Replacing this with more signal machinery would optimize a handful of arithmetic/property assignments and increase lifecycle complexity. Keep it as a deliberate non-candidate unless profiling contradicts the static assessment.

### R11.4 — Shell's broad deferred-feature check is admission control, not repeated service work

Current `shell.qml`: `aae76205a819e9b098f6a4be7fb6d56e14ff4900`.

On every Config change, shell calls:

```text
_ensureScreenTimeService()
_ensureDeferredFeatureServices()
_ensureLateFeatureServices()
```

Those functions check a small set of booleans/panel membership and assign singleton references only when a feature should exist. Once assigned, the same assignment does not recreate a singleton; the services retain their own work gating.

This broad check also allows an option enabled at runtime to materialize its service without requiring shell restart. It is therefore a good example where narrowing the listener is unnecessary unless actual traces attribute cost to it.



## Research continuation — round 12

Baseline: `dev` at `6230f4ba74a6218515f3f26743f9e830cfa19253`.

This round reconciled the newest canonical cross-repo handoff before promoting
anything. The Settings World Clock process fan-out and Clipboard decode
in-flight ownership are already documented there, so they are not counted as
new findings here.

Current source identities at this baseline:

- `modules/common/widgets/CliphistImage.qml`: `85f316c00c9dfebd6f792d779cb21c6a3e6ba6d2`;
- `modules/common/widgets/Favicon.qml`: `3d7e24e97236e53a174c977736d75e5ed850871d`;
- `modules/settings/QuickWallpaperItem.qml`: `6c9485c0344dc6e9c64c4ff45f24b689eb0bb3df`;
- `modules/common/widgets/NotificationAppIcon.qml`: `b7af10d8c4d9395ed3c4930d1ed86bf025590cbb`;
- `modules/bar/BarTaskbarWindowPreview.qml`: `6ef94fe54845b57f4562620226c519f94ebdee86`;
- `modules/waffle/bar/tasks/WindowPreview.qml`: `3dd610cf20f402ca0bc1f76a9162dd2e41c8573a`;
- `modules/sidebarLeft/SidebarLeftContent.qml`: `06c8e5aa355b97d14d606f7d152123d29a8b36ab`;
- `scripts/test-performance-lifecycle.sh`: `dcbbc9b28ce2258589df2daee5d1d7daa4c439c6`.

### R12.1 — Simple rounded-mask FBO sweep has an in-tree scene-graph precedent

Several current leaf/image components still use the same render shape:

```text
image/content item
  -> layer.enabled
  -> OpacityMask
       -> same-bounds Rectangle with only radius
```

Examples include Clipboard thumbnails, favicons, classic/Waffle taskbar window
previews, quick-wallpaper thumbnails and notification app images. Their masks
are not arbitrary alpha geometry; they are ordinary rounded rectangles or
circles.

Hadalis already has a stronger local precedent than a generic Qt performance
recommendation. `scripts/test-performance-lifecycle.sh` explicitly requires
`MediaCrossSlideImage` and InnerTune thumbnails to use
`Quickshell.Widgets.ClippingRectangle`, and rejects restoring an
`OpacityMask`/permanent rounded-mask FBO on those paths. That makes a bounded
conversion sweep worth testing rather than treating every remaining rounded
mask as unavoidable.

Strict-lossless first phase:

1. select only a non-inverted, same-bounds rounded rectangle/circle mask;
2. keep image source, decode size, cache policy, async behavior, visibility,
   opacity and lifecycle unchanged;
3. replace only the offscreen mask/effect ownership with the existing
   scene-graph clipping primitive;
4. preserve the exact effective radius, including any radius animation;
5. do not include masks that combine blur, transformed coordinates, inverse
   holes, unions, connected-surface topology, ripple-only clipping or any shape
   whose contribution extends outside the clip.

Structural claim only: each proven conversion can remove one mask/effect
layer/FBO for that visible instance. The aggregate value is larger in list/grid
surfaces such as quick-wallpaper and notification delegates than in a single
small avatar. This is not a whole-GPU or whole-RAM percentage.

Required raster/lifecycle oracle:

- transparent-edge and opaque images;
- radius 0, small rounded radius and full/circular radius;
- odd/even item sizes;
- integer and subpixel placement;
- DPR/fractional-scale cases representative of 1.0, 1.25, 1.5 and 2.0;
- ready -> error/fallback and source replacement;
- the animated-radius notification path;
- QuickWallpaper effects enabled/disabled;
- classic and Waffle taskbar preview arrival/removal;
- Clipboard blur overlay and hidden/reused delegate transitions;
- global normalized image error plus an edge-band/max-channel comparison so a
  tiny antialiasing regression cannot be hidden by a large transparent frame.

Target strict-lossless result is exact visible parity. If Qt's two clipping
paths rasterize edge antialiasing differently, the candidate must be reclassified
as a measured visual substitution and remain below the audit's <1% budget before
promotion.

### R12.2 — Full-surface rounded clipping is a larger second phase, not a bulk rewrite

`SidebarLeftContent.qml` already has the correct lifecycle discipline:
its SwipeView mask is enabled only while the panel is presented and Game Mode
has not disabled the effect. However, while open, the full content surface is
still rendered through a same-bounds rounded `OpacityMask` layer.

If R12.1 proves the primitive itself on leaf/image cases, the next experiment is
one full-surface host using the same `ClippingRectangle` strategy. This has a
larger local FBO footprint than an icon/thumbnail mask, but also a wider
behavioral boundary:

- current/next/previous SwipeView loaders must stay warm exactly as today;
- swipe animation and clipping must not change;
- pointer/touch routing must be identical;
- animated corner radius must match at intermediate frames;
- closing the panel must retain the current zero-residency behavior;
- child content may be embedded elsewhere, so no child mask is removed merely
  because this parent clips in one host.

Do not combine the full-surface experiment with child-mask deduplication. Prove
one render-primitive substitution first, then audit host reachability separately.

### R12.3 — Findings deliberately not promoted from this pass

- **Settings World Clock process fan-out:** already present in the newest
  `CROSS_REPO_OPTIMIZATION_HANDOFF.md`; it is not a new candidate for this
  audit. The canonical direction is the existing one-Bash/`printf %(...)T`
  approach rather than another independent proposal.
- **Clipboard decode dedupe:** still relevant on current source, but already
  owned by earlier cross-repo/audit research. The current component still
  acknowledges simultaneous surfaces and retains one process per component;
  do not double-count it as R12 work.
- **`AppLauncher._configRevision` removal:** rejected. The revision looks local
  in `AppLauncher.qml`, but current Settings/Niri configuration code consumes it
  as an explicit reactive dependency. It is not dead state.
- **Downscaling Clipboard decode via `sourceSize`:** not a strict-lossless
  cleanup under the current contract. Native Clipboard regression checks use the
  decoded image's intrinsic dimensions during preview sizing; changing decode
  dimensions would alter those observations unless the sizing contract is
  redesigned separately.
- **`modules/sidebarLeft/Wallhaven.qml` persistent mask:** source inspection
  found the old-looking ungated mask, but current Sidebar composition does not
  establish that file as a live owner. Do not claim a saving until reachability
  is proven rather than inferred from a filename.
- **Abyss/Wull automatic render-quality policy:** intentionally changes visual
  fidelity according to user/power policy. It is a product-controlled quality
  tradeoff, not a strict-lossless optimization and must not be credited here.

### R12.4 — Ranking implication

The leaf rounded-mask sweep is lower risk than replacing blur/shadow algorithms
because it reuses a clipping primitive already protected by Hadalis performance
regressions. It should nevertheless start with a focused raster oracle, not a
repository-wide mechanical replacement. If parity holds, prioritize repeated
list/grid instances first, then the full-sidebar surface; leave complex/inverted
masks under their existing specialized research owners.


## Research continuation — round 13

Baseline: `dev` at `e139c9c148766068ccb9ed5e448c7fd444fa6a2a`.

This round first reconciled the newest cross-repo handoff. Calendar bucketing,
LocalMusic payload/search work, WorldClock catalog lifecycle, Background
workspace occupancy, Hyprland collection passes, GameMode fullscreen snapshots,
DesktopItems snapshots and Niri toplevel app-id bucketing are already owned
there, so none is double-counted here.

Current source identity:

- `services/NiriService.qml`: `4c8194493fd380bf0ad8c51bc62990ad0c232738`.

### R13.1 — Workspace activation re-sorts an order whose sort key did not change

The authoritative full-workspace event correctly rebuilds and sorts:

```qml
root.workspaces = newWorkspaces
allWorkspaces = Object.values(newWorkspaces).sort((a, b) => a.idx - b.idx)
```

That is necessary when `WorkspacesChanged` can alter membership, output,
indices or topology.

The same sort is also executed by `handleWorkspaceActivated()`. That handler
changes only activation/focus flags on existing workspace records:

```text
is_active
is_focused
```

It does not add/remove workspaces and does not assign `idx`. Therefore the
previous `allWorkspaces` array is already in exactly the order required by the
same `a.idx - b.idx` comparator.

A strict-lossless replacement can keep the existing workspace-map construction
and existing per-record clone/reference choices, but derive the next ordered
array by walking the previous sorted projection:

```text
nextAll = []
for each old ordered workspace:
    next = updatedWorkspaces[old.id]
    append next
    track focused index from next.is_focused
```

This removes:

- one `Object.values(updatedWorkspaces)` array materialization;
- one stable O(W log W) sort;
- the later standalone O(W) `findIndex(w => w.is_focused)`, because focused
  index can be observed while publishing the ordered projection.

The existing `updateCurrentOutputWorkspaces()` filter can remain unchanged in
the first patch. Folding that filter into the same operation is possible, but it
would widen the proof surface for little additional value.

### R13.2 — Workspace urgency has the same redundant ordering rebuild

`handleWorkspaceUrgencyChanged()` replaces exactly one workspace record with a
copy whose `is_urgent` value changed, republishes `root.workspaces`, and then
again executes:

```qml
allWorkspaces = Object.values(updatedWorkspaces).sort((a, b) => a.idx - b.idx)
```

Urgency does not change membership or `idx`. The already-sorted projection can
therefore be remapped by id without sorting. This path has lower frequency than
workspace activation, but it is the same proof and should share one helper if
implemented.

### R13.3 — Identity/tie constraints make this narrower than “skip the sort”

The optimization must preserve more than values.

Current `handleWorkspaceActivated()` may clone workspace records even when a
particular record's final booleans equal their previous values. A proposed
optimization must initially keep those exact clone/reference decisions rather
than opportunistically retaining old records. QML consumers can observe object
identity indirectly, and strict-lossless research should not assume those
fresh objects are irrelevant.

Equal `idx` values also need an explicit oracle. JavaScript sort is stable on
the deployed runtime, so the old code preserves the pre-sort `Object.values`
tie order. Reusing the prior `allWorkspaces` order is equivalent only if:

- workspace membership is unchanged;
- ids still address the same records;
- `idx` is unchanged for every record;
- the previous projection was produced by the same canonical ordering.

Those conditions hold for the two targeted event handlers by current source,
but the helper must not be used for `WorkspacesChanged` or any future event
that can change `idx`/membership.

### R13.4 — Required oracle

Before promotion, compare old/new public state and notification behavior for:

- one workspace;
- many workspaces on one output;
- multiple outputs;
- focused and non-focused activation events;
- activation of the already-active workspace;
- equal/duplicate `idx` values and unusual id ordering;
- missing activation id (current early return);
- no focused workspace after update, including the current quirk where
  `focusedWorkspaceId` is cleared but `currentOutput` is not explicitly
  cleared in that branch;
- urgency true/false changes;
- untouched workspace object references versus records that current code
  clones;
- `allWorkspaces`, `focusedWorkspaceIndex`, `focusedWorkspaceId`,
  `currentOutput` and `currentOutputWorkspaces` value/order equality;
- signal/binding counts needed by Bar/Overview/Background/workspace consumers.

A useful structural benchmark should run repeated synthetic activation events
at workspace counts such as 10, 50 and 200 and report JS wall time/allocation
counts separately from whole-shell CPU. Real desktops normally have far fewer
workspaces, so this remains a targeted event-path reduction rather than a claim
of a large universal speedup.

### R13.5 — Adjacent ideas deliberately not promoted

- **Clone only records whose booleans actually changed:** values would usually
  match, but it changes workspace-object identity relative to current behavior.
  Keep that as a separate oracle-backed refinement, not part of the sort
  removal.
- **Mutate `root.workspaces` in place:** rejected for the first pass. The map is
  public reactive state; replacing it currently supplies a dependable property
  notification boundary.
- **Remove the full sort from `handleWorkspacesChanged()`:** rejected. That is
  the authoritative topology snapshot and can change membership/`idx`.
- **Optimize `MinimizedWindows` filter/sort selectors in the same round:**
  those paths are explicit minimize/restore actions and lower priority than the
  recurring workspace-activation event path.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 14

Baseline: `dev` at `33b9afaab5878defe6108fcf72587d9d8d5f9c5c`.

This round also consolidates all active optimization documentation under
`docs/optimization/`; superseded handoffs and completed/scoped journals move to
`docs/archive/optimization/`. Future optimization findings are written only to
this canonical audit.

Current source identities:

- `services/NiriService.qml`: `4c8194493fd380bf0ad8c51bc62990ad0c232738`;
- `modules/altSwitcher/AltSwitcher.qml`: `313928e4d55afca9ff188d9323f7de959f68f3ea`;
- `modules/altSwitcher/AltSwitcherNoVisual.qml`: `d362feb228a20227c726a85aac24382a505a71da`;
- `modules/waffle/altSwitcher/WaffleAltSwitcher.qml`: `00a169d62a31d4b3ae12aba6d6ab85f995b9fbd9`.

### R14.1 — MRU value can be republished even when its order is unchanged

Current `handleWindowFocusChanged()` rebuilds a fresh MRU array for every
non-null focus id. If that id is already at index 0 and does not occur later,
the produced array is element-for-element identical to the current value.

Qt QML `var` properties use reassignment as the change-notification boundary,
so assigning the fresh JS array can wake consumers even though the logical MRU
order did not change. The ii AltSwitcher explicitly listens to
`onMruWindowIdsChanged` in its closed/no-visual event-driven path and schedules
snapshot reconstruction; visual/Waffle switcher paths consume the same MRU
state when building their item order.

Strict-lossless direction:

1. keep the rest of `handleWindowFocusChanged()` unchanged;
2. prove the current MRU is already the exact output of the existing algorithm:
   index 0 equals the focused id and no later duplicate exists;
3. only in that exact case skip MRU array construction/reassignment;
4. if a later duplicate exists, retain the existing rebuild so duplicate cleanup
   stays identical;
5. do not skip window-focus normalization or workspace active-window
   reconciliation in the same patch.

A bounded guard can scan for a later duplicate. Worst-case inspection remains
O(N), but the no-op case avoids a new array, one public property publication and
any downstream rebuild caused solely by that publication.

### R14.2 — Notification parity is the blocker

Skipping a property publication changes signal count even if the value is
identical. The candidate is therefore not CONFIRMED until an oracle proves a
duplicate same-id `WindowFocusChanged` event carries no semantic refresh duty
that is delivered solely by the MRU signal.

Required oracle:

- first focus with empty MRU;
- A -> B -> A ordering;
- duplicate A -> A with canonical MRU;
- malformed MRU containing duplicate A later in the list;
- null/undefined focus id;
- clean and pending window batches;
- stale/missing workspace active-window metadata;
- ii visual AltSwitcher closed/open;
- ii no-visual mode and its event-driven snapshot refresh;
- Waffle AltSwitcher;
- Game Mode gating;
- exact MRU/item ordering and signal/rebuild counts.

Trace Niri as well: if duplicate same-id focus events are rare, retain this as a
correct micro-candidate but rank it below Round 13 and higher-leverage
render/process work.

### R14.3 — Close-event no-op is adjacent but separate

`handleWindowClosed()` similarly republishes a filtered MRU array even when the
closed id was never present. Do not bundle that path until R14.1 establishes the
notification contract; then extend the same oracle deliberately.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 15

Baseline: `dev` at `c51490a438e2534d1f980ce247f5b1786726c5a3`.

This round deliberately revalidated one useful historical finding from the
archived handoff before promoting it into the canonical ledger, then added a
new shell-process candidate. The archived note is not treated as active by
itself; current source identities were checked first.

Current source identities:

- `services/CalendarSync.qml`: `6e0b89c56eda5ee612be8438d9c20d4851a09617`;
- `services/Events.qml`: `dcc3671e7c6d640fdbe5d3ee8dce45bc412148e7`;
- `modules/dashboard/DashAgenda.qml`: `222f16088cf07d53c0ad606d1cc8a68d3abe717c`;
- `modules/sidebarRight/calendar/CalendarWidget.qml`: `4b5c53bc6392e7ce5f99df8e2643029969cdb98e`;
- `modules/waffle/notificationCenter/CalendarWidget.qml`: `820a50373bd475e583e8ce4cd9b66515a4acba01`;
- `modules/common/widgets/CalendarView.qml`: `767c8d6c9345f92925ad395b489be45262b62e72`;
- `modules/common/widgets/WeekRow.qml`: `e95df323efdbf6fbcc5f3e6e855e1450fa869507`;
- `scripts/scan-widgets.sh`: `d1176e3508335d0ad8d18fc884a4382fcd6a63a6`;
- `services/CustomWidgets.qml`: `fe4b1ef553fe7ed437b4e0de947615eee83752c9`.

### R15.1 — CalendarSync already has the exact batch primitive; two remaining views still bypass it

`CalendarSync.getEventsForDate(date)` performs a full `root.events.filter()`
and reparses event dates for every queried day. Current source already contains
`_getEventBucketsForDates(dates)`, which accepts an ordered date list and
constructs corresponding buckets while preserving the per-day multi-day/all-day
membership semantics.

Three current consumers have already moved to that helper:

- EventsWidget: 30 dates;
- CompactSidebarRightContent: 14 dates;
- CalendarUpcomingWidget: 30 dates.

Two remaining paths still perform repeated full external-list scans:

- DashAgenda loops over `lookaheadDays = 14` and calls
  `CalendarSync.getEventsForDate()` for every date;
- Waffle notification-center upcoming events repeats the same pattern for 3
  dates.

The strict-lossless migration is intentionally narrow: construct the same dates
in the same order, call `_getEventBucketsForDates()` once, then leave every
existing per-day clone, past-event filter, per-day sort, global merge and cap
unchanged.

Do **not** replace these loops with `getUpcomingEvents(days)`. Range semantics
are not identical: a multi-day all-day event is intentionally present in every
matching per-day bucket, whereas the range helper returns the event object once.

Required oracle:

- timed events;
- single-day all-day fallback with absent/degenerate DTEND;
- exclusive RFC5545 DTEND;
- multi-day all-day event repeated into every matching day;
- today with an already-past timed event;
- month/year boundary;
- empty list;
- exact object identity/order entering the existing downstream sort/cap.

### R15.2 — Visible calendar grids multiply the same list-wide work

The classic Sidebar month view computes exactly six weeks × seven days = 42
cells. For every cell it derives both count and dot colors:

```text
count
  -> Events.getEventsForDate()
  -> CalendarSync.getEventsForDate()

colors
  -> Events.getEventsForDate()
  -> CalendarSync.getSourceColorsForDate()
       -> CalendarSync.getEventsForDate()
```

Therefore a complete 42-cell invalidation can perform up to:

- **84 full local-event list scans**;
- **84 full external-event list scans**.

The Waffle notification-center Calendar is even broader. The shared
`CalendarView` uses `totalWeeks = 6 + paddingWeeks * 2` with default
`paddingWeeks = 2`, so it instantiates **10 WeekRow objects**. `WeekRow` builds
7 day delegates each, giving **70 day delegates**. Each delegate independently
binds both `eventCount` and `sourceColors` through the same pair of local and
external queries. A full event-trigger invalidation can therefore drive up to:

- **140 local full-list scans**;
- **140 external full-list scans**;
- **280 aggregate list scans** before count/dot rendering.

Those are structural upper counts for one full binding recomputation, not
measured CPU percentages.

Strict-lossless direction:

1. derive the exact ordered visible dates already owned by each calendar;
2. batch external events with the existing CalendarSync helper;
3. build equivalent local buckets from `Events.list` in one bounded pass, or
   add a narrowly specified local batch helper with exactly
   `Events.getEventsForDate()` semantics;
4. derive per-date metadata once: local count, external count, local-accent
   presence and ordered-unique external source colors;
5. bind cells/delegates to that private metadata snapshot;
6. invalidate on exactly the existing event triggers and month/week navigation.

The local path must preserve the current rule that notified timed events are
hidden but all-day events remain visible. External source-color order must remain
first-encounter order with duplicate source ids removed. Previous/current/next
month spill cells must use their actual resolved dates, not just day numbers.

Keep this snapshot widget-local first. A service-wide long-lived date cache would
introduce a larger invalidation/lifetime proof with no need for the initial gain.

### R15.3 — Custom-widget manifest scanning spawns avoidable per-entry helpers

`services/CustomWidgets.qml` owns one scanner process:

```text
scan-widgets.sh <widgets-dir>
```

That ownership is already bounded. The avoidable fan-out is inside the shell
loop in `scripts/scan-widgets.sh`:

```bash
wdir="$(dirname "$manifest")"
wid="$(basename "$wdir")"
content="$(cat "$manifest" 2>/dev/null)" || continue
```

For each discovered manifest this launches three child programs in addition to
the scanner shell. The input glob is fixed to `$dir/*/widget.json`, so the same
values can be derived in Bash itself:

```text
wdir = manifest minus trailing /widget.json
wid  = final path component of wdir
content = Bash direct file read
```

This does not require changing QML service ownership, manifest validation,
config seeding, reload behavior or the public widget list. It is a process-only
cleanup with a bounded saving of **up to three child processes per manifest**.

Required byte/behavior oracle:

- missing widget directory;
- empty directory;
- one and many manifests;
- spaces and Unicode in directory/widget names;
- unreadable manifest preserves the existing skip/failure behavior;
- manifest with and without trailing newline;
- malformed JSON remains malformed in the same way for the QML parser;
- exact scanner stdout for normal fixtures;
- CustomWidgets resulting `widgets` list/config seeding equality.

Do not combine this with deferred CustomWidgets service materialization in the
same patch. Background currently references CustomWidgets for live custom widget
ownership, and changing when the service scans/seeds config is a separate
behavior/lifecycle problem.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 16

Baseline: `dev` at `5aeaf5cff9acd48e46059937ff976e20b33a726f`.

This round revalidated a historical LocalMusic memory/transport finding against
current source and current contract tests before promoting it into the canonical
ledger.

Current source identities are unchanged from the archived research baseline:

- `services/LocalMusic.qml`: `88263668b48d85323a576c4c3645d9f40909f466`;
- `modules/sidebarLeft/LocalMusicView.qml`: `d5b1880d5a1a3796f0faefe343cf3f2f9909953a`;
- `native/inir-mpdd/src/main.rs`: `1c63b8e5281dad2a28e88ea3cb660f7cc0c0cb88`;
- `scripts/local_music_mpd.py`: `0e05af4f8a308072fbed7bed96994559b66bf6f1`.

### R16.1 — QML retains a duplicate folder tree that the live Songs browser does not use

`LocalMusic._applyPayload(..., includeLibrary=true)` currently retains:

```qml
libraryTracks = payload.tracks ?? []
playlists = payload.playlists ?? []
folderCollections = payload.folders ?? []
```

The live Songs browser does not consume that pre-grouped folder structure.
`LocalMusicView.qml` derives folder navigation, child counts, folder selection
and folder track sets directly from `LocalMusic.libraryTracks`.

Current repository search returns `folderCollections` only from
`services/LocalMusic.qml`, while the explicit qualified search for
`LocalMusic.folderCollections` returns no consumer. Because the service/view
blobs also match the archived research identities exactly, the earlier
no-consumer conclusion remains strongly supported at this baseline.

Strict-lossless first step:

1. remove the `folderCollections` property;
2. stop assigning `payload.folders` in `_applyPayload()`;
3. leave `libraryTracks`, `playlists`, queue/status/current-track state and every
   backend payload byte unchanged;
4. leave Songs folder derivation exactly as it is today.

This is deliberately smaller than changing the MPD snapshot protocol. The JSON
parser may still materialize `payload.folders` transiently, but after
`_applyPayload()` returns the subtree no longer has an intentional QML root and
can become collectible.

Why the retained subtree can be substantial:

- Rust builds a `BTreeMap<String, Vec<Value>>` and pushes
  `Value::Object(track.clone())` into folder buckets;
- Python groups the already-built track dictionaries into `folders_map` and
  emits a `folders` list;
- the payload therefore carries `tracks` plus another folder-organized
  representation proportional to library size.

No RSS percentage is claimed: actual V4/JSON representation, sharing and GC
need measurement.

Required oracle before implementation:

- current-dev reference search for unqualified and qualified
  `folderCollections` usage;
- empty/small/large libraries;
- nested folders and same-name leaf folders;
- root/child Songs navigation;
- search results;
- Ctrl/Shift selection and folder bulk actions;
- playlists and queue playback;
- refresh/rescan and MPD reconnect;
- QML warnings/property references;
- compare all public LocalMusic state except the intentionally removed dead
  property.

### R16.2 — Removing `folders` from the transport is a separate contract decision

After R16.1, the shell frontend no longer needs `payload.folders`, but the
backend field cannot simply be deleted under strict compatibility assumptions.

Current Rust snapshot generation:

```text
tracks
  -> group by folder
  -> clone each track object into folder buckets
  -> sort/build folder objects
  -> serialize tracks + playlists + folders
```

Python builds the equivalent `folders_map/folders` representation.

More importantly, current regression infrastructure explicitly treats
`folders` as a stable deep-snapshot field. The native benchmark contract checks:

```text
[connected, musicRoot, tracks, playlists, folders]
```

Therefore the higher-value backend optimization is **compatibility-gated**, not
a free cleanup.

Safe promotion options are:

1. formally revise the stable snapshot schema and update Rust/Python/tests in one
   contract change after proving no supported external/manual caller needs
   `folders`; or
2. add a lean/internal snapshot mode used by LocalMusic while retaining the
   legacy full snapshot shape for compatibility/deep parity.

Do not remove `folders` from only Rust or only Python. Native/fallback parity is
part of the maintained selector contract.

If a lean mode is adopted, measure:

- serialized stdout bytes versus track count;
- backend CPU time for grouping/cloning/serialization;
- transient process RSS;
- QML parse time/RSS;
- identical frontend library, folder-navigation and playback state.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 17

Baseline: `dev` at `4677288dc9d3bee5d3a65969ebb3c8b031e33030`.

This round adds one entirely new Niri minimize/restore candidate, promotes a
revalidated archived tray finding into the canonical ledger, and identifies a
separate Material tray duplication that the archived service-only analysis did
not cover.

Current source identities:

- `services/MinimizedWindows.qml`: `ced7e049ef5942dea1ca5f3395eb9b614e9ecaf6`;
- `modules/waffle/bar/tasks/TaskAppButton.qml`: `500c22e179e8ab88988e0bfc40f97b9d4e67fe81`;
- `services/TrayService.qml`: `3f5e1f2580aebadf87ab40b91b4876c9ca68e76b`;
- `modules/bar/SysTray.qml`: `df3d21edca72eaf173f015c00a4cc122386d1e5e`;
- `modules/waffle/bar/tray/Tray.qml`: `1f00cc4a96fa861470d40fd47c23b0d8666b7946`.

### R17.1 — MinimizedWindows sorts whole workspace subsets just to choose one result

`stashWorkspaceForOutput()` currently builds the occupied-workspace Set and
then executes:

```qml
const workspaces = (NiriService.allWorkspaces ?? [])
    .filter(workspace => workspace.output === output && !occupied.has(workspace.id))
    .sort((a, b) => b.idx - a.idx)
return workspaces[0] ?? null
```

Only the workspace with maximum `idx` is needed. A single pass can track the
best eligible workspace and avoid both the filtered array and sort.

Strict equivalence requires explicit tie handling. JavaScript sort is stable on
the supported runtime. For equal `idx`, descending sort preserves source order,
and `[0]` selects the first source-order candidate. Therefore a one-pass
selector must update only when `workspace.idx > best.idx`, not on equality.

### R17.2 — Restore fallback can also be one pass, but its tie rule is different

When the original workspace id no longer exists, `restoreWorkspace()` does:

```qml
const outputWorkspaces = allWorkspaces
    .filter(workspace => workspace.output === originalOutput)
    .sort((a, b) => a.idx - b.idx)

return outputWorkspaces.find(workspace => workspace.idx === originalWorkspace)
    ?? outputWorkspaces.reduce((best, workspace) =>
        abs(workspace.idx - originalWorkspace) < abs(best.idx - originalWorkspace)
            ? workspace : best)
```

The sort is not needed for distance itself, but it defines tie behavior:

- exact duplicate `idx`: stable ascending sort + `find` returns the first
  source-order duplicate;
- equal distance around the requested index, e.g. 4 and 6 around 5: ascending
  order sees 4 first, and the strict `<` reducer keeps 4 on the tie.

A strict one-pass equivalent can track:

1. first exact match in source order;
2. otherwise smallest absolute distance;
3. on equal distance, smaller `idx`;
4. on equal distance and equal `idx`, first source-order record.

That reproduces the current sorted semantics without allocating/sorting the
output subset.

Required oracle for R17.1/R17.2:

- empty workspace list;
- one/many outputs;
- all candidate workspaces occupied;
- equal max `idx` duplicates for stash selection;
- original workspace id still present;
- original id missing but exact original `idx` present;
- duplicate exact `idx` records;
- nearest lower only / upper only;
- symmetric nearest tie around the requested index;
- duplicate nearest records;
- negative/unusual indices if accepted by current Niri fixture model;
- compare selected workspace **object identity**, not only id/value.

This is action-path work, not frame-path work, so the expected gain is modest in
normal use despite the clean complexity reduction.

### R17.3 — countMinimizedForApp allocates a result array only to read length

Current service code:

```qml
function countMinimizedForApp(appId) {
    return getMinimizedForApp(appId).length
}
```

`getMinimizedForApp()` filters `minimizedIds` into a new array. The only
external count consumer found on current dev is Waffle
`TaskAppButton.minimizedCount`, instantiated once per task-app delegate.

Keep `getMinimizedForApp()` unchanged for ID-returning behavior. A direct count
loop can reuse the same lowercase substring predicate and remove one temporary
array per count binding evaluation.

This is a micro-candidate and ranks below the workspace selector cleanup.

### R17.4 — TrayService archived finding remains valid on current source

The current TrayService blob is identical to the archived research identity.
It still derives three outputs with three separate source filters:

- `fcitxItems`;
- `itemsInUserList`;
- `itemsNotInUserList`.

The archived one-pass partition remains valid and is now promoted into this
canonical ledger. Membership can use a Set without altering persisted pin order
or duplicates because this path only asks exact membership.

The service semantics to retain are asymmetric:

- Fcitx bypasses the normal lists;
- pinned items remain in `itemsInUserList` even when passive;
- passive filtering applies only to `itemsNotInUserList` when smartTray is on;
- final Waffle-visible pinned/unpinned composition still depends on
  `invertPins`.

### R17.5 — Material SysTray duplicates the same work but cannot blindly reuse TrayService outputs

Current Material `modules/bar/SysTray.qml` separately scans
`SystemTray.items.values` three times again. Its semantics differ from the
service in two important ways:

1. configuration comes from `Config.options.bar.tray`, while TrayService uses
   the generic `Config.options.tray` namespace consumed by Waffle;
2. Material has an explicit Spotify exception:
   a passive Spotify item remains visible when smart filtering is enabled.

Therefore the safe first optimization is **not** to replace Material lists with
`TrayService.pinnedItems/unpinnedItems`. Instead, Material can build one private
partition snapshot from its own pins/filter flag while preserving the Spotify
exception exactly.

For each valid non-Fcitx item, compute lowercase id/title once, determine the
Spotify exception once, perform pin membership once, and append to exactly one
of the Material user-list arrays. Fcitx remains its own always-visible group.

Required Material oracle:

- Fcitx by id/title;
- pinned/unpinned active item;
- pinned/unpinned passive item;
- passive Spotify by id and by title;
- smartTray on/off;
- duplicate bar pin ids;
- invertPins on/off;
- item status mutation without insertion/removal;
- overflow closes when the final unpinned item disappears;
- exact item identity and source order for all four public arrays.

Longer-term unification into one shared parameterized classifier may be useful,
but only after both service/Waffle and Material snapshots have parity tests.
Do not merge config namespaces or Spotify policy as part of the optimization.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 18

Baseline: `dev` at `ec13cf37718991f79a2c7b8b253c20d638ef0cd0`.

This round revalidated the archived Network helper-process candidate and corrected
one semantic detail before promotion into the canonical ledger. It also checked a
separate first-run shell wrapper and deliberately left that lower-value path
unpromoted.

Current source identities:

- `services/Network.qml`: `a20c4c1edf1fbeb2f2a8285518af053bf72a09dc`;
- `services/FirstRunExperience.qml`: `1b58bea64a235c24ea69b7afc260a69ea6c004f9`.

### R18.1 — Network's architecture is already event-driven; the remaining debt is helper fan-out

The broad canonical conclusion remains correct: Network uses one long-lived
`nmcli monitor`, coalesces bursts through a 200 ms one-shot debounce, and does
not need a new polling redesign.

However, after each successful connected-state reconciliation it may launch two
secondary detail paths:

```text
connection name:
  sh
   └─ nmcli ...
       └─ head -1

Wi-Fi strength:
  sh
   └─ nmcli ...
       └─ awk ...
```

Those shell/text-filter helpers are not required for lifecycle ownership. QML
already collects/parses stdout elsewhere in the same service.

### R18.2 — Connection name can be direct argv with first-line parsing

Current source:

```qml
command: ["sh", "-c", "nmcli -t -f NAME c show --active | head -1"]
onStreamFinished: root.networkName = text.trim()
```

Strict-lossless direction:

1. execute directly:
   `nmcli -t -f NAME c show --active`;
2. collect stdout;
3. select the first output line exactly as `head -1` does;
4. apply the same surrounding trim before publishing `networkName`.

Do not sort, prefer Wi-Fi, or select by active device. The current contract is
simply the first row emitted by `nmcli connection show --active`.

Required cases:

- zero/one/multiple active connections;
- Wi-Fi + Ethernet + VPN combinations;
- names containing spaces;
- empty first line / trailing newline fixtures;
- nonzero nmcli exit;
- transition to no active link, preserving the existing explicit stale-name
  clear performed by the parent status path.

### R18.3 — Archived Wi-Fi-strength note needed a row-order correction

Current source:

```qml
command: ["sh", "-c",
    "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
stdout: SplitParser {
    onRead: data => root.networkStrength = parseInt(data)
}
```

The older archived note described this as a first-active-row selection. That is
not exact. The awk program prints **every** row whose first character is `*`
(except a hypothetical matching row at NR=1), and `SplitParser.onRead` assigns
`networkStrength` once per emitted line. If several active rows are present,
the **last emitted active row wins**.

A correct direct-argv replacement therefore should not arbitrarily stop at the
first active row.

Safe shape:

1. run directly:
   `nmcli -f IN-USE,SIGNAL,SSID device wifi`;
2. collect/iterate output lines in original order;
3. for every line beginning exactly with `*`, parse the same second
   whitespace-delimited field;
4. assign/update the candidate strength for every match so the final matching
   row wins, matching today's SplitParser effect;
5. if no active row is present, retain the current parent-path ownership of
   stale clearing rather than inventing a new value transition.

An alternate terse nmcli format may be possible, but it widens the parser proof
and is not necessary to remove the shell and awk processes.

Required oracle:

- one active AP;
- multiple visible APs with one active row;
- fixture with multiple active-marker rows proving **last-match** behavior;
- no active row;
- signal 0 and 100;
- malformed/non-numeric signal;
- SSID with spaces and punctuation;
- localized/header variants (current row matching depends on the literal active
  marker, not the header text);
- nonzero nmcli exit;
- exact final `networkStrength` value and publication timing relative to the
  parent status reconciliation.

### R18.4 — Structural process saving

For a connected Wi-Fi detail refresh, these two helpers currently account for:

```text
name:     shell + nmcli + head = 3 processes
strength: shell + nmcli + awk  = 3 processes
```

Direct argv keeps the two required nmcli processes and removes the four
intermediaries:

```text
name:     nmcli = 1
strength: nmcli = 1
```

So this specific subpath falls from six processes to two: **4 fewer helper
processes per detail refresh**. This is a bounded structural count, not a
whole-shell CPU percentage.

Do not mix this patch with the larger `updateConnectionType` shell pipeline,
which intentionally sequences three nmcli commands and has partial-failure/radio
fallback semantics. That deserves a separate proof if researched later.

### R18.5 — First-run wallpaper discovery shell wrapper is valid but too low leverage to promote now

`FirstRunExperience.qml` currently uses:

```text
/bin/sh -c 'find <wallpaper-dir> ...'
```

The shell could theoretically be removed by expressing the same `find` argv
directly through Process. That would save one helper process, but this path runs
only when the first-run marker is absent and wallpaper discovery is required.
It is therefore much lower leverage than the recurring Network detail path.

Leave it unpromoted unless a broader startup-helper cleanup is later assembled.
Any direct-find change must preserve stderr suppression, extension predicate,
path handling, completion/failure timing and deterministic final wallpaper
selection after the existing QML sort.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 19

Baseline: `dev` at `48459a53a76b785c2927b4834b53a27112378a43`.

This round revalidated two archived collection-hot-path findings against current
source and promoted them into the canonical ledger. Their current blobs match
the archived research identities, so the original structural observations still
apply.

Current source identities:

- `services/AppSearch.qml`: `74ea3c9e92860af62f10850c89118d79b7837543`;
- `services/TaskbarApps.qml`: `b05b0b39988a40faf7fa3cb84e6b0c747cf4a3ee`;
- `modules/bar/BarTaskbar.qml`: `3aca1b63e2633584c86f75c6a2e5eb2ebaebfdb3`;
- `modules/dock/DockApps.qml`: `11b3ea8cc17c91a1cf3b6a1f41f64f392d4dfcc9`.

### R19.1 — AppSearch identity-rule cache still fingerprints on every lookup

Current source keeps a compiled rule cache but validates it with:

```qml
const rules = Config.options?.windows?.appIdentityRules ?? []
const key = JSON.stringify(rules)
if (root._identityRulesKey === key)
    return root._identityRules
```

That means a logical cache hit still serializes the complete rule list.
`resolveWindowIdentity()` calls this path once per non-empty window identity.

Current repository search confirms collection-pass callers in:

- `services/TaskbarApps.qml`;
- `modules/dock/DockApps.qml`;
- `modules/bar/BarTaskbar.qml`;
- `modules/bar/BarTaskbarPreview.qml`;
- `modules/altSwitcher/AltSwitcher.qml`;
- `modules/altSwitcher/AltSwitcherNoVisual.qml`;
- `modules/waffle/taskview/WaffleTaskViewContent.qml`.

So one compositor snapshot can cause the same unchanged rule list to be
serialized repeatedly across multiple N-window passes.

Strict-lossless direction:

1. keep `_identityRules` as the compiled resident representation;
2. split parsing into an explicit rebuild helper;
3. rebuild once on initial demand/Config-ready;
4. bind a `Connections` target to the current
   `Config.options?.windows` object and rebuild on
   `appIdentityRulesChanged`;
5. if config reload can replace the nested JsonObject instance, ensure the bound
   target follows that replacement and performs one rebuild against the new
   object;
6. let `resolveWindowIdentity()` read the resident compiled list directly with
   no per-window JSON fingerprint.

Behavior oracle:

- empty/missing rule list;
- app-id-only rule;
- title-only rule;
- both-regex rule;
- malformed app-id/title regex;
- malformed rule followed by valid rule;
- multiple matches proving first-rule ownership;
- case-insensitive matches;
- empty window app id early return;
- live rule mutation;
- config file reload and nested-object replacement;
- desktop entries becoming available after rule compilation, proving the
  configured `desktopId` remains a string and is not eagerly resolved.

Compare every returned identity string and malformed-rule behavior against the
current implementation.

### R19.2 — Taskbar's local identity revision is not a real dependency

Current TaskbarApps owns:

```qml
property int _identityRulesRevision: 0

function onAppIdentityRulesChanged() {
    root._identityRulesRevision++
    refreshApps.restart()
}

function computeApps() {
    const identityRulesRevision = root._identityRulesRevision
    ...
}
```

The local variable is never used after assignment. Because `computeApps()` is
called imperatively from the one-shot timer, this read does not establish a
binding dependency for `apps`. The same signal handler already restarts the
actual refresh path.

Once R19.1 gives AppSearch explicit rule invalidation, remove the counter/read
but keep `refreshApps.restart()`. Treat this only as companion cleanup.

The nearby ignored-app RegExp compilation remains lower priority. TaskbarApps
recompiles configured ignored regexes on every model rebuild, but invalid regex
patterns currently emit a warning each time. A cache that silently remembers a
failure would change diagnostic log frequency, so do not bundle that behavior
into R19.1.

### R19.3 — BarTaskbar repeats pinned-list scans inside its sort comparator

In separate-pinned mode, BarTaskbar sorts running groups with:

```qml
const aIndex = pinnedApps.findIndex(p => p.toLowerCase() === a.lowerAppId)
const bIndex = pinnedApps.findIndex(p => p.toLowerCase() === b.lowerAppId)
...
return a.lowerAppId.localeCompare(b.lowerAppId)
```

and later publishes:

```qml
pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId)
```

For R running groups and P pins, the sort performs repeated O(P) scans during
O(R log R) comparator calls, then publication adds another O(R·P) pass.

The sibling Dock path already demonstrates the intended structural shape with a
precomputed rank/membership map. Bar cannot copy Dock blindly because the
fallback order differs: Bar deliberately keeps unpinned running apps
alphabetical.

Strict-lossless Bar algorithm:

1. build `Map<lowercaseId, firstIndex>` once from `pinnedApps`;
2. **only set a key if absent**, matching current `findIndex` first-occurrence
   behavior for exact/case-variant duplicates;
3. use map membership/rank for pinned-vs-unpinned and pinned-order comparison;
4. preserve `lowerAppId.localeCompare()` for two unpinned groups;
5. publish the `pinned` field from map membership;
6. leave pinned-only item creation, separator placement, focused state and
   toplevel grouping unchanged.

Required oracle:

- empty pin list;
- one/many running groups;
- all pinned/all unpinned/mixed;
- exact duplicate pins;
- case-variant duplicate pins;
- pinned id with no installed desktop entry;
- case normalization;
- alphabetical fallback among unpinned groups;
- focused/running flags and separator placement;
- exact final item identity/order.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 20

Baseline: `dev` at `43b5ab1a6417d7f566822c6e6d731b3eed3b5cf6`.

This round repairs a post-consolidation ownership gap. Round 13 said several
findings were “already owned” by the then-active cross-repo handoff. That handoff
is now archived by design, so high-confidence findings that still match current
source must be promoted into this canonical ledger rather than remaining only in
history.

Current source identities:

- `services/GameMode.qml`: `692f3e200b7c46835f44f152c88f231e2d0bd2b5`;
- `services/DesktopItems.qml`: `415be57a15cfe34f373c8d2290e481bf978643ae`;
- `modules/background/Background.qml`: `29bd40236ba9579077d361fb1012d4f994ef4a3a`;
- `modules/background/desktopItems/DesktopItemDelegate.qml`: `88000b9820fb3b68cee5a007cec6a698b50948ba`.

### R20.1 — GameMode recomputes the same fullscreen facts for many consumers

Current GameMode exposes three related reads over the same published Niri state:

- `hasAnyFullscreenWindow`;
- `hasVisibleFullscreenWindow`;
- `hasFullscreenOnOutput(outputName)`.

The first two are derived properties/functions in the singleton itself, while
`hasFullscreenOnOutput()` is called from many resident consumers. Current
repository search finds consumers in Bar, Screen Edges, Screen Corners, classic
Background, Waffle Background, SidebarHost, Abyss Perimeter,
WidgetPowerManager and family work-area guards.

Each consumer can therefore rescan the same `NiriService.windows` snapshot after
one windows/workspaces/outputs publication.

Strict-lossless derived state:

```text
fullscreenSnapshot = {
    any: bool,
    visible: bool,
    activeOutputs: { outputName: true, ... }
}
```

Build it once from the same authoritative inputs already used today.

For each window:

1. resolve its workspace from `NiriService.workspaces[workspace_id]`;
2. evaluate fullscreen with the existing fullscreen helper logic;
3. update `any` using the exact current fallback rules;
4. only for a resolved active workspace, update `visible`;
5. for a resolved active workspace with a known output, set that output in
   `activeOutputs`.

Then:

- `hasAnyFullscreenWindow` reads `snapshot.any`;
- `hasVisibleFullscreenWindow` reads `snapshot.visible`;
- `hasFullscreenOnOutput("")` returns `snapshot.visible`, matching current
  empty-name semantics;
- `hasFullscreenOnOutput(name)` becomes an O(1) output lookup.

The critical semantic boundary is missing workspace metadata. Current “any”
fullscreen detection can still become true through the service's single-output
fallback even when the workspace record is temporarily unavailable. Visible and
per-output state do **not** inherit that fallback: they require a resolved active
workspace. The snapshot must preserve that asymmetry exactly.

Do not merge focused-window auto-detection into this patch. GameMode's focused
window path handles ordering/freshness details separately; this candidate only
removes duplicate secondary scans.

Required oracle:

- zero outputs/windows;
- one output with temporarily missing workspace metadata;
- fullscreen on inactive workspace;
- fullscreen on active workspace;
- two outputs with one or both fullscreen;
- direct `is_fullscreen` path;
- size-heuristic path and ±2 px tolerance;
- layout update before workspace update;
- output geometry change;
- active/inactive workspace transition;
- fullscreen exit;
- empty and named output query parity;
- complete boolean parity for every existing consumer after each source update.

Structural saving is one O(N) derivation per relevant source snapshot instead of
O(C·N) scans for C fullscreen-query consumers.

### R20.2 — DesktopItems clones the full model once per output

`DesktopItems.items` is stored as an id->record object. Current `listItems()`
returns a fresh array of fresh shallow clones:

```qml
return Object.keys(root.items).map(itemId =>
    Object.assign({ id: itemId }, root.items[itemId]))
```

Classic Background renders one desktop-item model per output. Its per-output
helper begins from `DesktopItems.listItems()` and only then filters the result to
that output. Therefore every output independently clones the entire item set.

For M outputs and I items, a single items revision can create approximately
M·I presentation record clones before output filtering. The repeated full-list
copy is unnecessary because current DesktopItemDelegate does not mutate its
`itemData` object directly; writes go back through explicit service operations
such as update/remove/repair and drag persistence.

Strict-lossless direction:

1. let DesktopItems own one derived read snapshot:
   `[{id, ...record}, ...]`;
2. rebuild it only when `root.items` changes;
3. let Background consume that snapshot and perform only its existing
   per-output/fallback filter;
4. retain `listItems()` as a defensive-copy API if any imperative caller relies
   on receiving independent mutable records;
5. do not expose invalid storage-only records through the shared presentation
   snapshot.

A later service-level output-bucket cache is possible but unnecessary for the
first strict-lossless step because it would pull screen/focus invalidation into
the persistence service.

Required oracle:

- zero/one/many items;
- one/multiple outputs;
- create/update/remove/undo;
- rename/lock/layer changes;
- drag persistence;
- cross-output move;
- saved output that is no longer connected;
- focused-output fallback for orphaned items;
- invalid-record preservation remains storage-only;
- exact Repeater item order and identity after every `items` reassignment;
- proof that current presentation delegates never mutate shared snapshot records.

### R20.3 — DesktopItems grid-candidate sort remains MEASURE-FIRST

The archived DesktopItems research also noted that `arrangePosition()` builds
and sorts all grid candidates by squared distance before searching for the first
collision-free cell. That path is not promoted here.

It runs on bounded interaction/layout events rather than pointer-frame updates,
and the candidate count is constrained by the desktop-item pitch. Replacing the
sort with a custom nearest-cell traversal could change tie/order behavior for
small practical gain. Keep it MEASURE-FIRST until profiling shows arrangement
CPU matters on realistic grids.

### R20.4 — Canonical ownership rule after consolidation

Any older section that says a finding is “owned by the cross-repo handoff” is now
historical wording only. `docs/archive/optimization/CROSS_REPO_OPTIMIZATION_HANDOFF.md`
is evidence/history, not an active owner. A still-valid candidate must appear in
this canonical audit to be considered active research.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 21

Baseline: `dev` at `da982e25fdb13bcee446a7332b98d4c913e10cd1`.

This round continues the post-consolidation promotion pass. Three archived
findings were revalidated against current source; all three source blobs are
unchanged from their archived research baselines, so they are now active in the
canonical ledger rather than remaining history-only.

Current source identities:

- `services/NiriService.qml`: `4c8194493fd380bf0ad8c51bc62990ad0c232738`;
- `modules/common/widgets/SettingsSearchRegistry.qml`: `836c9c061039bae7508aa6b44973722409ddf1dd`;
- `modules/settings/ThemesConfig.qml`: `fa617e33a5a4672e970a46ee19c2a3dae2c309be`.

### R21.1 — Niri layout sort is repeated at the toplevel-match boundary

Normal window publication already does:

```qml
const nextWindows = sortWindowsByLayout(_pendingWindows)
windows = nextWindows
```

and output changes re-sort `windows` as well. Yet `sortToplevels()` starts from:

```qml
for (const niriWindow of sortWindowsByLayout(windows)) {
    ...
}
```

so every compositor sort pass allocates another enriched array, sorts it, maps
it back, and only then begins the Niri↔foreign-toplevel match.

A direct replacement with `for (const niriWindow of windows)` is **not**
strict-lossless because `handleWorkspacesChanged()` can change workspace
`idx` or `output`—both layout sort keys—without reassigning public
`windows`. It emits `windowOrderChanged()` instead. The extra sort inside
`sortToplevels()` currently repairs that derived order.

Strict-lossless direction:

1. maintain a private layout-sorted window view;
2. rebuild it on normal batched window publication;
3. rebuild it on `WorkspacesChanged`;
4. rebuild it on output geometry/topology changes and initial output fetch;
5. keep public `windows` assignments and `windowsChanged` signal count exactly
   as today;
6. keep `windowOrderChanged()` emissions unchanged;
7. let `sortToplevels()` iterate the private sorted view directly.

This composes with the existing Niri app-id bucket research: cached layout order
removes repeated O(W log W) preparation while app-id bucketing removes
impossible cross-app match comparisons.

Required oracle:

- open/close/change publication;
- focus-only changes;
- `WindowLayoutsChanged`;
- `WorkspacesChanged` changing idx;
- workspace moving outputs;
- `OutputsChanged` changing logical x/y;
- initial output fetch arriving after windows;
- zero-window transition;
- exact `windowsChanged`, `windowOrderChanged` and `activeWindowChanged`
  counts/order;
- complete `sortToplevels()` identity/order parity.

Do not switch `filterCurrentWorkspace()` to this private view as part of the
same patch. Its current ordering after workspace-only topology changes is a
separate correctness question, not an optimization entitlement.

### R21.2 — Settings search normalizes snapshot metadata again on every keystroke

`SettingsSearchRegistry.registerOption(meta)` already snapshots the searchable
metadata associated with a live control. There is no update-in-place API for
those search strings; lifecycle changes unregister/re-register entries.

Despite that, each `buildResults(query)` recreates normalized forms for every
entry:

```text
label.toLowerCase()
description.toLowerCase()
pageName.toLowerCase()
section.toLowerCase()
keywords.join(" ").toLowerCase()
```

Strict-lossless direction is to compute those private normalized strings once
when the entry is registered while retaining all current raw/public fields.
Search then reads the precomputed strings.

Required oracle:

- empty query;
- one/multiple terms;
- case variants;
- exact/prefix/mid-string matches;
- generated and provided keywords;
- page/section/description-only matches;
- unregister/re-register;
- page/control destruction/recreation;
- translated label/description as captured at registration time;
- exact score, matchedTerms and final result ordering.

Do not add a debounce. Immediate per-keystroke observability is part of current
behavior.

### R21.3 — Highlight markup is built before the top-50 cutoff

Current `buildResults()` computes highlighted label/description fields for every
matched entry, then sorts and returns only `out.slice(0, 50)`.

Highlight strings do not participate in scoring or sort order. A strict-lossless
pipeline can therefore:

1. score all entries exactly as today;
2. retain raw label/description and matchedTerms;
3. perform the identical sort;
4. take the exact same first 50;
5. call the existing `highlightTerms()` only for those returned entries.

The proof must compare the complete result object, not only count/order:
IDs, scores, matchedTerms, raw strings and generated markup all need parity.
Include overlapping terms and term-order-sensitive highlight cases.

### R21.4 — Saved-theme polling has O(T) child-process fan-out every two seconds

While the custom-theme editor is visible/expanded, ThemesConfig runs a repeating
2 s refresh. Current command shape:

```text
Bash
  for every saved *.json:
    basename
    jq
```

For T saved themes, an unchanged poll therefore starts approximately
`1 + 2T` processes.

The same output can be produced with:

- Bash parameter expansion for `name.json -> name`;
- a single jq process over the complete ordered input-file list, using
  `input_filename` (or equivalent explicit filename input) to derive the name;
- one compact JSON object per valid source file on stdout for the existing QML
  parser.

That bounds each poll to roughly one Bash + one jq regardless of T.

Required oracle:

- zero/one/many themes;
- spaces/dots/Unicode filenames;
- deterministic glob/output order;
- invalid JSON mixed with valid JSON;
- file deleted/replaced during scan;
- exact id/name/description/tags/colors parity;
- current warning/skip behavior;
- `savedThemePresets = []` reset and incremental SplitParser publication timing.

The larger idea—replace the fixed 2 s poll with filesystem-driven updates—is a
separate follow-up. Add/remove watchers are insufficient by themselves because
same-name overwrite must also be detected. Do not remove polling until overwrite
semantics are proven.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 22

Baseline: `dev` at `318e50891bf1e93475945926b64881ea489c357a`.

This round promotes four more archived findings whose source identities still
match current dev exactly. It also separates a small Hyprland fullscreen cleanup
from the larger Background range/occupancy work so the priority remains honest.

Current source identities:

- `services/WorldClock.qml`: `1260b2d2ed85cf70339c2c8f366c296655dc3c9a`;
- `modules/sidebarLeft/LocalMusicView.qml`: `d5b1880d5a1a3796f0faefe343cf3f2f9909953a`;
- `modules/sidebarLeft/SidebarLeftContent.qml`: `06c8e5aa355b97d14d606f7d152123d29a8b36ab`;
- `modules/background/Background.qml`: `29bd40236ba9579077d361fb1012d4f994ef4a3a`;
- `modules/waffle/background/WaffleBackground.qml`: `6e9bcbdf8daef77c9f8169ed998c44bc72b94fa6`;
- `modules/screenCorners/ScreenCorners.qml`: `3fc43bf7e1b7ec63fae6d27f55a5dd48fbb4cb00`.

### R22.1 — WorldClock eagerly owns editor-only timezone catalog state

The runtime clock needs the configured timezone set and current offsets/time.
Yet whenever WorldClock is materialized it also evaluates:

```qml
readonly property var timezoneList: ... Intl.supportedValuesOf("timeZone") ...
readonly property var comboModel: root.timezoneList.map(tz => ({
    label: root.labelFor(tz), tz: tz, icon: ""
}))
```

Repository occurrence inspection shows the full catalog is consumed by timezone
picker/editor surfaces, not ordinary clock rendering.

Strict-lossless direction:

1. replace eager picker catalog evaluation with an idempotent
   `ensureTimezoneCatalog()`;
2. keep catalog state empty until the first picker/editor requests it;
3. compute `Intl.supportedValuesOf("timeZone")` at most once per singleton;
4. build labels/model once and share them among picker instances;
5. retain the complete fallback timezone list and existing `labelFor()`
   formatting;
6. keep configured timezone values and clock entries independent of catalog
   readiness.

Required oracle:

- Intl supported-values path;
- fallback path when Intl support is absent/throws;
- normal clock rendering before catalog creation;
- widget edit popover opened first;
- Desktop Widgets Settings opened first;
- both surfaces opened in either order;
- selected index for every configured timezone;
- custom configured timezone absent from the catalog;
- change timezone and verify current clock/offset refresh parity.

The picker must still show the complete model on its first visible frame. No
permanent spinner/delayed-user-visible catalog is acceptable for this candidate.

### R22.2 — LocalMusic repeats immutable metadata normalization on every keystroke

Current search binding lowercases four fields and concatenates one haystack for
every track whenever `searchField.text` changes:

```text
lower(title) + " " + lower(artist) + " " +
lower(album) + " " + lower(folder)
```

For N tracks and Q intermediate query states, this performs roughly O(N·Q)
normalization/concatenation even though track metadata is unchanged during the
search session.

The containing Sidebar keeps only current/adjacent SwipeView loaders active, so
the optimization can remain view-local rather than adding session-wide music
RAM.

Strict-lossless direction:

1. lazily build `[{track, searchText}]` when query transitions empty ->
   non-empty;
2. use the exact current `String(track?.field ?? "").toLowerCase()` values and
   single-space concatenation;
3. reuse the prepared array for subsequent query edits;
4. invalidate immediately on `LocalMusic.libraryTracksChanged`;
5. clear the prepared array when query becomes empty;
6. return the original track object references in original order.

Required oracle:

- empty/whitespace-only query;
- title/artist/album/folder matches;
- mixed case;
- null/missing metadata;
- multi-word substring queries;
- duplicate tracks;
- rescan while search is active;
- clear then re-enter search;
- exact result identity/order.

Do not add fuzzy search, Unicode normalization, token ranking or debounce.

### R22.3 — Niri Background occupancy is recomputed per output and per family

Classic and Waffle backgrounds each derive:

```text
Object.values(workspaces)
  -> find active workspace for this output
  -> scan windows for matching workspace_id
```

for every output instance. With M outputs, W workspaces and N windows, a relevant
publication can therefore trigger work shaped like O(M·(W+N)) in each family.

Strict-lossless shared derivation:

- `activeWorkspaceIdByOutput` from the authoritative workspace snapshot;
- `occupiedWorkspaceIds` Set/map from the authoritative Niri windows snapshot;
- helper/read model returning whether one output's current active workspace is
  occupied;
- replace the derived map/revision whenever windows/workspaces change so QML
  consumers invalidate reactively.

Do not derive this from foreign toplevels. Current behavior intentionally trusts
Niri's own window/workspace ids.

Required oracle:

- zero windows/workspaces;
- one/multiple outputs;
- active workspace change;
- open/close/move window;
- cross-output move;
- workspace id/index/output topology change;
- focus-only change must not alter occupancy;
- output remove/re-add;
- exact classic/Waffle `hasWindowsOnCurrentWorkspace`, focus-presence and blur
  progress parity.

### R22.4 — Hyprland Background keeps a sorted array stronger than its consumers need

Classic Background currently constructs a monitor-local `relevantWindows`
array by filtering `HyprlandData.windowList` and sorting it by workspace id.
The array is then used only for:

- first workspace id;
- last workspace id;
- whether the active workspace has a window.

One scan can derive `{first,last,hasCurrent}` without retaining/sorting the full
array.

The current fallback must be copied exactly:

```qml
firstWorkspaceId = summary.first || 1
lastWorkspaceId = summary.last || 10
```

That means workspace id 0 remains treated as falsy even though the existing
filter permits it. Do not silently convert to `??` and change semantics.

Required oracle:

- no windows;
- negative/special workspace ids;
- workspace id 0;
- out-of-order workspace ids;
- current workspace occupied/empty;
- active workspace change without window-list reorder;
- monitor migration;
- one/multiple outputs;
- exact first/last range and occupancy parity.

### R22.5 — Hyprland fullscreen nested filters are a clean secondary cleanup

Background and ScreenCorners both build monitor workspace arrays, filter again
for active+fullscreen, and inspect element 0. The requested answer is only a
boolean/existence result.

Equivalent allocation-light shape:

```qml
Hyprland.workspaces.values.find(workspace =>
    workspace.monitor
    && workspace.monitor.name == monitor.name
    && workspace.active
    && workspace.toplevels.values.some(window =>
        window.wayland?.fullscreen))
```

Preserve loose monitor-name equality, active-workspace requirement and
Wayland-only fullscreen detection. Keep Niri on the GameMode authority path.
This ranks below R22.4 because it removes smaller temporary arrays rather than an
entire sort pipeline.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 23

Baseline: `dev` at `cb5d11621cb793c06a10ee19c72b7e40cbfb4031`.

This round promotes three archived memo/index findings whose current source
blobs still match the archived research identities exactly. All three move work
from frequent read paths to existing authoritative rebuild/invalidation
boundaries.

Current source identities:

- `services/AppSearch.qml`: `74ea3c9e92860af62f10850c89118d79b7837543`;
- `services/MprisController.qml`: `3a8184f9308f0816ea395ea26f182bb5a3fbcf15`;
- `services/Notifications.qml`: `a05c6744c123d8ed96ee19c8d04cccdbcdeeae0e`;
- `modules/dock/DockAppButton.qml`: `e82cf611338e518d70f8c95e45808217c7b90934`.

### R23.1 — AppSearch repeats the complete desktop-entry resolution chain for stable ids

`lookupDesktopEntry(appId)` already benefits from reverse maps, but each call
still re-enters the resolution chain from the top:

1. `DesktopEntries.heuristicLookup(appId)`;
2. direct lowercase/kebab/reverse-map probes;
3. scoped/reverse-domain normalization candidates;
4. suffix stripping;
5. last-resort token-overlap scans across desktop-id/startup-class maps.

The same app identity is requested repeatedly from Taskbar, Dock, Bar/Waffle
buttons, AltSwitcher, MPRIS hint resolution, ScreenTime repair, Settings and
other icon/desktop-entry helpers.

Strict-lossless memo:

- key by the **exact incoming appId string**;
- cache the final `DesktopEntry` object or an explicit miss sentinel;
- check the memo before running the existing chain;
- invalidate the entire memo immediately in
  `DesktopEntries.applications.onValuesChanged`;
- keep the existing debounced reverse-map rebuild unchanged.

Immediate invalidation is essential. Today a new/removed desktop entry can be
observed by `DesktopEntries.heuristicLookup()` before the 500 ms local map
rebuild completes. If memo invalidation waited for `_cacheRevision`, an old
hit/miss would remain stale during that window.

Required oracle:

- exact desktop id/stem;
- StartupWMClass;
- executable basename;
- whitespace/kebab normalization;
- scoped ids;
- reverse-domain ids;
- suffix stripping;
- token-overlap fallback;
- no match;
- case variants;
- repeated hit/miss;
- DesktopEntry add/remove/change between calls, including lookup before the
  debounced map rebuild fires;
- exact returned object identity/null parity.

### R23.2 — MPRIS has a second expensive resolver after AppSearch misses

`MprisController._desktopEntryForHint()` first tries AppSearch. On a miss it
runs an MPRIS-specific fuzzy resolver across DesktopEntries, inspecting fields
such as id/name/genericName/startupClass/command and performing normalization,
substring/token scoring.

The same hint can be resolved repeatedly while building:

- player display names;
- stream desktop entries;
- stream display names;
- stream icons;
- volume-mixer/media reactive bindings.

The R23.1 AppSearch memo accelerates only the first stage. It does not eliminate
this MPRIS-specific catalog scan after an AppSearch miss.

Strict-lossless memo:

1. clean the incoming hint with the existing helper;
2. key by that exact cleaned hint;
3. cache the **final** `DesktopEntry|null` result;
4. invalidate immediately on DesktopEntries changes;
5. leave every score, threshold, token and first-best/tie rule untouched.

Required oracle:

- direct AppSearch hit;
- exact fallback-field match;
- substring match;
- token-overlap match;
- below-threshold miss;
- equal-score candidates proving current tie behavior;
- empty/malformed hint;
- case/whitespace/version-suffix variants;
- repeated hit/miss;
- DesktopEntry add/remove/change between calls;
- exact `streamDisplayName()` and `streamIconName()` parity for representative
  players/nodes.

### R23.3 — Notification badge lookup repeats group normalization once per Dock app

Current Dock button badge code calls:

```text
Notifications.countForApp([originalAppId/appId, desktopEntry.name])
```

The helper normalizes its small identifier list, then walks every popup group
and normalizes each group appName again on every call.

Popup groups already have a clear authoritative rebuild boundary in
`Notifications._updateGroups()`. Derive a private normalized lookup in the same
transaction as `_cachedPopupGroupsByAppName`.

Parity rule is subtle: current semantics are **not** “sum every normalized
collision” and not “first caller identifier wins”. The outer iteration is popup
group order. Therefore the first popup group in current object enumeration order
that matches any normalized caller id wins.

Strict-lossless index should retain, for every normalized group key:

- the earliest group rank/order;
- that group's notification count.

When caller identifiers map to multiple normalized keys, choose the candidate
with the lowest stored group rank.

Required oracle:

- empty groups/identifiers;
- app-id versus display-name match;
- punctuation/case normalization;
- two caller ids matching different groups;
- two distinct group names normalizing to the same key;
- no match;
- timeout/read transition;
- group insertion/order change;
- exact count parity after every popup-group rebuild.

This composes with existing notification timer/object-reuse research but remains
a separate patch and oracle.

### R23.4 — New-service pass deliberately produced no promotion

A separate current-dev audit covered BluetoothStatus, Updates, RecorderStatus,
KeyboardIndicators and WindowPreviewService.

- **Updates** already uses the real `checkupdates` spawn as its availability
  probe instead of a duplicate command-v helper; its long-interval poll and
  timeout are intentional service behavior.
- **RecorderStatus** already separates 15/30 s idle polling, 1 s visible-demand
  polling and 1 s active-recording polling; it is substantially demand-gated.
- **KeyboardIndicators** prefers the native/event-driven lock-state monitor and
  uses coarse sysfs discovery only as fallback.
- **BluetoothStatus** performs two small connected-device scans, but normal
  Bluetooth device counts are tiny and static analysis does not justify adding
  another retained snapshot solely to save that micro-work.
- **WindowPreviewService** already bounds/caches capture ownership and coalesces
  request bursts; no new high-confidence saving was established in this pass.

These are intentionally not promoted merely to increase candidate count.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 24

Baseline: `dev` at `dc6813ff2ebf7fddff2d62c5fe18980918922316`.

This round revalidated four strict-lossless process/collection findings plus one
higher-leverage timer-ownership idea that remains timing-sensitive. Existing
canonical entries for MPRIS grace state and default-off startup probes were
found and deliberately not duplicated.

Current source identities:

- `services/Notifications.qml`: `a05c6744c123d8ed96ee19c8d04cccdbcdeeae0e`;
- `services/Weather.qml`: `53ef5db3a161e6df18a29b1e6a7c6192d2e35a79`;
- `services/ScreenTime.qml`: `1eabb174c464bf0a1e372ebbe8a43f671d2e9d89`;
- `modules/regionSelector/RegionSelection.qml`: `05fe24280c78cfe065dc70660827dedb68f316c0`.

Current MPRIS producer identities were also re-read on this baseline:

- Bar media: `7286bbfaa8bac3b29ee7e818cd937d60405556e8`;
- Vertical Bar media: `f95416165769171cf98031cb115cbfd7dc59cf0e`;
- BarMediaPlayerItem: `bb51644c4558b3362105ea262a1b41c4b865b920`;
- PlayerControl: `db9881c7ed6b20d7b26b1503c9256e8529a3677b`;
- PlayerBase: `df900423be11198b5aaf34474f2c2b2cc8dc7f41`;
- Sidebar MediaPlayerWidget: `e29709da3645e344fd302f2f37ff9d8f58aa4b81`;
- Control Panel MediaSection: `5abcef65e7c66160b3742d9c0abfaf48fb8043a9`;
- LockMediaWidget: `9e5d2434d656457568eac7578973061385ecc4f6`;
- Waffle MediaPaneContent: `dfea7b4e2cfb5a0629f8b77911dd56e7c883c354`;
- VolumeMixer: `612903a3b1d8cdd5ebb933a53abd90c79aa93f7b`.

### R24.1 — Notification timer paths rediscover objects they already own

Current public helper:

```qml
function cancelTimeout(id) {
    const index = root.list.findIndex(notif => notif.notificationId === id)
    ... stop/destroy/null timer ...
}
```

That helper remains useful when a caller owns only an ID, but several internal
paths already own the authoritative notification object.

**timeoutNotification(id)**

It first performs `findIndex`, then immediately calls `cancelTimeout(id)`,
which performs the same lookup again. Preserve the first lookup, retain the
object, cancel its timer directly, then keep popup mutation/list-change/signal
order unchanged.

**timeoutAll()**

`popupList` already contains the live objects. Current code does one ID lookup
per popup solely to reach each object's timer. For P popups in a retained
history list of N notifications, this can add P full-list scans.

**markReadForApp()**

The function already iterates `root.list`. Each matching object again calls the
ID helper, creating a nested scan.

Strict-lossless shape:

- introduce a private object helper such as `_cancelTimerForNotification(notif)`;
- stop, destroy and null the timer exactly as today;
- retain `cancelTimeout(id)` for external/ID-only paths and have it delegate to
  the object helper after its single lookup;
- in object-owning paths call the private helper directly;
- preserve `timeout(id)` signal order and the current two-pass popup clearing in
  `timeoutAll()` unless an oracle explicitly proves phase collapse equivalent.

Required oracle:

- one popup / long history;
- many popups;
- notification without timer;
- missing ID;
- `timeoutNotification`;
- `timeoutAll` exact timeout-signal sequence;
- `markReadForApp` zero/one/many matches;
- final timer=null, popup flags, group snapshots and list-change count.

### R24.2 — Weather primary provider carries an unnecessary Bash process

Current primary path builds:

```qml
const cmd = `curl -s --max-time 15 'https://wttr.in/${query}?format=j1'`
fetcher.command = ["/usr/bin/bash", "-c", cmd]
```

There is no pipe, redirect, conditional or shell expansion needed. The same
Weather service already invokes curl by direct argv for Open-Meteo fallback and
air-quality requests.

Strict-lossless replacement:

```text
["/usr/bin/curl", "-s", "--max-time", "15",
 "https://wttr.in/" + query + "?format=j1"]
```

Keep query calculation and encoding exactly as current source. This removes one
Bash process for each primary request or retry while retaining curl itself.

Required oracle:

- lat/lon request;
- city with spaces and non-ASCII characters;
- request-generation cancellation;
- curl nonzero exit;
- empty/non-JSON/valid JSON;
- three primary failures and existing Open-Meteo bypass window;
- force-refresh during another provider request;
- exact URL argument parity with the shell command's effective curl argv.

The GPS Geoclue path still uses a real parsing pipeline and is not included.

### R24.3 — ScreenTime already owns the file primitive needed for startup

ScreenTime persists today's state with `todayFileView.setText()`, but its startup
read separately spawns:

```text
bash -c 'test -f PATH && cat PATH || echo __NOFILE__'
```

The FileView can own this read as well:

1. when `_loadTodayFromFile()` begins, set `todayFileView.path` to the resolved
   current-day file URL;
2. retain the existing `_loadingToday` guard;
3. on FileView loaded, call `_finishStartupRead(todayFileView.text())` only for
   the active startup load;
4. map FileNotFound to `_finishStartupRead("__NOFILE__")`;
5. map other failures to the same current fallback behavior;
6. remove `startupReadProc` only after start/load failure parity is tested.

Important boundary: do not mechanically replace `rangeReadProc`. It batches
multiple history files into one ordered shell read; converting that path into
many FileViews could increase event-loop work and change ordering.

Required oracle:

- valid/missing/empty/malformed current-day file;
- enable/disable around initialization;
- duplicate load request while pending;
- first persistence after missing/valid startup;
- day rollover;
- non-FileNotFound FileView error;
- exact `ready`, `_todayData`, `_dirty`, session state and `dataChanged()`
  timing/order.

### R24.4 — Region Selector has two shell-string boundaries that do not need shell composition

Recorder start currently emits:

```qml
bash -c "<recordScript> --region '<region>' [--sound]"
```

The same record script is already directly exec'd for `--stop`, so executable
ownership is established. Start can use direct argv:

```text
[recordScriptPath, "--region", slurpRegion]
[recordScriptPath, "--region", slurpRegion, "--sound"]
```

Content-region detection currently uses an outer `bash -c` around a Bash
wrapper. Keep one interpreter because the wrapper is a Bash script, but pass the
script and args directly:

```text
["/usr/bin/bash", find-regions-venv.sh,
 "--image", screenshotPath,
 "--max-width", ...,
 "--max-height", ...]
```

This removes command-string parsing and quoting without changing the wrapper.

Required oracle:

- normal/negative-coordinate region if supported;
- record with/without sound;
- startup failure;
- exact region argument observed by fixture;
- image path with spaces/Unicode;
- exact max-width/max-height values;
- malformed detector output;
- RecorderStatus quick-check scheduling;
- detached process behavior.

Do not apply this mechanically to Copy/Edit/Search/OCR/screenshot capture paths;
those branches use real pipelines/conditionals or depend on temp-directory
ownership.

### R24.5 — Shared MPRIS ticker is higher leverage but not raw-signal-lossless yet

Current repository search still finds ten `positionChanged()` occurrences in the
media path: nine producer-style refresh owners plus LyricsService's listener.
Independent producers use roughly three cadence classes:

- PlayerBase: 500 ms;
- rich media surfaces: 1000 ms;
- Bar/VerticalBar/VolumeMixer: configured resource interval, commonly ~3000 ms.

Multiple visible surfaces can target the same `MprisPlayer`. The fastest timer
already emits that player's signal frequently enough for all attached bindings,
while slower timers can add redundant emissions and wakeups.

Candidate architecture:

- one lease owner per player identity;
- each visible/demanding consumer requests its current interval;
- ticker interval is the minimum active lease;
- zero leases stops the ticker;
- lease acquisition performs the equivalent of current `triggeredOnStart`;
- multi-player surfaces create one logical ticker per player, not one global
  active-player ticker;
- non-MPRIS/YtMusic direct playback paths remain outside this mechanism.

This remains **MEASURE THEN ADAPT**, because independent timers currently have
separate phases and signal count/timing is observable. A shared minimum-cadence
ticker could make positions fresher while still changing listener callbacks.

Capture signal/value traces for Bar-only, popup-only, Bar+popup,
Sidebar/ControlPanel, Lock transition, Waffle Action Center, two-player surface,
open/close, pause/resume and a non-default resource interval before deciding the
parity contract. The correct target is likely visible progress freshness and
bounded wakeups, not identical raw signal count, but that must be explicit.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 25

Baseline: `dev` at `14ca9f7415d6a30e3f8e862820c77ad2247d7b89`.

This round promotes three direct-argv process cleanups, repairs the archived
Settings World Clock ownership gap, and keeps the more ambitious Sidebar World
Clock cadence redesign explicitly oracle-gated.

Current source identities:

- common/Waffle Cloudflare model:
  `0ec62b42e71e805b3c18f2cbfc9ffb5cd78b0e3c`;
- Classic Cloudflare toggle:
  `fee5c5fa1e85ba12daa2fb963fb2d80239558059`;
- Android Cloudflare toggle:
  `6c0e743dd92f2aa3016cc08e108d1576bde025e2`;
- `services/Hyprsunset.qml`:
  `ad37a89247439f2133ba65fb2248b81edbdc90b3`;
- `services/ResourceUsage.qml`:
  `1d8e8693c230ee7450072366557b6070d433af58`;
- `modules/settings/InterfaceConfig.qml`:
  `6f9e2c644aafebc0b3b54ba34df14c272bbbe52d`;
- Sidebar `WorldClockWidget.qml`:
  `5f9272b1aeedc3fa91b76e3a13de150bb6e61829`;
- shared `services/WorldClock.qml`:
  `1260b2d2ed85cf70339c2c8f366c296655dc3c9a`.

### R25.1 — WARP status polling pays an unnecessary shell per refresh

All three WARP toggle families currently use:

```qml
command: ["/bin/sh", "-c", root.warpCliPath + " status"]
```

with a fixed `warpCliPath = "/usr/bin/warp-cli"`. There is no pipe,
redirection, expansion, condition or user-controlled shell composition.

Strict-lossless replacement:

```qml
command: [root.warpCliPath, "status"]
```

Keep the existing 5 s cadence, `triggeredOnStart`, visibility gates and explicit
post-action refreshes. This is not a cadence change; it removes only the
intermediate process.

At a 5 s cadence, one continuously open toggle instance can avoid about twelve
shell launches per minute. That count is structural, not a whole-shell CPU
claim.

Required oracle across common/Waffle, Classic and Android variants:

- installed connected/disconnected;
- daemon unavailable;
- nonzero status exit;
- current connected/disconnected/error stdout forms;
- panel open/close poll start/stop;
- connect/disconnect/service-start actions and immediate refresh;
- exact available/daemon/toggled/status/tooltip behavior.

### R25.2 — Hyprsunset probe can be direct argv without touching state ownership

Current probe:

```qml
["/usr/bin/bash", "-c", "hyprctl hyprsunset temperature"]
```

The Process already owns stdout, timeout and completion/error state. Replace only
execution with:

```text
["hyprctl", "hyprsunset", "temperature"]
```

or a project-standard resolved hyprctl path if PATH ownership is intentionally
made explicit.

Keep the 5 s timeout and every current output check, including empty output,
`Couldn't...` and `6500` inactive interpretation.

This is lower leverage than WARP because probes are not short-cadence periodic,
but it is a clean strict-lossless companion candidate.

### R25.3 — ResourceUsage process-backed GPU probes can drop Bash independently of demand gating

The larger canonical ResourceUsage optimization remains metric-demand gating.
For samples that still occur, NVIDIA and Intel paths currently add one Bash
process each.

**NVIDIA**

Run directly:

```text
nvidia-smi
  --query-gpu=utilization.gpu,temperature.gpu
  --format=csv,noheader,nounits
```

Consume stderr with the existing QML Process facilities. Reproduce current
`head -n 1` semantics by selecting the **first non-empty output row** before
parsing usage/temperature. Do not accidentally average or choose another GPU.

**Intel**

Run directly through timeout:

```text
/usr/bin/timeout 1 <intel_gpu_top> -J -s 500
```

Preserve the one-second hard timeout, 500 ms sampling request and existing
maximum-engine-busy parser.

Required oracle:

- NVIDIA one/multiple GPU;
- empty/malformed/stderr-only/nonzero NVIDIA output;
- Intel valid multi-engine JSON;
- absent busy field;
- malformed/partial output;
- timeout/nonzero/missing executable;
- exact final `gpuUsage`/`gpuTemp` parity and no new stderr noise.

At the default expensive-source minimum around 6 s, direct argv can remove up to
about ten shell launches per minute of active NVIDIA/Intel monitoring. If metric
demand gating eliminates those samples entirely, that larger saving naturally
wins first.

### R25.4 — Settings World Clock still carries N external date children per visible refresh

The Widgets Settings preview refreshes every 20 seconds while its section is
active. Current QML generates Bash source containing one command substitution
per configured timezone:

```text
$(TZ='zone' date '+...')
```

For N zones, each refresh therefore starts one Bash plus N `date` processes.

Current sibling implementations already prove the one-process shape:

- pass each timezone as an argv entry;
- loop over `"$@"`;
- set `TZ="$tz"` for Bash builtin `printf '%(...)T' ... -1`;
- emit one line per timezone.

Strict-lossless Settings migration must preserve:

- 20 s cadence and section visibility gate;
- 12/24-hour formatting;
- positive/negative offsets;
- output protocol `timezone|time|offset`;
- configured order;
- one process owner and current in-flight behavior.

For valid IANA timezone inputs this removes N child processes per refresh. For a
malformed string containing shell-significant characters, current code has
accidental command-string semantics. Safe argv handling is preferable, but the
project should explicitly classify such input as unsupported/sanitized rather
than pretending shell injection side effects are a strict contract.

### R25.5 — Sidebar World Clock process cadence is a larger but timing-sensitive target

The Sidebar widget currently launches one Bash process on every display refresh:

- every 30 s when seconds are hidden;
- every 1 s when seconds are shown.

That process emits time, UTC offset, localized date, day-of-year and hour24 for
all configured zones. The newer shared WorldClock service demonstrates that
timezone offset metadata can be refreshed sparsely while a local `now` value
advances display state in-process.

Candidate architecture:

1. resolve timezone metadata/offsets at startup, timezone changes and a sparse
   safety cadence;
2. tick visible time in-process;
3. when seconds are disabled, use a one-shot timer aligned to the next minute
   boundary rather than fixed 30 s polling;
4. when seconds are enabled, update once per second in-process with no shell;
5. retain the current Bash formatter as deterministic oracle/fallback until
   parity is proven.

Required corpus/oracle:

- UTC;
- DST and non-DST zones;
- +05:30, +05:45, -03:30 and date-line zones;
- minute boundary;
- midnight and year rollover;
- known DST transition;
- 12/24 h and seconds on/off;
- date text, offset label, dayDelta, local highlight;
- system-clock jump;
- timezone config change during an in-flight metadata refresh.

Also record child-process counts for five minutes of sidebar-open operation in
both normal and seconds modes before/after. This remains ORACLE-GATED rather than
declared strict-lossless from static analysis alone.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.


## Research continuation — round 26

Baseline: `dev` at `f5d0806c0bea4f8a9486ce68eb4345872fe30d23`.

This round returns to GPU/RAM residency. The archived media-art decode-size
finding was revalidated against current source. The relevant blobs remain at the
same identities as the original research, and direct foreground/background art
paths still decode without explicit source-size bounds.

Current source identities:

- `modules/common/widgets/MediaCrossSlideImage.qml`:
  `99aacfef3bc12d58ab341e5cd530a5d776263ab6`;
- `modules/mediaControls/presets/CompactPlayer.qml`:
  `4642a25def2eff69ffe450dd09ca336d8f4b68bf`;
- `modules/mediaControls/presets/FullPlayer.qml`:
  `e51ef3d470192a245fe19b26bef3fcca8dc2a98a`;
- `modules/mediaControls/presets/AlbumArtPlayer.qml`:
  `f9c123d6b82073872dcafb7d1b9ba99b4ffeddf9`;
- Waffle Action Center `MediaPaneContent.qml`:
  `dfea7b4e2cfb5a0629f8b77911dd56e7c883c354`;
- Waffle `WidgetsContent.qml`:
  `7919f08b523479a5348660f0b95993d0b0b57544`;
- Waffle lock / safe lock:
  `9cc7e75e21650c26572a17f61140b7d56fd9a734` /
  `86d038cdb3503b0aaae1d3c78b6fdb580263235b`;
- ii `VolumeMixer.qml`:
  `612903a3b1d8cdd5ebb933a53abd90c79aa93f7b`.

### R26.1 — Existing Hadalis media code already proves a conservative decode-bound shape

`MediaCrossSlideImage.qml` requests both transition layers at approximately 2×
logical presentation size. That is a strong in-tree precedent: it keeps the
cross-slide sharp while preventing an arbitrary source cover from dictating
steady decoded texture size.

The current direct-art paths below do not consistently have such a bound.

Confirmed examples on current dev:

- Waffle Action Center foreground art: ~104×104 logical px, no sourceSize;
- Waffle Widgets foreground art: ~108×108, no sourceSize;
- Waffle Lock and Safe Lock media art: 48×48, no sourceSize;
- ii VolumeMixer cover: 96×96, no sourceSize;
- CompactPlayer blurred card background: card-sized, no sourceSize;
- FullPlayer cover-art background: card-sized, no sourceSize;
- AlbumArtPlayer blurred/full cover background: card-sized, no sourceSize;
- Waffle Widgets background art feeding `FastBlur`: panel/card-sized, no
  sourceSize.

Several of these use `cache:false`, so simultaneously resident surfaces are not
relying on the shared Image cache to guarantee one retained representation.

### R26.2 — First promotion phase should target small foreground slots

For fixed/small cover slots, use a conservative policy no more aggressive than
current MediaCrossSlideImage precedent:

```text
requested width  >= ceil(presentation width  × 2)
requested height >= ceil(presentation height × 2)
```

or a DPR-aware physical-pixel equivalent proven at the supported fractional
scales.

Recommended first A/B surfaces:

1. 48×48 Lock/Safe Lock art;
2. 96×96 VolumeMixer art;
3. 104×104 Waffle Action Center art;
4. 108×108 Waffle Widgets foreground art.

These have the cleanest bounded presentation geometry and no blur-radius
interaction.

Keep unchanged:

- source URL/cache-busting;
- `PreserveAspectCrop`;
- async/cache policy;
- opacity/visibility transitions;
- smooth/mipmap flags where present;
- rounded clipping/masks;
- MediaArtwork resolver lifecycle.

### R26.3 — Blurred/card-sized backgrounds need a separate oversampling oracle

The same 2× rule should not be copied mechanically to every blurred background.
Blurred/card-wide sources are sampled across a larger surface and filtering can
amplify decode-size differences.

For CompactPlayer, FullPlayer, AlbumArtPlayer and Waffle Widgets background art:

1. request at least the actual visible card/body dimensions;
2. test 1×, 1.5×, 2× and DPR-aware variants;
3. preserve blur radius/kernel, crop, smooth/mipmap and opacity exactly;
4. choose the smallest target that remains below the project <1% visual budget
   across all required scales/covers.

Do not combine this experiment with opacity-mask removal, blur substitution or
MediaArtwork in-flight deduplication. Isolate decode residency first.

### R26.4 — Why the RAM opportunity is structurally meaningful

Illustrative raw RGBA arithmetic:

- 2000×2000 source: 16,000,000 bytes (~15.3 MiB) of pixel data;
- 216×216 target for a 108×108 2× slot: 186,624 bytes (~0.18 MiB).

This is **not** a claim that Qt/Hadalis RSS or VRAM will fall by exactly that
amount. Decoder implementations can use transient full-resolution buffers,
textures may have alignment/mipmap/effect overhead, and formats differ.
Nevertheless, the steady presentation texture has a large upper-bound gap when
a multi-megapixel cover is displayed in a ~100 px slot.

The opportunity compounds when the same large cover is independently loaded by
multiple `cache:false` surfaces.

### R26.5 — Required visual/resource oracle

Use fixture artwork covering:

- low-resolution source;
- 512 px, 1k, 2k and 4k covers;
- square and non-square ratios;
- high-frequency/text/detail-heavy artwork;
- 1.0 / 1.25 / 1.5 / 2.0 output scale;
- 48 / 96 / 104 / 108 px foreground slots;
- Compact/Full/AlbumArt/Waffle blurred backgrounds;
- track-change/cross-slide state where applicable.

Compare baseline and bounded variants with:

- global normalized pixel-difference ratio;
- detail/edge crop around cover boundaries;
- max per-channel delta;
- subjective cover/text sharpness inspection;
- RSS/PSS under the same visible-surface set;
- renderer texture/GPU memory when available.

Acceptance remains the user's original optimization policy: **<1% measured
visual difference**. If a target exceeds that budget, increase the decode bound
or reject it for that surface.

### R26.6 — Existing bounded paths are non-targets

Do not reduce these from static reasoning:

- `MediaCrossSlideImage.qml`: already uses 2× bounds;
- Waffle MediaOSD: already bounded;
- existing explicitly bounded wallpaper/avatar images;
- Clipboard decoded images: intrinsic decoded dimensions participate in current
  preview-sizing regression contracts and are a separate non-candidate.

No whole-Hadalis RAM/GPU percentage is claimed without measurement.


## Research continuation — round 27

Baseline: `dev` at `74701f6fc1e79a4259378bd0f9d4e5adce7971cd`.

This round promotes the remaining wallpaper/private-cache findings that were
still archive-only and carries the Niri focus-only idea into the active ledger
at its correct MEASURE/PROVE confidence. Current source identities still match
the archived research baselines.

Current source identities:

- `services/Wallpapers.qml`: `162dc98dcb742d7dec918a1da01659ef64265330`;
- `modules/common/widgets/ThumbnailImage.qml`:
  `64386a41505f5b1a3dc4942b2a549b04d0f0cf59`;
- `scripts/thumbnails/thumbgen.py`:
  `fdc9ce7e4557a4296e45e8d25aea9101caf90fa1`;
- `services/Wallhaven.qml`: `ce28a24564a964df2de7748080f8f7893e788ef8`;
- `modules/background/Background.qml`:
  `29bd40236ba9579077d361fb1012d4f994ef4a3a`;
- `services/CompositorService.qml`:
  `017c1405d39a2a2f954bb8d90d350ca4d4356f1d`;
- `services/NiriService.qml`:
  `4c8194493fd380bf0ad8c51bc62990ad0c232738`.

### R27.1 — Wallpapers private bookkeeping currently pays reactive-copy cost without reactive consumers

Two wallpaper bookkeeping structures are imperative sets in practice:

```qml
property var _singleThumbPending: ({})
property var _knownThumbnailOutputs: ({})
```

Current enqueue/remember paths clone the entire object, mutate one key, then
reassign. Drain/forget paths clone again before delete.

Repository-wide current-source search returns each private name only from
`services/Wallpapers.qml`. No binding, `Connections`, change handler or external
consumer depends on object identity. Public access to known outputs is through
imperative helpers such as `hasKnownThumbnail()`, `rememberThumbnail()` and
`forgetThumbnail()`.

Strict-lossless direction:

- set/delete keys directly on the private object;
- retain `_singleThumbQueue` order and current one-process-at-a-time ownership;
- retain duplicate-request suppression and every success/failure callback;
- do not mutate `videoFirstFrames` in place because that map deliberately wakes
  presentation bindings.

For n distinct pending keys, copy-on-write insertion alone copies approximately
0+1+...+(n-1) existing keys; draining repeats shrinking copies. This is a clear
allocation/GC shape even though individual maps are session-bounded by actual
requests.

Required oracle:

- repeated/distinct thumbnail requests;
- queue success/failure interleaving;
- pending membership before/during/after completion;
- remember/forget/hasKnownThumbnail parity;
- empty/malformed paths and multiple sizes;
- explicit assertion that no private-map Changed signal is observed.

### R27.2 — Batch thumbnail generation still leaves per-delegate existence-process fan-out

`ThumbnailImage.reloadThumbnail()` checks the shared known set first. If the
expected path is not known, an instantiated delegate can still launch:

```text
test -f <expected-thumbnail>
```

The bulk Python generator already centralizes expensive image/video creation and
emits machine progress, but its current token is only progress:

```text
PROGRESS completed/total FILE source
```

It is not proof of output readiness. `make_thumbnail()` can return false for an
already-fresh cache item and for failure, while the parent currently ignores the
result.

Strict-lossless protocol extension:

1. after every worker result, Python checks expected-output existence in-process;
2. emit a machine token such as `READY <source>` or `FAILED <source>`;
3. QML converts READY source+size to the exact expected thumbnail path and calls
   `rememberThumbnail()` before existing source notification/reload;
4. affected delegates then satisfy the shared known-set branch with no child
   `test`;
5. FAILED never enters the known set and retains today's fallback/retry path;
6. the shell fallback generator can keep end-of-directory reload checks until a
   comparable per-file success protocol exists.

Required fixture:

- already-fresh item;
- newly generated image;
- newly generated video;
- intentional decode/generation failure;
- partial gallery with mixed results;
- exact visible state/retry parity;
- process-count trace for representative gallery open.

### R27.3 — Video first-frame pending map has a success-side stale key

`ensureVideoStill()/first-frame` ownership keeps `_ffPending[videoPath]` as an
in-flight/no-retry marker. Current source does not remove the key after success.

Once success publishes `videoFirstFrames[videoPath]`, the stale pending entry
cannot change later answers because success cache is consulted first. Deleting
the pending key at successful publication is therefore behaviorally redundant
state removal.

Do **not** extend this cleanup to failure. Today a failed path leaves pending
true for the session and suppresses repeated ffmpeg attempts. Clearing it on
failure would be a product/correctness change and could create retry loops.
If retry behavior is ever repaired, model explicit failed/backoff state instead
of silently repurposing the optimization.

### R27.4 — Wallhaven's bounded private caches clone themselves on every insertion

Current private caches include bounded suggestion/count/tag structures with
limits up to 256. `_boundedCacheInsert()` performs:

```text
clone cache object
clone key-order array
remove existing key from order
write value
append key
shift/delete until within limit
reassign both properties
```

Current repository search finds the cache structures only inside
`services/Wallhaven.qml`. Reads are imperative request/cache checks; there is no
presentation binding on cache identity.

An in-place helper can therefore preserve exact LRU semantics:

1. if key already exists, remove its first key-order occurrence;
2. write/update value;
3. append key as newest;
4. evict from the front until at limit;
5. keep TTL/request queue/network behavior unchanged.

This removes O(K) object+array copying for each insert/update. Filling a bounded
cache from empty creates O(K²) cumulative copied entries today, even though K is
capped.

Required oracle:

- empty insert;
- same-key refresh moves key to newest position;
- eviction exactly at/past limit;
- repeated same key;
- TTL hit/miss;
- suggestion/count/detail request dedup;
- no cache/key-array Changed observer.

### R27.5 — Background wallpaper-size cache is the same safe class at lower leverage

Background owns a private 64-entry LRU for `magick identify` results. Successful
probes clone both object and key array before publishing one record. Current
repository search finds no reader outside `Background.qml`, and local reads are
imperative cache lookups.

Use the same in-place LRU rule as R27.4 while keeping exact ordering and
64-entry eviction. This ranks lower because wallpaper dimension writes are much
less frequent than Wallhaven tag enrichment.

Do not generalize in-place mutation to reactive/public maps such as
`videoFirstFrames`, ScreenTime data, WindowPreview cache or GlobalStates lease
maps. The qualification is specifically **private imperative cache with no
identity/change observer**.

### R27.6 — Niri focus-only fast path remains measurement-gated

Current Niri compositor wiring schedules `scheduleSort()` for both:

```qml
onWindowOrderChanged()  -> scheduleSort()
onActiveWindowChanged() -> scheduleSort()
```

and the 100 ms coalesced timer republishes:

```qml
sortedToplevels = NiriService.sortToplevels(ToplevelManager.toplevels.values)
```

A pure focus change should not alter membership, app id, title, workspace or
layout order; it should only alter which enriched item reports `activated`.
Structurally, rebuilding the already matched array by `niriWindowId` would be
cheaper than rerunning full matching.

Do not implement this from static reasoning alone. Quickshell may also emit
`ToplevelManager.toplevels.valuesChanged` on activation changes, and that signal
already schedules the full sort. If so, a separate focus fast path can be
redundant or race a structural update.

Measurement/oracle:

- instrument ordinary focus switches;
- count/order `activeWindowChanged`, `windowOrderChanged` and
  `ToplevelManager.valuesChanged`;
- record whether sort timer is scheduled once/coalesced or repeatedly;
- only run a focus-only refresh when no full structural sort is already pending;
- compare complete `sortedToplevels`: order, `_sourceKey`, `niriWindowId`,
  title/appId, action functions and activated flags;
- open/close/title/app/workspace/output changes must always keep the full path.

This remains lower priority than already source-proven Niri app-id bucketing and
private layout-sort reuse.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without measurement.
