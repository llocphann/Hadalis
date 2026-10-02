#!/usr/bin/env python3
"""Vendor-free, account-free installed package metadata triage.

Reads only system package metadata and executable filesystem identities.
Does not spawn MEGAcmd, any package manager, a shell or a sandbox. A
package version is NOT the installed/active vendor server version.
"""
from pathlib import Path
import json
import os
import re
import shutil
import sys

PKGS = ("megacmd", "megacmd-bin", "megacmd-git", "mega-cmd")
VERSION = re.compile(r"(\d{1,3}(?:\.\d{1,3}){1,3})(?:[-+~][a-zA-Z0-9.+:~-]{1,48})?")
NIX = re.compile(
    r"[0-9a-z]{32}-(?:megacmd|mega-cmd)-"
    r"(\d{1,3}(?:\.\d{1,3}){1,3})(?:[-+~][a-zA-Z0-9.+:~-]{1,48})?"
)
FILE_LIMIT = 256 * 1024
STATUS_LIMIT = 32 * 1024 * 1024


def fields(text):
    """Read plain pacman desc fields; never execute a package manager."""
    lines = text.splitlines()
    answer = {}
    for pos, line in enumerate(lines[:-1]):
        if line in ("%NAME%", "%VERSION%") and line not in answer:
            answer[line] = lines[pos + 1].strip()
    return answer


def package_version(raw):
    """Normalize only numeric version; never publish arbitrary metadata."""
    if not isinstance(raw, str) or len(raw) > 80:
        return None
    match = VERSION.fullmatch(raw)
    return match.group(1) if match else None


def safe_read(path):
    try:
        if path.is_symlink() or not path.is_file() or path.stat().st_size > FILE_LIMIT:
            return None
        return path.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeError):
        return None


def candidate_pair():
    items = []
    for name in ("mega-version", "mega-cmd-server"):
        found = shutil.which(name)
        if not found:
            return None
        original = Path(found)
        try:
            canonical = original.resolve(strict=True)
            # Never follow a user-controlled /home or /tmp executable or file.
            if (not canonical.is_file()
                    or not os.access(original, os.X_OK)
                    or not original.is_absolute()
                    or not any(canonical.is_relative_to(prefix)
                        for prefix in (Path("/usr"), Path("/opt"), Path("/nix/store")))
                    or original.is_relative_to(Path("/home"))
                    or original.is_relative_to(Path("/tmp"))):
                return None
        except (OSError, RuntimeError):
            return None
        items.append((original, canonical))
    if items[0][1].parent != items[1][1].parent:
        return None
    return items


def path_tags(pair):
    tags = []
    for original, resolved in pair:
        tags.append({
            original.as_posix().lstrip("/"),
            resolved.as_posix().lstrip("/"),
        })
    return tags


def pacman_metadata(pair, root=Path("/")):
    base = root / "var/lib/pacman/local"
    tags = path_tags(pair)
    try:
        matches = sorted(
            (entry for entry in base.iterdir() if
             entry.is_dir() and not entry.is_symlink()
             and any(entry.name.startswith(name + "-") for name in PKGS)),
            key=lambda entry: entry.name,
        )
    except OSError:
        return None
    for entry in matches[:32]:
        desc = safe_read(entry / "desc")
        files = safe_read(entry / "files")
        if desc is None or files is None:
            continue
        meta = fields(desc)
        if meta.get("%NAME%") not in PKGS:
            continue
        version = package_version(meta.get("%VERSION%"))
        entries = {line.lstrip("/") for line in files.splitlines()
                   if line and not line.startswith("%")}
        if version and all(bool(ids & entries) for ids in tags):
            return {"source": "pacman_local_db", "version": version}
    return None


def debian_status_versions(path):
    """Bound streaming status parser; no full dpkg status/log collection."""
    try:
        if path.is_symlink() or path.stat().st_size > STATUS_LIMIT:
            return {}
        with path.open("r", encoding="utf-8", errors="replace") as fp:
            values, record = {}, {}
            def finish():
                if (record.get("Package") in PKGS
                        and record.get("Status") == "install ok installed"):
                    vers = package_version(record.get("Version"))
                    if vers:
                        values[record["Package"]] = vers
                record.clear()
            for line in fp:
                if line == "\n":
                    finish()
                    continue
                if line.startswith(("Package: ", "Version: ", "Status: ")):
                    name, value = line.split(": ", 1)
                    record[name] = value.strip()[:96]
            finish()
            return values
    except (OSError, UnicodeError):
        return {}


def dpkg_metadata(pair, root=Path("/")):
    vers = debian_status_versions(root / "var/lib/dpkg/status")
    tags = path_tags(pair)
    for name, version in vers.items():
        paths = safe_read(root / "var/lib/dpkg/info" / (name + ".list"))
        if paths is None:
            continue
        owned = {line.lstrip("/") for line in paths.splitlines()}
        if all(bool(ids & owned) for ids in tags):
            return {"source": "dpkg_local_db", "version": version}
    return None


def nix_metadata(pair):
    roots = {p[1].parts[3] for p in pair
             if len(p[1].parts) > 3 and p[1].parts[1:3] == ("nix", "store")}
    if len(roots) != 1:
        return None
    name = next(iter(roots))
    match = NIX.fullmatch(name)
    return {"source": "nix_derivation_label", "version": match.group(1)} if match else None


def inspect(pair):
    if pair is None:
        return {"status": "UNVERIFIED", "source": None, "version": None,
                "reason": "matching_system_binaries_not_confirmed"}
    for method in (pacman_metadata, dpkg_metadata, nix_metadata):
        result = method(pair)
        if result:
            return {"status": "PACKAGE_VERSION_OBSERVED", "source": result["source"],
                    "version": result["version"], "reason": "package_not_running_server"}
    return {"status": "UNVERIFIED", "source": None, "version": None,
            "reason": "installed_package_metadata_not_confirmed"}


def summary(result):
    assert result["status"] in ("UNVERIFIED", "PACKAGE_VERSION_OBSERVED")
    if result["status"] == "UNVERIFIED":
        assert result["version"] is None and result["source"] is None
    else:
        assert result["source"] in (
            "pacman_local_db", "dpkg_local_db", "nix_derivation_label")
        assert re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){1,3}", result["version"])
    return {
        "phase": "megaqml_phase3b_static_package_metadata",
        "state": result["status"],
        "source": result["source"],
        "package_version": result["version"],
        "reason": result["reason"],
        "vendor_executed": False,
        "network_used": False,
        "account_used": False,
        "server_version_qualified": False,
        "live_capabilities_unlocked": False,
    }


def main():
    if sys.argv[1:] != ["--acknowledge-vendor-free-static-triage"]:
        print("STOP=STATIC_TRIAGE_ACK_REQUIRED")
        return 64
    print(json.dumps(summary(inspect(candidate_pair())), sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
