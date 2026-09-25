#!/usr/bin/env python3
"""Static contract for opt-in QML owner profiling."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST = ROOT / "native" / "inir-native" / "src" / "qml_profile.rs"
MAIN = ROOT / "native" / "inir-native" / "src" / "main.rs"
DISPATCH = ROOT / "scripts" / "native-dispatch"
CAPTURE = ROOT / "scripts" / "qml-profile-capture.py"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing {token!r}")


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} contains forbidden {token!r}")


def main() -> None:
    rust = RUST.read_text(encoding="utf-8")
    main_rs = MAIN.read_text(encoding="utf-8")
    dispatch = DISPATCH.read_text(encoding="utf-8")
    capture = CAPTURE.read_text(encoding="utf-8")

    for token in (
        '"Binding"',
        '"HandlingSignal"',
        '"Javascript"',
        '"Creating"',
        '"Compiling"',
        "allocate_exclusive_work",
        "attribute_memory",
        '"components": sorted_rows',
        '"modules": sorted_rows',
        '"services": sorted_rows',
        '"qmlWorkMsPerSecond"',
        '"allocatedBytes"',
        '"freedBytes"',
        '"not per-owner CPU percent"',
        '"not retained RSS/PSS"',
        '"per-owner GPU usage is intentionally unavailable"',
    ):
        require(rust, token, "Rust QML profile attribution")

    for token in (
        "QmlProfile {",
        "qml_profile::summarize(&trace, &root)",
    ):
        require(main_rs, token, "inir-native qml-profile CLI")

    require(dispatch, "qml-profile)", "native dispatch qml-profile route")
    require(
        dispatch,
        '"$BIN_DIR/inir-native" qml-profile "$@"',
        "native dispatch qml-profile backend",
    )
    forbid(
        dispatch[dispatch.index("    qml-profile)"):dispatch.index(
            "    clipboard-store)"
        )],
        "python",
        "QML profile attribution must not silently fall back to Python",
    )

    for token in (
        '"--interactive"',
        '"--record",',
        '"off"',
        "PROFILE_FEATURES",
        'profiler.stdin.write("r\\n")',
        'profiler.stdin.write(f"f {trace}\\n")',
        '"qml-profile"',
        '"latest.json"',
        'service_action("stop")',
        'service_action("restart")',
    ):
        require(capture, token, "bounded QML profile capture")

    forbid(capture, "QSG_RHI_PROFILE", "QML owner capture GPU attribution")
    print("PASS: QML owner profiling is opt-in and attribution semantics stay truthful")


if __name__ == "__main__":
    main()
