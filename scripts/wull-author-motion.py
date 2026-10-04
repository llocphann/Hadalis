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
            verts.append((38*r*math.cos(angle), 38*r*.91*math.sin(angle), 38*y))
    for i in range(rings-1):
        for j in range(segments):
            a=i*segments+j; b=i*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.extend((tuple(reversed(range(segments))), tuple(range((rings-1)*segments,rings*segments))))
    mesh = bpy.data.meshes.new('Centered pointed liquid volume')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    body = bpy.data.objects.new('Liquid body', mesh)
    body.location.z=37
    body.rotation_mode='XZY'
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
    eyes=[]
    for x in (-16,16):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(x,-29,31))
        eye=bpy.context.object
        eye.name='Glossy eye'
        eye.scale=(5,2.6,6)
        eye.data.materials.append(dark)
        eye.location.z-=37
        eye.parent=body
        eyes.append(eye)
    clips={}
    walk={
        'lift': [(0,0),(.125,-1.7),(.25,-2.6),(.375,-1.7),(.5,0),(.625,-1.7),(.75,-2.6),(.875,-1.7),(1,0)],
        'roll': [(0,-2.0),(.25,0),(.5,2.0),(.75,0),(1,-2.0)],
        'scaleX': [(0,1.025),(.25,.985),(.5,1.025),(.75,.985),(1,1.025)],
        'scaleY': [(0,.985),(.25,1.02),(.5,.985),(.75,1.02),(1,.985)],
    }
    # Two feet alternate stance/swing, with the opposite arm moving forwards.
    # Stance moves 16 px in 1 s, matching the runtime's 16 px/s root travel.
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
        'walk':(2000,walk),
        'float':(1800,{
            'lift':[(0,-1),(.22,-3.2),(.52,-1),(.8,.6),(1,-1)],
            'roll':[(0,-1.1),(.25,0),(.5,1.1),(.75,0),(1,-1.1)],
            'scaleX':[(0,1),(.22,.984),(.52,1.012),(.8,1.02),(1,1)],
            'scaleY':[(0,1),(.22,1.035),(.52,1.012),(.8,.984),(1,1)],
            'arm0X':[(0,-.8),(.25,-2.4),(.5,-.8),(.75,.5),(1,-.8)],
            'arm1X':[(0,.8),(.25,2.4),(.5,.8),(.75,-.5),(1,.8)],
            'arm0Z':[(0,1),(.25,3.6),(.5,1),(.75,-.5),(1,1)],
            'arm1Z':[(0,1),(.25,3.6),(.5,1),(.75,-.5),(1,1)],
            'foot0X':[(0,0),(.25,-.6),(.5,0),(.75,.6),(1,0)],
            'foot1X':[(0,0),(.25,.6),(.5,0),(.75,-.6),(1,0)],
            'foot0Z':[(0,-1),(.25,-.4),(.5,-1),(.75,-1.4),(1,-1)],
            'foot1Z':[(0,-1),(.25,-.4),(.5,-1),(.75,-1.4),(1,-1)],
        }),
        'emerge':(900,{
            'normal':[(0,1),(.18,.94),(.36,.70),(.60,.27),(.79,.06),(.91,0),(1,0)],
            'scaleX':[(0,.65),(.36,.78),(.6,.91),(.79,1.04),(.91,.99),(1,1)],
            'scaleY':[(0,.65),(.36,.94),(.6,1.09),(.79,.98),(.91,1.01),(1,1)],
        }),
        'dive':(700,{'normal':[(0,0),(.18,.015),(.36,.08),(.62,.45),(.82,.83),(1,1)]}),
        'hop':(650,{'lift':[(0,0),(.15,1.4),(.42,-10),(.65,-6),(.82,0),(.91,1.2),(1,0)]}),
        'orbit':(24000,{'angle':[(0,0),(1,math.tau)]}),
    }
    # New actions keep the original six exports intact. Two alternating feet
    # match 32 px/s travel; flying has a propulsion stroke and tucked feet.
    run={
        'lift':[(0,0),(.25,-3),(.5,0),(.75,-3),(1,0)],
        'roll':[(0,-3),(.25,0),(.5,3),(.75,0),(1,-3)],
        'scaleX':[(0,1.03),(.25,.97),(.5,1.03),(.75,.97),(1,1.03)],
        'scaleY':[(0,.975),(.25,1.035),(.5,.975),(.75,1.035),(1,.975)],
    }
    for i in range(2):
        offset=.5 if i else 0
        knots=[(0,10.4,0),(.25,0,0),(.5,-10.4,0),(.65,-4,7),(.75,0,9),(.85,4,7)]
        shifted=sorted({((t+offset)%1):(x,z) for t,x,z in knots}.items())
        shifted.append((1,shifted[0][1]))
        run[f'foot{i}X']=[(t,p[0]) for t,p in shifted]
        run[f'foot{i}Z']=[(t,p[1]) for t,p in shifted]
        sign=1 if i else -1
        run[f'arm{i}X']=[(0,3*sign),(.5,-3*sign),(1,3*sign)]
        run[f'arm{i}Z']=[(0,-2*sign),(.25,4*sign),(.5,2*sign),(.75,-4*sign),(1,-2*sign)]
    definitions['run']=(1300,run)
    definitions['fly']=(800,{
        'lift':[(0,0),(.22,-2.8),(.45,-1.8),(.75,.5),(1,0)],
        'roll':[(0,-2.5),(.25,1),(.5,2.5),(.75,-1),(1,-2.5)],
        'scaleX':[(0,1.02),(.22,.975),(.55,1),(.75,1.025),(1,1.02)],
        'scaleY':[(0,.985),(.22,1.04),(.55,1.01),(.75,.985),(1,.985)],
        'arm0X':[(0,-1),(.22,-4),(.55,-2),(.75,1),(1,-1)],
        'arm1X':[(0,1),(.22,4),(.55,2),(.75,-1),(1,1)],
        'arm0Z':[(0,2),(.22,9),(.55,5),(.75,-1),(1,2)],
        'arm1Z':[(0,2),(.22,9),(.55,5),(.75,-1),(1,2)],
        'foot0X':[(0,-1),(.4,-3),(.75,0),(1,-1)],
        'foot1X':[(0,1),(.4,3),(.75,0),(1,1)],
        'foot0Z':[(0,6),(.35,9),(.7,5),(1,6)],
        'foot1Z':[(0,8),(.35,5),(.7,9),(1,8)],
        'height':[(0,0),(.25,.7),(.5,1),(.75,.7),(1,0)],
    })
    definitions['jump']=(950,{
        'height':[(0,0),(.12,0),(.4,1),(.62,.85),(.88,0),(1,0)],
        'journey':[(0,0),(.12,0),(.4,.42),(.62,.76),(.88,1),(1,1)],
        'scaleX':[(0,1),(.12,1.05),(.25,.96),(.62,.98),(.88,1.05),(1,1)],
        'scaleY':[(0,1),(.12,.94),(.25,1.045),(.62,1.02),(.88,.94),(1,1)],
        'roll':[(0,0),(.25,-4),(.62,3),(1,0)],
        'arm0Z':[(0,0),(.25,8),(.62,5),(.88,0),(1,0)],
        'arm1Z':[(0,0),(.25,8),(.62,5),(.88,0),(1,0)],
        'foot0Z':[(0,0),(.25,7),(.62,9),(.88,0),(1,0)],
        'foot1Z':[(0,0),(.25,9),(.62,7),(.88,0),(1,0)],
    })
    definitions['drag']=(1100,{
        'roll':[(0,-4),(.25,0),(.5,4),(.75,0),(1,-4)],
        'scaleX':[(0,.985),(.5,.97),(1,.985)],
        'scaleY':[(0,1.015),(.5,1.04),(1,1.015)],
        'arm0Z':[(0,-2),(.5,2),(1,-2)],'arm1Z':[(0,2),(.5,-2),(1,2)],
        'foot0X':[(0,-2),(.5,2),(1,-2)],'foot1X':[(0,2),(.5,-2),(1,2)],
        'foot0Z':[(0,0),(.5,2),(1,0)],'foot1Z':[(0,2),(.5,0),(1,2)],
    })
    definitions['fall']=(1100,{
        'scaleX':[(0,1),(.25,.965),(.72,.965),(1,1.025)],
        'scaleY':[(0,1),(.25,1.045),(.72,1.045),(1,.97)],
        'arm0X':[(0,0),(.2,-4),(.8,-4),(1,0)],
        'arm1X':[(0,0),(.2,4),(.8,4),(1,0)],
        'arm0Z':[(0,0),(.2,9),(.8,9),(1,0)],
        'arm1Z':[(0,0),(.2,9),(.8,9),(1,0)],
        'foot0Z':[(0,4),(.7,5),(1,0)],'foot1Z':[(0,5),(.7,4),(1,0)],
    })
    definitions['land']=(500,{
        'scaleX':[(0,1.05),(.22,1.035),(.5,.985),(1,1)],
        'scaleY':[(0,.93),(.22,.95),(.5,1.025),(1,1)],
        'arm0Z':[(0,4),(.35,-1),(1,0)],'arm1Z':[(0,4),(.35,-1),(1,0)],
    })
    # Feature-specific gestures: push a control, reach for a panel, study a
    # calendar/status display, or wave at Media. No feature action changes data.
    definitions['press']=(800,{
        'arm1X':[(0,0),(.35,4),(.55,2),(.72,4),(1,0)],
        'arm1Z':[(0,0),(.35,8),(.55,6),(.72,8),(1,0)],
        'roll':[(0,0),(.35,3),(.72,3),(1,0)],
    })
    definitions['reach']=(1000,{
        'arm0X':[(0,0),(.35,-3),(.65,-3),(1,0)],
        'arm1X':[(0,0),(.35,3),(.65,3),(1,0)],
        'arm0Z':[(0,0),(.35,8),(.65,8),(1,0)],
        'arm1Z':[(0,0),(.35,8),(.65,8),(1,0)],
        'scaleY':[(0,1),(.35,1.035),(.65,1.035),(1,1)],
    })
    definitions['inspect']=(1500,{
        'roll':[(0,0),(.25,-5),(.5,2),(.75,5),(1,0)],
        'arm0Z':[(0,0),(.25,4),(.75,2),(1,0)],
        'arm1Z':[(0,0),(.25,2),(.75,4),(1,0)],
    })
    definitions['wave']=(1300,{
        'arm1Z':[(0,0),(.2,8),(.35,5),(.5,9),(.65,5),(.8,8),(1,0)],
        'arm1X':[(0,0),(.2,3),(.35,1),(.5,4),(.65,1),(.8,3),(1,0)],
        'roll':[(0,0),(.2,-2),(.8,-2),(1,0)],
    })
    # Appearance/action curves are authored in this editable rig too. Normal
    # displacements below zero are an actual jump away from the water opening.
    for name,duration,normal in (
        ('riseJump',1850,[(0,1),(.15,.7),(.36,-.85),(.58,-.65),(.78,0),(1,0)]),
        ('launch',2150,[(0,1),(.12,.92),(.30,-1.10),(.55,-.88),(.77,0),(1,0)]),
        ('stuckJump',3100,[(0,1),(.18,.55),(.30,.53),(.40,.62),(.53,.48),(.64,-.85),(.84,0),(1,0)]),
        ('stuckLaunch',3400,[(0,1),(.18,.55),(.30,.56),(.40,.64),(.52,.49),(.65,-1.10),(.86,0),(1,0)]),
        ('faceplant',2600,[(0,1),(.16,.70),(.35,-.75),(.58,0),(.82,0),(1,0)]),
        ('buttplant',2900,[(0,1),(.14,.8),(.32,-.95),(.58,0),(.84,0),(1,0)]),
        ('diveJump',1300,[(0,0),(.18,-.25),(.34,-.38),(.50,-.20),(.65,0),(.82,.55),(1,1)]),
        ('sink',5600,[(0,0),(.18,.06),(.35,.19),(.46,.17),(.62,.36),(.72,.34),(.88,.68),(1,1)]),
        ('fallVanish',3100,[(0,0),(.15,-.18),(.36,0),(.57,.10),(.76,.38),(1,1)]),
    ):
        stuck=name.startswith('stuck')
        launch='Launch' in name or name=='launch'
        tracks={'normal':normal,
            'scaleX':[(0,1),(.18,1.06),(.40,.98),(.65,.96),(.82,1.08),(1,1)],
            'scaleY':[(0,1),(.18,.93),(.40,1.03),(.65,1.06),(.82,.91),(1,1)],
            'roll':[(0,0),(.24,-6),(.4,5),(.6,-5),(.8,3),(1,0)],
            'eyeOpen':[(0,1),(.18,.0),(.68,0),(.9,1),(1,1)],
        }
        for i in range(2):
            sign=1 if i else -1
            tracks[f'arm{i}X']=[(0,0),(.24,sign*3),(.4,-sign*2),(.6,sign*4),(.8,-sign*2),(1,0)]
            tracks[f'arm{i}Z']=[(0,0),(.24,9 if stuck else 4),(.4,2),(.6,10 if launch else 7),(.8,3),(1,0)]
            tracks[f'foot{i}X']=[(0,0),(.3,sign*3),(.5,-sign*3),(.7,sign*4),(1,0)]
            tracks[f'foot{i}Z']=[(0,0),(.3,4+i*3),(.5,9-i*4),(.7,3+i*4),(1,0)]
        if name=='faceplant':
            tracks['pitch']=[(0,0),(.35,12),(.53,78),(.72,78),(.85,15),(1,0)]
            tracks['yaw']=[(0,0),(.35,-8),(.53,-12),(.72,-12),(1,0)]
            tracks['roll']=[(0,0),(.35,4),(.53,8),(.72,8),(1,0)]
            tracks['scaleY']=[(0,1),(.35,1.03),(.53,.96),(.72,.98),(1,1)]
            tracks['scaleX']=[(0,1),(.35,.98),(.53,1.035),(.72,1.02),(1,1)]
        if name in ('buttplant','fallVanish'):
            tracks['pitch']=[(0,0),(.32,-28),(.57,-68),(.76,-68),(.9,-12),(1,0)]
            tracks['yaw']=[(0,0),(.32,-12),(.57,-22),(.76,-22),(1,0)]
            tracks['roll']=[(0,0),(.32,-6),(.57,-12),(.76,-12),(1,0)]
            tracks['scaleY']=[(0,1),(.32,1.04),(.57,.96),(.76,.98),(1,1)]
            tracks['scaleX']=[(0,1),(.32,.97),(.57,1.035),(.76,1.02),(1,1)]
            tracks['eyeOpen']=[(0,1),(.24,0),(.76,0),(.88,.25),(1,1 if name=='buttplant' else 0)]
            for i in range(2):
                tracks[f'foot{i}X']=[(0,0),(.35,(1 if i else -1)*5),(.58,(1 if i else -1)*9),(.8,(1 if i else -1)*8),(1,0)]
                tracks[f'foot{i}Z']=[(0,0),(.35,12),(.58,16),(.8,15),(1,0)]
        if name=='sink':
            tracks['eyeOpen']=[(0,1),(.15,.1),(.35,1),(.55,0),(.75,.05),(1,0)]
        definitions[name]=(duration,tracks)
    definitions['ice']=(2400,{
        'lift':[(0,0),(.18,-9),(.40,2),(.65,1),(.82,-2),(1,0)],
        'pitch':[(0,0),(.18,-12),(.40,-65),(.72,-65),(.9,3),(1,0)],
        'yaw':[(0,0),(.18,8),(.4,20),(.72,20),(1,0)],
        'roll':[(0,0),(.18,-4),(.4,-10),(.72,-10),(1,0)],
        'scaleX':[(0,1),(.4,1.035),(.65,1.02),(1,1)],
        'scaleY':[(0,1),(.4,.96),(.72,.98),(1,1)],
        'eyeOpen':[(0,1),(.35,0),(.6,0),(1,1)],
        'arm0Z':[(0,0),(.4,8),(.7,4),(1,0)],'arm1Z':[(0,0),(.4,8),(.7,4),(1,0)],
        'foot0Z':[(0,0),(.4,8),(.7,6),(1,0)],'foot1Z':[(0,0),(.4,8),(.7,6),(1,0)],
    })
    definitions['balance']=(1800,{
        'roll':[(0,0),(.15,-10),(.32,12),(.5,-8),(.68,7),(.85,-3),(1,0)],
        'scaleX':[(0,1),(.32,.985),(.68,1.015),(1,1)],
        'scaleY':[(0,1),(.32,1.02),(.68,.99),(1,1)],
        'arm0Z':[(0,0),(.15,7),(.32,10),(.5,6),(.68,8),(1,0)],
        'arm1Z':[(0,0),(.15,10),(.32,7),(.5,9),(.68,6),(1,0)],
        'foot0X':[(0,0),(.32,-3),(.68,-2),(1,0)],'foot1X':[(0,0),(.32,2),(.68,3),(1,0)],
    })
    definitions['startle']=(850,{
        'lift':[(0,0),(.18,-10),(.50,-5),(.8,1),(1,0)],
        'roll':[(0,0),(.18,-8),(.5,4),(1,0)],
        'scaleX':[(0,1),(.18,.95),(.8,1.05),(1,1)],
        'scaleY':[(0,1),(.18,1.07),(.8,.94),(1,1)],
        'arm0Z':[(0,0),(.18,10),(.5,5),(1,0)],'arm1Z':[(0,0),(.18,10),(.5,5),(1,0)],
        'foot0Z':[(0,0),(.18,7),(.5,4),(1,0)],'foot1Z':[(0,0),(.18,7),(.5,4),(1,0)],
    })
    definitions['delight']=(1600,{
        'lift':[(0,0),(.18,-11),(.36,0),(.55,-8),(.72,0),(.86,-5),(1,0)],
        'scaleX':[(0,1),(.18,.98),(.36,1.04),(.55,.98),(.72,1.03),(1,1)],
        'scaleY':[(0,1),(.18,1.04),(.36,.95),(.55,1.03),(.72,.96),(1,1)],
        'arm0Z':[(0,0),(.18,8),(.36,3),(.55,8),(.72,3),(1,0)],
        'arm1Z':[(0,0),(.18,8),(.36,3),(.55,8),(.72,3),(1,0)],
    })
    all_channels={name for _,tracks in definitions.values() for name in tracks}
    for channel in all_channels:
        rig[channel]=1.0 if channel.startswith('scale') or channel=='eyeOpen' else 0.0
    definitions['fly'][1]['pitch']=[(0,-5),(.22,6),(.55,-3),(.75,-7),(1,-5)]
    definitions['fall'][1]['pitch']=[(0,0),(.25,18),(.72,-12),(1,0)]
    # Same spatial rotation order as the runtime volume: roll, yaw, pitch.
    # Blender's Y is depth (opposite runtime Z), and its Z is vertical.
    driver(body,'location',2,rig,'lift',base=37,gain=-1)
    driver(body,'rotation_euler',0,rig,'pitch',gain=math.pi/180)
    driver(body,'rotation_euler',1,rig,'roll',gain=-math.pi/180)
    driver(body,'rotation_euler',2,rig,'yaw',gain=math.pi/180)
    driver(body,'scale',0,rig,'scaleX')
    driver(body,'scale',2,rig,'scaleY')
    depth_driver=body.driver_add('scale',1)
    for channel in ('scaleX','scaleY'):
        var=depth_driver.driver.variables.new();var.name=channel
        var.targets[0].id=rig;var.targets[0].data_path='["'+channel+'"]'
    depth_driver.driver.expression='1/max(0.01,scaleX*scaleY)'
    for eye in eyes:
        driver(eye,'scale',2,rig,'eyeOpen',gain=6)
    for i,limb in enumerate(limbs):
        base=limb.location.copy()
        channel=('arm'+str(i)) if i<2 else ('foot'+str(i-2))
        driver(limb,'location',0,rig,channel+'X',base=base.x)
        driver(limb,'location',2,rig,channel+'Z',base=base.z-37)
        limb.parent=body
    # Editable orbital bubbles share the same angular control exported to QML.
    for i,offset in enumerate((3.35,.4,4.1,5.4,4.78,5.08,2.5,.03)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8)
        bubble=bpy.context.object
        bubble.name='Orbital bubble '+str(i+1)
        size=(13.5,14,11,6.5,4,4.5,4,3)[i]
        bubble.scale=(size/2,)*3; bubble.parent=body; bubble.data.materials.append(blue)
        for axis,expression in enumerate((f'47*cos(motion+{offset})',f'25*sin(motion+{offset})',f'3-37*sin(motion+{offset})')):
            curve=bubble.driver_add('location',axis)
            var=curve.driver.variables.new(); var.name='motion'
            var.targets[0].id=rig; var.targets[0].data_path='["angle"]'
            curve.driver.expression=expression
    # A parent authoring rig demonstrates actual displacement from an edge.
    body.parent=rig
    driver(rig,'location',1,rig,'normal',gain=98)
    driver(rig,'location',2,rig,'height',gain=42)
    driver(rig,'location',0,rig,'journey',gain=90)
    parity=[]
    for name,(duration,tracks) in definitions.items():
        action=bpy.data.actions.new('Wull — '+name.title())
        action.use_fake_user=True
        rig.animation_data.action=action
        frames=duration*60/1000
        for channel in sorted(all_channels):
            neutral=1 if channel.startswith('scale') or channel=='eyeOpen' else 0
            points=tracks.get(channel,[(0,neutral),(1,neutral)])
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
    scene.frame_start=1; scene.frame_end=121
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
