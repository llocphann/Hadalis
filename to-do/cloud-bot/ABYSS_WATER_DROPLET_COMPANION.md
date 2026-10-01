# Cloud Bot — Abyss Water Droplet Companion

Status: **in progress — renderer/attachment proof implemented, production integration disabled pending evidence**  
Scope owner: Cloud Bot reasoning + source changes; Local Bot only runs explicit deterministic validation jobs.  
Target shell family: **Abyss first**.  
Primary constraint from maintainer: **do not implement this as a static image mascot. The Water Droplet Companion must be a genuinely animated, continuously alive runtime companion. Prefer Rust for the continuously running backend.**

## Product goal

Build a small water-droplet companion that belongs visually and behaviorally to the Abyss panel family. It should feel like part of the same deep-water material system rather than a PNG/GIF pasted onto the shell.

The companion must remain lightweight enough to live for the entire desktop session. Its personality comes from motion, gaze, squash/stretch, surface tension, specular movement, ripples and reactions to shell/system events. It must not depend on continuous AI inference, network access or a high-frequency scripting loop.

## Current-repo constraints observed before planning

- Hadalis production native helpers already live in the Rust workspace under `native/`; Rust is the production backend and Python is a rollback path for migrated helpers.
- Abyss already owns a procedural/material vocabulary through `modules/abyss/looks/AbyssStyle.qml`, `AbyssField.qml` and `AbyssField.frag(.qsb)`: deep surface, raised surface, electric accent, specular highlight, glow, blur/refraction controls and motion gating.
- The existing mascot settings path is pose/manifest based and can resolve PNG/GIF artwork. That architecture may remain for the existing mascot and other panel families, but the Water Droplet implementation must **not** reuse the static pose-file rendering model.
- `Appearance.animationsEnabled`, effects gates, Game Mode and performance settings already exist and must remain authoritative.
- Quickshell already supports long-lived `Process` consumers and stdin-enabled process interaction patterns, so a low-frequency/event-driven Rust bridge can be investigated before introducing a new heavyweight IPC stack.

## Non-negotiable implementation rules

- [ ] **No static Water Droplet art pack.** Do not implement the character as PNG, GIF, WebP animation, sprite sheet, APNG, video, Lottie export, pre-rendered frame atlas or a collection of pose images.
- [ ] The droplet body and face are runtime-rendered from primitives/procedural geometry/shaders.
- [ ] Rust owns long-lived behavior/state/scheduling where that materially reduces wakeups, allocations or QML/JS timer work.
- [ ] Do **not** move GPU drawing into Rust merely because Rust is preferred. Qt Quick/QML/ShaderEffect should remain the renderer when it is the lowest-overhead path; Rust should feed compact state/parameters rather than pixels.
- [ ] No 60 Hz IPC stream. QML interpolates visual motion locally; Rust emits state changes and low-rate physics targets/events.
- [ ] No busy loop while hidden or idle.
- [ ] Hidden companion must approach zero render work and near-zero backend wakeups except scheduled/event-driven work.
- [ ] Respect `Appearance.animationsEnabled`, reduced-motion, effects settings, Game Mode/fullscreen policy, battery policy and suspend/resume.
- [ ] No continuous LLM/personality inference. Personality is a deterministic/local state machine. Optional AI commentary, if ever added, stays outside the core animation loop.
- [ ] Multi-monitor behavior, shell reloads, suspend/resume and compositor restarts must not leave orphan processes or duplicate companions.
- [ ] Existing Kira/static mascot behavior must not be deleted as part of the first Abyss implementation. Migrate only after live acceptance proves the new companion can replace the required surfaces.

## Proposed architecture

### 1. Rust runtime: `inir-companiond`

Preferred direction: add a small dedicated workspace member such as `native/inir-companiond/` rather than putting a perpetual companion loop into an unrelated helper.

Responsibilities:

- own the companion state machine;
- aggregate low-frequency system/shell events;
- schedule blink, micro-expression, idle curiosity, sleep and reaction windows;
- maintain deterministic spring targets/behavior parameters;
- select reaction intent without choosing rendered frames;
- maintain per-monitor placement intent and visibility policy;
- persist only durable user settings/state that actually needs persistence;
- expose health/version/protocol information;
- sleep on event sources/timers instead of polling;
- survive normal shell UI recreation without resetting personality every time, if lifecycle testing shows that is desirable;
- exit cleanly when the Hadalis session ends and never multiply on shell reload.

Rust should **not** render the droplet, rasterize frames or send images to QML.

Candidate state model:

`Dormant -> Idle -> Curious -> Engage -> React -> Settle`

with orthogonal dimensions instead of an explosion of hard-coded poses:

- visibility: hidden / peeking / present;
- attention: neutral / pointer / active-surface / notification / media / task;
- mood: calm / happy / curious / focused / sleepy / concerned;
- activity: idle / thinking / working / success / warning / error;
- motion energy: 0..1;
- gaze target: normalized x/y or semantic target;
- body targets: squash, stretch, lean, tip bend, bob, ripple strength;
- face targets: blink, eye openness, pupil offset, mouth curve;
- accent/event pulse.

This produces many combinations without storing pose artwork.

### 2. Bridge/protocol

First candidate: one long-lived Rust child process owned by a QML service/bridge, using newline-delimited compact JSON or another existing native protocol pattern over stdio.

Requirements:

- event/state messages only, not per-frame updates;
- bounded messages;
- schema version field;
- monotonic sequence number;
- QML can send semantic events such as hover/click/surface-open instead of raw mouse samples when possible;
- process restart with exponential backoff and duplicate-process protection;
- no disk-file polling for animation state;
- no shelling out once per animation/event.

Before implementation, audit whether extending `inir-protocol` or another existing native transport gives lower lifecycle complexity. Do not introduce D-Bus/socket infrastructure solely for this feature unless the stdio bridge cannot meet lifecycle or bidirectional requirements.

### 3. QML procedural renderer

Proposed location: `modules/abyss/companion/`.

Potential components:

- `AbyssCompanion.qml` — public host and placement/input contract;
- `CompanionBridge.qml` — Rust process/protocol bridge;
- `WaterDropletBody.qml` — procedural body;
- `WaterDropletFace.qml` — eyes/pupils/mouth/highlights;
- `WaterDropletRipple.qml` — contact ripple/ground response;
- `WaterDropletMotion.qml` — local interpolation/springs from Rust targets;
- one compact fragment shader if SDF/refraction/specular quality materially beats pure Shapes.

Rendering direction:

- one droplet silhouette derived from an SDF, Shape path, or similarly cheap procedural representation;
- surface color comes from Abyss tokens rather than hard-coded mascot blues;
- reuse `AbyssStyle.surfaceDeep`, `surfaceRaised`, `accent`, `specular`, `glow`, effects gates and wallpaper/material context where practical;
- specular highlight and internal caustic-like movement are procedural and slowly animated;
- face geometry is vector/procedural, not texture artwork;
- contact shadow/ripple uses at most one cheap procedural pass;
- avoid an extra full-screen wallpaper capture/FBO just for the companion;
- avoid particle systems for normal idle behavior. Small secondary droplets should be generated sparingly and bounded if retained at all.

