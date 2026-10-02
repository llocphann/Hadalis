# MegaQML Phase 3b — synthetic same-response sync pair candidates

Owner-local Rust fixture results are intentionally not recorded in this
public repository; exact-source tests remain the acceptance boundary.

## Source observation and strict eligibility

Pinned MEGAcmd upstream source at
`6505327a5a7a0e94f26f611f83b024aeeb63582c`
contains `ColumnDisplayer::print` in
`src/megacmdcommonutils.cpp` which emits explicitly requested
`--output-cols` in order using the literal
`--col-separator`. It does not escape arbitrary free-text cells.
The `src/megacmdexecuter.cpp` read-only `sync` list branch
gets one vendor `getSyncs()` result and passes it to the
`SyncCommand::printSyncList` formatter. The separate
`src/sync_command.cpp` formatter supplies
`ID`, `RUN_STATE` and `STATUS` fields.
This is an upstream baseline only and does not prove exact installed
vendor behavior or atomicity across mutable fields.

## New pure Rust candidate, not an operation

`native/inir-mega/src/column_fixtures.rs` now contains
`parse_sync_pair` for **exactly two** permitted
same-response headers, `ID|RUN_STATE` and
`ID|STATUS`. The separator `|` is excluded by
the conservative ID candidate alphabet and every allowed finite enum.
All fields in a parsed pair must come from **one** complete, bounded
capture. It reuses the existing strict one-column validators for IDs
(including uniqueness) and the enums; unexpected/extra delimiters,
missing/extra headers, path-like text, malformed UTF-8, control
characters, unknown values, partial output, zero rows and output
beyond caps fail closed. Tests cover both positive and adversarial
synthetic fixtures.

This is deliberately **not** a general safe two-column text parser.
Any name, path, error or free-text field with a separator or newline
would be ambiguous. A syntactically valid-looking forged row cannot
be authenticated by any lexical parser. A one-call paired output
reduces the *independent-call row-correlation* ambiguity, but is
not proof of a truly atomic vendor snapshot, authenticated IDs,
safe row identities for mutations, or stable sync state. Neither the
single-column nor paired candidate is called from an active request.
All ten runtime cloud domains and auth vendor gates stay disabled.

## Remaining acceptance

Before even read-only sync integration:
- confirm exact installed `ID,RUN_STATE` /
  `ID,STATUS` column behavior and error delimiters
  on a separate **disposable authenticated** environment;
- prove snapshot/epoch lifecycle, row identity and handling of
  concurrently changing sync state and interrupted vendor output;
- prove parser safety for the actual installed version, rather
  than equating a help token with a usable option.

Those future account-dependent tests are **not authorized** by the
existing offline/no-account scope. Current work is source-only.
Run `cargo test -p inir-mega column_fixtures` offline
for purely synthetic tests. No additional vendor command, account
data, network access, `stable` or parallel Wull work
was affected.

## Source-only fixed argv and capture trust boundary

A further **unwired** `SyncReadProfile` constructor defines exactly
two immutable argument sets, `sync --output-cols=ID,RUN_STATE --col-separator=|`
and `sync --output-cols=ID,STATUS --col-separator=|`.
Only a future separately vetted runner could execute these;
there is no user-controlled command, column, separator or
target in the candidate interface.

`CandidateCapture` models a future bounded subprocess result.
`parse_sync_capture` rejects timeouts, output caps, absent/nonzero
exit codes and all stderr **before** parsing the complete, exact
paired table. An accepted synthetic capture does not authenticate
the binary, session, snapshot or request provenance, and a forged
but syntactically valid row remains undetectable here.
Even a harmless installed diagnostic on stderr fails closed
until separate disposable fixtures explicitly justify it.
Added Rust fake-only tests for these invariants.
No vendor call or live operation has been authorized.

