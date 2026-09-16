# BOT task board — local validation stabilization

This board turns the latest real-machine validation failures into non-overlapping work for BOT 1–5. It is intentionally role-based so the user can send the same generic continuation prompt to every bot.

Baseline evidence came from an Arch/Niri/Quickshell local validation at commit `afc8c6441dab74bdbe0284bfd5dea13f07cf17a5`. Because `dev` moves continuously, every bot must first fetch the latest HEAD and re-check whether its task is still unresolved.

## Shared completion target

The stabilization campaign is complete when all currently runnable local gates pass on a clean `dev` checkout:

```bash
make build
make test-local
fish scripts/qml-check.fish --all
```

If Nix is available, also run:

```bash
nix flake check --no-build --print-build-logs
nix build .#inir --print-build-logs
```

Do not make Nix availability on a developer machine a prerequisite for fixing unrelated gates.

---

## BOT 1 — perimeter architecture and integration semantics

Primary ownership: runtime architecture/integration, not stale test literals.

### Task

Audit the latest Connected Perimeter cutover semantics around placement-aware ownership and fallback behavior, especially:

- `modules/common/perimeter/PerimeterCutoverPolicy.qml`
- `modules/common/perimeter/PerimeterConfig.qml`
- `modules/common/perimeter/ModuleRegistry.qml`
- related runtime/presentation/reservation policy only when required

Verify that bar, dock, left sidebar, and right sidebar compatibility blockers apply only when the corresponding semantic panel is enabled **and** the relevant perimeter module/reservation is actually placed. An intentionally empty perimeter slot must not resurrect legacy chrome or block cutover incorrectly.

The local failure that triggered this review was a perimeter contract complaining that sidebar ownership was ignored after the runtime had been refactored to `leftSidebarOwned` / `rightSidebarOwned` plus placement checks. Determine from current code whether runtime behavior is correct. If runtime is correct, do **not** regress it merely to satisfy an old grep assertion; leave contract-only repair to BOT 4.

### Validation

Run the most relevant perimeter contract(s) and inspect the current policy semantics. If a runtime change is necessary, run:

```bash
bash scripts/test-perimeter-contracts.sh
fish scripts/qml-check.fish --all
```

### Collision boundary

BOT 1 owns runtime/policy semantics. BOT 4 owns stale QA assertions in `scripts/test-perimeter-contracts.sh` unless a runtime change makes a coordinated assertion update unavoidable.

---

## BOT 2 — QML/UI warning cleanup

Primary ownership: perimeter/UI/QML/UX warning cleanup without changing intended behavior.

### Task

Re-run `fish scripts/qml-check.fish --all` on the latest `dev` and reduce currently reproducible non-fatal warnings, prioritizing behavior-neutral fixes. The baseline warnings were in:

- `modules/background/widgets/clock/dateIndicator/RotatingDate.qml`
- `modules/bar/NotificationUnreadCount.qml`
- `modules/common/widgets/RoundCorner.qml`
- `modules/dashboard/DashClock.qml`
- `modules/ii/overlay/Overlay.qml`
- `modules/verticalBar/BatteryIndicator.qml`
- `modules/verticalBar/VerticalClockWidget.qml`
- `modules/waffle/lock/WaffleLockSurface.qml`
- `modules/waffle/lock/WaffleLockSurfaceSafe.qml`
- `modules/waffle/sessionScreen/WaffleSessionScreen.qml`

Typical categories were Config access that may need optional chaining and hardcoded-color warnings. Fix only warnings that are genuine under current project conventions; if a warning is a deliberate exception, improve the checker/annotation rather than distorting UI behavior.

Do not remove or downgrade Waffle. Waffle is supported and separate, not legacy.

### Validation

```bash
fish scripts/qml-check.fish --all
```

Also run focused syntax/static checks for every touched QML file where available.

### Collision boundary

Avoid editing perimeter cutover policy/contracts unless the warning originates there. BOT 1/BOT 4 own those areas.

---

## BOT 3 — localization/runtime locale integrity

Primary ownership: services/settings/integration data and translation runtime integrity.

### Task

Repair the locale structure failures reported by the local gate using the repository translation tooling as the source of truth.

Baseline state:

- most runtime locales: 6 missing keys each;
- `tr_TR`: 1633 missing keys, 151 extra keys, 13 placeholder errors, 10 protected-term warnings;
- suspected-untranslated counts are review warnings, not the structural blocker by themselves.

Work from current `en_US` and the existing localization tools. Preserve placeholders, markup, protected terms, and locale-specific content. Do not hand-wave the gate away and do not silently delete legitimate translated content just to match counts. If stale/renamed keys explain extras, migrate them deliberately.

