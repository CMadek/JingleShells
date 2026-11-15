"""Handmade fittings for the night shift, in the airfield's Godot coordinates."""
from math import sin, cos, pi, exp
from random import Random
import bpy
from surface_wear import woven


def dress(box, ell, rod, mat, xyz, wood, green, gold, leather, welt, iron, paper, spruce):
    rng = Random(1947)
    thread = mat('Flax thread', (.59, .42, .24))
    wool = mat('Weather blanket', (.20, .175, .108))
    slate = mat('Blanket check', (.075, .099, .101))
    braid = mat('Madder yarn', (.37, .095, .065))
    bone = mat('Cream yarn', (.62, .51, .32))
    coffee = mat('Cocoa tide mark', (.112, .054, .023))
    graphite = mat('Ink & graphite', (.066, .084, .079))

    def fabric(name, nu, nv, point, materials, swatch):
        verts, faces, uvs = [], [], []
        for j in range(nv+1):
            for i in range(nu+1):
                u,v = i/nu,j/nv
                verts.append(xyz(*point(u,v)))
                uvs.append((u,v))
        for j in range(nv):
            for i in range(nu):
                a=j*(nu+1)+i
                faces.append((a,a+1,a+nu+2,a+nu+1))
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(verts,[],faces)
        mesh.update()
        obj=bpy.data.objects.new(name,mesh)
        bpy.context.collection.objects.link(obj)
        for material in materials:mesh.materials.append(material)
        layer=mesh.uv_layers.new()
        for i,f in enumerate(mesh.polygons):
            f.use_smooth=True
            f.material_index=swatch(i%nu,i//nu)
            for corner in f.loop_indices:
                layer.data[corner].uv=uvs[mesh.loops[corner].vertex_index]
        return obj

    # Diamonds compress into deep creases around covered upholstery buttons.
    def tuft(u,v):
        z=842.91-4.52*u
        y=.74+.78*v
        s=(z-840.65)/.48
        t=(y-1.13)/.255
        loft=(abs(sin(pi*(s+t)*.5)*sin(pi*(s-t)*.5)))**.6
        hem=min(1,12*min(u,1-u),9*min(v,1-v))
        return (-35.042+.155*loft*hem,y,z)
    fabric("Quilted sofa back",168,42,tuft,[leather],lambda i,j:0)
    for k in range(-4,5):
        for row in [-1,0,1]:
            if (k+row)%2==0:
                ell(-35.018,1.13+.255*row,840.65+.48*k,.026,.026,.026,welt)
    # Folded blanket tips over the arm nearest the arrival point.
    path=[(842.49,.73),(842.62,.79),(842.76,1.03),(842.87,1.19),
          (843.02,1.23),(843.16,1.13),(843.24,.95),(843.26,.77),(843.30,.53),(843.34,.39)]
    def drape(u,v):
        p=v*(len(path)-1); i=min(int(p),len(path)-2); k=p-i
        z=path[i][0]*(1-k)+path[i+1][0]*k
        h=path[i][1]*(1-k)+path[i+1][1]*k
        fold=sin(u*7*pi+.7*v)
        return (-35.10+u*.91+.027*sin(3*v),h+.033*fold+.012*sin(19*u+v),z+.028*v*fold+.08*(u-.5))
    woven(wool,(4,6),(.23,.19,.128),(.115,.128,.100))
    cloth=fabric("Mended camp blanket",58,76,drape,[wool],lambda i,j:0)
    thick=cloth.modifiers.new("Turned hem","SOLIDIFY"); thick.thickness=.009
    for i in range(34):
        x,y,z=drape(i/33,1)
        rod((x,y,z),(x+.011*sin(i),y-rng.uniform(.05,.092),z+.018),.008,thread)
    for i in range(8):
        z=839.60+i*.035
        rod((-34.099,.568,z),(-34.098,.594,z+.024),.0045,thread)

    # Broken stain rings, briefing slips, and a pencil left beside the loose chart.
    def ring(x,z,r,start,end):
        fabric("Cocoa ring",38,1,
               lambda u,v:(x+(r+.004*v)*cos(start+(end-start)*u),.6465,
                           z+(r+.004*v)*sin(start+(end-start)*u)),
               [coffee],lambda i,j:0)
    ring(-32.76,841.21,.106,.20,5.84)
    ring(-32.78,841.18,.102,1.26,3.94)
    for i in range(3):
        slip=box(-33.04+.033*i,.65+i*.007,839.55,.38,.007,.24,paper,.002)
        slip.rotation_euler.z=.09*i
    for i in range(4):
        box(-33.045,.6725,839.50+i*.032,.18-.015*i,.002,.005,graphite,0)
    rod((-32.81,.658,839.67),(-32.69,.658,839.94),.012,braid)
    rod((-32.69,.658,839.94),(-32.68,.658,839.968),.012,thread,0)

    # Blackened wire screens bracket the service hatch, leaving the clerk's face clear.
    def wire_screen(left,right,bottom,top):
        z=834.03
        for x in [left,right]:box(x,(bottom+top)/2,z,.058,top-bottom,.060,iron)
        for y in [bottom,top]:box((left+right)/2,y,z,right-left,.058,.06,iron)
        # One mesh of slender diagonal square-section wires per grille.
        verts,faces=[],[]
        width,height=right-left,top-bottom
        for slope in [-1,1]:
            for q in range(-32,32):
                c=q*.235
                hits=[]
                for x,y in [(0,c),(width,slope*width+c),(-c/slope,0),((height-c)/slope,height)]:
                    if -.00001<=x<=width+.00001 and -.00001<=y<=height+.00001 and (x,y) not in hits:hits.append((x,y))
                if len(hits)!=2:continue
                a,b=hits
                if abs(a[0]-b[0])<.001:continue
                n=len(verts)
                for x,y in [a,b]:
                    for dx,dz in [(-.006,0),(0,.007),(.006,0),(0,-.007)]:
                        verts.append(xyz(left+x+dx,bottom+y,z+dz))
                for i in range(4):faces.append((n+i,n+(i+1)%4,n+4+(i+1)%4,n+4+i))
        mesh=bpy.data.meshes.new("Woven wire");mesh.from_pydata(verts,[],faces);mesh.update()
        cage=bpy.data.objects.new("Woven wire",mesh);bpy.context.collection.objects.link(cage);mesh.materials.append(iron)
    wire_screen(-32.14,-30.25,1.27,2.82)
    wire_screen(-26.77,-24.86,1.27,2.82)
    for x in [-31.195,-25.815]:box(x,2.85,834.03,1.94,.10,.11,wood[1])
    for x in [-32.07,-30.32,-26.69,-24.94]:
        for y in [1.38,2.72]:ell(x,y,834.077,.033,.033,.016,gold)
    # All the paperwork that doesn't fit in the till.
    for i in range(3):
        box(-31.78+.02*i,1.278+.046*i,834.85,.47,.038,.35,paper,.005)
        box(-31.78+.02*i,1.300+.046*i,834.85,.49,.009,.36,green if i!=1 else braid,.002)
    for i in range(4):
        box(-29.13+.032*i,1.258+i*.006,834.94,.36,.007,.22,paper,.001)
    for i in range(3):
        x=-31.97+.10*i
        rod((x,1.34,834.12),(x-.035,1.65+i*.045,834.12),.009,braid)
    rod((-31.87,1.26,834.12),(-31.87,1.44,834.12),.14,iron,.14)

    # Rough-sawn ceiling boards and a picture rail give the rafters visible depth.
    for i in range(38):
        x=-35.79+i*.42
        box(x,4.305,841,.413,.056,17.94,wood[(i*7)%3],.008)
    for z in [838.6,843.4,848.4]:
        box(-28,4.15,z,15.74,.22,.18,wood[0])
    for x in [-35.68,-20.32]:
        # Keep the east exit and west glazing clear.
        z0=838.18 if x>-28 else 832.25
        box(x,.88,(z0+849.76)/2,.13,1.59,849.76-z0,green)
        box(x,1.68,(z0+849.76)/2,.19,.085,849.76-z0,wood[2])
        for i in range(int((849.76-z0)/.79)):
            box(x+(.078 if x<-28 else -.078),.90,z0+.42+i*.79,.055,1.45,.034,wood[0],.007)

    # A proper cap and quoins give the practice chimney a soot-darkened mouth.
    for sign in [-1,1]:
        box(-22.2,1.586,842.5+sign*.65,1.64,.057,.25,wood[0],.012)
    for j in range(5):
        length=rng.uniform(.11,.22);z=843.20+rng.uniform(-.025,.025)
        box(-22.78+j*.18,1.10+.031*j,z,length,.015,.012,thread,.004)

    # A local route board: postcards tucked under tape and photos clipped to twine.
    box(-34.15,2.45,832.56,2.64,1.18,.11,wood[0],.025)
    box(-34.15,2.45,832.63,2.51,1.06,.04,slate,.014)
    for i in range(4):
        x=-35.05+i*.58;y=2.48+.135*cos(i*2.2)
        box(x,y,832.67,.42,.44,.015,paper,.003)
        box(x,y+.035,832.681,.36,.29,.008,green if i%2 else graphite,.002)
        box(x-.055,y+.21,832.69,.085,.09,.018,thread,.005)
        ell(x+.045,y+.055,832.69,.069,.08,.007,bone)
        for k in range(2):box(x-.04,y-.14-k*.025,832.683,.20-.03*k,.007,.005,iron,0)

    # The navigator's battered mail trunk doubles as the spare chair.
    cx,cz=-34.59,836.84
    box(cx,.34,cz,1.24,.49,.85,green,.055)
    box(cx,.59,cz,1.28,.10,.89,wood[0],.04)
    for dx in [-.42,.42]:
        box(cx+dx,.347,cz+.427,.082,.47,.018,iron,.006)
        box(cx+dx,.643,cz,.082,.014,.87,iron,.004)
        box(cx+dx,.49,cz+.45,.10,.09,.025,gold,.008)
    for dx in [-.56,.56]:
        for dz in [-.35,.35]:ell(cx+dx,.15,cz+dz,.087,.066,.087,gold)
    # An enamel jug and a pair of folded mittens share the crew's lamp shelf.
    box(-35.18,1.65,837.14,.84,.065,.91,wood[2])
    rod((-35.28,1.69,837.02),(-35.28,2.01,837.02),.125,green,.105)
    rod((-35.28,2.012,837.02),(-35.28,2.04,837.02),.105,gold,.07)
    for k in range(2):
        ell(-35.05,1.70+k*.055,837.30,.095,.04,.19,braid)
        ell(-34.967,1.71+k*.055,837.27,.043,.032,.066,braid)
