# Save the editable version before batching static pieces for the engine.
frame()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"north_star.blend"))
from mathutils import Matrix
def export_batch(name,collections,origin=Vector((0,0,0))):
    deps=bpy.context.evaluated_depsgraph_get()
    copies=[]
    buckets={}
    originals=[o for c in collections for o in c.objects]
    nodes={}
    for o in originals:
        if o.type=="EMPTY":
            n=bpy.data.objects.new(o.name+"_rig",None)
            scene.collection.objects.link(n)
            nodes[o]=n
            copies.append(n)
    for o,n in nodes.items():
        n.parent=nodes.get(o.parent)
        n.matrix_local=(o.parent.matrix_world.inverted() @ o.matrix_world if n.parent else Matrix.Translation(-origin) @ o.matrix_world)
    for o in originals:
        if o.type=="EMPTY": continue
        ev=o.evaluated_get(deps)
        data=bpy.data.meshes.new_from_object(ev,depsgraph=deps)
        parent=o.parent
        local=parent.matrix_world.inverted() if parent else Matrix.Translation(-origin)
        data.transform(local @ o.matrix_world)
        for index,material in enumerate(data.materials):
            part=bmesh.new(); part.from_mesh(data)
            bmesh.ops.delete(part,geom=[f for f in part.faces if f.material_index!=index],context='FACES')
            if part.faces:
                for f in part.faces:f.material_index=0
                subset=bpy.data.meshes.new("Material subset"); part.to_mesh(subset)
                key=(parent,material)
                if key not in buckets:buckets[key]=bmesh.new()
                buckets[key].from_mesh(subset)
                bpy.data.meshes.remove(subset)
            part.free()
        bpy.data.meshes.remove(data)
    for (parent,m),bm in buckets.items():
        data=bpy.data.meshes.new(m.name)
        bm.to_mesh(data)
        bm.free()
        data.materials.append(m)
        n=bpy.data.objects.new(m.name,data)
        scene.collection.objects.link(n)
        n.parent=nodes.get(parent)
        copies.append(n)
    bpy.ops.object.select_all(action="DESELECT")
    for o in copies:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),use_selection=True,use_active_scene=True)
    for o in reversed(copies):bpy.data.objects.remove(o,do_unlink=True)
export_batch("north_star",list(scene.collection.children))
