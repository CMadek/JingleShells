group("03 Fir deck and delivery hatch")
# Deck boards break around the actual two metre delivery opening.
for i in range(18):
    x=(i-8.5)/3
    spans=[(-7,-4),(-2,7)] if abs(x)<1 else [(-7,7)]
    for lo,hi in spans:
        y=lo
        while y<hi-.001:
            end=min(hi,y+rng.uniform(2.2,3.65))
            box("Tongue and groove decking",(x,(y+end)/2,-.105),(.331,end-y-.009,.21),rng.choice(wood),.009)
            y=end
for side in (-1,1):
    box("Hatch coaming",(side*1.042,-3,.013),(.085,2.18,.05),gold)
    box("Hatch threshold",(0,-3+side*1.043,.013),(2.04,.085,.05),gold)
    for i in range(4): rod("Hatch hinge",(side*1.10,-3.82+i*.48,.045),(side*1.10,-3.54+i*.48,.045),.046,iron)
    for y in (-6,-3,0,3,5.8):
        box("Sconce shoe",(side*2.86,y,2.35),(.15,.32,.35),pine)
        rod("Lamp lens",(side*2.70,y,2.25),(side*2.70,y,2.48),.107,warm,16)
        for z in (2.23,2.49):box("Lantern cap",(side*2.72,y,z),(.29,.29,.05),gold)
    for y in (-5.8,-2.9,.2,3.2,5.9):
        # Double pinstripe and hammer-set fasteners beneath the window belt.
        for z in (.74,.84):box("Coach line",(side*3.08,y,z),(.022,2.55,.028),gold)
        for j in range(6):
            rod("Belt rivet",(side*3.07,y-1+j*.41,.58),(side*3.10,y-1+j*.41,.58),.033,gold,8)
    label("Registry","NORTH   STAR",(side*3.09,1.1,.99),(pi/2,0,side*pi/2),.34,cream)
group("04 Flight deck")
box("Chart console",(0,6.28,.54),(2.49,.83,1.06),pine,.095)
box("Walnut fascia",(0,5.85,.82),(2.4,.105,.51),wood[1],.06)
box("Glare shield",(0,6.20,1.104),(2.62,.88,.08),iron,.04)
def pivot(name, center):
    node=bpy.data.objects.new(name,None)
    coll.objects.link(node)
    node.location=center
    node.empty_display_size=.035
    return node

def mounted(part, axis):
    # Geometry was authored in panel coordinates. Keep its rest pose about the spindle.
    part.parent=axis
    part.location-=axis.location
    return part

scales=[
    ("Power","PWR %","0","100"),
    ("Pitch","PITCH","-35","+35"),
    ("Speed","M/S","0","45"),
    ("Heading","HDG","W","E"),
    ("Altitude","ALT M","0","1800"),
    ("Bank","BANK","-45","+45"),
    ("Climb","V/S","-30","+30"),
]
for i,(name,caption,low,high) in enumerate(scales):
    x=(i-3)*.314
    r=.132 if i in (2,3,4) else .106
    rod("Instrument bezel",(x,5.78,.86),(x,5.805,.86),r,gold,32)
    rod("Dial face",(x,5.765,.86),(x,5.79,.86),r*.82,iron,32)
    for j in range(12 if name=="Heading" else 9):
        a=j*pi/6 if name=="Heading" else (j-4)*pi*.175
        line("Dial tick",[(x+k*r*sin(a),5.762,.86+k*r*cos(a)) for k in (.57,.74)],.0035,cream)
    axis=pivot(name+"Needle",(x,5.750,.86))
    mounted(line(name+" hand",[(x,5.750,.86-r*.13),(x,5.750,.86+r*.65)],.0045,cream),axis)
    rod("Needle pin",(x,5.74,.86),(x,5.749,.86),.010,gold)
    label("Gauge legend",caption,(x,5.785,.695),(pi/2,0,0),.039,cream)
    for side,mark in [(-1,low),(1,high)]:
        z=.86 if name=="Heading" else .86-.30*r
        label("Scale mark",mark,(x+side*.39*r,5.757,z),(pi/2,0,0),.019,cream)
    if name=="Heading":
        label("North index","N",(x,5.757,.86+.39*r),(pi/2,0,0),.022,cream)