## Animation language — “alive”, not looping artwork

The base idle animation must never look like a GIF loop. Use layered motions with different periods plus event-driven interruption:

- slow surface-tension breathing;
- tiny vertical bob;
- tip sway/bend;
- asymmetric squash/stretch with spring settling;
- eye blink with non-uniform intervals;
- gaze drift toward pointer/active content;
- pupil catchlight motion;
- slow specular/caustic drift across the body;
- subtle base ripple after movement;
- reaction pulse when a task/notification/system event arrives;
- settle animation after every stronger reaction;
- sleep behavior after prolonged inactivity;
- wake behavior on meaningful activity.

All motion should be parameterized so reduced-motion can lower amplitude/rate without substituting pre-rendered art. When animations are fully disabled, the renderer may hold a procedural still state; it must still not fall back to a static image asset.

## Interaction model

Initial safe scope:

- hover: eyes/gaze follow within a bounded region;
- click/tap: short squash + ripple + happy/curious response;
- optional drag: reposition only when explicitly enabled/editing, not normal accidental pointer movement;
- panel/surface events: glance or lean toward the active surface;
- task completion: brief success reaction;
- warning/error: concerned expression without distracting full-screen motion;
- media activity: subtle rhythm response only if a cheap existing signal is available; do not run another audio analyzer;
- idle: autonomous micro-behavior;
- fullscreen/Game Mode: hide or enter minimal mode according to existing policy.

The companion must never randomly rearrange user UI by default.

## Abyss placement

First integration should be a **panel-sitter / edge companion**, because it can visually share the Abyss perimeter without creating another independent floating-window design language.

Placement requirements:

- obey current output ownership;
- understand top/bottom/left/right Abyss edges;
- use existing Abyss geometry/placement helpers rather than inventing another screen coordinate system;
- do not block Screen Edge hover transfer or connected popup hit testing;
- input region should be limited to the actual companion bounds;
- preserve nearby-corner and popup clearance;
- hide/reflow when the available edge segment becomes too small;
- scale correctly at fractional display scale.

Later, the same procedural renderer may be embedded in Dashboard/empty states/AI surfaces, but do not duplicate independent animation engines per surface.

## Runtime/performance strategy

The companion is expected to exist for the whole desktop session, so performance is a release gate.

### Backend

- event-driven Rust; no fixed-rate busy loop;
- use monotonic timers;
- coalesce bursts of events;
- bounded queue;
- deterministic PRNG seed/state for idle scheduling where useful;
- no heap churn in the hot idle path;
- no filesystem polling;
- no subprocess spawn per event;
- hidden/quiet state should wake only for the next scheduled semantic action or an external event.

### Renderer

Use adaptive visual cadence:

- hidden: no animation frame work;
- visible calm idle: target ~24–30 fps only if the procedural effect actually needs continuous frames;
- direct interaction/strong transition: allow display-rate animation temporarily;
- battery/reduced-motion: lower motion amplitude and cadence;
- Rust target updates should usually be much lower frequency than render frames; QML interpolates locally.

Do not enforce these numbers blindly. Measure actual frame pacing and lower cadence further if visual quality is unchanged.

### Initial qualification budgets

These are **targets to measure**, not claims about current performance:

- idle hidden companion: effectively zero GPU animation work;
- Rust daemon idle CPU should be close to scheduler noise on maintainer hardware;
- no sustained wakeup loop when nothing changes;
- visible idle should not create measurable shell jank or missed frames during popup/sidebar animation;
- memory must remain bounded across 8+ hour runtime, repeated show/hide, shell reload and monitor changes;
- no growing QML object count, message queue or Rust allocation trend.

Record baseline and after-implementation measurements before setting a hard percentage threshold.

## Configuration/settings plan

Abyss settings should expose only useful controls:

- Enable Water Droplet Companion;
- size/scale;
- placement edge/automatic;
- interaction level;
- reaction intensity;
- idle personality intensity;
- follow-pointer/gaze toggle;
- battery saver behavior;
- event reaction toggles;
- reduced-motion behavior;
- debug overlay only in developer/debug mode.

Do not expose dozens of animation constants to normal users. Keep tuning values internal or grouped under Advanced.

## Existing mascot migration policy

The current mascot system can remain intact during development.

For Abyss Water Droplet:

- do not load `assets/images/mascot/manifest.json`;
- do not resolve `inir-mascot-*.png` or `*.gif`;
- do not model reactions as a filename switch;
- do not require the optional mascot art pack.

After live acceptance, decide whether:

1. Abyss uses Water Droplet while ii/Waffle keep Kira; or
2. the procedural companion becomes the common companion engine with family-specific skins.

Do not make that migration decision before runtime/performance acceptance.

## Implementation phases

### Phase 0 — audit and contract

- [ ] Re-audit latest `dev` before implementation.
- [ ] Map every existing mascot host, command, setting and event source.
- [ ] Map Abyss placement/hit-test ownership and identify the safest panel-sitter host.
- [ ] Audit Quickshell long-lived Process stdin/stdout semantics and shutdown behavior.
- [ ] Decide whether `inir-companiond` is standalone or part of an existing native binary.
- [ ] Write a small versioned protocol contract before UI implementation.
- [ ] Establish CPU/RSS/wakeup/frame-time baseline with companion disabled.

### Phase 1 — Rust core

- [ ] Add Rust crate/workspace wiring.
- [ ] Implement typed state machine and semantic event model.
- [ ] Implement monotonic scheduling and idle sleep.
- [ ] Implement bounded event coalescing.
- [ ] Implement deterministic unit tests for transitions/timers.
- [ ] Implement protocol parser/serializer and malformed-input handling.
- [ ] Implement graceful shutdown/restart/duplicate-instance policy.
- [ ] Add structured diagnostics suitable for local validation.

### Phase 2 — procedural renderer

- [ ] Implement droplet silhouette without image textures.
- [ ] Implement face/gaze/blink procedurally.
- [ ] Implement spring squash/stretch/lean/tip motion.
- [ ] Implement specular/caustic drift using Abyss colors.
- [ ] Implement contact ripple.
- [ ] Implement local interpolation so protocol is not frame-rate coupled.
- [ ] Gate shader/effects by existing performance/effects policy.
- [ ] Prove hidden state stops continuous rendering.

### Phase 3 — Abyss integration

- [ ] Add one canonical Abyss companion host.
- [ ] Integrate edge/output geometry.
- [ ] Integrate hover/click without stealing unrelated panel input.
- [ ] Integrate panel-open/notification/task/media/system semantic events.
- [ ] Add Game Mode/fullscreen/suspend behavior.
- [ ] Add settings and safe defaults.
- [ ] Ensure shell reload does not create duplicate daemon instances.

### Phase 4 — optimization

