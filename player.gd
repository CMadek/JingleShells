extends CharacterBody3D
## One elf. Child of the Bomber node, so it rides along with the ship.
## Each peer controls its own elf and streams its state to everyone else.

const Cargo := preload("res://cargo.gd")
const Crouch := preload("res://assets/elf/crouch.gd")
var presentation: Node3D
var capsule_node: CollisionShape3D
var crouched := false
var net_grounded := true
@export var crouch_speed := 2.5
@export var camera_smoothing := 12.0
var held_kind := Cargo.Kind.EMPTY
var held_model: Node3D
var charging_since := -1

const WALK_SPEED := 5.0
const JUMP_SPEED := 5.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0022

var peer_id := 1
var world: Node3D
var head: Node3D
var cam: Camera3D
var pitch := 0.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 17
	var cs := CollisionShape3D.new()
	capsule_node = cs
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	net_pos = position
	if is_multiplayer_authority():
		cam = Camera3D.new()
		cam.current = true
		cam.add_to_group("local_camera")
		cam.fov = Game.values.fov
		cam.far = 2000.0
		head.add_child(cam)
	presentation = preload("res://assets/elf/presentation.gd").new()
	add_child(presentation)
	presentation.setup(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or Game.menu_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS * Game.values.sensitivity)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS * Game.values.sensitivity * (-1.0 if Game.values.invert else 1.0), -1.5, 1.5)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and held_kind != Cargo.Kind.EMPTY and world.pilot_id != peer_id:
			if event.pressed and charging_since < 0:
				charging_since = Time.get_ticks_msec()
				world.cargo_action("charge")
			elif not event.pressed and charging_since >= 0:
				charging_since = -1
				world.cargo_action("throw")
	elif event.is_action_pressed("interact"):
		var item_id: int = world.aimed_loose(head.global_transform) if held_kind == Cargo.Kind.EMPTY else 0
		if world.pilot_id != peer_id and item_id != 0:
			world.cargo_action("pickup", item_id)
		elif world.pilot_id == peer_id or position.distance_to(world.HELM_POS) < 2.5:
			world.request_helm()
		else:
			world.cargo_action("pickup")
	elif event.is_action_pressed("drop_cargo"):
		charging_since = -1
		world.cargo_action("drop")


func carry(kind: int) -> void:
	charging_since = -1
	presentation.trigger("drop" if kind == Cargo.Kind.EMPTY else "pickup")
	held_kind = kind
	if held_model:
		held_model.queue_free()
		held_model = null
	if kind != Cargo.Kind.EMPTY:
		held_model = Cargo.model(kind)
		presentation.socket.add_child(held_model)
		held_model.position = Vector3.ZERO
		presentation.trigger("pickup")


func _physics_process(delta: float) -> void:
	head.position.y = lerpf(head.position.y, 1.0 if crouched else 1.6, 1.0 - exp(-camera_smoothing * delta))
	if not is_multiplayer_authority():
		capsule_node.shape.height = Crouch.DUCKED if crouched else Crouch.STANDING
		capsule_node.position.y = capsule_node.shape.height / 2.0
		position = position.lerp(net_pos, 0.35)
		rotation.y = lerp_angle(rotation.y, net_yaw, 0.35)
		head.rotation.x = net_pitch
		return

	Crouch.update(self, capsule_node, not Game.menu_open and world.pilot_id != peer_id and Input.is_action_pressed("crouch"))
	if world.pilot_id == peer_id:
		velocity = Vector3.ZERO
		position = world.HELM_POS
		var v := Vector2.ZERO if Game.menu_open else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		world.send_pilot_input(v.x, -v.y, 0.0 if Game.menu_open else Input.get_axis("descend", "jump"))
	else:
		if is_on_floor():
			velocity.y = JUMP_SPEED if (not Game.menu_open and Input.is_action_just_pressed("jump")) else 0.0
		else:
			velocity.y -= GRAVITY * delta
		var input := Vector2.ZERO if Game.menu_open else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := global_transform.basis * Vector3(input.x, 0, input.y)
		velocity.x = dir.x * (crouch_speed if crouched else WALK_SPEED)
		velocity.z = dir.z * (crouch_speed if crouched else WALK_SPEED)
		move_and_slide()

	# Safety net: if you somehow fall out of the ship, hop back in.
	if global_position.y < world.bomber.global_position.y - 6.0:
		position = Vector3(0, 0.3, 1)
		velocity = Vector3.ZERO

	world.get_parent().sync_elf.rpc(position, rotation.y, head.rotation.x, crouched, is_on_floor())
