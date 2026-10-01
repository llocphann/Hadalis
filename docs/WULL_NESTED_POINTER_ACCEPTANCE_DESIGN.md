# Wull — nested Niri real pointer acceptance design

Status: **underlay fixture and inert target contract staged; no physical pointer test executed**.
Scope: the existing actual `AbyssPerimeter` PanelWindow with production
`AbyssCompanion`, not a synthetic standalone mascot or an offscreen rectangle.

## Existing evidence and boundary

The October 1 production geometry receipts on `336726d7...` and
`fca39532...` both recorded four-edge containment of the actual centered
production QML. Focused native/perimeter qualification recorded 8/8 PASS
on `c10b669f...`. The new nested-Niri receipts
`docs/wull-nested-niri-20261001T152505Z-d938e783-24af1766f3eb.json`
and
`docs/wull-production-layer-20261001T152511Z-c5413658-24af1766f3eb.json`
both recorded PASS on exact source
`24af1766f3eb7fc7abb2a381efba962ea51ed42d`.
Those nested receipts established an owned private compositor, one active
output, real production layer mapping, default-off isolation, single owned
Rust backend when enabled, keyboard-focus constraints and full cleanup.
**They did not send a mouse event or qualify any compositor hit region.**

The existing production input mask deliberately includes the entire
`AbyssCompanion` host. The smaller rotated body is the click receiver. A
source-level rectangle is not proof that a Wayland compositor will route
an actual pointer event as intended. Do not change production mask yet.

## Staged groundwork (safe, no live run)

- `scripts/wull-fixtures/pointer-underlay/shell.qml` is a separate,
  full-output `WlrLayer.Bottom` PanelWindow with namespace
  `hadalis:wull-pointer-underlay`, no keyboard focus and a click witness.
  It has no production loader, Wull enablement or virtual input capability.
  Its `WULL_POINTER_UNDERLAY_PRESS` coordinates appear only in private
  test logs. It must be launched only inside an owned nested Niri socket.
- `scripts/wull-pointer-targets.py` computes **candidate** top-edge
  production bounds and three points from the reviewed default
  configuration, real shared host-policy placement equation and
  production mapped body dimensions: a body center, an empty host margin
  and an exterior control. It enforces a bounded output/geometry and
  avoids the default bar's top 40 logical pixels. Estimates do not
  constitute a hit-test or a screenshot-based visual acceptance.
- `scripts/test-wull-pointer-underlay-contract.py` is an inert automated
  regression: fixture layering and marker contracts, default-off and
  unchanged whole-host mask, actual production click wiring, and
  deterministic target calculations across small and large viewports.
  Its new code still requires execution evidence on an exact source SHA.

## Implementation gate for a controlled real click runner

1. **Isolation**: from a clean, fast-forward-only `dev`, verify permitted
   origin, owner-created private diagnostics outside the repository and
   audited production/fixture blobs. Start one nested Niri inside the
   host's regular Wayland window with a private empty `NIRI_CONFIG`.
   Verify *distinct* nested `WAYLAND_DISPLAY` and `NIRI_SOCKET` and
   zero preexisting production/underlay namespace collisions. Abort
   before launching any pointer actor if identity cannot be proved.
2. **Underlay**: start only the dedicated private underlay on the nested
   display. Confirm its explicit QML-ready marker AND compositor layer
   inventory (one bottom layer on the expected nested output).
   Never run underlay on the real host display.
3. **Production**: run the real unchanged Abyss production fixture with
   its own isolated XDG directories and D-Bus, pinned private release
   `inir-companiond`, default-off and temporarily enabled phases.
   For pointer tests only, explicitly set
   `abyss.companion.interactive=true`, `edge=top`, `along=.72`,
   `size=1`, and a known nested output. Do not persist any user config.
   Verify compositor-visible layer ownership and exact private daemon
   count. The prior production probe uses `interactive=false` and
   therefore cannot qualify click reception on its own.
4. **Input provenance**: permit only a Wayland-native virtual-pointer
   client bound to the **verified nested socket**. A native
   `wlr-virtual-pointer` backend may be used if installed and shown to
   work on the exact local nested Niri instance. Do not use host-global
   `ydotool`/`uinput`, root input, uncontrolled desktop tools or any
   fallback that can inject into the live compositor. Do not silently
   download or install an input tool as a test side effect. Missing
   backend or unavailable protocol => **INCONCLUSIVE**, not PASS.
