#!/usr/bin/env node
// Execute the actual scene API against registered surface and collision data.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
function load(name,imports={}){const c=vm.createContext(imports);vm.runInContext(fs.readFileSync(`modules/abyss/companion/${name}.js`,'utf8').replace(/^\.(?:pragma|import).*\n/gm,''),c);return c;}
const api=load('WullScene',{Slots:load('WullSurfacePlacement')});
const base={width:1280,height:820,scale:1,hostWidth:112,hostHeight:98,rimRadius:16,insets:{top:20,right:20,bottom:20,left:20}};
const plain=v=>JSON.parse(JSON.stringify(v));
// Production tray/Bar layout keeps hidden modules as zero-span records. Their
// presence must not suppress emergence, while painted neighbours still block.
for(const edge of ['top','bottom','left','right']) {
    const modules=[{edge,along:100,span:220},{edge,along:340,span:0},{edge,along:400,span:0}];
    const scene=api.fromParticipants(base,{},modules);
    assert.equal(api.valid(scene),true,'collapsed modules must not invalidate the output');
    assert.equal(scene.records.length,3,'retain validation of every layout record');
    assert.equal(scene.blockers.length,1,'only painted area blocks Wull');
    for(const scale of [.65,1,1.6]) {
        const scaled=api.fromParticipants({...base,scale,hostWidth:112*scale,hostHeight:98*scale},{},modules);
        for(let i=0;i<4;i++) {
            const p=api.appearance(scaled,.8,(i+.1)/4,.5);
            assert.equal(p.qualified,true);assert.equal(api.clearAt(scaled,p),true);
        }
    }
    for(const span of [-1,NaN,Infinity])
        assert.equal(api.valid(api.fromParticipants(base,{},[{edge,along:340,span}])),false,
            'malformed spans still fail closed');
    assert.equal(api.valid(api.fromParticipants(base,{},[{edge,along:NaN,span:0}])),false,
        'an empty record cannot bypass validation');
    const noDepth=api.fromParticipants({...base,insets:{...base.insets,[edge]:0}}, {},modules);
    assert.equal(api.valid(noDepth),true);assert.equal(noDepth.blockers.length,0);
}
let contacts=0;
for(const key of ['dock','settings','leftPanel','rightPanel','styledPopup0','popup','aux','clipboard','controls','dashboard','utility','notification','toast','osd','futureIpcBody']){
    for(const edge of ['top','bottom','left','right']){
        const rect={x:400,y:310,width:440,height:260};
        const participant={surfaceSettled:true,geometry:{edge,progress:1,surface:rect},inputBounds:{x:416,y:326,width:408,height:228}};
        const scene=api.fromParticipants(base,{[key]:participant},[]);
        assert.equal(api.valid(scene),true);assert.equal(scene.surfaces.length,1);
        const painted=scene.surfaces[0].rect;
        assert.deepEqual({x:painted.x,y:painted.y,width:painted.width,height:painted.height},rect,'use painted glass, not inset input bounds');
        const places=api.surfacePoints(scene);assert.equal(places.length,4);
        for(const p of places){
            assert.equal(api.clearAt(scene,p),true);assert.equal(p.key,key);
            const c=p.contact;assert.ok(c,'every appearance touches its actual water boundary');
            assert.equal(c.key,key);assert.equal(Math.hypot(c.nx,c.ny),1);
            assert.equal(c.sourceEdge,edge);assert.equal(c.sourceAlong,edge==='top'||edge==='bottom'?c.x:c.y);
            assert.ok([rect.x,rect.x+rect.width].includes(c.x)||[rect.y,rect.y+rect.height].includes(c.y));
            const exit=api.nearestWater(scene,p);assert.equal(exit.placement.key,key);
            assert.equal(exit.route.distance,0,'a body rim is water for disappearance too');contacts++;
        }
        const top=places.find(p=>p.edge==='bottom');assert.equal(top.grounded,true);
        const target=api.annotate(scene,{x:top.x+55,y:top.y},top.edge,top.kind,top.key);
        assert.equal(api.path(scene,top,target).mode,'walk');assert.equal(target.contact.x,top.contact.x+55);
        const corner=api.annotate(scene,{x:rect.x,y:top.y},'bottom','surface',key);
        assert.equal(corner.grounded,false,'rounded corners are not continuous horizontal support');
        const air=api.drop(scene,60,210,{x:60,y:210});assert.equal(air.contact,null);
        participant.surfaceSettled=false;
        const moving=api.fromParticipants(base,{[key]:participant},[]);
        assert.equal(moving.surfaces.length,1,'moving water remains available for carrying its existing actor');
        assert.equal(moving.surfaces[0].settled,false);
        assert.equal(moving.blockers.length,1,'entry/exit remains an obstacle');
        assert.equal(api.surfacePoints(moving).length,0,'do not choose a new visit on an unsettled body');
        assert.ok(api.supportAt(moving,top),'retain support for an actor already riding this rim');
        participant.geometry.progress=0;
        participant.geometry.surface={...rect,height:0};
        assert.equal(api.fromParticipants(base,{[key]:participant},[]).blockers.length,0);
    }
}
for(const edge of ['top','right','bottom','left']){
    const scene=api.fromParticipants(base,{},[]),p=api.edgePoint(scene,edge,.5);
    assert.equal(p.contact.key,edge);assert.equal(Math.hypot(p.contact.nx,p.contact.ny),1);contacts++;
}
const crowded=Object.fromEntries(Array.from({length:41},(_,i)=>['body'+i,{}]));
assert.equal(api.valid(api.fromParticipants(base,crowded,[])),false,'capacity overflow fails closed');
assert.equal(api.valid(api.fromParticipants(base,{broken:{geometry:{progress:1,edge:'top',surface:{x:5,y:NaN,width:3,height:3}}}},[])),false,'invalid visible geometry fails closed');
assert.equal(api.fromParticipants(base,{ipc:{geometry:{edge:'top',surface:{x:100,y:300,width:300,height:100}}}},[]).blockers.length,1,'custom visible IPC geometry blocks even without progress metadata');
for(const scale of [.65,1,1.6]){
    const scene=api.fromParticipants({...base,scale,hostWidth:112*scale,hostHeight:98*scale},
        {dock:{surfaceSettled:true,geometry:{edge:'bottom',progress:1,surface:{x:400,y:680,width:480,height:100}}}},[]);
    const top=api.surfacePoints(scene).find(p=>p.edge==='bottom');assert.ok(top);assert.equal(top.grounded,true);assert.ok(top.contact);
}
const full={surfaceSettled:true,geometry:{edge:'bottom',progress:1,surface:{x:0,y:0,width:1280,height:820}}};
assert.equal(api.appearance(api.fromParticipants(base,{settings:full},[]),0,0,.5).qualified,false,'do not cover full-screen content to force an appearance');
// Evaluate the actual QML hold expression. No speculative model of the Dock's
// visibility decision, and no native-window/source-mask claim.
const perimeter=fs.readFileSync('modules/abyss/AbyssPerimeter.qml','utf8');
const expression=perimeter.match(/readonly property bool companionDockHeld: ([\s\S]*?)\n\s*readonly property string dockEdge:/)[1];
function dockHeld(ready,visible,placement,destination={},traveling=false){return vm.runInNewContext(expression,{companionBridge:{ready},companion:{visible},companionPresence:{placement,destination,traveling}});}
assert.equal(dockHeld(true,true,{key:'dock'}),true);
assert.equal(dockHeld(true,true,{key:'drop',support:{key:'dock'}}),true);
assert.equal(dockHeld(true,true,{key:'top'},{key:'dock'},true),true);
assert.equal(dockHeld(true,true,{key:'top'},{key:'dock'},false),false);
assert.equal(dockHeld(true,false,{key:'dock'}),false);
assert.equal(dockHeld(false,true,{key:'dock'}),false);
const permission=perimeter.match(/readonly property bool companionPermission: ([\s\S]*?)\n\s*readonly property bool companionHostActive:/)[1];
function fieldPermission(count,capacity=40){return vm.runInNewContext(permission,{
    WullHostPolicy:{hostActive:()=>true},root:{},companionBridge:{},window:{companionOccluded:false},
    liquid:{records:Array(count)},field:{capacity}});}
assert.equal(fieldPermission(39),true);
assert.equal(fieldPermission(40),true);
assert.equal(fieldPermission(41),false,'never visit a body beyond the actual painted field capacity');
assert.equal(fieldPermission(2,1),false,'use the field capacity, not a duplicate fixed budget');
console.log(`WULL_SHARED_ABYSS_REGISTRY_CONTACT_SUPPORT_AND_RETREAT_PASS contacts=${contacts}`);
