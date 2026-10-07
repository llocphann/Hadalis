# Abyss strict-lossless optimization audit — 2026-09-30

## Outcome and evidence boundary

Two existing research groups were implemented after a native QV4 proposal
oracle passed: controller aggregate-array compaction (§58.1, narrowed to retain
both evaluation phases) and decorative-wave smoothing (§75.1).

Runtime commit: `ba5ae690dc59648a9bb7bddb1341b01aadf83e11`.
Frozen pre-change declarations: `45551e186f078395f8c40c562b0cf1304fc16230`.
Proposal job commit: `ef9de70329bf3f31a2d06b8b5596aecee5444f37`.
Proposal evidence: [native oracle result](../../automation/results/JOB-abyss-lossless-proposal-20260930.json).

The proposal passed **30,065 cases and 11 reactive steps** in native QV4.
The canonical validator's observed log also reports a pass against the actual
modified production declarations. Its raw worker result was lost after failed
publication; the [explicit recovery record](../../automation/results/JOB-abyss-lossless-runtime-20260930.json)
retains that limitation. Repository-wide acceptance is **HOLD / NOT_COMPLETE**:
the observed runtime-SHA summary reports failures in contracts, fixtures and
runtime linkage. Live owner-desktop acceptance remains open.
These reductions do not imply a CPU, GPU, FPS, latency, RSS/PSS or VRAM percentage.

## Research inventory and coverage

The complete canonical handoff was read and reconciled through Round 70 (§84).
At `bacf362b5f38ba350b40398fe0a4ebb62fd3c28b`, before adding this audit's
consolidation, it contained **20,823 lines, 113,128 whitespace-delimited words
and 604 numbered subsection headings**. Literal classification labels occur in
255 CONFIRMED headings and 47 HIGH CONFIDENCE headings. These are historical
heading counts, with mixed labels, expansions and later corrections; they are
**not unique, current, implementation-ready optimization counts**. In particular,
§72.1/§72.2 require stronger proof than their historical CONFIRMED labels imply.

The direct Abyss source inventory at the runtime commit is **60 QML/JS/fragment
source files, 7,974 lines**, excluding `qmldir` manifests and the compiled QSB.
Direct source, exported controls, content adapters, settings and editor paths
were inspected. Shared feature/model/backend paths were traced at their relevant
consumer, publication and lifecycle boundaries. This is a source audit with
bounded native tests, not an exhaustive execution of every hardware or extension
configuration, nor a claim to have audited every unrelated service internally.

### Shared presentation chain

Bar/corner hover, pointer presses, IPC and keyboard actions reach either the
existing `modules/bar/StyledPopup.qml` ownership path or
`AbyssGenericPopupPresenter.qml`. StyledPopup resolves its ancestor's
`liquidController`, retains semantic hand-off separately from the retract tail,
then calls `presentPopup`/`releasePopup`. The controller assigns four stable
popup slots and reparents the existing content without recreating its model.

Each `AbyssBodyHost` publishes a full target placement request through
`AbyssParticipant`. `AbyssSurfaceController.placementRequests` feeds
`AbyssBodyPlacement.arrange`; `AbyssVacancyBorrowing.resolve` post-processes the
resting placements. `AbyssPyramidCoordinator` owns neighborhood snapshots and
reveal/reflow transactions. BodyHost's placement Behaviors and
`AbyssPyramidMotion` produce presentation geometry while semantic input ownership
can already have closed. `AbyssGeometry.placedPanel` and `joinCorner` produce
surface/content records. Controller aggregation feeds both wave mass and the
40 ordered rectangle uniforms in `AbyssField.qml`. The existing fragment shader
owns the union, rim, shadow, wallpaper glass, refraction and wave shoulder.
Native input regions and keyboard arbitration use content bounds, independently
of the painted union. No part of this ownership sequence was changed.

### Surface and backend trace matrix

