#!/usr/bin/env python3
"""Fake-only private canonical classifier tests; no owner log access."""
import ast
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
P=ROOT/"scripts/wull-canonical-private-diagnostics-v2.py"
src=P.read_text(encoding="utf-8")
ast.parse(src)
assert "owned(target,1024*1024,False)" in src
assert "legacy_permissive = bool(stat.S_IMODE(target.lstat().st_mode)&0o077)" in src
assert "LEGACY_LOG_PERMISSIONS=" in src
assert "owned(private,64*1024,True)" in src

for marker in (
    'ORIGINAL="JOB-WULL-CANONICAL-P1E0042-20261003-40"',
    'EXACT_SOURCE="303478eae6cebe601486ab84db17dd3a5b9c2750"',
    'and result.get("exit_code")==1',
    'and result.get("observed_at_unix")==actions[0]["observed_at_unix"]',
    'and result.get("timed_out") is False',
    'len(re.findall("(?m)^SHA: "+EXACT_SOURCE+r"$",stdout))==1',
    'PRIVATE_LOG_PATH_OR_FAILED_COMMAND=NOT_PUBLISHED',
    'PRIVATE_LOG_PERMISSION_UNQUALIFIED',
    'target.parent==Path(tempfile.gettempdir()).resolve()',
    'stat.S_ISREG(st.st_mode) and st.st_uid==os.getuid()',
):
    assert marker in src,marker
for bad in ("git push", "git fetch", "subprocess.run", "shell=True",
            "rm -rf", "grabToImage", "grim "):
    assert bad not in src,bad
mod=runpy.run_path(str(P),run_name="inert_canonical_classifier")
summary=mod["summary"]
sample=("Exact SHA: 303478eae6cebe601486ab84db17dd3a5b9c2750\n"
        "Result: FAIL\nFailed: 2\n"
        "Primary failure groups:\n"
        "  - other regression contracts\n"
        "  - QML / module resolution / Connected Perimeter\n"
        "Skipped checks:\n")
assert summary(sample)==("CANONICAL_FAILURE_GROUPS_CLASSIFIED",2,
                         ("OTHER_REGRESSION","QML_MODULE"))
assert summary(sample.replace("Failed: 2","Failed: 0"))[0]==(
    "VALIDATOR_EXIT_INCONSISTENT")
assert summary(sample.replace("other regression contracts",
                              "private host path / secret token"))[0]==(
    "CANONICAL_LOG_UNQUALIFIED")
assert summary("unrelated log")==("CANONICAL_LOG_NO_SUMMARY",0,())
print("WULL_CANONICAL_PRIVATE_LOG_CLASSIFIER_FAKE_ONLY_PASS")
