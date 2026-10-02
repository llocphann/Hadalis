#!/usr/bin/env python3
"""Pure inert negative/sanitization test; never reads private logs or starts Qt."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
PUBLISHER = ROOT / "scripts/wull-publish-retained-dynamic-receipt.py"
RUNNER = ROOT / "scripts/wull-manual-offscreen-dynamic-geometry.py"


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(raw)).encode()
                        + b"\0" + raw).hexdigest()


assert blob(PUBLISHER) == "9b6fb909125da110266fb303bdcced6b9fdea7ed"
assert blob(RUNNER) == "9cab00fca46212c819ac7308cfc0d6923d1139d3"
source = PUBLISHER.read_text(encoding="utf-8")
ast.parse(source)
publish = runpy.run_path(str(PUBLISHER), run_name="inert_retained_publisher")
model = runpy.run_path(str(RUNNER), run_name="inert_retained_parser")
assert publish["SOURCE"] == "4caccd2058f1b3089ec398a131241f800eaae890"
assert publish["POSTMORTEM_BLOB"] == (
    "73904dbda1de437a8586925d32fa774af6b04d5e")
assert publish["FIXTURE_BLOB"] == (
    "6e3b5402d32d263868c1ec688925adba0fd7250b")
assert publish["FROZEN_BLOB"] == (
    "dc2f36b525ef7e412869f155153dc4e48720f898")
assert publish["SCRATCH"].name == "wull-qt-motion.y2aZdO"
assert "post[\"owner_guard\"](SCRATCH)" not in source
assert 'old["owner_guard"](SCRATCH)' in source
for literal in (
    'not stat.S_IMODE(s.st_mode) & 0o077',
    'git("branch", "--show-current") == "dev"',
    'not git("status", "--porcelain=v1", "--untracked-files=all")',
    'git("remote", "get-url", "--push", "origin") in ORIGINS',
    'gate(head == remote_head(), "REMOTE_MOVED")',
    'git("diff", "--cached", "--name-only") == str(PATH)',
    '"HEAD:refs/heads/dev"',
    'print("GATE=" +',
):
    assert literal in source, literal
for forbidden in (
    'subprocess.Popen', '"rebase"', '"--force"', '"reset"',
    'print(raw)', 'print(report)', '"qtpaths6"', '"--acknowledge-private-offscreen-dynamic-motion"'
):
    assert forbidden not in source

reference = model["known_frozen"]()
rows = []
for edge in model["EDGES"]:
    for scale in model["SCALES"]:
        observed = reference[str(scale)]
        flags = {
            "bbox_outside_static":
                edge in observed["stretched_bbox_outside_source_static_edges"],
            "bbox_outside_host":
                edge in observed["stretched_bbox_outside_host_edges"],
            "tip_outside_static":
                edge in observed["stretched_tip_outside_source_static_edges"],
            "tip_outside_host":
                edge in observed["stretched_tip_outside_host_edges"],
        }
        frame = {
            name: (72 if name == "samples" else flags[name] if name in flags
                   else True)
            for name in model["PHASE_FLAGS"]
        }
        rows.append({
            "edge": edge,
            "requested_scale": 1 if scale == 1.0 else scale,
            "neutral_verified": True, "frozen": flags,
            "stretch": dict(frame), "release": dict(frame),
        })
stages = "\n".join("WULL_OFFSCREEN_DYNAMIC_STAGE=" + stage
                   for stage in model["EXPECTED_STAGES"])
payload = json.dumps(rows, separators=(",", ":"))
raw = stages + "\nWULL_OFFSCREEN_DYNAMIC_GEOMETRY " + payload
receipt = publish["derive"](raw + "\nSENSITIVE_LOCAL_TEXT", model, "f"*40)
assert receipt["status"] == "pass"
assert receipt["all_12_edge_scale_state_witnesses"] is True
assert receipt["kind"] == "wull_retrospective_requalified_private_qml_samples"
assert receipt["source_sha"] == publish["SOURCE"]
assert receipt["publication_parent_sha"] == "f"*40
assert receipt["new_qt_execution"] == "not_run"
assert receipt["retrospective_receipt_not_production_acceptance"] is True
assert receipt["wayland_pointer_hover"] == "not_run"
assert receipt["production_mask_changed"] is False
assert "SENSITIVE_LOCAL_TEXT" not in json.dumps(receipt)
assert "private" not in str(receipt["sampled_categories"]).lower()
assert receipt["sample_count_range_per_case_phase"] == [72, 72]

def reject(candidate, category=None):
    try:
        publish["derive"](candidate, model, "f"*40)
    except publish["Stop"] as exc:
        if category is not None:
            assert str(exc) == category, (str(exc), category)
    except (ValueError, TypeError, KeyError, json.JSONDecodeError):
        pass
    else:
        raise AssertionError("Unsafe retained Qt data was accepted")

reject(raw.replace("SAMPLING_DONE", "BOOT"),
       "STAGE_SEQUENCE_INVALID")
reject(raw + "\nWULL_OFFSCREEN_DYNAMIC_STAGE=BOOT",
       "STAGE_SEQUENCE_INVALID")
reject(raw + "\nWULL_OFFSCREEN_DYNAMIC_GEOMETRY []",
       "MARKER_COUNT_INVALID")
reject(raw + "\nWULL_OFFSCREEN_DYNAMIC_TIMEOUT",
       "INVALID_OLD_RUN")
reject(raw.replace(payload, "[{"), None)
missing = copy.deepcopy(rows)
missing.pop()
reject(stages + "\nWULL_OFFSCREEN_DYNAMIC_GEOMETRY "
       + json.dumps(missing), None)
no_motion = copy.deepcopy(rows)
no_motion[0]["release"]["mapped_frame_change_witness"] = False
reject(stages + "\nWULL_OFFSCREEN_DYNAMIC_GEOMETRY "
       + json.dumps(no_motion), "OLD_MODEL_NOT_PASS")

print("WULL_RETAINED_DYNAMIC_RECEIPT_INERT_PASS")
