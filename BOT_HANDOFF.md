# HADALIS — BOT HANDOFF

Updated: 2026-09-16 22:27 +07:00
Branch: `dev`
Observed user runtime commit: `799b52c3`
Current `dev` HEAD when this handoff was written: `55cd0a730a9c90448ecbbc65f8fb66ec0e4464b0`

All bots: read this after `docs/BOT_PROTOCOL.md`, then fetch current `dev` before changing anything. This file is a handoff, not proof that an item is still open. Reconcile every item against live source first and avoid duplicate/reversion work.

## INCIDENT — shell loads but bar disappears on Niri

Maintainer runtime log on commit `799b52c3` showed:

```text
Type PerimeterRuntime unavailable
PerimeterRuntime.qml:325:13: CompositorFocusGrab is not a type

Type CloseConfirmContent unavailable
CloseConfirmContent.qml:130:5: MascotImage is not a type

Type BootGreeting unavailable
BootGreeting.qml:287:17: MascotAnimation is not a type

quickshell.qmlscanner: Ignoring unresolvable import ".../modules/pill"
```

Niri itself was healthy: shell config loaded, shellEntryReady fired, Niri socket was detected, one output loaded, Weather updated. The failure was QML/type-resolution related, not compositor startup.

## CURRENT-HEAD RECONCILIATION

At `55cd0a730a9c90448ecbbc65f8fb66ec0e4464b0`:

- `modules/perimeter/PerimeterRuntime.qml` now imports `qs.modules.common.widgets`; therefore the specific missing `CompositorFocusGrab` import observed on `799b52c3` appears fixed in live source. Do not re-add or duplicate it.
- `modules/bootGreeting/BootGreeting.qml` no longer contains the failing `MascotAnimation`/`MascotImage` block seen in the maintainer runtime.
- `modules/closeConfirm/CloseConfirmContent.qml` no longer contains the failing `MascotImage` usage seen in the maintainer runtime.
- `modules/pill` is absent on current `dev`, but stale imports remain, including at least:
  - `modules/dock/Dock.qml`
  - `modules/dock/DockAppButton.qml`
  - `modules/sidebarLeft/SidebarLeftContent.qml`
  - `modules/sidebarRight/SidebarRightContent.qml`

The `qs.modules.pill` references are therefore an active dangling-module cleanup target until live source proves otherwise.

## BOT OWNERSHIP / NEXT ACTIONS

### Bot 1 — architecture/core

Verify that critical shell startup cannot be taken down by retired/optional presentation modules. Trace the `ShellIiCriticalPanels`/`ShellIiPanelsImpl` dependency chain and ensure retired compatibility imports do not remain on the mandatory startup path. Prefer fix-forward cleanup; do not restore retired modules merely to satisfy stale imports.

### Bot 2 — QML/perimeter UI

Primary owner for this incident. Repo-wide audit on current HEAD for:

```text
import qs.modules.pill
MascotImage
MascotAnimation
CompositorFocusGrab
```

Remove or migrate stale retired-module references while preserving current visual behavior. Confirm every `CompositorFocusGrab` consumer imports the module that exports it. Treat qmlscanner/parser warnings for missing local modules as real startup-risk signals when they sit on always-loaded files.

### Bot 3 — services/settings

No primary service fault is indicated by this incident. Only act if tracing shows a service-controlled loader or setting can activate an invalid retired QML path. Do not spend time on Weather, Niri detection, or unrelated backend services for this incident.

### Bot 4 — QA/regression

Add/strengthen a regression guard that catches this class before runtime:

- always-loaded QML must not import nonexistent local modules;
- exported local types used by critical panels must resolve through the correct module import;
- retired types/modules (`MascotImage`, `MascotAnimation`, removed `modules/pill`) must not remain as dangling references unless a live implementation exists;
- the guard should fail on source state equivalent to the `799b52c3` incident.

Prefer behavior/module-resolution checks over brittle line-number assertions.

### Bot 5 — install/package/docs/release

Verify `./setup install` and packaged/staged installs copy the same QML tree as current `dev`, and that an update from an older `dev` checkout cannot leave a mixed runtime tree containing removed QML modules/types. Check whether stale installed files need explicit cleanup during install/update/uninstall. Document only if user action is actually required.

## ACCEPTANCE CRITERIA

Do not mark this incident closed until a current-HEAD/fresh-install test demonstrates all of the following:

1. `inir logs` no longer reports `PerimeterRuntime unavailable`, `CloseConfirmContent unavailable`, or `BootGreeting unavailable` for the signatures above.
2. No `quickshell.qmlscanner: Ignoring unresolvable import ".../modules/pill"` remains from always-loaded shell files.
3. On Niri, `Configuration Loaded` and `shellEntryReady` are followed by visible bar/critical shell panels.
4. A repo guard/test detects missing local QML-module imports or dangling retired-type references on critical startup paths.
5. Install/update staging does not leave a mixed old/new QML payload.

When an item is fixed by another commit before your turn, record the evidence and move to the next still-open item instead of recreating the same patch.
