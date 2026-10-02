#!/usr/bin/env python3
"""Owner-local FAKE TOKEN TTY interaction diagnostic: zero vendor calls.

This does not read an email/password or inspect the MEGA account. It
only probes the Python prompt path with public fixed test tokens.
All raw typed input stays in memory and never enters any diagnostic.
"""
import getpass
import os
import sys
import termios
import warnings

ACK = "TTY_TEST_ONLY"
NOECHO = "FAKE_PIN_ONLY"


def report(opened=False, flushed=False, read="not_attempted",
           noecho="not_attempted"):
    assert read in {"not_attempted", "passed", "mismatch", "eof", "unavailable"}
    assert noecho in {"not_attempted", "passed", "mismatch", "unavailable"}
    print("MEGAQML_FAKE_TTY_INTERACTION_RESULT")
    print("TEXT_TTY_OPEN=" + str(opened).lower())
    print("TTY_PROMPT_FLUSH=" + str(flushed).lower())
    print("TTY_ACK_READ=" + read)
    print("TTY_NOECHO_READ=" + noecho)
    print("ONLY_FIXED_FAKE_TOKENS=YES")
    print("EMAIL_REQUESTED=NO")
    print("VENDOR_EXECUTED=NO")
    print("PHASE3B=UNQUALIFIED")


def interact():
    print("FAKE TTY test, no MEGA access. Type public test tokens ONLY.",
          flush=True)
    print("First token: " + ACK + " ; second token: " + NOECHO,
          flush=True)
    try:
        with open("/dev/tty", "r+", encoding="utf-8") as tty:
            try:
                tty.write("Fake confirmation test; type " + ACK + ": ")
                tty.flush()
            except (OSError, ValueError, UnicodeError):
                report(opened=True)
                return
            try:
                answer = tty.readline(64)
            except (OSError, EOFError, ValueError, UnicodeError):
                report(opened=True, flushed=True, read="unavailable")
                return
            if not answer:
                report(opened=True, flushed=True, read="eof")
                return
            if answer.strip() != ACK:
                report(opened=True, flushed=True, read="mismatch")
                return
            # Refuse any getpass fallback that might echo a real secret.
            # Only a PUBLIC, fixed fake token is requested by this script.
            try:
                if not os.isatty(tty.fileno()):
                    raise OSError("not-terminal")
                termios.tcgetattr(tty.fileno())
                with warnings.catch_warnings():
                    warnings.simplefilter("error", getpass.GetPassWarning)
                    hidden = getpass.getpass(
                        "Fake no-echo test; type " + NOECHO + ": ",
                        stream=tty,
                    )
            except (OSError, EOFError, ValueError, UnicodeError,
                    getpass.GetPassWarning):
                report(opened=True, flushed=True, read="passed",
                       noecho="unavailable")
                return
            report(opened=True, flushed=True, read="passed",
                   noecho="passed" if hidden == NOECHO else "mismatch")
    except (OSError, ValueError, UnicodeError):
        report()


def self_test():
    for read in ("not_attempted", "passed", "mismatch", "eof", "unavailable"):
        for noecho in ("not_attempted", "passed", "mismatch", "unavailable"):
            if read != "passed":
                assert noecho == "not_attempted" or noecho in {
                    "passed", "mismatch", "unavailable"
                }
    assert ACK != NOECHO
    assert not any("@" in token for token in (ACK, NOECHO))
    print("PASS MegaQML fake TTY interaction pure self-test")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif sys.argv[1:] == ["--fake-tokens-only"]:
        interact()
    else:
        print("STOP=EXPLICIT_FAKE_TOKEN_FLAG_REQUIRED")
        print("VENDOR_EXECUTED=NO")
        print("PHASE3B=UNQUALIFIED")
        sys.exit(20)
