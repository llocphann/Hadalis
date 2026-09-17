# Hadalis

Hadalis is a Quickshell desktop shell for Niri, with secondary Hyprland compatibility. The current `dev` branch is focused on a Caelestia-inspired connected-surface UX while preserving the existing iNiR runtime, services, routing, lifecycle, and panel functionality.

> **Development branch:** `dev`  
> **Current validation policy:** maintainer local validation is authoritative; hosted CI is diagnostic only  
> **Release state:** `dev` is not considered ready for `stable` until the maintainer completes the local regression and live desktop acceptance pass

## Current shell contracts

### Connected bar popups

Existing bar popups continue to use the established `modules/bar/StyledPopup.qml` abstraction. `StyledPopup.qml` now composes the shared Connected Perimeter primitives rather than introducing a second popup framework.

The connected popup path is the default presentation behavior for those popups and does **not** require a new setting, appearance toggle, or full perimeter cutover.

The shared geometry contract covers:

- top, bottom, left, and right bar attachment;
- inward reveal/growth from the attached edge;
- real anchor-aware body/connector geometry;
- device-pixel-aware seam overlap to avoid transparent gaps at fractional scaling;
- a shared visible/input shape so transparent portions of the full-output host remain click-through.

Core primitives live under `modules/common/perimeter/`, including `ConnectedSurfaceGeometry.qml`, `ConnectedSurfaceFrame.qml`, `ConnectedSurfaceConnector.qml`, and `ConnectedSurfaceMask.qml`.

See [`docs/PERIMETER.md`](docs/PERIMETER.md) and [`docs/SHELL_SURFACE_CONTRACTS.md`](docs/SHELL_SURFACE_CONTRACTS.md).

### Full `iiPerimeter` composition

The repository also contains a broader configurable perimeter composition runtime with per-output topology, module registry/hosting, anchors, routing, reservation policy, and feature adapters.

That **full composition cutover remains guarded**. `PerimeterCutoverPolicy.qml` must keep the legacy composition active whenever broad `iiPerimeter` ownership would drop functionality that still exists only in the legacy panel graph.

Connected popup presentation must not be coupled to this broad cutover.

### Dock and Waffle

The ii Dock has one supported user-facing surface style: **Panel**.

- Dock Settings no longer exposes Pill, macOS, Island, or M3 as Dock-style alternatives.
- Legacy persisted `dock.style` values are normalized to `panel` during startup.
- Waffle remains a separate supported panel family with its own taskbar and settings; it is not a Dock style and is not part of Dock-style migration.

### English-only shell UI

Shell UI localization is English-only.

- Canonical UI locale: `en_US`.
- `services/Translation.qml` loads `translations/en_US.json`.
- `translations/en_US.json` is the only shipped shell UI locale catalog.
- Legacy persisted `language.ui` values normalize to `en_US` during startup.
- The old interface-language selector and translation-generation UI are not active product features.

Locale/time formatting remains separate from shell UI language.

## Panel families

Hadalis keeps two supported panel families:

| Family | Runtime |
|---|---|
| Material ii | Classic Bar, ii Dock, sidebars, Overview and related ii surfaces |
| Waffle | Windows 11-style taskbar, Start menu, Action Center and Notification Center |

Waffle must not be classified as a legacy renderer during ii/Connected Perimeter cleanup.

Retired renderer families and old feature surfaces must not be revived merely to satisfy stale configuration or documentation references.

## Connected Perimeter topology

The broad perimeter runtime models eight logical placement slots per output:

```text
┌───────────────────────────────────────────────────────────────┐
│ top.start              top.center                     top.end │
│                                                               │
│ left.center                                      right.center │
│                                                               │
│ bottom.start         bottom.center                 bottom.end │
└───────────────────────────────────────────────────────────────┘
```

Placement belongs to perimeter configuration, not to individual feature implementations. Slots may be empty or host ordered module instances. Feature adapters consume edge/output context instead of owning a permanent hard-coded position.

The current built-in perimeter preset includes ThinkFan/System Monitor, Workspaces/Media/Weather, sidebars, and Dock adapters. That preset describes the full perimeter runtime and does not imply that broad composition ownership is enabled by default.

## Repository map

