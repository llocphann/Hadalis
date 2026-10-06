# Cross-repo optimization handoff

## 2026-10-06 — Maintainer-scoped Screen Edge analytic renderer

The maintainer explicitly prioritized Screen Edges before Wull and authorized
implementation in two classes: strict-lossless changes, and very small visual
deviation only when it buys a large rendering reduction. This checkpoint is
separate from the generic research-only optimization program.

### Implemented healthy path

- `modules/screenCorners/ScreenEdgeField.frag` +
  `ScreenEdgeField.qml` are the normal physical Screen Edge painter.
- The healthy path is one output-local analytic rounded-box SDF
  `ShaderEffect`: **zero texture samples, zero ShaderEffectSource capture,
  zero blur-pyramid intermediates and zero MultiEffect pass**.
- The accepted historical odd-even `ShapePath` / four-`PathArc` /
  `MultiEffect` renderer remains available only through a lazy
  `ShaderEffect.Error` Loader. It is not constructed on a healthy shader path.
- The exact existing frame insets, Bar-owned edge thickness, radius token,
  reservation windows, mapping/fullscreen lifecycle and click-through ownership
  remain unchanged.
- Shader QColor inputs use Qt's premultiplied representation correctly; no
  second alpha multiplication is applied.
- The inward physical shadow uses a three-band analytic response
  (sharp shoulder / middle rolloff / faint tail) chosen to track the accepted
  Qt 6.11 MultiEffect profile without sampling the blur pyramid.
- Deep workspace fragments are rejected before `length`, `fwidth` and
  `smoothstep`. The guard is geometry-safe and is covered by 50,000
  deterministic randomized cases. At the default 1920x1080 / 10 px frame /
  25 px radius / 15 px shadow geometry, about **92.9% of output pixels** fall
  into that guaranteed deep-interior early-return region. This is a structural
  fragment-work reduction, not a measured whole-GPU speedup percentage.
- The physical shadow work remains disabled when a fullscreen client covers the
  output and in minimal Game Mode, while the FrameWindow mapping lock remains
  intact.
- Screen Edge workspace-Overview support is lazy: bottom/left/right reservations
  no longer instantiate unusable Overview stacks, and a normal horizontal-Bar
  configuration retains no workspace-Overview support stack in Screen Edges.

### QSB source identity

`.github/workflows/screen-edge-shader-bake.yml` builds the shader twice and
requires byte equality between those two same-toolchain outputs. Publication is
fail-closed: it verifies that current `dev` still contains the exact GLSL
source that was baked before updating only
`modules/screenCorners/ScreenEdgeField.frag.qsb`.

The QSB corresponding to the current three-band field was published by commit
`f5e5a2ae232303c5f012ae87463472c362c490fa`. Later commits in this checkpoint
change tests/docs/job dispatch only, not the shader source.

### Validation status

At exact checkpoint `44a1b978c358d05eb3b67e5d9f48647dc415f0d2`,
the repository-wide CI invocation of the canonical validator reported:

- `test-screen-edge-analytic-field-contract.py`: PASS;
- `test-screen-edge-analytic-perceptual.py`: process PASS (owner-session visual
  mode was not enabled by canonical CI, so this is not live visual acceptance);
- `test-screen-edge-shadow-padding-parity.py`: PASS;
- `test-screen-edge-shadow-raster-perceptual.py`: process PASS (same
  owner-session qualification caveat);
- `test-shell-elevation-shadow-contract.py`: PASS;
- `test-shell-surface-contracts.py`: PASS;
- `test-bar-orientation-module-sync.py`: PASS;
- `test-performance-lifecycle.sh`: PASS;
- documentation contracts: PASS.

The same canonical run completed **417 PASS / 11 FAIL / 12 SKIP**. None of the
11 failures were Screen Edge failures; they were existing Abyss/Wull and
MegaQML checks outside this scoped task. Do not present that run as a repository
canonical PASS.

