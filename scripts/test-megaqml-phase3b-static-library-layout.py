#!/usr/bin/env python3
"""Fake-only check: no vendor binary or package manager invocation."""
import ast
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
path = root / "scripts/megaqml-phase3b-static-library-layout.py"
source = path.read_text(encoding="utf-8")
nodes = ast.parse(source)
m = runpy.run_path(str(path), run_name="inert_library_layout_test")
m["self_test"]()
assert m["CATEGORIES"] == {
    "package_opt_libraries_present", "package_opt_libraries_partially_missing",
    "package_opt_libraries_missing", "package_no_opt_libraries_listed",
    "package_layout_unverified",
}
assert 'STATIC["candidate_pair"]()' in source
assert 'STATIC["safe_read"]' in source
assert "SO.fullmatch(p)" in source
assert "if not all(bool(tag & records) for tag in tags)" in source
# Reject any process spawning or network imports in this static inspector.
for node in ast.walk(nodes):
    if isinstance(node, ast.Import):
        assert all(alias.name not in {"subprocess", "socket"} for alias in node.names)
    if isinstance(node, ast.ImportFrom):
        assert node.module not in {"subprocess", "socket"}
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        assert node.func.attr not in {"system", "popen", "Popen", "run", "connect"}
assert "network_used" in source and "account_used" in source
print("PASS MegaQML Phase3b static library-layout fake-only contract")
