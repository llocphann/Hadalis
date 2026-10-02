#!/usr/bin/env python3
"""One-shot *no-input, no-vendor* diagnostic for a disposable Linux TTY.

Read ONLY kernel terminal capabilities on the already-selected Unix
user. Never read stdin, query a server, inspect credentials or print paths.
The observed flags are transport evidence, not MEGA qualification.
"""
import os
import sys
import termios


def route(controlling_open, controlling_termios, stdin_tty,
          stdin_termios, stderr_tty):
    if controlling_open and controlling_termios:
        return "CONTROLLING_TTY_CANDIDATE"
    if stdin_tty and stdin_termios and stderr_tty:
        return "STDIO_TTY_CANDIDATE"
    return "NO_SECURE_INTERACTIVE_TTY"


def is_terminal(fd):
    try:
        if not os.isatty(fd):
            return False, False
        termios.tcgetattr(fd)
        return True, True
    except (OSError, ValueError, termios.error):
        return True, False


def check():
    # Opening a controlling terminal is not equivalent to reading from it.
    # Do not print any kernel path, errno, login, session, or account data.
    open_ok = False
    termios_ok = False
    try:
        fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    except OSError:
        pass
    else:
        try:
            open_ok = True
            _, termios_ok = is_terminal(fd)
        finally:
            os.close(fd)
    stdin_tty, stdin_termios = is_terminal(0)
    stdout_tty, _ = is_terminal(1)
    stderr_tty, _ = is_terminal(2)
    selected = route(open_ok, termios_ok, stdin_tty,
                     stdin_termios, stderr_tty)
    print("MEGAQML_TTY_ONLY_DIAGNOSTIC")
    print("CONTROLLING_TTY_OPEN=" + str(open_ok).lower())
    print("CONTROLLING_TTY_TERMIOS=" + str(termios_ok).lower())
    print("STDIN_TTY=" + str(stdin_tty).lower())
    print("STDIN_TERMIOS=" + str(stdin_termios).lower())
    print("STDOUT_TTY=" + str(stdout_tty).lower())
    print("STDERR_TTY=" + str(stderr_tty).lower())
    print("SAFE_INPUT_CANDIDATE=" + selected)
    print("EMAIL_REQUESTED=NO")
    print("VENDOR_EXECUTED=NO")
    print("PHASE3B=UNQUALIFIED")


def self_test():
    assert route(True, True, False, False, False) == "CONTROLLING_TTY_CANDIDATE"
    assert route(False, False, True, True, True) == "STDIO_TTY_CANDIDATE"
    assert route(True, False, True, True, True) == "STDIO_TTY_CANDIDATE"
    assert route(False, False, True, True, False) == "NO_SECURE_INTERACTIVE_TTY"
    assert route(False, False, False, False, False) == "NO_SECURE_INTERACTIVE_TTY"
    print("PASS MegaQML TTY-only diagnostic pure self-test")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif sys.argv[1:] == ["--diagnose"]:
        check()
    else:
        print("MEGAQML_TTY_ONLY_DIAGNOSTIC")
        print("STOP=EXPLICIT_DIAGNOSTIC_FLAG_REQUIRED")
        print("VENDOR_EXECUTED=NO")
        print("PHASE3B=UNQUALIFIED")
        sys.exit(20)
