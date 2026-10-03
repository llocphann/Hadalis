# Wull reference design — 2026-10-03

The four original `assets/Water Droplet Companion*.png` boards and the maintainer's [close-up](wull-visual/design-20261003/reference-closeup.png) are the visual reference. They are comparison material, never runtime pose images. The maintainer's contour correction requires a centered, evenly pointed tip above the round, smooth belly. The latest anatomy correction requires **two feet and two hands**, with bubbles orbiting around the body. Tiered optical detail, slight adjustable translucency and dedicated English Companion settings remain. The runtime material uses a three-dimensional implicit liquid volume, refracted light, curved glass reflections, an illuminated lower core, glossy dark eyes, a small soft mouth and pink blush.

Run the interactive preview with `qs -p wullDesign.qml`. Select an expression or theme, tap the large Wull, and use Appear, Notify, Complete, Travel, Hide and Pause motion. Front, 3/4, Side and Back rotate the actual volume. It uses the same body/face/shaders as `AbyssCompanion`. The comparison gallery lives in `scripts/wull-fixtures/design-gallery/`; only this development fixture loads the original reference image.

[Current two-foot/two-hand motion evidence](wull-visual/locomotion-20261003/README.md) includes the [actual walking/emergence video](wull-visual/locomotion-20261003/motion.mp4), [three-tier comparison](wull-visual/locomotion-20261003/material-comparison.png), saved Blender rig readback and exact curve evaluations. Source renderer and short daemon checks pass; strict full-image GPU pixel parity remains inconclusive because identical-source controls also differ. See the evidence's explicit scope and limits.

[Earlier renderer and settings evidence](wull-visual/settings-20261003/README.md), [actual QML gallery](wull-visual/settings-20261003/gallery.png), [9-second motion demonstration](wull-visual/settings-20261003/motion.mp4) and [software fallback](wull-visual/settings-20261003/software-fallback.png) have exact source and artifact digests in [provenance](wull-visual/settings-20261003/provenance.json). Those images retain the previous four-foot anatomy; they do not represent the latest two-foot/two-hand rig. The native stdio process accepted expression intents, restored an ongoing task after expiry, and remained quiet after hide; that proof also verifies scheduled visits and preference dispatch. These are manual source/renderer checks; native desktop and maintainer visual acceptance remain open. The [earlier feet milestone](wull-visual/design-20261003/README.md) is retained unchanged.

## Reference mapping

| Board requirement | Runtime design |
| --- | --- |
| Round 1:1 droplet with an evenly pointed tip | Symmetric radius profile and centered apex in a 3D volume; matching vector fallback inside the existing 76×92 input envelope |
| Outer glass, liquid core, edge light, reflection | Analytic front intersection, bounded refracted back-interface search, Fresnel reflection and a private procedural light environment |
| Large glossy dark eyes with colored light and multiple catches | Convex implicit corneas share the light environment; projected face and eye scale follow camera yaw; vector eyes remain available in software |
| Two feet and two hands | Two flattened ground feet step alternately; two side hands swing on separate Blender tracks; all use the liquid material and camera depth ordering |
| Shadow, reflection and luminous contact rings | A 76×82 texture (152×164 in Quality) captures only Wull's own body, limbs, bubbles and face for a compressed floor mirror; each foot's contact light fades when lifted |
| Small soft mouth and blush | Vector mouth, smile/open/surprised/concerned variants; paired cheeks |
| Idle, happy, excited, thinking, working, surprised, sleepy, sad, alert | Nine semantic expressions shared by Rust and QML |
| Bob, blink, wobble, squash/stretch, gaze | Local interpolation; Rust schedules non-uniform blink/curiosity at low frequency |
| Tap ripple, hover glow, notification bounce, completion shine | Event reactions, bounded spring/number animations, sparse procedural glints |
| Appear/disappear | Blender-authored emergence and dive curves displace the body through the attached screen edge or stable panel/popup boundary; clipped host and input readiness follow presentation |
| Theme adaptation | Body, corneas, droplets and contact plane derive from live `AbyssStyle.accent` and its specular lightness role; palette changes interpolate locally |
| Walking and orbital bubbles | Editable Blender gait, weight shift, alternating planted/swinging feet and opposite hands; slow 3D bubble orbit with front/back depth ordering |
| Smooth travel | Sparse Rust destination suggestions map into one verified free Bar interval; the entire local path stays clear of modules; stable popup/panel handoffs use dive and emergence |
| Small local LLM | Planned local-default AI connection; typed, expiring expression intents already use the existing single Rust bridge |