The deterministic local worker has not published analytic Screen Edge receipts:
R63 through R69 remain pending while results stop at R62. Therefore the
authoritative local canonical PASS is **not claimed** for this checkpoint.

### Remaining acceptance boundary

Implementation/source work for this Screen Edge optimization is complete.
Two environment-owned acceptance items remain separate and must not be inferred
from source inspection:

1. run the analytic-vs-pre-cutover owner-session A/B with
   `HADALIS_SCREEN_EDGE_ANALYTIC_PERCEPTUAL=1` and retain the reported
   `global_mae` / edge-band diagnostic; the intended budget is <= 1% global
   normalized mean pixel error;
2. visually verify real Niri/Quickshell idle/maximized/fullscreen,
   top/bottom/left/right Bar ownership, fractional scaling and multi-output
   behavior on the exact runtime SHA.

No whole-Hadalis CPU/GPU/RAM/FPS percentage is claimed without before/after
measurement.


## 2026-10-06 — Screen Edge strict-lossless continuation checkpoint

This section supersedes the earlier full-output analytic-painter implementation
details while preserving the same visual/SDF contract. The maintainer requested
continued Screen Edge optimization with strict-lossless changes preferred and a
visual budget below 1% only where necessary.

### Additional implemented reductions

- **Adaptive four-tile rasterization.** The analytic field is no longer drawn as
  one full-output quad. Four disjoint `ShaderEffect` tiles cover only the
  perimeter region that can produce non-zero pixels; the centre is never
  rasterized. All tiles evaluate the same output-local SDF through `tileRect`.
- **Cheapest-axis partition selection.** The wrapper evaluates horizontal-corner
  and vertical-corner four-tile partitions and selects the smaller raster area
  without adding draw calls. At the default 1920x1080 / 10 px inset / 25 px
  radius / 15 px shadow geometry, the structural fragment-invocation footprint
  is below **9.7% of the output**; at 3840x2160 it is below **4.9%**. These are
  raster-area ratios, not measured GPU speedup percentages.
- The 50,000-case geometry oracle proves every omitted pixel belongs to the
  already-proven transparent deep-interior region. The owner-session
  `test-screen-edge-banded-perceptual.py` separately retains the <=1% global
  normalized-MAE budget for seam/derivative verification.
- **Exact SDF fast paths.** Straight-edge samples skip Euclidean
  `length/sqrt`; a 200,000-case float32 oracle requires bit-identical output
  against the canonical rounded-box formula. Exact outside/inside AA/shadow
  regions also bypass unnecessary smoothstep/composition work.
- **Minimal safe band bounds.** Conservative padding that was not needed by the
  proven SDF/shadow reach was removed; per-side shallow/deep extents retain the
  complete corner/shadow support.
- **Covered-frame sleep.** The physical FrameWindow remains mapped across
  fullscreen as required by the stacking lock, but `updatesEnabled` is false
  while the fullscreen client completely covers it.
- **Transparent reservation sleep.** Bottom/left/right reservation windows
  paint nothing and no longer render-update. The top reservation renders only
  when vertical-Bar workspace-Overview hover support is actually available;
  mapping, exclusive-zone and input-mask state remain independent.
- **Legacy type-graph isolation.** `QtQuick.Shapes` and `QtQuick.Effects`
  moved into `ScreenEdgeLegacyFallback.qml`, loaded by URL only after aggregate
  tiled `ShaderEffect` failure. The healthy ScreenEdges.qml path no longer
  imports or embeds the legacy Shape/MultiEffect graph.
- **Output-targeting allocation removal.** The old
  `Quickshell.screens.filter(...)` temporary result array is replaced by a
  complete-order scan that records only whether any configured output exists.
  A 50,000-case behavior/read-order oracle preserves answers and full screen
  traversal/dependency order.
- **Fallback bridge binding compaction.** The inactive legacy Loader previously
  kept ten value-proxy bindings per output (four insets, radius, padding,
  shadow state/size/color and edge color) resident even though the fallback
  renderer was not loaded. The healthy path now retains only two object
  references (`edgeRoot` + `frameHost`); all fallback value bindings are
  instantiated only after an actual tiled ShaderEffect error. This removes
  **8 resident fallback bindings per output** without changing fallback values
  or visual behavior.

