extends Node3D
## Visual vignette only. All motion is bounded and continuous across action loops.
const CREW = preload("res://assets/menu/off_duty_crew.glb")
const PLANE = preload("res://assets/aircraft/north_star.glb")
const SOFT_PARTICLE = preload("res://assets/menu/soft_particle.gdshader")
var camera: Camera3D
var actors: Array[Node3D] = []
var animations: Array[AnimationPlayer] = []
var bulbs: Array[MeshInstance3D] = []
var faces: Array[Dictionary] = []

func _process(_delta: float) -> void:
	# Use each acting clip's clock, including paused/seeking review captures.
	for face in faces:
		var time: float = face.player.current_animation_position
		var blink := 0.0
		for beat in [2.3, 7.8, 13.4, 19.5, 20.0]:
			var distance := absf(fposmod(time + face.offset - beat + 12, 24) - 12)
			if distance < .13:
				blink = maxf(blink, pow(cos(distance / .13 * PI * .5), 2))
		for target in face.targets:
			target.mesh.set_blend_shape_value(target.index, blink)

func _ready() -> void:
	name = "OffDutyAirfield"
	_build_environment()
	var plane: Node3D = PLANE.instantiate()
	plane.name = "ParkedNorthStar"
	plane.position = Vector3(0, 3.05, 7)
	add_child(plane)
	preload("res://assets/aircraft/cabin_finish.gd").polish_glass(plane)
	_omni(plane, Vector3(0, 3.5, -7.4), Color("ffd09a"), .7, 7.0)
	_omni(plane, Vector3(0, 3.0, 1), Color("ffce8a"), .8, 8.0)
	_build_set()
	_crew(Vector3(6.25, 0, -7.9), 2.0, "menu_smoke", Color("28472f"), 1.0)
	_crate(Vector3(7.9, .23, -7.3), Vector3(.95, .46, .8), .12)
	_crew(Vector3(7.884, 0, -7.57), 3.2, "menu_sit", Color("693034"), 6.0)
	_crate(Vector3(9, .48, -5.7), Vector3(.9, .96, .85), -.12)
	_crew(Vector3(9.3, 0, -6.6), 3.65, "menu_lean", Color("304455"), 3.0)
	_lantern(Vector3(9, .97, -5.7))
	_snow()
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.position = Vector3(12, 3.3, -14)
	camera.fov = 48
	camera.near = .1
	camera.far = 180
	add_child(camera)
	camera.look_at(Vector3(8, 2.3, -2))
	camera.make_current()

func fit_aspect(aspect: float) -> void:
	if not camera:
		return
	# Keep the crew in the right-hand picture at 4:3, 16:9 and ultrawide.
	camera.fov = 48 + maxf(0, 1.7778 - aspect) * 16
	camera.look_at(Vector3(8 + maxf(0, 1.7778 - aspect) * 1.2, 2.3, -2))

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("101c30")
	sky_material.sky_horizon_color = Color("1f2c42")
	sky_material.ground_horizon_color = Color("1f2c42")
	sky_material.ground_bottom_color = Color("202f43")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("90aac5")
	environment.ambient_light_energy = .25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("25394d")
	environment.fog_density = .005
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-32, -28, 0)
	moon.light_color = Color("a4bdd8")
	moon.light_energy = .22
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70
	add_child(moon)
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(240, 240)
	ground.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/snow.gdshader")
	ground.material_override = material
	add_child(ground)
	var key := SpotLight3D.new()
	key.position = Vector3(10, 4, -11)
	key.light_color = Color("ffdbac")
	key.light_energy = .9
	key.spot_range = 17
	key.spot_angle = 55
	key.spot_attenuation = .7
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3(7.6, .8, -7))
	_omni(self, Vector3(3, 3, -3), Color("8eadd0"), .65, 12)

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .9
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material

func _mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, pos, material)

func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 10
	var mesh := _mesh(parent, shape, (a+b)*.5, material)
	mesh.quaternion = Quaternion(Vector3.UP, (b-a).normalized())

func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)

