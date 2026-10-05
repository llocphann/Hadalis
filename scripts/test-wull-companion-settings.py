#!/usr/bin/env python3
"""English Companion settings, typed defaults and live preference dispatch."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
subprocess.run(["node", str(ROOT / "scripts/test-wull-preferences.cjs")], check=True)
page = (ROOT / "modules/settings/CompanionConfig.qml").read_text()
catalog = json.loads((ROOT / "translations/en_US.json").read_text())
for label in re.findall(r'Translation\.tr\("([^"\n]*)"\)', page):
    assert label in catalog, f"unshipped English label: {label}"
    assert catalog[label] == label, f"English label changed: {label}"
assert "CompanionBridge {" not in page, "settings preview must not start another daemon"
assert "WaterDropletBody {" in page, "preview must use the real material and geometry"
schema = (ROOT / "modules/common/Config.qml").read_text().split(
    "property JsonObject companion: JsonObject {", 1)[1].split("}", 1)[0]
defaults = json.loads((ROOT / "defaults/config.json").read_text())["abyss"]["companion"]
properties = {key: json.loads(value) for key, value in re.findall(
    r'property (?:bool|string|real) (\w+): ([^\n]+)', schema)}
assert properties == defaults, "typed persistence and shipped defaults must agree"
mind_schema = (ROOT / "modules/common/Config.qml").read_text().split(
    "property JsonObject companionMind: JsonObject {", 1)[1].split("}", 1)[0]
mind_defaults = json.loads((ROOT / "defaults/config.json").read_text())["abyss"]["companionMind"]
mind_properties = {key: json.loads(value) for key, value in re.findall(
    r'property (?:bool|string|real) (\w+): ([^\n]+)', mind_schema)}
assert mind_properties == mind_defaults, "Wull mind typed persistence and shipped defaults must agree"
assert mind_defaults["thinkingEffort"] == "off"
subprocess.run(["python3", str(ROOT / "scripts/test-settings-information-architecture.py")], check=True)
print("WULL_COMPANION_SETTINGS_DEFAULTS_ENGLISH_AND_ROUTING_PASS")
