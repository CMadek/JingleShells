"""North Star Mk II fittings. Blender +Y forward, +Z up; Godot -Z forward."""
group("07 Mk II workshop fittings")
leather=mat("Oxblood leather",(.065,.023,.020),0,.83)
cream_coat=mat("Warm ivory enamel",(.73,.65,.46),.12,.55)
# Keep exportable pivot origins in aircraft coordinates; no decorative bones.
def rig(name,loc,parent=None):
    o=pivot(name,loc)
    if parent:
        bpy.context.view_layer.update()
        o.parent=parent
        o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o
def bind(o,parent):
    bpy.context.view_layer.update()
    o.parent=parent
    o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o
rig("BoardingDoor",(-4.70,5.6,1.14))
# The tracks feed aft into guarded discharge wells just ahead of the stores.
paint=mat("Lichen green machine enamel",(.115,.163,.105),.25,.53)
steel=mat("Burnished chute edges",(.255,.26,.238),.68,.42)
amber=mat("Safety ochre enamel",(.65,.34,.052),.22,.58)
chute_centers=[]
for rack,side in enumerate((-1,1)):
    x=side*2.92
    y=-5.9
    chute_centers.append((x,y))
    box("Feed machine plinth",(x,-3.72,.37),(1.14,4.86,.74),paint,.065)
    # Service side faces the crew aisle. Recessed doors, toggle latches and
    # replaceable scuff bars keep the load-bearing housing legible at eye level.
    face=x-side*.57
    for bay,cy in enumerate((-2.02,-3.46,-4.90)):
        box("Service hatch gasket",(face,cy,.41),(.035,1.31,.52),iron,.034)
        box("Pressed service cover",(face-side*.028,cy,.41),(.038,1.255,.46),paint,.026)
        for dz in (-.108,.108):
            box("Pressed stiffening bead",(face-side*.052,cy+.08,.41+dz),(.028,.83,.045),steel,.013)
        for dy in (-.54,.54):
            rod("Hatch quarter turn fastener",(face-side*.038,cy+dy,.59),(face-side*.069,cy+dy,.59),.026,steel,6)
        box("Overcentre catch",(face-side*.065,cy-.47,.39),(.050,.073,.18),iron,.016)
        box("Catch thumb tab",(face-side*.1,cy-.47,.36),(.04,.10,.06),amber,.012)
        box("Bolted mounting shoe",(x,cy-.6,.08),(1.25,.18,.13),iron,.018)
    box("Continuous kick strip",(face-side*.035,-3.70,.115),(.07,4.50,.07),steel,.017)
    for dx in (-.49,.49):
        box("Rolled guide channel",(x+dx,-3.73,.85),(.09,4.8,.23),iron,.023)
        box("Polished rail crown",(x+dx,-3.73,.974),(.09,4.8,.035),steel,.012)
    for i in range(5):
        slot_y=-5.28+i*.8
        rig("Rack%dSlot%d"%(rack,i+1),(x,slot_y,1.03))
        box("Recessed roller bed",(x,slot_y,.773),(.91,.76,.065),iron,.018)
        for dy in (-.24,0,.24):
            rod("Worn steel roller",(x-.43,slot_y+dy,.806),(x+.43,slot_y+dy,.806),.052,steel,16)
    load_x=side*2.26
    rig("Rack%dLoadingPoint"%rack,(load_x,-1.44,1.02))
    box("Inboard loading tray",(side*2.54,-1.53,.88),(.96,.93,.12),paint,.046)
    for dy in (-.43,.43):
        box("Tray rolled lip",(side*2.54,-1.53+dy,.97),(.95,.04,.10),steel,.012)
    # Open-front folded-steel hood, with a removable bolted inspection plate.
    for dx in (-.54,.54):
        loft("Chute cheek", [[(x+dx+t,y+d,z) for d,z in
                    [(-.54,.12),(-.54,1.55),(.18,1.55),(.47,1.24),(.47,.12)]] for t in (-.04,.04)],paint,True,.025)
        for dy in (-.38,.20):
            for z in (.38,1.18):
                rod("Chute hex bolt",(x+dx,y+dy,z),(x+dx+(.062 if dx>0 else -.062),y+dy,z),.039,steel,6)
    box("Hood back",(x,y-.50,.86),(1.08,.08,1.34),paint,.022)
    box("Hood cover",(x,y-.14,1.55),(1.15,.78,.09),paint,.035)
    box("Intake bumper",(x,y+.30,1.49),(1.19,.12,.13),amber,.028)
    for dx in (-.40,-.20,0,.20,.40):
        box("Black bumper bands",(x+dx,y+.365,1.49),(.085,.014,.115),iron,.004)
    face=x-side*.595
    box("Pressed access plate",(face,y,.80),(.035,.73,.54),iron,.025)
    label("Foundry stencil","P - 01" if rack==0 else "S - 02",(face-side*.023,y,.81),(pi/2,0,pi/2 if rack==0 else -pi/2),.135,cream)
    for z in (.18,-1.36):
        for dx in (-.51,.51):box("Outlet angle flange",(x+dx,y,z),(.105,1.08,.09),steel,.014)
        for dy in (-.49,.49):box("Outlet angle flange",(x,y+dy,z),(.96,.11,.09),steel,.014)
    for dx in (-.49,.49):box("Duct side plate",(x+dx,y,-.64),(.07,.99,1.52),iron,.012)
    for dy in (-.46,.46):box("Duct end plate",(x,y+dy,-.64),(.95,.07,1.52),iron,.012)
    gate=rig("ChuteShutter%d"%rack,(x,y,-1.40))
    bind(box("Guillotine slide",(x,y,-1.40),(1.01,1.0,.075),paint,.018),gate)
    for dx in (-.42,0,.42):
        bind(box("Gate reinforcing rib",(x+dx,y,-1.454),(.046,.91,.04),steel,.009),gate)
    rig("ChuteOutlet%d"%rack,(x,y,-1.84))

exec(compile((HERE/"dispatch_terminal.py").read_text(),str(HERE/"dispatch_terminal.py"),"exec"),globals())
exec(compile((HERE/"ball_turret.py").read_text(),str(HERE/"ball_turret.py"),"exec"),globals())
exec(compile((HERE/"rear_engines.py").read_text(),str(HERE/"rear_engines.py"),"exec"),globals())
label("Mk II builders plate","NORTH STAR  /  MK II",(0,-11.90,1.9),(pi/2,0,pi),.17,cream)
