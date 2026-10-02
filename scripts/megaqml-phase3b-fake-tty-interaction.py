#!/usr/bin/env python3
"""Owner-local FAKE TOKEN low-level TTY interaction diagnostic: no vendor.

Uses the os.open(O_NOCTTY) variant that separately passed the Linux
capability test, wrapping the resulting descriptor in a Python text
stream. Requests only two fixed, publicly printable *fake* tokens;
never prompts for account details or reports the typed text.
"""
import getpass
import os
import sys
import termios
import warnings

ACK = "TTY_TEST_ONLY"
NOECHO = "FAKE_PIN_ONLY"


def report(low=False, text=False, flushed=False, read="not_attempted",
           noecho="not_attempted"):
    assert read in {"not_attempted", "passed", "mismatch", "eof", "unavailable"}
    assert noecho in {"not_attempted", "passed", "mismatch", "unavailable"}
    print("MEGAQML_FAKE_TTY_INTERACTION_RESULT")
    print("LOW_LEVEL_TTY_OPEN=" + str(low).lower())
    print("TEXT_TTY_OPEN=" + str(text).lower())
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
        fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    except OSError:
        report()
        return
    try:
        tty = os.fdopen(fd, "r+", encoding="utf-8", buffering=1)
    except (OSError, ValueError, UnicodeError):
        os.close(fd)  # fdopen did not take ownership on failure.
        report(low=True)
        return
    try:
        with tty:
            try:
                tty.write("Fake confirmation test; type " + ACK + ": ")
                tty.flush()
            except (OSError, ValueError, UnicodeError):
                report(low=True, text=True)
                return
            try:
                answer = tty.readline(64)
            except (OSError, EOFError, ValueError, UnicodeError):
                report(low=True, text=True, flushed=True, read="unavailable")
                return
            if not answer:
                report(low=True, text=True, flushed=True, read="eof")
                return
            if answer.strip() != ACK:
                report(low=True, text=True, flushed=True, read="mismatch")
                return
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
                report(low=True, text=True, flushed=True, read="passed",
                       noecho="unavailable")
                return
            report(low=True, text=True, flushed=True, read="passed",
                   noecho="passed" if hidden == NOECHO else "mismatch")
    except (OSError, ValueError, UnicodeError):
        report(low=True, text=True)


def self_test():
    assert (os.O_RDWR | os.O_NOCTTY) & os.O_NOCTTY == os.O_NOCTTY
    assert ACK != NOECHO
    assert "@" not in ACK and "@" not in NOECHO
    print("PASS MegaQML low-level fake TTY pure self-test")


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
