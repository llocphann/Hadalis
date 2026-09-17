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
    bar_settings = read("modules/settings/BarConfigHugOnly.qml")
    source_setup = read("sdata/subcmd-install/2.setups.sh")
    thinkfan_docs = read("docs/THINKFAN.md")

    for token in (
        "ThinkFanService.refresh()",
        "ThinkFanService.applyProfile(",
        'Translation.tr("ThinkFan")',
        'Translation.tr("Fan speed")',
        'Translation.tr("Fan level")',
        'Translation.tr("Service")',
        "thinkFanCanApply",
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

    for token in (
        'title: Translation.tr("System Monitor & Thermals")',
        'text: Translation.tr("ThinkFan managed control")',
        "ThinkFanService.applyProfile(",
        "checked: root.thinkFanManaged",
    ):
        check(token in bar_settings,
              f"Bar Settings must expose the shared ThinkFan profile control: {token}")

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