The current analytic QSB containing the exact-SDF fast paths was published by
`f7d8d2d282326c2f906f2c385cca19ee5d1660f2`. Later commits in this
checkpoint change QML partitioning, lifecycle gating, tests and documentation;
they do not change the fragment shader source.

### Scoped validation

At exact runtime/source checkpoint
`254f7d3db6a787d6cdda444c778d3750fd574f83`, the repository-wide CI
invocation of the canonical validator completed **419 PASS / 11 FAIL / 12
SKIP**. The dedicated Nix package workflow for the same exact SHA also
completed successfully. All Screen Edge and connected-perimeter checks relevant to this work
passed, including:

- `test-screen-edge-analytic-field-contract.py`;
- `test-screen-edge-banded-perceptual.py` in its canonical process/skip mode;
- `test-screen-edge-output-targeting.py`;
- `test-screen-edge-shadow-padding-parity.py`;
- `test-shell-elevation-shadow-contract.py`;
- `test-shell-surface-contracts.py`;
- `test-bar-orientation-module-sync.py`;
- `test-performance-lifecycle.sh`;
- `test-perimeter-compatibility-placement-contract.sh`;
- packaging/make contracts and source-tree cleanliness.

The remaining 11 failures are existing Abyss/Wull and MegaQML checks outside
this scoped Screen Edge task. Therefore this is a **scoped Screen Edge
validation checkpoint**, not a repository-wide canonical PASS. The CI host also
lacked `qmlformat`, so the strict parser pass remains unclaimed on this exact
SHA.

The deterministic local worker remains stalled with Screen Edge results ending
at R62 while R63-R69 remain pending. Do not create additional duplicate worker
jobs until that transport/backlog issue is resolved.

### Completion boundary

The current Screen Edge optimization implementation pass is complete through
`254f7d3db6a787d6cdda444c778d3750fd574f83`. No further runtime candidate is
promoted here because remaining ideas either add draw-call complexity, alter
QML reactive topology, or produce only micro-level savings relative to the
already-bounded raster footprint.

Live owner-session acceptance remains separate:

1. run `HADALIS_SCREEN_EDGE_BANDED_PERCEPTUAL=1
   python3 scripts/test-screen-edge-banded-perceptual.py` and retain
   `global_mae`, `edge_mae` and `max_channel_delta`; intended global budget
   is <=1%;
2. run the existing analytic-vs-pre-cutover visual fixture if historical visual
   comparison is still desired;
3. verify real Niri/Quickshell multi-output, fractional scaling, Bar ownership
   and fullscreen transitions.

No whole-Hadalis CPU/GPU/RAM/FPS percentage is claimed without before/after
measurement.

## 2026-10-06 — subsystem removal boundary

The maintainer removed the Hadalis Automation subsystem and the MegaQML/MEGAcmd
Cloud Storage integration from current `dev`. Older worker queues/results,
MegaQML failures, Cloud Storage qualification notes and exact-SHA validation
counts above are historical evidence only; they are not current runtime,
packaging or validation dependencies. Future work must use repository tests and
the canonical maintainer validator directly and must not dispatch local worker
jobs or expect MegaQML/Cloud Storage routes.

## 2026-10-07 — Wallpaper thumbnail queue strict-lossless research

Research-only continuation on current `dev`
`08fcc563311cde0e218672f4f97df006377e7a61`. No runtime/product source was
changed in this round.

Current source identities:

- `services/Wallpapers.qml`:
  `162dc98dcb742d7dec918a1da01659ef64265330`;
- `modules/common/widgets/ThumbnailImage.qml`:
  `64386a41505f5b1a3dc4942b2a549b04d0f0cf59`;
- `scripts/thumbnails/thumbgen.py`:
  `fdc9ce7e4557a4296e45e8d25aea9101caf90fa1`.

