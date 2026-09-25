#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/SystemInfo.qml"

node - "$service" <<'NODE'
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const service = fs.readFileSync(process.argv[2], 'utf8');

function method(name) {
    const token = 'function ' + name + '(';
    const start = service.indexOf(token);
    assert.ok(start >= 0, 'missing service method: ' + name);
    const brace = service.indexOf('{', start);
    let depth = 0;
    for (let i = brace; i < service.length; i++) {
        if (service[i] === '{') depth++;
        if (service[i] === '}' && --depth === 0) {
            return service.slice(start, i + 1)
                .replace(/:\s*(?:int|real|var|bool|string|void)\b/g, '');
        }
    }
    throw Error('unclosed function: ' + name);
}

assert.ok(service.includes('command: ["/usr/bin/id", "-un"]'),
    'id(1) compatibility fallback must remain available');
assert.ok(service.includes('command: ["/usr/bin/getent", "passwd", root.username]'),
    'display-name lookup must remain available');

let envUser = 'alice';
const root = {username: 'seed', displayName: ''};
const getUsername = {running: false};
const getDisplayName = {running: false, command: []};
const passwdFile = {
    path: '',
    lookupName: '',
    reloadCount: 0,
    reload() { this.reloadCount++; },
};
const ctx = {
    root,
    getUsername,
    getDisplayName,
    passwdFile,
    Quickshell: {env(name) { return name === 'USER' ? envUser : ''; }},
    String,
};
vm.createContext(ctx);
vm.runInContext(
    method('_resolveDisplayName')
        + '\nroot._resolveDisplayName = _resolveDisplayName;'
        + '\n' + method('refreshIdentity')
        + '\nroot.refreshIdentity = refreshIdentity;',
    ctx,
);

root.refreshIdentity();
assert.equal(root.username, 'alice', 'normal session uses USER identity');
assert.equal(getUsername.running, false,
    'normal session must not spawn id -un');
assert.equal(getDisplayName.running, false,
    'normal /etc/passwd resolution must not spawn getent');
assert.equal(passwdFile.lookupName, 'alice',
    'in-process passwd lookup targets the environment username');
assert.equal(passwdFile.path, '/etc/passwd',
    'normal identity lookup reads the local passwd database');

getDisplayName.running = false;
getDisplayName.command = [];
getUsername.running = false;
envUser = '   ';
root.username = 'user';
root.refreshIdentity();
assert.equal(getUsername.running, true,
    'missing USER must preserve id -un fallback');
assert.equal(getDisplayName.running, false,
    'fallback waits for the resolved username before display-name lookup');

getUsername.running = false;
getDisplayName.running = true;
envUser = 'bob';
root.username = 'unchanged';
root.refreshIdentity();
assert.equal(root.username, 'unchanged',
    'busy identity refresh must remain serialized');
assert.equal(getUsername.running, false,
    'busy refresh must not start a second username lookup');

console.log('SystemInfo startup identity lifecycle: PASS');
NODE
