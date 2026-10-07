#!/usr/bin/env python3
"""Reopen both saved Blender rigs, verify keys/deformation, render owned previews.
Run in the bpy 4.3 authoring environment; Blender is never a desktop dependency.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
def sample(keys,t):
    for a,b in zip(keys,keys[1:]):
        if t<=b[0]:return a[1]+(b[1]-a[1])*(t-a[0])/(b[0]-a[0])
    return keys[-1][1]
def verify(output,render):
    output.mkdir(mode=0o700,parents=True,exist_ok=True);receipt={'blender':bpy.app.version_string,'characters':{}}
    for character in ['Aqua','Octo']:
        blend=ROOT/'assets'/character.lower()/(character+'Motion.blend')
        module=ROOT/'modules/abyss/companion'/(character+'MotionData.js')
        clips=json.loads(re.search(r'var clips=(.*);',module.read_text())[1])
        bpy.ops.wm.open_mainfile(filepath=str(blend))
        rig=bpy.data.objects[character+' Motion Controls'];errors=[];samples=0
        assert len(bpy.data.actions)==len(clips)==30
        for name,clip in clips.items():
            action=bpy.data.actions[character+' — '+name.title()]
            for channel,keys in clip['tracks'].items():
                f=next(f for f in action.fcurves if f.data_path=='["'+channel+'"]')
                assert len(f.keyframe_points)==len(keys)
                assert all(k.interpolation=='LINEAR' for k in f.keyframe_points)
                for i in range(51):
                    t=i/50;errors.append(abs(sample(keys,t)-f.evaluate(1+t*clip['duration']*.06)));samples+=1
        assert max(errors)<.0001
        body=bpy.data.objects['Octo liquid head' if character=='Octo' else 'Liquid body']
        rig.animation_data.action=bpy.data.actions[character+' — Buttplant']
        bpy.context.scene.frame_set(1+round(clips['buttplant']['duration']*.06*.6))
        assert abs(body.matrix_local.determinant()-1)<.00001
        assert abs(body.rotation_euler.x)>1,'saved fall is a flat scale'
        info={'animations':len(clips),'exportedKeys':sum(len(k) for c in clips.values() for k in c['tracks'].values()),
            'verifiedSamples':samples,'maximumCurveError':max(errors),'blendSha256':hashlib.sha256(blend.read_bytes()).hexdigest(),
            'curveSha256':hashlib.sha256(module.read_bytes()).hexdigest(),'spatialFallDeterminant':body.matrix_local.determinant()}
        if character=='Octo':
            arms=[o for o in bpy.data.objects if o.name.startswith('Tentacle ')];cups=[o for o in bpy.data.objects if o.name.startswith('Suction cup ')]
            assert len(arms)==4 and len(cups)==16
            assert not any('water arm' in o.name or 'water foot' in o.name for o in bpy.data.objects)
            assert all(len(a.data.shape_keys.key_blocks)==4 for a in arms)
            surface=next(n for n in arms[0].data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            assert surface.inputs['Transmission Weight'].default_value<.051
            assert surface.inputs['Alpha'].default_value==1
            rig.animation_data.action=bpy.data.actions['Octo — Pull']
            bpy.context.scene.frame_set(1);graph=bpy.context.evaluated_depsgraph_get()
            rest=arms[0].evaluated_get(graph).to_mesh();rest_tip=rest.vertices[-1].co.copy();arms[0].evaluated_get(graph).to_mesh_clear()
            cup_rest=cups[0].evaluated_get(graph).location.copy()
            bpy.context.scene.frame_set(1+round(5600*.06*.3));graph=bpy.context.evaluated_depsgraph_get()
            extended=arms[0].evaluated_get(graph).to_mesh();movement=(extended.vertices[-1].co-rest_tip).length;arms[0].evaluated_get(graph).to_mesh_clear()
            cup_movement=(cups[0].evaluated_get(graph).location-cup_rest).length
            assert movement>25 and cup_movement>3,'Blender tube/cup failed to follow the pull'
            info.update(tentacles=4,suctionCups=16,pullTipTravel=movement,pullCupTravel=cup_movement,
                tentacleTransmission=surface.inputs['Transmission Weight'].default_value,tentacleOpacity=1)
        receipt['characters'][character]=info
        if render:
            rig.animation_data.action=bpy.data.actions[character+' — Walk'];bpy.context.scene.frame_set(1)
            scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48
            scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
            scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
            scene.camera.location=(-45,-220,68);scene.camera.rotation_euler=(Vector((0,0,37))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
            for light in (o for o in bpy.data.objects if o.type=='LIGHT'):
                light.data.energy=120000;light.data.size=60
            bpy.ops.object.light_add(type='AREA',location=(75,-25,82));bpy.context.object.data.energy=90000;bpy.context.object.data.size=38
            scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.008,.02,.04,1)
            scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
            scene.render.filepath=str(output/(character.lower()+'-blender.png'));bpy.ops.render.render(write_still=True)
    (output/'blender-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('COMPANION_REOPENED_BLENDER_PASS '+json.dumps(receipt,separators=(',',':')))
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--render',action='store_true');args=parser.parse_args();verify(args.output,args.render)
