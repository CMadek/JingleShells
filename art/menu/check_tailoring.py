"""Sample scarf/chest clearance and relaxed elbow positions in every menu clip."""
import bpy
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/menu/off_duty_crew.blend'))
rig = bpy.data.objects['ElfRig']
scarf = bpy.data.objects['Folded knitted scarf']
coat = bpy.data.objects['Joined plush coat and sleeves']
# The top is deliberately sewn into the collar; test the hanging cloth below it.
tail = [v.index for v in scarf.data.vertices if (scarf.matrix_world @ v.co).z < 1.19]
worst = (100, '', 0)
maximum_elbow_width = 0
for clip in ('menu_cocoa', 'menu_sit', 'menu_lean'):
    rig.animation_data.action = bpy.data.actions[clip]
    for frame in range(1,578,4):
        bpy.context.scene.frame_set(frame)
        graph = bpy.context.evaluated_depsgraph_get()
        evaluated = coat.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        tree = BVHTree.FromPolygons([evaluated.matrix_world @ v.co for v in mesh.vertices],
                                   [p.vertices[:] for p in mesh.polygons])
        evaluated.to_mesh_clear()
        evaluated = scarf.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        for index in tail:
            point = evaluated.matrix_world @ mesh.vertices[index].co
            nearest, normal, _, distance = tree.find_nearest(point)
            signed = distance if (point-nearest).dot(normal) >= 0 else -distance
            if signed < worst[0]: worst = (signed,clip,frame)
        evaluated.to_mesh_clear()
        for side in ('L','R'):
            maximum_elbow_width = max(maximum_elbow_width, abs(rig.pose.bones['Forearm'+side].head.x))
print('Minimum hanging scarf / coat clearance (m), clip, frame:',worst)
print('Maximum elbow lateral offset (m):',maximum_elbow_width)
assert worst[0] > .003, 'Scarf penetrates or touches the coat during acting'
assert maximum_elbow_width < .55, 'An elbow flares unnaturally outward'
assert 'Fitted continuous hair' in bpy.data.objects
assert not any(o.name.startswith('Hair side curl') for o in bpy.data.objects)
print('MENU TAILORING: PASS (435 poses across three loops)')
