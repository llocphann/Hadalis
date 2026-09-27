# Abyss continuous liquid mass

## Maintainer clarification (September 27)

Abyss is the intended successor to Material. Shared layouts, controls, sizes and
feature behavior remain the design baseline. The rework concerns ownership and
presentation of Screen Edge, modules, popups, Dock and large surfaces.

The resting Screen Edge is a thicker **flat, continuous strip**, with no permanent
module depressions or bulges. Waves are optional and disabled by default.
Transparency, wallpaper blur and wave controls enhance the existing design;
opaque, blur-free, wave-free presentation uses the original Material surface ink.
Popup features supply their existing content and measured size. The central
output field supplies the attached silhouette once, rather than each feature
painting another connector. These instructions supersede the earlier always
sculpted module silhouettes and default interactive waves in the concept brief.
Material remains available for regression comparison during this cutover;
Waffle remains independently supported.

## Audit baseline and scope

The September 27 redesign starts at dev `aed7241f202e7d99f248aaeb1a1989ed99d7acc2`.
Canonical local validation: 173 checks passed, one dedicated Nix check deferred.
Native qualification and unresolved physical hardware gates remain in ABYSS.md;
that evidence does not qualify this redesign. The new brief explicitly includes
Settings, Dashboard, Overview, the control panel and a desktop edge editor.

The audit follows presentation, routing, configuration, content, input, shared
service leases, shader packaging and install/local-validation contracts. It is
not a security audit of unrelated backend implementations.

## Current flow

```text
IPC / shortcut / module
    -> GlobalStates + ShellLayoutController (one shared routing owner)
    -> family mount gate in shell.qml
    -> Abyss critical host -> one AbyssPerimeter per output
       -> AbyssBar: five evenly divided legacy module groups
       -> seven AbyssBodyHost instances: geometry + clipped content + input
       -> AbyssField: one inverse rounded workspace hole / union of 12 records
    -> Abyss deferred host -> separate shared specialist PanelWindows
    -> settings root loader -> shared SettingsOverlay or external settings window
```

The field already owns one fill/rim/shadow and uses a static wallpaper texture.
It has no clock uniform. Its deformations are static rounded boxes and finite
opening tweens, not propagating waves. A grouped bar deformation does not follow
individual module bounds. Separate Settings/Dashboard/control hosts prevent a
continuous liquid envelope. The private native harness identified and fixed
shared mount, fullscreen, QML-list, cached-shader and outgoing clipboard faults;
those lifetime contracts must survive the redesign.

## Reuse boundaries

| Surface | Existing functional content | Presentation work |
| --- | --- | --- |
| Settings | SettingsOverlay rail, search, page host, persistence, dialog guard | Embed the existing card in the output field; retain ordinary host for Material |
| Dashboard | DashboardContent / DashboardCanvas | Set embeddedSurface, keep dimensions and editing/agenda actions |
| Overview / launcher | OverviewDashboard, OverviewNiriWidget, OverviewWidget, OverviewAllAppsGrid | Adapt content composition and search/task view; keep compositor interactions |
| Control panel | ControlPanelContent and its section components | Suppress outer card in embedded mode; retain controls |
| Left sidebar | AI, LocalMusicView and existing feature pages | Keep functional pages inside a large connected envelope |
| Right sidebar / devices | Existing controls/device content and shared services | Reuse functional controls and dialogs inside liquid host |
| Calendar / media / weather | Existing shared backends and content | Geometry participant and finite open/close impulses |
| Dock | TaskbarApps / AppSearch / native toplevels | Participant-sized body, per-icon impulse, stable reservation |
| Notifications / clipboard / OSD | Shared models and actions | Connected participants; immediate input release on close |
| Lock / polkit / region tools | Existing security/native workflow owners | Retain native ownership; do not register duplicate IPC or intercept native dialogs |

## Target flow and invariants

```text
output-local controller
    -> participant registry (edge, position, extent, depth, mass, reveal, content)
    -> one closed-loop spring/wave state (displacement + velocity)
    -> one material field (participant geometry + wave texture + wallpaper)
    -> independent readable content Items / explicit content-only input mask

pointer/open/close/drag -> bounded impulse at loop coordinate
edit draft -> output-local normalized placements -> Done persists / Cancel restores
```

The wave loop follows top -> right -> bottom -> left with wraparound. Logical
output dimensions determine arc length, so resize/scale cannot leak state to
another output. Neighbor coupling propagates impulses; spring stiffness,
damping/viscosity, corner transmission, distance and bounded displacement keep
the solver stable. There is no unbounded particle or two-dimensional fluid
simulation. A timer runs only while energy remains or an explicit interaction
continues. ACTIVE -> SETTLING -> SLEEPING stops updates at rest. Hidden,
fullscreen-covered, locked and reduced-motion outputs clear transient motion.

Module placements are normalized and identified independently of list order.
Existing enabled module configuration seeds the first layout. Geometry follows
each module's actual bounds and hover/press influence, without a second bar
fill. Shared bar auto-hide/output targeting and work-area reservations retain
their functional meaning. Reservation geometry does not fluctuate with waves.

Large envelopes receive greater mass, broader influence and slower pull/rebound.
Content uses stable mature layout sizes and padding. Decorative wave pixels do
not become input regions. The workspace center remains pass-through; editor
input expands only during explicit editing. Native dialogs yield keyboard and
layer ownership. Escape/close/unload always release input and resource leases.

The material derives directional reflection, thickness and refraction from the
same distance field. It keeps a dark readable interior, environmental cyan/blue
and restrained bloom. Performance quality bounds texture taps and resolution;
it must not substitute a neon rectangle for the connected geometry.

## Implementation and acceptance sequence

1. Audit and record presentation/reuse boundaries (this checkpoint).
2. Output controller/participant registry and shared reservoir geometry.
3. Individual module layout/geometry, preserving existing actions.
4. Closed-loop solver, impulses, lifecycle and deterministic behavior tests.
5. Small popup reactions and stable input.
6. Dock fusion, icon reactions and reservation lifecycle.
7. Embedded mature Settings and style-aware routing.
8. Dashboard/Overview/control and remaining ordinary surface adapters.
9. Desktop Live Edge Editor: add, reorder, cross-edge drag, disable/remove,
   spacing, reset, output profiles, atomic Done and snapshot Cancel.
10. Dedicated Surface/Waves/Modules/Popups/Live Editor/Interaction/Performance
    settings and a preview using the production solver.
11. Profile idle/active/settling and lifecycle/native focus/fullscreen behavior.
12. Full local regressions plus native motion recordings and final review.

Each implementation checkpoint records its exact commit and relevant local
tests. Native recordings must show idle, module hover/click, calendar open/close,
Settings, Dashboard, Dock and editor cross-edge drag/exit. A still image is not
motion evidence. Recordings and measurements apply only to the source identity
used to produce them. Material and Waffle retain independent presentation.

Physical multi-monitor/hotplug/suspend/mixed-DPI acceptance remains separate
from a nested single-output run. Any unavailable native or specialized adapter
is reported explicitly; no local parser pass substitutes for live interaction.

### Reservoir checkpoint

The output controller now collects independently registered body geometry and
input records. Participant migration removes the old registration, and close
releases input immediately while presentation retracts. Forty bounded shader
slots leave room for individual modules and large envelopes. Large surfaces
opt into a 92% depth bound; ordinary opposing sidebars retain the 42% bound.
Geometry/orientation/flood-fill regressions, actual QML registry migration and
body lifecycle, shader cold/cache/error/software checks and touched-file QML
validation passed. This checkpoint does not yet add propagation or new content.
