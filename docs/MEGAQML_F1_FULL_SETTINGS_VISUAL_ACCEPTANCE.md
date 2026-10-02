# MegaQML F1 — owner-local full Settings visual and pointer acceptance

**Status:** owner-manual runtime acceptance **PENDING**. This plan is **not** a
test report or evidence that any desktop click succeeded. It adds no new
synthetic subphase and does not unlock live vendor/auth/account/write features.

**Last qualified synthetic baseline before the compact-UI changes:** source
`f7bf4d6eebbcd43344503f7cbaf717a4e64e9c66`;
`docs/evidence/megaqml/phase2p-f7bf4d6eebbc-20261001T182658Z.md`:
40/40 PASS, 0 FAIL, 0 SKIP, 8/8 independent fake-only race repeats.
The five real copied-page **synthetic** F1 cases include concurrent static
and opt-in preflight timeouts and explicit recovery. The copied
`SettingsPageHost` Material button/cache/reopen lifecycle passed inside
isolated offscreen Quickshell. None of that proves actual production desktop
pointer input, complete module loading or installed MEGAcmd behavior.

## Scope and entry points

Test actual Settings presentation in the maintainer's **intended desktop
session**, not just copied-page fixtures. Do not ask the user to upload
screenshots, raw QML logs, shell paths, cloud inventory, account identifiers,
credentials or tokens as GitHub evidence. This gate checks **offline-only**
visual behavior. The production Cloud Storage service exposes
`connected=false` and `liveAuthQualified=false`; any apparent connected
or authenticated state is an immediate **FAIL**.

* Material standalone: `settings.qml`, Cloud Storage registry index **36**;
  exact launcher supports `inir settings-window --config DIR` and honors
  `QS_SETTINGS_PAGE=36 QS_SETTINGS_SECTION=overview`.
* Material embedded Settings overlay/focus: the already-running production
  shell must be on the reviewed source before its ordinary Settings
  navigation/IPC is used. Both variants use the same registered Cloud
  Storage page and `SettingsPageHost`; only test whichever presentation is
  already enabled. Do **not** change user preferences just to exercise an
  inactive presentation.
* Independent Waffle standalone: `waffleSettings.qml`, Cloud Storage page
  index **19**; launcher supports
  `inir waffle-settings-window --config DIR` and honors
  `QS_SETTINGS_PAGE=19 QS_SETTINGS_SECTION=overview`. Do not switch the
  user's active panel family to test this independent standalone page.

These standalone windows are **production source**, not a disposable fake
UI; opening them may persist ordinary Settings navigation state.
The standalone launcher may replace an already-open window of the same
kind. Run these commands only after verifying source identity and accepting
those ordinary UI effects. Do not run `inir update`, `inir restart`, kill
the normal shell, overwrite another worktree, switch branch, or change
Settings values automatically as part of this plan.

## Gate 0 — verify what the desktop will actually load

1. First obtain fresh 40/40 exact-source local qualification for the
   current compact-UI `dev` revision; the historical baseline above does not
   qualify these later visual changes. The owner must establish that the
   **running/deployed** Settings QML payload and `scripts/native-dispatch`
   match the newly qualified source. A matching
   Git HEAD alone is **not enough** when the original worktree is dirty,
   the installed config is a copy, or another checkout is running.
2. From a separate clean checkout of shared `dev` (no new branch), compare
   deployed files against the qualified commit, at minimum:
   `settings.qml`, `waffleSettings.qml`,
   `modules/settings/CloudStorageConfig.qml`,
   `modules/waffle/settings/pages/WCloudStoragePage.qml`,
   `modules/settings/SettingsPageHost.qml`,
   `modules/waffle/settings/WSettingsContent.qml`,
   `services/deferred/CloudStorageService.qml`,
   `services/deferred/CloudStorageStaticProtocol.js`,
   `services/deferred/CloudStoragePreflightProtocol.js`, and
   `scripts/native-dispatch`. All source differences mean **BLOCKED**;
   do not mark the gate PASS.
3. Confirm Niri/Wayland + Quickshell are actually available and that
   the installed `inir-mega` helper belongs to a separately controlled
   build. The F1 interaction must not depend on the presence of
   installed vendor clients. It is permissible to observe a missing
   dependency or helper-unavailable state; never launch MEGAcmd to
   artificially make this test pass. The exact identity of an installed
   Rust binary cannot be proved from a matching QML file list; if binary
   provenance is unknown, record that limitation.
