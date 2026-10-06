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

## 2026-10-07 — Niri layout-sort cache research

Research-only continuation on current `dev`
`3d607b1b01f9ec937122fdaf48bcfa938cafcfed`. No runtime/product source was
changed in this round.

Current `services/NiriService.qml`:
`4c8194493fd380bf0ad8c51bc62990ad0c232738`.

### Candidate — HIGH CONFIDENCE: cache the Niri layout-sorted window view instead of sorting it again on every toplevel match pass

`NiriService.windows` is already layout-sorted at the normal publication
boundary:

```qml
const nextWindows = sortWindowsByLayout(_pendingWindows)
windows = nextWindows
```

and it is explicitly re-sorted when output geometry changes. However
`sortToplevels()` still starts from:

```qml
for (const niriWindow of sortWindowsByLayout(windows)) {
    ...
}
```

so every compositor sort pass allocates another enriched array, sorts it and
maps it back before the actual Niri↔foreign-toplevel matching begins.

A direct replacement with `for (const niriWindow of windows)` is **not**
strict-lossless today. `handleWorkspacesChanged()` replaces the workspace map
and may change `ws.idx` or `ws.output`, both of which are sort keys, but it
does not reassign public `windows`; it only emits `windowOrderChanged()`.
The extra sort inside `sortToplevels()` currently repairs that derived order
before consumers observe it.

Strict-lossless direction:

1. maintain a private layout-sorted window view for matching;
2. refresh that view whenever any sort-key source changes:
   - normal batched window publication;
   - `WorkspacesChanged` (workspace index/output topology);
   - output geometry changes;
   - initial output fetch completion;
3. keep public `windows` assignments and `windowsChanged` signal count exactly
   as today;
4. let `sortToplevels()` iterate the private sorted view directly;
5. keep `windowOrderChanged()` emissions unchanged so current compositor
   scheduling remains intact.

The private-view requirement matters. Reassigning public `windows` from
`handleWorkspacesChanged()` merely to refresh order would introduce an extra
`windowsChanged` notification and could wake unrelated consumers; that is not
strict-lossless.

Expected structural saving:

- one `map -> sort -> map` pipeline is removed from each
  `sortToplevels()` call;
- sorting instead happens only when the authoritative inputs that determine
  layout order change;
- the benefit composes with the separate appId-bucket matching candidate:
  cached order removes redundant O(W log W) preparation, while bucketing removes
  impossible cross-app match comparisons.

Required oracle before implementation:

- window open/close/change publication;
- focus-only changes where layout order must not change;
- `WindowLayoutsChanged`;
- `WorkspacesChanged` changing workspace idx;
- workspace moved between outputs;
- `OutputsChanged` changing logical x/y;
- initial output fetch arriving after windows;
- zero-window transitions;
- verify public `windowsChanged`, `windowOrderChanged`,
  `activeWindowChanged` counts/order remain identical to the current source;
- compare complete `sortToplevels()` output identity/order before and after.

### Adjacent finding deliberately not promoted

`filterCurrentWorkspace()` currently filters from public `windows` and does
not call `sortWindowsByLayout()`. That means its order semantics differ from
`sortToplevels()` after a workspace-topology-only change until another public
window sort occurs. This is potentially a correctness consistency question, not
an optimization. Do not silently switch it to the new private view under a
strict-lossless patch without first establishing the intended consumer order.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Desktop-entry lookup memo research

Research-only continuation on current `dev`
`3153562a6dabe3d630360a3786a1e93461300547`. No runtime/product source was
changed in this round.

Current `services/AppSearch.qml`:
`74ea3c9e92860af62f10850c89118d79b7837543`.

Repository/history search found no prior optimization note for memoizing
`lookupDesktopEntry()` results.

### Candidate — HIGH CONFIDENCE: memoize exact desktop-entry lookup results per DesktopEntries epoch

`AppSearch.lookupDesktopEntry(appId)` already has good internal reverse maps,
but every call still restarts the whole lookup chain:

