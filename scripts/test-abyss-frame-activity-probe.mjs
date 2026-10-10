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
                .replace('(): void {', '() {').replace('(): var {', '() {');
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
};
const leftPanel={progress:0}, rightPanel={progress:0};
const dashboardBody={progress:0}, controls={progress:0}, settings={progress:0};
const bar={visible:true};
const liquid={popupsOpen:false,popupSlots:[]};
const fakeDate={value:0, now() { return this.value; }};
const qml = new Function('window','leftPanel','rightPanel','dashboardBody',
    'controls','settings','liquid','bar','Date',
    namedFunction('onFrameSwapped') + '\n' + namedFunction('stopFrameProbe')
    + '\nreturn {tick:onFrameSwapped, stop:stopFrameProbe};')(
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
check('long interval duration',window._frameProbeSlowEvents[0].intervalMs,73);
check('zero panel progress during the long interval',
    window._frameProbeSlowEvents[0].leftPanelProgress,0);
const result=qml.stop();
check('result includes sampled motion counts',result.panelNonzeroFrames,5);
check('result includes changed-frame counts',result.panelProgressChangedFrames,5);
check('result includes popup-open counts',result.popupOpenFrames,2);
check('measurement is disabled after stop',window._frameProbeEnabled,false);
check('frame pacing caveat retains idle gaps',result.caveat.includes('idle gaps'),true);
console.log('PASS: '+checks+' actual-QML frame diagnostic assertions');
