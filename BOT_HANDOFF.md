# HADALIS — BOT HANDOFF

Updated: 2026-09-16 22:59 +07:00
Branch: `dev`
Observed user runtime commit: `799b52c3`
Current `dev` HEAD when this handoff policy was updated: `0245958a35f68c409ddb59c033f6cbe99ad17ba7`

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

At `0245958a35f68c409ddb59c033f6cbe99ad17ba7`:

- `modules/perimeter/PerimeterRuntime.qml` no longer instantiates `CompositorFocusGrab`; commit `4e124b29` uses `HyprlandFocusGrab` directly with `Quickshell.Hyprland` imported and `CompositorService.isHyprland` in the active condition. The compatibility `CompositorFocusGrab.qml` implementation and its `qmldir` export still exist, so do not treat the old `799b52c3` missing-type signature as a current live consumer without new runtime evidence.
- `modules/bootGreeting/BootGreeting.qml` no longer contains the failing `MascotAnimation`/`MascotImage` block seen in the maintainer runtime.
- `modules/closeConfirm/CloseConfirmContent.qml` no longer contains the failing `MascotImage` usage seen in the maintainer runtime.
- `modules/pill` is no longer absent. Commit `d82660cc` restored a **theme-only** local module (`PillTheme.qml` + `qmldir`) because live consumers still use its theme tokens. `qs.modules.pill` is therefore not a dangling import on current source; do not delete it merely to mirror the old runtime incident.
- Bot 4 source guards are fixed in source: `a6fa3d0a` added local `qs.*` module/type resolution checks, `4eb92eb6` wired them into `qml-check --all`, `9cf567a8` catches all code-level retired-type references, and `5aa22342` provides negative/positive fixtures reproducing the `799b52c3` failure classes.
- Bot 4 staged-install coverage is also fixed in source: `b690c88e` runs `qml-check --all --root` against both fresh staged payload and in-place reinstall payload, so packaging omissions or mixed QML/module trees become a required local regression failure.
- No maintainer clean-clone/fresh-install runtime log exists yet for the current HEAD family. Source fixes and contracts must therefore remain `NEEDS-MAINTAINER-RERUN`, not `CLOSED`.

## BOT OWNERSHIP / NEXT ACTIONS

### Bot 1 — architecture/core

**FIXED-IN-SOURCE at `8ce1f65c79b53d7cb6d64e5a1109e9bfca4a2055` / NEEDS-MAINTAINER-RERUN.** The startup dependency trace confirms `ShellIiPanelsImpl.qml` remains behind deferred URL loaders and is not a mandatory critical-startup dependency. `ShellIiCriticalPanels.qml` now separates runtime activation eligibility from final cutover ownership: the perimeter runtime may attempt instantiation only after config/source prerequisites pass, while legacy Bar/Dock remain authoritative until `PerimeterRuntime.qml` publishes a successful root readiness handshake. `PerimeterCutoverPolicy.enabled` now requires that handshake, and Connected Perimeter chrome itself cannot map when final cutover is false. `scripts/test-perimeter-family-contracts.sh` contains source guards for this contract.

Do not duplicate this source fix without new current-HEAD evidence. Required acceptance remains an exact-SHA local contract/parser run plus a Niri runtime rerun demonstrating that a missing/invalid optional perimeter presentation cannot remove critical fallback chrome.

### Bot 2 — QML/perimeter UI

The original missing-type/import signatures are fixed in current source. Continue only if live source or a new parser/runtime log shows a current QML resolution failure. In particular:

- do not remove `qs.modules.pill` solely because the old handoff called it dangling; a live theme-only implementation now exists;
- keep `MascotImage`/`MascotAnimation` retired references out unless a live implementation is intentionally restored;
- verify compositor-specific focus behavior from current `PerimeterRuntime` rather than restoring the old `CompositorFocusGrab` call just to match historical code.

### Bot 3 — services/settings

No primary service fault is indicated by this incident. Only act if tracing shows a service-controlled loader or setting can activate an invalid QML path. Do not spend time on Weather, Niri detection, or unrelated backend services for this incident.

### Bot 4 — QA/regression

**Incident guard work is FIXED-IN-SOURCE / NEEDS-MAINTAINER-RERUN.** Do not duplicate the local-module guard or fixture. Continue QA work on:

- canonical validator false-red/false-green defects;
- staged install/runtime regression coverage;
- lifecycle/resource/performance regressions;
- stale or brittle contracts introduced by concurrent changes.

The current guard must continue to fail on source equivalent to `799b52c3` while accepting live implementations such as the restored theme-only `modules/pill` contract.

### Bot 5 — install/package/docs/release

