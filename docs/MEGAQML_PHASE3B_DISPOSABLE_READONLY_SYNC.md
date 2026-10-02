# MegaQML Phase 3b — approved disposable read-only Sync observation

## Exact-path pair fake-only evidence; single original-account read pending (2026-10-02)

The single authorized original-fixture exact-path `ls` / `ls -l` comparison is **not yet owner-local observed**. Dedicated-profile synthetic validation `JOB-MEGAQML-P3B-PAIR-20261002-001` passed on job/source SHA `803a70cd026a5492011efc14da32e4cf27ba88ef` (base/first parent `5052ac38a40660567a737586ecdc5fc45b9ef40e`) at `2026-10-02T15:39:34Z`: evidence `JOB-MEGAQML-P3B-PAIR-20261002-001:0` contract test and `JOB-MEGAQML-P3B-PAIR-20261002-001:1` classifier self-test both exit 0 with zero stderr, no timeout and no truncation. [Worker receipt](../automation/results/JOB-MEGAQML-P3B-PAIR-20261002-001.json). These results establish only the fake-source test outcomes, not live-vendor grammar, remote emptiness or cleanup eligibility.

The existing original private journal stores nonce/local/remote/stage **but no historical account fingerprint**. The probe performs a fresh, private `whoami` confirmation and exact root/path checks but cannot cryptographically bind the currently authenticated MEGA account to the account used for the old journal. Before any owner-local observation, the maintainer must independently establish that the dedicated account/session is the **same original account associated with that journal**, not a subsequently substituted throwaway account; if unknown/different, do not run this probe on the old journal. This one approved read is conditional on the existing dedicated-user HOME/runtime/package/server and private journal checks, its exact new CLI mode and TTY acknowledgments. If the dedicated server is absent, explicit startup acknowledgment warns about possible resuming existing Sync behavior. Never pass credentials to commands or post raw output. Do not repeat the single approved owner-local observation without separate approval.

Return only finite classifier output for review. `prefix_header_only_candidate` and `direct_header_only_candidate` are source-correlated read-only observations, **not proof that the remote is empty** and never deletion authorization. Unknown/mismatch remains blocked. Keep the private journal unchanged, no `--cleanup-only`, no new fixture, no domain-gate promotion.


## Owner recovery: protected remote nonempty and bounded ls-l inspection (2026-10-02)

Owner's prior SHA-pinned recovery inspection at `75b734f1dd8ad3817d55900bf6c264e5e961b020` returned `inspection_complete`, matched the disposable server and account, validated journal stage `sync_detached`, blank Sync listing, exactly one fixture in account root, `REMOTE_STATUS=nonempty`, empty owned local directory, and `RECOVERY_PLAN=no_action`. The nonempty remote listing is a **stop condition**, not deletion permission; private object names and vendor output have not been published. The pinned upstream `ls -l` formatter uses a FLAGS/ VERS/ SIZE/ DATE/ NAME header with one-letter node-type flags, but installed-version formatting is still unqualified.

Owner separately approved one additional private **read-only** `ls -l` on that exact journal-bound remote folder, and had approved starting only the dedicated disposable server if absent. Source-staged `scripts/megaqml-phase3b-fixture-remote-ls-classify.py` requires a 0600 prior journal, its existing lock, the verified package and private libs, exactly one matching dedicated server, an explicit TTY start acknowledgment, then separate no-echo disposable-account confirmation. It permits only a fresh whoami identity recheck, the fixed blank Sync query, an exact account-root listing, and at most **one** `ls -l` at the original remote path with independent identity checks. At most one direct isolated server launch is allowed, only if the verified server was absent; startup can resume existing account Sync behavior, so it needs a separate explicit terminal acknowledgment. All client output is capped and kept in RAM; the strict parser returns finite type/count buckets or `listing_format_unqualified`, never names, dates, paths or raw logs. A header-only observation does **not** prove deletion safety in light of the earlier nonempty result. Script and independent fake-only contract are source-staged, not yet owner-Linux tested.

