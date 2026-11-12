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
rig("BoardingDoor",(-3.08,4.8,1.14))
rig("EmergencyDoor",(3.08,-11,1.14))
# Solid continuous deck replaces the former open delivery hole.

for side in (-1,1):
    x=side*2.22
    box("Return track plinth",(x,-3.1,.34),(1.04,4.5,.68),pine,.055)
    for dx in (-.43,.43):
        box("Return guide rail",(x+dx,-3,.87),(.055,4.35,.17),gold,.018)
        box("Leather rail backing",(x+dx*.9,-3,.82),(.035,4.28,.06),leather,.012)
    for i in range(5):
        y=-1.4-i*.8
        rig("Rack%dSlot%d"%(0 if side<0 else 1,i+1),(x,y,1.02))
        box("Cargo cradle",(x,y,.735),(.83,.69,.09),wood[i%4],.025)
        for yy in (-.24,.24): rod("Brass feed roller",(x-.37,y+yy,.79),(x+.37,y+yy,.79),.038,gold,12)
        # Painted feed arrows on the outward rail.
        line("Feed direction",[(x-.28,y-.16,.81),(x,y+.12,.81),(x+.28,y-.16,.81)],.018,cream_coat)
    rack=0 if side<0 else 1
    rig("Rack%dLoadingPoint"%rack,(side*1.6,-5.65,1))
    box("Cargo loading plaque",(side*1.6,-5.78,1.2),(1.02,.04,.25),pine,.025)
    box("Inboard cargo loading tray",(side*1.9,-5.45,.87),(.90,.85,.12),pine,.05)
    for dx in (-.40,.40):box("Loading tray brass rim",(side*1.9+dx,-5.45,.95),(.035,.80,.04),gold,.012)
    box("Feed throat guard",(x,-.94,1.03),(1.04,.32,.59),red,.07)
    # Enclosed transition across the belly, guarded from the cabin.
    loft("Enclosed transfer elbow",[[(cx+dx,-1.4+dy,z) for dx,dy in [(-.38,-.38),(.38,-.38),(.38,.38),(-.38,.38)]] for cx,z in [(x,.45),(side*1.32,-.8)]],pine,True,.035)
    box("Chute casing",(side*1.32,-1.4,-.80),(.80,.84,.80),pine,.075)
    for yy in (-.43,.43): box("Outlet flange",(side*1.32,-1.4+yy,-1.18),(.90,.06,.10),gold,.015)
    gate=rig("ChuteShutter%d"%rack,(side*1.32,-1.4,-1.2))
    bind(box("Sliding outlet gate",(side*1.32,-1.4,-1.2),(.82,.82,.09),berry,.02),gate)
    rig("ChuteOutlet%d"%rack,(side*1.32,-1.4,-1.60))
# Compact stations outside the circulation aisle.
for name,x,y in [("Delivery",-2.55,.05)]:
    box(name+" console pedestal",(x,y,.47),(.65,1,.94),pine,.075)
    box(name+" console brass fascia",(x,y,1.02),(.70,1.06,.12),gold,.035)
    box(name+" instrument surface",(x,y,1.09),(.61,.96,.06),iron,.025)
    for dy in (-.28,.28):
        rod(name+" selector bezel",(x,y+dy,1.12),(x,y+dy,1.14),.115,gold,24)
        rod(name+" selector face",(x,y+dy,1.14),(x,y+dy,1.15),.09,pine,24)
    rig(name+"Controls",(x,y,1.15))
    for yy in (-.43,.43):
        rod(name+" leather grip",(x-.20,y+yy,1.16),(x+.20,y+yy,1.16),.035,leather)
exec(compile((HERE/"ball_turret.py").read_text(),str(HERE/"ball_turret.py"),"exec"),globals())
exec(compile((HERE/"rear_engines.py").read_text(),str(HERE/"rear_engines.py"),"exec"),globals())
label("Mk II builders plate","NORTH STAR  /  MK II",(0,-11.90,1.9),(pi/2,0,pi),.17,cream)
