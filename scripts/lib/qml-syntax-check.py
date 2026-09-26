#!/usr/bin/env python3
"""Check syntax without treating a formatter round-trip failure as invalid QML."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

def check(parser, filename):
    formatted = subprocess.run([parser, filename], capture_output=True, text=True)
    if formatted.returncode == 0:
        return True

    # Qt 6.11 qmlformat cannot round-trip a valid property named `id`.
    # qmllint uses Qt's parser directly; inspect its structured diagnostics,
    # since a zero exit status alone does not guarantee a clean parse.
    parser_path = Path(shutil.which(parser) or parser).resolve()
    candidates = [parser_path.with_name("qmllint"), Path("/usr/lib/qt6/bin/qmllint"),
                  Path("/usr/lib/x86_64-linux-gnu/qt6/bin/qmllint")]
    for linter in dict.fromkeys(candidates):
        if not linter.is_file():
            continue
        version = subprocess.run([str(linter), "--version"], capture_output=True, text=True)
        match = re.search(r"qmllint (\d+)\.(\d+)\.", version.stdout)
        if not match or tuple(map(int, match.groups())) < (6, 8):
            continue
        result = subprocess.run([str(linter), "--json", "-", filename], capture_output=True, text=True)
        try:
            files = json.loads(result.stdout)["files"]
            accepted = (len(files) == 1 and files[0].get("success") is True
                        and Path(files[0]["filename"]).resolve() == Path(filename).resolve()
                        and not any(d.get("id") == "syntax" or d.get("type") == "error"
                                    for d in files[0].get("warnings", [])))
        except (ValueError, KeyError, TypeError):
            accepted = False
        if accepted:
            print(f"INFO: {filename}: Qt parser accepted; qmlformat round-trip failed", file=sys.stderr)
            return True
        break
    return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: qml-syntax-check.py QMLFORMAT FILE")
    raise SystemExit(0 if check(*sys.argv[1:]) else 1)
