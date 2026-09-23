#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CENTER = (ROOT / "modules/notificationCenter/NotificationCenterContent.qml").read_text(encoding="utf-8")
LIST = (ROOT / "modules/common/widgets/NotificationListView.qml").read_text(encoding="utf-8")
GROUP = (ROOT / "modules/common/widgets/NotificationGroup.qml").read_text(encoding="utf-8")
ITEM = (ROOT / "modules/common/widgets/NotificationItem.qml").read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"FAIL: {message}: {token}")


# The standalone history center should reveal content while canvas is available;
# overflow is handled by its scroll viewport rather than pre-collapsing every
# notification group into a tiny strip.
require(CENTER, "preferExpanded: true", "history center must prefer full cards")
require(CENTER, "modernCards: true", "history center must opt into modern cards")
require(LIST, "property bool preferExpanded: false", "shared list expansion knob missing")
require(LIST, "expandedByDefault: root.preferExpanded", "list must forward expansion policy")
require(GROUP, "property bool expanded: expandedByDefault", "group must honor expansion policy")

# Modern center cards use the whole group width: the old 38px leading icon is
# hidden and a compact icon moves into the header, so nested notification cards
# no longer inherit a permanent empty left gutter.
require(GROUP, "visible: !root.modernLayout", "legacy leading icon must leave modern layout")
require(GROUP, "id: modernHeaderIcon", "modern header icon missing")
require(GROUP, "modernLayout: root.modernCards", "modern card mode must reach group delegates")
require(GROUP, "modernLayout: root.modernLayout", "modern card mode must reach notification items")

# Body text should use the foreground token in modern history cards rather than
# the deliberately faint generic subtext token.
require(ITEM, "? Appearance.colors.colOnLayer3", "modern notification body contrast is too weak")

# The large two-column action footer from the old sidebar should become compact
# trailing actions in the standalone center.
require(ITEM, "implicitWidth: root.modernLayout ? 34", "compact action geometry missing")
require(ITEM, "visible: root.modernLayout", "modern action spacer/alignment missing")

print("PASS: notification center history cards use expanded, readable modern layout")
