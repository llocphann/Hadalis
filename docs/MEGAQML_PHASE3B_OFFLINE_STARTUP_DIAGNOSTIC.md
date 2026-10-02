# MegaQML Phase 3b — one-shot isolated server-startup diagnosis

**Status: owner Linux loader indicator and vendor-free private library layout observed; Phase 3b UNQUALIFIED. Narrow opt-in mount code staged, owner sandbox retest PENDING.**
This is an explanation-only, *not* a new server capability or general
license to run vendor commands. The owner earlier approved only
isolated/disposable version and compatibility checks, not existing
account access, authentication, writes or a host-session connection.

## Owner Linux result: isolated loader indicator (2026-10-02)

The owner published `docs/evidence/megaqml/phase3b-startup-c9227926a26c-20261002T043826Z.md` at tested source `c9227926a26cf3c22a25217cec0eca632f063756`:
- Fake-only diagnostic gate PASS and inert self-test PASS.
- Single offline bubblewrap diagnosis exit 21, `state=UNQUALIFIED`, `reason=sandbox_server_log_library_missing`, `sandbox_log_present=true`, `sandbox_client_timed_out=false`.
- No network, account, qualified server version or unlocked capabilities; report publication added only the evidence file above on top of its tested source.

The category proves that a **fresh disposable sandbox server log contained a recognized shared-library loader-error indicator**, but **does not identify the missing library, demonstrate a broken host installation, or prove the root cause**. Do not publish or request the original server log or assume the earlier IPC symptom is a separate defect.

**Source-grounded hypothesis, not confirmed host diagnosis:** pinned upstream MEGAcmd `CMakeLists.txt` configures `CMAKE_INSTALL_LIBDIR=opt/megacmd/lib` and normally sets RPATH to `/opt/megacmd/lib`; the Hadalis bubblewrap mount list permits system roots such as `/usr`, `/etc` and `/nix/store`, but it **does not mount host `/opt`**. If the installed pacman-owned MEGAcmd package actually relies on its own `/opt/megacmd/lib` libraries, the approved sandbox would hide those files. The installed package layout has **not** been verified. Source: https://github.com/meganz/MEGAcmd/blob/6505327a5a7a0e94f26f611f83b024aeeb63582c/CMakeLists.txt#L130-L150.

**Next narrow gate:** inspect only matched local pacman package metadata and existence of declared `/opt/megacmd/lib` library files with the separate **vendor-free, read-only** `scripts/megaqml-phase3b-static-library-layout.py`. It prints fixed categories only, not filenames or private paths, and does not auto-publish to public GitHub. Its fake-only self-test and contract must pass before any owner-local inspection. This is **not** a second vendor probe. If matching private libraries are corroborated, propose a strictly scoped sandbox-only read-only mount *for separate explicit maintainer approval* before any further vendor invocation; otherwise stop and reassess static loader evidence. Never automatically bind all `/opt`, relax network isolation, access existing MEGA state, or assume that a missing-library category permits retry.

## Authorized private-library sandbox retest (2026-10-02)

Owner's separate, local-only static run at exact source `b0f5ef07955876e1963d69d070a157ac3966930a` reported the vendor-free fake contract and inert self-test PASS, `STATIC_EXIT=0`, and `SAFE_CATEGORY=package_opt_libraries_present`. This is **owner-reported local evidence**, not a published GitHub acceptance report. The result supports package-owned private libraries at the expected location but does not identify the missing runtime dependency.

Owner separately approved one new isolated **offline**, **account-free**, **local-output-only** retest with a narrowly scoped read-only library mount. New `--acknowledge-isolated-offline-private-libs-test` is the sole route for this retest; the prior diagnostic flag retains its original mount behavior. Before any vendor execution the new helper requires a matched pacman package record; all declared private libraries present; root-owned and non-group/world-writable `/opt`, `/opt/megacmd`, `/opt/megacmd/lib` and regular library files; and package-listed, private-directory-only relative symlinks. Unlisted files, unusual nested directories, symlinks outside this directory, mismatched binary ownership or unsupported layouts **fail closed without vendor invocation**. The sandbox gains only three mount arguments to create its private `/opt` and `/opt/megacmd` directories and `--ro-bind /opt/megacmd/lib /opt/megacmd/lib`. It does NOT bind host `/opt`; network/PID isolation, ephemeral HOME, scrubbed environment, time/output caps and namespace teardown are unchanged. Run fake-only tests first, then exactly one sandboxed vendor invocation if all safety gates pass. No publisher is connected to the new flag; print fixed local summary only, with no raw logs or account details. Source-staged until new exact-SHA owner Linux report.

The observed result, whether a new fixed error or no log, remains Phase 3b `UNQUALIFIED`. No capability, auth or read/write domain may be enabled. Stop if the result is still unexplained; another mount or a networked experiment requires a different permission.

## Approved one-shot client-signal follow-up (2026-10-02)

The follow-up has a **separate explicit CLI flag**
`--acknowledge-isolated-offline-client-signals`. It reuses the already
authorized, strictly ownership-gated read-only `/opt/megacmd/lib` sandbox
and does NOT add mounts, expose account state, enable networking, alter
the MEGAcmd command, extend time limits, or automatically publish evidence.
The previous two diagnostic flags keep their **unchanged public JSON
summary shape**; only the new flag emits the additional local signals.

