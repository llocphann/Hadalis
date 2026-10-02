# MegaQML Phase 3b — approved disposable read-only Sync observation

## Scope and permission boundary (2026-10-02)

The owner authorized a **separate disposable authenticated** read-only
probe. This does NOT authorize login automation, editing or syncing any
files, creation/deletion/pause/resume of sync jobs, Transfers controls,
changes to normal MEGA account/session, or enabling QML Cloud Storage.
Owner-only values and output must remain private.

The staged `scripts/megaqml-phase3b-disposable-readonly-sync.py`
performs exactly two vendor data commands, strictly sequentially,
**only after all host safeguards and operator confirmation succeed**:

1. `mega-exec whoami` (compare exactly one observed email to the
   throwaway identity typed via private terminal prompt).
2. `mega-exec sync --output-cols=ID,RUN_STATE,STATUS --col-separator=|`
   (read-only list with exact three finite scalar fields).

It starts NO login, creates NO sync rows, issues NO transfer action and
does NOT stop/restart/kill the existing MEGAcmd server. The process
may communicate with MEGA over the network; only an independently
pre-provisioned throwaway environment is in scope.

## Required environment before any actual read

The probe **must fail closed** unless all conditions are met:

- Non-root, existing **dedicated Linux user named exactly
  `megaqml-disposable`**; not the normal developer's UID.
  The owner must create/provision this user separately and protect its
  home directory with mode 0700. The probe NEVER does this.
- An actual login session for that Linux user, with its own
  `/run/user/<uid>` runtime directory owned by the same user,
  with mode 0700. No inherited normal-user MEGAcmd socket, home,
  login, proxy, debug override or credentials.
- A **pre-existing**, separately logged-in disposable MEGA account
  and exactly one already-running `mega-cmd-server` executable
  belonging to the dedicated Linux user. The server's resolved
  executable must be the vetted, package-owned binary; absence or
  ambiguity blocks the probe instead of auto-starting the server.
- Executable/package ownership and the root-owned private-library
  mount must satisfy the already staged conservative Arch/pacman
  metadata validators. Other packaging layouts must stop until
  independently vetted, not bypass the checks.
- A working interactive terminal; the owner types
  `READ_DISPOSABLE_ONLY` then supplies the expected disposable email
  through a no-echo prompt. Neither the confirmation nor the private
  identity is accepted in argv, environment variables or the repo.

Provisioning a disposable Sync row, if absent, is a separate
account-write operation **not included** in this read-only approval.
With no pre-existing nonempty test Sync list, report
`sync_header_only_not_qualified` or a fail-closed incompatible
response. Do not call that an empty-account proof or parser
qualification.

## Private bounded capture and result contract

The probe runs with a minimal controlled environment and
`stdin=DEVNULL` (no hidden login prompt or credential injection).
For each client command it enforces a 12-second deadline, 16-KiB
stdout cap and 4-KiB stderr cap, checks exit 0 and **rejects any
stderr**. Only the disposable client's process group may be killed
on timeout; the pre-existing throwaway server is left alone.
It confirms the same dedicated server PID/executable identity
still exists between and after observations.

The output is ONLY a finite diagnostic state and booleans:
`ISOLATED_SERVER_MATCH`, `DISPOSABLE_ACCOUNT_MATCH`,
`NONEMPTY_SYNC_SCALARS`, `REASON` and
`PHASE3B=UNQUALIFIED`. Raw vendor stdout/stderr, email, paths,
Sync IDs, installed version digits and exception text stay in process
memory and are never printed, committed or uploaded. Do not paste
private terminal setup, credentials or raw vendor output into chat.

`sync_shape_observed_unqualified` means only that this one
private, exit-zero, bounded response matched the **candidate**
syntactic table under a matched disposable account. It does NOT prove
atomic snapshot consistency, authenticated Sync object ID semantics,
version-precise behavior across installations, concurrency or an
implementation-ready read-only GUI. Treat unknown enums, duplicates,
extra columns, partial results, zero rows and any diagnostic as
failure. The candidate Rust parser remains unwired, the vendor
auth feature gate remains false and all ten cloud domains stay
read/write denied.

## Safe validation and next acceptance boundary

`scripts/test-megaqml-phase3b-disposable-readonly-contract.py`
and the probe's `--self-test` are entirely fake-only, exercising
validation and a fully mocked nominal/mismatched account path;
these do not run MEGAcmd. The real command only runs from the
dedicated Unix user after the operator's separate confirmation.

After a shape observation, further **separately controlled**
disposable fixtures and independent per-row object identity/
snapshot-epoch reconciliation are still necessary. Only then
consider a gated read-only Sync runner and its QML request contract.
No writes or Transfer TAG qualification are implied by this probe.

## Private terminal-confirmation diagnostic refinement

