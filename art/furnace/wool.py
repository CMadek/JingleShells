group="Stockings"
blue=material("Midnight blue wool",(.031,.16,.43))
yellow=material("Marigold wool",(.93,.54,.058))
green=material("Spruce green wool",(.028,.28,.135))
pink=material("Rose felt",(.99,.16,.36))
def knit_ring(cx,rx,ry,z,phase=0):
    loop=[]
    for i in range(40):
        a=i*pi/20
        pleat=1+.035*cos(5*a+phase)+.021*cos(7*a-phase)
        loop.append((cx+rx*cos(a)*pleat,-.214+ry*sin(a)*pleat,z+.005*sin(3*a+phase)))
    return loop
for x,mark,m in [(-.48,"J",blue),(0,"Heart",yellow),(.48,"C",green)]:
    profile=[(-.103,.045,.032,1.752),(-.086,.122,.058,1.773),(-.061,.157,.071,1.818),(-.035,.146,.076,1.870),(.002,.112,.071,1.927),(.014,.098,.069,1.990),(.017,.104,.072,2.08),(.011,.110,.069,2.17),(.004,.113,.071,2.25)]
    loops=[knit_ring(x+cx,rx,ry,z,j*.32) for j,(cx,rx,ry,z) in enumerate(profile)]
    loops.extend([knit_ring(x+.004,.103,.060,2.25),knit_ring(x+.009,.092,.050,2.13)])
    sock=rings(mark+" | stocking",loops,m,caps=True)
    sub=sock.modifiers.new("Soft wool folds","SUBSURF")
    sub.levels=2
    for p in sock.data.polygons: p.use_smooth=True
    cuff=rings(mark+" | turned cuff",[knit_ring(x+.007,rx,ry,z) for rx,ry,z in [(.115,.074,2.17),(.126,.083,2.177),(.129,.085,2.247),(.12,.078,2.256),(.101,.058,2.255),(.105,.060,2.17)]],cream,True)
    for p in cuff.data.polygons: p.use_smooth=True
    for i in range(24):
        a=i*pi/12
        wire("Cuff rib",[(x+.007+.128*cos(a),-.214+.085*sin(a),2.186),(x+.007+.130*cos(a+.034),-.214+.086*sin(a+.034),2.235)],.0027,cream)
    wire("Wool hanging loop",[(x-.026,-.175,2.236),(x-.01,-.185,2.35),(x+.017,-.216,2.366),(x+.035,-.21,2.244)],.013,m)
    for j in range(7):
        z=1.94+j*.031
        wire("Blanket stitch",[(x+.096,-.255,z),(x+.107,-.239,z+.010)],.0034,cream)
    if mark=="Heart":
        outline=[(.011+.083*sin(i*pi/32)**3,-.293,2.044+.005*(13*cos(i*pi/32)-5*cos(i*pi/16)-2*cos(3*i*pi/32)-cos(i*pi/8))) for i in range(64)]
        bevel(rings("Rose heart | felt applique",[[(x+u,y+d,z) for u,y,z in outline] for d in (.009,-.008)],pink,caps=True),.003)
    else:
        c=bpy.data.curves.new(mark+" embroidered initial","FONT")
        c.body=mark
        c.align_x="CENTER"
        c.align_y="CENTER"
        c.size=.218
        c.extrude=.005
        c.bevel_depth=.0027
        o=finish(bpy.data.objects.new(mark+" | felt applique",c),mark+" | felt applique",cream)
        o.location=(x+.012,-.293,2.047)
        o.rotation_euler.x=pi/2
