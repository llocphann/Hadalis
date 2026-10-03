#!/usr/bin/env python3
"""Author editable Wull 3D actions in Blender and export their exact linear curves.

Run with Blender --background --python this-file or a Blender bpy development
environment. Blender is an authoring dependency only; the desktop reads the
small scalar curve module, never the .blend, rendered frames or a Blender process.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def radius(y):
    if y < -.23:
        return .93 * math.sqrt(max(0, 1 - ((y + .23) / .64) ** 2))
    t = max(0, min(1, (y + .23) / 1.22))
    u = max(0, min(1, (t - .5) / .5))
    return .93 * (1 - t*t) * (1 - .15 * u*u * (3 - 2*u))


def material(name, color, transmission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .10
    bsdf.inputs['IOR'].default_value = 1.333
    bsdf.inputs['Transmission Weight'].default_value = transmission
    return mat


def driver(obj, property_name, axis, rig, channel, base=0, gain=1):
    curve = obj.driver_add(property_name, axis)
    var = curve.driver.variables.new()
    var.name = 'motion'
    var.targets[0].id = rig
    var.targets[0].data_path = '["' + channel + '"]'
    curve.driver.expression = f'{base!r} + motion * {gain!r}'


def author(blend_path, module_path, parity_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    scene = bpy.context.scene
    scene.render.fps = 60
    rig = bpy.data.objects.new('Wull Motion Controls', None)
    scene.collection.objects.link(rig)
    rig.animation_data_create()
    blue = material('Abyss liquid — runtime recolors from Panel Style', (.055,.30,.85), .9)
    dark = material('Glossy eyes', (.001,.012,.065))
    verts, faces = [], []
    rings, segments = 49, 64
    for i in range(rings):
        y = -.87 + (1.86 * i / (rings-1))
        r = radius(y)
        for j in range(segments):
            angle = math.tau * j / segments
            verts.append((38*r*math.cos(angle), 38*r*.91*math.sin(angle), 38*y+37))
    for i in range(rings-1):
        for j in range(segments):
            a=i*segments+j; b=i*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.extend((tuple(reversed(range(segments))), tuple(range((rings-1)*segments,rings*segments))))
    mesh = bpy.data.meshes.new('Centered pointed liquid volume')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    body = bpy.data.objects.new('Liquid body', mesh)
    scene.collection.objects.link(body)
    body.data.materials.append(blue)
    for poly in mesh.polygons: poly.use_smooth=True
    limbs=[]
    for i in range(4):
        hand=i<2
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=((1 if i%2 else -1)*(34 if hand else 19),-8,30 if hand else 3))
        limb=bpy.context.object
        limb.name=('Right' if i%2 else 'Left') + (' water arm' if hand else ' water foot')
        limb.scale=(5.25 if hand else 7,3.8,4.3 if hand else 2.8)
        limb.data.materials.append(blue)
        limbs.append(limb)
    for x in (-16,16):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(x,-29,31))
        eye=bpy.context.object
        eye.name='Glossy eye'
        eye.scale=(5,2.6,6)
        eye.data.materials.append(dark)
        eye.parent=body
    clips={}
    walk={
        'lift': [(0,0),(.125,-1.7),(.25,-2.6),(.375,-1.7),(.5,0),(.625,-1.7),(.75,-2.6),(.875,-1.7),(1,0)],
        'roll': [(0,-2.0),(.25,0),(.5,2.0),(.75,0),(1,-2.0)],
        'scaleX': [(0,1.025),(.25,.985),(.5,1.025),(.75,.985),(1,1.025)],
        'scaleY': [(0,.985),(.25,1.02),(.5,.985),(.75,1.02),(1,.985)],
    }
    # Two feet alternate stance/swing, with the opposite arm moving forwards.
    # Stance moves 16 px in .5 s, matching the runtime's 32 px/s root travel.
    for i in range(2):
        offset=.5 if i==1 else 0
        knots=[(0,8,0),(.125,4,0),(.25,0,0),(.375,-4,0),(.5,-8,0),(.625,-4,4),(.75,0,5.5),(.875,4,4),(1,8,0)]
        shifted=sorted({((t+offset)%1): (x,z) for t,x,z in knots[:-1]}.items())
        shifted.append((1,shifted[0][1]))
        walk[f'foot{i}X']=[(t,p[0]) for t,p in shifted]
        walk[f'foot{i}Z']=[(t,p[1]) for t,p in shifted]
        sign=1 if i==0 else -1
        walk[f'arm{i}X']=[(t,value*sign) for t,value in [(0,-1.5),(.25,0),(.5,1.5),(.75,0),(1,-1.5)]]
        walk[f'arm{i}Z']=[(t,value*sign) for t,value in [(0,-1),(.25,2),(.5,1),(.75,-2),(1,-1)]]
    definitions={
        'walk':(1000,walk),
        'emerge':(900,{
            'normal':[(0,1),(.18,.94),(.36,.70),(.60,.27),(.79,.06),(.91,0),(1,0)],
            'scaleX':[(0,.65),(.36,.78),(.6,.91),(.79,1.04),(.91,.99),(1,1)],
            'scaleY':[(0,.65),(.36,.94),(.6,1.09),(.79,.98),(.91,1.01),(1,1)],
        }),
        'dive':(700,{'normal':[(0,0),(.18,.015),(.36,.08),(.62,.45),(.82,.83),(1,1)]}),
        'hop':(650,{'lift':[(0,0),(.15,1.4),(.42,-10),(.65,-6),(.82,0),(.91,1.2),(1,0)]}),
        'orbit':(24000,{'angle':[(0,0),(1,math.tau)]}),
    }
    all_channels={name for _,tracks in definitions.values() for name in tracks}
    for channel in all_channels:
        rig[channel]=1.0 if channel.startswith('scale') else 0.0
    driver(body,'location',2,rig,'lift',gain=-1)
    driver(body,'rotation_euler',1,rig,'roll',gain=math.pi/180)
    driver(body,'scale',0,rig,'scaleX')
    driver(body,'scale',2,rig,'scaleY')
    for i,limb in enumerate(limbs):
        base=limb.location.copy()
        channel=('arm'+str(i)) if i<2 else ('foot'+str(i-2))
        driver(limb,'location',0,rig,channel+'X',base=base.x)
        driver(limb,'location',2,rig,channel+'Z',base=base.z)
        limb.parent=body if i<2 else rig
    # Editable orbital bubbles share the same angular control exported to QML.
    for i,offset in enumerate((3.35,.4,4.1,5.4,4.78,5.08,2.5,.03)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8)
        bubble=bpy.context.object
        bubble.name='Orbital bubble '+str(i+1)
        size=(13.5,14,11,6.5,4,4.5,4,3)[i]
        bubble.scale=(size/2,)*3; bubble.parent=body; bubble.data.materials.append(blue)
        for axis,expression in enumerate((f'47*cos(motion+{offset})',f'25*sin(motion+{offset})',f'40-37*sin(motion+{offset})')):
            curve=bubble.driver_add('location',axis)
            var=curve.driver.variables.new(); var.name='motion'
            var.targets[0].id=rig; var.targets[0].data_path='["angle"]'
            curve.driver.expression=expression
    # A parent authoring rig demonstrates actual displacement from an edge.
    body.parent=rig
    driver(rig,'location',1,rig,'normal',gain=98)
    parity=[]
    for name,(duration,tracks) in definitions.items():
        action=bpy.data.actions.new('Wull — '+name.title())
        action.use_fake_user=True
        rig.animation_data.action=action
        frames=duration*60/1000
        for channel in sorted(all_channels):
            points=tracks.get(channel,[(0,1 if channel.startswith('scale') else 0),(1,1 if channel.startswith('scale') else 0)])
            for t,value in points:
                rig[channel]=float(value)
                rig.keyframe_insert(data_path='["'+channel+'"]',frame=1+t*frames,group='Wull '+name)
        exported={}
        for curve in action.fcurves:
            for key in curve.keyframe_points: key.interpolation='LINEAR'
            channel=curve.data_path[2:-2]
            if channel not in tracks:
                continue  # Constant defaults are implicit; keep every authored key.
            # Export the evaluated Blender keys including its stored float32
            # timing/values; no resampling, rounding or key reduction.
            exported[channel]=[[float(key.co.x-1)/frames,float(key.co.y)] for key in curve.keyframe_points]
            if parity_path:
                for i in range(101):
                    phase=i/100
                    parity.append([name,channel,phase,float(curve.evaluate(1+phase*frames))])
        clips[name]={'duration':duration,'tracks':exported}
    rig.animation_data.action=bpy.data.actions.get('Wull — Walk')
    scene.frame_start=1; scene.frame_end=61
    scene.frame_set(1)
    bpy.ops.object.camera_add(location=(0,-220,82))
    camera=bpy.context.object
    camera.name='Front reference camera'
    camera.rotation_euler=(Vector((0,0,37))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'; camera.data.ortho_scale=115
    scene.camera=camera
    bpy.ops.object.light_add(type='AREA',location=(-55,-70,110))
    bpy.context.object.data.energy=1600; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=65
    scene.render.resolution_x=640; scene.render.resolution_y=640
    scene.world=bpy.data.worlds.new('Abyss studio')
    scene.world.color=(.006,.014,.04)
    blend_path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    header='.pragma library\n// Generated by scripts/wull-author-motion.py using Blender '+bpy.app.version_string+'.\n// Exact LINEAR F-curves; authoring scene: assets/wull/WullMotion.blend.\n'
    sampler='''
function sample(clip, channel, phase) {
    const keys = clips[clip].tracks[channel];
    if (!keys) return channel.indexOf("scale") === 0 ? 1 : 0;
    const t = Math.max(0, Math.min(1, phase));
    for (let i = 1; i < keys.length; i++) {
        if (t <= keys[i][0]) {
            const a = keys[i-1], b = keys[i];
            return a[1] + (b[1]-a[1]) * (t-a[0]) / (b[0]-a[0]);
        }
    }
    return keys[keys.length-1][1];
}
if (typeof module !== "undefined") module.exports = {clips, sample};
'''
    module_path.write_text(header+'var clips = '+json.dumps(clips,sort_keys=True,separators=(',',':'))+';\n'+sampler)
    if parity_path: parity_path.write_text(json.dumps(parity,separators=(',',':')))
    print('WULL_BLENDER_AUTHORED_MOTION_EXPORTED',json.dumps({'blender':bpy.app.version_string,'clips':list(clips),'curve_sha256':hashlib.sha256(module_path.read_bytes()).hexdigest()}))


if __name__=='__main__':
    arguments=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blend',type=Path,default=ROOT/'assets/wull/WullMotion.blend')
    parser.add_argument('--module',type=Path,default=ROOT/'modules/abyss/companion/WullMotionData.js')
    parser.add_argument('--parity',type=Path)
    args=parser.parse_args(arguments)
    author(args.blend.resolve(),args.module.resolve(),args.parity.resolve() if args.parity else None)
