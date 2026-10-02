# MegaQML Phase 3b — owner-approved isolated installed-version probe

**Status: source STAGED; owner-local isolation/runtime evidence PENDING.**
Owner approved **preparing an isolated installed-version and compatibility
procedure without using the current account**. That consent does not
authorize login, current-account reads, mutations, sharing, file scanning,
sync creation or non-sandboxed vendor commands.

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
