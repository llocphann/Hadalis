#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"FAIL: {message}: missing {token!r}")

identity = read("services/CodeWorkflowIdentity.qml")
runtime = read("services/CodeWorkflowRuntime.qml")
qmldir = read("services/qmldir")
shell = read("shell.qml")
background = read("modules/background/Background.qml")

require(qmldir,
        "singleton CodeWorkflowIdentity 1.0 CodeWorkflowIdentity.qml",
        "canonical identity service must be exported")

for token in (
    "function targetRef(targetId: string): var",
    "function instanceRef(targetId: string, instanceId: string): var",
    "function graphNodeRef(graphId: string, nodeId: string): var",
    "function sourceRef(sourcePath: string, semanticAnchor: string): var",
    "function isValid(ref): bool",
    "function key(ref): string",
    "function sanitize(ref): var",
    'kind: "target"',
    'kind: "instance"',
    'kind: "graph-node"',
    'kind: "source"',
):
    require(identity, token, "canonical TargetRef contract is incomplete")

# Diagnostics telemetry must reuse Workflow identity rather than smuggling its
# own presentation metadata into canonical references.
for forbidden in ("label:", "name:", "icon:", "title:"):
    if forbidden in identity:
        raise SystemExit(
            "FAIL: canonical identity references must remain ID-only; found "
            + repr(forbidden)
        )

for token in (
    "function identityConflictFields(left, right): var",
    '["label", "family", "kind", "parentId"]',
    "function _identityDescriptors(): var",
    "function computeIdentityCollisions(): var",
    "readonly property var localIdentityCollisions:",
    "readonly property var identityCollisions:",
    "function hasIdentityCollision(targetId: string): bool",
    "function canonicalTargetRef(targetId: string): var",
    "CodeWorkflowIdentity.targetRef(id)",
    "identityCollisions: root.localIdentityCollisions",
):
    require(runtime, token, "runtime identity collision contract is incomplete")

# Source path is deliberately evidence, not an identity-conflict field: two
# renderer/host variants may intentionally own the same canonical target while
# still satisfying the same label/family/kind/parent contract.
conflict_start = runtime.index("function identityConflictFields(")
conflict_end = runtime.index("function _identityDescriptors()", conflict_start)
conflict_block = runtime[conflict_start:conflict_end]
if '"sourcePath"' in conflict_block:
    raise SystemExit(
        "FAIL: alternate source-backed renderer variants must not collide "
        "solely because their sourcePath differs"
    )

# Existing future-facing panel canonicalization stays generic. Diagnostics must
# not add a fixed component-name table.
for token in (
    'if (id.startsWith("ii"))',
    'return root._kebabCase(id.slice(2))',
    'if (id.startsWith("w"))',
    'return "waffle/" + root._kebabCase(id.slice(1))',
):
    require(runtime, token, "future panel canonicalization regressed")

for token in (
    "function targetIdForCustomWidget(widgetId: string): string",
    'return "desktop-widget/custom/" + id',
):
    require(runtime, token,
            "custom widgets need one Workflow-owned canonical namespace")

for token in (
    "property CodeWorkflowRuntimeTarget workflowRuntimeTarget:",
    "runtimeObject: customWidgetLoader.item",
    "CodeWorkflowRuntime.targetIdForCustomWidget(",
    "customWidgetLoader.modelData?.id",
    'family: "custom-widget"',
    'parentId: "background"',
    "customWidgetLoader.modelData?.qmlPath",
):
    require(background, token,
            "dynamic custom widget loader must register Workflow runtime identity")

# Registration must remain generic: installing a new manifest ID should not
# require editing a known-widget list in Workflow/Diagnostics.
for forbidden in (
    'targetId: "desktop-widget/custom/',
    "KnownCustomWidgetTargets",
    "diagnosticsCustomWidgets",
):
    if forbidden in background or forbidden in runtime:
        raise SystemExit(
            "FAIL: custom-widget discovery must stay manifest-driven: "
            + forbidden
        )

for forbidden in (
    "KnownDiagnosticsComponents",
    "diagnosticsCatalog",
    "diagnosticsLabelForTarget",
):
    if forbidden in runtime or forbidden in shell:
        raise SystemExit(
            f"FAIL: Diagnostics must not own a parallel target catalog: {forbidden}"
        )

print("ok - canonical Workflow identity, collision, and custom-widget contract")
