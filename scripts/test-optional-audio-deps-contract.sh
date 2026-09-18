#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

payload_list="$(python3 sdata/lib/runtime-payload.py list --root .)"
for runtime_path in \
  services/deferred/EasyEffects.qml \
  services/deferred/EqualizerService.qml; do
  grep -Fqx "$runtime_path" <<<"$payload_list" \
    || { printf 'FAIL: runtime payload omits optional Equalizer service boundary: %s\n' "$runtime_path" >&2; exit 1; }
done

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
optional_descriptions = {
    "easyeffects": "optional audio effects and equalizer backend",
    "socat": "optional EasyEffects control transport for equalizer",
}


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


def require_optional_descriptions(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    for package, description in optional_descriptions.items():
        if path.name == ".SRCINFO":
            marker = f"optdepends = {package}: {description}"
        else:
            marker = f"'{package}: {description}'"
        if marker not in text:
            raise SystemExit(
                f"FAIL: {path} does not describe {package} as the optional Equalizer backend/transport contract"
            )


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

    require_optional_descriptions(path)

print("PASS: Arch packaging keeps EasyEffects and socat optional with consistent Equalizer metadata")
PY

media_controller="services/MprisController.qml"
audio_doc="docs/AUDIO_MEDIA.md"
deps_map="sdata/lib/deps-map.sh"
audio_bundle="sdata/dist-arch/inir-audio/PKGBUILD"
deps_bundle="sdata/dist-arch/inir-deps/PKGBUILD"

for pkg in distro/arch/inir-shell/PKGBUILD distro/arch/inir-shell-git/PKGBUILD; do
  grep -Fq "'mpd-mpris: MPD/rmpc media controls through MPRIS'" "$pkg" \
    || { printf 'FAIL: %s does not advertise the MPD MPRIS bridge\n' "$pkg" >&2; exit 1; }
done
for srcinfo in distro/arch/inir-shell/.SRCINFO distro/arch/inir-shell-git/.SRCINFO; do
  grep -Fq "optdepends = mpd-mpris: MPD/rmpc media controls through MPRIS" "$srcinfo" \
    || { printf 'FAIL: %s does not advertise the MPD MPRIS bridge\n' "$srcinfo" >&2; exit 1; }
done
grep -Eq '^[[:space:]]+mpd-mprisgrep -Eq '^[[:space:]]+mpd-mprisgrep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
 "$deps_bundle" \
  || { printf 'FAIL: inir-deps must track official mpd-mpris as an installed dependency candidate\n' >&2; exit 1; }
grep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
 "$audio_bundle" \
  || { printf 'FAIL: inir-audio must include mpd-mpris for MPD/rmpc media integration\n' >&2; exit 1; }
grep -Eq '^[[:space:]]+mpd-mprisgrep -Eq '^[[:space:]]+mpd-mprisgrep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
 "$deps_bundle" \
  || { printf 'FAIL: inir-deps must track official mpd-mpris as an installed dependency candidate\n' >&2; exit 1; }
grep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
 distro/arch/inir-meta/PKGBUILD \
  || { printf 'FAIL: full Arch meta-package must install mpd-mpris for MPD/rmpc media integration\n' >&2; exit 1; }
grep -Fq grep -Eq '^[[:space:]]+mpd-mprisgrep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
 "$deps_bundle" \
  || { printf 'FAIL: inir-deps must track official mpd-mpris as an installed dependency candidate\n' >&2; exit 1; }
grep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
\tdepends = mpd-mpris' distro/arch/inir-meta/.SRCINFO \
  || { printf 'FAIL: inir-meta .SRCINFO must include mpd-mpris\n' >&2; exit 1; }
grep -Eq '^[[:space:]]+mpd-mprisgrep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
 "$deps_bundle" \
  || { printf 'FAIL: inir-deps must track official mpd-mpris as an installed dependency candidate\n' >&2; exit 1; }
grep -Fq 'DEPS_AUDIO_MPD_MPRIS="arch:mpd-mpris' "$deps_map" \
  || { printf 'FAIL: dependency routing omits the Arch mpd-mpris bridge\n' >&2; exit 1; }

for marker in \
  'function _mpdPlaybackStreamPresent(): bool' \
  'function _maybeStartMpdMprisBridge(): void' \
  '["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' \
  'name === "org.mpris.MediaPlayer2.mpd"' \
  'name.startsWith("org.mpris.MediaPlayer2.mpd.")'; do
  grep -Fq "$marker" "$media_controller" \
    || { printf 'FAIL: MprisController MPD bridge contract missing: %s\n' "$marker" >&2; exit 1; }
done

grep -Fq '### MPD and rmpc' "$audio_doc" \
  || { printf 'FAIL: audio/media docs omit MPD/rmpc bridge behavior\n' >&2; exit 1; }
grep -Fq '`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself' "$audio_doc" \
  || { printf 'FAIL: audio/media docs no longer explain the MPD/MPRIS boundary\n' >&2; exit 1; }

printf '%s\n' 'PASS: MPD/rmpc media integration routes through the mpd-mpris bridge'