4. If deployed code identity cannot be demonstrated because of a dirty
   checkout or a mismatched installed payload, mark the visual gate
   **BLOCKED** and leave the existing 40/40 synthetic evidence untouched.
   Do not reset, stash, deploy or overwrite the owner's shared Wull work.

## Gate 1 — real physical pointer / standalone Material

With the **verified** deployed config and after closing any prior
standalone Settings window, owner may manually launch the reviewed source
using `QS_SETTINGS_PAGE=36 QS_SETTINGS_SECTION=overview inir settings-window
--config DIR`. Make the clicks with the desktop pointer, not a QML
`.clicked()` signal injected by a fixture.

- The real Cloud Storage sidebar/search route opens exactly one page,
  displays its **five areas** (Overview; Files; Sync & Backup; Sharing;
  Advanced), and navigates through all **ten sections** (overview, drive,
  transfers, sync, backups, sharing, contacts, mounts, security, preferences).
  A hidden advanced section may be reached through Area + Section, not
  necessarily through a global sidebar item.
- The Overview shows the actual no-vendor static state in bounded time:
  missing dependency, installed-but-disconnected, or a safe helper error
  depending on the owner's environment. Never claim installed client
  qualification merely because an executable appears in `PATH`.
- The selected Overview/area tab has a distinct outline, clear background
  and readable icon/text contrast against inactive tabs.
- Physically click the compact **Recheck** icon button; verify no duplicate
  spin or permanent "Checking executables" state. Physically click the
  compact **Offline check** shield button once; verify a bounded
  readiness/error result. Click rapidly again while busy and verify no
  duplicate visible request or irreversible UI stall.
- Navigate away and back, then close and reopen standalone Settings.
  There must be no implicit opt-in preflight and no stale successful or
  connected badge. The supported actions remain offline only; no login
  inputs, cloud account data or file mutation controls become enabled.
- Resize the window down to its declared minimum **750×500** and restore
  it. Area + Section remains accessible; cards, long safe error copy,
  disabled-feature warning and focus/pointer targets must not clip or
  overlap. Do not modify other Settings values to force a viewport state.

## Gate 2 — independent Waffle and optional embedded Settings

With the same verified deployed source, manually open Waffle standalone
via `QS_SETTINGS_PAGE=19 QS_SETTINGS_SECTION=overview inir
waffle-settings-window --config DIR`. Repeat actual pointer navigation,
static recheck, one offline readiness click, close/reopen and responsive
visual inspection (declared minimum **700×450**). Waffle must preserve
its independent page styling and show the same **offline** security
boundary. Waffle cannot be inferred PASS from Material.

If the existing *running* Material desktop already presents Settings as
an overlay or focus view and its deployed code identity has been
verified, additionally inspect that native presentation using the
ordinary `inir settings` command and actual pointer clicks. Mark it
**NOT_APPLICABLE** if the owner does not use that presentation; do not
force a configuration change or restart to obtain another mode.

## Gate 3 — report an honest observation, not automatic success

For Material standalone, Waffle standalone, and optional embedded mode,
the maintainer records `PASS`, `FAIL`, `BLOCKED` or `NOT_APPLICABLE`
**separately**, with only fixed non-sensitive categories:
`source_mismatch`, `environment_blocked`, `load_failed`,
`navigation_failed`, `pointer_failed`, `timeout_or_spinner`,
`visual_layout_failed`, `security_boundary_failed`, or `none`.
A `PASS` requires the operator's **actual desktop observation**,
not a 40/40 synthetic report. Do not upload raw screenshot pixels or
child logs by default. If a failure needs investigation, provide
redacted, explicitly approved minimal evidence separately.

**Release decision:** Do **not** mark F1 full production visual acceptance
complete unless both standalone modes pass with verified source identity.
The optional embedded presentation is separately recorded. A completely
successful visual run still does **not** authorize real MEGAcmd vendor
execution, installed-version prompt/parser claims, authentication,
account reads, synchronization or writes. Those require independent
owner-approved disposable-client and capability qualification.

## Optional owner-local Gate 0 helper (static bytes only)

`scripts/megaqml-f1-deployed-source-identity.py` compares the **ten**
source/deployed files enumerated in Gate 0, with an exact pinned Git SHA and
clean tracked source files, without invoking MEGAcmd or reading account data.
Run it only from the reviewed clean source checkout:

