extends Node3D
const CREW := preload("res://assets/menu/off_duty_crew.glb")
var room: Node3D
var world: Node3D
var seated_clip: Animation
var quartermaster: Node3D
var canvas_sack: ArrayMesh
func sign_at(value: String, p: Vector3, scale_px: float, color := Color("f6dda2")) -> Label3D:
	var tag := Label3D.new()
	tag.text = value
	tag.position = p
	tag.pixel_size = scale_px
	tag.font_size = 52
	tag.modulate = color
	tag.outline_size = 1
	add_child(tag)
	return tag

func build(mess: Node3D,depot: Node3D) -> void:
	room = mess
	world = mess.world
	var interior: Node3D = preload("res://assets/depot/last_stop.glb").instantiate()
	interior.position = Vector3(-28,0,841)
	add_child(interior)
	# Fitted furniture has simple collision independent of the bevelled visual meshes.
	for fitting in [[Vector3(-34.64,.36,840.65),Vector3(1.42,.58,4.82)],[Vector3(-35.20,.87,840.65),Vector3(.36,1.26,4.65)],[Vector3(-33.05,.58,840.65),Vector3(1.13,.13,2.62)]]:
		world._hull_box(depot.solid,fitting[1],fitting[0])
	world._hull_box(depot.solid,Vector3(1.28,.55,.89),Vector3(-34.59,.365,836.84))
	for s in [-1,1]:
		world._hull_box(depot.solid,Vector3(1.58,1.8,.24),room.CHIMNEY+Vector3(0,-.9,s*.68))
		world._hull_box(depot.solid,Vector3(.24,1.8,1.14),room.CHIMNEY+Vector3(s*.68,-.9,0))
	var rollway := StaticBody3D.new()
	rollway.collision_layer = 16
	add_child(rollway)
	rollway.position = Vector3(-22.2,.3,844.21)
	rollway.rotation.x = .17
	world._hull_box(rollway,Vector3(.61,.08,1.92),Vector3.ZERO)
	sign_at("THE LAST STOP",Vector3(-28.5,3.37,832.73),.009)
	sign_at("NORTH STAR   •   CREW OUTFITTER",Vector3(-28.5,3.02,832.73),.0034)
	sign_at("FLIGHT LINE  →",Vector3(-22.5,3.37,832.73),.0048)
	quartermaster = duty_elf(room.CLERK,0,1.24,"menu_cocoa","Veteran",Color("46503a"))
	var player: AnimationPlayer = quartermaster.find_child("AnimationPlayer",true,false)
	seated_clip = player.get_animation("menu_sit")
	duty_elf(Vector3(-34.48,.16,837.03),.54,1.0,"menu_sit","Smirk",Color("7c4940"))
	for i in room.COUNTER.size():
		var p: Vector3 = room.COUNTER[i]
		world._box(self,Vector3(1.26,.10,.62),p-Vector3.UP*.19,Color("244b3a"))
		var card_back := world._box(self,Vector3(1.38,.19,.035),p+Vector3(0,-.12,.46),Color("373e35")) as MeshInstance3D
		card_back.rotation.x = -.22
		var good: Dictionary = room.STOCK[i]
		var card := sign_at("%s    %d" % [str(good.name).to_upper(),good.cost],p+Vector3(0,-.115,.485),.0022)
		card.rotation.x = card_back.rotation.x
		if i == 0:
			var glove := ellipsoid(p,Vector3(.40,.18,.28),Color("a45c32"))
			for n in 4: ellipsoid(p+Vector3(-.14+n*.09,.02,-.13),Vector3(.09,.11,.21),Color("81482a"))
			glove.rotation.y = -.2
		else:
			for j in 2:
				var strap := world._box(self,Vector3(.07,.07,.49),p+Vector3(j*.17-.08,0,0),Color("99553a")) as MeshInstance3D
				strap.rotation.y = -.35 if j == 0 else .35
			ellipsoid(p+Vector3(0,0,.19),Vector3(.32,.1,.22),Color("c39457"))
	world._box(self,Vector3(1.62,.62,.085),Vector3(-22.15,2.57,842.04),Color("344b40"))
	world._box(self,Vector3(.09,.86,.09),Vector3(-22.8,2.1,842.04),Color("73573f"))
	room.placard = sign_at("CHIMNEY LEAGUE\n00   /   BEST 0.0 m",Vector3(-22.15,2.57,842.10),.0029)
	room.carrier = Node3D.new()
	add_child(room.carrier)
	room.stamp = Node3D.new()
	room.stamp.position = Vector3(-28.55,1.59,834.71)
	add_child(room.stamp)
	world._box(self,Vector3(.37,.026,.28),Vector3(-28.55,1.27,834.71),Color("e9d9ad"))
	world._box(room.stamp,Vector3(.23,.085,.13),Vector3(0,-.075,0),Color("755538"))
	ellipsoid_on(room.stamp,Vector3(0,.03,0),Vector3(.14,.19,.14),Color("8e4840"))
	world._box(self,Vector3(12.2,.10,.10),Vector3(-26.8,4.01,835.9),Color("4c4d48"))
	canvas_sack = sack_shape()
	for hook in [-1.0,0.0,1.0]:
		mailbag(hook)
	room.bell = AudioStreamPlayer3D.new()
	room.bell.stream = preload("res://assets/audio/departure_bell.wav")
	room.bell.position = room.CHIMNEY
	room.bell.volume_db = -13
	room.bell.max_distance = 24
	add_child(room.bell)
	# Short, focused sources leave shadow between the warm work areas.
	practical(Vector3(-32.6,3.18,837.1),Vector3(-33.5,.55,840.4),Color("ffd197"),5.3,8,49,true)
	practical(Vector3(-25.2,3.18,836.9),Vector3(-28.5,1.45,834.1),Color("ffd9a5"),6.8,9,50,true)
	practical(Vector3(-23.0,3.18,844.8),Vector3(-22.1,.55,842.2),Color("ffc286"),4.2,7,52,false)
	depot.lamp(Vector3(-34.7,1.86,837.85),Color("ffcc92"),.88,4.8)
	depot.lamp(Vector3(-28.8,2.65,833.1),Color("ffcb8c"),1.15,3.6)
	practical(Vector3(-18.3,2.8,835.8),Vector3(-25.5,.2,837.4),Color("a7caf2"),3.8,12,45,true,false)
	poster(Vector3(-35.53,2.30,843.25),PI/2)
	poster(Vector3(-20.47,2.28,840.65),-PI/2)
	var decorations := preload("res://mess_decorations.gd").new()
	decorations.name = "HolidayTrim"
	add_child(decorations)
	decorations.build()
	crew_photo()

