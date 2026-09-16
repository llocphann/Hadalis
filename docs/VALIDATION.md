# Maintainer validation

The canonical daily maintainer gate is local, clean-clone validation of `dev`:

```bash
bash scripts/validate-maintainer-local.sh
```

The command creates a temporary clone, records the exact tested SHA, runs the required non-Nix validation matrix, and writes one combined log. By default the log is outside the working tree at:

```text
/tmp/hadalis-maintainer-validation-YYYYMMDD-HHMMSS.log
```

The exact log path is printed at startup and in the final summary. Set `HADALIS_VALIDATION_LOG=/path/to/file.log` only when a different destination is needed.

A PASS applies only to the exact SHA printed in that log. If `dev` advances, the new HEAD is unvalidated until this command is run again.

## Validation matrix

### REQUIRED LOCAL

Daily validation is blocking for all of the following:

- clean-clone identity and exact SHA capture;
- host dependency preflight;
- tracked shell/package, Python, JSON, JavaScript, and Fish syntax;
- every tracked `test-*.py` regression;
- every tracked non-Nix `test-*.sh` regression;
- translation catalog audit and source parity;
- IPC parser coverage and generated registry freshness;
- documentation contracts;
- project-specific QML/startup guards;
- runtime payload and generated-state contracts;
- Connected Perimeter cutover, routing, output placement, fallback, registry recovery, settings, compatibility, and runtime-health contracts;
- Equalizer boundary/lifecycle and optional-backend graceful-degradation contracts;
- battery/TLP/ThinkFan helper, UI, timeout, and lifecycle contracts;
- updater/source-target identity and lifecycle contracts;
- Arch metadata/source identity and non-Nix package contracts;
- staged install/uninstall, package teardown, prefix/path relocation, and package-owned lifecycle hooks;
- a final source-tree mutation check.

The validator collects independent failures instead of stopping at the first failing gate when continuing is safe.

### OPTIONAL / ENVIRONMENT DEPENDENT

`qmlformat` parsing is optional in the normal daily command because old or missing Qt tooling must not turn a project-guard result into a false parser result. The summary always reports one of `QML parser: PASS`, `QML parser: FAIL`, or `QML parser: SKIPPED`, including the detected version when available.

For an environment that has a suitable parser, the stricter form is:

```bash
bash scripts/validate-maintainer-local.sh --strict-qml
```

Strict mode requires `qmlformat >= 6.8`; missing or older parser tooling is a failure in that mode.

### RELEASE-ONLY

These checks remain outside daily static/local-contract validation because they require a real host or publication environment:

- actual Arch package build/install in a packaging environment;
- live Niri/Quickshell desktop acceptance;
- multi-monitor and hotplug behavior;
- suspend/resume behavior;
- fractional-scaling and live focus/fullscreen acceptance;
- GitHub release publication, Wiki remote access, credentials, and hosted permissions.

They must be completed before release when relevant; a daily local PASS does not claim these acceptance checks passed.

### NIX-DEFERRED

Nix support remains in the repository, but dedicated Nix evaluation/build/module validation is temporarily deferred and non-blocking for the maintainer daily lane. `scripts/test-nix-module-contract.sh`, Nix package assertions, and `.github/workflows/nix.yml` are not evidence for or against the REQUIRED LOCAL result.

This is a validation-policy choice, not removal of Nix support and not a claim that the Nix lane is green.

### REDUNDANT / COMPATIBILITY AGGREGATES

Some standalone aggregates intentionally re-use lower-level contracts so they remain useful when run by themselves. The canonical validator still discovers the tracked test files directly, so no REQUIRED LOCAL gate depends on a GitHub Actions-only assertion set or on `make test-local` being the entry point.

### STALE / NEEDS FIX

The 2026-09-16 validation audit removed two stale orchestration hazards from the required daily path:

- the canonical daily validator no longer makes dedicated Nix validation blocking;
- assertions that previously existed only inline in GitHub Actions are represented by repository regression contracts and are exercised locally.

Future stale tests should be fixed or reclassified rather than weakening product/runtime behavior merely to obtain a green aggregate.

## CI relationship

Hosted CI is diagnostic. Non-Nix workflows should invoke the same repository validator or the same reusable contracts used by it; they should not maintain a separate hidden set of product/architecture assertions.

For CI or another already-checked-out exact commit, the validator supports:

```bash
bash scripts/validate-maintainer-local.sh --current-repo
```

That mode still validates a clean clone of the current repository HEAD rather than the mutable working tree.
