#!/usr/bin/env python3
"""Parity oracle for the guarded responsive Dashboard overlap fast path."""

from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CANVAS = ROOT / "modules/dashboard/DashboardCanvas.qml"


def require_source_contract(source: str) -> None:
    required = (
        "function _snapshotVisibleRects()",
        "result[id] = root._cloneRect(",
        "root._rectPixels(id))",
        "function _layoutHasOverlap(rects, baselineRects)",
        "if (root.responsiveWorkspace) {",
        "const fixed = Object.assign({}, baselineRects)",
        "fixed[activeId] = root._fitRectToCanvas(",
        "const probe = Object.assign({}, baselineRects)",
        "probe[activeId] = root._fitRectToCanvas(",
    )
    for marker in required:
        if marker not in source:
            raise AssertionError(f"Dashboard responsive-overlap source contract lost {marker!r}")

    ids_match = re.search(
        r"readonly property var _allIds:\s*\[(.*?)\]",
        source,
        flags=re.S,
    )
    if not ids_match:
        raise AssertionError("Dashboard _allIds literal is no longer statically auditable")
    ids = re.findall(r'"([^"]+)"', ids_match.group(1))
    if not ids or len(ids) != len(set(ids)):
        raise AssertionError("Dashboard production _allIds must remain a unique literal list")