The private supervisor records the actual scriptable client exit code
as an integer only when it is in the fixed range 0–255, otherwise null,
with `client_exit_class` in
`zero | nonzero | signal_terminated | timed_out | unobserved`.
It separately reports `client_version_line` as
`recognized | not_recognized | indeterminate`: **recognized** only
means a bounded stdout line matches the anchored MEGAcmd version
format. Timeout or output truncation yields **indeterminate**.
A syntactically recognized line does not prove that a particular server
version has been independently verified. Existing bounded,
fresh-sandbox-only log classification is unchanged, and raw stdout,
stderr, version digits, log text and machine paths stay private.
The outer summary remains `UNQUALIFIED`; all ten live gates remain denied.
The outer diagnostic script returns 21 for a completed classification
regardless of the actual bounded client exit code.

The owner has separately authorized **one** local-only, no-account,
offline test at the new exact source SHA. Run independent fake-only
gates and the inner Python self-test **before** the single sandboxed
MEGAcmd call; if a gate fails, stop before launching vendor.
No automatic retry and no public diagnostic publication are authorized.
Stop and reassess once the fixed local client signals are available.

## Earlier evidence

1. `docs/evidence/megaqml/phase2p-ad79725acda0-20261002T031538Z.md`:
   prior synthetic F1/Phase 3a 40/40 and 8/8 PASS **at its exact
   older source SHA**.
2. `docs/evidence/megaqml/phase3b-7c9e01dcd3db-20261002T034719Z.md`:
   owner-approved isolated offline `mega-version -l` returned a
   nonzero exit, safely classified `sandbox_server_handshake_failed`.
   The error alone does **not** establish why the server was unavailable.
3. `docs/evidence/megaqml/phase3b-static-284001594ca4-20261002T040142Z.md`:
   owner-local **vendor-free static metadata PASS**, matching
   `mega-version` and `mega-cmd-server` to the pacman-installed
   MEGAcmd package **2.6.0**. This observation never executed
   MEGAcmd and cannot prove the running server version, runtime
   ABI compatibility, network readiness or any live cloud capability.

Do not repeat the earlier identical version call expecting a
different outcome; do not misdiagnose the IPC failure as absent
binaries, parser version syntax or a broken package.

## Narrowly justified offline diagnostic

`scripts/megaqml-phase3b-offline-startup-diagnostic.py` reuses the
existing **unchanged** offline isolation boundary and makes a **single**
explicit `mega-version -l` call, but supervises it using Python
running **inside** the disposable bubblewrap PID namespace.
The isolated supervisor reads only its own freshly created
`/home/disposable/.megaCmd/megacmdserver.log`, `.log.err` and
`.log.out` after a bounded client attempt. It reads at most 4096 bytes
from each file and uses fixed-string classification for loader,
private socket, permission and network-error **indicators**, not
proof of root cause. If no nonempty private server log exists (including when startup created
empty `.err`/`.out` redirects), the inner supervisor attempts
**fixed-category classification of only its bounded, private client
stdout/stderr**. `sandbox_log_present` reports file existence even
when only empty redirects were created. It distinguishes an apparent
client-side missing library/socket/server launch/IPC error, or an
output-cap event, from the generic absence of a server log.
Unrecognized text stays `sandbox_server_log_absent`. In particular,
`sandbox_client_server_handshake_failed` is a symptom, **not**
evidence of why an isolated server failed to launch. Raw client
stdout/stderr remain inside the sandbox and are never published.

Crucial safety properties:
- User must opt in with an exact CLI acknowledgment; no automatic
  polling, retries, login or CloudStorageService wiring.
- Nonvendor bubblewrap smoke must succeed before any vendor process.
  Bubblewrap still uses `--unshare-all --unshare-net --as-pid-1`,
  `--die-with-parent`, `--new-session`, empty tmpfs root, scrubbed
  environment and a **private fresh HOME**. No host home, socket,
  existing account or runtime directory is mounted.
- The inner Python supervisor never prints raw client stdout,
  stderr, server logs, machine paths, addresses, email or diagnostics;
  it returns only an exact JSON category and two booleans.
  The outer Python rejects unexpected fields/data and publishes
  only fixed allowlisted result tokens.
- Bounded subprocess time/size and PID-namespace teardown prevent
  accepting background vendor persistence as success. A report of
  missing/unknown logs is **not** permission to widen the sandbox.

The independent fake-only contract
`scripts/test-megaqml-phase3b-offline-startup-diagnostic.py`
exercises malformed/private outputs, fixed categories and a simulated
vendor/sandbox boundary. That and
`python3 scripts/megaqml-phase3b-offline-startup-diagnostic.py --self-test`
must pass before the actual owner test; **source existence alone
does not mean the test has passed on Linux**.

The wrapper
`scripts/megaqml-phase3b-offline-startup-owner-local.sh` requires both
`--acknowledge-isolated-offline-startup-diagnostic` and
`--publish-public-diagnostic-category`. The second flag matters:
**Hadalis is a public GitHub repository.** Only if the owner
intentionally allows a fixed diagnostic category to appear publicly
does the wrapper publish one sanitized
`docs/evidence/megaqml/phase3b-startup-*.md` file on `dev`.
No raw logs or installed package path are published. A publication
failure must not be interpreted as an accepted test.

## Stop condition / next owner gate

Run this one-shot offline diagnostic **once** after reviewing it.
If the inner log is absent, unreadable or unclassifiable, stop;
do not repeatedly launch vendor or automatically change mount,
socket, HOME, network, privileges or timeout. A genuine
networked/server-compatibility test would need a **separate explicit
owner decision** and an entirely disposable networked VM with
no current account state, no host home, no host runtime and no
access to the current MEGA server. Network access could disclose
the VM's public IP to external services even without login.

Regardless of the diagnostic category, Phase 3b is unqualified
until the installed server's observed version and version-specific
command contracts are independently checked in an approved
environment. Keep all ten live read/write feature gates denied,
`LIVE_AUTH_VENDOR_ENABLED=false`, and preserve `stable` and
parallel Wull work untouched.