func _crate(pos: Vector3, size: Vector3, angle: float) -> void:
	var crate := Node3D.new()
	crate.position = pos
	crate.rotation.y = angle
	add_child(crate)
	var wood := _material(Color("75614a"))
	var dark := _material(Color("443d32"))
	_box(crate, Vector3.ZERO, size, wood)
	for i in [-1, 1]:
		_box(crate, Vector3(i*size.x*.36, 0, 0), Vector3(.065, size.y+.035, size.z+.035), dark)
	for i in range(1, 5):
		_box(crate, Vector3(0, 0, -size.z*.5 + i*size.z/5), Vector3(size.x+.006, size.y+.008, .009), dark)

func _lantern(pos: Vector3) -> void:
	var metal := _material(Color("263c35"))
	var glass := _material(Color("ffe1a1"), true)
	_box(self, pos+Vector3(0,.06,0), Vector3(.22,.12,.22), metal)
	_box(self, pos+Vector3(0,.22,0), Vector3(.14,.24,.14), glass)
	_box(self, pos+Vector3(0,.36,0), Vector3(.25,.06,.25), metal)
	for x in [-.09,.09]:
		for z in [-.09,.09]:
			_rod(self, pos+Vector3(x,.1,z), pos+Vector3(x,.36,z), .012, metal)
	_omni(self, pos+Vector3(0,.3,0), Color("ffca82"), 1.5, 4)