## Motion and state ownership

The renderer keeps the existing public host sizes and orientation/input ownership. The visible body has a square aspect ratio inside those bounds. All face geometry counter-rotates with the existing attachment orientation so expressions stay upright. Pointer gaze updates are local to the hovered body and never produce per-frame IPC.

QML layers slow bob, sway and moving reflections with different periods. The resting apex has no permanent sideways sweep; state-driven tip displacement is capped below one pixel at the native size. Tap uses a squash/rebound; positive and urgent expression changes use a short bounce and ripple. Happy/excited reactions add a bounded shine burst. Eyes crossfade between glossy, smiling and closed contours. Animation/effects policy still comes from Appearance/Abyss; hidden or motion-disabled bodies stop animation groups. Software Qt or a failed shader has a procedural vector fallback. Shader readiness uses an actually presented frame, since Qt may reuse a QSB reflection cache while reporting Uncompiled.

The material uses an implicit 3D volume, water-like refraction, Fresnel reflection, thickness-dependent absorption/translucency, a saturated illuminated core and small surface-normal ripples. The richer transmitted light retains colored detail instead of clipping each channel into a gray fill. Quality traces a bounded internal reflection and separate red/blue exit rays for subtle dispersion, with three depth samples of soft liquid focusing. Exactly two flattened feet and two higher side hands share the optical rig. They rotate and change front/back ordering with the body's yaw; the vector fallback keeps the same anatomy. The floor mirrors the body/limbs/bubbles/face layer at a fixed contact plane, compresses it in perspective and fades it with distance. Its capture never includes desktop content or recursively includes itself. The old detached theme-surface attachment oval is removed.

## Blender motion and runtime cost

`assets/wull/WullMotion.blend` contains the editable droplet mesh, two feet, two arms, eight orbital bubbles and Walk, Emerge, Dive, Hop and Orbit actions. Rebuild with Blender's Python engine using `scripts/wull-author-motion.py`; the exported `WullMotionData.js` retains every authored LINEAR F-curve key and Blender's stored timing/value precision. It drops only unused constant defaults (zero, or one for scale). `node scripts/test-wull-motion.cjs /absolute/blender-parity.json` compares runtime interpolation against actual Blender evaluations when the authoring script is run with `--parity`.

The desktop loads the small shared scalar module and existing procedural renderer. It never loads the authoring mesh, runs Blender, decodes an animation video or sends frames over IPC. `WullMotion.qml` uses one local gait clock while traveling. Shared particle layouts and cached yaw/orbit trigonometry avoid repeated array creation and duplicate calculations. Optical steps, particle budgets and floor texture sizes are unchanged. Hidden or motion-disabled bodies stop gait, orbit, bob, sway, shimmer and reaction clocks.

The host interpolates walking at 32 native pixels/second, matching each planted foot's opposing stance movement. It wanders only within the current verified free Bar interval. A stable existing Panel or Popup offers a separate full-host rectangle beside its live content bounds; viewport edges and other occupied surfaces reject unsafe candidates. During relocation Wull dives, changes attachment while hidden, then emerges at the destination. Its input Region is disabled until fully presented, and follows its actual position while walking. Hover and task events stop travel. There is still one companion bridge, one existing perimeter window and one native input Region. These source and isolated preview checks do not establish physical pointer pass-through or native multi-output acceptance.

