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
bind directly to native binaries, enforces the committed Rust tree with
`cargo fmt --check`, and runs clippy plus the workspace tests with the tracked
`native/Cargo.lock` via `--locked`.

After updating the local `dev` checkout and installed runtime, run one command:

```bash
bash scripts/benchmark-python-vs-rust.sh
```

For a deeper MPD library run that also compares a full Python/Rust snapshot,
use:

```bash
bash scripts/benchmark-python-vs-rust.sh --deep
```

`--deep` is opt-in because a large MPD library can take materially longer to
scan. It runs snapshot parity in a shared temporary cache, then times Python and
Rust with separate empty temporary caches so neither implementation warms the
other and the user's real cover cache is untouched. The deep snapshot defaults
to one timing run; set `MPD_SNAPSHOT_RUNS` explicitly when more samples are
worth the extra library work. `--deep` can be combined with `--read-only`.

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
and MPD status through direct Rust, the persistent daemon, and the dispatcher
when the service is available. Deep mode additionally measures the full MPD
library snapshot where artwork discovery, cache hashing, playlists and folder
models dominate the workload.

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

## Current source-side qualification: 2026-09-24

Source qualification has been rerun through `dev`
`d454daad8b43543645903d790bb4d8c2fed8b134`; the code-side native
qualification has advanced beyond the historical desktop snapshot below:

- The native workspace has a tracked Cargo 1.95 lockfile (198 package entries),
  canonical committed rustfmt output, and a release profile using thin LTO,
  one codegen unit, and stripped symbols. Native staging is read-only again and
  requires `cargo fmt --check`, `cargo clippy --locked ... -D warnings`, and
  `cargo test --locked`.
- Native staging is green after the latest runtime work. `inir-inputd --once`
  uses a synchronous zero-thread snapshot path and streaming input discovery is
  mode-aware, so lock-only operation does not maintain physical-key state.
- Local Music now uses the persistent Rust MPD daemon when the Rust/auto backend
  is available. MPD `idle` events carry authoritative state back to QML;
  player/mixer/options changes avoid rebuilding the full queue, playlist changes
  include queue state, and database/stored-playlist changes request a rescan.
  Compatibility polling remains only as a fail-soft path.
- MPD artwork lookup now reuses one cache across persistent status events and
  across every phase of a full snapshot. Library artwork fetched from MPD is
  published back into that same lookup before playlists/current/queue are
  built, avoiding repeated filesystem misses and keeping artwork consistent
  within the snapshot. Cache-key generation no longer builds temporary string
  vectors, the exact historical SHA-256 filename contract is fixture-tested,
  and one folder scan keeps only the highest-priority cover candidate instead
  of materializing a filename map for every file.
- Deterministic fake-MPD tests now cover persistent connection/root reuse,
  lightweight player-state updates that must not request `playlistinfo`, and
  queue-bearing playlist updates. The benchmark also has an opt-in,
  cache-isolated full-snapshot lane guarded by
  `test-native-benchmark-deep-contract.sh`.
- Runtime Diagnostics keeps its lease-driven lifecycle but its Rust sampler now
  avoids temporary field vectors/sets in the hot `/proc/stat`, `/proc/net/dev`,
  task, process-stat, and process-I/O parsing paths. Fixed `/proc/meminfo`
  fields parse directly into a small struct, and the slower memory/DRM/child
  sample keeps one `SlowState` instead of cloning the same maps/state into
  parallel temporaries. The native formatter, clippy, and unit-test gates pass
  with these changes.
- The canonical repository validator is currently **RED: 184 passed, 27 failed,
  2 skipped**. The native-related stale contracts for Local Music, Diagnostics,
  Niri launcher lookup, optional MPD/MPRIS packaging, and the performance
  lifecycle are now passing. The remaining failures are repository-wide UI,
  perimeter, packaging/helper, and preview regressions rather than evidence of
  27 Rust defects.
- The Nix package workflow passes on this source state. A real Arch package
  install/update/uninstall qualification and a matched installed-runtime Niri
  live A/B are still separate gates.
- Python implementations remain intentionally present behind
  `scripts/native-dispatch`. No permanent cutover or fallback removal has been
  approved.

This source-side qualification does **not** replace a matched live desktop
measurement. The old benchmark numbers below are retained only as historical
evidence from the earlier implementation.

## Historical qualification snapshot: 2026-09-24

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
- At that historical SHA, `cargo fmt --check` failed, Cargo.lock was not
  tracked, and the local run had not established hosted native CI or an Arch
  package build. Those source-side formatting/lockfile/CI gaps have since been
  closed as described above; the Arch package/live-desktop gates remain open.

## Remaining work before making Rust the default

### 1. Prove the installed runtime and reversible live trial

- Install the current `dev` runtime through the supported update flow and
  verify all trial-critical installed files match the tested checkout. Do not
  infer this from the checkout SHA alone. The harness reports each mismatch
  separately and will not restart the service while any remain.
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

- Niri: current parity covers the listed read-only commands, including
  `detect-customizations`, on one local config. Isolated fixtures also cover
  missing defaults, reordered and repeated lines, and extra files. Add
  fixture-based Python/Rust comparisons for every write command
  (`apply-output`, `persist-output`, `persist-layout`,
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

- Repeat the historical Diagnostics CPU and MPD latency measurements on the
  current implementation. Diagnostics parsing and MPD runtime architecture have
  both changed since the old sample, so the previous 4.0%/2.3% Diagnostics and
  2.64 s MPD observations are signals only, not current measurements. When MPD
  is available, use `bash scripts/benchmark-python-vs-rust.sh --deep` at least
  once so the new library/artwork path is measured rather than inferred from
  status-only timings.
- The harness now reports average, p50, p95, min/max and standard deviation for
  repeated command workloads. Collect a fresh report that also captures the
  selector/dispatcher path and matched live shell/cgroup behavior; use
  `perf`/scheduler counters when the host permits them. Deep MPD snapshot
  timings intentionally default to one cold-cache run per backend unless
  `MPD_SNAPSHOT_RUNS` is raised.
- Lockfile, canonical formatting, locked CI, release-profile tuning and Nix
  package execution are established. Remaining distribution work is the real
  Arch install/update/uninstall path, installed-binary identity, rollback, and
  live desktop acceptance. Rust binaries are still not required by packaging.
  Do not remove Python until those gates and the maintainer's live acceptance
  pass.

### 4. Restore the canonical validator

The historical list below records the 32 failures from the old benchmark SHA.
The current source state is **184 passed, 27 failed, 2 skipped**; several stale
native-migration contracts from this list now pass. Re-run the validator on
each new HEAD and inspect its detailed log. Prefer behavioral repair and update
a contract only when its intended behavior has changed. Repository-wide
validator failures are not automatically Rust defects.

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

The Diagnostics session, Niri keybind launcher, MPD-related packaging, Local
Music, and performance-lifecycle contracts from this historical list now pass.
The remaining repository-wide failures still block a fully green validator, but
they should be repaired according to their own intended behavior rather than
attributed wholesale to the native migration. A default Rust cutover still
requires the relevant behavioral tests, reversible live A/B, and release
packaging checks above to pass.
