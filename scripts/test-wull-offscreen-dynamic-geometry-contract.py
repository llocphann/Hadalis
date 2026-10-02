#!/usr/bin/env python3
"""INERT safety, parser and sanitization contract for sampled real QML frames.

Creates ONLY synthetic 12-case data. NEVER launches Qt, Rust, Niri or pointer
input. The separate explicit maintainer-local runner is the only live gate.
"""
import ast
import copy
import hashlib
import json
from pathlib import Path
import runpy
from unittest.mock import call, patch

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts/wull-manual-offscreen-dynamic-geometry.py"
FIXTURE = ROOT / "scripts/wull-fixtures/motion-envelope/shell.qml"
source = RUNNER.read_text(encoding="utf-8")
qml = FIXTURE.read_text(encoding="utf-8")
ast.parse(source)
model = runpy.run_path(str(RUNNER), run_name="wull_dynamic_inert_contract")
assert model["EDGES"] == ("top", "right", "bottom", "left")
assert model["SCALES"] == (0.65, 1.0, 1.5)
assert model["DYNAMIC_FIXTURE"] == "scripts/wull-fixtures/motion-envelope/shell.qml"
assert model["DYNAMIC_PINS"][model["DYNAMIC_FIXTURE"]] == (
    "6e3b5402d32d263868c1ec688925adba0fd7250b")
assert model["DYNAMIC_PINS"][model["FROZEN_RUNNER"]] == (
    "0dd833ed05d54e9d1045553a1da8be8f66b6511a")
assert model["DYNAMIC_PINS"][model["FROZEN_RECEIPT"]] == (
    "dc2f36b525ef7e412869f155153dc4e48720f898")


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(RUNNER) == "fe1c828e7c2f0e4fdc4bb7340242062085db3118"

# The former 512 KiB RLIMIT_FSIZE applied to *all* Quickshell private files,
# not just captured stdout. Actual owner-local controls observed SIGXFSZ at
# 512 KiB and one successful synthetic QML load at 8 MiB. Assert the process
# limit by mocking setrlimit; do not call it on the local test process.
assert model["MAX_LOG"] == 524288
assert model["QS_CHILD_FILE_LIMIT"] == 8 * 1024 * 1024
assert model["MAX_LOG"] < model["QS_CHILD_FILE_LIMIT"]
resource_module = model["resource"]
with patch.object(resource_module, "setrlimit") as set_limit:
    model["limit_private_process_files"]()
set_limit.assert_has_calls([
    call(resource_module.RLIMIT_CORE, (0, 0)),
    call(resource_module.RLIMIT_FSIZE,
         (model["QS_CHILD_FILE_LIMIT"], model["QS_CHILD_FILE_LIMIT"])),
])
assert set_limit.call_count == 2


for name, digest in model["DYNAMIC_PINS"].items():
    assert blob(ROOT / name) == digest, name
assert model["frozen"]["PINNED"][
    "modules/abyss/companion/WaterDropletBody.qml"
] == "fc5b1c227026786ab553685bc170daff74e82517"
assert model["frozen"]["PINNED"][
    "modules/abyss/companion/AbyssCompanion.qml"
] == "b5b01835a282458eba0d0268396ae2c350d919d2"

