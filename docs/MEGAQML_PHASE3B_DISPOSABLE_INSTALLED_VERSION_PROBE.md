# MegaQML Phase 3b — owner-approved isolated installed-version probe

**Status: source STAGED; owner-local isolation/runtime evidence PENDING.**
Owner approved **preparing an isolated installed-version and compatibility
procedure without using the current account**. That consent does not
authorize login, current-account reads, mutations, sharing, file scanning,
sync creation or non-sandboxed vendor commands.

## First owner-local result and bounded follow-up

The first owner-approved `dev` run published
`docs/evidence/megaqml/phase3b-c1ab9cdbbb5a-20261002T033428Z.md`
at exact source `c1ab9cdbbb5a23f8dd83c0b8926f2110ad6d1948`:
fake-only safety contract **PASS**, nonvendor self-test **PASS**,
but the sandboxed `mega-version -l` returned a **nonzero exit (21)**.
Its sanitized result was `UNQUALIFIED`, `vendor_version=null`
and `vendor_exit_nonzero`. Neither startup, installation compatibility
nor a version was established. This **does not** authorize a direct
host command, internet access, a real account, or weakening isolation.

The next source revision retains exactly the same offline sandbox and
vendor command. It adds a bounded **fixed-category classifier** for
common loader, private socket directory, vendor-server resolution,
IPC readiness and permission failures; **unknown errors stay
unclassified**. Only a fixed reason code is published; even a
vendor-printed version line with nonzero exit remains UNQUALIFIED,
with `vendor_version=null`. The strict parser now accepts the
pinned upstream MEGAcmd source's four-part output shape
`MEGAcmd version: major.minor.micro.build: code N`, in addition to
shorter already tested shapes, without accepting SDK/latest-online
version lines. This format correction **does not explain** the
original nonzero exit; the next local run is needed to classify it.
Do not upload stdout/stderr, shell traces, crash dumps or local
paths to GitHub. If the new classifier still returns unknown, stop
at the fixed boundary rather than repeatedly changing sandbox
permissions or starting the host vendor.

## Second owner result: isolated socket handshake still unqualified

The second, explicitly approved offline sandbox run was published as
`docs/evidence/megaqml/phase3b-7c9e01dcd3db-20261002T034719Z.md`
at exact source `7c9e01dcd3db964a837b12755b088dd2594c9b6d`.
The independent fake-only contract and self-test **PASS**, the
nonvendor smoke sandbox completed, but `mega-version -l` exited
nonzero. Only `sandbox_server_handshake_failed` was safely
classified; `vendor_version=null`, Phase 3b remains **UNQUALIFIED**.
This fixed error covers an IPC timeout/connect failure, not the root
cause of failed startup. The upstream POSIX MEGAcmd client can
`fork()`, `setsid()` and `execvp("mega-cmd-server", ...)` when it
cannot find a Unix socket. Its Linux socket path normally follows
`HOME/.megaCmd`, and the version command may attempt a remote
latest-release check. The permitted bubblewrap smoke only proves a
simple nonvendor binary runs in the sandbox; it does not prove that a
networkless, ephemeral MEGAcmd server can fully initialize. Do not
attribute the failure to the parser, loosen the network namespace,
bind the current account's runtime socket, add login or keep
repeating the same vendor command.

### Vendor-free installed package metadata triage (next safe step)

`scripts/megaqml-phase3b-static-package.py` does **not** run
`mega-version`, start MEGAcmd, invoke a package manager, inspect
`$HOME`, connect to a socket, or access the network. It verifies
that the detected `mega-version` and `mega-cmd-server` resolve to
the same supported system binary directory and checks **local
package metadata only**: pacman's `/var/lib/pacman/local` package
description/files, dpkg's installed status plus package file list,
or a matching Nix store derivation label. It never publishes the
installed file paths, arbitrary package names, package-manager raw
output or the owner's environment. It emits only a strictly parsed
numeric **package** version if both executables can be attributed
to the same package; otherwise `UNVERIFIED`.

Both outcomes explicitly declare `vendor_executed=false`,
`network_used=false`, `account_used=false`,
`server_version_qualified=false` and
`live_capabilities_unlocked=false`. The independent
`scripts/test-megaqml-phase3b-static-package.py` uses fake Arch,
Debian and Nix metadata to test path ownership, normalization,
redaction and inability to launch a vendor subprocess.
The one-command `scripts/megaqml-phase3b-static-owner-local.sh`
accepts only `--acknowledge-vendor-free-static-triage`, checks
clean temporary `dev` ancestry, validates the strict safe result
and publishes only that summary as
`docs/evidence/megaqml/phase3b-static-*.md`. The script has
**not** yet been qualified on the owner's local package database.

A version observed here proves only static package metadata, **not**
that a compatible MEGA server can start with networking disabled,
that an already running server has the same version, or that any
cloud read is safe. If the static triage is unverified or the
prior handshake remains blocked, stop and choose a new isolated
diagnostic design with explicit consent rather than switching to
a real account or relaxing containment.