5. **Acceptance matrix**: require an *observed* underlay click at the
   body-center candidate with Wull disabled (negative control), then
   an observed underlay click outside the host when enabled (pass-through
   control). With Wull enabled, click the actual body center: require
   the underlay receives **no** click **and** independent private evidence
   that production Wull's click was delivered to its real Rust bridge.
   Absence of an underlay click alone is not enough: an unrelated top
   UI region or absent input could yield the same result. Measure the
   host-empty-margin point separately; the current whole-host mask may
   capture it, and that is an **observation** rather than a reason to
   call pass-through successful. Count clicks using distinct bounded
   time windows, exclude startup/animation settle windows, and check
   the current top bar is not covering any test point.
6. **No conflation**: the first controlled top-edge matrix is separate
   from four-edge *physical* input behavior; later extend the validated
   approach to bottom/left/right, and then test pointer passthrough
   before/after any proposed inner-body-only Region change. Niri
   layer inventory does not report per-pixel input masks. A screenshot
   command succeeding does not prove visual quality.
7. **Cleanup/publication**: bound each process and whole milestone;
   terminate only owned live process groups and the exact private
   daemon binary, verify underlay and production layers unmap, verify
   nested socket disappearance and unchanged host-output inventory.
   Log raw QML events and coordinates locally only. Publish a unique
   SHA-pinned allowlisted JSON receipt with per-case status, preflight
   reason, exact source blobs and cleanup evidence; no raw screenshots,
   device names, host sockets, paths or logs. If publication is blocked,
   retain local evidence and print a short STOP; never rewrite shared
   Git history or fall back to an active desktop test.

## Decision after evidence

Only consider replacing the whole-host Wull `Region` after the real
underlay/body matrix, followed by a separate candidate-mask test
on the same compositor with unchanged click/hover behavior. Keep
`abyss.companion.enabled=false` by default. Canonical-wide validation,
physical multi-output/hotplug, long-run **whole-shell** resources,
session reload/suspend and maintainer visual/motion approval remain
independent outstanding gates.


## Private click-delivery relay prepared

The source-only fixture `scripts/wull-fixtures/pointer-underlay/companion-relay.py`
was staged in `f8116f4000b40265648e8a20f0d6f29fa16b1012`. A future nested
runner may explicitly point the real production bridge's private
`INIR_COMPANIOND` override to this narrowly guarded executable while the
relay itself starts the **real exact-source private Rust binary**. It
preserves newline JSON stdio, records only bounded private
`real_bridge_click_received` markers for v1 click events, and observes
the associated happy/pulse reaction produced by the real Rust core.
It refuses invocation without the private nested-session opt-in, distinct
nested/parent display and Niri socket names, absolute executable path
and out-of-checkout private trace. This is an observational fixture;
it cannot fake a production click or change the production source.

`scripts/test-wull-private-relay-contract.py`, committed as
`1a3e7a7d837e7bcfc82bf2bb8f702355d5475891`, is an **inert**
fake-backend unit smoke for relay line forwarding, private marker
creation and refusal of equal host/nested display identity. A fake
backend is used ONLY by that inert contract, never as evidence of a
real production click. These source files have no exact-source local
execution receipt yet.

A real pointer PASS additionally requires that observed private
underlay click controls bracket an enabled Wull center click and that
the relay's click marker plus a subsequent real backend reaction
belong to that phase. The marker/reaction alone cannot establish the
true pointer target without the independent underlay controls.


## Staged real nested pointer runner

The controlled real pointer implementation is staged in `dev`:
`scripts/wull-manual-pointer-child.py` launches the dedicated bottom
underlay and the unchanged actual `AbyssPerimeter` production fixture in
separate private Quickshell/XDG/D-Bus sessions on a **parent-verified single
nested Niri output**. Its disabled-center negative control must click the
underlay, enabled-outside-host control must click the underlay, and enabled
body-center must instead produce both a real production bridge click
and a subsequent state reaction from the private exact-source Rust daemon.
The empty whole-host margin is diagnostic only.

`scripts/wull-manual-nested-pointer.py` creates the owned nested compositor
from the live compositor's ordinary Wayland window and verifies distinct
nested Wayland/Niri socket identity, no namespace collision, output topology,
the private child's sanitized evidence and cleanup. It never injects pointer
events itself. The child forces an already-installed `wdotool` to the
`wlr-protocols` backend for `mousemove` and `click`, rechecking the
nested Wayland socket before each input operation. It **never** falls
back to portal permissions or host-global `/dev/uinput`. Missing `wdotool`,
unsupported native protocol, incomplete nested identity or unavailable
prerequisites yield **INCONCLUSIVE** without claiming input acceptance.
No automatic package installation or live-user-session test is permitted.

