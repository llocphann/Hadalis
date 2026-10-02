# MegaQML Phase 3b — synthetic evidence must not unlock runtime

This source-only boundary separates **candidate parsing** from
**actual installed capability qualification**. Installed owner results
remain private and are not reproduced in this public research note.

## Independently inspectable source baseline

- MEGAcmd pinned source `6505327a5a7a0e94f26f611f83b024aeeb63582c`
  documents `sync` output column labels `ID`, `RUN_STATE`,
  `STATUS`, and has `ColumnDisplayer` printing selected columns
  with a literal, unescaped delimiter. The pinned `transfers --help`
  does **not** enumerate every output column, even though transfer
  `TAG` is used internally in its source formatter.
- The installed `sync --help` option fingerprint and upstream source
  are **not** proof that read-only `sync` output correctly returns all
  requested columns or a coherent, authenticated account snapshot.
- `native/inir-mega/src/column_fixtures.rs` is strictly synthetic
  and unused by production request dispatch.

## Cross-module regression barrier

The `feature_gates.rs` unit test
`synthetic_sync_parse_evidence_never_unlocks_any_cloud_domain`
parses both a nominal, complete three-column fake capture and a
truncated fake capture, then queries the **actual**
`offline_policy_preview` policy. In both cases it asserts all
ten read/write domain denials and each authentication, connection,
installed-version and vendor-execution denial. The fake output
never runs through MEGAcmd or any live account and cannot
authenticate real backup IDs or session lifecycle.

Existing `CloudStorageService.qml` only performs static
nonvendor dependency detection and explicit static preflight;
its existing generation/consumer cancellation tests already
exercise stale UI dependencies. Synthetic parser tests must
not be mistaken for end-to-end UI Sync or real vendor tests.

## Required subsequent qualification, not part of this change

A future separately authorized disposable authenticated environment
must independently establish executable/server identity, actual
per-command help column legends, coherent completed read-only
output, snapshot/refresh ordering, error behavior, and safe row
identity before enabling even read-only Sync. Transfer TAG column
parsing needs its own installed fixtures; keyword presence in
`transfers --help` is insufficient. Mutations require additional
explicit safety/identity validation.

Keep network, account use and all ten feature gates disabled
within the current source-only/no-account scope. The exact-source
local validation is `cargo test -p inir-mega` in offline mode.
