#!/usr/bin/env python3
"""Static contract for CAVA, Weather and ThinkFan runtime dependencies."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        failures.append(f"{source} missing dependency contract token: {token!r}")


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        failures.append(f"{source} must not hard-require optional capability: {token!r}")


def main() -> None:
    cava = read("services/deferred/CavaService.qml")
    weather = read("services/Weather.qml")
    songrec = read("services/deferred/SongRec.qml")
    mpris = read("services/MprisController.qml")
    helper = read("assets/helpers/inir-thinkfan")
    doctor = read("sdata/lib/doctor.sh")
    generic = read("sdata/dist-generic/install-deps.sh")
    arch_installer = read("sdata/dist-arch/install-deps.sh")
    debian = read("sdata/dist-debian/install-deps.sh")
    fedora = read("sdata/dist-fedora/install-deps.sh")
    uninstall = read("sdata/lib/uninstall.sh")
    nix = read("nix/package.nix")
    arch = read("distro/arch/inir-shell/PKGBUILD")
    arch_git = read("distro/arch/inir-shell-git/PKGBUILD")
    thinkfan_docs = read("docs/THINKFAN.md")

    # CAVA is a real process dependency of the shared visualizer service.
    require(cava, 'command: ["cava", "-p", root.configPath]', "CavaService.qml")
    require(doctor, '"cava:cava"', "doctor.sh")
    require(generic, 'check_cmd "cava" "CAVA audio visualizer"', "generic installer")
    require(generic, "pipewire, pipewire-pulse, wireplumber, pavucontrol, cava",
            "generic installer")
    require(debian, "DEBIAN_AUDIO_PKGS+=(cava)", "Debian installer")
    require(debian, "if ! command -v cava &>/dev/null; then", "Debian installer")
    require(fedora, "  cava", "Fedora installer")
    require(nix, '++ optionalTop "cava"', "Nix package")
    for source, text in (("inir-shell", arch), ("inir-shell-git", arch_git)):
        require(text, "'cava: audio visualizer'", source)

    # Weather hard-requires curl. GPS via Geoclue/where-am-i is optional because
    # the service falls back to IP location providers.
    require(weather, 'command: ["/usr/bin/curl"', "Weather.qml")
    require(weather, 'command: ["where-am-i", "-t", "10"]', "Weather.qml")
    require(weather, "http://ip-api.com/json/", "Weather.qml")
    require(weather, "https://ipwho.is/", "Weather.qml")
    require(doctor, '"curl:curl"', "doctor.sh")
    require(generic, 'check_cmd "curl" "curl"', "generic installer")
    require(debian, "  curl", "Debian installer")
    require(debian, "  geoclue-2.0", "Debian installer")
    require(fedora, "  curl", "Fedora installer")
    require(fedora, "  geoclue2", "Fedora installer")
    require(nix, "      curl", "Nix package")
    require(nix, '++ optionalTop "geoclue2"', "Nix package")
    for source, text in (("inir-shell", arch), ("inir-shell-git", arch_git)):
        require(text, "  curl", source)
        require(text, "'geoclue: GPS-backed weather location detection'", source)

    # Song recognition uses the standard freedesktop notification client.
    # Installing dunst just for dunstify would conflict with Hadalis' own
    # notification server; notify-send supports actions and returns the chosen
    # action identifier on stdout.
    for token in (
        '"/usr/bin/notify-send"',
        '"-A", "shazam=Shazam"',
        '"-A", "youtube=YouTube"',
        'action === "shazam"',
        'action === "youtube"',
    ):
        require(songrec, token, "SongRec.qml")
    forbid(songrec, "dunstify", "SongRec.qml")
    forbid(arch_installer, '[dunstify]="dunst"', "Arch installer")
    forbid(debian, '[dunstify]="dunst"', "Debian installer")
    forbid(fedora, '[dunstify]="dunst"', "Fedora installer")
    forbid(generic, "dunst, libnotify", "generic installer")
    if (ROOT / "sdata/lib/deps-map.sh").exists():
        failures.append("retired sdata/lib/deps-map.sh dependency map returned")
    forbid(uninstall, '["dunstify"]', "uninstall ownership")

    # Browser media must not depend on the KDE compatibility bridge. Native
    # Firefox/Chromium MPRIS remains supported, while the Plasma bridge is
    # handled opportunistically when present.
    for token in (
        "org.mpris.MediaPlayer2.firefox",
        "org.mpris.MediaPlayer2.chromium",
        "org.mpris.MediaPlayer2.chrome",
        "org.mpris.MediaPlayer2.plasma-browser-integration",
    ):
        require(mpris, token, "MprisController.qml")

    forbid(
        arch_installer,
        "plasma-browser-integration   # Provides browser MPRIS sessions and artwork",
        "Arch source installer",
    )
    for source, text, array_name in (
        ("Debian installer", debian, "DEBIAN_AUDIO_PKGS"),
        ("Fedora installer", fedora, "FEDORA_AUDIO_PKGS"),
    ):
        match = re.search(
            rf"(?ms)^{array_name}=\(\n(?P<body>.*?)^\)\s*$",
            text,
        )
        if not match:
            failures.append(f"{source} is missing {array_name}=()")
        elif re.search(r"(?m)^\s*plasma-browser-integration\s*$", match.group("body")):
            failures.append(
                f"{source} hard-requires optional plasma-browser-integration"
            )

    require(
        generic,
        "plasma-browser-integration (optional browser MPRIS compatibility/artwork bridge)",
        "generic installer",
    )
    for source, text in (("inir-shell", arch), ("inir-shell-git", arch_git)):
        require(
            text,
            "'plasma-browser-integration: browser MPRIS sessions and artwork'",
            source,
        )

    # ThinkFan is intentionally optional and hardware-specific. Hadalis owns the
    # bridge, while upstream executable/service/config remain external.
    for token in (
        "find_thinkfan()",
        "service_name=thinkfan.service",
        'systemctl cat "$service_name"',
        "[ -r /etc/thinkfan.yaml ]",
        "[ -r /etc/thinkfan.conf ]",
    ):
        require(helper, token, "inir-thinkfan helper")

    forbid(doctor, '"thinkfan:thinkfan"', "doctor.sh")
    for source, text in (("inir-shell", arch), ("inir-shell-git", arch_git)):
        require(text, "'thinkfan: managed fan-control integration'", source)

    for token in (
        "This integration is optional",
        "the `thinkfan` executable",
        "a system `thinkfan.service` visible to `systemctl`",
        "a valid ThinkFan configuration",
        "ThinkFan configuration is hardware-specific",
        "does not invent fan curves or sensor mappings automatically",
        "The current Nix package does not provision these privileged system-level files",
    ):
        require(thinkfan_docs, token, "THINKFAN.md")

    if failures:
        print("Runtime integration dependency contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Runtime integration dependency contract: OK")


if __name__ == "__main__":
    main()