```bash
python3 scripts/megaqml-f1-deployed-source-identity.py \
  --source-root "$CLEAN_CHECKOUT" \
  --deployed-config-root "$ACTUAL_DEPLOYED_CONFIG" \
  --expect-sha "$QUALIFIED_SOURCE_SHA"
```

These three variables must be established independently by the owner in a
private terminal; the helper emits only fixed categories and counts, not
paths or file content. Self-comparison with the source checkout, a source-nested deployed tree, or
source/deployed files sharing an inode (for example, hard links) yields
`deployment_not_independent` instead of a false independent Gate 0 result.
The helper also rejects any file whose descriptor or resolved in-root path
changes while it is hashed, rather than publishing a transient static match.
This guards the comparison window; it is not filesystem snapshot attestation
and does not establish that a running Quickshell loaded those bytes.
An exit-zero `static_bytes_match` confirms only the
compared bytes. It **cannot** verify the actual running process loaded that
config, establish installed Rust helper identity, replace exact-source local
qualification or count as a real mouse/visual observation. Never publish
private installed paths or interpret a static match as full Gate 0 PASS.
`scripts/test-megaqml-f1-deployed-source-identity.py` is fake-only.

## Private local 40-case requalification without public publication

The existing full `scripts/test-megaqml-phase2-local.sh` matrix now supports
an explicit second argument, `--local-only`. Run this ONLY from a separate
clean `dev` checkout on the owner's Linux desktop (not the shared Wull
working tree), after independently pinning the source SHA:

```bash
bash scripts/test-megaqml-phase2-local.sh "$QUALIFIED_CANDIDATE_SHA" --local-only
```

This mode still checks clean source and remote ancestry and runs the existing
no-vendor synthetic matrix. Its allowlisted report stays **untracked inside
that checkout**; it does not `git add`, commit or push. Keep the checkout until
the report has been reviewed privately. A zero exit is NOT a 40/40 result if
Quickshell or Qt tests were skipped: require all 40 explicit PASS rows and
8/8 race repeats at the exact printed source SHA. Do not upload a report or
publish local environment metadata by default. This matrix is still not real
desktop pointer acceptance, actual deployed/running identity or installed
MEGAcmd proof.


### Private offline classification of the generated matrix

After the `--local-only` matrix finishes in the separate clean clone,
classify its exact `SAFE_REPORT` from that run without copying its content:

```bash
python3 scripts/megaqml-f1-local-matrix-classify.py \
  --report "$SAFE_REPORT" --expect-sha "$QUALIFIED_CANDIDATE_SHA"
```

The helper requires all 40 canonical ordered PASS rows with exit 0 and the
same source SHA, one PASS aggregate, and 8/8 race evidence. It accepts only
a bounded report in that checkout's `docs/evidence/megaqml/`, rejects
external symlinks and emits fixed reason codes, never report data, paths or
environment metadata. `REPORT_CONTRACT_PASS=TRUE` checks the **report
format/content only**; the operator must also verify that the runner actually
executed successfully in the trusted clean checkout. It does not prove
the installed/running source, actual desktop behavior, MEGAcmd or account
capabilities, and it grants no new permission for Phase 3b.


### Integrated private runner qualification

The opt-in `--local-only` runner now calls the same bounded classifier
automatically **after** generating the private report. It prints
`F1_MATRIX=QUALIFIED_SYNTHETIC_REPORT` and exits zero only when the
executed required tests did not fail **and** the report satisfies exactly
40 canonical PASS rows and 8/8 race evidence. Missing Quickshell/Qt tests,
skips, or a malformed report yield `F1_MATRIX=UNQUALIFIED` and exit 21;
an executed required test failure remains a failure.

The standalone classifier invocation above remains available to re-check
an existing private report without running the tests again. This new runner
outcome qualifies the **synthetic matrix only**, never the actual deployed
or running desktop payload, Rust binary, physical pointer observations or
installed MEGAcmd behavior. All local output stays on the owner's
separate clean checkout; do not publish private logs or run vendor commands.


## Current offline evidence and optional selected-PID corroboration (2026-10-03)