for literal in (
    "import qs.modules.abyss.companion",
    "delegate: AbyssCompanion {",
    "body.mapToItem(host, 0, 0)",
    "body.mapToItem(host, body.width * 0.5, 2)",
    "host.mapToItem(stage, host.width, host.height)",
    "body.motionEnabled = false",
    "body.motionEnabled = true",
    "body.stateStretch = 1",
    "body.stateStretch = 0",
    "root.phase = \"stretch\"",
    "root.phase = \"release\"",
    "neutral_verified: r.neutral_verified",
    "sample.active = sample.active && body.motionEnabled === true",
    "sample.transition_witness",
    "sample.target_reached_witness",
    "sample.mapped_frame_change_witness",
    "root.privateLastBounds[i] = {",
    "sample.bob_witness",
    "sample.sway_witness",
    "samples.stop()",
    "WULL_OFFSCREEN_DYNAMIC_GEOMETRY ",
    "WULL_OFFSCREEN_DYNAMIC_INVALID",
    "WULL_OFFSCREEN_DYNAMIC_TIMEOUT",
    "WULL_OFFSCREEN_DYNAMIC_STAGE=",
    'root.stage("BOOT")',
    'root.stage("FROZEN_VERIFIED")',
    'root.stage("NEUTRAL_VERIFIED")',
    'root.stage("STRETCH_SAMPLE")',
    'root.stage("RELEASE_START")',
    'root.stage("RELEASE_SAMPLE")',
    'root.stage("SAMPLING_DONE")',
):
    assert literal in qml, literal
assert qml.count("delegate: AbyssCompanion {") == 1
assert "WaterDropletBody {" not in qml
for forbidden in ("Process {", "wdotool", "ydotool", "uinput", "Niri {"):
    assert forbidden not in qml, forbidden

for literal in (
    "explicit_private_dynamic_opt_in_required",
    "private_dynamic_quickshell_version_differs_from_frozen",
    "frozen[\"guard\"](state)",
    "frozen[\"audit\"](commit)",
    "offscreen_dynamic_source_changed_after_review",
    "QT_QPA_PLATFORM\": \"offscreen\"",
    "\"WAYLAND_DISPLAY\", \"NIRI_SOCKET\"",
    "preexec_fn=limit_private_process_files",
    "if not 0 < log.stat().st_size <= MAX_LOG:",
    '"QML_IMPORT_PATH", "QML2_IMPORT_PATH"',
    "private_dynamic_child_cleanup_unverified",
    "PRIVATE_QS_EXIT_CLASS=",
    "PRIVATE_QML_LAST_STAGE=",
    "private_dynamic_qml_stage_sequence_inconclusive",
    '"mapped_frame_change_witness", "bob_witness"',
    "os.killpg(proc.pid, 0)",
    "os.killpg(proc.pid, signal.SIGTERM)",
    "private_dynamic_receipt_push_refused",
    "\"git\", \"push\", \"origin\", \"HEAD:refs/heads/dev\"",
    "\"rebase\", \"--onto\", remote, previous",
    "\"private_coordinates_animation_values_and_logs\": \"local_only\"",
    "\"global_spring_extrema_proven\": False",
    "\"native_backend_traces\": \"not_run\"",
    "\"wayland_pointer_hover\": \"not_run\"",
    "\"production_mask_changed\": False",
):
    assert literal in source, literal
for forbidden in ('"reset"', '"--force"', '"ydotool"',
                  '"wlrctl"', '"/dev/uinput"'):
    assert forbidden not in source, forbidden

reference = model["known_frozen"]()
assert set(reference) == {str(s) for s in model["SCALES"]}
for scale in model["SCALES"]:
    assert reference[str(scale)]["stretched_tip_outside_host_edges"] == ["top"]
    assert reference[str(scale)]["stretched_bbox_outside_host_edges"] == [
        "top", "bottom"]


def phase(record, finished=True):
    data = {
        "samples": 72,
        "active": True,
        "stretch_witness": True,
        "transition_witness": True,
        "target_reached_witness": True,
        "mapped_frame_change_witness": True,
        "bob_witness": True,
        "sway_witness": True,
        "bbox_outside_static": record["bbox_outside_static"],
        "bbox_outside_host": record["bbox_outside_host"],
        "tip_outside_static": record["tip_outside_static"],
        "tip_outside_host": record["tip_outside_host"],
        "bbox_beyond_frozen": finished,
    }
    return data