The first real-owner attempt stopped **before any vendor read** at its
interactive confirmation gate. The operator-confirmation path formerly
collapsed a missing/unavailable terminal, a mismatched exact opt-in
phrase, and an invalid disposable email into one public reason.
The refined probe distinguishes:

- `operator_confirmation_mismatch`: exact opt-in phrase was not entered;
- `disposable_email_format_invalid`: the entered throwaway email did not
  pass the deliberately strict, private input grammar;
- `tty_confirmation_unavailable`: the terminal or no-echo prompt could
  not be read.

Once the pre-existing, dedicated OS-owned server has already passed its
local identity gate, the diagnostic reports
`ISOLATED_SERVER_MATCH=true` even if the user declines the subsequent
prompt. This is **not** evidence that an MEGA account was checked:
`DISPOSABLE_ACCOUNT_MATCH=false` until a real, successful `whoami`.
The private email is never logged or printed. The no-echo prompt uses
the same explicit `/dev/tty` stream as the confirmation prompt.
These changes add only better diagnostics and fake-only tests; they do
not modify vendor argv, enable any cloud feature, or turn malformed
email into an account-existence probe.

## Owner-only TTY transport diagnosis after a second fail-closed stop

The owner completed the original `sudo -u` attempt and then a
`machinectl shell` one-shot attempt. Both returned the finite
`tty_confirmation_unavailable` state **before any account or
Sync data command**. The second attempt positively identified the
already-running isolated OS-owned server; the terminal transport
remains unqualified. Do not guess that credentials or the server
are faulty, relax the private-input requirement, or turn on
automatic login.

`scripts/megaqml-phase3b-tty-only-diagnostic.py` is a
**standalone, no-input, no-vendor** Linux terminal capability
observation. It does not import the MEGA adapter, read input,
print account or terminal paths, or start a process. With the
explicit `--diagnose` argument it prints only finite booleans
indicating whether this launch mode can open its controlling
`/dev/tty`, query terminal attributes there, or instead has a
terminal-backed inherited stdin and stderr. No-echo credential
input must **not** be attempted on a pipe or non-controllable
terminal, even if an email is not a password.

The owner should run this diagnostic in the **exact same
`machinectl shell` one-shot launch mode** and return only its
finite summary, never raw terminal text. The result dictates
whether to switch to a true interactive dedicated-user shell,
or to explicitly implement and unit-test a separate
privacy-preserving inherited-terminal transport. It is not
an installed vendor qualification and does not change the
live read-only probe or the ten-deny policy.

## Python text prompt and fake-token getpass observation

The dedicated `machinectl shell` /dev/tty capability check returned
all six kernel/stdio terminal booleans true and classified its
controlling terminal as a candidate. Nevertheless the read-only vendor
probe still stopped with `tty_confirmation_unavailable` and did not
run `whoami` or `sync`. The initial terminal diagnostic had not
exercised Python's text `open(..., "r+")`, its prompt write and
flush, line reading, or the `getpass` no-echo operation.

The separate `scripts/megaqml-phase3b-fake-tty-interaction.py`
offers an **explicit fake-only challenge**, independent of the
vendor/probe. In the same one-shot `machinectl shell` invocation
it asks for the *public fixed* acknowledgement `TTY_TEST_ONLY`,
then a *public fixed* no-echo `FAKE_PIN_ONLY` solely to identify
which Python interactive operation fails. Never enter an account
email, account password, recovery code or actual OTP in this test.
It prints only fixed states for text TTY open, prompt flush,
bounded fake acknowledgement read, fake no-echo read, and
`VENDOR_EXECUTED=NO`. It catches getpass fallback warnings rather
than accepting secret input echo or exposing arbitrary errors.
The new companion mock-only test covers open, write, flush,
read, EOF, mismatch and no-echo failure/success paths without
touching a real terminal.

Do not change the main disposable read-only probe or retry real
vendor reads until this no-vendor test returns conclusive stage
evidence. A text/flush/read failure is not evidence of a wrong
MEGA credential or faulty server. No runtime/auth gate is
unlocked by a terminal transport observation.

## Owner observation: raw terminal opens; Python text open fails

The owner successfully ran the separate fake-only diagnostic under
the same dedicated `machinectl shell`. Its finite outcome was
`TEXT_TTY_OPEN=false`, and all input stages were
`not_attempted`. A previous same-mode no-vendor capability
diagnostic had reported `CONTROLLING_TTY_OPEN=true` using
`os.open("/dev/tty", O_RDWR | O_NOCTTY)` with valid `termios`.
This **localizes, but does not yet prove the underlying OS cause**
of the discrepancy to the terminal-opening path. No credentials
were prompted for, and no MEGA vendor access occurred.

