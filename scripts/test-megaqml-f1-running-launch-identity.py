#!/usr/bin/env python3
"""No-vendor fake /proc contract for owner-selected F1 launch corroboration."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile

script = Path(__file__).with_name("megaqml-f1-running-launch-identity.py")
spec = importlib.util.spec_from_file_location("megaqml_running", script)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    root = base / "deployed"
    root.mkdir()
    (root / "settings.qml").write_text("fake")
    (root / "waffleSettings.qml").write_text("fake")
    exe = base / "bin" / "quickshell"
    exe.parent.mkdir()
    exe.write_text("fake, never executed")
    exe.chmod(0o755)
    pid = 78123
    proc = base / "proc" / str(pid)
    proc.mkdir(parents=True)
    (proc / "exe").symlink_to(exe)
    uid = os.getuid()
    fields = [b"S"] + [b"0"] * 18 + [b"12345"] + [b"0"] * 22
    good_stat = str(pid).encode() + b" (quickshell) " + b" ".join(fields) + b"\n"
    good_uid = b"Uid:\t" + b"\t".join([str(uid).encode()] * 4) + b"\n"
    (proc / "stat").write_bytes(good_stat)
    (proc / "status").write_bytes(good_uid)

    def argv(*args):
        (proc / "cmdline").write_bytes(
            b"\x00".join(os.fsencode(item) for item in args) + b"\x00")

    def check(reason, family="material"):
        got = m.assess_running(root, family, pid, proc_root=base / "proc", uid=uid)
        assert got == reason, (reason, got)

    argv("qs", "-n", "-p", root / "settings.qml")
    check("standalone_launch_path_observed")
    check("launch_arguments_unqualified", "waffle")
    argv("qs", "-n", "-p", root / "waffleSettings.qml")
    check("standalone_launch_path_observed", "waffle")
    argv("qs", "-n", "-p", root / "settings.qml", "-p", root / "settings.qml")
    check("launch_arguments_unqualified")
    argv("qs", "-p", root / "settings.qml")
    check("launch_arguments_unqualified")
    argv("qs", "-n", "-p", base / "wrong.qml")
    check("process_unavailable")
    argv("qs", "-n", "-p", root / "settings.qml")
    (proc / "status").write_bytes(b"Uid:\t" + b"\t".join(
        [str(uid + 1).encode()] * 4) + b"\n")
    check("process_owner_unqualified")
    (proc / "status").write_bytes(good_uid)
    (proc / "exe").unlink()
    (proc / "exe").symlink_to(base / "missing-executable")
    check("process_executable_unqualified")
    (proc / "exe").unlink()
    (proc / "exe").symlink_to(exe)
    (proc / "stat").write_bytes(b"unrecognized stat")
    check("process_identity_unstable")
    (proc / "stat").write_bytes(good_stat)
    (proc / "cmdline").write_bytes(b"qs\x00-n\x00-p\x00not_terminated")
    check("launch_arguments_unqualified")
    argv("qs", "-n", "-p", root / "settings.qml")
    (root / "settings.qml").unlink()
    check("deployed_entry_unavailable")
    with contextlib.redirect_stdout(io.StringIO()) as output:
        m.emit("standalone_launch_path_observed")
    report = output.getvalue()
    assert "STANDALONE_LAUNCH_PATH_OBSERVED=YES" in report
    assert "RUNNING_QML_BYTES_PROVEN=NO" in report
    assert "INSTALLED_RUST_HELPER_PROVEN=NO" in report
    assert "PHYSICAL_DESKTOP_ACCEPTED=NO" in report
    assert str(base) not in report

print("PASS MegaQML F1 fake selected-PID launch contract")