rows = []
for edge in model["EDGES"]:
    for scale in model["SCALES"]:
        original = reference[str(scale)]
        flags = {
            "bbox_outside_static":
                edge in original["stretched_bbox_outside_source_static_edges"],
            "bbox_outside_host":
                edge in original["stretched_bbox_outside_host_edges"],
            "tip_outside_static":
                edge in original["stretched_tip_outside_source_static_edges"],
            "tip_outside_host":
                edge in original["stretched_tip_outside_host_edges"],
        }
        rows.append({
            "edge": edge, "requested_scale": scale,
            "neutral_verified": True, "frozen": flags,
            "stretch": phase(flags), "release": phase(flags),
        })

good = model["model_summary"](rows, reference)
assert good["status"] == "pass"
assert good["all_dynamic_state_witnesses"] is True
assert good["observed_host_cases"] == 12
assert good["sample_count_range_per_case_phase"] == [72, 72]
assert good["sampled_categories"]["1.0"][
    "stretch_tip_outside_host_edges"] == ["top"]
assert good["sampled_categories"]["0.65"][
    "release_bbox_outside_host_edges"] == ["top", "bottom"]
assert good["global_spring_extrema_proven"] is False

publication = model["public_report"](
    good, "a"*40, "b"*40, "0.3.1", "not_recorded")
assert publication["status"] == "pass"
assert publication["all_12_edge_scale_state_witnesses"] is True
assert publication["global_spring_extrema_proven"] is False
assert publication["production_mask_changed"] is False
assert publication["canonical_validation"] == "not_run"
assert publication["private_coordinates_animation_values_and_logs"] == "local_only"
payload = json.dumps(publication)
for forbidden in ("private_frozen", "tip_x", "tip_y", "bbox_left",
                  "stage_host_width", "screen_name", "niri_socket",
                  "private_dynamic_log"):
    assert forbidden not in payload, forbidden

for alteration in (
    lambda data: data.pop(),
    lambda data: data[0].update(edge=data[1]["edge"],
                               requested_scale=data[1]["requested_scale"]),
    lambda data: data[0].update(requested_scale=2),
    lambda data: data[0]["stretch"].update(samples="72"),
    lambda data: data[0]["stretch"].update(active="true"),
    lambda data: data[0]["stretch"].update(transition_witness="true"),
    lambda data: data[0]["stretch"].update(samples=999),
    lambda data: data[0]["stretch"].update(private_coordinates=[1, 2]),
    lambda data: data[0].update(private_host_log="/tmp/private"),
    lambda data: data[0].update(neutral_verified="true"),
    lambda data: data[0]["frozen"].update(bbox_outside_host="false"),
):
    candidate = copy.deepcopy(rows)
    alteration(candidate)
    try:
        model["model_summary"](candidate, reference)
    except (TypeError, ValueError):
        pass
    else:
        raise AssertionError("Unsafe synthetic sampled-QML input accepted")

for mutation in (
    lambda data: data[0]["stretch"].update(samples=0),
    lambda data: data[0]["stretch"].update(active=False),
    lambda data: data[0]["stretch"].update(stretch_witness=False),
    lambda data: data[0]["stretch"].update(transition_witness=False),
    lambda data: data[0]["stretch"].update(target_reached_witness=False),
    lambda data: data[0]["release"].update(mapped_frame_change_witness=False),
    lambda data: data[0]["stretch"].update(bob_witness=False),
    lambda data: data[0]["stretch"].update(sway_witness=False),
    lambda data: data[0].update(neutral_verified=False),
    lambda data: data[0]["frozen"].update(bbox_outside_host=False),
):
    candidate = copy.deepcopy(rows)
    mutation(candidate)
    summary = model["model_summary"](candidate, reference)
    assert summary["status"] == "inconclusive"
    assert "top" in summary["unqualified_edges_by_scale"]["0.65"]
    safe = model["public_report"](
        summary, "c"*40, "d"*40, "0.3.1", "not_recorded")
    assert safe["status"] == "inconclusive"

