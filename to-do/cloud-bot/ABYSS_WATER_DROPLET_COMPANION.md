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
