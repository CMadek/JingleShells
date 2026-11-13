import bpy, math, os, sys
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
sys.path.insert(0,os.path.join(ROOT,'art'))
import material_library as surfaces
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(n,c):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1); m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85; return m
pine=mat('Coat',surfaces.PALETTE['spruce']); red=mat('Cranberry',surfaces.PALETTE['cranberry']); cream=mat('Wool',surfaces.PALETTE['cream']); skin=mat('Skin',(.67,.39,.25)); dark=mat('Leather',surfaces.PALETTE['leather']); gold=mat('Brass',surfaces.PALETTE['brass']); ink=mat('Ink',(.022,.030,.028))
for m in (pine,red,cream):surfaces.finish(m,'wool',.92,0)
surfaces.finish(dark,'leather',.76,0)
surfaces.finish(gold,'brass',.32,.72)
skin.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.67
parts=[]
def ell(n,p,s,m,b='Spine'):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=p); o=bpy.context.object; o.name=n; o.scale=s; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 parts.append((o,b)); return o
def loft(n,rings,m,b):
 verts=[]; faces=[]; count=32
 for x,y,z,rx,ry in rings:
  for i in range(count):
   a=i*math.tau/count; verts.append((x+math.cos(a)*rx,y+math.sin(a)*ry,z))
 for j in range(len(rings)-1):
  for i in range(count):faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
 faces.extend([tuple(range(count-1,-1,-1)),tuple((len(rings)-1)*count+i for i in range(count))])
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(n,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(m)
 for f in mesh.polygons:f.use_smooth=True
 parts.append((o,b));return o
exec(compile(open(os.path.join(ROOT,'art/elf/character.py'),encoding='utf-8').read(),'character.py','exec'),globals())
exec(compile(open(os.path.join(ROOT,'art/elf/surface_paint.py'),encoding='utf-8').read(),'surface_paint.py','exec'),globals())
paint_surfaces('crew')
# Keep the gameplay rig; continuous garments blend through shoulders, elbows and knees.
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='ElfRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(n,h,t,parent=None):
 b=rig.data.edit_bones.new(n);b.head=h;b.tail=t
 if parent:b.parent=rig.data.edit_bones[parent]
bone('Root',(0,0,0),(0,0,.2));bone('Spine',(0,0,.70),(0,0,1.25),'Root');bone('Head',(0,0,1.25),(0,0,1.7),'Spine')
for side in [-1,1]:
 s='L' if side<0 else 'R';bone('Thigh'+s,(side*.145,0,.7),(side*.145,0,.36),'Root');bone('Shin'+s,(side*.145,0,.36),(side*.145,0,.10),'Thigh'+s);bone('Arm'+s,(side*.30,0,1.22),(side*.38,0,.94),'Spine');bone('Forearm'+s,(side*.38,0,.94),(side*.40,0,.68),'Arm'+s)
bone('CargoSocket',(0,-.48,1.0),(0,-.48,1.10),'Spine')
bone('Scarf',(.11,-.205,1.25),(.18,-.22,1.01),'Spine')
bpy.ops.object.mode_set(mode='OBJECT')
for o,b in parts:
 surfaces.planar_uv(o,.10)
 if callable(b):
  groups={}
  for v in o.data.vertices:
   weights=b(o.matrix_world @ v.co)
   total=sum(weights.values())
   for name,weight in weights.items():
    if weight<.0001:continue
    if name not in groups:groups[name]=o.vertex_groups.new(name=name)
    groups[name].add([v.index],weight/total,'REPLACE')
 else:
  vg=o.vertex_groups.new(name=b);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
 mod=o.modifiers.new('Crew rig','ARMATURE');mod.object=rig;o.parent=rig
rig.animation_data_create()
clips=['idle','walk','jump','land','crouch_idle','crouch_walk','crouch_carry_idle','crouch_carry_walk','pickup','carry_idle','carry_walk','charge','throw','drop','helm']
for clip in clips:
 action=bpy.data.actions.new(clip);rig.animation_data.action=action
 for frame in [1,7,13,19,25]:
  phase=(frame-1)/24*math.tau
  for p in rig.pose.bones:p.rotation_mode='XYZ';p.rotation_euler=(0,0,0);p.location=(0,0,0)
  crouch=clip.startswith('crouch');moving='walk' in clip;carry='carry' in clip or clip in ['pickup','charge','throw','drop','helm']
  rig.pose.bones['Root'].location.y=-.35 if crouch else math.sin(phase)*.008
  if crouch:rig.pose.bones['Spine'].rotation_euler.x=.55
  # An anchored, outward sway keeps the scarf on the visible third-person rig.
  rig.pose.bones['Scarf'].rotation_euler.x=-.04-(.14*abs(math.sin(phase)) if moving else .012*math.sin(phase))
  rig.pose.bones['Scarf'].rotation_euler.z=(.075 if moving else .012)*math.sin(phase)
  for side in ['L','R']:
   sign=1 if side=='L' else -1
   rig.pose.bones['Thigh'+side].rotation_euler.x=(-1.4 if crouch else 0)+(math.sin(phase)*.5*sign if moving else 0)
   rig.pose.bones['Shin'+side].rotation_euler.x=2.1 if crouch else (-.35 if clip=='jump' else 0)
   rig.pose.bones['Arm'+side].rotation_euler.x=(-.65 if carry else 0)+(math.sin(phase)*.35*-sign if moving and not carry else 0)
   rig.pose.bones['Forearm'+side].rotation_euler.x=-.85 if carry else -.15
   if carry:rig.pose.bones['Arm'+side].rotation_euler.z=-.20 if side=='L' else .20
   if clip=='land':rig.pose.bones['Root'].location.y=-.06*math.sin((frame-1)/24*math.pi)
   if clip=='jump':rig.pose.bones['Thigh'+side].rotation_euler.x=-.25
   if clip=='drop':rig.pose.bones['Forearm'+side].rotation_euler.x=-.85+.6*math.sin((frame-1)/24*math.pi)
   if clip=='charge':rig.pose.bones['Arm'+side].rotation_euler.x=-1.15
   if clip=='throw':rig.pose.bones['Arm'+side].rotation_euler.x=-1.6*(1-(frame-1)/24)
   if clip=='pickup':rig.pose.bones['Spine'].rotation_euler.x=.18*math.sin((frame-1)/24*math.pi)
  for p in rig.pose.bones:p.keyframe_insert('rotation_euler',frame=frame);p.keyframe_insert('location',frame=frame)
 track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action);track.mute=True
rig.animation_data.action=None
for p in rig.pose.bones:p.rotation_euler=(0,0,0);p.location=(0,0,0)
def batch_materials():
 # Keep the editable file separated, but submit one skinned mesh per material.
 # Blender's join preserves named bone groups, UVs and the active armature.
 buckets={}
 for o in list(bpy.context.scene.objects):
  if o.type=='MESH':buckets.setdefault(o.data.materials[0],[]).append(o)
 for material,objects in buckets.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  if len(objects)>1:bpy.ops.object.join()
  bpy.context.object.name='Crew '+material.name
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art/elf/flight_elf.blend')
batch_materials()
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/elf/flight_elf.glb',export_animation_mode='ACTIONS',export_anim_slide_to_zero=True)
# Separate camera-space sleeves and mittens. Godot import maps Blender +Y to camera -Z.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);parts=[]
first_person_arms()
paint_surfaces('hands')
for o,b in parts:surfaces.planar_uv(o,.10)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art/elf/first_person_arms.blend')
batch_materials()
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/elf/first_person_arms.glb')
print('ELF EXPORT COMPLETE')




