# Code Workflow feasibility probes

Development-only, opt-in tools for Phase 0 of
[the editor design](../../docs/CODE_WORKFLOW_EDITOR.md). No Settings page,
production service, source-writing transform, or runtime dependency is added.

## Spike A

Requires a C compiler, Python 3.10+, and a public Tree-sitter shared library
compatible with grammar ABI 14 (tested with libtree-sitter 0.26.9 on Linux).
Rust was unavailable on the test host, so the first native candidate is the
upstream generated C parser/scanner, accessed through the public C API. Python
standard library ctypes is only the development harness. This does not select
the eventual helper language or prove supported installation packaging.

```sh
bash scripts/code-workflow/build-parser.sh /tmp/hadalis-workflow-parser
export HADALIS_WORKFLOW_GRAMMAR=/tmp/hadalis-workflow-parser/qmljs.so
python3 scripts/code-workflow/test-spike-a.py
python3 scripts/code-workflow/corpus.py --grammar "$HADALIS_WORKFLOW_GRAMMAR" > /tmp/hadalis-workflow-corpus.json
python3 scripts/code-workflow/corpus.py --grammar "$HADALIS_WORKFLOW_GRAMMAR" --inspect modules/bar/Media.qml
HADALIS_WORKFLOW_GRAMMAR="$HADALIS_WORKFLOW_GRAMMAR" bash scripts/validate-maintainer-local.sh --current-repo --strict-qml
```

The builder pins grammar 0.3.1, checks the crate SHA-256, retains its MIT license
in the temporary build directory and compiles its released C files without Node
or a grammar generator. Supply a downloaded crate as the optional second argument
for offline builds. Never commit the grammar, library, cache or generated report.

The corpus runner resolves a commit first, reads every tracked `.qml` from that
commit, and records the revision, file hashes and corpus manifest hash. Untracked
files and concurrent working-tree edits cannot silently change the sample.
`--revision SHA` replays an older corpus. The JSON includes diagnostics/ranges,
real construct coverage, extraction examples, and per-file evidence. A nonzero
exit status means syntax/range/incremental/anchor failure or missing coverage;
zero does **not** mean the graph is safe to edit.

The lossless representation is the original UTF-8 byte buffer plus CST ranges.
Reconstruction checks every node's parent bounds and row/byte-column coordinates,
and joins leaf slices with omitted whitespace/trivia gaps. It never pretty-prints.
Incremental parsing uses `ts_tree_edit` on a copied tree, then compares every node
against a fresh parse after Unicode/comment insertion. Anchors are tested after
that insertion; an additional fixture inserts unrelated lines inside an object.

Extraction distinguishes bindings, declarations, handler candidates, Connections,
Loader/LazyLoader/Variants lifecycle boundaries, Components and inline components.
It is deliberately not a resolver: signal names, QML types, attached properties,
lexical scope and dependencies are not validated. Every entry is read-only.
Grouped bindings, property interceptors and imperative `Qt.binding` stay opaque.
Anonymous scopes use structural ordinals; only line/comment movement stability
is promised. Duplicate member anchors are reported and cannot serve as identity.
Nested inline declarations are a negative fixture: the CST accepts them, while
the analyzer reports an unsupported QML construct. The Qt oracle also checks
diagnostic output because qmllint can warn with exit code zero.

The canonical validator discovers `test-spike-a.py`. Without the optional grammar,
its native tests explicitly skip; no test downloads dependencies. To count native
tests as evidence, run with the environment variable above.

