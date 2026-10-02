#!/usr/bin/env python3
"""Vendor-free read-only package layout check. Fixed local categories only."""
import json
import os
from pathlib import Path
import re
import runpy
import sys
import tempfile

STATIC = runpy.run_path(
    str(Path(__file__).with_name("megaqml-phase3b-static-package.py")),
    run_name="library_layout_import")
SO = re.compile(r"opt/megacmd/lib/[A-Za-z0-9_.+-]+[.]so(?:[.][0-9]+)*")
CATEGORIES = frozenset({
    "package_opt_libraries_present", "package_opt_libraries_partially_missing",
    "package_opt_libraries_missing", "package_no_opt_libraries_listed",
    "package_layout_unverified",
})


def inspect_package_layout(pair, root=Path("/")):
    # Read matched pacman records only. No vendor or package-manager process.
    if pair is None:
        return "package_layout_unverified"
    tags = STATIC["path_tags"](pair)
    base = root / "var/lib/pacman/local"
    try:
        packages = sorted(entry for entry in base.iterdir()
                          if entry.is_dir() and not entry.is_symlink()
                          and any(entry.name.startswith(name + "-")
                                  for name in STATIC["PKGS"]))
    except OSError:
        return "package_layout_unverified"
    for entry in packages[:32]:
        desc = STATIC["safe_read"](entry / "desc")
        files = STATIC["safe_read"](entry / "files")
        if desc is None or files is None:
            continue
        info = STATIC["fields"](desc)
        if (info.get("%NAME%") not in STATIC["PKGS"] or
                STATIC["package_version"](info.get("%VERSION%")) is None):
            continue
        records = {line.lstrip("/") for line in files.splitlines()
                   if line and not line.startswith("%")}
        if not all(bool(tag & records) for tag in tags):
            continue
        declared = sorted(p for p in records if SO.fullmatch(p))
        if not declared:
            return "package_no_opt_libraries_listed"
        if len(declared) > 128:
            return "package_layout_unverified"
        private_root = root / "opt/megacmd/lib"
        existing = 0
        for filename in declared:
            file = root / filename
            try:
                target = file.resolve(strict=True)
                if (target.is_relative_to(private_root.resolve())
                        and target.is_file()):
                    existing += 1
            except (OSError, RuntimeError):
                pass
        if existing == len(declared):
            return "package_opt_libraries_present"
        if existing:
            return "package_opt_libraries_partially_missing"
        return "package_opt_libraries_missing"
    return "package_layout_unverified"


def safe_summary(category):
    assert category in CATEGORIES
    return json.dumps({
        "phase": "megaqml_phase3b_static_private_library_layout",
        "state": "STATIC_LAYOUT_ONLY",
        "reason": category,
        "vendor_executed": False,
        "network_used": False,
        "account_used": False,
        "server_version_qualified": False,
        "live_capabilities_unlocked": False,
    }, sort_keys=True, separators=(",", ":"))


def self_test():
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        parent = root / "var/lib/pacman/local/megacmd-2.6.0-1"
        parent.mkdir(parents=True)
        pair = [(Path("/usr/bin/mega-version"), Path("/usr/bin/mega-version")),
                (Path("/usr/bin/mega-cmd-server"), Path("/usr/bin/mega-cmd-server"))]
        (parent / "desc").write_text("%NAME%\nmegacmd\n%VERSION%\n2.6.0-1\n")
        (parent / "files").write_text(
            "%FILES%\nusr/bin/mega-version\nusr/bin/mega-cmd-server\n")
        assert inspect_package_layout(pair, root) == "package_no_opt_libraries_listed"
        (parent / "files").write_text(
            "%FILES%\nusr/bin/mega-version\nusr/bin/mega-cmd-server\n"
            "opt/megacmd/lib/libfake.so.1\nopt/megacmd/lib/libother.so.2\n")
        assert inspect_package_layout(pair, root) == "package_opt_libraries_missing"
        target = root / "opt/megacmd/lib/libfake.so.1"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"synthetic-not-a-real-library")
        assert inspect_package_layout(pair, root) == "package_opt_libraries_partially_missing"
        (root / "opt/megacmd/lib/libother.so.2").write_bytes(b"fake")
        assert inspect_package_layout(pair, root) == "package_opt_libraries_present"
        (parent / "files").write_text("%FILES%\nusr/bin/mega-version\n")
        assert inspect_package_layout(pair, root) == "package_layout_unverified"
        assert inspect_package_layout(None, root) == "package_layout_unverified"
    for category in CATEGORIES:
        result = safe_summary(category)
        assert "libfake" not in result and temp not in result
        assert json.loads(result)["vendor_executed"] is False
    print("PASS MegaQML Phase3b vendor-free private library layout self-test")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return 0
    if sys.argv[1:] != ["--acknowledge-vendor-free-library-layout"]:
        print(safe_summary("package_layout_unverified"))
        return 20
    if os.geteuid() == 0:
        print(safe_summary("package_layout_unverified"))
        return 20
    category = inspect_package_layout(STATIC["candidate_pair"]())
    print(safe_summary(category))
    return 0 if category != "package_layout_unverified" else 21


if __name__ == "__main__":
    sys.exit(main())
