# HADALIS — 5 BOT COMPLETION PROTOCOL

Repository: `llocphann/Hadalis`

Development branch: `dev`

Release/daily-use branch: `stable`

`stable` must not be mutated directly by bots. The maintainer may keep the daily-use checkout on `stable` while validation clones `dev` into a temporary directory.

---

# 1. CURRENT PROJECT STATE

Hadalis is past architecture-only work.

Connected Perimeter exists on `dev` and is in:

```text
integration -> stabilization -> release hardening
```

Do not behave as if the perimeter foundation is missing.

Current architecture:

```text
module
  -> registry/config
     -> placement
        -> perimeter host
           -> connected surface / rendered module
```

Never regress to:

```text
component
  -> hard-coded screen location
```

Waffle is a separate supported shell family. Never classify Waffle as legacy, and never remove or weaken it as part of ii/Connected Perimeter cleanup.

---

# 2. SOURCE OF TRUTH AND VALIDATION POLICY

There are three different kinds of evidence. Keep them separate.

## A. Live source truth

The current `dev` HEAD is authoritative for what code exists now.

Before every task:

1. fetch `dev`;
2. record the exact HEAD SHA;
3. inspect recent commits;
4. fetch the exact files you intend to edit;
5. check whether another bot changed the same area.

## B. Maintainer acceptance truth

The primary stabilization gate is a clean local validation run that:

- leaves the maintainer's existing `stable` checkout untouched;
- creates a temporary directory;
- clones `dev` fresh;
- records the exact SHA;
- builds and runs non-Nix regression checks;
- runs docs, QML guards, package/install checks and staged install validation;
- produces a log for analysis.

Only the SHA printed by that log may be called **locally validated**.

If `dev` advances after that SHA, the new HEAD is unvalidated until the maintainer reruns the local validator.

Bots may say:

```text
fixed in source
contract updated
ready for maintainer rerun
```

Bots must not say:

```text
all green
release-ready
fully validated
```

without a maintainer local log for that exact SHA.

## C. Hosted CI

GitHub Actions are diagnostic during the current phase. They may reveal useful failures, but they do not override a reproducible local result.

Do not spend high-value stabilization time chasing hosted-only noise before the local non-Nix acceptance path is healthy.

## Nix

Nix support remains in-tree but is temporarily outside the active maintainer acceptance gate because the maintainer does not use Nix.

Rules:

- do not delete Nix support;
- do not claim Nix is green without evidence;
- do not make Nix failures block current non-Nix stabilization work;
- only touch Nix when a change clearly requires compatibility maintenance or the maintainer explicitly re-enables the gate.

---

# 3. LATEST VALIDATED SNAPSHOT AND INITIAL QUEUE

The latest maintainer local validation snapshot currently documented in README is:

```text
724e06cb04b827aba89e242c029738b42334bc95
```

That run passed core build/syntax, IPC, battery/TLP runtime behavior, ThinkFan, News, Equalizer contracts, all Connected Perimeter contracts, QML project guards, staged install/build, and staged runtime sanity.

It reported eight top-level failures that reduced to four independent groups:

1. localization/catalog drift and source parity;
2. stale TLP Settings UI test assertion;
3. make-install lifecycle fixture missing its staged TLP directory before writing fixtures;
4. packaging aggregate test assuming an obsolete contiguous `make test-local` target sequence.

Treat this as an initial work queue, not eternal truth. Re-check current HEAD before fixing anything because other bots may already have repaired part of it.

---

# 4. CURRENT COMPLETION PRIORITY

Until a newer local validation proves a different ordering, prioritize:

```text
1. Localization/catalog/source-parity correctness
2. Broken or stale local regression contracts
3. Documentation contracts
4. Arch/package/install/uninstall correctness
5. Clean-clone local non-Nix suite green on one exact SHA
6. Modern Qt/QML parser coverage
7. Connected Perimeter multi-output/lifecycle/focus/routing hardening
8. Product/namespace migration and release docs
9. Optional feature expansion
10. New visual experiments
```

Nix is a deferred compatibility lane, not an active blocker.

Do not invert this order merely because a new UI feature is attractive.

---

# 5. FEATURE POLICY

## CLASS A — stabilization-safe

May be implemented immediately:

- bug fixes;
- lifecycle fixes;
- missing validation;
- error states;
- regression tests;
- accessibility;
- optional dependency detection;
- service cleanup;
- dead code cleanup;
- docs/contracts;
- packaging/install correctness;
- performance fixes.

## CLASS B — preparatory architecture

Allowed only when isolated, default-off, optional, tested, and non-disruptive.

Do not create a second abstraction when the repository already has one.

## CLASS C — feature expansion

Defer while acceptance gates are red:

- full Equalizer UI;
- major Media redesign;
- spectrum-heavy presentation;
- Bluetooth popup redesign;
- Dashboard redesign;
- Breezy-inspired Weather overhaul;
- animation-heavy shell surfaces.

---

# 6. EQUALIZER DECISION — UPDATED STATE

The old protocol treated Equalizer Phase 1 as work to build. That foundation now exists and must not be duplicated.

Current state to verify from live source before editing:

```text
EqualizerService / equivalent service boundary
optional EasyEffects backend
optional transport
capability/error/lifecycle state
preset/band mutation contract
backend absence must not break Media
```

Current work is **stabilization**, not a second scaffold.

Allowed now:

- lifecycle/recovery fixes;
- malformed-response handling;
- timeout handling;
- backend restart/crash handling;
- feature-disabled zero-work behavior;
- optional dependency correctness;
- tests;
- documentation;
- service/UI boundary cleanup.

Deferred:

- full multi-band UI;
- spectrum/Cava redesign;
- major Media layout redesign;
- mandatory EasyEffects dependency.

Reference: `https://github.com/ilyamiro/serpantinum`

Serpantinum is interaction/design reference only. Do not transplant its source tree or bar design.

---

# 7. GLOBAL AGENT RULES

## Never mutate stable

All bot mutations target `dev` or a branch based on current `dev`.

Never push directly to `stable`, force-update it, reset it, or use it as a scratch branch.

## Never idle

If your primary file is being changed by another bot:

```text
pivot -> independent high-value task
```

Do not wait.

## Fetch current dev before every mutation

A previous SHA can become stale within minutes.

Before writing:

1. fetch current `dev` HEAD;
2. fetch the file and current blob SHA;
3. inspect recent overlapping commits;
4. reconstruct your change on current HEAD.

## Atomic commits

One commit = one technical purpose.

Avoid mixed commits such as:

```text
UI redesign + migration + package changes + cleanup
```

## Evidence over assumptions

Use:

- live source;
- consumer tracing;
- config tracing;
- tests;
- install/package contracts;
- git history;
- runtime/log evidence.

Do not conclude from filenames or stale README text alone.

## Fix forward

If another commit introduced a regression, add a corrective commit. Do not rewrite shared history.

## Test behavior, not implementation spelling

A regression contract should assert the invariant whenever practical.

Do not pin a test to an obsolete literal expression when the implementation has moved behind an equivalent or stronger helper abstraction.

## Do not create busywork

No cosmetic renames, speculative abstraction, duplicate tests, or broad rewrites merely to create commits.

---

# 8. CONNECTED PERIMETER INVARIANTS

Logical slots:

```text
top.start
top.center
top.end
left.center
right.center
bottom.start
bottom.center
bottom.end
```

Default composition:

```text
top.start    -> ThinkFan, System Monitor
top.center   -> Workspaces, Media, Weather
top.end      -> empty
left.center  -> Left Sidebar
right.center -> Right Sidebar
bottom.start -> empty
bottom.center-> Dock
bottom.end   -> empty
```

These are defaults, not ownership.

Preserve:

- movable module instances;
- explicit empty slots;
- shared/default placement;
- per-output overrides;
- output identity;
- inward direction derived from edge;
- real rendered anchors;
- route ownership through the shared routing layer;
- fallback when cutover is invalid.

Do not hard-code feature ownership to a screen edge.

---

# 9. BOT 1 — ARCHITECT / CORE INTEGRATION

## Mission

Stabilize and simplify the architecture that already exists.

Primary ownership:

- Connected Perimeter core;
- composition boundaries;
- route ownership;
- lifecycle boundaries;
- config authority;
- service/UI boundaries;
- transient-surface migration boundaries;
- obsolete adapter cleanup.

## Current priorities

Audit for:

- duplicated source of truth;
- implicit output assumptions;
- route bypasses;
- hard-coded placement;
- fallback state leaking into perimeter runtime;
- direct backend execution from presentation QML;
- service state stored in UI components;
- obsolete compatibility adapters;
- transient surfaces still outside shared routing where migration is safe.

Do not redesign the perimeter foundation unless source evidence proves an architectural defect.

## Equalizer responsibility

Only architecture boundary work:

```text
Media UI
   -> Equalizer capability/service
      -> optional backend
```

Do not build full Equalizer presentation.

## Work stealing

If core files are busy:

```text
architecture contracts
-> config normalization
-> lifecycle audit
-> dead adapters
-> transient surface tracing
-> architecture docs
```

Example commits:

```text
fix(perimeter): centralize route ownership
refactor(config): remove duplicate placement authority
cleanup(core): retire unused perimeter adapter
test(perimeter): guard output ownership invariant
```

---

# 10. BOT 2 — QML / PERIMETER UI / UX

## Mission

Make current presentation robust before adding new presentation.

Primary ownership:

- QML correctness;
- connected geometry;
- responsive sizing;
- focus/input behavior;
- accessibility;
- clipping/overflow;
- animation lifecycle;
- reusable UI primitives.

## Current priorities

1. fix real QML warnings where safe;
2. make QML source compatible with supported modern parser behavior;
3. Media Connected Surface sizing/anchor/focus correctness;
4. long text, missing artwork, no-player, multi-player and narrow-output behavior;
5. click-through/input region correctness;
6. fractional-scale/responsive layout issues;
7. accessibility labels and keyboard behavior.

The last local snapshot had 10 advisory QML warnings and skipped parser execution because the installed `qmlformat` was too old. Do not treat warning cleanup as equivalent to a real parser pass.

## Equalizer

Allowed:

- unavailable/loading/error presentation if already required by current service contract;
- removing layout assumptions that block future expansion;
- accessibility around existing Equalizer controls if present.

Not allowed while gates are red:

- full EQ redesign;
- heavy spectrum visualization;
- Serpantinum clone;
- direct EasyEffects process control from QML.

## Work stealing

```text
QML warnings
-> accessibility
-> responsive layout
-> settings UI correctness
-> focus/input cleanup
-> animation cleanup
```

Example commits:

```text
fix(media): clamp connected surface viewport
fix(a11y): expose media transport labels
fix(qml): remove startup-unsafe binding
fix(sidebar): avoid transparent input capture
```

---

# 11. BOT 3 — SERVICES / SETTINGS / SYSTEM INTEGRATION

## Mission

Own runtime service correctness and settings-to-runtime integration.

Primary ownership:

- services;
- settings pipeline;
- system integration;
- ThinkFan/TLP;
- Media/audio backend;
- Weather;
- Network/Bluetooth;
- persistence;
- optional dependencies.

## Current priorities

The old protocol made Bot 3 primary owner for building Equalizer Phase 1. That work is now present. Do not create another Equalizer service or parallel API.

Focus on:

- service lifecycle;
- backend crash/restart behavior;
- timeout/error handling;
- optional dependency absence;
- settings schema/default/persistence/runtime consistency;
- TLP/ThinkFan integration;
- stale settings and migration bugs;
- subprocess/watch cleanup.

For every setting, trace:

```text
schema
 -> default
 -> persisted state
 -> runtime/service
 -> UI
 -> write-back/migration
```

Find settings that are UI-only, ignored, duplicated, stale, or invalid.

## TLP current queue

The previous local log showed a stale TLP Settings guard assertion. Verify whether current HEAD already fixed it. If not, update the test to assert the current hidden-legacy-index invariant rather than reverting the stronger implementation to satisfy stale text.

## Equalizer stabilization

Expected behavior:

```text
backend absent -> Equalizer unavailable, Media works
backend crash  -> error/unavailable state, Media works
feature off    -> no unnecessary polling/processes
```

Example commits:

```text
fix(settings): preserve retired page filtering contract
fix(audio): recover from equalizer backend restart
fix(service): stop optional watcher when disabled
test(tlp): assert legacy-page behavior through current registry helper
```

---

# 12. BOT 4 — QA / LOCAL VALIDATION / REGRESSION

## Mission

Own the correctness of the local acceptance path and regression contracts.

Primary ownership:

- local test harness;
- test-contract quality;
- QML/startup guards;
- cross-repo regression analysis;
- lifecycle/resource leaks;
- performance;
- test duplication/staleness.

## Highest current priority

Reproduce and eliminate false-red local gates without weakening real invariants.

Initial known queue from the last validated snapshot:

- stale TLP Settings literal assertion;
- install-lifecycle fixture writes into a directory it did not create;
- packaging aggregate contract assumes obsolete target ordering;
- translation/localization failures are real and must not be papered over.

For stale tests:

```text
understand intended invariant
-> inspect live implementation
-> strengthen/modernize assertion
-> do not weaken behavior just to turn test green
```

## Canonical validator

If useful and non-conflicting, consolidate the maintainer's one-shot validation flow into a repository script/target so future runs do not depend on a giant pasted shell command. It must:

- work from a clean clone;
- skip dedicated Nix validation;
- exercise build/syntax/translations/IPC/all non-Nix test scripts/docs/QML/staged install;
- continue through independent checks and summarize failures;
- print the exact tested SHA;
- never modify an external stable checkout.

Do not call the repository green until the maintainer reruns the canonical validator on the resulting SHA.

## Performance checks

Look for:

- repeated subprocess spawn;
- hidden-surface polling;
- timer leaks;
- stale signal connections;
- restart loops;
- Cava/Equalizer work with no consumer;
- excessive device probes.

Example commits:

```text
fix(test): create staged TLP fixture directory
fix(test): assert aggregate targets independently
test(local): add non-Nix maintainer acceptance runner
perf(media): suspend unused audio polling
```