- [ ] Profile backend CPU, wakeups and RSS.
- [ ] Profile QML scene graph/frame timing/GPU effects.
- [ ] Remove unnecessary timers and bindings.
- [ ] Ensure no 60 Hz backend-to-QML state traffic.
- [ ] Ensure no image decode/cache path is used for the Water Droplet.
- [ ] Tune animation cadence separately for idle/interacting/battery/reduced-motion.
- [ ] Stress 8+ hour runtime and repeated state changes for leaks.

### Phase 5 — validation

- [ ] Add contract test that Water Droplet runtime does not reference static pose image formats or mascot manifest paths.
- [ ] Add Rust unit/integration tests.
- [ ] Add lifecycle test for one daemon only across shell restart/reload.
- [ ] Run `bash scripts/validate-maintainer-local.sh` on the exact SHA.
- [ ] Live Niri test: primary + secondary monitor, fractional scaling, edge changes, fullscreen, Game Mode.
- [ ] Live suspend/resume.
- [ ] Live popup/sidebar hover-transfer test with companion present.
- [ ] Record visual acceptance for idle, hover, click, working, success, warning/error, sleep/wake.
- [ ] Compare disabled vs enabled CPU/RSS/frame-time before closing the task.

## Local Bot deterministic validation jobs to prepare later

Do **not** dispatch these until implementation exists and a SHA is pinned:

- build the Rust workspace in release mode;
- run companion Rust tests;
- run protocol/lifecycle contract tests;
- run the static-art prohibition contract;
- collect bounded process CPU/RSS/wakeup diagnostics;
- collect bounded Quickshell logs;
- run canonical maintainer validation.

Cloud Bot remains responsible for interpreting evidence, diagnosing failures and deciding changes.

## Acceptance definition

This task is complete only when all of the following are true:

- Water Droplet is rendered procedurally and has no PNG/GIF/sprite/video pose dependency.
- It visibly behaves as a living character through layered non-loop-like motion and reactions.
- Rust owns the long-lived state/scheduling backend and sleeps efficiently.
- QML/ShaderEffect owns visual interpolation/rendering without frame-rate IPC.
- Hidden state produces no continuous visual animation work.
- No duplicate daemon/process appears across shell reloads.
- Abyss panel interaction and popup geometry remain correct.
- Game Mode, reduced-motion, battery policy, suspend/resume and multi-monitor behavior are correct.
- Long-run memory/resource usage is bounded.
- Exact-SHA local validation passes.
- Maintainer accepts the live appearance and animation quality.

## Out of scope for the first implementation

- continuous generative-AI personality;
- speech synthesis/listening;
- networking/cloud dependency;
- physically accurate full fluid simulation;
- per-pixel Rust software rendering;
- replacing every existing mascot surface in one patch;
- a second independent desktop-widget/window framework just for the companion.

## Design principle

**Rust makes the companion cheap to keep alive; Qt Quick makes it cheap to draw.** The backend decides *what the droplet is doing*, while the renderer decides *how that intent moves smoothly on screen*. The Water Droplet should feel native to Abyss because its shape, light, refraction, accent, motion gates and placement are derived from the existing Abyss material/geometry system—not because a blue mascot image was placed beside it.


## Checkpoint — 2026-10-01 renderer/attachment proof

- Source base: `209cd2a21212b3f0d02db9488228d8567558960a`.
- Added a development-only procedural Wull renderer under `modules/abyss/companion/`; it uses Qt Quick Shapes/primitives and Abyss theme tokens, with no image asset path.
- Added an edge-aware attachment host plus a top-edge proof scene. It is intentionally not wired into production shell ownership yet.
- Added `docs/WULL_COMPANION_PROTOCOL_V1.md` to freeze the low-rate semantic stdio contract before daemon implementation.
- Next gate: run deterministic QML/static contract checks and capture a bounded live screenshot/Quickshell diagnostic proving render + attachment before production integration.
- Reference-asset note: the current task file contains no linked image URL/path at this HEAD; no repository reference image could be resolved from the task itself.


## Checkpoint — 2026-10-01 Quickshell-native proof recovery

- Phase: **Phase 2 renderer/attachment proof; production integration remains disabled**.
- Current development proof commit: `822a19f1086a967a75e1e939c3a540eb0e4cb473`; the proof harness now follows Hadalis standalone-window conventions with a Quickshell `ApplicationWindow`, while `AbyssCompanion.qml` and `WaterDropletBody.qml` remain unchanged.
- Prior local evidence: `JOB-WULL-DIAG-004:0` / `:1` on source `2e41e0aeca6917c6cdb3f42c075106b1912a65d2` established only an unclassified standalone-launch failure (exit 46); `JOB-WULL-DIAG-006:0` on source `9d7032f45775498b4d639ecd3c144462da932c85`, observed at Unix `1790803241`, failed with classifier exit 48 and did not match the explicit Quickshell-string hypothesis. `JOB-WULL-DIAG-005` was invalid before action execution and supplies no runtime evidence.
- Test dispatched: `JOB-WULL-PROOF-007`, introduced by commit `92091826c525e34365cba0fe6b33aaa5406a9e81`, is pinned to base/test source `822a19f1086a967a75e1e939c3a540eb0e4cb473` and invokes the repository-confirmed `qs -n -p` standalone path before bounded runtime/service/screenshot diagnostics.
- Blocker: no Quickshell-native receipt or live visual evidence has passed yet; therefore renderer attachment is not accepted and Wull is not wired into production ownership.
- Next: inspect `JOB-WULL-PROOF-007`; if the exact pinned SHA loads under Quickshell, use its bounded diagnostics to advance renderer/attachment proof. If it fails, diagnose only from its published evidence before any further source change.

## Checkpoint — 2026-10-01 committed renderer/attachment mapping proof

- Phase: **Phase 2 renderer/attachment proof structurally qualified; visual acceptance still pending; production integration remains disabled**.
- CURRENT audited/tested path: root-level `wullProof.qml` commit `12575c626658bb73f5c716b28531c7561eef23f1`, validation job commit/source `c9b725f2aa4eb4f426d89a51004c6b5e55d7b96e`, receipt published at `4e20fda46df9faad552c60ab1a0821e5283b8f66`.
- Diagnosis evidence: `JOB-WULL-DIAG-010:1` proved the generated minimal standalone window survived while the nested Wull entry matched the QML-error classifier; `JOB-WULL-DIAG-011:1` then passed with a temporary root-level wrapper and required Niri to map the Wull proof title.
- Source fix: `37e69d6963762c745c8ca5451e41b075d2fe1ea6` added the missing `QtQuick.Controls` import to the development proof surface; `12575c626658bb73f5c716b28531c7561eef23f1` added the permanent repository-root `wullProof.qml` entry so `qs.modules.*` resolves against the Hadalis shell root.
- Proof PASS: `JOB-WULL-PROOF-012:0` and `:1` both exited 0 on source `c9b725f2aa4eb4f426d89a51004c6b5e55d7b96e`; the committed proof stayed alive and Niri mapped `Wull procedural attachment proof`.
- Scope boundary: this PASS covers Quickshell load + Niri window mapping of the procedural renderer/attachment scene only. It does **not** claim screenshot/appearance acceptance, popup hit-test acceptance, canonical maintainer validation, performance qualification, or production ownership.
- Phase 1 audit started after the proof: the native workspace currently has `inir-protocol` plus five binaries and no companion daemon; `docs/WULL_COMPANION_PROTOCOL_V1.md` freezes newline-delimited JSON state/event messages with version and monotonic sequence requirements.
- Blockers before production integration: bounded visual/screenshot acceptance of the proof scene, Rust companion core/bridge implementation and tests, hidden-idle/resource evidence, settings/policy wiring, and later canonical/live desktop validation.
- Next: implement the smallest standalone `inir-companiond` Rust core milestone (typed protocol + deterministic state machine/scheduling tests) without wiring production QML ownership yet; keep visual proof acceptance as a separate gate before Phase 3 production attachment.

