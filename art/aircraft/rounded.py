"""Rounded cargo airframe. Cross sections are rounded rectangles; openings are cut later."""
def hull():
    group("01 Rounded cargo airframe")
    # Broad cargo shoulders and a continuous roof; no separate inflated nose dome.
    # (lengthwise position, half width, half height, section center height)
    stations=[(-16.2,.08,.12,2.1),(-15.7,.75,.65,2.1),(-14.6,2.3,1.85,2.1),(-13.2,3.65,2.85,2.1),(-12,4.15,3.25,2.1),(-10,4.2,3.3,2.1),(-7,4.4,3.425,2.225),(-3,4.65,3.525,2.325),(0,4.8,3.6,2.4),(3.5,4.8,3.675,2.475),(5.5,4.7,3.7,2.5),(6.8,4.6,3.7,2.5),(8,4.35,3.7,2.5),(9.4,3.75,3.45,2.3),(10.2,3.1,2.95,2.1),(11.2,2.3,2.25,1.85),(12,1.5,1.5,1.5)]
    # A curved cap meets the taper tangentially and turns upright at the pole.
    # Sampling in curve space keeps the last rings dense without a pointed cone.
    for i in range(1,25):
        t=i/24;u=1-t
        y=12*u**3+3*12.55*u*u*t+3*13.35*u*t*t+13.35*t**3
        radius=max(.025,1.5*u**3+3*1.0*u*u*t+3*.65*u*t*t)
        stations.append((y,radius,radius,1.5-.17*t))
    # Dense longitudinal loft removes the polygonal nose and tail transitions.
    for y in [-6.6,-5.8,-3.8,-3,-1,-.2,1.8,2.6,4.6,5.4,6.8,11.5]:
        if not any(abs(st[0]-y)<.001 for st in stations):
            a,b=next((a,b) for a,b in zip(stations,stations[1:]) if a[0]<=y<=b[0])
            t=(y-a[0])/(b[0]-a[0])
            stations.append(tuple([y]+[a[j]*(1-t)+b[j]*t for j in range(1,4)]))
            stations.sort()
    stations.sort()
    controls=stations
    stations=[]
    def tangent(i,j):
        if i==0:return (controls[1][j]-controls[0][j])/(controls[1][0]-controls[0][0])
        if i==len(controls)-1:return (controls[i][j]-controls[i-1][j])/(controls[i][0]-controls[i-1][0])
        left=(controls[i][j]-controls[i-1][j])/(controls[i][0]-controls[i-1][0])
        right=(controls[i+1][j]-controls[i][j])/(controls[i+1][0]-controls[i][0])
        return 0 if left*right<=0 else 2*left*right/(left+right)
    for k in range(len(controls)-1):
        a,b=controls[k],controls[k+1]; span=b[0]-a[0]
        for step in range(6):
            t=step/6
            p=[a[0]+span*t]
            for j in range(1,4):
                p.append((2*t**3-3*t*t+1)*a[j]+(-2*t**3+3*t*t)*b[j]+(t**3-2*t*t+t)*span*tangent(k,j)+(t**3-t*t)*span*tangent(k+1,j))
            stations.append(tuple(p))
    stations.append(controls[-1])
    def power(y):
        # Blend the tail into the rounded rectangular cargo section.
        t=max(0,min(1,(y+14)/4))
        nose=max(0,min(1,(y-8)/4))
        return 2+1.4*t*t*(3-2*t)*(1-nose*nose*(3-2*nose))
    def signed_power(value,exponent):
        return (1 if value>=0 else -1)*abs(value)**exponent
    def section_ring(st,inset=0,count=96):
        y,w,h,c=st;p=2/power(y)
        return [(max(.001,w-inset)*signed_power(cos(i*2*pi/count),p),y,c+max(.001,h-inset)*signed_power(sin(i*2*pi/count),p)) for i in range(count)]
    def profile(y):
        a,b=next((a,b) for a,b in zip(stations,stations[1:]) if a[0]<=y<=b[0])
        t=(y-a[0])/(b[0]-a[0])
        return tuple(a[j]*(1-t)+b[j]*t for j in range(1,4))
    def surface_x(y,z):
        w,h,c=profile(y)
        return w*max(0,1-abs((z-c)/h)**power(y))**(1/power(y))
    globals()["airframe_surface_x"]=surface_x
    globals()["airframe_profile"]=profile
    globals()["airframe_power"]=power
    globals()["airframe_ring"]=section_ring
    globals()["airframe_signed_power"]=signed_power
    globals()["airframe_stations"]=stations
    skin_vs=[];skin_faces=[];skin_mats=[];finishes=[red,cream,pine,glass]
    n=96
    def ring(st):
        return section_ring(st,count=n)
    def clip_z(poly,height,above):
        result=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            ina=(a[2]>=height) if above else (a[2]<=height)
            inb=(b[2]>=height) if above else (b[2]<=height)
            if ina:result.append(a)
            if ina!=inb:
                t=(height-a[2])/(b[2]-a[2]); result.append(tuple(a[k]+t*(b[k]-a[k]) for k in range(3)))
        return result
    # The narrow wraparound windshield follows exact horizontal boundaries.

    for a,b in zip(stations,stations[1:]):
        A,B=ring(a),ring(b)
        for j in range(n):
            nxt=(j+1)%n
            t=(j+.5)*2*pi/n
            quad=[A[j],A[nxt],B[nxt],B[j]]
            # Level livery and window bands reinforce the cargo-plane silhouette.
            bands=[]
            cuts=[(-100,-.4,pine),(-.4,.55,red),(.55,1.15,cream),(1.15,3.0,red),(3.0,4.45,glass if a[0]>=6.8 else red),(4.45,100,red)]
            for low,high,material in cuts:
                bands.append((clip_z(clip_z(quad,low,True),high,False),material))
            for polygon,material in bands:
                if len(polygon)<3:continue
                clean=[]
                for v in polygon:
                    if not clean or (Vector(v)-Vector(clean[-1])).length>1e-7:clean.append(v)
                if len(clean)>1 and (Vector(clean[0])-Vector(clean[-1])).length<1e-7:clean.pop()
                if len(clean)<3:continue
                first=len(skin_vs);skin_vs.extend(clean)
                skin_faces.append(tuple(range(first,first+len(clean))));skin_mats.append(finishes.index(material))
        if a[0] in (-12,-10,-7,-3,0,3,5.5,7,8.2,9.3):
            pts=[(x*.966,y,a[3]+(z-a[3])*.966) for x,y,z in A]
            line("Curved structural former",pts+[pts[0]],.043,pine)
    # Windshield borders conform to each loft section at constant eye height.
    for side in (-1,1):
        for z in (3.0,4.45):
            pts=[]
            for y,w,h,c in stations:
                if 6.8<=y<=13.6 and abs((z-c)/h)<1:
                    pts.append((side*(surface_x(y,z)+.015),y,z))
            if len(pts)>1:line("Windshield soft surround",pts,.028,pine)
    # Three front mullions divide the panoramic windshield into four panes.
    for x in (-1.15,0,1.15):
        pts=[]
        for k in range(13):
            z=3.0+(4.45-3.0)*k/12
            for a,b in zip(stations,stations[1:]):
                if a[0]<6.8:continue
                def outside(st):return abs(x/st[1])**power(st[0])+abs((z-st[3])/st[2])**power(st[0])-1
                if outside(a)<=0 and outside(b)>=0:
                    lo,hi=0.,1.
                    for step in range(24):
                        t=(lo+hi)/2; st=[a[i]*(1-t)+b[i]*t for i in range(4)]
                        if outside(st)>0:hi=t
                        else:lo=t
                    pts.append((x,a[0]*(1-lo)+b[0]*lo+.02,z));break
        if len(pts)>1:line("Cockpit window mullion",pts,.023,pine)
    # Weld the skin before solidifying: shared normals eliminate strip highlights.
    shell=obj("Continuous airframe skin",skin_vs,skin_faces,red)
    for material in finishes[1:]:shell.data.materials.append(material)
    for face,index in zip(shell.data.polygons,skin_mats):face.material_index=index;face.use_smooth=True
    bpy.ops.object.select_all(action="DESELECT");shell.select_set(True)
    bpy.context.view_layer.objects.active=shell
    bm=bmesh.new(); bm.from_mesh(shell.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(shell.data); bm.free()
    modifier=shell.modifiers.new("Skin gauge","SOLIDIFY");modifier.thickness=.045
    # True oval portholes: cut smooth apertures, then fit glazing and rounded rims.
    bpy.context.view_layer.objects.active=shell
    for modifier in list(shell.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    cutter=box("Forward gunner well cutter",(1.75,7.3,-1),(1.6,1.5,2.4),pine,0)
    bpy.context.view_layer.objects.active=shell
    modifier=shell.modifiers.new("Forward starboard crew opening","BOOLEAN");modifier.operation="DIFFERENCE";modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    assert shell.data.polygons,"Gunner opening removed the airframe"
    bpy.data.objects.remove(cutter,do_unlink=True)
    for cy in [-5,-1,3]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=1,depth=12,location=(0,cy,2.55),rotation=(0,pi/2,0))
        cutter=bpy.context.object
        cutter.scale=(.84,.75,1)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=shell
        modifier=shell.modifiers.new("Oval cargo window","BOOLEAN");modifier.operation='DIFFERENCE';modifier.object=cutter;modifier.solver="MANIFOLD"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        assert shell.data.polygons,"Porthole cut removed the airframe"
        bpy.data.objects.remove(cutter,do_unlink=True)
        for side in (-1,1):
            rim=[]
            for i in range(49):
                t=i*2*pi/48; z=2.55+.84*sin(t)
                x=surface_x(cy+.75*cos(t),z)
                rim.append((side*(x+.012),cy+.75*cos(t),z))
            line("Rounded porthole surround",rim,.048,cream)
            verts=[(side*surface_x(cy,2.55),cy,2.55)]+rim[:-1]
            obj("Curved porthole glazing",verts,[(0,1+i,1+(i+1)%48) for i in range(48)],glass)
    group("02 Rounded flight surfaces and runners")
    def foil(name,sections,m):
        rings=[]
        for x,lead,chord,z in sections:
            rings.append([(x,lead-chord*(1-cos(i*2*pi/32))/2,z+.085*chord*sin(i*2*pi/32)) for i in range(32)])
        o=loft(name,rings,m)
        for p in o.data.polygons:p.use_smooth=True
        return o
    wing_roots=[]
    for side in (-1,1):
        wing_roots.append(foil("Cargo mainplane",[(side*2.6,1.2,8.2,.45),(side*3.4,.9,7.8,.40),(side*4.4,.3,7.0,.32),(side*6.4,-.6,5.8,.36),(side*10.8,-2.7,4.0,.55),(side*13.4,-4.0,2.7,.85)],red))
        foil("Ivory wingtip",[(side*13.4,-4.0,2.7,.85),(side*14.1,-4.4,2.0,1.05),(side*14.4,-4.7,1.5,1.6),(side*14.5,-4.9,1.0,2.15),(side*14.45,-5.1,.5,2.4)],cream)
        foil("Horizontal stabilizer",[(side*.6,-13.2,3.8,2.7),(side*3.8,-14.1,3.0,2.9),(side*5.1,-14.8,1.8,3.05),(side*5.5,-15.3,.6,3.1)],pine)
        # One exaggerated central fin; the port loop creates it once.
        rings=[]
        for z,front,chord,width in [(2.5,-12.2,4,.42),(4,-12.2,4,.42),(5.05,-11.5,4.4,.42),(5.8,-12,4,.34),(7.8,-12.7,3,.23),(8.8,-13,2.2,.13),(9.05,-13.5,1.1,.05)]:
            rings.append([(width*sin(i*2*pi/32),front-chord*(1-cos(i*2*pi/32))/2,z) for i in range(32)])
        if side == -1:
            fin=loft("Oversized rounded tail fin",rings,red)
            for p in fin.data.polygons:p.use_smooth=True
        runner=[(side*2.06,-13,-.84),(side*2.06,-11,-1.56),(side*2.06,-9,-1.72),(side*2.06,8.9,-1.72),(side*2.06,10.4,-1.46),(side*2.06,11.6,-.81),(side*2.06,11.82,-.37),(side*2.06,11.61,-.14)]
        pts=[Vector(p) for p in runner]
        runner=[]
        for k in range(len(pts)-1):
            p0,p1,p2,p3=pts[max(0,k-1)],pts[k],pts[k+1],pts[min(len(pts)-1,k+2)]
            for j in range(8):
                t=j/8
                runner.append(.5*(2*p1+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
        runner.append(pts[-1])
        loft("Forged sleigh runner",[[(x+a,y,z+b) for a,b in [(-.14,0),(0,.115),(.14,0),(0,-.095)]] for x,y,z in [(x,y,z-1.1) for x,y,z in runner]],gold)
        for y in (-10,-5,0,4.8,9.5):
            rod("Runner compression strut",(side*2.4,y,-.2),(side*2.06,y+.44,-2.72),.10,pine)
            brace_x=side*min(2.4,airframe_surface_x(y+1.2,-.2)-.08)
            rod("Runner diagonal brace",(brace_x,y+1.2,-.2),(side*2.06,y+.44,-2.72),.065,iron)
    # Wing roots terminate inside the skin thickness, never in the passenger cabin.
    envelope=loft("Temporary wing root fitting",[section_ring(st,.015) for st in stations],pine)
    for wing in wing_roots:
        bpy.context.view_layer.objects.active=wing
        modifier=wing.modifiers.new("Trim wing out of cabin","BOOLEAN");modifier.operation="DIFFERENCE";modifier.object=envelope
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(envelope,do_unlink=True)
    frame()
