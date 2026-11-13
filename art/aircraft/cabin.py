from math import asin, acos
group("03 Fitted carpet and turret access")
carpet=mat("Deep spruce wool carpet",(.039,.105,.083),0,.97)
runner=mat("Cranberry wool aisle runner",(.245,.035,.054),0,.97)
binding=mat("Champagne woven carpet binding",(.48,.32,.13),0,.92)
for fabric in (carpet,runner,binding):
    fabric.node_tree.nodes.get("Principled BSDF").inputs["Sheen Weight"].default_value=.28
def wool_texture(material):
    # Packed, UV-mapped weave survives the GLB export; no Blender-only shader noise.
    noise=random.Random(74)
    size=128
    color=material.diffuse_color[:3]
    pixels=[]
    for row in range(size):
        for col in range(size):
            fiber=1+noise.uniform(-.10,.10)+(.025 if (col+row//2)%3==0 else -.012)
            rgb=[max(0,min(1,c*fiber)) for c in color]
            pixels.extend([12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055 for c in rgb]+[1])
    image=bpy.data.images.new(material.name+" weave",width=size,height=size)
    image.colorspace_settings.name="sRGB"
    image.pixels.foreach_set(pixels)
    image.pack()
    texture=material.node_tree.nodes.new("ShaderNodeTexImage");texture.image=image
    material.node_tree.links.new(texture.outputs["Color"],material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
for fabric in (carpet,runner):wool_texture(fabric)
def carpet_uv(part):
    uv=part.data.uv_layers.new(name="Wool weave")
    for loop in part.data.loops:
        p=part.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=(p.x/.32,p.y/.32)
# Continuous fitted pieces retain the exact deck height and open climb-in well.
deck=[]
for x,width,spans in [(-1.9,5.7,[(-12,9.4)]),(1.75,1.6,[(-12,6.55),(8.05,9.4)]),(3.65,2.2,[(-12,9.4)])]:
    for lo,hi in spans:
        deck.append(box("Fitted carpet deck",(x,(lo+hi)/2,-.105),(width,hi-lo,.21),carpet,.006))
# Intersect with the actual interior shell: floor corners cannot emerge through the nose.
envelope=loft("Temporary deck fitting envelope",[airframe_ring(st,.065) for st in airframe_stations],pine)
for part in deck:
    bpy.context.view_layer.objects.active=part
    for modifier in list(part.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    modifier=part.modifiers.new("Fit carpet inside curved shell","BOOLEAN")
    modifier.operation="INTERSECT";modifier.object=envelope
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    carpet_uv(part)
    assert len(part.data.polygons)>0,"Carpet fitting removed a deck section"
    assert all(abs(v.co.x)<airframe_surface_x(v.co.y,v.co.z)-.03 for v in part.data.vertices),"Deck penetrates the outer airframe"
bpy.data.objects.remove(envelope,do_unlink=True)
for lo,hi in [(-11.85,2.5)]:
    carpet_uv(box("Carpet aisle runner",(0,(lo+hi)/2,.004),(1.46,hi-lo,.008),runner,.004))
    for x in (-.705,.705):
        box("Woven runner border",(x,(lo+hi)/2,.009),(.026,hi-lo-.035,.004),binding,.002)
    for y in (lo+.028,hi-.028):
        box("Woven runner end binding",(0,y,.009),(1.43,.026,.004),binding,.002)
for side in (-1,1):
    pts=[(side*(airframe_surface_x(y,.045)-.09),y,.045) for y in [-11.9+i*18.8/112 for i in range(113)]]
    line("Carpet perimeter binding",pts,.018,binding)
for side in (-1,1):
    for y in (-6,-3,0,3,5.0):
        cx=airframe_surface_x(y,3.8)-.12
        rod("Lamp wall bracket",(side*(airframe_surface_x(y,3.55)-.06),y,3.55),(side*cx,y,3.55),.04,pine)
        box("Sconce shoe",(side*cx,y,3.55),(.15,.32,.35),pine)
        rod("Lamp lens",(side*(cx-.2),y,3.45),(side*(cx-.2),y,3.68),.107,warm,16)
        for z in (3.43,3.69):box("Lantern cap",(side*(cx-.18),y,z),(.29,.29,.05),gold)
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
    if instrument.parent is None: instrument.location.y += 2.35
    if instrument.parent is None: instrument.location.z += 1.55
# Open passage into the windowless aft stores compartment.
pw,ph,pc=airframe_profile(-7)
pw-=.09;ph-=.09
pp=airframe_power(-7)
for side in (-1,1):
    arc=[(side*pw*airframe_signed_power(cos(a),2/pp),pc+ph*airframe_signed_power(sin(a),2/pp)) for a in [asin(airframe_signed_power(-pc/ph,pp/2))+(acos((1.04/pw)**(pp/2))-asin(airframe_signed_power(-pc/ph,pp/2)))*i/32 for i in range(33)]]
    outline=[(side*1.04,0)]+arc+[(side*1.04,arc[-1][1])]
    loft("Curved hold partition",[[(x,y,z) for x,z in outline] for y in (-7.07,-6.93)],pine)
    box("Passage jamb",(side*1.04,-6.90,1.23),(.10,.12,2.46),gold,.025)
    for y in (-8,-10):
        box("Hold lamp shoe",(side*3.55,y,3.55),(.15,.32,.35),pine)
        rod("Hold lamp",(side*3.35,y,3.45),(side*3.35,y,3.68),.107,warm,16)
lintel_top=pc+ph*(1-(1.065/pw)**pp)**(1/pp)
box("Passage lintel",(0,-7,(2.46+lintel_top)/2),(2.13,.14,lintel_top-2.46),pine,.04)
for side in (-1,1):
    pts=[(side*1.0,-6.82,.08),(side*1.0,-6.82,2.24)]
    pts += [(side*(.80+.20*cos(a)),-6.82,2.24+.20*sin(a)) for a in [i*pi/32 for i in range(17)]]
    pts.append((0,-6.82,2.44))
    line("Rounded passage brass casing",pts,.025,gold)
label("Hold sign","DELIVERY STORES",(0,-6.895,2.75),(pi/2,0,pi),.16,cream)
bw,bh,bc=airframe_profile(-12);bw-=.09;bh-=.09;bp=airframe_power(-12)
start=asin(airframe_signed_power(-bc/bh,bp/2))
outline=[(bw*airframe_signed_power(cos(start+(pi-2*start)*i/64),2/bp),bc+bh*airframe_signed_power(sin(start+(pi-2*start)*i/64),2/bp)) for i in range(65)]
loft("Windowless curved aft bulkhead",[[(x,y,z) for x,z in outline] for y in (-12.06,-11.92)],pine)
label("Rear plate","NORTH STAR / CARGO",(0,-11.90,2.35),(pi/2,0,pi),.19,cream)
group("06 Coachwork")

group("05 Raised pilot deck and stairs")
# The pilot floor is continuous; the gunner enters below it from the cabin.
pilot_deck=box("Raised pilot carpet deck",(0,8.9,1.45),(9.6,6.6,.20),carpet,.006)
envelope=loft("Temporary cockpit fitting envelope",[airframe_ring(st,.075) for st in airframe_stations],pine)
bpy.context.view_layer.objects.active=pilot_deck
for modifier in list(pilot_deck.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
modifier=pilot_deck.modifiers.new("Fit pilot floor inside nose","BOOLEAN")
modifier.operation="INTERSECT";modifier.object=envelope;modifier.solver="MANIFOLD"
bpy.ops.object.modifier_apply(modifier=modifier.name)
carpet_uv(pilot_deck)
assert pilot_deck.data.polygons,"Cockpit fitting removed the deck"
assert all(abs(v.co.x)<airframe_surface_x(v.co.y,v.co.z)-.03 for v in pilot_deck.data.vertices),"Pilot floor penetrates the nose"
bpy.data.objects.remove(envelope,do_unlink=True)
for i in range(9):
    y=2.5+(i+.5)*3.1/9;h=(i+1)*1.55/9
    box("Pilot stair riser",(0,y,h/2),(1.9,3.1/9,h),pine,.012)
    carpet_uv(box("Pilot stair tread",(0,y,h+.003),(1.84,3.1/9-.012,.006),runner,.003))
    box("Pilot stair brass nosing",(0,y-3.1/18+.022,h+.012),(1.86,.03,.02),gold,.008)
for side in (-1,1):
    line("Stair handrail",[(side*1.04,2.5,.82),(side*1.04,5.6,2.37)],.035,gold)
    for y,z in [(2.5,.82),(5.6,2.37)]:rod("Stair rail post",(side*1.04,y,z-.82),(side*1.04,y,z),.035,pine)
# Gunner hatch aperture in the vertical face beside the stairs: x 1.28..2.52.
box("Pilot platform left fascia",(-.985,5.64,.775),(4.53,.08,1.55),pine,.018)
box("Pilot platform right fascia",(2.885,5.64,.775),(.73,.08,1.55),pine,.018)
box("Gunner hatch lintel",(1.9,5.64,1.48),(1.24,.08,.14),pine,.018)
box("Gunner hatch sill",(1.9,5.64,.055),(1.24,.08,.11),pine,.018)
exec(compile((HERE/"cockpit_finish.py").read_text(),str(HERE/"cockpit_finish.py"),"exec"),globals())
