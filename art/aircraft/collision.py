"""Export fitted cabin collision separately from decorative GLB meshes."""
group("09 Temporary collision construction")
# A low-resolution shell includes solid windows, plus the actual access openings.
stations=airframe_stations[::6]
if stations[-1]!=airframe_stations[-1]:stations.append(airframe_stations[-1])
shell=loft("Temporary cabin collision shell",[airframe_ring(st,.055,48) for st in stations],pine,False)
bpy.context.view_layer.objects.active=shell
modifier=shell.modifiers.new("Collision skin thickness","SOLIDIFY");modifier.thickness=.045
bpy.ops.object.modifier_apply(modifier=modifier.name)
for center,size in [((-4.25,4.8,.94),(2.5,1.6,2.68)),((4.25,-11,.94),(2.5,1.6,2.68)),((1.75,7.3,-1),(1.6,1.5,2.4))]:
    cutter=box("Temporary collision aperture",center,size,pine,0)
    bpy.context.view_layer.objects.active=shell
    modifier=shell.modifiers.new("Collision aperture","BOOLEAN")
    modifier.operation="DIFFERENCE";modifier.object=cutter;modifier.solver="MANIFOLD"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
assert shell.data.polygons,"Collision shell lost its surface"

def write_collision(name,objects,origin=Vector((0,0,0))):
    deps=bpy.context.evaluated_depsgraph_get()
    numbers=[]
    for part in objects:
        mesh=bpy.data.meshes.new_from_object(part.evaluated_get(deps),depsgraph=deps)
        mesh.transform(part.matrix_world)
        # Dissolve coplanar triangulation before serializing the static surface.
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.dissolve_limit(bm,angle_limit=.001,verts=list(bm.verts),edges=list(bm.edges))
        bm.to_mesh(mesh);bm.free()
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            points=[mesh.vertices[index].co-origin for index in tri.vertices]
            if (points[1]-points[0]).cross(points[2]-points[0]).length_squared<1e-12:continue
            # Blender +Y forward, +Z up -> Godot -Z forward, +Y up.
            for p in points:numbers.extend([p.x,p.z,-p.y])
        bpy.data.meshes.remove(mesh)
    assert numbers,"Empty collision resource"
    data=", ".join(format(value,".6f").rstrip("0").rstrip(".") if abs(value)>1e-7 else "0" for value in numbers)
    (OUT/(name+".tres")).write_text('[gd_resource type="ConcavePolygonShape3D" format=3]\n\n[resource]\ndata = PackedVector3Array('+data+')\nbackface_collision = true\n')

fitted=[o for o in scene.objects if o.type=="MESH" and o.name.startswith(("Fitted carpet deck","Raised pilot carpet deck","Curved hold partition","Passage lintel","Windowless curved aft bulkhead","Curved door jamb","Fitted side console cabinet","Forward dashboard body","Pilot platform left fascia","Pilot platform right fascia"))]
write_collision("cabin_collision",[shell]+fitted)
write_collision("boarding_door_collision",[boarding_leaf],door_rig.location)
bpy.data.objects.remove(shell,do_unlink=True)
