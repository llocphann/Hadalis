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
