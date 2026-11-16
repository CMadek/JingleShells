extends CharacterBody3D
## World-space elf; World carries crew inside the cabin or occupied belly station.
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
var last_lounge_seat := -1
var dragging_orbit := false
var orbit_yaw := 0.23
var orbit_elevation := 0.30
var shown_yaw := orbit_yaw
var shown_elevation := orbit_elevation
var chase_heading := 0.0
var cam: Camera3D
var pitch := 0.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 17
	platform_floor_layers = 0
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
	if world.stations.station_for(peer_id) != "":
		world.stations.handle_input(event)
		return
	if not local_pilot and world.mess.handle_input(peer_id,event):
		get_viewport().set_input_as_handled()
		return
	if local_pilot and event.is_action_pressed("pilot_view"):
		world.toggle_pilot_view()
		return
	if local_pilot and event.is_action_pressed("aerobatics"):
		world.request_aerobatics()
		get_viewport().set_input_as_handled()
		return
	if local_pilot and event.is_action_pressed("cruise_hold"):
		_send_flight_controls()
		world.request_cruise_hold()
		get_viewport().set_input_as_handled()
		return
	if local_pilot and chase.current and (event.is_action_pressed("pilot_orbit") or event.is_action_released("pilot_orbit")):
		dragging_orbit = event.is_action_pressed("pilot_orbit")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if dragging_orbit else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if local_pilot and event is InputEventMouseMotion:
		if dragging_orbit and chase.current and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			orbit_yaw = wrapf(orbit_yaw - event.relative.x * .006, -PI, PI)
			orbit_elevation = clampf(orbit_elevation + event.relative.y * .006, -1.15, 1.30)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -event.relative.x * MOUSE_SENS * Game.values.sensitivity)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS * Game.values.sensitivity * (-1.0 if Game.values.invert else 1.0), -1.5, 1.5)
		head.rotation.x = pitch
	elif not local_pilot and (event.is_action_pressed("crew_primary") or event.is_action_released("crew_primary")):
		if event.is_pressed() and world.stations.aimed(peer_id) == "turret":
			world.stations.request("turret")
			get_viewport().set_input_as_handled()
		elif event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and held_kind != Cargo.Kind.EMPTY and world.pilot_id != peer_id:
			if event.is_pressed() and charging_since < 0:
				charging_since = Time.get_ticks_msec()
				world.cargo_action("charge")
			elif not event.is_pressed() and charging_since >= 0:
				charging_since = -1
				world.cargo_action("throw")
	elif event.is_action_pressed("interact"):
		if world.queues.interact(peer_id): return
		var station: String = world.stations.aimed(peer_id)
		if station == "turret": return
		if station == "delivery":
			world.stations.request(station)
			return
		var item_id: int = world.aimed_loose(head.global_transform) if held_kind == Cargo.Kind.EMPTY else 0
		if world.pilot_id != peer_id and world.access.aimed(head.global_transform) != "":
			world.access.request(world.access.aimed(head.global_transform))
		elif world.pilot_id != peer_id and item_id != 0:
			world.cargo_action("pickup", item_id)
		elif world.pilot_id == peer_id or global_position.distance_to(world.bomber.to_global(world.HELM_POS)) < 2.5:
			world.request_helm()
		else:
			world.cargo_action("pickup")
	elif not local_pilot and event.is_action_pressed("drop_cargo"):
		charging_since = -1
		world.cargo_action("drop")