1. `DesktopEntries.heuristicLookup(appId)`;
2. direct lowercase/kebab map probes;
3. scoped/reverse-domain normalization candidates;
4. suffix stripping;
5. last-resort token-overlap scans across
   `_desktopIdStemMap` and `_startupClassMap`.

Many shell surfaces ask for the same application identity repeatedly across
model rebuilds and delegate bindings. Current callers include:

- `TaskbarApps.qml`;
- `DockApps.qml`;
- `BarTaskbar.qml`;
- Dock/Bar/Waffle task buttons;
- AltSwitcher;
- MPRIS hint resolution;
- ScreenTime history repair;
- Dock Settings;
- desktop-item validation/opening;
- icon-theme fallback paths.

A per-exact-input memo therefore avoids both repeated successful resolution and
repeated expensive misses.

Strict-lossless direction:

1. cache `appId -> DesktopEntry|null` after the current lookup chain finishes;
2. key by the exact incoming appId string rather than only lowercasing the key,
   so any behavior specific to `DesktopEntries.heuristicLookup()` input casing
   remains untouched;
3. distinguish an explicit cached miss from “not in memo”;
4. clear/invalidate the memo **immediately** in
   `DesktopEntries.applications.onValuesChanged`;
5. retain the existing 500 ms debounce for rebuilding the reverse maps;
6. keep the exact lookup precedence and token-score algorithm unchanged.

The immediate invalidation is required. Current source can observe a newly
installed/removed desktop entry through `DesktopEntries.heuristicLookup()`
before the debounced `_rebuildCache()` has rebuilt the local maps. If the memo
were invalidated only when `_cacheRevision` advances, a previously cached hit
or miss could remain stale for that debounce window.

This candidate can be implemented with a private JS Map or equivalent private
object; no QML binding or public change notification needs to depend on memo
mutation.

### Required oracle before implementation

Compare current and memoized lookup result identity for:

- exact desktop id/stem;
- StartupWMClass;
- executable basename;
- whitespace/kebab normalization;
- scoped IDs such as `@scope/app-desktop`;
- reverse-domain ids;
- suffix stripping;
- token-overlap fallback;
- no match;
- case variants;
- repeated hit and repeated miss;
- DesktopEntries add/remove/change between repeated lookups, including a change
  observed before the 500 ms reverse-map rebuild;
- malformed/unexpected but currently tolerated string inputs.

Cache invalidation must preserve the same first lookup result immediately after
a DesktopEntries change.

### Expected saving

Repeated lookup of an unchanged app identity becomes O(1) Map access rather
than re-running heuristic/normalization/token-overlap work. The structural gain
is largest for misses and unusual Electron/AppImage ids that fall through to
token scoring.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Clipboard/Booru image process research

Research-only continuation on current `dev`
`31665dcccb696c66741ca80d3d78a05f3159fd6d`. No runtime/product source was
changed in this round.

Current source identities:

- `modules/common/widgets/CliphistImage.qml`:
  `d210fa7c52aba17fddec09909cc464fe034ffa03`;
- `modules/sidebarLeft/anime/BooruImage.qml`:
  `69e9db92e3a900c0295f6eee309e900f30a503b6`;
- `modules/common/Directories.qml`:
  `0fb9ae0b8ce77bb5b280c3aef16c9b3d22d73f27`.

### Candidate A — HIGH CONFIDENCE: shared in-flight/success cache for Cliphist image decode

`CliphistImage` is correctly lazy: it only starts decoding once the delegate is
visible. It also publishes through a per-process temporary file and atomic
rename. However each visible `CliphistImage` still owns its own Bash process:

```qml
if [ -s '${imageDecodeFilePath}' ]; then
    exit 0
fi
_tmp='${imageDecodeFilePath}'.$$
if ${Cliphist.decodeCommand(root.entry)} > "$_tmp" && [ -s "$_tmp" ]; then
    /usr/bin/mv -f "$_tmp" '${imageDecodeFilePath}'
...
```

The source itself notes that multiple clipboard surfaces can render the same
entry concurrently. Current call sites include Overview search, ii Clipboard and
Waffle Clipboard.

