"""Shareable group portrait of the actual three in-game crew palettes."""
import bpy, math, os
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/elf/share';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/elf/flight_elf.blend'))
scene=bpy.context.scene
source=list(scene.objects)
source_rig=bpy.data.objects['ElfRig']
coat=bpy.data.materials['Coat']
mask=bpy.data.images.load(str(ROOT/'assets/elf/textures/crew_coat_tint.png'),check_existing=True)
mask.colorspace_settings.name='Non-Color'

def linear_hex(value):
    values=[int(value[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in values)

def crew_coat(name,color):
    material=coat.copy();material.name=name
    nodes=material.node_tree.nodes;links=material.node_tree.links
    pbr=nodes['Principled BSDF'];paint=pbr.inputs['Base Color'].links[0].from_socket
    tex=nodes.new('ShaderNodeTexImage');tex.image=mask;tex.interpolation='Linear'
    delta=nodes.new('ShaderNodeVectorMath');delta.operation='SCALE'
    delta.inputs[0].default_value=tuple(c-base for c,base in zip(linear_hex(color),(.035,.145,.106)))
    links.new(tex.outputs['Color'],delta.inputs['Scale'])
    combine=nodes.new('ShaderNodeVectorMath');combine.operation='ADD'
    links.new(paint,combine.inputs[0]);links.new(delta.outputs['Vector'],combine.inputs[1])
    links.new(combine.outputs['Vector'],pbr.inputs['Base Color'])
    return material

for name,color,x,y,angle in [('Spruce','254e38',-1.32,.10,9),('Cranberry','78323d',0,-.10,0),('Midnight','354d65',1.32,.10,-9)]:
    material=crew_coat(name+' coat',color)
    anchor=bpy.data.objects.new(name+' crew',None);scene.collection.objects.link(anchor)
    anchor.location=(x,y,0);anchor.rotation_euler.z=math.radians(angle)
    copies={}
    for original in source:
        clone=original.copy()
        if original.type=='ARMATURE':clone.data=original.data.copy()
        scene.collection.objects.link(clone);copies[original]=clone
    rig=copies[source_rig]
    rig.animation_data.action=bpy.data.actions['idle']
    for original,clone in copies.items():
        clone.parent=copies.get(original.parent,anchor)
        for modifier in clone.modifiers:
            if modifier.type=='ARMATURE':modifier.object=rig
        if clone.type=='MESH':
            for slot in clone.material_slots:
                if slot.material==coat:
                    slot.link='OBJECT';slot.material=material
for original in source:bpy.data.objects.remove(original,do_unlink=True)
scene.frame_set(7)

def material(name,color,roughness=.8,emission=False):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=roughness
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=.75
    return m

floor=material('Deep spruce studio',(.055,.095,.078))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006))
bpy.context.object.name='Seamless studio floor';bpy.context.object.data.materials.append(floor)
world=bpy.data.worlds.new('Winter studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.40,.45,.50,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4;scene.world=world

for name,location,power,size,color in [
    ('Softbox',(-3,-4,6),700,5,(1,.90,.77)),
    ('Cool fill',(4,-2,3.5),400,4,(.79,.87,1)),
    ('Warm edge',(0,3,5),700,3,(1,.83,.61))]:
    bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.name=name
    light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.data.color=color
    light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()

bpy.ops.object.camera_add(location=(0,-10,2.85));camera=bpy.context.object;scene.camera=camera
target=Vector((0,0,1.12));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=5.35;camera.data.lens=65
ink=material('Title warm cream',(.92,.81,.60),emission=True)
gold=material('Subtitle brass',(.55,.36,.15),emission=True)
font_file=Path('C:/Windows/Fonts/georgiab.ttf')
font=bpy.data.fonts.load(str(font_file)) if font_file.exists() else None
rotation=camera.rotation_euler.to_quaternion()
right=rotation@Vector((1,0,0));up=rotation@Vector((0,1,0));normal=rotation@Vector((0,0,1))
def title(text,height,size,mat,spacing=1.0):
    curve=bpy.data.curves.new(text,'FONT');curve.body=text;curve.align_x='CENTER';curve.align_y='CENTER'
    curve.size=size;curve.space_character=spacing
    if font:curve.font=font
    obj=bpy.data.objects.new(text,curve);scene.collection.objects.link(obj)
    obj.location=target+up*height+normal*.5;obj.rotation_euler=camera.rotation_euler
    obj.data.materials.append(mat);obj.visible_shadow=False
title('JINGLE SHELLS',1.34,.24,ink,1.10)
title('THE NORTH STAR CREW',1.08,.080,gold,1.24)

scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=64;scene.cycles.use_denoising=True
scene.render.resolution_x=2560;scene.render.resolution_y=1600;scene.render.resolution_percentage=100
scene.render.film_transparent=False;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB'
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.filepath=str(OUT/'jingle-shells-crew.png')
bpy.ops.render.render(write_still=True)
scene.render.image_settings.file_format='JPEG';scene.render.image_settings.quality=95
bpy.data.images['Render Result'].save_render(str(OUT/'jingle-shells-crew.jpg'),scene=scene)
print('SHARE RENDER COMPLETE',flush=True)
