#!/usr/bin/env python3
"""Offline contract for the user-triggered Hadalird package manager."""
import importlib.util
import io
import json
import pathlib
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("manager", ROOT / "scripts/hadalird-manager.py")
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)
revision1 = "1" * 40
revision2 = "2" * 40
manifest = {
    "id": "hadalird", "version": "0.2.0", "hostApi": 1,
    "session": manager.discovery.ENTRYPOINTS["session"],
    "settings": {
        "tlp": manager.discovery.ENTRYPOINTS["tlpSettings"],
        "thinkfan": manager.discovery.ENTRYPOINTS["thinkfanSettings"],
        "obsidian": manager.discovery.ENTRYPOINTS["obsidianSettings"],
        "obsidianTodo": manager.discovery.ENTRYPOINTS["obsidianTodoSettings"],
        "tlpRow": manager.discovery.ENTRYPOINTS["tlpRowSettings"],
        "tlpWaffle": manager.discovery.ENTRYPOINTS["tlpWaffleSettings"],
        "tlpWaffleRow": manager.discovery.ENTRYPOINTS["tlpWaffleRowSettings"],
    },
    "backends": {
        "managedTodo": manager.discovery.ENTRYPOINTS["managedTodo"],
        "dailyTodo": manager.discovery.ENTRYPOINTS["dailyTodo"],
    },
}


def make_tar(entries):
    with io.BytesIO() as stream:
        with tarfile.open(fileobj=stream, mode="w:gz") as handle:
            for name, data in entries:
                info = tarfile.TarInfo("source/" + name)
                info.size = len(data)
                handle.addfile(info, io.BytesIO(data))
        return stream.getvalue()


def bundle(version):
    files = [("manifest.json", json.dumps({**manifest, "version": version}).encode())]
    for entry in set(manager.discovery.ENTRYPOINTS.values()):
        files.append((entry, ("import QtQuick\nItem {} // " + version).encode()))
    files.append(("scripts/notes/worker.py", b"no execution"))
    files.append(("assets/helpers/inir-thinkfan", b"fake helper"))
    return make_tar(files)


with tempfile.TemporaryDirectory(prefix="hadalird-manager-test-") as location:
    base = pathlib.Path(location)
    home = base / "data/hadalird"
    shell = base / "shell"
    shell.mkdir()
    requested = []

    def fetch_sha():
        requested.append("lookup")
        return revision1 if requested.count("lookup") <= 2 else revision2

    def fetch_archive(url, limit):
        requested.append("archive")
        assert limit == manager.MAX_ARCHIVE
        assert url.startswith(manager.ARCHIVE)
        return bundle("0.2.0" if revision1 in url else "0.3.0")

    def run(action):
        return manager.operate(action, home, shell, fetch_sha, fetch_archive)

    state = run("status")
    assert not state["available"] and requested == []
    assert run("check")["updateAvailable"] and requested == ["lookup"]
    assert not (home / "current").exists()
    install = run("install")
    assert install["installedSha"] == revision1 and install["version"] == "0.2.0"
    assert manager.discovery.inspect(shell, base / "data")["available"]
    files = json.loads((home / "current/manifest.json").read_text())["files"]
    assert "scripts/notes/worker.py" in files
    assert (home / "current/assets/helpers/inir-thinkfan").stat().st_mode & 0o111
    assert "manifest.json" not in files
    assert run("status")["available"]
    assert requested.count("archive") == 1

    upgrade = run("install")
    assert upgrade["installedSha"] == revision2 and upgrade["canRollback"]
    assert (home / "releases" / revision1).is_dir()
    assert run("rollback")["installedSha"] == revision1
    assert run("status")["installedSha"] == revision1

    # Previous versions are kept; removal never clears data, enables workers or
    # performs privileged system installation.
    assert not run("remove")["available"]
    assert (home / "releases" / revision1).exists()
    assert (home / "releases" / revision2).exists()
    assert not (home / "current").exists()

    foreign = base / "foreign"
    foreign.mkdir()
    (home / "current").symlink_to(foreign)
    try:
        run("remove")
        raise AssertionError("Unowned link was removed")
    except ValueError:
        pass
    assert foreign.is_dir()
    (home / "current").unlink()

    for payload in [
        make_tar([("manifest.json", b"{}"), ("manifest.json", b"{}")]),
        make_tar([("manifest.json", b"{}")]),
        make_tar([("manifest.json", json.dumps({**manifest, "hostApi": 2}).encode())]),
    ]:
        try:
            manager.assemble(manager.unpack(payload), revision1, base / "invalid")
            raise AssertionError("Malformed package accepted")
        except ValueError:
            pass
    try:
        manager.unpack(make_tar([("../escape", b"bad")]))
        raise AssertionError("Path traversal accepted")
    except ValueError:
        pass

    (shell / "optional/hadalird").mkdir(parents=True)
    try:
        run("install")
        raise AssertionError("Bundled integration was overwritten")
    except ValueError:
        pass

print("HADALIRD_MANAGER_PASS explicit install/update/rollback/remove, immutable SHA, package validation, no shell/privilege")