Likely areas:

- `translations/*.json`
- `translations/l10n/*`
- `translations/tools/l10n.py`
- related translation management tooling only if the tool itself is wrong

### Validation

At minimum:

```bash
python3 translations/tools/l10n.py audit-all
python3 translations/tools/source-parity.py
python3 translations/tools/test-cleaner.py
python3 translations/tools/test-manager.py
```

Then run `bash scripts/verify-docs.sh` to confirm the i18n section is no longer the blocker, understanding BOT 5 may still be concurrently fixing docs/link drift.

### Collision boundary

BOT 3 owns locale data/tooling. BOT 5 owns documentation/link/IPC documentation drift.

---

## BOT 4 — QA/regression contracts and final convergence

Primary ownership: QA, regression tests, cleanup, and local-gate truthfulness.

### Task

Fix the stale perimeter regression assertion if it is still present on latest `dev`.

Baseline failure:

```text
FAIL: perimeter contract: sidebar compatibility policy ignores left ownership
```

The runtime was refactored to separate `leftSidebarOwned` and `rightSidebarOwned` and combine them into `sidebarOwned`, with placement-aware checks. The test previously expected an obsolete literal form such as a direct `sidebarOwned = enabledPanels.includes("iiSidebarLeft")` expression.

Update `scripts/test-perimeter-contracts.sh` so it verifies the **semantic contract** now intended by BOT 1/runtime:

- left ownership checks `iiSidebarLeft` and actual `left-sidebar` placement;
- right ownership checks `iiSidebarRight` and actual `right-sidebar` placement;
- combined sidebar ownership participates in the unsupported edge-open compatibility gate;
- intentionally unplaced sidebars do not block perimeter cutover.

Prefer robust assertions that will not fail merely because equivalent logic is split into named intermediate variables.

After the assigned fix, act as convergence QA: re-run current local gates, identify the next highest-value reproducible regression in QA/test infrastructure, and fix it if it lies within BOT 4 scope.

### Validation

```bash
bash scripts/test-perimeter-contracts.sh
make build
make test-local
fish scripts/qml-check.fish --all
```

The full suite may remain red while BOT 3/BOT 5 are still repairing i18n/docs; report which remaining failures are outside BOT 4 ownership instead of masking them.

### Collision boundary

Do not regress runtime policy to satisfy tests. BOT 1 owns runtime semantics; BOT 4 owns correctness and resilience of the regression assertions.

---

## BOT 5 — docs/build/release gate repair

Primary ownership: documentation, packaging/build gates, release-readiness contracts.

### Task A — IPC documentation drift

Repair `docs/IPC.md` if it still documents retired IPC targets with no current `IpcHandler`, including the baseline stale headings:

- `orbit`
- `workspaceStrip`
- `pill`
- `mascot`
- `mascotMood`

Do not reintroduce removed runtime targets just to satisfy docs. Code is the source of truth for this contract.

### Task B — wiki-style link verifier false positives

Repair the relative-link verification logic in `scripts/verify-docs.sh` or normalize the relevant docs so valid GitHub Wiki-style links do not fail repository validation.

Baseline examples:

- `docs/_Sidebar.md`: `[Home](Home)`, `[Install](INSTALL)`, etc.
- `docs/index.md`: `[Install](INSTALL)`, `[Setup](SETUP)`, etc.

The verifier previously treated `INSTALL` as a literal filesystem path and reported it missing even though the repository page is `docs/INSTALL.md`. Preserve validation strength for genuine broken relative links: support the intentional wiki-page convention rather than broadly disabling link checks.

### Task C — build/release gate follow-through

After A/B, run the docs and packaging-facing contracts relevant to touched files. If the only remaining `verify-docs` failure is i18n owned by BOT 3, report that precisely and do not weaken the locale gate.

### Validation

```bash
bash scripts/verify-docs.sh
bash scripts/test-packaging-contract.sh
make build
```

Run `make test-local` when useful for final integration evidence.

### Collision boundary

BOT 5 owns docs/verifier/release-facing contracts. BOT 3 owns translation data integrity. BOT 4 owns perimeter QA assertions.

---

## Repeated generic-prompt behavior

When the user sends the same continuation prompt again after a bot has completed its assignment:

1. fetch latest `dev`;
2. verify the bot's assigned area is still green;
3. inspect commits since the bot's previous HEAD;
4. if another bot caused a regression in this bot's area, fix it;
5. otherwise choose the next highest-value unresolved task inside the bot's standing role;
6. validate, race-check, commit atomically, verify the new HEAD, and continue.

Do not wait for other bots. Do not ask the user which bot should own an issue already covered by this routing table.
