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
assert '"operator_confirmation_mismatch"' in source
assert '"disposable_email_format_invalid"' in source
assert '"tty_confirmation_unavailable"' in source
assert 'stream=tty' in source
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

    # No-vendor local TTY path: never publish confirmation input or email.
    class FakeTty:
        def __init__(self, answer):
            self.answer = answer
            self.messages = []
        def __enter__(self):
            return self
        def __exit__(self, *_):
            return False
        def write(self, message):
            self.messages.append(message)
        def flush(self):
            pass
        def readline(self, limit):
            assert limit <= 64
            return self.answer[:limit]

    bad_tty = FakeTty("not-the-confirmation\n")
    with mock.patch("builtins.open", return_value=bad_tty):
        with mock.patch.object(g["getpass"], "getpass",
                               side_effect=AssertionError("must not read email")):
            reason, private = g["tty_confirmation"]()
            assert reason == "operator_confirmation_mismatch" and private is None
            assert "not-the-confirmation" not in "".join(bad_tty.messages)

    malformed_tty = FakeTty("READ_DISPOSABLE_ONLY\n")
    with mock.patch("builtins.open", return_value=malformed_tty):
        with mock.patch.object(g["getpass"], "getpass",
                               return_value="INVALID FAKE EMAIL") as private_read:
            reason, private = g["tty_confirmation"]()
            assert reason == "disposable_email_format_invalid" and private is None
            assert private_read.call_args.kwargs["stream"] is malformed_tty
            assert "INVALID FAKE EMAIL" not in "".join(malformed_tty.messages)

    good_tty = FakeTty("READ_DISPOSABLE_ONLY\n")
    with mock.patch("builtins.open", return_value=good_tty):
        with mock.patch.object(g["getpass"], "getpass",
                               return_value="fixture@example.invalid"):
            reason, private = g["tty_confirmation"]()
            assert reason is None and private == b"fixture@example.invalid"
            assert "fixture@example.invalid" not in "".join(good_tty.messages)

    with mock.patch("builtins.open", side_effect=OSError("PRIVATE_CANARY")):
        assert g["tty_confirmation"]() == ("tty_confirmation_unavailable", None)
    assert "PRIVATE_CANARY" not in g["summary"]("tty_confirmation_unavailable")

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
        "tty_confirmation": lambda: (None, b"fixture@example.invalid"),
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
