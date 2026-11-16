"""Cut the boarding aperture and the two guarded transfer ducts before batching."""
door_y,door_x=4.8,-4.25
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
    mesh=bpy.data.meshes.new_from_object(part.evaluated_get(deps),depsgraph=deps)
    replacement=bpy.data.objects.new(part.name+" doorway",mesh)
    part.users_collection[0].objects.link(replacement)
    replacement.matrix_world=part.matrix_world
    bpy.data.objects.remove(part,do_unlink=True)
    modifier=replacement.modifiers.new("Boarding cut","BOOLEAN")
    modifier.operation="DIFFERENCE"; modifier.object=cutter
    if replacement.name.startswith("Continuous airframe"): modifier.solver="MANIFOLD"
    bpy.context.view_layer.objects.active=replacement
    bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.data.objects.remove(cutter,do_unlink=True)
shell=next(o for o in scene.objects if o.name.startswith("Continuous airframe"))
assert shell.data.polygons,"Door cut removed the airframe"
for z in (.5,1.2,2.0):
    assert not shell.ray_cast(Vector((-7,door_y,z)),Vector((1,0,0)),distance=3.9)[0],"Fuselage blocks the boarding door"

for x,y in chute_centers:
    cutter=box("Duct aperture cutter",(x,y,-.8),(.96,.93,1.30),iron,0)
    bpy.context.view_layer.objects.active=shell
    modifier=shell.modifiers.new("Chute outlet aperture","BOOLEAN")
    modifier.operation="DIFFERENCE";modifier.object=cutter;modifier.solver="MANIFOLD"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    assert shell.data.polygons and not shell.ray_cast(Vector((x,y,-2)),Vector((0,0,1)),distance=1.8)[0],"Blocked belly outlet"

for edge in (-.8,.8):
    rings=[]
    for i in range(17):
        z=2.28*i/16
        outer=airframe_surface_x(door_y+edge,z)+.015
        rings.append([(-x,door_y+edge+dy,z) for x,dy in [(outer-.12,-.055),(outer,-.055),(outer,.055),(outer-.12,.055)]])
    loft("Curved door jamb",rings,red)
for z in (0,2.28):
    line("Exterior boarding sill",[(-airframe_surface_x(door_y-.8+i*.1,z)-.01,door_y-.8+i*.1,z) for i in range(17)],.026,gold)
# A curved, livery-matched leaf closes flush with the aircraft's outer skin.
door_rig=bpy.data.objects["BoardingDoor"]
ys=[4.02+i*1.56/8 for i in range(9)]
zs=sorted(set([.025+i*2.23/20 for i in range(21)]+[.55,1.15]))
ny,nz=len(ys),len(zs);count=ny*nz
verts=[(-airframe_surface_x(y,z)-.012+inset,y,z) for inset in (0,.08) for y in ys for z in zs]
faces=[];materials=[]
for row in range(ny-1):
    for col in range(nz-1):
        a=row*nz+col;b=a+nz
        faces.extend([(a,b,b+1,a+1),(a+count,a+1+count,b+1+count,b+count)])
        materials.extend([1 if .55<(zs[col]+zs[col+1])/2<1.15 else 0,2])
boundary=list(range(nz))+[r*nz+nz-1 for r in range(1,ny)]+list(range(count-2,count-nz-1,-1))+[r*nz for r in range(ny-2,0,-1)]
for a,b in zip(boundary,boundary[1:]+boundary[:1]):
    faces.append((a,a+count,b+count,b));materials.append(2)
boarding_leaf=obj("Flush boarding door",verts,faces,red)
boarding_leaf.data.materials.append(cream);boarding_leaf.data.materials.append(pine)
for face,material in zip(boarding_leaf.data.polygons,materials):face.material_index=material;face.use_smooth=True
bind(boarding_leaf,door_rig)
outline=[(-airframe_surface_x(ys[i//nz],zs[i%nz])-.023,ys[i//nz],zs[i%nz]) for i in boundary]
bind(line("Boarding door edge seal",outline+[outline[0]],.014,iron),door_rig)
for z in (.40,1.90):rod("Boarding door outer hinge",(-4.72,5.63,z-.12),(-4.72,5.63,z+.12),.055,gold,24)
for face_side in (-1,1):
    x=-airframe_surface_x(4.24,1.20)+(-.085 if face_side==-1 else .12)
    bind(box("Boarding latch backing",(x,4.24,1.20),(.035,.38,.16),iron,.025),door_rig)
    bind(rod("Boarding lever handle",(x+face_side*.04,4.09,1.20),(x+face_side*.04,4.37,1.20),.026,gold,24),door_rig)
