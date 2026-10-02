# MegaQML Phase 3b — installed command-help option fingerprint

**Source-staged; exact-source owner Linux test pending.**
Earlier owner's installed-version and offline command catalog output
stays private and is not embedded in this public source.

## Narrow documented upstream basis

At pinned MEGAcmd `6505327a5a7a0e94f26f611f83b024aeeb63582c`,
`src/megacmd.cpp` handles `--help` (lines 3607–3612) by printing
`getHelpStr` and returning **before executing normal commands**.
It recommends per-command `command --help` (line 3792).
Command docs list `df -h`, `sync --output-cols`,
`sync --col-separator`, `sync --show-handles`,
`transfers --output-cols`, `transfers --col-separator`
and `transfers --summary`.
Those upstream source statements are hypotheses to verify against the
actual locally installed build; they are not vendor capability proof.

## Exactly scoped next test

`scripts/megaqml-phase3b-offline-command-help.py` has one new
explicit `--acknowledge-disposable-offline-command-help` flag.
It reuses the existing vendor-package ownership check for
`mega-exec`, the root-owned/symlink-safe private library metadata
gate, the same narrowly scoped read-only `/opt/megacmd/lib` mount
and strict fresh networkless/PID/tmpfs sandbox, private HOME,
scrubbed environment and no real account/session.
Run the fake-only contract and inert inner self-test first.
The supervisor runs ONLY `mega-exec df --help`, then
`mega-exec sync --help`, then
`mega-exec transfers --help` in one disposable namespace,
with a **shared 8.5-second** deadline and 12 KiB
combined-output cap for each subprocess, plus the preexisting
outer sandbox bound. It does NOT execute those data commands.

Only fixed category and limited usage/option presence Booleans
are returned. Raw help output, version numbers, emails,
filesystem paths and private logs stay inside the namespace.
On errors, stop; do not silently retry or widen network/mounts.
No publisher is wired to the new script.

A successful option fingerprint does NOT validate the semantics,
valid `--output-cols` column names, argument/filename roundtrip
safety, logged-in status, server identity or read/write capability.
The existing ten cloud feature gates remain denied and
`LIVE_AUTH_VENDOR_ENABLED=false`.
Leave `stable` and concurrent Wull untouched.