All rows ultimately use the shared chain above unless explicitly identified as
an independent renderer. Backend results return through the listed service's
existing publication into QML, then content size/placement and field records.

| Surface / interaction | Frontend and state/model/backend linkage | Lifecycle / audit conclusion |
|---|---|---|
| Bar clock, resources, battery, weather, tray, workspaces, timer, update, taskbar | `AbyssBarModule` hosts mature shared controls; ClockCalendarPopup, ResourcesPopup, BatteryPopup, WeatherPopupContent and SysTray retain their models. DateTime, resource/power services, Weather curl requests, compositor state and TimerService remain their publishers. | Module measurement drives layout/extents; hover/press impulses enter the existing wave field. No blanket backend shutdown or sort replacement. |
| Generic Wi-Fi/Bluetooth | SysTray → generic presenter → `AbyssPopupContent` → `AbyssNetworkPopup` → embedded WifiDialog/BluetoothDialog. Wi-Fi controls call Network's nmcli commands; Bluetooth controls mutate the Quickshell/BlueZ adapter/device state. | One shared 650 ms hover/focus lease; embedded forms disable their extra footer. Scans and password retries retain their current observations/order. |
| Sidebar connectivity and other dialogs | CompactSidebarRight controls → ToggleDialog → WindowDialog → `presentDialog` → dialogBody; connectivity role enters vacancy resolution. Volume, Hotspot, NightLight and Events retain their own services. | Destruction releases without restoring a destroyed item. Wi-Fi opening enables/rescans; Bluetooth opening enables/discovers and closing stops discovery. These calls are behavior, not redundant scans by default. |
| Quick Notes / To-do / Timers | `AbyssCorners` → QuickNotesPopup → QuickNotesView/NotepadWidget, DashTodo or PomodoroWidget → Notepad, task persistence and TimerService → text/list/time publication. | Editor flush/release occurs at close, mode switch and destruction. Timer UI loads only on selected timer tab; timers are service-owned. Exclusive editor lease is output-local. Already gated; do not reset drafts or clocks. |
| Notifications / Activity | Corners → NotificationCenterPopup → NotificationCenterContent or ScreenTime activity rows. Dismiss/actions/read state → Notifications → server callback, timers, history FileView → grouped publication. Activity → ScreenTime's persisted tracking → bounded visible rows. | Quick Notes can own keyboard while center remains pointer-interactive. Search/drag/entry/exit grace remain observable. Tracking is useful while its popup is closed. |
| Notification popups / toast | notificationBody → NotificationListView/NotificationGroup/NotificationItem → Notifications. toastBody → AbyssToastContent → ToastNotification → existing ToastManager queue, timeout and dismissal. | Retract/drag/expand timing and queue order retained. No second Abyss toast queue/window/backend. |
| Volume / mic / brightness / keyboard / media / voice OSD | Shared Audio, Brightness, KeyboardIndicators, MprisController and VoiceSearch state → AbyssOsdController → indicator loader → mature indicator controls. Audio normally uses tracked PipeWire objects, with wpctl fallback; brightness uses brightnessctl/ddcutil. | Initial 1,500 ms gate; compact kinds coexist in fixed order; media hover holds its timeout. Read-only indicatorKind assignment errors are a separate prerequisite below. |
| Media bar popup | generic/mature Media owner → BarMediaPopup → live MPRIS player tabs / PlayerControl and EqualizerPanel → EqualizerService transport/backend and shared CavaService. | Decorative WaveVisualizer is disabled here. EQ animation uses Date.now and its 33 ms repaint demand; removing that clock changes pixels. No decorative-wave saving is attributed to this path. |
| Sidebar Left music | AbyssLeftContent → SidebarLeftContent's LocalMusicView → LocalMusic playback adapter / MPRIS, CavaProcess → CavaService config process + cava → points/ceiling → PlayerControl → WaveVisualizer → rectangle height/opacity. | A confirmed consumer of the smoothing change, when music is enabled, visible and playing. Lease acquisition, adaptive normalization and 75 ms visual Behaviors are unchanged. |
| Sidebar Right / media | AbyssRightContent → CompactSidebarRightContent → controls/adjacent widget loaders → shared Audio, Network, Bluetooth, calendar/tasks/system-monitor/timer services. CompactMediaPlayer uses PlayerBase; EQ has a separate consumer registration. | Base Controls stays resident while neighboring widgets can load; narrowing the EQ lease requires a section-switch/reopen oracle. CompactMediaPlayer itself is not a WaveVisualizer consumer. |
| Dashboard / Overview | dashboardBody/aux → DashboardContent/DashboardCanvas or OverviewDashboard/OverviewNiriWidget/OverviewWidget → DashboardLayout projection, compositor models/sorting lease and shared widget services. | Pointer previews and saved projection differ; malformed geometry/ties must remain. DashMedia disables decorative wave. Sorting lease is acquired/released by AbyssOverviewContent. |
| Clipboard / application launcher | AbyssClipboardContent → Cliphist list/copy/delete/wipe/pin commands and native-dispatch clipboard-store → history/pinned publication. AbyssLauncherContent → LauncherSearch/AppSearch → ShellExec, compositor workspace/window activation. | Confirmation clear is local two-step state; search resets it. Deferred execution/clipboard suppression and provider model ownership retained. |
| Dock and attached menus | DockApps / DockAppButton → TaskbarApps/AppSearch/compositor; menu publishes GlobalStates model/owner/output, generic dockAppMenu rehosts it, action clears ownership before Qt.callLater(callback). | Resident Dock, attached-popup hold, pointer bridge and app-menu width are intentional. Menu dismissal snapshots cannot be removed across callbacks. |
| Utilities | AbyssUtilitiesPopup SwipeView → current/adjacent monitor/display/audio/night loaders → MonitorVisibilityConfig/Niri, DisplayMode action helper / wl-mirror, Audio and NightLight services. | Animated envelope tracks active page. Adjacent pages are needed during swipe; eager destruction can reset controls or first-frame readiness. |
| Session / cheatsheet / updates / settings | utilityBody or settingsBody → mature SessionScreen/Cheatsheet/ShellUpdateOverlay/SettingsOverlay → existing action/config/process publishers. | Current page tree is reused. Session confirmations and destructive actions keep their existing handlers. No separate Abyss confirmation service/presenter exists at this HEAD. |
| Confirmation / Polkit / lock / specialist surfaces | Clipboard clear and existing shared feature dialogs remain their actual source paths. ShellAbyssPanelsImpl retains the shared Polkit/Lock renderers and demand-loaded specialist panels. | Historical ConfirmationService/PopupAnchorRegistry/Abyss prompt recommendations are SUPERSEDED/not applicable. Do not restore removed architecture or treat authorization prompts as unused content. |
| Live Edge Editor / settings / preview | Draft placement and popup position edits → AbyssLayout snap/geometry and AbyssPresentation → preview BodyHost / input regions → Config.setNestedValues only on Done; settings sliders use the same config/material/wave parameters. | Cancel does not persist. 90 ms toolbar relocation and 80 ms drag impulse throttle remain. No P3 draft-copy optimization promoted. |
| Multi-output / scaling / family transition | Per-output controller/window and reservation surfaces; logical geometry plus renderScale/DPR; family transition Shape and readiness gate. | No controller sharing, uniform packing reordering, DPR change, antialiasing change or timer change. Live hotplug/transforms/fractional scaling/fullscreen/lock/suspend acceptance remains owner-only. |

