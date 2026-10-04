#!/usr/bin/env bash
# One-shot, read-only maintainer acceptance. Does not submit prompts or restart services.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(git symbolic-ref --quiet --short HEAD)" == "dev" ]] || {
  echo "FAIL: run from the dev branch; no branch changes were made"; exit 2;
}
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/dev)" ]] || {
  echo "FAIL: local dev is not at fetched origin/dev; no branch changes were made"; exit 2;
}
git diff --quiet HEAD -- automation/chat_bridge/native_adapter.mjs \
  automation/chat_bridge/native_cli.mjs scripts/test-hadalis-native-contract.mjs \
  scripts/test-hadalis-desktop-repair.sh || {
  echo "FAIL: local automation source has uncommitted edits; stopped"; exit 2;
}
printf 'HADALIS_DESKTOP_TEST_SHA=%s\n' "$(git rev-parse HEAD)"
echo "=== OFFLINE REGRESSION TESTS ==="
node --check automation/chat_bridge/native_adapter.mjs
node --check automation/chat_bridge/native_cli.mjs
node --check scripts/test-hadalis-native-contract.mjs
node scripts/test-hadalis-native-contract.mjs
node scripts/test-hadalis-native-session.mjs
node scripts/test-hadalis-native-branch.mjs
python3 scripts/test-hadalis-desktop-host.py
python3 scripts/test-hadalis-managed-chat-diagnose.py
python3 scripts/test-hadalis-automation-profile-lifecycle.py
python3 scripts/test-hadalis-automation-workflows.py
python3 scripts/test-hadalis-automation-overnight.py
python3 scripts/test-hadalis-cursor-timeout.py
python3 scripts/test-hadalis-rotation-10.py
python3 scripts/test-hadalis-overnight-check.py

echo "=== INSTALLED DESKTOP CONTRACT (BOOLEAN FLAGS ONLY) ==="
node --input-type=module <<'JS'
import {inspectInstalledContract} from "./automation/chat_bridge/native_adapter.mjs";
try {
  const result = inspectInstalledContract();
  for (const [name,ok] of Object.entries(result.checks))
    console.log("CONTRACT_" + name.toUpperCase() + "=" + (ok ? "PASS" : "FAIL"));
  console.log("CONTRACT=" + (result.contract ?
    result.contract.api_resolution === "static_export" ?
      "PASS_STATIC" : "RUNTIME_VALIDATION_REQUIRED" : "UNSUPPORTED"));
} catch (error) {
  // Never leak a private archive path, source line, native symbols, or a stack.
  console.log("CONTRACT=UNAVAILABLE");
}
JS

echo "=== BOUNDED READ-ONLY LIVE PROBE ==="
python3 - <<'PY'
import json
import subprocess
import sys

from automation.manager.store import read_snapshot

CODES = {
    "DESKTOP_RATE_LIMITED", "DESKTOP_OPERATION_UNAVAILABLE",
    "DESKTOP_OPERATION_TIMEOUT", "DESKTOP_CAPABILITY_UNAVAILABLE",
    "GITHUB_PLUGIN_UNAVAILABLE", "THINKING_EFFORT_UNAVAILABLE",
    "PROJECT_UNAVAILABLE_OR_AMBIGUOUS", "LEGACY_IDENTITY_AMBIGUOUS",
}
def run(label, operation):
    try:
        result = subprocess.run(
            ["node", "automation/chat_bridge/native_cli.mjs"],
            input=json.dumps(dict(operation, error_observation=True)),
            text=True, capture_output=True, timeout=43, check=False
        )
    except subprocess.TimeoutExpired:
        print(label + "=PROCESS_TIMEOUT")
        return False
    if result.returncode == 0:
        try:
            value = json.loads(result.stdout)
            if not isinstance(value, dict):
                print(label + "=INVALID_RECEIPT")
                return False
            print(label + "=PASS")
            return True
        except (ValueError, TypeError):
            print(label + "=INVALID_RECEIPT")
            return False
    try:
        observation = json.loads(result.stderr)
        code = observation.get("code") if isinstance(observation, dict) else observation
        resource = observation.get("resource") if isinstance(observation, dict) else None
    except (ValueError, TypeError):
        code = result.stderr.strip()
        resource = None
    code = code if code in CODES else "UNCLASSIFIED"
    resource = resource if resource in {"desktop","projects","models","conversation","stream_status"} else "none"
    print(label + "=" + code + ";RESOURCE=" + resource)
    return False

if not run("NATIVE_PROBE", {"op":"probe"}):
    print("=== READ-ONLY RENDERER STAGE DIAGNOSIS ===")
    allowed = {
        "contract_inspected", "contract_supported",
        "contract_initial_asset", "contract_shared_asset",
        "contract_conversation_stream_hook", "contract_api_import",
        "contract_stream_scope", "contract_stream_method",
        "contract_api_export", "contract_stream_export",
        "contract_stream_runtime_discovery",
        "contract_api_exact_binding", "contract_api_exact_export",
        "contract_api_runtime_link",
        "renderer_found", "modules_loaded", "static_api_valid",
        "safe_get_exports", "stream_post_exports", "combined_api_exports",
        "stream_definition_exports", "stream_transport_matches",
        "stream_definition_valid", "react_root_found", "scope_found",
        "transport_valid",
    }
    try:
        diagnostic = subprocess.run(
            ["node", "automation/chat_bridge/native_cli.mjs"],
            input=json.dumps({"op":"diagnose", "error_observation":True}),
            text=True, capture_output=True, timeout=43, check=False
        )
        if diagnostic.returncode == 0:
            payload = json.loads(diagnostic.stdout)
            if not isinstance(payload, dict):
                raise ValueError("not a diagnostic object")
            for key in sorted(allowed):
                value = payload.get(key)
                if type(value) is bool:
                    print("RENDERER_" + key.upper() + "=" + ("PASS" if value else "FAIL"))
                elif key.endswith("_exports") and value in {"zero", "one", "multiple"}:
                    print("RENDERER_" + key.upper() + "=" + value.upper())
                else:
                    print("RENDERER_" + key.upper() + "=UNAVAILABLE")
        else:
            print("RENDERER_DIAGNOSIS=UNAVAILABLE")
    except (subprocess.TimeoutExpired, ValueError, TypeError):
        print("RENDERER_DIAGNOSIS=UNAVAILABLE")
    print("RESULT=CONTRACT_OR_TRANSPORT_BLOCKED_NO_PROMPTS_SENT")
    sys.exit(2)

config, _state, issues = read_snapshot()
if issues:
    print("RESULT=PROFILE_CONFIGURATION_PROBLEM")
    sys.exit(2)
enabled = [p for p in config["profiles"] if p["enabled"]]
all_ok = True
for index, project in enumerate(sorted(set(p["project_name"] for p in enabled)), 1):
    all_ok = run("PROJECT_" + str(index), {"op":"project", "name":project}) and all_ok
for index, (effort, github) in enumerate(sorted(set(
    (p["thinking_effort"], p["requires_github"]) for p in enabled
)), 1):
    all_ok = run("PREFLIGHT_" + str(index), {
        "op":"preflight", "thinking_effort":effort, "requires_github":github
    }) and all_ok
print("RESULT=" + ("PASS_READ_ONLY" if all_ok else "PROJECT_OR_PREFLIGHT_BLOCKED"))
sys.exit(0 if all_ok else 2)
PY
