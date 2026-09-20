#!/usr/bin/env python3
"""Research-only Connect dependency/cycle coverage proof.

This helper deliberately does not authorize production Connect. It proves only a
small parser-resolved local dependency subset:

- the reviewed source expression is one explicit parent-id member reference;
- every traversed same-object property/binding is uniquely resolved by semantic
  scope and remains non-opaque;
- each dependency value is either another explicit parent-id member reference or
  a direct literal terminal.

Within that closed subset, reaching the absent target property proves a cycle and
reaching only literal terminals proves acyclicity. Any external object, complex
expression, unqualified identifier, missing/ambiguous member, or opaque semantic
entry remains UNKNOWN. The reviewed presentation graph is never treated as a
complete dependency graph.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re

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
PROVEN_CYCLE = "cycle-proven-local-closure"
PROVEN_ACYCLIC = "acyclic-closed-local-closure"
PROVEN_ACYCLIC_CROSS_FILE = "acyclic-source-backed-cross-file-closure"
PROOF_UNKNOWN = "unknown-incomplete-local-closure"
_LITERAL_VALUE_KINDS = {"true", "false", "number", "string"}
_LITERAL_FALLBACKS = {"true", "false"}
_SIMPLE_MEMBER = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)$"
)
_QS_IMPORT = re.compile(
    r"^\s*import\s+(qs(?:\.[A-Za-z_][A-Za-z0-9_]*)+)"
    r"(?:\s+\d+(?:\.\d+)?)?\s*(?://.*)?$"
)


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
        "cycleSafetyProof": PROOF_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "typeCompatibility": TYPE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }
    payload.update(evidence)
    return payload


def _value_text(source: bytes, entry: dict) -> str | None:
    span = entry.get("value_range")
    if (
        not isinstance(span, list)
        or len(span) != 2
        or not all(isinstance(item, int) for item in span)
        or not (0 <= span[0] <= span[1] <= len(source))
    ):
        return None
    try:
        return source[span[0]:span[1]].decode("utf-8").strip()
    except UnicodeError:
        return None



def _take_identifier(text: str, index: int) -> tuple[str | None, int]:
    if index >= len(text):
        return None, index
    first = text[index]
    if not (first == "_" or first.isalpha()):
        return None, index
    end = index + 1
    while end < len(text):
        char = text[end]
        if not (char == "_" or char.isalnum()):
            break
        end += 1
    return text[index:end], end


def parse_optional_member_chain_with_literal_fallback(
    expression: str,
) -> dict:
    parts = str(expression).split("??")
    if len(parts) != 2:
        return {
            "status": "unknown",
            "reason": "expression-is-not-one-nullish-member-chain",
        }

    left = parts[0].strip()
    fallback = parts[1].strip()
    if fallback not in _LITERAL_FALLBACKS:
        return {
            "status": "unknown",
            "reason": "nullish-fallback-outside-literal-subset",
        }

    base, index = _take_identifier(left, 0)
    if base is None:
        return {
            "status": "unknown",
            "reason": "external-chain-base-invalid",
        }

    path = []
    optional_hops = []
    while index < len(left):
        optional = False
        if left.startswith("?.", index):
            optional = True
            index += 2
        elif left[index:index + 1] == ".":
            index += 1
        else:
            return {
                "status": "unknown",
                "reason": "external-chain-syntax-outside-subset",
            }

        member, index = _take_identifier(left, index)
        if member is None:
            return {
                "status": "unknown",
                "reason": "external-chain-member-invalid",
            }
        path.append(member)
        optional_hops.append(optional)

    if not path:
        return {
            "status": "unknown",
            "reason": "external-chain-has-no-members",
        }

    return {
        "status": "resolved",
        "base": base,
        "path": path,
        "optionalHops": optional_hops,
        "fallbackLiteral": fallback,
    }


def _resolve_imported_local_singleton(
    root: Path,
    consumer_source: bytes,
    singleton_name: str,
) -> dict:
    try:
        text = consumer_source.decode("utf-8")
    except UnicodeError:
        return {
            "status": "unknown",
            "reason": "consumer-source-not-utf8",
        }

    matches = []
    for line in text.splitlines():
        import_match = _QS_IMPORT.fullmatch(line)
        if import_match is None:
            continue
        module_uri = import_match.group(1)
        module_parts = module_uri.split(".")[1:]
        if not module_parts:
            continue
        module_dir = (root.joinpath(*module_parts)).resolve()
        try:
            module_dir.relative_to(root)
        except ValueError:
            return {
                "status": "unknown",
                "reason": "local-module-path-escapes-runtime-root",
            }
        qmldir = module_dir / "qmldir"
        if not qmldir.is_file():
            continue
        try:
            lines = qmldir.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            return {
                "status": "unknown",
                "reason": "local-module-qmldir-unreadable",
            }

        for raw in lines:
            fields = raw.split("#", 1)[0].strip().split()
            if (
                len(fields) >= 4
                and fields[0] == "singleton"
                and fields[1] == singleton_name
            ):
                source_name = fields[-1]
                if not source_name.endswith(".qml"):
                    continue
                source_path = (module_dir / source_name).resolve()
                try:
                    relative = source_path.relative_to(root)
                except ValueError:
                    return {
                        "status": "unknown",
                        "reason": "singleton-source-escapes-runtime-root",
                    }
                if not source_path.is_file():
                    return {
                        "status": "unknown",
                        "reason": "singleton-source-missing",
                    }
                matches.append({
                    "moduleUri": module_uri,
                    "sourcePath": relative.as_posix(),
                })

    if len(matches) != 1:
        return {
            "status": "unknown",
            "reason": "local-singleton-export-not-unique",
            "occurrences": len(matches),
        }

    result = dict(matches[0])
    result["status"] = "resolved"
    return result


def _resolve_alias_nested_literal(
    source: bytes,
    entries: list[dict],
    alias_name: str,
    nested_path: list[str],
) -> dict:
    if not nested_path:
        return {
            "status": "unknown",
            "reason": "external-nested-path-empty",
        }

    alias_matches = [
        entry for entry in entries
        if entry.get("kind") == "property"
        and entry.get("name") == alias_name
        and entry.get("declared_type") == "alias"
        and entry.get("anchor_unique") is True
        and entry.get("opaque_context") is not True
    ]
    if len(alias_matches) != 1:
        return {
            "status": "unknown",
            "reason": "external-alias-not-unique",
            "occurrences": len(alias_matches),
        }

    alias_entry = alias_matches[0]
    if alias_entry.get("value_kind") != "identifier":
        return {
            "status": "unknown",
            "reason": "external-alias-target-not-identifier",
        }
    alias_target_id = _value_text(source, alias_entry)
    if not alias_target_id:
        return {
            "status": "unknown",
            "reason": "external-alias-target-unavailable",
        }

    object_matches = [
        entry for entry in entries
        if entry.get("kind") == "object"
        and entry.get("qml_id") == alias_target_id
        and entry.get("anchor_unique") is True
        and entry.get("opaque_context") is not True
    ]
    if len(object_matches) != 1:
        return {
            "status": "unknown",
            "reason": "external-alias-object-not-unique",
            "occurrences": len(object_matches),
        }

    current_object = object_matches[0]
    alias_scope = alias_entry.get("scope")
    current_scope = current_object.get("scope")
    if (
        not isinstance(alias_scope, list)
        or not isinstance(current_scope, list)
        or current_scope[:len(alias_scope)] != alias_scope
        or any(
            str(segment).startswith("component:")
            for segment in current_scope[len(alias_scope):]
        )
    ):
        return {
            "status": "unknown",
            "reason": "external-alias-object-crosses-component-scope",
        }

    traversed = [alias_name]
    for segment in nested_path[:-1]:
        property_matches = [
            entry for entry in entries
            if entry.get("kind") == "property"
            and entry.get("scope") == current_scope
            and entry.get("name") == segment
            and entry.get("anchor_unique") is True
            and entry.get("opaque_context") is not True
        ]
        if len(property_matches) != 1:
            return {
                "status": "unknown",
                "reason": "external-container-property-not-unique",
                "dependencyPath": [*traversed, segment],
                "occurrences": len(property_matches),
            }

        property_entry = property_matches[0]
        if property_entry.get("declared_type") != "JsonObject":
            return {
                "status": "unknown",
                "reason": "external-container-type-outside-jsonobject-subset",
                "dependencyPath": [*traversed, segment],
                "declaredType": property_entry.get("declared_type", ""),
            }

        value_range = property_entry.get("value_range")
        if (
            not isinstance(value_range, list)
            or len(value_range) != 2
            or not all(isinstance(item, int) for item in value_range)
        ):
            return {
                "status": "unknown",
                "reason": "external-container-value-range-unavailable",
                "dependencyPath": [*traversed, segment],
            }

        child_objects = [
            entry for entry in entries
            if entry.get("kind") == "object"
            and entry.get("name") == "JsonObject"
            and entry.get("anchor_unique") is True
            and entry.get("opaque_context") is not True
            and isinstance(entry.get("range"), list)
            and len(entry["range"]) == 2
            and value_range[0] <= entry["range"][0]
            and entry["range"][1] <= value_range[1]
            and isinstance(entry.get("scope"), list)
            and entry["scope"][:len(current_scope)] == current_scope
            and len(entry["scope"]) == len(current_scope) + 1
        ]
        if len(child_objects) != 1:
            return {
                "status": "unknown",
                "reason": "external-jsonobject-value-not-unique",
                "dependencyPath": [*traversed, segment],
                "occurrences": len(child_objects),
            }

        current_object = child_objects[0]
        current_scope = current_object["scope"]
        traversed.append(segment)

    terminal_name = nested_path[-1]
    terminal_matches = [
        entry for entry in entries
        if entry.get("kind") == "property"
        and entry.get("scope") == current_scope
        and entry.get("name") == terminal_name
        and entry.get("anchor_unique") is True
        and entry.get("opaque_context") is not True
    ]
    if len(terminal_matches) != 1:
        return {
            "status": "unknown",
            "reason": "external-terminal-property-not-unique",
            "dependencyPath": [*traversed, terminal_name],
            "occurrences": len(terminal_matches),
        }

    terminal = terminal_matches[0]
    value_kind = str(terminal.get("value_kind") or "")
    value_text = _value_text(source, terminal)
    if value_kind not in _LITERAL_VALUE_KINDS or value_text is None:
        return {
            "status": "unknown",
            "reason": "external-terminal-is-not-direct-literal",
            "dependencyPath": [*traversed, terminal_name],
            "terminalValueKind": value_kind,
        }

    return {
        "status": "resolved",
        "aliasTargetId": alias_target_id,
        "dependencyPath": [*traversed, terminal_name],
        "terminalPropertySemanticAnchor": terminal.get("anchor", ""),
        "terminalDeclaredType": terminal.get("declared_type", ""),
        "terminalValueKind": value_kind,
        "terminalValueText": value_text,
    }


def prove_cross_file_dependency_closure(
    root: Path,
    grammar_path: Path,
    library: str,
    consumer_source: bytes,
    consumer_entries: list[dict],
    parent_anchor: str,
    source_expression: str,
    target_property: str,
) -> dict:
    parent_matches = [
        entry for entry in consumer_entries
        if entry.get("anchor") == parent_anchor
    ]
    if len(parent_matches) != 1:
        return {
            "status": "unknown",
            "reason": "cross-file-parent-semantic-anchor-not-unique",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    parent = parent_matches[0]
    source_ref = _SIMPLE_MEMBER.fullmatch(str(source_expression))
    if (
        source_ref is None
        or parent.get("kind") != "object"
        or parent.get("anchor_unique") is not True
        or parent.get("opaque_context") is True
        or source_ref.group(1) != str(parent.get("qml_id") or "")
    ):
        return {
            "status": "unknown",
            "reason": "cross-file-source-member-not-resolved",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    scope = parent.get("scope")
    if not isinstance(scope, list) or not scope:
        return {
            "status": "unknown",
            "reason": "cross-file-parent-scope-unavailable",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    source_member = source_ref.group(2)
    if source_member == target_property:
        return {
            "status": "proven-cycle",
            "reason": "dependency-closure-reaches-connect-target",
            "cycleSafetyProof": PROVEN_CYCLE,
            "cycleKind": "proposed-target-cycle",
            "dependencyPath": [source_member, target_property],
        }

    source_matches = [
        entry for entry in consumer_entries
        if entry.get("kind") in {"property", "binding"}
        and entry.get("scope") == scope
        and entry.get("name") == source_member
        and entry.get("anchor_unique") is True
        and entry.get("opaque_context") is not True
    ]
    if len(source_matches) != 1:
        return {
            "status": "unknown",
            "reason": "cross-file-source-property-not-unique",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member],
            "occurrences": len(source_matches),
        }

    source_entry = source_matches[0]
    expression = _value_text(consumer_source, source_entry)
    if expression is None:
        return {
            "status": "unknown",
            "reason": "cross-file-source-value-unavailable",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member],
        }

    parsed = parse_optional_member_chain_with_literal_fallback(expression)
    if parsed.get("status") != "resolved":
        return {
            "status": "unknown",
            "reason": parsed.get(
                "reason", "cross-file-expression-outside-subset"),
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member],
            "dependencyValueKind": source_entry.get("value_kind", ""),
        }

    path = parsed["path"]
    if len(path) < 2:
        return {
            "status": "unknown",
            "reason": "cross-file-chain-too-short",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member],
        }

    singleton = _resolve_imported_local_singleton(
        root, consumer_source, parsed["base"])
    if singleton.get("status") != "resolved":
        return {
            "status": "unknown",
            "reason": singleton.get(
                "reason", "cross-file-singleton-unresolved"),
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member, parsed["base"]],
        }

    external_path = (root / singleton["sourcePath"]).resolve()
    try:
        external_source = external_path.read_bytes()
        external_source.decode("utf-8")
    except (OSError, UnicodeError) as exc:
        return {
            "status": "unknown",
            "reason": "cross-file-singleton-source-read-failed",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member, parsed["base"]],
            "detail": str(exc),
        }

    if sum(
        1 for line in external_source.decode("utf-8").splitlines()
        if line.strip() == "pragma Singleton"
    ) != 1:
        return {
            "status": "unknown",
            "reason": "cross-file-singleton-pragma-not-unique",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member, parsed["base"]],
        }

    parser = None
    try:
        parser = Parser(grammar_path, library or None)
        with parser.parse(external_source) as (_, nodes):
            verify_ranges(external_source, nodes)
            semantic = extract(
                singleton["sourcePath"], external_source, nodes)
    except (OSError, RuntimeError, AssertionError, UnicodeError) as exc:
        return {
            "status": "unknown",
            "reason": "cross-file-singleton-analysis-failed",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member, parsed["base"]],
            "detail": str(exc),
        }
    finally:
        if parser is not None:
            parser.close()

    if semantic["diagnostics"]:
        return {
            "status": "unknown",
            "reason": "cross-file-singleton-has-parser-diagnostics",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [source_member, parsed["base"]],
        }

    nested = _resolve_alias_nested_literal(
        external_source,
        semantic["entries"],
        path[0],
        path[1:],
    )
    if nested.get("status") != "resolved":
        result = dict(nested)
        result.update({
            "status": "unknown",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [
                source_member,
                parsed["base"],
                *nested.get("dependencyPath", []),
            ],
            "externalSourcePath": singleton["sourcePath"],
            "externalSourceSha256": sha256(external_source).hexdigest(),
        })
        return result

    return {
        "status": "proven-acyclic",
        "reason": "source-backed-cross-file-chain-ends-in-literal",
        "cycleSafetyProof": PROVEN_ACYCLIC_CROSS_FILE,
        "dependencyPath": [
            source_member,
            parsed["base"],
            *nested["dependencyPath"],
        ],
        "externalModuleUri": singleton["moduleUri"],
        "externalSourcePath": singleton["sourcePath"],
        "externalSourceSha256": sha256(external_source).hexdigest(),
        "aliasTargetId": nested["aliasTargetId"],
        "terminalPropertySemanticAnchor":
            nested["terminalPropertySemanticAnchor"],
        "terminalDeclaredType": nested["terminalDeclaredType"],
        "terminalValueKind": nested["terminalValueKind"],
        "terminalValueText": nested["terminalValueText"],
        "fallbackLiteral": parsed["fallbackLiteral"],
    }


def prove_local_dependency_closure(
    source: bytes,
    entries: list[dict],
    parent_anchor: str,
    source_expression: str,
    target_property: str,
) -> dict:
    parent_matches = [
        entry for entry in entries
        if entry.get("anchor") == parent_anchor
    ]
    if len(parent_matches) != 1:
        return {
            "status": "unknown",
            "reason": "parent-semantic-anchor-not-unique",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    parent = parent_matches[0]
    if (
        parent.get("kind") != "object"
        or parent.get("anchor_unique") is not True
        or parent.get("opaque_context") is True
    ):
        return {
            "status": "unknown",
            "reason": "parent-object-not-safe-for-cycle-resolution",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    parent_id = str(parent.get("qml_id") or "")
    scope = parent.get("scope")
    if (
        not parent_id
        or not isinstance(scope, list)
        or not scope
        or not isinstance(target_property, str)
        or not target_property
    ):
        return {
            "status": "unknown",
            "reason": "parent-cycle-identity-incomplete",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    def parse_member(expression: str) -> tuple[str, str] | None:
        match = _SIMPLE_MEMBER.fullmatch(str(expression))
        if not match:
            return None
        return match.group(1), match.group(2)

    start_ref = parse_member(source_expression)
    if start_ref is None:
        return {
            "status": "unknown",
            "reason": "source-expression-outside-explicit-member-subset",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }
    if start_ref[0] != parent_id:
        return {
            "status": "unknown",
            "reason": "source-expression-base-is-external",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    completed: set[str] = set()

    def walk(member_name: str, stack: list[str]) -> dict:
        path = [*stack, member_name]
        if member_name == target_property:
            return {
                "status": "proven-cycle",
                "reason": "dependency-closure-reaches-connect-target",
                "cycleSafetyProof": PROVEN_CYCLE,
                "cycleKind": "proposed-target-cycle",
                "dependencyPath": path,
            }

        if member_name in stack:
            cycle_start = stack.index(member_name)
            return {
                "status": "proven-cycle",
                "reason": "existing-cycle-in-source-dependency-closure",
                "cycleSafetyProof": PROVEN_CYCLE,
                "cycleKind": "existing-source-cycle",
                "dependencyPath": [*stack[cycle_start:], member_name],
            }

        if member_name in completed:
            return {
                "status": "proven-acyclic",
                "reason": "dependency-already-proven-closed",
                "cycleSafetyProof": PROVEN_ACYCLIC,
                "dependencyPath": path,
            }

        candidates = [
            entry for entry in entries
            if entry.get("scope") == scope
            and entry.get("name") == member_name
            and entry.get("kind") in {"property", "binding"}
            and entry.get("anchor_unique") is True
            and entry.get("opaque_context") is not True
        ]
        if len(candidates) != 1:
            return {
                "status": "unknown",
                "reason": "same-scope-dependency-not-unique",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
                "occurrences": len(candidates),
            }

        entry = candidates[0]
        value_kind = str(entry.get("value_kind") or "")
        value_text = _value_text(source, entry)
        if value_text is None:
            return {
                "status": "unknown",
                "reason": "dependency-value-range-unavailable",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
            }

        if value_kind in _LITERAL_VALUE_KINDS:
            completed.add(member_name)
            return {
                "status": "proven-acyclic",
                "reason": "closed-local-dependency-chain-ends-in-literal",
                "cycleSafetyProof": PROVEN_ACYCLIC,
                "dependencyPath": path,
                "terminalValueKind": value_kind,
            }

        if value_kind != "member_expression":
            return {
                "status": "unknown",
                "reason": "dependency-value-kind-outside-closed-subset",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
                "dependencyValueKind": value_kind,
            }

        dependency = parse_member(value_text)
        if dependency is None:
            return {
                "status": "unknown",
                "reason": "dependency-member-expression-not-simple",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
            }
        if dependency[0] != parent_id:
            return {
                "status": "unknown",
                "reason": "dependency-leaves-reviewed-parent-scope",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
                "externalBase": dependency[0],
            }

        result = walk(dependency[1], path)
        if result.get("status") == "proven-acyclic":
            completed.add(member_name)
        return result

    return walk(start_ref[1], [])


def analyze_connect_cycle(
    root: Path,
    target_id: str,
    connect_target_id: str,
    grammar: str = "",
    library: str = "",
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
    if preview.get("cycleStatus") != CYCLE_UNKNOWN:
        return _blocked(
            "connect-preview",
            "production-cycle-status-must-remain-unknown",
            target_id,
            connect_target_id,
        )
    candidate_sha = str(preview.get("candidateSha256") or "")
    if (
        len(candidate_sha) != 64
        or any(ch not in "0123456789abcdef" for ch in candidate_sha.lower())
    ):
        return _blocked(
            "connect-preview",
            "connect-preview-candidate-sha-invalid",
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
            "cycle-proof-source-sha-drift",
            target_id,
            connect_target_id,
            currentSha256=source_sha,
            previewSha256=preview.get("baseSha256", ""),
        )

    grammar_path = resolve_grammar(root, grammar)
    if grammar_path is None:
        return _blocked(
            "cycle-analysis",
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
            "cycle-analysis",
            "tree-sitter-library-missing",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return _blocked(
            "cycle-analysis",
            "cycle-source-analysis-failed",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    finally:
        if native_parser is not None:
            native_parser.close()

    if semantic["diagnostics"]:
        return _blocked(
            "cycle-analysis",
            "current-source-has-parser-diagnostics",
            target_id,
            connect_target_id,
        )

    local = prove_local_dependency_closure(
        source,
        semantic["entries"],
        str(preview.get("parentSemanticAnchor") or ""),
        descriptor["sourceExpression"],
        descriptor["bindingName"],
    )

    cross_file = None
    effective = local
    if local.get("status") == "unknown":
        cross_file = prove_cross_file_dependency_closure(
            root,
            grammar_path,
            library,
            source,
            semantic["entries"],
            str(preview.get("parentSemanticAnchor") or ""),
            descriptor["sourceExpression"],
            descriptor["bindingName"],
        )
        if cross_file.get("status") in {
            "proven-acyclic", "proven-cycle"
        }:
            effective = cross_file

    return {
        "status": "analysis",
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "sourcePath": descriptor["sourcePath"],
        "baseSha256": source_sha,
        "candidateSha256": candidate_sha,
        "parentSemanticAnchor": preview.get("parentSemanticAnchor", ""),
        "targetProperty": descriptor["bindingName"],
        "sourceExpression": descriptor["sourceExpression"],
        "cycleAnalysisStatus": effective.get("status", "unknown"),
        "cycleSafetyProof": effective.get(
            "cycleSafetyProof", PROOF_UNKNOWN),
        "cycleAnalysisReason": effective.get("reason", ""),
        "dependencyPath": effective.get("dependencyPath", []),
        "cycleKind": effective.get("cycleKind", ""),
        "dependencyValueKind": effective.get(
            "dependencyValueKind", ""),
        "localCycleSafetyProof": local.get(
            "cycleSafetyProof", PROOF_UNKNOWN),
        "localCycleAnalysisReason": local.get("reason", ""),
        "externalModuleUri": effective.get("externalModuleUri", ""),
        "externalSourcePath": effective.get("externalSourcePath", ""),
        "externalSourceSha256": effective.get(
            "externalSourceSha256", ""),
        "aliasTargetId": effective.get("aliasTargetId", ""),
        "terminalPropertySemanticAnchor": effective.get(
            "terminalPropertySemanticAnchor", ""),
        "terminalDeclaredType": effective.get(
            "terminalDeclaredType", ""),
        "terminalValueKind": effective.get("terminalValueKind", ""),
        "terminalValueText": effective.get("terminalValueText", ""),
        "fallbackLiteral": effective.get("fallbackLiteral", ""),
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
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
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "cycleStatus": CYCLE_UNKNOWN,
            "typeCompatibility": TYPE_UNKNOWN,
            "applyEnabled": False,
            "artifactsStaged": False,
            "productionIntegrated": False,
        }, 4)

    grammar = args.grammar or os.environ.get(
        "HADALIS_WORKFLOW_GRAMMAR", "")
    library = args.library or os.environ.get(
        "HADALIS_TREE_SITTER_LIBRARY", "")

    result = analyze_connect_cycle(
        root,
        args.target_id,
        args.connect_target_id,
        grammar,
        library,
    )
    return emit(result, 0 if result.get("status") == "analysis" else 7)


if __name__ == "__main__":
    raise SystemExit(main())
