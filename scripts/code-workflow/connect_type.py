#!/usr/bin/env python3
"""Research-only Connect type-compatibility proof.

This helper never changes Hadalis source and is not part of the production
runtime payload. It composes the reviewed Connect preview with two independent
forms of type evidence:

1. source-backed resolution of one simple parent-id member expression to an
   explicitly typed QML property declaration; and
2. a Qt qmllint oracle fixture using the reviewed parent QML module/type and
   target property.

The positive oracle must accept the resolved source type, while a negative
control must produce qmllint's incompatible-type diagnostic. Even a successful
proof does not change production Connect authorization: TYPE remains UNKNOWN,
CYCLE remains UNKNOWN, and Apply/artifact staging stay disabled.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from analyze import resolve_grammar, resolve_source
from connect_preview import (
    CYCLE_UNKNOWN,
    TYPE_UNKNOWN,
    coordinate_connect_preview,
    load_reviewed_connect_target,
)
from native import Parser, verify_ranges
from semantics import extract

PROTOCOL = 1
TYPE_PROOF = "compatible-qmllint-proof"
_SIMPLE_MEMBER = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)$"
)
_SIMPLE_QML_TYPE = re.compile(r"^[A-Z][A-Za-z0-9_]*$")
_SIMPLE_MODULE = re.compile(
    r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$"
)
_PROBE_INITIALIZERS = {
    "bool": "true",
}


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _blocked(
    phase: str,
    reason: str,
    target_id: str,
    connect_target_id: str,
    **evidence,
) -> dict:
    payload = {
        "status": "blocked",
        "phase": phase,
        "reason": reason,
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }
    payload.update(evidence)
    return payload


def resolve_parent_member_declared_type(
    entries: list[dict],
    parent_anchor: str,
    expression: str,
) -> dict:
    match = _SIMPLE_MEMBER.fullmatch(str(expression))
    if not match:
        return {
            "status": "unknown",
            "reason": "expression-is-not-one-simple-member-reference",
        }

    parent_matches = [
        entry for entry in entries
        if entry.get("anchor") == parent_anchor
    ]
    if len(parent_matches) != 1:
        return {
            "status": "unknown",
            "reason": "parent-semantic-anchor-not-unique",
        }

    parent = parent_matches[0]
    if (
        parent.get("kind") != "object"
        or parent.get("anchor_unique") is not True
        or parent.get("opaque_context") is True
    ):
        return {
            "status": "unknown",
            "reason": "parent-object-not-safe-for-type-resolution",
        }

    base_name, member_name = match.groups()
    qml_id = str(parent.get("qml_id") or "")
    if not qml_id or base_name != qml_id:
        return {
            "status": "unknown",
            "reason": "member-base-is-not-reviewed-parent-id",
        }

    scope = parent.get("scope")
    if not isinstance(scope, list) or not scope:
        return {
            "status": "unknown",
            "reason": "parent-object-has-no-semantic-scope",
        }

    candidates = [
        entry for entry in entries
        if entry.get("kind") == "property"
        and entry.get("scope") == scope
        and entry.get("name") == member_name
        and entry.get("anchor_unique") is True
        and entry.get("opaque_context") is not True
    ]
    if len(candidates) != 1:
        return {
            "status": "unknown",
            "reason": "source-property-declaration-not-unique",
        }

    declaration = candidates[0]
    declared_type = str(declaration.get("declared_type") or "")
    if not declared_type:
        return {
            "status": "unknown",
            "reason": "source-property-has-no-declared-type",
        }

    return {
        "status": "resolved",
        "parentSemanticAnchor": parent_anchor,
        "parentQmlId": qml_id,
        "propertySemanticAnchor": declaration.get("anchor", ""),
        "propertyName": member_name,
        "declaredType": declared_type,
    }


def _source_imports_module(source: bytes, module: str) -> bool:
    if not _SIMPLE_MODULE.fullmatch(module):
        return False
    pattern = re.compile(
        r"^\s*import\s+"
        + re.escape(module)
        + r"(?:\s+\d+(?:\.\d+)?)?\s*(?://.*)?$"
    )
    text = source.decode("utf-8")
    return sum(
        1 for line in text.splitlines()
        if pattern.fullmatch(line)
    ) == 1


def _local_directory_exports_type(source_path: Path, type_name: str) -> bool:
    if (source_path.parent / f"{type_name}.qml").is_file():
        return True
    qmldir = source_path.parent / "qmldir"
    if not qmldir.is_file():
        return False
    try:
        lines = qmldir.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return True
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("module "):
            continue
        fields = line.split()
        if fields and fields[0] == type_name:
            return True
    return False


def _find_qmllint(explicit: str) -> str | None:
    if explicit:
        resolved = shutil.which(explicit)
        if resolved:
            return resolved
        candidate = Path(explicit).expanduser()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate.resolve())
        return None

    env_value = os.environ.get("HADALIS_WORKFLOW_QMLLINT", "")
    if env_value:
        resolved = _find_qmllint(env_value)
        if resolved:
            return resolved

    candidates = (
        "/usr/lib/qt6/bin/qmllint",
        "/usr/lib/x86_64-linux-gnu/qt6/bin/qmllint",
        "qmllint6",
        "qmllint",
    )
    for candidate in candidates:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    return None


def _qmllint_version(tool: str) -> tuple[str, tuple[int, int] | None]:
    completed = subprocess.run(
        [tool, "--version"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=20,
    )
    rendered = (completed.stdout + "\n" + completed.stderr).strip()
    match = re.search(r"(?<!\d)(\d+)\.(\d+)(?:\.\d+)?", rendered)
    if not match:
        return rendered, None
    return rendered, (int(match.group(1)), int(match.group(2)))


def _diagnostic_blob(payload: object) -> str:
    return json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
    ).lower().replace("_", "-")


def _diagnostic_markers(payload: object) -> dict:
    blob = _diagnostic_blob(payload)
    return {
        "incompatibleType": (
            "incompatible-type" in blob
            or "incompatible type" in blob
        ),
        "unresolvedType": (
            "unresolved-type" in blob
            or "missing-type" in blob
            or "type was not found" in blob
            or "type not found" in blob
        ),
        "missingProperty": (
            "missing-property" in blob
            or "non-existent property" in blob
            or "does not have members" in blob
        ),
        "importFailure": (
            "failed to import module" in blob
            or "warnings occurred while importing" in blob
        ),
    }


def _qmllint_import_paths() -> list[str]:
    paths = []
    seen = set()
    for name in ("QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        raw = os.environ.get(name, "")
        for item in raw.split(os.pathsep):
            candidate = item.strip()
            if not candidate or candidate in seen:
                continue
            path = Path(candidate).expanduser()
            if not path.is_dir():
                continue
            resolved = str(path.resolve())
            if resolved in seen:
                continue
            seen.add(resolved)
            paths.append(resolved)
    return paths


def _run_qmllint_json(tool: str, source: str) -> dict:
    import_args = []
    for path in _qmllint_import_paths():
        import_args += ["-I", path]

    with tempfile.TemporaryDirectory(prefix="hadalis-connect-type-") as directory:
        path = Path(directory) / "TypeProbe.qml"
        path.write_text(source, encoding="utf-8")
        completed = subprocess.run(
            [
                tool,
                "--json", "-",
                "--ignore-settings",
                *import_args,
                str(path),
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30,
        )

    stdout = completed.stdout.strip()
    if not stdout:
        return {
            "status": "unavailable",
            "reason": "qmllint-produced-no-json",
            "returnCode": completed.returncode,
            "stderr": completed.stderr.strip(),
        }
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError as exc:
        return {
            "status": "unavailable",
            "reason": "qmllint-produced-invalid-json",
            "returnCode": completed.returncode,
            "detail": str(exc),
            "stderr": completed.stderr.strip(),
        }

    return {
        "status": "ok",
        "returnCode": completed.returncode,
        "markers": _diagnostic_markers(payload),
        "payload": payload,
        "stderr": completed.stderr.strip(),
    }


def _type_probe_source(
    module: str,
    parent_type: str,
    binding_name: str,
    source_type: str,
    initializer: str,
) -> str:
    return (
        f"import {module}\n\n"
        f"{parent_type} {{\n"
        f"    property {source_type} workflowSource: {initializer}\n"
        f"    {binding_name}: workflowSource\n"
        f"}}\n"
    )


def prove_connect_type_compatibility(
    root: Path,
    target_id: str,
    connect_target_id: str,
    grammar: str = "",
    library: str = "",
    qmllint: str = "",
) -> dict:
    try:
        descriptor = load_reviewed_connect_target(
            root, target_id, connect_target_id)
    except ValueError as exc:
        return _blocked(
            "descriptor",
            str(exc),
            target_id,
            connect_target_id,
        )

    parent_module = str(
        descriptor.get("reviewedParentTypeModule") or "")
    parent_type = str(
        descriptor.get("reviewedParentTypeName") or "")
    if not _SIMPLE_MODULE.fullmatch(parent_module):
        return _blocked(
            "descriptor",
            "reviewed-parent-type-module-invalid",
            target_id,
            connect_target_id,
        )
    if not _SIMPLE_QML_TYPE.fullmatch(parent_type):
        return _blocked(
            "descriptor",
            "reviewed-parent-type-name-invalid",
            target_id,
            connect_target_id,
        )

    preview = coordinate_connect_preview(
        root,
        target_id,
        connect_target_id,
        grammar,
        library,
    )
    if preview.get("status") != "preview":
        return _blocked(
            "connect-preview",
            str(preview.get("reason", "connect-preview-unavailable")),
            target_id,
            connect_target_id,
            connectPreviewStatus=preview.get("status", ""),
        )
    if preview.get("typeCompatibility") != TYPE_UNKNOWN:
        return _blocked(
            "connect-preview",
            "production-type-status-must-remain-unknown",
            target_id,
            connect_target_id,
        )

    try:
        source_path = resolve_source(root, descriptor["sourcePath"])
        source = source_path.read_bytes()
        source.decode("utf-8")
    except (ValueError, OSError, UnicodeError) as exc:
        return _blocked(
            "source",
            str(exc),
            target_id,
            connect_target_id,
        )

    source_sha = sha256(source).hexdigest()
    if source_sha != preview.get("baseSha256"):
        return _blocked(
            "source",
            "type-proof-source-sha-drift",
            target_id,
            connect_target_id,
            currentSha256=source_sha,
            previewSha256=preview.get("baseSha256", ""),
        )

    if not _source_imports_module(source, parent_module):
        return _blocked(
            "source",
            "reviewed-parent-type-module-import-not-unique",
            target_id,
            connect_target_id,
        )
    if _local_directory_exports_type(source_path, parent_type):
        return _blocked(
            "source",
            "reviewed-parent-type-shadowed-locally",
            target_id,
            connect_target_id,
        )

    grammar_path = resolve_grammar(root, grammar)
    if grammar_path is None:
        return _blocked(
            "source-type",
            "grammar-missing",
            target_id,
            connect_target_id,
        )

    native_parser = None
    try:
        native_parser = Parser(grammar_path, library or None)
        with native_parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(descriptor["sourcePath"], source, nodes)
    except OSError as exc:
        return _blocked(
            "source-type",
            "tree-sitter-library-missing",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return _blocked(
            "source-type",
            "source-type-analysis-failed",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    finally:
        if native_parser is not None:
            native_parser.close()

    if semantic["diagnostics"]:
        return _blocked(
            "source-type",
            "current-source-has-parser-diagnostics",
            target_id,
            connect_target_id,
        )

    parent_entries = [
        entry for entry in semantic["entries"]
        if entry.get("anchor") == preview.get("parentSemanticAnchor")
    ]
    if len(parent_entries) != 1:
        return _blocked(
            "source-type",
            "parent-semantic-anchor-not-unique",
            target_id,
            connect_target_id,
        )
    parent_entry = parent_entries[0]
    if parent_entry.get("name") != parent_type:
        return _blocked(
            "source-type",
            "reviewed-parent-type-name-drift",
            target_id,
            connect_target_id,
            resolvedParentType=parent_entry.get("name", ""),
        )

    source_type = resolve_parent_member_declared_type(
        semantic["entries"],
        str(preview.get("parentSemanticAnchor") or ""),
        descriptor["sourceExpression"],
    )
    if source_type.get("status") != "resolved":
        return _blocked(
            "source-type",
            str(source_type.get("reason", "source-type-unresolved")),
            target_id,
            connect_target_id,
        )

    declared_type = str(source_type.get("declaredType") or "")
    initializer = _PROBE_INITIALIZERS.get(declared_type)
    if initializer is None:
        return _blocked(
            "oracle",
            "source-type-not-in-first-qmllint-proof-subset",
            target_id,
            connect_target_id,
            sourceDeclaredType=declared_type,
        )

    tool = _find_qmllint(qmllint)
    if tool is None:
        return _blocked(
            "oracle",
            "qmllint-unavailable",
            target_id,
            connect_target_id,
        )
    version_text, version = _qmllint_version(tool)
    if version is None or version[0] != 6 or version < (6, 8):
        return _blocked(
            "oracle",
            "qmllint-version-unqualified",
            target_id,
            connect_target_id,
            qmllintVersion=version_text,
        )

    positive_source = _type_probe_source(
        parent_module,
        parent_type,
        descriptor["bindingName"],
        declared_type,
        initializer,
    )
    positive = _run_qmllint_json(tool, positive_source)
    if positive.get("status") != "ok":
        return _blocked(
            "oracle",
            str(positive.get("reason", "qmllint-positive-probe-failed")),
            target_id,
            connect_target_id,
            qmllintVersion=version_text,
        )
    positive_markers = positive.get("markers") or {}
    if positive.get("returnCode") != 0 or any(positive_markers.values()):
        return _blocked(
            "oracle",
            "qmllint-positive-probe-not-clean",
            target_id,
            connect_target_id,
            qmllintVersion=version_text,
            positiveReturnCode=positive.get("returnCode"),
            positiveMarkers=positive_markers,
        )

    negative_source = _type_probe_source(
        parent_module,
        parent_type,
        descriptor["bindingName"],
        "rect",
        "Qt.rect(0, 0, 1, 1)",
    )
    negative = _run_qmllint_json(tool, negative_source)
    if negative.get("status") != "ok":
        return _blocked(
            "oracle",
            str(negative.get("reason", "qmllint-negative-probe-failed")),
            target_id,
            connect_target_id,
            qmllintVersion=version_text,
        )
    negative_markers = negative.get("markers") or {}
    if negative_markers.get("incompatibleType") is not True:
        return _blocked(
            "oracle",
            "qmllint-negative-control-did-not-detect-incompatible-type",
            target_id,
            connect_target_id,
            qmllintVersion=version_text,
            negativeReturnCode=negative.get("returnCode"),
            negativeMarkers=negative_markers,
        )
    if (
        negative_markers.get("unresolvedType")
        or negative_markers.get("missingProperty")
        or negative_markers.get("importFailure")
    ):
        return _blocked(
            "oracle",
            "qmllint-negative-control-had-resolution-failures",
            target_id,
            connect_target_id,
            qmllintVersion=version_text,
            negativeMarkers=negative_markers,
        )

    return {
        "status": "proof",
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "sourcePath": descriptor["sourcePath"],
        "baseSha256": source_sha,
        "parentSemanticAnchor": preview.get("parentSemanticAnchor", ""),
        "parentTypeModule": parent_module,
        "parentTypeName": parent_type,
        "targetProperty": descriptor["bindingName"],
        "sourceExpression": descriptor["sourceExpression"],
        "sourcePropertySemanticAnchor": source_type.get(
            "propertySemanticAnchor", ""),
        "sourceDeclaredType": declared_type,
        "typeCompatibilityProof": TYPE_PROOF,
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "oracle": {
            "tool": "qmllint",
            "version": version_text,
            "importPaths": _qmllint_import_paths(),
            "positiveReturnCode": positive.get("returnCode"),
            "positiveMarkers": positive_markers,
            "negativeReturnCode": negative.get("returnCode"),
            "negativeMarkers": negative_markers,
        },
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--target-id", required=True)
    parser.add_argument("--connect-target-id", required=True)
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    parser.add_argument("--qmllint", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
            "typeCompatibility": TYPE_UNKNOWN,
            "cycleStatus": CYCLE_UNKNOWN,
            "applyEnabled": False,
            "artifactsStaged": False,
            "productionIntegrated": False,
        }, 4)

    result = prove_connect_type_compatibility(
        root,
        args.target_id,
        args.connect_target_id,
        args.grammar or os.environ.get("HADALIS_WORKFLOW_GRAMMAR", ""),
        args.library or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", ""),
        args.qmllint,
    )
    return emit(result, 0 if result.get("status") == "proof" else 7)


if __name__ == "__main__":
    raise SystemExit(main())
