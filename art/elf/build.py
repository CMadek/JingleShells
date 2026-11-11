import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(n,c):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1); m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85; return m
pine=mat('Coat',(.075,.22,.15)); red=mat('Cranberry',(.48,.065,.08)); cream=mat('Wool',(.87,.77,.53)); skin=mat('Skin',(.72,.43,.27)); dark=mat('Leather',(.09,.055,.04)); gold=mat('Brass',(.65,.38,.10)); ink=mat('Ink',(.025,.035,.035))
parts=[]
def ell(n,p,s,m,b='Spine'):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=p); o=bpy.context.object; o.name=n; o.scale=s; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 parts.append((o,b)); return o
def loft(n,rings,m,b):
 verts=[]; faces=[]; count=20
 for x,y,z,rx,ry in rings:
  for i in range(count):
   a=i*math.tau/count; verts.append((x+math.cos(a)*rx,y+math.sin(a)*ry,z))
 for j in range(len(rings)-1):
  for i in range(count):faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
 faces.extend([tuple(range(count-1,-1,-1)),tuple((len(rings)-1)*count+i for i in range(count))])
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(n,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(m)
 for f in mesh.polygons:f.use_smooth=True
 parts.append((o,b));return o
loft('Tailored flight jacket',[(0,0,.66,.25,.19),(0,0,.74,.29,.21),(0,0,1.04,.27,.20),(0,0,1.20,.32,.18),(0,0,1.27,.18,.14)],pine,'Spine')
ell('Head',(0,-.025,1.49),(.245,.205,.265),skin,'Head')
ell('Nose',(0,-.235,1.47),(.065,.065,.055),skin,'Head')
for side in [-1,1]:
 suffix='L' if side<0 else 'R'
 loft('Pointed ear '+suffix,[(side*.19,0,1.42,.05,.08),(side*.32,0,1.52,.075,.045),(side*.43,.015,1.65,.004,.004)],skin,'Head')
 ell('Cheek '+suffix,(side*.13,-.17,1.43),(.065,.04,.05),red,'Head')
 ell('Eye '+suffix,(side*.085,-.218,1.53),(.024,.014,.033),ink,'Head')
 ell('Eye glint '+suffix,(side*.08,-.231,1.54),(.007,.006,.009),cream,'Head')
 ell('Brow '+suffix,(side*.09,-.208,1.59),(.055,.014,.015),dark,'Head')
 ell('Trouser '+suffix,(side*.145,0,.53),(.12,.14,.23),red,'Thigh'+suffix)
 ell('Sock '+suffix,(side*.145,0,.27),(.10,.105,.14),cream,'Shin'+suffix)
 ell('Boot '+suffix,(side*.145,-.08,.12),(.14,.23,.12),dark,'Shin'+suffix)
 ell('Boot strap '+suffix,(side*.145,-.07,.205),(.145,.15,.035),gold,'Shin'+suffix)
 ell('Sleeve '+suffix,(side*.35,0,1.07),(.125,.13,.23),pine,'Arm'+suffix)
 ell('Forearm '+suffix,(side*.39,-.025,.84),(.10,.11,.16),pine,'Forearm'+suffix)
 ell('Cuff '+suffix,(side*.40,-.035,.74),(.11,.12,.06),cream,'Forearm'+suffix)
 ell('Mitten '+suffix,(side*.40,-.045,.65),(.11,.095,.115),dark,'Forearm'+suffix)
 ell('Thumb '+suffix,(side*.32,-.08,.67),(.05,.06,.065),dark,'Forearm'+suffix)
 ell('Pocket '+suffix,(side*.16,-.19,.88),(.10,.035,.10),red)
 ell('Goggle rim '+suffix,(side*.105,-.17,1.77),(.085,.035,.065),gold,'Head')
 ell('Goggle glass '+suffix,(side*.105,-.198,1.77),(.063,.015,.045),ink,'Head')
for z in [.85,1.0,1.14]:ell('Brass toggle',(0,-.211,z),(.025,.02,.023),gold)
loft('Folded knitted cap',[(0,0,1.65,.25,.20),(0,0,1.79,.245,.19),(.06,.02,1.94,.15,.13),(.20,.02,2.0,.09,.08),(.29,.01,1.91,.015,.015)],red,'Head')
ell('Cap brim',(0,0,1.69),(.26,.215,.055),cream,'Head');ell('Pom pom',(.29,.01,1.90),(.075,.07,.075),cream,'Head')
ell('Scarf collar',(0,0,1.27),(.23,.18,.07),cream)
loft('Scarf tail',[(.11,-.205,1.25,.055,.025),(.13,-.22,1.08,.06,.025),(.18,-.22,.99,.055,.025)],cream,'Spine')
# A small stitched smile, modeled as a bevelled curve.
curve=bpy.data.curves.new('Smile','CURVE');curve.dimensions='3D';curve.bevel_depth=.008;curve.bevel_resolution=2
spline=curve.splines.new('POLY');spline.points.add(8)
for i,p in enumerate(spline.points):
 x=(i-4)*.012;p.co=(x,-.216,1.384 + (x/.048)**2*.018,1)
o=bpy.data.objects.new('Smile',curve);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.data.materials.append(dark);parts.append((o,'Head'))
# A single deform rig; deliberately rigid garment panels retain the print-like silhouette.
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='ElfRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(n,h,t,parent=None):
 b=rig.data.edit_bones.new(n);b.head=h;b.tail=t
 if parent:b.parent=rig.data.edit_bones[parent]
bone('Root',(0,0,0),(0,0,.2));bone('Spine',(0,0,.70),(0,0,1.25),'Root');bone('Head',(0,0,1.25),(0,0,1.7),'Spine')
for side in [-1,1]:
 s='L' if side<0 else 'R';bone('Thigh'+s,(side*.145,0,.7),(side*.145,0,.36),'Root');bone('Shin'+s,(side*.145,0,.36),(side*.145,0,.10),'Thigh'+s);bone('Arm'+s,(side*.30,0,1.22),(side*.38,0,.94),'Spine');bone('Forearm'+s,(side*.38,0,.94),(side*.40,0,.68),'Arm'+s)
bone('CargoSocket',(0,-.48,1.0),(0,-.48,1.10),'Spine')
bpy.ops.object.mode_set(mode='OBJECT')
for o,b in parts:
 vg=o.vertex_groups.new(name=b);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('Crew rig','ARMATURE');mod.object=rig;o.parent=rig
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
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art/elf/flight_elf.blend')
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/elf/flight_elf.glb',export_animation_mode='ACTIONS',export_anim_slide_to_zero=True)
# Separate camera-space sleeves and mittens. Godot import maps Blender +Y to camera -Z.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);parts=[]
for side in [-1,1]:
 ell('Sleeve',(side*.30,.15,-.40),(.105,.28,.105),pine)
 ell('Wool cuff',(side*.28,.40,-.32),(.11,.065,.10),cream)
 ell('Mitten',(side*.27,.49,-.28),(.09,.12,.095),dark)
 ell('Thumb',(side*.20,.49,-.23),(.045,.07,.05),dark)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art/elf/first_person_arms.blend')
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/elf/first_person_arms.glb')
print('ELF EXPORT COMPLETE')




