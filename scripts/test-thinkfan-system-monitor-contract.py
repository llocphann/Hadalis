#!/usr/bin/env python3
"""Regression contract for the v1.0 ThinkFan/System Monitor integration."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    resources_popup = read("modules/bar/ResourcesPopup.qml")
    dashboard_system = read("modules/dashboard/DashSystem.qml")
    styled_popup = read("modules/bar/StyledPopup.qml")
    config_schema = read("modules/common/Config.qml")
    default_config = read("defaults/config.json")
    thinkfan_service = read("services/ThinkFanService.qml")
    thinkfan_helper = read("assets/helpers/inir-thinkfan")
    shell_root = read("shell.qml")
    system_settings = read("modules/settings/GeneralConfigCore.qml")
    system_facade = read("modules/settings/GeneralConfig.qml")
    settings_registry = read("modules/settings/SettingsPageRegistryData.qml")
    bar_settings = read("modules/settings/BarConfig.qml")
    bar_config = read("modules/settings/BarConfig.qml")
    source_setup = read("sdata/subcmd-install/2.setups.sh")
    thinkfan_migration = read("sdata/migrations/041-thinkfan-helper-bridge.sh")
    uninstall_lib = read("sdata/lib/uninstall.sh")
    migration_engine = read("sdata/lib/migrations.sh")
    setup_entrypoint = read("setup")
    thinkfan_docs = read("docs/THINKFAN.md")

    for token in (
        "ThinkFanService.refresh()",
        "ThinkFanService.applyProfile(",
        'Translation.tr("Fan")',
        'Translation.tr("RPM:")',
        'Translation.tr("Level:")',
        "thinkFanCanApply",
        "font.pixelSize: Appearance.font.pixelSize.small",
        "thinkFanApplyErrorMessage",
    ):
        check(token in resources_popup,
              f"System Monitor popup must own ThinkFan runtime UI: {token}")

    for token in (
        "ThinkFanService.refresh()",
        "ThinkFanService.applyProfile(",
        'Translation.tr("Fan")',
        'Translation.tr("RPM:")',
        'Translation.tr("Level:")',
        "ThinkFanService.fanRpm",
        "ThinkFanService.fanLevel",
        "root.thinkFanCanApply",
    ):
        check(token in dashboard_system,
              f"Dashboard System module must reuse ThinkFan runtime state/control: {token}")

    for forbidden in (
        "ThinkFanConnectedSurface",
        "SurfaceRouteController",
        "AnchorPublisher",
        'surface: "thinkfan"',
        "connectAdjacentScreenEdge: true",
    ):
        check(forbidden not in resources_popup,
              f"System Monitor ThinkFan UI must not revive a standalone popup route: {forbidden}")

    for forbidden in (
        'Translation.tr("Free:")',
        'Translation.tr("Service")',
        'Translation.tr("ThinkFan")',
        'Translation.tr("Fan speed")',
        'Translation.tr("Fan level")',
        'Translation.tr("Temperature")',
        'Translation.tr("High")',
        'Translation.tr("Medium")',
        'Translation.tr("Low")',
        "thinkFanStatusMessage",
        "describeThinkFanStatus",
    ):
        check(forbidden not in resources_popup,
              f"System Monitor popup must keep the compact metrics contract: {forbidden}")

    fan_pos = resources_popup.index('Translation.tr("Fan")')
    speed_pos = resources_popup.index('Translation.tr("RPM:")')
    level_pos = resources_popup.index('Translation.tr("Level:")')
    notice_pos = resources_popup.index("NoticeBox {", level_pos)
    check(fan_pos < speed_pos < level_pos < notice_pos,
          "ThinkFan monitor controls/metrics must remain one inline row before error feedback")

    for token in (
        'label: Translation.tr("Thermal")',
        'value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`',
        'value: `${Math.round(ResourceUsage.gpuUsage * 100)}%`',
        'property string minimumValueSample: ""',
        'property int valueHorizontalAlignment: Text.AlignRight',
        'Layout.minimumWidth: minimumValueText.implicitWidth',
        'horizontalAlignment: resourceItem.valueHorizontalAlignment',
        'minimumValueSample: "99%"',
        'valueHorizontalAlignment: Text.AlignLeft',
        'text: "speed"',
        'text: "tune"',
        "width: thermalColumn.width",
        "width: cpuColumn.width",
    ):
        check(token in resources_popup,
              f"System Monitor compact grid must keep screenshot-aligned metrics: {token}")

    for token in (
        "property bool connectAdjacentScreenEdge: false",
        "id: directEdgeAttachment",
        "readonly property real _popupScreenMargin: root._screenEdgeThickness",
        "screenMargin: root._popupScreenMargin",
        "connectorLength: 0",
        "ConnectedSurfaceIrisFrame {",
        "shadowEnabled: root._edgeShadowEnabled",
        "screenEdge?.physicalShadow?.enabled ?? true",
        "Qt.alpha(Appearance.m3colors.m3shadow, root._edgeShadowOpacity)",
    ):
        check(token in styled_popup,
              f"StyledPopup must use direct Caelestia-style edge attachment: {token}")
    for forbidden in (
        "id: adjacentScreenEdgeGeometry",
        "geometry: adjacentScreenEdgeGeometry",
    ):
        check(forbidden not in styled_popup,
              f"StyledPopup must not render a separate adjacent connector stem: {forbidden}")

    for token in (
        "property JsonObject fanControl: JsonObject {",
        "property bool enabled: false",
        "property int powerSaver: 0",
        "property int balanced: 0",
        "property int performance: 0",
    ):
        check(token in config_schema,
              f"Config schema must persist safe per-profile fan levels: {token}")

    for token in (
        '"fanControl": {',
        '"powerSaver": 0',
        '"balanced": 0',
        '"performance": 0',
    ):
        check(token in default_config,
              f"Default config must keep per-profile fan levels on Auto: {token}")

    for token in (
        "import Quickshell.Services.UPower",
        "property bool directControlAvailable: false",
        "property bool fanLevelControlSupported: false",
        "readonly property string activePowerProfileKey:",
        "readonly property int configuredActiveFanLevel:",
        "function setConfiguredFanLevel(key: string, requestedLevel): bool",
        "function setProfileFanControlEnabled(requestedEnabled: bool): bool",
        "function applyFanLevel(requestedLevel): bool",
        "function applyConfiguredPowerProfileFanLevel(): bool",
        "Config.flushWrites()",
        'root.lastApplyError = "managed-control-active"',
        'root.lastApplyError = "helper-update-required"',
        'Config.getNestedValue("powerProfiles.fanControl.enabled", false)',
        'Config.getNestedValue(path, 0)',
        "function _scheduleConfiguredFanLevelApply(): void",
        "function onConfigChanged(): void",
        "root._scheduleConfiguredFanLevelApply()",
        'String(root.fanLevel ?? "").trim().toLowerCase() === normalized',
        "root._profileFollowArmed",
        'property string _queuedFanLevel: ""',
        "function _drainQueuedFanLevel(): void",
        'completedOperation === "profile:firmware"',
        "onTriggered: {",
        "root._profileFollowArmed = true",
    ):
        check(token in thinkfan_service,
              f"ThinkFan service must own guarded power-profile fan levels: {token}")

    for token in (
        "fan_control_path=/sys/module/thinkpad_acpi/parameters/fan_control",
        "direct_control_available()",
        '"fanLevelControlSupported":true',
        "--set-level auto|1..7",
        "set_fan_level()",
        "auto|1|2|3|4|5|6|7",
        "stop ThinkFan managed control before setting a fixed fan level",
        "level auto",
    ):
        check(token in thinkfan_helper,
              f"Privileged helper must guard direct fan-level control: {token}")

    for token in (
        'settingsTaskSection: "fan"',
        'title: Translation.tr("Fan Control")',
        'text: Translation.tr("ThinkFan managed control")',
        "ThinkFanService.applyProfile(",
        "checked: root.thinkFanManaged",
        '{ displayName: Translation.tr("Fan Control"), icon: "mode_fan", value: "fan" }',
        'text: Translation.tr("Follow power profile fan level")',
        'text: Translation.tr("Power Saver fan level")',
        'text: Translation.tr("Balanced fan level")',
        'text: Translation.tr("Performance fan level")',
        "ThinkFanService.directControlAvailable",
        "ThinkFanService.fanLevelControlSupported",
        "ThinkFanService.setConfiguredFanLevel(",
        "ThinkFanService.setProfileFanControlEnabled(",
        "enabled: Config.ready",
    ):
        check(token in system_settings,
              f"System Settings must own the shared ThinkFan profile control: {token}")

    for forbidden in (
        "root.setProfileFanLevel(",
        "root.profileFanControlReady",
        "enabled: ThinkFanService.directControlAvailable && !root.thinkFanManaged",
    ):
        check(forbidden not in system_settings,
              f"Fan preferences must persist independently of runtime helper readiness: {forbidden}")

    for token in (
        "function flushWrites(): void",
        "if (root._writeInFlight) {",
        "root._pendingWrite = true",
        "root._writeMirrorToDisk()",
    ):
        check(token in config_schema,
              f"Explicit Config flushes must serialize safely before fan apply: {token}")

    check("property var _thinkFanService: ThinkFanService" in shell_root,
          "Shell root must keep ThinkFanService alive so power-profile following works with Settings closed")

    for token in (
        'value.includes("fan")',
        'root.activeSection = "fan"',
    ):
        check(token in system_facade,
              f"System Settings search must route Fan Control correctly: {token}")

    for token in (
        'section: Translation.tr("Fan Control")',
        'keywords: ["fan", "fan control", "thinkfan", "thermal", "cooling", "rpm", "temperature", "system"]',
    ):
        check(token in settings_registry,
              f"Settings search index must expose System Fan Control: {token}")

    for forbidden in (
        'settingsTaskSection: "system"',
        'title: Translation.tr("Fan Control")',
        'text: Translation.tr("ThinkFan managed control")',
    ):
        check(forbidden not in bar_settings,
              f"Bar Settings must not own Fan Control anymore: {forbidden}")

    for forbidden in (
        '{ displayName: Translation.tr("System"), icon: "tune", value: "system" }',
        '"fan control": "system"',
    ):
        check(forbidden not in bar_config,
              f"Bar navigation must not expose the removed pseudo-System task: {forbidden}")

    check(not (ROOT / "modules/perimeter").exists(),
          "Retired broad perimeter module must stay absent")
    for path in (
        "modules/perimeter/ThinkFanModule.qml",
        "modules/perimeter/ThinkFanConnectedSurface.qml",
        "modules/perimeter/ThinkFanPopupContent.qml",
    ):
        check(not (ROOT / path).exists(),
              f"Retired standalone ThinkFan surface must stay removed: {path}")

    for token in (
        "function setup_thinkfan_helper()",
        'helper_src="${REPO_ROOT}/assets/helpers/inir-thinkfan"',
        'policy_src="${REPO_ROOT}/assets/polkit/org.inir.thinkfan.policy"',
        'helper_dst="/usr/libexec/inir-thinkfan"',
        'policy_dst="/usr/share/polkit-1/actions/org.inir.thinkfan.policy"',
        'pkg_sudo install -Dm755 "$helper_src" "$helper_dst"',
        'pkg_sudo install -Dm644 "$policy_src" "$policy_dst"',
        "showfun setup_thinkfan_helper",
        "v setup_thinkfan_helper",
    ):
        check(token in source_setup,
              f"Repo-managed setup must provision the Hadalis ThinkFan bridge: {token}")

    check('update_strategy" == "package-manager"' in source_setup,
          "Source setup must not overwrite package-manager-owned ThinkFan integration files")

    for token in (
        'MIGRATION_ID="041-thinkfan-helper-bridge"',
        "MIGRATION_REQUIRED=true",
        'get_installed_update_strategy 2>/dev/null || true',
        '== "package-manager"',
        'helper_src="${REPO_ROOT}/assets/helpers/inir-thinkfan"',
        'policy_src="${REPO_ROOT}/assets/polkit/org.inir.thinkfan.policy"',
        'helper_dst="/usr/libexec/inir-thinkfan"',
        'policy_dst="/usr/share/polkit-1/actions/org.inir.thinkfan.policy"',
        'cmp -s "$helper_src" "$helper_dst"',
        'cmp -s "$policy_src" "$policy_dst"',
        'pkg_sudo install -Dm755 "$helper_src" "$helper_dst"',
        'pkg_sudo install -Dm644 "$policy_src" "$policy_dst"',
    ):
        check(token in thinkfan_migration,
              f"Required migration must self-heal the Hadalis ThinkFan bridge: {token}")

    for forbidden in (
        "systemctl stop thinkfan",
        "systemctl disable thinkfan",
        "systemctl disable --now thinkfan",
        "pacman -R",
        "dnf remove thinkfan",
        "apt remove thinkfan",
        "rm -f /etc/thinkfan",
        "rm -rf /etc/thinkfan",
    ):
        check(forbidden not in thinkfan_migration,
              f"ThinkFan bridge migration must preserve upstream ThinkFan ownership: {forbidden}")

    for token in (
        "uninstall_remove_thinkfan_bridge()",
        'helper="/usr/libexec/inir-thinkfan"',
        'policy="/usr/share/polkit-1/actions/org.inir.thinkfan.policy"',
        "get_installed_update_strategy 2>/dev/null || true",
        '[[ "$update_strategy" == "package-manager" ]]',
        'pkg_sudo rm -f "$helper" "$policy"',
        "upstream ThinkFan preserved",
    ):
        check(token in uninstall_lib,
              f"Repo uninstall must remove only the Hadalis-owned ThinkFan bridge: {token}")
    check(uninstall_lib.count("uninstall_remove_thinkfan_bridge") >= 3,
          "Both normal and quick repo uninstall paths must clean the Hadalis ThinkFan bridge")

    for forbidden in (
        "systemctl stop thinkfan",
        "systemctl disable thinkfan",
        "systemctl disable --now thinkfan",
        "pacman -R thinkfan",
        "dnf remove thinkfan",
        "apt remove thinkfan",
        "rm -f /etc/thinkfan",
        "rm -rf /etc/thinkfan",
    ):
        check(forbidden not in uninstall_lib,
              f"Repo uninstall must preserve upstream ThinkFan ownership: {forbidden}")

    check("run_migrations_auto" in setup_entrypoint,
          "Repo update path must run required migrations after pulling source changes")
    check('apply_migration "$migration_id" true' in migration_engine,
          "Required migrations must re-apply from real state when a managed artifact is missing/outdated")
    check("sudo make install-thinkfan-helper" in thinkfan_docs,
          "ThinkFan troubleshooting must document the targeted helper repair path")

    if failures:
        print("ThinkFan/System Monitor contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("ThinkFan/System Monitor contract: OK")


if __name__ == "__main__":
    main()