func _build_set() -> void:
	var wood := _material(Color("353e39"))
	var snow := _material(Color("b5c4cd"))
	var green := _material(Color("263d37"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2412
	# A quiet tree line, not a simulated gameplay level.
	var green_trees: Array[Transform3D] = []
	var snow_trees: Array[Transform3D] = []
	for i in 28:
		var pos := Vector3(-48+i*3.6, 0, 38+rng.randf_range(-8, 13))
		var height := rng.randf_range(5, 11)
		for tier in 3:
			var radius := height*(.27-tier*.05)
			var basis := Basis.IDENTITY.scaled(Vector3(radius,height*.55,radius))
			green_trees.append(Transform3D(basis,pos+Vector3(0,height*(.32+tier*.22),0)))
			snow_trees.append(Transform3D(basis.scaled(Vector3.ONE*.82),pos+Vector3(0,height*(.32+tier*.22)+height*.08,0)))
	_tree_batch(green_trees, green)
	_tree_batch(snow_trees, snow)
	# Low hangar silhouette and warm distant windows.
	_box(self, Vector3(-20,3,22), Vector3(18,6,12), wood)
	_box(self, Vector3(-20,6.1,22), Vector3(19,.3,13), snow)
	for x in [-26,-22,-18,-14]:
		_box(self, Vector3(x,3.9,15.97), Vector3(1.7,1.1,.04), _material(Color("b89965"),true))
	# Crooked festive cable beside the parked plane, with modest warm bulbs.
	var cable := _material(Color("242e2b"))
	var bulb_material := _material(Color("ffd997"), true)
	var first := Vector3(4.1, 4.3, -1.5)
	var last := Vector3(11, 3.1, .8)
	_rod(self, Vector3(11,0,.8), last+Vector3(0,.2,0), .065, wood)
	for i in 16:
		var t := i/15.0
		var point := first.lerp(last,t) - Vector3(0,sin(t*PI)*.65,0)
		if i > 0:
			var previous_t := (i-1)/15.0
			var previous_point := first.lerp(last,previous_t)-Vector3(0,sin(previous_t*PI)*.65,0)
			_rod(self, previous_point, point, .012, cable)
		var bulb := SphereMesh.new()
		bulb.radius = .045
		bulb.height = .11
		bulb.radial_segments = 8
		bulb.rings = 4
		bulbs.append(_mesh(self, bulb, point-Vector3(0,.08,0), bulb_material))
	# Cargo awaiting the next sortie; reuse the actual present asset.
	for spec in [[Vector3(3.6,.03,-1.8),-.2],[Vector3(4.1,.03,-1.2),.3]]:
		var present: Node3D = preload("res://assets/cargo/present.glb").instantiate()
		present.position = spec[0]
		present.rotation.y = spec[1]
		add_child(present)

func _tree_batch(transforms: Array[Transform3D], material: Material) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 1
	cone.height = 1
	cone.radial_segments = 9
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cone
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var trees := MultiMeshInstance3D.new()
	trees.multimesh = multimesh
	trees.material_override = material
	add_child(trees)

func _crew(pos: Vector3, yaw: float, clip: String, color: Color, offset: float) -> void:
	var actor: Node3D = CREW.instantiate()
	actor.position = pos
	actor.rotation.y = yaw
	add_child(actor)
	actors.append(actor)
	var expression: String = {"menu_smoke":"Veteran", "menu_sit":"Smirk", "menu_lean":"Skeptic"}[clip]
	var blink_targets: Array[Dictionary] = []
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		for index in node.mesh.get_blend_shape_count():
			node.set_blend_shape_value(index, 0.0)
			var shape: String = node.mesh.get_blend_shape_name(index)
			if shape == expression:
				node.set_blend_shape_value(index, 1.0)
			elif shape == expression + "Blink":
				blink_targets.append({"mesh":node,"index":index})
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material is StandardMaterial3D and material.resource_name == "Skin":
				var skin: StandardMaterial3D = material.duplicate()
				skin.vertex_color_use_as_albedo = true
				skin.vertex_color_is_srgb = false
				node.set_surface_override_material(surface, skin)
			elif material and material.resource_name == "Coat":
				var coat := ShaderMaterial.new()
				coat.shader = preload("res://assets/elf/coat_palette.gdshader")
				coat.set_shader_parameter("surface_color", material.albedo_texture)
				coat.set_shader_parameter("coat_mask", preload("res://assets/elf/textures/crew_coat_tint.png"))
				coat.set_shader_parameter("coat_color", color)
				node.set_surface_override_material(surface, coat)
			# The third crew member is simply enjoying the break.
			elif clip == "menu_lean" and material and material.resource_name.begins_with("Cigarette"):
				node.hide()
			elif clip != "menu_lean" and material and material.resource_name.begins_with("Watch"):
				node.hide()
	var animation: AnimationPlayer = actor.find_child("AnimationPlayer", true, false)
	for animation_name in animation.get_animation_list():
		animation.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	animation.play(clip)
	animation.advance(offset)
	animations.append(animation)
	faces.append({"player":animation, "targets":blink_targets, "offset":offset*.73, "expression":expression})
	if clip != "menu_lean":
		var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "SmokeTip"
		skeleton.add_child(attachment)
		_smoke(attachment)

func _smoke(parent: Node3D) -> void:
	var smoke := CPUParticles3D.new()
	smoke.name = "CigaretteSmoke"
	smoke.amount = 24
	smoke.lifetime = 4.8
	smoke.preprocess = 4.8
	smoke.local_coords = false
	smoke.direction = Vector3(0,1,0)
	smoke.spread = 12
	smoke.initial_velocity_min = .20
	smoke.initial_velocity_max = .25
	smoke.gravity = Vector3(.035,.035,0)
	smoke.scale_amount_min = .10
	smoke.scale_amount_max = .16
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0,.15))
	scale_curve.add_point(Vector2(1,1))
	smoke.scale_amount_curve = scale_curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,.15,.7,1])
	ramp.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,.7),Color(1,1,1,.3),Color(1,1,1,0)])
	smoke.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	smoke.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = SOFT_PARTICLE
	material.set_shader_parameter("tint",Color(.78,.85,.91,.55))
	smoke.material_override = material
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(smoke)

func _snow() -> void:
	var snow := CPUParticles3D.new()
	snow.name = "AirfieldSnow"
	snow.amount = 380
	snow.lifetime = 18
	snow.preprocess = 18
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(19,8,17)
	snow.position = Vector3(1,10,3)
	snow.direction = Vector3(.12,-1,.035)
	snow.spread = 9
	snow.initial_velocity_min = .35
	snow.initial_velocity_max = .75
	snow.gravity = Vector3(.015,-.015,0)
	snow.scale_amount_min = .018
	snow.scale_amount_max = .04
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	snow.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = SOFT_PARTICLE
	material.set_shader_parameter("tint",Color(.84,.9,1,.75))
	snow.material_override = material
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,.15,.85,1])
	ramp.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)])
	snow.color_ramp = ramp
	add_child(snow)
