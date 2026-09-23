#!/usr/bin/env python3
"""Exercise the production remote lease client across page and IPC races."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "services/RuntimeDiagnosticsSession.qml").read_text(encoding="utf-8")


def function_source(name: str) -> str:
    start = SOURCE.index(f"function {name}(")
    opening = SOURCE.index("{", start)
    depth = 0
    for index in range(opening, len(SOURCE)):
        if SOURCE[index] == "{":
            depth += 1
        elif SOURCE[index] == "}":
            depth -= 1
            if depth == 0:
                return SOURCE[start:index + 1]
    raise AssertionError(f"unclosed QML function: {name}")


names = (
    "_pulseRemote", "_releaseRemote", "_acquireLease", "_releaseLease",
    "_remotePulseExited", "_remoteReleaseExited",
)
payload = {name: function_source(name) for name in names}

node_test = r"""
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const sources = JSON.parse(fs.readFileSync(0, 'utf8'));

function makeSession() {
    const commands = [];
    const runtimeEvents = [];
    const callbacks = [];
    const remotePulse = {action: '', command: []};
    const remoteRelease = {command: []};
    for (const [process, name] of [[remotePulse, 'pulse'], [remoteRelease, 'release']]) {
        let running = false;
        Object.defineProperty(process, 'running', {
            get: () => running,
            set: value => {
                running = value;
                if (value) commands.push(name === 'pulse' ? process.action : 'release');
            },
        });
    }
    const remotePulseOutput = {text: '{"ok":true}'};
    const remotePulseError = {text: 'IPC failed'};
    const root = {
        pageCurrent: false,
        localShell: false,
        clientId: 'settings:100',
        releaseAfterPulse: false,
        leaseTransport: '',
        remoteError: '',
        _remoteCommand: action => [action, 'settings:100'],
    };
    const context = vm.createContext({
        root, remotePulse, remoteRelease, remotePulseOutput, remotePulseError,
        RuntimeDiagnostics: {
            acquire: () => { runtimeEvents.push('local-acquire'); return true; },
            release: () => { runtimeEvents.push('local-release'); return true; },
        },
        Qt: {callLater: callback => callbacks.push(callback)},
    });
    for (const [name, source] of Object.entries(sources)) {
        const js = source.replace(/:\s*(string|bool|var|int|real|double|void)(?=\s*[,){])/g, '');
        root[name] = vm.runInContext('(' + js + ')', context);
    }
    const flush = () => {
        let count = 0;
        while (callbacks.length > 0) {
            assert.ok(++count <= 10, 'queued callbacks must converge');
            callbacks.shift()();
        }
    };
    return {
        root, commands, runtimeEvents, remotePulse, remoteRelease, flush,
        setPulseError(text) { remotePulseError.text = text; },
        enter() { root.pageCurrent = true; root._acquireLease(); },
        leave() { root.pageCurrent = false; root._releaseRemote(); },
        finishPulse(exitCode = 0, payload = '{"ok":true}', runCallbacks = true) {
            assert.equal(remotePulse.running, true);
            remotePulse.running = false;
            remotePulseOutput.text = payload;
            root._remotePulseExited(exitCode);
            if (runCallbacks) flush();
        },
        finishRelease() {
            assert.equal(remoteRelease.running, true);
            remoteRelease.running = false;
            root._remoteReleaseExited();
            flush();
        },
    };
}

// Release must follow a queued acquire, even when the page changes immediately.
{
    const s = makeSession();
    s.enter();
    s.leave();
    assert.equal(s.remoteRelease.running, false);
    s.finishPulse();
    assert.deepEqual(s.commands, ['acquire', 'release']);
    assert.equal(s.remoteRelease.running, true);
}

// An IPC error still needs a release because the server may have acquired it.
{
    const s = makeSession();
    s.enter();
    s.finishPulse();
    s.root._pulseRemote('heartbeat');
    s.leave();
    s.finishPulse(1);
    assert.deepEqual(s.commands, ['acquire', 'heartbeat', 'release']);
}

// Remote command failures must remain diagnosable even when stderr is empty,
// and an explicit acquire rejection must not look like a healthy lease.
{
    const s = makeSession();
    s.enter();
    s.setPulseError('');
    s.finishPulse(7);
    assert.equal(s.root.remoteError, 'Diagnostics lease command exited with 7');
    s.root._pulseRemote('heartbeat');
    assert.equal(
        s.root.remoteError,
        'Diagnostics lease command exited with 7',
        'a retry must not hide the last failure before recovery'
    );
    s.finishPulse();
    assert.equal(s.root.remoteError, '');
}
{
    const s = makeSession();
    s.enter();
    s.finishPulse(0, '{"ok":false}');
    assert.equal(s.root.remoteError, 'Diagnostics lease was rejected');
}

// Reentering before acquire completes retains that lease without a late release.
{
    const s = makeSession();
    s.enter();
    s.leave();
    s.enter();
    s.finishPulse();
    assert.deepEqual(s.commands, ['acquire']);
}

// Reentering during release reacquires only after the release has completed.
{
    const s = makeSession();
    s.enter();
    s.finishPulse();
    s.leave();
    s.enter();
    assert.deepEqual(s.commands, ['acquire', 'release']);
    s.finishRelease();
    assert.deepEqual(s.commands, ['acquire', 'release', 'acquire']);
}

// Switching from remote to local preserves the deferred remote release even
// when the remote acquire pulse is still in flight.
{
    const s = makeSession();
    s.enter();
    assert.equal(s.root.leaseTransport, 'remote');
    s.root.localShell = true;
    s.root._releaseLease();
    assert.equal(s.root.releaseAfterPulse, true);
    s.root._acquireLease();
    assert.equal(s.root.leaseTransport, 'local');
    assert.equal(s.root.releaseAfterPulse, true);
    assert.deepEqual(s.runtimeEvents, ['local-acquire']);
    s.finishPulse();
    assert.deepEqual(s.commands, ['acquire', 'release']);
    s.finishRelease();
    assert.deepEqual(s.commands, ['acquire', 'release']);
}

// Switching from local to remote releases the local authority before acquiring
// through IPC.
{
    const s = makeSession();
    s.root.pageCurrent = true;
    s.root.localShell = true;
    s.root._acquireLease();
    assert.equal(s.root.leaseTransport, 'local');
    s.root.localShell = false;
    s.root._releaseLease();
    s.root._acquireLease();
    assert.deepEqual(s.runtimeEvents, ['local-acquire', 'local-release']);
    assert.equal(s.root.leaseTransport, 'remote');
    assert.deepEqual(s.commands, ['acquire']);
}

// Expired heartbeat reacquires only while the page remains current.
{
    const s = makeSession();
    s.enter();
    s.finishPulse();
    s.root._pulseRemote('heartbeat');
    s.finishPulse(0, '{"ok":false}');
    assert.deepEqual(s.commands, ['acquire', 'heartbeat', 'acquire']);
}
{
    const s = makeSession();
    s.enter();
    s.finishPulse();
    s.root._pulseRemote('heartbeat');
    s.finishPulse(0, '{"ok":false}', false);
    s.leave();
    s.flush();
    assert.deepEqual(s.commands, ['acquire', 'heartbeat', 'release']);
}
console.log('ok - remote Diagnostics lease serializes pulse and release');
"""

subprocess.run(["node", "-e", node_test], input=json.dumps(payload),
               text=True, check=True)
