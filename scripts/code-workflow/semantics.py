"""Conservative read-only QML semantic extraction; NOT a type resolver/editor.

The production analyzer and Phase 0 corpus probes share this deliberately
partial projection. Unsupported constructs remain opaque and editable=False.
"""

from collections import Counter, defaultdict
from hashlib import sha256
import json


OBJECTS = {"ui_object_definition", "ui_object_definition_binding"}
LIFECYCLE = {"Loader", "LazyLoader", "Variants", "Instantiator", "Repeater"}
RUNTIME_OBJECT_BOUNDARIES = {
    "Timer": "timer",
    "Process": "process",
    "FileView": "file-view",
    "FileWatcher": "file-watcher",
    "WebSocket": "network",
    "TcpSocket": "network",
    "UnixSocket": "network",
}
DYNAMIC_CREATION_CALLS = {
    "Qt.createComponent": "dynamic-component",
    "Qt.createQmlObject": "dynamic-qml-object",
}


def semantic_value_node(nodes, index):
    """Return the expression node that owns a QML value's semantic bytes.

    tree-sitter-qmljs 0.3.1 can expose a QML member's value field as an
    expression_statement wrapper. Source transforms must classify/replace the
    expression itself, not the statement wrapper. Only unwrap when there is
    exactly one healthy named non-comment child; ambiguous wrappers stay opaque
    to later edit gates.
    """
    current = index
    while current is not None and nodes[current].kind == "expression_statement":
        wrapper = nodes[current]
        candidates = [
            child for child in wrapper.children
            if nodes[child].named
            and nodes[child].kind != "comment"
            and not nodes[child].error
            and not nodes[child].missing
            and wrapper.start <= nodes[child].start
            and nodes[child].end <= wrapper.end
        ]
        if len(candidates) != 1:
            break
        current = candidates[0]
    return current


