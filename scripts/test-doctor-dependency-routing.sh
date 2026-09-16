#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

doctor="sdata/lib/doctor.sh"
arch_installer="sdata/dist-arch/install-deps.sh"

python3 - "$doctor" "$arch_installer" <<'PY'
from pathlib import Path
import re
import sys

doctor_path = Path(sys.argv[1])
installer_path = Path(sys.argv[2])
doctor = doctor_path.read_text(encoding="utf-8")
installer = installer_path.read_text(encoding="utf-8")

cmd_block = re.search(r"local cmds=\(\n(?P<body>.*?)\n\s*\)", doctor, re.S)
if not cmd_block:
    raise SystemExit("FAIL: could not find doctor command dependency list")

doctor_cmds = []
for command, _friendly in re.findall(r'^\s*"([^":]+):([^"\n]+)"\s*$', cmd_block.group("body"), re.M):
    doctor_cmds.append(command)

if not doctor_cmds:
    raise SystemExit("FAIL: doctor dependency command list is empty")

mapping_block = re.search(r"declare -A cmd_to_pkg=\(\n(?P<body>.*?)\n\s*\)", installer, re.S)
if not mapping_block:
    raise SystemExit("FAIL: could not find Arch doctor command mapping")

mapping = dict(re.findall(r'^\s*\[([^\]]+)\]="([^"]+)"\s*$', mapping_block.group("body"), re.M))
missing = sorted(set(doctor_cmds) - mapping.keys())
if missing:
    raise SystemExit(
        "FAIL: doctor commands lack explicit Arch package mappings: " + ", ".join(missing)
    )

# These aliases are deliberately non-identity mappings. Lock them separately so
# a future cleanup cannot leave a syntactically present but invalid package name.
required_aliases = {
    "qs": "quickshell",
    "nmcli": "networkmanager",
    "wpctl": "wireplumber",
    "python3": "python",
    "magick": "imagemagick",
    "wl-copy": "wl-clipboard",
    "wl-paste": "wl-clipboard",
    "awww-daemon": "awww",
    "notify-send": "libnotify",
    "flock": "util-linux",
    "qalc": "libqalculate",
    "blueman-manager": "blueman",
    "gowall": "gowall-bin",
    "kwriteconfig6": "kconfig",
    "checkupdates": "pacman-contrib",
    "missioncenter": "mission-center",
    "xdg-settings": "xdg-utils",
    "trans": "translate-shell",
}
wrong = [
    f"{cmd}->{mapping.get(cmd)!r} (expected {package!r})"
    for cmd, package in required_aliases.items()
    if mapping.get(cmd) != package
]
if wrong:
    raise SystemExit("FAIL: invalid Arch doctor aliases: " + "; ".join(wrong))

print(f"ok - {len(doctor_cmds)} doctor command dependencies have explicit Arch package routing")
PY
