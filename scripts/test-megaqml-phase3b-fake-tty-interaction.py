#!/usr/bin/env python3
"""Fake-only tests for fixed-token terminal interaction; never call a vendor."""
import contextlib
import io
from pathlib import Path
import runpy
from unittest import mock

path = Path(__file__).with_name("megaqml-phase3b-fake-tty-interaction.py")
source = path.read_text(encoding="utf-8")
for forbidden in ("subprocess", "socket", "mega-exec", "mega-login",
                  "mega-cmd", "import requests", "http://", "https://"):
    assert forbidden not in source, forbidden

module = runpy.run_path(str(path), run_name="fake_tty_contract")
g = module["interact"].__globals__


class Tty:
    def __init__(self, answer, bad=None):
        self.answer, self.bad = answer, bad
        self.messages = []
    def __enter__(self):
        return self
    def __exit__(self, *_):
        return False
    def fileno(self):
        return 71
    def write(self, value):
        if self.bad == "write":
            raise OSError("PRIVATE_CANARY")
        self.messages.append(value)
    def flush(self):
        if self.bad == "flush":
            raise OSError("PRIVATE_CANARY")
    def readline(self, count):
        assert count <= 64
        if self.bad == "read":
            raise OSError("PRIVATE_CANARY")
        return self.answer[:count]


def simulate(answer="", bad=None, hidden=None, fail_open=False,
             terminal=True, termios=True):
    tty = Tty(answer, bad)
    out = io.StringIO()
    open_mock = (mock.patch("builtins.open", side_effect=OSError("PRIVATE_CANARY"))
                 if fail_open else mock.patch("builtins.open", return_value=tty))
    with open_mock:
        with mock.patch.object(g["os"], "isatty", return_value=terminal):
            with mock.patch.object(g["termios"], "tcgetattr",
                                   side_effect=None if termios else OSError("PRIVATE_CANARY"),
                                   return_value=[0]*7):
                with mock.patch.object(g["getpass"], "getpass",
                                       side_effect=hidden if isinstance(hidden, BaseException)
                                       else None,
                                       return_value=hidden) as gp:
                    with contextlib.redirect_stdout(out):
                        module["interact"]()
    msg = out.getvalue()
    assert "PRIVATE_CANARY" not in msg
    assert "VENDOR_EXECUTED=NO" in msg
    assert "EMAIL_REQUESTED=NO" in msg
    assert "PHASE3B=UNQUALIFIED" in msg
    if not fail_open and bad is None and answer == module["ACK"] + "\n" and terminal and termios:
        assert gp.call_args.kwargs["stream"] is tty
    return msg, tty

s,_ = simulate(fail_open=True)
assert "TEXT_TTY_OPEN=false" in s
s,_ = simulate(bad="write")
assert "TEXT_TTY_OPEN=true" in s and "TTY_PROMPT_FLUSH=false" in s
s,_ = simulate(bad="flush")
assert "TTY_PROMPT_FLUSH=false" in s
s,_ = simulate(bad="read")
assert "TTY_ACK_READ=unavailable" in s
s,_ = simulate(answer="")
assert "TTY_ACK_READ=eof" in s
s,_ = simulate(answer="PRIVATE_CANARY\n")
assert "TTY_ACK_READ=mismatch" in s and "PRIVATE_CANARY" not in s
s,_ = simulate(answer=module["ACK"]+"\n", terminal=False)
assert "TTY_ACK_READ=passed" in s and "TTY_NOECHO_READ=unavailable" in s
s,_ = simulate(answer=module["ACK"]+"\n", termios=False)
assert "TTY_NOECHO_READ=unavailable" in s
s,_ = simulate(answer=module["ACK"]+"\n", hidden=OSError("PRIVATE_CANARY"))
assert "TTY_NOECHO_READ=unavailable" in s
s,t = simulate(answer=module["ACK"]+"\n", hidden=module["NOECHO"])
assert "TTY_ACK_READ=passed" in s and "TTY_NOECHO_READ=passed" in s
assert module["NOECHO"] not in "".join(t.messages)
s,_ = simulate(answer=module["ACK"]+"\n", hidden="PRIVATE_CANARY")
assert "TTY_NOECHO_READ=mismatch" in s and "PRIVATE_CANARY" not in s
print("PASS MegaQML fake TTY interaction contract (no vendor)")
