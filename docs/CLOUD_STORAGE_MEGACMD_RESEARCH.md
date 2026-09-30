# Cloud Storage / MEGAcmd Settings — research only

Status: **RESEARCH; NO IMPLEMENTATION AUTHORIZED**
Research date: 2026-09-30 (Asia/Ho_Chi_Minh).
Hadalis reference: `llocphann/Hadalis@dev`, observed `76245857e5ddd9e3bd0c2e45eb4eaaf23e0b0566`.
Scope: Evaluate a first-class **Cloud Storage** Settings page that manages the MEGA account and **MEGAcmd-owned** syncs, transfers and backups using the official `mega-*` scriptable commands. Do **not** modify runtime code, execute commands against the maintainer's MEGA account, or assume the official MEGA Desktop app is remotely controlled by MEGAcmd. Verify everything on the currently installed MEGAcmd version before implementation.

## 1. Key feasibility finding: distinguish MEGA Desktop / MEGAsync from MEGAcmd

Official MEGAcmd has a separate background server (`mega-cmd-server`), interactive shell (`mega-cmd`), and scriptable clients (`mega-whoami`, `mega-sync`, `mega-transfers`, etc.). Its client commands can start its own server on demand, which persists state/cache and keeps sync/backup activity alive independently of a Quickshell Settings window.

The official docs describe its sync algorithm as the same underlying mechanism used by MEGAsync, **not** the same running desktop application's process, sync configuration, cache, status or command interface. The public material inspected does **not** establish a supported MEGAcmd-to-MEGA-Desktop control protocol. Therefore:

- An accurate V1 product name is **Cloud Storage > MEGA (MEGAcmd)** or **MEGA via MEGAcmd**, not a claim to manage an already-running MEGA Desktop/MEGAsync instance.
- Start with a dedicated MEGAcmd-managed account/session and expose only MEGAcmd-owned jobs.
- If MEGA Desktop is detected, warn about competing clients and conservatively block creating a CLI sync with a local directory overlapping a Desktop-managed sync. Because a supported Desktop config/status API has not been verified, mere process detection cannot prove non-overlap: request explicit owner confirmation or disable creation when overlap cannot be established. Read-only account/CLI-status inspection can remain available.
- A genuinely unified desktop-client controller would require separate research into a supported MEGA Desktop API/IPC or SDK integration. Do not scrape private Desktop config or reimplement its session behavior.

