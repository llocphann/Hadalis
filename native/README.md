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

The timed cases include every ported read-only Niri command, clipboard
filtering, desktop icon configuration in temporary homes, color-only and full
theme generation, input probes and resident daemons, diagnostics sampling,
and MPD status when the service is available.

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

## Qualification snapshot: 2026-09-24

This is evidence from one Arch/Niri desktop at `dev`
`148f01e17f1f7db4ca62fc979bea893c8c22ed22`, not a whole-shell or release
qualification. The one-command report was produced with the default five runs
per startup case; it is under the local state directory named above.

- Native release build, 35 workspace unit tests, clippy with warnings denied,
  selector/source guards, and every read-only parity case in the benchmark
  passed. MPD was available, so its status-only comparison also ran.
- Selected mean wall times: Niri `get-binds` Python 88.2 ms / Rust 11.0 ms;
  full color-seed theme Python 210.9 ms / Rust 4.9 ms; MPD status Python
  5.90 s / Rust 2.64 s. The input daemon's sampled resident RSS was about
  26.1 MiB for Python / 3.0 MiB for Rust. These measurements do not establish
  whole-shell improvement.
- Live shell A/B was **HOLD**. The installed runtime differed from the tested
  checkout in `scripts/native-dispatch`, `services/IconThemeService.qml`, and
  `services/deferred/NiriKeybinds.qml`; the harness reported the first mismatch
  and did not restart `inir.service`. The active backend remained Python.
- The canonical local validator was **RED: 177 passed, 32 failed, 2 skipped**
  on that exact SHA. Its 32 names are recorded below. The QML parser pass was
  skipped because the available `qmlformat` was 1.0, below the required 6.8;
  dedicated Nix validation remained deferred.
- `cargo fmt --manifest-path native/Cargo.toml --all -- --check` failed on the
  current native tree. The staging workflow formats its runner copy before
  clippy/tests, so those passes are not a formatting pass on the committed tree.
  `native/Cargo.lock` is currently untracked. Neither a GitHub CI result nor
  an Arch package build was established by this local run.

## Remaining work before making Rust the default

### 1. Prove the installed runtime and reversible live trial

- Install the current `dev` runtime through the supported update flow and
  verify all trial-critical installed files match the tested checkout. Do not
  infer this from the checkout SHA alone. Make the harness report **every**
  installed-file mismatch instead of stopping at the first one.
- Rerun `bash scripts/benchmark-python-vs-rust.sh`. Require parity to pass,
  zero activation blockers, both Python and Rust `inir.service` samples, and
  a successful return to Python with service and selector state verified.
  Compare shell startup, cgroup memory, shell RSS/PSS, CPU, processes, and
  journal errors under the same session/workload. No live A/B was captured
  in the snapshot above.
- Exercise fallback and rollback behavior dynamically: missing or failing Rust
  binary, strict vs fail-soft selection, environment vs state-file precedence,
  restart failure, and interrupted trial. The present selector contract test
  mostly checks source tokens; replace or supplement those checks with
  behavior tests. Keep the Python fallback while qualifying Rust.
- In a real Niri session, verify the migrated clipboard watcher after session
  restart, keyboard lock and OSK key events, Diagnostics QML lease lifecycle,
  theme/icon updates, Niri settings/keybind views, and MPD UI controls. Include
  hotplug, suspend/resume, lock/unlock, and multi-output behavior when relevant.

### 2. Close parity and regression coverage gaps

- Niri: current parity covers only the listed read-only commands on one local
  config. Add fixture-based Python/Rust comparisons for `detect-customizations`
  and every write command (`apply-output`, `persist-output`, `persist-layout`,
  `set`, `set-bind`, `remove-bind`, `sync-cursor`, and
  `sync-backdrop-overview-shadow`). Mock or isolate compositor actions; never
  benchmark writes against the live Niri config.
- MPD: the benchmark compares `status` only. Test queue, playback, seek,
  errors, reconnects, and persistent-daemon message behavior against a fake
  or isolated MPD service before qualifying the port.