# An eight-spoke wheel with turned grips, a laminated rim and brass inlay.
cx,cy,cz=0,5.52,.63
helm=pivot("HelmWheel",(cx,cy,cz))
rod("Wheel shaft",(0,5.88,.63),(0,5.52,.63),.053,iron)
for radius,thickness,y,finish in [(.248,.031,cy,wood[2]),(.248,.007,cy-.029,gold)]:
    ring=[(radius*sin(i*pi/48),y,cz+radius*cos(i*pi/48)) for i in range(97)]
    mounted(line("Laminated rim",ring,thickness,finish),helm)
for i in range(8):
    a=i*pi/4
    radial=Vector((sin(a),0,cos(a)))
    tangent=Vector((cos(a),0,-sin(a)))
    sections=[]
    for d,r in [(.043,.021),(.075,.026),(.105,.013),(.207,.016),(.245,.022),(.275,.015),(.297,.023),(.324,.024),(.342,.013)]:
        sections.append([Vector((cx,cy,cz))+d*radial+r*(cos(j*pi/8)*tangent+Vector((0,sin(j*pi/8),0))) for j in range(16)])
    mounted(loft("Turned walnut spoke",sections,wood[i%4]),helm)
mounted(rod("Wheel boss",(0,cy-.042,cz),(0,cy+.044,cz),.062,gold,32),helm)
mounted(rod("Hub medallion",(0,cy-.049,cz),(0,cy-.041,cz),.042,pine,24),helm)
for i in range(2):
    rod("Throttle lever",(.95+i*.10,6.16,1.11),(.95+i*.10,6.03,1.27),.023,gold)
    box("Lever grip",(.95+i*.10,6.03,1.27),(.08,.1,.076),red)
for instrument in coll.objects:
    if instrument.parent is None: instrument.location.y += .70
# Seal the rear of the usable cabin with a paneled pressure door.
box("Aft bulkhead",(0,-6.99,1.42),(5.87,.11,2.87),pine,.06)
box("Service door surround",(0,-6.90,1.14),(1.42,.09,2.28),gold,.1)
box("Aft service door",(0,-6.835,1.14),(1.32,.09,2.18),berry,.08)
rod("Inspection port",(0,-6.77,1.61),(0,-6.80,1.61),.31,gold,40)
rod("Port insert",(0,-6.744,1.61),(0,-6.775,1.61),.249,iron,40)
label("Builders plate","NORTH STAR   /   025",(0,-6.77,.86),(pi/2,0,pi),.084,cream)
for x in (-.55,.55):
    line("Ladder upright",[(x+1.14,1.22,.04),(x+1.14,1.22,2.23),(x+.83,1.53,2.41)],.047,gold)
for i in range(7):rod("Ladder rung",(.59,1.22,.22+i*.30),(1.69,1.22,.22+i*.30),.038,iron)
box("Gunner landing",(0,2.80,2.10),(2.29,2.55,.15),pine,.05)
group("06 Coachwork")
for s in (-1,1):
    line("Gilt prow sweep",[(s*2.97,6.85,.74),(s*2.52,8.12,.63),(s*1.64,9.78,.38),(s*.47,10.54,.29),(s*.09,10.68,.27)],.042,gold)
    for y in (-5.8,-3.9,1.8,4.75):
        box("Riveted field patch",(s*3.074,y,1.036),(.017,.47,.20),berry,.012)
        for yy in (-.19,.19):
            for z in (.976,1.097):rod("Patch fastener",(s*3.077,y+yy,z),(s*3.10,y+yy,z),.016,gold,8)
        for i in range(5):
            ly=y+rng.uniform(-.18,.12)
            z=rng.uniform(.95,1.10)
            line("Enamel wear",[(s*3.086,ly,z),(s*3.086,ly+rng.uniform(.016,.09),z+.008)],.0028,cream)
