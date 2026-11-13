"""Keep the original rounded elf design; resolve intersections and refine the ears.

The authoring forms stay readable in character.py. These surface unions join those
forms before skinning, preserving the plump silhouette without exposed overlaps.
"""
exec(compile(open(os.path.join(ROOT,'art/elf/meshcraft.py'),encoding='utf-8').read(),'meshcraft.py','exec'),globals())

def named(*prefixes):
    return [o for o,w in parts if any(o.name.startswith(prefix) for prefix in prefixes)]

def remove_parts(*prefixes):
    for o in named(*prefixes):
        parts[:]=[(p,w) for p,w in parts if p!=o]
        bpy.data.objects.remove(o,do_unlink=True)

# The original plush shoulders, belly and soft sleeves become a continuous coat.
# Do not slim the belly or straighten the playful sleeve silhouette.
remove_parts('Elbow patch')
for side in (-1,1):
    s='L' if side<0 else 'R'
    # A little breathing room prevents the puffy forearm from fusing to the belly.
    for o in named('Soft shoulder '+s,'Tailored sleeve '+s,'Sleeve forearm '+s,'Wool glove cuff '+s,'Tailored mitten '+s,'Mitten thumb '+s,'Mitten back seam '+s):
        o.location.x+=side*.04
fused('Joined plush coat and sleeves',named('Rounded tailored flight coat','Soft shoulder','Tailored sleeve','Sleeve forearm'),pine,sleeve_weights,voxel=.009,ratio=.16)

# Keep the big round head and button nose, blending away the separate chin/neck seams.
face_forms=named('Soft neck','Round expressive head','Rounded chin','Button nose')
for o in face_forms:
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Smooth rounded face forms','SUBSURF');mod.levels=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
fused('Round face with blended button nose',face_forms,skin,'Head',voxel=.005,ratio=.16)

for side in (-1,1):
    s='L' if side<0 else 'R'
    remove_parts('Boot upper '+s,'Soft boot cuff '+s,'Upturned boot toe '+s,'Rounded boot sole '+s,'Boot welt '+s,'Boot lace '+s)
    def boot_ring(z,rx,front,back):
        def power(v):return math.copysign(abs(v)**.78,v)
        return [(side*.145+rx*power(math.cos(a)),(front if math.sin(a)<0 else back)*power(math.sin(a)),z) for a in [j*math.tau/32 for j in range(32)]]
    boot=ring_mesh('Single shaped boot '+s,[boot_ring(*r) for r in [(.066,.122,.286,.111),(.084,.13,.29,.116),(.12,.129,.279,.117),(.16,.12,.237,.113),(.205,.108,.162,.108),(.25,.101,.111,.104),(.282,.10,.106,.102),(.291,.096,.102,.10)]],dark,'Shin'+s,1,caps=False)
    bpy.context.view_layer.objects.active=boot
    mod=boot.modifiers.new('Leather cuff thickness','SOLIDIFY');mod.thickness=.004
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ring_mesh('Fitted boot sole '+s,[boot_ring(*r) for r in [(.022,.118,.277,.105),(.029,.133,.298,.12),(.059,.133,.298,.12),(.072,.127,.29,.114)]],rubber,'Shin'+s,1)
    remove_parts('Knitted sock '+s)
    ring_mesh('Knitted sock '+s,[[(side*.145+rx*math.cos(a),ry*math.sin(a),z) for a in [j*math.tau/32 for j in range(32)]] for z,rx,ry in [(.27,.082,.089),(.282,.086,.093),(.295,.091,.098),(.305,.093,.101),(.346,.091,.099),(.365,.084,.095),(.373,.08,.088)]],cream,'Shin'+s,1)
    fused('Soft joined mitten '+s,named('Tailored mitten '+s,'Mitten thumb '+s),dark,'Forearm'+s,voxel=.0055,ratio=.16)
    # The same puffy trouser shape can now bend into the sock at the knee.
    for index,(o,w) in enumerate(parts):
        if o.name=='Tailored trousers '+s:parts[index]=(o,leg_weights(s))
    remove_parts('Soft rosy cheek '+s)
    # Fit the sock binding to the curved knit, instead of floating circular hoops.
    remove_parts('Sock rib '+s)
    for z in (.30,.325,.35):
        factor=math.sqrt(1-((z-.275)/.14)**2)
        sewn('Fitted sock rib '+s,[(side*.145+(.102*factor+.004)*math.cos(a),(.108*factor+.004)*math.sin(a),z) for a in [j*math.tau/48 for j in range(49)]],.003,thread,'Shin'+s)
    # Project the laces onto the actual boot surface, avoiding buried white slivers.
    remove_parts('Boot lace '+s)
    bpy.context.view_layer.update()
    for z in (.185,.22,.255):
        for flip in (-1,1):
            lace=[]
            for j in range(17):
                t=j/16;x=side*.145+(t-.5)*.085;zz=z+flip*(t-.5)*.014
                hit,point,normal,index=boot.ray_cast(boot.matrix_world.inverted()@Vector((x,-1,zz)),Vector((0,1,0)))
                if hit:
                    p=boot.matrix_world@point;p.y-=.008;lace.append(tuple(p))
            if len(lace)>1:sewn('Fitted crossed lace '+s,lace,.004,cream,'Shin'+s)

