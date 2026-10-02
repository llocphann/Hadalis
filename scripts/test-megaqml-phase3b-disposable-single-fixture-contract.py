#!/usr/bin/env python3
"""No-vendor deterministic contract for ONE isolated MEGA fixture/cleanup.

Never launches installed MEGAcmd, logs private data, or creates cloud state.
Uses real temporary LOCAL folders and fake in-memory vendor replies only.
"""
from pathlib import Path
import contextlib
import io
import runpy
import tempfile
from unittest import mock

HERE = Path(__file__).resolve().parent
path = HERE / "megaqml-phase3b-disposable-single-fixture.py"
src = path.read_text(encoding="utf-8")
mod = runpy.run_path(str(path), run_name="fixture_fake_contract")
g = mod["cleanup"].__globals__
assert '"--execute-fixture"' in src and '"--cleanup-only"' in src
assert 'os.O_NOCTTY' in src and 'GetPassWarning' in src
assert 'fcntl.LOCK_EX | fcntl.LOCK_NB' in src
assert 'os.O_EXCL | os.O_NOFOLLOW' in src
assert '"sync", "--delete", local' in src
assert 'runner, "rm", "-r", "-f", remote' in src
assert 'folder.rmdir()' in src
assert 'RAW_PRIVATE_OUTPUT_PUBLISHED=NO' in src
assert 'PHASE3B=UNQUALIFIED' in src
assert 'BASE["existing_server"]' in src
assert 'BASE["CAT"]["package_executor_owned"]' in src
assert '"login"' not in src and '"logout"' not in src

def capture(code):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code()
    text = out.getvalue()
    for canary in ("PRIVATE_CANARY", "fixture@example.invalid",
                   "MEGAQML-Phase3b-Fixture-"):
        assert canary not in text
    assert "PHASE3B=UNQUALIFIED" in text
    assert "RAW_PRIVATE_OUTPUT_PUBLISHED=NO" in text
    return text

out = capture(lambda: mod["result"]("supervisor_error",
                                    PRIVATE_RECOVERY_PENDING=True))
assert "PRIVATE_RECOVERY_PENDING=true" in out
assert mod["parse_rows"](b"\n", (b"ID", b"LOCALPATH")) is None
assert mod["parse_rows"](b"ID|LOCALPATH\nAbcDef12|/x\nAbcDef12|/y\n",
                         (b"ID", b"LOCALPATH")) is None
assert mod["parse_rows"](b"ID|LOCALPATH\nAbcDef12|/x\n",
                         (b"ID", b"LOCALPATH"))[0]["ID"] == "AbcDef12"
assert mod["parse_rows"](b"ID|LOCALPATH\nAbcDef12|/x",
                         (b"ID", b"LOCALPATH")) is None

