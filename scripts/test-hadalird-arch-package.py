#!/usr/bin/env python3
"""Execute Arch package functions and hooks in private filesystem fixtures."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
recipe = ROOT / "sdata/dist-arch/inir-deps/PKGBUILD"
arrays = {}
for field in ("depends", "optdepends"):
    result = subprocess.run(["bash", "-ec", 'source "$1"; name="$2"; declare -n values="$name"; printf "%s\\n" "${values[@]}"',
                             "fixture", str(recipe), field], text=True, capture_output=True, check=True)
    arrays[field] = result.stdout.splitlines()
for name in ("tlp", "tlp-pd", "tlp-rdw"):
    assert name not in arrays["depends"], name + " remains a mandatory core dependency"
    assert any(value.startswith(name + ":") for value in arrays["optdepends"]), name + " lost its optional package guidance"
with tempfile.TemporaryDirectory(prefix="hadalird-arch-") as name:
    base = Path(name)
    source = base / "src"
    source.mkdir()
    for dirname in ("inir", "Hadalis-fixture"):
        (source / dirname).symlink_to(ROOT, target_is_directory=True)
    binaries = source / "inir-native-target/release"
    binaries.mkdir(parents=True)
    for binary in ("inir-inputd", "inir-mpdd", "inir-native", "inir-theme"):
        (binaries / binary).write_text("#!/bin/sh\nexit 0\n")
    for family in ("inir-shell", "inir-shell-git"):
        stage = base / family
        recipe = ROOT / "distro/arch" / family / "PKGBUILD"
        env = dict(os.environ, srcdir=str(source), pkgdir=str(stage),
                   INIR_SOURCE_DIR="Hadalis-fixture")
        result = subprocess.run(["bash", "-ec", 'source "$1"; package',
                                 "fixture", str(recipe)], env=env, cwd=base,
                                text=True, capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
        for path in ("usr/libexec/inir-battery-charge-limit", "usr/libexec/inir-thinkfan",
                     "usr/share/inir/tlp-settings-schema.json",
                     "usr/share/polkit-1/actions/org.inir.battery-charge-limit.policy",
                     "usr/share/polkit-1/actions/org.inir.thinkfan.policy"):
            assert not (stage / path).exists(), (family, path)
        assert (stage / "usr/bin/inir").is_file()
        assert (stage / "usr/lib/systemd/user/inir.service").is_file()
        assert (stage / "usr/share/quickshell/inir/services/Hadalird.qml").is_file()
        # Rewrite only absolute system roots into the private fixture. An old
        # destructive hook would execute this helper and remove these profiles.
        system = base / (family + "-system")
        helper = system / "usr/libexec/inir-battery-charge-limit"
        helper.parent.mkdir(parents=True)
        marker = system / "mutated"
        helper.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$MARKER"\n')
        helper.chmod(0o755)
        profiles = [system / "etc/tlp.d" / filename for filename in
                    ("99-inir-battery-charge-limit.conf", "99-inir-tlp-settings.conf")]
        for profile in profiles:
            profile.parent.mkdir(parents=True, exist_ok=True)
            profile.write_text("preserve-owner-state\n")
        original = ROOT / "distro/arch" / family / (family + ".install")
        hook = base / (family + ".hook")
        hook.write_text(original.read_text().replace("/usr/libexec/", str(system) + "/usr/libexec/")
                        .replace("/etc/tlp.d/", str(system) + "/etc/tlp.d/"))
        result = subprocess.run(["bash", "-ec", 'source "$1"; pre_remove', "fixture", str(hook)],
                                env=dict(os.environ, MARKER=str(marker)), text=True, capture_output=True)
        assert result.returncode == 0, result.stderr
        assert not marker.exists(), family + " mutated optional hardware state"
        assert all(p.read_text() == "preserve-owner-state\n" for p in profiles)
print("HADALIRD_ARCH_PASS stable/git payloads omit privileged integrations; actual removal hooks preserve state")