Consequences today for the same clipboard entry:

- every visible instance forks its own Bash;
- a cache hit still forks Bash just to test `-s`;
- simultaneous misses can decode the same cliphist entry more than once;
- atomic rename prevents partial-file corruption but does not deduplicate the
  decode work.

Strict-lossless direction:

1. move per-entry decode ownership into the shared Cliphist/service layer or a
   dedicated shared resolver;
2. preserve demand gating: no decode until at least one visible image requests
   it;
3. maintain `entryNumber -> decodedPath` for **successful** decodes only;
4. maintain one in-flight request per entry number;
5. let all requesting delegates subscribe to the same completion;
6. on failure, clear in-flight state and do **not** cache failure, so a later
   delegate/open can retry just as current independent instances can;
7. preserve the current temporary-file + atomic-rename publication;
8. keep Directories' session cleanup boundary unchanged.

This removes duplicate decode processes without changing success/failure file
semantics or making failure sticky.

Required oracle:

- one visible instance, cold decode success;
- two/three simultaneous surfaces requesting the same entry;
- different entries requested concurrently;
- successful cache reuse after the first decode;
- decode failure followed by a later retry;
- delegate destroyed while decode is in flight;
- source file already present before the first request;
- malformed/zero entry number behavior matching current source;
- exact published path and visibility behavior unchanged.

Measure child-process count and cliphist decode invocation count before/after;
do not claim CPU/RSS percentages from source alone.

### Candidate B — P2 / INVESTIGATE: Booru manual-preview process burst

For providers listed by `BooruResponse` as manual-download providers
(`danbooru`, `waifu.im`, `t.alcy.cc`), each `BooruImage` delegate starts:

```qml
/usr/bin/bash -c "mkdir -p ... && [ -f path ] || curl ... -o path"
```

on component completion.

Unlike Favicon, this is not a persistent cross-session cache-hit problem:
`Directories.qml` deliberately removes and recreates `booruPreviews` on
shell startup. Unique images therefore legitimately need one network fetch in
the session. The remaining debt is burst/concurrency overhead:

- one Bash wrapper per manual-preview delegate;
- potentially many simultaneous curl processes as a result grid instantiates;
- repeated delegates for the same image in one session can still race/check
  independently.

Do not promote a serial queue blindly: changing download concurrency can change
visible image arrival order/timing. Measure representative result counts first.
A safer first optimization may be shared in-flight dedup plus direct curl
ownership after one directory-readiness gate, while retaining current
parallelism for distinct URLs.

### Separate correctness issue — Booru preview cache identity

`BooruImage.fileName` is derived from the remote file URL basename, while all
providers share `Directories.booruPreviews`. Therefore unrelated provider URLs
with the same basename can map to the same local preview path. Current
`[ -f path ]` logic can then reuse the wrong image.

This is a cache-identity correctness issue, not a strict-lossless optimization.
A future repair should key by normalized full source URL/provider+id or a hash
and define how legacy basename-only files are ignored/migrated. Do not fold that
behavioral change into a process-only optimization patch.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Media artwork resolver process research

Research-only continuation on current `dev`
`d52ea737adb5cd1d52926e15ec164beaa719a723`. No runtime/product source was
changed in this round.

Current source identities:

- `modules/common/widgets/MediaArtworkResolver.qml`:
  `801d6422216b4b5f8e1ed31111b27010b963006e`;
- canonical active-player singleton `modules/common/widgets/MediaArtwork.qml`:
  `22cde9d2038d0ebf4c226773cdb9ca9a8cc6721f`.

Repository/history search found no prior optimization note for shared in-flight
ownership inside `MediaArtworkResolver`.

### Candidate — HIGH CONFIDENCE structural duplicate: share exact-key artwork file work while keeping per-instance display state

`MediaArtworkResolver` intentionally gives each owner independent presentation
state: current display source, stale-art retention, generation counters, retry
timers and local-file reload handling. That independence must remain.

The expensive file/backend work is not independent, however. Every resolver
instance owns its own:

