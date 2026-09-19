# Code Workflow Editor: Phase 0 evidence

This records experiments, not production readiness. The editor design is in
[CODE_WORKFLOW_EDITOR.md](CODE_WORKFLOW_EDITOR.md); reproducible probes are in
[scripts/code-workflow](../scripts/code-workflow/README.md).

## Spike A — corpus/range feasibility: pass for continued prototyping

Corpus revision: `bad2981208f8d46fe03f1f9ad9403555f8300bf2` on `dev`.
Manifest SHA-256: `e6594577d823bc6936442fbbf7f32738457db01fe0aa9327d93de612eb83935e`.
The runner reads committed Git objects so subsequent dev/working-tree changes
do not change the evidence. Re-run for any later source revision.

Candidate: tree-sitter-qmljs **0.3.1**, upstream
`de96ed62abded51fcdfcbeaaa120e0dd0d20c697`, released generated C parser/scanner,
libtree-sitter **0.26.9**, Python **3.14.7** standard-library test driver,
Qt **6.11.2**, Linux x86_64. The pinned crate SHA-256 is
`e6ed3a7040df54fed1183801ad482139622bf9b9ec1c5f7ee36c5ece25806c58`.
Two independent temporary builds succeeded without Node.js or Python packages.
Rust's toolchain was unavailable on this host. No dependency was added to Hadalis
installation, startup, package manifests, or Nix support.

| Evidence | Result |
| --- | ---: |
| Tracked QML files / parsed without ERROR or missing nodes | 1,005 / 1,005 |
| Source bytes / CST nodes checked | 12,025,692 / 2,491,730 |
| Comments retained | 11,172 |
| Byte-identical leaf + trivia-gap reconstruction | 1,005 / 1,005 |
| Incremental edit/reparse equals a fresh CST | 1,005 / 1,005 |
| Extraction anchors unchanged after Unicode/comment prefix insertion | 1,005 / 1,005 |
| Native regression tests, including Qt diagnostic oracle | 16 passed |
| Complete corpus run (includes extraction and 3 parses/file) | 87.669 seconds |

Timing is the developer harness wall time, not parser-only throughput or a
runtime latency claim. Fixtures additionally cover an insertion inside an
object, CRLF, BOM, Unicode byte offsets, comments, missing final newline,
malformed syntax/encoding, duplicate anchors, and opaque JavaScript bodies.

Real extraction includes 81,830 bindings, 16,142 property declarations,
6,963 handler candidates, 419 Connections, 840 lifecycle objects, 272 Component
objects, 223 inline component declarations, and 18 explicit Binding objects.
The required Bar/Media, dashboard, overview, SettingsPageHost, NiriService,
ShellEditSession and Waffle files are all included. These are source-backed
syntax candidates, not type-resolved Workflow IR or verified reactive edges.

### Ambiguity and unsupported semantics

All extracted entries remain read-only. The JSON report enumerates each opaque
range and reason; `--inspect PATH` emits complete extraction for a source file.

| Construct | Count | Policy |
| --- | ---: | --- |
| Lowercase/grouped object notation | 760 | Opaque, including its descendants; type/scope disambiguation required |
| Property interceptors/value sources (`Behavior on`, etc.) | 1,932 | Opaque; preserve target and source span |
| Imperative `Qt.binding` | 12 | Opaque script; never relabel as a declarative binding wire |

Repeated opaque `Qt.binding` calls produce anchor collisions in
`MediaControlsWidget.qml`, `OverviewNiriWidget.qml`, and Waffle's
`WindowThumbnail.qml`. They are explicitly flagged non-unique and cannot become
persistent selection IDs. Anonymous object anchors use structural ordinals:
comment/line insertion stability is proven, arbitrary structural edits are not.
Import/type resolution, attached properties, lexical dependency resolution,
signal existence, and robust reconciliation remain future semantic work.

### A useful rejection probe

The design's original valid-corpus requirement for *nested inline declarations*
was impossible: [Qt does not support them](https://doc.qt.io/qt-6/qtqml-documents-definetypes.html).
There are none in the real corpus. It now requires valid inline declarations
and nested Component/Loader boundaries, with a separate negative fixture.

For `Item { component A: Item { component B: Item {} } }`:

- tree-sitter produces a clean CST;
- qmlformat 6.11.2 returns success;
- qmllint 6.11.2 emits `[syntax]` but returns zero;
- QQmlComponent 6.11.2 rejects creation with a nested-inline diagnostic.

The prototype analyzer marks this unsupported construct opaque and reports a
diagnostic. This proves why neither CST success nor validator exit code alone
can authorize a transform. The eventual transaction validator must consume
diagnostics and distinguish syntax acceptance from semantic/runtime validity.

### Decision and remaining gates

Keep tree-sitter-qmljs as the viable **CST/range candidate** for Phase 0. The
probe preserves original source bytes and source slices; it does not serialize
a tree into QML or implement a source-writing transform. The optional native
test dependency is skipped explicitly when unavailable to the normal validator.

Runtime helper language/JSON-lines protocol, packaging across supported install
paths, semantic resolution and source transaction safety are **not proven**.
This is sufficient to continue to independent renderer/input experiments; it
does not select a permanent runtime dependency or authorize production editing.

## Remaining spikes

| Spike | Evidence status | Next gate |
| --- | --- | --- |
| B — renderer/input | Next experiment | Actual Shape backend, pointer/keyboard interactions and measured performance |
| C — ii Bar registry | Not started | Real resident/unloaded targets, stable identity, allowlisted snapshots, no forced loading |
| D — picker | Not started | Multi-output lifecycle, presentation hold, Settings restore, click isolation and lock cancellation |
| E — reload/rebind | Not started | Actual QObject destruction/replacement, static fallback and selection survival |

No production Code Workflow UI or source-writing operation is ready. Phase 0
must complete A–E before implementing the first source-writing transform.