func duty_elf(at: Vector3, yaw: float, size: float, clip: String, expression: String, coat: Color) -> Node3D:
	var actor: Node3D = CREW.instantiate()
	actor.position = at
	actor.rotation.y = yaw
	actor.scale = Vector3.ONE*size
	add_child(actor)
	preload("res://off_duty_uniform.gd").dress(actor,clip,coat,expression)
	var player: AnimationPlayer = actor.find_child("AnimationPlayer",true,false)
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.play(clip)
	return actor

func practical(at: Vector3, target: Vector3, tint: Color, energy: float, reach: float, cone: float, shadows: bool, has_bulb := true) -> void:
	var light := SpotLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = cone
	light.spot_angle_attenuation = .85
	light.spot_attenuation = .78
	light.shadow_enabled = shadows
	light.shadow_opacity = .78
	add_child(light)
	light.look_at(target,Vector3.UP)
	if has_bulb:
		var glow := ellipsoid(at+Vector3.UP*.015,Vector3(.14,.12,.14),tint)
		glow.material_override = world._mat(tint,true)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func mailbag(offset: float) -> void:
	var holder := Node3D.new()
	holder.position.x = offset
	room.carrier.add_child(holder)
	world._box(holder,Vector3(.055,.23,.06),Vector3(0,.26,0),Color("594a35"))
	var roller := ellipsoid_on(holder,Vector3(0,.375,.066),Vector3(.15,.15,.066),Color("3d433d"))
	roller.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sack := MeshInstance3D.new()
	sack.mesh = canvas_sack
	sack.rotation.y = offset*.26
	holder.add_child(sack)
	world._box(holder,Vector3(.16,.035,.14),Vector3(0,.083,0),Color("795135"))
	var tag := world._box(holder,Vector3(.10,.15,.018),Vector3(.045,-.13,.189),Color("d7ba88")) as MeshInstance3D
	tag.rotation = Vector3(-.19,0,.16*offset+.09)

