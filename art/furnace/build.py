"""Run in Blender from the project folder. Each stage redraws the live viewport."""
from pathlib import Path
from math import pi, sin, cos
import random
import traceback
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
EXPORT = ROOT.parents[1] / "assets" / "cargo"
rng = random.Random(2412)
scene = bpy.data.scenes.new("North Line | Aft furnace")
bpy.context.window.scene = scene
scene.world = bpy.data.worlds.new("Foundry sky")
groups = {}
for name in ("Furnace", "Chimney", "Stockings", "Removable coal", "Embers"):
    groups[name] = bpy.data.collections.new(name)
    scene.collection.children.link(groups[name])

group = "Furnace"
def material(name, rgb, metal=0, rough=.6):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb,1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    for key,v in [("Base Color",(*rgb,1)),("Metallic",metal),("Roughness",rough)]:
        p.inputs[key].default_value=v
    return m

def finish(o,name,m):
    o.name=name
    for c in list(o.users_collection):
        c.objects.unlink(o)
    groups[group].objects.link(o)
    o.data.materials.append(m)
    return o

def bevel(o,d):
    mod=o.modifiers.new("Cast edge radius","BEVEL")
    mod.width=d
    mod.segments=3
    o.modifiers.new("Face normals","WEIGHTED_NORMAL")
    return o

def box(name,loc,size,m,r=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object
    o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return bevel(finish(o,name,m),r)

def mesh(name,vs,fs,m,loc=(0,0,0)):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vs,[],fs)
    bm=bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    o=bpy.data.objects.new(name,data)
    o.location=loc
    return finish(o,name,m)

def rings(name,loops,m,closed=False,caps=False,loc=(0,0,0)):
    n=len(loops[0])
    faces=[]
    for i in range(len(loops) if closed else len(loops)-1):
        j=(i+1)%len(loops)
        faces.extend((i*n+k,i*n+(k+1)%n,j*n+(k+1)%n,j*n+k) for k in range(n))
    if caps: faces.extend([tuple(reversed(range(n))),tuple(range((len(loops)-1)*n,len(loops)*n))])
    return mesh(name,sum(loops,[]),faces,m,loc)

def rod(name,a,b,r,m,n=24):
    d=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d.length,location=(Vector(b)+Vector(a))/2)
    o=bpy.context.object
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return bevel(finish(o,name,m),min(.005,r*.12))

def wire(name,pts,r,m,closed=False):
    c=bpy.data.curves.new(name,"CURVE")
    c.dimensions="3D"
    c.bevel_depth=r
    c.bevel_resolution=2
    s=c.splines.new("POLY")
    s.points.add(len(pts)-1)
    for p,v in zip(s.points,pts): p.co=(*v,1)
    s.use_cyclic_u=closed
    return finish(bpy.data.objects.new(name,c),name,m)

iron=material("Graphite | seasoned casting",(.065,.073,.075),.65)
bronze=material("Umber | oxidised bronze",(.23,.105,.047),.7)
brass=material("Honey | burnished brass",(.57,.34,.12),.68,.35)
black=material("Soot | interior lining",(.024,.018,.016),.2)
brick=material("Fired chamotte",(.22,.087,.047))
cream=material("Oatmeal wool",(.88,.74,.53))
def arch(w,b,h,curve,y):
    return [(-w,y,b),(w,y,b)]+[(w*cos(i*pi/32),y,h+curve*sin(i*pi/32)) for i in range(33)]
def jacket(name,outer,inner,y1,y2,m):
    o=rings(name,[arch(*outer,y1),arch(*outer,y2),arch(*inner,y2),arch(*inner,y1)],m,True)
    return bevel(o,.009)

def base():
    for x in (-.65,.65):
        box("Deck shoe",(x,0,.055),(.28,1.08,.11),iron)
        for y in (-.43,.43):
            rod("Deck bolt",(x,y,.095),(x,y,.14),.066,brass,6)
            box("Cast foot",(x,y*.70,.19),(.17,.18,.28),bronze)
    box("Ash pit",(0,0,.425),(1.57,.94,.35),iron,.055)
    box("Hearth sill",(0,-.02,.60),(1.77,1.07,.11),bronze,.025)
    for y in (-.52,-.545):
        box("Ash drawer moulding",(0,y,.43),(1.27 if y>-.54 else 1.19,.055,.23 if y>-.54 else .18),bronze if y>-.54 else iron)
    wire("Drawer bail",[(-.19,-.57,.46),(-.17,-.64,.40),(.17,-.64,.40),(.19,-.57,.46)],.019,brass)
    jacket("Barrel vault",(.82,.60,1.26,.39),(.67,.67,1.24,.27),-.49,.50,iron)
    jacket("Raised fire mouth",(.855,.58,1.27,.415),(.65,.68,1.23,.28),-.55,-.47,bronze)
    jacket("Polished mouth bead",(.678,.658,1.24,.287),(.653,.68,1.23,.279),-.57,-.545,brass)
    box("Fireback",(0,.453,1.04),(1.42,.08,.81),black)
    for row in range(4):
        for i in range(5):
            x=(i-2)*.24+.055*(row%2)
            if row==3 and abs(x)>.35: continue
            box("Fireback brick",(x,.397,.756+.174*row),(.228,.06,.163),brick,.012)
    for i in range(11):
        rod("Grate bar",((i-5)*.115,-.48,.70),((i-5)*.115,.41,.70),.028,iron,10)
    for i in range(13):
        a=(i+.5)*pi/13
        x=.752*cos(a)
        z=1.25+.35*sin(a)
        rod("Hammered rim stud",(x,-.553,z),(x,-.575,z),.027,brass,8)
    for x in (-.762,.762):
        for z in (.74,.90,1.08):
            rod("Hammered rim stud",(x,-.553,z),(x,-.575,z),.028,brass,8)

def frame():
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active
            s.region_3d.view_rotation=Vector((-.29,1,-.21)).to_track_quat('-Z','Y')
            s.region_3d.view_distance=5.9
            s.region_3d.view_location=(0,0,1.37)
            s.overlay.show_overlays=False
            s.shading.color_type='MATERIAL'
            s.shading.show_cavity=True
            s.shading.cavity_type='WORLD'

steps=iter(["base","chimney","wool","fuel","deliver"])
current=next(steps)
def advance():
    global current
    try:
        if current=="base":
            base()
            frame()
        else:
            stage=ROOT/(current+".py")
            if not stage.exists(): return 1.0
            exec(compile(stage.read_text(encoding="utf-8-sig"),str(stage),"exec"),globals())
        current=next(steps,None)
        return 3.0 if current else None
    except Exception:
        (ROOT/"build-error.txt").write_text(traceback.format_exc())
        return None
if bpy.app.background:
    while current and advance() is not None: pass
else:
    bpy.app.timers.register(advance,first_interval=1.0)