Sources: [MEGAcmd user guide](https://github.com/meganz/MEGAcmd/blob/master/UserGuide.md), [official CLI repository](https://github.com/meganz/MEGAcmd), [MEGA Desktop source](https://github.com/meganz/MEGAsync).

## 2. Existing Hadalis fit, without a second Settings framework

Current Hadalis Settings shares one `SettingsPageRegistryData.qml` registry and `SettingsPageRegistry.qml` facade across standalone `settings.qml`, the overlay `SettingsOverlay.qml`, and drill-down `SettingsFocus.qml`. All three use lazy page loading through `SettingsPageHost.qml`, so add one page rather than independent UIs. The page should use `ContentPage`, `SettingsTaskNavigator`, `SettingsCardSection`, `SettingsGroup`, established widgets and `ConfirmationService`.

Current registry indices stop at 35 (`automation`); append a stable `cloud-storage` key rather than insert a page or reuse hidden legacy slots. Adding only the entry is **insufficient**: the `SettingsPageRegistry.isPageApplicable()` non-Abyss and Waffle branches currently restrict most pages to index <32. They must explicitly allow the appended cross-family Cloud Storage page. Update the shared default **Features & Services** category for Abyss and Waffle; `SettingsNavigation.js` appends newly known pages to a saved arrangement when missing, subject to review of hidden/custom layouts. Search entries and deep links must use the new stable key.

Suggested future component names (planning only):
- `modules/settings/CloudStorageConfig.qml` — visual page, Settings search section activation and state projections; no direct shell construction.
- `services/deferred/MegaCmdService.qml` or a page-owned lightweight controller — optional state, consumer demand, refresh coalescing, typed read/action results.
- `scripts/cloud/mega_bridge.py` — tightly allowlisted external-process adapter with bounded timeouts, argv arrays, normalized JSON, structured errors and no credential logging.
- Focused parser/controller/Settings-route tests, plus optional packaging guidance. The existing `modules/settings/AutomationConfig.qml` + `scripts/hadalis-automation-control.py` shows the narrow JSON-bridge pattern; do **not** couple this feature to the autonomous Automation manager or its scheduler.

The source/package boundary currently ships `modules/`, `services/` and `scripts/` per `sdata/runtime-payload-dirs.txt`, so a feature helper fits existing payload layout. MEGAcmd itself should be a separately detected/installed **optional** external dependency, with distribution-specific guidance; do not silently install packages or block core shell startup.

## 3. Proposed page — visually integrated, functionally isolated

`Settings > Features & Services > Cloud Storage` with the normal responsive Material/Abyss Settings components. A `SettingsTaskNavigator` switches five internal sections within the one page:

1. **Overview**: dependency found/missing, backend/version, MEGAcmd server/session state, signed-in account identity, used/total storage, active/suspended sync counts, transfer summary, unresolved-issue count, manual refresh and timestamp. Distinguish `Unavailable`, `Not configured`, `Signed out`, `Connecting`, `Running`, `Degraded`, `Offline`, `Permission error`, `Stale snapshot`. Do not show `Synced` merely because the CLI process exits with code zero.
2. **Sync folders**: per-sync row/card with local and remote paths, ID, separate RUN_STATE and STATUS, last observed error, pause/enable, exclusions link, new sync wizard. Show explicit two-way deletion/conflict warning before creating a new pair. The `Disabled` state can restart like a new sync; do not label every nonrunning state `Paused`.
3. **Transfers**: distinguish upload/download/sync/backup; show bounded active/completed list, progress where reliably reported, pause/resume by transfer tag, speed limits and optional per-job cancellation confirmation. Pausing a transfer is **not** equivalent to pausing the sync definition.
4. **Backups**: configured source/destination, schedule, retention count, next run, last result/history, clear differentiation from two-way synchronization. A running MEGAcmd server is required for scheduling.
5. **Preferences & Diagnostics**: MEGAcmd dependency information and safe install/open-interactive-shell guidance, per-sync ignore filters, optional bandwidth preferences, last command's redacted error/exit/status/timestamp, copy/export sanitized diagnostics. Keep status/controls distinct from any MEGA Desktop app outside CLI ownership.

Keep direct cloud-file browsing (`mega-ls`, uploads/downloads), WebDAV and FUSE mounting **out of the first implementation** pending confirmed owner scope; they are supported capability candidates, not needed to operate sync/transfer/backup settings.

## 4. Verified CLI capability map (check installed version)

| Feature | Supported CLI surface | Important behavior |
|---|---|---|
| Account identity | `mega-whoami`, `mega-whoami -l` | Extended output includes storage and active session information; redact before UI/logging. |
| Storage | `mega-df` | Supports byte counts or `-h` human-readable values; parse numbers from the nonhuman form when feasible. |
| Syncs | `mega-sync` | Lists ID, LOCALPATH, REMOTEPATH, RUN_STATE, STATUS, ERROR; supports `--col-separator` and `--output-cols` on documented versions. |
| Create sync | `mega-sync <localpath> <remotepath>` | Bidirectional. Destructive propagation is possible after later changes. |
| Pause/enable sync | `mega-sync -p <ID>`, `mega-sync -e <ID>` | Different from pausing upload/download transfers. |
| Remove sync definition | `mega-sync -d <ID>` | Documentation says it removes the synchronization, not existing files; confirm before action. |
| Sync errors | `mega-sync-issues` with `--detail` as needed | Use as source for actual file conflicts/warnings, not a generic invented error string. |
| Ignore filters | `mega-sync-ignore` | Filters have MEGA-specific syntax and scope; use validated UI/warnings, not arbitrary shell evaluation. |
| Transfers | `mega-transfers --summary`, `--output-cols`, `--col-separator` | Documented pause `-p`, resume `-r`, cancel `-c` by tag/all; cap list output. |
| Backups | `mega-backup`, `mega-backup -l`, `mega-backup -h` | Period/retention/history; stopped server can produce skipped backups. |
| Bandwidth | `mega-speedlimit` | Must distinguish speed and connection limits; verify units/version. |
| Login/logout | `mega-login`, `mega-logout` | Only one logged-in entity in an ordinary MEGAcmd session; a full logout clears local session cache including sync/backup configuration. |

Primary command references: [sync](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync.md), [transfers](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/transfers.md), [sync issues](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-issues.md), [ignore syntax](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/sync-ignore.md), [backup](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/backup.md), [login](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/login.md), [logout](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/logout.md), [storage](https://github.com/meganz/MEGAcmd/blob/master/contrib/docs/commands/df.md).

**Version and parser limitation:** the public UserGuide examined identifies version **2.6.0**; individual command docs describe text/column output, not a stable machine-readable JSON contract. Probe the *installed* version and `--help` surfaces, use CLI-level explicit columns/separator where supported, and validate spaces, Unicode, delimiters, errors, localized messages and truncated output with recorded fixtures. Never bind the UI to unverified regexes over arbitrary human tables. Prefer stable sync IDs rather than display paths for actions. Unrecognized output => `parse_error / unavailable` with diagnostics, never a false zero-issue/synced status.

## 5. Lifecycle, performance and safety design

**One owner**: MEGAcmd server remains the sync/backup engine and source of truth. Hadalis is a front-end only; no second sync scheduler, metadata mirror or silent background worker. No provider polling during shell boot. Open the page in a no-side-effect dependency-detection state; CLI commands can implicitly start `mega-cmd-server`, so ask before connecting/starting the engine if it is not already active. Closing Settings must **not** shut down the external server or destroy ongoing syncs/backups.

**Read strategy**: one coalesced status operation per refresh; poll only while the page is visible (tentative 5–10 seconds during active transfer/sync, 30–60 seconds when idle, refresh immediately after an action). Avoid concurrent overlapping read and write probes. Label the snapshot stale and keep last known state when CLI calls fail. Detect whether another app/service already owns `mega-cmd-server` before offering lifecycle controls. Avoid unconditional calls to every `mega-*` executable each tick; fetch detail/issues/history on demand.

**Secrets**: never put MEGA password, MFA code, session string, exported link key or any credential in shell command strings, process arguments, JSON files, logs, crash output, copy/export diagnostics or QML properties longer than strictly necessary. The documented scriptable login syntax accepts password/--auth-code arguments, which makes a naive in-Settings login flow unsafe because argv may be inspected. For the first phase, detect/use an **existing** MEGAcmd login and offer a safe external interactive sign-in instruction. A native Settings sign-in needs separate validation of a secure PTY/stdin or vendor-supported non-argv secret channel, redaction and MFA. Never call `mega-session` for status: it prints a secret session ID. Never silently invoke logout; MEGAcmd documents that it clears the local session cache and associated sync/backup/webdav setup.

**Mutations**: strict per-action allowlist and argv execution (never `bash -c` from UI content); path canonicalization, symlink/nesting checks and directory ownership validation; refuse empty, filesystem-root, unsafe and duplicate/overlapping local paths. Confirm creates/deletes/cancels/logout. Mark work as pending until the subsequent vendor-observed state change; record raw exit status and timeout but never fabricate success. Do not send privileged commands or kill another application's process.

**Packaging**: optional `megacmd`; detect installed binary family and version at runtime, give links/commands appropriate to the OS rather than forcing it into Hadalis core dependencies. Verify source/package/Nix runtime-payload inclusion only when implementation is authorized. Avoid assuming a vendor-shipped `systemd --user` service exists: MEGAcmd commonly starts its own server on command demand.

## 6. Research and validation gates BEFORE requesting implementation approval

- [ ] Resolve product meaning with the maintainer: **MEGAcmd-managed** storage (supported plan here) versus actual control of the independently running **MEGA Desktop/MEGAsync GUI** (not established by official docs). Do not promise both without a verified supported API.
- [ ] Capture `mega-*` `--help`, CLI version, real logged-in/no-session/offline outputs on the actual supported Linux distributions. Check UTF-8, spacing, numeric units, `--output-cols`/delimiter capabilities and errors.
- [ ] Verify exact MEGAcmd process/session behavior: cold start, server already running, login persistence, true logout effects, restart, offline transition, no duplicate servers.
- [ ] Test conservative coexistence with MEGA Desktop and CLI using **isolated throwaway paths/test data only**; do not allow duplicate root/ancestor/descendant sync paths.
- [ ] Define structured bridge response schema: `ok`, `error.code`, `error.message`, `cli_version`, `timestamp`, `account`, `storage`, `syncs[]`, `transfers[]`, `backups[]`, `issues[]`, with never-secret log projection. Separate `RUN_STATE` from `STATUS`.
- [ ] Confirm safe paths, duplicate guards, idempotent job visibility, action races and **logout/destructive** confirmations on synthetic fixtures before touching an account.
- [ ] Confirm lazy Settings routing and navigation/search/deep links work in standalone, overlay, focus, Abyss and Waffle, including saved custom category arrangements and historical index preservation.
- [ ] Benchmark idle shell cost with the page never opened (target: no MEGAcmd child processes or polling induced by Hadalis), visible-page reads, server-down timeout and large sync/transfer lists.
- [ ] Test backup missed-run states and sync issues distinctly from transport/parse failures. After backend restart or in offline mode, do not downgrade stale data to `Synced`.
- [ ] Run narrow parser/route tests and the canonical `bash scripts/validate-maintainer-local.sh` on the **exact eventual implementation SHA**, then perform owner-session acceptance separately. This document is not such evidence.

## 7. Implementation sequencing (not authorized yet)

**Research phase (current):** source/docs feasibility, exact version/output fixtures, backend-ownership/coexistence constraints, interaction and security contract. **No runtime changes.**

**Phase A / lowest-risk, only after approval:** one shared Settings page and opt-in read-only MEGAcmd status/account/quota/syncs/issues/transfers via a fail-closed JSON adapter. No credentials stored, no modifications to syncs, no shell boot polling.

**Phase B:** controlled pause/enable and per-transfer operations with confirmations, tagged errors and post-action state reconciliation; carefully validate create/remove sync against throwaway directories and duplicate-client protections.

**Phase C:** backups, exclusion editor, throttling/diagnostics. Native Settings login and remote file browsing are *separate, optional* subprojects gated by credential/CLI protocol research.

## 8. Findings / limits of this research snapshot

**Established from sources:** MEGAcmd supplies the needed CLI surfaces, dedicated background server, saved session/syncs, status/error fields, and independent sync/transfer/backup operations; Hadalis already has shared lazy Settings navigation and a narrow JSON-helper precedent.

**Unverified without owner runtime:** the installed MEGAcmd version/output quirks, actual desktop coexistence, login integration via secure non-argv secret input, real synchronization correctness, performance impact, package availability on the owner's distribution and visual acceptance. No CLI commands were run against a MEGA account and no code was changed during this research.
