"""Round, whimsical North Star courier; refinement joins the sculpted forms below."""
rose=mat('Rosy cheeks',(.55,.20,.14))
white=mat('Eye ivory',(.93,.89,.73))
hair=mat('Chestnut hair',(.105,.048,.022))
thread=mat('Flax stitching',(.52,.38,.19))
rubber=surfaces.material('Boot soles',(.027,.031,.025),'rubber',.88)
goggle=mat('Glacier goggle glass',(.07,.22,.23))
goggle.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.28
goggle.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.2

def sewn(name, points, radius, material, bone='Spine'):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D'
    curve.bevel_depth=radius;curve.bevel_resolution=2
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for p,v in zip(spline.points,points):p.co=(*v,1)
    o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    o=bpy.context.object;o.data.materials.append(material);parts.append((o,bone))
    return o

loft('Rounded tailored flight coat',[(0,0,z,rx,ry) for z,rx,ry in [(.67,.23,.17),(.69,.27,.20),(.73,.295,.215),(.80,.29,.22),(.90,.28,.215),(1.02,.28,.205),(1.13,.31,.19),(1.20,.325,.18),(1.245,.27,.16),(1.27,.18,.13)]],pine,'Spine')
for z in (.71,.735):
    sewn('Coat hem piping',[(.289*math.cos(a),.209*math.sin(a),z) for a in [i*math.tau/64 for i in range(65)]],.007,thread)
sewn('Jacket front placket',[(0,-.22,.76),(0,-.222,.89),(0,-.215,1.05),(0,-.18,1.22)],.012,cream)
for z in (.80,.94,1.08):
    ell('Handmade brass toggle',(.035,-.225,z),(.028,.015,.014),gold)
ell('Soft neck',(0,0,1.285),(.12,.115,.095),skin,'Head')
ell('Round expressive head',(0,-.025,1.49),(.239,.204,.254),skin,'Head')
ell('Rounded chin',(0,-.09,1.335),(.14,.115,.08),skin,'Head')
ell('Button nose',(0,-.235,1.47),(.069,.071,.060),skin,'Head')
for side in (-1,1):
    s='L' if side<0 else 'R'
    # Curved ears with rounded tips and inset warm inner lobes.
    loft('Sculpted elf ear '+s,[(side*.20,0,1.43,.050,.075),(side*.27,0,1.47,.068,.068),(side*.33,.003,1.53,.060,.045),(side*.39,.008,1.60,.032,.022),(side*.411,.01,1.642,.006,.006)],skin,'Head')
    ear=ell('Inner ear '+s,(side*.295,-.047,1.53),(.044,.014,.092),rose,'Head');ear.rotation_euler.y=side*.46
    ell('Soft rosy cheek '+s,(side*.135,-.187,1.435),(.056,.019,.035),rose,'Head')
    ell('Eye white '+s,(side*.088,-.215,1.535),(.047,.020,.049),white,'Head')
    ell('Bright pupil '+s,(side*.083,-.234,1.535),(.025,.012,.033),ink,'Head')
    ell('Eye highlight '+s,(side*.076,-.245,1.548),(.008,.004,.011),white,'Head')
    sewn('Sculpted upper eyelid '+s,[(side*.088+.047*math.cos(a),-.226,1.535+.047*math.sin(a)) for a in [i*math.pi/12 for i in range(13)]],.008,skin,'Head')
    sewn('Expressive brow '+s,[(side*.088+dx,-.209,1.604+.015*(1-(dx/.048)**2)) for dx in [-.048+i*.008 for i in range(13)]],.010,hair,'Head')
    # Cheek-side curls tucked under the cap, not floating eyebrows at the ears.
    ell('Hair side curl '+s,(side*.205,-.055,1.64),(.046,.105,.060),hair,'Head')
    ell('Tailored trousers '+s,(side*.145,0,.54),(.125,.145,.24),red,'Thigh'+s)
    ell('Knitted sock '+s,(side*.145,0,.275),(.102,.108,.14),cream,'Shin'+s)
    for z in (.30,.325,.35):
        sewn('Sock rib '+s,[(side*.145+.103*math.cos(a),.109*math.sin(a),z) for a in [i*math.tau/32 for i in range(33)]],.004,thread,'Shin'+s)
    # Boots have flat rounded soles, a tall cuff and a jaunty upturned toe.
    loft('Rounded boot sole '+s,[(side*.145,-.08,z,rx,ry) for z,rx,ry in [(.018,.115,.204),(.03,.145,.23),(.075,.146,.232),(.09,.132,.22)]],rubber,'Shin'+s)
    ell('Boot upper '+s,(side*.145,-.075,.145),(.136,.215,.102),dark,'Shin'+s)
    ell('Soft boot cuff '+s,(side*.145,.005,.212),(.128,.139,.09),dark,'Shin'+s)
    ell('Upturned boot toe '+s,(side*.145,-.245,.135),(.102,.103,.076),dark,'Shin'+s)
    sewn('Boot welt '+s,[(side*.145+.142*math.cos(a),-.08+.227*math.sin(a),.082) for a in [i*math.tau/48 for i in range(49)]],.005,thread,'Shin'+s)
    for z in (.19,.23):sewn('Boot lace '+s,[(side*.145-.057,-.126,z),(side*.145+.057,-.126,z+.012)],.007,cream,'Shin'+s)
    ell('Soft shoulder '+s,(side*.30,0,1.165),(.135,.141,.135),pine,'Arm'+s)
    ell('Tailored sleeve '+s,(side*.35,0,1.065),(.119,.13,.197),pine,'Arm'+s)
    ell('Elbow patch '+s,(side*.397,.057,.945),(.071,.081,.08),dark,'Forearm'+s)
    ell('Sleeve forearm '+s,(side*.39,-.023,.84),(.102,.113,.166),pine,'Forearm'+s)
    ell('Wool glove cuff '+s,(side*.40,-.035,.735),(.115,.125,.065),cream,'Forearm'+s)
    ell('Tailored mitten '+s,(side*.40,-.045,.65),(.11,.101,.116),dark,'Forearm'+s)
    ell('Mitten thumb '+s,(side*.32,-.083,.67),(.047,.061,.065),dark,'Forearm'+s)
    sewn('Mitten back seam '+s,[(side*.40-.06,-.13,.65),(side*.40,-.148,.635),(side*.40+.06,-.13,.65)],.004,thread,'Forearm'+s)
    ell('Rounded coat pocket '+s,(side*.165,-.197,.86),(.091,.031,.094),pine)
    sewn('Pocket bound flap '+s,[(side*.165-.073,-.224,.905),(side*.165,-.237,.89),(side*.165+.073,-.224,.905)],.007,cream)
    ell('Goggle padded rim '+s,(side*.106,-.171,1.778),(.089,.039,.069),dark,'Head')
    ell('Aged brass goggle bezel '+s,(side*.106,-.194,1.778),(.079,.024,.060),gold,'Head')
    ell('Glacier goggle lens '+s,(side*.106,-.214,1.778),(.061,.014,.042),goggle,'Head')
