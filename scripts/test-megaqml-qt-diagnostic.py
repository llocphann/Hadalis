#!/usr/bin/env python3
"""Allowlisted QML syntax diagnostic; never reproduce arbitrary tool output."""
import re
import sys
from pathlib import Path

kind = sys.argv[1] if len(sys.argv) > 1 else ""
if kind not in {"qml_baseline", "qml_service", "qml_page"}:
    raise SystemExit(64)
text = Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")[:32768]
lower = text.lower()
if any(t in lower for t in ("unexpected token", "expected token", "syntax error")):
    category = "syntax"
elif "module " in lower and "is not installed" in lower:
    category = "missing_qt_module"
elif "unrecognized option" in lower or "unknown option" in lower:
    category = "unsupported_tool_option"
elif "could not open" in lower:
    category = "source_unavailable"
else:
    category = "unclassified"
# Only the numeric position is allowlisted, never the actual source path.
position = re.search(r":([1-9][0-9]{0,4}):([1-9][0-9]{0,3}):", text)
location = (position.group(1) + ":" + position.group(2)) if position else "unavailable"
print(f"{kind}_diagnostic={category};line_column={location}")