## Finding A — phase-preserving aggregate compaction

| Required field | Finding |
|---|---|
| Classification | **CONFIRMED**, implemented; repository acceptance separately HOLD. |
| Priority | P1–P2 reactive layout/input/record publication. |
| Exact path | `modules/abyss/AbyssSurfaceController.qml`. |
| Symbol | `placementRequests`, `inputBounds`, `records`. |
| Behavior | Read all participant fields through the existing map, then apply the existing predicates in order; publish fresh arrays and cloned geometry records. |
| Current cost | Before: keys + map + filter arrays; records also creates final concat. |
| Optimization | Compact only the unpublished, dense map result and truncate it after all predicates. Keep concat for records. |
| Strict proof | Object.keys().map produces a private dense ordinary array. At iteration i, kept ≤ i, so a write cannot overwrite an unread item. Predicates and accepted order are identical; every removed item is excluded by the old predicate. |
| Dependencies | Mapping remains unchanged, including both geometry reads, Object.assign enumeration and mass read. All map reads finish before width/height predicate reads. records retains moduleRecords receiver evaluation before mapping via an immediately invoked argument expression. |
| Ordering/ties | Object.keys order, integer keys, inherited/non-enumerable exclusions and participant duplicates retain baseline semantics. No sort, Set or index introduced. |
| Malformed state | Same null/undefined handling, width/height short circuits, false request retention, NaN/Infinity/-0 predicates and first thrown error. The oracle includes accessor traces and thrown geometry reads. |
| Lifecycle | No registration, slot, parent, Loader or semantic-open change. Fresh output per evaluation; no retained scratch buffer. |
| Animation/render | Geometry values/order and rectangle uniform inputs unchanged. No animation/shader/material edits. |
| Frontend/backend | No process, query, lease, signal handler or backend publication change. |
| Local reduction | Requests **3 → 2 arrays (33.3%)**; input **3 → 2 (33.3%)**; records **4 → 3 (25%)**. If each binding evaluates once, 10 → 7 arrays, a local 30% count reduction. Mapping/predicate visits remain two phases. |
| Oracle/benchmark | Native old-vs-new values/errors/read traces/fresh identity and QObject dependency/NOTIFY parity passed. Net CPU/RSS/PSS and backing-capacity effects are unmeasured. |
| Relation to note | Existing owner §23.2/§58.1; no new optimization group. |
| Note disposition | **Refined**: do not apply its more aggressive scan-fusion counts to this implementation. |