NODE_ORACLE = r"""
"use strict";

function sameRect(a,b) {
    return a && b && ["x","y","width","height"].every(
        key => Math.abs(a[key]-b[key]) < 0.001);
}
function rectsOverlap(a,b,gap) {
    const g=Number(gap ?? 0);
    return a.x < b.x+b.width+g
        && a.x+a.width+g > b.x
        && a.y < b.y+b.height+g
        && a.y+a.height+g > b.y;
}
function generic(visibleIds,rects,baselineRects,gap) {
    const ids=[], pairs=[];
    for (let i=0;i<visibleIds.length;++i) {
        const id=String(visibleIds[i]);
        if (rects[id]) ids.push(id);
    }
    for (let i=0;i<ids.length;++i) {
        for (let j=i+1;j<ids.length;++j) {
            const left=ids[i], right=ids[j];
            pairs.push(left+"|"+right);
            if (!rectsOverlap(rects[left],rects[right],gap)) continue;
            if (baselineRects
                    && sameRect(rects[left],baselineRects[left])
                    && sameRect(rects[right],baselineRects[right]))
                continue;
            return {value:true,pairs};
        }
    }
    return {value:false,pairs};
}
function finitePlainRect(rect) {
    return !!rect
        && typeof rect.x==="number" && Number.isFinite(rect.x)
        && typeof rect.y==="number" && Number.isFinite(rect.y)
        && typeof rect.width==="number" && Number.isFinite(rect.width)
        && typeof rect.height==="number" && Number.isFinite(rect.height);
}
function proposed(visibleIds,rects,baselineRects,activeId,gap,plainSnapshot) {
    if (plainSnapshot !== true || typeof activeId !== "string"
            || typeof gap !== "number" || !Number.isFinite(gap)
            || !baselineRects)
        return Object.assign({fast:false},generic(visibleIds,rects,baselineRects,gap));

    const ids=[], seen=Object.create(null);
    let activeIndex=-1;
    for (let i=0;i<visibleIds.length;++i) {
        const id=String(visibleIds[i]);
        const rect=rects[id];
        if (!rect) continue;
        if (Object.prototype.hasOwnProperty.call(seen,id))
            return Object.assign({fast:false},generic(visibleIds,rects,baselineRects,gap));
        seen[id]=true;
        const base=baselineRects[id];
        if (!finitePlainRect(rect) || !finitePlainRect(base)
                || (id!==activeId && rect!==base))
            return Object.assign({fast:false},generic(visibleIds,rects,baselineRects,gap));
        if (id===activeId) activeIndex=ids.length;
        ids.push(id);
    }
    if (activeIndex<0)
        return Object.assign({fast:false},generic(visibleIds,rects,baselineRects,gap));

    const pairs=[];
    function pair(left,right) {
        pairs.push(left+"|"+right);
        if (!rectsOverlap(rects[left],rects[right],gap)) return false;
        if (sameRect(rects[left],baselineRects[left])
                && sameRect(rects[right],baselineRects[right]))
            return false;
        return true;
    }
    const active=ids[activeIndex];
    for (let i=0;i<activeIndex;++i)
        if (pair(ids[i],active)) return {value:true,pairs,fast:true};
    for (let j=activeIndex+1;j<ids.length;++j)
        if (pair(active,ids[j])) return {value:true,pairs,fast:true};
    return {value:false,pairs,fast:true};
}

function assert(cond,msg) { if(!cond) throw new Error(msg); }
function checkParity(name,visibleIds,baseline,rects,active,gap,plain,expectFast) {
    const oldResult=generic(visibleIds,rects,baseline,gap);
    const nextResult=proposed(visibleIds,rects,baseline,active,gap,plain);
    assert(oldResult.value===nextResult.value,name+": result mismatch");
    assert(nextResult.fast===expectFast,name+": unexpected fast/fallback route");
    if (expectFast) {
        const activePairs=oldResult.pairs.filter(p => {
            const [a,b]=p.split("|");
            return a===active || b===active;
        });
        assert(JSON.stringify(activePairs)===JSON.stringify(nextResult.pairs),
            name+": active-pair order changed");
        assert(nextResult.pairs.length<=Math.max(0,visibleIds.length-1),
            name+": fast path checked too many pairs");
    } else {
        assert(JSON.stringify(oldResult.pairs)===JSON.stringify(nextResult.pairs),
            name+": fallback pair order changed");
    }
    return {oldPairs:oldResult.pairs.length,newPairs:nextResult.pairs.length};
}

let seed=0x5eed1234;
function rnd() {
    seed=(Math.imul(seed,1664525)+1013904223)>>>0;
    return seed/0x100000000;
}
function rint(n) { return Math.floor(rnd()*n); }
function makeRect() {
    const maybeNegZero = () => rnd()<0.04 ? -0 : Math.round((rnd()*700-50)*1000)/1000;
    return {
        x:maybeNegZero(), y:maybeNegZero(),
        width:Math.round((20+rnd()*240)*1000)/1000,
        height:Math.round((20+rnd()*180)*1000)/1000
    };
}

let cases=0,oldPairs=0,newPairs=0;
for (let n=0;n<20000;++n) {
    const count=1+rint(11);
    const ids=[];
    const baseline={};
    for (let i=0;i<count;++i) {
        const id="w"+i;
        ids.push(id);
        baseline[id]=makeRect();
    }
    const active=ids[rint(ids.length)];
    const rects=Object.assign({},baseline);
    rects[active]=rnd()<0.18 ? baseline[active] : makeRect();
    const gap=Math.round((rnd()*20)*1000)/1000;
    const out=checkParity("finite-"+n,ids,baseline,rects,active,gap,true,true);
    oldPairs+=out.oldPairs; newPairs+=out.newPairs; cases++;
}

// Pre-existing legacy overlap among unchanged non-active cards must stay exempt.
{
    const ids=["a","b","c"];
    const baseline={
        a:{x:0,y:0,width:100,height:100},
        b:{x:20,y:20,width:100,height:100},
        c:{x:400,y:400,width:80,height:80}
    };
    const rects=Object.assign({},baseline);
    rects.c={x:520,y:400,width:80,height:80};
    checkParity("legacy-overlap",ids,baseline,rects,"c",0,true,true); cases++;
}

// Malformed or non-proven states must take the exact generic fallback.
const malformed=[];
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    malformed.push(["plain-flag-false",["a","b"],b,r,"a",0,false]);
}
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:Infinity,height:10}};
    const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    malformed.push(["infinity",["a","b"],b,r,"a",0,true]);
}
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    b.b.y=NaN; const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    malformed.push(["nan",["a","b"],b,r,"a",0,true]);
}
{
    const b={a:{x:0,y:0,width:10,height:10}};
    const r={a:{x:1,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    malformed.push(["visibility-added-id",["a","b"],b,r,"a",0,true]);
}
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    malformed.push(["active-hidden",["b"],b,r,"a",0,true]);
}
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    malformed.push(["duplicate-key",["a","b","b"],b,r,"a",0,true]);
}
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    r.b={x:20,y:0,width:10,height:10};
    malformed.push(["nonactive-replaced",["a","b"],b,r,"a",0,true]);
}
{
    const b={a:{x:0,y:0,width:10,height:10},b:{x:20,y:0,width:10,height:10}};
    const r=Object.assign({},b); r.a={x:1,y:0,width:10,height:10};
    malformed.push(["nonfinite-gap",["a","b"],b,r,"a",Infinity,true]);
}
for (const [name,ids,b,r,a,g,plain] of malformed) {
    checkParity(name,ids,b,r,a,g,plain,false); cases++;
}

// Getter-backed inputs are never eligible: fallback must preserve exact read order.
{
    const logOld=[], logNew=[];
    function proxyRect(log,label,raw) {
        return new Proxy(raw,{get(target,key) {
            if (["x","y","width","height"].includes(String(key)))
                log.push(label+"."+String(key));
            return target[key];
        }});
    }
    function fixture(log) {
        const b={
            a:proxyRect(log,"ba",{x:0,y:0,width:10,height:10}),
            b:proxyRect(log,"bb",{x:8,y:0,width:10,height:10})
        };
        const r={a:proxyRect(log,"ra",{x:1,y:0,width:10,height:10}),b:b.b};
        return {b,r};
    }
    const f1=fixture(logOld), f2=fixture(logNew);
    const oldResult=generic(["a","b"],f1.r,f1.b,0);
    const nextResult=proposed(["a","b"],f2.r,f2.b,"a",0,false);
    assert(oldResult.value===nextResult.value,"getter fallback result mismatch");
    assert(nextResult.fast===false,"getter fallback unexpectedly fast");
    assert(JSON.stringify(logOld)===JSON.stringify(logNew),
        "getter fallback property-read order changed");
    cases++;
}

console.log(JSON.stringify({
    pass:true,
    cases,
    finiteCases:20000,
    genericPairChecks:oldPairs,
    fastPairChecks:newPairs
}));
"""


def main() -> None:
    source = CANVAS.read_text(encoding="utf-8")
    require_source_contract(source)
    proc = subprocess.run(
        ["node", "-e", NODE_ORACLE],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=True,
    )
    result = json.loads(proc.stdout)
    if not result.get("pass"):
        raise AssertionError("responsive overlap parity oracle did not pass")
    if result["fastPairChecks"] >= result["genericPairChecks"]:
        raise AssertionError("oracle did not demonstrate a collision-pair reduction")
    print(
        "Dashboard responsive overlap parity: PASS "
        f"cases={result['cases']} "
        f"generic_pairs={result['genericPairChecks']} "
        f"fast_pairs={result['fastPairChecks']}"
    )


if __name__ == "__main__":
    main()
