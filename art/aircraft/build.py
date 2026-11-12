"""Build the North Star in Blender. Local +Y points toward the nose."""
from pathlib import Path
from math import sin, cos, pi
import bpy, bmesh, random, traceback
from mathutils import Vector

HERE=Path(__file__).resolve().parent
OUT=HERE.parents[1]/"assets"/"aircraft"
scene=bpy.data.scenes.new("North Star")
bpy.context.window.scene=scene
rng=random.Random(1212)
def group(name):
    global coll
    coll=bpy.data.collections.new(name)
    scene.collection.children.link(coll)
def mat(name,c,metal=0,rough=.53,glow=0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*c,1)
    m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF")
    for k,v in [("Base Color",(*c,1)),("Metallic",metal),("Roughness",rough),("Emission Color",(*c,1)),("Emission Strength",glow)]: p.inputs[k].default_value=v
    return m
red=mat("Cranberry enamel",(.40,.026,.043),.32)
berry=mat("Oxide red",(.28,.019,.032),.32)
pine=mat("Spruce lacquer",(.023,.113,.091),.36)
gold=mat("Old brass",(.67,.385,.101),.59)
cream=mat("Ivory sign paint",(.91,.80,.56))
iron=mat("Parkerized iron",(.035,.045,.048),.57)
wood=[mat("Oiled fir %d"%i,(.27+i*.026,.128+i*.014,.053+i*.006)) for i in range(4)]
warm=mat("Honey lamp glass",(1,.56,.20),0,.4,3)
glass=mat("Pale glacier glazing",(.36,.67,.73),.14,.16)
glass.node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value=.13
def obj(name,vs,faces,m,bevel=0):
    d=bpy.data.meshes.new(name)
    d.from_pydata(vs,[],faces)
    bm=bmesh.new()
    bm.from_mesh(d)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(d)
    bm.free()
    o=bpy.data.objects.new(name,d)
    coll.objects.link(o)
    d.materials.append(m)
    if bevel:
        mod=o.modifiers.new("Rolled edges","BEVEL")
        mod.width=bevel
        mod.segments=2
        o.modifiers.new("Face normals","WEIGHTED_NORMAL")
    return o
def box(name,c,d,m,b=.018):
    x,y,z=c
    a,l,h=[i/2 for i in d]
    vs=[(x+i*a,y+j*l,z+k*h) for k in (-1,1) for j in (-1,1) for i in (-1,1)]
    return obj(name,vs,[(0,1,3,2),(4,5,7,6),(0,1,5,4),(2,3,7,6),(0,2,6,4),(1,3,7,5)],m,b)
def loft(name,rings,m,caps=True,b=0):
    n=len(rings[0])
    faces=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(rings)-1) for j in range(n)]
    if caps: faces += [tuple(range(n)),tuple(range((len(rings)-1)*n,len(rings)*n))]
    return obj(name,sum(rings,[]),faces,m,b)
def rod(name,a,b,r,m,n=12):
    a,b=Vector(a),Vector(b)
    axis=(b-a).normalized()
    u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized()
    v=axis.cross(u)
    return loft(name,[[p+r*(u*cos(i*2*pi/n)+v*sin(i*2*pi/n)) for i in range(n)] for p in [a,b]],m)
def line(name,pts,r,m):
    c=bpy.data.curves.new(name,"CURVE")
    c.dimensions="3D"
    c.bevel_depth=r
    c.bevel_resolution=2
    s=c.splines.new("POLY")
    s.points.add(len(pts)-1)
    for p,co in zip(s.points,pts):p.co=(*co,1)
    o=bpy.data.objects.new(name,c)
    coll.objects.link(o)
    c.materials.append(m)
    return o
def label(name,words,loc,rot,size,m):
    c=bpy.data.curves.new(name,"FONT")
    c.body=words
    c.align_x="CENTER"
    c.align_y="CENTER"
    c.size=size
    c.space_character=1.18
    c.extrude=.002
    o=bpy.data.objects.new(name,c)
    coll.objects.link(o)
    o.location=loc
    o.rotation_euler=rot
    c.materials.append(m)
    return o
def frame():
    for a in bpy.context.screen.areas:
        if a.type=="VIEW_3D":
            s=a.spaces.active
            s.region_3d.view_location=(0,0,1)
            s.region_3d.view_distance=38
            s.region_3d.view_rotation=Vector((-1,-1.35,-.68)).to_track_quat('-Z','Y')
            s.overlay.show_overlays=False
            s.shading.color_type="MATERIAL"
            s.shading.show_cavity=True

def panel(name,v,m,t=.055):
    o=obj(name,v,[(0,1,2,3)],m)
    mod=o.modifiers.new("Skin gauge","SOLIDIFY")
    mod.thickness=t
    return o
exec(compile((HERE/"rounded.py").read_text(),str(HERE/"rounded.py"),"exec"),globals())
def stages():
    hull()
    yield
    for name in ["cabin","mk2","interior_details","access","export"]:
        path=HERE/(name+".py")
        while not path.is_file():
            yield
        exec(compile(path.read_text(encoding="utf-8-sig"),str(path),"exec"),globals())
        yield
build=stages()
def advance():
    try:
        next(build)
        return 2.5
    except StopIteration:
        return None
    except Exception:
        (HERE/"build-error.txt").write_text(traceback.format_exc())
        return None
if bpy.app.background:
    for step in build: pass
else:
    bpy.app.timers.register(advance,first_interval=1)
