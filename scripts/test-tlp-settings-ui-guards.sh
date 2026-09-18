#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
helper="$repo_root/assets/helpers/inir-battery-charge-limit"
runtime="$repo_root/services/TlpRuntimeCapabilities.qml"
classic="$repo_root/modules/settings/TlpSettingRow.qml"
waffle="$repo_root/modules/waffle/settings/WTlpSettingRow.qml"
general="$repo_root/modules/settings/GeneralConfig.qml"
power="$repo_root/modules/settings/TlpPowerSettings.qml"
selection_group_button="$repo_root/modules/common/widgets/SelectionGroupButton.qml"
registry="$repo_root/modules/settings/SettingsPageRegistry.qml"
arrangement="$repo_root/modules/settings/SettingsArrangement.qml"
legacy_tlp="$repo_root/modules/settings/TlpConfig.qml"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    expected=$1
    actual=$2
    message=$3
    [ "$expected" = "$actual" ] || fail "$message (expected '$expected', got '$actual')"
}

assert_contains() {
    needle=$1
    file=$2
    message=$3
    grep -Fq -- "$needle" "$file" || fail "$message"
}

assert_not_contains() {
    needle=$1
    file=$2
    message=$3
    if grep -Fq -- "$needle" "$file"; then
        fail "$message"
    fi
}

sh -n "$helper" || fail 'TLP helper must remain valid POSIX shell syntax'

# Source the helper under this test basename; its guarded main() must not run.
# shellcheck disable=SC1090
. "$helper"

assert_eq CPU_BOOST_ON_AC \
    "$(tlp_settings_runtime_key CPU_BOOST_ON_AC 1.10.2)" \
    'TLP 1.10 must keep legacy AC profile keys'
assert_eq CPU_BOOST_ON_PRF \
    "$(tlp_settings_runtime_key CPU_BOOST_ON_AC 1.11.0)" \
    'TLP 1.11 must read the canonical PRF profile key'
assert_eq CPU_BOOST_ON_BAL \
    "$(tlp_settings_runtime_key CPU_BOOST_ON_BAT 1.11.0)" \
    'TLP 1.11 must read the canonical BAL profile key'
assert_eq DEVICES_TO_DISABLE_ON_PRF_NOT_IN_USE \
    "$(tlp_settings_runtime_key DEVICES_TO_DISABLE_ON_AC_NOT_IN_USE 1.11.0)" \
    'TLP 1.11 must rename embedded AC profile markers before trailing qualifiers'
assert_eq DEVICES_TO_DISABLE_ON_BAL_NOT_IN_USE \
    "$(tlp_settings_runtime_key DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE 1.11.0)" \
    'TLP 1.11 must rename embedded BAT profile markers before trailing qualifiers'
assert_eq TLP_PROFILE_AC \
    "$(tlp_settings_runtime_key TLP_PROFILE_AC 1.11.0)" \
    'profile selection keys are not suffix-renamed settings'

assert_contains 'CPU_DRIVER_OPMODE_ON_AC' "$runtime" \
    'runtime capabilities must gate CPU driver modes'
assert_contains '/sys/devices/system/cpu/intel_pstate/status' "$runtime" \
    'intel_pstate passive mode must remain detectable'
assert_contains '_kernelAtLeast(6, 4)' "$runtime" \
    'guided amd-pstate mode must be kernel-gated'
assert_contains 'INTEL_GPU_MIN_FREQ_ON_AC' "$runtime" \
    'runtime capabilities must probe Intel GPU frequency support'
assert_contains 'numberRanges' "$runtime" \
    'runtime capabilities must expose hardware number ranges'

for row in "$classic" "$waffle"; do
    assert_contains 'gpuFrequencyGroupKeys' "$row" \
        "$(basename "$row") must stage Intel GPU frequency groups atomically"
    assert_contains 'editorNumberRange' "$row" \
        "$(basename "$row") must use runtime numeric bounds"
    assert_contains 'next.length === 0 && root.settingKey.startsWith("PLATFORM_PROFILE_")' "$row" \
        "$(basename "$row") must turn an empty TLP 1.11 profile list into inherit/unset"
done

# Classic Settings integration: TLP is a System → Power task, not a separate
# navigation page. Static search must target the real embedded card titles so
# spotlight navigation can both switch tabs and scroll to the requested card.
assert_contains 'GeneralConfigCore {' "$general" \
    'System settings must retain the upstream GeneralConfig core'
assert_contains 'TlpPowerSettings {' "$general" \
    'System settings must embed the TLP power controls'
assert_contains 'visible: root.activeSection === "power"' "$general" \
    'embedded TLP controls must only be visible in the Power task'
assert_contains 'tlpPowerSettings.navigationCategories' "$general" \
    'TLP deep links must use the visible category model after battery-care integration'
