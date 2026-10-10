#!/usr/bin/env node
// Deterministic behavior regression for Niri fullscreen + workspace focus.
// Execute the actual QML JS functions with mock Niri IPC state. No shell,
// compositor, input or live desktop is mutated by this test.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const gameMode = readFileSync(resolve(rootDir, 'services/GameMode.qml'), 'utf8');
const niriService = readFileSync(resolve(rootDir, 'services/NiriService.qml'), 'utf8');

function qmlFunction(source, name) {
    const expression = new RegExp('\\bfunction\\s+' + name + '\\s*\\(');
    const match = expression.exec(source);
    assert.ok(match, 'Missing QML function: ' + name);
    const open = source.indexOf('{', match.index);
    assert.ok(open >= 0, 'Missing function body: ' + name);
    let nesting = 0;
    let end = -1;
    for (let i = open; i < source.length; i++) {
        if (source[i] === '{') nesting++;
        else if (source[i] === '}' && --nesting === 0) {
            end = i + 1;
            break;
        }
    }
    assert.ok(end > open, 'Unclosed function: ' + name);
    return source.slice(match.index, end)
        .replace('(outputName: string): bool', '(outputName)');
}

const niri = {
    windows: [],
    workspaces: {},
    outputs: {
        'eDP-1': { logical: { width: 1920, height: 1080 } },
        'DP-1': { logical: { width: 2560, height: 1440 } },
    },
};
const compositor = { isNiri: true };
const gameRoot = {};
const compiled = new Function(
    'NiriService', 'CompositorService', 'root',
    qmlFunction(gameMode, '_isWindowFullscreenWithWorkspace') + '\n'
    + qmlFunction(gameMode, '_selectedWindowForWorkspace') + '\n'
    + qmlFunction(gameMode, 'hasFullscreenOnOutput') + '\n'
    + 'return { full: _isWindowFullscreenWithWorkspace, '
    + 'select: _selectedWindowForWorkspace, covers: hasFullscreenOnOutput };'
)(niri, compositor, gameRoot);
gameRoot._isWindowFullscreenWithWorkspace = compiled.full;
gameRoot._selectedWindowForWorkspace = compiled.select;

let assertions = 0;
function expect(name, actual, expected) {
    assert.equal(actual, expected, name);
    assertions++;
}
function window(id, workspaceId, size, focused = false) {
    return { id, workspace_id: workspaceId, is_focused: focused,
        layout: { window_size: size } };
}
const fullA = window(1, 10, [1920, 1080], true);
const normalB = window(2, 10, [900, 700]);
const fullC = window(3, 11, [2560, 1440]);

niri.windows = [fullA];
niri.workspaces = { 10: { id: 10, output: 'eDP-1',
    is_active: true, active_window_id: 1 } };
expect('A fullscreen foreground covers its output',
    compiled.covers('eDP-1'), true);

niri.windows = [fullA, normalB];
niri.workspaces[10] = { ...niri.workspaces[10], active_window_id: 2 };
expect('opening/focusing B reveals shell while A stays fullscreen',
    compiled.covers('eDP-1'), false);
niri.workspaces[10].active_window_id = '1';
expect('return to A fullscreen, accepting string ID',
    compiled.covers('eDP-1'), true);
niri.workspaces[10].is_active = false;
expect('background workspace fullscreen does not hide shell',
    compiled.covers('eDP-1'), false);

niri.workspaces = {
    10: { id: 10, output: 'eDP-1', is_active: true, active_window_id: 2 },
    11: { id: 11, output: 'DP-1', is_active: true, active_window_id: 3 },
};
niri.windows = [fullA, normalB, fullC];
expect('normal primary output unaffected by remote fullscreen',
    compiled.covers('eDP-1'), false);
expect('secondary output still respects fullscreen',
    compiled.covers('DP-1'), true);
expect('global visible fullscreen sees one active fullscreen output',
    compiled.covers(''), true);

niri.workspaces = { 10: { id: 10, output: 'eDP-1', is_active: true } };
niri.windows = [fullA, normalB];
expect('cold-start fallback uses focused fullscreen window',
    compiled.covers('eDP-1'), true);
niri.windows = [{ ...fullA, is_focused: false },
    { ...normalB, is_focused: true }];
expect('cold-start fallback prefers focused normal window',
    compiled.covers('eDP-1'), false);
niri.windows = [{ ...fullA, is_focused: false }];
expect('cold-start singleton fullscreen remains suppressed',
    compiled.covers('eDP-1'), true);
niri.windows = [{ ...fullA, is_focused: false },
    { ...normalB, is_focused: false }];
expect('ambiguous focus does not claim foreground fullscreen',
    compiled.covers('eDP-1'), false);

// Run the real NiriService event handlers as well. JavaScript object keys
// are strings, while IPC workspace_id values are numeric.
const svcRoot = {
    workspaces: { 10: { id: 10, active_window_id: 1 } },
    windows: [fullA, normalB], _windowsDirty: false, _pendingWindows: [],
    _latestFocusedWindowId: undefined,
};
const eventHelpers = new Function('root', 'mruWindowIds', 'scheduleWindowsUpdate',
    qmlFunction(niriService, 'handleWorkspaceActiveWindowChanged') + '\n'
    + qmlFunction(niriService, 'handleWindowFocusChanged') + '\n'
    + 'return { active: handleWorkspaceActiveWindowChanged, '
    + 'focus: handleWindowFocusChanged };'
)(svcRoot, [], () => {});
eventHelpers.active({ workspace_id: 10, active_window_id: 2 });
expect('native workspace-active event updates numeric ID key',
    svcRoot.workspaces[10].active_window_id, 2);
eventHelpers.focus({ id: 1 });
expect('native focus event updates numeric workspace ID key',
    svcRoot.workspaces[10].active_window_id, 1);

assert.match(gameMode,
    /readonly property bool hasVisibleFullscreenWindow:[\s\S]*?\? hasFullscreenOnOutput\(""\)/,
    'global visible fullscreen must reuse selection-aware output logic');
assertions++;
console.log('PASS: ' + assertions + ' selected-fullscreen and Niri IPC focus assertions');
