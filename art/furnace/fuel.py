if not groups["Chimney"].objects:
    exec(compile((ROOT/"chimney.py").read_text(),"chimney.py","exec"))
group="Removable coal"
coal=material("Anthracite | cleaved mineral",(.029,.034,.042),.24,.5)
def rugged(name,loc,radii,m):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
    o=finish(bpy.context.object,name,m)
    for v in o.data.vertices:
        f=rng.uniform(.82,1.15)
        v.co.x*=f*radii[0]
        v.co.y*=f*radii[1]
        v.co.z=max(-.8,min(.78,v.co.z*f))*radii[2]+v.co.x*.10
    o.rotation_euler.z=rng.uniform(-pi,pi)
    return o
hand_piece=None
for row,y in enumerate((-.37,-.12,.105)):
    for i in range(4):
        x=(i-1.5)*.287+rng.uniform(-.022,.022)
        o=rugged("Loose anthracite | %02d"%(1+4*row+i),(x,y+rng.uniform(-.02,.02),.815),(.161,.139,.128),coal)
        if hand_piece is None: hand_piece=o
for x in (-.31,.023,.36):
    rugged("Loose anthracite | crown",(x,-.125,.951),(.19,.14,.12),coal)
group="Embers"
hot=material("Banked cinders | warm core",(.63,.075,.009),.1)
p=hot.node_tree.nodes.get("Principled BSDF")
p.inputs["Emission Color"].default_value=(1,.105,.008,1)
p.inputs["Emission Strength"].default_value=2.4
for i in range(17):
    x=(i%9-4)*.135+rng.uniform(-.03,.03)
    z=.798+(.07 if i>=9 else 0)
    o=rugged("Banked clinker",(x,.248+.06*(i>=9),z),(.123,.082,.102),black)
    o.data.materials.append(hot)
    for face in o.data.polygons:
        if rng.random()<.26: face.material_index=1
light=bpy.data.lights.new("Ember bounce","POINT")
light.energy=15
light.color=(1,.235,.045)
light.shadow_soft_size=.15
o=bpy.data.objects.new("Ember bounce",light)
groups["Embers"].objects.link(o)
o.location=(0,.21,1.02)

# Layer mineral cleavages and casting patina in editable Blender materials.
def patina(m,colors,scale,grit):
    nt=m.node_tree
    def node(kind,name,x,y):
        n=nt.nodes.new(kind)
        n.label=name
        n.location=(x,y)
        return n
    p=nt.nodes.get("Principled BSDF")
    co=node("ShaderNodeTexCoord","Local grain",-780,0)
    noise=node("ShaderNodeTexNoise","Oxidation / mineral clouds",-565,200)
    noise.inputs["Scale"].default_value=scale
    noise.inputs["Detail"].default_value=5
    nt.links.new(co.outputs["Object"],noise.inputs["Vector"])
    ramp=node("ShaderNodeValToRGB","Surface tones",-310,215)
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for i,(pos,col) in enumerate(colors):
        el=ramp.color_ramp.elements.new(pos) if i else ramp.color_ramp.elements[0]
        el.position=pos
        el.color=(*col,1)
    nt.links.new(noise.outputs["Fac"],ramp.inputs[0])
    nt.links.new(ramp.outputs[0],p.inputs["Base Color"])
    micro=node("ShaderNodeTexVoronoi","Fracture edges",-575,-85)
    micro.feature='DISTANCE_TO_EDGE'
    micro.inputs["Scale"].default_value=grit
    nt.links.new(co.outputs["Object"],micro.inputs["Vector"])
    bump=node("ShaderNodeBump","Fine pits and fissures",-300,-70)
    bump.inputs["Strength"].default_value=.19
    bump.inputs["Distance"].default_value=.003
    nt.links.new(micro.outputs["Distance"],bump.inputs["Height"])
    nt.links.new(bump.outputs[0],p.inputs["Normal"])
    nt.links.new(noise.outputs["Fac"],p.inputs["Roughness"])
patina(coal,[(.2,(.009,.010,.013)),(.5,(.022,.026,.032)),(.68,(.056,.068,.083)),(.78,(.14,.148,.15))],31,105)
patina(iron,[(.20,(.022,.020,.019)),(.47,(.072,.075,.076)),(.57,(.061,.060,.052)),(.62,(.128,.055,.024)),(.75,(.215,.092,.033))],4,180)