Repository/history search found no prior optimization note for
`_singleThumbPending`, `_knownThumbnailOutputs` or `_ffPending`.
This is distinct from the older Dashboard projection/overlap research.

### Candidate A — HIGH CONFIDENCE: stop cloning private thumbnail bookkeeping maps

`Wallpapers` currently uses copy-on-write for two private maps:

```qml
const pending = Object.assign({}, root._singleThumbPending)
pending[key] = true
root._singleThumbPending = pending
```

and:

```qml
const nextKnown = Object.assign({}, root._knownThumbnailOutputs)
nextKnown[normalizedPath] = true
root._knownThumbnailOutputs = nextKnown
```

The corresponding delete paths clone again before deleting the key.

Repository-wide search shows:

- `_singleThumbPending` is read/written only inside `Wallpapers.qml`;
- `_knownThumbnailOutputs` is exposed only through imperative
  `hasKnownThumbnail()/rememberThumbnail()/forgetThumbnail()`;
- no QML binding, `Connections`, change handler or external consumer depends
  on either property's change notification.

Therefore the copy-on-write reassignment is not part of the observable
contract. Directly mutating the private object preserves the current
dedup/existence answers while avoiding whole-map copies.

The allocation shape is materially worse than O(n): enqueueing n distinct
single-thumbnail requests copies approximately 0+1+...+(n-1) keys; draining
them copies the shrinking pending map again. The known-output set similarly
copies all previously known thumbnail paths on each newly learned path.
This can become quadratic JS key-copy/allocation work while browsing a large
wallpaper library.

Required oracle before implementation:

1. enqueue repeated and distinct thumbnail keys;
2. prove one queued request per unique pending key;
3. finish requests in success/failure order and prove pending membership parity;
4. prove `hasKnownThumbnail` answers are identical across remember/forget;
5. include empty/malformed paths and source-size changes.

No visual deviation is expected; this is bookkeeping-only.

### Candidate B — HIGH CONFIDENCE, protocol-gated: eliminate post-batch per-delegate `test -f` process fan-out

`ThumbnailImage.reloadThumbnail()` starts a dedicated Process when a thumbnail
path is not already in the shared known set:

```qml
_thumbnailCheckProc.command = ["test", "-f", targetPath]
_thumbnailCheckProc.running = true
```

The component is used by Quick Wallpaper, wallpaper selector directory/grid,
Coverflow, Skew, Waffle quick/background and related wallpaper surfaces.
Generation itself has already been centralized to avoid one
ImageMagick/ffmpeg process per delegate, but existence verification remains
per instantiated `ThumbnailImage`.

The batch generator already reports progress through stdout. However the
current machine protocol is **not a success protocol**:

```python
for result in p.imap(make_thumbnail, all_files):
    completed += 1
    print(f"PROGRESS {completed}/{total} FILE {all_files[completed - 1]}")
```

`make_thumbnail()` returns `False` both for an already-fresh cache entry and
for generation failure, and the parent currently ignores `result`.
Therefore QML must **not** treat the current `FILE` token as proof that the
thumbnail exists.

Strict-lossless direction:

1. extend the machine-progress protocol so the Python parent reports whether
   the expected thumbnail path exists after each worker result, e.g.
   `READY <source>` vs `FAILED <source>`;
2. compute that readiness in Python with in-process filesystem metadata, not a
   subprocess;
3. on READY, QML calls `rememberThumbnail(getExpectedThumbnailPath(...))`
   before emitting the existing source-file notification;
4. affected delegates then hit the shared known set and avoid their immediate
   `test -f` process;
5. FAILED retains the current fallback/generation behavior and must not be
   marked known.

The shell fallback generator
`generate-thumbnails-magick.sh` does not expose per-file machine progress, so
its rare fallback path can retain the existing end-of-directory reload/check
behavior unless separately measured.

Required evidence before promotion beyond HIGH CONFIDENCE:

- a fixture with fresh, newly generated and intentionally failed inputs proving
  READY/FAILED classification;
