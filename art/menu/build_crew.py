"""Menu-only acting on the shipped elf rig. Run with Blender --background --python.

The gameplay source/GLB are never modified. The 24-second actions share matching
end poses and tangents; the export is batched by material just like the game elf.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix

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

exec(compile((ROOT / 'art/menu/refreshments.py').read_text(), 'refreshments.py', 'exec'), globals())
exec(compile((ROOT / 'art/menu/tailoring.py').read_text(), 'tailoring.py', 'exec'), globals())

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

# The mug control and steam origin follow the animated cup, never the face.
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
mug = rig.data.edit_bones.new('Mug')
mug.head = (0,0,0)
mug.tail = (0,0,.12)
mug.parent = rig.data.edit_bones['Root']
tip = rig.data.edit_bones.new('MugSteam')
tip.head = (0,0,.15)
tip.tail = (0,0,.20)
tip.parent = mug
bpy.ops.object.mode_set(mode='OBJECT')

targets = {}

def solve_arm(side, wrist):
    """Two-link IK with a deliberate elbow plane, avoiding flared/swapped bends."""
    upper = rig.pose.bones['Arm'+side]
    lower = rig.pose.bones['Forearm'+side]
    spine = rig.pose.bones['Spine']
    parent = spine.matrix @ spine.bone.matrix_local.inverted()
    shoulder = parent @ upper.bone.head_local
    direction = Vector(wrist)-shoulder
    length = max(.001, min(direction.length, upper.length+lower.length-.0001))
    direction.normalize()
    sign = -1 if side == 'L' else 1
    pole = parent @ Vector((sign*.49,.10,.78))
    bend = pole-shoulder
    bend = (bend-direction*bend.dot(direction)).normalized()
    along = (upper.length**2-lower.length**2+length**2)/(2*length)
    elbow = shoulder+direction*along+bend*math.sqrt(max(0,upper.length**2-along**2))
    end = shoulder+direction*length
    for bone, start, finish in ((upper,shoulder,elbow),(lower,elbow,end)):
        rest = bone.bone
        rotation = (rest.tail_local-rest.head_local).rotation_difference(finish-start)
        bone.matrix = Matrix.Translation(start) @ rotation.to_matrix().to_4x4() @ rest.matrix_local.to_3x3().to_4x4()
        bpy.context.view_layer.update()

rig.animation_data_create()
def smooth_pulse(t, start, rise_end, fall_start, end):
    def ease(v):
        v = max(0, min(1, v))
        return v*v*v*(v*(v*6-15)+10)
    return ease((t-start)/(rise_end-start)) * (1-ease((t-fall_start)/(end-fall_start)))

for clip in ('menu_cocoa', 'menu_sit', 'menu_lean'):
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
        if clip == 'menu_cocoa':
            # Lift, tip gently against the lips, pause, and lower the mug.
            sip = smooth_pulse(time, 1.5, 3.0, 4.2, 5.8) + smooth_pulse(time, 13.5, 15.0, 16.2, 17.8)
            targets['L'] = (-.43, -.07, .70 + .015*math.sin(phase*2))
            bones['Spine'].rotation_euler.z = -.035 + .045*math.sin(phase*2)
            bones['Head'].rotation_euler.x = -.05*sip
            bones['Head'].rotation_euler.y = .18*math.sin(phase*2)*(1-sip)
            bones['Head'].rotation_euler.z *= 1-sip
            bpy.context.view_layer.update()
            mouth = bones['Head'].matrix @ bones['Head'].bone.matrix_local.inverted() @ Vector((.025,-.234,1.395))
            mug_rotation = Matrix.Rotation(-.28*sip,4,'X')
            sip_center = mouth - mug_rotation.to_3x3() @ Vector((0,.106,.12))
            mug_center = Vector((.14,-.46,1.00)).lerp(sip_center,sip)
            mug_transform = Matrix.Translation(mug_center) @ mug_rotation
            bones['Mug'].matrix = mug_transform @ bones['Mug'].bone.matrix_local
            grip = mug_transform @ Vector((.23,0,-.015))
            targets['R'] = grip.copy()
            # Correct for the mitten's offset from the forearm tail. The hand
            # stays wrapped around the handle as the arm bends and the cup tips.
            for adjustment in range(8):
                solve_arm('R', targets['R'])
                hand = bones['ForearmR'].matrix @ bones['ForearmR'].bone.matrix_local.inverted() @ Vector((.44,-.045,.65))
                targets['R'] += grip-hand
        elif clip == 'menu_sit':
            # Seat is .46m high, with the pelvis at the front edge. Rotate the
            # thighs out at the hips so both boots clear each other throughout.
            bones['Root'].location.y = -.07
            bones['Spine'].rotation_euler.x = .09 + .035 * math.sin(phase * 3)
            bones['ThighL'].rotation_euler = (-1.48, .20, 0)
            bones['ThighR'].rotation_euler = (-1.42, -.20, 0)
            bones['ShinL'].rotation_euler.x = 1.14 + .48 * math.sin(phase * 6)
            bones['ShinR'].rotation_euler.x = 1.20 + .46 * math.sin(phase * 6 + math.pi)
            targets['L'] = (-.32, -.38, .83)
            targets['R'] = (.32, -.37, .84)
            bones['Head'].rotation_euler.y = -.10 + .23 * math.sin(phase * 2)
            bones['Head'].rotation_euler.x = .04*math.sin(phase*6)
        else:
            checking = smooth_pulse(time, 3, 4.2, 7.3, 8.7) + smooth_pulse(time, 16, 17.2, 19.3, 20.7)
            bones['Spine'].rotation_euler.z = .035 + .045*math.sin(phase)
            targets['L'] = Vector((-.46,-.04,.76)).lerp(Vector((-.16,-.42,1.06)), checking)
            targets['R'] = (.43,-.10,.73)
            bones['Head'].rotation_euler.x = .43*checking
            bones['Head'].rotation_euler.y = (.20 + .18*math.sin(phase))*(1-checking) - .24*checking
        bpy.context.view_layer.update()
        solve_arm('L', targets['L'])
        solve_arm('R', targets['R'])
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
