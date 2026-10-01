#!/usr/bin/env python3
"""Waffle standalone Cloud Storage integration contract, no runtime actions."""
from pathlib import Path
base = Path(__file__).resolve().parents[1]
waffle = (base / "waffleSettings.qml").read_text()
content = (base / "modules/waffle/settings/WSettingsContent.qml").read_text()
page = (base / "modules/waffle/settings/pages/WCloudStoragePage.qml").read_text()
service = (base / "services/deferred/CloudStorageService.qml").read_text()
assert 'key: "cloud-storage"' in waffle
assert 'component: Qt.resolvedUrl("modules/waffle/settings/pages/WCloudStoragePage.qml")' in waffle
assert 'keys: ["ai", "mascot", "cloud-storage"]' in content
assert 'settingsPageIndex: 19' in page and 'pageIndex: 19' in content
assert 'activateSettingsSearchSection' in page and 'applyPendingCloudSection' in content
assert 'onLoaded: if (index === 19)' in content
for section in ("overview","drive","transfers","sync","backups",
                "sharing","contacts","mounts","security","preferences"):
    assert f'key:"{section}"' in page, section
    assert f'pageIndex: 19, pageName: "Cloud Storage", section: "{section}"' in content, section
assert 'CloudStorageService.registerConsumer()' in page
assert 'CloudStorageService.unregisterConsumer()' in page
assert 'CloudStorageService.refreshStatic()' in page
for executable in ("mega-login:", "mega-whoami:", "mega-version:"):
    assert executable in page
assert 'readonly property bool connected: false' in service
for forbidden in ('auth_begin', 'secret:', 'mutationProc'):
    assert forbidden not in page
print("PASS MegaQML Waffle standalone source integration")
