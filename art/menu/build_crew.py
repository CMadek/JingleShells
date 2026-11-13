"""Menu-only acting on the shipped elf rig. Run with Blender --background --python.

The gameplay source/GLB are never modified. The 24-second actions share matching
end poses and tangents; the export is batched by material just like the game elf.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/menu'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/elf/flight_elf.blend'))
bpy.context.preferences.filepaths.save_version = 0
rig = bpy.data.objects['ElfRig']
rig.animation_data_clear()
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
scene = bpy.context.scene
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 577

# A discreet cigarette sits at the corner of the mouth; the mitten touches it
# during the inhale, rather than a floating prop sliding through the face.
def material(name, color, emission=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .9
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*color, 1)
        bsdf.inputs['Emission Strength'].default_value = 1.8
    return m

paper = material('Cigarette paper', (.80, .74, .58))
ember = material('Cigarette ember', (.95, .18, .035), True)
ash = material('Cigarette ash', (.18, .15, .13))
start = Vector((.055, -.239, 1.398))
end = Vector((.095, -.385, 1.378))
axis = (end - start).normalized()
for name, a, b, radius, mat in [
    ('Cigarette', start, end, .009, paper),
    ('Burning tip', end, end + axis * .009, .0095, ember),
    ('Ash tip', end + axis * .009, end + axis * .015, .008, ash),
]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=(b-a).length, location=(a+b)/2)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    group = o.vertex_groups.new(name='Head')
    group.add(list(range(len(o.data.vertices))), 1, 'REPLACE')
    modifier = o.modifiers.new('Crew rig', 'ARMATURE')
    modifier.object = rig
    o.parent = rig

# A real watch makes the checking gesture readable rather than miming a prop.
watch_brass = material('Watch brass', (.52, .34, .13))
watch_dark = material('Watch dial and strap', (.025, .035, .031))
watch_cream = material('Watch hands', (.88, .79, .55))
def bind_watch(o, mat):
    o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    group = o.vertex_groups.new(name='ForearmL')
    group.add(list(range(len(o.data.vertices))), 1, 'REPLACE')
    o.modifiers.new('Crew rig', 'ARMATURE').object = rig
    o.parent = rig

bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8, location=(-.44,-.023,.805), major_radius=.106, minor_radius=.013)
bpy.context.object.name = 'Watch leather strap'
bind_watch(bpy.context.object, watch_dark)
for name, radius, depth, y, mat in [
    ('Watch bezel', .064, .023, -.140, watch_brass),
    ('Watch face', .052, .006, -.155, watch_dark),
]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=(-.44,y,.805), rotation=(math.pi/2,0,0))
    bpy.context.object.name = name
    bind_watch(bpy.context.object, mat)
for tip in [Vector((-.44,-.161,.841)), Vector((-.413,-.161,.791))]:
    center = Vector((-.44,-.161,.805))
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=.003, depth=(tip-center).length, location=(center+tip)*.5)
    o = bpy.context.object
    o.name = 'Watch hand'
    o.rotation_euler = (tip-center).to_track_quat('Z','Y').to_euler()
    bind_watch(o, watch_cream)

exec(compile((ROOT / 'art/menu/faces.py').read_text(), 'faces.py', 'exec'), globals())

# Marker bone gives Godot an exact smoke origin that follows the head animation.
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
tip = rig.data.edit_bones.new('SmokeTip')
tip.head = end + axis * .015
tip.tail = tip.head + Vector((0, 0, .04))
tip.parent = rig.data.edit_bones['Head']
bpy.ops.object.mode_set(mode='OBJECT')

targets = {}
constraints = []
for side in ('L', 'R'):
    target = bpy.data.objects.new('Hand target ' + side, None)
    scene.collection.objects.link(target)
    targets[side] = target
    ik = rig.pose.bones['Forearm' + side].constraints.new('IK')
    ik.target = target
    ik.chain_count = 2
    ik.use_stretch = False
    constraints.append(ik)

rig.animation_data_create()
def smooth_pulse(t, start, rise_end, fall_start, end):
    def ease(v):
        v = max(0, min(1, v))
        return v*v*v*(v*(v*6-15)+10)
    return ease((t-start)/(rise_end-start)) * (1-ease((t-fall_start)/(end-fall_start)))

for clip in ('menu_smoke', 'menu_sit', 'menu_lean'):
    samples = []
    for frame in range(1, 578, 4):
        phase = (frame - 1) / 576 * math.tau
        time = (frame - 1) / 24
        scene.frame_set(frame)
        for p in rig.pose.bones:
            p.rotation_mode = 'XYZ'
            p.rotation_euler = (0, 0, 0)
            p.location = (0, 0, 0)
        bones = rig.pose.bones
        # Keep feet planted; breathing lives in the chest/head, not root bobbing.
        bones['Spine'].rotation_euler.x = .025 * math.sin(phase * 4)
        bones['Head'].rotation_euler.y = .18 * math.sin(phase)
        bones['Head'].rotation_euler.z = .035 * math.cos(phase * 2)
        bones['Scarf'].rotation_euler.x = -.025 + .018 * math.sin(phase * 3)
        bones['Scarf'].rotation_euler.z = .025 * math.sin(phase * 2)
        if clip == 'menu_smoke':
            # A slow inhale, a pause, then the hand lowers onto the hip.
            inhale = smooth_pulse(time, 1.5, 2.6, 4.4, 5.6) + smooth_pulse(time, 13.5, 14.6, 16.4, 17.6)
            targets['R'].location = Vector((.46, -.13, .91)).lerp(Vector((.09, -.295, 1.36)), inhale)
            targets['L'].location = (-.47, -.10, .80 + .035*math.sin(phase*2))
            bones['Spine'].rotation_euler.z = -.035 + .045*math.sin(phase*2)
            bones['Head'].rotation_euler.x = -.025 - .10*smooth_pulse(time, 5, 6, 6.7, 7.8)
            bones['Head'].rotation_euler.y = .23*math.sin(phase*2) * (1-.5*inhale)
        elif clip == 'menu_sit':
            # Seat is .46m high, with the pelvis at the front edge. Rotate the
            # thighs out at the hips so both boots clear each other throughout.
            bones['Root'].location.y = -.07
            bones['Spine'].rotation_euler.x = .09 + .035 * math.sin(phase * 3)
            bones['ThighL'].rotation_euler = (-1.48, .20, 0)
            bones['ThighR'].rotation_euler = (-1.42, -.20, 0)
            bones['ShinL'].rotation_euler.x = 1.14 + .48 * math.sin(phase * 6)
            bones['ShinR'].rotation_euler.x = 1.20 + .46 * math.sin(phase * 6 + math.pi)
            targets['L'].location = (-.32, -.38, .83)
            targets['R'].location = (.32, -.37, .84)
            bones['Head'].rotation_euler.y = -.10 + .23 * math.sin(phase * 2)
            bones['Head'].rotation_euler.x = .04*math.sin(phase*6)
        else:
            checking = smooth_pulse(time, 3, 4.2, 7.3, 8.7) + smooth_pulse(time, 16, 17.2, 19.3, 20.7)
            bones['Spine'].rotation_euler.z = .035 + .045*math.sin(phase)
            targets['L'].location = Vector((-.48,.015,.91)).lerp(Vector((-.16,-.42,1.06)), checking)
            targets['R'].location = (.39,-.19,.88)
            bones['Head'].rotation_euler.x = .43*checking
            bones['Head'].rotation_euler.y = (.20 + .18*math.sin(phase))*(1-checking) - .24*checking
        bpy.context.view_layer.update()
        # Bake IK to ordinary local bone transforms; no runtime constraints.
        matrices = {p.name: p.matrix.copy() for p in bones}
        local = {}
        for p in bones:
            parent = p.parent
            local[p.name] = p.bone.convert_local_to_pose(
                matrices[p.name], p.bone.matrix_local,
                parent_matrix=matrices[parent.name] if parent else None,
                parent_matrix_local=parent.bone.matrix_local if parent else None,
                invert=True,
            ) if parent else p.bone.matrix_local.inverted() @ matrices[p.name]
        samples.append((frame, local))
    for ik in constraints:
        ik.mute = True
    action = bpy.data.actions.new(clip)
    rig.animation_data.action = action
    for frame, transforms in samples:
        for p in rig.pose.bones:
            loc, rot, scale = transforms[p.name].decompose()
            p.rotation_mode = 'QUATERNION'
            p.location = loc
            p.rotation_quaternion = rot
            p.scale = scale
            p.keyframe_insert('location', frame=frame)
            p.keyframe_insert('rotation_quaternion', frame=frame)
            p.keyframe_insert('scale', frame=frame)
    track = rig.animation_data.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, 1, action)
    track.mute = True
    rig.animation_data.action = None
    for ik in constraints:
        ik.mute = False

for side in ('L', 'R'):
    for constraint in list(rig.pose.bones['Forearm' + side].constraints):
        rig.pose.bones['Forearm' + side].constraints.remove(constraint)
    bpy.data.objects.remove(targets[side], do_unlink=True)
for p in rig.pose.bones:
    p.location = (0, 0, 0)
    p.rotation_quaternion = (1, 0, 0, 0)
    p.scale = (1, 1, 1)
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'art/menu/off_duty_crew.blend'))

# Export compact batches, retaining the separated editable source above.
buckets = {}
for o in list(scene.objects):
    if o.type == 'MESH':
        buckets.setdefault(o.data.materials[0], []).append(o)
for mat, objects in buckets.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    bpy.context.object.name = 'Crew ' + mat.name
bpy.ops.export_scene.gltf(filepath=str(OUT / 'off_duty_crew.glb'), export_animation_mode='ACTIONS', export_anim_slide_to_zero=True)
print('MENU CREW EXPORT COMPLETE')
