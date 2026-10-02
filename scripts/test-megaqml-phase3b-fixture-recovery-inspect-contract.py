#!/usr/bin/env python3
"""Pure fake-data recovery-inspection contract. No vendor or real account."""
import contextlib
import io
from pathlib import Path
import runpy
import tempfile

HERE = Path(__file__).resolve().parent
SRC = HERE / "megaqml-phase3b-fixture-recovery-inspect.py"
text = SRC.read_text(encoding="utf-8")
assert 'if sys.argv[1:] == ["--diagnose-only"]' in text
assert '"DIAGNOSE_DISPOSABLE_FIXTURE"' in text
assert 'assert argv[0] in {"whoami", "sync", "ls"}' in text
assert 'fcntl.LOCK_EX | fcntl.LOCK_NB' in text
assert 'os.O_RDONLY | os.O_NOFOLLOW' in text
assert 'RAW_PRIVATE_OUTPUT_PUBLISHED=NO' in text
assert 'PRIVATE_JOURNAL_CHANGED=NO' in text
assert 'PHASE3B=UNQUALIFIED' in text
assert '"mkdir"' not in text
assert '"--delete"' not in text
assert '"-r", "-f"' not in text

d = runpy.run_path(str(SRC), run_name="test_fixture_inspection_import")
with tempfile.TemporaryDirectory(prefix="megaqml-recovery-mock-") as td:
    home = Path(td)
    nonce = "9" * 32
    local = home / (d["F"]["LOCAL_PREFIX"] + nonce)
    remote = d["F"]["REMOTE_PREFIX"] + nonce
    journal = {"nonce": nonce, "local": str(local),
               "remote": remote, "stage": "sync_detached"}
    uid = d["os"].getuid()
    local.mkdir(mode=0o700)
    expected_root = remote[1:].encode("ascii") + b"\n"

    def cat(sync=b"\n", root=expected_root, rem=b""):
        return d["categorize"](sync, root, rem, journal, uid)

    assert cat() == ("blank", "only_fixture", "empty", "empty_owned",
                     "remote_cleanup_candidate")
    assert cat(rem=b"\n")[-1] == "remote_cleanup_candidate"
    assert cat(rem=None) == ("blank", "only_fixture", "unknown",
                             "empty_owned", "no_action")
    assert cat(root=b"\n", rem=None) == (
        "blank", "blank", "unknown", "empty_owned",
        "remote_absence_candidate")
    assert cat(root=b"\n", rem=b"")[-1] == "no_action"
    assert cat(root=b"UNTRUSTED_OTHER\n")[-1] == "no_action"
    assert cat(sync=None)[-1] == "no_action"
    assert cat(sync=b"ID|LOCALPATH\nAbcDef12|/PRIVATE_CANARY\n")[-1] == "no_action"
    assert cat(sync=b"ID|LOCALPATH\nAbcDef12|"+str(local).encode()+b"\n"
               )[:1] == ("one_owned",)
    local.joinpath("user_data").write_bytes(b"x")
    assert cat()[-2:] == ("nonempty_owned", "no_action")
    local.joinpath("user_data").unlink()
    local.rmdir()
    assert cat()[-2:] == ("absent", "remote_cleanup_candidate")
    local.mkdir(mode=0o700)

    calls = []
    count = [0]
    def match():
        count[0] += 1
        return True
    def runner(argv):
        argv = tuple(argv)
        calls.append(argv)
        if argv == d["F"]["TWO"]:
            return 0, b"\n", b"", None
        if argv == ("ls", "/"):
            return 0, expected_root, b"", None
        if argv == ("ls", remote):
            return 0, b"", b"", None
        raise AssertionError("REAL_VENDOR_CALL_FORBIDDEN")
    result = d["inspect"](runner, match, journal, uid)
    assert result == ("blank", "only_fixture", "empty", "empty_owned",
                      "remote_cleanup_candidate")
    assert calls == [d["F"]["TWO"], ("ls", "/"), ("ls", remote)]
    assert count[0] == 4
    assert d["F"]["JOURNAL"] not in [x.name for x in home.iterdir()]

    count = [0]
    def fail_middle():
        count[0] += 1
        return count[0] < 2
    calls = []
    assert d["inspect"](runner, fail_middle, journal, uid) is None
    assert calls == [d["F"]["TWO"]]

    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        d["result"]("inspection_complete", stage="sync_detached",
                    sync="blank", root="only_fixture", remote="empty",
                    local="empty_owned", plan="remote_cleanup_candidate",
                    server=True, identity=True)
    report = out.getvalue()
    assert "PRIVATE_JOURNAL_STAGE=sync_detached" in report
    assert "RECOVERY_PLAN=remote_cleanup_candidate" in report
    assert "VENDOR_ACTIONS=READ_ONLY" in report
    assert "PRIVATE_JOURNAL_CHANGED=NO" in report
    for secret in ("PRIVATE_CANARY", nonce, str(home), remote, "AbcDef12"):
        assert secret not in report

print("PASS MegaQML fixture recovery inspection fake-only contract")
