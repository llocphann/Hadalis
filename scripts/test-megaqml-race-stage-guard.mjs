import assert from "node:assert/strict"
import {readFileSync} from "node:fs"
import vm from "node:vm"
const source = readFileSync(new URL("./megaqml-fixtures/runtime-ui-race/RaceStageGuard.js", import.meta.url), "utf8")
const scope = vm.createContext({})
vm.runInContext(source + "\nthis.classify = stageTwo;", scope, {timeout: 1000})
const classify = scope.classify
const missing = {installed:false, shell:false, server:false, login:false, whoami:false, version:false}
const pending = {sawStaleInstalled:false, backendState:"checking", materialLease:true,
    waffleLease:false, consumers:1, requestSerial:2, readBusy:true,
    snapshot:null, safeError:"", connected:false, liveAuthQualified:false}
function expect(patch, result) {
    assert.equal(classify({...pending, ...patch}), result)
}
expect({}, "WAIT")
expect({readBusy:false}, "WAIT")
expect({snapshot:missing}, "STALE_SNAPSHOT")
expect({sawStaleInstalled:true}, "STALE_INSTALLED")
expect({backendState:"installed_disconnected"}, "STALE_INSTALLED")
expect({waffleLease:true}, "STALE_LEASE")
expect({consumers:0}, "STALE_LEASE")
expect({backendState:"unavailable"}, "STALE_UNAVAILABLE")
expect({requestSerial:4}, "STALE_REPLY")
expect({requestSerial:3, readBusy:true}, "THIRD_PENDING")
expect({requestSerial:3, readBusy:true, snapshot:missing}, "STALE_SNAPSHOT")
expect({requestSerial:3, readBusy:false, backendState:"dependency_missing",
        snapshot:missing}, "THIRD_FINISHED")
expect({requestSerial:3, readBusy:false, backendState:"dependency_missing",
        snapshot:missing, sawStaleInstalled:true}, "STALE_INSTALLED")
expect({requestSerial:3, readBusy:false, backendState:"dependency_missing",
        snapshot:{...missing, installed:true}}, "THIRD_RESULT")
expect({requestSerial:3, readBusy:false, backendState:"dependency_missing",
        snapshot:{...missing, server:true}}, "THIRD_RESULT")
expect({requestSerial:3, readBusy:false, backendState:"dependency_missing",
        snapshot:missing, safeError:"bad"}, "THIRD_RESULT")
expect({requestSerial:3, readBusy:false, backendState:"dependency_missing",
        snapshot:null}, "THIRD_RESULT")
console.log("PASS MegaQML stage 2 rejects stale data and accepts early valid third missing reply")