`scripts/test-wull-nested-pointer-contract.py` is an inert parser, isolation,
source-provenance and private fixture test. The existing
`scripts/test-wull-pointer-underlay-contract.py` and
`scripts/test-wull-private-relay-contract.py` remain prerequisites.
The coordinator source guard pins reviewed Wull production, native dependency
continuity, prior Niri helper, underlay, real relay, target estimator, and
the new child source blob. Their addition does **not** certify successful
runtime execution: no `docs/wull-pointer-acceptance-*.json` receipt yet.

The first coordinated manual gate must run all three inert contracts on
one clean `dev` SHA before explicitly invoking
`python3 scripts/wull-manual-nested-pointer.py --acknowledge-nested-pointer`.
The opt-in runner keeps bounded raw logs/coordinates in private state outside
the checkout and publishes only per-case classifications and exact source SHA.
A forced SIGTERM or timeout may terminate only its owned processes; no
real shell settings are read or written. A PASS on a single top-edge nested
output must not be interpreted as the other three edges, visual quality,
whole-shell resources or permission to narrow the production input mask.


## Missing wdotool: reviewed native-only wlrctl alternative

The first opt-in pointer receipt
`docs/wull-pointer-acceptance-20261001T155651Z-c552449b-304d6ab601b1.json`
on source `304d6ab601b130c11756de2f4ac7059cdda5507b`
is `INCONCLUSIVE` with `native_wdotool_missing_no_input_injected`.
The parent refused to start the nested pointer trial, and its
`observation` is null: **no physical input event was measured**.
The previously accepted geometry, native/perimeter, and owned nested
production host reports are unaffected.

Reviewed alternative: the external `wlrctl` CLI directly uses the
Wayland wlroots virtual-pointer protocol, without portal or uinput.
It is **relative-motion only**, unlike `wdotool mousemove X Y`.
The new fallback is accepted only when `wdotool` is absent and
`wlrctl` is already available in `PATH`. On the verified private
one-output nested socket the child issues a far-negative relative
move as a **candidate** origin reset, then a target-relative move
and native left click; it re-verifies the distinct nested Wayland
and Niri endpoints before **every** command. This origin reset
is deliberately NOT treated as proven positioning. Independent actual
underlay controls and the real production bridge-to-Rust reaction
must all pass to accept body hit-testing. For the relative-only
backend, failed controls/ambiguous targets are `INCONCLUSIVE`,
not evidence of a Wull product defect. `wdotool` remains the preferred
absolute native-only test backend; there is NO portal, host-global
input or automatic package-install fallback.

Source-only commits:
- `666d6d18d206a92a5d6b28d2800eb9e0e7156898`: alternative
  child backend command planner and per-command isolation check.
- `5f3b777457091bab8ed8c47be31512c1f915fd97`:
  coordinator selection and first reviewed-child pin.
- `0f22292de807744af0220356c96e66c71010fc33`:
  cautious relative-only inconclusive classifications.
- `97c2a4e5577759fcfb731890792e6a99135fbc66`:
  coordinator pins that final child and its seventh self revision.
- `0b716fa8f5011a29051aae2d4486869f2633351f`:
  inert command-plan/identity, pin and conservative classification
  assertions. **None of these source commits supplies new local
  acceptance evidence.**

The next user-owned local milestone is the three inert contracts
followed by one explicitly opted-in nested test ONLY if `wdotool`
or `wlrctl` is already installed. If neither executable exists,
report that missing prerequisite and do not automatically install
or rerun the pointer probe. Should the relative backend prove
unstable despite controls, keep `INCONCLUSIVE` and consider a
maintainer-installed, verified `wdotool` binary instead. All other
edge input, actual popup noninterference, visual and global release
gates remain separate; never shrink the production input Region
on a tool-availability failure.


## First real nested click failure and target-coordinate diagnostic