## Checkpoint — 2026-10-01 Rust companion core dispatched

- Phase: **Phase 1 Rust core implementation + exact-SHA validation; production integration remains disabled**.
- Renderer prerequisite remains structurally qualified: `JOB-WULL-PROOF-012:0` / `:1` passed Quickshell load plus Niri window mapping for the committed root-level proof. This is not visual/maintainer acceptance.
- Core implementation commit: `5a54934a83169c570988417f121b298f1002f69a`. Added standalone workspace member `native/inir-companiond` with typed protocol/state, monotonic input sequencing, bounded 8 KiB line intake, bounded 64-record stdin channel, deterministic semantic reaction/scheduling state machine, hidden state with no scheduled wakeup, malformed-input recovery, and unit tests. `Cargo.lock` is pinned and the existing installer still does not copy/package `inir-companiond`, so Wull is not enabled in production.
- Concurrent repository work after the core commit touched MEGAcmd rather than Wull. Validation is therefore pinned to a newer exact source rather than assuming the core SHA remained HEAD.
- `JOB-WULL-CORE-013` was recorded `status=invalid` with `actions=[]`: a concurrent commit landed between the read and the job-file commit, so its declared `base_sha` did not equal the job commit's first parent. It produced no runtime/test evidence and will not be reused.
- Active validation: `JOB-WULL-CORE-014` was introduced by `d24eb5f9a65e401c75a747bf4518679a7c585b52` with first parent/base `6dadecde913e067c7910404563e82080010f4931`. It runs `cargo test --locked -p inir-companiond` plus a deterministic stdin/stdout protocol smoke for hidden -> show -> click -> hide.
- Blocker: `JOB-WULL-CORE-014` has no result receipt yet. No Rust PASS is claimed until its exact-source actions return successfully.
- Next: inspect only `JOB-WULL-CORE-014`. On PASS, continue with the QML stdio bridge and low-rate state interpolation while keeping production ownership disabled; on failure, diagnose only from the worker evidence before changing source.

## Checkpoint — 2026-10-01 companion runtime shipping dispatched

- Phase: **Phase 1/3 boundary — Rust backend is qualified for development proof and now prepared for current-source runtime shipping; production companion ownership remains disabled by default**.
- Evidence already present on current `dev`: `JOB-WULL-CORE-017:0` exited 0 at Unix `1790832251` and `:1` exited 0 at `1790832252`, both on source `dee44282f1a489ecf7d36a0f194f30ace42f9e1f`. `JOB-WULL-BRIDGE-018:0` exited 0 at `1790832564` and `:1` at `1790832570`, both on source `fdc984e80dd8c7e4b469a9435f8888c9719b5002`; that proof required exactly one `inir-companiond` while the Wull window was alive and zero after shutdown. `JOB-WULL-VISUAL-019:0..3` all exited 0 on source `ad7c90470c97e35537145a14386c384f29e99046` at Unix `1790832794..1790832795`, including a private bounded screenshot/process/resource capture. These receipts prove execution/capture success, not maintainer visual acceptance.
- Runtime-shipping source commit: `10489a9deed25fdc1d1f85ae7d32eca8744ee107`. It adds a Rust-only `scripts/native-dispatch companion` route that `exec`s `inir-companiond` in place, adds the daemon to current-source install/Nix/rolling-Arch packaging contracts, and lets `CompanionBridge.qml` opt into the native dispatcher without changing the development proof override.
- Safety boundary: no Abyss production host or user-facing enable default is changed by this milestone. Wull remains off unless a later guarded production host explicitly opts into the dispatcher.
- Validation dispatched as `JOB-WULL-RUNTIME-020`, pinned to base/source `10489a9deed25fdc1d1f85ae7d32eca8744ee107`: companion unit tests, release build, dispatcher version smoke, native-production contract, packaging contract, and static Nix contract.
- Next: inspect only `JOB-WULL-RUNTIME-020`. On PASS, add the single shared Abyss production bridge/host behind `abyss.companion.enabled=false`, then validate one-daemon lifecycle, output/edge placement and input-mask behavior before any default enablement.

## Checkpoint — 2026-10-01 guarded production attachment dispatched

- Phase: **Phase 3 guarded Abyss integration; Wull remains disabled by default and NOT_COMPLETE**.
- `JOB-WULL-RUNTIME-020` receipt is determinate, source `8d6974ef9fe172644aa4b6acf4d4b5cffd3458f0`. Actions `:0` through `:4` all exited 0 at Unix `1790834433..1790834443`: companion Rust tests, release build, `native-dispatch companion --version`, native-production contract, and non-Nix packaging contract. Action `:5` exited 1 at Unix `1790834443`; it was the dedicated static Nix contract.
- Repository audit of the exact failed source found the first missing Nix assertion is the pre-existing Workflow-parser gate `lib.optionalString withWorkflowParser`. The same marker was already absent at pre-Wull source `dc3d097efcf08edc09da52fceeaa0bd93346fbf3`, so this is not a Wull regression. Per `AGENTS.md`, dedicated Nix validation remains deferred/non-blocking for the maintainer workflow.
- Guarded host source commit: `8a1023b6e368b8fc600e5b75e5e0e85aa748a86c`. It adds `abyss.companion` config with `enabled=false` and `soundEnabled=false`, one shared `CompanionBridge` for the Abyss perimeter, one output-selected `AbyssCompanion` host, fullscreen/Game Mode hiding, companion-only input masking, and reactive backend start/stop. No static mascot asset path is introduced.
- Added `scripts/test-wull-production-contract.py` and attached it to `make test-perimeter-contracts`; the contract checks default-off/sound-off configuration, a single shared backend, one output-selected host, input-mask containment, native dispatcher routing, and static-art prohibition.
- Validation dispatched as `JOB-WULL-HOST-021`, pinned to base `8a1023b6e368b8fc600e5b75e5e0e85aa748a86c`. It runs the Wull contract, perimeter regression suite, exact-SHA companion Rust tests, native-production contract, and `scripts/validate-maintainer-local.sh --current-repo`.
- Blockers after static/local validation: live production-host proof with the option temporarily enabled, one-daemon lifecycle across shell reload, multi-output/edge and popup hit-test evidence, battery/reduced-motion tuning, Settings UI, long-run resource qualification, and maintainer visual acceptance.
- `JOB-WULL-HOST-021` receipt is now present. On source `6b45bb195e78f3797bab22950b16eda33c800d06`, action `:0` (Wull production contract) exited 0; action `:1` (`make -s test-perimeter-contracts`) exited 2. The public result records only exit codes and output checksums; its bounded raw stdout/stderr are private. The failing perimeter subcheck and root cause are **undetermined**. Subsequent `dev` commits through `c1df9d31f23cda86324eef47255e7b1f8c73347a` affect automation/reporting, not Wull host source; older PASS does not certify current HEAD.
- Manual continuation: no automation dispatch or job replay. On an exact, clean `dev` SHA, run the perimeter component checks separately (without unnecessary duplicates), record each exit code and only publish a sanitized, SHA-pinned summary under a unique `docs/` path. Keep raw diagnostics local. Do not change runtime behavior solely to satisfy a stale static assertion, and do not enable production Wull before host/lifecycle/live validation.
- Next: read the manual diagnostic receipt and inspect the identified failing component. If it needs private evidence not safely publishable, request only that evidence; otherwise fix the proven issue and rerun the required exact-SHA gates before guarded live-host proof.


