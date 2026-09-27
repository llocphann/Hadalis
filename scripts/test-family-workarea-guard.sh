#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null; then
    printf 'SKIP: family work-area guard (Quickshell unavailable)\n'
    exit 0
fi
guard_test_root="$(mktemp -d)"
trap 'rm -rf -- "$guard_test_root"' EXIT
# Execute the production controller; native PanelWindow geometry is qualified
# separately in nested Niri because the offscreen plugin has no layer backend.
python3 - "$repo_root" "$guard_test_root" <<'PY'
from pathlib import Path
import sys
source = (Path(sys.argv[1])/'FamilyWorkAreaGuard.qml').read_text()
(Path(sys.argv[2])/'Controller.qml').write_text(source.split('    Variants {',1)[0]+'}\n')
PY
cat > "$guard_test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-workarea-guard-test
import QtQuick
import Quickshell
ShellRoot {
    id: harness
    property int step: 0
    function check(value, message): bool {
        if (value) return true
        console.error("GUARD_FAIL",message); Qt.quit(); return false
    }
    Loader { id: guard; source: "Controller.qml" }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            if (harness.step === 0) {
                if (!harness.check(guard.item && !guard.item.retained,"initial idle")) return
                guard.item.guarded = true
                if (!harness.check(guard.item.retained,"immediate reservation")) return
            } else if (harness.step === 1) {
                guard.item.guarded = false
                if (!harness.check(guard.item.retained,"retain through compositor commits")) return
            } else if (harness.step === 2) guard.item.guarded = true
            else if (harness.step === 6) {
                if (!harness.check(guard.item.retained,"cancel stale release")) return
                guard.item.guarded = false
            } else if (harness.step === 10) {
                if (!harness.check(!guard.item.retained,"return exclusive zone to zero")) return
                console.info("GUARD_PASS"); Qt.quit()
            }
            harness.step++
        }
    }
}
QML
QT_QPA_PLATFORM=offscreen timeout 5s qs -p "$guard_test_root" --no-color > "$guard_test_root/runtime.log" 2>&1
if ! rg -q 'GUARD_PASS' "$guard_test_root/runtime.log" || rg -q 'GUARD_FAIL|ReferenceError:|TypeError:|Binding loop' "$guard_test_root/runtime.log"; then
    cat "$guard_test_root/runtime.log"
    exit 1
fi
printf 'PASS: production family guard retains reservation, cancels stale release and settles to zero\n'