```text
shell.qml                     # Quickshell root and startup sequencing
ShellIiPanels.qml             # Material ii panel family
ShellWafflePanels.qml         # Waffle panel family
GlobalStates.qml              # Shared runtime UI state

modules/common/               # Shared config, appearance, widgets, perimeter core
modules/bar/                  # Classic Bar + StyledPopup
modules/dock/                 # ii Dock
modules/perimeter/            # Hadalis perimeter feature adapters/runtime
modules/settings/             # Settings pages and compatibility normalization
modules/waffle/               # Waffle family
services/                     # Runtime singletons
scripts/                      # CLI, helpers, regressions and validation
translations/                 # en_US UI catalog + English-only validators
sdata/                        # Install/update lifecycle and migrations
docs/                         # User/developer documentation
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`STRUCTURE.md`](STRUCTURE.md) for the maintained architecture map.

## Configuration compatibility

Runtime configuration is owned by `modules/common/Config.qml` and persisted through the existing iNiR configuration path.

Compatibility normalization is intentionally narrow:

- legacy Dock styles converge to `dock.style = "panel"`;
- legacy UI locale values converge to `language.ui = "en_US"`;
- retired Settings page indices remain hidden/redirected rather than reviving removed feature pages.

`SettingsPageRegistry` is materialized from shell startup so these compatibility migrations do not depend on the user opening Settings first.

## Installation and lifecycle

Typical repository workflow:

```bash
git clone https://github.com/llocphann/Hadalis.git
cd Hadalis
./setup
./setup install -y
./setup update
./setup doctor
./setup rollback
```

The supported forced restart path is:

```bash
inir restart
```

Avoid bypassing the managed user service with raw Quickshell kill/start commands unless debugging the service layer itself.

## Local validation

The canonical maintainer validation entry point is:

```bash
bash scripts/validate-maintainer-local.sh
```

Focused shell-surface regression coverage is also available with:

```bash
python scripts/test-shell-surface-contracts.py
```

A validation result applies only to the exact SHA tested. This README intentionally does not publish an old “latest green SHA”; after `dev` changes, the maintainer should rerun the local validator and use the SHA printed by that run.

The focused shell-surface contract checks source-level invariants for:

- existing `StyledPopup.qml` connected-perimeter integration;
- four-edge geometry/seam behavior contracts;
- Panel-only Dock Settings and legacy Dock migration;
- Waffle remaining a separate panel family;
- canonical English-only UI catalog/runtime behavior;
- startup materialization of configuration normalization.

Static/local regression is not a substitute for live desktop acceptance.

## Live acceptance checklist

For the final local pass, verify at minimum:

1. Open existing bar popups from a top bar and confirm body + connector read as one attached surface.
2. Repeat for bottom, left, and right bar placement.
3. Verify reveal starts from the attached bar/screen edge rather than appearing as an independent floating scale animation.
4. Verify transparent regions outside the visible popup shape do not intercept input.
5. Restart with a legacy `dock.style` value and confirm the persisted value converges to `panel` and only Panel presentation is offered.
6. Verify Waffle behavior is unchanged and is never presented as a Dock style.
7. Restart with a legacy `language.ui` value and confirm the shell stays English and persists `en_US`.
8. Exercise multi-output, hotplug, suspend/resume, fullscreen/focus transitions, and fractional scaling.
9. If testing the full `iiPerimeter` composition separately, confirm fallback prevents loss of legacy-only functionality.

## Development rules

- Work from current `dev`; refetch before edits and branch updates.
- Keep commits focused and fix forward rather than rewriting shared history.
- Reuse existing popup/runtime abstractions instead of building parallel frameworks.
- Keep feature state/functionality separate from perimeter placement.
- Preserve Waffle as a separate supported family.
- Do not add a user-facing Connected Perimeter appearance toggle to control connected popup geometry.
- Do not reintroduce retired Dock style choices or multilingual shell UI generation.
- Keep broad `iiPerimeter` cutover guarded until feature parity is sufficient.

## Further documentation

- [`docs/PERIMETER.md`](docs/PERIMETER.md) — Connected Perimeter geometry, topology and cutover rules.
- [`docs/SHELL_SURFACE_CONTRACTS.md`](docs/SHELL_SURFACE_CONTRACTS.md) — focused local acceptance contract.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — runtime architecture.
- [`STRUCTURE.md`](STRUCTURE.md) — codebase layout.
- [`docs/INSTALL.md`](docs/INSTALL.md) — installation details.
- [`docs/PACKAGES.md`](docs/PACKAGES.md) — packaging.
- [`docs/RELEASING.md`](docs/RELEASING.md) — release process.
- [`docs/IPC.md`](docs/IPC.md) — IPC targets and commands.

## Architectural references

Caelestia is used as a connected-composition/interaction reference, not as a source merge. Hadalis keeps its own topology, runtime ownership, routing, lifecycle, service boundaries, configuration and visual implementation.

Any other external UI reference remains feature-specific and does not change these shell-surface contracts.
