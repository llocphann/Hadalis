#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/code-workflow"))

from native import Node
from semantics import semantic_value_node


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def node(kind, start, end, parent=None, *, named=True, field_name=None,
         error=False, missing=False, children=None):
    return Node(
        kind, start, end, (0, start), (0, end), parent, named,
        error, missing, field_name, list(children or []),
    )


literal_nodes = [
    node("expression_statement", 0, 6, children=[1, 2]),
    node("false", 0, 5, parent=0),
    node(";", 5, 6, parent=0, named=False),
]
if semantic_value_node(literal_nodes, 0) != 1:
    fail("single healthy expression child must unwrap from expression_statement")

comment_nodes = [
    node("expression_statement", 0, 16, children=[1, 2, 3]),
    node("false", 0, 5, parent=0),
    node("comment", 6, 15, parent=0),
    node(";", 15, 16, parent=0, named=False),
]
if semantic_value_node(comment_nodes, 0) != 1:
    fail("trailing named comments must not hide the semantic expression")

ambiguous_nodes = [
    node("expression_statement", 0, 3, children=[1, 2]),
    node("identifier", 0, 1, parent=0),
    node("identifier", 2, 3, parent=0),
]
if semantic_value_node(ambiguous_nodes, 0) != 0:
    fail("ambiguous wrapper must remain wrapped/fail closed")

error_nodes = [
    node("expression_statement", 0, 5, children=[1]),
    node("false", 0, 5, parent=0, error=True),
]
if semantic_value_node(error_nodes, 0) != 0:
    fail("errored child must not be promoted to semantic value")

plain_nodes = [node("member_expression", 0, 3)]
if semantic_value_node(plain_nodes, 0) != 0:
    fail("non-wrapper semantic values must remain unchanged")

print("ok - Code Workflow semantic value wrapper contract")
