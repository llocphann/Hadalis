#!/usr/bin/env python3
"""Regression checks for docs/IPC.md metadata parsing and completeness."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATOR_PATH = REPO_ROOT / "scripts" / "lib" / "generate-ipc-registry.py"

spec = importlib.util.spec_from_file_location("inir_ipc_registry_generator", GENERATOR_PATH)
if spec is None or spec.loader is None:
    raise SystemExit(f"FAIL: unable to load {GENERATOR_PATH}")
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

fixture = r"""# IPC Reference

## Available Targets

### sample

Parser regression fixture.

| Function | Description |
|----------|-------------|
| `status` | Return `niri\|<path>\|<managedCount>` |
| `page(index)` | Open the requested page index |
| `clockDebugSetMode digital\|cookie adaptToWallpaper` | Select the debug clock mode |

## Standalone Commands

### colorpicker

Not an IPC target.
"""

with tempfile.TemporaryDirectory() as tmpdir:
    fixture_path = Path(tmpdir) / "IPC.md"
    fixture_path.write_text(fixture, encoding="utf-8")

    original_ipc_md = module.IPC_MD
    module.IPC_MD = fixture_path
    try:
        entries = module.parse_ipc_md()
    finally:
        module.IPC_MD = original_ipc_md

sample = entries.get("sample")
if sample is None:
    raise SystemExit("FAIL: parser did not discover sample IPC target")

expected = {
    "status": "Return `niri|<path>|<managedCount>`",
    "page": "Open the requested page index",
    "clockDebugSetMode": "Select the debug clock mode",
}
for function_name, description in expected.items():
    actual = sample.functions.get(function_name)
    if actual != description:
        raise SystemExit(
            f"FAIL: {function_name} description parsed as {actual!r}, expected {description!r}"
        )

if "colorpicker" in entries:
    raise SystemExit("FAIL: standalone command was misclassified as an IPC target")

qml_targets = module.scan_qml()
doc_entries = module.parse_ipc_md()
merged_targets = module.merge(qml_targets, doc_entries)
missing_descriptions = sorted(
    f"{target.name}:{function.name}"
    for target in merged_targets
    for function in target.functions
    if not function.description.strip()
)
if missing_descriptions:
    raise SystemExit(
        "FAIL: live IPC functions are missing docs/IPC.md descriptions: "
        + ", ".join(missing_descriptions)
    )

print(
    "ok - IPC registry parser preserves Markdown semantics and all live functions are documented"
)
