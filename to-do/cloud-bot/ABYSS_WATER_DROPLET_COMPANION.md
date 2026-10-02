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

## Checkpoint — 2026-10-01 live existing Abyss 4/4 PASS and guarded nested Niri milestone

- Live read-only observation on source `7029ce5618b08dda817774fd3f1fa1e3ccad6903` published as `docs/wull-existing-layer-20261001T141653Z-d6ec2c70-7029ce5618b0.json`, commit `bec798f633aa500ca7a0ba527143b895d4dba241`: **PASS, four consecutive samples** at 500 ms intervals. Niri reported exactly one active display and exactly one existing `hadalis:abyss-perimeter` layer on that display; no duplicates, no inactive-output/orphan layers, and observed keyboard interactivity `none` in all four samples. It is strictly the currently running shell's *compositor-visible layer topology*, **not** verification of which Git SHA is running, whether Wull is enabled, pointer pass-through, live Wull rendering, or multioutput behavior. The earlier side-by-side isolated production test properly returned INCONCLUSIVE because that one running layer exists.
- A controlled alternative is now staged on `dev` by `fe4fa400ec9ac1a643c858b697ae515c735d523a`: `scripts/wull-manual-nested-niri.py` plus an inert `scripts/test-wull-nested-niri-contract.py`. With explicit `--acknowledge-nested-niri`, the coordinator uses an empty private `NIRI_CONFIG` to run exactly one owned nested Niri **inside a normal Wayland window**, detects a *different* Wayland display and IPC socket, checks a usable nested output and absence of existing Abyss layers there, then invokes the *existing reviewed* two-phase real production PanelWindow Rust/Quickshell runner against only the nested socket. It preserves host `WAYLAND_DISPLAY` and `NIRI_SOCKET` in separate variables, does not kill or reconfigure the running user's compositor/shell, waits for private child and nested cleanup, verifies the host output count is unchanged, retains unfiltered logs locally, and may publish a sanitized `docs/wull-nested-niri-*.json` report. If nested Winit Niri or its layer IPC is unavailable, mark INCONCLUSIVE, not PASS. These new scripts **have not yet run**; their exact-SHA syntax/inert contract check must precede the real invocation.
- Even an isolated real production PanelWindow PASS on nested Niri would only qualify compositor mapping, requested keyboard mode, disabled default-off with inherited executable override, enabled one-owned-real-daemon lifecycle and cleanup in that nested environment. It does **not** certify the existing live user shell's source identity, physical mouse hit-test/pass-through, edge visuals, hotplug/multiple real outputs, compositor restart/suspend, or full canonical validation. Keep production defaults off, keep private diagnostic paths out of Git, and never alter `stable`.

- Follow-up safety fix `c5b1ec2709c72c91d100f92ca1451dd20c4edbce` guards the nested compositor's process-group cleanup: never signal a numeric group if the owned Niri parent already exited and the ID could have been reused. The source audit permits exactly the reviewed initial runner and this one safety revision, and pins the initial blob. This opt-in nested proof still has no execution report or live pointer acceptance yet.

## Checkpoint — 2026-10-01 nested production host PASS; standalone hidden-idle resource gate staged

- The nested Niri controlled production-host receipt is now **PASS**, not merely planned: `docs/wull-nested-niri-20261001T142650Z-d57cd21c-569f1b863af2.json` on exact source `569f1b863af2fcd45a2ffcfc6bdce1a8b7982ce8` reports distinct private Wayland and Niri IPC endpoints, one nested output, no pre-existing Abyss layer, child exit 0, complete owned nested compositor cleanup and unchanged host output count. Its linked independent child receipt `docs/wull-production-layer-20261001T142651Z-8275d996-569f1b863af2.json` reports **2/2 PASS** on the actual unchanged `AbyssPerimeter` PanelWindow in nested Niri: disabled despite inherited executable override (zero private daemon), and enabled with exactly one owned real Rust daemon. Both phases observed one production layer per active output, no unwanted keyboard focus, full private process/layer cleanup. All these claims are limited to their source SHA and single nested output; native pointer pass-through, running host source identity, physical multioutput/hotplug, visual quality and global canonical are still not measured. Keep Wull default-off and never touch `stable`.
- A separate Phase 4 backend resource qualification is staged on `dev` at `165a1f8541654e666477e3ea7ed64ae4774a8e6f`: `scripts/wull-manual-idle-resource.py` and its inert `scripts/test-wull-idle-resource-contract.py`. It uses an exact-SHA locked private Rust release build, exercises actual versioned show/hide handshakes and records **13 /proc samples across 60 seconds of hidden idle**. Its explicit provisional budgets are peak RSS <=32768 KiB, growth <=4096 KiB, hidden CPU <=0.5 s and zero unsolicited stdout reads; sample count, observed measurements, one-owned-process and full cleanup are reported without exposing raw logs. These are conservative *test thresholds*, not an established production long-run memory target. The script uses a unique private Cargo target and refuses to keep diagnostic files inside the checkout. **It has not yet run**, so do not promote Phase 4 resource acceptance until its SHA-pinned sanitized receipt is checked.
- Run the inert contract and 60-second native idle probe only, rather than repeating already PASS 7/7 bridge, 8/8 focused native/perimeter or nested host acceptance. The next independent gate after this measurement is a deliberately authorized visual/pointer test of the actual production Wull against an interactive underlay in nested Niri; available compositor layer inventory does not establish pointer pass-through or accurate hit regions. Another distinct gate is long-run shell/reload/suspend and physical multioutput qualification; global canonical failures remain separate.

## Checkpoint — 2026-10-01 hidden-idle 3/3 PASS; four-edge clickable geometry pending

- Three independently published, exact-source private Rust hidden-idle receipts **PASS 3/3**: `docs/wull-idle-resource-20261001T143515Z-2d8edc1d-b2d6e7728e65.json` on `b2d6e7728e6549ac6431e85a560ad1ba88b445b2` (peak **2664 KiB**), `docs/wull-idle-resource-20261001T143822Z-88f9b83e-61839bc12d27.json` on `61839bc12d27a605d277aadccea3fc1cfdf5d64b` (peak **2680 KiB**) and `docs/wull-idle-resource-20261001T144009Z-a1ec8630-5a3a2526aeac.json` on `5a3a2526aeace69a5f7a3e72448eaa6a6654d086` (peak **2672 KiB**). Each accepted initial hidden/show/hide, sampled 13 times over 60 seconds, observed **0 KiB RSS growth**, **0.0 s measured hidden CPU**, **zero unsolicited hidden stdout**, exactly one private daemon while active and none after cleanup. No production Wull/native code changed between these source SHAs; newer shared commits are unrelated MegaQML/results. This is one-minute *standalone Rust* evidence only; not whole-Quickshell resources, unlimited uptime, input or visual acceptance.
- The production Abyss compositor mask currently uses the *entire* `AbyssCompanion` item, while its hover/click handlers live in the smaller `WaterDropletBody` child. A tighter mask could avoid capturing unrelated edge clicks, but **must not be applied blindly** because the clickable child rotates for left/right/bottom edges; this is a source-observed possible optimization, **not** a reproduced hit-test defect. Geometry diagnostic `b3479455e05a5b60ffce850a27cba5aecbf0bda4` introduces `scripts/wull-fixtures/footprint/shell.qml`, `scripts/wull-manual-footprint.py`, `scripts/test-wull-footprint-contract.py`. The private offscreen fixture measures real, unchanged QML child corners mapped onto four host orientations and publishes bounded bounding-box and overhang facts only. Safety update `5c16f743bc2f79d0aae479fdf1ddb0c3c417c047` pins reviewed source and escalates teardown on a hung fixture. **No four-edge execution receipt yet**; production mask has not been changed.
- Run the inert contract then `python3 scripts/wull-manual-footprint.py --observe-footprint` from one clean `dev` checkout. Use that receipt to decide a region geometry change; mapped boxes alone are **not a physical pointer-pass-through test**. A subsequent independently controlled compositor pointer interaction, maintainer visual comparison, full-shell long-run measurement, physical multioutput/reload/suspend and canonical-wide validation remain open. Wull defaults off; never alter `stable`.

## Checkpoint — 2026-10-01 4-edge footprint exposes overflow; centered prototype pending execution

- Real unmodified QML geometry receipt `docs/wull-footprint-20261001T145330Z-44ee61ee-34b14b3d8f6e.json` on exact source `34b14b3d8f6e4d1986dd528d7c8b51e9856b0004`, published as `a5345a22a1e7be2b1ee324cf48df5071112b4649`, **PASS only for four-edge diagnostic execution**, not for containment or hit-testing. Offscreen `AbyssCompanion` measured mapped `WaterDropletBody` boxes: top (18,6,76×92) fully contained; right (-43,74,92×76), bottom (18,98,76×92), left (49,74,92×76) **protrude beyond their 98×112 or 112×98 host boxes**. These three overflow flags mean a blind reduced compositor hit region could clip interaction. The existing production full-host mask may also capture non-body space; actual compositor mouse pass-through has not been measured. Do not call the previous PASS a four-edge layout or pointer PASS.
- Candidate experiment commit `2aa15b2963597cf3eaccc7ef0d660062f8db4bbb` adds `scripts/wull-fixtures/centered-prototype/shell.qml`, `scripts/wull-manual-centered-prototype.py` and `scripts/test-wull-centered-prototype-contract.py`. A separate isolated **offscreen-only** fixture instantiates four instances of the unchanged real production `AbyssCompanion` and temporarily resets each actual child `WaterDropletBody` to `anchors.centerIn = host` with `transformOrigin = Item.Center` rather than its current bottom anchor and bottom rotation origin. The bounded exact-source runner checks whether all four mapped child bounds stay in their host with less than 90% host-area occupancy, publishes only sanitized numbers/flags and leaves all production QML, input masks, live compositor and settings unchanged. The candidate is **NOT YET RUNTIME-QUALIFIED**; the conceptual center-origin placement is an experiment, not a committed production fix.
- Next: execute the inert contract followed by one manual offscreen candidate run against a clean, SHA-reviewed `dev`; examine the new `docs/wull-centered-prototype-*.json` before any production edit. If all four geometries fit, consider the minimum reviewed `AbyssCompanion` anchor/origin change and a separately gated Quickshell host-area vs inner body Region policy change with fresh 7-case bridge, 8-check focused and 2-phase isolated production-host qualification. Preserve click/hover in all orientations, keep default-off and unchanged `stable`. If candidate fails, diagnose private QML warnings and revise fixture instead of making speculative production changes. Even successful mapped rectangles do **not** establish physical pointer hit-testing or visual/animation acceptance.

## Checkpoint — 2026-10-01 centered prototype 4/4 PASS; production layout pending exact-SHA geometry and focused gates

- Isolated, unmodified-component *prototype* receipt `docs/wull-centered-prototype-20261001T150053Z-22dbb28f-80965c73af11.json` on source `80965c73af11a38b8a9c90e546b942c70fe88982`, committed as `4d0cb02825ade80786f880db421bb8771560a5c6`, is **PASS**: runtime-only center anchor plus center rotation origin places mapped clickable `WaterDropletBody` within all four `AbyssCompanion` hosts. Top/bottom body box (18,3,76×92) and left/right body box (3,18,92×76) each occupy approximately **63.7%** of host area; no overhang. This is QML-mapped geometry only, not a physical input or screenshot pass.
- Minimum production layout fix `5dde4e2f0559b7adac52ab0438435884236c24f9` applies only `transformOrigin: Item.Center` and `anchors.centerIn: parent` to the real `modules/abyss/companion/AbyssCompanion.qml` body, preserving orientation, hover/tap wiring, all default-off policies and the **unchanged complete host compositor mask**. This source change needs *its own* execution evidence; earlier offscreen prototype and nested production receipts predate it and cannot certify the new production SHA.
- Source-guarded proof `82ac379e65fe8be65df14a7fca19675a5076f8e5` adds `scripts/wull-manual-production-geometry.py` plus `scripts/test-wull-production-geometry-contract.py`. It runs the ORIGINAL four-edge offscreen fixture on the **updated real production component without any runtime anchor overrides**, requires all four mapped bodies to fit within host bounds while occupying less than 90% of host area, explicitly pins reviewed QML and fixture blobs, and publishes only a sanitized `docs/wull-production-geometry-*.json` report. Focused eight-check qualification was re-anchored in `6d2db8ffd3995de15834fcc61a85aacbefaac08c` to the reviewed new production geometry source/runner. **Neither the new production geometry runner nor the focused eight-check qualifier has been rerun after the fix.**
- Next local gate: from one clean `dev` checkout, run the inert production-geometry contract, its four-edge real QML probe and (only if geometry PASS) the 8-check focused native/perimeter qualification. The two manual runners each publish a distinct exact-source sanitized receipt. Do not claim new runtime PASS until these arrive. Once green, safely re-anchor the separately opt-in nested Niri production-host probe to the changed component; then investigate an inner-body-only `Region` with independent real pointer pass-through against an interactive underlay, rather than immediately shrinking the mask. Physical multioutput/hotplug, long-run *whole-shell* resources, visual/animation approval and canonical-wide validation remain open. `stable` untouched.


## Checkpoint — 2026-10-01 centered production geometry 4/4 and focused qualification 8/8; nested host guard refreshed

- Two independent sanitized post-change production QML receipts are **PASS** on exact sources: `docs/wull-production-geometry-20261001T151747Z-81e30bf2-336726d7ea1d.json` at `336726d7ea1d9523b217fd911db6739aa9242dff` and `docs/wull-production-geometry-20261001T151838Z-fd6d4452-fca3953264b1.json` at `fca3953264b1fa7a7d6e58ed6ff5300c96f8433b`. Both ran the unchanged four-edge fixture against the updated REAL production `AbyssCompanion.qml` with no runtime anchor override: **4/4 containment PASS**, each mapped clickable-body bounding box/host area ratio **0.637**, no protrusion. Offscreen geometry only; neither receipt measures native pointer pass-through or visual quality.
- Focused receipt `docs/wull-manual-qualification-20261001T151759Z-19830792-c10b669fa87f.json` on `c10b669fa87ff8b26ed2c1f58a9e9781feb0290d` is **8/8 PASS**: Wull production and host policy, complete perimeter regression, Rust unit and locked release, exact-build dispatcher version, native production and package metadata. Global canonical remains `not_run` for this receipt, and previous canonical-wide failures are unresolved. The tested Wull production sources did not change across these receipt SHA transitions.
- Source-guard-only changes to the previously used real Niri opt-in host probes: `c5f04586992b0d7992b43a7b910764b651421dbf` re-anchors `scripts/wull-manual-production-layer.py` to post-qualification `b5eaf719c5b9d161c862f8e9176b6f4dd3d93739`, preserving its pinned original script/fixture and rejecting later production dependency changes. `cfe5a7eda916e0667825199112b7a6f7b0483e74` and fix-forward `425e334d0b6d735a7ad6ca997dac10c3d2d56a78` update the `scripts/wull-manual-nested-niri.py` child blob pin and baseline-audit revision for the centered production component. These source-only probe guard changes **have not yet earned fresh local validation or nested Niri execution evidence**. No Wull rendering, daemon, default, existing running shell or compositor input mask was changed by them.
- Next exact-source gate: from one clean `dev` checkout, run `scripts/test-wull-production-layer-contract.py` and `scripts/test-wull-nested-niri-contract.py`, then the explicitly opt-in `scripts/wull-manual-nested-niri.py --acknowledge-nested-niri` only if the inert contracts pass. Inspect both nested and child `docs/wull-*.json` receipts and source SHAs. Never infer physical mouse hit-testing from the Niri layer inventory. After PASS, design an independent controlled nested-session real pointer/interactive-underlay test BEFORE changing the complete host input region; later distinct gates remain live visual/motion approval, multi-output/hotplug/reload/suspend, whole-shell long-run resources and canonical global acceptance. Wull stays default-off, `stable` untouched.

- Preflight hardening before the next local nested test: commit `db6bd1f144cac9379e33a96e09514731099fa555` changes only the child test runner to avoid signalling an already-exited Quickshell owner's potentially reused process-group ID; `ef4316953e2254104741a4f9bd0b780e4c9a7836` adds a no-live-process executable regression for that case; `8243ca5375d85119d455875ac6aff820ed01ef56` pins the nested coordinator to the cleanup-hardened child and its fresh exact baseline. This is deterministic **test tooling only**, not a production feature change. Both inert contracts and the real nested production-host lifecycle must still run on one clean exact source before any fresh PASS claim.


## Checkpoint — 2026-10-01 refreshed nested production PASS; pointer witness and safe geometry staged

- Fresh source-pinned independent nested receipts on `dev`: `docs/wull-nested-niri-20261001T152505Z-d938e783-24af1766f3eb.json` and `docs/wull-production-layer-20261001T152511Z-c5413658-24af1766f3eb.json` both record **PASS** against `24af1766f3eb7fc7abb2a381efba962ea51ed42d`. The guarded coordinator used a distinct owned private Niri socket and one nested output, with no preexisting Abyss layer, one mapped actual production PanelWindow, disabled phase with zero private daemon, enabled phase with exactly one private daemon, no unrequested keyboard focus, full layer/process/nested cleanup and unchanged host output count. This qualifies the centered post-fix production host's bounded single-output mapping/lifecycle in the nested environment, **not** physical pointer routing, Wull visual quality, multioutput or global canonical validation. Its associated inert contracts were prerequisites in the user's one-command runner; do not generalize their PASS beyond the receipt source.
- A new *separate*, not yet executed pointer-test groundwork was committed without changing any production file: `36bb15bd319aa6f0f6d78393bdc14abd75780807` adds `scripts/wull-fixtures/pointer-underlay/shell.qml`, a dedicated full-output bottom layer that records private real click markers while remaining separate from the production Abyss namespace. `d1092caa4ac05ac486523db2a5941c23e7d59d8d` adds the inert `scripts/wull-pointer-targets.py` initial top-edge control/body/margin geometry. `88c78958dcbc5f9d90233ae79c862932db7d1c17` adds the inert contract `scripts/test-wull-pointer-underlay-contract.py`. `d52da3b0c8a798c279b99c817e16b7accdf16f29` documents a strict pointer acceptance matrix in `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`. **No actual pointer event has been sent or accepted yet; these new files have no new local execution receipt.**
- Next: implement a dedicated guarded child/coordinator for a real native virtual-pointer test **only on a separately verified nested Niri socket**. Run the inert pointer contract before any actual injection. Start the private underlay and the real production Abyss concurrently on that same output with Wull `interactive=true` in the enabled phase (prior production mapping probe deliberately used `interactive=false`). Require observed underlay disabled-center and enabled-outside clicks plus independently observed real Wull-to-daemon click delivery before claiming body hit-test PASS. Host-empty-margin response is diagnostic under the current whole-host mask. If the native virtual-pointer tool or protocol is missing, record `INCONCLUSIVE` and do not inject on the host desktop. Publish only sanitized exact-SHA per-case/cleanup data; raw coordinates and event logs stay local. Do not shrink production Region until this real control matrix, subsequent candidate-mask comparison and click/hover behavior have been qualified. Distinct outstanding gates: canonical-wide failures, live visual/motion approval, real multi-output/hotplug/reload/suspend and whole-shell long-run resource observation. Default-off Wull; `stable` untouched.


- Follow-up private relay: `f8116f4000b40265648e8a20f0d6f29fa16b1012` adds `scripts/wull-fixtures/pointer-underlay/companion-relay.py`, a gated test-only stdio relay that forwards unchanged bridge JSON to the **real private inir-companiond** and records private bounded click-event/reaction markers. `1a3e7a7d837e7bcfc82bf2bb8f702355d5475891` adds `scripts/test-wull-private-relay-contract.py`, an inert fake-backend forwarding/host-identity refusal smoke only; `5bfc6b4f17d4234f8dc86584a74fd2c55b7c57cf` documents the strict distinction in `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`. No live pointer or relay receipt yet; next build the isolated nested-only coordinator and child before requesting **one** grouped local command. Do not run separate test commands or claim pointer PASS from an inert fake backend. Keep `stable` and production mask unchanged.


## Checkpoint — 2026-10-01 guarded real nested-pointer runner staged; awaiting exact-SHA local probe