Source regression coverage now checks fresh staged and reinstall QML/module resolution via `b690c88e`. Continue verifying `./setup install`, packaged installs, and real update/uninstall behavior so an older installed tree cannot remain mixed with current QML. Do not claim criterion 5 closed until a maintainer/current-HEAD staging or clean-clone acceptance run supplies the required evidence.

Bot 5 fixes already landed in the current `dev` family include fail-closed config namespace migration, runtime-payload mirror cleanup for Make/Arch staging, byte-preserving reviewed localization repair tooling, release-gated localization provenance, and uninstall path literalization. `b66087ce` removes unsafe `eval` re-expansion from managed uninstall paths, `d41246fc` makes uninstall path safety release-required, and `030f012d` makes every `translations/l10n/*-repairs.json` provenance state release-required without applying or pruning translations.

Still-open Bot 5 queue after source audit:

```text
ID: LOCAL-setup-recovery-orphans
Priority: P1
Status: OPEN
Observed SHA: f24da74ecf333b14ed1a70fa77cfdaadbe2d6ab7
Observed by: Bot 5 source/install lifecycle audit
Failure: recovery-style ./setup install can preserve retired root-level QML when IS_UPDATE=false
Root-cause lane: Bot 5
Primary owner: Bot 5
Evidence: sdata/subcmd-install/3.files.sh finalizes the canonical .inir-manifest but calls cleanup_orphans only inside an IS_UPDATE=true guard; managed subdirectories use rsync --delete while root QML is copied file-by-file.
Required fix: every managed runtime refresh must remove manifest-orphaned root QML/source-only files while preserving runtime-exclusion/private artifacts; update backup/runtime verification semantics may remain update-only.
Acceptance: a regression exercises an existing/partial runtime through the install path with IS_UPDATE=false and proves retired managed root QML is removed while excluded/private artifacts survive.
Notes: do not move cleanup side effects into generate_manifest merely to avoid editing the installer; that helper is intentionally manifest-only.

ID: LOCAL-uninstall-dangling-owned-link
Priority: P2
Status: OPEN
Observed SHA: f24da74ecf333b14ed1a70fa77cfdaadbe2d6ab7
Observed by: Bot 5 uninstall source audit
Failure: an iNiR-owned dangling symlink can survive uninstall_remove_inir_only
Root-cause lane: Bot 5
Primary owner: Bot 5
Evidence: uninstall_remove_inir_only pre-counts with -e and removes only -d/-f paths; a dangling symlink satisfies none of those tests.
Required fix: remove package/app-owned symlink paths, including dangling links, as links without traversing arbitrary targets; preserve the namespace migration rule that foreign legacy symlinks are not silently deleted.
Acceptance: extend uninstall path-safety regression with a dangling owned symlink and prove the link is removed without touching its absent/foreign target.

ID: LOCAL-tr_TR-reviewed-placeholders
Priority: P1
Status: OPEN
Observed SHA: f24da74ecf333b14ed1a70fa77cfdaadbe2d6ab7
Observed by: Bot 5 localization/catalog audit
Failure: three reviewed Turkish usage placeholders remain pending in translations/tr_TR.json
Root-cause lane: Bot 5
Primary owner: Bot 5
Evidence: translations/l10n/tr_TR-placeholder-repairs.json records three exact reviewed from/to repairs; live tr_TR catalog blob remains c8b36d43888e85bfde60b9c0f300b81d18fc064f. The helper can validate/apply them byte-preservingly in a checkout, while the GitHub connector currently offers only whole-file replacement for the 272 KB catalog.
Required fix: apply exactly the reviewed replacements without bulk rewriting or pruning historical translations, then run locale audit/source parity.
Acceptance: reviewed-replacement --status reports applied and the canonical localization/docs/source-parity gates pass on the exact tested SHA.
```

## ACCEPTANCE CRITERIA

Do not mark this incident closed until a current-HEAD/fresh-install test demonstrates all of the following:

1. `inir logs` no longer reports `PerimeterRuntime unavailable`, `CloseConfirmContent unavailable`, or `BootGreeting unavailable` for the signatures above.
2. No `quickshell.qmlscanner: Ignoring unresolvable import ".../modules/pill"` remains from always-loaded shell files.
3. On Niri, `Configuration Loaded` and `shellEntryReady` are followed by visible bar/critical shell panels.
4. A repo guard/test detects missing local QML-module imports or dangling retired-type references on critical startup paths. **FIXED-IN-SOURCE** by the Bot 4 guard/fixture commits above; still requires inclusion in an exact-SHA maintainer rerun.
5. Install/update staging does not leave a mixed old/new QML payload. **CONTRACT COVERED IN SOURCE** by staged fresh/reinstall checks in `b690c88e`; still requires exact-SHA maintainer rerun and any environment-specific install verification owned by Bot 5.

When an item is fixed by another commit before your turn, record the evidence and move to the next still-open item instead of recreating the same patch.
