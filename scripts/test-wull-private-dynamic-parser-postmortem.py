#!/usr/bin/env python3
"""Pure-inert negative and privacy contract for existing private dynamic logs."""
import ast
from contextlib import redirect_stdout
import hashlib
from io import StringIO
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-private-dynamic-parser-postmortem.py"
raw = SCRIPT.read_bytes()
sha = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
assert sha == "73904dbda1de437a8586925d32fa774af6b04d5e"
source = raw.decode("utf-8")
ast.parse(source)
m = runpy.run_path(str(SCRIPT), run_name="wull_parser_postmortem_inert")
assert m["SOURCE"] == "4caccd2058f1b3089ec398a131241f800eaae890"
assert m["RUNNER_BLOB"] == "fe1c828e7c2f0e4fdc4bb7340242062085db3118"
assert m["FIXTURE_BLOB"] == "6e3b5402d32d263868c1ec688925adba0fd7250b"
assert m["LOG_BYTES_CAP"] == 524288
assert m["value_error_code"](ValueError("invalid_dynamic_host_count")) == (
    "invalid_dynamic_host_count")
assert m["value_error_code"](ValueError(
    "private /home/secret x=879.2")) == "OTHER_VALUE_ERROR"
assert m["payload_shape"]({"private": "secret"}) == (
    "NOT_LIST", "NOT_APPLICABLE", "NOT_APPLICABLE")
assert m["payload_shape"]([]) == (
    "WRONG_HOST_COUNT", "NOT_APPLICABLE", "NOT_APPLICABLE")
expected = ["BOOT", "SETUP_START", "FROZEN_VERIFIED", "NEUTRAL_VERIFIED",
            "STRETCH_SAMPLE", "RELEASE_START", "RELEASE_SAMPLE",
            "SAMPLING_DONE"]
flags = {name: False for name in m["FLAGS"] if name != "samples"}
flags["samples"] = 70
rows = [
    {"edge": edge, "requested_scale": scale, "neutral_verified": True,
     "frozen": {}, "stretch": dict(flags), "release": dict(flags)}
    for edge in ("top", "right", "bottom", "left")
    for scale in (.65, 1.0, 1.5)
]
assert m["payload_shape"](rows) == (
    "TWELVE_HOSTS", "HOST_FIELDS_MATCH", "PHASE_FIELDS_MATCH")
rows[0]["stretch"].pop("sway_witness")
assert m["payload_shape"](rows) == (
    "TWELVE_HOSTS", "HOST_FIELDS_MATCH", "PHASE_FIELDS_MISMATCH")
rows[0]["stretch"]["sway_witness"] = False
marker = "WULL_OFFSCREEN_DYNAMIC_GEOMETRY "
def raise_exact(*args):
    raise ValueError("unreviewed_dynamic_phase_fields")
def raise_private(*args):
    raise ValueError("x=9999 /home/owner/personal/private")
base = {
    "MARKER": marker, "EXPECTED_STAGES": tuple(expected),
    "private_stage_summary": lambda _: list(expected),
    "known_frozen": lambda: {},
    "model_summary": lambda *args: {"status": "inconclusive"},
}
def diagnostic(text, runner=base):
    stream = StringIO()
    with redirect_stdout(stream):
        m["diagnose"](text, runner)
    result = stream.getvalue()
    assert "/home/" not in result and "9999" not in result
    return result
payload = json.dumps(rows, separators=(",", ":"))
ok = diagnostic(marker + payload)
assert "PARSER_STAGE=MODEL_VALIDATED" in ok
assert "MODEL_STATUS=inconclusive" in ok
assert "JSON_HOST_SHAPE=TWELVE_HOSTS" in ok
bad = diagnostic(marker + "[{")
assert "PARSER_STAGE=JSON_DECODE_ERROR" in bad
assert "PAYLOAD_ENDS_ARRAY=NO" in bad
unknown = diagnostic(marker + payload, {**base, "model_summary": raise_private})
assert "MODEL_CATEGORY=OTHER_VALUE_ERROR" in unknown
known = diagnostic(marker + payload, {**base, "model_summary": raise_exact})
assert "MODEL_CATEGORY=unreviewed_dynamic_phase_fields" in known
bad_frozen = diagnostic(marker + payload, {**base, "known_frozen": raise_exact})
assert "PARSER_STAGE=FROZEN_REFERENCE_ERROR" in bad_frozen
assert "FROZEN_REFERENCE_CATEGORY=unreviewed_dynamic_phase_fields" in bad_frozen
assert "PARSER_STAGE=MARKER_COUNT" in diagnostic("private no marker")
assert 'os.getuid()' in source
assert 'stat.S_IMODE(st.st_mode) & 0o077' in source
assert 'git(repo, "rev-parse", "HEAD") != SOURCE' in source
assert 'git(repo, "rev-parse", "HEAD:" + RUNNER) != RUNNER_BLOB' in source
assert 'git(repo, "remote", "get-url", "origin") not in SAFE_ORIGINS' in source
assert "subprocess.Popen" not in source
assert "os.killpg" not in source
assert 'print(raw)' not in source and 'print(candidate)' not in source
print("WULL_PRIVATE_DYNAMIC_PARSER_POSTMORTEM_INERT_PASS")