- `artExistsChecker` process;
- remote `artworkDownloader`;
- base64 writer;
- local-file MIME checker/cacher;
- stable-file readiness checker.

The remote/data/local cache destination is derived from the resolver's exact
metadata identity: normalized source URL + title + artist + album. Multiple
resolver instances with the same identity therefore target the same cache file,
yet can independently probe or produce it.

This can happen for active-player surfaces because Hadalis has both the
canonical `MediaArtwork` singleton and additional resolver instances in
`PlayerControl`, `PlayerBase`, `CavaTheme`, Bar media and YtMusic-specific
surfaces. Other owners legitimately resolve non-active players, so replacing
all of them with the active-player singleton would be incorrect.

Strict-lossless direction:

1. keep each resolver's presentation/generation state local;
2. centralize only backend work keyed by the exact output/cache identity
   (`artFilePath` or an equivalent exact metadata key + operation kind);
3. allow one producer/check pipeline at a time for a given exact key;
4. fan successful completion/path readiness back to all current waiters;
5. keep distinct metadata keys independent even when they share the same URL;
6. never use URL-only dedup because title/artist/album are intentionally part of
   cache identity;
7. preserve atomic temp-file publication and MIME validation;
8. do not make failures sticky.

The last point is important: current remote resolver instances each have their
own retry counter/timing. A shared backend must not silently convert several
independent retry opportunities into a permanent failed cache entry. The safest
design is success/in-flight sharing only, with failed in-flight state removed
and retry scheduling still owned by the requesting resolver(s), or another
oracle-proven policy that reproduces current visible recovery.

### Why not simply route everything through `MediaArtwork`

That would change behavior:

- `MediaControls` can render several players, not only the active player;
- LocalMusic can use a playback adapter;
- YtMusic-specific surfaces have dedicated metadata rules;
- some resolver metadata keys differ in album handling;
- each surface currently preserves its own previous artwork while the next
  source resolves.

Backend dedup is therefore the narrow optimization boundary.

### Required oracle before implementation

Exercise exact result/path and transition parity for:

- two simultaneous resolvers with identical remote metadata;
- identical URL but different title/artist/album;
- active-player singleton + `PlayerControl` / `PlayerBase` overlap;
- different players resolving concurrently;
- warm cache hit;
- cold remote download;
- HTTP failure followed by retries and later recovery;
- resolver destroyed while shared work is in flight;
- local file that appears late;
- local file replaced or deleted during readiness checks;
- Plasma/browser temporary art copied before the source disappears;
- base64 data URI success/failure;
- rapid track A -> B -> A generation changes;
- each resolver retaining its own stale display until its requested replacement
  is ready.

Measure process count (`test`, Bash, curl, file/stat helpers) for one active
track displayed on several surfaces before claiming a runtime saving.

### Adjacent non-candidate

Do not memoize a successful file path forever without filesystem invalidation.
Current resolvers re-check existence and can recover if a cache file is deleted
or replaced externally. A process-free session-known-success set would change
that recovery contract unless coupled to authoritative file lifetime/version
evidence.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Settings World Clock process research

Research-only continuation on current `dev`
`da0d94faa2b8376e1cd6f026f8474c9fd4982596`. No runtime/product source was
changed in this round.

Current source identities:

- `modules/settings/InterfaceConfig.qml`:
  `6f9e2c644aafebc0b3b54ba34df14c272bbbe52d`;
- sibling `modules/sidebarLeft/widgets/WorldClockWidget.qml`:
  `5f9272b1aeedc3fa91b76e3a13de150bb6e61829`;
- shared desktop `services/WorldClock.qml`:
  `1260b2d2ed85cf70339c2c8f366c296655dc3c9a`.

Repository/history search found no prior optimization note for the Settings
`liveTimeProc` child-process fan-out.

### Candidate — HIGH CONFIDENCE for supported timezone inputs: collapse Settings preview from 1+N processes to one Bash process

The World Clock settings preview refreshes every 20 seconds while the Widgets
section is active. It currently builds shell source like:

```qml
for (let i = 0; i < tzs.length; i++)
    script += `printf ... "$(TZ='timezone' date '+format|%:z')"\n`
liveTimeProc.command = ["/usr/bin/bash", "-c", script]
```

For N configured timezones, each refresh starts one Bash plus N external
`date` children.

Two existing sibling implementations already prove Hadalis does not need those
children:

- `services/WorldClock.qml`;
- `modules/sidebarLeft/widgets/WorldClockWidget.qml`.

Both pass timezone names as argv and use Bash's builtin
`printf '%(...)T' ... -1`, so one Bash process formats all requested zones.

Strict-lossless direction for the Settings preview:

1. keep the existing 20-second cadence and visibility gate unchanged;
2. keep one `liveTimeProc`;
3. pass each configured timezone as an argv entry;
4. use the already-proven sibling `TZ="$tz" printf '%(...)T' ... -1` loop;
5. preserve the exact output protocol currently consumed by `SplitParser`:
   `timezone|time|offset`;
6. preserve the configured 12/24-hour format choice;
7. do not merge Settings state with the desktop/background World Clock service,
   because the two features use different config namespaces.

Structural saving per refresh:

- current: 1 Bash + N `date` children;
- candidate: 1 Bash;
- child-process reduction: N external processes per refresh while this settings
  section is visible.

No cadence reduction is claimed here. Changing 20 seconds to one minute would
alter refresh timing and is a separate product/performance decision.

### Input-contract caveat

Current Settings code interpolates timezone strings into shell source inside
single quotes. The sibling argv implementations avoid that interpolation. For
valid IANA timezone names the behavior is directly equivalent.

Malformed strings containing shell-significant characters currently have
shell-parsing side effects rather than a well-defined timezone contract. Moving
them to argv is safer, but strict-lossless classification for malformed input
requires an oracle/decision rather than pretending those shell side effects are
a supported behavior.

Required oracle:

- empty timezone list;
- 1 and several valid zones;
- 12-hour and 24-hour formatting;
- positive/negative UTC offsets;
- DST transition fixture if practical;
- invalid but non-shell-significant timezone;
- timezone string containing whitespace/quote/metacharacters, explicitly
  deciding whether safe argv handling supersedes historical shell parsing;
- repeated refresh while a prior process is still running, if that condition is
  reachable in the current Settings process wrapper.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Shared MPRIS position ticker research

Research-only continuation on current `dev`
`70174b2cee2acd94f997ce993f55689acfc938e4`. No runtime/product source was
changed in this round.

Repository-wide source search finds ten `positionChanged()` occurrences in
the media path. Nine are producer-style refresh sites/timers; LyricsService is
a listener.

Current independent refresh owners include:

- horizontal Bar media;
- vertical Bar media;
- BarMediaPlayerItem;
- PlayerControl;
- PlayerBase;
- left-sidebar MediaPlayerWidget;
- Control Panel MediaSection;
- LockMediaWidget;
- Waffle Action Center MediaPaneContent;
- VolumeMixer music page.

Current cadences are not uniform:

- `PlayerBase`: 500 ms while its presentation explicitly requests updates;
- several rich surfaces: 1000 ms;
- Bar/VerticalBar/VolumeMixer: configurable resource interval, defaulting near
  3000 ms.

Every producer calls the same method on the same `MprisPlayer` object:

```qml
player.positionChanged()
```

That is a player-level signal refresh, not a private per-surface computation.
If multiple surfaces refer to the same player, the fastest timer already wakes
bindings attached to that player; slower owners can then add redundant signal
emissions/wakeups.

### Candidate — P1 / MEASURE THEN ADAPT: one demand-leased ticker per player identity

A shared ticker can potentially replace the independent periodic producers while
preserving each surface's demand boundary:

1. consumers acquire a lease for a specific player and requested interval;
2. one ticker per player runs at the minimum active requested interval;
3. releasing a consumer recomputes the required interval and stops the ticker
   when no consumer remains;
4. acquiring a consumer performs the current `triggeredOnStart` equivalent:
   request one immediate refresh even if another ticker is already running;