with tempfile.TemporaryDirectory(prefix="megaqml-inert-test-") as temp:
    home = Path(temp)
    nonce = "b" * 32
    local = home / (mod["LOCAL_PREFIX"] + nonce)
    remote = mod["REMOTE_PREFIX"] + nonce
    fcols = b"ID|LOCALPATH|REMOTEPATH|RUN_STATE|STATUS\n"
    bcols = b"ID|RUN_STATE|STATUS\n"
    full = fcols + ("AbcDef12|" + str(local) + "|" + remote
                    + "|Running|Synced\n").encode()
    compact = bcols + b"AbcDef12|Running|Synced\n"
    assert mod["evaluate"](full, compact, full, str(local), remote)
    assert not mod["evaluate"](full, bcols + b"WrongID11|Running|Synced\n",
                                full, str(local), remote)
    assert not mod["evaluate"](full, compact, full, str(local), remote+"x")
    assert mod["parse_rows"](fcols + b"PRIVATE_CANARY\n",
           (b"ID", b"LOCALPATH", b"REMOTEPATH", b"RUN_STATE", b"STATUS")) is None

    def make_fixture():
        folder = home / (mod["LOCAL_PREFIX"] + mod["JOURNAL_NONCE"])
        folder.mkdir(mode=0o700)
        doc = {"nonce": mod["JOURNAL_NONCE"],
               "local": str(folder),
               "remote": mod["REMOTE_PREFIX"] + mod["JOURNAL_NONCE"],
               "stage": "sync_created"}
        jp = home / mod["JOURNAL"]
        mod["save_journal"](jp, doc)
        return folder, doc, jp

    # A clean full run detaches exactly the fixture Sync, then deletes
    # the REMOTE folder only after independently proving it is empty.
    mod["JOURNAL_NONCE"] = "c" * 32
    folder, doc, jp = make_fixture()
    unrelated = home / "UNRELATED_KEEP"
    unrelated.mkdir()
    calls = []
    detached = False
    deleted = False
    def fake_vendor(argv):
        global detached, deleted
        argv = tuple(argv)
        calls.append(argv)
        if argv == mod["TWO"]:
            value = b"\n" if detached else (
                b"ID|LOCALPATH\nAbcDef12|" + str(folder).encode() + b"\n")
        elif argv == ("sync", "--delete", str(folder)):
            detached = True
            value = b""
        elif argv == ("ls", doc["remote"]):
            value = b"\n"
        elif argv == ("rm", "-r", "-f", doc["remote"]):
            assert detached
            deleted = True
            value = b""
        elif argv == ("ls", "/"):
            assert deleted
            value = b"\n"
        else:
            raise AssertionError("UNAUTHORIZED VENDOR ARGUMENT")
        return 0, value, b"", None
    def forbid_vendor(*args, **kwargs):
        raise AssertionError("real vendor forbidden")
    with mock.patch.dict(g["BASE"], {"bounded_read": forbid_vendor}):
        result = mod["cleanup"](fake_vendor, lambda: True, doc, jp, home)
    assert all(result.values()), result
    assert not folder.exists() and not jp.exists()
    assert unrelated.exists()
    assert calls.count(("sync", "--delete", str(folder))) == 1
    assert calls.count(("rm", "-r", "-f", doc["remote"])) == 1

    # Unknown object/path means do not DELETE another Sync or remote node.
    mod["JOURNAL_NONCE"] = "d" * 32
    folder, doc, jp = make_fixture()
    calls = []
    def wrong_identity(argv):
        argv = tuple(argv)
        calls.append(argv)
        if argv == mod["TWO"]:
            return 0, b"ID|LOCALPATH\nAbcDef12|/NOT_OWNED\n", b"", None
        raise AssertionError("MUST NOT MUTATE")
    res = mod["cleanup"](wrong_identity, lambda: True, doc, jp, home)
    assert not any(res.values())
    assert calls == [mod["TWO"]]
    assert jp.exists() and folder.exists()
    jp.unlink()
    folder.rmdir()

    # Nonempty remote listing blocks recursive rm and local cleanup.
    mod["JOURNAL_NONCE"] = "e" * 32
    folder, doc, jp = make_fixture()
    calls = []
    detached2 = False
    def remote_not_empty(argv):
        global detached2
        argv = tuple(argv)
        calls.append(argv)
        if argv == mod["TWO"]:
            value = (b"\n" if detached2 else
                     b"ID|LOCALPATH\nAbcDef12|" + str(folder).encode() + b"\n")
        elif argv == ("sync", "--delete", str(folder)):
            detached2 = True
            value = b""
        elif argv == ("ls", doc["remote"]):
            value = b"PRIVATE_CANARY\n"
        else:
            raise AssertionError("REMOVAL_FORBIDDEN")
        return 0, value, b"", None
    res = mod["cleanup"](remote_not_empty, lambda: True, doc, jp, home)
    assert res["SYNC_DETACHED"]
    assert not res["REMOTE_REMOVED"] and not res["LOCAL_REMOVED"]
    assert ("rm", "-r", "-f", doc["remote"]) not in calls
    assert jp.exists() and folder.exists()
    assert mod["load_journal"](jp, home, mod["os"].getuid())["stage"] == "sync_detached"
    jp.unlink()
    folder.rmdir()

    # Recovery after remote was already deleted must NOT delete it twice.
    mod["JOURNAL_NONCE"] = "f" * 32
    folder, doc, jp = make_fixture()
    doc["stage"] = "remote_removed"
    mod["save_journal"](jp, doc)
    def already_removed(argv):
        assert tuple(argv) == mod["TWO"]
        return 0, b"\n", b"", None
    res = mod["cleanup"](already_removed, lambda: True, doc, jp, home)
    assert all(res.values()) and not jp.exists() and not folder.exists()

    # Crash after rmdir and before unlink: journal-only recovery is safe.
    mod["JOURNAL_NONCE"] = "a" * 32
    folder, doc, jp = make_fixture()
    doc["stage"] = "remote_removed"
    mod["save_journal"](jp, doc)
    folder.rmdir()
    res = mod["cleanup"](already_removed, lambda: True, doc, jp, home)
    assert all(res.values()) and not jp.exists()

print("PASS MegaQML disposable single-fixture fake-only contract")
