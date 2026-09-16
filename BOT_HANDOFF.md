# HADALIS — BOT HANDOFF

Updated: 2026-09-16 22:30 +07:00
Branch: `dev`
Observed user runtime commit: `799b52c3`
Current `dev` HEAD when this handoff policy was updated: `c16050a8ef51dc17f0cd2e26454cd699fdbb95ab`

All bots: read this after `docs/BOT_PROTOCOL.md`, then fetch current `dev` before changing anything. This file is a handoff, not proof that an item is still open. Reconcile every item against live source first and avoid duplicate/reversion work.

## SHARED LOCAL-TEST ISSUE QUEUE POLICY

`BOT_HANDOFF.md` is the shared queue for maintainer/local-test issues that still need investigation or repair.

Whenever a maintainer local run, staged install, runtime smoke test, parser/QML check, packaging check, docs/l10n check, or other non-Nix acceptance test reveals a real issue, record it here before the next bot round whenever practical.

Every bot must treat this queue as work-stealing input, not as passive notes.

### Start-of-turn protocol for all 5 bots

1. Read `docs/BOT_PROTOCOL.md`.
2. Read the current `BOT_HANDOFF.md`.
3. Fetch current `dev` and record the exact HEAD SHA.
4. Reconcile queued issues against live source and recent commits.
5. Ignore/close items already fixed by another commit; do not recreate the same patch.
6. Select the highest-priority still-open issue whose **root cause** belongs to your ownership lane.
7. If your primary lane has no open issue, steal an independent high-value issue that does not overlap another bot's active area.
8. Fix forward with one technical purpose per commit.
9. Add or strengthen a regression test/guard when practical.
10. Record enough evidence for the next bot/maintainer to know what changed and what still requires a local rerun.

### Deterministic ownership by root cause

Do not assign ownership merely from the filename of the failing test. Assign it from the underlying defect.

- **Bot 1 — architecture/core:** Connected Perimeter core, composition boundaries, routing, lifecycle ownership, startup dependency chains, config authority, architectural regressions.
- **Bot 2 — QML/UI:** QML type/import failures, visual/runtime QML warnings, geometry, focus/input, clipping, responsive layout, accessibility, animation lifecycle, presentation components.
- **Bot 3 — services/settings/system:** services, settings pipeline, persistence, subprocesses/watchers, TLP/ThinkFan, audio/media backends, Weather, Network/Bluetooth, optional dependency runtime behavior.
- **Bot 4 — QA/regression:** broken/stale tests, validator/harness defects, missing regression coverage, source guards, parser/test infrastructure, lifecycle/performance regression detection.
- **Bot 5 — completion/release:** localization, docs contracts, install/uninstall, packaging, dependency hygiene, namespace/product migration, release engineering and release docs.

For a cross-cutting issue, choose one **primary owner from the root cause** and let other bots handle only independent supporting work. Example: a QML type-resolution bug is Bot 2 primary; a missing test that should have caught it is independent Bot 4 work; a stale installed payload that preserves removed QML is independent Bot 5 work.

### Priority order

Use these priorities when multiple local issues are queued:

- **P0:** shell cannot start/use critical UI, data-loss risk, install/update can break the active environment.
- **P1:** blocks canonical local acceptance, staged install, core runtime path, or a required release gate.
- **P2:** real regression/warning affecting a supported feature but not blocking the whole acceptance run.
- **P3:** cleanup, stale references, non-blocking hardening, or future-proofing.

Within the same priority, prefer the issue that blocks the largest number of downstream checks.

### Standard issue record

New local-test issues should use this compact shape so bots can divide work without re-investigating the basic evidence:

```text
ID: LOCAL-<number or short-name>
Priority: P0 | P1 | P2 | P3
Status: OPEN | IN-PROGRESS | FIXED-IN-SOURCE | NEEDS-MAINTAINER-RERUN | CLOSED
Observed SHA: <exact tested SHA>
Observed by: <local validator / runtime smoke / staged install / command>
Failure: <short stable signature>
Root-cause lane: Bot 1 | Bot 2 | Bot 3 | Bot 4 | Bot 5 | cross-cutting
Primary owner: <bot>
Supporting owner(s): <optional>
Evidence: <relevant log/test/file facts>
Required fix: <behavioral invariant, not guessed implementation>
Acceptance: <specific test/runtime condition that proves resolution>
Notes: <optional current-HEAD reconciliation>
```

A bot may change an item's status to `FIXED-IN-SOURCE` after landing a source fix, but must not mark it `CLOSED` merely because code looks correct. Local acceptance issues close only when the required acceptance evidence exists for the relevant current SHA/environment.

### Concurrency rules

- Never have multiple bots independently rewrite the same fix.
- Before editing, fetch the current target file/blob and inspect recent overlapping commits.
- If another bot already fixed the root cause, pivot immediately to the next queue item or an independent regression/packaging/support task.
- Do not revert another bot's valid fix just to satisfy a stale assertion; modernize the assertion around the intended invariant.
- Do not weaken a real local acceptance gate to make the queue smaller.
- Do not restore retired modules/types merely to silence stale references unless live architecture requires them.
- `stable` remains untouched by bots.

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