- The latest prior actual centered production nested-Niri receipts remain `docs/wull-nested-niri-20261001T152505Z-d938e783-24af1766f3eb.json` and child `docs/wull-production-layer-20261001T152511Z-c5413658-24af1766f3eb.json`: PASS on `24af1766f3eb7fc7abb2a381efba962ea51ed42d`. They verified actual production PanelWindow mapping, default-off zero backend, enabled one exact-private Rust daemon, no unwanted keyboard focus and cleanup on one nested output, but **NOT pointer input**.
- The controlled next-stage **REAL pointer runner is now staged on dev**, not yet executed: `scripts/wull-manual-nested-pointer.py` is the top-level coordinator (initial `b47f921bf2789dbb7106360fa8aadea624d22fbb` with audited follow-up hardening through `a0af3df733b64b0f21617b7a19693cbf516590d4`); `scripts/wull-manual-pointer-child.py` builds exact private release Rust and stages isolated production/underlay Quickshell sessions (created `ee0b3bed0f4d1745189f51bcba0c8341906f1fdc`, hardened through `6f5c0a6abc717138e0535716b1f84d510b4fe2b7`). The parent pins reviewed exact blobs of its child and all actual production Wull/fixture dependencies, verifies distinct owned nested Wayland/Niri sockets, checks one active nested output and no preexisting namespaces, and refuses unreviewed changes. Cleanup is limited to verified owned processes. Production Wull QML, native source, complete input mask and default-off settings are unchanged.
- The private test child enables Wull interactively only inside its temporary nested config and uses the `companion-relay.py` fixture to forward unchanged production bridge messages to the REAL privately built `inir-companiond`. It requires actual Rust `present` state before click, disables Wull for an underlay-center negative control, verifies enabled external underlay pass-through, then requires BOTH a real bridge click and real Rust `happy`/pulse reaction from the Wull body center without an underlay click. The host-empty-margin observation is diagnostic under the unchanged whole-host mask, not an acceptance claim. It checks no unexpected keyboard focus and revalidates nested Wayland socket before every injection.
- Native input is allowed **only** through an already-installed `wdotool --backend wlr-protocols` within the verified nested session. Missing `wdotool`, unavailable native backend or any uncertain isolation emits `INCONCLUSIVE`; no installation, portal, host-global `uinput` or real desktop fallback. The first probe covers only **one top edge on one nested output**. Physical clicks on other edges, popup non-interference, live host visuals, whole-shell long-run resources, multi-output/hotplug/reload/suspend and unresolved global canonical acceptance remain separate.
- Inert prerequisites on the same clean `dev` source: `scripts/test-wull-pointer-underlay-contract.py`, `scripts/test-wull-private-relay-contract.py` (updated to check explicit checkout and real-present markers), and `scripts/test-wull-nested-pointer-contract.py` (created `269eace9bc019f71dbe8cbdf5ee6bcd9d4a49be5`, guarded safety followup through `4a59cc0c81dcd49e2540df13c4c93f653bed2ae6`). The parser/provenance source was inspected through GitHub but **none of these three new gates or the actual pointer runner has fresh local execution evidence**.
- Next: run exactly those three inert prerequisites, then (only on PASS) `python3 scripts/wull-manual-nested-pointer.py --acknowledge-nested-pointer` from one clean fast-forward-only `dev` checkout as ONE grouped local command. Check the unique `docs/wull-pointer-acceptance-*.json` receipt on `dev`, exact source SHA, all control cases and owned cleanup. If no receipt appears, do NOT rerun blindly; inspect available evidence/STOP first. Do not narrow the production Region without the actual observed control matrix followed by separate candidate-mask comparison. `stable` untouched.


## Checkpoint — 2026-10-01 bounded nested pointer child-group timeout hardening

- Before executing the previously staged real pointer coordinator, source audit found a cleanup risk: on a bounded parent timeout, terminating only the owned Python child PID could leave an in-group Cargo/virtual-input subprocess alive. Source-only commit `42fca65f2eba1f5d8202649123f8fb31b97db9bc` adds `stop_owned_child_group` to `scripts/wull-manual-nested-pointer.py`: it SIGTERMs (and boundedly SIGKILLs if needed) the child's *verified live* process group, while refusing a group signal after the leader already exited to avoid reused PGIDs. The self revision guard is advanced from four to five reviewed commits. Commit `3eb3202d7f8d3ec95d87b7e80db71b1b71137136` adds an **inert** mock test for both exited and hung child-group cleanup in `scripts/test-wull-nested-pointer-contract.py`. This is test-tool cleanup hardening only, NOT an observed local/desktop PASS. Production Wull QML, daemon, complete host input mask and defaults are unchanged.
- Latest inspection found **zero** committed `docs/wull-pointer-acceptance-*.json` receipts. Next run the three current-source inert pointer contracts (underlay, private relay, nested pointer) sequentially, and only after all succeed invoke the explicitly authorized coordinator `python3 scripts/wull-manual-nested-pointer.py --acknowledge-nested-pointer` from a clean fast-forward-only `dev` checkout in **one terminal command**. The runner publishes one SHA-pinned sanitized receipt, with `INCONCLUSIVE` (not PASS) when `wdotool` or its forced native `wlr-protocols` backend is unavailable. Do not automatically rerun on an uncertain result; read receipt/current Git state first. Subsequent gates remain physical other-edge controls, popup interactions, long-run shell resources, multioutput/hotplug/reload/suspend, visual motion and canonical-wide validation. Never enable Wull by default or mutate `stable`.


- Underlay inert false-positive repair: user's grouped local run stopped at the FIRST inert safety test with `AssertionError` on `assert "AbyssPerimeter" not in fixture`. Source verification found that `scripts/wull-fixtures/pointer-underlay/shell.qml` mentions `AbyssPerimeter` only in a `//` explanatory comment and does NOT instantiate/import the production QML. Commit `cf86274889fcb27108c9aa7b5421d187011cf2d5` corrects **only the inert contract** `scripts/test-wull-pointer-underlay-contract.py` to check uncommented QML statements for a real Abyss import/instantiation. The actual underlay fixture, production code, real nested pointer runner and all source guard pins remain unchanged. A GitHub-side logic check confirmed the actual fixture and comment-only case are accepted and synthetic production import/instantiation are rejected; this is NOT an exact-SHA local test PASS. The previous grouped command stopped BEFORE private relay contract or live nested pointer execution; do not claim those gates or a pointer report passed. Resume only after clean `dev` fast-forward with all three current inert contracts, then explicitly opt in to the real nested runner; inspect its unique sanitized receipt and classify `INCONCLUSIVE` rather than asserting PASS if no native backend is available.


## Checkpoint — 2026-10-01 real pointer preflight tool missing; native-only alternative staged

- The user's grouped command passed far enough to publish the real
  `docs/wull-pointer-acceptance-20261001T155651Z-c552449b-304d6ab601b1.json`
  receipt on exact source `304d6ab601b130c11756de2f4ac7059cdda5507b`.
  The receipt is **INCONCLUSIVE** with
  `native_wdotool_missing_no_input_injected`; its `observation` is
  null. No real pointer event occurred, no Wull input-mask failure
  or PASS is established, and nothing in production was changed.
- The source-only alternative keeps preferred exact native
  `wdotool --backend wlr-protocols` and accepts already-installed
  `wlrctl` only if `wdotool` is absent. The latter speaks the
  native virtual-pointer protocol but moves **relative**, not
  absolute; `scripts/wull-manual-pointer-child.py` now uses a
  candidate origin-reset plus relative target, verifies the
  owned nested endpoints **before each command**, and treats failed
  relative input controls as **INCONCLUSIVE** until the real
  independent underlay / production bridge / Rust reaction matrix
  establishes the physical hit. The only source changes are in
  test tooling: child commits `666d6d18d206a92a5d6b28d2800eb9e0e7156898`,
  `0f22292de807744af0220356c96e66c71010fc33`, parent
  `5f3b777457091bab8ed8c47be31512c1f915fd97`,
  `97c2a4e5577759fcfb731890792e6a99135fbc66`,
  and updated inert contract
  `0b716fa8f5011a29051aae2d4486869f2633351f`.
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md` now records
  the limitations and the original inconclusive receipt. No new
  local evidence has been collected for this optional backend yet.
- Next command for the user: fetch/fast-forward from clean `dev`,
  run the three inert pointer safety contracts in order, and run
  the explicit nested pointer coordinator only when the machine
  already has at least one of `wdotool` or `wlrctl`. If neither
  exists, STOP with only a short missing-tool message: do not
  install dependencies automatically or repeat the known
  missing-input receipt. Check the next unique sanitized pointer
  receipt on GitHub rather than asking the user for raw logs.
  A physical top-edge PASS, if observed, is only one nested output;
  four-edge physical pointer behavior, mask change comparison,
  full-shell resource behavior, live visuals, actual multi-output,
  reload/suspend and canonical-wide acceptance remain separate.
  Default-off Wull and `stable` stay unchanged.


## Checkpoint — 2026-10-01 all three inert pointer safety checks PASS; local CLI unavailable

- The user's latest one-command local run printed **all three new inert contracts PASS**: `WULL_POINTER_UNDERLAY_INERT_CONTRACT_PASS`, `WULL_PRIVATE_RELAY_INERT_CONTRACT_PASS` and `WULL_NESTED_POINTER_INERT_CONTRACT_PASS`. Its next **CLI availability** gate stopped with `Neither wdotool nor wlrctl is installed; no pointer input attempted`. The script did **not** invoke `scripts/wull-manual-nested-pointer.py` this time, and therefore produced no new real-pointer JSON receipt. Do NOT count these inert tests as actual pointer validation, and do NOT repeat the exact same unavailable-input probe.
- Verify and use one native-only virtual-pointer CLI that is already packaged by the user's distro; `wlrctl` is available in official Debian, Ubuntu and Fedora packaging, with documented native relative `pointer move <dx> <dy>` and `pointer click` actions. In Niri, access to its own Wayland socket admits `wlr-virtual-pointer`, but this does NOT license input into the current desktop. An explicit **user-approved** OS package installation may be suggested separately from tests; never silently download/build/install, never modify a package manager without informed approval, and never substitute host-global uinput. If the distro has no verified package, stop and collect non-sensitive distro/package-manager information, rather than guessing a third-party repository. Underlay control failures with the relative backend must remain `INCONCLUSIVE`.
- When a verified native CLI is available, resume the clean-`dev` single-command sequence: three inert contracts and then the opt-in `scripts/wull-manual-nested-pointer.py --acknowledge-nested-pointer`, which creates its owned nested session and publishes only sanitized exact-source evidence. Production code/mask/default-off behavior and `stable` remain unchanged. Physical top-edge click, four-edge input, popup interactions, visual quality, multioutput/reload/suspend, long-run full-shell resources and unresolved canonical-wide acceptance remain independent open gates.


## Checkpoint — 2026-10-01 Arch Linux: Cargo-only native pointer dependency

- Maintainer confirms Arch Linux: one clean-`dev` grouped run on
  `8f2bcb3f38065ca17e8914befd3d9578cb60e9ee` logged all three
  pointer inert contracts **PASS**, then stopped at `No verified wlrctl
  package found for Arch Linux`. Neither `wdotool` nor `wlrctl`
  was installed and NO new real pointer event/report occurred.
- Public upstream `cushycush/wdotool` explicitly supports
  `cargo install wdotool` from crates.io, plus native
  `--backend wlr-protocols` absolute `mousemove` and `click`
  commands. It can be installed with `cargo install --locked wdotool
  --root ~/.local` as the normal user, **only after the maintainer
  explicitly approves building third-party code**. The next single
  local command must first fast-forward clean `dev` and run all three
  inert contracts, detect a currently available native pointer CLI,
  otherwise explain the Cargo source/install destination and require
  interactive explicit yes before executing `cargo install`. Add
  `~/.local/bin` to PATH only for this shell. Never run Cargo as
  root, pipe downloaded scripts into the shell, use AUR without
  review, allow the uinput/portal input fallback, or test the live
  host directly. The nested runner itself forces
  `--backend wlr-protocols` and validates a distinct owned Niri
  socket before input. Any missing protocol remains INCONCLUSIVE.
- Pointer acceptance is NOT yet achieved: inspect a freshly
  published `docs/wull-pointer-acceptance-*.json` exact-source receipt
  before any claims or changes to Wull's current whole-host Region.
  Keep production QML, native code, default-off and `stable`
  untouched; global canonical, physical other-edge input,
  multioutput/hotplug, visual quality and long-running shell
  resource qualification remain separate.


## Checkpoint — 2026-10-01 first real pointer matrix failure and coordinate-qualified rerun

- Latest exact-source **real** nested pointer receipt:
  `docs/wull-pointer-acceptance-20261001T161301Z-8af536c9-115ab32a9825.json`
  on `115ab32a98251453edc76c84bdc8558068186aab`
  has overall **FAILED** status. One compositor-owned nested output
  and private source-built real Rust backend were verified; disabled
  candidate-center underlay control and enabled exterior underlay
  control both passed **by event counts**. The enabled candidate
  body-center click was instead observed by the full-output
  underlay (`underlay_not_clicked=false`), with zero real bridge
  click marker and zero real Rust reaction. Production layer, underlay,
  private daemon and nested compositor cleanup all passed, and host
  output count stayed unchanged. **Critical evidence limitation**:
  event counts do not prove that the native pointer actually moved
  to the requested candidate coordinates. Do not label this proven
  production input-mask failure or narrow the Region yet.
- Source-only follow-up
  `a83f630f7f4bdc73953bc75b7b14b888e6544219` adds bounded
  actual underlay-event coordinate verification to the private
  child: disabled-center and enabled-exterior now must produce
  exactly one matched left-click within six logical pixels of
  their requested point; the enabled-body underlay event is
  independently tested for positional alignment. Wrong/missing
  or ambiguous positions are **INCONCLUSIVE**, not production
  regressions. Only allow further mask/host analysis once
  underlay coordinates corroborate the target. Raw locations
  remain local private logs, while sanitized reports publish
  bounded alignment labels only. `a784b3db6157d4c05368fee0ec79925a1a51f468`
  re-reviews/pins the exact child and increments the coordinator's
  self guard; `03d237620ada9dd170d31163ef6081bd40a66042`
  adds a synthetic inert-parser contract and updated pins.
  The technical investigation is in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  (updated `e4553da088fa1bdde5b2c0991f26ff835f6fb96e`).
- Await **one clean exact-SHA local grouped run** of the three
  inert contracts and the explicit owned nested pointer runner
  using the now-available already-installed native CLI. If the
  next pointer receipt shows both controls aligned but the
  enabled body underlay aligned too, investigate **runtime host
  visibility/activation versus compositor input mask** with a
  separate, read-only or test-only fixture before editing
  production. If coordinates are off target, diagnose native
  pixel-vs-logical-output mapping instead of changing Wull.
  Full canonical, visual/animation signoff, physical four-edge
  pointer and multioutput/hotplug, resource long-run and
  reload/suspend remain unqualified. Stable and production
  input mask/default-off remain unchanged.


- Follow-up sanitized backend provenance: `6670066439c8899b42ba528e5cf81f9b71ce9ee4`
projects the allowlisted actual child pointer backend
(`forced_wlr_protocols_wdotool` or
`native_relative_wlrctl_unverified`) into the main sanitized
receipt, without host paths, and raises the reviewed coordinator
self-revision count from eight to nine. The inert contract assertion
was added in `1de19ca38f1738e0167b01a169c63f67d43cf1a4`.
The technical design note records this. No new real pointer receipt
after the prior FAILED source `115ab32a9825` has yet been inspected:
the next grouped local run must validate the current inert tests and
the stricter real coordinate-witness matrix before any Wull
production input change.


## Checkpoint — 2026-10-01 coordinate-qualified top-edge pointer PASS; private candidate comparison awaiting local test

- The latest verified source-pinned REAL nested Niri pointer receipt is now
  `docs/wull-pointer-acceptance-20261001T161911Z-4d87f846-391d8e81d461.json`,
  `source_sha=391d8e81d4617a6dbdb1199d009db4e0970ce073`,
  **PASS**. Its forced native `wdotool --backend wlr-protocols`
  body-disabled and enabled-exterior controls independently reported
  `target_alignment=matched`; its enabled body hit produced NO underlay
  click, exactly one actual bridge click and a real private native Rust
  happy/pulse acknowledgment. Verified clean single-output nested
  identity, namespace isolation, all owned layer/process/compositor
  cleanup and unchanged host output count. The prior count-only
  `FAILED` receipt is diagnostic history, NOT proof that this
  newly coordinate-qualified run failed. The current full host
  mask's empty internal margin did not pass through to underlay;
  it also did not accidentally trigger a body click.
- With that baseline PASS, the next priority is a separate source-only
  **PRIVATE top-edge size=1 candidate mask A/B**, NEVER a premature
  production mask edit. Commit
  `e3da0c57264cb44f26045e285f14b22a301a06ba` adds
  `scripts/wull-private-mask-candidate.py`, which guards and
  substitutes precisely ONE reviewed Wull Region in a PRIVATE
  shadowed `AbyssPerimeter.qml` outside the checkout, leaving
  all other modules linked unchanged. Child commits
  `11ecc21ad115fd0c683f3c7ce0c2e003e58f256d` and
  `975482cd8a49475d9eb622d7b38c49aa601ec2bf`
  add a same-owned-nested-compositor real full-mask control
  followed by a separately launched private candidate.
  The candidate must preserve correct-coordinate exterior
  pass-through, genuine body bridge/Rust click and obtain a
  positive correctly aligned underlay click at the formerly
  blocked empty host margin. All controls, phase handoff,
  cleanup and one absolute native pointer source must pass.
- `244b6a95a485ff669506614958832e2715cb3e3c`
  provides a separate explicit coordinator argument
  `--acknowledge-nested-pointer-candidate` and distinct
  `docs/wull-mask-candidate-*.json` sanitized receipt.
  It pins the new helper/child and ten audited parent revisions,
  leaving the existing production-pointer opt-in unchanged.
  `b705c2b224ff432e06e4268b25fb8ba7d84626f3`
  introduces a NEW wholly inert private-mask staging/source
  contract, and
  `55e191bb119be6e7f7d47150dff8876db0fb6fe8`
  re-anchors the existing pointer inert contract.
  The technical details and limitations are in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md` updated
  `2700abe1f65be9b98a13e6eeeb2c15b1de6c3c77`.
- **NEXT LOCAL GATE**, not yet executed: on one clean
  fast-forward-only `dev` checkout and with already-installed
  user-space `wdotool`, run the three existing inert pointer
  contracts AND `scripts/test-wull-private-mask-candidate-contract.py`,
  then ONLY if all PASS invoke
  `python3 scripts/wull-manual-nested-pointer.py --acknowledge-nested-pointer-candidate`
  in the SAME grouped terminal command. Inspect the unique
  `docs/wull-mask-candidate-*.json` receipt; an inert PASS
  alone is not real candidate approval. If a candidate
  QML load fails, analyze the private scoped diagnostic without
  guessing the input mask. Keep `stable`, production Wull,
  default-off and complete host Region unchanged until separate
  candidate PASS plus later four-edge, popup/hover, live visual,
  real multioutput and canonical/global qualification.


## Checkpoint — 2026-10-01 top private mask A/B PASS; bottom trial source staged

- The NEW real private top-edge input-mask comparison receipt is
  `docs/wull-mask-candidate-20261001T165308Z-a3bc585f-124f02155679.json`,
  exact source `124f02155679949e60a810e54a9c216fbfd2fabe`:
  **PASS** using forced native `wdotool` in one verified owned
  nested Niri output. The unchanged production full-host mask
  passed aligned disabled-center and exterior controls, actual
  body bridge and private Rust response, while its empty internal
  host margin did NOT pass through. The shadow-only narrow
  rectangular top-size1 BBOX then passed its independently
  aligned exterior control, genuine bridge/Rust body click and
  **positive aligned** empty-margin underlay pass-through
  without false body activation. Distinct nested endpoints,
  all private process/Wayland layer cleanup and unchanged
  host output count passed. The shipped Wull production mask
  and default-off settings remain unchanged; `stable` untouched.