## Finding B — old-value wave smoothing window

| Required field | Finding |
|---|---|
| Classification | **CONFIRMED**, implemented. |
| Priority | P2 active CAVA frame path, shared with Abyss Left music. |
| Exact path | `modules/common/widgets/WaveVisualizer.qml`. |
| Symbol | `processedBars` smoothing loop. |
| Behavior | Normalize/mirror input, edge taper, then P capped three-tap smoothing passes; publish a fresh array. |
| Current cost | One N-element output plus P N-element smoothing arrays per active evaluation. |
| Optimization | Keep previous/current old values and read the following old value before overwriting the current slot. |
| Strict proof | Before iteration i, prev/curr represent old[i−1]/old[i], and unread slots ≥ i+1 are untouched. Boundary repetition is identical. The exact expression prev*.25 + curr*.5 + following*.25 and arithmetic association remain. Induction applies independently to each pass. |
| Dependencies | All reads of live, points, lengths, ceiling and smoothing remain in their previous positions; smoothing touches only already-normalized private numbers. |
| Ordering/ties | Source coercion order and bar order unchanged; no sort, cache or shared array. |
| Malformed state | Object.is parity for NaN and -0; finite/infinite ceilings and inputs, strings, null/undefined samples, empty/single-point inputs, count 0–64 and smoothing below/above the cap tested. Native typed reactive properties also tested. |
| Lifecycle | Same fresh array on inactive/empty paths and each evaluation. No CAVA/service ownership change. |
| Animation/render | Delegate dimensions/opacity/colors and 75 ms OutCubic/OutQuad Behaviors unchanged; render nodes and textures unchanged. |
| Frontend/backend | CavaService frame normalization/publication and stop/restart/watchdog timing untouched. |
| Local reduction | Active P-pass path **1+P → 1 arrays**, reduction P/(1+P): 0%, 50%, **66.7% at default P=2**, 75% at P=3. Allocated N-element array payloads follow the same ratio; smoothing pass count/arithmetic work is not removed. |
| Oracle/benchmark | Native numeric/error/fresh-publication and reactive parity passed. No frame-time, CPU, GPU or memory benchmark claimed. |
| Relation to note | Existing §75.1. |
| Note disposition | **Confirmed and qualified by actual consumer reachability**; bar Media and DashMedia disable this decorative layer. |

