#!/usr/bin/env python3
"""Author Aqua/Octo 3D rigs in Blender; export exact editable F-curves.

uv run --python 3.11 --with bpy==4.3.0 --with 'numpy<2' python this-file
The desktop renders live volumes and reads curves, never Blender or frames.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import tempfile

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'modules/abyss/companion'
HANDOFF=5600
GEOMETRY=json.loads(re.search(r'var geometry=(.*)\n',(DATA/'OctoRig.js').read_text())[1])
GRIP_WRAP=json.loads(re.search(r'var gripWrapPoints=(.*)\n',(DATA/'OctoRig.js').read_text())[1])
TENTACLES=GEOMETRY['tentacles']

def controls(index,curl=1,lift=0,reach=0):
    a=(index+.5)*math.tau/TENTACLES;x=math.cos(a);z=math.sin(a)
    return [(10*x,-10,10*z,GEOMETRY["rootRadius"]),(21*x+reach*.25,-23+lift,21*z,8.6),
        (34*x+reach*.8,-26+curl*6+lift,26*z,6.2),(31*x+reach,-22+curl*9+lift+reach*.12,27*z,GEOMETRY["tipRadius"])]

def point(points,t):
    u=1-t;weights=(u**3,3*u*u*t,3*u*t*t,t**3)
    return Vector(tuple(sum(p[k]*w for p,w in zip(points,weights)) for k in range(3)))

def grip_controls(index,rise=0,wrap=0):
    sign=-1 if index<2 else 1
    base=[(sign*16,-42,-10),(sign*25,-42,-14),(sign*26,-40,-14),(sign*23,-38,-14)]
    raised=[(sign*16,-42,-10),(sign*44,-17,-8),(sign*42,18,-8),(sign*34,28,-2)]
    return [tuple(base[i][k]+(raised[i][k]-base[i][k])*rise+(GRIP_WRAP[index][i][k]-raised[i][k])*wrap for k in range(3))
        +(GEOMETRY['rootRadius']+(GEOMETRY['tipRadius']-GEOMETRY['rootRadius'])*i/3,) for i in range(4)]

def tube(name,points,material,body,rig,index):
    rings=25;sides=16;vertices=[];faces=[]
    for j in range(rings):
        t=j/(rings-1);p=point(points,t)
        tangent=(point(points,min(1,t+.001))-point(points,max(0,t-.001))).normalized()
        side=tangent.cross(Vector((0,0,1)))
        if side.length<.01:side=tangent.cross(Vector((1,0,0)))
        side.normalize();up=tangent.cross(side).normalized();radius=points[0][3]*(1-t)+points[3][3]*t
        for k in range(sides):
            a=k*math.tau/sides;q=p+radius*(side*math.cos(a)+up*math.sin(a))
            vertices.append((q.x,-q.z,q.y))
    for j in range(rings-1):
        for k in range(sides):
            a=j*sides+k;b=j*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces.extend((tuple(reversed(range(sides))),tuple(range((rings-1)*sides,rings*sides))))
    mesh=bpy.data.meshes.new(name+' mesh');mesh.from_pydata(vertices,[],faces);mesh.update()
    arm=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(arm);arm.parent=body;arm.data.materials.append(material)
    for polygon in mesh.polygons:polygon.use_smooth=True
    arm.shape_key_add(name='Rest')
    # Independent editable curl, lift and reach keys deform the actual tube.
    for channel,args in [('Curl',(0,0,0)),('Lift',(1,8,0)),('Reach',(1,0,35))]:
        key=arm.shape_key_add(name=channel);new=controls(index,*args)
        key.slider_min=-2;key.slider_max=4
        for j in range(rings):
            t=j/(rings-1);delta=point(new,t)-point(points,t)
            for k in range(sides):
                v=key.data[j*sides+k].co;v.x+=delta.x;v.y-=delta.z;v.z+=delta.y
        f=key.driver_add('value');var=f.driver.variables.new();var.name='v';var.targets[0].id=rig;var.targets[0].data_path='["tentacle'+str(index)+channel+'"]'
        f.driver.expression='1-v' if channel=='Curl' else 'v/8' if channel=='Lift' else 'v/35'
    for channel,previous,new in [('GripBase',points,grip_controls(index)),
            ('GripRise',grip_controls(index),grip_controls(index,1)),
            ('GripWrap',grip_controls(index,1),grip_controls(index,1,1))]:
        key=arm.shape_key_add(name=channel)
        for j in range(rings):
            delta=point(new,j/(rings-1))-point(previous,j/(rings-1))
            for k in range(sides):
                v=key.data[j*sides+k].co;v.x+=delta.x;v.y-=delta.z;v.z+=delta.y
        f=key.driver_add('value');var=f.driver.variables.new();var.name='v';var.targets[0].id=rig
        var.targets[0].data_path='["'+{'GripBase':'gripActive','GripRise':'gripRise','GripWrap':'gripWrap'}[channel]+'"]'
        f.driver.expression='v'
    # Real shallow concave suction cups, retained in the editable mesh scene.
    for n,t in enumerate((.32,.47,.62,.77)):
        p=point(points,t);radius=(points[0][3]*(1-t)+points[3][3]*t)*.7
        bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=.42,major_segments=20,minor_segments=8,
            location=(p.x,-p.z-radius,p.y))
        sucker=bpy.context.object;sucker.name=f'Suction cup {index+1}.{n+1}';sucker.parent=body;sucker.rotation_euler.x=math.pi/2;sucker.data.materials.append(material)
        # Cups follow the same deforming curve, rather than staying at rest
        # while their tentacle moves. Native y points up; Blender y is -depth.
        weights=((1-t)**3,3*(1-t)**2*t,3*(1-t)*t*t,t**3)
        for axis,native_axis,sign,offset in [(0,0,1,0),(1,2,-1,-radius),(2,1,1,0)]:
            f=sucker.driver_add('location',axis);f.driver.type='SCRIPTED'
            for name,channel in [('c','Curl'),('l','Lift'),('r','Reach')]:
                var=f.driver.variables.new();var.name=name;var.targets[0].id=rig;var.targets[0].data_path=f'["tentacle{index}{channel}"]'
            for name,channel in [('g','gripActive'),('u','gripRise'),('w','gripWrap')]:
                var=f.driver.variables.new();var.name=name;var.targets[0].id=rig;var.targets[0].data_path=f'["{channel}"]'
            neutral=point(controls(index,0,0,0),t)[native_axis]*sign+offset
            increments=[(point(controls(index,*args),t)[native_axis]-point(controls(index,0,0,0),t)[native_axis])*sign for args in [(1,0,0),(0,1,0),(0,0,1)]]
            grip_deltas=[(point(new,t)[native_axis]-point(old,t)[native_axis])*sign for old,new in
                [(points,grip_controls(index)),(grip_controls(index),grip_controls(index,1)),(grip_controls(index,1),grip_controls(index,1,1))]]
            f.driver.expression=f'{neutral:.9f}+c*{increments[0]:.9f}+l*{increments[1]:.9f}+r*{increments[2]:.9f}+g*{grip_deltas[0]:.9f}+u*{grip_deltas[1]:.9f}+w*{grip_deltas[2]:.9f}'
    return arm

def export_actions(rig,clips,label):
    channels=set(k for clip in clips.values() for k in clip['tracks'])
    for channel in channels:rig[channel]=1. if channel.startswith('scale') or channel.endswith('Curl') or channel=='eyeOpen' else 0.
    samples=[];result={}
    for name,clip in clips.items():
        action=bpy.data.actions.new(label+' — '+name.title());action.use_fake_user=True;rig.animation_data.action=action
        frames=clip['duration']*60/1000
        for channel in sorted(channels):
            default=1 if channel.startswith('scale') or channel.endswith('Curl') or channel=='eyeOpen' else 0
            for t,value in clip['tracks'].get(channel,[(0,default),(1,default)]):
                rig[channel]=float(value);rig.keyframe_insert(data_path='["'+channel+'"]',frame=1+t*frames,group=label+' '+name)
        tracks={}
        for f in action.fcurves:
            for key in f.keyframe_points:key.interpolation='LINEAR'
            channel=f.data_path[2:-2]
            if channel not in clip['tracks']:continue
            tracks[channel]=[[float(k.co.x-1)/frames,float(k.co.y)] for k in f.keyframe_points]
            for i in range(51):samples.append([name,channel,i/50,float(f.evaluate(1+i/50*frames))])
        result[name]={'duration':clip['duration'],'tracks':tracks}
    rig.animation_data.action=bpy.data.actions[label+' — Walk'];bpy.context.scene.frame_set(1)
    return result,samples

def module(path,clips,label):
    sampler='''
function sample(clip, channel, phase) {
    const keys = clips[clip]?.tracks[channel];
    if (!keys) return channel.indexOf("scale")===0 || channel.endsWith("Curl") || channel==="eyeOpen" ? 1 : 0;
    const t=Math.max(0,Math.min(1,phase));
    for(let i=1;i<keys.length;i++)if(t<=keys[i][0]) {
        const a=keys[i-1],b=keys[i];return a[1]+(b[1]-a[1])*(t-a[0])/(b[0]-a[0]);
    }
    return keys[keys.length-1][1];
}
if(typeof module!=="undefined")module.exports={clips,sample};
'''
    path.write_text('.pragma library\n// Blender '+bpy.app.version_string+'; exact LINEAR keys from assets/'+label.lower()+'/'+label+'Motion.blend.\nvar clips='+json.dumps(clips,sort_keys=True,separators=(',',':'))+';\n'+sampler)

def main(receipt):
    spec=importlib.util.spec_from_file_location('original',ROOT/'scripts/wull-author-motion.py');original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
    with tempfile.TemporaryDirectory(prefix='companion-author-') as temporary:
        private=Path(temporary);original.author(private/'source.blend',private/'curves.js',None)
        base=json.loads(re.search(r'var clips = (.*);', (private/'curves.js').read_text())[1])
        rig=bpy.data.objects['Wull Motion Controls'];rig.name='Aqua Motion Controls'
        for action in list(bpy.data.actions):bpy.data.actions.remove(action)
        aqua=json.loads(json.dumps(base));aqua.pop('sink')
        aqua['pulled']={'duration':HANDOFF,'tracks':{
            'normal':[[0,0],[.20,0],[.35,.12],[.60,.55],[.83,.95],[1,1.20]],
            'pitch':[[0,0],[.18,14],[.35,-12],[.65,22],[.85,-8],[1,0]],
            'roll':[[0,0],[.2,-12],[.45,14],[.7,-9],[1,0]],
            'eyeOpen':[[0,1],[.22,0],[.40,1],[.70,.1],[1,0]],
            'arm0Z':[[0,0],[.24,12],[.5,4],[.7,11],[1,0]],'arm1Z':[[0,0],[.24,9],[.5,13],[.7,3],[1,0]],
            'foot0Z':[[0,0],[.25,8],[.5,3],[.75,12],[1,0]],'foot1Z':[[0,0],[.25,3],[.5,10],[.75,4],[1,0]]}}
        aqua['push']={'duration':HANDOFF,'tracks':{'roll':[[0,0],[.2,8],[.4,12],[.7,5],[1,0]],
            'arm1X':[[0,0],[.2,10],[.65,10],[1,0]],'arm1Z':[[0,0],[.2,10],[.65,-3],[1,0]],
            'eyeOpen':[[0,1],[.35,.15],[.6,1],[1,1]],'lift':[[0,0],[.25,-4],[.7,1],[1,0]]}}
        authored,samples=export_actions(rig,aqua,'Aqua');blend=ROOT/'assets/aqua/AquaMotion.blend';blend.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend));module(DATA/'AquaMotionData.js',authored,'Aqua')
        receipts={'Aqua':{'clips':list(authored),'keys':sum(len(k) for c in authored.values() for k in c['tracks'].values()),'samples':samples,'blendSha256':hashlib.sha256(blend.read_bytes()).hexdigest()}}
        # Reuse the material/pose drivers, replace droplet anatomy with a globe
        # and exactly four curved, independently driven tentacles.
        rig.name='Octo Motion Controls'
        for action in list(bpy.data.actions):bpy.data.actions.remove(action)
        body=bpy.data.objects['Liquid body'];blue=body.data.materials[0]
        old=body.data;verts=[];faces=[];rings=41;segments=64
        for i in range(rings):
            y=-.89+1.78*i/(rings-1);r=math.sqrt(max(0,.89**2-y*y))
            for j in range(segments):
                a=math.tau*j/segments;unit=GEOMETRY["headSize"]/2.15;verts.append((unit*r*math.cos(a),unit*r*.91*math.sin(a),unit*y+GEOMETRY["headOffset"]))
        for i in range(rings-1):
            for j in range(segments):
                a=i*segments+j;b=i*segments+(j+1)%segments;faces.append((a,b,b+segments,a+segments))
        mesh=bpy.data.meshes.new('Octo round liquid head');mesh.from_pydata(verts,[],faces);mesh.update();body.data=mesh;body.name='Octo liquid head';body.data.materials.append(blue)
        for p in mesh.polygons:p.use_smooth=True
        for eye in (o for o in bpy.data.objects if o.name.startswith('Glossy eye')):
            eye.location.x=math.copysign(11.7,eye.location.x);eye.location.y=-24;eye.location.z=-1
            eye.scale.x*=.9;eye.scale.y*=.9
        for o in list(bpy.data.objects):
            if ' water arm' in o.name or ' water foot' in o.name:bpy.data.objects.remove(o,do_unlink=True)
        octo=json.loads(json.dumps(base));octo['pull']={'duration':HANDOFF,'tracks':{'roll':[[0,0],[.25,-8],[.6,4],[1,0]],'eyeOpen':[[0,1],[.35,.2],[.6,1],[1,1]],
            'gripActive':[[0,1],[1,1]],'gripRise':[[0,0],[.13,.5],[.23,1],[.8,1],[1,0]],
            'gripWrap':[[0,0],[.18,0],[.32,.55],[.43,1],[.8,1],[1,0]]}}
        for name,clip in octo.items():
            clip['tracks']={k:v for k,v in clip['tracks'].items() if not k.startswith(('arm','foot'))}
            for i in range(TENTACLES):
                amplitude=5 if name=='walk' else 8 if name in ('run','fly','balance') else 3
                clip['tracks'][f'tentacle{i}Curl']=[[0,1],[.25,1.35 if i%2 else .55],[.5,1],[.75,.55 if i%2 else 1.35],[1,1]]
                clip['tracks'][f'tentacle{i}Lift']=[[0,0],[.25,amplitude if i%2 else 0],[.5,0],[.75,0 if i%2 else amplitude],[1,0]]
                if name=='pull':
                    clip['tracks'][f'tentacle{i}Curl']=[[0,1],[1,1]]
                    clip['tracks'][f'tentacle{i}Lift']=[[0,0],[1,0]]
                elif name in ('launch','stuckLaunch','fall','pulled','sink'):
                    clip['tracks'][f'tentacle{i}Curl']=[[0,1],[.2,.25],[.4,1.7],[.6,.3],[.8,1.5],[1,1]]
                elif name in ('press','reach') and i in (0,3):
                    clip['tracks'][f'tentacle{i}Reach']=[[0,0],[.35,18],[.55,12],[.72,18],[1,0]]
                    clip['tracks'][f'tentacle{i}Lift']=[[0,0],[.35,9],[.72,9],[1,0]]
                elif name=='wave' and i==0:
                    clip['tracks'][f'tentacle{i}Lift']=[[0,0],[.2,13],[.35,7],[.5,15],[.65,7],[.8,13],[1,0]]
        arms_material=blue.copy();arms_material.name='Octo opaque glossy tentacles'
        surface=next(n for n in arms_material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        surface.inputs['Transmission Weight'].default_value=.05
        surface.inputs['Alpha'].default_value=1
        for i in range(TENTACLES):tube('Tentacle '+str(i+1),controls(i),arms_material,body,rig,i)
        mouth=bpy.data.curves.new('Octo smile','CURVE');mouth.dimensions='3D';mouth.bevel_depth=.38;mouth.bevel_resolution=4
        spline=mouth.splines.new('BEZIER');spline.bezier_points.add(2)
        for p,co in zip(spline.bezier_points,[(-3,-25,-5),(0,-25,-6.6),(3,-25,-5)]):
            p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
        smile=bpy.data.objects.new('Octo smile',mouth);bpy.context.scene.collection.objects.link(smile);smile.parent=body
        mouth.materials.append(bpy.data.materials['Glossy eyes'])
        authored,samples=export_actions(rig,octo,'Octo');blend=ROOT/'assets/octo/OctoMotion.blend';blend.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend));module(DATA/'OctoMotionData.js',authored,'Octo')
        receipts['Octo']={'clips':list(authored),'keys':sum(len(k) for c in authored.values() for k in c['tracks'].values()),'samples':samples,'blendSha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'tentacles':TENTACLES,'suctionCups':TENTACLES*4,'controls':[controls(i) for i in range(TENTACLES)]}
        assert len(receipts['Aqua']['clips'])==len(receipts['Octo']['clips'])==30
        if receipt:receipt.write_text(json.dumps(receipts,separators=(',',':')))
        print(f'COMPANION_BLENDER_RIGS_PASS Aqua=30 Octo=30 tentacles={TENTACLES} suctionCups={TENTACLES*4}')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--receipt',type=Path);main(parser.parse_args().receipt)