## Checkpoint — 2026-10-01 manual perimeter root-cause isolation

- On exact source `f3a1faaf3c2ea955818759a1cb777dc92272872a`, committed sanitized report `docs/wull-manual-perimeter-20261001T111318Z-ecdc18de-f3a1faaf3c2e.json` records 9/10 component checks PASS, including Wull production/default-off contract. Only `perimeter-shared-and-source` failed (exit 1), classified as the **source** sub-contract. These are historical results, not a current-HEAD acceptance.
- Read the current and pre-Wull `modules/screenCorners/ScreenCorners.qml`: both omit `GlobalStates.openOrbit(` and explicitly assign overview priority to `NiriService.isOverviewHotCornerActive(outputName, cornerName)`. Existing `scripts/test-quick-notes-corner-contract.py` explicitly rejects the retired Orbit entry. `scripts/test-perimeter-source-contracts.sh` contradicted both by requiring the removed Orbit call. This stale regression assertion is one definite source-contract failure; do not infer that no further assertions may fail until a new test completes.
- Source-only test fix: commit `ea46df3955acb9b6c92d6c47103affa40f9c42ba` replaces the retired Orbit requirement with assertions for compositor-owned Niri overview priority and continued absence of Orbit routing. It makes **no production runtime/Wull change**; Wull remains disabled by default.
- Next gate: test the corrected source contract on the current exact `dev` SHA, then run relevant perimeter, Rust, native shipping and canonical maintainer acceptance without claiming success from older SHA. Keep raw logs local and publish only a sanitized SHA-pinned report. After PASS, proceed to guarded live host, one-daemon and output/input lifetime evidence.

## Checkpoint — 2026-10-01 manual perimeter regression PASS

- Independent manual diagnostic receipt `docs/wull-manual-perimeter-20261001T112408Z-e91462e7-642c676c2ce0.json` on exact source `642c676c2ce03ad5635c7fbbe3f278a1ce5da206` records **10/10 PASS** (Iris production, input lifecycle, Quick Notes, Wull production, placement, family, routes, settings, shared/source and retirement). The formerly failing source sub-contract exited **0** following the retired-Orbit/Niri-priority assertion correction. Logs remain private; the committed sanitized report exposes per-check exit codes only.
- This resolves the known perimeter contract blocker for that exact SHA, **not** canonical acceptance of later dev commits. The report explicitly marks canonical validation and live visual acceptance `not_run`.
- Next gate: on one clean exact-SHA local checkout, independently record Wull Rust tests, locked release build, dispatcher version smoke (using the binary built for that SHA), native packaging contract, and the canonical `scripts/validate-maintainer-local.sh --current-repo` result. Keep verbose logs local; publish only sanitized status and exact SHA. Do not enable Wull by default or claim multi-output/lifecycle/live qualification without real host evidence.

## Checkpoint — 2026-10-01 guarded-host unexpected-exit audit

- Static lifecycle audit (pending live verification): `CompanionBridge.qml` sets `ready=false` and resets `inboundSeq` when `backendProcess.running` becomes false; `onExited` also clears only `ready`. Neither path clears its last `visibility`. Meanwhile `AbyssPerimeter.qml` binds the companion's `reveal` to `companionBridge.visibility` and includes a revealed, interactive host in the native input mask. Thus an unanticipated daemon exit **can** leave a stale visible companion and interactive region until another valid state update or an explicit backend-disable reset. This is a source-level risk, not a reproduced live failure.
- Post-qualification fix gate: ensure host rendering and input fail closed whenever the bridge is not `ready` (or clear stale visibility on unexpected exit), while preserving the queued show intent for a permitted restart. Add a targeted contract for unexpected exit, restart initial handshake and disabled-by-default behavior. Run the relevant current-SHA contract, native/Rust gate and canonical validation after any runtime change. Do not silently count pre-change perimeter results as acceptance.
- The manually prepared `scripts/wull-manual-qualification.py` has **no committed report** as of this audit. Do not treat local execution, release build, dispatcher smoke or canonical validation as complete without a SHA-pinned receipt. Its source-sensitive review guard intentionally requires review before accepting future runtime/contract changes.

## Checkpoint — 2026-10-01 native qualification receipt and fail-closed host fix

- New sanitized native/canonical result: `docs/wull-manual-qualification-20261001T115741Z-f9da4543-6d7eb8d2a831.json` on exact source `6d7eb8d2a83143b5437c4e1d0a2a0570f7048870`: 5/6 independent checks PASS (Rust unit, locked Rust release, dispatcher version, native production contract and packaging metadata). `canonical-maintainer-validator` exited 1 after 501.06 seconds. The public receipt omits the specific failing canonical check, so root cause is **unknown**; do not attribute this failure to Wull or MegaQML without evidence. The historical 10/10 perimeter PASS applies to `642c676c2ce03ad5635c7fbbe3f278a1ce5da206`, not the revised Wull source.
- A bounded source audit exposed a real guarded-host risk on unexpected daemon exit: bridge `ready=false` did not independently gate host rendering or its companion input region. Atomic source/test commit `7bb1f99b0cd932c7bb0e50888ae19c982d7e1ec3` now requires `companionBridge.ready` in `companionHostActive`, immediately hides the Wull host while unready, and checks the reset/re-handshake contract. The queued `requestedVisible` intent remains intact; default enabled/sound values remain false. **Static source inspection only**; new code has not earned local or live PASS.
- To diagnose the historical canonical exit without rerunning an expensive validator or exposing private raw logs, `scripts/wull-canonical-failure-receipt.py` reads only the matching previous local validator's final summary, publishes allowlisted failed check names/groups and numbers to a unique `docs/` JSON report, and retains verbose logs locally. No automation/background workers. If no matching old local log exists, report that prerequisite rather than inventing findings.
- Next: read the new sanitized canonical-failure classifier receipt, determine whether the actual failing check is Wull-related, and make only justified fixes. Then perform fresh current-SHA perimeter/native/canonical validation on the revised host; separate live daemon exit/restart, single-process, input region, multi-output, reduced-motion/resource and maintainer visual acceptance gates remain open. Do not enable Wull by default.