## Remaining candidates — bounded findings, no runtime patch

The following cards reuse the same 18-field contract. They are existing owners,
not additional backlog counts. Standard QV4 built-ins and current supported
producer contracts are the proof boundary; arbitrary replacement of global
Array/Number intrinsics is not a newly supported extension API.

### C — vacancy role-winner selection

1. **HIGH CONFIDENCE**, not implemented.
2. P1–P2 layout.
3. `modules/abyss/looks/AbyssVacancyBorrowing.js`.
4. `_vacancyMemberForRole` / `resolve`.
5. Six role filters/sorts select members for three semantic pairs.
6. Repeated metadata visits plus sorting accepted members.
7. Invocation-local winner scan, only after proving exact comparison/ties.
8. Strict proof incomplete: replacing sort[0] with first-on-zero assumes a stable tie policy not established for the deployed QV4 sort.
9. The filter reads request/placement before checking role; skipping those reads can alter errors/accessor observations. Preserve phase and field order.
10. Repeated metadata, duplicate IDs and distinct Unicode IDs with localeCompare==0 require current-engine tie parity; no insertion-order assumption.
11. Missing IDs, prototype keys, malformed order/coercion, non-finite values and accessors need an oracle.
12. Automatic ownership must remain independent of pointer hover and preserve released-space behavior.
13. Wrong winner changes expansion/reflow, focus bounds and pixels.
14. No backend benefit is claimed.
15. Proposed six metadata traversals → one; **not realized or credited**.
16. Native comparator/winner/error/read-order oracle required.
17. §72.1, including older sort caveats in §§45/46/48.
18. **Restricted** historical CONFIRMED to HIGH CONFIDENCE pending proof.

### D — vacancy final collision pass

1. **HIGH CONFIDENCE**, not implemented.
2. P1–P2 multi-popup geometry.
3. `modules/abyss/looks/AbyssVacancyBorrowing.js`.
4. `_vacancyBestCandidate` blocker limiting and grown-rectangle validation.
5. Ordered blocker limiting can be followed by a separate collision scan.
6. Repeated normalization/checks for accepted directions.
7. Fuse only if limiting proves the final rounded arithmetic/predicate outcome.
8. Mathematical monotonicity alone is insufficient for floating-point sums, subtraction, rounding, overflow and the gap−.01 tolerance.
9. Public JS placement enumeration includes inherited keys; normalization/accessor reads currently occur again in the second phase.
10. Direction order, early breaks, parallel-peer exclusions, gain comparisons and pair-conflict priority must remain.
11. Finite inputs can still overflow sums; extreme magnitude, subnormal, -0, malformed content and coercion need testing/fallback.
12. Closing/reopening and surviving paired bodies retain automatic borrowing semantics.
13. Removed rejection can change collisions/pixels/resize behavior.
14. No backend change proposed.
15. Candidate second-phase checks C×B → 0 only for a proven specialization; **no applied saving**.
16. Native adversarial old-vs-new solver oracle; generic fallback for unproved states.
17. §72.2.
18. **Restricted**; existing second pass deliberately retained.

### E — GPU union pruning / uniform packing

