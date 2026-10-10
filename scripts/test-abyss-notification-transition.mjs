#!/usr/bin/env node
// Regression for the *actual* Abyss transient banner QML expressions.
// This runs without Qt: native presentation/performance acceptance is separate.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>readFileSync(resolve(root,p),'utf8');
const source=read('modules/abyss/AbyssPerimeter.qml');
const bannerContent=read('modules/abyss/content/AbyssNotificationsContent.qml');
const centerPopup=read('modules/notificationCenter/NotificationCenterPopup.qml');
const corners=read('modules/abyss/AbyssCorners.qml');

const start=source.indexOf('id: notification\n');
const end=source.indexOf('id: toastBody\n',start);
assert.ok(start>=0 && end>start,'live transient banner host is missing');
const banner=source.slice(start,end);
function expression(before,after) {
    const a=banner.indexOf(before);
    assert.ok(a>=0,'missing banner QML property '+before);
    const b=banner.indexOf(after,a+before.length);
    assert.ok(b>a,'missing expression delimiter '+after);
    return banner.slice(a+before.length,b).trim();
}
const expressions={
    position:expression('readonly property string position:','\n                readonly property string presentationKind:'),
    kind:expression('readonly property string presentationKind:','\n                edge:'),
    edge:expression('\n                edge:','\n                joinedEdge:'),
    open:expression('\n                open:','\n                edgeInsets:'),
    width:expression('readonly property real contentWidth:','\n                readonly property real contentHeight:'),
    height:expression('readonly property real contentHeight:','\n                span:'),
    span:expression('\n                span:','\n                along:'),
    along:expression('\n                along:','\n                depth:'),
    depth:expression('\n                depth:','\n                obstacles:'),
    contentKind:expression('\n                contentKind:','\n                source:')
};
const functions=Object.fromEntries(Object.entries(expressions).map(([key,code])=>[
    key,new Function('Config','GlobalStates','Notifications','window',
        'Appearance','padding','contentItem','field','Geometry','Quickshell',
        'position','presentationKind','edge','span','contentWidth','contentHeight',
        'return ('+code+');')]));
let tests=0;
function same(label,actual,expected) {
    assert.deepEqual(actual,expected,label);
    ++tests;
}
function state({centerOpen=false,toastCount=1,toastHeight=130,
    position='topRight',customCenterWidth=420,customCenterHeight=560,
    outputName='eDP-1'}={}) {
    const config={options:{
        panelFamily:'abyss',enabledPanels:['abyssNotificationPopup','abyssNotificationCenter'],
        notifications:{position,screenList:[]},
        notificationCenter:{popupWidth:customCenterWidth,popupHeight:customCenterHeight}
    }};
    const gs={notificationCenterOpen:centerOpen,
        notificationCenterPresentationOutput:outputName};
    const notification={popupInhibited:centerOpen,popupList:Array(toastCount).fill({})};
    const window={presented:true,outputName,width:1920,height:1200,
        nativeInsets:{left:16,right:16,top:16,bottom:16},
        positionEdge:(_kind,fallback)=>fallback,
        positionAlong:(_kind,_edge,_span,fallback)=>fallback};
    const ctx=[config,gs,notification,window,
        {sizes:{notificationPopupWidth:360}},14,
        {item:{desiredWidth:360,desiredHeight:toastHeight}},
        {ready:true},{horizontal:e=>e==='top'||e==='bottom',
            targets:()=>true},
        {screens:[{name:'eDP-1'}]}];
    function value(which,...additional){return functions[which](...ctx,...additional)}
    const side=value('position'),kind=value('kind'),edge=value('edge',side,kind);
    const width=value('width',side,kind,edge);
    const height=value('height',side,kind,edge);
    const span=value('span',side,kind,edge,0,width,height);
    return {position:side,kind,edge,width,height,span,
        depth:value('depth',side,kind,edge,span,width,height),
        along:value('along',side,kind,edge,span,width,height),
        contentKind:value('contentKind',side,kind,edge,span,width,height),
        open:value('open',side,kind,edge,span,width,height)};
}
const normal=state();
const openingCenter=state({centerOpen:true});
same('toast visible before center opens',normal.open,true);
same('center open dismisses toast request',openingCenter.open,false);
for(const prop of ['position','kind','edge','width','height','span','depth','along','contentKind']) {
    same('opening center MUST NOT mutate closing toast '+prop,openingCenter[prop],normal[prop]);
}
same('transient notification still uses small popup renderer',normal.contentKind,'popup');
same('live top-right banner height',normal.height,158);
same('live banner attaches to top',normal.edge,'top');
const custom=state({centerOpen:true,customCenterWidth:760,customCenterHeight:900});
for(const prop of ['width','height','span','depth','along']) {
    same('custom center size MUST NOT alter closing notification '+prop,custom[prop],normal[prop]);
}
const bottom=state({position:'bottomLeft'});
same('bottom-left banner is still bottom-edge anchored',bottom.edge,'bottom');
same('bottom-left banner begins at 40px tangent margin',bottom.along,40);
same('bottom-left banner stays popup content',bottom.contentKind,'popup');
const noToast=state({toastCount:0});
same('empty banner list cannot leave phantom notification open',noToast.open,false);
const many=state({toastCount:3,toastHeight:320});
same('multi-notification banner height follows its own content',many.height,348);
same('center does not alter multi-notification banner height',
    state({centerOpen:true,toastCount:3,toastHeight:320}).height,348);
same('notification entry is a stable-content-size clipped host',
    banner.includes('stableContentSize: true'),true);
same('no center/tall-screen branch remains in banner host',
    !banner.includes('centerOnOutput') && !banner.includes('contentKind: centerOnOutput'),
    true);
same('banner Loader only switches to center on kind=center',
    bannerContent.includes('readonly property bool center: kind === "center"'),true);
same('banner does not instantiate history center Loader',
    normal.contentKind==='popup' && bannerContent.includes('active: root.center'),true);
same('actual separately-owned Notification Center remains present',
    corners.includes('NotificationCenterPopup {'),true);
same('custom Notification Center width still binds to public setting',
    centerPopup.includes('Config.options?.notificationCenter?.popupWidth ?? 420'),true);
same('custom Notification Center height still binds to public setting',
    centerPopup.includes('Config.options?.notificationCenter?.popupHeight ?? 560'),true);
console.log('PASS: '+tests+' source-executed Abyss Notification Center transition assertions');