The maintainer's first real native input run published
`docs/wull-pointer-acceptance-20261001T161301Z-8af536c9-115ab32a9825.json`
on exact source `115ab32a98251453edc76c84bdc8558068186aab`.
It is **FAILED**, not accepted: nested Niri and private endpoint identity
passed, disabled-center underlay control passed, enabled-outside-host
underlay control passed, and all owned cleanup passed. In the enabled
body-center phase, the underlay still received a click and neither
the real production bridge nor the real private Rust daemon recorded
the required click/reaction. That narrows the problem to actual pointer
target placement, production host activation/visibility, or the
compositor-visible input mask. It does **not** yet prove that the
production Region is incorrect: the original two full-output underlay
positive controls counted clicks but never checked their coordinates.
The prior `rust_present` relay event proves real backend state, not
that the actual per-output host is active and correctly hit-tested.

Two guarded source-only diagnostic updates on dev:
- `a83f630f7f4bdc73953bc75b7b14b888e6544219` adds
  `underlay_target_status` to the private child. It parses the
  *actual* recorded mouse coordinates from the existing **private**
  full-output underlay witness. Both disabled body-center and enabled
  exterior control now require **exactly one** matched left-click
  within six logical pixels of each predicted requested point;
  missing, multiple, malformed or off-target clicks are
  `INCONCLUSIVE` on either backend, not Wull defects.
  For the enabled body phase, any underlay click is separately
  compared with the candidate body point. An off-target or ambiguous
  underlay event is likewise `INCONCLUSIVE`; a matched underlay
  click at the expected candidate, with no real bridge/Rust event,
  is the narrower failure warranting host/mask investigation.
  Raw coordinates remain exclusively in local private logs:
  the sanitized public per-case receipt publishes only
  `matched`, `off_target`, `no_click`, or bounded ambiguity
  classifications and the independent real-bridge/Rust booleans.
- `a784b3db6157d4c05368fee0ec79925a1a51f468`
  reviews/pins that exact new child blob in the coordinator and
  advances its guarded self-revision count to eight.
  `03d237620ada9dd170d31163ef6081bd40a66042`
  adds synthetic *inert* witness-parser cases, bounded-target
  rejection and the updated exact child blob requirement.
  These are NOT new live pointer results.

Run the three inert prerequisites before the next optional
single-command isolated nested probe from clean fast-forward-only
`dev`, now that a native pointer CLI is available. Evaluate
`target_alignment` on both controls and
`underlay_target_alignment` on the enabled body before attributing
the failure. If both controls and body-underlay alignment match
but the daemon did not react, design a **separate test-only**
production-host visibility/input-mask diagnostic without changing
the production mask. Do not shrink the mask, disable default-off
behavior, infer visual qualification or modify `stable`.


Diagnostic receipt backend provenance follow-up: source-only commit `6670066439c8899b42ba528e5cf81f9b71ce9ee4`
also projects the private child's bounded `injection_backend` classification
into the sanitized top-level `native_pointer_backend` field. This
distinguishes `forced_wlr_protocols_wdotool` from
`native_relative_wlrctl_unverified` when analyzing alignment, without
publishing the user's executable path or environment. The coordinator
self-review count advances from eight to **nine** reviewed commits.
`1de19ca38f1738e0167b01a169c63f67d43cf1a4` adds an
inert contract assertion for the allowlisted provenance field.
The new coordinate-verified pointer run still needs local execution.


## Coordinate-qualified real top-edge PASS; private candidate A/B staged

The new exact-source real production receipt
`docs/wull-pointer-acceptance-20261001T161911Z-4d87f846-391d8e81d461.json`
was published on source
`391d8e81d4617a6dbdb1199d009db4e0970ce073` and is **PASS**.
The separately owned one-output nested Niri had distinct verified
Wayland and IPC sockets, zero preexisting witness/production namespaces,
and a privately built REAL Rust `inir-companiond`. The precise
native backend was `forced_wlr_protocols_wdotool`.
The underlay separately confirmed *correct requested actual coordinates*
for both the Wull-disabled body-center control and Wull-enabled exterior
pass-through control. At Wull's enabled body center, the underlay saw
no click and the actual production bridge emitted exactly one real
click with the private native Rust daemon subsequently recording its
happy/pulse reaction. All owned production/underlay layers, private
daemon and nested compositor were cleaned; host output count was
unchanged. The earlier count-only FAILED receipt does not override
this newer coordinate-qualified test. This PASS applies ONLY to the
unchanged full-host input mask, one top edge on one nested output:
it is not proof of a narrower mask, all four edges, popup
noninterference, live host visual quality, canonical-wide validation,
suspend/reload/multioutput, or long-run whole-shell resources.

