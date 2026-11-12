extends Node3D
## Visual-only character state. Inventory and cargo remain controlled by World.
const BODY = preload("res://assets/elf/flight_elf.glb")
const ARMS = preload("res://assets/elf/first_person_arms.glb")
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
		for name in animation.get_animation_list():
			animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR if name not in ["pickup", "throw", "drop", "land"] else Animation.LOOP_NONE
	socket = Node3D.new()
	if actor.is_multiplayer_authority():
		actor.head.add_child(socket)
		socket.position = carry_offset
		hands = ARMS.instantiate()
		actor.head.add_child(hands)
	else:
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = "CargoSocket"
		attachment.add_child(socket)
	apply_palette(model)
	if hands:
		apply_palette(hands)
	last_position = (actor.world.bomber.to_local(actor.global_position) if actor.world.aboard(actor.global_position) else actor.global_position)

func apply_palette(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material and material.resource_name == "Coat":
				var copy = material.duplicate()
				copy.albedo_color = [Color("254e38"), Color("78323d"), Color("354d65")][actor.peer_id % 3]
				node.set_surface_override_material(surface, copy)
	for child in node.get_children():
		apply_palette(child)

func trigger(next: String) -> void:
	if next == "charge":
		charge_pose = true
		return
	charge_pose = false
	action = next if next in ["pickup", "throw", "drop", "land"] else ""
	action_time = .38 if action != "" else 0.0

func _process(delta: float) -> void:
	if not actor:
		return
	phase += delta
	var movement_speed: float = (actor.world.bomber.to_local(actor.global_position) if actor.world.aboard(actor.global_position) else actor.global_position).distance_to(last_position) / maxf(delta, .001)
	moving = movement_speed > .3
	last_position = (actor.world.bomber.to_local(actor.global_position) if actor.world.aboard(actor.global_position) else actor.global_position)
	var local := actor.is_multiplayer_authority()
	var pilot: bool = actor.world.pilot_id == actor.peer_id
	var grounded: bool = actor.is_on_floor() if local else actor.net_grounded
	if grounded and not was_grounded:
		trigger("land")
	was_grounded = grounded
	action_time = maxf(0, action_time - delta)
	if local and Game.menu_open:
		charge_pose = false
		action_time = 0
	var carrying: bool = actor.held_kind != 0
	if is_instance_valid(actor.held_model):
		actor.held_model.visible = not pilot
	var next := "idle"
	if pilot:
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
	model.visible = not local or actor.cam != actor.get_viewport().get_camera_3d()
	if hands:
		hands.visible = not model.visible and not pilot
		var lift := .0 if carrying else -.20
		var reach := -.12 * sin((action_time / .38) * PI) if action_time > 0 else 0.0
		var target := hand_offset + Vector3(0, lift + sin(phase * 2) * .004, reach + (.12 if charge_pose else 0.0))
		hands.position = hands.position.lerp(target, 1.0 - exp(-14 * delta))
		socket.position = carry_offset + hands.position
