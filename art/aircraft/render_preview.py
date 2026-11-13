import bpy, sys
from mathutils import Vector
from pathlib import Path
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio sky')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.30,.37,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
side_view="--side" in sys.argv
bpy.ops.object.camera_add(location=(-40,1,7) if side_view else (32,36,13))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,-2,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=44
scene.camera=cam
for loc,energy,size in [((2,10,25),5500,20),((-22,0,12),3500,18),((10,-24,16),4500,16)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(Vector((0,-2,0))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-3.15))
mat=bpy.data.materials.new('Studio floor');mat.diffuse_color=(.11,.14,.17,1)
bpy.context.object.data.materials.append(mat)
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(Path('art/aircraft/mk2/previews/rearjet-side.png' if side_view else 'art/aircraft/mk2/previews/rounded-studio.png').resolve())
bpy.ops.render.render(write_still=True)