## Checkpoint — 2026-10-01 canonical failure classification and focused follow-up

- Original prior canonical failure (source `6d7eb8d2a83143b5437c4e1d0a2a0570f7048870`) has a sanitized classification receipt at `docs/wull-canonical-failures-20261001T121228Z-05455b4b-6d7eb8d2a831.json`: **293 checks run; 257 passed, 35 failed, 2 skipped**. It identifies one Wull-specific failure in `scripts/test-wull-manual-perimeter.py`; that file is a manual branch-checking diagnostic/report publisher, not a standalone regression and cannot succeed when the canonical validator invokes all `test-*.py` on a detached clone. Other 34 failures include Abyss/UI and other components; this report records names/exit codes only, not their causes. No failed `scripts/test-wull-production-contract.py` entry was recorded. Do not infer current-HEAD PASS or attribute unrelated regressions to Wull.
- Canonical discovery fix `9976e08d7db2537af747541afdba987515635b9b` skips **only** the manual Wull publisher while retaining ordinary tracked Python syntax and the automated Wull production test. The production contract now guards this exclusion against accidental removal. Canonical validation remains **NOT PASSED** until the other actual failed cases are diagnosed and a new exact-SHA run succeeds.
- Guarded post-exit source fix `7bb1f99b0cd932c7bb0e50888ae19c982d7e1ec3` remains pending new execution evidence. To avoid repeating a known-failing global canonical run while qualifying Wull-specific changes, `scripts/wull-manual-qualification.py --focused` was added in `17f7a94f9f232cf79c2deb2a8b86edc7675c83ee`. It runs Wull production + perimeter regression, companion Rust tests + release build, exact-build native dispatcher version, native production contract and packaging metadata; bounded logs stay local, the unique sanitized report is SHA-pinned on `dev`, and its `canonical_validation` field explicitly records `not_run`.
- Next: inspect focused receipt first. If it passes, keep canonical global acceptance and live desktop acceptance as separate open gates; if it fails, diagnose only identified checks and rerun after any further fixes. Then validate daemon exit/restart, single-process ownership, output/edge/input-region interaction and visual/resource acceptance on a live Niri host. Never enable Wull by default without those gates.

## Checkpoint — 2026-10-01 focused post-fix qualification PASS; isolated lifecycle probe prepared

- Committed receipt `docs/wull-manual-qualification-20261001T121835Z-f53b4dbe-cf28b0fb2202.json` on exact source `cf28b0fb22026cb0fdd3eb0d7178d0b6787de7c8` records **7/7 PASS**: Wull production contract, complete perimeter regression, companion Rust tests, locked release build, exact-build native dispatcher smoke, native production contract, and package metadata. It includes the fail-closed host readiness fix `7bb1f99b0cd932c7bb0e50888ae19c982d7e1ec3`. These are local/static checks, not a live daemon crash, visual, or multi-output proof.
- The historical 35-failure canonical result remains outstanding. Excluding the manual Wull publisher from the detached-clone test discovery via `9976e08d7db2537af747541afdba987515635b9b` addresses one *identified* harness mismatch, not the other failure causes. Do not mark global canonical accepted.
- New isolated diagnostic groundwork on `dev`: `scripts/wull-fixtures/bridge-exit/shell.qml` and `fake-dispatch.py` instantiate a copied real CompanionBridge under a private offscreen Quickshell configuration and simulate one deliberate fake-backend exit followed by a re-handshake. `scripts/wull-manual-bridge-smoke.py` runs disabled/default-off and exit/restart scenarios, writes bounded private logs and a SHA-pinned sanitized `docs/wull-bridge-isolation-*.json` receipt. The fake dispatcher is confined to a temporary fixture; no production/user configuration or real vendor daemon is enabled. This **is not yet run or accepted**.
- Next: inspect the isolated bridge receipt. On PASS, advance to a separately authorized, bounded **real Niri guarded production host** check for mapped output, input-mask non-interference, backend exit/restart and one-process lifecycle; then visual/resource acceptance and global canonical recovery. If Quickshell is unavailable, retain an explicit inconclusive receipt rather than calling it a pass. Maintain default-off Wull and do not alter `stable`.

## Checkpoint — 2026-10-01 isolated bridge PASS and inherited-daemon-override guard

- Sanitized isolated Quickshell receipt `docs/wull-bridge-isolation-20261001T122458Z-4ce0b139-b7077ea8950d.json` was published as commit `31939f07b190f81f514bd1f70e1315f86b8a99cb` after a fast-forward-only retry. On source `b7077ea8950dc8fccb673adaabf1a6c8d0f496de`, both tests passed: disabled/default-off spawned **0** fake daemons and forced fake-daemon exit plus re-handshake spawned **2** as intended. The proof used private offscreen Quickshell, not the real Niri production host. The historical focused Wull contract/native receipt remains 7/7 PASS on its own exact earlier SHA.
- New source-audit finding after the bridge proof: a globally inherited `INIR_COMPANIOND` environment override could bypass the production host's disabled-by-default dispatcher setting because `CompanionBridge.backendCommand` prefers `binaryPath`. Fix commit `d7d6290bc9e27b17c18c9576fc94ff12e470cca5` explicitly gates **production** `binaryPath` behind `root.companionEnabled`, preserving standalone proof overrides. An assertion in the production contract protects this source boundary. This is a proactive default-off fix, not a confirmed observed live failure.
- Test expansion commit `22cd281781b0d221ad92a2165e0730609a843354` adds isolated `disabled-override` to the two original bridge cases and advances the reviewed Wull focused qualification baseline. The third case intentionally sets `INIR_COMPANIOND` while disabled and requires **0** fake daemon starts, in addition to checking `backendEnabled=false`.
- Publication hardening commit `ba6e1d8a273f41454dcfa721acc812efe8a7d85c` adds bounded retry for both manual runners on a moving `dev`. Before retrying, it refetches and audits the remote and rebases/amends **only the single unpublished sanitized report commit**, updating its publication parent. Never force push, rewrite shared history, publish raw logs, or run background jobs.
- Next exact-SHA gate: execute the expanded 3-case isolated bridge smoke and the 7-check focused Wull native/perimeter qualification against the *new* guarded source; publish both sanitized reports. Until fresh results arrive, the new environment guard and third fixture remain unqualified. Global canonical and separately observed live Niri production-host, multi-output/input-mask, one-real-daemon lifecycle, resource and visual acceptance remain outstanding; Wull defaults remain off.

## Checkpoint — 2026-10-01 guarded source PASS and real-Niri standalone probe ready