func sack_shape() -> ArrayMesh:
	# Each ring describes the radius and height of the sewn base, belly and gathered neck.
	var profile := [Vector2(.015,-.46),Vector2(.19,-.45),Vector2(.25,-.39),Vector2(.265,-.26),
		Vector2(.23,-.11),Vector2(.15,.015),Vector2(.065,.081),Vector2(.115,.15),Vector2(.078,.16)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 32
	for layer in profile.size():
		var ring: Vector2 = profile[layer]
		for j in sides:
			var angle := TAU*j/sides
			var fold := cos(7*angle+layer*.145)
			var r := ring.x*(1+(.12 if layer > 4 else .045)*fold+.032*sin(3*angle))
			st.set_color(Color("bca47c").darkened(.048*(1-fold)))
			st.add_vertex(Vector3(r*cos(angle)+.035*cos(layer*.41),ring.y+.01*cos(3*angle),r*.78*sin(angle)))
	for layer in range(profile.size()-1):
		for j in sides:
			var a := layer*sides+j
			var b := layer*sides+(j+1)%sides
			for idx in [a,b,a+sides,b,b+sides,a+sides]: st.add_index(idx)
	st.generate_normals()
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = .97
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(cloth)
	return st.commit()

func crew_photo() -> void:
	var frame := Node3D.new()
	frame.position = Vector3(-35.72,2.38,840.20)
	frame.rotation = Vector3(0,PI/2,-.026)
	add_child(frame)
	world._box(frame,Vector3(1.53,1.09,.06),Vector3.ZERO,Color("654831"))
	world._box(frame,Vector3(1.43,.99,.03),Vector3(0,0,.039),Color("ddcfab"))
	var print_mesh := QuadMesh.new()
	print_mesh.size = Vector2(1.32,.745)
	var print_node := MeshInstance3D.new()
	print_node.mesh = print_mesh
	print_node.position = Vector3(0,.053,.058)
	var sepia := StandardMaterial3D.new()
	sepia.albedo_texture = preload("res://assets/menu/airfield_still.jpg")
	sepia.albedo_color = Color("f3dfb5")
	sepia.roughness = .9
	print_node.material_override = sepia
	frame.add_child(print_node)
	var caption := sign_at("Christmas Eve   •   Night crew",Vector3.ZERO,.00135,Color("513a29"))
	caption.reparent(frame,false)
	caption.position = Vector3(0,-.411,.059)
	caption.outline_size = 0

func poster(at: Vector3, yaw: float) -> void:
	var frame := Node3D.new()
	frame.position = at
	frame.rotation.y = yaw
	add_child(frame)
	world._box(frame,Vector3(1.47,1.99,.06),Vector3.ZERO,Color("594937"))
	var print_mesh := QuadMesh.new()
	print_mesh.size = Vector2(1.40,1.92)
	var print_node := MeshInstance3D.new()
	print_node.mesh = print_mesh
	print_node.position.z = .036
	var stock := StandardMaterial3D.new()
	stock.albedo_texture = preload("res://assets/depot/air_mail.svg")
	print_node.material_override = stock
	frame.add_child(print_node)
	for line in [["OVERNIGHT",-.47,.0024],["AIR MAIL",-.60,.0044],["NORTH STAR POST   •   1947",-.81,.0014]]:
		var lettering := sign_at(line[0],Vector3.ZERO,line[2])
		lettering.reparent(frame,false)
		lettering.position = Vector3(0,line[1],.040)

func ellipsoid(p: Vector3, dims: Vector3, tint: Color) -> MeshInstance3D:
	return ellipsoid_on(self,p,dims,tint)

func ellipsoid_on(parent: Node3D,p: Vector3,dims: Vector3,tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = SphereMesh.new()
	node.scale = dims
	node.position = p
	node.material_override = world._mat(tint)
	parent.add_child(node)
	return node

func dress_prop(body: Node3D,i: int,texture: Texture2D,dims: Vector3) -> void:
	if i == 0:
		world._box(body,dims,Vector3.ZERO,Color("c4ae83"))
		var page := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(dims.x,dims.z)
		page.mesh = plane
		page.position.y = dims.y*.5+.001
		var paper := StandardMaterial3D.new()
		paper.albedo_texture = texture
		paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paper.cull_mode = BaseMaterial3D.CULL_DISABLED
		page.material_override = paper
		body.add_child(page)
	elif i < 4:
		var parcel := preload("res://assets/cargo/present.glb").instantiate()
		parcel.scale *= .75
		body.add_child(parcel)
	elif i < 6:
		var mug := MeshInstance3D.new()
		var tin := CylinderMesh.new()
		tin.top_radius = .105
		tin.bottom_radius = .088
		tin.height = .22
		mug.mesh = tin
		mug.material_override = world._mat(Color("849a97"))
		body.add_child(mug)
		ellipsoid_on(body,Vector3(0,.11,0),Vector3(.185,.009,.185),Color("473422"))
		var handle := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = .051
		ring.outer_radius = .077
		handle.mesh = ring
		handle.rotation.x = PI*.5
		handle.position.x = .11
		handle.material_override = mug.material_override
		body.add_child(handle)
	else:
		ellipsoid_on(body,Vector3.ZERO,dims*1.17,Color("ad6954"))
		ellipsoid_on(body,Vector3(0,.10,0),Vector3(.035,.015,.035),Color("805d3c"))
