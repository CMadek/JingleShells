"""Courier cabin fittings kept outside the walking and loading routes."""
group("08 North Star cabin character")
# Printed instructions on the working console, rather than floating wall text.
box("Delivery instructions plaque",(-2.80,.05,1.48),(.05,1.26,.50),pine,.025)
label("Delivery plaque heading","CARGO CONTROL",(-2.765,.05,1.61),(pi/2,0,pi/2),.11,cream)
label("Delivery plaque channels","1 LEFT   /   2 RIGHT",(-2.765,.05,1.47),(pi/2,0,pi/2),.085,gold)
label("Delivery plaque action","E ENTER   /   SPACE DROP",(-2.765,.05,1.34),(pi/2,0,pi/2),.065,cream)
# Warm miniature festoon lamps follow the side shoulders, above head height.
for side in (-1,1):
    points=[]
    for i in range(65):
        y=-6.1+i*10.0/64;z=3.68-.08*cos(i*pi/8)
        points.append((side*(airframe_surface_x(y,z)-.13),y,z))
    line("Festoon cloth cable",points,.009,pine)
    for i in range(0,65,4):
        x,y,z=points[i]
        rod("Festoon lamp socket",(x,y,z),(x,y,z-.065),.022,gold,12)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.038,location=(x,y,z-.088))
        bulb=bpy.context.object;bulb.name="Warm courier cabin bulb"
        for collection in list(bulb.users_collection):collection.objects.unlink(bulb)
        coll.objects.link(bulb);bulb.data.materials.append(warm)
        for face in bulb.data.polygons:face.use_smooth=True
# A small North Star crest gives the rear bulkhead a focal point.
star=[]
for i in range(10):
    a=pi/2+i*pi/5;r=.33 if i%2==0 else .14
    star.append((r*cos(a),-11.87,3.05+r*sin(a)))
obj("North Star brass crest",star,[tuple(range(10))],gold)
