"""Check the deformed seated legs against the actual menu crate for a full loop."""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/menu/off_duty_crew.blend'))
rig = bpy.data.objects['ElfRig']
rig.animation_data.action = bpy.data.actions['menu_sit']
legs = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name.startswith(
    ('Tailored trousers', 'Single shaped boot', 'Fitted boot sole', 'Knitted sock'))]
actor_rotation = Matrix.Rotation(3.2, 3, 'Y')
crate_inverse = Matrix.Rotation(-.12, 3, 'Y')
actor_position = Vector((7.884, 0, -7.57))
crate_position = Vector((7.9, .23, -7.3))
minimum_gap = 100
minimum_ground = 100
collisions = []
for frame in range(1, 578, 4):
    bpy.context.scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    left_max, right_min = -100, 100
    for obj in legs:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        for vertex in mesh.vertices:
            p = evaluated.matrix_world @ vertex.co
            minimum_ground = min(minimum_ground, p.z)
            if obj.name.startswith(('Single shaped boot', 'Fitted boot sole')):
                if obj.name.endswith('L'):
                    left_max = max(left_max, p.x)
                elif obj.name.endswith('R'):
                    right_min = min(right_min, p.x)
            world = actor_position + actor_rotation @ Vector((p.x, p.z, -p.y))
            local = crate_inverse @ (world - crate_position)
            if abs(local.x) < .475-.005 and abs(local.y) < .23-.005 and abs(local.z) < .40-.005:
                collisions.append((frame, obj.name, tuple(local)))
                break
        evaluated.to_mesh_clear()
    minimum_gap = min(minimum_gap, right_min-left_max)
print('Minimum boot gap (m):', round(minimum_gap, 4))
print('Minimum ground clearance (m):', round(minimum_ground, 4))
print('Leg/crate penetrations:', len(collisions))
assert minimum_gap > .02, 'The boots overlap during the idle loop'
assert minimum_ground >= .0, 'A boot penetrates the snow'
assert not collisions, str(collisions[:6])
print('SEATED CREW CLEARANCE: PASS (145 poses across 24 seconds)')
