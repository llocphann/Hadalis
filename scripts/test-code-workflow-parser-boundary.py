#!/usr/bin/env python3
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ANALYZER = ROOT / "scripts/code-workflow/analyze.py"
sys.path.insert(0, str(ANALYZER.parent))

import analyze as workflow_analyze
from native import Node


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def run(*args: str):
    return subprocess.run(
        [sys.executable, str(ANALYZER), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


source = ANALYZER.read_text(encoding="utf-8")
for forbidden in ("curl ", "wget ", "npm ", "node ", "subprocess."):
    if forbidden in source:
        fail("production analyzer must not download/build/spawn tooling: " + forbidden)
if "write_text(" in source or "write_bytes(" in source:
    fail("production analyzer must not write source")
if 'SYSTEM_GRAMMAR = Path("/usr/lib/inir/code-workflow/qmljs.so")' not in source:
    fail("analyzer must discover the optional system grammar package")
if 'QMLJS_VERSION = "0.3.1"' not in source:
    fail("analyzer grammar version metadata drifted")
if '"--needle",' not in source or "resolve_reviewed_anchor(" not in source:
    fail("analyzer must accept and resolve a reviewed source needle")

sample = b"Item {\n    foo: 1\n}\n"
sample_start = sample.index(b"foo: 1")
sample_end = sample_start + len(b"foo: 1")
sample_node = Node(
    "ui_binding",
    sample_start,
    sample_end,
    (1, 4),
    (1, 10),
    None,
    True,
    False,
    False,
    None,
)
sample_entry = {
    "anchor": "sample-anchor",
    "kind": "binding",
    "name": "foo",
    "range": [sample_start, sample_end],
}
resolved = workflow_analyze.resolve_reviewed_anchor(
    sample,
    [sample_node],
    [sample_entry],
    "foo: 1",
)
if resolved.get("status") != "resolved":
    fail("unique reviewed needle must resolve")
if resolved.get("needleRange") != [sample_start, sample_end]:
    fail("resolved reviewed needle byte range drifted")
if resolved.get("cstKind") != "ui_binding":
    fail("resolved reviewed needle must expose enclosing CST kind")
if resolved.get("semanticAnchor") != "sample-anchor":
    fail("resolved reviewed needle must expose enclosing semantic entry")

ambiguous = workflow_analyze.resolve_reviewed_anchor(
    b"foo: 1\nfoo: 1\n",
    [sample_node],
    [sample_entry],
    "foo: 1",
)
if ambiguous.get("status") != "ambiguous" or ambiguous.get("occurrences") != 2:
    fail("ambiguous reviewed needle must fail closed")

missing_anchor = workflow_analyze.resolve_reviewed_anchor(
    sample,
    [sample_node],
    [sample_entry],
    "bar: 2",
)
if missing_anchor.get("status") != "missing":
    fail("missing reviewed needle must fail closed")

missing = run(
    "--root", str(ROOT),
    "--path", "modules/bar/Media.qml",
    "--grammar", str(ROOT / ".definitely-missing-qmljs.so"),
)
if missing.returncode != 3:
    fail("missing grammar must return capability-unavailable exit 3")
try:
    missing_payload = json.loads(missing.stdout)
except json.JSONDecodeError as exc:
    fail("missing grammar result is not JSON: " + str(exc))
if missing_payload.get("protocol") != 1:
    fail("analyzer protocol must be version 1")
if missing_payload.get("status") != "unavailable":
    fail("missing grammar must report unavailable")
if missing_payload.get("reason") != "grammar-missing":
    fail("missing grammar reason drifted")

escaped = run(
    "--root", str(ROOT),
    "--path", "../outside.qml",
    "--grammar", str(ROOT / ".definitely-missing-qmljs.so"),
)
if escaped.returncode != 4:
    fail("path escape must be rejected before parser capability checks")
escaped_payload = json.loads(escaped.stdout)
if escaped_payload.get("status") != "invalid-request":
    fail("path escape must report invalid-request")
if "escapes runtime root" not in escaped_payload.get("reason", ""):
    fail("path escape reason must remain explicit")

wrong_type = run(
    "--root", str(ROOT),
    "--path", "README.md",
    "--grammar", str(ROOT / ".definitely-missing-qmljs.so"),
)
if wrong_type.returncode != 4:
    fail("non-QML source must be rejected")

service = (ROOT / "services/CodeWorkflowAnalyzer.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")

for token in (
    "singleton CodeWorkflowAnalyzer 1.0 CodeWorkflowAnalyzer.qml",
):
    if token not in qmldir:
        fail("services/qmldir missing analyzer singleton")

for token in (
    'property string status: "idle"',
    'property string sourceNeedle: ""',
    'property var reviewedAnchor: ({ status: "not-requested" })',
    'function request(path: string, needle: string, force: bool): void',
    'Quickshell.shellPath("scripts/code-workflow/analyze.py")',
    '"--path", nextPath',
    'command.push("--needle", nextNeedle)',
    'payload?.status === "unavailable"',
    "StdioCollector",
):
    if token not in service:
        fail("analyzer service missing " + token)

for token in (
    "CodeWorkflowAnalyzer.request(",
    "root.sourceNeedle,",
    "root.sourceAnchorEvidence",
    "root.sourceRangeText",
    "CodeWorkflowAnalyzer.entryCount",
    "CodeWorkflowAnalyzer.diagnostics.length",
):
    if token not in page:
        fail("Code Workflow page missing analyzer integration " + token)

payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"), "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
runtime_paths = set(payload)

for required in (
    "scripts/code-workflow/analyze.py",
    "scripts/code-workflow/native.py",
    "scripts/code-workflow/semantics.py",
):
    if required not in runtime_paths:
        fail("production parser core missing from runtime payload: " + required)

for excluded in (
    "scripts/code-workflow/GraphSandbox.qml",
    "scripts/code-workflow/build-parser.sh",
    "scripts/code-workflow/corpus.py",
    "scripts/code-workflow/run-runtime.py",
    "scripts/code-workflow/runtime/PickerProbe.qml",
    "scripts/code-workflow/virtual-pointer.c",
):
    if excluded in runtime_paths:
        fail("Phase 0 harness leaked into runtime payload: " + excluded)

parser_pkg_path = ROOT / "distro/arch/inir-workflow-parser/PKGBUILD"
parser_srcinfo_path = ROOT / "distro/arch/inir-workflow-parser/.SRCINFO"
if not parser_pkg_path.is_file() or not parser_srcinfo_path.is_file():
    fail("optional Arch parser package recipe/.SRCINFO is missing")

parser_pkg = parser_pkg_path.read_text(encoding="utf-8")
parser_srcinfo = parser_srcinfo_path.read_text(encoding="utf-8")
for token in (
    "pkgname=inir-workflow-parser",
    "pkgver=0.3.1",
    "arch=(x86_64)",
    "depends=(glibc tree-sitter)",
    "e6ed3a7040df54fed1183801ad482139622bf9b9ec1c5f7ee36c5ece25806c58",
    "src/parser.c src/scanner.c",
    "${pkgdir}/usr/lib/inir/code-workflow/qmljs.so",
):
    if token not in parser_pkg:
        fail("parser PKGBUILD missing " + token)

for token in (
    "pkgbase = inir-workflow-parser",
    "\tpkgver = 0.3.1",
    "\tarch = x86_64",
    "\tdepends = glibc",
    "\tdepends = tree-sitter",
    "\tsha256sums = e6ed3a7040df54fed1183801ad482139622bf9b9ec1c5f7ee36c5ece25806c58",
):
    if token not in parser_srcinfo:
        fail("parser .SRCINFO missing " + token)

syntax = subprocess.run(
    ["bash", "-n", str(parser_pkg_path)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)
if syntax.returncode != 0:
    fail("parser PKGBUILD is not valid Bash: " + syntax.stderr.strip())

git_pkg = (ROOT / "distro/arch/inir-shell-git/PKGBUILD").read_text(encoding="utf-8")
git_srcinfo = (ROOT / "distro/arch/inir-shell-git/.SRCINFO").read_text(encoding="utf-8")
capability = "inir-workflow-parser: native QML parser capability for Code Workflow"
if capability not in git_pkg or ("\toptdepends = " + capability) not in git_srcinfo:
    fail("inir-shell-git must advertise the optional parser capability")
if re.search(r"^[ \t]+inir-workflow-parser$", git_pkg, re.MULTILINE):
    fail("inir-shell-git must not hard-depend on the optional parser capability")

deps_pkg = (ROOT / "sdata/dist-arch/inir-deps/PKGBUILD").read_text(encoding="utf-8")
if capability not in deps_pkg:
    fail("source-install dependency tracker must know the optional parser capability")

stable_pkg = (ROOT / "distro/arch/inir-shell/PKGBUILD").read_text(encoding="utf-8")
stable_srcinfo = (ROOT / "distro/arch/inir-shell/.SRCINFO").read_text(encoding="utf-8")
match = re.search(r'_source_ref="\$\{INIR_SOURCE_REF:-([^}]+)\}"', stable_pkg)
if not match:
    fail("cannot resolve stable inir-shell source snapshot")
stable_ref = match.group(1)
snapshot_has_analyzer = subprocess.run(
    ["git", "cat-file", "-e", f"{stable_ref}:scripts/code-workflow/analyze.py"],
    cwd=ROOT,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
).returncode == 0
stable_advertises = capability in stable_pkg and ("\toptdepends = " + capability) in stable_srcinfo
if snapshot_has_analyzer != stable_advertises:
    fail("stable parser optdepend must match whether its pinned source snapshot contains the analyzer")

print("ok - Code Workflow parser process boundary, native capability package, and runtime payload contract")