## Why a strict sandbox is necessary

Normal MEGAcmd scriptable commands, even `mega-version -l`, may launch
`mega-cmd-server` and may contact a vendor service. Using a new HOME
alone is not an adequate containment claim. The real probe must not
see the owner's HOME, `$HOME/.megaCmd`, XDG runtime sockets, current
session bus, `/run`, `/tmp` or live MEGA Desktop control channels.
It must have no network access or inherited proxy/secret overrides.

`scripts/megaqml-manual-disposable-version-probe.py` requires:
- a deliberately supplied `--acknowledge-disposable-offline-probe`;
- non-root Linux with the installed `mega-version`,
  `mega-cmd-server` and `bwrap` executables in accepted read-only
  system roots (`/usr` or `/nix/store`), with matched vendor bin dirs;
- a successful **nonvendor smoke sandbox** using `true`, before any
  vendor execution;
- bubblewrap `--unshare-all --unshare-net --as-pid-1`
  `--die-with-parent --new-session`, an empty tmpfs root and
  **only** explicitly read-only system binaries/libraries,
  isolated private HOME/XDG and /run, controlled PATH, and a
  scrubbed environment. No host home or runtime/socket bind;
- subprocess stdin closed, bounded wall time and *combined*
  stdout/stderr cap; timed-out sandbox process group is terminated;
  as-PID-1 also prevents an isolated auto-started vendor server
  persisting once the version client exits.

The only vendor command allowed by this script is
`mega-version -l`, **inside the sandbox**. No account, login or
vendor data action is included. The version source is the isolated
vendor's printed local version, not a proof that a separate
already-running host server has the same version.

A failing/missing sandbox, unsupported host binary layout,
unrecognized vendor output, timeout, or output-cap exits as BLOCKED
or UNQUALIFIED with a fixed reason. Never fall back to a direct
host `mega-version` invocation. Do not workaround an unavailable
bubblewrap with inherited HOME or alternate live credentials.

## Evidence, privacy and acceptance

`python3 scripts/test-megaqml-phase3b-probe-contract.py` and
`python3 scripts/megaqml-manual-disposable-version-probe.py --self-test`
perform **no vendor invocation**. The opt-in probe emits only
one allowlisted JSON summary: observed numeric version if recognized,
a fixed state/reason and negative flags for account use, network
availability and live capability activation. Vendor stdout, stderr,
installed paths, environment, credentials and screenshots stay out of
GitHub and chat. Do not request or publish raw output if the regex does
not recognize the installed build.

## One-command maintainer evidence path

After reviewing the script, run it only from a **fresh temporary clone**
of `dev` (never modify or clean the parallel Wull checkout):
`bash scripts/megaqml-phase3b-owner-local.sh --acknowledge-disposable-offline-probe`.
The owner-local wrapper checks clean `dev`, approved GitHub remote,
Git identity and remote ancestry, then runs the independent fake-only
contract and nonvendor self-test **before** any sandboxed vendor probe.
It validates the entire resulting JSON envelope against fixed allowed
keys, states, version digits and reason codes before reporting or
publishing anything. The wrapper writes only this sanitized summary,
source SHA and static PASS flags to a new private `dev` report
`docs/evidence/megaqml/phase3b-<source-prefix>-<utc>.md`. A missing
bubblewrap or unsupported environment may produce a safely published
BLOCKED report rather than an invented version observation. It
fast-forwards or merges only approved concurrent Wull/previous tested
evidence changes, never force-pushes, stashes or resets Wull work.
If publication fails, only the fixed local summary appears in the
terminal; this is **not** a published/accepted Phase 3b result.
This explicit wrapper invocation consents to publishing only the
sanitized numeric installed version (if detected) and fixed status,
not raw output or any account information.

**Passing the version-only probe is not full Phase 3b qualification.**
It only establishes a sanitized, isolated first observed version.
Next, review the version result and author a version-specific
`mega-*` help/parser fixture procedure that uses the **same
isolation**. Enabling even a read-only cloud domain requires
independent explicit Connect/session ownership approval, installed
output parser and argv/locale fixtures, fake failure testing,
environment compatibility and authoritative readback. Destructive
operations require additional separate approval. Keep
`LIVE_AUTH_VENDOR_ENABLED=false` and every Phase 3a feature gate
denied regardless of what this report prints.

The last exact-source synthetic Phase 3a qualification is
`docs/evidence/megaqml/phase2p-ad79725acda0-20261002T031538Z.md`:
40/40 PASS, 8/8 fake-only repeats at source
`ad79725acda0fe3c61ba6b1afaba700e1a73b78b`.
These new probe files have **not** been run by the owner's local
bubblewrap/installed MEGAcmd; never mark Phase 3b as PASS from F1
synthetic checks alone. All development remains on shared `dev`
without touching `stable` or parallel Wull files.
