# Hadalis native backend staging area

This directory contains the Rust migration before cutover.

## Hard rule

Nothing under this directory is wired into the current Hadalis runtime yet.

- QML still invokes the existing Python helpers.
- Existing Python scripts remain the source of truth.
- No Rust systemd unit is installed or enabled.
- Packaging does not depend on these binaries yet.
- Do not replace a Python call site until the maintainer explicitly approves the
  final migration report.

The workspace is intentionally developed in parallel so Rust behavior can be
validated against the current implementation before any runtime switch.

Current staged crates:

- `inir-protocol`: versioned native message contracts shared by the daemon-style
  crates.
- `inir-inputd`: evdev input aggregation and native input-state reporting.
- `inir-mpdd`: MPD state/event bridge with the same record and argument
  contracts as the current helper path.
- `inir-native`: one-shot clipboard filtering, desktop configuration writers,
  runtime diagnostics sampling, and Niri configuration/query helpers.
- `inir-theme`: Material 2025 color generation, Celebi/Score image seed
  extraction, Hadalis app/terminal palette contracts, compatibility template
  rendering, and the ii-pixel SDDM sync hook.

## Validation gate

The `Native Rust staging` workflow keeps this tree dormant and runs clippy with
warnings denied plus the full native unit-test workspace. Theme parity tests pin
the Material 2025 surface contract and the Python generator's CLI/output
semantics that Hadalis relies on.

Cutover is intentionally not part of this staging work. Python remains the
runtime source of truth until the maintainer reviews the final migration report
and explicitly approves replacing the existing call sites.
