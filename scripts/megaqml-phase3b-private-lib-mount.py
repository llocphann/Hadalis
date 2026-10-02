#!/usr/bin/env python3
"""Fail-closed gate for the narrowly approved disposable private-library bind.

Only reads pacman ownership records, /opt/megacmd/lib metadata and the
matched MEGAcmd binaries' filesystem identities. No vendor process, network,
real account, dynamic loader, host HOME or log access. Root-owned, non-writable
paths only; symlinks must stay within the package-owned private directory.
"""
import os
from pathlib import Path
import runpy
import stat
import tempfile

LAYOUT = runpy.run_path(
    str(Path(__file__).with_name("megaqml-phase3b-static-library-layout.py")),
    run_name="private_mount_import")


def _trusted_directory(path, expected_uid):
    try:
        m = path.lstat()
        return (stat.S_ISDIR(m.st_mode) and m.st_uid == expected_uid
                and m.st_mode & 0o022 == 0)
    except OSError:
        return False


def _declared_private_libs(pair, root):
    tags = LAYOUT["STATIC"]["path_tags"](pair)
    base = root / "var/lib/pacman/local"
    try:
        packages = sorted(entry for entry in base.iterdir()
                          if entry.is_dir() and not entry.is_symlink()
                          and any(entry.name.startswith(pkg + "-")
                                  for pkg in LAYOUT["STATIC"]["PKGS"]))
    except OSError:
        return None
    for entry in packages[:32]:
        desc = LAYOUT["STATIC"]["safe_read"](entry / "desc")
        files = LAYOUT["STATIC"]["safe_read"](entry / "files")
        if desc is None or files is None:
            continue
        info = LAYOUT["STATIC"]["fields"](desc)
        if (info.get("%NAME%") not in LAYOUT["STATIC"]["PKGS"] or
                not LAYOUT["STATIC"]["package_version"](info.get("%VERSION%"))):
            continue
        records = {line.lstrip("/") for line in files.splitlines()
                   if line and not line.startswith("%")}
        if not all(tag & records for tag in tags):
            continue
        declared = {Path(p).name for p in records
                    if LAYOUT["SO"].fullmatch(p)}
        if not 0 < len(declared) <= 128:
            return None
        return declared
    return None


def verify_private_lib_mount(pair, root=Path("/"), expected_uid=0):
    """Return only a Boolean; never leak any host path or library filename."""
    if LAYOUT["inspect_package_layout"](pair, root) != "package_opt_libraries_present":
        return False
    base = root / "opt/megacmd/lib"
    for directory in (root / "opt", root / "opt/megacmd", base):
        if not _trusted_directory(directory, expected_uid):
            return False
    declared = _declared_private_libs(pair, root)
    if not declared:
        return False
    try:
        # Reject unlisted files, nested folders, devices and writable files.
        if set(os.listdir(base)) != declared:
            return False
        for name in declared:
            current = name
            seen = set()
            for _ in range(9):
                if current in seen:
                    return False
                seen.add(current)
                entry = base / current
                mode = entry.lstat()
                if mode.st_uid != expected_uid:
                    return False
                if stat.S_ISLNK(mode.st_mode):
                    target = os.readlink(entry)
                    # Reject absolute, nested, parent-relative, unlisted links.
                    if target not in declared or target in (".", ".."):
                        return False
                    current = target
                    continue
                if (not stat.S_ISREG(mode.st_mode)
                        or mode.st_mode & 0o022 != 0):
                    return False
                break
            else:
                return False
        return True
    except (OSError, RuntimeError):
        return False


def self_test():
    # Synthetic package tree only; no host MEGA, package-manager process or
    # real HOME. Use the current UID for fake files; production requires UID 0.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        pacman = root / "var/lib/pacman/local/megacmd-2.6.0-1"
        pacman.mkdir(parents=True)
        lib = root / "opt/megacmd/lib"
        lib.mkdir(parents=True)
        pair = [(Path("/usr/bin/mega-version"), Path("/usr/bin/mega-version")),
                (Path("/usr/bin/mega-cmd-server"), Path("/usr/bin/mega-cmd-server"))]
        (pacman / "desc").write_text("%NAME%\nmegacmd\n%VERSION%\n2.6.0-1\n")
        (pacman / "files").write_text("%FILES%\nusr/bin/mega-version\n"
                                      "usr/bin/mega-cmd-server\n"
                                      "opt/megacmd/lib/libfake.so.1\n"
                                      "opt/megacmd/lib/libfake.so.1.0\n")
        (lib / "libfake.so.1.0").write_bytes(b"FAKE_LIB_ONLY")
        (lib / "libfake.so.1").symlink_to("libfake.so.1.0")
        uid = os.getuid()
        check = lambda: verify_private_lib_mount(pair, root, uid)
        assert check()
        (lib / "unexpected.so").write_bytes(b"UNLISTED")
        assert not check()
        (lib / "unexpected.so").unlink()
        (lib / "libfake.so.1").unlink()
        (lib / "libfake.so.1").symlink_to("/etc/passwd")
        assert not check()
        (lib / "libfake.so.1").unlink()
        (lib / "libfake.so.1").symlink_to("libfake.so.1")
        assert not check()
        (lib / "libfake.so.1").unlink()
        (lib / "libfake.so.1").symlink_to("libfake.so.1.0")
        lib.chmod(0o777)
        assert not check()
        lib.chmod(0o755)
        assert check()
        (pacman / "files").write_text("%FILES%\nusr/bin/mega-version\n"
                                      "opt/megacmd/lib/libfake.so.1\n"
                                      "opt/megacmd/lib/libfake.so.1.0\n")
        assert not check()
    print("PASS MegaQML private library ownership and symlink fake-only test")


if __name__ == "__main__":
    self_test()