sewn('Goggle bridge',[(-.03,-.213,1.78),(0,-.224,1.79),(.03,-.213,1.78)],.011,gold,'Head')
sewn('Goggle leather strap',[(.251*math.cos(a),.202*math.sin(a),1.77) for a in [i*math.tau/64 for i in range(65)]],.018,dark,'Head')
cap_rings=[(0,0,1.66,.238,.194),(0,0,1.73,.249,.199),(0,0,1.80,.238,.188),(.025,.01,1.87,.205,.165),(.08,.02,1.94,.15,.125),(.16,.02,1.978,.101,.086),(.23,.015,1.965,.067,.058),(.282,.01,1.92,.025,.022)]
loft('Soft folded wool cap',cap_rings,red,'Head')
for a in (math.pi*.12,math.pi*.65,math.pi*1.2,math.pi*1.7):
    sewn('Knitted cap panel seam',[(x+(rx+.002)*math.cos(a),y+(ry+.002)*math.sin(a),z) for x,y,z,rx,ry in cap_rings],.004,thread,'Head')
ell('Turned wool cap brim',(0,0,1.695),(.256,.211,.052),cream,'Head')
for i in range(40):
    a=i*math.tau/40
    sewn('Brim knit rib',[(.253*math.cos(a),.21*math.sin(a),z) for z in (1.676,1.71)],.0035,thread,'Head')
ell('Wool pom pom',(.292,.01,1.90),(.076,.071,.078),cream,'Head')
ell('Thick scarf collar',(0,0,1.275),(.225,.181,.068),cream)
loft('Folded knitted scarf',[(.11,-.205,1.25,.054,.028),(.12,-.222,1.16,.060,.027),(.16,-.225,1.045,.059,.026),(.18,-.22,1.01,.053,.022)],cream,'Spine')
for z in (1.04,1.07):sewn('Scarf cranberry stripe',[(.123,-.247,z),(.225,-.247,z)],.008,red)
for i in range(5):sewn('Scarf fringe',[(.14+i*.018,-.223,1.02),(.143+i*.018,-.224,.982)],.005,cream)
sewn('Friendly stitched smile',[(x,-.218,1.387+(x/.055)**2*.020) for x in [-.055+i*.011 for i in range(11)]],.006,dark,'Head')
# A small courier badge ties the costume to the North Star interior.
ell('Courier badge',(-.14,-.203,1.12),(.044,.012,.048),gold)
sewn('Badge North Star',[(-.14,-.217,1.157),(-.14,-.217,1.085)],.004,cream)
sewn('Badge cross',[(-.169,-.217,1.12),(-.111,-.217,1.12)],.004,cream)
exec(compile(open(os.path.join(ROOT,'art/elf/refine.py'),encoding='utf-8').read(),'refine.py','exec'),globals())
