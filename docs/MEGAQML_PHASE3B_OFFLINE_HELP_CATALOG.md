# MegaQML Phase 3b — disposable offline command-catalog gate

**Source-staged only; owner local Linux run pending.** The previous
offline script's successful bounded numeric observation was shared only
in the private conversation. This file deliberately does **not**
publish the maintainer's local installed version or diagnostic results.

## Why the next gate is a command catalog, not a new capability

Pinned upstream MEGAcmd source defines `mega-version` as a wrapper
for `mega-exec version`. The upstream server's `version` handler
prints its compiled MEGAcmd version. Upstream `help -f` is documented
as listing the available commands with brief descriptions, and upstream
documents `version`, `df`, `sync` and `transfers`.
Sources (upstream pinned at
`6505327a5a7a0e94f26f611f83b024aeeb63582c`):
- `src/client/mega-version`,
- `src/megacmdexecuter.cpp` (version handler),
- `contrib/docs/commands/{help,version,df,sync,transfers}.md`.

The source's `version` handler can request the latest vendor release.
**This check retains full network namespace isolation**; the fact that
an offline version line appeared does not establish network readiness.
Upstream documentation is a research baseline and does not override
what the owner's actual installed package supports.

## One new, explicitly acknowledged, local-only procedure

`scripts/megaqml-phase3b-offline-help-catalog.py` is separately
opt-in via `--acknowledge-disposable-offline-help-catalog`.
It uses the existing validated pacman-owned binaries, private-library
ownership and symlink gate, only the existing read-only
`/opt/megacmd/lib` mount and unchanged disposable bubblewrap
network/PID/private HOME environment. It additionally requires
`mega-exec` to be root-owned, non-writable and declared in the
same matched installed pacman package. If any dependency or provenance
check fails, no vendor executes.

After a nonvendor bubblewrap smoke, a **single fresh sandbox** runs
`mega-exec version -l`, then only if successful and uniquely parsed,
`mega-exec help -f`. The inner supervisor bounds combined output,
keeps total time to at most 8.5 seconds and never executes `df`,
`sync` or `transfers` commands. It emits only fixed categories,
a Boolean indicating a consistent version-format line, and
presence flags for those four command names in the isolated catalog.
Raw vendor output, version digits, emails, host paths, account
information and sandbox logs stay private.

A present command name is **catalog evidence only**. It does not
prove that options/column names, installed help fixtures, parser
roundtrips or login-state semantics work, and **does not qualify**
server identity or enable any live domain. Unknown catalog formatting,
truncation, timeout, missing executor or ambiguous version fails
closed; do not open network access or auto-retry. Run the synthetic
contract and inert self-test before a one-shot local Linux run.
No public publisher is connected to this script.

The later installed help/parser phase must separately establish
exact installed command-level help/column options, error handling,
argument injection safety, and disposable account fixtures under
an additional controlled, approved context. Preserve `stable`,
parallel Wull work and all ten disabled feature gates.