for mutation in (
    lambda data: data.update(status="inconclusive", reason=None),
    lambda data: data.update(global_spring_extrema_proven=True),
    lambda data: data.update(native_backend_traces="pass"),
    lambda data: data.update(wayland_pointer_hover="pass"),
    lambda data: data.update(private_local_coordinate=[1, 2]),
    lambda data: data["sampled_categories"]["1.0"].update(
        stretch_tip_outside_host_edges=["bottom", "top"]),
):
    candidate = copy.deepcopy(good)
    mutation(candidate)
    # An unchanged PASS summary is valid: force a bad alteration for each case.
    if candidate == good:
        raise AssertionError("Inert negative mutation was a no-op")
    try:
        model["public_report"](candidate, "a"*40, "b"*40, "0.3.1", "not_recorded")
    except (ValueError, TypeError):
        pass
    else:
        raise AssertionError("Unsafe dynamic public receipt accepted")
for source_sha, qs in (("invalid", "0.3.1"),
                       ("a"*40, "host-private-name")):
    try:
        model["public_report"](good, source_sha, "b"*40, qs, "not_recorded")
    except ValueError:
        pass
    else:
        raise AssertionError("Unsafe source or private version accepted")

# A failed QML marker must expose only a fixed categorical diagnostic, never
# user-private paths, coordinates or the captured original log message.
classify = model["categorize_private_qml_failure"]
cases = (
    ("WULL_OFFSCREEN_DYNAMIC_INVALID", 0, 0, "FIXTURE_INVALID"),
    ("WULL_OFFSCREEN_DYNAMIC_TIMEOUT", 0, 0, "FIXTURE_TIMEOUT"),
    ('module "QtQuick.Shapes" is not installed', 1, 0, "QML_IMPORT_FAILURE"),
    ("TypeError: Cannot read private/path data", 1, 0, "QML_SCRIPT_ERROR"),
    ("Cannot assign to read-only property", 1, 0, "QML_COMPONENT_ERROR"),
    ("Could not load the Qt platform plugin", 1, 0, "QT_PLATFORM_FAILURE"),
    ("private /home/user/docs/secret", 1, 0, "PRIVATE_QS_NONZERO_EXIT"),
    ("private /home/user/docs/secret", 0, 0, "MISSING_GEOMETRY_MARKER"),
    ("private /home/user/docs/secret", 0, 2, "DUPLICATE_GEOMETRY_MARKERS"),
)
for raw, code, markers, expected_category in cases:
    got = classify(raw, code, markers)
    assert got == expected_category, (got, expected_category)
    assert got == expected_category and "/home/" not in got

# The 312-byte 3-line old log is not a runtime verdict: the future
# controlled rerun must distinguish private child exit from QML stage failure.
stages = model["EXPECTED_STAGES"]
summarize = model["private_stage_summary"]
assert stages == (
    "BOOT", "SETUP_START", "FROZEN_VERIFIED", "NEUTRAL_VERIFIED",
    "STRETCH_SAMPLE", "RELEASE_START", "RELEASE_SAMPLE", "SAMPLING_DONE")
clean_stage_log = "\n".join(
    "private safe stage WULL_OFFSCREEN_DYNAMIC_STAGE=" + name for name in stages)
assert summarize(clean_stage_log) == list(stages)
assert summarize("three private startup log lines only") == []
assert summarize(clean_stage_log + "\nWULL_OFFSCREEN_DYNAMIC_STAGE=BOOT") is None
assert summarize(clean_stage_log + "\nWULL_OFFSCREEN_DYNAMIC_STAGE=SECRET") is None
assert summarize(clean_stage_log.splitlines()[0]) == ["BOOT"]
assert summarize(clean_stage_log.replace("NEUTRAL_VERIFIED", "SECRET")) is None
for value, status in ((0, "ZERO"), (2, "NONZERO"), (-9, "SIGNAL"),
                      (None, "NOT_RECORDED"), ("0", "NOT_RECORDED")):
    assert model["private_exit_class"](value) == status
# Marker and stage classifications do not contain any private line content.
assert "private" not in "\n".join(stages).lower()

print("WULL_OFFSCREEN_DYNAMIC_INERT_CONTRACT_PASS")