def extract(path, source, nodes):
    def field(index, name):
        return next((c for c in nodes[index].children if nodes[c].field_name == name), None)

    def text(index):
        return source[nodes[index].start:nodes[index].end].decode("utf-8") if index is not None else ""

    def span(index):
        return [nodes[index].start, nodes[index].end] if index is not None else None

    def field_text(index, name):
        return text(field(index, name))

    scopes, opaque, ordinals = {}, {}, defaultdict(Counter)
    entries, diagnostics = [], []
    for i, n in enumerate(nodes):
        parent_scope = scopes.get(n.parent, ())
        scopes[i] = parent_scope
        opaque[i] = opaque.get(n.parent, False)
        kind, name, details = None, "", {}
        if n.kind in OBJECTS:
            type_name = field_text(i, "type_name")
            short_type = type_name.rsplit(".", 1)[-1]
            initializer = field(i, "initializer")
            members = nodes[initializer].children if initializer is not None else []
            ids = [field_text(c, "value").rstrip("; \r\n") for c in members
                   if nodes[c].kind == "ui_binding" and field_text(c, "name") == "id"]
            label = f"{type_name}#{ids[0]}" if len(ids) == 1 else type_name
            ordinals[parent_scope][label] += 1
            scopes[i] = parent_scope + (f"{label}[{ordinals[parent_scope][label]}]",)
            name, kind = type_name, "object"
            details = {"qml_id": ids[0] if len(ids) == 1 else None,
                       "identity_basis": "qml-id" if len(ids) == 1 else "structural-ordinal",
                       "object_type": type_name,
                       "initializer_range": span(initializer)}
            if short_type and short_type[0].islower():
                kind, opaque[i] = "opaque", True
                details["reason"] = "grouped-binding-or-object; needs type/scope resolution"
            elif n.kind == "ui_object_definition_binding":
                kind, opaque[i] = "opaque", True
                details["reason"] = "property-value-source/interceptor; needs type resolution"
                details["target_property"] = field_text(i, "name")
            elif short_type in LIFECYCLE:
                kind = "lifecycle"
                details["runtime_boundary"] = "lifecycle"
                details["runtime_capability"] = short_type
            elif short_type in RUNTIME_OBJECT_BOUNDARIES:
                details["runtime_boundary"] = RUNTIME_OBJECT_BOUNDARIES[short_type]
                details["runtime_capability"] = short_type
            elif short_type == "Connections":
                kind = "connections"
            elif short_type == "Component":
                kind = "component"
            elif short_type == "Binding":
                kind = "explicit-binding"
        elif n.kind == "ui_inline_component":
            name, kind = field_text(i, "name"), "inline-component"
            scopes[i] = parent_scope + ("component:" + name,)
            if any(s.startswith("component:") for s in parent_scope):
                kind, opaque[i] = "opaque", True
                details["reason"] = "unsupported-nested-inline-component"
                diagnostics.append({"kind": "qml-rule", "node_type": n.kind,
                                    "range": span(i), "point": list(n.start_point),
                                    "reason": details["reason"]})
        elif n.kind in {"ui_property", "ui_binding", "ui_signal", "function_declaration", "ui_required"}:
            name = field_text(i, "name")
            short_name = name.rsplit(".", 1)[-1]
            is_handler = len(short_name) > 2 and short_name.startswith("on") and short_name[2].isupper()
            kind = {"ui_property": "property", "ui_binding": "binding", "ui_signal": "signal",
                    "function_declaration": "function", "ui_required": "required"}[n.kind]
            # JavaScript nested functions are preserved as scripts, not QML actions.
            if n.kind == "function_declaration" and nodes[n.parent].kind != "ui_object_initializer":
                continue
            if n.kind in {"ui_binding", "function_declaration"} and is_handler:
                kind = "handler-candidate"  # Must resolve the signal/property in Phase 1.
            if n.kind == "ui_binding" and name == "id":
                kind = "id"
            value = semantic_value_node(nodes, field(i, "value"))
            details = {
                "value_range": span(value),
                "value_kind": nodes[value].kind if value is not None else None,
            }
            if n.kind == "ui_property":
                details["declared_type"] = field_text(i, "type")
                details["modifiers"] = [text(c) for c in n.children if nodes[c].kind == "ui_property_modifier"]
            if n.kind == "function_declaration":
                details["body_range"] = span(field(i, "body"))
        elif n.kind == "ui_pragma":
            kind, name = "pragma", field_text(i, "name")
            details["value"] = field_text(i, "value")
        elif n.kind == "call_expression":
            function_name = field_text(i, "function")
            if function_name == "Qt.binding":
                kind, name = "opaque", "Qt.binding"
                details["reason"] = "imperative-rebinding; preserve script, not a declarative wire"
            else:
                boundary = DYNAMIC_CREATION_CALLS.get(function_name)
                if boundary is None and function_name.endswith(".createObject"):
                    boundary = "dynamic-object"
                if boundary is None and (
                    function_name == "setSource"
                    or function_name.endswith(".setSource")
                ):
                    boundary = "dynamic-loader-source"
                if boundary is not None:
                    kind, name = "runtime-boundary", function_name
                    details["runtime_boundary"] = boundary
                    details["runtime_capability"] = function_name
        elif n.kind == "new_expression":
            raw_expression = text(i).lstrip()
            if raw_expression.startswith("new XMLHttpRequest("):
                kind, name = "runtime-boundary", "XMLHttpRequest"
                details["runtime_boundary"] = "network"
                details["runtime_capability"] = "XMLHttpRequest"
        elif n.kind.startswith("ui_") and n.kind in {"ui_annotation", "ui_annotated_object_member"}:
            kind, name, opaque[i] = "opaque", n.kind, True
            details["reason"] = "annotation semantics not modeled"
        if n.error or n.missing:
            diagnostics.append({"kind": "missing" if n.missing else "error", "node_type": n.kind,
                                "range": span(i), "point": list(n.start_point)})
        if kind is None:
            continue
        anchor_key = (path, scopes[i], kind, name)
        entries.append({"anchor": sha256(json.dumps(anchor_key).encode()).hexdigest()[:24],
                        "kind": kind, "name": name, "scope": list(scopes[i]),
                        "range": span(i), "parent_range": span(n.parent),
                        "opaque_context": opaque[i], "editable": False, **details})
    counts = Counter(e["anchor"] for e in entries)
    for e in entries:
        e["anchor_unique"] = counts[e["anchor"]] == 1
    return {"entries": entries, "diagnostics": diagnostics,
            "counts": dict(sorted(Counter(e["kind"] for e in entries).items())),
            "anchor_collisions": sorted(k for k, v in counts.items() if v > 1)}
