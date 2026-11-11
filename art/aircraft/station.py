group("05 Dorsal station")
def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None)
    coll.objects.link(o)
    o.location=loc
    o.empty_display_size=.11
    if parent: attach(o,parent)
    return o
def attach(o,p):
    bpy.context.view_layer.update()
    o.parent=p
    o.matrix_parent_inverse=p.matrix_world.inverted()
    return o
base=empty("FixedBase",(0,2.8,3.18))
yaw=empty("YawPivot",(0,2.8,3.18),base)
pitch=empty("PitchPivot",(0,2.83,3.73),yaw)
def latitude(z,r):
    return [(r*cos(i*pi/32),2.8+r*sin(i*pi/32),z) for i in range(64)]
def circular_band(name,z,r,width,h,m,parent):
    o=loft(name,[latitude(z,r),latitude(z+h,r),latitude(z+h,r-width),latitude(z,r-width),latitude(z,r)],m,False)
    return attach(o,parent)
# Fill the rectangular roof aperture up to the circular canopy sill.
outer=[]
for i in range(64):
    a=i*pi/32
    scale=1.304/max(abs(sin(a)),abs(cos(a)))
    outer.append((scale*cos(a),2.8+scale*sin(a),3.20))
attach(loft("Roof saddle",[outer,latitude(3.20,1.20)],pine,False),base)
circular_band("Brass mounting ring",3.19,1.24,.11,.13,gold,base)
circular_band("Turntable skirt",3.31,1.17,.10,.16,pine,yaw)
canopy=[latitude(3.46+1.22*sin(k*pi/24),1.15*max(.003,cos(k*pi/24))) for k in range(13)]
attach(loft("Observation canopy",canopy,glass,False),yaw)
for i in range(0,64,8):attach(line("Canopy bow",[r[i] for r in canopy],.03,gold),yaw)
circular_band("Canopy crown",4.65,.19,.10,.045,pine,yaw)
attach(box("Gunner seat",(-.43,2.82,2.66),(.70,.69,.17),wood[0],.08),yaw)
attach(box("Padded seat back",(-.43,2.49,2.96),(.72,.16,.72),pine,.07),yaw)
attach(rod("Seat pedestal",(-.43,2.82,2.17),(-.43,2.82,2.61),.12,iron),base)
for side in (-1,1):
    attach(rod("Control grip",(-.43+side*.31,3.13,2.80),(-.43+side*.31,3.13,3.03),.036,iron),yaw)
    x=side*.71
    attach(rod("Display barrel", (x,3.45,3.73),(x,4.81,3.73),.084,pine),pitch)
    attach(rod("Brass tip",(x,4.72,3.73),(x,4.82,3.73),.091,gold),pitch)
    empty("MuzzleLeft" if side<0 else "MuzzleRight",(x,4.83,3.73),pitch)
