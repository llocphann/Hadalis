#!/usr/bin/env python3
"""Static contract for opt-in QML owner profiling."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUST = ROOT / "native" / "inir-native" / "src" / "qml_profile.rs"
MAIN = ROOT / "native" / "inir-native" / "src" / "main.rs"
DISPATCH = ROOT / "scripts" / "native-dispatch"
CAPTURE = ROOT / "scripts" / "qml-profile-capture.py"
RUNTIME = ROOT / "services" / "RuntimeDiagnostics.qml"
DASHBOARD = ROOT / "modules" / "settings" / "widgets" / "BtopDashboard.qml"
OWNER_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopOwnerProfileTable.qml"
QMLEDIR = ROOT / "modules" / "settings" / "widgets" / "qmldir"
CLI = ROOT / "scripts" / "inir"


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
    runtime = RUNTIME.read_text(encoding="utf-8")
    dashboard = DASHBOARD.read_text(encoding="utf-8")
    owner_table = OWNER_TABLE.read_text(encoding="utf-8")
    qmldir = QMLEDIR.read_text(encoding="utf-8")
    cli = CLI.read_text(encoding="utf-8")

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
        '"hotspots": hotspot_rows',
        "event_work_ns",
        '"qmlWorkMsPerSecond"',
        '"allocatedBytes"',
        '"cumulative positive QV4 SmallItem/LargeItem allocations"',
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
        '"qml-profile", "--help"',
        "runtime_environment()",
        '"NIRI_SOCKET"',
        "reserve_debug_port()",
        "wait_for_debug_listener",
        '"--debug"',
        '"--waitfordebug"',
        '"--attach"',
        '"127.0.0.1"',
        '"--port"',
    ):
        require(capture, token, "bounded QML profile capture")

    forbid(capture, "QSG_RHI_PROFILE", "QML owner capture GPU attribution")

    for token in (
        'qmlOwnerProfilePath:',
        'watchChanges: true',
        'qmlProfile: root.qmlOwnerProfile',
        'parsed?.source !== "qt-qml-profiler-xml"',
    ):
        require(runtime, token, "RuntimeDiagnostics persisted owner profile")

    for token in (
        "readonly property var qmlOwnerProfile:",
        "BtopOwnerProfileTable {",
        "visible: root.qmlOwnerProfile !== null",
        "visible: root.qmlOwnerProfile === null",
        "function launchDeepProfile(): void",
        "onDeepProfileRequested:",
        "root.launchDeepProfile()",
        '"/usr/bin/systemd-run"',
        '"--user", "--collect", "--quiet"',
        '"--service-type=exec"',
        'Quickshell.shellPath("scripts/inir")',
        '"dev", "profile", "--duration", "5"',
    ):
        require(dashboard, token, "Diagnostics deep profile presentation")

    for token in (
        'Translation.tr("Deep QML owners")',
        'Translation.tr("Modules")',
        'Translation.tr("Services")',
        'Translation.tr("Components")',
        '"QML "',
        '"JS alloc "',
        "root.allocatedBytes(ownerRow.modelData)",
        "root.allocationRate(ownerRow.modelData)",
        "interactive: contentHeight > height",
    ):
        require(owner_table, token, "deep QML owner table")
    require(
        owner_table,
        "JS/QV4 allocated by owner — cumulative pressure, not retained RAM/PSS",
        "deep QML owner semantics",
    )
    forbid(owner_table, "CPU %", "deep owner table fake CPU attribution")
    forbid(owner_table, "RAM %", "deep owner table fake RAM attribution")
    forbid(owner_table, "freedBytes(", "owner frees cannot be attributed reliably")

    activity_table = (ROOT / "modules" / "settings" / "widgets"
                      / "BtopActivityTable.qml").read_text(encoding="utf-8")
    for token in (
        "signal deepProfileRequested()",
        "Per-owner RAM/PSS unavailable · capture JS/QV4 memory",
        'Translation.tr("Profile 5s")',
        "onClicked: root.deepProfileRequested()",
        "Layout.preferredWidth: 104",
        "Layout.preferredHeight: 28",
        "contentItem: Row {",
        "anchors.centerIn: parent",
        'text: "memory"',
        "iconSize: 15",
    ):
        require(activity_table, token, "component memory profile affordance")

    require(
        qmldir,
        "BtopOwnerProfileTable 1.0 BtopOwnerProfileTable.qml",
        "settings widget type export",
    )
    require(cli, 'elif [[ "${1:-}" == "profile" ]]', "inir dev profile route")
    require(cli, 'qml-profile-capture.py"', "inir dev profile capture worker")
    print("PASS: QML owner profiling is opt-in and attribution semantics stay truthful")


if __name__ == "__main__":
    main()
