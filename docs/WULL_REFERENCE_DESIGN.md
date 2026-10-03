# Wull reference design — 2026-10-03

The four original `assets/Water Droplet Companion*.png` boards supplied again by the maintainer are the visual reference. They are design material, never runtime pose images. Earlier Cloud automation produced a matte dark dome with white eyes and capsule contact strips. This implementation changes the actual procedural renderer to a rounded liquid-glass droplet with a swept tip, illuminated lower core, cyan glass rim, large blue-black reflective eyes, small curved mouth, pink cheeks, floating droplets and elliptical contact ripples.

Run the interactive preview with `qs -p wullDesign.qml`. Select an expression or theme, tap the large Wull, and use Appear, Notify, Complete, Travel, Hide and Pause motion. It uses the same body/face/shader as `AbyssCompanion`; the gallery is a development surface.

[Actual QML gallery](wull-visual/design-20261003/gallery.png), [9-second motion demonstration](wull-visual/design-20261003/motion.mp4), [software fallback](wull-visual/design-20261003/software-fallback.png), and [source provenance](wull-visual/design-20261003/provenance.json) were captured from source `0a639e67498ebf484f2f7854bf21f2ab0e5ba3e6`. The native stdio process accepted all nine intents, restored an ongoing task after expiry, and remained quiet after hide. These are manual source/renderer checks; desktop and maintainer visual acceptance remain open.

## Reference mapping

| Board requirement | Runtime design |
| --- | --- |
| 1:1 rounded droplet, gently swept tip | Six cubic curves in a square body area inside the existing 76×92 input envelope |
| Outer glass, liquid core, edge light, reflection | One procedural fragment pass; no wallpaper/window texture capture |
| Large glossy dark eyes with blue light and multiple catches | Vector eye contours, radial blue iris, three moving catchlights |
| Small soft mouth and blush | Vector mouth, smile/open/surprised/concerned variants; paired cheeks |
| Idle, happy, excited, thinking, working, surprised, sleepy, sad, alert | Nine semantic expressions shared by Rust and QML |
| Bob, blink, wobble, squash/stretch, gaze | Local interpolation; Rust schedules non-uniform blink/curiosity at low frequency |
| Tap ripple, hover glow, notification bounce, completion shine | Event reactions, bounded spring/number animations, sparse procedural glints |
| Appear/disappear | Host fade, local float offset, contact ripple; no frame/pose switching |
| Theme adaptation | Animated accent color; blue, amber, purple and green previews |
| Smooth travel | Explicit gallery position transition; automatic desktop routes remain an integration gate |
| Small local LLM | Typed, expiring expression intents over the existing single Rust bridge |

## Motion and state ownership

The renderer keeps the existing public host sizes and orientation/input ownership. The visible body has a square aspect ratio inside those bounds. All face geometry counter-rotates with the existing attachment orientation so expressions stay upright. Pointer gaze updates are local to the hovered body and never produce per-frame IPC.

QML layers slow bob, sway and moving reflections with different periods. Tap uses a squash/rebound; positive and urgent expression changes use a short bounce and ripple. Happy/excited reactions add a bounded shine burst. Eyes crossfade between glossy, smiling and closed contours. Animation/effects policy still comes from Appearance/Abyss; hidden or motion-disabled bodies stop animation groups. Software Qt or a failed shader has a procedural vector fallback. Shader readiness uses an actually presented frame, since Qt may reuse a QSB reflection cache while reporting Uncompiled.

The Rust state machine remains deterministic. The optional local-model adapter uses `intent` with one of nine expression names, intensity 0..1, and TTL 250..10000 ms. It cannot reveal a hidden companion or replace an ongoing task permanently. Expiry restores the saved baseline; shell events preempt the temporary reaction. See [protocol](WULL_COMPANION_PROTOCOL_V1.md). No model/inference runtime is installed in this design milestone.

## Evidence and acceptance limits

Export an image with `python3 scripts/wull-render-design.py --output /absolute/new-file.png`. This opens a short-lived standalone window with isolated config and captures only its own QML item. `--software` checks the fallback. `--frames /absolute/empty-directory` exports 180 real QML frames for an animation demonstration. These previews are source renderer evidence, not host desktop screenshots or native acceptance.

The historical contour/motion research tests now exercise their immutable reviewed Git blobs and still reject altered source; they no longer require the current renderer to equal the old prototype. Their measured evidence is retained unchanged. The private rectangle-mask generator's orientation guard follows the existing public `orientationAngle` API.

Production remains default-off. The render is a reference-directed procedural interpretation; there is no measured resemblance score or maintainer visual approval. Full panel/edge/popup travel, editable drag placement, context-menu actions, multi-output/fractional-scale/hotplug/suspend acceptance, and long-session CPU/PSS qualification remain required before enabling the companion by default. The existing connected-surface/Region gates and eight historical visual runs are retained.

Qt material implementation follows the official [ShaderEffect](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html) uniform, premultiplied output and QSB contracts and [RadialGradient](https://doc.qt.io/qt-6/qml-qtquick-shapes-radialgradient.html) for vector eyes.