5. YtMusic/direct playback-adapter paths that do not rely on MPRIS position
   refresh remain outside this lease;
6. multi-player surfaces retain one logical ticker per player, not one global
   active-player ticker.

This direction has higher leverage than shaving individual timer intervals
because it attacks duplicated ownership, not merely cadence.

### Why this is not yet marked strict-lossless

The exact timing and count of `positionChanged()` emissions is observable to
bindings/listeners. Independent timers currently have separate phases. A shared
minimum-cadence ticker would change that signal schedule even when displayed
position values remain equivalent or fresher.

Before implementation, capture the current signal/callback sequence for:

- one Bar-only active player;
- PlayerControl only;
- PlayerBase/preset only;
- Bar + popup simultaneously;
- Bar + Sidebar/Control Panel;
- Dashboard + another active media surface;
- Lock transition;
- Waffle Action Center;
- two different MPRIS players in the multi-player surface;
- consumer open/close while playing;
- pause/resume;
- configured resource interval differing from 3000 ms.

Then define the parity contract around visible progress freshness rather than
assuming raw signal count is irrelevant.

### Important implementation boundary

Do not centralize this as a permanently running MPRIS poll. The current code is
already presentation/demand gated. Any shared owner must preserve that property
and balance all leases on destruction/visibility transitions.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Saved-theme catalog polling research

Research-only continuation on current `dev`
`10c4a09d0dc222a58cff316d1b6824b54611c286`. No runtime/product source was
changed in this round.

Current `modules/settings/ThemesConfig.qml`:
`fa617e33a5a4672e970a46ee19c2a3dae2c309be`.

Repository/history search found no prior optimization note for
`savedThemesProcess` / `refreshSavedThemes()`.

### Candidate A — HIGH CONFIDENCE: collapse per-poll theme catalog child fan-out

While the Custom Theme Editor is expanded, `ThemesConfig` refreshes the saved
theme catalog every 2000 ms.

The current scan starts one Bash and, for every saved JSON file, invokes:

- one external `basename`;
- one external `jq`.

For T saved themes, one unchanged poll therefore uses approximately
`1 + 2T` processes.

The same output can be produced without changing the polling cadence or model
semantics:

1. keep the current Bash owner and 2-second timer;
2. derive the basename with shell parameter expansion instead of an external
   `basename`;
3. invoke one `jq` over the complete ordered file argument list, deriving each
   record's name from `input_filename`;
4. preserve one compact JSON object per input file on stdout and the existing
   `SplitParser` consumption;
5. preserve glob/order semantics and invalid-file warning behavior through an
   oracle.

Structural process count per poll becomes roughly:

- current: `1 + 2T`;
- candidate: `1 Bash + 1 jq`, independent of T.

This is a narrow strict-lossless process optimization and does not require a
new service or watcher.

### Candidate B — P1 follow-up: replace fixed 2-second polling with filesystem-driven refresh only after overwrite semantics are proven

The repository already uses `FolderListModel` reactively for setup scripts and
other directory inventories. That makes event-driven saved-theme discovery a
natural follow-up.

However add/remove detection alone is not sufficient: an existing
`name.json` can be overwritten in place while keeping the same filename and
count. A watcher design must prove it catches content replacement, not merely
directory count changes.

A robust eventual design may combine:

- `FolderListModel` for add/remove/name/order changes;
- watched per-file content or another authoritative directory/content change
  signal for same-name overwrites;
- explicit refresh after Hadalis itself saves/deletes a theme.

Do not delete the polling timer merely because `FolderListModel.countChanged`
works for add/remove.

### Required oracle

For Candidate A:

- zero saved themes;
- one/many themes;
- filenames with spaces/dots;
- deterministic output order;
- invalid JSON mixed with valid JSON;
- one file removed during scan;
- one file replaced during scan;
- exact preset id/name/description/tags/colors parity;
- same warning/skip behavior for invalid entries.

For Candidate B later:

- external create/delete;
- external same-name overwrite;
- atomic rename replacement;
- Hadalis save/delete;
- editor closed/reopened;
- no refresh/process activity while the relevant settings surface is inactive.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