- identical delegate visible state and generation retry behavior;
- process-count comparison for a representative gallery open.

### Candidate C — CONFIRMED lifecycle asymmetry, but do not call the failure fix strict-lossless

The video first-frame dedup map currently does:

```qml
if (root._ffPending[videoPath]) return
root._ffPending[videoPath] = true
```

and no current source path deletes that key.

On success, `videoFirstFrames[videoPath]` is populated, so the stale pending
entry no longer changes subsequent answers because the success cache is checked
first. Removing the pending key inside `_cacheFirstFrame()` is therefore a
strict-lossless memory cleanup for successful paths.

On generation/check failure, however, the pending key remains true for the rest
of the shell session. That suppresses all retry attempts for that video. Simply
deleting the key on failure would change current behavior and could also create
a repeated ffmpeg retry loop when a reactive surface keeps asking for a bad
video.

Treat the failure side as a separate correctness/lifecycle decision, not as an
optimization. If product repair is authorized later, use an explicit failed
state with bounded retry/backoff rather than conflating “in flight” and “never
retry this session”.

### Non-candidates checked in this pass

- `KeyboardIndicators` lock-state maps are rebuilt from the current discovered
  LED path set by `_setLockPaths()`; stale device paths are pruned there, so
  the per-path copy-on-write code is not an unbounded session leak and the maps
  are normally tiny.
- `WindowPreviewService` explicitly prunes previews against the authoritative
  compositor window list and bounds decoded overview warm images to 12. Do not
  reopen it as a generic cache-growth candidate without new runtime evidence.
- `videoFirstFrames` itself must remain copy-on-write in the current design
  because multiple QML consumers deliberately depend on that property changing
  to refresh Image/ColorQuantizer bindings.

### Next measurement/research order

1. build a source-level oracle for Candidate A's private-map mutation parity;
2. inspect/fixture the thumbnail machine-progress protocol for Candidate B;
3. measure gallery process count before considering implementation;
4. then leave wallpaper thumbnails and diversify into another high-value hot
   path rather than accumulating micro-candidates in the same subsystem.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed from static analysis.

## 2026-10-07 — App identity-rule lookup hot-path research

Research-only continuation on `dev`
`5b1a7d44d7b66a84318f19c998ea32fe47ebd9b8`. No runtime/product source was
changed in this round.

Current source identities:

- `services/AppSearch.qml`:
  `74ea3c9e92860af62f10850c89118d79b7837543`;
- `services/TaskbarApps.qml`:
  `b05b0b39988a40faf7fa3cb84e6b0c747cf4a3ee`.

Repository/history search found no earlier optimization note for
`_parseIdentityRules()`, `_identityRulesKey` or the per-window
`JSON.stringify(appIdentityRules)` path.

### Candidate A — HIGH CONFIDENCE: move identity-rule cache validation out of every window lookup

`AppSearch` correctly caches the compiled regular expressions, but validates
that cache by serializing the entire configured rule list every time
`resolveWindowIdentity()` is called:

```qml
function _parseIdentityRules(): var {
    const rules = Config.options?.windows?.appIdentityRules ?? []
    const key = JSON.stringify(rules)
    if (root._identityRulesKey === key)
        return root._identityRules
    ...
}

function resolveWindowIdentity(toplevel): string {
    ...
    const rules = root._parseIdentityRules()
    ...
}
```

This means a cache hit still performs a complete `JSON.stringify(rules)`.

That lookup is used inside collection passes by:

- `TaskbarApps.qml`;
- `DockApps.qml`;
- `BarTaskbarPreview.qml`;
- `BarTaskbar.qml`;
- `AltSwitcherNoVisual.qml`;
- `AltSwitcher.qml`;
- `WaffleTaskViewContent.qml`.

For a pass over N windows, one unchanged identity-rule list can therefore be
serialized N times before the already-cached RegExp list is reused. Several
surfaces perform their own N-window passes, so this work can repeat again for
the same compositor snapshot.

The config schema already exposes:

```qml
property JsonObject windows: JsonObject {
    ...
    property list<var> appIdentityRules: []
}
```

and current `TaskbarApps` already relies on
`Config.options.windows.onAppIdentityRulesChanged`. The narrower invalidation
signal therefore exists today; no new Config API is required.

Strict-lossless direction:

1. keep the parsed rule array resident in `AppSearch`;
2. parse/rebuild it on initial use/Config-ready and on
   `appIdentityRulesChanged`, rather than fingerprinting it for every window;
3. let `resolveWindowIdentity()` read the current parsed array directly;
4. if `Config.options.windows` can be replaced during file reload, keep the
   `Connections.target` bound to the current object so the handler follows
   replacement;
5. preserve lazy desktop-entry resolution exactly as today: `desktopId` stays
   a string in the parsed rule and is not resolved during parsing.

Behavior that must remain byte-for-byte/logically equivalent:

- first matching rule wins;
- app-id regex and title regex are independently optional;
- at least one regex must be present;
- malformed regex rules are ignored;
- matching stays case-insensitive;
- empty app IDs return immediately;
- rules with missing/empty `desktopId` are ignored;
- rule ordering and configured object read order remain stable.

Required oracle before implementation:

- empty list;
- app-id-only/title-only/both-regex rules;
- malformed regex mixed with valid rules;
- multiple matching rules proving first-match ownership;
- repeated lookup of the same and different windows;
- rule-list replacement between lookups;
- Config object reload/replacement if the runtime can recreate the nested
  JsonObject;
- compare both result strings and malformed-rule behavior against current
  source.

Structural saving only: unchanged-rule cache validation becomes O(1) per window
lookup instead of serializing the rule list per lookup. No whole-shell CPU
percentage is claimed without runtime measurement.

### Candidate B — HIGH CONFIDENCE companion cleanup: Taskbar's identity revision is currently redundant

`TaskbarApps` owns:

```qml
property int _identityRulesRevision: 0
...
function onAppIdentityRulesChanged() {
    root._identityRulesRevision++
    refreshApps.restart()
}
...
function computeApps(): var {
    const identityRulesRevision = root._identityRulesRevision
    ...
}
```

Full-file occurrence inspection finds only those three references. The local
`identityRulesRevision` value is never consumed after assignment.

Because `computeApps()` is called imperatively by the 16 ms
`refreshApps` timer, the property read does not establish a live property
binding for `root.apps`. The same change handler already directly restarts
`refreshApps`, which is the actual invalidation mechanism.

After Candidate A establishes AppSearch's own rule invalidation, this revision
counter/read can be removed as a strict-lossless cleanup. Its standalone
resource value is negligible; keep it grouped with the identity-rule work
rather than advertising it as an independent optimization.

### Candidate C — LOWER PRIORITY: cache Taskbar ignored-app RegExp compilation only with log parity

Every `TaskbarApps.computeApps()` also rebuilds RegExp objects for configured
`dock.ignoredAppRegexes` plus the fixed system ignore patterns. Window list
changes can therefore recompile an unchanged pattern set.

The RegExp flags are only `i`, so successful regex instances have no
`lastIndex` state and are safe to reuse for matching. However invalid patterns
currently emit a warning each time `computeApps()` recompiles them. Silently
caching parse failures would change diagnostic log frequency.

Do not promote this as a trivial cache unless the implementation preserves that
observable diagnostic contract, e.g. cache valid compiled expressions and the
ordered invalid-pattern list while re-emitting the same warnings when the
current compute path would have done so. Given normal ignored-pattern counts,
this ranks below Candidate A.

### Non-candidates / corrections in this pass

- Do not claim `TaskbarApps.Config.onOptionsChanged` is equivalent to the
  explicit `Config.configChanged` signal. `Config.options` is an alias to a
  JsonAdapter object, and static source alone does not prove that its top-level
  `optionsChanged` fires for every nested mutation.
- Notification group reconstruction remains a real multi-pass candidate, but it
  was already recorded elsewhere in the optimization research as a
  notification derived-state single-pass direction. It is not counted again as
  a new finding here.
