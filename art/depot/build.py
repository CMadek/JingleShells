"""Build the Last Stop's fitted furniture and architectural trim. Coordinates use Godot metres."""
import math, sys
from pathlib import Path
import bpy
from mathutils import Vector
from math import pi

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from surface_wear import finish as weather, box_uv, woven
bpy.ops.wm.read_factory_settings(use_empty=True)
palette = {}
def mat(name, rgb, metal=0, grain=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs['Base Color'].default_value = (*rgb,1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = .37 if metal else .79
    if grain:
        weather(m,'wood',sum(map(ord,name)),rgb)
    return m
wood=[mat('Oiled timber '+str(i),(.16+i*.02,.078+i*.012,.036+i*.008),grain=True) for i in range(3)]
green=mat('Dispatch enamel',(.052,.138,.105)); gold=mat('Worn brass',(.53,.32,.105),.68)
red=mat('Oxblood upholstery',(.24,.045,.035)); welt=mat('Leather piping',(.38,.108,.062))
dark=mat('Japanned iron',(.035,.045,.048),.5); cream=mat('Linen',(.75,.64,.43))
brick=[mat('Fired brick '+str(i),(.22+.04*i,.073+.012*i,.046+.012*i)) for i in range(3)]
for material, family in [(red,'leather'),(green,'enamel')]+[(m,'brick') for m in brick]:
    weather(material,family,sum(map(ord,material.name)),material.diffuse_color[:3])
red.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value=.46
mortar=mat('Mortar',(.37,.32,.26)); spruce=mat('Fir needles',(.04,.14,.07))
def xyz(x,y,z):return (x+28,841-z,y)
def finish(o,m):o.data.materials.append(m);return o
def box(x,y,z,sx,sy,sz,m,r=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(x,y,z))
    o=bpy.context.object;o.dimensions=(sx,sz,sy)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    box_uv(o)
    if r:
        mod=o.modifiers.new('Roundover','BEVEL');mod.width=min(r,min(sx,sy,sz)*.46);mod.segments=3
        mod=o.modifiers.new('Highlights','WEIGHTED_NORMAL')
    return finish(o,m)
def ell(x,y,z,sx,sy,sz,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=xyz(x,y,z))
    o=bpy.context.object;o.scale=(sx,sz,sy)
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,m)
def rod(a,b,r,m,top=None):
    a,b=Vector(xyz(*a)),Vector(xyz(*b))
    bpy.ops.mesh.primitive_cone_add(vertices=18,radius1=r,radius2=r if top is None else top,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(o,m)
# Strip flooring, perimeter wainscoting, structural braces.
for i in range(33):
    x=-35.73+i*.48
    for j in range(3):
        z=832.16+j*5.88+(i%3)*.52
        lo=max(832.16,z-(i%3)*.52 if j==0 else z)
        hi=min(849.84,z+5.88 if j!=2 else 849.84)
        box(x,.077,(lo+hi)/2,.475,.024,hi-lo-.012,wood[(i*7+j)%3],.006)
for x in [-35.72,-32.2,-28.5,-24.8,-20.25]:
    box(x,2.25,832.27,.24,4.45,.26,wood[1])
    box(x+.33,3.88,832.43,.14,1.18,.15,wood[0]).rotation_euler.y=-.62
for i in range(26):
    box(-35.55+i*.60,.83,832.23,.59,1.5,.12,green)
box(-28,1.59,832.37,15.7,.10,.20,wood[2])
# Deep-buttoned club sofa with separate cushions, nailheads and rolled arms.
box(-34.64,.25,840.65,1.28,.24,4.75,wood[0],.06)
box(-35.20,.87,840.65,.30,1.26,4.64,red,.14)
for z in [839.2,840.65,842.1]:
    box(-34.66,.53,z,1.13,.31,1.41,red,.14)
    box(-34.62,.46,z,1.16,.042,1.39,welt,.018)
for z in [838.30,843.00]:
    box(-34.66,.62,z,1.46,.86,.27,red,.13)
    rod((-35.24,1.01,z),(-33.98,1.01,z),.19,red)
    ell(-33.98,1.01,z,.075,.205,.205,welt)
    for h in [.42,.57,.72,.87]:ell(-33.92,h,z,.025,.034,.034,gold)
# Reading table and enamel lamp.
box(-33.05,.58,840.65,1.13,.13,2.62,wood[2],.05)
for x in [-33.47,-32.63]:
    for z in [839.54,841.76]:rod((x,.09,z),(x,.55,z),.055,gold,.07)
rod((-34.7,.08,837.66),(-34.7,2.18,837.66),.045,gold)
rod((-34.7,.08,837.66),(-34.7,.19,837.66),.32,dark,.22)
rod((-34.7,1.84,837.66),(-34.7,2.27,837.66),.46,cream,.20)
# Counter panels, shelving, accounts, till.
for x in [-31.4,-29.95,-28.5,-27.05,-25.6]:
    box(x,.60,835.02,1.4,.87,.06,green,.025)
    box(x,.60,835.06,1.20,.66,.035,wood[1])
for h in [.18,1.02]:box(-28.5,h,835.07,7.45,.065,.08,gold)
for x in [-33.25,-23.75]:
    for h in [1.45,2.12,2.79]:
        box(x,h,832.76,2.36,.09,.77,wood[1])
        for k in range(5):
            box(x-.88+k*.43,h+.21,832.80,.36,.32,.53,green if k%3 else wood[2])
            box(x-.88+k*.43,h+.23,833.07,.18,.076,.018,cream)
box(-31.3,1.43,834.44,.70,.49,.53,green,.075)
box(-31.3,1.73,834.37,.55,.20,.28,gold,.04)
for i in range(5):ell(-31.53+i*.11,1.64,834.69,.033,.035,.033,cream)
# Chimney opening and staggered face courses. Throw lane runs alongside the east wall.
cx,cz=-22.2,842.5
for row in range(7):
    y=.2+row*.225
    for sign in [-1,1]:
        for i in range(4):
            box(cx-.57+i*.38,y,cz+sign*.66,.365,.216,.20,brick[(row+i)%3])
        for i in range(3):
            box(cx+sign*.66,y,cz-.4+i*.40,.20,.216,.38,brick[(row+i+1)%3])
for s in [-1,1]:
    box(cx,1.71,cz+s*.68,1.66,.18,.27,mortar,.03)
    box(cx+s*.69,1.71,cz,.27,.18,1.12,mortar,.03)
for z in [845.5,847.6]:
    box(cx,.094,z,1.85,.012,.045,cream,.003)
# Bell support and return chute
rod((-21.35,.08,842.42),(-21.35,2.45,842.42),.049,dark)
rod((-21.35,2.42,842.42),(-21.74,2.42,842.42),.04,dark)
rod((-21.74,2.1,842.42),(-21.74,2.4,842.42),.17,gold,.055)
for x in [-22.49,-21.91]:
    box(x,.35,844.21,.06,.18,1.92,wood[0]).rotation_euler.x=.17
box(-22.2,.30,844.21,.61,.08,1.92,wood[1]).rotation_euler.x=.17
# Framed dispatch signs, seasonal paper stars punched from retired forms.
for x,y,z,w,h in [(-28.5,3.23,832.58,5.6,.91),(-22.5,3.38,832.55,2.3,.65)]:
    box(x,y,z,w+.10,h+.10,.10,gold)
    box(x,y,z+.065,w,h,.10,green)
# A tartan runner, salvaged from a sleeping car. Keep the apron lane clear.
navy=mat('Indigo wool',(.033,.066,.070))
stripe=mat('Faded madder',(.22,.063,.049))
box(-33.73,.096,840.6,4.02,.013,6.34,navy)
woven(navy,(10,7),(.058,.092,.076),(.15,.074,.053))
# Lamps hang from conduit; cones have a contrasting warm enamel lining.
for x,z in [(-32.6,837.1),(-25.2,836.9),(-23.0,844.8)]:
    rod((x,3.38,z),(x,4.41,z),.018,dark)
    rod((x,3.24,z),(x,3.51,z),.34,green,.085)
    rod((x,3.225,z),(x,3.25,z),.33,cream,.33)
    ell(x,3.21,z,.085,.07,.085,cream)
# Braced rafters and a few diagonal stays, lighter marks where straps attach.
for z in [836.1,841.0,846.0]:
    for side in [-1,1]:
        x=-28+side*7.78
        rod((x,2.8,z),(x-side*1.75,4.15,z),.105,wood[0])
        box(x-side*.3,3.08,z,.23,.25,.26,dark,.018)
# Coat pegs and numbered pigeonholes beside the lounge.
box(-35.70,1.94,845.9,.17,.34,3.5,wood[1])
for i in range(5):
    z=844.50+i*.62
    rod((-35.62,1.92,z),(-35.42,2.01,z),.035,gold)
    if i in [1,3]:
        ell(-35.46,1.49,z,.12,.45,.23,green if i==1 else navy)
        ell(-35.44,1.45,z-.2,.12,.29,.09,green if i==1 else navy)
        ell(-35.44,1.45,z+.2,.12,.29,.09,green if i==1 else navy)
# Wrapping desk archive: worn ledger spines and brass pulls.
for i in range(8):
    x=-33.95+i*.20
    book=box(x,3.02,832.80,.17,.37+.04*(i%3),.42,stripe if i%3 else navy,.012)
    box(x,3.12,833.018,.14,.028,.012,gold,.003)
# The softer fittings and crew keepsakes use the same room-space mesh helpers.
from night_shift import dress
dress(box,ell,rod,mat,xyz,wood,green,gold,red,welt,dark,cream,spruce)
# Join static materials into a single low-draw-call exported scene.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
o=bpy.context.object;o.name='Last Stop fitted joinery'
dest=ROOT/'assets/depot/last_stop.glb'
dest.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_yup=True)
