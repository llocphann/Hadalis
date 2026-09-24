# Hadalis native backend trial cutover

This directory contains the Rust migration and its reversible runtime trial.

## Runtime policy

Rust is now wired only through `scripts/native-dispatch`.

- `INIR_NATIVE_BACKEND=python` keeps the existing Python implementation active.
- `INIR_NATIVE_BACKEND=rust` selects the Rust implementation and keeps Python
  as a fail-soft fallback unless `INIR_NATIVE_STRICT=1` is set.
- `INIR_NATIVE_BACKEND=auto` prefers available Rust binaries and falls back to
  Python.
- Existing Python helpers remain in the repository during the trial.
- The benchmark harness also writes `$XDG_STATE_HOME/inir/native-backend` and
  `native-bin-dir`. This lets helpers launched by Niri (not just
  `inir.service`) observe the same trial selection. Explicit environment
  variables still take precedence.
- Migration 049 routes already-installed clipboard text watchers through the
  selector; a watcher that was spawned before the migration remains Python
  until the next Niri session, while the direct clipboard A/B test is still
  valid immediately.
- No Rust systemd service is installed or enabled yet.
- Packaging still does not require the Rust binaries.

The trial is intentionally reversible. Run
`scripts/native-cutover-benchmark.sh --restore` to return the user service to the
Python backend.

## Native crates

- `inir-protocol`: versioned native message contracts shared by daemon-style
  crates.
- `inir-inputd`: evdev input aggregation and native input-state reporting.
- `inir-mpdd`: persistent MPD backend plus a compatibility mode matching the
  current `local_music_mpd.py` command contract.
- `inir-native`: clipboard filtering, desktop configuration writers, runtime
  diagnostics sampling, and Niri configuration/query helpers.
- `inir-theme`: Material 2025 color generation, Celebi/Score image seed
  extraction, Hadalis app/terminal palette contracts, compatibility template
  rendering, and the ii-pixel SDDM sync hook.

## Validation and benchmarking

The `Native Rust staging` workflow verifies that runtime/package files do not
bind directly to native binaries, then runs clippy with warnings denied and the
native unit-test workspace.

After updating the local `dev` checkout and installed runtime, run one command:

```bash
bash scripts/benchmark-python-vs-rust.sh
```

This command verifies the `dev` HEAD, builds release binaries, runs Rust and
selector regressions, compares Python/Rust output on read-only paths and
temporary config files, measures startup time, CPU and peak/resident memory,
and includes the canonical repository validator. It writes one text report
under `$XDG_STATE_HOME/inir/` (or `~/.local/state/inir/`). Send that file for
analysis, even if the command exits nonzero: parity failures, missing services,
and validator failures are recorded in it.

When the installed runtime matches this checkout and parity checks pass, the
command also measures the live `inir.service` once in Python and Rust mode,
then returns it to Python. It skips the live switch when the checkout or
runtime cannot be verified. Use `--read-only` to run all helper benchmarks
without restarting the service.

For a persistent Rust trial after examining the report, the lower-level
`scripts/native-cutover-benchmark.sh` still supports live activation and
`--restore` rollback.

A permanent removal of Python call sites and dependencies is still a separate
maintainer-approved step.