- The next separately qualified edge is **BOTTOM**, not yet
  accepted. Four-edge postchange offscreen geometry from
  `docs/wull-production-geometry-20261001T151838Z-fd6d4452-fca3953264b1.json`
  establishes source-measured clickable BBOXes ONLY. Source
  `62c483451d91c7b0e5e1f1184fd84f8b04443c14`
  adds conservative four-edge pointer targets without
  modifying the old top function.
  `5b928b852664e8369f74fa17243e78cc92a402c8`
  changes ONLY the private candidate generator to select
  76x92 on top/bottom and rotated 92x76 on left/right at
  size=1, refusing unreviewed geometry/source. Child
  `4e32eaa1f874540b5f71ceca34c5a4b697734568`
  adds `candidate-mask-bottom` alongside the preserved
  original top opt-in. Parent
  `3309b00ac035ff5944283073aef8e181382339e8`
  pins all changed source, raises the audited self-revision
  count to 11, adds `--acknowledge-nested-pointer-candidate-bottom`,
  and publishes its unique `docs/wull-mask-bottom-*.json`
  in a separate bottom-specific scope.
  Contracts `4d5080b87951885e40b920d6e603a5e064f35cb9`
  and `6b210355f794d2490059f5de46251ece32f313ea`
  review static four-edge bounds, preserve top equivalence,
  re-pin the child and check bottom-only entry controls.
  Full design/limits in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md` update
  `dd677e30a08f4cd78fb999add13e7487d9a1c0e9`.
- **Next one-command local gate:** from a clean fast-forward-only
  `dev` root with already-installed user `wdotool`, run
  the three old inert pointer contracts PLUS
  `scripts/test-wull-private-mask-candidate-contract.py`.
  Only if all PASS, invoke the original private top
  A/B comparison (new dynamic generator regression) and
  require explicit observed `WULL_REAL_POINTER_RESULT: pass`.
  Only then invoke the separately authorized bottom A/B
  on a new owned nested Niri compositor and check its
  independent explicit PASS. Both publish sanitized
  different-prefix exact-source receipts, never raw
  coordinates or host-global input. Read new receipts on
  `dev` before deciding how to extend to right/left.
  Do not modify real production Region or `stable` from
  inert or top-only success. Subsequent physical side edges,
  popup/hover, actual multi-output/hotplug, reload/suspend,
  whole-shell long-run resources, visuals and canonical-wide
  validation remain outstanding.


## Checkpoint — 2026-10-01 dynamic top A/B remap off-target; read-only retro diagnosis

- Local clean temporary-clone run **DID publish** the new report
  `docs/wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json`
  on exact source `1518db798d1012592cdbceb29115cceb72cffd9b`:
  **INCONCLUSIVE**, not FAIL or PASS. Four baseline real
  full-production checks succeeded (disabled-body and
  enabled-exterior actual coordinates matched, actual body click
  reached bridge and private real Rust happy/pulse, full-host
  empty margin remained blocked). After baseline cleaned,
  the FIRST newly remapped private dynamic-candidate exterior
  control registered a real underlay click at the WRONG
  location (`target_alignment=off_target`).
  The runner stopped before candidate body and margin
  checks, and before any bottom-edge run. It verified
  private nested endpoints, process/layer cleanup and
  unchanged host output count. The older `124f0215...`
  top-size1 private A/B **PASS** remains separate
  historical evidence; this new run has not requalified
  the now-dynamic four-edge candidate source.
- Added **read-only local retrospective** diagnosis
  `scripts/wull-private-pointer-drift-diagnostic.py`
  commit `55907217e8e1a18d9ae74cc5b129578db45f1aa8`,
  with symlink-rejection correction
  `a0f1e06f2f934298312e19a2df74563e604bc395`,
  and synthetic inert parser contract
  `scripts/test-wull-private-pointer-drift-diagnostic.py`
  commit `06c640e1ee1385e75524c6c3eb2a3650c2ffa031`.
  It accepts only the existing exact report sequence,
  reads the corresponding owned PRIVATE previous-run
  underlay log on the user's host, compares baseline
  and candidate exterior witness locations against
  each other (identical target expected), and prints
  only coarse drift magnitude/direction and possible
  stale-disabled-center categorization. No raw
  coordinates, new physical pointer input, new
  dependencies, user config, Git checkout or production
  source changes. Detailed constraints are in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`,
  updated `ea8152e80104f1169aa0c56f16c6942281527efb`.
- **NEXT ONE-COMMAND LOCAL GATE**: from any original
  Hadalis Git checkout, fetch the current remote `dev`
  WITHOUT merging/rebasing/resetting the user's
  divergent local `dev`. Stage ONLY that read-only
  diagnostic, its inert synthetic contract and the
  one public sanitized target report in a new
  permission-restricted temporary directory using
  `git show origin/dev:...`. Run the inert test,
  then classify the user's existing local private
  Niri-session underlay witness (if retained).
  Capture ONLY the short categorical output. If
  source log is absent or input count ambiguous,
  report INCONCLUSIVE and design a new isolated
  instrumentation gate; do not guess. Avoid another
  expensive full Rust/Niri pointer rerun until
  this existing evidence is read.
  Do not increase mouse-target tolerance, call
  host-global injection, make production changes,
  or promote bottom/right/left as accepted.
  Production/default-off and `stable` stay
  unchanged; all other four-edge and full-system
  qualification remains separate.


## Checkpoint — 2026-10-02 old private top pointer log: sanitized autonomous publication staged

- As of review of `dev`, the only new dynamic private
  top candidate run is still
  `docs/wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json`,
  source `1518db798d1012592cdbceb29115cceb72cffd9b`,
  **INCONCLUSIVE** at the FIRST post-remap candidate
  exterior witness: `target_alignment=off_target`.
  Its four real full-production controls passed and
  all owned private compositor, underlay, production
  layer and Rust cleanup passed. A separate older top
  candidate PASS still exists but did NOT test the
  latest dynamic four-edge BBOX generator. Bottom has
  no independent real acceptance report.
- Latest additional source-only progress:
  `scripts/wull-private-pointer-drift-publish.py`
  commit `dc06dd36aabc688f1945205bb4a814c58f91d90e`
  supports one EXPLICIT, input-free retrospective
  classification and Git publication in a permission-private
  TEMPORARY clone of `dev`; never modifies the
  maintainer's potentially divergent original local branch.
  Its only imported measurement logic is the previously
  reviewed source-pinned
  `scripts/wull-private-pointer-drift-diagnostic.py`
  blob `91c2207e7d96aa8852f6d6f8df0ea1cb28d647d2`;
  it also pins the exact public original report blob.
  It reads the prior run's private underlay log by
  the known session ID; it requires an unambiguous
  three-event and exact-source sequence; it emits
  only reviewed categorical axis/magnitude/relative
  direction, one prior-center-proximity boolean and
  explicit no-new-input/no-production-change fields.
  Its unique fixed public result path is
  `docs/wull-pointer-drift-20261001T170950Z-105fd7a8-1518db798d10.json`.
  Concurrent Git pushes are handled ONLY by guarded,
  non-forced replay of that single unpublished
  sanitized commit in the temporary clone. If
  old logs were not retained or source changes
  invalidate exact blobs, stop INCONCLUSIVE rather
  than guess.
- The publisher's inert/test-only payload and
  source guard contract is
  `scripts/test-wull-private-pointer-drift-publish-contract.py`
  created `fbd1e709b0b64046afa9e619426e409973dce59b`.
  Existing diagnostic inert parser contract must
  PASS in the same local invocation before any
  Git publication. The technical design appendage
  is in `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  updated `87c5c295bfb1ba0c8cc97d66b1bb24a8fe32d828`.
- **NEXT LOCAL GATE:** one clean permission-private
  temp `dev` clone outside the user's original
  checkout; run BOTH no-input inert drift
  contracts, then explicitly invoke
  `python3 scripts/wull-private-pointer-drift-publish.py --publish-existing-top-off-target`
  if they pass. Inspect only the resulting
  unique sanitized public report on `dev`.
  This avoids another expensive Rust rebuild and
  real Niri pointer run before the existing log
  evidence is consumed.
  Independently, external wdotool documentation
  confirms a possible transient virtual-device
  lifecycle variable and documents `wdotool prime`,
  but this is just a hypothesis. Do not change
  injection timing, install new tools, enable
  host-global injection, run a blind second
  pointer attempt or qualify bottom until
  old-log evidence or a new separately
  authorized bounded instrumented test exists.
  Current production Region, default-off and
  `stable` remain unchanged.


## Checkpoint — 2026-10-02 verified large two-axis drift; discriminating physical pre-remap witness staged

- The explicit read-only retrospective report was actually published:
  `docs/wull-pointer-drift-20261001T170950Z-105fd7a8-1518db798d10.json`
  on source `5164395aea401bcfcd79fa8e74622d34fe5fceb5`.
  Its exact pinned prior-run underlay witnesses verify that
  the same requested exterior point was hit **96+
  pixels off-target in maximum-axis deviation** after
  the private candidate stage mapped. Both axes
  shifted (horizontal negative, vertical positive)
  and the event did **not** land near the original
  disabled-center location. This is real old-log
  categorical evidence, NOT a new pointer run,
  diagnosis of wdotool's internal cause, or
  acceptance of the new dynamic four-edge BBOX.
  Previous same-source full production controls
  passed, then first dynamic candidate exterior
  witness was off-target, so the new top-edge run
  remains **INCONCLUSIVE**; no bottom receipt exists.
- Source-only follow-up adds an independently
  corroborated discriminating physical gate, not
  retries/tolerance workarounds. Child source
  `5b79c09aabb2f5b50895d0d4c0b38c86cffe4248`
  now verifies the owned Niri single output's
  logical geometry, scale and current mode before
  EVERY native virtual-pointer command. After
  qualifying the full-host real production controls
  and fully stopping/unmapping it, but BEFORE
  mapping a new private candidate, it requires
  one exact-target underlay exterior click
  `after_baseline_unmap_exterior_underlay_control`.
  This separates pointer drift that began during
  baseline teardown from drift observed only after
  candidate remapping, without attributing causality
  prematurely. If intermediate click is off-target,
  stop **INCONCLUSIVE**, do not map candidate or
  claim mask failure. If aligned, proceed with
  the previous separately witnessed candidate
  exterior/body/margin checks. Any output
  geometry/topology change stops the test
  inconclusively before the click.
  No changes to native backend invocation,
  no new dependencies, no host-global injection,
  no silent retries and no changed tolerance.
- Parent source-guard update
  `3ede937c9b70284de76dcb5fc1724abe0da09500`
  pins the revised child and advances 11 to
  12 reviewed parent revisions. Existing inert
  tests `scripts/test-wull-nested-pointer-contract.py`
  (commit `7a4a935afa99a1712bbeba7e4e7d0928de0b01c4`)
  and `scripts/test-wull-private-mask-candidate-contract.py`
  (commit `485cc1ec307980c9cc07af1ecccc7ea5ad75462a`)
  were updated to prove pure invalid geometry
  rejection, strict child blob pins, and mandatory
  intermediate witness source. Full technical
  rationale in `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  commit `7bcadfd1b06eef39afa4d597d5c481c4b55137d9`.
- **NEXT LOCAL GATE, not yet run:** because the
  original dev checkout previously diverged, use
  ONE new permission-private temporary clean dev
  clone (never reset/rebase/merge the original).
  Run the four standard inert pointer contracts;
  if all PASS, run ONLY the fresh real dynamic
  top private A/B with the pre-remap witness
  on that independently verified owned nested
  Niri output and read the new exact-source
  sanitized top report on `dev`. If top
  now fully PASSes including intermediate
  control, a SEPARATE bottom-edge test could
  be authorized after reviewing that top
  evidence (avoid automatically running
  bottom while investigating drift). If
  off-target BEFORE candidate mapping,
  investigate native pointer/device vs
  baseline lifecycle with the private
  phase-specific log, and do not modify
  production. If only off-target AFTER
  mapping, investigate transient input
  device and new layer/output mapping as
  competing hypotheses, not production
  mask defect. The upstream-documented
  `wdotool prime` option remains untested;
  don't enable it without isolated evidence.
  Existing shipped whole-host Region,
  Rust backend, Wull default-off,
  `stable`, and any physical four-edge/
  full canonical acceptance remain unchanged.


## Checkpoint — 2026-10-02 dynamic top with pre-remap witness REAL PASS; bottom next

- The new independently source-pinned
  `docs/wull-mask-candidate-20261001T173129Z-ce33db3c-8efa0b7d7341.json`,
  `source_sha=8efa0b7d73418af9fc52b117199e2a691e0158ac`,
  is **REAL PASS** for the private dynamic candidate
  **TOP edge, size=1, one owned nested Niri output**.
  The unchanged old full production mask passed separate
  disabled-body and enabled-exterior exact-coordinate
  underlay controls, true enabled-body bridge/Rust
  happy/pulse without underlay click, and observed
  blocked empty margin without false body activation.
  After fully unmapped old production and Rust,
  the newly added `after_baseline_unmap_exterior_underlay_control`
  independently clicked the SAME exterior target
  with `target_alignment=matched`. The newly
  mapped dynamic private top mask then separately
  passed correctly aligned exterior, real
  bridge/Rust body and **positive matched**
  empty-host-margin pass-through without false
  body activation. One-output nested endpoints,
  all owned processes/layers/compositor cleanup
  and original host output count passed.
  No source or host config was changed by the probe.
- Keep the previous
  `docs/wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json`
  INCONCLUSIVE. Its real old-log diagnosis showed
  large off-target drift in both axes at first
  candidate exterior; latest successful trial
  proves capability on that new source but
  cannot claim that transient cause is fixed.
- **NEXT LOCAL ACTION:** a SINGLE NEW physical
  **BOTTOM** private candidate A/B test using
  existing separately allowed coordinator flag
  `--acknowledge-nested-pointer-candidate-bottom`
  in an exclusively fresh permission-private dev
  clone. Run four inert pointer safety/geometry
  contracts first; fail closed on any test or
  source audit failure. Publish/read distinct
  `docs/wull-mask-bottom-*.json` and inspect
  its child checks, real backend, output isolation,
  genuine bridge/Rust, intermediary witness
  and complete cleanup before moving to left/right.
  Do NOT automatically run side edges before
  inspecting bottom receipt. Technical analysis
  and complete prior-run evidence in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  (latest checkpoint commit
  `560948038d08307effee1ff9a3203ad8d1991acd`).
  Real production mask, default-off, `stable`,
  visuals/popup, multioutput/hotplug/scale,
  long-run/lifecycle and canonical-wide validation
  remain unchanged/unqualified.


## Checkpoint — 2026-10-02 real bottom PASS; right independent A/B now staged

- New exact-source independently real PASS on
  `docs/wull-mask-bottom-20261001T173542Z-10d599c4-9ac701f650dc.json`,
  source `9ac701f650dce381487fa00a56f24520c5c83289`,
  **BOTTOM** dynamic private BBOX candidate scale=1
  on one verified newly owned Niri output with forced
  absolute native wdotool. Every expected baseline,
  post-baseline-unmap target witness and independent
  candidate exterior, bridge/real-Rust body and
  positive empty-margin pass-through check passed.
  The old production full-host margin remained
  blocked; true Wull body responses never leaked
  to the underlay; all owned layers, private Rust
  processes and the nested compositor stopped,
  and host outputs were unchanged. The distinct
  latest dynamic TOP private candidate real PASS
  remains `docs/wull-mask-candidate-20261001T173129Z-ce33db3c-8efa0b7d7341.json`.
  The previous dynamic TOP off-target
  INCONCLUSIVE trial and its categorical
  two-axis drift evidence remain unresolved
  reliability observations, not proof that
  new wdotool timing fixes are necessary.
- Dedicated right-side private trial has been
  SOURCE-STAGED, **not physically executed**.
  Original source-measured right host/BBOX is
  98x112 / (x=3,y=18,w=92,h=76), already
  pure geometry-checked by the existing four-edge
  inert helper; the existing PRIVATE dynamic
  source generator selects a centered 92x76
  side-edge rectangle. New child commit
  `555d735f2a99fd18b7588d757810c009e5ebfea2`
  adds ONLY `candidate-mask-right` explicit
  mode using the same guarded actual production
  host, exact-coordinate underlay controls and
  real Rust body response. Parent commit
  `a86e2284907207bb0811a820298e5bd57bcfd3ed`
  pins the new child blob, advances audited
  parent revision count from 12 to 13,
  adds the explicit
  `--acknowledge-nested-pointer-candidate-right`
  option and publishes a new separate
  `docs/wull-mask-right-*.json` scope/receipt
  without modifying top/bottom/production modes.
  Updated inert contracts are commits
  `ef65b9483b78cba5b6f0c7bcbff55593cd7078dc`
  and `b627e658fb4e4a53dc07a967c0d19a96c96d45f1`.
  Full technical acceptance history is in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  updated `674879bebb8c660fda55ebd5380d3fda28fe1285`.
- Additional inert RIGHT shadow-staging contract
  `6f11029cf852079396c37e7a9ea71dce16747eae`
  independently writes/validates a private right-edge
  `AbyssPerimeter.qml` shadow and right-edge
  scale=1 isolated config while asserting the
  shipped production source stays unchanged.
  This is SOURCE-STAGED, not compositor acceptance.
- **NEXT SINGLE LOCAL GATE**: from fresh
  permission-private clean dev clone, run
  four existing inert Wull pointer contracts
  first and then ONLY the new explicit
  RIGHT dynamic private candidate A/B
  on its own newly owned nested Niri.
  Require unique source-pin and full parent
  production dependency audit, observed
  absolute native backend, eight real witness
  checks, cleanup and publication of a
  distinct sanitized
  `docs/wull-mask-right-*.json` receipt.
  Do not automatically try LEFT yet:
  first read, validate and debug the independent
  RIGHT result. If positional witness misses,
  classify as INCONCLUSIVE and do not mislabel
  as production-mask defect or silently retry.
  Stable and shipped production Region/default-off
  remain unchanged. LEFT physical trial,
  nonrectangular silhouette, popups/hover,
  live visual/multioutput/fractional scale,
  suspend/reload/hotplug/lifecycle and
  canonical-wide qualification are pending.


## Checkpoint — 2026-10-02 right real A/B PASS; left isolated candidate gate staged

- New independently published real RIGHT side scale=1
  PRIVATE dynamic BBOX A/B PASS in
  `docs/wull-mask-right-20261001T174248Z-cd6a3010-cdbe02bbcd61.json`,
  source `cdbe02bbcd61720f07852fd7eb62929d14004188`.
  All eight phase controls and single owned nested
  output/process/layer/Rust cleanup passed with
  forced native absolute wdotool, including separate
  old production exact-coordinate body/Rust controls,
  unmap-before-remap exterior target, and the
  independent private candidate's correctly
  aligned exterior, real body bridge/Rust,
  and positive margin pass-through without false
  activation. TOP and BOTTOM have separate
  real PRIVATE dynamic mask PASS reports.
  The previous large two-axis transient TOP
  off-target observation remains unresolved;
  these successes do not prove lifetime reliability.
- Separate private LEFT-side mode is now
  SOURCE-STAGED only; NOT physically accepted.
  Child commit
  `57d81d35e1e0f6543f61195f275eba5cd5f0a982`
  adds explicit `candidate-mask-left` using
  existing source-measured vertical 98x112 host
  / (3,18,92,76) rotated body geometry,
  existing exact after-unmap witness, private
  actual Rust and real producer A/B controls.
  Parent commit
  `5e2ca4470c04926b7200df89b730bded154eed7b`
  pins exact changed child and 14 audited
  parent revisions, adds ONLY the explicit
  `--acknowledge-nested-pointer-candidate-left`
  and publishes sanitized
  `docs/wull-mask-left-*.json` with separate
  left-only scope. All top, bottom, right
  and original production modes remain.
  Inert contracts
  `db97e763d244a98ba6a351b3568658255749b7fa`
  and `ccfbe7e947e82c3865651f6aeaf90dbbd1a07c20`
  pin the new child/parent left-only markers,
  and independently stage a PRIVATE
  left-edge side BBOX QML/config while
  asserting unchanged real production source.
  Technical details in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  latest left staging checkpoint
  `d54fc99cd2e2e7b32ae591112b7c434c76e72b43`.
- **NEXT SINGLE LOCAL GATE**: user launches one
  fresh clean permission-restricted temporary
  `dev` clone, never touches any
  original potentially divergent `dev`
  checkout; four inert Wull pointer contracts
  must pass, then ONLY new explicit real
  LEFT candidate A/B on a newly owned
  isolated nested Niri, with independent
  matched underlay controls, genuine bridge/
  private Rust body response, positive
  empty-margin pass-through and verified
  cleanup. Read published unique exact-source
  `docs/wull-mask-left-*.json` first;
  FAILED/INCONCLUSIVE cannot qualify left.
  After all four edges achieve private
  pointer PASS, NEXT scope is precise
  curved silhouette/input region design,
  hover and popup, actual visuals,
  multimonitor/hotplug/fractional scale,
  lifecycle/reload/suspend, and
  canonical-wide/long-run validation.
  Do not silently swap the shipped full-host
  Region for a rectangular private test
  BBOX. Leave shipped Wull default-off,
  real production Region and `stable`
  untouched before further evidence.


## Checkpoint — 2026-10-02 first left physical gate INCONCLUSIVE; five private witness analysis next