The fake-only interactive script now uses this previously observed
low-level open operation and `os.fdopen(..., "r+", encoding="utf-8",
buffering=1)`. It prints separate finite booleans for the
low-level open and text stream creation, then attempts only the
fixed public `TTY_TEST_ONLY` and `FAKE_PIN_ONLY` tokens.
The fake-only unit tests mock low-level open/fdopen failures,
descriptor cleanup, write/flush/read, getpass fallback failure,
and happy path. A failure never prints exceptions or typed tokens.

**Do not change the main disposable vendor probe** until the
owner confirms both `TTY_ACK_READ=passed` and
`TTY_NOECHO_READ=passed` with an exact-source Linux
`machinectl shell` fake-only run. Even then, separately update
and test the private-email transport before any real whoami/sync
observation. Phase 3b remains unqualified and all ten cloud
domains denied.

## Owner-approved direct local disposable account test

The owner clarified that the installed MEGAcmd should be tested **on
the real local Linux host**, using a **separate empty disposable MEGA
account**, rather than repeating standalone fake terminal rounds or
deploying a virtual machine. Previous `machinectl shell` commands
already executed on the local Linux host, under the separate
`megaqml-disposable` Unix account; `machinectl` itself was NOT a VM.
The local dedicated Unix user remains mandatory so an existing
personal MEGAcmd server/account cannot be accidentally reused.

The first real local TTY tests observed `os.open("/dev/tty",
O_RDWR|O_NOCTTY)` succeed while Python's duplex text
`open("/dev/tty", "r+")` failed before prompting. The read-only
probe now opens that already-observed low-level descriptor but
wraps two **separate unidirectional** Python text streams, one for
bounded confirmation input and one for flushing private prompts.
It verifies terminal attributes and converts getpass warnings to a
closed failure, never echoing or logging private account input.
The read-only `whoami` and `sync` calls retain the same
pre-existing dedicated-UID/server/package gates and finite
capture/timeouts. Mock-only contract coverage was expanded for
open, wrapped-descriptor cleanup, invalid confirmation, invalid
account formatting, no-echo fallback, identity and zero-byte Sync
stdout. A single SHA-pinned command is the owner acceptance path:
run non-vendor mocks, then the guarded local-host disposable read
immediately. If secure terminal input fails, there must be **no
vendor execution** and no further permissive fallback.

A completely empty account may legitimately produce only a Sync
header or no stdout; such data are insufficient to classify real
Sync row IDs or lifecycle. `sync_header_only_not_qualified` and
`sync_no_snapshot_unqualified` remain distinct finite outcomes
and **are not proofs of an empty account**. A later nonempty
disposable fixture must be separately authorized and observed to
consider any Phase 3b row-shape qualification. Never create
Sync jobs, upload files, turn on writes or unlock the ten cloud
domains as part of this read-only observation.

## Owner local prompt accepted; disposable email gate diagnostic refinement

The owner ran the SHA-pinned real local installed MEGAcmd read-only
probe with a separate OS user/account. The no-vendor fake-only contract
passed, the existing server matched, and the actual opt-in prompt
`READ_DISPOSABLE_ONLY` was visibly accepted. The private no-echo
email prompt was displayed, but the probe reported the broad
`disposable_email_format_invalid` reason. There was **no
`whoami` or `sync` invocation**: this result does not attest
a bad login, account identity or actual Sync output.

The probe now classifies only finite, non-sensitive format outcomes:
`disposable_email_empty` (no string returned),
`disposable_email_surrounding_whitespace` (input needs local
manual correction), `disposable_email_non_ascii`
(the current ASCII identity grammar cannot represent the
input) and `disposable_email_format_invalid` (all remaining
length/grammar failures). It does not print the received email,
its length, terminal error detail, or normalize a different
identity silently. Added fake-only tests of each class plus a
nominal plus-address case. This refinement changes **neither**
the read-only vendor argument sequence nor independent
UID/server/package guards. In a subsequent local run, if the
input passes validation, only fixed bounded `whoami` then
`sync` are allowed.

The account is owner-described as empty; `sync` returning only
a header or zero stdout remains insufficient to qualify row
shape or the Phase 3b runtime. Do not fabricate Sync fixtures
or create a Sync job under the current read-only approval.

## Owner local whoami qualified; candidate blank-line Sync shape

On the owner-provided exact-source local run, the probe reported
`ISOLATED_SERVER_MATCH=true`, `DISPOSABLE_ACCOUNT_MATCH=true`,
`NONEMPTY_SYNC_SCALARS=false` and
`REASON=sync_header_or_row_invalid`. Since this precise reason
comes after an error-free, return-code-zero fixed-argv sync
invocation and unchanged dedicated server, the owner-local
evidence **establishes a matched disposable whoami and a
completed Sync command attempt**, but neither the actual
installed-vendor empty-state output nor any nonempty row shape.
No private stdout/stderr was published.

