"""Fitted coachwork and shared surface treatment; gameplay markers stay fixed."""
group("10 Christmas coachwork finish")
lining=surfaces.material("Warm cream cabin headliner",(.60,.51,.35),"wool",.91)
upholstery=surfaces.material("Spruce quilted wall upholstery",(.065,.18,.128),"leather",.78)
seam=mat("Upholstery welt",(.13,.25,.17),0,.88)
rubber=surfaces.material("Soft rubber seals",surfaces.PALETTE["rubber"],"rubber",.84)
ivory_panel=surfaces.material("Warm cream panel enamel",(.66,.56,.38),"paint",.48,.06)
instrument_glow=mat("Warm luminous dial ink",(.8,.63,.32),0,.6,.4)

# A continuous warm headliner fits the actual curved shell, above every window.
roof_rings=[]
for y,w,h,c in airframe_stations:
    if not -11.9<=y<=11.2:continue
    low=3.72+max(0,min(1,(y-5.4)/1.35))*.81
    if c+h-.09<=low:continue
    power=airframe_power(y)
    start=asin(airframe_signed_power((low-c)/(h-.085),power/2))
    roof_rings.append([((w-.085)*airframe_signed_power(cos(a),2/power),y,c+(h-.085)*airframe_signed_power(sin(a),2/power)) for a in [start+(pi-2*start)*i/48 for i in range(49)]])
roof=loft("Fitted wool headliner",roof_rings,lining,False)
for f in roof.data.polygons:f.use_smooth=True
for side in (0,48):line("Headliner brass piping",[ring[side] for ring in roof_rings],.014,gold)
for y in (-10.0,-7.0,-3.0,1.0,5.4,8.0):
    ring=min(roof_rings,key=lambda r:abs(r[0][1]-y))
    line("Padded roof bow",[(x,y,z-.015) for x,_,z in ring],.042,lining)
    line("Roof bow seam",[(x,y-.045,z-.018) for x,_,z in ring],.009,binding)

# Low fitted pads lend warmth at the wall without occupying the aisle.
for side in (-1,1):
    spans=[(-11.8,-11.35),(-10.05,-7.25),(-6.65,-3.30),(-3.15,.25),(.40,3.70)]
    if side==1:spans=[(-10.05,-7.25),(-6.65,-3.3),(-3.15,.25),(.40,5.45)]
    for lo,hi in spans:
        rings=[]
        for y in [lo+(hi-lo)*i/16 for i in range(17)]:
            rings.append([(side*(airframe_surface_x(y,z)-.087),y,z) for z in (.18,.30,1.43,1.55)])
        p=loft("Fitted lower cabin upholstery",rings,upholstery,False)
        for f in p.data.polygons:f.use_smooth=True
        for z in (.23,1.50):
            line("Padded wall edge welt",[(side*(airframe_surface_x(y,z)-.10),y,z) for y in [lo+(hi-lo)*i/24 for i in range(25)]],.017,seam)
        for y in [lo+.35+j*.65 for j in range(max(0,int((hi-lo-.35)/.65)))]:
            line("Wall panel sewn channel",[(side*(airframe_surface_x(y,z)-.099),y,z) for z in [.31+i*1.11/12 for i in range(13)]],.007,seam)

# Tailored runner embroidery is flat: it cannot catch cargo or a capsule.
for y in (-10.5,-8.8,-5.9,-4.2,-2.5,-.8,.9):
    for side in (-1,1):
        x=side*.61
        line("Woven runner diamond",[(x,y-.11,.014),(x+.045,y,.014),(x,y+.11,.014),(x-.045,y,.014),(x,y-.11,.014)],.005,binding)

# The cockpit remains the benchmark: rounded framed panels, warm luminous dials.
for o in list(scene.objects):
    if o.type in ("CURVE","FONT") and o.name.startswith(("Dial tick","Scale mark","Gauge legend","North index")):
        o.data.materials.clear();o.data.materials.append(instrument_glow)
    if o.type=="MESH" and o.name.startswith("Walnut fascia"):
        o.data.materials.clear();o.data.materials.append(ivory_panel)