`qs -p wullMotion.qml` opens the actual host in a development panel/popup scene. `python3 scripts/wull-render-design.py --motion --frames /absolute/empty-directory` captures 180 frames and verifies actual travel/emergence, front/back bubble movement and frozen hidden clocks. It captures only its own item and uses isolated settings. Blender is used according to its official [Python module documentation](https://docs.blender.org/api/main/info_advanced_blender_as_bpy.html).

| Wull rendering preset | Steps per exit / refinement | Outer droplets / inner candidates | Own floor capture |
| --- | --- | --- | --- |
| Performance | 10 / 3 | 3 / 0 | None; vector contact rings |
| Balanced (default) | 18 / 5 | 6 / 18 | 76 x 82 |
| Quality | 28 / 7 | 8 / 48 | 152 x 164; sharper filtering |

These are source budgets, not measured FPS/CPU/RAM claims. Total internal reflection can require a second path even at lower presets. Shell Performance caps Wull at Performance; the shell effects/motion policies remain authoritative. Effects-off removes outer/inner droplets and the floor capture while retaining procedural material and anatomy. This is an implicit optical renderer with artistic light/caustic approximations, not a fluid simulator or full path tracer; the studio environment does not reproduce the reference city's exact lighting or refract actual desktop pixels.

## Companion settings

The Rendering section includes a bounded 0..35% Translucency control, initially 16%. It lowers the liquid's opacity slightly while Fresnel edges and bright reflection catches recover opacity; the glossy eyes keep their independent dense material. It composites the actual background through the body without capturing or distorting desktop pixels. The percentage describes the material control, not uniform whole-character transparency.

The English **Settings > Abyss > Companion** page has Overview, Placement, Behavior and Rendering sections. Its live preview reuses `WaterDropletBody`; it starts no second daemon. Right-clicking an interactive Wull opens this page through the existing connected Settings surface. Placement exposes output, edge, along-edge position and size, retaining configured disconnected outputs. Pointer response, an additional fullscreen hide preference, animation and effects controls persist through the existing typed config. Reset affects Companion only.

Personality choices are Calm, Balanced and Energetic. They change local motion amplitude plus native idle cadence, reaction energy/targets and positive expressions. Appearance frequency is Always visible, Every minute, Every 3 minutes or Every 10 minutes. Visits last twenty seconds; interaction extends them, hovering holds them, and an ongoing task holds them until completion. A shell hide cancels both the visibility permission and all automatic deadlines. Defaults preserve the previous always-visible Balanced behavior when enabled. Small-model integration remains the bounded intent adapter described below, with no installed model.

`python3 scripts/wull-preview-settings.py --output /absolute/new.png --section rendering --roundtrip --legacy-config` exercises actual controls, reopens saved config, verifies the live material policy and resets only Companion in isolated storage. `python3 scripts/wull-preview-material.py --output /absolute/new.png` renders all three tiers next to the unchanged concept and checks their budgets and the shell Performance ceiling. Both export only their own QML board.

The Rust state machine remains deterministic. The optional local-model adapter uses `intent` with one of nine expression names, intensity 0..1, and TTL 250..10000 ms. It cannot reveal a hidden companion or replace an ongoing task permanently. Expiry restores the saved baseline; shell events preempt the temporary reaction. See [protocol](WULL_COMPANION_PROTOCOL_V1.md). No model/inference runtime is installed in this design milestone.

## Planned AI connection — Local LLM by default

The maintainer's next design requirement is to connect Wull to an LLM, with **Local LLM as the default connection source**. This section describes future implementation; the renderer and bounded intent transport exist, but the AI settings, conversation UI and inference adapter do not yet exist. AI is enabled separately after configuration, so an unconfigured model cannot delay shell startup. Wull's ordinary personality, visits, expressions and animation remain available without inference.

The first AI implementation targets a small locally installed model, with model size, quantization and CPU/GPU use chosen after measurement on the target machine. Its adapter connects to a local loopback endpoint. It requires no cloud account and does not download a model or start a model server when Settings opens. An unavailable local model produces an honest connection status while the deterministic companion continues. There is **no automatic cloud fallback**; any future remote connection requires the user to select it explicitly.

Add an English **AI** section to the existing **Settings > Abyss > Companion** page:

| Planned control | Default and behavior |
| --- | --- |
| Enable AI | Off until configured and explicitly enabled; independent of Enable Companion |
| Connection | Local LLM; a future remote option must be explicitly selected |
| Local endpoint | Loopback address for the configured local provider; validate before connecting |
| Model | Select an installed small model; show unavailable models clearly |
| Test connection | Explicit health/model probe; show Disconnected, Connecting, Ready, Generating or Error from actual results |
| Context sharing | Direct messages only; selected companion events require opt-in |
| Conversation memory | Session only with bounded history; Clear conversation removes that session context |
| Advanced | Bounded response length, context limit and request timeout; separate from rendering quality |

A **Chat** action opens a conversation surface connected to Wull through the existing Abyss surface host and keyboard ownership. It uses the panel's colors and material roles, keeps replies readable and offers Cancel while generating. Opening a conversation or receiving an automatic event must not steal focus. Calm / Balanced / Energetic may inform response tone, but the model cannot change the user's personality, appearance frequency or rendering settings.

The planned data flow is:

`Explicit message / opted-in event -> async local-model adapter -> validated reply + optional reaction -> CompanionBridge.sendIntent -> existing inir-companiond -> QML interpolation`

Model I/O and generation run outside the UI and companion scheduling loop. There is still one companion daemon and one writer to its stdio bridge; the model server supplies inference, not animation scheduling. Replies are bounded plain text. An optional structured reaction accepts only the nine existing expression names, finite intensity 0..1 and integer TTL 250..10000 ms. The adapter owns validation and request identity; the existing bridge owns protocol sequence numbers. Invalid reaction data must not interrupt a valid text reply or the companion's deterministic state.

Only direct user messages and explicitly enabled meaningful events may request inference. Blink, bobbing, hover motion, reflections and scheduled visits never trigger it. Keep one request in flight, coalesce optional event bursts and prevent an unbounded queue. Send only the user's message and approved semantic context; desktop images, clipboard contents, file contents and unrelated window details are not collected automatically. Model output cannot execute commands or modify shell settings.

Cancel or discard outstanding results on AI disable, provider/model change, shell reload or suspend; a hidden host accepts no AI reaction and starts no automatic inference. An explicitly opened conversation may return text while shell policy hides the droplet, but it cannot reveal Wull. Late replies from a cancelled request cannot update the new session. Temporary model reactions preserve the existing task baseline and yield to shell events. Opening Settings and a quiet/hidden companion do not introduce model polling or inference loops.

Implementation proceeds through provider/connection validation, the asynchronous adapter, English AI settings and connected conversation UI, then integration with the existing bounded intent bridge. First verify fake-provider cases for unavailable models, malformed output, timeouts, cancellation, stale replies and task restoration. Then qualify an actual small local model on a pinned source revision: text and reaction behavior, latency, CPU/PSS, bounded history/queues, model residency and shell frame pacing. Performance / Balanced / Quality continue to describe Wull's optical rendering, independently of AI budgets. Existing visual/native acceptance remains open; the active [Phase 6 plan](../to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md#phase-6--local-llm-connection) records the implementation work.

## Evidence and acceptance limits

Export an image with `python3 scripts/wull-render-design.py --output /absolute/new-file.png`. This opens a short-lived standalone window with isolated config and captures only its own QML item. `--software` checks the fallback. `--frames /absolute/empty-directory` exports 180 real QML frames for an animation demonstration. These previews are source renderer evidence, not host desktop screenshots or native acceptance.

The historical contour/motion research tests now exercise their immutable reviewed Git blobs and still reject altered source; they no longer require the current renderer to equal the old prototype. Their measured evidence is retained unchanged. The private rectangle-mask generator's orientation guard follows the existing public `orientationAngle` API.

Production remains default-off. The gallery places the unmodified reference beside the actual renderer so contour, face scale, light catches, liquid depth and contact effects can be compared throughout iteration. There is no measured resemblance percentage or 100% visual approval; the reference's lighting, internal pattern and contact detail still differ. Production panel/edge/popup travel acceptance, editable drag placement, context-menu actions, fresh native paint/input acceptance, multi-output/fractional-scale/hotplug/suspend acceptance, and long-session CPU/PSS qualification remain required before enabling the companion by default. The existing connected-surface/Region gates and eight historical visual runs are retained and are not reused as acceptance of this new renderer.

Qt material implementation follows the official [ShaderEffect](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html) uniform, premultiplied output and QSB contracts, [ShaderEffectSource](https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html) for the companion's own reflection, and [RadialGradient](https://doc.qt.io/qt-6/qml-qtquick-shapes-radialgradient.html) for the vector fallback and soft blush.

The optical structure is informed by the primary [dielectric reflection/transmission model](https://pbr-book.org/4ed/Reflection_Models/Dielectric_BSDF) and [volume transmittance](https://pbr-book.org/4ed/Volume_Scattering/Transmittance). The luminous core, procedural studio and liquid focusing are artistic approximations on top of those mechanisms.
