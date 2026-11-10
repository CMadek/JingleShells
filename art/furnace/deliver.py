# Create UV-space game maps for the materials which use Blender-only 3D nodes.
import numpy as np
from mathutils import noise as mnoise
def game_finish(source, ramp, frequency, grain):
    m=material(source.name+" | game",source.diffuse_color[:3],.35)
    n=192
    t=np.arange(n)/n
    height=np.array([[mnoise.fractal(Vector((x*frequency,y*frequency,1.7)),1,2,4) for x in t] for y in t])
    h=np.clip(.5+.34*height,0,1)
    stops=[pos for pos,col in ramp]
    rgb=np.stack([np.interp(h,stops,[col[k] for pos,col in ramp]) for k in range(3)],axis=-1)
    micro=np.random.default_rng(24).normal(0,.05,(n,n))
    dy,dx=np.gradient(h+micro)
    normal=np.stack([-dx*grain,-dy*grain,np.ones_like(h)],axis=-1)
    normal=normal/np.linalg.norm(normal,axis=-1,keepdims=True)*.5+.5
    nt=m.node_tree
    p=nt.nodes.get("Principled BSDF")
    for label,data,slot in [("Colour",rgb,"Base Color"),("Fracture normal",normal,"Normal"),("Roughness",np.repeat(np.clip(.32+.4*h+micro,.1,.9)[:,:,None],3,axis=2),"Roughness")]:
        im=bpy.data.images.new(source.name+" "+label,n,n,alpha=False)
        if slot!="Base Color": im.colorspace_settings.name="Non-Color"
        rgba=np.ones((n,n,4),dtype=np.float32)
        rgba[:,:,:3]=data
        im.pixels.foreach_set(rgba.ravel())
        im.pack()
        tex=nt.nodes.new("ShaderNodeTexImage")
        tex.image=im
        out=tex.outputs["Color"]
        if slot=="Normal":
            nm=nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(out,nm.inputs["Color"])
            out=nm.outputs["Normal"]
        nt.links.new(out,p.inputs[slot])
    return m
def project_uv(o):
    data=o.data
    uv=data.uv_layers.active or data.uv_layers.new()
    for face in data.polygons:
        axis=max(range(3),key=lambda k: abs(face.normal[k]))
        for idx in face.loop_indices:
            v=data.vertices[data.loops[idx].vertex_index].co
            uv.data[idx].uv=((v.y if axis==0 else v.x)*1.25,(v.y if axis==2 else v.z)*1.25)

frame()
bpy.ops.object.select_all(action="DESELECT")
# Keep the procedural source editable and open for inspection.
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=4.9
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"aft_furnace.blend"))
mapped={}
for m,f,g in [(iron,4,1.1),(coal,13,2.6)]:
    ramp=next(n.color_ramp for n in m.node_tree.nodes if n.type=="VALTORGB")
    mapped[m]=game_finish(m,[(e.position,e.color[:3]) for e in ramp.elements],f,g)
def export(name,objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(name+".glb")),use_selection=True,export_apply=True,export_lights=False)
swapped=[]
for obj in scene.objects:
    if obj.type=="MESH" and obj.data.materials and obj.data.materials[0] in mapped:
        mat=obj.data.materials[0]
        project_uv(obj)
        swapped.append((obj,mat))
        obj.data.materials[0]=mapped[mat]
try:
    export("aft_furnace",[o for o in scene.objects if o.type in ("MESH","CURVE","FONT")])
    pos=hand_piece.location.copy()
    hand_piece.location=(0,0,0)
    try: export("anthracite",[hand_piece])
    finally: hand_piece.location=pos
finally:
    for obj,mat in swapped: obj.data.materials[0]=mat
    bpy.ops.object.select_all(action="DESELECT")
