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
paths or file content. An exit-zero `static_bytes_match` confirms only the
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