**Hard stop:** no `--cleanup-only`, `rm`, `rmdir`, journal edit, new fixture, live auth or cloud-domain unlock based on this observation. Any unknown/unrecognized output or account/server change is unqualified; evaluate owner-only finite summary before deciding on further action.


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

## Owner-authorized controlled nonempty throwaway Sync fixture (source-staged)

After the separate owner-local empty-branch result on
`f5c689cea67d8e8db036b6c364274b7a78d7f69a`, the owner
**explicitly approved** creating exactly **one new, empty local
and remote Sync fixture**, only inside the already independent
`megaqml-disposable` Linux user and existing empty throwaway
MEGA account, observing it and cleaning it up. This is a
narrow, time-bounded **test mutation authorization**; it
does **not** authorize MEGA main-account use, account login,
cloud-product writes, real transfers, production Connect,
automated general provisioning or changes to any other Sync.

The dedicated script
`scripts/megaqml-phase3b-disposable-single-fixture.py` has
three explicit modes: `--self-test` (no vendor),
`--execute-fixture` (exact interactive operator consent,
bounded fixed-argv vendor calls) and `--cleanup-only`
(independent operator-confirmed recovery of only the existing
private journal fixture after interruption). It runs only
directly on the owner's installed Linux host under
`megaqml-disposable`, never in an application runtime.
Its separate fake-only companion test never calls vendor.

Owner-only ordered test acceptance:
1. Existing UID, HOME and independent runtime, vetted package
   binary/libraries and exactly one pre-running dedicated
   server must all match. Manual no-echo entry must match
   `whoami`; no caller environment credentials inherited.
2. Immediately before provisioning, an exact clean
   selected-column Sync blank-line response **and** an exact
   clean empty root listing must be observed; otherwise
   **do not create anything**. One random nonce generates
   one unique local folder and one unique remote root
   folder. An exclusive 0600 private home journal and lock
   prevent untracked/reentrant experiments.
3. Create the empty local test folder, then create and
   verify the random remote root folder; only then create
   **one** MEGAcmd Sync. Every vendor command uses a
   bounded subprocess with capped stdout/stderr entirely
   in memory. Recheck account and dedicated server before
   mutations. No test files are placed in either folder.
4. Obtain exact whole-table `ID|LOCALPATH|REMOTEPATH|
   RUN_STATE|STATUS`, separately a single-response
   `ID|RUN_STATE|STATUS`, then the original five-column
   table again. Require exactly one permitted syntactic ID,
   unchanged across all three responses, with both original
   same-response local and remote fixture paths. Finite
   run state and status may legitimately change between
   snapshots. Observed stability is **not** a transactional
   vendor epoch or production qualification.
5. Remove a discovered Sync only by the nonce-derived
   exclusive local path, only after a separate `ID|LOCALPATH`
   snapshot proves the one Sync belongs to this fixture.
   Verify subsequent Sync list is exactly one blank line.
   Only then, with identity rechecked and a successful
   exact empty `ls` of the nonce-derived remote folder,
   allow the narrowly scoped `rm -r -f` of that folder.
   Recheck the root returns its original empty form.
   Finally use local `rmdir` (not recursive delete),
   require the local test folder to be empty, and remove
   the private journal only after full safe cleanup.
6. If any proof fails, leave uncertain resources
   untouched, report only fixed booleans/reason and
   retain the owner-private journal for
   `--cleanup-only`. Do not print nonce, journal, remote
   path, account email, stdout, stderr or test Sync ID.
   Do not rerun creation while a prior journal exists.
   On every outcome **keep Phase 3b unqualified** and
   production live-auth plus all ten cloud domains disabled.

The locally observed original blank-line branch no
longer needs repeating on its own. This fixture is the
next source-staged test; its actual on-host mutation,
vendor output grammar and safe cleanup remain
**unobserved until the owner returns finite results**.
Only if the observed nonempty row meets these gates
should subsequent source-only work design independently
correlated identity and refresh epochs; no automatic
feature-gate promotion.

## One-shot installed ls-l parsing mismatch: second diagnostic requires NEW approval (2026-10-02)

