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

The trial is intentionally reversible. The same user entrypoint handles rollback:

```bash
bash scripts/benchmark-python-vs-rust.sh --restore
```

The rollback path verifies the selector state file, the installed selector's
reported mode, the systemd user-manager environment, and `inir.service` before
reporting success.

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

The lower-level cutover harness is an implementation detail of this wrapper;
normal qualification, deep testing, read-only runs, and rollback all use
`scripts/benchmark-python-vs-rust.sh`. A permanent removal of Python call sites
and dependencies is still a separate maintainer-approved step.

## Current source-side qualification: 2026-09-25

Behavioral source qualification is green through `dev`
`ec80ac0b8188151172a015c1d83fe6a5fc7f7366`. Hosted `Native Rust staging`
passed rustfmt, Clippy with warnings denied, workspace unit tests, and every
isolated parity fixture described below.

- The native workspace keeps a tracked Cargo 1.95 lockfile and a release profile
  with thin LTO, one codegen unit, and stripped symbols. Staging uses
  `cargo fmt --check`, `cargo clippy --locked ... -D warnings`, and
  `cargo test --locked`.
- The canonical user command is `bash scripts/benchmark-python-vs-rust.sh`.
  It builds release binaries, runs the source/regression/parity gates, records
  repeated wall-time/CPU/RSS measurements plus resident PSS/RSS/CPU windows,
  includes systemd status/journal output and the canonical validator, and writes
  one text report under `$XDG_STATE_HOME/inir/`. `--read-only`, `--deep`,
  and `--restore` stay on this same entrypoint.
- Niri parity now covers the read-only commands plus isolated write fixtures for
  `apply-output`, `persist-output`, `persist-layout`, `set`,
  `set-bind`, `remove-bind`, `sync-cursor`, and
  `sync-backdrop-overview-shadow`. The write fixture uses temporary config
  roots and mocked `niri`/`gsettings`/`systemctl`; it never edits the live
  compositor config.
- MPD parity now covers status/full snapshots, queue replacement, playlist
  mutation with stable first-seen ordering, play/pause/seek, ACK errors,
  reconnects without replaying failed mutations, persistent manager reuse, and
  a Unix daemon-RPC mutation/error/reconnect lifecycle against an isolated
  loopback MPD service. Full Unicode casefold is fixture-tested for track,
  playlist, folder, and duplicate ordering semantics.
- Clipboard filtering is exercised only through stdin and now includes plain
  text, literal HTML, NUL bytes, Firefox/Chromium fragments, image-only markup,
  entities, Unicode, invalid UTF-8, empty-after-sanitize, and large plain/HTML
  payloads. Input streaming has deterministic synthetic press/release,
  multi-device aggregation, and hot-unplug release coverage.
- Diagnostics parity uses isolated target/child processes and checks stable
  values and units including PID, children, RSS/PSS, uptime and CPU tolerance,
  then verifies both implementations emit `shell-process-gone` and exit with
  the expected lifecycle code after the target disappears.
- Theme parity uses a synthetic PNG image and compares Python/Rust dark and light
  colors, palette/app palette, terminal JSON, metadata, SCSS, and rendered
  templates. Python is also run under multiple `PYTHONHASHSEED` values so
  template aliases cannot depend on hash iteration order. Material snake-case
  aliases have deterministic precedence, and desktop icon configuration parity
  runs in temporary homes. The theme fixture explicitly suppresses the SDDM
  post-hook, so an installed SDDM theme is not modified during qualification.
- Runtime consumers for Niri settings/writes, input, Local Music/lyrics,
  clipboard startup/history, theme switching, and icon synchronization enter
  through `scripts/native-dispatch`. Bootstrap installer paths may still use
  Python before Rust binaries are available; Python remains the supported
  fallback during the trial.
- Rollback verification now requires `native-backend=python`, an installed
  selector reporting `mode=python`, an active `inir.service`, and a clean
  user-manager environment with no stale native bin/strict variables.
- The canonical repository validator on this source state is **RED: 183 passed,
  28 failed, 2 skipped**. Its 28 failures are repository-wide UI, Connected
  Perimeter, preview, helper and QML/startup contracts; the Native Rust staging
  job is green and those validator failures are tracked separately below.
- The latest relevant hosted Nix package workflow passed after the theme
  generator changes. A real Arch package install/update/uninstall qualification
  and a matched installed-runtime Niri live A/B are still separate gates.
- Python implementations remain intentionally present behind
  `scripts/native-dispatch`. No permanent cutover or fallback removal has been
  approved.

Hosted source qualification does **not** prove that the user's installed
Quickshell/Niri runtime matches this checkout. The hosted runner cannot inspect
that desktop or perform the live service A/B. The latest local evidence remains
the read-only/deep reports below; until a fresh local run proves runtime identity,
the live Rust cutover remains **HOLD**.

### Latest read-only local recheck: 2026-09-24