- Exact-source REAL LEFT edge single-output,
  scale=1 private candidate report
  `docs/wull-mask-left-20261001T175020Z-5a11aa42-5b72e0e3294c.json`
  source `5b72e0e3294c32276c306b3c6911fd9fa4e79fb1`
  was independently published as **INCONCLUSIVE**,
  NOT PASS. Seven earlier real checks passed,
  including baseline native pointer controls,
  actual baseline and private candidate
  body bridge + Rust, full production empty
  margin blocked with no false activation,
  and correctly aligned exterior underlay
  controls before/after baseline teardown
  and after private LEFT candidate remap.
  Eighth test `candidate_empty_margin_pass_through`
  recorded exactly one real underlay click,
  no accidental body activation, but
  `target_alignment=off_target`.
  The runner correctly marked
  `candidate_margin_target_unverified`.
  Owned nested compositor/layers/Rust cleanup
  and host output invariance passed. This
  is not evidence that the LEFT candidate
  mask is faulty or that it passes.
  The separate latest dynamic TOP, BOTTOM
  and RIGHT private one-output, size=1
  A/B trials remain real PASS within
  their limited scopes. Previous TOP
  off-target pointer drift remains
  a separate unresolved observation.
- New input-FREE retrospective path now
  staged, not yet run:
  `scripts/wull-private-left-margin-diagnostic.py`
  commit `5b09ca99107ea1c7107c3d32d3e1e40eabc1077e`,
  `scripts/wull-private-left-margin-publish.py`
  commit `008cd132c79dd657b361e76b8a8ef64aea5bac02`,
  plus dedicated inert negative contracts
  `scripts/test-wull-private-left-margin-diagnostic.py`
  (latest fix `f4024d971c7971b38472f3fd93cd6e4ab16ccdf2`)
  and
  `scripts/test-wull-private-left-margin-publish-contract.py`
  commit `cfb24dc8fc9f58fe9dc1ccbbd0ebf7b8e1b2c68e`.
  EXACT report/blob, original child/target
  source SHA and same-user prior private log
  are all allowlisted. The old report's
  first 7 qualified controls imply exactly
  FIVE real underlay clicks: disabled
  body center, enabled exterior,
  after-unmap exterior, candidate exterior,
  candidate last empty margin. The
  three exterior controls target the
  same position and must be consistent
  within 12 px of one another.
  The old disabled-center matched
  underlay witness shares exactly
  the LEFT margin's REQUESTED x;
  its requested y is
  47 px above disabled center within
  at most 1 px round-to-even ambiguity.
  Using only these relative geometry
  anchors, the helper emits coarse
  direction/magnitude buckets, flags
  whether the last click landed near
  the previous disabled-center
  or candidate exterior positions,
  and NEVER exports raw x/y, log,
  exact private paths, sockets or
  host identifying data. The
  publisher can non-force push only
  its own single categorical result
  `docs/wull-pointer-left-margin-drift-20261001T175020Z-5a11aa42-5b72e0e3294c.json`
  from a clean permission-private
  throwaway `dev` clone, leaving
  the owner's original possibly
  divergent checkout untouched.
  The full technical design and
  source-derived caveats are in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  updated `4933959a2f374f9d72d9ffa11efc79dd1ca5cb6a`.
- **NEXT LOCAL ACTION:** on user's host,
  one permission-private fresh `dev`
  clone; run BOTH new inert contracts;
  then explicitly run only
  `python3 scripts/wull-private-left-margin-publish.py
  --publish-existing-left-margin-off-target`.
  This reads the previous private log,
  publishes a safely categorical result
  and **does not execute Niri/Rust/wdotool**.
  If private log is missing or any
  witness/source is ambiguous, stop
  INCONCLUSIVE, DO NOT launch a new
  blind physical pointer test, expand
  source scope or lower any position
  tolerance. Review the unique
  sanitized report first to decide
  whether the next physical trial
  needs additional phase-local input
  instrumentation. Production Region,
  default-off and `stable` remain
  unchanged. Precise curved visual
  input Region, hover/popup, multioutput,
  fractional scaling, hotplug, suspend,
  long-run reliability, aesthetic
  acceptance and canonical-wide
  validation remain separate after
  four-edge private pointer qualification.


## Checkpoint — 2026-10-02 existing left drift verified; left pre-body differential source staged

- The previously staged no-input retrospective LEFT
  analysis has now actually completed and published
  `docs/wull-pointer-left-margin-drift-20261001T175020Z-5a11aa42-5b72e0e3294c.json`.
  The exact original left test source
  `5b72e0e3294c32276c306b3c6911fd9fa4e79fb1`
  remains **INCONCLUSIVE** only at its last
  candidate empty-margin click; the first
  seven real pointer controls and cleanup
  passed. The five-witness exact-session
  classifier independently found the
  final actual underlay click displaced
  96+ pixels in at least one relative
  axis, BOTH axes changed, horizontal
  positive/vertical negative, near
  neither its former disabled-body-center
  nor candidate exterior actual point.
  This is prior real input log evidence,
  NOT proof of any virtual backend,
  compositor or candidate input-mask
  root cause. New TOP, BOTTOM and RIGHT
  dynamic private single-output scale=1
  separate real PASS reports remain
  source-pinned. The old off-target TOP
  trial remains a distinct unresolved
  flakiness observation.
- New source-only guarded physical
  differential on **LEFT ONLY**:
  child `3e9f843906edf1654ef3b150bad9de2413e61826`
  adds an independent
  `candidate_left_margin_before_body_control`
  on the SAME left empty-host-margin target
  immediately after a matched candidate
  exterior click and BEFORE the real
  candidate-body bridge/Rust click.
  It requires exact matched underlay
  alignment at the unchanged 6px
  tolerance and zero accidental
  bridge/Rust response; else stops
  FAILED on matched+false activation
  or INCONCLUSIVE on absent/ambiguous/
  off-target coordinates. If it PASSes,
  the runner still performs the original
  adjacent real body click then the
  original final margin target, without
  interposed actions. This can bound
  whether the second margin misses
  only after a Wull body event, but
  does NOT identify causality.
  Parent `9c36779c39d08cdc95c9882fe79973c02b8622e6`
  exact-source pins the new child blob
  `8dd65a0d10d5a8d1475be0939dbb78a0f977dd35`
  and increases audited coordinator
  history from 14 to 15 revisions.
  Separate inert pointer tests updated
  `c1f274ecc8fe44ec663cdd7a3984dbc81db4ef85`
  for pure differential decision and
  `ddf0f55afbd28ea3dab93986ab3a27952a11c5c5`
  for candidate source pin and left-only
  witness. Documentation in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  checkpoint
  `38798daceb1df9e58be614aa947fefe5f72a8d8c`.
  Existing production Region/default-off,
  native Rust and top/bottom/right
  original pointer test semantics
  unchanged. No LEFT differential
  local real result exists yet.
- **NEXT SINGLE LOCAL GATE:** fresh
  clean permission-private temporary
  `dev` clone, NEVER reset/rebase/merge
  the maintainer's original potentially
  divergent local branch. Run all FOUR
  existing inert Wull pointer contracts,
  then ONE explicit
  `python3 scripts/wull-manual-nested-pointer.py
  --acknowledge-nested-pointer-candidate-left`
  on a verified newly owned nested
  one-output Niri using native absolute
  backend, real private Rust and the
  added pre-body same-target witness.
  Require unique exact-source sanitized
  `docs/wull-mask-left-*.json` report;
  inspect pre-body candidate margin
  result and direct body→final-margin
  result independently. If either
  misses coordinates, STOP
  INCONCLUSIVE and analyze phase
  without blind retry. Do not
  mutate `stable`, production
  QML or host configuration.
  Four-edge private pointer gating
  does NOT qualify curved exact
  silhouette, hover/popup/visual
  fit, multioutput/fractional-scale,
  hotplug/reload/suspend/lifecycle,
  reliability or canonical-wide
  validation.


## Checkpoint — 2026-10-02 four-edge BBOX live PASS; inert curve feasibility next

- New exact-source REAL LEFT differential
  `docs/wull-mask-left-20261001T180740Z-22d0c52b-df1cb0eef52e.json`,
  `source_sha=df1cb0eef52e4089833704c32510d65239c5ae41`,
  is **PASS** on one verified newly owned
  Niri output, private source-shadow BBOX,
  scale=1. The new independent margin
  witness BEFORE the candidate-body event,
  genuine body bridge + private Rust,
  and unchanged final adjacent
  candidate-body→margin witness ALL
  passed, with exact underlay alignment
  and zero accidental body activation.
  Production A/B controls,
  post-baseline-unmap witness,
  new candidate exterior,
  host output invariants and full
  owned cleanup passed separately.
  Latest four unique physical private
  dynamic BBOX A/B receipts are now
  TOP `docs/wull-mask-candidate-20261001T173129Z-ce33db3c-8efa0b7d7341.json`,
  BOTTOM `docs/wull-mask-bottom-20261001T173542Z-10d599c4-9ac701f650dc.json`,
  RIGHT `docs/wull-mask-right-20261001T174248Z-cd6a3010-cdbe02bbcd61.json`,
  LEFT new report above; all FOUR are
  real individual bounded PASSes.
  Earlier separate TOP/LEFT real
  off-target runs and their
  retrospective categorical drift
  reports REMAIN unresolved
  reliability observations. No
  production Wull input Region,
  Rust native backend, defaults,
  host setup or `stable` has
  been changed.
- New source-only visual-shape
  feasibility research:
  `scripts/wull-silhouette-band-prototype.py`
  commit `d9d5ab6d4b80fb1fbf22292c693a66e5464bded3`
  plus strict inert
  `scripts/test-wull-silhouette-band-prototype.py`
  latest fix
  `d7465907230d047c0ff647da6b884000f121856a`.
  Pins the exact current
  `WaterDropletBody.qml` four-cubic
  source blob, models the static
  76x92 path interior with
  400 samples per cubic and
  1.7px conservative
  side inset at three samples
  per 1px row, coalesces
  identical spans and maps
  rectangles through source-measured
  four-edge rotations/host offsets.
  The independent prototype-formula
  estimate is ~43 rectangles,
  ~3006 interior px versus
  6992 px body BBOX (~43%),
  showing a STATIC tight
  alpha-like hit approximation
  may exclude too much visible
  tip/stroke/halo/animated body.
  This estimate is NOT
  live QML/Quickshell performance,
  visual-ergonomic acceptance,
  production release approval
  or a maintainer-host run
  of the new Python contract.
  No script generates a live
  mask or injects pointer input.
  Official Quickshell `Region`
  documents nested Rect/Ellipse
  compositing but has no
  verified arbitrary Qt
  `PathCubic` alpha hit mask.
  Design analysis and every
  evidence boundary in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  (latest checkpoint commit
  `26dd1c1b2ff71083f250637aa77b9739281ce464`).
- **NEXT SOURCE / LOCAL GATE:** run
  ONLY the new static silhouette
  inert contract on a clean
  throwaway current `dev`
  clone to check real
  Python/Qt-source agreement;
  do NOT instantiate a
  43-Region live mask
  or replace the currently
  source-shadow tested
  BBOX automatically.
  Next resolve accessible
  interactive footprint,
  animated bob/sway/stretch/
  tilt/squash + pulse halo
  envelope and rotation/scale
  transform obligations,
  Quickshell version/API
  compatibility and nested
  pointer+hover witnesses
  BEFORE any source-guarded
  private visual mask trial.
  Independently test
  repeatability of the
  observed rare off-target
  virtual-pointer transients.
  Actual curved-shape/halo
  quality, hover/popup,
  multioutput/fractional
  scaling, hotplug,
  suspend/reload/lifecycle,
  long-run resources
  and canonical-wide
  validation remain
  unqualified.


## Checkpoint — 2026-10-02 static curve and motion footprint: separate inert source risk gates

- Latest four-edge independently published
  PRIVATE, scale=1, single-output Niri dynamic
  BBOX trials all remain real PASS; they
  do not qualify the final production
  hit shape, animated geometry, hover or
  rare pointer reliability. The earlier
  distinct TOP/LEFT off-target old
  runs and retrospective classification
  reports remain unresolved, and no
  new runtime or host-local geometry
  test receipt is available for this
  checkpoint.
- New strictly inert animation/scale
  feasibility tool
  `scripts/wull-motion-footprint-feasibility.py`
  first source commit
  `cf700d32453b20742b4a32882a1b7516d22d0a32`,
  corrected original body
  implicit-dimensions pin
  `6a9aeeb9d4738e3fc11ebfaaf5c6a603bb45b3c7`,
  deterministic nominal bob
  float normalization
  `c6968fc7963839ee33f59c0c89d59c07aec44bfa`.
  Its independent INERT
  source/trust/negative contract is
  `scripts/test-wull-motion-footprint-feasibility.py`
  commit
  `8786afdbbebb037812f37d8dd27e4fad734321ca`.
  The tool SHA-pins ALL four original
  production body, bridge, wrapper
  and host-QML source blobs; no
  Niri, Quickshell, Rust, native pointer,
  live input Region or host config
  is touched. It derives ONLY the
  nominal input-clamped source-formula
  values, not actual frame extrema
  through Qt SpringAnimation/OutBack,
  actual mask mapping, observed Rust
  state frequency, or rendered pixels.
- Significant SOURCE-LEVEL
  counterexample to static 76x92
  mask promotion: the bridge permits
  target `squash=0,stretch=1`,
  explicit body bottom-origin
  `yScale=1.06`, and the upper
  Bézier point at item y=2
  would map to item y=-3.4
  when other transforms
  are analytically held at
  identity. With actual source
  TOP body host offset y=3,
  tip would nominally reach
  host y=-0.4, outside both
  original test-candidate
  static body bbox top y=3
  and host y=0. This is an
  admissible isolated
  source-state risk, NOT an
  actually witnessed rendered
  Qt/Rust pose. Simple
  source-size arithmetic
  also gives top static
  body 114x138 at parent
  scale1.5 vs host112x98,
  and rotated side body
  138x114 vs host98x112;
  exact Qt parent scale
  pivot, compositor mapping,
  clipping and region refresh
  remain unverified.
  Bridge-clamped nominal
  `state_xScale` .925–1.075
  and `state_yScale`
  .905–1.095, root tap
  squash scale targets
  .98775–1.035, and
  state/sway expression
  nominal angles -9.6–
  +10.59 degrees MUST NOT
  be mistaken for guaranteed
  live SpringAnimation
  extrema. The pulse halo
  at full intensity has
  nominal 76x90.16
  local extent; treating
  any bright halo/ripple
  as a click target is
  a separate UX decision.
- This is why even the
  existing source-pinned
  four-cubic static
  approximately 43-band,
  43%-BBOX conservative
  outline study cannot
  be promoted to a moving
  exact hit shape, or
  used to claim actual
  Quickshell runtime
  performance. Current
  real full-host mask,
  Wull default-off,
  native backend and
  `stable` remain unchanged.
  Expanded technical
  design with precise
  source-bounded vs
  unqualified runtime
  observations in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  checkpoint commit
  `c755f46276aae77aa01922d57a3b42b6f37639ea`.
- **NEXT SINGLE LOCAL ACTION:**
  run BOTH standalone
  inert geometric test
  scripts on a fresh
  clean private `dev`
  clone:
  `python3 scripts/test-wull-silhouette-band-prototype.py`
  and
  `python3 scripts/test-wull-motion-footprint-feasibility.py`;
  print BOTH inert redacted
  model summaries, record
  PASS/FAIL locally.
  No host pointer input
  or production changes.
  Then design an explicit
  PRIVATE motion-aware
  body-interaction
  hypothesis with generous
  touch target for all
  pose/tip boundaries,
  possible decorative
  halo distinction,
  exact source-pinned
  Quickshell runtime
  version and real
  `mapToItem`/Region
  live geometry probes.
  Qualify each edge,
  sizes 0.65/1/1.5,
  motion extrema, hover,
  popup, multimonitor
  fractional/hotplug,
  lifecycle/resource
  and canonical-wide
  behavior separately.
  Do not implement
  a production mask
  based on the 43-band
  feasibility or
  nominal transform
  arithmetic alone.


## Checkpoint — 2026-10-02 private inert geometry/motion receipt staged; await real local execution

- Newly added explicit
  `scripts/wull-motion-inert-publish.py`
  commit
  `d28f85553cec359aca1c66399b636eaae07813bd`
  runs both reviewed
  STATIC four-cubic and
  NOMINAL motion/scale
  independent Python
  inert tests and
  their source-only
  model summaries
  ONLY in a clean
  user-private scratch
  clone of remote
  `dev`. It exact
  Git-blob pins all
  four original
  production
  body/bridge/
  wrapper/host
  QML sources
  and both reviewed
  model/test programs,
  enforces repository
  origin, no untracked
  paths and safe
  single-file
  non-force Git
  publication. An
  updated current
  remote source is
  reaudited before
  test and publication;
  concurrency retries
  may rebase ONLY
  the newly created
  sanitized RECEIPT
  commit inside
  the private
  temporary clone,
  not the user's
  original checkout.
  No Niri, Quickshell,
  Rust, pointer input,
  real production
  Region or host
  config changed.
  The new
  `scripts/test-wull-motion-inert-publish-contract.py`
  commit
  `f7bf4d6eebbcd43344503f7cbaf717a4e64e9c66`
  adds independent
  inert pins, schema
  negative cases,
  redaction and
  safe private-push
  contract checks.
  Full technical
  handoff checkpoint
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  commit
  `f19bdcdeabf8ee0e2adf269a7c207ad75ba12594`.
- **NEXT LOCAL GATE**:
  one new mode-0700
  fresh private dev
  clone and SINGLE
  opt-in
  `python3 scripts/wull-motion-inert-publish.py
  --acknowledge-inert-motion-receipt`
  after the additional
  inert publisher
  safety contract
  passes. It
  internally runs
  both standalone
  geometry and
  nominal motion
  test programs
  and emits exactly
  one new redacted
  `docs/wull-motion-inert-*.json`
  receipt only if
  BOTH succeed.
  READ THE EXACT
  published report
  before declaring
  local source
  arithmetic PASS.
  No actual live
  mouse/hover, Qt
  transform
  composition,
  sprite animation,
  popup, multioutput
  or canonical-wide
  acceptance may be
  claimed from this
  pure source-based
  result. Even if
  both inert tests
  pass, do not
  select a final
  production mask
  before independently
  assessing accessible
  animated core vs
  decorative halo,
  real Quickshell
  version and
  dynamic
  mapToItem/Region
  pointer behavior,
  four edges,
  scales .65/1/1.5,
  fractional/multioutput,
  lifecycle and
  rare old TOP/LEFT
  pointer drift.


## Checkpoint — 2026-10-02 local inert geometry+motion PASS; private real-QML offscreen phase staged

- Verified new SANITIZED, SOURCE-PINNED,
  actually locally executed inert
  geometry/motion receipt
  `docs/wull-motion-inert-20261001T182922Z-d5584c0e-3e27fdeb5c43.json`
  (`source_sha=3e27fdeb5c43b0a0cbad6c09f02c979bcaa4da07`):
  separate static four-cubic band contract
  PASS and nominal body motion/scale
  arithmetic contract PASS. Static
  43 bands/edge cover 3,006 of
  6,992 unanimated body-box pixels
  with inset. The source nominal
  stretch=1 upper tip may reach
  y=-0.4 relative to the TOP host
  under the isolated authored
  y-scale formula. Crucially
  the published report states
  ACTUAL Qt/QML transformation,
  rendered Rust animation frames,
  Niri region/hover, multioutput,
  canonical validation and
  production mask release were
  NOT RUN. The distinct
  historical TOP and LEFT
  off-target pointer transients
  remain open reliability
  evidence despite new four-edge
  separate static body
  BBOX pointer PASSes.
- A NEW isolated actual
  unmodified-QML offscreen
  fixture is source-staged:
  `scripts/wull-fixtures/motion-geometry/shell.qml`
  commit
  `07c81fef4217f634a8a8910a1903a7d9007c878a`.
  It loads the original
  reviewed
  `AbyssCompanion` and
  `WaterDropletBody`
  at all FOUR output
  edges and THREE
  parent scaling
  configurations
  0.65/1.0/1.5,
  disables animation
  ONLY inside the
  offscreen fixture
  to isolate the
  nominal Qt transform
  mapping and
  samples both
  neutral and
  source-permitted
  stretch=1 states
  for 24 distinct
  actual QML
  measurements.
  Real Qt
  `mapToItem` for
  item-to-host
  body box and
  path tip and
  host-to-stage
  parent scaling
  are measured
  jointly to
  avoid the
  previous
  incomparable
  scale1.5 body
  versus UNSCALED
  host dimensional
  arithmetic.