- Waffle Task View's wallpaper blur tree is instantiated only while Task View is
  open and captures a horizontal strip rather than the entire output. Static
  source alone does not justify a new residency/blur optimization claim.
- Current ScreenTime on Niri is already focus-event-driven with a coarse
  30-second heartbeat; no new high-confidence source-only polling reduction was
  established in this pass.

### Next research order

1. build a behavioral/read-order oracle for Candidate A;
2. benchmark rule-list sizes and window counts only if implementation is later
   authorized;
3. inspect another distinct collection hot path rather than expanding this into
   speculative AppSearch micro-caches.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed from static analysis.

## 2026-10-07 — Bar Taskbar pinned-order research

Research-only continuation on `dev`
`050a8b19059a150bacb9f97759592dab06ee0394`. No runtime/product source was
changed in this round.

Current source identities:

- `modules/bar/BarTaskbar.qml`:
  `3aca1b63e2633584c86f75c6a2e5eb2ebaebfdb3`;
- sibling reference `modules/dock/DockApps.qml`:
  `11b3ea8cc17c91a1cf3b6a1f41f64f392d4dfcc9`.

Repository/history search found no prior optimization note for
`BarTaskbar`'s `pinnedApps.findIndex()` comparator path.

### Candidate — HIGH CONFIDENCE: precompute pinned rank once per Bar Taskbar rebuild

When `dock.separatePinnedFromRunning` is enabled, `BarTaskbar` constructs
`sortedRunningApps` and sorts it with:

```qml
const aIndex = pinnedApps.findIndex(p => p.toLowerCase() === a.lowerAppId)
const bIndex = pinnedApps.findIndex(p => p.toLowerCase() === b.lowerAppId)
...
```

After the sort it again computes:

```qml
pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId)
```

The comparator can run O(R log R) times for R running app groups, and every
comparison linearly scans P pinned entries while lowercasing them. The final
publication then performs another O(R * P) membership scan.

The sibling Dock implementation has already eliminated this shape. It builds
one lowercase `pinnedOrder` Map before sorting and uses Map membership/rank
inside its comparator.

Strict-lossless Bar direction:

1. build one lowercase pinned-rank Map at the beginning of the separate-mode
   branch;
2. use Map membership/rank inside the existing comparator;
3. keep the Bar's current unpinned fallback ordering
   `lowerAppId.localeCompare()` — do **not** copy Dock's running-order fallback;
4. publish `pinned` from Map membership instead of rescanning
   `pinnedApps.some(...)`.

Important duplicate/case oracle:

Current `findIndex` returns the **first** case-insensitive occurrence. A naive
Map built with unconditional `set()` would instead retain the last duplicate
rank. Therefore the strict-lossless map must only set a lowercase key when it
is not already present.

Required behavioral oracle:

- empty pinned list;
- all-running unpinned apps;
- mixed pinned/running apps;
- duplicate exact pins;
- case-variant duplicate pins;
- pinned app missing a desktop entry;
- alphabetical order among unpinned running apps;
- separator placement and focused/running flags unchanged.

This removes repeated pinned-list scanning from each sort comparison and from
final membership publication. No whole-shell CPU percentage is claimed without
runtime measurement.

### Adjacent paths checked

- `DockApps.qml` already uses a precomputed pinned-order Map in the equivalent
  separate-mode sort; do not rewrite it.
- Both Dock and Bar already cache ignored-app RegExp objects. Their cache-hit
  check still serializes the small configured pattern list, but this ranks below
  the AppSearch identity-rule serialization finding because it happens once per
  model rebuild, not once per window.
- Compositor sorting is already demand-leased and debounce-limited; no new
  source-only lifecycle reduction was established in this pass.

### Next research order

Continue with another distinct high-value collection/process/render path rather
than multiplying taskbar micro-caches. Prefer a path where the same expensive
data transformation is demonstrably repeated within one event or visible frame.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed from static analysis.