1. **BENCHMARK / CONDITIONAL**, not implemented.
2. P0–P1 fragment cost and reveal frames.
3. `modules/abyss/looks/AbyssField.qml`, `AbyssField.frag`, `AbyssGeometry.js`.
4. `packed`, 40 rectangle uniforms, `field`, `record`, `fuse` and derivatives.
5. One ordered SDF union drives fill/rim/shadow/glass; static wallpaper and tiny wave texture feed the same pass.
6. Up to 40 record evaluations per fragment and repeated packing/dependency work.
7. Proven inactive-record specialization or a conservative support-bound rejection before expensive work.
8. No pixel oracle proves a revised cutoff/union order. Smooth union is order-sensitive; derivative evaluation precedes divergent returns.
9. Packing array capture/coalescing must retain independent binding dependencies and fresh publication semantics.
10. Capacity/truncation and original record order must stay; sorting/grouping uniforms is unsafe.
11. Negative/NaN/non-finite rectangles, oversized surfaces and softness/radius/refraction require old-vs-new handling.
12. Readiness and first presented frame gate input; output recreation/DPR can invalidate texture state.
13. Antialiasing, derivatives, rim, shadow, blur/refraction and wave corners are required pixel contracts.
14. Wallpaper resolver remains output-aware; no decoder/process saving established.
15. Existing shader already rejects empty records and far exterior pixels. Further GPU/VRAM reduction **unquantified**.
16. Same-GPU image/frame-time oracle at 0/typical/capacity records and DPR 1/1.25/1.5/2, all edge joins/material modes.
17. §§13.5/22.6/23.2/24.2.
18. **Refined / existing fast paths ALREADY**. No effect-disable, quality/sample downgrade or shader reassociation.

### F — hidden trees, masks and wave mass

1. **CONDITIONAL** for finer sleeps; blanket destruction/effect removal is **OUT OF STRICT-LOSSLESS**.
2. P0–P1 hidden work/residency.
3. `AbyssBodyHost.qml`, `AbyssWaveController.qml`, SidebarLeftContent, CompactSidebarRightContent, QuickNotesPopup and AbyssUtilitiesPopup.
4. `visualResident`, Loader activation, `onRecordsChanged/setMass`, adjacent page/section loaders and EQ registration.
5. Retract tails, resident Dock, drafts, neighboring swipe pages and shared services retain useful state.
6. Trees/textures/bindings or wave-mass updates can remain resident beyond one visible face.
7. Gate only a proven non-observable phase and restore before the first relevant frame/interaction.
8. Close≠unobservable: callbacks, autosave, clocks, transitions and warm reopening still matter. No blanket release proof.
9. Hoisting gate properties or caching mass can change dependency capture/reset/first-impulse order.
10. Signal sequencing, service stop debounce and first integration step must match.
11. Missing screen/config/player, rapid hide→show, canceled transitions and destroyed QObject handling require oracle coverage.
12. Notes flush and timer completion persist while UI is absent; adjacent loaders support swipe state.
13. Masks/effects are already gated in several owners; releasing earlier can flash or change a reverse morph.
14. CAVA is already shared, with 800 ms stop debounce and recovery; EQ has consumer acquire/release.
15. No current PSS/texture/lease measurement; no RAM/VRAM percentage or extra process reduction credited.
16. Close-tail/reversal/warm-reopen/family-switch/lease oracle plus RSS/PSS and texture evidence.
17. §§19.2–19.3/23.1/25.2/28.4/58.7 and historical gating findings.
18. **ALREADY in part, remaining hypotheses conditional**. Date.now-driven EQ repaint is not redundant merely because CAVA points stay constant.

### G — frontend/backend query or callback reuse

