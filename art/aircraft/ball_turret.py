"""Smooth glazed belly sphere, with its entrance in the forward starboard bay."""
well_x,well_y=1.75,7.3
center=Vector((well_x,well_y,-1.55))
def at(x,y,z):return Vector((well_x+x,well_y+y,z))
rig("VentralControls",(1.9,5.48,.78))
for side in (-1,1):
    rod("Well ladder rail",at(side*.43,-.60,.75),at(side*.43,-.60,-1.85),.03,gold)
    box("Enclosed gunner passage wall",(well_x+side*.84,6.87,.68),(.08,2.5,1.34),pine,.012)
for z in (.65,.35,.05,-.25,-.55,-.85,-1.15,-1.45,-1.75):rod("Well foothold",at(-.43,-.60,z),at(.43,-.60,z),.032,iron)
box("Gunner passage back",(well_x,8.10,.68),(1.76,.08,1.34),pine,.012)

def hatch_outline(width,height,radius,y):
    pts=[]
    for cx,cz,start in [(width/2-radius,height/2-radius,0),(-width/2+radius,height/2-radius,90),(-width/2+radius,-height/2+radius,180),(width/2-radius,-height/2+radius,270)]:
        for i in range(9):
            a=(start+i*90/8)*pi/180
            pts.append((1.9+cx+radius*cos(a),y,.76+cz+radius*sin(a)))
    return pts
outline=hatch_outline(1.27,1.34,.18,5.535)
line("Rounded gunner hatch surround",outline+[outline[0]],.035,gold)
hatch=rig("GunnerHatch",(2.50,5.54,.76))
bind(loft("Gunner access hatch leaf",[hatch_outline(1.15,1.22,.16,y) for y in (5.515,5.565)],pine,True,.012),hatch)
outline=hatch_outline(.98,1.04,.13,5.48)
bind(line("Hatch inset brass line",outline+[outline[0]],.011,gold),hatch)
for z in (.37,1.15):rod("Gunner hatch hinge",(2.51,5.53,z-.10),(2.51,5.53,z+.10),.045,gold,24)
bind(rod("Hatch latch spindle",(1.90,5.48,.80),(1.90,5.40,.80),.035,gold,24),hatch)
ring=[(1.9+.18*cos(i*pi/32),5.38,.80+.18*sin(i*pi/32)) for i in range(65)]
bind(line("Gunner hatch handwheel",ring,.022,gold),hatch)
for i in range(3):
    a=i*2*pi/3
    bind(rod("Hatch handwheel spoke",(1.9,5.38,.80),(1.9+.18*cos(a),5.38,.80+.18*sin(a)),.014,gold,16),hatch)
bind(label("Gunner hatch title","BELLY GUN",(1.9,5.47,1.17),(pi/2,0,0),.105,cream),hatch)
bind(label("Gunner hatch instruction","CLICK TO ENTER",(1.9,5.47,.36),(pi/2,0,0),.067,gold),hatch)
for z in (-1.0,-1.15):line("Fixed turret bearing",[at(1.10*cos(i*pi/64),1.10*sin(i*pi/64),z) for i in range(129)],.045,pine)
vyaw=rig("VentralYaw",center)
vpitch=rig("VentralPitch",center,vyaw)
for side in (-1,1):
    bind(rod("Gimbal trunnion",center+Vector((side*.99,0,0)),center+Vector((side*1.15,0,0)),.14,gold,32),vyaw)
# A single smooth UV sphere instead of coarse, overlapping polygon panels.
crystal=mat("Turret crystal glass",(.56,.77,.82),.12,.12)
crystal.node_tree.nodes.get("Principled BSDF").inputs["Alpha"].default_value=.16
bpy.ops.mesh.primitive_uv_sphere_add(segments=96,ring_count=48,radius=1.08,location=center)
pod=bpy.context.object;pod.name="Continuous crystal turret globe"
for collection in list(pod.users_collection):collection.objects.unlink(pod)
coll.objects.link(pod);pod.data.materials.append(crystal)
for face in pod.data.polygons:face.use_smooth=True
bind(pod,vpitch)
# Restrained meridians and a lower belt leave the forward sightline clear.
for lon in (55,125,235,305):
    b=lon*pi/180
    bind(line("Pod glazing mullion",[center+Vector((cos(a*pi/180)*sin(b),cos(a*pi/180)*cos(b),sin(a*pi/180)))*1.09 for a in range(-75,91,3)],.014,gold),vpitch)
for a in (-50,-35):
    a=a*pi/180
    bind(line("Pod lower brass belt",[center+Vector((cos(a)*sin(b*pi/180),cos(a)*cos(b*pi/180),sin(a)))*1.09 for b in range(361)],.018,gold),vpitch)
# A shallow metal cradle below the occupant, without an opaque hemisphere.
rings=[]
for lat in (-89.8,-85,-80,-75,-70):
    a=lat*pi/180
    rings.append([center+Vector((cos(a)*sin(i*pi/48),cos(a)*cos(i*pi/48),sin(a)))*1.085 for i in range(96)])
cradle=loft("Rounded gunner foot cradle",rings,pine)
for face in cradle.data.polygons:face.use_smooth=True
bind(cradle,vpitch)
bind(box("Gunner leather seat",center+Vector((0,-.18,-.46)),(.62,.57,.13),leather,.07),vpitch)
bind(box("Gunner backrest",center+Vector((0,-.50,-.13)),(.64,.12,.65),leather,.09),vpitch)
for side in (-1,1):
    bind(rod("Gunner hand control",center+Vector((side*.35,.30,-.32)),center+Vector((side*.35,.34,-.08)),.035,iron),vpitch)
    bind(rod("Snowball barrel",center+Vector((side*.43,.65,-.18)),center+Vector((side*.43,1.25,-.18)),.075,iron,32),vpitch)
    bind(rod("Barrel sleeve",center+Vector((side*.43,1.10,-.18)),center+Vector((side*.43,1.24,-.18)),.095,cream_coat,32),vpitch)
rig("SnowballMuzzle",center+Vector((0,1.40,-.18)),vpitch)
rig("GunnerEye",center+Vector((0,.14,.22)),vpitch)
rig("GunnerSeat",center+Vector((0,-.18,-.55)),vpitch)
for side in (-1,1):rod("Turret suspension cheek",at(side*1.08,0,-.18),at(side*1.08,0,-1.55),.07,pine,24)