That PASS also observed **no underlay click at an empty location
inside the current full 112x98 Wull host**, and no accidental
body activation there. Although this is consistent with the current
full-host production mask, the empty-margin negative result alone
cannot independently attest precise pointer coordinates. A follow-up
private A/B comparison MUST show the *positive* correct-coordinate
underlay margin click for the candidate.

Source-only follow-up for the explicit separate A/B gate:

- `scripts/wull-private-mask-candidate.py` (created
  `e3da0c57264cb44f26045e285f14b22a301a06ba`) verifies
  the EXACT real production `Region` and centered top-edge
  76x92 `AbyssCompanion` source. It replaces precisely that
  one input-mask Region in a PRIVATE copy of
  `modules/abyss/AbyssPerimeter.qml`, shadowing only the Abyss
  module directory in an isolated test shell. Every other
  module remains an unchanged symlink to the pinned checkout.
  The test-only candidate uses a rectangular top-edge size=1
  centered 76x92 body footprint; this does not establish
  a curved silhouette mask or multi-edge fitness.
- `11ecc21ad115fd0c683f3c7ce0c2e003e58f256d`
  and `975482cd8a49475d9eb622d7b38c49aa601ec2bf`
  add private candidate staging and **same-owned-nested-Niri**
  baseline/candidate sequential comparison inside the child.
  The baseline full-host mask must qualify FIRST (disabled
  body, enabled exterior, real bridge/Rust body), and then
  show its expected no-underlay empty-margin observation.
  The child stops and unmaps that actual baseline source
  before launching a NEW private candidate fixture with
  separate real Rust trace. Candidate must independently
  confirm enabled exterior underlay alignment, body bridge
  click+real Rust response with no underlay click, and
  positive exact-coordinate underlay reception at the
  otherwise-empty Wull host margin without an extra body
  activation. A candidate requiring a different toolkit,
  ambiguous pointer result or unable to unmap its baseline
  must NOT claim PASS.
- `244b6a95a485ff669506614958832e2715cb3e3c`
  adds an explicit opt-in to the existing guarded parent:
  `--acknowledge-nested-pointer-candidate`. Only this mode
  passes the private candidate flag; the old
  `--acknowledge-nested-pointer` path continues to use
  the unchanged production source. The coordinator pins
  exact candidate-generator and child blobs and has
  ten guarded revisions; a production or dependency edit
  cannot silently pass the old source audit. It requires
  the native **absolute** Wayland protocol backend
  `wdotool` for the initial A/B geometry gate.
  Its sanitized result uses a DIFFERENT unique prefix
  `docs/wull-mask-candidate-*.json`; all private mouse
  coordinates and raw logs stay outside the checkout.
- `scripts/test-wull-private-mask-candidate-contract.py`,
  created in `b705c2b224ff432e06e4268b25fb8ba7d84626f3`,
  exercises exact single-marker replacement, refusal
  of changed production source, shell-private-only
  module staging and anti-overwrite constraints with NO
  compositor or input. `55e191bb119be6e7f7d47150dff8876db0fb6fe8`
  re-anchors the existing nested-pointer inert source
  contract. All four current inert pointer contracts must
  PASS on one clean checked-out `dev` SHA before an
  opt-in private A/B execution.

**Status: new candidate gate STAGED IN SOURCE ONLY, not locally
executed.** Do not edit the production Region based solely on
the current top-edge full-host PASS. Next review the unique
candidate report (including BOTH stage check sets, matched
witnesses, real bridge/Rust and owned cleanup) before considering
a minimal real production integration, which would still need
four-edge, hover/popup and live-host qualification. `stable`
and shipped default-off Wull have not been changed.


## Private top-edge A/B PASS; bottom-edge qualification staged

The new maintainer-owned real comparison receipt
`docs/wull-mask-candidate-20261001T165308Z-a3bc585f-124f02155679.json`
on exact source `124f02155679949e60a810e54a9c216fbfd2fabe`
has overall **PASS** on one top edge with scale=1 and a single
privately owned nested Niri output. The original production full
mask qualified in the SAME private compositor first: actual disabled
body-center and enabled exterior clicks had `target_alignment=matched`,
the enabled body click reached the real production bridge and private
Rust happy/pulse without touching underlay, and the old full-host
empty margin remained blocked (no body click). The candidate copied
ONLY the guarded `AbyssPerimeter.qml` input region outside the
checkout; it separately demonstrated an aligned exterior underlay
click, a real body bridge/Rust click with no underlay click, AND a
positive `target_alignment=matched` underlay click at the formerly
blocked empty host margin with no accidental body activation.
Nested identity, process/layer cleanup and host-output count passed.
The backend was native `wdotool --backend wlr-protocols`. This is
**positive evidence for the private rectangular candidate at top,
scale=1, one nested output**, not proof of full deployment safety
or a reason to edit production already. Production Wull and
`stable` remain unchanged.

