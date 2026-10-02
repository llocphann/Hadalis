# MegaQML Phase 3b — synthetic refresh ordering and child-reap barrier

This design and its unit tests are **source-only**. They simulate
candidate Sync table captures using in-memory fixture bytes.
Nothing in this change opens a vendor process, authenticates a
MEGA account, or changes the QML runtime or its feature gates.

## Why this is separate from valid table syntax

Even exact `ID|RUN_STATE|STATUS` table parsing cannot tell
whether its result belongs to the latest visible consumer. Refresh
bursts, page close and reopen, deadlines and out-of-order child
exit callbacks can make old, valid-looking results stale.

The private `native/inir-mega/src/snapshot_lifecycle.rs`
module provides a purely deterministic *candidate* state machine:
- Each visible activation obtains a new monotonic generation;
  request tokens carry a monotonic serial and that generation.
- A new request always hides an older snapshot rather than
  silently presenting it as the latest state.
- At most one token is in flight. Refresh bursts coalesce
  into one pending refresh; a superseded response is discarded
  without parsing, then a new candidate may start.
- Closing the consumer hides its snapshot but retains a
  still-unreaped in-flight token. Reopening cannot start
  another candidate until the earlier child's matching
  `finish` (external **post-reap** signal) arrives.
- `expire` marks a request obsolete and hides results;
  timeout itself is **not** proof that a process exited.
- Unknown/old tokens cannot clear or replace the current
  in-flight token. Monotonic counter overflow permanently
  fails closed instead of wrapping tokens.
- Only an active, unexpired, current token with a clean
  exit and complete, strictly parsed table is considered
  `ready` in this synthetic model.

Unit tests exercise valid then truncated data, bursts and
out-of-order completions, last-consumer close/reopen, timeout
versus actual reap, false token completions and generation/
serial overflow.

**This model is not a proof of actual subprocess reaping.**
A future separately approved runner MUST ensure that `finish`
is invoked only after its exact child has been reaped and that
the executable, environment, session and capture provenance
have been independently qualified. No account data, cloud
operation, authenticated snapshot or row mutation may be
inferred from these fixtures.

`native/inir-mega/src/main.rs` only declares the otherwise
unused synthetic module. The existing actual production
`CloudStorageService.qml` detection/preflight lifecycle and
all ten denied capability domains are unmodified. Run
`cargo test -p inir-mega` offline for exact-source validation;
that does not qualify the installed vendor, real QML races
or actual cloud features.

## Expanded bounded synthetic event-sequence regression

A follow-up test explores all **32,768** five-step traces over eight
simulated events: activate, close, refresh, expire, reap with a valid
capture, reap with a truncated capture, stale-token completion, and
no-op/visibility inspection. After every event it checks active lease
consistency, a single matching in-flight token, and that a ready
snapshot exists only after a clean current completion. It checks a
stale callback cannot reveal or replace a current snapshot. Separate
focused regressions cover expiration without a queued refresh and a
reopen with no refresh request: neither may resurrect old output.

An additional test calls the **actual** offline policy after a
synthetically completed visible refresh and verifies that all ten
cloud read/write domains and authentication/read/write flags remain
blocked. The model never launches a process; only a separately
qualified runner could attest actual process reap, session identity
and capture provenance. These local tests must not be presented as
installed MEGAcmd qualification or a live QML race acceptance.

## Local non-vendor OS child/reap harness (Linux/Unix only)

The follow-up `#[cfg(unix)]` tests exercise the lifecycle model with
**real local process IDs, but entirely inert, fake-only children**.
They spawn a fixed `/bin/sh` with an empty inherited environment and
an entirely literal shell built-in `read`/`printf` program; no
`mega-*` program, account, network call or writable vendor fixture
is used. All output is synthetic `ID|RUN_STATE|STATUS` rows or
synthetic diagnostic text.

The test harness verifies three external lifecycle sequences:
1. The blocked local child cannot make a snapshot visible. After
   supplying its inert stdin trigger, the parent waits for actual OS
   process exit/reap, captures stdout/stderr/exit status and only
   then calls `SnapshotRefresh::finish` with a complete fake capture.
2. A timed-out blocked child is killed and fully reaped while the
   next candidate is still queued. Only the matching post-reap
   callback may return a new request token; the second fake child
   is spawned **after** the first child's wait completes.
3. Even a syntactically valid fake table from a child with stderr
   or a nonzero exit is rejected, without exposing a snapshot.

These are more realistic tests of the **test harness's** order of
operations, not evidence that the unwired production code supervises
or reaps a real MEGAcmd child. No real runner has been enabled.
The existing QML static/preflight race tests and all ten denied
feature gates remain unchanged.
