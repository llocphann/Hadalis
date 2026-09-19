"""Development-only adapter to Tree-sitter's public C API (no Python packages).

The grammar is compiled by build-parser.sh. This is a corpus probe, not the
runtime helper or a promise of a supported installation/FFI boundary.
"""

from bisect import bisect_right
from contextlib import contextmanager
import ctypes as c
import ctypes.util
from dataclasses import dataclass, field


class Point(c.Structure):
    _fields_ = [("row", c.c_uint32), ("column", c.c_uint32)]


class CNode(c.Structure):
    _fields_ = [("context", c.c_uint32 * 4), ("id", c.c_void_p), ("tree", c.c_void_p)]


class InputEdit(c.Structure):
    _fields_ = [("start_byte", c.c_uint32), ("old_end_byte", c.c_uint32),
                ("new_end_byte", c.c_uint32), ("start_point", Point),
                ("old_end_point", Point), ("new_end_point", Point)]


@dataclass
class Node:
    kind: str
    start: int
    end: int
    start_point: tuple
    end_point: tuple
    parent: int | None
    named: bool
    error: bool
    missing: bool
    field_name: str | None
    children: list = field(default_factory=list)


class Parser:
    def __init__(self, grammar, library=None):
        self.lib = c.CDLL(library or ctypes.util.find_library("tree-sitter") or "libtree-sitter.so")
        self.grammar = c.CDLL(str(grammar))
        self.grammar.tree_sitter_qmljs.restype = c.c_void_p
        signatures = {
            "ts_parser_new": (c.c_void_p, []),
            "ts_parser_delete": (None, [c.c_void_p]),
            "ts_parser_set_language": (c.c_bool, [c.c_void_p, c.c_void_p]),
            "ts_parser_parse_string": (c.c_void_p, [c.c_void_p, c.c_void_p, c.c_char_p, c.c_uint32]),
            "ts_tree_delete": (None, [c.c_void_p]),
            "ts_tree_copy": (c.c_void_p, [c.c_void_p]),
            "ts_tree_edit": (None, [c.c_void_p, c.POINTER(InputEdit)]),
            "ts_tree_root_node": (CNode, [c.c_void_p]),
            "ts_node_type": (c.c_char_p, [CNode]),
            "ts_node_start_byte": (c.c_uint32, [CNode]),
            "ts_node_end_byte": (c.c_uint32, [CNode]),
            "ts_node_start_point": (Point, [CNode]),
            "ts_node_end_point": (Point, [CNode]),
            "ts_node_child_count": (c.c_uint32, [CNode]),
            "ts_node_child": (CNode, [CNode, c.c_uint32]),
            "ts_node_field_name_for_child": (c.c_char_p, [CNode, c.c_uint32]),
            "ts_node_is_named": (c.c_bool, [CNode]),
            "ts_node_is_error": (c.c_bool, [CNode]),
            "ts_node_is_missing": (c.c_bool, [CNode]),
        }
        for name, (restype, args) in signatures.items():
            fn = getattr(self.lib, name)
            fn.restype, fn.argtypes = restype, args
        self.handle = self.lib.ts_parser_new()
        if not self.lib.ts_parser_set_language(self.handle, self.grammar.tree_sitter_qmljs()):
            self.close()
            raise RuntimeError("Tree-sitter library/grammar ABI mismatch")

    def close(self):
        if self.handle:
            self.lib.ts_parser_delete(self.handle)
            self.handle = None

    @contextmanager
    def parse(self, source, old_tree=None, edit=None):
        if len(source) > 2**32 - 1:
            raise ValueError("Source exceeds Tree-sitter byte range")
        source.decode("utf-8")  # Reject invalid encoding instead of changing it.
        copied = self.lib.ts_tree_copy(old_tree) if old_tree else None
        tree = None
        try:
            if edit is not None:
                if copied is None:
                    raise ValueError("An incremental edit requires an old tree")
                self.lib.ts_tree_edit(copied, c.byref(edit))
            tree = self.lib.ts_parser_parse_string(self.handle, copied, source, len(source))
            if not tree:
                raise RuntimeError("Parser returned no tree")
            yield tree, self.nodes(tree)
        finally:
            if tree:
                self.lib.ts_tree_delete(tree)
            if copied:
                self.lib.ts_tree_delete(copied)

    def nodes(self, tree):
        result = []
        stack = [(self.lib.ts_tree_root_node(tree), None, None)]
        while stack:
            n, parent, field_name = stack.pop()
            start, end = self.lib.ts_node_start_point(n), self.lib.ts_node_end_point(n)
            index = len(result)
            result.append(Node(
                self.lib.ts_node_type(n).decode(), self.lib.ts_node_start_byte(n),
                self.lib.ts_node_end_byte(n), (start.row, start.column), (end.row, end.column),
                parent, self.lib.ts_node_is_named(n), self.lib.ts_node_is_error(n),
                self.lib.ts_node_is_missing(n), field_name))
            if parent is not None:
                result[parent].children.append(index)
            for i in reversed(range(self.lib.ts_node_child_count(n))):
                name = self.lib.ts_node_field_name_for_child(n, i)
                stack.append((self.lib.ts_node_child(n, i), index, name.decode() if name else None))
        return result


def point_at(source, offset):
    prefix = source[:offset]
    return Point(prefix.count(b"\n"), len(prefix.rsplit(b"\n", 1)[-1]))


def insertion(source, offset, text):
    return InputEdit(offset, offset, offset + len(text), point_at(source, offset),
                     point_at(source, offset), point_at(source[:offset] + text, offset + len(text)))


def verify_ranges(source, nodes):
    """Check every node and reconstruct from leaves AND the omitted trivia gaps.

    Tree-sitter is not a whitespace-preserving serializer. The retained source
    buffer plus exact CST byte slices is the lossless document representation.
    """
    line_starts = [0] + [i + 1 for i, byte in enumerate(source) if byte == 10]

    def point(offset):
        row = bisect_right(line_starts, offset) - 1
        return row, offset - line_starts[row]

    leaves = []
    for n in nodes:
        assert 0 <= n.start <= n.end <= len(source), ("range", n)
        assert point(n.start) == n.start_point and point(n.end) == n.end_point, ("point", n)
        if n.parent is not None:
            parent = nodes[n.parent]
            assert parent.start <= n.start <= n.end <= parent.end, ("parent", n)
        if not n.children and n.end > n.start:
            leaves.append(n)
    chunks, cursor, gaps = [], 0, 0
    for n in leaves:
        assert n.start >= cursor, ("overlapping leaf", n)
        if n.start > cursor:
            chunks.append(source[cursor:n.start])
            gaps += n.start - cursor
        chunks.append(source[n.start:n.end])
        cursor = n.end
    chunks.append(source[cursor:])
    gaps += len(source) - cursor
    rebuilt = b"".join(chunks)
    assert rebuilt == source, "No-op reconstruction changed bytes"
    return {"nodes": len(nodes), "leaf_slices": len(leaves), "trivia_gap_bytes": gaps,
            "comments": sum(n.kind == "comment" for n in nodes), "byte_identical": True}
