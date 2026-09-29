#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
confirm=(r/"modules/abyss/AbyssConfirmationPresenter.qml").read_text()
legacy=(r/"services/PolkitService.qml").read_text()
legacy_host=(r/"modules/polkit/Polkit.qml").read_text()
critical=(r/"modules/abyss/critical/ShellAbyssCriticalPanels.qml").read_text()
deferred=(r/"modules/abyss/ShellAbyssPanelsImpl.qml").read_text()
assert not (r/"modules/abyss/AbyssPolkitPresenter.qml").exists()
assert not (r/"modules/abyss/content/AbyssPolkitContent.qml").exists()
assert "AbyssPolkitPresenter" not in per
assert "PolkitService." not in confirm
for token in ("PopupAnchorRegistry","AbyssPromptHostRegistry","targetOutputName","resolvedAnchor",
              "presentationRetained","abyssPresenterAvailable","abyssPresentationSuppressed",
              "hintSource","requestSerial"):
    assert token not in legacy
assert 'source: "../../polkit/Polkit.qml"' not in critical
assert 'source: "../polkit/Polkit.qml"' in deferred
assert "PolkitService.available && PolkitService.active" in legacy_host
print("Confirmation/legacy-Polkit separation contract: ok")
