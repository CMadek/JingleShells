extends Node3D
## Visual-only character state. Inventory and cargo remain controlled by World.
const BODY = preload("res://assets/elf/flight_elf.glb")
const ARMS = preload("res://assets/elf/first_person_arms.glb")
const COAT_SHADER = preload("res://assets/elf/coat_palette.gdshader")
const COAT_MASK = preload("res://assets/elf/textures/crew_coat_tint.png")
const HANDS_COAT_MASK = preload("res://assets/elf/textures/hands_coat_tint.png")
var actor: CharacterBody3D
var model: Node3D
var hands: Node3D
var socket: Node3D
var animation: AnimationPlayer
var current := ""
var action := ""
var action_time := 0.0
var phase := 0.0
var last_position := Vector3.ZERO
var moving := false
var movement_speed := 0.0
var last_on_deck := false
var stride := 0.0
var body_meshes: Array[Node] = []
var first_person_body := false
var was_grounded := true
var charge_pose := false
@export var carry_offset := Vector3(0, -.28, -.65)
@export var hand_offset := Vector3(0, -.10, -.28)

func setup(player: CharacterBody3D) -> void:
	actor = player
	model = BODY.instantiate()
	model.rotation.y = PI
	add_child(model)
	animation = model.find_child("AnimationPlayer", true, false)
	if animation:
		if actor.world.mess and not animation.has_animation("lounge"):
			var sit: Animation = actor.world.mess.graphics.seated_clip.duplicate()
			var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
			var rig_path: NodePath = animation.get_node(animation.root_node).get_path_to(skeleton)
			for track in range(sit.get_track_count()-1,-1,-1):
				var bone := sit.track_get_path(track).get_concatenated_subnames()
				if skeleton.find_bone(bone) < 0: sit.remove_track(track)
				else: sit.track_set_path(track,NodePath("%s:%s" % [rig_path,bone]))
			animation.get_animation_library("").add_animation("lounge",sit)
		for name in animation.get_animation_list():
			animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR if name not in ["pickup", "throw", "drop", "land"] else Animation.LOOP_NONE
	socket = Node3D.new()
	if actor.is_multiplayer_authority():
		hands = ARMS.instantiate()
		actor.head.add_child(hands)
		hands.position = hand_offset
		hands.add_child(socket)
		socket.position = carry_offset
		body_meshes = model.find_children("*", "MeshInstance3D", true, false)
		for mesh in hands.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = "CargoSocket"
		attachment.add_child(socket)
	apply_palette(model)
	if hands:
		apply_palette(hands, true)
	last_on_deck = actor.world.aboard(actor.global_position)
	last_position = actor.world.bomber.to_local(actor.global_position) if last_on_deck else actor.global_position

func apply_palette(node: Node, first_person := false) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material and material.resource_name == "Coat":
				var copy := ShaderMaterial.new()
				copy.shader = COAT_SHADER
				copy.set_shader_parameter("surface_color", material.albedo_texture)
				copy.set_shader_parameter("coat_mask", HANDS_COAT_MASK if first_person else COAT_MASK)
				copy.set_shader_parameter("coat_color", [Color("254e38"), Color("78323d"), Color("354d65")][actor.peer_id % 3])
				node.set_surface_override_material(surface, copy)
	for child in node.get_children():
		apply_palette(child, first_person)

func trigger(next: String) -> void:
	if next == "charge":
		charge_pose = true
		return
	charge_pose = false
	action = next if next in ["pickup", "throw", "drop", "land"] else ""
	action_time = .38 if action != "" else 0.0

func _physics_process(delta: float) -> void:
	if not actor: return
	var deck: bool = actor.world.aboard(actor.global_position)
	var point: Vector3 = actor.world.bomber.to_local(actor.global_position) if deck else actor.global_position
	var distance := Vector2(point.x-last_position.x,point.z-last_position.z).length()
	var measured := distance / delta if deck == last_on_deck and distance < 1.0 else 0.0
	movement_speed = lerpf(movement_speed, measured, 1.0-exp(-14.0*delta))
	moving = movement_speed > .24
	last_on_deck = deck
	last_position = point

func _process(delta: float) -> void:
	if not actor:
		return
	phase += delta
	var local := actor.is_multiplayer_authority()
	var pilot: bool = actor.world.pilot_id == actor.peer_id or actor.world.stations.station_for(actor.peer_id) != ""
	var grounded: bool = actor.is_on_floor() if local else actor.net_grounded
	if grounded and not was_grounded:
		trigger("land")
	was_grounded = grounded
	action_time = maxf(0, action_time - delta)
	if local and Game.menu_open:
		charge_pose = false
		action_time = 0
	var carrying: bool = actor.held_kind != 0 or actor.world.mess.held(actor.peer_id) >= 0
	if is_instance_valid(actor.held_model):
		actor.held_model.visible = not pilot
	var next := "idle"
	if actor.world.mess.seats.has(actor.peer_id):
		next = "lounge"
	elif actor.world.stations.station_for(actor.peer_id) == "turret":
		next = "crouch_idle"
	elif pilot:
		next = "helm"
	elif action_time > 0:
		next = action
	elif actor.crouched:
		next = ("crouch_carry_walk" if moving else "crouch_carry_idle") if carrying else ("crouch_walk" if moving else "crouch_idle")
	elif charge_pose and carrying:
		next = "charge"
	elif not grounded:
		next = "jump"
	elif carrying:
		next = "carry_walk" if moving else "carry_idle"
	elif moving:
		next = "walk"
	if next != current and animation and animation.has_animation(next):
		animation.play(next, .15)
		current = next
	if animation:
		animation.speed_scale = clampf(movement_speed / (actor.crouch_speed if actor.crouched else actor.WALK_SPEED), .4, 1.6) if "walk" in next else 1.0
	if hands:
		var first_person: bool = actor.cam == actor.get_viewport().get_camera_3d() or actor.world.stations.station_for(actor.peer_id) == "turret"
		if first_person != first_person_body:
			first_person_body = first_person
			for mesh in body_meshes:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		hands.visible = first_person and not pilot
		var lift := .0 if carrying else -.20
		var reach := -.12 * sin((action_time / .38) * PI) if action_time > 0 else 0.0
		var target := hand_offset + Vector3(0, lift + sin(phase * 2) * .004, reach + (.12 if charge_pose else 0.0))
		stride = fmod(stride + minf(movement_speed,actor.WALK_SPEED)*delta*2.8,TAU)
		var swing := clampf(movement_speed / actor.WALK_SPEED,0,1) if grounded else 0.0
		target += Vector3(sin(stride)*.025, -cos(2*stride)*.018, 0) * swing
		hands.position = hands.position.lerp(target, 1.0 - exp(-14 * delta))
