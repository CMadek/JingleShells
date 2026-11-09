"""From any directory: blender -b --factory-startup -P build.py"""
from pathlib import Path
from math import pi, sin, cos
import bpy
from mathutils import Vector, Matrix

SOURCE = Path(__file__).resolve().parent
EXPORT = SOURCE.parents[1] / "assets" / "cargo"
EXPORT.mkdir(parents=True, exist_ok=True)


def finish(name, material):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def mat(name, hex_color, metal=0, rough=.46):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    rgb = tuple((int(hex_color[i:i+2],16)/255)**2.2 for i in (0,2,4)) + (1,)
    m.diffuse_color = rgb
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    for key, val in (("Base Color",rgb),("Metallic",metal),("Roughness",rough)):
        p.inputs[key].default_value = val
    return m


def box(name, size, pos, material, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = finish(name, material)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    edge = obj.modifiers.new("Hand softened edges","BEVEL")
    edge.width, edge.segments = bevel, 2
    obj.modifiers.new("Face normals","WEIGHTED_NORMAL")
    return obj


def tube(name, path, radius, material):
    c = bpy.data.curves.new(name,"CURVE")
    c.dimensions = "3D"
    c.bevel_depth, c.bevel_resolution, c.use_fill_caps = radius, 1, True
    spline = c.splines.new("POLY")
    spline.points.add(len(path)-1)
    for p, xyz in zip(spline.points,path):
        p.co = (*xyz,1)
    obj = bpy.data.objects.new(name,c)
    bpy.context.collection.objects.link(obj)
    c.materials.append(material)
    return obj


def ring(name, r, wire, pos, material):
    bpy.ops.mesh.primitive_torus_add(location=pos, major_segments=32, minor_segments=6,
                                     major_radius=r, minor_radius=wire)
    return finish(name,material)


def star(name, x,y,z, radius, material):
    # A raised four-point foil stamp on a vertical face.
    verts = [(x,y-.002,z)] + [(x+sin(i*pi/4)*radius*(.26 if i%2 else .8), y,
                                z+cos(i*pi/4)*radius*(.26 if i%2 else 1)) for i in range(8)]
    mesh(name,verts,[(0,1+(i+1)%8,1+i) for i in range(8)],material)


def mesh(name, verts, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(material)
    return obj


def gift(color="bc304b", lid="d94b60", bow=True):
    paper = mat("Paper "+color,color)
    box("Wrapped parcel",(.46,.46,.435),(0,0,-.021),paper,.018)
    box("Overhanging lid",(.48,.48,.078),(0,0,.201),mat("Lid "+lid,lid),.012)
    for turn in (0,pi/2):
        for side in (-1,1):
            # Ribbon conforms to the body, then widens around the lip of the lid.
            for height, depth, z in ((.405,.232,-.037),(.08,.242,.2)):
                obj = box("Grosgrain wrap",(.076,.005,height),(0,side*depth,z),gold,.002)
                obj.location.rotate(Matrix.Rotation(turn,3,'Z'))
                obj.rotation_euler.z = turn
        box("Crossed ribbon",(.076,.483,.005),(0,0,.242+turn*.002),gold,.002).rotation_euler.z=turn
    if bow:
        for side in (-1,1):
            verts=[]
            for i in range(25):
                t=2*pi*i/24
                x=side*(.008+.078*(1-cos(t)))
                z=.263+.036*(1-cos(t))+.034*sin(t)
                for edge in (-1,1):
                    verts.append((x,side*.013*sin(t)+edge*.027,z+edge*.006*sin(t)))
            obj=mesh("Folded satin loop",verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(24)],gold)
            obj.modifiers.new("Ribbon thickness","SOLIDIFY").thickness=.003
        box("Pinched bow knot",(.064,.077,.043),(0,0,.266),gold,.014)
    for x in (-.159,-.087,.092,.168):
        for z in (-.14,-.032,.075):
            star("Foil paper print",x,-.231,z,.014,champagne)
    box("Paper gift tag",(.084,.009,.104),(.131,-.242,.124),cream,.005).rotation_euler.y=.24
    star("Tag seal",.134,-.248,.121,.024,pine)
    tube("Tag cord",[(.020,-.031,.254),(.052,-.070,.251),(.096,-.175,.249),(.112,-.232,.249),(.116,-.245,.244),(.117,-.249,.234),(.119,-.250,.202),(.118,-.250,.169)],.003,gold)


def bomb():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=.24)
    body=finish("Midnight enamel shell",iron)
    for poly in body.data.polygons:
        poly.use_smooth=True
    for z in (-.035,.035):
        ring("Rolled steel edging",.237,.004,(0,0,z),iron)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.241,depth=.063)
    finish("Oxidised equator band",mat("Patinated steel","526068",.45))
    for i in range(10):
        t=i*2*pi/10
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.012,location=(.241*sin(t),.241*cos(t),0))
        finish("Hammered rivet",champagne)
    star("Workshop compass",0,-.242,0,.047,gold)
    for r,z,h,m in ((.074,.236,.032,brass),(.052,.257,.018,iron)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=h,location=(0,0,z))
        finish("Scalloped crown",m)
    for phase in (0,pi*2/3,pi*4/3):
        path=[]
        for i in range(29):
            t=i/28
            path.append((.075*t*t+.006*cos(phase+t*13),.006*sin(phase+t*13),
                         .26+.105*t-.025*t*t))
        tube("Woven cotton wick",path,.0055,cream if phase else brass)


