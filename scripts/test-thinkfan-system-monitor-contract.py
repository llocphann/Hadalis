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
    styled_popup = read("modules/bar/StyledPopup.qml")
    system_settings = read("modules/settings/GeneralConfigCore.qml")
    system_facade = read("modules/settings/GeneralConfig.qml")
    settings_registry = read("modules/settings/SettingsPageRegistryData.qml")
    bar_settings = read("modules/settings/BarConfigHugOnly.qml")
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
        'Translation.tr("ThinkFan")',
        'Translation.tr("Fan speed")',
        'Translation.tr("Fan level")',
        "thinkFanCanApply",
        "connectAdjacentScreenEdge: true",
        "font.pixelSize: Appearance.font.pixelSize.normal",
        "thinkFanApplyErrorMessage",
    ):
        check(token in resources_popup,
              f"System Monitor popup must own ThinkFan runtime UI: {token}")

    for forbidden in (
        "ThinkFanConnectedSurface",
        "SurfaceRouteController",
        "AnchorPublisher",
        'surface: "thinkfan"',
    ):
        check(forbidden not in resources_popup,
              f"System Monitor ThinkFan UI must not revive a standalone popup route: {forbidden}")

    for forbidden in (
        'Translation.tr("Free:")',
        'Translation.tr("Service")',
        "thinkFanStatusMessage",
        "describeThinkFanStatus",
    ):
        check(forbidden not in resources_popup,
              f"System Monitor popup must keep the compact metrics contract: {forbidden}")

    for token in (
        "property bool connectAdjacentScreenEdge: false",
        "id: adjacentScreenEdgeGeometry",
        "screenMargin: root._popupScreenMargin",
        "ConnectedSurfaceConnector {",
    ):
        check(token in styled_popup,
              f"StyledPopup must support the opt-in adjacent Screen Edge join: {token}")

    for token in (
        'settingsTaskSection: "fan"',
        'title: Translation.tr("Fan Control")',
        'text: Translation.tr("ThinkFan managed control")',
        "ThinkFanService.applyProfile(",
        "checked: root.thinkFanManaged",
        '{ displayName: Translation.tr("Fan Control"), icon: "mode_fan", value: "fan" }',
    ):
        check(token in system_settings,
              f"System Settings must own the shared ThinkFan profile control: {token}")

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