The current source repair is [commit `533b1294`](https://github.com/llocphann/Hadalis/commit/533b1294ef0c47572b151631eceabe194ed20910). The separate SHA-pinned [retest receipt](../automation/results/JOB-MEGAQML-F1-RUNLAUNCH-RETEST-20261003-001.json) qualifies `JOB-MEGAQML-F1-RUNLAUNCH-RETEST-20261003-001:0/:1/:2/:3` at its exact job/source SHA `612d468e88bf99df4f214072c8648abee72650dc`: four offline actions exited 0, including the full strict local-only F1 matrix, finishing `2026-10-02T22:29:56Z`. The new code has NOT passed owner-desktop acceptance; this receipt is synthetic only.

After the owner has privately run the fresh strict full local-only matrix on a separate clean checkout and independently established the **actual installed/deployed** config root, `scripts/megaqml-f1-deployed-source-identity.py` must first produce `static_bytes_match` for all ten files. The newer `scripts/megaqml-f1-running-launch-identity.py` can then optionally corroborate an **owner-selected, already-running standalone** Quickshell PID. The owner must identify that PID themselves from their intended session: neither this script nor the deterministic worker discovers, launches, stops, restarts or reconfigures a shell. Invoke once for each relevant existing Material/Waffle standalone process, supplying `--source-root`, `--deployed-config-root`, `--expect-sha`, `--family material` or `waffle`, and `--pid`. Run the script only from the independently pinned clean checkout; never from a source/deployed alias.

The tool checks the source pin and ten-file static identity first, then samples `/proc/<selected-pid>/stat`, `status`, `cmdline` and `exe` with bounded reads; it requires the same user, a stable PID start time, an executable named `qs`/`quickshell` and the reviewed standalone `-n -p` invocation referring to the independently provided deployed QML entry. It returns only fixed classifications and never outputs machine paths, command lines or environment variables. An exit-zero `standalone_launch_path_observed` is **not** attestation that QML bytes were loaded, a view rendered, the installed Rust binary matches source, or a mouse click succeeded; `RUNNING_QML_BYTES_PROVEN`, `INSTALLED_RUST_HELPER_PROVEN` and `PHYSICAL_DESKTOP_ACCEPTED` explicitly remain `NO`. Missing/escaped deployed QML and unreadable processes are distinct fail-closed categories. The tool is optional supporting evidence, not an extra permission to change the running desktop.

Keep the owner's full matrix report, selected PID, deployed paths, observations, logs and screenshots local and private. Gate 0 still requires independent installed-helper provenance and source verification. Gate 1/2 still require actual Material and Waffle mouse/visual inspection. Do not use this tool, its fake fixtures or any output as a Phase 3b authorization or as evidence that the original MEGA remote is empty.

## Optional owner-private installed Rust helper byte comparison (2026-10-03)

The [SHA-pinned, fake-only receipt](../automation/results/JOB-MEGAQML-F1-HELPER-BYTES-20261003-001.json) qualified the new source and synthetic tests at job/source SHA `9f7883ddcceca4b63da4e6feacdd637601df1eaa`: four offline actions exited zero, including the full strict local-only matrix, between `2026-10-02T22:41:39Z` and `22:43:07Z`. This is not proof that any maintainer machine helper matches a trusted build or was selected by the running dispatcher.

After **independent owner-local** clean-current-`dev` matrix qualification and a separately controlled build of `native/inir-mega` at the reviewed source SHA, the owner can invoke `scripts/megaqml-f1-helper-byte-identity.py` with `--source-root`, `--expect-sha`, `--trusted-build-root`, `--trusted-built-helper` and `--installed-helper`. The trusted build root must be independent of the source checkout, and the installed helper must be independent of both. Do not build a reference by copying the installed binary: the tool **does not** attest the supplied reference's build origin. Do not run either helper binary or any MEGAcmd command merely to get a match. Keep the actual paths and digests local; the tool itself prints fixed categories only.

An exit-zero `binary_bytes_match_only` means only the owner-selected independent executable ELF files had identical SHA-256 bytes at comparison time. The tool checks the source pin and selected Rust workspace files for local modifications; it rejects root/inode aliases, nonexecutables, non-ELF files, size overruns and changed-file metadata. `TRUSTED_REFERENCE_BUILD_PROVEN`, `ACTUAL_DISPATCHER_SELECTION_PROVEN`, `RUNNING_HELPER_PROVEN` and `INSTALLED_VENDOR_QUALIFIED` remain **NO** even after a byte match.

Separately and privately confirm that the **actual installed `scripts/native-dispatch` used by the reviewed desktop** resolves to the independently checked helper. This depends on the owner's current runtime configuration (including the native binary directory selection); byte comparison cannot establish dispatcher selection. Treat an unknown reference-build origin or unknown selected binary as **BLOCKED**, not a pass. Neither helper comparison nor PID corroboration substitutes for the separate real desktop Material/Waffle acceptance, original Phase 3b identity gates or vendor/auth authorization.