def place(builder, pos, scale, yaw, *args):
    before=set(bpy.context.scene.objects)
    builder(*args)
    transform=Matrix.Translation(pos) @ Matrix.Rotation(yaw,4,'Z') @ Matrix.Diagonal((*scale,1))
    bpy.context.view_layer.update()
    for o in set(bpy.context.scene.objects)-before:
        o.matrix_world=transform @ o.matrix_world


def gift_tray():
    for i in range(5):
        box("Cedar floorboard",(.24,1.13,.10),((i-2)*.245,0,.05),wood)
    for s in (-1,1):
        box("Painted long rail",(1.27,.055,.165),(0,s*.56,.135),pine)
        box("Gilded lip",(1.27,.061,.014),(0,s*.56,.218),gold,.004)
        box("Tray end",(.055,1.10,.19),(s*.602,0,.146),pine)
        for e in (-1,1):
            box("Brass corner cap",(.079,.08,.23),(s*.6,e*.55,.125),brass)
    for i,(x,y,k,h,a,c,l) in enumerate([
        (-.29,-.24,1,.83,-.06,"bc304b","d94b60"),(.24,-.25,.93,1.12,.04,"197866","369981"),
        (-.27,.24,.93,1.21,.04,"427698","609ab1"),(.24,.24,.89,.76,-.09,"863765","aa5b83")]):
        place(gift,(x,y,.10+.24*h),(k,k,h),a,c,l,i != 2)
    place(gift,(-.25,.24,.10+.483*1.21+.24*.49),(.74,.71,.49),-.13,"bc304b","d94b60")
    star("Tray compass",0,-.591,.136,.052,champagne)


def rack():
    for x in (-.53,.53):
        box("Steel runner",(.14,1.12,.095),(x,0,.048),iron)
    for y in (-.5,0,.5):
        box("Oak crossbeam",(1.27,.11,.16),(0,y,.15),wood)
    for x in (-.56,0,.56):
        box("Cradle divider",(.072,1.1,.24),(x,0,.16),iron)
        box("Leather contact strip",(.08,1.06,.027),(x,0,.29),brass)
    for x in (-.28,.28):
        for y in (-.25,.25):
            ring("Cup liner",.178,.027,(x,y,.196),iron)
            place(bomb,(x,y,.36),(1,1,1),x+y)
    for s in (-1,1):
        tube("Carry handle",[(s*.61,-.41,.18),(s*.61,-.36,.44),(s*.61,-.29,.49),
                             (s*.61,.29,.49),(s*.61,.36,.44),(s*.61,.41,.18)],.023,brass)


def studio(name):
    scene=bpy.context.scene
    big="pile" in name
    focus=Vector((0,0,.37 if big else .045))
    bpy.ops.object.camera_add(location=focus+Vector((1.35,-2.6,1.45)))
    cam=bpy.context.object
    cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=1.91 if big else .77
    scene.camera=cam
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002 if big else -.245))
    finish("Studio floor",mat("Backdrop","304552"))
    for pos,power,size in [((-2,-3,4),310,3),((3,-1,2),145,2),((0,2,3),260,2)]:
        bpy.ops.object.light_add(type="AREA",location=pos)
        light=bpy.context.object
        light.rotation_euler=(focus-light.location).to_track_quat('-Z','Y').to_euler()
        light.data.energy,light.data.shape,light.data.size=power,"DISK",size
    scene.world=bpy.data.worlds.new("Soft fill")
    scene.world.color=(.34,.34,.34)
    scene.render.engine="CYCLES"
    scene.cycles.samples=8
    scene.cycles.use_denoising=True
    scene.render.resolution_x,scene.render.resolution_y=680,640
    scene.render.resolution_percentage=100
    scene.render.filepath=str(SOURCE/(name+".png"))
    bpy.ops.render.render(write_still=True)


for name,builder in [("present",gift),("bomb",bomb),("present_pile",gift_tray),("bomb_pile",rack)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    gold=mat("Satin gold","efb44f",.36)
    champagne=mat("Pale gold","ffda89",.30)
    cream=mat("Oatmeal","f3d9a3")
    brass=mat("Antique brass","ba874e",.55)
    pine=mat("Fir lacquer","236855")
    iron=mat("Blued iron","354451",.55,.38)
    wood=mat("Oiled cedar","a06642")
    builder()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+".blend")),compress=True)
    # Merge the export at the origin while keeping individual parts in the source.
    bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.context.object.name=name
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(name+".glb")),export_format="GLB",
                              use_selection=True,export_animations=False)
    studio(name)
