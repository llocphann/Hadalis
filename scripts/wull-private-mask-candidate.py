#!/usr/bin/env python3
"""Source-guarded PRIVATE four-edge Wull BBOX hit-mask candidate.

This module never edits production. Only the explicitly opted-in owned nested
pointer child may stage this QML copy outside the checkout. The candidate is
a RECTANGLE around the source-measured production body (76x92 horizontal,
92x76 vertical) at size=1, not its curved silhouette or an approved
production implementation. Right/left/bottom require NEW physical tests.
"""
from pathlib import Path

INPUT_MARKER = (
    "Region { item: WullHostPolicy.acceptsInput("
    "window.companionHostActive, companion.interactive, companion.visible)"
    " ? companion : emptyInput }"
)
BODY_WIDTH = 76
BODY_HEIGHT = 92
CANDIDATE = """// PRIVATE_NESTED_WULL_CANDIDATE_MASK: four-edge BBOX, scale=1.
                Region {
                    readonly property bool verticalCandidate:
                        root.companionEdge === "left"
                        || root.companionEdge === "right"
                    readonly property real bodyBBoxWidth:
                        verticalCandidate ? 92 : 76
                    readonly property real bodyBBoxHeight:
                        verticalCandidate ? 76 : 92
                    readonly property bool candidateActive:
                        WullHostPolicy.acceptsInput(
                            window.companionHostActive, companion.interactive,
                            companion.visible)
                        && ["top", "bottom", "left", "right"].includes(
                            root.companionEdge)
                        && root.companionScale === 1
                    x: companion.x + (companion.implicitWidth - bodyBBoxWidth) / 2
                    y: companion.y + (companion.implicitHeight - bodyBBoxHeight) / 2
                    width: candidateActive ? bodyBBoxWidth : 0
                    height: candidateActive ? bodyBBoxHeight : 0
                }"""


def candidate_source(perimeter: str, body: str) -> str:
    """Only replace the exact reviewed full-companion input-mask Region."""
    if not isinstance(perimeter, str) or not isinstance(body, str):
        raise ValueError("invalid_candidate_source")
    if perimeter.count(INPUT_MARKER) != 1:
        raise ValueError("unreviewed_production_mask_or_multiple_regions")
    # These are intentional constraints on the static first physical probe.
    for item in ('implicitWidth: verticalEdge ? 98 : 112',
                 'implicitHeight: verticalEdge ? 112 : 98',
                 'width: 76; height: 92', 'anchors.centerIn: parent',
                 'transformOrigin: Item.Center',
                 'orientationAngle: root.edge === "left" ? 90',
                 'enabled: root.interactive', 'onPressed: root.activated()'):
        if item not in body:
            raise ValueError("unreviewed_centered_top_body")
    if 'onActivated: companionBridge.sendEvent("click")' not in perimeter:
        raise ValueError("production_bridge_contract_changed")
    return perimeter.replace(INPUT_MARKER, CANDIDATE, 1)


def stage_candidate_modules(checkout: Path, shell: Path) -> Path:
    """Construct a PRIVATE module shadow tree with ONE substituted QML file.

    All module dependencies keep their exact checkout paths. Refuse to write
    within the repository, replace an existing tree, or follow a shell symlink.
    The caller MUST verify the owned nested Wayland/Niri identities first.
    """
    checkout = Path(checkout).resolve(strict=True)
    shell = Path(shell)
    if not shell.is_dir() or shell.is_symlink():
        raise ValueError("private_candidate_shell_unavailable")
    private = shell.resolve()
    if private == checkout or checkout in private.parents:
        raise ValueError("candidate_shell_inside_checkout")
    modules = checkout / "modules"
    abyss = modules / "abyss"
    if not (modules.is_dir() and abyss.is_dir()):
        raise ValueError("production_module_tree_unavailable")
    generated = candidate_source(
        (abyss / "AbyssPerimeter.qml").read_text(encoding="utf-8"),
        (abyss / "companion/AbyssCompanion.qml").read_text(encoding="utf-8"))
    shadow = shell / "modules"
    if shadow.exists() or shadow.is_symlink():
        raise ValueError("candidate_module_shadow_already_exists")
    shadow.mkdir(mode=0o700)
    for item in modules.iterdir():
        if item.name == "abyss":
            continue
        (shadow / item.name).symlink_to(item)
    abyss_shadow = shadow / "abyss"
    abyss_shadow.mkdir(mode=0o700)
    for item in abyss.iterdir():
        if item.name == "AbyssPerimeter.qml":
            continue
        (abyss_shadow / item.name).symlink_to(item)
    target = abyss_shadow / "AbyssPerimeter.qml"
    target.write_text(generated, encoding="utf-8")
    target.chmod(0o600)
    return target


if __name__ == "__main__":
    raise SystemExit("test_only_module_no_direct_execution")