- The guarded inherited-override Wull source now has **two fresh sanitized qualification receipts**: isolated offscreen Quickshell `docs/wull-bridge-isolation-20261001T123951Z-d8b180d7-8e4288351a78.json`, on source `8e4288351a784e5bb3e2591ee8ea8a01fde6a03c`, confirms **3/3 PASS** (default-off: 0 fake backends, default-off with inherited `INIR_COMPANIOND`: 0 fake backends, forced fake exit/restart: 2 starts). Subsequent focused native/perimeter receipt `docs/wull-manual-qualification-20261001T124007Z-e662331b-ba17bae9f6ef.json`, on source `ba17bae9f6ef3ab25445e08cecea7074050d8574`, confirms **7/7 PASS** (production/perimeter, companion Rust unit and release, dispatcher, native shipping and packaging). Source changes between the exact SHAs were limited to reports, not Wull runtime. Both receipts explicitly leave canonical and live production-host acceptance `not_run`.
- Next distinct gate: `scripts/wull-manual-niri-proof.py` introduced in `a4153d4840b72d1f9ad76c072a546d3d8f44dbda`. Run it manually from a clean `dev` checkout in the owner's actual Niri session. It builds a **private exact-SHA** release `inir-companiond` and launches a single bounded `qs -n -p wullProof.qml` child, uses Niri's JSON window inventory to detect a newly mapped `[present]` proof window and `/proc/*/exe` to require one private daemon, samples bounded RSS, and verifies both owned child and new window shut down after cleanup. It isolates its XDG config/data/cache/state directories, keeps raw logs private, and may publish PASS/FAIL/INCONCLUSIVE as `docs/wull-niri-proof-*.json`. It never changes existing user shell config or enables production Wull and never runs as a persistent worker. No successful execution or live result is claimed yet.
- This is **standalone proof**, not an Abyss production-host test, not input-mask/hotplug/multi-monitor/fractional-scaling or visual-quality acceptance. Global canonical still has unrelated failures. On a valid standalone PASS, proceed to a separately controlled production-host session and live renderer/performance observations; do not turn Wull on by default or modify `stable`.

## Checkpoint — 2026-10-01 real Niri proof PASS and bounded daemon restart under test

- Committed `docs/wull-niri-proof-20261001T124709Z-033217ce-ede831d004b6.json` as `6d49fb08df49c40c4544d75fac7b9e9564e8345c`. On exact source `ede831d004b6e94031a983e8a66d27d9cc92c69e`, **standalone** real Niri/Quickshell plus privately built Rust daemon **PASS**: release build exit 0; newly mapped `[present]` proof window; one private daemon; owned daemon stopped; own window unmapped; peak sampled daemon VmRSS **2672 KiB**. Raw observations remain local. Not a production Abyss host, input-mask, multi-output, visual, or canonical acceptance. MegaQML-only changes between this source and its publication do not change Wull runtime.
- Source lifecycle audit found the production bridge still lacked *automatic* process recovery after unexpected termination despite being fail-closed and preserving `requestedVisible`. The design TODO explicitly calls for exponential backoff and duplicate-process protection. `af2565174916c12a8360b2566ba755d00c050777` adds at most **four automatic attempts** at 500/1000/2000/4000 ms while backend remains enabled; stops pending attempts on explicit disable; suppresses late child stdout while disabled/unready; and resets its retry budget only after 30 seconds of stable handshake. Both process termination callbacks schedule through one guarded timer to prevent double starts. A depleted budget remains stopped until explicit disable/re-enable. The production host's ready-based opacity/input-mask guard and default-off configuration remain in place.
- The same commit extends the inert fake daemon with an always-failing crash-budget mode, and the isolated QML fixture with automatic single-crash recovery and exhausted-budget assertions. Followup `b7af0aedc98f556f3b938adf72e2de1183114b3d` advances source guards and adds **five** manual bridge matrix cases: disabled, disabled with inherited environment override, explicit exit/restart, automatic exit/restart, and bounded repeated crash. The reviewed focused native/perimeter and bounded real-Niri proof runners are re-anchored to the new source. These **new source and test changes have not earned a PASS yet**; earlier 3/3, 7/7 and real-Niri proof receipts are historical exact-SHA evidence only.
- Next execute the updated five-case offscreen bridge, seven-check focused native/perimeter, and bounded real-Niri standalone proof in **one** manual command; publish three sanitized receipts on `dev`. If the new retry mechanism fails, investigate the specific failing check first. The canonical global failures and real production Abyss host, layer/input-mask, output/hotplug, visual/resource gates remain separate. Never enable Wull by default or touch `stable`.

## Checkpoint — 2026-10-01 bounded recovery 5/5, native 7/7 and real Niri PASS

- The new bounded automatic recovery logic has now been **run and verified**. Sanitized bridge report `docs/wull-bridge-isolation-20261001T125520Z-89265409-521100717e61.json`, exact source `521100717e61c85038a5457d8f4b196f92cceb21`, records **5/5 PASS**: disabled and inherited binary override each started zero fake children; explicit exit/restart and automatic exit/restart each started two; crash-budget started exactly five children (initial + four retries) and stopped. The two newer reports are `docs/wull-manual-qualification-20261001T125539Z-47a9f48d-6d30f92e3661.json` (on `6d30f92e366170e25907744c0fbbc8495f552d27`, **7/7 PASS**, production/perimeter/Rust/release/dispatcher/packaging) and `docs/wull-niri-proof-20261001T125559Z-3e25f617-c33efac2dc54.json` (on `c33efac2dc54b8e45d2220575321339bab36cb20`, **PASS** real Rust daemon + standalone Quickshell on Niri, mapped window, one owned daemon, cleanup verified, peak sampled RSS 2628 KiB). All three runs include the automatic-recovery production source `af2565174916c12a8360b2566ba755d00c050777`; intervening non-Wull changes are MegaQML and report-only. These results do **not** certify live Abyss production host, user visual quality or canonical validation.
- Next uncovered recovery boundaries: (a) turning Wull off **while the first 500 ms retry timer is pending** must cancel the retry and create no more children; (b) exhausting the four-retry budget must allow a **deliberate off/on** to start a fresh attempt without any unrequested infinite loop. The fixture/fake-only commit `6403d2b8e2fcdafd150e7f5274026df788359f67` introduces two scenarios, and `926ad5a83720521f99438f684448efb5b0051029` advances the SHA-guarded runner to **seven cases**, allowing only known sanitized markers/counts. Wull production code is unchanged after the prior 5/7/live PASS receipts. **New tests have not yet run**: publish the new seven-case receipt before marking either new recovery boundary PASS.
- Once that new bridge receipt has been reviewed, address safe, independently observable **production Abyss layer-host** correctness on a temporary desktop session without overriding existing user config, hijacking unrelated shell ownership or assuming that a standalone proof verifies input masks. Canonical global recovery, output/hotplug, suspend/reload, user visual comparison and final opt-in remain open. Wull remains disabled by default; `stable` is untouched.

## Checkpoint — 2026-10-01 recovery 7/7 PASS and shared production host policy awaiting qualification

