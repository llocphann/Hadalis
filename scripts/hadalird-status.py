#!/usr/bin/env python3
"""Finite, read-only discovery of a committed optional integration package."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ENTRYPOINTS = {
    "session": "HadalisSession.qml",
    "thinkfanSettings": "modules/settings/ThinkfanSettings.qml",
    "tlpSettings": "modules/settings/TlpPowerSettings.qml",
    "obsidianSettings": "modules/settings/ObsidianThemeSettings.qml",
    "obsidianTodoSettings": "modules/settings/ObsidianTodoSettings.qml",
    "tlpRowSettings": "modules/settings/TlpSettingRow.qml",
    "tlpWaffleSettings": "modules/waffle/settings/WTlpPowerSettings.qml",
    "tlpWaffleRowSettings": "modules/waffle/settings/WTlpSettingRow.qml",
    "managedTodo": "services/ObsidianTodoBackend.qml",
    "dailyTodo": "services/DailyNoteTodoBackend.qml",
}


def inspect(shell_root, data_home=None):
    package = Path(shell_root) / "optional/hadalird"
    if not package.exists():
        package = Path(data_home or os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "hadalird/current"
    result = {"available": False, "diagnostic": "not-installed"}
    try:
        manifest = package / "manifest.json"
        if not manifest.is_file():
            return result
        if manifest.stat().st_size > 65536:
            raise ValueError("oversized manifest")
        data = json.loads(manifest.read_text())
        if not isinstance(data, dict):
            raise ValueError("manifest must be an object")
        if data.get("id") != "hadalird" or type(data.get("hostApi")) is not int or data["hostApi"] != 1:
            return {**result, "diagnostic": "incompatible-package"}
        settings, backends = data.get("settings", {}), data.get("backends", {})
        if not isinstance(settings, dict) or not isinstance(backends, dict):
            raise ValueError("invalid entrypoints")
        entries = {"session": data.get("session"), "tlpSettings": settings.get("tlp"), "thinkfanSettings": settings.get("thinkfan"),
                   "obsidianSettings": settings.get("obsidian"),
                   "obsidianTodoSettings": settings.get("obsidianTodo"), "tlpRowSettings": settings.get("tlpRow"),
                   "tlpWaffleSettings": settings.get("tlpWaffle"), "tlpWaffleRowSettings": settings.get("tlpWaffleRow"),
                   "managedTodo": backends.get("managedTodo"),
                   "dailyTodo": backends.get("dailyTodo")}
        if entries != ENTRYPOINTS:
            raise ValueError("unexpected entrypoints")
        root = package.resolve()
        hashes = data.get("files")
        if not isinstance(hashes, dict) or not hashes or len(hashes) > 512:
            raise ValueError("missing payload identity")
        if not all(name in hashes for name in ENTRYPOINTS.values()):
            raise ValueError("incomplete package")
        for name, digest in hashes.items():
            if not isinstance(name, str) or not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError("invalid payload identity")
            path = root / name
            if not path.resolve().is_relative_to(root) or not path.is_file():
                raise ValueError("invalid payload path")
            if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise ValueError("modified payload")
        version, sha = data.get("version"), data.get("sourceSha")
        if not isinstance(version, str) or not version or len(version) > 64 or not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{40}", sha):
            raise ValueError("invalid revision")
        return {"available": True, "diagnostic": "ready", "root": str(root), "version": version, "sourceSha": sha}
    except (OSError, ValueError, TypeError):
        return {**result, "diagnostic": "invalid-package"}


if __name__ == "__main__":
    print(json.dumps(inspect(sys.argv[1] if len(sys.argv) == 2 else Path(__file__).resolve().parents[1])))