# Longer leaf ears, a soft turned rim, and a recessed rosy bowl replace the thick
# intersecting inner-ear ellipsoids. The root is embedded in the rounded skull.
remove_parts('Sculpted elf ear','Inner ear')
for side in (-1,1):
    outline=[(.195,1.432),(.270,1.435),(.337,1.485),(.409,1.615),(.418,1.652),(.35,1.602),(.275,1.571),(.205,1.555)]
    cx=.285;cz=1.535;rings=[]
    for scale,y in [(.04,.014),(.75,.018),(1,-.002),(.89,-.026),(.66,-.044),(.39,-.023),(.04,-.011)]:
        rings.append([(side*(cx+(x-cx)*scale),y,cz+(z-cz)*scale) for x,z in outline])
    ring_mesh('Curved leaf ear '+('L' if side<0 else 'R'),rings,skin,'Head',2)

# A linear complexion attribute gives the ears a soft inner blush without an
# additional floating surface. All other skin retains the original warm tone.
for o,w in parts:
    if o.data.materials[0]!=skin:continue
    attr=o.data.color_attributes.new(name='Complexion',type='FLOAT_COLOR',domain='POINT')
    for v,c in zip(o.data.vertices,attr.data):
        x,y,z=o.matrix_world@v.co
        tint=.64*math.exp(-((abs(x)-.295)/.075)**2-((z-1.543)/.067)**2)*smoothstep(.005,.026,-y) if o.name.startswith('Curved leaf ear') else 0
        if o.name.startswith('Round face'):
            tint=.72*math.exp(-(((abs(x)-.135)/.051)**2+((z-1.435)/.032)**2)**2)*smoothstep(.13,.18,-y)
        c.color=(.67*(1-tint)+.55*tint,.39*(1-tint)+.20*tint,.25*(1-tint)+.14*tint,1)
vc=skin.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Complexion'
skin.node_tree.links.new(vc.outputs['Color'],skin.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

# Retain the knitted feel without the harsh checker-like relief of the old maps.
for material in (pine,red,cream):
    for node in material.node_tree.nodes:
        if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.32

def first_person_arms():
    for side in (-1,1):
        ell('Soft first person sleeve',(side*.30,.15,-.40),(.105,.28,.105),pine)
        ell('Turned first person cuff',(side*.28,.40,-.32),(.11,.065,.10),cream)
        palm=ell('First person mitten palm',(side*.27,.49,-.28),(.09,.12,.095),dark)
        thumb=ell('First person thumb',(side*.20,.49,-.23),(.045,.07,.05),dark)
        fused('Joined first person mitten',[palm,thumb],dark,'Spine',voxel=.005,ratio=.4)
        for offset in (-.036,.036):
            sewn('Glove finger stitching',[(side*.27+offset,.47,-.187),(side*.27+offset,.54,-.199)],.0025,thread)
        sewn('Glove bound seam',[(side*.27-.063,.52,-.222),(side*.27,.55,-.183),(side*.27+.063,.52,-.222)],.003,thread)

# Decorative lines are authored into surface color maps, not separate cylinders.
def remove_line_guides():
    remove_parts('Coat hem piping','Jacket front placket','Mitten back seam','Pocket bound flap','Knitted cap panel seam','Brim knit rib','Scarf cranberry stripe','Scarf fringe','Fitted sock rib','Fitted crossed lace','Badge North Star','Badge cross','Goggle leather strap','Glove finger stitching','Glove bound seam')

def scarf_weights(p):
    tail=1-smoothstep(1.17,1.25,p.z)
    return {'Spine':1-tail,'Scarf':tail}
for index,(o,w) in enumerate(parts):
    if o.name=='Folded knitted scarf':parts[index]=(o,scarf_weights)
