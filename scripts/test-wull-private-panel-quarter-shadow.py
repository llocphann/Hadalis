#!/usr/bin/env python3
"""FAKE ONLY: source-pinned, reversible BOTTOM quarter shadow/safety contract.

No Qt, nested Niri, Git changes, screenshots or access to desktop input.
"""
import hashlib
import os
from pathlib import Path
import runpy
import stat
import tempfile

os.umask(0o077)
ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/wull-private-panel-quarter-shadow.py"
ORIGINAL = ROOT / "modules/abyss/companion/AbyssCompanion.qml"
PERIMETER = ROOT / "modules/abyss/AbyssPerimeter.qml"
PERIMETER_SHA = "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac"
PREFLIGHT = ROOT / "scripts/wull-private-nested-visual-prerequisites.py"
EXPECTED_PREFLIGHT_BLOB = "83367598877fa61804cdb84ef500fce744fbbb99"
EXPECTED_HELPER_BLOB = "dd62b2b834e86d41856730547bca8ea4d73aaca8"
EXPECTED_QML_BLOB = "b5b01835a282458eba0d0268396ae2c350d919d2"


def blob(raw):
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
    ).hexdigest()


def denied(category, func, *args):
    try:
        func(*args)
    except source["UnsafeShadow"] as exc:
        assert str(exc) == category, (str(exc), category)
    else:
        raise AssertionError("Unsafe private shadow accepted: " + category)


assert blob(HELPER.read_bytes()) == EXPECTED_HELPER_BLOB
assert blob(PREFLIGHT.read_bytes()) == EXPECTED_PREFLIGHT_BLOB
original = ORIGINAL.read_bytes()
perimeter = PERIMETER.read_bytes()
assert blob(original) == EXPECTED_QML_BLOB
assert blob(perimeter) == PERIMETER_SHA
source = runpy.run_path(str(HELPER), run_name="inert_private_shadow_source_only")
assert source["MODES"] == ("original_m0", "private_bottom_m025")
assert source["ORIGINAL_BLOB"] == EXPECTED_QML_BLOB
assert source["PERIMETER_BLOB"] == PERIMETER_SHA
marker, insert = source["MARKER"], source["INSERT"]
assert marker in original.decode("utf-8")
assert original.decode("utf-8").count(marker) == 1
assert insert.count('root.edge === "bottom" ? 0.25 : 0') == 1
updated = source["generate"](original)
assert blob(updated) != EXPECTED_QML_BLOB
assert updated.decode("utf-8").count(insert) == 1
assert updated.decode("utf-8").replace(insert, marker, 1).encode() == original
assert updated.count(b"WaterDropletBody {") == original.count(
    b"WaterDropletBody {")
denied("ORIGINAL_QML_SOURCE_MISMATCH",
       source["generate"], original + b"\n// unreviewed drift")

