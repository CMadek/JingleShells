"""Fitted pilot consoles fill the nose while preserving a clear central approach."""
group("05b Fitted cockpit consoles")
pad=mat("Cockpit padded glare shield",(.028,.041,.032),0,.91)
panel_finish=mat("Ivory cockpit instrument panels",(.48,.40,.25),.24,.48)
for side in (-1,1):
    stations=[5.92+i*(9.10-5.92)/24 for i in range(25)]
    # Console bodies curve into the sidewall instead of leaving uncovered edges.
    rings=[]
    for y in stations:
        outer=airframe_surface_x(y,2.56)-.11
        rings.append([(side*1.42,y,1.55),(side*outer,y,1.55),(side*outer,y,2.54),(side*1.42,y,2.54)])
    loft("Fitted side console cabinet",rings,pine,True,.035)
    rings=[]
    for y in stations:
        outer=airframe_surface_x(y,2.59)-.10
        rings.append([(side*1.40,y,2.54),(side*outer,y,2.54),(side*outer,y,2.62),(side*1.40,y,2.62)])
    loft("Cockpit side padded coaming",rings,pad,True,.025)
    line("Side console brass edge",[(side*1.405,y,2.56) for y in stations],.015,gold)
    # Recessed cabinet faces and slender brass pulls add visible structure.
    for y in (6.55,7.65,8.65):
        box("Cockpit cabinet inset",(side*1.405,y,2.02),(.028,.80,.65),berry,.028)
        rod("Cockpit cabinet pull",(side*1.37,y-.13,2.18),(side*1.37,y+.13,2.18),.015,gold,16)
    # Cosmetic systems panels sit below the panoramic glazing.
    for y,title in [(6.55,"LIGHTS"),(7.65,"ENGINES"),(8.65,"DE-ICE")]:
        box("Cockpit systems panel",(side*2.02,y,2.645),(.85,.72,.045),panel_finish,.035)
        label("System panel legend",title,(side*2.02,y+.22,2.672),(0,0,0),.075,cream)
        for dx in (-.24,0,.24):
            rod("System switch bezel",(side*2.02+dx,y-.10,2.67),(side*2.02+dx,y-.10,2.69),.050,iron,24)
            rod("System toggle",(side*2.02+dx,y-.10,2.69),(side*2.02+dx,y-.14,2.77),.012,gold,12)
            rod("System indicator",(side*2.02+dx,y+.06,2.67),(side*2.02+dx,y+.06,2.69),.021,warm,16)
# The deep forward dashboard seals the old gap between the helm and the nose.
envelope=loft("Temporary dashboard fitting",[airframe_ring(st,.09) for st in airframe_stations],pine)
for name,z,height,finish in [("Forward dashboard body",2.10,1.10,pine),("Curved forward glare shield",2.70,.10,pad)]:
    piece=box(name,(0,10.60,z),(9.6,3.10,height),finish,.012)
    bpy.context.view_layer.objects.active=piece
    for modifier in list(piece.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    modifier=piece.modifiers.new("Fit dashboard to nose","BOOLEAN")
    modifier.operation="INTERSECT";modifier.object=envelope;modifier.solver="MANIFOLD"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    assert piece.data.polygons,"Dashboard fit failed"
bpy.data.objects.remove(envelope,do_unlink=True)
line("Dashboard brass sill",[(-1.22,9.05,2.65),(0,9.05,2.65),(1.22,9.05,2.65)],.018,gold)
# A fitted runner leads from the stair landing to the wheel.
carpet_uv(box("Pilot approach carpet",(0,6.81,1.556),(2.28,2.30,.012),runner,.006))
for side in (-1,1):box("Pilot carpet binding",(side*1.10,6.81,1.564),(.025,2.27,.004),binding,.002)
