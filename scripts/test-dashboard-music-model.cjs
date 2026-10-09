const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const model=vm.createContext({});
vm.runInContext(fs.readFileSync('modules/dashboard/DashboardMusicModel.js','utf8').replace(/^\.pragma library\s*/,''),model);
const tracks=Object.freeze([
 Object.freeze({uri:'Jazz/Live/one.flac',folder:'Jazz/Live',title:'One',genre:'Jazz; Fusion'}),
 Object.freeze({uri:'Jazz/two.flac',folder:'Jazz',title:'Two',genre:['Jazz','Jazz']}),
 Object.freeze({uri:'Jazzical/three.flac',folder:'Jazzical',title:'Three',genre:'Classical'}),
 Object.freeze({uri:'__proto__/四.flac',folder:'__proto__',title:'四',genre:''}),
 Object.freeze({uri:'root.flac',folder:'',title:'Root',genre:'Jazz'})
]);
const json=value=>JSON.parse(JSON.stringify(value));
assert.equal(model.results(tracks,'','','').length,0,'results must start empty');
assert.deepEqual(json(model.genres(tracks)).find(x=>x.key==='Jazz'),{key:'Jazz',count:3});
assert.equal(model.results(tracks,'genre','Jazz','').length,3);
assert.equal(model.results(tracks,'genre','','').length,1);
assert.deepEqual(json(model.results(tracks,'genre',['Jazz','Fusion'],'')).map(e=>e.track.uri),
 ['Jazz/Live/one.flac','Jazz/two.flac','root.flac'],'genre union preserves order without duplicate tracks');
assert.equal(model.results(tracks,'genre',[],'').length,0,'deselected genres leave no phantom results');
assert.equal(model.results(tracks,'genre',[''],'').length,1,'unknown genre is a selectable value');
assert.deepEqual(json(model.results(tracks,'folder','',['Jazz','Jazz/Live'])).map(model.key),
 ['d:Jazz/Live','t:Jazz/two.flac','t:Jazz/Live/one.flac']);
assert.equal(model.results(tracks,'folder','',[]).length,0,'deselected folders leave no phantom results');
let sources=model.selectValues(['','Jazz','Rock'],[],-1,0,false,false);
sources=model.selectValues(['','Jazz','Rock'],sources.keys,sources.anchor,2,true,false);
assert.deepEqual(json(sources.keys),['','Rock'],'Ctrl supports unknown/root values');
sources=model.selectValues(['','Jazz','Rock'],sources.keys,sources.anchor,0,false,true);
assert.deepEqual(json(sources.keys),['','Jazz','Rock'],'Shift selects a source range');
sources=model.selectValues(['','Jazz','Rock'],sources.keys,sources.anchor,1,true,false);
assert.deepEqual(json(sources.keys),['','Rock'],'Ctrl deselects only the clicked source');
const jazz=json(model.contents(tracks,'/Jazz/'));
assert.deepEqual(jazz.map(x=>x.kind),['folder','track']);
assert.equal(jazz[0].path,'Jazz/Live');assert.equal(jazz[1].track.uri,'Jazz/two.flac');
assert.equal(model.contents(tracks,'Jazz/Live')[0].track,tracks[0],'keep track identity for playback');
assert.equal(model.contents(tracks,'Jazz').some(x=>x.name==='Three'),false,'prefix sibling must stay out');
assert.ok(model.roots(tracks).some(x=>x.path==='__proto__'),'path keys must not become object prototypes');
assert.ok(model.roots(tracks).some(x=>x.path===''),'root files remain reachable');
assert.equal(model.parent('Jazz/Live'),'Jazz');assert.equal(model.parent('Jazz'),'');
assert.deepEqual(json(model.genres([undefined,...tracks])),json(model.genres(tracks)));
assert.equal(model.trackFolder({uri:'a/b/c.flac'}),'a/b');
const entries=model.results(tracks,'genre','Jazz','');
let selection=model.select(entries,[],-1,0,false,false);
selection=model.select(entries,selection.keys,selection.anchor,1,true,false);
assert.equal(selection.keys.length,2);
assert.equal(model.selectedTracks(tracks,selection.keys).length,2);
selection=model.select(entries,selection.keys,selection.anchor,2,false,true);
assert.equal(selection.keys.length,2,'Shift selects the anchored range');
assert.equal(model.selectedTracks(tracks,['d:Jazz']).length,2,'selected folder excludes Jazzical');
assert.equal(model.selectedTracks(tracks,['d:Jazz','t:Jazz/two.flac']).length,2,'selected files and folders must not duplicate playback');
assert.equal(model.matching(tracks,'LiVe')[0],tracks[0],'search preserves playback identity');
console.log('DASHBOARD_MUSIC_MODEL_PASS empty/genre/folder/drilldown/Unicode/root-files/prefix-boundary/identity/immutable-input');