1. **CONDITIONAL / BENCHMARK**, not implemented.
2. P1 interaction/process work.
3. Network.qml, Bluetooth dialogs/items, Notifications.qml, Cliphist.qml, DisplayMode.qml and their Abyss adapters.
4. Scan/connect/status result paths, `attemptInvokeAction/discardNotification`, history mutation and display actions.
5. Asynchronous operations publish independently observed state and can reenter/mutate collections.
6. Processes, parses and repeated lookups exist; many already use debounce, watchdog, failure-only fallback or native dispatch.
7. Batch or reuse only observations proven equivalent at their original times.
8. A pre-callback notification lookup cannot substitute for the fresh post-action lookup without mutation/reentrancy proof. Consecutive nmcli/remote requests need not observe the same state.
9. Preserve result/error publications, running/busy/target state and parse ordering.
10. Duplicate history IDs require first-match timer semantics; direct-current-wrapper cancellation changes malformed behavior.
11. Backend unavailable, failed start, timeout, stale result, missing adapter and duplicate IDs remain required cases.
12. Closing a popup does not necessarily cancel user-requested connection, persistence or display operation.
13. Busy/progress/error and first-open network lists are observable UI.
14. Full service→process/native/BlueZ/PipeWire→result→state→QML boundary is the candidate, not one isolated command.
15. No proven process-spawn reduction or latency measurement in this audit.
16. Backend-fixture/event-order oracle and representative workload benchmark.
17. Existing process research plus §78.2/§78.3 notification restrictions.
18. **Refined / unsafe direct reuse rejected**; correctness fixes are separate.

### H — Dashboard projection and responsive overlap scans

1. **CONDITIONAL** guarded plain-numeric subset; remaining paths **HIGH CONFIDENCE**, not implemented.
2. P1 geometry during resize/drop/projection.
3. `modules/dashboard/DashboardLayout.js`, `DashboardCanvas.qml`.
4. `freeRect`, exhaustive fallback candidate validation, responsive overlap bisection.
5. Candidate loops preserve first minimum-cost winner; public generic helpers and persisted geometry remain tolerant.
6. Cartesian X/Y candidates repeatedly test obstacles; responsive solving can revisit unaffected pairs.
7. Reuse exact X-overlap subset on private numeric snapshots; remove only a second pass already proved identical; preserve generic fallback.
8. Guard must establish plain primitive fields and every relevant bound. Native malformed/error/order proof is absent here.
9. Getter/QObject/coercion reads cannot be reordered under the generic public API.
10. Preserve X/Y enumeration, tie winner, shrink order, duplicate widget IDs and scoring arithmetic.
11. NaN/Infinity/extreme values/malformed persisted references and touching tolerance need an oracle.
12. Preview geometry, saved edits, overflow and viewport resize must agree throughout transitions.
13. Changing adaptive packing/resize feedback changes positions and motion.
14. No backend change proposed.
15. Potential reduced obstacle tests depends on subset density; no whole-system percentage or applied reduction.
16. Native solver oracle, actual production-path reachability and resize/drop cases.
17. §§65.1/73.1/73.2/74.1.
18. **Retained guarded mathematical result, no blanket promotion**.

### I — Perimeter obstacle buffers and notification collapsed model

1. **HIGH CONFIDENCE** implementation leads; not implemented in this batch.
2. P1–P2 reactive geometry and expanding/collapsing history.
3. `modules/abyss/AbyssPerimeter.qml`, `modules/common/widgets/NotificationGroup.qml`.
4. `sideObstacles`, Dock/notification obstacles, collapsed `ScriptModel.values`.
5. Filter progress before reading selected records; conditional concat ordering; notification list reverses before selecting its visible prefix.
6. Intermediate arrays; collapsed history traverses the full group despite a bounded visible face.
7. Phase-preserving result buffers and exact reversed-prefix extraction.
8. Need current native QObject/array/error/publication oracle; cannot interleave filter predicates and record reads blindly.
9. Left/right progress reads must both precede their record reads; notification and popup evaluations must retain concat phase order.
10. Preserve reversed newest-first order, duplicates/holes and concurrent dismiss snapshot semantics.
11. Sparse/extensible/malformed notification sequences and record getters must remain equivalent.
12. Expanded delegate/retract/dismiss lifetimes and synchronous list changes remain unchanged.
13. Layout/drag/expand animations and obstacle geometry must match at intermediate frames.
14. Notification callback and timer mutations cannot be skipped just because rows are collapsed.
15. Note's side-obstacle arrays 3→1 / collapsed O(N)→O(min(N,2)) remain candidate counts, not delivered gains.
16. Native reactive/read-order/identity and malformed-array oracle required.
17. §§59.3/60.1; nearby §58.2 popup derived-state reductions likewise retain required dismissal snapshots.
18. **Refined** proof requirement; not counted as new findings or implemented savings.

