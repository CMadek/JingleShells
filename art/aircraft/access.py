"""Cut the port boarding aperture before static mesh batching.
Blender axes: +Y nose, +Z up. Godot doorway is x=-3, z=-4.8.
"""
bpy.ops.mesh.primitive_cube_add(size=1, location=(-3.05,4.8,.94))
cutter=bpy.context.object
cutter.name="Boarding aperture cutter"
cutter.dimensions=(1.1,1.6,2.68)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
deps=bpy.context.evaluated_depsgraph_get()
for part in list(scene.objects):
    if part==cutter or part.type not in {"MESH","CURVE","FONT"}: continue
    bounds=[part.matrix_world @ Vector(corner) for corner in part.bound_box]
    if not all(min(p[a] for p in bounds)<hi and max(p[a] for p in bounds)>lo
               for a,lo,hi in [(0,-3.60,-2.50),(1,4.0,5.6),(2,-.4,2.28)]): continue
    # Evaluate bevels/solidify and convert trim curves before the boolean.
    mesh=bpy.data.meshes.new_from_object(part.evaluated_get(deps),depsgraph=deps)
    replacement=bpy.data.objects.new(part.name+" doorway",mesh)
    part.users_collection[0].objects.link(replacement)
    replacement.matrix_world=part.matrix_world
    bpy.data.objects.remove(part,do_unlink=True)
    modifier=replacement.modifiers.new("Boarding cut","BOOLEAN")
    modifier.operation="DIFFERENCE"
    modifier.object=cutter
    bpy.context.view_layer.objects.active=replacement
    bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.data.objects.remove(cutter,do_unlink=True)