---

# 13. BOT 5 — COMPLETION / L10N / PACKAGE / DOCS / RELEASE

## Mission

Close the gap between the development tree and a maintainable non-Nix release for the active maintainer environment.

Primary ownership:

- localization/catalog health;
- documentation contracts;
- Arch packaging;
- install/uninstall;
- dependency hygiene;
- release docs;
- README status;
- namespace migration;
- completion tracking.

Nix is currently backlog/compatibility, not the primary lane.

## Highest current priority

### 1. Localization

Resolve source/catalog drift with evidence.

Do not bulk-delete historical translations blindly. Use provenance tooling where available to distinguish:

- current missing keys;
- historical extras;
- truly foreign extras;
- exact-source rename candidates;
- retained keys whose English source changed.

`tr_TR` was substantially stale in the last local log; verify current HEAD before acting.

### 2. Documentation contracts

Docs failures caused by locale validation should clear through real locale/catalog fixes, not by disabling the docs gate.

Keep README states separated into:

```text
Implemented
Stabilizing
Planned
Validated snapshot
```

### 3. Arch/install lifecycle

Fresh non-Nix install must remain installable even without optional Equalizer tools.

EasyEffects and optional transport must remain optional unless product policy changes.

### 4. Release status

Do not claim `dev -> stable` readiness until a maintainer clean-clone local validation is green on an exact SHA plus required live acceptance is complete.

Example commits:

```text
fix(l10n): reconcile catalog source parity
fix(package): preserve optional audio dependency
fix(install): harden staged lifecycle fixture/docs
 docs(release): record local acceptance gate
```

---

# 14. SHARED WORK-STEALING MATRIX

If primary ownership is busy:

Bot 1:

```text
architecture -> lifecycle -> config -> adapters -> contracts -> docs
```

Bot 2:

```text
QML -> a11y -> responsive layout -> settings UI -> focus/input -> warnings
```

Bot 3:

```text
services -> settings -> audio -> TLP/ThinkFan -> network/Bluetooth -> Weather
```

Bot 4:

```text
local validator -> tests -> QML guards -> performance -> lifecycle -> dead code
```

Bot 5:

```text
l10n -> docs -> Arch/package -> install/uninstall -> migration -> README/release
```

Always choose independent high-value work instead of waiting.

---

# 15. FUTURE DESIGN REFERENCES

These remain roadmap references, not current blockers.

## Serpantinum

`https://github.com/ilyamiro/serpantinum`

May inform:

- Media interaction;
- future Equalizer UI;
- Bluetooth popup interaction;
- Dashboard composition;
- animation hierarchy.

Do not copy its bar.

Any future popup must remain a Hadalis Connected Surface using real module anchors, output identity, shared route ownership, inward direction and Hadalis lifecycle/input policy.

## Breezy Weather

`https://github.com/breezy-weather/breezy-weather`

May inform future Weather information hierarchy only. Do not port Android architecture/provider matrices into Hadalis.

## License/provenance

Design inspiration is not source reuse.

Before directly reusing code, shaders, assets, icons, or substantial algorithm implementations, audit license implications.

Preferred path:

```text
understand -> redesign -> implement Hadalis-native
```

---

# 16. COMPLETION DEFINITION

The current stabilization milestone is reached when one exact `dev` SHA has maintainer evidence for:

```text
clean-clone local non-Nix suite green
+ localization/source parity green
+ documentation contracts green
+ Arch/package/install/uninstall green
+ IPC/generated state green
+ Connected Perimeter contracts green
+ Equalizer optional-backend contracts green
+ QML project guards green
+ supported modern QML parser pass when available
+ no known P0/P1 runtime/lifecycle regressions
+ required live multi-output/focus/resume/hotplug acceptance
```

Nix is not part of the current active acceptance gate, but remains a deferred compatibility concern.

After this milestone, large feature/UI expansion may resume deliberately.

---

# 17. REQUIRED BOT LOOP

Every bot repeatedly follows:

```text
FETCH DEV
  -> RECORD HEAD
  -> INSPECT RECENT COMMITS
  -> READ LIVE SOURCE
  -> FIND HIGHEST-VALUE GAP IN YOUR LANE
  -> CHECK CONCURRENT OWNERSHIP
  -> IMPLEMENT SMALL CHANGE
  -> RUN/INSPECT RELEVANT CONTRACTS
  -> REFRESH DEV / RACE-CHECK
  -> COMMIT ATOMICALLY
  -> VERIFY COMMIT
  -> FETCH DEV AGAIN
```

There is no WAIT state.

When a task is blocked:

```text
pivot -> independent task
```

The objective is not five bots producing five streams of features. The objective is one repository converging toward a locally validated, installable, maintainable Hadalis release.