- Latest bounded offscreen bridge receipt `docs/wull-bridge-isolation-20261001T130310Z-5cbc6880-655bcf554c6b.json` was published in `2e6100d034312d487109f5dc84565473d1f78a22` for exact source `655bcf554c6b836013aad4101bdddea2e106727c`: **7/7 PASS**. The new `disable-pending` case observed only one fake daemon and canceled the pending retry. The new `budget-reset` case observed six starts (initial, four bounded retries, one deliberate re-enable); all original five scenarios also passed. It does not claim production input-mask or Niri host acceptance.
- Source integration `a7c7c6f794c54d41912c21de51a2c89061437b62` replaces three duplicated production-host predicates with pure `modules/abyss/companion/WullHostPolicy.js` functions for target-output and readiness ownership, input activation, and bounded `alongPosition`. The latter preserves normal-scale placement but centers on a tiny logical output when normal margins cannot fit. The production `AbyssPerimeter.qml` consumes all three helpers, and production contract + `scripts/test-wull-host-policy.py` assert the wiring and exercise many output, readiness, input and viewport permutations. Production Wull defaults remain disabled. This source refactor has **not yet earned new local or live PASS**.
- Isolated fixture and runner commit `f6008cdaebf465ae7065c0e822f141b92d2f25f2` imports the **same** production JS policy next to the copied real bridge. Seven scenarios now also test per-output ownership and immediate logical input release upon the fake backend exit. Followup `be532047ac933cc3411e78e97ea0e2cdad66e343` re-anchors the focused qualification and guards the new dynamic host-policy test against unreviewed edits; focused scope is now **8 checks**, up from seven. These new reports are **pending execution**, not PASS.
- Next: run the new output/input policy test, 7-case offscreen bridge and 8-check focused qualification on an exact clean `dev` SHA and inspect the sanitized receipts. The subsequent distinct milestone is a safely controlled **actual production Abyss PanelWindow** desktop test of layer mapping/input passthrough, then multiple live outputs/hotplug and maintainer visual review. Standalone Niri proof and synthetic host logic cannot substitute for those. Global canonical is still not accepted, and `stable` remains untouched.

## Checkpoint — 2026-10-01 shared host policy 7/7 + focused 8/8; isolated production-layer probe staged

- Verified two new sanitized runtime/local receipts on `dev`: `docs/wull-bridge-isolation-20261001T131232Z-16cc10f7-15c32970f8e5.json` on exact source `15c32970f8e508c12ae070bd4d0b88f5721d4e4c` is **7/7 PASS** with the *real shared* Wull production JS host policy imported into isolated Quickshell alongside the real CompanionBridge. `docs/wull-manual-qualification-20261001T131857Z-49f7237b-970b8d65e791.json` on exact source `970b8d65e791e4b9c7a90b0f8d39851a29b2ef34` is **8/8 PASS**, including the new executable output/input/viewport host policy and the existing seven native/perimeter/package checks. Intervening changed files are MegaQML and result documents, not Wull production sources. These results are not physical pointer pass-through or live Abyss production PanelWindow evidence.
- New opt-in proof groundwork on `dev` in commit `ae14ff81a35400019cd4bd5ca0efe29be49f4b5d`: `scripts/wull-fixtures/production-layer/shell.qml` instantiates the **unmodified actual** `AbyssPerimeter`; `scripts/wull-manual-production-layer.py` creates isolated XDG directories, per-test empty optional panel configuration, isolated session D-Bus, private exact-source Cargo target and bounded child Quickshell sessions. It first checks Niri's JSON layer inventory and **does not launch** any temporary layer if namespace `hadalis:abyss-perimeter` is already in use. The runner requires `--acknowledge-temporary-layer`, tests disabled with an inherited daemon path before any enabled run, checks one mapped production layer per active output, no unrequested layer keyboard focus, one private daemon only when enabled, and own child/layer cleanup. Failures/inconclusive preflights are separately classified and sanitized under `docs/wull-production-layer-*.json`; raw logs and private config remain local. `scripts/test-wull-production-layer-contract.py` provides a syntax/source-safety contract. **These new fixtures/runner have not yet been executed; no live production host PASS is claimed.**
- Crucial limit: Niri's layer listing reports namespace/output/layer/keyboard interactivity, **not the exact pointer-input mask, rendered Wull visibility or user visual quality**. Even if the isolated production layer receipt passes, independently inspect actual pointer pass-through, edge placement/reveal, animations, multi-monitor hotplug, shell reload/suspend, and visual/resource outcomes before approving normal production enablement. Global canonical validation remains open. Do not change default-off Wull or `stable`.

- Follow-up guard `850691d85660620fa1ccc34fafba886630b7478c` hardens the same not-yet-executed opt-in runner: an alternate allowlisted GitHub push URL is permitted, but only one push URL; the private diagnostic directory must remain **outside the checkout**; and source auditing permits precisely this one reviewed runner revision. Its updated production-layer safety contract remains a required prerequisite. The earlier probe must not be described as an executed or accepted host test.

## Checkpoint — 2026-10-01 active Abyss prevents parallel production probe; read-only inventory prepared

- Opt-in live temporary PanelWindow receipt `docs/wull-production-layer-20261001T140538Z-94d94872-a1a043e6cc3f.json` on source `a1a043e6cc3f18c11deea4d6a77fc6e9fa34b3c0` is **INCONCLUSIVE** with preflight reason `abyss_perimeter_already_running`. Niri observed one active output; the safety guard correctly refused to launch a second `hadalis:abyss-perimeter` layer. Its `tests` array is empty. Do not call this PASS or FAIL, do not recommend killing the user's running shell, and do not claim production Wull, pointer mask, visual, canonical, or hotplug acceptance.
- Follow-up `aff8e8b3b2f805cdbaf40d77630378ac48cc8506` adds `scripts/wull-manual-existing-layer.py` and `scripts/test-wull-existing-layer-contract.py`. This **read-only** alternative samples Niri `layers` and `outputs` four times, counts the already running `hadalis:abyss-perimeter` surfaces per active output and observable keyboard mode (without storing device names), and classifies stable complete coverage, duplicate layer inventory or inconsistent observations. It **never** opens another shell, reads or changes user configuration, enables Wull, sends pointer/keyboard input or claims running shell binary-source identity. It still publishes only a unique sanitized report on a clean `dev` checkout with bounded fast-forward retry.
- Required next gate: run its local synthetic `scripts/test-wull-existing-layer-contract.py` followed by `python3 scripts/wull-manual-existing-layer.py --observe-current-session`, inspect the SHA-pinned `docs/wull-existing-layer-*.json` report, and address any real layer-inventory anomaly. This verifies compositor-visible active-layer topology only; Niri layer inventory **cannot** observe exact pointer masks or whether Wull is enabled. The previous guarded standalone real-Niri proof remains valid for its earlier SHA; live production Wull enablement and interactive/visual acceptance still require a separately controlled session. Global canonical red and `stable` untouched.
