"""Blender-authored candy cane and cocoa mug for the off-duty menu crew."""

def bind_prop(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    obj.modifiers.new('Crew rig', 'ARMATURE').object = rig
    obj.parent = rig
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj

def prop_mesh(name, vertices, polygons, materials, bone, indices=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    for mat in materials:
        mesh.materials.append(mat)
    if indices:
        for polygon, index in zip(mesh.polygons, indices):
            polygon.material_index = index
    return bind_prop(obj, bone)

def prop_tube(name, points, radius, materials, bone, guide, stripes=False):
    count = 16
    vertices, polygons, indices = [], [], []
    distance = 0
    for i, point in enumerate(points):
        tangent = (points[min(i+1,len(points)-1)] - points[max(i-1,0)]).normalized()
        normal = (guide-tangent*guide.dot(tangent)).normalized()
        across = tangent.cross(normal).normalized()
        if i:
            distance += (point-points[i-1]).length
        for j in range(count):
            angle = j*math.tau/count
            vertices.append(point + radius*(normal*math.cos(angle)+across*math.sin(angle)))
            if i:
                polygons.append(((i-1)*count+j, (i-1)*count+(j+1)%count, i*count+(j+1)%count, i*count+j))
                indices.append(1 if stripes and (distance/.057+j/count)%1 < .30 else 0)
    polygons.extend([tuple(range(count-1,-1,-1)), tuple((len(points)-1)*count+j for j in range(count))])
    indices.extend([0,0])
    return prop_mesh(name, vertices, polygons, materials, bone, indices)

# The seated elf holds the straight end at the corner of their mouth. The hook
# is large enough to read as a candy cane at the actual menu camera distance.
candy_red = material('Candy cane red', (.65,.025,.04))
candy_cream = material('Candy cane cream', (.94,.86,.68))
for mat in (candy_red, candy_cream):
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .28
points = [Vector((.060, -.238-.19*i/32, 1.412-.012*i/32)) for i in range(33)]
points += [Vector((.060, -.428-.044*math.sin(a), 1.356+.044*math.cos(a))) for a in [i*math.pi/40 for i in range(1,41)]]
points.append(Vector((.060,-.409,1.312)))
prop_tube('Hooked peppermint cane', points, .013, [candy_red,candy_cream], 'Head', Vector((1,0,0)), True)

# The cup is authored around its own rig control, independent of the forearm.
# This lets the mitten remain on the handle as the mug tilts toward the lips.
ceramic = material('Cocoa ceramic', (.87,.78,.59))
trim = material('Cocoa cranberry trim', (.40,.025,.045))
chocolate = material('Cocoa drink', (.10,.032,.012))
mallow = material('Cocoa marshmallows', (.96,.89,.73))
crest = material('Cocoa gold star', (.58,.38,.13))
for mat in (ceramic, trim):
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .30
chocolate.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .4
profile = [(.001,-.12),(.081,-.12),(.098,-.105),(.11,.085),(.108,.12),(.092,.12),(.086,.085),(.081,-.085),(.001,-.085)]
vertices, polygons, indices = [], [], []
count = 48
for i, (radius, height) in enumerate(profile):
    for j in range(count):
        angle = j*math.tau/count
        vertices.append((radius*math.cos(angle),radius*math.sin(angle),height))
        if i:
            polygons.append(((i-1)*count+j,(i-1)*count+(j+1)%count,i*count+(j+1)%count,i*count+j))
            indices.append(1 if i in (2,4,5) else 0)
prop_mesh('Open ceramic cocoa mug', vertices, polygons, [ceramic,trim], 'Mug', indices)
handle = [Vector((.101+.079*math.cos(a),0,.073*math.sin(a))) for a in [-math.pi/2+i*math.pi/32 for i in range(33)]]
prop_tube('Cocoa mug handle', handle, .018, [trim], 'Mug', Vector((0,1,0)))
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.085, depth=.005, location=(0,0,.089))
bpy.context.object.name = 'Hot cocoa surface'
bpy.context.object.data.materials.append(chocolate)
bind_prop(bpy.context.object, 'Mug')
for x,y in [(-.032,-.02),(.027,.018),(-.018,.035)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(x,y,.098))
    obj = bpy.context.object
    obj.name = 'Cocoa floating marshmallow'
    obj.scale = (.019,.017,.011)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mallow)
    bind_prop(obj, 'Mug')
star = [(0,-.111,0)]
for j in range(10):
    angle = math.pi/2+j*math.tau/10
    radius = .035 if j%2 == 0 else .015
    star.append((radius*math.cos(angle),-.111,radius*math.sin(angle)))
prop_mesh('Cocoa mug star', star, [(0,j+1,(j+1)%10+1) for j in range(10)], [crest], 'Mug')