Primary references: [QML grammar and ambiguity](https://github.com/yuja/tree-sitter-qmljs),
[Tree-sitter byte ranges](https://tree-sitter.github.io/tree-sitter/using-parsers/2-basic-parsing.html),
[incremental edits](https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html).

## Spike B

`GraphSandbox.qml` is a synthetic graph with Bar/Media-style categories, not
production UI or a resolved Workflow IR. `run-sandbox.py` requires optional
PySide6 (tested at Qt 6.11.2) and is intentionally outside the default regression
runner: desktop access and graphics drivers must be available explicitly.

```sh
# Interactive, independent window; never starts/reloads the shell.
python3 scripts/code-workflow/run-sandbox.py

# Repeatable input tests, software fallback; not a GPU performance comparison.
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  python3 scripts/code-workflow/run-sandbox.py --test --nodes 60

# Real Wayland Shape backend, synthetic combined workload, window closes itself.
QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl \
  python3 scripts/code-workflow/run-sandbox.py --benchmark 4 --nodes 100 --renderer curve --output /tmp/curve-100.json

# Per-process fractional rendering/input; does not change compositor settings.
QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl QT_SCALE_FACTOR=1.25 \
  python3 scripts/code-workflow/run-sandbox.py --test --benchmark 5 --nodes 60 --renderer curve --output /tmp/curve-125.json
```

Compare `geometry` and `curve` with 20, 60, 100 and 250 nodes. Reports record
the *actual* backend, logical window size, DPR, source hashes, visible nodes,
QObject/visual-delegate count, frame and GUI-timer intervals, model update time,
RSS and QML warnings. The window adapts to the size granted by the compositor;
benchmarks fit the entire graph before applying the combined workload. Hit
testing uses curve bounding boxes plus sampled segment distances, independent
of Shape containment, with a screen-space tolerance.

The 20 input checks include wheel/pixel scroll, node drag, middle-button pan,
Ctrl selection, Shift lasso, subflow restoration, arrow/Tab focus and synthetic
two-point pinch. QtTest wheel positions need the measured device-pixel adapter
on this Qt 6.11 host; production QML coordinates remain logical. The unchanged
pivot assertion will catch a different QtTest behavior on another version.

Routes use a per-node adjacency index. Both endpoints update once after a complete
node move; pan/zoom changes only the view transform. The dense routing test checks
every painted endpoint and verifies that unrelated paths are not updated.

```sh
# Owned nested Niri, paired old/new QML with the same harness and workload.
python3 scripts/code-workflow/run-graph-matrix.py --work-dir /tmp/graph-matrix-new \
  --baseline-revision 7387ef0a26081d56df816369d4d9d74fedbe2324 --seconds 8 --soak 600

# Native fractional scaling on an independent headless compositor.
python3 scripts/code-workflow/run-graph-matrix.py --work-dir /tmp/graph-scale-new \
  --sway /usr/bin/sway --scale 1.25 --seconds 8
```

The matrix creates private XDG paths and stops only its own compositor. It checks
the actual screen DPR and Shape renderer and retains every paired result. The
soak samples RSS, object/path counts and trace retention every ten seconds while
rebuilding every fifteen seconds. Timing buffers retain at most 16,384 samples;
their totals/window are explicit so harness storage cannot grow without bound.
Run one performance matrix at a time. These are opt-in desktop tools.

For Qt's profiler, use the Qt 6 `qmlprofiler` and an executable wrapper that runs
`python3 run-sandbox.py "$@"`; a direct Python executable consumes the profiler's
injected `-qmljsdebugger` argument as a Python option. The harness enables QML
debugging only when that explicit argument is present. Keep profiling separate
from uninstrumented timing runs. `summarize-profile.py trace.qtd` produces a compact
summary with a trace hash and inclusive durations; nested durations must not be
summed as wall time. Large raw traces stay in the supplied temporary work folder.

These are short experiments on one machine. QTest cadence and Python callbacks
affect timing. Synthetic pinch is not hardware touchpad acceptance; a per-process
scale is not compositor hotplug. No node budget, memory-leak verdict, permanent
renderer choice, live registry, picker or reload/rebind claim follows from them.

## Spike C — actual ii Bar runtime

```sh
python3 scripts/code-workflow/run-runtime.py --work-dir /tmp/hadalis-workflow-runtime-new
```

Requires Quickshell 0.3.1, Niri, a Wayland desktop and dbus-run-session. The
destination must not exist. The runner exports a committed Git tree, adds probe
hooks only to that temporary copy, then starts nested Niri and Quickshell with
isolated XDG paths and a private session bus. It never calls IPC on the installed
shell. Processes it starts are stopped in a finally block; logs/report remain.
No real credentials/config are copied. Audio/system bus are deliberately absent.

Actual BarContent, Media and ClockWidget register themselves through narrow
temporary hooks. Resources remains statically known and unloaded. The committed
ProbeShell is a staging template and deliberately does not import
`qs.workflowprobe`; `prepare-runtime.py` injects that import only after creating
the temporary exported `workflowprobe/qmldir`, so whole-repository QML module
verification never sees a dangling generated-only import. There is no recursive
item discovery, no read of LazyLoader.item, and no arbitrary property
serialization. Only geometry, enabled and visible enter runtime snapshots.
The Media probe carries a private sentinel that must not enter the report.

Ten live checks cover stable semantic/instance identity, safe snapshots, dormant
LazyLoader behavior, module destruction/recreation and static selection fallback.
Geometry is currently an explicit ii horizontal Bar adapter using QML-owned
anchors/window/output data; it is not a generic cross-window mapToGlobal promise.
See the committed evidence and current continuation status in
[CODE_WORKFLOW_HANDOFF.md](../../docs/CODE_WORKFLOW_HANDOFF.md).

## Spikes D/E — compositor input, picker and ordinary reload

```sh
bash scripts/code-workflow/build-pointer.sh /tmp/hadalis-workflow-pointer
python3 scripts/code-workflow/run-runtime.py --work-dir /tmp/hadalis-cde-niri-new \
  --spikes CDE --pointer /tmp/hadalis-workflow-pointer/pointer

# Optional independent two-output compositor matrix; requires sway + swaymsg.
python3 scripts/code-workflow/run-runtime.py --work-dir /tmp/hadalis-cde-sway-new \
  --spikes CDE --pointer /tmp/hadalis-workflow-pointer/pointer --sway /usr/bin/sway
```

The pointer helper requires a C compiler, wayland-client development files,
pkg-config and wayland-scanner. Its upstream protocol is pinned by revision and
SHA-256. The driver passes an explicit socket under its own private runtime
directory; it never falls back to the desktop socket. It keeps the virtual input
device alive throughout the sequence, because removing the last headless device
generates pointer-leave and invalidates an auto-hide experiment.

Niri runs nested in a window. Sway runs headless with two real wl_output objects,
scales 1.0/1.25, and actual disable/enable operations. This tests compositor-native
fractional coordinates and Qt screen destruction/recreation, not hardware hotplug
or Niri multi-monitor acceptance. A locally extracted Sway package can be passed
by path; the driver uses its adjacent `usr/lib` directory without system installs.

The picker uses actual layer-shell windows and the existing SettingsOverlay.
It waits for Settings teardown before creating picker input surfaces, consumes
the complete selection click, restores the page and viewport, and supports a
right-click cancel with keyboard interactivity None. Wire-protocol traces assert
Overlay layer, full anchors, no keyboard grab, no exclusive reservation, and
destruction of every picker surface before cleanup. Niri IPC independently
confirms the mapped layer/keyboard mode.

The driver tests actual Media click as a positive control, then explicitly resets
that fixture popup before the independent auto-hide test. Ephemeral popup focus
grabs are outside this milestone. Lock testing drives the real shell
GlobalStates.screenLocked signal; it does not authenticate or exercise PAM or a
physical session lock. Settings restoration uses its actual overlayCurrentPage,
since the published page field can remain -1 for the initial page 0.

E changes only a revision literal in the temporary shell.qml, allowing Quickshell
file watching to perform ordinary reload. It checks new QObject identities and
actual old-object destruction, stable selection/viewport, and reload while the
selected Media module is unloaded. Persistent state contains primitives only.
The restoration case uses Settings page 2 and non-default viewport metadata.
Actual-object birth markers and destruction signals identify each QObject
lifetime; memory addresses are recorded only as diagnostics and may be reused.
Fixture configuration uses Config.setNestedValue on the private XDG file so the
normal JSON mirror cannot silently overwrite direct JsonAdapter assignments.

Reports pin the source revision, QML/driver hashes and pointer binary hash.
The complete CDE matrix currently has 40 passing checks on Niri and 44 on Sway.
These probes are opt-in; do not add them to unattended static CI or run them
against the installed shell. The standard local module guard remains unchanged.