## Correctness prerequisites and validation

These are not optimization factors and were not patched to change the baseline
product while performing this strict-lossless work:

- `AbyssLayoutPreview.qml` assigns `indicatorKind` while
  `AbyssOsdContent.qml` declares it readonly. The supported writable input is
  `kind`; the live editor fixture reports a load failure. The OSD fixture also
  attempts the readonly assignment. Both source/fixture states predate this batch.
- Several Dock hover-menu fixtures/controls reference a GlobalStates menu API
  different from the current AbyssDockContent presenter contract.
- Vacancy and Pyramid tests report geometry/neighborhood failures. The solver,
  coordinator and those test bodies are byte-identical to the frozen pre-change
  snapshot; they must be reconciled as product-contract issues, not relabeled
  green or repaired by altering runtime merely to satisfy spelling assertions.
- Existing retirement/style/documentation and lifecycle assertions also fail.
  The observed 33 failure names are retained in the recovery record; original
  action stdout/stderr and detailed failure output were not recovered. No broad
  product cleanup or unrelated automation edits are included in the optimization
  commit. Not every failed check has been causally attributed by this audit.

Canonical dispatch: [runtime job](../../automation/queue/pending/JOB-abyss-lossless-runtime-20260930.json).
It uses `--current-repo` in the worker's isolated exact-SHA clone, so a later
remote `dev` movement cannot change the tested revision.

During execution a manual invocation duplicated an already-running background
worker. The manually launched copy was interrupted; the background run completed.
Both initially wrote the same external log path. Consequently that combined
external file is **not a clean canonical log artifact** and is not treated as a
benchmark or independent confirmation. Publication failed, and the service
restarted and re-executed the consumed job; after the interrupted session,
startup triggered another execution. The active duplicate was stopped.

The original action stdout, stderr, exit code and execution timestamps could not
be recovered. The explicit **manual recovery** record deliberately leaves them
unavailable rather than reconstructing a normal worker result. It consumes the
job identifier and preserves FAIL/HOLD so that missing publication does not
trigger another execution. The worker service was restored after that record
was pushed and verified on remote `dev`. The underlying publication-failure
handling is a separate automation correctness prerequisite, not an optimization
factor or a completed repair in this audit. Future canonical validation requires
a new SHA and a new job identifier.

The observed canonical summary is **267 checks, 233 passed, 33 failed**;
the validator reports two skip entries (QML parser capability and deferred Nix).
The actual-production native allocation oracle is among the observed passed
checks. These are an observed summary, not qualified retained canonical evidence.
Final readiness remains **HOLD** until the existing failing contracts are
resolved on a new SHA and owner desktop acceptance covers multi-popup transitions,
focus, all edges, hotplug, fullscreen, lock/suspend and fractional scaling.

## Honest percentage calculation

For a local source count, reduction = `(before − after) / before × 100`.
The delivered local ratios are 25%, 33.3% and 66.7% (75% at three smoothing
passes). They refer to different allocations and workloads, so adding them
would be meaningless. High-confidence proposals contribute **zero credited
saving** until their missing proof is closed and they are implemented.

No qualified before/after CPU, GPU, latency, FPS, RSS/PSS or VRAM sample was
collected. Thus there is **no defensible aggregate percent** for implementing all
CONFIRMED/HIGH CONFIDENCE entries. In particular, fewer allocations do not prove
proportional resident RAM savings; capacity, object payloads, GC and retained
content require measurement. Future measurements need identical source paths,
features, outputs, DPR, media state, cold/warm state and popup choreography.