At `dev` `159565b07efc443271c185e48fd065031e384d6e`, the one-command
benchmark ran with `BENCH_RUNS=1`, `SAMPLE_SECONDS=1`, and `--read-only`.
The native release build, unit tests, rustfmt, clippy, selector guards, and
isolated Niri customization fixtures passed. Python/Rust parity passed for
the exercised clipboard, read-only Niri, desktop config, theme, input,
diagnostics, and MPD status/daemon paths. A single timing sample per case is
not enough for a stable speedup estimate or a whole-shell claim. The full
repository validator remained **RED: 184 passed, 27 failed, 2 skipped**;
the failures are listed in the generated report.

No live Rust trial was attempted. The installed runtime still differs from
the tested checkout in `scripts/native-dispatch`,
`scripts/colors/switchwall.sh`, `services/NiriService.qml`, and
`services/LocalMusic.qml`. The active `inir.service` stayed on Python.

At `9af858ccdded88d894f016b54108ddbc5f4e2eb0`, the opt-in, read-only
MPD deep benchmark also passed stable full-snapshot parity on a local library
of 2,893 tracks and 220 folders. A Rust folder-order mismatch found by the
first deep run was repaired before the passing run. With one cold-cache sample,
Python took 19.35 s and Rust took 0.73 s; peak process RSS was 67,288 KiB and
76,916 KiB, respectively. This is a single library workload, not a steady-state
or whole-shell performance claim. The passing detailed report is
`native-cutover-20260924-230950.txt` in the local iNiR state directory.

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
- Selector behavior tests cover missing or failing Rust binaries, strict vs
  fail-soft selection, and environment vs state-file precedence. Still test
  restart failure and interrupted-trial rollback in a matched live runtime.
  Keep the Python fallback while qualifying Rust.
- In a real Niri session, verify the migrated clipboard watcher after session
  restart, keyboard lock and OSK key events, Diagnostics QML lease lifecycle,
  theme/icon updates, Niri settings/keybind views, and MPD UI controls. Include
  hotplug, suspend/resume, lock/unlock, and multi-output behavior when relevant.

### 2. Keep source parity gates green; finish live-only acceptance

The source-side gaps that previously blocked the listed ports are now covered
by hosted fixtures. Remaining work is intentionally environment-dependent:

- Niri: keep the temporary read/write fixtures green, then exercise the same
  settings/keybind/output operations in the matched live Niri session, including
  multi-output and rollback behavior.
- MPD: keep isolated compatibility and daemon-RPC mutation/reconnect tests green.
  On the real library, rerun status and `--deep` snapshot parity and exercise
  queue/playback/seek controls through Local Music while the persistent daemon is
  active.
- Theme/desktop: keep synthetic image/template/terminal/icon parity green. In the
  matched desktop, verify actual GTK/KDE/terminal/browser/editor consumers and
  the installed ii-pixel SDDM update path; hosted fixtures deliberately do not
  touch `/usr/share/sddm`.
- Clipboard/input: keep the stdin corpus and synthetic event-state tests green.
  A real Niri session must still verify the migrated `wl-paste` watcher after
  session restart plus physical keyboard hotplug, lock-state and OSK events.
- Diagnostics: keep isolated value/lifecycle parity green, then verify the QML
  lease start/stop path and visible Diagnostics values against the live shell.
- Keep Python fallback behavior exercised until the matched live A/B, package
  qualification, and maintainer acceptance all pass.

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

At `ec80ac0b8188151172a015c1d83fe6a5fc7f7366`, the canonical validator is
**183 passed, 28 failed, 2 skipped**. Native Rust staging is green on the same
source state, so these failures must not be counted as 28 Rust migration defects.
Repair them according to their own UI/runtime contracts and rerun the validator
after concurrent UI work lands.

Current Python/QML contract failures (18):

```text
scripts/test-bar-media-popup-layout-contract.py
scripts/test-bar-media-width-contract.py
scripts/test-calendar-weather-composition-contract.py
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
scripts/test-shell-surface-contracts.py
scripts/test-styled-popup-content-contract.py
scripts/test-surface-motion-contract.py
scripts/test-thinkfan-system-monitor-contract.py
scripts/test-zettelkasten-service-contract.py
```

QML/startup project guards contribute one additional failed check.

Current shell contract failures (9):

```text
scripts/test-critical-panel-isolation.sh
scripts/test-equalizer-service-contract.sh
scripts/test-local-required-contracts.sh
scripts/test-perimeter-contracts.sh
scripts/test-perimeter-route-contracts.sh
scripts/test-perimeter-source-contracts.sh
scripts/test-reviewed-replacement-manifests.sh
scripts/test-window-preview-cache-behavior.sh
scripts/test-window-preview-lifecycle.sh
```

The validator also skips the QML parser when a suitable `qmlformat` is
unavailable and defers its Nix check; hosted Nix qualification is tracked
separately. A default Rust cutover still requires the matched-runtime live A/B,
fresh multi-sample local report, release/package qualification and maintainer
acceptance even if this repository-wide validator becomes green.
