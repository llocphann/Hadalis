#!/usr/bin/env python3
"""Frozen/new snapshot interpreter parity with no retained unused folders."""
import json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'services/LocalMusic.qml').read_text()
functions='\n'.join(re.search(r'^    function '+name+r'\(.*?^    }',source,re.M|re.S)[0] for name in ['_applyCurrentTrack','_applyPayload'])
old=json.loads((ROOT/'scripts/fixtures/local-music-folder-reference.json').read_text())['functions']
program=r'''
const vm=require('node:vm'),assert=require('node:assert/strict');
const initial={mpdConnected:false,error:'before',mpdHost:'owned-fixture',mpdPort:6600,detectedLibraryFolder:'old-root',libraryTracks:[],playlists:[],activeQueue:[],mpdState:'stop',currentIndex:-1,resumeIndex:-1,currentPosition:0,currentDuration:0,volume:.5,shuffleMode:false,repeatMode:0,currentUri:'',currentPath:'',currentTitle:'',currentArtist:'',currentAlbum:'',currentArt:''};
const keys=Object.keys(initial);
function normalize(v){if(Array.isArray(v))return Array.from(v,normalize);if(v && typeof v==='object')return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,normalize(x)]));return v}
function context(source,legacy){const c=JSON.parse(JSON.stringify(initial));c.calls=[];c.MprisController={ensureMpdMprisBridge:(...args)=>c.calls.push(args)};if(legacy)c.folderCollections=[];vm.createContext(c);vm.runInContext(source.replace(/\): void \{/g,') {'),c);return c;}
let cases=0;
for(const size of [0,1,16,5000])for(const includeLibrary of [false,true])for(const state of ['play','pause','stop'])for(const song of [-1,0,size-1,size+1]){
 const tracks=Array.from({length:size},(_,i)=>({uri:`same/${i%3}/album/${i}.flac`,path:`/owned/Music/${i%3}/${i}.flac`,title:`track ${i}`,artist:'artist',album:'album',duration:i+1}));
 const folders=Array.from({length:3},(_,i)=>({path:`same/${i}/album`,tracks:tracks.filter((_,j)=>j%3===i).map(t=>({...t}))}));
 const payload={connected:true,musicRoot:'/owned/Music',tracks,playlists:[{name:'list',tracks}],queue:tracks,status:{state,song,elapsed:12,duration:130,volume:73,random:'1',repeat:'1',single:'0'}};
 let reads=0;Object.defineProperty(payload,'folders',{get(){reads++;return folders}});
 const before=context(OLD,true),after=context(NEW,false);
 before._applyPayload(payload,includeLibrary);const legacyReads=reads;reads=0;after._applyPayload(payload,includeLibrary);
 for(const key of keys)assert.deepEqual(normalize(after[key]),normalize(before[key]),`changed ${key} at ${size}/${state}/${song}`);
 assert.deepEqual(after.calls,before.calls);assert.equal(reads,0,'candidate read unused folders');assert.equal(legacyReads,includeLibrary?1:0);
 if(includeLibrary){assert.equal(after.libraryTracks,payload.tracks);assert.equal(after.playlists,payload.playlists);assert.equal(before.folderCollections,folders)}
 assert.equal(after.activeQueue,payload.queue);assert(!Object.hasOwn(after,'folderCollections'),'unused folder tree remains rooted');cases++;
}
for(const payload of [null,{connected:false,error:'offline'},{connected:true},{connected:true,current:{uri:'radio://owned',title:'Stream'},status:{state:'play',song:-1}}]){
 const before=context(OLD,true),after=context(NEW,false);before._applyPayload(payload,true);after._applyPayload(payload,true);
 for(const key of keys)assert.deepEqual(normalize(after[key]),normalize(before[key]));assert.deepEqual(after.calls,before.calls);cases++;
}
console.log('LOCAL_MUSIC_FOLDER_PASS',cases,'snapshot states and array identities; zero unused-folder reads/roots; protocol unchanged');
'''
subprocess.run(['node','-e','const OLD='+json.dumps(old)+';const NEW='+json.dumps(functions)+';\n'+program],check=True,cwd=ROOT)
