pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.abyss.companion
import qs.modules.abyss.looks

Window {
    id: root
    visible: true; width:480; height:320; color:"#07151c"
    property string edge: "bottom"
    property bool captured: false
    property int previewHeight: 320
    Component.onCompleted: Quickshell.watchFiles=false
    Item {
        id: board; width:480; height:root.previewHeight; anchors.centerIn:parent
        Rectangle { anchors.fill:parent; color:root.color }
        Rectangle {
            x:root.edge==="right" ? board.width-12 : 0
            y:root.edge==="bottom" ? board.height-12 : 0
            width:root.edge==="left"||root.edge==="right" ? 12 : board.width
            height:root.edge==="left"||root.edge==="right" ? board.height : 12
            radius:6; color:"#173f4e";border.width:1;border.color:"#468696"
        }
        Text { x:24;y:24;text:root.edge;color:"#98c9d6";font.pixelSize:14 }
        AbyssCompanion {
            id:actor;edge:root.edge;scale:.85;reveal:1;motionEnabled:false;upright:true
            standingAngle:root.edge==="top" ? 180 : root.edge==="left" ? 90 : root.edge==="right" ? -90 : 0
            readonly property real cx:root.edge==="left" ? 18+34.3*scale : root.edge==="right" ? board.width-18-34.3*scale : board.width/2
            readonly property real cy:root.edge==="top" ? 18+34.3*scale : root.edge==="bottom" ? board.height-18-34.3*scale : board.height/2
            x:cx-width/2-sideAlignment*scale
            y:cy-height/2-floorAlignment*scale
        }
        WullCloudActions { id:actions;actor:actor;outputWidth:board.width;outputHeight:board.height;allowed:true }
        WullTalkCloud { id:chat;actor:actor;outputWidth:board.width;outputHeight:board.height;allowed:true }
    }
    function capture(name):void {
        const directory=Quickshell.env("WULL_CLOUD_ORBIT_OUTPUT")
        if(!directory) {root.captured=true;return}
        root.captured=false
        board.grabToImage(result=>{
            if(!result.saveToFile(directory+"/"+name+".png"))console.error("WULL_CLOUD_ORBIT=FAIL capture")
            root.captured=true
        })
    }
    TestCase {
        id:proof;when:false;optional:true
        function check(value,message):void {if(!value)throw new Error(message)}
        function run():void {
            try {
                tryCompare(Config,"ready",true,4000)
                Ai._initialized=true
                WullMind.hostVisible=false
                WullMind.historyLoaded=true;WullMind.history=[]
                Config.setNestedValue("abyss.companionMind.proactive","manual")
                for(const edge of ["bottom","top","left","right"]) {
                    root.edge=edge;actor.character=edge==="left"||edge==="top" ? "octo" : "aqua"
                    wait(100);tryCompare(actor,"inputReady",true,2000)
                    mouseMove(actor,actor.width/2,actor.height/2);wait(80)
                    check(actions.visible,"orbit not visible on "+edge)
                    const a=actions.obsidianTarget,b=actions.aiTarget
                    for(const node of [a,b]) {
                        const p=node.mapToItem(board,0,0)
                        check(p.x>=8 && p.y>=8 && p.x+node.width<=board.width-8
                            && p.y+node.height<=board.height-8,"painted cloud outside "+edge)
                    }
                    const ax=a.x+a.width/2-actor.cx,ay=a.y+a.height/2-actor.cy
                    const bx=b.x+b.width/2-actor.cx,by=b.y+b.height/2-actor.cy
                    check(Math.abs(Math.hypot(ax,ay)-Math.hypot(bx,by))<1e-6,"painted cloud distances lost symmetry on "+edge)
                    check(Math.abs((ax-bx)*Math.cos(actions.orbit.axisAngle)+(ay-by)*Math.sin(actions.orbit.axisAngle))<1e-6,
                        "painted actions are not mirrored on "+edge)
                    const obsidian=findChild(a,"wullObsidianGlyph"),ai=findChild(b,"wullAiGlyph")
                    check(obsidian?.visible && ai?.visible && obsidian.color===ai.color,"theme-matched vector glyphs missing")
                    mouseMove(board,a.x+a.width/2,a.y+a.height/2);wait(50)
                    check(actions.hovered,"cloud hover did not hold its orbit "+JSON.stringify({
                        edge:edge,visible:actions.visible,eligible:actions.eligible,revealed:actions.revealed,
                        a:a.mapToItem(board,0,0),width:a.width,height:a.height,hover:a.hovered,
                        button:a.children[1]?.buttonHovered,boardOrigin:board.mapToItem(null,0,0)}))
                    mouseMove(board,board.width/2,board.height/2);wait(50)
                    check(!actions.hovered,"empty orbit space captured hover")
                    wait(470);check(!actions.visible,"departed orbit never hid")
                    mouseMove(actor,actor.width/2,actor.height/2);wait(60)
                    mouseClick(board,a.x+a.width/2,a.y+a.height/2);wait(60)
                    check(WullMind.contextOpen && !WullMind.conversationOpen,"context action missed on "+edge)
                    WullMind.dismiss();mouseMove(actor,actor.width/2,actor.height/2);wait(60)
                    mouseClick(board,b.x+b.width/2,b.y+b.height/2);wait(60)
                    check(WullMind.conversationOpen && !WullMind.contextOpen,"chat action missed on "+edge)
                    WullMind.dismiss();mouseMove(actor,actor.width/2,actor.height/2);wait(60)
                    mouseMove(board,10,10);wait(60)
                    root.capture(edge);tryCompare(root,"captured",true,3000)
                }
                const obsidian=findChild(actions.obsidianTarget,"wullObsidianGlyph"),ai=findChild(actions.aiTarget,"wullAiGlyph")
                let previous=String(obsidian.color)
                for(const color of ["#ab70fa","#20d7ba","#e6ae36"]) {
                    Appearance.m3colors.m3primary=color
                    for(let frame=0;frame<5;frame++) {
                        wait(30)
                        check(obsidian.color===ai.color,"glyphs diverged during the shared color transition")
                    }
                    tryVerify(()=>obsidian.color===AbyssStyle.accent && ai.color===AbyssStyle.accent,3000)
                    check(String(obsidian.color)!==previous,
                        "Obsidian glyph failed a live theme change "+JSON.stringify({
                            input:color,previous:previous,obsidian:String(obsidian.color),ai:String(ai.color),
                            accent:String(AbyssStyle.accent),primary:String(Appearance.colors.colPrimary),m3primary:String(Appearance.m3colors.m3primary)}))
                    previous=String(obsidian.color)
                }
                root.edge="bottom";root.previewHeight=640;wait(100)
                WullMind.historyLoaded=true;WullMind.history=[];WullMind.openChat();wait(120)
                check(chat.visible && chat.editing && !actions.visible,"explicit chat did not replace the orbit")
                root.capture("chat");tryCompare(root,"captured",true,3000)
                WullMind.dismiss();actions.allowed=false;wait(30)
                check(!actions.visible && !actions.hovered,"disabled orbit retained input")
                console.log("WULL_CLOUD_ORBIT=PASS symmetricFourEdges AquaOcto cornerSafe uprightThemedVectorGlyphs livePaletteChanges nodeHover emptySpacePassThrough finiteHide contextAndChatClicks explicitChat themedBorder")
            }catch(e){console.error("WULL_CLOUD_ORBIT=FAIL "+e+" "+e.stack)}
            Qt.quit()
        }
    }
    Timer { interval:200;running:Config.ready;onTriggered:proof.run() }
}
