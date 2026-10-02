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