Next source-only staged gate: a guarded private **bottom edge**
A/B trial. A prior exact-source postchange offscreen production
geometry receipt
`docs/wull-production-geometry-20261001T151838Z-fd6d4452-fca3953264b1.json`
observed the centered Wull body on all four edges:
top/bottom full host 112x98, body BBOX (18,3,76,92);
left/right full host 98x112, rotated body BBOX (3,18,92,76).
This is geometry only, NOT actual four-edge pointer acceptance.
`scripts/wull-pointer-targets.py` (commit
`62c483451d91c7b0e5e1f1184fd84f8b04443c14`)
now proposes conservative four-edge body center, host empty margin
and exterior candidate points, with pure bounds validation; its
original `top_edge_targets` still drives the exact same top path.
`scripts/wull-private-mask-candidate.py` (commit
`5b928b852664e8369f74fa17243e78cc92a402c8`)
generates a PRIVATE body BBOX Region that selects 76x92 on
horizontal edges and 92x76 on vertical edges, conditioned on
reviewed interactive host state, allowed edge and size=1. It
guards exact centered production body/rotation source and replaces
only one old mask Region. Despite generating all four variants,
ONLY the top variant has the independent real pointer evidence.

`4e32eaa1f874540b5f71ceca34c5a4b697734568`
adds an allowlisted `candidate-mask-bottom` child mode with the
correct bottom production config and target geometry; the default
legacy production and original top candidate modes continue to
select top. `3309b00ac035ff5944283073aef8e181382339e8`
pins those reviewed child/candidate/geometry blobs and adds a
DIFFERENT explicitly opt-in coordinator argument
`--acknowledge-nested-pointer-candidate-bottom`.
Bottom reports have a distinct unique
`docs/wull-mask-bottom-*.json` prefix and a bottom-specific
scope, while top uses its original distinct report prefix.
The coordinator's reviewed self-revision guard advances to 11.
`4d5080b87951885e40b920d6e603a5e064f35cb9`
extends the all-private inert mask contract with the four
offscreen-measured BBOX relationships and top-path equivalence;
`6b210355f794d2490059f5de46251ece32f313ea`
updates the original nested pointer source-pinning and
bottom-only opt-in assertions. The next LOCAL trial must execute
four inert pointer tests first, followed by a fresh top candidate
regression (because the private mask generator is now dynamic),
and only if that returns an explicitly observed PASS, run the
bottom candidate mode on its own private owned nested compositor.
The bottom run independently re-verifies old production full
host controls and then private candidate controls.

The bottom-stage source is reviewed but **NOT locally executed**
as of this checkpoint. Do not promote this provisional BBOX
to shipped production while bottom/right/left live pointer,
hover/popup, host visual quality, true multioutput/lifecycle
and canonical-wide gates remain outstanding.


## Follow-up: new top A/B run is INCONCLUSIVE on first candidate exterior witness

The temporary-clone run has produced a new real,
unique exact-source report
`docs/wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json`,
source `1518db798d1012592cdbceb29115cceb72cffd9b`,
overall **INCONCLUSIVE**. The full-host production
disabled-center and enabled-exterior controls both aligned
with the requested coordinates, and its enabled body
click reached both the production bridge and the real
private Rust daemon. The old full-host empty margin
remained blocked. After destroying the old production
stage and remapping the private BBOX candidate in the
SAME nested output, the FIRST candidate enabled-exterior
underlay click occurred at an **off-target** location.
No candidate body, margin or bottom-edge measurements
were performed in this new run. All private layers,
Rust processes and nested Niri were cleaned, and host
output count remained unchanged.

This outcome does NOT overturn the separately
source-pinned top-edge private-mask PASS from
`124f02155679949e60a810e54a9c216fbfd2fabe`,
but does require investigation of physical pointer
repeatability across stage remapping before using
the newer dynamic BBOX generator to qualify bottom.
Do not label an off-target *underlay* click a Wull
mask defect. Do not increase positional tolerance
or silently retry until a flaky first event disappears
and then mark the run PASS.

