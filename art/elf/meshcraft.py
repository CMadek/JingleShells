"""Surface joining, curved details and skin weights for the rounded courier."""
import bmesh

def smoothstep(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3-2*t)

def mesh_part(name,verts,faces,material,weights='Spine',subdivision=1):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    for f in mesh.polygons:f.use_smooth=True
    if subdivision:
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Tailored smooth surface','SUBSURF');mod.levels=subdivision
        bpy.ops.object.modifier_apply(modifier=mod.name)
    parts.append((o,weights));return o

def ring_mesh(name,rings,material,weights='Spine',subdivision=1,caps=True):
    count=len(rings[0]);verts=[p for ring in rings for p in ring];faces=[]
    for k in range(len(rings)-1):
        for j in range(count):faces.append((k*count+j,k*count+(j+1)%count,(k+1)*count+(j+1)%count,(k+1)*count+j))
    if caps:faces.extend([tuple(range(count-1,-1,-1)),tuple((len(rings)-1)*count+j for j in range(count))])
    return mesh_part(name,verts,faces,material,weights,subdivision)

def sewn(name,points,radius,material,weights='Spine'):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=1
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for p,v in zip(spline.points,points):p.co=(*v,1)
    o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.data.materials.append(material);parts.append((o,weights));return o

def fused(name,objects,material,weights,voxel=.006,ratio=.45):
    for o in objects:
        parts[:]=[(p,w) for p,w in parts if p!=o]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    mod=o.modifiers.new('Joined sculpt surface','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Soft leather','SMOOTH');mod.factor=.65;mod.iterations=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Game mesh','DECIMATE');mod.ratio=ratio;bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.clear();o.data.materials.append(material)
    for f in o.data.polygons:f.use_smooth=True;f.material_index=0
    parts.append((o,weights));return o

def sleeve_weights(p):
    side='L' if p.x<0 else 'R'
    shoulder=smoothstep(1.0,1.13,p.z)
    arm=smoothstep(.297*(1-shoulder)+.235*shoulder,.321*(1-shoulder)+.35*shoulder,abs(p.x))
    fore=1-smoothstep(.875,1.025,p.z)
    return {'Spine':1-arm,'Arm'+side:arm*(1-fore),'Forearm'+side:arm*fore}

def leg_weights(side):
    def weights(p):
        shin=1-smoothstep(.29,.46,p.z)
        return {'Thigh'+side:1-shin,'Shin'+side:shin}
    return weights
