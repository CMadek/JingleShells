"""Validate the authored mug grip, sipping contact and wrap across 24 seconds."""
import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/menu/off_duty_crew.blend'))
rig = bpy.data.objects['ElfRig']
rig.animation_data.action = bpy.data.actions['menu_cocoa']
assert not any('cigarette' in material.name.lower() for material in bpy.data.materials)
assert 'SmokeTip' not in rig.data.bones
assert 'MugSteam' in rig.data.bones

def transform(name):
    bone = rig.pose.bones[name]
    return bone.matrix @ bone.bone.matrix_local.inverted()

maximum_grip_error = 0
maximum_lip_error = 0
minimum_rise, maximum_rise = 100, -100
for frame in range(1,578,4):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    mug = transform('Mug')
    hand = transform('ForearmR') @ Vector((.44,-.045,.65))
    grip = mug @ Vector((.23,0,-.015))
    maximum_grip_error = max(maximum_grip_error, (hand-grip).length)
    minimum_rise = min(minimum_rise, mug.translation.z)
    maximum_rise = max(maximum_rise, mug.translation.z)
    time = (frame-1)/24
    if 3 <= time <= 4.2 or 15 <= time <= 16.2:
        mouth = transform('Head') @ Vector((.025,-.234,1.395))
        lip = mug @ Vector((0,.106,.12))
        maximum_lip_error = max(maximum_lip_error, (mouth-lip).length)
print('Maximum mitten/handle gap (m):', round(maximum_grip_error,6))
print('Maximum sipping lip gap (m):', round(maximum_lip_error,6))
print('Mug lift (m):', round(maximum_rise-minimum_rise,4))
assert maximum_grip_error < .008, 'The hand loses the mug handle'
assert maximum_lip_error < .006, 'The mug does not reach the lips during the sip'
assert maximum_rise-minimum_rise > .25, 'The sipping lift must be visible'
print('MENU REFRESHMENTS: PASS (145 poses across 24 seconds)')
