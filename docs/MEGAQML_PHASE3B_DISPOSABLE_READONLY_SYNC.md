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
