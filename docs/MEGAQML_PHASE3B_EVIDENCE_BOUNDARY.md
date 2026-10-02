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

## Phase 3b evidence stop gate — no synthetic promotion

The completed **source-staged** synthetic parser, cross-module policy,
refresh-state exploration and inert local child/reap exercises prove
only the proposed *candidate contracts*. Re-running or growing them
does not establish the installed package's real output or an
authenticated Sync snapshot. In particular, an exit-zero fake child
cannot attest a real MEGAcmd executable, session, epoch or row identity.

Under the existing **offline/no-account** permission boundary,
stop before launching any real `sync` / `transfers` command or
interacting with a MEGA session. No synthetic result may enable a
runtime domain. This is a qualification gate, not a reason to bypass
the ten-deny policy or route candidate Rust parsers into QML.

For a **separately authorized future** run, the minimum read-only
evidence sequence is:

1. Independently pin the intended *installed executable and server*
   provenance and verify a fresh, isolated **disposable** authenticated
   environment, explicitly approved for vendor execution. Never use
   the maintainer's normal or production account.
2. In a private, permission-restricted local workspace, run bounded,
   exact-argv, **read-only** observations after explicit Connect and
   capture the exit state, stdout, stderr, timeout/output-cap status
   and session lifetime. The existing isolated offline `--help`
   findings alone do not qualify real data commands.
3. With **pre-existing disposable test Sync rows**, verify the exact
   `ID|RUN_STATE|STATUS` header, each permitted finite value,
   row count and source-object identity. If there are no rows, or
   output differs, keep the parser unqualified; do not infer empty
   account state from a header-only table. Proving consistency while
   the state changes needs separate controlled disposable testing.
4. Reconcile a bounded result against independently observed
   disposable object identity and a coherent request/session epoch.
   Do not use row index from different calls, free-text delimiter
   splitting, or a syntactically valid ID as identity proof. Do not
   unlock Sync when either provenance or snapshot coherence fails.
5. Qualify Transfers and its TAG output independently. The help
   keyword and pinned upstream source do **not** qualify the installed
   transfer list. All mutating controls, creation, credentials,
   installation changes and account writes require **further,
   separate** authorization and tests.

Owner-only evidence must remain **local**. Never push installed
version text, raw vendor output, account identifiers, private local
paths, diagnostic observations or temporary evidence into this
public repository; publish only generic static contracts and
non-sensitive source changes. If this environment cannot be
provided, leave Phase 3b `UNQUALIFIED`, all ten domains denied,
and auth/vendor execution disabled.
