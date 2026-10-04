#!/usr/bin/env bash
# Qualify actual Clipboard retraction without swapping in Overview/Dashboard.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss clipboard lifecycle (Quickshell/Wayland unavailable)\n'
    exit 0
fi
clipboard_test_root="$(mktemp -d)"
trap 'rm -rf -- "$clipboard_test_root"' EXIT
python3 - "$repo_root" "$clipboard_test_root" <<'PYSETUP'
from pathlib import Path
import re,shutil,sys
repo,base=map(Path,sys.argv[1:])
(base/'modules').mkdir()
for entry in (repo/'modules').iterdir():
    if entry.name=='abyss': shutil.copytree(entry,base/'modules'/entry.name)
    else: (base/'modules'/entry.name).symlink_to(entry)
for name in ['services','GlobalStates.qml','qmldir','assets','scripts','defaults','translations']: (base/name).symlink_to(repo/name)
p=base/'modules/abyss/AbyssPerimeter.qml';s=p.read_text()
variants_id=re.search(r'\bVariants\s*\{\s*id:\s*(\w+)',s).group(1)
s=s.replace('id: root\n',f'id: root\n    readonly property var qaWindows: {variants_id}.instances\n',1)
clipboard='clipboardBody' if 'id: clipboardBody' in s else 'aux'
s=s.replace('id: window\n','id: window\n            property alias qaClipboard: '+clipboard+'\n            property alias qaOverview: aux\n            property alias qaField: field\n',1)
p.write_text(s)
(base/'config/illogical-impulse').mkdir(parents=True)
shutil.copy2(repo/'defaults/config.json',base/'config/illogical-impulse/config.json')
PYSETUP
cat > "$clipboard_test_root/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
ShellRoot {
    id:root
    property int step:0
    property bool failed:false
    property string clipboardSource:""
    function check(ok,message) { if(ok) return true; console.error("CLIPBOARD_REFINE_FAIL",message);failed=true;Qt.quit();return false }
    AbyssPerimeter { id:perimeter }
    Timer {
        interval:400;running:!root.failed;repeat:true
        onTriggered: {
            if(!Config.ready || !perimeter.qaWindows.length) return
            const output=perimeter.qaWindows[0],clip=output.qaClipboard,overview=output.qaOverview
            if(!output.qaField.ready) return
            if(root.step===0) {
                Config.setNestedValue("panelFamily","abyss")
                Config.setNestedValue("performance.reduceAnimations",false)
                Config.setNestedValue("enabledPanels",["abyssPerimeter","abyssClipboard","abyssOverview","iiDashboard"])
                GlobalStates.shellEntryReady=true;GlobalStates.deferredPanelsReady=true
                GlobalStates.dashboardOpen=false;GlobalStates.clipboardOpen=true
            } else if(root.step===1) {
                if(!root.check(clip.open && clip.ready && !overview.ready && !GlobalStates.dashboardOpen,"only Clipboard content is loaded")) return
                root.clipboardSource=String(clip.contentItem.source)
                GlobalStates.clipboardOpen=false
                if(!root.check(clip.progress>0 && String(clip.contentItem.source)===root.clipboardSource && !overview.ready && !GlobalStates.dashboardOpen,"closing retains Clipboard while retracting without opening Dashboard")) return
            } else if(root.step===3) {
                if(!root.check(!clip.ready && !overview.ready && !GlobalStates.dashboardOpen,"closed Clipboard unloads with Dashboard unchanged")) return
                GlobalStates.dashboardOpen=true;GlobalStates.clipboardOpen=true
            } else if(root.step===4) {
                if(!root.check(clip.ready && !overview.ready && GlobalStates.dashboardOpen,"Clipboard leaves an already-open Dashboard flag intact")) return
                GlobalStates.clipboardOpen=false
                if(!root.check(String(clip.contentItem.source)===root.clipboardSource && !overview.ready && GlobalStates.dashboardOpen,"retraction preserves the already-open Dashboard")) return
            } else if(root.step===6) {
                if(!root.check(!clip.ready && !overview.ready && GlobalStates.dashboardOpen,"repeated close keeps prior Dashboard state")) return
                GlobalStates.dashboardOpen=false
                console.info("CLIPBOARD_REFINE_PASS");Qt.quit()
            }
            root.step++
        }
    }
}
QML
if ! dbus-run-session -- env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland \
 XDG_CONFIG_HOME="$clipboard_test_root/config" XDG_STATE_HOME="$clipboard_test_root/state" \
 XDG_CACHE_HOME="$clipboard_test_root/cache" timeout 25s qs -p "$clipboard_test_root" --no-color \
 > "$clipboard_test_root/runtime.log" 2>&1; then
    cat "$clipboard_test_root/runtime.log"; exit 1
fi
if ! rg -q CLIPBOARD_REFINE_PASS "$clipboard_test_root/runtime.log" || \
 rg -q 'CLIPBOARD_REFINE_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type|Failed to load configuration' "$clipboard_test_root/runtime.log"; then
    cat "$clipboard_test_root/runtime.log"; exit 1
fi
printf 'PASS: Clipboard retains its content while retracting, unloads, and preserves closed/open Dashboard state\n'