## 2026-10-07 — Settings search registry hot-path research

Research-only continuation on current `dev`
`9b4ebaf9ad76f2b754ce612322533f40af669ad7`. No runtime/product source was
changed in this round.

Current `modules/common/widgets/SettingsSearchRegistry.qml`:
`836c9c061039bae7508aa6b44973722409ddf1dd`.

Repository/history search found no prior optimization note for
`SettingsSearchRegistry.buildResults()` field normalization or pre-top-50
highlight generation.

### Candidate A — HIGH CONFIDENCE: normalize immutable registry search fields once at registration

`registerOption(meta)` snapshots each live control's search metadata into an
entry:

- page index/name;
- section;
- label;
- description;
- provided + generated keywords.

There is no update-in-place API for these entry fields. Controls are
unregistered/re-registered when their searchable identity changes through
lifecycle recreation.

Despite that snapshot model, every `buildResults(query)` call currently
recreates the normalized search corpus for every active entry:

```qml
var label = (e.label || "").toLowerCase()
var desc = (e.description || "").toLowerCase()
var page = (e.pageName || "").toLowerCase()
var sect = (e.section || "").toLowerCase()
var kw = (e.keywords || []).join(" ").toLowerCase()
```

Settings search runs on text changes, so this repeats lowercase conversions and
keyword joining for the complete live-control registry on every keystroke.

Strict-lossless direction:

1. during `registerOption()`, keep the existing public/raw entry fields and
   additionally compute private normalized fields;
2. `buildResults()` reads those precomputed strings directly;
3. keep current auto-keyword generation, scoring weights, match order and
   page/tie ordering unchanged;
4. preserve entry removal/flush behavior exactly.

Because the current registry already snapshots those raw fields rather than
reactively rereading the control during search, caching their normalized forms
does not make metadata any staler than current behavior.

### Candidate B — HIGH CONFIDENCE: defer highlight markup until after score/sort/top-50 selection

Current `buildResults()` generates:

```qml
labelHighlighted: highlightTerms(e.label, matchedTerms)
descriptionHighlighted: highlightTerms(e.description, matchedTerms)
```

for every matched entry before sorting all matches and returning only:

```qml
out.slice(0, 50)
```

Highlight markup does not participate in scoring, applicability, ordering or
the top-50 cutoff.

Strict-lossless direction:

1. during the scoring pass, retain raw label/description plus
   `matchedTerms`;
2. perform the existing sort;
3. take the exact same first 50 entries;
4. only for those retained entries, call the existing `highlightTerms()` in
   the same term order and publish the same result fields.

This removes lowercase/substr/HTML-string work for matches that are guaranteed
to be discarded while preserving the complete visible result object for every
returned row.

### Required oracle before implementation

Compare complete result arrays/fields for:

- empty query;
- one and multiple terms;
- case variants;
- exact/prefix/mid-string matches;
- generated and caller-provided keywords;
- duplicate keyword terms;
- page/section/description-only matches;
- score ties and page-index tie ordering;
- more than 50 matching entries;
- overlapping highlight terms and term-order-sensitive markup;
- removed controls before the coalesced registry flush;
- unregister/re-register and page/control destruction/recreation;
- translated labels/descriptions as they exist at registration time.

The oracle should compare IDs, order, scores, matchedTerms, raw text and final
highlight markup, not merely result count.

### Adjacent non-candidates

- Do not add a keystroke debounce as part of this strict-lossless work. That
  changes when results become observable.
- Do not merge standalone Settings, SettingsOverlay, SettingsFocus and Waffle
  search orchestration merely because they call the same registry. Their
  applicability/easy-mode/navigation contracts differ, and static source does
  not prove those routes execute concurrently for one user query.
- Static `SettingsPageRegistry.searchIndex()` normalization can be examined
  separately, but it should not be conflated with the live-control registry
  candidate above.

No whole-Hadalis CPU/RAM/GPU/FPS percentage is claimed without runtime
measurement.

