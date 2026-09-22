#!/usr/bin/env python3
"""Fcitx5 Keyboard Settings regression: status, config safety and UI wiring."""

import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/input-method/fcitx5-settings.py"
QML = ROOT / "modules/settings/FcitxInputSettings.qml"
NIRI = ROOT / "modules/settings/NiriConfig.qml"
REGISTRY = ROOT / "modules/settings/SettingsPageRegistryData.qml"


def load_bridge():
    spec = importlib.util.spec_from_file_location("hadalis_fcitx_settings", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FcitxSettingsTest(unittest.TestCase):
    def setUp(self):
        self.sandbox = tempfile.TemporaryDirectory()
        self.addCleanup(self.sandbox.cleanup)
        self.home = Path(self.sandbox.name)
        self.bridge = load_bridge()
        self.bridge.FCITX_HOME = self.home / "fcitx5"
        self.bridge.PROFILE = self.bridge.FCITX_HOME / "profile"
        self.bridge.UNIKEY = self.bridge.FCITX_HOME / "conf" / "unikey.conf"
        self.bridge.ENGINE = self.home / "installed" / "unikey.conf"
        self.bridge.ENGINE.parent.mkdir(parents=True)
        self.bridge.ENGINE.write_text("[InputMethod]\nName=Unikey\n", encoding="utf-8")

    def test_status_reads_real_configuration_without_creating_files(self):
        bridge = self.bridge
        bridge.PROFILE.parent.mkdir(parents=True)
        bridge.PROFILE.write_text(
            "[Groups/0]\nName=Default\n[Groups/0/Items/0]\nName=keyboard-us\n"
            "[Groups/0/Items/1]\nName=unikey\n", encoding="utf-8")
        bridge.UNIKEY.parent.mkdir(parents=True)
        bridge.UNIKEY.write_text(
            "# user preferences\n[Config]\nInputMethod=1\nOutputCharset=0\nMacro=True\n",
            encoding="utf-8")
        with patch.object(bridge.shutil, "which", side_effect=lambda key: "/usr/bin/" + key), \
             patch.object(bridge, "remote", side_effect=[
                 subprocess.CompletedProcess([], 0, "2\n", ""),
                 subprocess.CompletedProcess([], 0, "unikey\n", ""),
             ]):
            result = bridge.snapshot()
        self.assertEqual(result["method"], "1")
        self.assertEqual(result["charset"], "0")
        self.assertEqual(result["current"], "unikey")
        self.assertTrue(result["unikeyConfigured"])
        self.assertTrue(result["running"])
        self.assertTrue(result["engineInstalled"])
        self.assertEqual(len(list(self.home.rglob("*.tmp"))), 0)

    def test_change_typing_method_preserves_unrelated_settings(self):
        bridge = self.bridge
        bridge.UNIKEY.parent.mkdir(parents=True)
        bridge.UNIKEY.write_text(
            "# own comment\n[Config]\nInputMethod=0\nMacro=True\nModernStyle=False\n"
            "[AnotherAddon]\nSetting=value\n", encoding="utf-8")
        bridge.UNIKEY.chmod(0o600)
        bridge.update_unikey_option("InputMethod", "1")
        result = bridge.UNIKEY.read_text(encoding="utf-8")
        self.assertIn("# own comment\n", result)
        self.assertIn("[Config]\nInputMethod=1\n", result)
        self.assertIn("Macro=True\nModernStyle=False\n", result)
        self.assertIn("[AnotherAddon]\nSetting=value\n", result)
        self.assertNotIn("InputMethod=0", result)
        self.assertEqual(bridge.UNIKEY.stat().st_mode & 0o777, 0o600)

    def test_add_option_only_to_config_section(self):
        bridge = self.bridge
        bridge.UNIKEY.parent.mkdir(parents=True)
        bridge.UNIKEY.write_text("[Other]\nKeep=yes\n[Config]\nMacro=True\n", encoding="utf-8")
        bridge.update_unikey_option("OutputCharset", "0")
        result = bridge.UNIKEY.read_text()
        self.assertIn("[Config]\nOutputCharset=0\nMacro=True\n", result)
        self.assertIn("[Other]\nKeep=yes\n", result)

    def test_explicit_add_unikey_is_additive_and_idempotent(self):
        bridge = self.bridge
        bridge.PROFILE.parent.mkdir(parents=True)
        original = ("[Groups/0]\nName=Personal\nDefaultIM=keyboard-us\n"
                    "[Groups/0/Items/0]\nName=keyboard-us\nLayout=\n"
                    "[GroupOrder]\n0=Default\n")
        bridge.PROFILE.write_text(original, encoding="utf-8")
        with patch.object(bridge, "state", return_value=0):
            bridge.add_unikey()
            bridge.add_unikey()
        result = bridge.PROFILE.read_text()
        self.assertTrue(result.startswith(original.rstrip("\n")))
        self.assertEqual(result.count("Name=unikey"), 1)
        self.assertIn("[Groups/0/Items/1]\nName=unikey\nLayout=", result)

    def test_custom_profile_not_rewritten(self):
        bridge = self.bridge
        bridge.PROFILE.parent.mkdir(parents=True)
        bridge.PROFILE.write_text("[Custom]\nOwn=1\n", encoding="utf-8")
        with self.assertRaisesRegex(bridge.InputMethodError, "Advanced Settings"):
            bridge.add_unikey()
        self.assertEqual(bridge.PROFILE.read_text(), "[Custom]\nOwn=1\n")

    def test_reload_uses_documented_dbus_method_without_daemon_restart(self):
        bridge = self.bridge
        calls = []
        def fake_command(*args):
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, "", "")
        with patch.object(bridge, "state", return_value=2), \
             patch.object(bridge.shutil, "which", return_value="/usr/bin/busctl"), \
             patch.object(bridge, "command", side_effect=fake_command):
            self.assertEqual(bridge.reload_config("unikey"), "")
        self.assertEqual(
            calls, [("busctl", "--user", "call", "org.fcitx.Fcitx5", "/controller",
                     "org.fcitx.Fcitx.Controller1", "ReloadAddonConfig", "s", "unikey")])

    def test_invalid_values_do_not_write_settings(self):
        bridge = self.bridge
        for action, value in [("set-method", "23"), ("set-charset", "1"),
                              ("set-language", "other")]:
            with patch.object(sys, "argv", [str(SCRIPT), action, value]), \
                 patch.object(bridge, "snapshot", return_value={}), \
                 contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(bridge.main(), 1)
                self.assertIn('"ok": false', output.getvalue())
        self.assertFalse(bridge.UNIKEY.exists())

    def test_text_bindings_import_translation_singleton(self):
        # Regression: missing qs.services left all text/labels blank while icons,
        # backgrounds and controls still appeared in Keyboard Settings.
        controls = QML.read_text(encoding="utf-8")
        translation = (ROOT / "services/Translation.qml").read_text(encoding="utf-8")
        qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")
        self.assertIn("Translation.tr(", controls)
        self.assertIn("import qs.services\n", controls)
        self.assertIn("singleton Translation 1.0 Translation.qml", qmldir)
        self.assertIn("function tr(text)", translation)
        for label in ('"Refresh"', '"English"', '"Vietnamese"',
                      '"Telex"', '"VNI"', '"Advanced Fcitx5 settings"'):
            self.assertIn("Translation.tr(" + label + ")", controls)

    def test_qml_wiring_and_search(self):
        page = NIRI.read_text(encoding="utf-8")
        controls = QML.read_text(encoding="utf-8")
        registry = REGISTRY.read_text(encoding="utf-8")
        keyboard = page.index('title: Translation.tr("Keyboard")')
        input_method = page.index('FcitxInputSettings {', keyboard)
        touchpad = page.index('title: Translation.tr("Touchpad")', keyboard)
        self.assertLess(keyboard, input_method)
        self.assertLess(input_method, touchpad)
        for signal in ('"status"', '"set-language"', '"set-method"',
                       '"set-charset"', '"add-unikey"'):
            self.assertIn(signal, controls)
        for keyword in ('"fcitx5"', '"telex"', '"vni"', '"unicode"'):
            self.assertIn(keyword, registry)
        self.assertIn('ShellExec.execDetachedArgs(["fcitx5-configtool"]', controls)


if __name__ == "__main__":
    unittest.main(verbosity=2)
