#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/ShellUpdates.qml"

fail() {
    printf 'shell updates lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

assert_guarded_process() {
    local id="$1" block="$2"
    [[ -n "$block" ]] || fail "$id process block is missing"
    assert_contains 'property bool startObserved: false' "$block" "$id startup guard state is missing"
    assert_contains 'onRunningChanged:' "$block" "$id startup failure path is missing"
    assert_contains "onStarted: $id.startObserved = true" "$block" "$id must distinguish a successful start"
}

fetch_block="$(sed -n '/id: fetchProc/,/\/\/ Step 3:/p' "$service")"
branch_block="$(sed -n '/id: currentBranchProc/,/\/\/ Step 4:/p' "$service")"
local_block="$(sed -n '/id: localCommitProc/,/\/\/ Step 5:/p' "$service")"
remote_block="$(sed -n '/id: remoteCommitProc/,/\/\/ Step 5b:/p' "$service")"
remote_main_block="$(sed -n '/id: remoteCommitFallbackProc/,/\/\/ Step 5c:/p' "$service")"
remote_master_block="$(sed -n '/id: remoteCommitFallback2Proc/,/\/\/ Step 6:/p' "$service")"
count_block="$(sed -n '/id: countCommitsProc/,/\/\/ Step 7:/p' "$service")"
message_block="$(sed -n '/id: latestMessageProc/,/Detail fetching/p' "$service")"

version_reader_block="$(sed -n '/id: versionMetadataFile/,/^    }/p' "$service")"
[[ -n "$version_reader_block" ]] || fail 'version metadata FileView is missing'
assert_contains 'onLoaded: root._consumeVersionMetadata(versionMetadataFile.text())' "$version_reader_block" 'version metadata must be consumed in-process'
assert_contains 'onLoadFailed:' "$version_reader_block" 'missing version metadata must retain repository-search fallback'
if grep -Fq 'command: ["cat", Directories.shellConfig + "/version.json"]' "$service"; then
    fail 'version metadata must not spawn cat during startup'
fi

manifest_reader_block="$(sed -n '/id: manifestMetadataFile/,/^    }/p' "$service")"
[[ -n "$manifest_reader_block" ]] || fail 'manifest metadata FileView is missing'
assert_contains 'onLoaded: root._consumeManifestInfo(manifestMetadataFile.text())' "$manifest_reader_block" 'manifest metadata must be consumed in-process'
assert_contains 'onLoadFailed: recentLocalLogProc.running = true' "$manifest_reader_block" 'missing manifest must continue the update startup chain'
if grep -Fq 'id: manifestInfoProc' "$service"; then
    fail 'manifest metadata must not restore the bash/head/grep/sed process pipeline'
fi

local_version_block="$(sed -n '/id: localVersionFile/,/^    }/p' "$service")"
[[ -n "$local_version_block" ]] || fail 'local VERSION FileView is missing'
assert_contains 'property bool tryingConfigFallback: false' "$local_version_block" 'local VERSION reader must retain repo-to-config fallback state'
assert_contains 'root._setLocalVersionPath(root.configDir + "/VERSION")' "$local_version_block" 'local VERSION reader must fall back to the active config copy'
assert_contains 'root._finishLocalVersion("")' "$local_version_block" 'missing local VERSION files must still complete the update check'
if grep -Fq 'id: localVersionStartupProc' "$service"; then
    fail 'local VERSION startup must not restore the bash/cat process chain'
fi

progress_reader_block="$(sed -n '/id: updateProgressFile/,/^    }/p' "$service")"
[[ -n "$progress_reader_block" ]] || fail 'update progress FileView is missing'
assert_contains 'onLoaded: root._consumeUpdateProgress(updateProgressFile.text())' "$progress_reader_block" 'update progress must be consumed in-process'
assert_contains 'root._reloadUpdateProgress()' "$(sed -n '/id: updateProgressPoller/,/^    }/p' "$service")" '2s progress cadence must reload the in-process FileView'
if grep -Fq 'id: updateProgressReader' "$service"; then
    fail 'update progress polling must not restore one cat process every two seconds'
fi

resume_reader_block="$(sed -n '/id: updateResumeReader/,/stdout: StdioCollector/p' "$service")"
[[ -n "$resume_reader_block" ]] || fail 'update resume reader is missing'
assert_contains 'done < /proc/stat' "$resume_reader_block" 'update resume reader must derive boot time without date/uptime subprocesses on the normal path'
assert_contains 'uptime_s=\${uptime%%.*}' "$resume_reader_block" 'fallback uptime truncation must escape shell expansion inside the QML template literal'
assert_contains 'status=$(<"$status_file")' "$resume_reader_block" 'update resume reader must read the one-line status with Bash builtins'
if grep -Fq '/usr/bin/printf' <<<"$resume_reader_block"; then
    fail 'update resume reader must not restore external printf'
fi
if grep -Fq '/usr/bin/cut' <<<"$resume_reader_block"; then
    fail 'update resume reader must not restore external cut'
fi
if grep -Fq '/usr/bin/cat' <<<"$resume_reader_block"; then
    fail 'update resume reader must not restore external cat'
fi

assert_guarded_process fetchProc "$fetch_block"
assert_guarded_process currentBranchProc "$branch_block"
assert_guarded_process localCommitProc "$local_block"
assert_guarded_process remoteCommitProc "$remote_block"
assert_guarded_process remoteCommitFallbackProc "$remote_main_block"
assert_guarded_process remoteCommitFallback2Proc "$remote_master_block"
assert_guarded_process countCommitsProc "$count_block"
assert_guarded_process latestMessageProc "$message_block"

fail_helper="$(sed -n '/function _failCheckStart/,/^    }/p' "$service")"
count_helper="$(sed -n '/function _finishCountFallback/,/^    }/p' "$service")"
finish_helper="$(sed -n '/function _finishCheck/,/^    }/p' "$service")"

assert_contains 'root.lastError = message' "$fail_helper" 'failed startup must publish a diagnostic error'
assert_contains 'root.isChecking = false' "$fail_helper" 'failed startup must release isChecking'
assert_contains 'root.localCommit !== root.remoteCommit' "$count_helper" 'count startup fallback must compare resolved commit IDs'
assert_contains 'root.commitsBehind = root.hasUpdate ? 1 : 0' "$count_helper" 'count startup fallback must retain a usable behind count'
assert_contains 'root.initialUpdateCheckDone = true' "$count_helper" 'count startup fallback must finish the check cycle'
assert_contains 'root.isChecking = false' "$finish_helper" 'normal finish helper must release isChecking'
assert_contains 'root.initialUpdateCheckDone = true' "$finish_helper" 'normal finish helper must mark the check cycle complete'

fetch_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$fetch_block")"
branch_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$branch_block")"
local_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$local_block")"
remote_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$remote_block")"
remote_main_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$remote_main_block")"
remote_master_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$remote_master_block")"
count_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$count_block")"
message_start="$(sed -n '/onRunningChanged:/,/onStarted:/p' <<<"$message_block")"

assert_contains 'root._failCheckStart("fetch")' "$fetch_start" 'fetch startup failure must terminate the stuck check'
assert_contains 'root._failCheckStart("branch lookup")' "$branch_start" 'branch lookup startup failure must terminate the stuck check'
assert_contains 'root._failCheckStart("local commit lookup")' "$local_start" 'local commit startup failure must terminate the stuck check'
assert_contains 'remoteCommitFallbackProc.running = true' "$remote_start" 'primary remote lookup startup failure must continue to origin/main'
assert_contains 'remoteCommitFallback2Proc.running = true' "$remote_main_start" 'origin/main startup failure must continue to origin/master'
assert_contains 'root._failCheckStart("remote commit lookup")' "$remote_master_start" 'final remote lookup startup failure must terminate the stuck check'
assert_contains 'root._finishCountFallback()' "$count_start" 'count startup failure must use the direct commit fallback'
assert_contains 'root.latestMessage = ""' "$message_start" 'latest-message startup failure must clear stale message text'
assert_contains 'root._finishCheck()' "$message_start" 'latest-message startup failure must complete the check cycle'

changelog_block="$(sed -n '/id: remoteChangelogProc/,/\/\/ Detail Step 5:/p' "$service")"
[[ -n "$changelog_block" ]] || fail 'remote changelog process block is missing'
assert_contains '...root._gitCmd, "show"' "$changelog_block" 'remote changelog must invoke git directly'
assert_contains '.slice(0, 200)' "$changelog_block" 'remote changelog must retain the 200-line display cap in-process'
assert_contains 'localModsProc.running = true' "$changelog_block" 'remote changelog completion must continue detail fetching'
if grep -Fq '"/usr/bin/bash", "-c"' <<<"$changelog_block"; then
    fail 'remote changelog must not restore a bash wrapper'
fi
if grep -Fq 'head -200' <<<"$changelog_block"; then
    fail 'remote changelog must not restore an external head process'
fi

printf 'shell updates check lifecycle guards: ok\n'