- New separate
  private exact-source
  runner
  `scripts/wull-manual-offscreen-motion-geometry.py`
  initial commit
  `b12c5db4b4fac4609997d4eb544ec2054f9fe073`,
  hardened
  `9364ab83497111f4b02041f2657c1021ea56171b`.
  It requires an
  entirely NEW
  current-user-owned
  permission-0700
  clean temporary
  `dev` clone
  and trusted
  Git fetch/push
  remote, pins
  fixture and
  original body,
  wrapper, style,
  Config/default
  and unchanged
  perimeter source
  Git blob hashes;
  launches a
  PRIVATE D-Bus
  `QT_QPA_PLATFORM=offscreen`
  Quickshell only
  after stripping
  inherited
  Wayland/Niri
  socket and
  QML override
  environments.
  Strictly requires
  24 unique finite
  pose rows,
  checks all
  source-measured
  host geometry,
  actual host
  stage scaling
  and recovers
  consistent
  tip/static/host
  inclusion flags
  from the private
  numerical QML
  data. If any
  neutral baseline
  geometry
  regresses,
  result is
  INCONCLUSIVE,
  not silently
  accepted.
  Publishes only
  edge/scale
  CATEGORICAL
  stretch-inclusion
  flags, source,
  optional
  normalized
  Qt/Quickshell
  version and
  scope in
  one uniquely
  named sanitized
  `docs/wull-qt-motion-*.json`
  receipt, never
  actual host
  coordinates,
  screen logs,
  sockets or
  screenshots.
  Concurrent
  Git retry
  rebases only
  that fresh
  unpublished
  private clone
  receipt commit;
  never the
  maintainer's
  potentially
  divergent
  checkout.
- An independent
  parser/negative
  inert contract
  `scripts/test-wull-offscreen-motion-geometry-contract.py`
  source commit
  `a71f105cc0420baff4b7cb808a6d4f3cd549d6aa`
  source-pins
  the fixture,
  verifies
  exact
  24-pose
  cross-product
  and rejects
  missing,
  duplicated,
  fabricated
  booleans,
  untrusted
  numeric fields,
  unexpected
  private log
  or
  unsanitized
  public
  receipt
  fields
  without
  launching
  Qt or
  any
  pointer tool.
  Detailed
  scope/evidence
  handoff in
  `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`
  updated commit
  `3f505c93ec5a802702bad5ad8f07ee868e74b4c6`.
- **NEXT SINGLE LOCAL GATE:**
  one new
  permission-private
  clean
  throwaway `dev`
  clone.
  FIRST run
  only
  `python3 scripts/test-wull-offscreen-motion-geometry-contract.py`,
  then ONE
  explicit
  `python3 scripts/wull-manual-offscreen-motion-geometry.py
  --acknowledge-private-offscreen-qt-motion`.
  Inspect
  new distinct
  exact-source
  `docs/wull-qt-motion-*.json`
  report before
  any additional
  physical
  pointer,
  animated
  hover or
  production
  change. This
  is ACTUAL
  Qt frozen-pose
  geometry only,
  NOT a moving
  SpringAnimation
  envelope,
  native Rust
  state,
  Wayland
  input mask,
  multioutput,
  fractional
  scale,
  resource/lifecycle
  or canonical
  release gate.
  Preserve
  default-off,
  existing
  production
  host mask,
  backend
  and
  `stable`.


- **Last pre-local safety refinement**:
  the actual
  original-QML offscreen
  fixture must
  demonstrate that
  it applied the
  intended frozen
  `stateStretch=0/1`
  target state
  BEFORE reporting
  Qt geometry.
  Fixture updated
  `d114a768a26ec6956bfd1f83d14a2aebb6a82e54`,
  latest exact
  blob
  `11df91496a8bb9b18d79498e86d1f734d78dc574`;
  reporter updated
  `82f6f078282dc7a73dd727f1cd003c91dea5391b`,
  blob
  `0dd833ed05d54e9d1045553a1da8be8f66b6511a`;
  inert contract
  updated
  `17632a74eb9b472e39684f44c0eb088314c8c0c3`,
  blob
  `fc98c43a40502e94e493a3d7ce565d969f0d1e8a`.
  Any of 24 missing
  frozen-state
  witnesses makes
  the actual-QML
  test inconclusive;
  it cannot publish
  an unchanged
  neutral 24-pose
  PASS disguised
  as stretched
  geometry.
  See the latest
  technical doc
  amendment
  `45f38dc104697230f05f4deb2df3e83882cc23c0`.
  Run only the
  updated inert
  contract then
  guarded offscreen
  runner in
  ONE disposable
  private clone.


## Checkpoint — 2026-10-02 actual-QML 24-pose first local gate blocked by stale inert assertion

- The maintainer's fresh private `dev` clone at exact source `aa59e2f09c211219fef7a8153fa27abe94efd63b` stopped during `scripts/test-wull-offscreen-motion-geometry-contract.py`: `AssertionError: body.stateStretch = 1`. The guard searched for an obsolete literal even though the already source-pinned QML fixture assigns the stretch target to all actual repeated hosts via `root.bodyOf(hosts.itemAt(i)).stateStretch = 1`. This is a diagnosed inert test assertion mismatch. The actual 24-pose offscreen Quickshell runner was NOT executed; no `docs/wull-qt-motion-*.json` result was published. Do not count any Qt geometry pose as observed.
- A test-only forward fix at commit `d38699b4385d5aeb2a284d65bdaecb5de1823c5f` replaces the obsolete assertion with the precise existing per-host stretch assignment, and additionally checks the neutral `body.stateStretch=0` initialization and fixture's `expectedStretch`/actual frozen-state witness predicate. New inert test blob `73572134c29ccbc448bb0d48290ae7b0e99637c5`. The production QML, offscreen fixture blob `11df91496a8bb9b18d79498e86d1f734d78dc574`, runner blob `0dd833ed05d54e9d1045553a1da8be8f66b6511a`, backend, existing full-host input mask, default-off configuration and `stable` are unchanged. Remote static source comparison found all 13 referenced QML conditions present, but the repaired Python inert contract has NOT yet earned local runtime PASS.
- NEXT: ONE fresh permission-private, clean `dev` clone; recheck its HEAD and run the repaired inert contract. Only if it passes, run the existing acknowledged bounded offscreen runner and inspect one unique new `docs/wull-qt-motion-*.json` source-pinned 24-pose report on GitHub. Do not reuse the failed prior clone, hand-edit the reviewed fixture, relax SHA guards, or treat frozen poses as a live SpringAnimation/Wayland/hover/production mask qualification.


## Checkpoint — 2026-10-02 actual frozen QML 24/24 PASS; independently guarded sampled dynamic gate STAGED

- The local repaired inert contract was followed by the reviewed real Qt offscreen runner; UNIQUE exact-source published receipt `docs/wull-qt-motion-20261001T185752Z-53e5c5cc-72ac0580b12e.json` on `source_sha=72ac0580b12e08c88e74f69ac919e30a93f481f4` reports actual 24/24 PASS at Quickshell 0.3.1. Every one of four edges × three scales × neutral/stretched verified frozen state was observed and parent-scale Qt geometry was consistent. All neutral body boxes remain inside their source static body box and host. On ALL THREE scales, actual frozen stretch=1 makes transformed body ITEM AABB leave the former static body box on all four edges; transformed item AABB leaves host on TOP and BOTTOM; upper path TIP leaves host on TOP. The body item AABB is NOT pixel-exact outline/clipping or an observed input-mask shape.
- A separate report `docs/wull-qt-motion-20261001T190302Z-a0fcad4b-5f5331d7fb6d.json` on `source_sha=5f5331d7fb6d1b689f245e630e0eebfe56fb8b4d` independently repeats SAME frozen categories, 24/24 PASS and QS 0.3.1; source comparison from first to second showed docs, prior report and private dynamic fixture only, no production Wull runtime change. These are two frozen-pose experiments, NOT real animation/hover reliability.
- New SOURCE-ONLY private sampled-motion gate is staged on `dev`: 12 distinct existing original-QML hosts (4 edges, 3 scales), both controlled stretch/release phases, measured Qt 40ms sampled body-box/tip/host geometry; per-host neutral and frozen-stretch guards; live intermediate stretch AND near-target stretch, actual `motionEnabled` and independent bob/sway positive witnesses. Fixture `scripts/wull-fixtures/motion-envelope/shell.qml` blob `0fede26c2dc370234ae1b1702afdca3ea05e33e0`; private runner `scripts/wull-manual-offscreen-dynamic-geometry.py` blob `71262816d9d64c97061c90e03bed9acee76bdc18`; independent negative/sanitized inert contract `scripts/test-wull-offscreen-dynamic-geometry-contract.py` blob `08ca436a007d5d78831655644bee455d77f4cd28`. Runner reuses frozen source/clean-clone guard, pins first frozen receipt and these reviewed blobs, requires local QS version 0.3.1 before testing, enforces 512-KiB private log file size and owned process group cleanup, and may non-force publish only ONE unique sanitized source-SHA-pinned `docs/wull-qt-dynamic-*.json`. Raw coordinates and logs stay private. **The new contract and runner have NOT been executed locally and no dynamic report exists**.
- IMPORTANT: A controlled sampled frame witness is neither a guaranteed complete SpringAnimation envelope nor a real Rust trace; it cannot certify painted contour clipping, Wayland Region, live click/hover, old rare TOP/LEFT pointer drift, popup safety, fractional/multioutput, hotplug, lifecycle/performance or canonical validation. Production full-host mask, backend, disabled-by-default Wull and `stable` unchanged. Phase 4 and Phase 5 remain open.
- **NEXT SINGLE LOCAL ACTION:** start ONE fresh current-user-owned mode-0700 private clean `dev` clone in `XDG_STATE_HOME/hadalis/wull-qt-motion.*`. FIRST run `python3 scripts/test-wull-offscreen-dynamic-geometry-contract.py`, require exact `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS`. Only on that PASS, run `python3 scripts/wull-manual-offscreen-dynamic-geometry.py --acknowledge-private-offscreen-dynamic-motion` from the same fresh clone. The runner fetches latest `dev` and must stop on changed pins or runtime versions. User then enters `tiếp tục`; FIRST inspect an actually published `docs/wull-qt-dynamic-*.json` on GitHub, its exact SHA and per-edge phase witnesses. If no report/INCONCLUSIVE, investigate only the specific failure; do not automatically rerun or move on to physical pointer experiments.


## Checkpoint — 2026-10-02 dynamic report still absent; private QML runner cleanup hardened

- Fresh GitHub `dev` inspection found NO new `docs/wull-qt-dynamic-*.json` after the prior staged dynamic gate. The maintainer has not supplied the prior local status. Do **not** infer inert success, Qt run failure, or a completed dynamic sample from the absence of a published receipt. Existing two 24/24 frozen-pose QML reports remain historical evidence; they do not certify dynamic frames.
- A source-level review of the staged dynamic runner found a real cleanup assurance gap: termination of the `dbus-run-session` wrapper was not sufficient evidence that all owned child processes exited. Test-only fix `d0df7600baecdd320eab4b4534618ccf454eb8cb` now additionally strips inherited `QML_IMPORT_PATH`/`QML2_IMPORT_PATH`, sends TERM to its own process group, checks whether that private group survives, attempts KILL on remaining owned members and fails closed if cleanup is still unverified. No user desktop or shared shell process should be targeted. This change is SOURCE-ONLY; it has NOT been locally exercised. New runner blob `8270d405809bff86599e570399dd05a390e22601`; separate inert test `c923e664eebb49a56a18fd3b45a418ecfff55730` pins it and checks environment/cleanup guard tokens (blob `9a858ca789c5cb7bd3fac778ff844396b726e969`). Dynamic fixture original blob `0fede26c2dc370234ae1b1702afdca3ea05e33e0` and production Wull code remain unchanged.
- NEXT: FIRST retrieve/classify any earlier saved LOCAL dynamic inert/runner status WITHOUT rerunning an uncertain test; the owner can send only allowlisted short `GATE`/`STOP`/source lines, never raw private logs. If an old run had no report, investigate exactly that failure before a fresh retry. If no prior dynamic run exists, use ONE new permission-private clean `dev` clone, require current static blobs, run `scripts/test-wull-offscreen-dynamic-geometry-contract.py` first and only after its token PASS invoke `scripts/wull-manual-offscreen-dynamic-geometry.py --acknowledge-private-offscreen-dynamic-motion`. Inspect exact published `docs/wull-qt-dynamic-*.json` before extending to compositor/pointer tests. Staged source + static inspection alone is NOT a Qt/contract PASS. Maintain default-off Wull, original host mask/Rust backend and untouched `stable`.


## Checkpoint — 2026-10-02 dynamic Qt gate: added independent mapped-frame motion witness; local evidence still absent

- Rechecked current remote `dev` after the last manual command: there was NO new `docs/wull-qt-dynamic-*.json` report. The user's prior local terminal result was NOT received; neither a previously attempted FAIL nor an executed dynamic PASS can be inferred. Do not automatically rerun without classifying any retained previous local status. The two published 24/24 frozen-pose Qt PASS reports remain distinct from real sampled motion.
- Source audit found that requiring `bob_witness`, `sway_witness` and animated `stateStretch` numerically is NOT sufficient by itself to prove that the transformed real QML item *moved* in host coordinates (for example, authored anchors can mask a nominal position property). The privately staged dynamic fixture now retains only locally held per-host previous real Qt `mapToItem` body AABB values, resets these private baselines at the start of EACH controlled stretch and release phase, and explicitly requires a >0.12-unit inter-sample mapped AABB difference before setting `mapped_frame_change_witness` for that host and phase. NO actual coordinate values are included in the public fixture marker or prospective redacted receipt. This is evidence of observed body geometry varying within the sampled phase, not proof that each separate bob/sway component independently moves the rendered silhouette.
- Source-only update: `scripts/wull-fixtures/motion-envelope/shell.qml` exact blob `221c07d0a451ba918e3e2074aeafe389e588f594`; pinned private runner `scripts/wull-manual-offscreen-dynamic-geometry.py` exact blob `12ade72c22912c44aa3e66a2b5aef62c9e8b58f3`; synthetic negative inert contract `scripts/test-wull-offscreen-dynamic-geometry-contract.py` exact blob `1598ab0730667254e0a0bcf0f64393ff2d50fbcd`. The runner now marks a host/phase INCONCLUSIVE if that observed mapped change witness is absent; its previously hardened process-group/QML-import isolation, Quickshell 0.3.1 guard, original renderer source pins, log bounds and sanitized one-report push remain in place. The inert contract pins both new exact blobs and includes a false mapped-motion witness negative case.
- Remote source-agreement audit checked both per-phase private baseline resets, positive mapped-frame witness, allowlisted no-coordinate fixture publication, runner strict phase checks and the inert negative/pin statements. This audit is NOT a locally executed Python/Qt PASS. The next local step remains FIRST classify any previous retained `STOP`/`GATE`/source output; only if no prior dynamic attempt exists run the revised inert contract on ONE NEW mode-0700 privately cloned current `dev`, and only if it prints `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS` invoke the explicit acknowledged offscreen dynamic runner. Inspect the exact new `docs/wull-qt-dynamic-*.json` on GitHub before any real pointer/nested compositor experiment. Keep Wull default off; preserve current production full-host Region, backend and `stable`.


## Checkpoint — 2026-10-02 actual first dynamic run: inert PASS, QML marker inconclusive; diagnose old private log first

- The maintainer returned actual local status for the exact old source `ad79725acda0fe3c61ba6b1afaba700e1a73b78b`: `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS`, then `STOP: private_dynamic_qml_marker_inconclusive`. This proves the old synthetic contract completed, but establishes NO valid Qt dynamic matrix, no witnessed mapped motion and no result receipt. The old runner used a combined stop code for child exit nonzero, fixture `WULL_OFFSCREEN_DYNAMIC_INVALID`, fixture `WULL_OFFSCREEN_DYNAMIC_TIMEOUT`, no geometry marker or duplicate markers. There is NO published `docs/wull-qt-dynamic-*.json` to substitute for this missing local evidence. Do NOT assume an animation bug, true lack of geometry change, or Qt import failure without first reading a **sanitized classification** of the previous run's private `dynamic-qml/dynamic.private.log`. Do not request full/raw logs, coordinates or private paths.
- Source-only forward hardening of the CURRENT dev runner at `c9770356bbbe276828b08171013107eca65e3882` added pure `categorize_private_qml_failure(raw, code, marker_count)`, printing ONLY a fixed non-sensitive failure category before the existing fail-closed stop. Possible categories include FIXTURE_INVALID, FIXTURE_TIMEOUT, QML_IMPORT_FAILURE, QML_SCRIPT_ERROR, QML_COMPONENT_ERROR, QT_PLATFORM_FAILURE, PRIVATE_QS_NONZERO_EXIT and MISSING/DUPLICATE_GEOMETRY_MARKER. Its exact current blob `c152a1fec7a5a1514407d7850549f987923621c2` still source-pins the reviewed private mapped-frame fixture blob `221c07d0a451ba918e3e2074aeafe389e588f594`; unchanged runtime source and private process-group guards. New exact negative inert contract blob `86a684f9a0712b06f160d00adead2cd3faff3291` pins this diagnostic runner and adds synthetic categorical/privacy assertions. These new assertions have been source-staged only; NO local success has been observed at the revised source SHA.
- **NEXT SINGLE LOCAL ACTION: OLD LOG CLASSIFICATION ONLY, NO RERUN.** In the original retained private `wull-qt-motion.*` clone at `ad79725...`, classify the private `dynamic-qml/dynamic.private.log` locally using only predeclared categories, booleans, marker counts, and optionally safe QML basename/line numbers. Never display raw lines, coordinates, paths or environment details. Once classified, investigate the specific old fixture failure or runtime category and fix forward at current `dev` if justified; only then consider a NEW permission-private SHA-pinned rerun. Do not use the stale old clone for reruns. Wull default-off, original production input Region, Rust backend and `stable` remain untouched.


## Checkpoint — 2026-10-02 old local dynamic log: zero markers, zero fixture sentinel, unclassified process result

