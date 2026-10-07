#!/usr/bin/env node
// Frozen pre-spectrum traces qualify the untouched interaction path, including
// every sample, substep, projected crest and foam value (not just final output).
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');

function traces(source) {
    const wave = vm.createContext({});
    vm.runInContext(source, wave);
    const result = [];
    for (const count of [128, 256]) for (const [width, height] of [[1920, 1080], [720, 650], [420, 260]])
        for (const preset of ['calm', 'balanced', 'fluid', 'deep', 'custom']) {
            const options = {preset, ...wave.customDefaults};
            const state = wave.create(count, width, height, wave.parameters(options));
            wave.setMass(state, [{edge:'top', along:20, span:width*.6, mass:4, progress:1},
                {edge:'left', along:height*.4, span:100, mass:2, progress:.7}]);
            const hash = crypto.createHash('sha256');
            for (let frame = 0; frame < 600; frame++) {
                if (frame === 0 || frame === 160 || frame === 320) {
                    const edge = ['top','right','bottom'][frame/160];
                    const along = edge === 'right' ? height*.6 : width*.7;
                    const strength = frame === 160 ? -.7 : .8;
                    wave.impulse(state, edge, along, 110, strength, 3);
                    wave.travel(state, edge, along, 110, strength, 3);
                }
                if (frame === 480) wave.clearTravel(state);
                wave.advance(state, [1/120, 1/60, .033, .05][frame%4]);
                wave.projectCrests(state, frame%2 === 0);
                hash.update(JSON.stringify({mode:state.mode, quiet:state.quiet, age:state.age, steps:state.steps,
                    displacement:state.displacement, velocity:state.velocity, mass:state.mass,
                    acceleration:state.acceleration, traveling:state.traveling, travelTargets:state.travelTargets,
                    hasTravelTargets:state.hasTravelTargets, crestSource:state.crestSource,
                    crests:state.crests, whitewater:state.whitewater, crestPeak:state.crestPeak}));
            }
            result.push({count, width, height, preset, sha256:hash.digest('hex')});
        }
    return result;
}

if (require.main === module) {
    const expected = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/abyss-wave-interaction.json')));
    const actual = traces(fs.readFileSync(path.join(root, 'modules/abyss/looks/AbyssWave.js'), 'utf8'));
    assert.deepEqual(actual, expected.traces);
    console.log(`PASS: ${actual.length} frozen pre-spectrum interaction traces, 18000 frames with exact samples/physics/crests/foam`);
}
module.exports = {traces};
