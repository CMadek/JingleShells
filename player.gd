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
var chase: Camera3D
var local_pilot := false
var dragging_orbit := false
var orbit_yaw := 0.23
var orbit_elevation := 0.30
var shown_yaw := orbit_yaw
var shown_elevation := orbit_elevation
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
		chase = Camera3D.new()
		chase.add_to_group("local_camera")
		chase.fov = Game.values.fov
		chase.top_level = true
		chase.far = cam.far
		add_child(chase)
		cam.make_current()
	presentation = preload("res://assets/elf/presentation.gd").new()
	add_child(presentation)
	presentation.setup(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or Game.menu_open:
		return
	if local_pilot and event.is_action_pressed("pilot_view"):
		world.toggle_pilot_view()
		return
	if local_pilot and event is InputEventMouseButton:
		if chase.current and event.button_index == MOUSE_BUTTON_RIGHT:
			dragging_orbit = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if dragging_orbit else Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		return
	if local_pilot and event is InputEventMouseMotion:
		if dragging_orbit and chase.current and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			orbit_yaw = wrapf(orbit_yaw - event.relative.x * .006, -PI, PI)
			orbit_elevation = clampf(orbit_elevation + event.relative.y * .006, -1.15, 1.30)
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
		if world.pilot_id != peer_id and at_ladder():
			position = Vector3(.55, 2.19, -2.80) if position.y < 1.0 else Vector3(1.14,.03,-.83)
			velocity = Vector3.ZERO
			return
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


func at_ladder() -> bool:
	if position.y < 1.0:
		return position.distance_to(Vector3(1.14, 0, -1.16)) < .95
	return position.y > 2.0 and absf(position.x) < 1.18 and absf(position.z + 2.8) < 1.35


func set_local_pilot(active: bool) -> void:
	if local_pilot == active:
		return
	local_pilot = active
	dragging_orbit = false
	cam.make_current()
	if active:
		rotation.y = 0
		pitch = -.30
		head.rotation.x = pitch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if active or Game.menu_open else Input.MOUSE_MODE_CAPTURED


func toggle_view() -> bool:
	if not local_pilot or Game.menu_open:
		return false
	if chase.current:
		dragging_orbit = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		cam.make_current()
		return false
	_update_chase(1.0)
	chase.make_current()
	return true


func _update_chase(weight: float) -> void:
	var plane: Node3D = world.bomber
	var target := plane.to_global(Vector3(0, 1.5, 0))
	shown_yaw = lerp_angle(shown_yaw, orbit_yaw, weight)
	shown_elevation = lerpf(shown_elevation, orbit_elevation, weight)
	var boom := Vector3.BACK.rotated(Vector3.RIGHT, -shown_elevation).rotated(Vector3.UP, shown_yaw)
	var next := target + plane.global_basis * boom * 25.25
	var ray := PhysicsRayQueryParameters3D.create(target, next, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		next = hit.position + hit.normal * .35
	chase.global_position = next
	if next.distance_squared_to(target) > .001:
		chase.look_at(target, Vector3.UP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and dragging_orbit:
		dragging_orbit = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
		if chase.current:
			_update_chase(1.0 - exp(-7.0 * delta))
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