with tempfile.TemporaryDirectory(prefix="wull-paint-canary.") as tmp:
    work = Path(tmp)
    clone = work / "repo"
    original_path = clone / source["ORIGINAL"]
    original_path.parent.mkdir(parents=True, mode=0o700)
    original_path.write_bytes(original)
    (clone / "modules" / "common").mkdir(mode=0o700)
    (clone / "modules" / "common" / "Other.qml").write_text("Item {}\n")
    (clone / "modules" / "abyss" / "Other.qml").write_text("Item {}\n")
    (clone / source["PERIMETER"]).write_bytes(perimeter)
    (original_path.parent / "qmldir").write_text("module qs.modules.abyss.companion\n")

    def fixture(name):
        shell = work / "private" / name / "shell"
        shell.mkdir(mode=0o700, parents=True)
        return shell

    baseline_shell = fixture("baseline")
    candidate_shell = fixture("candidate")
    before = original_path.read_bytes()
    baseline = source["stage"](clone, baseline_shell, "original_m0")
    candidate = source["stage"](clone, candidate_shell, "private_bottom_m025")
    assert baseline.is_symlink() and baseline.resolve() == original_path
    assert candidate.is_file() and not candidate.is_symlink()
    assert stat.S_IMODE(candidate.stat().st_mode) == 0o600
    assert candidate.read_bytes() == updated
    assert original_path.read_bytes() == before
    baseline_perimeter = baseline_shell / "modules" / "abyss" / "AbyssPerimeter.qml"
    candidate_perimeter = candidate_shell / "modules" / "abyss" / "AbyssPerimeter.qml"
    for staged in (baseline_perimeter, candidate_perimeter):
        assert staged.is_file() and not staged.is_symlink()
        assert staged.read_bytes() == perimeter
        assert stat.S_IMODE(staged.stat().st_mode) == 0o600
    assert (clone / source["PERIMETER"]).read_bytes() == perimeter
    assert not (clone / "private").exists()
    assert (candidate_shell / "modules" / "abyss" /
            "Other.qml").is_symlink()
    assert (candidate_shell / "modules" / "common").is_symlink()
    assert (candidate_shell / "modules" / "abyss" /
            "companion" / "qmldir").is_symlink()
    assert baseline_shell != candidate_shell
    assert not (candidate_shell / "modules").is_symlink()

    denied("PRIVATE_SHADOW_ALREADY_EXISTS", source["stage"], clone,
           candidate_shell, "private_bottom_m025")
    denied("UNREVIEWED_PRIVATE_MARGIN_MODE", source["stage"], clone,
           fixture("invalid_mode"), "unsafe_variant")

    unsafe_shell = fixture("unsafe_perm")
    unsafe_shell.chmod(0o755)
    denied("PRIVATE_DIRECTORY_UNSAFE", source["stage"], clone,
           unsafe_shell, "private_bottom_m025")
    unsafe_shell.chmod(0o700)

    renamed = work / "Hadalis"
    renamed.mkdir(mode=0o700)
    denied("UNREVIEWED_DISPOSABLE_CLONE_LAYOUT",
           source["stage"], renamed, fixture("wrong_clone"),
           "private_bottom_m025")

    clone_symlink = work / "symlink-repo"
    clone_symlink.symlink_to(clone, target_is_directory=True)
    denied("UNREVIEWED_DISPOSABLE_CLONE_LAYOUT",
           source["stage"], clone_symlink, fixture("clone_link"),
           "private_bottom_m025")

    fake_source = clone / "modules" / "abyss" / "companion" / "AbyssCompanion.qml"
    fake_source.write_bytes(original + b"\n")
    denied("ORIGINAL_QML_SOURCE_MISMATCH", source["stage"], clone,
           fixture("drift"), "private_bottom_m025")
    fake_source.write_bytes(original)
    assert blob(fake_source.read_bytes()) == EXPECTED_QML_BLOB


# The capability probe is INERT: fake environment/socket/binary lookup only.
capability = runpy.run_path(str(PREFLIGHT),
                            run_name="fake_nested_visual_capability_only")
fake_tools = {"niri", "qs", "dbus-run-session", "cargo", "grim"}
fake_sockets = {"/tmp/fake-wull-runtime/wayland-51",
                "/tmp/fake-wull-runtime/niri-51.sock"}
fake_env = {"XDG_RUNTIME_DIR": "/tmp/fake-wull-runtime",
            "WAYLAND_DISPLAY": "wayland-51",
            "NIRI_SOCKET": "/tmp/fake-wull-runtime/niri-51.sock"}


def lookup(tool):
    return "/fake/binary/" + tool if tool in fake_tools else None


def socket_exists(path):
    return path in fake_sockets


ready = capability["prerequisites"](lookup, fake_env, socket_exists)
assert ready["capture_phase_ready"] is True
assert set(ready) == set(capability["REQUIRED_BINARIES"]) | {
    "host_wayland_socket", "host_niri_ipc_socket", "capture_phase_ready"}
fake_tools.remove("grim")
assert capability["prerequisites"](lookup, fake_env,
                                   socket_exists)["capture_phase_ready"] is False
fake_tools.add("grim")
invalid_env = dict(fake_env, WAYLAND_DISPLAY="../wayland-51")
assert capability["prerequisites"](lookup, invalid_env,
                                   socket_exists)["host_wayland_socket"] is False
missing_host = dict(fake_env, NIRI_SOCKET="")
assert capability["prerequisites"](lookup, missing_host,
                                   socket_exists)["capture_phase_ready"] is False

print("WULL_PRIVATE_NESTED_VISUAL_SHADOW_INERT_PASS")
