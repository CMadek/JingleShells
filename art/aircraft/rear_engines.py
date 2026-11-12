"""Twin rear-mounted, high-shoulder turbofans. Blender +Y is the intake direction."""
group("08 Rear turbofan assemblies")
for side in (-1,1):
    x,y,z=side*5.45,-9.1,4.35
    # A broad shoulder pylon emerges from the upper aft fuselage.
    pylon=loft("Rear engine shoulder pylon",[[(cx,cy,cz) for cy,cz in [(y+1.2,4.25),(y+.8,4.6),(y-1.8,4.55),(y-2,4.15)]] for cx in [side*2.9,side*4.2,side*5.25]],red,True,.10)
    for face in pylon.data.polygons:face.use_smooth=True
    def ring(d,r):return [(x+r*cos(i*pi/32),y+d,z+r*sin(i*pi/32)) for i in range(64)]
    # Continuous outer shell and rolled intake lip with a real recessed throat.
    nacelle=loft("Rounded rear nacelle",[ring(d,r) for d,r in [(-3,.74),(-2.6,1.04),(-1.8,1.39),(-.3,1.49),(1.4,1.46),(2.15,1.37),(2.45,1.20),(2.48,1.05),(2.34,.97),(1.75,.98)]],cream_coat,False)
    for face in nacelle.data.polygons:face.use_smooth=True
    tunnel=loft("Dark intake duct",[ring(1.76,.985),ring(1.25,.94)],iron,False)
    for face in tunnel.data.polygons:face.use_smooth=True
    line("Intake brass reveal",ring(2.46,1.09)+[ring(2.46,1.09)[0]],.026,gold)
    fan=rig("EngineFan"+("L" if side<0 else "R"),(x,y+1.36,z))
    bind(rod("Fan spinner",(x,y+1.3,z),(x,y+1.83,z),.20,iron,32),fan)
    for j in range(12):
        a=j*2*pi/12
        radial=Vector((cos(a),0,sin(a)))
        tangent=Vector((-sin(a),0,cos(a)))
        center=Vector((x,y+1.4,z))
        sections=[]
        for radius,width,sweep in [(.18,.06,0),(.46,.13,.08),(.82,.12,.21),(.92,.07,.27)]:
            c=center+radial*radius+tangent*sweep
            sections.append([c+tangent*dx*width+Vector((0,dy*.055,0)) for dx,dy in [(-1,-1),(1,-1),(1,1),(-1,1)]])
        bind(loft("Swept intake fan blade",sections,pine,True,.015),fan)
    exhaust=loft("Recessed exhaust nozzle",[ring(d,r) for d,r in [(-2.85,.73),(-3.08,.67),(-3.1,.51),(-2.55,.48)]],iron,False)
    for face in exhaust.data.polygons:face.use_smooth=True
    cone=loft("Rounded exhaust centerbody",[ring(d,r) for d,r in [(-2.65,.46),(-3.05,.41),(-3.48,.27),(-3.65,.08),(-3.68,.015)]],pine)
    for face in cone.data.polygons:face.use_smooth=True
