#!/usr/bin/env node
// Execute the actual opt-in QML frame callback and stop() against deterministic
// Panel/Popup state. This guards diagnostic counters, not native FPS or GPU.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = readFileSync(resolve(root, 'modules/abyss/AbyssPerimeter.qml'), 'utf8');
function namedFunction(name) {
    const start = source.indexOf('function ' + name + '(');
    assert.ok(start >= 0, 'missing QML function: ' + name);
    const brace = source.indexOf('{', start);
    let depth = 0;
    for (let i = brace; i < source.length; ++i) {
        if (source[i] === '{') depth++;
        else if (source[i] === '}' && --depth === 0)
            return source.slice(start, i + 1)
                .replace(/\)\s*:\s*(?:void|var)\s*\{/, ') {');
    }
    throw new Error('unclosed QML function ' + name);
}
const window = {
    outputName: 'eDP-1',
    _frameProbeEnabled: true,
    _frameProbePreviousMs: 0,
    _frameProbeIntervals: [],
    _frameProbeSlowEvents: [],
    _frameProbePreviousPanelProgress: null,
    _frameProbePanelNonzeroFrames: 0,
    _frameProbePanelChangedFrames: 0,
    _frameProbePopupOpenFrames: 0,
    _frameProbeHeartbeatPrevMs: 0,
    _frameProbeHeartbeatCount: 0,
    _frameProbeHeartbeatOver100Ms: 0,
    _frameProbeHeartbeatMaxMs: 0,
    _frameProbeHeartbeatLateEvents: [],
    _frameProbeHeartbeatHistory: [],
    _frameProbeBarPrevProgress: -1,
    _frameProbeBarChangedFrames: 0,
    barProgress: 1,
};
const leftPanel={progress:0}, rightPanel={progress:0};
const dashboardBody={progress:0}, controls={progress:0}, settings={progress:0};
const bar={visible:true};
const liquid={popupsOpen:false,popupSlots:[]};
const fakeDate={value:0, now() { return this.value; }};
const qml = new Function('window','leftPanel','rightPanel','dashboardBody',
    'controls','settings','liquid','bar','Date',
    namedFunction('onFrameSwapped') + '\n' + namedFunction('stopFrameProbe')
    + '\n' + namedFunction('recordProbeHeartbeat')
    + '\nreturn {tick:onFrameSwapped, stop:stopFrameProbe, heartbeat:recordProbeHeartbeat};')(
    window,leftPanel,rightPanel,dashboardBody,controls,settings,liquid,bar,fakeDate);
let checks=0;
function check(label,actual,expected) {
    assert.deepEqual(actual,expected,label);
    checks++;
}
// Actual transitions: 0 -> .2 -> .6 -> 1 -> steady -> .4 -> 0
// followed by a 73ms idle gap, never accompanied by Panel motion.
const samples = [
    [1000,0,false],[1017,.2,true],[1034,.6,true],[1051,1,false],
    [1068,1,false],[1085,.4,false],[1102,0,false],[1175,0,false]
];
for(const [time,progress,popupOpen] of samples) {
    fakeDate.value=time; leftPanel.progress=progress;
    liquid.popupsOpen=popupOpen;
    qml.tick();
}
check('bounded frame count',window._frameProbeIntervals.length,7);
check('all panel nonzero observations',window._frameProbePanelNonzeroFrames,5);
check('five actual panel progress changes',window._frameProbePanelChangedFrames,5);
check('two popup-open frames',window._frameProbePopupOpenFrames,2);
check('one actual long interval',window._frameProbeSlowEvents.length,1);
check('Bar unchanged',window._frameProbeBarChangedFrames,0);
// Timestamp 0 is the sentinel, so start after a positive clock value.
for(const tick of [1000,1050,1100,1210,1260]) qml.heartbeat(tick);
check('heartbeat intervals after first tick',window._frameProbeHeartbeatCount,4);
check('one heartbeat gap greater than 100ms',window._frameProbeHeartbeatOver100Ms,1);
check('heartbeat max gap',window._frameProbeHeartbeatMaxMs,110);
check('full heartbeat chronology captured',window._frameProbeHeartbeatHistory.length,5);
check('first interval intentionally unknown',
    window._frameProbeHeartbeatHistory[0].intervalMs,null);
check('heartbeat chronology includes normal ticks',
    window._frameProbeHeartbeatHistory[1].intervalMs,50);
check('bounded late event timestamp',window._frameProbeHeartbeatLateEvents[0].timestampMs,1210);
check('long interval duration',window._frameProbeSlowEvents[0].intervalMs,73);
check('zero panel progress during the long interval',
    window._frameProbeSlowEvents[0].leftPanelProgress,0);
const result=qml.stop();
check('result includes sampled motion counts',result.panelNonzeroFrames,5);
check('result includes changed-frame counts',result.panelProgressChangedFrames,5);
check('result includes popup-open counts',result.popupOpenFrames,2);
check('result contains heartbeat gap count',result.heartbeatOver100Ms,1);
check('result contains max heartbeat gap',result.heartbeatMaxIntervalMs,110);
check('returned history contains all ticks',result.heartbeatHistory.length,5);
check('history not exhausted under normal capture',result.heartbeatHistoryExhausted,false);
check('result contains bar change count',result.barProgressChangedFrames,0);
check('measurement is disabled after stop',window._frameProbeEnabled,false);
check('frame pacing caveat retains idle gaps',result.caveat.includes('idle gaps'),true);
// Verify the guard on an abnormally long diagnostic run without touching
// any live surfaces or changing the earlier stopFrameProbe receipt.
for(let i=0;i<170;i++) qml.heartbeat(1300+i*50);
check('heartbeat history is hard-capped at 160',
    window._frameProbeHeartbeatHistory.length,160);
console.log('PASS: '+checks+' actual-QML frame diagnostic assertions');
