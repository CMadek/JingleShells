"""Boarding and emergency door apertures, before mesh batching."""
for door_y in (4.8,-11.0):
    door_x = -4.25 if door_y > 0 else 4.25
    bpy.ops.mesh.primitive_cube_add(size=1, location=(door_x,door_y,.94))
    cutter=bpy.context.object
    cutter.name="Boarding aperture cutter"
    cutter.dimensions=(2.5,1.6,2.68)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    deps=bpy.context.evaluated_depsgraph_get()
    for part in list(scene.objects):
        if part==cutter or part.type not in {"MESH","CURVE","FONT"}: continue
        if part.name.startswith(("Fitted carpet deck","Carpet aisle runner","Woven runner")): continue
        bounds=[part.matrix_world @ Vector(corner) for corner in part.bound_box]
        if not all(min(p[a] for p in bounds)<hi and max(p[a] for p in bounds)>lo
                   for a,lo,hi in [(0,door_x-1.25,door_x+1.25),(1,door_y-.8,door_y+.8),(2,-.4,2.28)]): continue
        # Evaluate bevels/solidify and convert trim curves before the boolean.
        mesh=bpy.data.meshes.new_from_object(part.evaluated_get(deps),depsgraph=deps)
        replacement=bpy.data.objects.new(part.name+" doorway",mesh)
        part.users_collection[0].objects.link(replacement)
        replacement.matrix_world=part.matrix_world
        bpy.data.objects.remove(part,do_unlink=True)
        modifier=replacement.modifiers.new("Boarding cut","BOOLEAN")
        modifier.operation="DIFFERENCE"
        modifier.object=cutter
        if replacement.name.startswith("Continuous airframe"): modifier.solver="MANIFOLD"
        bpy.context.view_layer.objects.active=replacement
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        if replacement.name.startswith("Continuous airframe"): assert replacement.data.polygons,"Door cut removed the airframe"
    bpy.data.objects.remove(cutter,do_unlink=True)
# Catch a failed boolean even when the airframe still has valid faces.
shell=next(o for o in scene.objects if o.name.startswith("Continuous airframe"))
inverse=shell.matrix_world.inverted()
for side,y in [(-1,4.8),(1,-11.0)]:
    for z in (.5,1.2,2.0):
        origin=inverse @ Vector((side*7,y,z))
        direction=inverse.to_3x3() @ Vector((-side,0,0))
        assert not shell.ray_cast(origin,direction,distance=3.9)[0],"Fuselage blocks a door aperture"
# Curved door reveals connect the flat leaf to the local shell without a box surround.
for side,y in [(-1,4.8),(1,-11.0)]:
    for edge in (-.8,.8):
        rings=[]
        for i in range(17):
            z=2.28*i/16
            outer=airframe_surface_x(y+edge,z)+.015
            rings.append([(side*x,y+edge+dy,z) for x,dy in [(3.06,-.055),(outer,-.055),(outer,.055),(3.06,.055)]])
        loft("Curved door jamb",rings,red)
    for z in (0,2.28):box("Door sill",(side*3.06,y,z),(.24,1.7,.09),gold,.018)
