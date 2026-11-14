"""Fit the menu costume to the head/chest before baking its acting clips.

Everything here edits the menu copy; the gameplay character remains unchanged.
"""
from mathutils.bvhtree import BVHTree


def fit_mesh(o, transform):
    inverse = o.matrix_world.inverted()
    for vertex in o.data.vertices:
        vertex.co = inverse @ transform(o.matrix_world @ vertex.co)
    o.data.update()


# Set the whole hat/goggle assembly down over the skull together. The original
# ellipsoid brim and two temple blobs made it read as a stack of separate pieces.
for o in list(scene.objects):
    if o.type != 'MESH':
        continue
    if o.name.startswith(('Soft folded wool cap', 'Wool pom pom', 'Goggle',
                          'Aged brass goggle', 'Glacier goggle')):
        fit_mesh(o, lambda p: Vector((p.x*.91, p.y*.94-.025, p.z-.06)))
    if o.name.startswith(('Hair side curl', 'Turned wool cap brim', 'Thick scarf collar')):
        bpy.data.objects.remove(o, do_unlink=True)


def fitted_ring(name, rx, ry, z, tube, depth, mat, bone, center_y=0, ribs=0):
    vertices, faces = [], []
    for i in range(128):
        angle = i/128*math.tau
        knit = 1 + .035*math.cos(angle*ribs) if ribs else 1
        for j in range(12):
            section = j/12*math.tau
            vertices.append(((rx+tube*math.cos(section)*knit)*math.cos(angle),
                             center_y+(ry+tube*math.cos(section)*knit)*math.sin(angle),
                             z+depth*math.sin(section)))
    for i in range(128):
        for j in range(12):
            faces.append((i*12+j, ((i+1)%128)*12+j,
                          ((i+1)%128)*12+(j+1)%12, i*12+(j+1)%12))
    return prop_mesh(name, vertices, faces, [mat], bone)


wool = material('Menu fitted wool', (.82,.73,.53))
fitted_ring('Fitted cap binding', .201, .169, 1.638, .024, .026,
            wool, 'Head', center_y=-.025, ribs=40)
fitted_ring('Fitted scarf collar', .178, .132, 1.258, .034, .032,
            wool, 'Spine', center_y=-.006, ribs=64)

# A continuous scalp shell with a shaped hairline. Each row is ray-fitted to the
# actual sculpt, so the sideburns connect to the hair beneath the cap.
head = bpy.data.objects['Round face with blended button nose']
tree = BVHTree.FromPolygons([head.matrix_world @ v.co for v in head.data.vertices],
                          [p.vertices[:] for p in head.data.polygons])
vertices, faces = [], []
for row in range(9):
    for i in range(96):
        angle = i/96*math.tau
        front = max(0, -math.sin(angle))
        # Short sideburn tips above the ears, with a clean higher forehead line.
        bottom = 1.577 + .103*front**5 + .008*math.cos(angle*6)
        z = bottom + (1.732-bottom)*row/8
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        origin = Vector((0,-.025,z)) + direction
        hit, normal, _, _ = tree.ray_cast(origin, -direction, 2)
        assert hit is not None, 'Hair must stay fitted to the sculpt'
        vertices.append(hit + normal*.004)
for row in range(8):
    for i in range(96):
        faces.append((row*96+i,row*96+(i+1)%96,(row+1)*96+(i+1)%96,(row+1)*96+i))
prop_mesh('Fitted continuous hair', vertices, faces, [bpy.data.materials['Chestnut hair']], 'Head')

# Bow the scarf over the coat instead of burying its rear surface in the chest.
scarf = bpy.data.objects['Folded knitted scarf']
def scarf_fit(p):
    import numpy as np
    old_y = float(np.interp(p.z, [1.01,1.045,1.16,1.25], [-.22,-.225,-.222,-.205]))
    new_y = float(np.interp(p.z, [1.01,1.045,1.16,1.20,1.25], [-.265,-.270,-.265,-.245,-.170]))
    return Vector((p.x, new_y+(p.y-old_y)*.70, p.z))
fit_mesh(scarf, scarf_fit)
