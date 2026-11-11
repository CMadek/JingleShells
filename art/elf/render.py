import bpy, math, os
from mathutils import Vector
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
bpy.ops.wm.open_mainfile(filepath=root+'/art/elf/flight_elf.blend')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=700;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world.color=(.23,.23,.23)
for loc,power,size in [((3,-4,5),450,4),((-3,-2,3),300,3),((0,3,4),400,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.5
scene.view_settings.view_transform='Standard'
for name,pos in [('front',(0,-5,1.3)),('side',(5,0,1.3)),('back',(0,5,1.3))]:
 cam.location=pos;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=root+'/art/elf/blender_'+name+'.png';bpy.ops.render.render(write_still=True)
