#!/usr/bin/env python3
"""INERT private-only QML shadow for original Wull BOTTOM quarter visual A/B.

No Qt, Wayland, screenshot, native input, Git, desktop or production writes.
Only creates an owner-private staged modules tree OUTSIDE the checkout.
"""
import hashlib
import os
from pathlib import Path
import stat

ORIGINAL = "modules/abyss/companion/AbyssCompanion.qml"
ORIGINAL_BLOB = "b5b01835a282458eba0d0268396ae2c350d919d2"
PERIMETER = "modules/abyss/AbyssPerimeter.qml"
PERIMETER_BLOB = "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac"
MARKER = (
    "        anchors.horizontalCenter: parent.horizontalCenter\n"
    "        anchors.bottom: parent.bottom\n"
    "        scale: 1 + root.ripple * 0.16"
)
INSERT = (
    "        anchors.horizontalCenter: parent.horizontalCenter\n"
    "        anchors.bottom: parent.bottom\n"
    "        anchors.bottomMargin: root.edge === \"bottom\" ? 0.25 : 0\n"
    "        scale: 1 + root.ripple * 0.16"
)
MODES = ("original_m0", "private_bottom_m025")
LINK_NAMES = (
    "services", "GlobalStates.qml", "qmldir", "assets", "scripts",
    "defaults", "translations"
)


class UnsafeShadow(ValueError):
    """Categorical failure: never include a path or private data."""


def require(ok, category):
    if not ok:
        raise UnsafeShadow(category)


def blob(raw):
    require(type(raw) is bytes, "SOURCE_BYTES_REQUIRED")
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
    ).hexdigest()


def generate(original):
    require(type(original) is bytes and blob(original) == ORIGINAL_BLOB,
            "ORIGINAL_QML_SOURCE_MISMATCH")
    text = original.decode("utf-8")
    require(text.count(MARKER) == 1 and text.count(INSERT) == 0,
            "ORIGINAL_QML_ANCHOR_MISMATCH")
    # The only reviewed anchor is the separate original cradle Rectangle,
    # never the centered/rotated procedural body or production input region.
    start = text.index(MARKER)
    require(text.rfind("    Rectangle {", 0, start) >
            text.rfind("    WaterDropletBody {", 0, start),
            "ORIGINAL_QML_TOPOLOGY_MISMATCH")
    updated = text.replace(MARKER, INSERT, 1)
    require(updated.replace(INSERT, MARKER, 1) == text and
            updated.count("AbyssCompanion {") == text.count("AbyssCompanion {"),
            "PRIVATE_QML_REVERSIBILITY_INVALID")
    return updated.encode("utf-8")


def private_dir(path):
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and not path.is_symlink() and
            info.st_uid == os.getuid() and
            not stat.S_IMODE(info.st_mode) & 0o077,
            "PRIVATE_DIRECTORY_UNSAFE")


def audit_layout(repo, shell):
    repo, shell = Path(repo), Path(shell)
    require(repo.name == "repo" and
            repo.parent.name.startswith("wull-paint-canary."),
            "UNREVIEWED_DISPOSABLE_CLONE_LAYOUT")
    for part in (repo.parent, repo, shell.parent, shell):
        private_dir(part)
    root = repo.resolve(strict=True)
    target = shell.resolve(strict=True)
    require(root not in target.parents and
            target != root and target not in root.parents and
            shell.parent != repo and
            shell != repo and
            not (repo / "modules").is_symlink(),
            "PRIVATE_SHADOW_OVERLAPS_CHECKOUT")
    require((repo / ORIGINAL).is_file() and
            not (repo / ORIGINAL).is_symlink()
            and (repo / PERIMETER).is_file()
            and not (repo / PERIMETER).is_symlink(),
            "ORIGINAL_QML_SOURCE_MISSING")
    require(not (shell / "modules").exists() and
            not (shell / "modules").is_symlink(),
            "PRIVATE_SHADOW_ALREADY_EXISTS")
    return root, target


def stage(repo, shell, mode):
    require(mode in MODES, "UNREVIEWED_PRIVATE_MARGIN_MODE")
    root, output = audit_layout(repo, shell)
    original = (root / ORIGINAL).read_bytes()
    perimeter = (root / PERIMETER).read_bytes()
    require(blob(perimeter) == PERIMETER_BLOB,
            "PRODUCTION_PERIMETER_SOURCE_MISMATCH")
    # Check BOTH cases against the exact original source before ANY write.
    candidate = generate(original)
    modules = root / "modules"
    abyss = modules / "abyss"
    companion = abyss / "companion"
    require(modules.is_dir() and abyss.is_dir() and companion.is_dir() and
            not modules.is_symlink() and not abyss.is_symlink() and
            not companion.is_symlink(),
            "REVIEWED_QML_MODULES_MISSING")
    shadow = output / "modules"
    shadow.mkdir(mode=0o700)
    for child in modules.iterdir():
        if child.name != "abyss":
            (shadow / child.name).symlink_to(child)
    abyss_shadow = shadow / "abyss"
    abyss_shadow.mkdir(mode=0o700)
    for child in abyss.iterdir():
        if child.name not in ("companion", "AbyssPerimeter.qml"):
            (abyss_shadow / child.name).symlink_to(child)
    # Copy exact production perimeter bytes into private import tree rather
    # than symlink: its relative companion module must resolve the SHADOW
    # and not be silently resolved from its original repository directory.
    private_perimeter = abyss_shadow / "AbyssPerimeter.qml"
    private_perimeter.write_bytes(perimeter)
    private_perimeter.chmod(0o600)
    require(private_perimeter.read_bytes() == perimeter,
            "PRIVATE_PERIMETER_COPY_UNVERIFIED")
    companion_shadow = abyss_shadow / "companion"
    companion_shadow.mkdir(mode=0o700)
    for child in companion.iterdir():
        if child.name != "AbyssCompanion.qml":
            (companion_shadow / child.name).symlink_to(child)
    target = companion_shadow / "AbyssCompanion.qml"
    if mode == "original_m0":
        target.symlink_to(root / ORIGINAL)
    else:
        target.write_bytes(candidate)
        target.chmod(0o600)
        require(target.read_bytes() == candidate and
                blob((root / ORIGINAL).read_bytes()) == ORIGINAL_BLOB,
                "PRIVATE_CANDIDATE_WRITE_NOT_VERIFIED")
    return target


if __name__ == "__main__":
    raise SystemExit("INERT_MODULE_ONLY_NO_STANDALONE_EXECUTION")