- The maintainer performed a read-only sanitized diagnosis of the retained old run at exact source `ad79725acda0fe3c61ba6b1afaba700e1a73b78b`. It reported `GATE=MISSING_MARKER_OR_CHILD_EXIT`, `GEOMETRY_MARKERS=0`, `FIXTURE_INVALID=False`, `FIXTURE_TIMEOUT=False`, `ERROR_CLASSES=NONE` and `QML_LOCATIONS=NONE`. Coupled with the previous old run's **actual** `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS` and `STOP: private_dynamic_qml_marker_inconclusive`, this proves no output marker, no known fixture abort sentinel, no standard error recognized by the OLD narrow classifier, and NO eligible dynamic geometry or published receipt. The old classifier does NOT distinguish successful child exit without a marker from child nonzero/crash or log truncation; no exit status was persisted by the old runner. Do not claim a QML crash, wrong geometry, a missing Qt module, a verified lack of stretch motion or a PASS from these facts.
- Next safe LOCAL step: one READ-ONLY second-pass fingerprint of the SAME ORIGINAL private `dynamic-qml/dynamic.private.log` (never a rerun, no original worktree mutation or raw log release). Check bounded file size (particularly whether it is exactly at the runner's 512 KiB file limit), nonempty line count, whether the log contains only startup/shutdown notices, selected *fixed* broad Qt/Quickshell/D-Bus/error/signal keywords and whether any console line includes the expected WULL prefix; emit only allowlisted booleans/categories and coarse counts, never raw messages, paths, screen identifiers or coordinates. If no recognized cause, preserve `UNKNOWN_EARLY_EXIT_OR_MISSING_MARKER` and request an explicitly guarded local run with a separate private exit-code receipt and stage-marker-only instrumentation, not an invented diagnosis.
- The latest dev runner contains its future safe categorical failure diagnostic, and the new mapped-motion witness remains source-staged. Neither retrospectively provides the prior child's exit code. Production full-host mask, source Wull renderers, default-off behavior, backend and `stable` stay untouched; do not progress to physical pointer tests.


## Checkpoint — 2026-10-02 old dynamic private log fingerprint + staged boot/phase diagnostics

- Maintainer's second READ-ONLY fingerprint of retained failed private real-QML run at \`ad79725acda0fe3c61ba6b1afaba700e1a73b78b\`: \`LOG_BYTES=312\`, \`LOG_LINES=3\`, \`LOG_AT_LIMIT=False\`, \`LOG_ENDS_NEWLINE=True\`, \`GENERIC_ERROR_LINES=0\`, \`WARNING_LINES=0\`, \`FATAL_OR_SIGNAL_LINES=0\`, \`QML_RUNTIME_LINES=0\`, \`QUICKSHELL_LINES=1\`, \`DBUS_LINES=0\`, \`PLATFORM_LINES=0\`, \`LIBRARY_LINES=0\`, \`FILE_LIMIT_LINES=0\`, \`WULL_PREFIX_LINES=0\`, \`MAX_REPEATED_LINE=1\`, \`OLD_CHILD_EXIT_CODE=NOT_RECORDED\`, \`GATE=OLD_LOG_FINGERPRINT_COMPLETE\`. Original inert safety test PASS; original actual-QML dynamic run STOP \`private_dynamic_qml_marker_inconclusive\`. This establishes a tiny, complete, unqualified log, not a file-size cutoff, but still DOES NOT identify a premature successful shell exit, loader/CLI behavior, unlogged crash, or cause in source. The original runner discarded the child's return code, so it cannot be reconstructed from the existing 3 lines without unsupported guesses.
- Source-only instrumentation has now been added to PRIVATE offscreen dynamic fixture, **not** production: QML logs ONLY ordered literal markers \`BOOT\`, \`SETUP_START\`, \`FROZEN_VERIFIED\`, \`NEUTRAL_VERIFIED\`, \`STRETCH_SAMPLE\`, \`RELEASE_START\`, \`RELEASE_SAMPLE\`, \`SAMPLING_DONE\`. Stage markers never serialize motion values, host coordinates or screen metadata. Instrumented fixture exact Git blob: \`6e3b5402d32d263868c1ec688925adba0fd7250b\` (staging commit \`62e5418b8ad6d86858a2913c0b5156e0ba7ad154\`). Runner now preserves the privacy of the raw log but emits \`PRIVATE_QS_EXIT_CLASS\` (\`ZERO/NONZERO/SIGNAL\`), \`PRIVATE_QML_STAGES\` count, \`PRIVATE_QML_LAST_STAGE\` allowlisted category, and its existing fixed failure classification. If a geometry marker is present but stage order/census is not exactly complete, stop fail-closed instead of publishing a PASS. Runner exact blob \`9978fa6da0fd2e05b7d52a801fc9cce4a4e5131d\` (commit \`28f07ebbbe2d2a1dcb4d117b03d0160781ad6e83\`); fixture and frozen/production pins unchanged apart from explicit expected fixture revision. Negative inert test exact blob \`4ca0fb183131b67a67920ba60530f85e1631f2be\` (commit \`09feece3079e78cd12ffac49c77864767f7c34ea\`) source-pins the changes and tests synthetic complete, absent, duplicate and unexpected stage markers plus child return classes. No dynamic private runtime PASS or NEW local Python inert PASS has been observed for this staging revision.
- **NEXT SINGLE LOCAL GATE (explicit user action only)**: ONE NEW owned permission-0700 clean remote \`dev\` clone in a new private state folder, not the old failed clone. First pin and run the current \`scripts/test-wull-offscreen-dynamic-geometry-contract.py\` and require its exact \`WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS\`. Only then run the explicit \`scripts/wull-manual-offscreen-dynamic-geometry.py --acknowledge-private-offscreen-dynamic-motion\`. Report ONLY its controlled \`PRIVATE_QS_EXIT_CLASS\`, \`PRIVATE_QML_STAGES\`, \`PRIVATE_QML_LAST_STAGE\`, \`PRIVATE_QML_FAILURE_CATEGORY\`, STOP and sanitized unique report marker. If the runner produces a receipt, validate full report source SHA and observed frame witnesses before attempting a Niri input test. If no BOOT stage, compare isolated launch with a separately approved frozen known-good startup control; never infer real animation regression without a loaded and observed fixture.
- Keep production full-host Region, disabled-by-default Wull, original QML/Rust backend and \`stable\` unchanged. Source-only safe instrumentation is NOT a locally verified PASS.


## Checkpoint — 2026-10-02 second actual dynamic run: child nonzero before BOOT; bounded private log fingerprint staged

- Maintainer ran the SHA-pinned dynamic private Qt gate again in a NEW private clean `dev` clone (source `c1ab9cdbbb5a23f8dd83c0b8926f2110ad6d1948`). Local stdout: `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS`; `PRIVATE_QS_EXIT_CLASS=NONZERO`; `PRIVATE_QML_STAGES=0`; `PRIVATE_QML_LAST_STAGE=NO_BOOT`; `PRIVATE_QML_FAILURE_CATEGORY=PRIVATE_QS_NONZERO_EXIT`; `STOP: private_dynamic_qml_marker_inconclusive`. Original runner returned no dynamic receipt and no compositor/pointer/production edit was attempted. This is direct **Qt process startup/fixture load** blockage, NOT evidence about actual QML animation geometry or input. The new result does not explain the origin of the child's nonzero exit; neither a specific Qt import problem nor QML parse bug is verified.
- Earlier first attempt's 312-byte / 3-line log at `ad79725...` is from an OLD different execution. Do NOT present its size or line counts as evidence for the newer `c1ab9cd...` log. The new retained private scratch contains its own `dynamic-qml/dynamic.private.log`; never expose raw contents, local path, screen coordinates or environment details.
- Compared the current dynamic runner startup against the earlier real-Qt frozen fixture runner: both launch the fixture through a private offscreen `dbus-run-session -- qs --path <isolated shell.qml>`, with the same on-clone reviewed symlink dependencies. The dynamic gate additionally drops inherited QML import paths, hard-limits log size, and adds explicit stage markers. Prior frozen 24/24 successes are **historical** and do not alone establish whether the CURRENT local Quickshell environment or new fixture can still boot.
- Added a strictly READ-ONLY bounded input/fixed-schema local log classification helper `scripts/wull-private-offscreen-boot-fingerprint.py` (source blob `2c7a4e069492c1a72d321f91fa509d9d94736002`, commit `17473b48fff8563a4a835cf06b9722e0c7eefa7e`), with synthetic privacy/negative contract `scripts/test-wull-private-offscreen-boot-fingerprint.py` (blob `a9b5116454540ca4a95c085e93509bd2312704b7`, commit `2a10344ccc8ef2746e567df3a66e2d1d493db881`). The helper verifies the exact original clone source/owned scratch/safe origin, reads ONLY its bounded retained log, emits predeclared category + safe-vocabulary + length-band classifications per line and counts, and NEVER prints the private original log lines or starts Qt. The test is SOURCE-STAGED but NOT YET RUN locally. This helper does NOT reconstruct an exit code or claim a root cause.
- **NEXT**: run the inert helper contract in a separate fresh read-only tool clone and classify the *newer retained* original `c1ab9cd...` log, requiring output `WULL_PRIVATE_BOOT_FINGERPRINT_INERT_PASS` before accepting its classifier. If exact logged clues are still unclassified, design an explicitly acknowledged isolated **minimal ShellRoot vs previously successful frozen QML control** probe under the same current private offscreen env to separate local Quickshell CLI/Qt startup changes from dynamic fixture load. Do NOT rerun a full dynamic sweep or touch production based on inference; Phase 4/5 remain open, Wull default off, full-host Region retained and `stable` untouched.


## Checkpoint — 2026-10-02 repeated pre-BOOT dynamic Qt failure, controlled startup A/B/C isolated

- The owner's *newer* permission-private local attempt (source `c1ab9cdbbb5a23f8dd83c0b8926f2110ad6d1948`) achieved `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS` but the actual Quickshell child returned `PRIVATE_QS_EXIT_CLASS=NONZERO`, `PRIVATE_QML_STAGES=0`, `PRIVATE_QML_LAST_STAGE=NO_BOOT`, `PRIVATE_QML_FAILURE_CATEGORY=PRIVATE_QS_NONZERO_EXIT`, then fail-closed STOP. The exact log from that same clone was independently fingerprinted after an inert PASS: 312 bytes, 3 lines, no Wull marker; line 1 had safe terms CONFIG and QML but matched none of the existing failure categories, line 2 matched none, line 3 contained QUICKSHELL. A generic config/QML startup clue is not enough to assert an import error, argument error, source syntax error or cause. No actual dynamic observations; do not conflate this with the successful *historical* frozen 24/24 reports.
- Compared reviewed frozen and current dynamic launch implementation. Both use a private temporary `shell.qml`, reviewed source symlinks, private XDG directories, `dbus-run-session -- qs --path`, offscreen platform and cleared compositor socket environment. The dynamic runner additionally removes inherited `QML_IMPORT_PATH` and `QML2_IMPORT_PATH`, sets a log file size limit and expects staged QML markers. The historically successful frozen runner has NOT been rerun on the current local environment, so it cannot rule out common current startup or isolated path failure.
- Staged a **separate**, explicit-opt-in, bounded, NON-PUBLISHING private actual-Qt startup control runner `scripts/wull-private-offscreen-boot-controls.py` (Git blob `7c0a29bcaac7d576615ce20bd1b15b021cb951c0`, commit `53700c631144fbc1b788f0e344a5b4ecd951495b`): three independent 0700 private `dbus-run-session` offscreen launch environments. `MINIMAL_DYNAMIC_ENV`: synthetic minimal ShellRoot with dynamic-like import-path sanitization. `FROZEN_DYNAMIC_ENV`: EXACT source-pinned formerly passing frozen Wull fixture with dynamic-like import-path sanitization. `FROZEN_HISTORICAL_ENV`: SAME frozen fixture under historical import-path inheritance. Each uses separate `XDG_*`, hard file-size limit, short timeout, owned private process-group cleanup, source + frozen fixture checks and the recorded Quickshell 0.3.1 guard. stdout contains only fixed per-control PASS/INCONCLUSIVE, ZERO/NONZERO/SIGNAL/TIMEOUT, ONE/NONE/MULTIPLE marker, fixed fixture-abort and Quickshell-presence booleans. It stores any original control logs ONLY locally and never publishes a report, runs pointer input, touches existing production UI or calls the dynamic production mask. Distinct read-only `scripts/test-wull-private-offscreen-boot-controls.py` (blob `3731898020bd9a844ea8238bdbbc36b192ec9dc5`, commit `605cc2b6a923805227a3788925aa6930045afa7a`) source-pins and synthetically tests marker/abort classifiers and launch safety. Both new sources are STAGED, not executed/verified locally.
- **NEXT SINGLE USER LOCAL COMMAND**: NEW mode-0700 permission-private clean `dev` scratch clone; assert the two exact Git blobs above; run `scripts/test-wull-private-offscreen-boot-controls.py` and require `WULL_BOOT_CONTROLS_INERT_PASS`; only on PASS, invoke `scripts/wull-private-offscreen-boot-controls.py --acknowledge-private-boot-controls`. Report only printed categorical result lines. Branch-dependent interpretation: MINIMAL FAIL suggests general isolated Quickshell runtime/bootstrap; MINIMAL PASS/FROZEN_DYNAMIC FAIL suggests original Wull/dependency loading; FROZEN_DYNAMIC PASS plus the prior dynamic NO_BOOT points toward dynamic fixture-specific bootstrap and will warrant a source-level QML syntax/import audit; FROZEN_HISTORICAL PASS but FROZEN_DYNAMIC FAIL suggests inherited QML import environment matters. These are provisional discriminators, NOT root-cause proof. Neither this isolated control nor prior frozen proof qualifies dynamic geometry or production Region. Keep Wull default off, original full-host mask and `stable` unchanged.


## Checkpoint — 2026-10-02 three private offscreen startup controls uniformly pre-BOOT inconclusive

- The maintainer ran source-pinned startup controls on EXACT `7c9e01dcd3db964a837b12755b088dd2594c9b6d`, after `WULL_BOOT_CONTROLS_INERT_PASS`. All three PRIVATE nonpublishing controls: `MINIMAL_DYNAMIC_ENV`, `FROZEN_DYNAMIC_ENV`, and `FROZEN_HISTORICAL_ENV`, returned `INCONCLUSIVE`, `EXIT=NONZERO`, `MARKER=NONE`, `FIXTURE_ABORT=NO`, `QS_MENTION=YES`, `CONTROL_VERDICT=STARTUP_ISOLATION_INCONCLUSIVE`. The minimal ShellRoot case contains NO Wull dependency. Therefore the blocked observation point is SHARED private Quickshell startup or fixture/config selection and cannot be asserted to be a Wull dynamic animation regression. Do NOT interpret older frozen 24/24 PASS as proof that the *current* local runtime or isolated environment still loads.
- The separate *previous* actual dynamic failure at `c1ab9cdbbb5a23f8dd83c0b8926f2110ad6d1948` was also pre-BOOT with NONZERO child; its fingerprint was 312 bytes and three lines with one safe CONFIG/QML mention and one QUICKSHELL mention. Those are measurements of that old log, NOT of the new three startup controls. The three new private control logs are retained ONLY locally at the maintainer-owned previously reported scratch, each under `boot-controls/<test-lowercase>/control.private.log`. No full raw log, filesystem path, text, coordinates, or environment values should be shared.
- The official Quickshell 0.3.1 CLI documentation supports `--path` with a QML-file path; this rules out an unsupported CLI *syntax assumption*, but not a current launcher/runtime/config path failure, nor user-local sandbox/policy failure. Next action is ONE READ-ONLY local comparison of the three retained private control logs, using the already source-pinned allowlisted `scripts/wull-private-offscreen-boot-fingerprint.py` classifier (`2c7a4e069492c1a72d321f91fa509d9d94736002`) and NEVER launching Qt. Print only fixed categorical per-line signatures, bounded counts and whether the raw files are internally identical (boolean, not hashes); optionally compare signatures to the previously inspected separate dynamic log without conflating clone/source timestamps. If all signatures are the same and generic, treat cause as UNKNOWN_SHARED_PRIVATE_QS_BOOT; then plan a minimal launcher/config-path-specific private control rather than another full Wull dynamic sweep. If one log differs, investigate its categorical diagnostic first.
- Current previously reviewed nonpublishing three-control probe `scripts/wull-private-offscreen-boot-controls.py` blob `7c0a29bcaac7d576615ce20bd1b15b021cb951c0` remains unchanged and still requires explicit private owner invocation. Phase 4 actual dynamic QML gate NOT qualified, no `docs/wull-qt-dynamic-*.json`, real pointer/Niri multioutput and production mask acceptance NOT qualified. Maintain production full-host Region/default-off Wull and untouched `stable`.


## Checkpoint — 2026-10-02 uniform bootstrap fingerprints; private Qslog postmortem staged

- Maintainer's READ-ONLY classification of exact three retained CONTROL logs from earlier source `7c9e01dcd3db964a837b12755b088dd2594c9b6d` found each had exactly THREE log lines and the IDENTICAL FIXED CLASS/SAFE-TERM/LENGTH signatures: line 1 UNCLASSIFIED + CONFIG/QML + MEDIUM; line 2 UNCLASSIFIED + NONE + MEDIUM; line 3 QUICKSHELL_MESSAGE + QUICKSHELL + MEDIUM. Raw logs are NOT identical; their byte sizes were 335/334/337. Because ALL three actual Qt startup controls also exited NONZERO before any fixture marker, the common failure remains BEFORE any meaningful Wull dynamics. The matching three-line signatures are compatible with Quickshell's well-documented standard startup banners (launching config; shell/path ID; saving internal logs), **but cannot prove these are the actual messages** because content intentionally remains private.
- External verification against Quickshell upstream 0.3.x CLI and public startup examples: `qs --path` accepts an exact QML file path; `qs log` reads a specified dead instance's binary `log.qslog` without launching a new shell. The observed text-only captured console logs might therefore contain just standard startup banners while a fuller diagnostic was stored in a separate Quickshell internal instance log. This is an UNCONFIRMED hypothesis until exact banner templates and the log path are verified locally from the preserved control log; never scan global user sessions or use `qs list`/unqualified `qs log` to retrieve another instance.
- Added source-only PRIVATE READ-ONLY `scripts/wull-private-qslog-postmortem.py` Git blob `edd1b35e4a20706daf8d72ee8d8d0ffec7943e08`: accepts ONLY the original owner-owned permission-private `wull-qt-motion.*` scratch with exact old SHA and pinned original classifier, validates exact three known startup banner templates, enforces expected per-control original `shell.qml` path match and a specific `XDG_RUNTIME_DIR/quickshell/by-id/<id>/log.qslog` path (no arbitrary paths), verifies log ownership/size/symlink constraints and optionally invokes ONLY `qs log` for that explicit file IF local CLI help recognizes safe file-read syntax. All decoder output is reclassified through the existing fixed-vocabulary privacy helper; original log text, private paths and identifiers are NEVER printed. It never launches a configuration, follows a log or changes any repo/desktop source. If internal QS log is missing, no assumption about the original startup failure; report unavailable rather than falling back to global instance logs.
- Separate inert synthetic source-pin/negative-privacy test `scripts/test-wull-private-qslog-postmortem.py` exact blob `528816fcb986f101117857833fccaa3e84d79e52` covers standard/wrong-root/unexpected-banner/unsafe-path formats, symlink rejection, bounded text and no-Qs-launch source contract. Both new files were staged directly on `dev` but have **NOT** been run locally; a reviewed source pin is NOT an inert PASS. Continue single owner action: NEW read-only ephemeral `dev` clone to require exact two file blobs, run the synthetic inert test FIRST; only on PASS invoke the script against the previously retained OLD source `7c9e01dcd3db964a837b12755b088dd2594c9b6d` original scratch. Publish only allowlisted terminal output. If all three banners verified and own internal logs decode, investigate the categorical actual error; if not, mark INCONCLUSIVE and design a separate tightly bounded startup-focused probe rather than rerun the full dynamic Wull test. Production mask, original backend, default-off Wull and `stable` remain unchanged.


## Checkpoint — 2026-10-02 all three internal Qslogs only repeat startup banners; isolate common Qt boot

- Maintainer ran `scripts/test-wull-private-qslog-postmortem.py` on a fresh read-only `dev` clone: `WULL_PRIVATE_QSLOG_POSTMORTEM_INERT_PASS`. Explicit read-only `qs log` postmortem against the exact retained original control clone source `7c9e01dcd3db964a837b12755b088dd2594c9b6d` confirmed all three bootstrap logs ARE precisely Quickshell's recognized normal three-banner pattern (`STANDARD_3_BANNERS`), each unique `log.qslog` existed and decoded, but the decoded content was also exactly three INFO startup banners, with no subsequent error, Wull marker or QML diagnostic. These are ACTUAL local results; the earlier CLASSIFIER PASS alone does not certify the Qt startups, which had `NONZERO` and `MARKER=NONE` under all three minimal/frozen environments. This closes the unproductive historical-log-recovery path: there is no hidden diagnostic beyond the startup banners in these previously retained QSLOGs.
- User-visible source-only reasoning: because even minimal `import QtQuick; import Quickshell; ShellRoot` did not run a marker, an animation-level regression is not the demonstrated issue. Three cases sharing the same early failure do NOT prove which subsystem failed. Prior frozen 24/24 actual Qt success remains historical and must not be equated with present runtime success.
- Staged a NEW explicit private NON-PUBLISHING synthetic minimal startup probe `scripts/wull-private-minimal-qs-bootstrap.py` exact blob `edd28683dc1ce679f24aa460e914cfad5abdc0a6` (commit `f8de8cfd85e3226691a0758798a2611b60cf0689`): strictly protected NEW clean dev scratch, same original frozen source audits, Quickshell `0.3.1` / local CLI help guard, only minimal ShellRoot (no Wull import or Wayland windows), three controlled variants: (`OFFSCREEN_FILE`, `offscreen`, QML file `--path`); (`OFFSCREEN_DIRECTORY`, `offscreen`, enclosing directory `--path`); (`MINIMAL_FILE`, Qt `minimal`, file `--path`). All three run in separate owned private DBus sessions and XDG directories, suppress compositor/desktop socket environment, capture only bounded private stdout/stderr with verbose Quickshell and QT_DEBUG_PLUGINS; a dedicated private Python child classifies the ACTUAL `qs` exit independently of the outer `dbus-run-session` wrapper; stage marker is emitted at QML `Component.onCompleted`, not after a long timer. Public terminal output is only static enum exit/marker/plugin/QML category labels with no private log lines, environment, host coordinates or paths. Owned process-group cleanup is fail-closed. No source or production edit occurs during probe; no GitHub report is published.
- Companion inert synthetic test `scripts/test-wull-private-minimal-qs-bootstrap.py` exact blob `17122bf3bb22a20b821801ce77276df73a04b4bd` (commit `076bbbe194591141dc756be9fd11f4efe34cd02d`) pins source and validates no-Wull minimal QML, finite synthetic categories, duplicate/absent marker rejection, actual child exit classification and private launch guard tokens. Both sources are STAGED only, not yet executed/Qt-qualified in maintainer's environment. Distinguishing file path vs directory and Qt platform may reveal configuration resolution or plugin initialization; if all fail before immediate Component.onCompleted even with local Quickshell child categorization, treat as COMMON EARLY QS/Qt environment blocker and investigate exact sanitized plugin categories before a full dynamic test. Do NOT infer a root cause or weaken normal production security.
- NEXT: ONE single private clean `dev` clone, assert both exact source blobs, run inert contract first, then explicitly acknowledged minimal standalone source. Publish only its fixed `OFFSCREEN_*`/`MINIMAL_FILE_*` and `GATE` lines. No dynamic receipts, no real compositor or pointer gating yet. Production original full host mask, default-off Wull, Rust backend and `stable` remain unchanged.


## Checkpoint — 2026-10-02 all synthetic minimal Qt probes were signal-terminated; classify retained plugin logs without rerun

- Owner ran a source-pinned `scripts/test-wull-private-minimal-qs-bootstrap.py` at `SOURCE_SHA=284001594ca472ec6a098956754ad13bfa977e7a`: `WULL_MINIMAL_QS_BOOTSTRAP_INERT_PASS`. Three ACTUAL standalone PRIVATE synthetic tests `OFFSCREEN_FILE`, `OFFSCREEN_DIRECTORY`, `MINIMAL_FILE` all reported `WRAPPER=NONZERO`, `QML_MARKER=NONE`, `QS_CHILD_EXIT=SIGNAL`, `ERROR_CLASSES=QT_PLATFORM_OR_PLUGIN,ABORT_OR_SIGNAL`, terminal `GATE=PRIVATE_MINIMAL_QS_BOOTSTRAP_CLASSIFIED`. Private evidence remains at the owner's reported `wull-qt-state.*/hadalis/wull-qt-motion.*/minimal-qs-bootstrap/{offscreen_file,offscreen_directory,minimal_file}/minimal.private.log`, not publicly uploaded. Do not infer a particular signal number, dynamic Wull QML defect, plugin failure, or frame qualification from these coarse categories.
- SOURCE-RULE LIMITATION IDENTIFIED: Old `categorized_log()` considers the mere presence of the strings `qt.qpa` / `platform plugin` and `signal` / `fatal` to establish broad error category presence. `QT_DEBUG_PLUGINS=1` intentionally causes normal plugin-discovery diagnostic lines too (Qt official docs: `https://doc.qt.io/qt-6/debug.html`), so current broad error classes cannot themselves prove a broken Qt platform plugin. In the three tests, actual `qs` subprocess did return a negative signal-coded Python return code, which is distinct direct evidence of signal termination, but exact signal cause still unverified; old child stdout intentionally only printed `SIGNAL`.
- Staged a **NEW read-only POSTMORTEM** `scripts/wull-private-minimal-boot-log-review.py` (Git blob `0557565ca81685aa7e1bf2a2fd820e0a58d9742c`) plus source-pinned synthetic benign-vs-fatal/privacy test `scripts/test-wull-private-minimal-boot-log-review.py` (Git blob `6387deab8b9560a4a0a1fc89b9fa5a21b4df5655`). Both source-only, **NOT YET EXECUTED LOCAL**. Reader verifies the exact original source SHA and original previous runner blob, owner-owned private mode0700 scratch, safe known origin, bounded non-symlink files. It never starts Qt/Quickshell, reads only the three existing old minimal debug logs and reports static fields for actual byte count, newline/near512KiB-limit, fixed explicit fatal QPA/linker/QML/resource error patterns vs benign plugin discovery/loading, last six lines fixed classes, whether QML marker actually appears, whether the old child exit marker occurs uniquely and whether any explicit signal mnemonic appears in the raw private log. Does not print source lines, private paths, plugin identifiers, environment or arbitrary values. Raw logs remain owner-local; no docs receipt published.
- NEXT ONE OWNER ACTION: from a NEW ephemeral read-only `dev` clone, require the exact two updated source blobs, run the inert source/test first and require `WULL_MINIMAL_BOOT_LOG_REVIEW_INERT_PASS`. Only then read-only inspect previous retained scratch `/tmp/wull-qt-state.rw21NC/hadalis/wull-qt-motion.i0Yk7d` against original SHA `284001594ca472ec6a098956754ad13bfa977e7a`. The parsed actual plugin QPA/linking errors or near-limit status, rather than broad debug token matches, must drive the next repair. If still no explicit error in logs, do not speculate that the SIG originated in the plugin; consider a separate minimal signal-number-only traced probe after comparing previously retained control child/wrapper behavior. All Qt Wull dynamic QML, real pointer and production Region gates still OPEN, original full-host mask and Wull default-off unchanged, no `stable` edit.


## Checkpoint — 2026-10-02 complete retained minimal Qt debug logs still lack explicit failures; exact signal gate staged

- Actual maintainer local synthetic inert contract `WULL_MINIMAL_BOOT_LOG_REVIEW_INERT_PASS`. The exact three OLD retained private minimal Qt probe logs from source `284001594ca472ec6a098956754ad13bfa977e7a` were read-only classified: `OFFSCREEN_FILE` 13,221 bytes/350 lines, `OFFSCREEN_DIRECTORY` 13,226 bytes/350 lines, `MINIMAL_FILE` 10,280 bytes/277 lines. ALL three were not near their file-size limit, ended with newline, had NO QML component-completed marker, had `CHILD_EXIT=SIGNAL`, had no explicit signal mnemonic in their text and `FAILURES=NO_EXPLICIT_FAILURE_PATTERN`. Their permitted Qt events consist of `QT_PLUGIN_DISCOVERY`, standard Quickshell banners and the child-exit marker; neither successful plugin load nor explicit loader failure was identified by this classifier. Fixed last six category signatures were equal: UNCLASSIFIED, UNCLASSIFIED, QT_PLUGIN_DISCOVERY, QT_PLUGIN_DISCOVERY, UNCLASSIFIED, CHILD_EXIT_MARKER. GATE `READ_ONLY_EXISTING_MINIMAL_LOGS_CLASSIFIED`. Neither the old coarse `QT_PLATFORM_OR_PLUGIN` class nor the mere plugin-discovery lines prove plugin failure, and no stored diagnostic includes a genuine numeric signal code.
- In the previously reviewed minimal probe `scripts/wull-private-minimal-qs-bootstrap.py` the code `child_exit_status(code)` deliberately collapses ANY negative `subprocess.run` return code into the same `SIGNAL` label. The old full file was read-only parsed, so exact -SIGNUM is unrecoverable from that private log; guessing SIGABRT/SIGSEGV would be unsupported. Historical actual frozen geometry PASS proves ONLY an earlier runtime succeeded, not this present offscreen runtime.
- Staged **NEW narrow explicit-opt-in PRIVATE minimal-ShellRoot signal probe** `scripts/wull-private-qs-signal-gate.py` Git blob `2380e7c2a46569e8c21ca3f0c4cea0ac9441f61f` (commit `c00e91109b022bd4d778bb305e89916bc720ab41`) with inert synthetic source-pin/negative privacy test `scripts/test-wull-private-qs-signal-gate.py` blob `0e9e053a74638197163594fd8149230b746f0a2c` (commit `c75f9db27290b1b27cd0eb7fa0b05541b8c2414e`). Both new files are SOURCE-STAGED, not yet run local. Borrow original frozen private-clone guards, frozen production QML source audit, exact older minimal fixture QML from `edd28683dc1ce679f24aa460e914cfad5abdc0a6`, exact local Quickshell 0.3.1 check, isolated offscreen `dbus-run-session` / no compositor environment, `--verbose` + `QT_DEBUG_PLUGINS=1` to replay ONE former failing `OFFSCREEN_FILE` test. Critically, the dedicated child writes ONLY `STATE=<enum>\nQS_SIGNAL=<fixed SIG name or NONE>\n` into a new mode0700 local-only sidecar in addition to separately bounded private debug stdout, so signal classification does not depend on truncated console output or the `dbus-run-session` wrapper's code. `RLIMIT_CORE=0` prevents sensitive crash dumps. Default `RLIMIT_FSIZE=524288` matches the earlier run. Only if actual QS child explicitly returned `SIGXFSZ`, automatically run ONE identical additional bounded 8MiB-fsize comparison with a fresh private DBus/XDG space; Linux documents SIGXFSZ as the result of exceeding RLIMIT_FSIZE (`https://man7.org/linux/man-pages/man2/getrlimit.2.html`). Other signal classes do NOT trigger extra Qt runs; do NOT infer the underlying root cause from the signal alone.
- NEXT SINGLE MAINTAINER LOCAL COMMAND: NEW mode0700 owned clean `dev` clone; exact-blob guard both staged script and test; run inert and assert `WULL_PRIVATE_QS_SIGNAL_INERT_PASS`; then private explicit opt-in `python3 scripts/wull-private-qs-signal-gate.py --acknowledge-private-qs-signal`. Return fixed `BASELINE_QS_STATE`, `BASELINE_QS_SIGNAL`, conditional control and `GATE` only. Keep user raw Qt logs, sidecar, QML path and state directory local. No dynamic Wull geometry report or compositor pointer acceptance is proved by this standalone diagnostic; original production full-host Region, Wull default-off, Rust backend and `stable` remain unchanged.


## Checkpoint — 2026-10-02 exact QS signal inert blocked by stale string assertion; corrected

- Owner attempted the source-pinned private exact signal gate from previous `dev` state; the NEW inert test failed at line 69 on the source-spelling assertion `assert '"QS_SIGNAL=" + sig' in source`. The actual reviewed signal runner writes the correct sidecar format using `"STATE=" + state + "\\nQS_SIGNAL=" + sig + "\\n"`; the old grep omitted the preceding escaped newline. `set -e` stopped before the `EXACT SIGNAL DIAGNOSIS` private Quickshell launch. Therefore this attempt produced **NO Qt signal evidence**. The maintainer's previous minimal three control results (all child `SIGNAL`) and previous fully classified logs remain the last actual runtime evidence.
- Corrected ONLY `scripts/test-wull-private-qs-signal-gate.py` (Git blob `5917d780c9933cd28484a4651bf342b1abeed003`, commits `772237875a6211519b8c44dd0f6dce4bc55cf194` and `0af7d81219f2646bb46bd7f6d4ccfa3eb9207a9c`) by replacing the brittle source-text assertion with mocked `subprocess.run` behavioral tests. Four cases exercise the real child function: `SIGXFSZ`, `SIGABRT`, exit 0 and ordinary nonzero, each checking actual sidecar format through `receipt_read`, child exit status and exact `--verbose --path` invocation without starting Quickshell. Source pin continues to require unchanged original actual signal runner blob `2380e7c2a46569e8c21ca3f0c4cea0ac9441f61f`; other existing negative, security, conditional-only SIGXFSZ checks retained. Source/branch static consistency was rechecked, but FULL new repo inert contract has **NOT** been rerun in the owner's local clone yet; do not mark it PASS from source review.
- NEXT ONE USER ACTION: new permission-private clean `dev` clone (concurrent MegaQML commits allowed, provided two exact file blobs unchanged); require signal runner `2380e7c2a46569e8c21ca3f0c4cea0ac9441f61f` and corrected inert test `5917d780c9933cd28484a4651bf342b1abeed003`, run `scripts/test-wull-private-qs-signal-gate.py` first, then only on `WULL_PRIVATE_QS_SIGNAL_INERT_PASS` run `scripts/wull-private-qs-signal-gate.py --acknowledge-private-qs-signal`. It prints fixed `BASELINE_QS_STATE`, `BASELINE_QS_SIGNAL`, conditional-only `RAISED_LIMIT_*` if real `SIGXFSZ`, and `GATE`. Keep all raw logs/core/environment/private paths local. No source change to the production animation, Rust backend, Wull default-off, full-host input mask or `stable`.


## Checkpoint — 2026-10-02 owner-local 512 KiB SIGXFSZ proven; 8 MiB minimal Qt PASS; dynamic runner resource separation staged

- Owner actually ran exact-signal minimal startup probe from `SOURCE_SHA=294c29f8feafaf7960d1f654abb3236f324937d2`, first obtaining `WULL_PRIVATE_QS_SIGNAL_INERT_PASS`. In isolated private minimal Quickshell offscreen with the SAME source-pinned original minimal ShellRoot QML, `RLIMIT_FSIZE=512 KiB` produced `BASELINE_QS_STATE=SIGNAL`, `BASELINE_QS_SIGNAL=SIGXFSZ`, `BASELINE_QML_MARKER=NONE_OR_UNVERIFIED`, `BASELINE_LOG_AT_LIMIT=NO`. The exact conditional control with independently isolated XDG/dbus and `RLIMIT_FSIZE=8 MiB` produced `RAISED_LIMIT_QS_STATE=ZERO`, `RAISED_LIMIT_QS_SIGNAL=NONE`, `RAISED_LIMIT_QML_MARKER=ONE`, `RAISED_LIMIT_LOG_AT_LIMIT=NO`, `GATE=PRIVATE_EXACT_QS_SIGNAL_OBSERVED`. This is direct evidence the inherited 512 KiB **process-wide file-size limit** prevented that minimal Quickshell fixture from initializing; it does NOT prove the specific underlying file that exceeded the limit (stdout log was not at the limit; QS internal/other private files may have been involved) and does NOT yet qualify full Wull dynamic behavior or actual geometry.
- Previous dynamic runner `scripts/wull-manual-offscreen-dynamic-geometry.py` used `resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_LOG, MAX_LOG))` in the `dbus-run-session` child's preexec_fn with `MAX_LOG=524288`. The cap is INHERITED by all Quickshell descendant writes, not an isolated stdout quota, providing a source-grounded explanation consistent with earlier pre-BOOT nonzero child and banner-only logs; the new exact proof was conducted only on the synthetic minimal control. Keep all former failed dynamic results `INCONCLUSIVE`; avoid overclaiming a successful full dynamic gate.
- Corrected ONLY the PRIVATE dynamic offscreen probe runner on `dev` (blob `fe1c828e7c2f0e4fdc4bb7340242062085db3118`, commits `11ec60846184a646c064af725e461984eb5aeec9` and `18fa09cc67849af118ebd143cbc090ca46eab76b`). Separate `MAX_LOG=524288` (postrun stdout/stderr evidence cap) from `QS_CHILD_FILE_LIMIT=8*1024*1024` (inherited private QS regular-file cap, empirical minimal PASS). The private preexec function `limit_private_process_files()` now sets `RLIMIT_CORE=(0,0)` (prevent crash core dumps) and `RLIMIT_FSIZE=(8MiB,8MiB)`; original postrun check still rejects a stdout log over 512 KiB and original stage/source/private-cleanup/receipt guards remain unchanged. The original production Rust backend, dynamic QML fixture, default-off Wull, full-host input Region and `stable` are untouched. These numbers do NOT guarantee all future QML log or dynamic animation loads under 8MiB; fail closed and inspect safe stages after one local run.
- Updated companion inert test `scripts/test-wull-offscreen-dynamic-geometry-contract.py` (blob `ad1f97cec8c30ecbdd447ec3bc8ddd0070a17b7b`, commit `60d7f58a98034740f6514620969cfda4ad1f1ca8`) pins the exact updated runner, proves separate 512KiB/8MiB constants, mocks `resource.setrlimit` to assert BOTH core=0 and exact new fsize bounds without changing host process limits, and still explicitly requires a postrun `0 < log.stat().st_size <= MAX_LOG` check plus all original synthetic geometry, stage order and private redaction constraints. THIS CORRECTED TEST HAS NOT YET RUN on the owner's machine; source-only GitHub checks are not local PASS.
- **NEXT**: ONE freshly permission-private owner-owned mode0700 clean `dev` clone, exact Git blob guards for both updated files `fe1c828e7c2f0e4fdc4bb7340242062085db3118` and `ad1f97cec8c30ecbdd447ec3bc8ddd0070a17b7b` plus original QML fixture source pin `6e3b5402d32d263868c1ec688925adba0fd7250b`. Run inert first and require `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS` at printed `SOURCE_SHA`; only then with explicit owner opt-in run `scripts/wull-manual-offscreen-dynamic-geometry.py --acknowledge-private-offscreen-dynamic-motion`. Print ONLY allowlisted `PRIVATE_QS_EXIT_CLASS`, `PRIVATE_QML_STAGES`, `PRIVATE_QML_LAST_STAGE`, `PRIVATE_QML_FAILURE_CATEGORY`, `STOP`, `WULL_QT_DYNAMIC_RESULT`, `REPORT_PUBLISHED`; keep private Qt logs and coordinates local. Report status PASS only on real all-12 witness acceptance and published sanitized receipt, not on inert/source proof. A full source/desktop/Niri/pointer/production-mask acceptance is STILL a separate gate.


## Checkpoint — 2026-10-02 first full dynamic Qt stages complete, private parser still INCONCLUSIVE; read-only postmortem staged

- Owner ran corrected 8MiB-fsize `dev` runner at `SOURCE_SHA=4caccd2058f1b3089ec398a131241f800eaae890`; `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS`. ACTUAL private offscreen dynamic Qt process reported `PRIVATE_QS_EXIT_CLASS=ZERO`, all `PRIVATE_QML_STAGES=8`, `PRIVATE_QML_LAST_STAGE=SAMPLING_DONE`, then `STOP: private_dynamic_qml_parser_inconclusive`, runner exit 1 and `GATE=UNVERIFIED`. The owner preserved original private log and clean private repo in its original 0700 scratch. This directly proves the source-authored BOOT/SETUP/FROZEN/NEUTRAL/STRETCH/RELEASE/DONE Qt stage sequence was observed for the QML fixture. It does **NOT** prove that all 12 hosts supplied valid frozen flags, that parsed JSON is complete, that individual motion witness booleans are TRUE, that 12-case dynamic model validation passed, or that the end-to-end dynamic gate has been accepted. No dynamic receipt was published.
- Source-level review of original runner at blob `fe1c828e7c2f0e4fdc4bb7340242062085db3118`: `private_dynamic_qml_parser_inconclusive` merges **three distinct** failure categories inside ONE try block: `json.loads(single geometry marker)` JSON decode, `known_frozen()` frozen-reference I/O/content validity, `model_summary(rows, baseline)` 12-host structural/type/witness-reference validation. A normal `INCONCLUSIVE` motion witness returned by `model_summary()` would NOT raise here, so treating this as a motion-frame failure without examining the private retained marker is premature. Original fixture remains unchanged and all stage markers complete.
- Created independent, NON-PUBLISHING, READ-ONLY private postmortem `scripts/wull-private-dynamic-parser-postmortem.py` exact Git blob `73904dbda1de437a8586925d32fa774af6b04d5e` (commit `d5f31df3872ffe6fbb31e7a87e8fd2103f86de50`) with inert synthetic privacy/shape/JSON/exception tests `scripts/test-wull-private-dynamic-parser-postmortem.py` blob `aa6fff8e52471fd876c7c4249deb6bd810e71aa8` (commit `896049d03b8090ae168bdc86c300ef1e5318c5fc`). These two NEW sources are staged on `dev` but NOT YET RUN locally. The postmortem requires the exact original retained clean clone source `4caccd2058f1b3089ec398a131241f800eaae890`, old dynamic runner blob `fe1c828e7c2f0e4fdc4bb7340242062085db3118`, original dynamic QML fixture blob `6e3b5402d32d263868c1ec688925adba0fd7250b`, owner/mode0700 scratch and safe original remote; it imports the OLD runner inertly and reads ONLY the old already-retained 512KiB-bounded `dynamic.private.log`. Output contains only fixed stage/marker counts, payload character count/bracket classifications, fixed JSON host/phase key shape enums and strictly allowlisted parser/frozen reference/structural validation ValueError names, never raw JSON, coordinates, QML error text, private filenames, desktop data or original log lines. It does not run Quickshell, touch repo/desktop, publish docs or change source pins. Its classification is DIAGNOSIS, NOT a fabricated dynamics receipt.
- NEXT SINGLE LOCAL ACTION: fresh ephemeral read-only `dev` clone; verify BOTH postmortem and inert exact Git blobs; run `scripts/test-wull-private-dynamic-parser-postmortem.py` and require `WULL_PRIVATE_DYNAMIC_PARSER_POSTMORTEM_INERT_PASS` before executing read-only `scripts/wull-private-dynamic-parser-postmortem.py --scratch /tmp/wull-qt-state.TwSIa1/hadalis/wull-qt-motion.y2aZdO`. Return only categorical result and `GATE`. Then use direct evidence to fix the narrow cause: JSON decode/shape errors require payload framing or original fixture review; frozen-reference error requires reference audit; model parser error requires specific allowlisted model field correction. Do NOT rerun a full private Qt dynamic sweep before isolating existing failure, nor modify original production Wull mask, Rust backend, default-off Wull or `stable`.

## Checkpoint — 2026-10-02 retained dynamic parser scale-key mismatch

- Owner postmortem at old source `4caccd2058f1b3089ec398a131241f800eaae890`: 8 expected stages, one geometry marker, valid 12-case JSON and valid frozen reference, then `MODEL_CATEGORY=missing_scale_frozen_reference`. No motion PASS inferred.
- Source analysis: JavaScript JSON serializes scale 1.0 as integer 1; Python accepts numeric equality but original `str(scale)` looks up `"1"` where pinned frozen reference uses `"1.0"`. This is the specific first-failure mechanism.
- Staged narrow private-runner scale normalization: runner blob `9cab00fca46212c819ac7308cfc0d6923d1139d3` commit `9c2a280d5cf2902f17b39e911f5ff5b05faaaee2`; inert contract regression blob `023cdaccd9d0f8234b9dea0b4fb1bdc43c1c3754` commit `86b6c29cc64e1aa5070e0aaef8f8127e9f27cdba`. No local test on these updated blobs yet. Fixture, backend, production mask, Wull default-off and `stable` untouched.
- NEXT: in a new clean mode0700 `dev` clone, verify exact runner and inert blobs; run updated inert and only if PASS read-only reclassify the retained old private log with the new parser and existing pinned `owner_guard`. Print only allowlisted categories, no Qt rerun and no raw log export. This is old-sample reclassification, not broad animation acceptance.

## Checkpoint — 2026-10-02 owner reclassified OLD actual Qt log PASS with corrected parser; bounded receipt publication staged

- Owner executed source- and blob-pinned clean `dev` private recheck at `DEV_HEAD=caeffb6ea25fb033d49544910b4917d87bc144c0`: `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS`, `WULL_PRIVATE_DYNAMIC_PARSER_POSTMORTEM_INERT_PASS`. Read-only existing original private Qt log from `SOURCE_SHA=4caccd2058f1b3089ec398a131241f800eaae890` showed `STAGES=8`, correct ordered stages, exactly one geometry marker, valid 9858-character JSON, correct TWELVE_HOSTS/host and phase fields, valid frozen reference, `PARSER_STAGE=MODEL_VALIDATED`, `MODEL_STATUS=pass`, `GATE=READ_ONLY_CORRECTED_PARSER_CLASSIFIED`. This proves corrected parser acceptance of the retained real Qt sampled motion data, NOT re-execution of Qt, full motion extrema, compositor input Region acceptance or shell production qualification.
- Source fix runner blob `9cab00fca46212c819ac7308cfc0d6923d1139d3`, inert regression blob `023cdaccd9d0f8234b9dea0b4fb1bdc43c1c3754`, retained original fixture blob `6e3b5402d32d263868c1ec688925adba0fd7250b`, pinned original frozen receipt blob `dc2f36b525ef7e412869f155153dc4e48720f898` remain unchanged. No full `docs/wull-qt-dynamic-*.json` automatic runner receipt was published for the original execution.
- STAGED NEW separate opt-in PRIVATE retrospective receipt publisher `scripts/wull-publish-retained-dynamic-receipt.py` Git blob `9b6fb909125da110266fb303bdcced6b9fdea7ed`, commit `4a56b629809df4860f6ab1eeec4ea3c6fa2762bf`, and inert synthetic privacy/negative-contract `scripts/test-wull-retained-dynamic-receipt-contract.py` Git blob `06bbc5fb457b1aea99b1ef6f277ead7c332437a1`, commit `a23c67805bb25bfb36da825a71d6a84b3535f916`. Not owner-local tested yet. Script checks clean private `dev` clone and exact Wull blobs, reuses original old-log `owner_guard`, checks all expected stages/exactly one geometry marker/no failure markers, runs fixed `model_summary`, then publishes ONLY the bounded existing `public_report` categorical projection augmented with EXPLICIT retrospective/non-rerun provenance to deterministic `docs/wull-qt-dynamic-retained-4caccd2058f1-scale-parser.json`. It uses a one-shot NONFORCE push, no rebase/retry, fail-closed on concurrent dev changes. Never launches Qt or touches original old scratch.
- NEXT ONE OWNER ACTION: in a new mode0700 private clean `dev` clone, check exact publisher/test/runner blobs plus pinned fixture/reference, run updated `scripts/test-wull-offscreen-dynamic-geometry-contract.py` and NEW retained receipt inert test first. Only if both PASS, run `python3 scripts/wull-publish-retained-dynamic-receipt.py --acknowledge-retained-publication`. Print only fixed `SOURCE_SHA`, `MODEL_STATUS`, `OBSERVED_HOST_CASES`, `NEW_QT_RUN`, `PUBLICATION_COMMIT`, `REPORT_PUBLISHED`, `GATE`; if remote moves or old evidence is unavailable, abort without claiming publication. Re-read GitHub only after result to verify published report and advance to independent live pointer/spring/resource acceptance. Do NOT change original production full-host mask, default-off Wull, Rust or `stable`.

## Checkpoint — 2026-10-02 retrospective dynamic Qt receipt published; painted host boundary next

- Owner launched the staged one-command publication in a clean private `dev` clone and reported both `WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS` and `WULL_RETAINED_DYNAMIC_RECEIPT_INERT_PASS`. Its next reported `DEV_HEAD=556e7643bca1f672feef6ed5d879ffff73f861c4` and `GATE=RECEIPT_ALREADY_EXISTS` were NOT a new parser/model failure: exact subsequent GitHub verification proved the previous run had ALREADY pushed the intended SINGLE receipt in the direct child commit `556e7643bca1f672feef6ed5d879ffff73f861c4`, with exactly one added file, `docs/wull-qt-dynamic-retained-4caccd2058f1-scale-parser.json` Git blob `54a153d717b10056d156e4724d80cb759cf5941d`. Do not rerun publisher or create a second receipt; stop-on-existing was correct idempotent refusal.
- AUTHENTIC PUBLISHED RETROSPECTIVE REPORT: old actual Qt source `4caccd2058f1b3089ec398a131241f800eaae890`, corrected parser blob `9cab00fca46212c819ac7308cfc0d6923d1139d3`, `status=pass`, `all_12_edge_scale_state_witnesses=true`, 80 actual old saved-frame samples per case/phase and no unqualified edge-scale entries. Qt was NOT rerun; original QS exit ZERO is owner-reported rather than reconstructed from the retained log. The old published frozen 24-pose reference remains unchanged.
- NEW EVIDENCE for next design: for each of three scales (0.65/1.0/1.5), the OR-ed sampled body-item BBOX is outside host for TOP/BOTTOM and exceeds corresponding frozen BBOX for ALL FOUR edge placements during BOTH stretch and release. Mapped nominal path-tip is beyond TOP host in STRETCH only. This is NOT proof that painted Bézier body pixels or their interactive target cross the host: full per-frame coordinates/alpha/clipping and compositor pointer delivery were not measured. Static four-edge size=1 BBOX click PASS is not a viable standalone dynamic mask guarantee. Keep `global_spring_extrema_proven=false`, `native_backend_traces=not_run`, `wayland_pointer_hover=not_run`, `canonical_validation=not_run`.
- Updated the existing technical research in `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md` in commit `25316ce6c8215400578d1331206f7b6340ae0778`. NEXT SOURCE TASK: design and source-stage an independent, source-pinned PRIVATE offscreen painted-core-vs-host boundary probe (expanded capture canvas, sampled actual QML, separate core/stroke vs halo/ripple, strict no-coordinates sanitizer and negative tests). If core/decor separation requires a shadow-only altered renderer, label and validate that shadow scope separately; never call it identical production renderer. This source task itself does not authorize running Qt, starting Niri, publishing raw screenshots, widening or shrinking the production mask, enabling Wull, or touching `stable`. Only after source/inert review should ONE bounded owner-local test command be issued. A separate nested pointer+underlay proof and backend replay remain future independent gates.

## Checkpoint — 2026-10-02 fake-only painted-alpha model staged ahead of Qt capture

- New first-stage implementation of the NEXT painted-core/host research: `scripts/wull-private-painted-alpha-model.py` blob `fa9e7c2af87ee830336988fa7060e2720e816ed0` (initial commit `6f66406a3913f1ee6c26f587d89568707553bd1b`, PNG signature correction `8d7207ec27b392b56069124f4bf3cfc51031527e`). Pure-inert bounded PNG RGBA8 decoder with all five filter types, anti-fabrication phase/mapped-motion/host-rectangle checks, transparent canvas edge/truncation rejection and categorical 48-slot 4-edge × 3-scale × 2-phase × 2-source aggregation, NO Qt, filesystem access, stdout pixels or source/production edits. It STRICTLY distinguishes an unchanged FULL-companion composite from a separate shadow-only body assembly; it cannot infer that composited exterior alpha belongs to Wull's clickable core.
- Added synthetic-only `scripts/test-wull-private-painted-alpha-model.py` blob `f673e062669d5b03f7af5bd74c20c5126b37e9be` (first commit `62298a20f7b0c578adc6ddc6a8a8d63073842e82`, oversized-fixture correction `23ce6d0836ac0c6514522ca37f1bd4951d6edd17`). Negative test includes transparent pixels, anti-alias threshold/edge crop, invalid PNG/chunk/filter and data shape, strict no private fields and duplicate case coverage. Source-staged NOT OWNER-LOCAL TESTED YET; do NOT claim alpha observations exist, Qt capture works or full 48-slot dynamic motion passes.
- Detailed gate in `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md` (commit `1e4274beb27b96cd46654a454e96afcb80dc6061`). NEXT EXACT OWNER ACTION: new mode0700 clean read-only `dev` clone with exact two blob guards; run only `python3 -B scripts/test-wull-private-painted-alpha-model.py`, require `WULL_PRIVATE_PAINTED_ALPHA_INERT_PASS`. No Qt or old log re-run. After that, source-stage one-case bounded offscreen original-companion transparent `grabToImage` canary in a new private runner and fake contract to verify Qt capture/format without presupposing full 48-case frame budget. Only afterward develop full paired 48-case capture. Other pointer, native backend, popup, multitarget/fractional/long-term and canonical gates remain open. No production mask or default-off change; do not edit `stable`.

## Checkpoint — 2026-10-02 painted-alpha inert PASS, isolated one-case Qt paint canary source staged

- OWNER LOCAL RESULT at `DEV_HEAD=19408521c6927de57ba74163a3001fc67e6f2dc1`: `WULL_PRIVATE_PAINTED_ALPHA_INERT_PASS`, `QT_EXECUTED=NO`, `PRODUCTION_CHANGED=NO`, `GATE=PAINTED_ALPHA_INERT_VERIFIED`. This qualifies only the fake-only PNG decoder, privacy/shape regressions. No actual Qt image or paint-pixel evidence existed at that checkpoint.
- NEW SOURCE-STAGED one-case PRIVATE Qt `grabToImage` feasibility: original unchanged `AbyssCompanion`/`WaterDropletBody` at TOP scale 1 and privately fixed stretch pose inside a hidden-then-shown transparent 320×300 offscreen `FloatingWindow` with extra room around the 112×98 host. Fixture `scripts/wull-fixtures/paint-alpha-canary/shell.qml` exact blob `4ed1c92b81870197927b449cfe60cd2c57859b30`. This is a static capture/format feasibility test, NOT an actual dynamic frame, core-specific rendered-pixel measurement, real Wayland clipping, input Region or host screenshot.
- Guarded script `scripts/wull-manual-private-paint-canary.py` blob `5ce5155303913b9eda49590ba017c074b8e176fc`: owner-owned clean mode0700 `dev` scratch, exact stable Wull fixture/production/config/parser pins, private D-Bus/XDG/Qt offscreen, stripped host Wayland/Niri/display/session bus, v0.3.1 Quickshell check, bounded Qt process group/capture time/file sizes and private-only PNG/log. Only `OUTSIDE_HOST_COMPOSITE_ALPHA` categorical result can escape; even YES cannot distinguish paint of body from halo/ripple. No Git publishing, no source mutation.
- New separate fake-only `scripts/test-wull-private-paint-canary-contract.py` blob `2c4a98c61c42e21634d568e68d10d8ac452f21f1`: exact source-pin/static env/cleanup constraints; synthetic private PNG interior, exterior, blank, edge-cropped and malformed validations. Neither this NEW test nor actual canary has yet run owner-local. Design instructions appended to existing `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md` in commit `67d56026b171a5759fcb7ae85dee3b8499f62efa`.
- NEXT EXACT OWNER ACTION: issue ONE ephemeral clean `dev` clone command with explicit new fixture/runner/contract and old model/production blob verification; run previous `test-wull-private-painted-alpha-model.py` and new `test-wull-private-paint-canary-contract.py` fake-only first, requiring BOTH expected PASS markers. ONLY on these two PASS and explicit owner-local command consent run ONE `scripts/wull-manual-private-paint-canary.py --acknowledge-private-one-case-capture`. Fail closed on unsupported Qt image type, insufficient original painted pixels, file limits, capture timeout, unexpected status, source drift or missing owned cleanup. Do not expand to full 48-case sampling without separately reviewing the observed one-case feasibility evidence. Never modify original full-host production mask, default-off Wull, original Rust backend or `stable`.

## Checkpoint — 2026-10-02 private actual full-companion painted-alpha canary PASS; body-only shadow staged

- Owner successfully executed the source-pinned FIRST actual Qt composite canary at `SOURCE_SHA=63eb572bdf324f1fd437df6f87617a2b9a81cbaa`, reporting `WULL_PRIVATE_PAINTED_ALPHA_INERT_PASS`, `WULL_PRIVATE_PAINT_CANARY_INERT_PASS`, `ACTUAL_UNMODIFIED_COMPANION=YES`, `STATIC_TOP_SCALE1_PNG=VALID`, `OUTSIDE_HOST_COMPOSITE_ALPHA=YES`, `BODY_SPECIFIC_PAINT_OUTSIDE_HOST=UNPROVEN`, `DYNAMIC_WITNESS=NOT_RUN`, `PRODUCTION_MASK_CHANGED=NO`, `GATE=PRIVATE_OFFSCREEN_ONE_CASE_CAPTURE_VERIFIED`. This is one exact-source real OFFSCREEN Qt composite painted-alpha existence observation outside TOP host at scale1 in the frozen private test pose; not core/stroke attribution, compositor clipping or live interaction.
- NEXT ISOLATION staged on `dev`: `scripts/wull-fixtures/paint-alpha-shadow/shell.qml` exact blob `feea498f8b75c24cdd93fe116bac0dd6b36b1d01` directly instantiates the UNMODIFIED `WaterDropletBody` at source-matched TOP/scale1/frozen stretch transform in a 112×98 shadow host inside its own 320×300 transparent offscreen capture stage, omitting original `AbyssCompanion` external cradle. It is an explicitly ALTERNATE shadow assembly, not production; the body's own face/highlights remain, internal halo pulse set zero.
- `scripts/wull-manual-private-paint-shadow.py` exact blob `08670b15307115adf8432614bdb13b36071effe0` source-pins Wull production files, old successful full-composite canary and fixture, new shadow fixture and alpha parser. It preserves the 0700 clean `dev` clone, privately isolated Qt offscreen/XDG/D-Bus, source review, bounded 13s subprocess/8MiB child files/256KiB private log and strict group cleanup. Publishes NO PNG or Git file; prints fixed categorical result. `scripts/test-wull-private-paint-shadow-contract.py` blob `c52562657920f7c0a2bfd88f5dbe8974aa590261` is NEW fake-only inert source/PNG/isolation test; both new artifacts have NOT YET run owner-local. Detailed implications and next gate appended in existing `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`, commit `cf5f2a54eaba207175baf9c74e09e44a7877f3fc`.
- NEXT ONE OWNER ACTION: fresh, strictly private mode0700 clean `dev` clone, check shadow fixture/runner/inert exact blobs AND original canary and alpha model pins. Run existing fake-only painted alpha test and new shadow fake-only test first; only after both PASS run ONE `scripts/wull-manual-private-paint-shadow.py --acknowledge-private-one-case-shadow`. Return strictly categorical `SHADOW_OUTSIDE_HOST_ALPHA` and `GATE`, keep raw log/capture local and auto-cleaned. If failure, classify from fixed GATE before any repeat. The old composite capture must NOT be rerun for this independent shadow feasibility. A shadow YES does NOT yet prove production core paint or actual Wayland hit-region reach; a shadow NO does NOT prove the earlier composite pixel was cradle without synchronized capture. Keep original full-host input Region, default-off Wull and `stable` unchanged.

## Checkpoint — 2026-10-02 body-shadow outside-host alpha PASS; original ShapePath-only Qt canary staged

- OWNER ran exact-source one-case body-only SHADOW canary at `SOURCE_SHA=81daf8f7e64d1a7521d18f831d4db30044a10c74`: `WULL_PRIVATE_PAINTED_ALPHA_INERT_PASS`, `WULL_PRIVATE_PAINT_SHADOW_INERT_PASS`, original UNMODIFIED `WaterDropletBody` standalone no external `AbyssCompanion` cradle, static TOP scale1 PNG VALID, `SHADOW_OUTSIDE_HOST_ALPHA=YES`, `PRODUCTION_BODY_PAINT_OUTSIDE_HOST=UNPROVEN`, `BODY_SHAPE_VS_INTERNAL_CHILDREN=UNRESOLVED`, `DYNAMIC_WITNESS=NOT_RUN`, `PRODUCTION_MASK_CHANGED=NO`, `GATE=PRIVATE_ONE_CASE_SHADOW_CLASSIFIED`. The shadow result means the external cradle was NOT necessary for observed exterior alpha in this altered source-pinned PRIVATE assembly. It cannot attribute the outside pixels to the original Bézier path vs internal highlights/eyes/mouth or certify original production clipping/clicking, no dynamic output.
- New source-staged NEXT private isolation: original unmodified Wull body **only its exact original full-size Bézier ShapePath child rendered**, with its original gradient and stroke; hide remaining 4 visual siblings (internal halo, specular highlight, eyes, mouth) on a private child instance after a strict expected five-child/one-full-size-child runtime gate and a `Qt.callLater` visibility checkpoint. DO NOT edit production source. Fixture `scripts/wull-fixtures/paint-alpha-core/shell.qml` blob `eb35bd8366a0d2b274302a02eff089b5507bf3db` commit `4b129b7a0aea19791d93a1671d4679244c2e584a`. It is an intentionally ALTERED child-visibility shadow, not identical original production.
- Separate strict mode0700 current-`dev` clean-clone owner-only offscreen runner `scripts/wull-manual-private-paint-core.py` blob `1fbc0e8e0c8c361a706ff31af1b0a138ec9b841c`, commit `e9de952c55006200d075e70dbae67d2fb40234ea`; retains original renderer/style/config/perimeter and old canary/shadow exact pin sets, private XDG/D-Bus and no display connection, bounded 13s/8MiB/256KiB image/log/process controls, prints only categorical `CORE_OUTSIDE_HOST_ALPHA`/scope and no private image/log/path or Git report. Fake-only `scripts/test-wull-private-paint-core-contract.py` blob `2f0a7dd88076900d8dec2ce08766a6a6b1dd83ee`, commit `e6af4429cfb215e65547d12611c904b1626d76a6`, guards visual-child isolate, source pins/process env/stage parser and fake RGBA PNG malformed/transparent/canvas crop/exterior cases. NEW sources have NOT been run owner-local yet. Full research detail added to existing `docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md`, commit `9dbca05b2057bf53af3cdb6f4895e8efc5cf4b69`.
- NEXT single owner-local action: a new clean 0700 disposable `dev` clone, exact Git blob guards on fixture/runner/test and prior alpha/shadow/production sources; run existing `scripts/test-wull-private-painted-alpha-model.py` followed by new `scripts/test-wull-private-paint-core-contract.py` fake-only, requiring exact PASS markers. ONLY if both actually pass run acknowledged `scripts/wull-manual-private-paint-core.py --acknowledge-private-one-case-core` once; return strict categorical classification and stop immediately on any GATE failure. Regardless of core YES/NO no production mask or defaults changes: compositor clipping/real moving core and all 12 host edge-scale cases, real Rust motion, popup interference, long-run/fractional/multioutput and canonical validation remain unqualified; do not edit `stable`.
