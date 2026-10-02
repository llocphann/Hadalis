#!/usr/bin/env python3
"""No-vendor contract for the separately authorized disposable *read-only* probe."""
import builtins
import contextlib
import io
from pathlib import Path
import runpy
from types import SimpleNamespace
from unittest import mock

HERE = Path(__file__).resolve().parent
probe = runpy.run_path(str(HERE / "megaqml-phase3b-disposable-readonly-sync.py"),
                       run_name="disposable_probe_fake_test")
g = probe["main"].__globals__
source = (HERE / "megaqml-phase3b-disposable-readonly-sync.py").read_text()

assert 'EXPECTED_USER = "megaqml-disposable"' in source
assert '["--read-disposable-session-only"]' in source
assert '"--output-cols=ID,RUN_STATE,STATUS"' in source
assert '"--col-separator=|"' in source
assert "os.killpg" in source
assert "start_new_session=True" in source
assert "subprocess.DEVNULL" in source
assert "stdin=subprocess.DEVNULL" in source
assert "getpass.getpass" in source
assert "def existing_server(" in source
assert "private_dir(home" in source
assert "private_dir(runtime" in source
assert "package_executor_owned" in source
assert "verify_private_lib_mount" in source
assert '"login"' not in source
assert '"logout"' not in source
assert '"delete"' not in source

def run_main(argv, overrides=None):
    stream = io.StringIO()
    with mock.patch.object(g["sys"], "argv", ["read-probe", *argv]):
        with contextlib.redirect_stdout(stream):
            rc = probe["main"]()
    return rc, stream.getvalue()

with mock.patch.object(g["subprocess"], "Popen",
                       side_effect=AssertionError("real vendor forbidden")):
    code, output = run_main(["--unknown", "PRIVATE_FAKE_CANARY"])
    assert code == 20
    assert "PRIVATE_FAKE_CANARY" not in output
    assert "explicit_acknowledgment_required" in output

    code, output = run_main(["--self-test"])
    assert code == 0 and "selftest_pass" in output

    with mock.patch.object(g["os"], "geteuid", return_value=0):
        code, output = run_main(["--read-disposable-session-only"])
        assert code == 20
        assert "dedicated_os_user_required" in output

    # Deterministic end-to-end supervisor with *all* potentially real
    # commands and account values mocked. No host paths or MEGA processes.
    simulated_calls = []
    def fake_binary(name):
        if name not in {"mega-version", "mega-cmd-server", "mega-exec"}:
            raise AssertionError("unexpected executable")
        return Path("/usr/bin/" + name), Path("/usr/bin/" + name)
    def fake_open(path, *args, **kwargs):
        if str(path) == "/dev/tty":
            return io.BytesIO()
        return real_open(path, *args, **kwargs)
    def fake_read(argv, env):
        simulated_calls.append(tuple(argv))
        assert "MEGACMD_SOCKET_NAME" not in env
        assert "http_proxy" not in env and "https_proxy" not in env
        if argv[1] == "whoami":
            return 0, b"Account: fixture@example.invalid\n", b"", None
        assert argv[1:] == [
            "sync", "--output-cols=ID,RUN_STATE,STATUS", "--col-separator=|"
        ]
        return 0, b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\n", b"", None
    real_open = builtins.open
    overrides = {
        "private_dir": lambda *args, **kwargs: True,
        "trusted_program": lambda *args, **kwargs: True,
        "existing_server": lambda *args, **kwargs: [4242],
        "tty_confirmation": lambda: b"fixture@example.invalid",
        "bounded_read": fake_read,
    }
    with mock.patch.dict(g, overrides):
        with mock.patch.dict(g["BOUNDARY"], {"allowed_binary": fake_binary}):
            with mock.patch.dict(g["PRIVATE"],
                                 {"verify_private_lib_mount": lambda *args: True}):
                with mock.patch.dict(g["CAT"],
                                     {"package_executor_owned": lambda *args: True}):
                    with mock.patch.object(g["os"], "geteuid", return_value=11223):
                        with mock.patch.object(g["os"], "getuid", return_value=11223):
                            with mock.patch.object(
                                    g["pwd"], "getpwuid",
                                    return_value=SimpleNamespace(
                                        pw_name="megaqml-disposable",
                                        pw_uid=11223,
                                        pw_dir="/home/megaqml-disposable")):
                                with mock.patch.dict(
                                    g["os"].environ,
                                    {"XDG_RUNTIME_DIR": "/run/user/11223"},
                                    clear=True):
                                    with mock.patch("builtins.open", fake_open):
                                        code, output = run_main(
                                            ["--read-disposable-session-only"])
                                        assert code == 0, output
                                        assert "sync_shape_observed_unqualified" in output
                                        assert "NONEMPTY_SYNC_SCALARS=true" in output
                                        assert "fixture@example.invalid" not in output
                                        assert "AbcDef12_-x" not in output
                                        assert len(simulated_calls) == 2
                                        assert simulated_calls[0][1] == "whoami"
                                        assert simulated_calls[1][1] == "sync"

                                        simulated_calls.clear()
                                        def wrong_account(argv, env):
                                            simulated_calls.append(tuple(argv))
                                            return 0, b"Account: other@example.invalid\n", b"", None
                                        with mock.patch.dict(
                                                g, {"bounded_read": wrong_account}):
                                            code, output = run_main(
                                                ["--read-disposable-session-only"])
                                            assert code == 21
                                            assert "account_identity_mismatch" in output
                                            assert "other@example.invalid" not in output
                                            assert len(simulated_calls) == 1
                                            assert simulated_calls[0][1] == "whoami"

                                        simulated_calls.clear()
                                        def bad_sync(argv, env):
                                            simulated_calls.append(tuple(argv))
                                            if argv[1] == "whoami":
                                                return 0, b"fixture@example.invalid\n", b"", None
                                            return (0,
                                                    b"ID|RUN_STATE|STATUS\nPRIVATE_FAKE_CANARY|UNKNOWN|Synced\n",
                                                    b"", None)
                                        with mock.patch.dict(
                                                g, {"bounded_read": bad_sync}):
                                            code, output = run_main(
                                                ["--read-disposable-session-only"])
                                            assert code == 21
                                            assert "sync_header_or_row_invalid" in output
                                            assert "PRIVATE_FAKE_CANARY" not in output

print("PASS MegaQML disposable read-only probe fake-only contract")