- Theme and desktop: the benchmark uses a color seed and temporary INI homes.
  Add image-seed/Celebi, template, terminal, SDDM, and icon-theme fixture
  parity, then verify actual desktop consumers in a reversible live trial.
- Clipboard and input: extend the single benchmark HTML fixture to a corpus
  with malformed, Unicode, plain-text, and large payloads. Compare real
  watcher behavior and input event streams; the current input probe only
  compares one lock-state snapshot while daemon checks sample resident cost.
- Diagnostics: current gate compares JSON field paths, not live values or
  timing semantics. Check stable fields, units, counters, error cases, and
  lease start/stop behavior with tolerances for changing processes.

### 3. Qualify performance and distribution

- Investigate the sampled Diagnostics CPU signal: Rust used 4.0% versus
  Python 2.3% in one short window, despite lower RSS. Repeat on matched idle
  and loaded windows before treating this as a confirmed regression or win.
  MPD Rust status still averaged 2.64 s; profile the remaining latency.
- Record individual samples or at least median, range, and variance for
  repeated fixed workloads. The present report gives means and peak RSS for
  short-lived commands, plus short resident windows; it has no statistical
  confidence or whole-shell result yet. `perf` counters were unavailable on
  the measured host.
- Before release packaging, decide whether to track `native/Cargo.lock` and
  use locked builds, commit canonical Rust formatting and change the workflow
  back to `cargo fmt --check`, and verify Arch install/update/uninstall plus
  binary identity and rollback. Rust binaries are currently not required by
  packaging. Run the deferred Nix check on a suitable host, then establish
  runner CI and live desktop acceptance separately. Do not remove Python until
  these gates and the maintainer's live acceptance pass.

### 4. Restore the canonical validator

The following 32 checks failed on the snapshot SHA. Re-run the validator on
each new HEAD and inspect its detailed log; some failures may be stale
source-token assertions while others may reflect real behavior. Prefer
behavioral repair and update a contract only when its intended behavior has
changed. These are repository-wide failures, not 32 proven Rust defects.

Python regressions (19):

```text
scripts/test-bar-media-popup-layout-contract.py
scripts/test-calendar-weather-composition-contract.py
scripts/test-code-workflow-diagnostics-contract.py
scripts/test-connected-route-lifecycle.py
scripts/test-dashboard-freeform-contract.py
scripts/test-dashboard-search-system-refinement-contract.py
scripts/test-iris-production-surface-contract.py
scripts/test-material-only-global-style-contract.py
scripts/test-notification-center-card-layout-contract.py
scripts/test-notification-center-contract.py
scripts/test-osd-connected-surface-contract.py
scripts/test-overview-hover-contract.py
scripts/test-p0-settings-navigation-contract.py
scripts/test-runtime-diagnostics-session-contract.py
scripts/test-shell-surface-contracts.py
scripts/test-styled-popup-content-contract.py
scripts/test-surface-motion-contract.py
scripts/test-thinkfan-system-monitor-contract.py
scripts/test-zettelkasten-service-contract.py
```

QML/startup project guards (1).

Shell regressions (12):

```text
scripts/test-critical-panel-isolation.sh
scripts/test-equalizer-service-contract.sh
scripts/test-local-required-contracts.sh
scripts/test-niri-keybind-launcher-contract.sh
scripts/test-optional-audio-deps-contract.sh
scripts/test-performance-lifecycle.sh
scripts/test-perimeter-contracts.sh
scripts/test-perimeter-route-contracts.sh
scripts/test-perimeter-source-contracts.sh
scripts/test-reviewed-replacement-manifests.sh
scripts/test-window-preview-cache-behavior.sh
scripts/test-window-preview-lifecycle.sh
```

The Diagnostics session, Niri keybind launcher, MPD-related packaging, and
performance lifecycle checks deserve early review alongside the native trial;
the remaining UI/perimeter failures still block a repository-wide green
validator. A default Rust cutover requires the relevant behavioral tests,
reversible live A/B, and release packaging checks above to pass.