New read-only, source-only retrospective helper
`scripts/wull-private-pointer-drift-diagnostic.py`
(created `55907217e8e1a18d9ae74cc5b129578db45f1aa8`,
receipt-symlink check fixed
`a0f1e06f2f934298312e19a2df74563e604bc395`)
takes that ONE sanitized report and finds its
private exact-run underlay log by the report's
random session ID in the current user's
`XDG_STATE_HOME/hadalis/wull-pointer-<id>`
(or `~/.local/state`). It requires the exact
five-check observed sequence, exactly three
real left-click underlay witnesses, valid
same-source suffix and the forced native wdotool
backend. It compares the first production exterior
witness and the candidate exterior witness,
which deliberately share the **same** requested
coordinates, and returns only horizontal/vertical
direction categories and a coarse maximum-offset
bucket. It also checks whether the candidate
event landed near the earlier disabled-center
witness, a possible stale-event indicator.
No absolute mouse coordinates, raw log or private
environment data enter GitHub. The helper does
NOT move the pointer, run Quickshell or change
the checkout. Independent synthetic/parser tests
were added in
`06c640e1ee1385e75524c6c3eb2a3650c2ffa031`.

NEXT: obtain this read-only categorical
diagnostic from the maintainer's **existing**
private log. If the log is missing or the
witness count is ambiguous, keep the result
INCONCLUSIVE and design a new explicit
bounded isolated pointer instrumentation,
not a blind repeated full-suite retry.
Avoid speculative timing or driver workarounds
until that evidence exists. The existing
bottom-edge candidate source remains STAGED,
not physically qualified. Production region,
default-off and `stable` remain unchanged.


## Retrospective old-log classification can now publish sanitized evidence from isolated clone

The earlier dynamic private top candidate report
`docs/wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json`
is still **INCONCLUSIVE** on its first candidate exterior coordinate
witness. No second real top pass and no bottom real receipt have been
published as of the source-only next gate. The old private underlay log
may still hold a precise explanation about whether the candidate first
exterior hit deviated horizontally, vertically or possibly reflected
a stale previous position. Without that private observation, it is
incorrect to choose a timing adjustment, increase tolerance, rewrite
production, or assert a virtual-pointer backend fault.

`scripts/wull-private-pointer-drift-publish.py` (source-only commit
`dc06dd36aabc688f1945205bb4a814c58f91d90e`) is a separate
**explicit opt-in retrospective** publisher. It requires a fresh,
clean, permission-private `dev` clone under
`${XDG_STATE_HOME:-~/.local/state}/hadalis/wull-drift-publish.*/repo`,
verifies the trusted GitHub origin/push URLs, exact old public
report blob, exact reviewed read-only diagnostic script blob and
ancestry of the original source SHA, and reads ONLY the original
run's existing private underlay log. It requires exactly the known
off-target receipt sequence and exactly three left-button underlay
witness records. It constructs a strict public schema consisting of
pre-reviewed classification enums, a single boolean for proximity
to the old disabled-center witness, Git source provenance and
explicit no-input/no-production-change annotations. It never
publishes or prints raw screen coordinates, raw logs, usernames,
session paths, screenshots or private runtime endpoints.
Its distinct fixed-name JSON report is
`docs/wull-pointer-drift-20261001T170950Z-105fd7a8-1518db798d10.json`.
It refuses to overwrite an existing report.

The clone-only publisher synchronizes by **fast-forward** on fresh
`dev`, creates only its own sanitized report commit, pushes
non-forced, and, if another Cloud Bot publishes concurrently, may
rebase ONLY its own single unpublished sanitized report after
verifying the old parent is an ancestor, current exact source pins
still hold, and the changed path is exclusively its own report.
It does not fetch/merge/rebase/reset the maintainer's original
potentially diverged checkout. If the private prior-run log has
been deleted or cannot prove an unambiguous three-event
sequence, publishing stops **INCONCLUSIVE**, and no new
cursor action is taken.

`scripts/test-wull-private-pointer-drift-publish-contract.py`
(added `fbd1e709b0b64046afa9e619426e409973dce59b`)
provides an inert payload sanitization and explicit-action
safety contract. This new helper and contract are source-staged;
their run result and old-log classifications must not be
represented as successful before a real local invocation.