# Cabinet kick rails, panel fasteners and leather cuffs add construction detail.
for side in (-1,1):
    line("Cockpit cabinet kick rail",[(side*1.385,5.99,1.69),(side*1.385,8.97,1.69)],.025,gold)
    for y in (6.55,7.65,8.65):
        for dy in (-.31,.31):
            for dx in (-.36,.36):
                rod("Panel countersunk screw",(side*2.02+dx,y+dy,2.668),(side*2.02+dx,y+dy,2.678),.015,gold,12)
    line("Leather stair handgrip",[(side*1.04,2.70,.92),(side*1.04,5.35,2.245)],.043,leather)
    for y,z in [(2.7,.92),(5.35,2.245)]:
        rod("Handgrip ferrule",(side*1.04,y-.025,z-.012),(side*1.04,y+.025,z+.012),.046,gold,20)
    # Flush inset faces give the cargo machinery a crafted cabinet silhouette.
    for y in (-2.0,-3.1,-4.2):
        box("Cargo feed cabinet inset",(side*1.691,y,.35),(.018,.91,.41),berry,.028)
        rod("Feed cabinet recessed pull",(side*1.675,y-.12,.45),(side*1.675,y+.12,.45),.013,gold,16)

# A fitted, restrained eight-point North Star on each tail side.
for side in (-1,1):
    star=[]
    for i in range(16):
        a=i*pi/8;r=.62 if i%4==0 else (.38 if i%2==0 else .15)
        star.append((side*.275,-13.8+r*cos(a),7.25+r*sin(a)))
    obj("Tail North Star inlay",star,[tuple(range(16))],cream)

# Rounded, robust stores shelves authored alongside the aircraft, replacing boxes
# generated at runtime. Dimensions and each cargo pickup center remain identical.
for side in (-1,1):
    x=side*2.42
    for z in (.25,.95):
        box("Stores padded shelf",(x,-8.65,z),(.9,2.8,.09),pine,.025)
        box("Stores shelf leather mat",(x,-8.65,z+.048),(.79,2.69,.008),leather,.004)
        line("Stores shelf brass lip",[(side*1.97,-7.28,z+.08),(side*1.97,-10.02,z+.08)],.025,gold)
        for y in (-7.75,-8.65,-9.55):
            for dx in (-.30,.30):
                box("Individual cargo cradle",(x+dx,y,z+.07),(.06,.53,.045),rubber,.02)
    for y in (-7.25,-10.05):
        for xx in (side*2.02,side*2.82):
            rod("Turned stores upright",(xx,y,.04),(xx,y,1.10),.045,pine,20)
            rod("Stores brass foot",(xx,y,.02),(xx,y,.16),.058,gold,20)
    box("Stores framed label",(side*1.95,-8.65,.70),(.06,1.20,.27),pine,.025)
    label("Stores painted title","BOMBS" if side==1 else "PRESENTS",(side*1.913,-8.65,.70),(pi/2,0,pi/2 if side<0 else -pi/2),.12,cream)

# Seat upholstery seams and solid mounts stay on the pitch rig, never the camera.
turret_center=Vector((well_x,well_y,-1.55))
for x in (-.26,.26):
    bind(line("Gunner seat piping",[turret_center+Vector((x,-.42,-.385)),turret_center+Vector((x,.05,-.385))],.009,binding),vpitch)
for side in (-1,1):
    bind(rod("Padded gunner grip",turret_center+Vector((side*.35,.32,-.24)),turret_center+Vector((side*.35,.34,-.08)),.045,leather,20),vpitch)

# Finish existing named materials with standard glTF PBR maps; no custom shader
# extensions are required to read the surfaces in Godot's Forward+ renderer.
for m in [red,berry,pine,cream,cream_coat,panel_finish]:surfaces.finish(m,"paint",.43,.10)
surfaces.finish(gold,"brass",.33,.72)
surfaces.finish(iron,"paint",.55,.58)
for m in wood:surfaces.finish(m,"wood",.64,0)
for m in (carpet,runner,binding):surfaces.finish(m,"wool",.94,0)
for m in (leather,pad):surfaces.finish(m,"leather",.79,0)
for o in scene.objects:surfaces.planar_uv(o)
print("COACHWORK POLISH COMPLETE")
