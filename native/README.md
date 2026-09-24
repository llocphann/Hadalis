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

Current crates:

- `inir-protocol`: versioned native message contracts.
- `inir-native`: one-shot native helpers. The first parity implementation is
  the clipboard HTML filter currently handled by `scripts/clipboard-store.py`.

Input, MPD, diagnostics, Niri configuration and theme crates are added in later
staging commits without changing existing runtime call sites.