An independently researched possible future discriminator,
NOT an identified cause: the external `wdotool`
documentation confirms the `wlr-protocols` backend issues
absolute `motion_absolute` using an enumerated output
and documents `wdotool prime` for maintaining virtual
input devices between commands. Upstream testing notes
the importance of compositor roundtrips for dispatch
reliability:
https://github.com/cushycush/wdotool and
https://github.com/cushycush/wdotool/blob/main/docs/testing.md .
The existing Wull child currently invokes `mousemove`
and `click` in separate short-lived CLI processes.
This makes persistent-input-session behavior a
**hypothesis to test only after** the existing private
log classification has been received. Do not introduce
`prime`, host-global input or a new backend on assumption.


## Retrospective drift verified; new pre-candidate witness and output-geometry guard

New real read-only retrospective evidence was published on `dev`:
`docs/wull-pointer-drift-20261001T170950Z-105fd7a8-1518db798d10.json`
at publisher source `5164395aea401bcfcd79fa8e74622d34fe5fceb5`.
The source-verified classifier consumed exactly three old, previously
private, underlay left-button witnesses from the
`1518db798d1012592cdbceb29115cceb72cffd9b` A/B session.
The candidate's first exterior event, versus the earlier
production exterior event at the **same requested location**,
was classified `offset_bucket=ninety_six_or_more`,
`offset_axes=both`, negative horizontal and positive vertical.
It was NOT near the old disabled-center witness. These are
categorical results only: maximum-axis magnitude at least 96
logical pixels; exact x/y remain private, and no extra pointer
injection was performed by the classifier. Thus a simple replay
of the old disabled-center coordinate is not supported. This
still does NOT identify whether the transient position originated
from the virtual pointer's device lifecycle, Niri remapping,
underlay geometry, race/order or a changed output mode. The
candidate's input mask should not be altered on this evidence.

A source-only, explicitly opted-in **differential** follow-up
was added in `scripts/wull-manual-pointer-child.py` commit
`5b79c09aabb2f5b50895d0d4c0b38c86cffe4248`.
The same one-output/private Rust/Niri source-verified pointer
runner now uses `output_geometry_signature` to require that
the one live nested output retains its initial logical x/y,
width/height, scale and current mode **before every native
motion/click command**. Unknown/changing geometry stops
the test inconclusively; it is not accepted as a valid mask
failure. After the full production baseline controls PASS
and its original layer and private daemon have fully
stopped/unmapped, but BEFORE mapping the candidate, the
child now injects ONE independent real exterior left-click
on the unchanged full-output underlay, with the **exact same
target** used in both other exterior controls.
This `after_baseline_unmap_exterior_underlay_control` must
report `target_alignment=matched`. If already off-target,
the run is **INCONCLUSIVE** with reason
`post_baseline_unmap_pointer_target_unverified`, assigning
investigation to the intermediate stage rather than the
candidate mask. If matched, only then does it map the
temporary candidate, require a new true Rust-present signal,
and perform its already-existing separate first candidate
exterior coordinate check. A later candidate-only
`off_target` narrows the investigation to the interval
after the new private layer remap (but STILL is not
proof that candidate QML mask itself is faulty).
All events remain solely in owned nested Niri with
`wdotool --backend wlr-protocols`; no host-global
input, new dependency, auto-retry, loosened tolerance,
raw coordinate publication or production source edit.
The old top-size1 and both new top/bottom options
remain explicit separate modes, with the bottom gate
requiring a fresh independent top PASS on the CURRENT
dynamic generator first.

Coordinator commit
`3ede937c9b70284de76dcb5fc1724abe0da09500`
re-pins that exact reviewed child and advances its
self-revision guard from 11 to 12.
`7a4a935afa99a1712bbeba7e4e7d0928de0b01c4`
adds inert pure logical-geometry drift, invalid topology
and child source marker checks to the existing pointer
contract; `485cc1ec307980c9cc07af1ecccc7ea5ad75462a`
re-pins the candidate-mask contract and requires
the intermediate control. These updated inert tests
are SOURCE-STAGED, **not yet executed on local Niri**.
The next grouped local execution needs all four original
inert pointer contracts followed by **one** full
exact-source top-edge differential probe. Only if the
new top probe produces a complete independently verified
PASS is a subsequent bottom-edge probe authorized.
Neither the prior old-generator top PASS nor the
current old-run classifier means that the new dynamic
four-edge candidate has been physically accepted.

Upstream documentation: wdotool's native
`wlr-protocols` backend implements absolute
`motion_absolute` in output pixel coordinates; its
`prime` command can keep virtual devices alive between
CLI invocations. This is a plausible *alternative
hypothesis*, NOT independently validated as the cause,
and is deliberately not enabled by this differential
probe. See https://github.com/cushycush/wdotool .
