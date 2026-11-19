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
    if not -12.1<=y<=11.2:continue
    low=3.72+max(0,min(1,(y-5.4)/1.35))*.81
    crown=min(.28,c+h-low-.07)
    if crown<=0:continue
    width=airframe_surface_x(y,low)-.023
    roof_rings.append([(width*u,y,low+crown*(1-u*u)) for u in [1-i/12 for i in range(25)]])
# A continuous vaulted liner with a solid edge. Its underside is also the jump collider.
roof=loft("Fitted wool headliner",[row+[(x,y,z+.075) for x,y,z in reversed(row)] for row in roof_rings],lining,True)
for f in roof.data.polygons:f.use_smooth=True
for side in (0,24):line("Headliner brass piping",[ring[side] for ring in roof_rings],.014,gold)
for y in (-10.0,-7.0,-3.0,1.0,5.4,8.0):
    ring=min(roof_rings,key=lambda r:abs(r[0][1]-y))
    line("Padded roof bow",[(x,y,z-.015) for x,_,z in ring],.042,lining)
    line("Roof bow seam",[(x,y-.045,z-.018) for x,_,z in ring],.009,binding)

# Low fitted pads lend warmth at the wall without occupying the aisle.
for side in (-1,1):
    spans=[(-11.8,-11.35),(-10.05,-7.25),(-6.65,-3.30),(-3.15,.25),(.40,3.70)]
    if side==1:spans=[(-11.9,-7.25),(-6.65,-3.3),(-3.15,.25),(.40,5.45)]
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

# A fitted, restrained eight-point North Star on each tail side.
for side in (-1,1):
    star=[]
    for i in range(16):
        a=i*pi/8;r=.62 if i%4==0 else (.38 if i%2==0 else .15)
        star.append((side*.275,-13.8+r*cos(a),7.25+r*sin(a)))
    obj("Tail North Star inlay",star,[tuple(range(16))],cream)

# Square postal stores inside the tail skin, with a timber aisle between pallets.
for i in range(13):
    box("Stores fir deck plank",((i-6)*.373,-9.495,.014),(.37,4.85,.034),wood[(i*3)%len(wood)],.004)
box("Stores ceiling",(0,-9.495,3.76),(4.94,4.87,.12),lining,.02)
for y in (-7.52,-9.49,-11.46):
    box("Stores overhead beam",(0,y,3.67),(4.87,.10,.09),pine,.014)
for side in (-1,1):
    box("Stores liner wall",(side*2.475,-9.495,1.88),(.10,4.87,3.76),pine,.012)
    for j in range(8):
        y=-7.385-j*.604
        box("Fir wainscot",(side*2.417,y,.69),(.035,.59,1.32),wood[j%len(wood)],.007)
        box("Stamped liner panel",(side*2.416,y,2.49),(.025,.584,2.14),upholstery,.023)
    for h in (.16,1.39,3.46):
        box("Stores rubbing strake",(side*2.385,-9.495,h),(.085,4.84,.08),wood[1],.013)
    x=side*1.77
    for dx in (-.49,.49):
        box("Pallet skid",(x+dx,-9.50,.091),(.14,3.22,.12),iron,.012)
    for j in range(10):
        box("Pallet slat",(x,-8.06-j*.32,.17),(1.24,.31,.08),wood[j%len(wood)],.01)
    for j in range(6):
        box("Aisle painted dash",(side*1.05,-8.18-j*.53,.035),(.046,.33,.007),cream,.002)
    box("Freight placard rim",(side*1.47,-11.87,1.84),(1.58,.075,.70),gold,.03)
    box("Freight placard face",(side*1.47,-11.818,1.84),(1.51,.046,.63),red if side==1 else pine,.025)
    for words,h,size in [("BOMBS" if side==1 else "PRESENTS",1.93,.21),
                         ("HANDLE WITH CARE" if side==1 else "NORTH POLE POST",1.68,.090)]:
        label("Freight placard lettering",words,(side*1.47,-11.786,h),(pi/2,0,pi),size,cream)
    for y in (-8.0,-10.8):
        box("Stores lamp bracket",(side*2.35,y,2.93),(.14,.26,.39),iron,.025)
        rod("Stores lamp glass",(side*2.24,y,2.83),(side*2.24,y,3.03),.072,warm,16)
        for h in (2.81,3.05):
            rod("Stores lamp cap",(side*2.24,y,h-.018),(side*2.24,y,h+.018),.091,gold,16)
        for offset in (-.052,.052):
            rod("Stores lamp guard",(side*2.17,y+offset,2.82),(side*2.17,y+offset,3.04),.009,iron,8)

# The ground crew keeps its own embarrassing safety record.
box("Counting board frame",(0,-11.865,1.53),(1.12,.08,.93),wood[0],.025)
box("Counting board slate",(0,-11.812,1.53),(1.05,.042,.86),pine,.016)
for words,h in [("DAYS WITHOUT",1.82),("A MIX-UP",1.66)]:
    label("Safety record title",words,(0,-11.783,h),(pi/2,0,pi),.094,cream)
box("Flip number card",(0,-11.776,1.35),(.38,.035,.34),cream,.009)
label("Incident count","0",(0,-11.750,1.36),(pi/2,0,pi),.26,iron)
for x in (-.12,.12):
    box("Card clip",(x,-11.746,1.52),(.032,.025,.06),gold,.007)

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
for m in (paint,case,steel):surfaces.finish(m,"paint",.55,.58)
for m in wood:surfaces.finish(m,"wood",.64,0)
for m in (carpet,runner,binding):surfaces.finish(m,"wool",.94,0)
for m in (leather,pad):surfaces.finish(m,"leather",.79,0)
for o in scene.objects:surfaces.planar_uv(o)
print("COACHWORK POLISH COMPLETE")
