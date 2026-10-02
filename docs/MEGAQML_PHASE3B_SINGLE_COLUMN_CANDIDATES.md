# MegaQML Phase 3b — synthetic single-column parser candidates

## Grounded source boundary

Pinned upstream MEGAcmd `6505327a5a7a0e94f26f611f83b024aeeb63582c`
(`src/megacmdcommonutils.cpp`) implements
`ColumnDisplayer::print` by concatenating selected
`--output-cols` values using `--col-separator`, without
escaping embedded free-text paths, names or newlines.
Upstream `src/sync_command.cpp` prints sync `ID`
through `syncBackupIdToBase64` and separate
`RUN_STATE` and `STATUS` columns; the pinned
`src/megacmdexecuter.cpp` prints transfer `TAG`
from `getTag()`. These are source observations,
not installed-account data fixtures or qualification.

## Implemented, but NOT wired into live requests

The new `native/inir-mega/src/column_fixtures.rs`
provides a **side-effect-free candidate parser** only for
four independently requested single columns:
`ID`, `RUN_STATE`, `STATUS` (sync) and
`TAG` (transfers). It intentionally refuses free-text
fields and multi-column separator-based parsing.
It requires an exact header, complete output and a final
newline. Invalid UTF-8, control characters, unknown state
values, noncanonical positive tags, duplicate IDs/tags,
oversized rows, partial output and header-only output
are denied. The limited ID character grammar is a
**hypothesis** requiring exact installed-version fixtures.

**A syntactically valid ID is not evidence of identity or privacy.**
For example, a fake marker made solely of permitted characters
can pass the candidate grammar. The parser must only be fed an
independently verified, complete single-column vendor response;
it cannot detect whether arbitrary caller-supplied text is
secret, authentic or associated with any server object.

**Do not correlate rows from independent calls by
position.** A sync-ID request and a sync-state request
can observe different snapshots. Separate parsed
columns cannot prove safe sync object identity or
authorize any operation. Future work requires real
disposable fixtures with a coherent identity/row proof,
documented error behavior and installed output variants;
those account-dependent steps are beyond the current
no-network/no-account scope.

## Local validation and immutable gates

Run `cargo test -p inir-mega column_fixtures`
on the exact commit for purely synthetic parser coverage.
All existing `inir-mega` typed operations,
`feature_gates_preview`,
`LIVE_AUTH_VENDOR_ENABLED=false` and all ten
feature denials are **unchanged**. No vendor subprocess,
account, network or runtime connection is added.
The Rust parser unit tests are not installed vendor
acceptance and should not be described as Phase 3b PASS.
Public docs must not include owner-local version text
or private diagnostic observations.