Direct inspection of upstream `meganz/MEGAcmd` source (the
master branch as retrieved for this research, not an assertion
about the owner's installed package version) identified a narrow
explanation for the original invalid result:
- `src/sync_command.cpp`, `printSyncList()`, does **not**
  register any column headers if `syncList.size()==0`.
- `src/megacmdexecuter.cpp` constructs `ColumnDisplayer`,
  asks `printSyncList()` to populate it, and writes `cd.str()`.
- `src/megacmdcommonutils.cpp`, `ColumnDisplayer::print()`,
  with nonempty `--col-separator`, emits `std::endl` even
  when its selected field-name collection is empty; on the
  Linux host this is potentially one exact byte `b"\n"`.

References:
https://github.com/meganz/MEGAcmd/blob/master/src/sync_command.cpp
https://github.com/meganz/MEGAcmd/blob/master/src/megacmdexecuter.cpp
https://github.com/meganz/MEGAcmd/blob/master/src/megacmdcommonutils.cpp

The disposable probe now recognizes **only exact single-newline
stdout** with clean exit, empty stderr, matching `whoami`
and unchanged dedicated server as
`sync_source_blank_line_candidate_unqualified`; it remains
`PHASE3B=UNQUALIFIED` and does **not** infer an authenticated
empty Sync state or permit cloud reads in production. Zero
stdout is a different condition; an unexpected header returns
the fixed `sync_unexpected_header_unqualified` code without
publishing actual bytes. All other unknown/malformed outputs
still fail closed. Pure fake-only regression covers the source-
blank candidate, multi-newline, CRLF until observed, header-only,
unexpected untrusted header, malformed row, a mismatched account,
and the previously qualified synthetic row shape. An installed-
vendor repeat using the exact pinned source is pending.

The owner described the separate account as having no data; no
Sync must be created or uploaded to observe this branch.
Even if the candidate shape appears in the local run, further
separately authorized, controlled **nonempty** Sync evidence and
snapshot identity checks are required before Phase 3b can
qualify any real Sync row lifecycle.

## Owner-local installed-vendor blank-line branch observed (2026-10-02)

The owner ran the exact-source Phase 3b disposable read-only probe
from commit `f5c689cea67d8e8db036b6c364274b7a78d7f69a`
on the **actual local Linux host**, with the existing dedicated
`megaqml-disposable` OS user/session and independently
authenticated **throwaway MEGA account**. The fake-only
contract passed. Its public finite local summary was:

```text
REASON=sync_source_blank_line_candidate_unqualified
ISOLATED_SERVER_MATCH=true
DISPOSABLE_ACCOUNT_MATCH=true
NONEMPTY_SYNC_SCALARS=false
VENDOR_PROBE_SCOPE=WHOAMI_THEN_SYNC_READ_ONLY
RAW_PRIVATE_OUTPUT_PUBLISHED=NO
PHASE3B=UNQUALIFIED
```

These markers are the complete shareable evidence, not the
private raw vendor output. Since this code reports the
`sync_source_blank_line_candidate_unqualified` branch only
after a bounded fixed-argv `whoami` matching the locally
entered account, a completed successful fixed-argv `sync`
with empty stderr, an unchanged dedicated server and exactly
one newline on stdout, this **confirms the owner's installed
MEGAcmd returned the upstream source-consistent blank-line
shape in this separately configured test environment**.
The owner reported that the throwaway account has no data;
neither that report nor the blank line alone establishes
authenticated Sync-list emptiness in arbitrary environments.
Do not interpret `NONEMPTY_SYNC_SCALARS=false` as a parser
failure or an observed nonempty row.

**Owner-private evidence status:**
- Dedicated executable/server and local disposable account
  identity: observed matching under the probe's existing
  source-described local checks.
- Fixed selected-column read-only Sync command: ran with
  successful exit and exact source-consistent blank-line
  stdout in the owner's local dedicated account.
- Nonempty Sync `ID|RUN_STATE|STATUS` vendor row, stable
  per-ID identity across refresh, row provenance, snapshot
  coherence, lifecycle transitions and vendor error-path
  behavior: **unobserved**.
- Production live-auth gate and all ten cloud domains:
  **remain disabled**. No data, credentials, raw stdout,
  stderr, local paths, Sync IDs or vendor version were
  collected for the repository.

**Decision:** the empty-output local experiment is
complete; do not request another blank-line repeat or
misclassify this as Phase 3b qualification. The next
material empirical step requires separate explicit owner
approval and a controlled, nonempty **throwaway-only**
Sync fixture (with local/remote folders created only after
approval), followed by bounded private read-only observation
and independently correlated row identity/snapshot epochs.
The current permission is **read-only**, so no Sync
creation, login automation, file upload or mutation command
is authorized. If no such approval is given, remain at
this evidence boundary and continue only source-only
research; do not unlock any runtime read path.