## 2026-10-07 — Niri toplevel matching research

Research-only continuation on current `dev`
`580792f3785031cd79746b0305728503233d3652`. No runtime/product source was
changed in this round.

Current `services/NiriService.qml`:
`4c8194493fd380bf0ad8c51bc62990ad0c232738`.

Repository/history search found no prior optimization note for
`sortToplevels()`, `filterCurrentWorkspace()` or
`matchToplevelToWindow()`.

### Candidate — HIGH CONFIDENCE: bucket foreign toplevels by appId before Niri greedy matching

Both `sortToplevels()` and `filterCurrentWorkspace()` currently use the
same greedy nested match:

```qml
for (const niriWindow of ...) {
    let bestMatch = null
    let bestScore = -1

    for (const toplevel of toplevels) {
        if (usedToplevels.has(toplevel))
            continue

        const score = matchToplevelToWindow(toplevel, niriWindow)
        ...
    }
    ...
}
```

The matcher begins with:

```qml
if (toplevel.appId !== niriWindow.app_id)
    return 0
```

Therefore every comparison against a toplevel from a different app is
provably incapable of winning. On a desktop with W Niri windows and T foreign
toplevel handles, the current path can execute W*T matcher calls even when
nearly every window belongs to a different application.

Strict-lossless direction:

1. make one pass over the input `toplevels` and build
   `Map<appId, toplevel[]>`, preserving original toplevel order inside every
   bucket;
2. for each Niri window, scan only the bucket matching
   `niriWindow.app_id`;
3. preserve the existing `usedToplevels` rule inside each bucket;
4. keep `matchToplevelToWindow()` unchanged for title scoring;
5. preserve `sortWindowsByLayout(windows)` ordering in `sortToplevels()`;
6. preserve current workspace-window order in `filterCurrentWorkspace()`;
7. continue dropping all unmatched foreign handles so stale/ghost Wayland
   handles cannot reappear in Dock/Taskbar.

Why this is semantically safe:

- different-app candidates always score 0 today;
- a successful match always has score > 0;
- within one app bucket, retaining original toplevel order preserves tie
  behavior because the current algorithm updates only when
  `score > bestScore`, not on equality;
- an exact-title score 3 still stops scanning immediately;
- score-2 substring and score-1 same-app fallbacks retain the same candidate
  order and used-object exclusion.

The optimization changes only which candidates are known in advance to be
incapable of matching.

Expected complexity:

- bucket construction: O(T);
- matching: sum of same-app candidate scans rather than W*T global scans;
- worst case remains quadratic when every window belongs to the same app,
  which is necessary unless the title-scoring/greedy contract is redesigned;
- mixed-app desktops approach a much smaller comparison count.

This has broader leverage than a consumer-local taskbar cache because
`CompositorService.sortedToplevels` feeds Dock/Taskbar and other surfaces,
and `filterCurrentWorkspace()` contains the same matching debt separately.

### Required oracle before implementation

Use a pure helper/oracle with stable object identities and compare complete
matched source identity/order for:

- zero windows / zero toplevels;
- all unique app IDs;
- multiple windows of the same app;
- duplicate same-app/same-title handles;
- exact-title score 3;
- asymmetric substring score 2;
- same-app title mismatch score 1;
- mixed stale foreign handles absent from Niri;
- Niri window without a foreign handle;
- one foreign handle that could match multiple same-app Niri windows, proving
  used-handle exclusion and greedy order;
- reordered input toplevels to prove tie behavior follows current input order;
- workspace-filtered subset parity.

Ghost-window correctness is a hard boundary: unmatched foreign handles must
remain dropped exactly as current source specifies.

### Adjacent source notes

- `findNiriWindow()` also linearly scans `windows`, but its call frequency
  was not established as a hot path in this pass; do not merge it into this
  candidate without evidence.
- Do not replace greedy title scoring with a direct title Map. Duplicate titles,
  substring matches and one-handle-per-window ownership make that a behavioral
  redesign, not the strict-lossless bucket optimization above.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

