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

# Distinct panel strips allow the belly, roof and glazing to have actual openings.
profile=[(-1,-.38),(-1.04,.48),(-1.04,1.22),(-1,2.30),(-.82,2.91),(-.44,3.20),(.44,3.20),(.82,2.91),(1,2.30),(1.04,1.22),(1.04,.48),(1,-.38)]
def outline(y,w,zscale=1,offset=0):
    return [(u*w,y,z*zscale+offset) for u,z in profile]
def panel(name,v,m,t=.055):
    o=obj(name,v,[(0,1,2,3)],m)
    mod=o.modifiers.new("Skin gauge","SOLIDIFY")
    mod.thickness=t
    return o
def hull():
    group("01 Airframe and windows")
    stations=[(-12,.13,.13,1.5),(-10,1.16,.57,.86),(-7,2.89,.99,0),(-5,2.95,1,0),(-4,2.95,1,0),(-2,2.95,1,0),(0,2.95,1,0),(1.5,2.95,1,0),(4.1,2.95,1,0),(5.5,2.95,1,0),(7,2.85,.96,0),(8.5,2.30,.7,.05),(9.8,1.57,.37,.09),(10.55,.42,.17,.16),(10.68,.09,.09,.24)]
    for k,(l,r) in enumerate(zip(stations,stations[1:])):
        A,B=outline(*l),outline(*r)
        for j in range(11):
            if j==5 and l[0]==1.5: continue
            window=(j in (2,8) and -7<=l[0]<8.5) or (7<=l[0]<9.8 and 2<=j<=8)
            m=glass if window else (pine if j in (0,10) else red if k%4 else berry)
            panel("Recessed glazing" if window else "Lapped fuselage plate",[A[j],A[j+1],B[j+1],B[j]],m)
            if window: line("Brass glazing bead",[A[j],A[j+1],B[j+1],B[j],A[j]],.038,gold)
        line("Former and panel seam",A,.064,pine)
        if l[0]<-7 or l[0]>=7: panel("Lower fairing",[A[0],A[-1],B[-1],B[0]],pine)
    group("02 Sweep surfaces")
    def foil(name,sections,m):
        return loft(name,[[(x,lead,z),(x,lead-.18*c,z+.12*c),(x,lead-c,z+.016*c),(x,lead-.66*c,z-.035*c),(x,lead-.14*c,z-.045*c)] for x,lead,c,z in sections],m,True,.035)
    for s in (-1,1):
        foil("Swept mainplane",[(s*3.08,2.65,5.6,.48),(s*6.1,1.4,4.36,.55),(s*15.4,-3.3,1.31,.80)],red)
        foil("Wingtip flash",[(s*15.38,-3.30,1.31,.8),(s*16.15,-3.73,.88,.87)],pine)
        foil("Tailplane",[(s*.62,-8.25,3.1,1.49),(s*5.6,-10.82,1.03,1.84)],pine)
        for x,y in [(5.8,.55),(10.8,-1.80)]:
            box("Pod pylon",(s*x,y,.06),(.21,1.48,1.26),iron)
            for dx in (-.49,.49):
                cx=s*(x+dx)
                def ring(d,r):
                    return [(cx+r*cos(i*pi/16),y+d,-.64+r*sin(i*pi/16)) for i in range(32)]
                for name,spec,m in [("Nacelle",[(-1.52,.32),(-.85,.45),(.73,.47),(1.0,.40)],pine),("Intake lip",[(.94,.43),(1.04,.40),(1.04,.33),(.64,.31)],gold),("Inlet shadow",[(.64,.31),(.61,.30)],iron),("Exhaust",[(-1.53,.32),(-1.54,.25),(-1.28,.21)],iron)]:
                    loft(name,[ring(d,r) for d,r in spec],m,name=="Inlet shadow")
        runner=[(s*2.06,-8,-.84),(s*2.06,-6,-1.56),(s*2.06,-4,-1.72),(s*2.06,5.4,-1.72),(s*2.06,7.4,-1.46),(s*2.06,8.6,-.81),(s*2.06,8.82,-.37),(s*2.06,8.61,-.14),(s*2.06,8.33,-.28)]
        loft("Scrolled sleigh runner",[[(x+a,y,z+b) for a,b in [(-.14,0),(0,.115),(.14,0),(0,-.095)]] for x,y,z in runner],gold)
        for y in (-5,0,4.8):
            rod("Runner brace",(s*2.4,y,-.20),(s*2.06,y+.44,-1.62),.087,pine)
    loft("Swept vertical fin",[[(x,y,z) for y,z in [(-8.1,2),(-10.35,5.25),(-11.35,5.39),(-11.55,1.68)]] for x in (-.12,.12)],red,True,.07)
    for s in (-1,1):
        label("Fin number","N P   2 5",(s*.126,-10.45,3.49),(pi/2,0,s*pi/2),.34,cream)
    frame()
def stages():
    hull()
    yield
    for name in ["cabin","station","export"]:
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
