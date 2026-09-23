#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
guard="$repo_root/scripts/test-qml-local-module-contract.sh"
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT

fail() {
    printf 'qml local module guard regression failed: %s\n' "$1" >&2
    exit 1
}

expect_guard_failure() {
    local root="$1"
    local needle="$2"
    local output
    if output="$(bash "$guard" "$root" 2>&1)"; then
        fail "guard unexpectedly accepted fixture: ${root#$stage/}"
    fi
    grep -Fq -- "$needle" <<<"$output" \
        || fail "guard failure for ${root#$stage/} did not contain: $needle"
}

# Incident class 1: an always-loaded file imports a local qs.* module whose
# directory disappeared from source/runtime. This must fail even without a QML
# parser, matching the qmlscanner failure mode for any removed local module.
case_root="$stage/missing-module"
mkdir -p "$case_root/modules/panel"
cat > "$case_root/modules/panel/Panel.qml" <<'QML'
import QtQuick
import qs.modules.retired
Item {}
QML
expect_guard_failure "$case_root" \
    'local QML import qs.modules.retired maps to missing directory modules/retired'

# Incident class 2: a retired type remains in executable QML after its
# implementation was removed. Use a typed property rather than object syntax so
# the regression proves the guard catches any code-level dangling reference.
case_root="$stage/retired-type"
mkdir -p "$case_root/modules/panel"
cat > "$case_root/modules/panel/Panel.qml" <<'QML'
import QtQuick
Item {
    property MascotImage mascot
}
QML
expect_guard_failure "$case_root" \
    'MascotImage is referenced but MascotImage.qml is absent from the scanned tree'

# Incident class 3: a critical exported type exists, but a consumer outside its
# module forgot to import the module that exports it. This is the exact
# PerimeterRuntime/CompositorFocusGrab failure mode from the maintainer log.
case_root="$stage/focus-import"
mkdir -p "$case_root/modules/common/widgets" "$case_root/modules/perimeter"
cat > "$case_root/modules/common/widgets/CompositorFocusGrab.qml" <<'QML'
import QtQuick
Item {}
QML
cat > "$case_root/modules/perimeter/PerimeterRuntime.qml" <<'QML'
import QtQuick
Item {
    CompositorFocusGrab {}
}
QML
expect_guard_failure "$case_root" \
    'CompositorFocusGrab consumer must import qs.modules.common.widgets'

# Correcting the module import must make the same fixture pass. Comments and
# strings mentioning retired symbols must stay non-fatal so old documentation
# text cannot create a false-red acceptance failure.
cat > "$case_root/modules/perimeter/PerimeterRuntime.qml" <<'QML'
import QtQuick
import qs.modules.common.widgets
Item {
    // MascotImage { retired example only }
    property string note: "MascotAnimation { retired example only }"
    CompositorFocusGrab {}
}
QML
bash "$guard" "$case_root" >/dev/null \
    || fail 'guard rejected corrected local module/type fixture'

# Incident class 4: a compatibility type can be intentionally restored, but the
# existence of MascotImage.qml does not make it globally visible. Consumers must
# still import the owning local module. This protects the old CloseConfirm class
# of failure if mascot compatibility is reintroduced on an always-loaded path.
case_root="$stage/restored-mascot-import"
mkdir -p "$case_root/modules/common/widgets" "$case_root/modules/panel"
cat > "$case_root/modules/common/widgets/MascotImage.qml" <<'QML'
import QtQuick
Item {}
QML
cat > "$case_root/modules/panel/Panel.qml" <<'QML'
import QtQuick
Item {
    MascotImage {}
}
QML
expect_guard_failure "$case_root" \
    'MascotImage consumer must import qs.modules.common.widgets'

# The owner import resolves the restored compatibility type. Use an alias to
# prove the guard keys off the imported URI, not one exact import spelling.
cat > "$case_root/modules/panel/Panel.qml" <<'QML'
import QtQuick
import qs.modules.common.widgets as Widgets
Item {
    Widgets.MascotImage {}
}
QML
bash "$guard" "$case_root" >/dev/null \
    || fail 'guard rejected restored MascotImage consumer with owner-module import'

# Incident class 5: the Code Workflow runtime shell is a staging template.
# qs.workflowprobe exists only after prepare-runtime creates the isolated export,
# so the committed template must not import that generated-only module directly.
probe_shell="$repo_root/scripts/code-workflow/runtime/ProbeShell.qml"
prepare_runtime="$repo_root/scripts/code-workflow/prepare-runtime.py"
if grep -Fq -- 'import qs.workflowprobe' "$probe_shell"; then
    fail 'ProbeShell directly imports generated-only qs.workflowprobe and will break whole-tree verification'
fi
grep -Fq -- 'WORKFLOW_PROBE_IMPORT' "$probe_shell"     || fail 'ProbeShell is missing the staged workflowprobe import marker'
grep -Fq -- "'import qs.workflowprobe\\n'" "$prepare_runtime"     || fail 'prepare-runtime no longer injects qs.workflowprobe into the isolated shell'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - local QML resolution guard catches missing modules, retired types, missing owner imports, and generated-only probe imports'
