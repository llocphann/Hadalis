#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
content=(r/"modules/abyss/content/AbyssPopupContent.qml").read_text()

assert 'property string kind: ""' in content
assert ': root.kind === "media" ? media' in content
assert ': null' in content
assert 'property string latchedContentKind: ""' in per
assert 'contentKind: latchedContentKind' in per
assert 'GlobalStates.mediaControlsOpen ? "media" : ""' in per
assert 'GlobalStates.abyssPopupKind || "media"' not in per
assert 'if (expected === "media")' in per
assert 'GlobalStates.mediaControlsOpen = false' in per
print("Abyss popup Media-flash regression contract: ok")