Owner ran the approved one `ls -l` on exact source `d72553d36c4c6cd9beb0cd7b865b6671027d145a`. Its finite result was `listing_format_unqualified`, `NODE_KIND=unknown`, `NODE_COUNT_BUCKET=unknown`, `SERVER_START_ATTEMPTED=false`, and `REMOTE_CLEANUP_AUTHORIZED=NO`. This means the bounded selected vendor listing was returned but did not match the strict synthetic parser, NOT that the directory is empty. The previous separately observed `REMOTE_STATUS=nonempty` and pending private `sync_detached` journal remain the strongest current evidence. The previous one-time live permission has been consumed; **DO NOT rerun that exact source's live command**. The owner has now approved ONE new, bounded read-only format probe on the same original disposable fixture using the distinct mode and terminal token below; this grants no cleanup or fixture-creation permission.

Reviewed upstream pinned MEGAcmd source: normal `ls -l` invokes summary header and node rows, but the owner's private installed stdout was deliberately never retained or published. No justified way exists to distinguish installed header/date/flags/line-endings using that consumed observation. Source-only improvement preserves the original strict `classify` acceptance test, adds a PURE bounded `format_fingerprint(raw)` with only finite header/row-prefix/line-endings/non-ASCII/coarse-row-bucket labels, and expands mock-only negative tests. All such labels are diagnostic, cannot infer content safety or authorize deletion even when a header looks valid. The prior `--approved-one-server-start-and-ls` argument is DISABLED in revised source. A DIFFERENT `--approved-additional-one-ls-format-probe` option and exact `START_DISPOSABLE_FORMAT_ONLY` manual acknowledgment implement the owner's new approval for ONE extra read of the same original fixture. Under that future conditional approval retain same original journal lock, dedicated package/server/account checks, same single exact remote `ls -l` max, finite labels only, and zero deletion/creation/journal mutation; any mismatch is unqualified.

Approval is now recorded; until exact-SHA owner-local fake-only tests PASS and a new finite owner observation is returned, this is SOURCE-STAGED only. Continue no cleanup/new fixture/main MEGA account access or ten production-domain unlock; Phase 3b remains UNQUALIFIED.

## Source-correlated hyphenated path prefix / old ls evidence reinterpretation (2026-10-02)

Owner's second exact-source one-shot observation at `be36eed90407c9d89fe8b062095042f7d1b88122` returned `listing_format_unqualified`, `FORMAT_HEADER=unrecognized`, `FORMAT_ROW_PREFIXES=no_four_flag_candidate`, `FORMAT_LINE_ENDINGS=lf`, `FORMAT_NONASCII_OR_CONTROL=absent`, and `FORMAT_ROW_BUCKET=one`. The last code means TWO total nonblank lines (the fingerprint assumed one first header and then counted one remaining line); it is **not** evidence of one actual child.

Source investigation found a precise potential explanation in pinned MEGAcmd `src/megacmdexecuter.cpp` and `src/megacmdutils.cpp`: in PCRE-enabled builds, `isRegExp` compares `QuoteMeta(path-without-slashes)` to the original string, so ordinary hyphens in the journal-generated `/MEGAQML-Phase3b-Fixture-<hex>` can trigger the pattern-listing branch. For exactly one matching folder, that branch emits an EXACT `<absolute-folder>: \n` prefix BEFORE any children. `ls -l` additionally emits the FLAGS/VERS/SIZE/DATE/NAME summary header, even if the folder is empty. A prefix-only plain `ls` can falsely look nonempty to the original recovery inspector; a prefix+header-only detailed `ls -l` can falsely appear to have an unknown header plus one unknown row. This *fits* both owner observations but the vendor stdout was intentionally not retained, and the installed package's PCRE build must NOT be assumed. Prior `REMOTE_STATUS=nonempty` was a byte-shape result, **not a proven child node**. The folder may be empty OR may hold content. No cleanup until independently proved.

