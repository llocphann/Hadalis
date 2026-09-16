#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - \
  sdata/dist-arch/inir-audio/PKGBUILD \
  sdata/dist-arch/inir-deps/PKGBUILD \
  distro/arch/inir-shell/PKGBUILD \
  distro/arch/inir-shell/.SRCINFO \
  distro/arch/inir-shell-git/PKGBUILD \
  distro/arch/inir-shell-git/.SRCINFO \
  distro/arch/inir-meta/PKGBUILD \
  distro/arch/inir-meta/.SRCINFO <<'PY'
from pathlib import Path
import re
import sys

optional = {"easyeffects", "socat"}


def normalize_package(line: str) -> str:
    value = line.strip()
    if value and value[0] in "'\"" and value[-1] == value[0]:
        value = value[1:-1]
    package = value.split(":", 1)[0]
    return re.split(r"[<>=]", package, maxsplit=1)[0]


def packages_in_pkgbuild(path: Path, name: str) -> set[str]:
    text = path.read_text(encoding="utf-8")
    match = re.search(rf"(?ms)^{re.escape(name)}=\(\n(?P<body>.*?)^\)\s*$", text)
    if not match:
        raise SystemExit(f"FAIL: {path} is missing {name}=()")

    packages = set()
    for raw_line in match.group("body").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        packages.add(normalize_package(line))
    return packages


def packages_in_srcinfo(path: Path, name: str) -> set[str]:
    prefix = f"{name} = "
    packages = {
        normalize_package(line.strip()[len(prefix):])
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip().startswith(prefix)
    }
    if not packages:
        raise SystemExit(f"FAIL: {path} is missing {name} metadata")
    return packages


def packages_in(path: Path, name: str) -> set[str]:
    if path.name == ".SRCINFO":
        return packages_in_srcinfo(path, name)
    return packages_in_pkgbuild(path, name)


for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    hard = packages_in(path, "depends")
    opt = packages_in(path, "optdepends")

    leaked = sorted(optional & hard)
    if leaked:
        raise SystemExit(
            f"FAIL: {path} hard-depends on optional Equalizer backend tools: {', '.join(leaked)}"
        )

    missing = sorted(optional - opt)
    if missing:
        raise SystemExit(
            f"FAIL: {path} does not advertise optional Equalizer backend tools: {', '.join(missing)}"
        )

print("PASS: Arch packaging keeps EasyEffects and socat optional")
PY
