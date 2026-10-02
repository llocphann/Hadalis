#!/usr/bin/env python3
"""Static + mocked terminal-only diagnostic tests. No vendor/account usage."""
import contextlib
import io
from pathlib import Path
import runpy
from unittest import mock

path = Path(__file__).with_name("megaqml-phase3b-tty-only-diagnostic.py")
source = path.read_text(encoding="utf-8")
for forbidden in ("subprocess", "socket", "runpy", "getpass", "input(",
                  "stdin.read", "readline", "mega-exec", "mega-login",
                  "mega-cmd"):
    assert forbidden not in source, forbidden
module = runpy.run_path(str(path), run_name="tty_diagnostic_fake_contract")
g = module["check"].__globals__
assert module["route"](True, True, False, False, False) == "CONTROLLING_TTY_CANDIDATE"
assert module["route"](False, False, True, True, True) == "STDIO_TTY_CANDIDATE"
assert module["route"](False, False, False, False, False) == "NO_SECURE_INTERACTIVE_TTY"


def simulate(open_fd, tty_set):
    out = io.StringIO()
    with mock.patch.object(g["os"], "open", return_value=open_fd) if open_fd is not None else mock.patch.object(g["os"], "open", side_effect=OSError("PRIVATE_FAKE_ERR")):
        with mock.patch.object(g["os"], "close") as close:
            with mock.patch.object(g["os"], "isatty",
                                   side_effect=lambda fd: fd in tty_set):
                with mock.patch.object(g["termios"], "tcgetattr",
                                       return_value=[0] * 7):
                    with contextlib.redirect_stdout(out):
                        module["check"]()
            if open_fd is not None:
                close.assert_called_once_with(open_fd)
            else:
                close.assert_not_called()
    result = out.getvalue()
    assert "PRIVATE_FAKE_ERR" not in result
    assert "EMAIL_REQUESTED=NO" in result
    assert "VENDOR_EXECUTED=NO" in result
    assert "PHASE3B=UNQUALIFIED" in result
    return result


direct = simulate(71, {71})
assert "SAFE_INPUT_CANDIDATE=CONTROLLING_TTY_CANDIDATE" in direct
stdin_fallback = simulate(None, {0, 2})
assert "SAFE_INPUT_CANDIDATE=STDIO_TTY_CANDIDATE" in stdin_fallback
denied = simulate(None, set())
assert "SAFE_INPUT_CANDIDATE=NO_SECURE_INTERACTIVE_TTY" in denied
print("PASS MegaQML TTY diagnostic fake-only contract")