Source-staged follow-up modifies ONLY the guarded, dedicated owner-local read-only classifier plus mock-only tests. The old single-use `--approved-additional-one-ls-format-probe` is disabled. Distinct `--approved-journal-exact-prefix-pair-only` and `START_DISPOSABLE_PREFIX_ONLY` require the same separate owner TTY confirmation, throwaway email matched by fresh whoami, strict exact-source package/private libs, existing journal lock and exact `sync_detached` stage, root only fixture, blank Sync, owner-empty local folder and unchanged isolated dedicated server. Exactly ONE plain `ls <exact journal folder>` and ONE `ls -l <same folder>` are permitted, with account/server checks before/between/after; no raw stdout/stderr, paths or names leave process memory. Source-shape accepts ONLY both exact `<private path>: \n` + known header with zero child lines, OR the separate non-PCRE pair of blank plain output and header-only detailed output. Any other result remains `mismatch` and all outcomes have `REMOTE_CLEANUP_AUTHORIZED=NO`. Even a candidate requires independent cleanup design; do not run old `--cleanup-only`. Run fake-only tests first. No new fixture or Phase 3b promotion.

## Owner local fixture creation stopped; cleanup still pending (2026-10-02)

The owner ran the source-pinned one-fixture script on the
existing local dedicated throwaway Linux/MEGA account. The
finite owner-local summary was:

```text
REASON=cleanup_incomplete
SERVER_MATCH=true
ACCOUNT_MATCH=true
EMPTY_BASELINE=true
FIXTURE_ATTEMPTED=false
NONEMPTY_ROW=false
SAME_ID_REOBSERVED=false
SYNC_DETACHED=true
REMOTE_REMOVED=false
LOCAL_REMOVED=false
PRIVATE_RECOVERY_PENDING=true
PHASE3B=UNQUALIFIED
```

This **does not** show a Sync-creation command was attempted.
The previous fixture script marked its cleanup journal
`sync_detached` after confirming an empty Sync listing but
*before* proving the status/existence of the remote folder.
That stage is therefore insufficient to infer whether
`mkdir` succeeded, failed or later became visible.
There is no evidence qualifying a nonempty vendor row.
Do not re-run `--execute-fixture`, blindly run
`--cleanup-only`, or manually remove a local/remote
directory or the owner-private recovery journal.

The next step is **read-only recovery inspection only**,
implemented as
`scripts/megaqml-phase3b-fixture-recovery-inspect.py` and
`scripts/test-megaqml-phase3b-fixture-recovery-inspect-contract.py`.
It requires the *existing* private fixture lock and
0600 validated journal, dedicated UID/private HOME/runtime,
trusted package + the same pre-running dedicated server,
and local interactive acknowledgement
`DIAGNOSE_DISPOSABLE_FIXTURE` with no-echo expected
throwaway email validated by a fresh `whoami`.
It issues only the bounded allowlisted vendor commands
`sync --output-cols=ID,LOCALPATH --col-separator=|`,
`ls /` and `ls <exact journal remote folder>`, with
independent identity/server rechecks before and after
each observation. It checks the exact nonce-derived
local directory via `lstat` and at most one bounded
directory-emptiness check. There is **no** vendor or
local mutation, journal edit or private output publication.

Only a fixed public stage, finite classification and
**non-authorizing** recovery-plan candidate are returned:
`SYNC_STATUS=blank|one_owned|other|unknown`,
`ROOT_STATUS=blank|only_fixture|other|unknown`,
`REMOTE_STATUS=empty|nonempty|unknown` and
`LOCAL_STATUS=empty_owned|nonempty_owned|absent|other|unknown`.
`remote_cleanup_candidate` requires blank Sync,
exactly one root object matching the random journal
name, the exact remote folder readable as empty,
and an empty/absent owned local folder;
`remote_absence_candidate` means root appears blank
and remote lookup is unavailable but **is not proof of
absence and does not authorize journal cleanup**.
Any other result is `no_action`. The probe never
deletes anything in any case.

After the owner returns the *finite summary only*,
review the actual stage and independent remote listing
evidence before proposing a narrowly safe cleanup-only
fix. The current approved scope includes cleaning
**only the original throwaway fixture** once proved;
no new fixture creation while recovery is pending.
Production vendor auth and all ten cloud domains
remain disabled; Phase 3b stays UNQUALIFIED.