func set_local_pilot(active: bool) -> void:
	if local_pilot == active:
		return
	local_pilot = active
	dragging_orbit = false
	cam.fov = Game.values.fov
	chase.fov = Game.values.fov
	cam.make_current()
	if active:
		rotation.y = world.heading
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
	# Follow the turn while keeping the horizon steady as the wings bank.
	# At the top of a loop the compass reverses. Swing the boom through that
	# change over time while keeping its up vector on the horizon.
	chase_heading = lerp_angle(chase_heading, world.heading, weight)
	var chase_basis := Basis.from_euler(Vector3(world.pitch * .65, chase_heading, 0))
	var next := target + chase_basis * boom * 32.0
	var ray := PhysicsRayQueryParameters3D.create(target, next, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		next = hit.position + hit.normal * .35
	chase.global_position = next
	if next.distance_squared_to(target) > .001:
		chase.look_at(target + Vector3.UP * 2.0 - chase_basis.z * 3.0, Vector3.UP)


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


func keep_upright(yaw_delta: float = 0.0) -> void:
	# Work at the character root, leaving head pitch and animated bone poses alone.
	var yaw := atan2(global_basis.z.x, global_basis.z.z) + yaw_delta
	global_basis = Basis(Vector3.UP, yaw)

func _share_pose(on_deck: bool, on_floor: bool) -> void:
	var pos := global_position
	var facing := global_basis
	if on_deck:
		pos = world.bomber.to_local(pos)
		facing = world.crew_frame(world.bomber.transform).inverse() * facing
	world.get_parent().sync_elf.rpc(pos, atan2(facing.z.x, facing.z.z), head.rotation.x, crouched, on_floor, on_deck)

func _send_flight_controls() -> void:
	if Game.menu_open:
		world.send_pilot_input(0, 0, 0)
	else:
		# Banking and moving the throttle lever are independent at the helm.
		world.send_pilot_input(Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_back", "move_forward"), Input.get_axis("descend", "jump"),
			Input.is_action_pressed("afterburner"))

func _physics_process(delta: float) -> void:
	var station: String = world.stations.station_for(peer_id)
	var seat: int = world.mess.seats.get(peer_id,-1)
	if seat >= 0:
		if last_lounge_seat != seat:
			rotation.y = -PI/2
			pitch = 0
			head.rotation.x = 0
		last_lounge_seat = seat
		global_position = world.mess.SEATS[seat]
		head.position.y = 1.14
		velocity = Vector3.ZERO
		if is_multiplayer_authority():
			world.get_parent().sync_elf.rpc(position,rotation.y,pitch,false,true)
		else:
			rotation.y = net_yaw
			head.rotation.x = net_pitch
		return
	if last_lounge_seat >= 0:
		# Step out beside the cushions, clear of the coffee table.
		position = world.mess.SEATS[last_lounge_seat] + Vector3(1.55,0,2.9 if last_lounge_seat > 0 else -2.9)
		net_pos = position
		last_lounge_seat = -1
	var on_deck: bool = world.aboard(global_position) or world.pilot_id == peer_id or station != ""
	var frame: Basis = world.crew_frame(world.bomber.transform) if on_deck else Basis.IDENTITY
	up_direction = frame.y
	var relative := frame.inverse() * global_basis
	var facing_yaw := atan2(relative.z.x, relative.z.z)
	if station != "turret":
		global_basis = frame * Basis(Vector3.UP, facing_yaw)
	head.position.y = lerpf(head.position.y, 1.0 if crouched else 1.6, 1.0 - exp(-camera_smoothing * delta))
	if not is_multiplayer_authority():
		capsule_node.shape.height = Crouch.DUCKED if crouched else Crouch.STANDING
		capsule_node.position.y = capsule_node.shape.height / 2.0
		# Turret transforms come from the replicated gimbal, not walking snapshots.
		if station != "turret":
			position = position.lerp(net_pos, 0.35)
			var course := atan2(world.bomber.basis.z.x, world.bomber.basis.z.z) if on_deck else 0.0
			global_basis = frame * Basis(Vector3.UP, lerp_angle(facing_yaw, net_yaw - course, .35))
		head.rotation.x = net_pitch
		return

	if world.stations.station_for(peer_id) != "":
		velocity = Vector3.ZERO
		_share_pose(on_deck, true)
		return
	var browsing: bool = world.mess.dialogue.choosing()
	Crouch.update(self, capsule_node, not Game.menu_open and not browsing and world.pilot_id != peer_id and Input.is_action_pressed("crouch"))
	if world.pilot_id == peer_id:
		velocity = Vector3.ZERO
		global_position = world.bomber.to_global(world.HELM_POS)
		global_basis = frame
		var burn: float = clampf(world.speed / world.AFTERBURNER_SPEED, 0, 1) if world.afterburner_active() else 0.0
		var weight := 1.0 - exp(-4.0 * delta)
		cam.fov = lerpf(cam.fov, minf(110.0, Game.values.fov + 2.5 * burn), weight)
		chase.fov = lerpf(chase.fov, minf(110.0, Game.values.fov + 5.0 * burn), weight)
		if chase.current:
			_update_chase(1.0 - exp(-7.0 * delta))
		_send_flight_controls()
	else:
		var vertical := velocity.dot(up_direction) - GRAVITY * delta
		if is_on_floor():
			vertical = JUMP_SPEED if (not Game.menu_open and not world.mess.presenting and not browsing and Input.is_action_just_pressed("jump")) else 0.0
		var input := Vector2.ZERO if Game.menu_open or world.mess.presenting or browsing else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var dir := global_transform.basis * Vector3(input.x, 0, input.y)
		velocity = dir * (crouch_speed if crouched else WALK_SPEED) + up_direction * vertical
		move_and_slide()

	# Safety net: if you somehow fall out of the ship, hop back in.
	if global_position.y < -20:
		global_position = world.Airfield.SPAWN
		velocity = Vector3.ZERO

	_share_pose(world.aboard(global_position), is_on_floor())