if grep -Fq 'root.selectTlpCategory("battery-care")' "$general"; then
    fail 'charge-care deep links must land on the merged Power card, not a retired category tab'
fi
assert_contains 'SettingsPageRegistry.consumeLegacyTlpPowerRedirect()' "$general" \
    'legacy page-28 state must land on the Power task instead of Audio'
assert_contains 'property string settingsTaskSection: "power"' "$power" \
    'TLP controls must identify themselves as part of the Power task'
assert_contains 'title: Translation.tr("Battery and TLP power management")' "$power" \
    'the primary TLP card title must remain a stable search target'
assert_contains '.filter(category => String(category?.id ?? "") !== "battery-care")' "$power" \
    'Configuration categories must exclude the battery-care tab after merging it into Battery'
assert_contains 'columns: 5' "$power" \
    'Configuration categories must render five tabs per row'
assert_contains 'rows: 2' "$power" \
    'Configuration categories must stay at two rows'
assert_contains 'model: root.navigationCategories' "$power" \
    'Configuration categories must consume the filtered ten-category model'
assert_contains 'leftAlignContent: true' "$power" \
    'Configuration category tabs must opt into scoped left alignment'
assert_contains 'text: Translation.tr("Config: %1").arg(TlpSettingsService.configFile)' "$power" \
    'Battery/TLP summary must keep the managed config path concise'
assert_contains ': Translation.tr("Effective values")' "$power" \
    'Battery/TLP summary must use the concise effective-values label'
assert_contains 'BatteryChargeLimitSettings {' "$power" \
    'battery charge care must be integrated into the primary Battery/TLP card'
assert_not_contains 'Values shown below come from TLP' "$power" \
    'Battery/TLP summary must not restore the old verbose effective-configuration description'
assert_not_contains 'Apply validates every change and authenticates only once' "$power" \
    'Battery/TLP summary must keep apply guidance concise'
assert_not_contains 'Reset removes only the general iNiR TLP' "$power" \
    'Battery/TLP summary must keep reset guidance concise'
assert_contains 'Layout.fillWidth: root.leftAlignContent' "$selection_group_button" \
    'scoped category left alignment must consume trailing button space without changing global controls'
assert_contains 'import Quickshell' "$registry" \
    'SettingsPageRegistry must import the Quickshell Singleton type or shell startup will fail'
assert_contains 'readonly property int retiredTlpPageIndex: 28' "$registry" \
    'the historical TLP page index must stay retired from public navigation'
assert_contains 'SettingsPageRegistryData.pages.map((page, index)' "$registry" \
    'legacy page 28 must remain an internal compatibility alias until migration wins the startup race'
assert_contains 'name: systemPage.name' "$registry" \
    'the internal page-28 fallback must present itself as System, not as a standalone Battery page'
assert_contains 'function isHiddenLegacyIndex(index: int): bool' "$registry" \
    'the registry must centralize filtering of retired navigation indexes'
assert_contains 'return index === root.retiredTlpPageIndex || root.isRetiredFeaturePage(index)' "$registry" \
    'the hidden-index invariant must include both the retired TLP page and retired feature pages'
assert_contains 'pages: category.pages.filter(index => !root.isHiddenLegacyIndex(index))' "$registry" \
    'retired compatibility pages must never reappear in sidebar categories'
assert_contains 'Persistent.states.settings.iiPage = root.systemPageIndex' "$registry" \
    'persisted legacy page 28 must migrate to System when Persistent becomes available'
assert_contains 'function consumeLegacyTlpPowerRedirect(): bool' "$registry" \
    'legacy current-page migration must expose a one-shot Power landing hint'
assert_contains 'redirected.pageIndex = root.systemPageIndex' "$registry" \
    'legacy TLP search entries must redirect to System'
assert_contains 'redirected.section = Translation.tr("Power")' "$registry" \
    'charge-care search must land on the merged Power section'
assert_contains 'redirected.label = Translation.tr("Battery and TLP power management")' "$registry" \
    'all retired TLP search entries must target the merged Battery/TLP card'
assert_contains 'keywords.concat(["system", "settings", "power"])' "$registry" \
    'redirected TLP search must stay discoverable through System settings terms'
assert_contains 'hidden.push(root.retiredTlpPageIndex)' "$arrangement" \
    'retired page 28 must stay internal-only in saved arrangements'
assert_contains 'GeneralConfig {' "$legacy_tlp" \
    'legacy TlpConfig links must redirect through System settings'
assert_contains 'activeSection: "power"' "$legacy_tlp" \
    'legacy TlpConfig links must land on the Power task'

printf '%s\n' '1..1'
printf '%s\n' 'ok 1 - TLP UI guards and System Power integration are present'
