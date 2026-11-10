extends Node3D
## The whole game world: night-time village, the bomber, presents, scoring and networking.
## The host (peer 1) is authoritative for flight, drops and score.

const Cargo := preload("res://cargo.gd")
const PlayerScript := preload("res://player.gd")
const Instruments := preload("res://assets/aircraft/instruments.gd")

const HELM_POS := Vector3(0, 0, -5.2)   # stand here to take the helm
const HATCH_POS := Vector3(0, 0, 3.0)   # center of the deck opening
const GRAVITY := 9.8
const START_ALTITUDE := 45.0
const MIN_SPEED := 8.0
const TURN_RATE := 0.45
const NICE_POINTS := 10
const NAUGHTY_PENALTY := 5
const MIN_ALTITUDE := 20.0
const MAX_ALTITUDE := 1800.0

# Flight model
const STALL_SPEED := 9.0            # below this, no lift
const CRUISE_SPEED := 14.0          # full lift at or above this
const MAX_SPEED := 45.0             # hard cap (dive)
const MIN_THROTTLE := 0.2           # idle; level cruise is ~14 m/s
const THROTTLE_RATE := 0.5          # throttle lever change per second
const MAX_THRUST := 12.0            # accel at full throttle
const DRAG := 0.012                 # accel lost = DRAG * speed^2
const PITCH_GRAVITY := 6.0          # speed lost per sin(pitch)
const MAX_PITCH := deg_to_rad(35.0)
const PITCH_RATE := deg_to_rad(35.0)
const LEVEL_RATE := deg_to_rad(0.2)  # nose drifts back to level with no input
const MAX_ROLL := deg_to_rad(45.0)
const ROLL_RATE := deg_to_rad(15.0)
const TURN_FACTOR := 0.6            # scales the coordinated-turn rate
const STALL_NOSE_DROP := deg_to_rad(40.0)
const STALL_SINK := 12.0





var bomber: Node3D
var instruments: Instruments
var players := {}          # peer id -> player node
var pilot_id := 0          # 0 = helm is empty
var score := 0
var chimneys: Array = []   # {top: Vector3, nice: bool}
const PILES := {Cargo.Kind.PRESENT: Vector3(-2, 0.55, 0), Cargo.Kind.BOMB: Vector3(2, 0.55, 0)}
@export_range(1, 6) var pickup_range := 2.8
@export_range(0.1, 4) var charge_seconds := 1.2
@export var min_throw_speed := 2.5
@export var max_throw_speed := 13.0
@export_range(0, 1) var cargo_friction := 0.55
@export var cargo_lifetime := 90.0
@export var max_loose_items := 48

var loose := {} # ID -> host rigid body or client visual
var next_item := 1
var charge_start := {}
var moving_hull: AnimatableBody3D
var previous_plane: Transform3D
var physics_delta := 1.0 / 60.0

# Flight state. The host simulates it; clients receive it via sync_bomber.
var heading := 0.0      # yaw
var pitch := 0.0        # nose up = positive
var roll := 0.0         # right wing down = positive
var speed := 14.0
var throttle := MIN_THROTTLE
var in_steer := 0.0
var in_throttle := 0.0
var in_climb := 0.0
var hud_score: Label
var view_button: Button
var hud_info: Label
var hud_msg: Label
var msg_timer := 0.0

var _mats := {}
var _beam_nice: StandardMaterial3D
var _beam_bad: StandardMaterial3D


func _ready() -> void:
	_build_environment()
	_build_village()
	_build_bomber()
	_build_hud()
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		add_player(1)
	else:
		request_players.rpc_id(1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- building

func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	_mats[key] = m
	return m


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, glow := false, body: StaticBody3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, glow)
	mi.position = pos
	parent.add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)
	return mi


func _label3d(parent: Node, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.006
	l.outline_size = 12
	parent.add_child(l)


func _build_environment() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.04, 0.15)
	sm.sky_horizon_color = Color(0.2, 0.25, 0.45)
	sm.ground_horizon_color = Color(0.2, 0.25, 0.45)
	sm.ground_bottom_color = Color(0.1, 0.12, 0.2)
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.25, 0.45)
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 30, 0)
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 150.0
	add_child(moon)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	ground.material_override = _mat(Color(0.9, 0.93, 1.0))
	add_child(ground)
	var terrain := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	terrain.add_child(floor_shape)
	add_child(terrain)


func _build_village() -> void:
	_beam_nice = _make_beam_mat(Color(0.2, 1.0, 0.4, 0.25))
	_beam_bad = _make_beam_mat(Color(1.0, 0.2, 0.2, 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # same seed on every peer = same village
	var walls := [Color(0.8, 0.7, 0.55), Color(0.65, 0.45, 0.4), Color(0.55, 0.65, 0.7), Color(0.85, 0.8, 0.7)]
	for gx in range(-6, 7):
		for gz in range(-10, 11):
			if rng.randf() < 0.2:
				continue
			var base := Vector3(gx * 24 + rng.randf_range(-4, 4), 0, gz * 24 + rng.randf_range(-4, 4))
			var nice := rng.randf() < 0.7
			var col: Color = walls[rng.randi() % walls.size()]
			_make_house(base, col, nice)


func _make_beam_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _make_house(base: Vector3, col: Color, nice: bool) -> void:
	var house := StaticBody3D.new()
	house.position = base
	add_child(house)
	_box(house, Vector3(8, 5, 7), Vector3(0, 2.5, 0), col, false, house)

	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(9, 2.5, 7.6)
	roof.mesh = prism
	roof.material_override = _mat(Color(0.35, 0.2, 0.2))
	roof.position = Vector3(0, 6.25, 0)
	house.add_child(roof)
	roof.create_convex_collision()

	_box(house, Vector3(1.2, 3.5, 1.2), Vector3(2.2, 5.75, 1.0), Color(0.45, 0.2, 0.15))
	if nice:
		_box(house, Vector3(1.5, 1.5, 0.1), Vector3(-1.5, 2.5, 3.55), Color(1.0, 0.85, 0.4), true)

	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 8.0
	beam.mesh = cyl
	beam.material_override = _beam_nice if nice else _beam_bad
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(2.2, 11.5, 1.0)
	house.add_child(beam)

	chimneys.append({"top": base + Vector3(2.2, 7.5, 1.0), "nice": nice})

func _hull_box(hull: StaticBody3D, size: Vector3, center: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	hull.add_child(collision)


func _build_bomber() -> void:
	bomber = Node3D.new()
	bomber.name = "Bomber"
	bomber.position = Vector3(0, START_ALTITUDE, 300)
	add_child(bomber)

	var airframe := preload("res://assets/aircraft/north_star.glb").instantiate()
	airframe.set_script(Instruments)
	instruments = airframe as Instruments
	bomber.add_child(airframe)
	instruments.update_readings(self, 0.0)
	var station := preload("res://assets/aircraft/dorsal_station.tscn").instantiate() as Node3D
	bomber.add_child(station)
	station.position = Vector3(0, 3.18, -2.8)
	var hull := StaticBody3D.new()
	hull.name = "Hull"
	bomber.add_child(hull)
	# Deck plates end at the lip so released cargo can clear the belly.
	_hull_box(hull, Vector3(6,.4,9), Vector3(0,-.2,-2.5))
	_hull_box(hull, Vector3(6,.4,3), Vector3(0,-.2,5.5))
	for side in [-1, 1]:
		_hull_box(hull, Vector3(2,.4,2), Vector3(side*2,-.2,3))
		_hull_box(hull, Vector3(.14,3.1,14), Vector3(side*3,1.15,0))
		_hull_box(hull, Vector3(1.9,.18,2.6), Vector3(side*2.20,3.03,-2.8))
	_hull_box(hull, Vector3(6,3.2,.15), Vector3(0,1.50,7))
	_hull_box(hull, Vector3(6,3.2,.15), Vector3(0,1.50,-7))
	_hull_box(hull, Vector3(6,.18,2.9), Vector3(0,3.08,-5.55))
	_hull_box(hull, Vector3(6,.18,8.5), Vector3(0,3.08,2.75))
	_hull_box(hull, Vector3(2.29,.15,2.55), Vector3(0,2.10,-2.8))
	for i in range(12):
		var angle := TAU * i / 12.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		_hull_box(hull, Vector3(.65,1.92,.09), Vector3(0,3.19,-2.8) + radial * 1.18)
		(hull.get_child(-1) as CollisionShape3D).rotation.y = angle
	_hull_box(hull, Vector3(2.49,1.1,.83), Vector3(0,.55,-6.98))
	# The signed boards and coaming mark the helm and delivery hatch.
	for kind in PILES:
		var center: Vector3 = PILES[kind]
		var display := Cargo.pile(kind)
		bomber.add_child(display)
		display.position = Vector3(center.x, 0, center.z)
		# Face the decorated front toward the center aisle.
		display.rotation.y = signf(-center.x) * PI / 2.0
		_label3d(bomber, "PRESENTS" if kind == Cargo.Kind.PRESENT else "BOMBS", center + Vector3.UP)
	# Elves ride by parenting. Cargo needs a moving surface with physics velocity.
	hull.collision_layer = 16
	if multiplayer.is_server():
		moving_hull = AnimatableBody3D.new()
		moving_hull.collision_layer = 8
		moving_hull.collision_mask = 4
		moving_hull.transform = bomber.transform
		for child in hull.get_children():
			if child is CollisionShape3D:
				moving_hull.add_child(child.duplicate())
		add_child(moving_hull)
	previous_plane = bomber.transform

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.2, 0)
	lamp.light_color = Color(1, 0.85, 0.6)
	lamp.omni_range = 14.0
	bomber.add_child(lamp)
	var chart_light := OmniLight3D.new()
	chart_light.position = Vector3(0, 2.2, -5.55)
	chart_light.light_color = Color(1.0, .81, .55)
	chart_light.light_energy = 1.4
	chart_light.omni_range = 4.0
	bomber.add_child(chart_light)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	view_button = Button.new()
	view_button.text = "Chase view [V]"
	view_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	view_button.offset_left = -178
	view_button.offset_top = -56
	view_button.offset_right = -20
	view_button.offset_bottom = -18
	view_button.visible = false
	view_button.focus_mode = Control.FOCUS_NONE
	layer.add_child(view_button)
	view_button.pressed.connect(toggle_pilot_view)
	hud_score = _hud_label(layer, Vector2(20, 14), 30)
	hud_info = _hud_label(layer, Vector2(20, 58), 18)
	hud_msg = _hud_label(layer, Vector2(20, 150), 30)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.8)
	dot.custom_minimum_size = Vector2(4, 4)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(dot)


func _hud_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- players

@rpc("any_peer", "reliable")
func request_players() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	for pid in players.keys():
		add_player.rpc_id(id, pid)
	add_player.rpc(id)
	sync_score.rpc_id(id, score, "")
	set_pilot.rpc_id(id, pilot_id)
	for pid in players:
		if players[pid].held_kind != Cargo.Kind.EMPTY:
			set_held.rpc_id(id, pid, players[pid].held_kind)
	for item_id in loose:
		var body: Node3D = loose[item_id]
		show_loose.rpc_id(id, item_id, body.get_meta("kind"), body.transform)


@rpc("authority", "call_local", "reliable")
func add_player(id: int) -> void:
	if players.has(id):
		return
	var p: CharacterBody3D = PlayerScript.new()
	p.name = str(id)
	p.peer_id = id
	p.world = self
	p.set_multiplayer_authority(id)
	p.position = Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.0, 2.0))
	bomber.add_child(p)
	players[id] = p


@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)


func _on_peer_disconnected(id: int) -> void:
	charge_start.erase(id)
	if pilot_id == id:
		set_pilot.rpc(0)
	remove_player.rpc(id)


# ---------------------------------------------------------------- helm

func request_helm() -> void:
	if multiplayer.is_server():
		_handle_helm(1)
	else:
		_helm_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _helm_rpc() -> void:
	if multiplayer.is_server():
		_handle_helm(multiplayer.get_remote_sender_id())


func _handle_helm(id: int) -> void:
	if pilot_id == 0 and players.has(id) and players[id].position.distance_to(HELM_POS) < 3.5:
		set_pilot.rpc(id)
	elif pilot_id == id:
		set_pilot.rpc(0)


@rpc("authority", "call_local", "reliable")
func set_pilot(id: int) -> void:
	if id in players:
		players[id].charging_since = -1
		charge_start.erase(id)
	pilot_id = id
	var me := multiplayer.get_unique_id()
	var elf = players.get(me)
	if elf:
		elf.set_local_pilot(id == me)
	view_button.visible = id == me
	view_button.text = "Chase view [V]"
	in_steer = 0.0
	in_throttle = 0.0
	in_climb = 0.0


func toggle_pilot_view() -> void:
	var me := multiplayer.get_unique_id()
	if pilot_id == me and players.has(me):
		var outside: bool = players[me].toggle_view()
		view_button.text = "Cockpit view [V]" if outside else "Chase view [V]"


func send_pilot_input(steer: float, throttle: float, climb: float) -> void:
	if multiplayer.is_server():
		_apply_input(1, steer, throttle, climb)
	else:
		_input_rpc.rpc_id(1, steer, throttle, climb)


@rpc("any_peer", "unreliable_ordered")
func _input_rpc(steer: float, throttle: float, climb: float) -> void:
	if multiplayer.is_server():
		_apply_input(multiplayer.get_remote_sender_id(), steer, throttle, climb)


func _apply_input(id: int, steer: float, throttle: float, climb: float) -> void:
	if id != pilot_id:
		return
	in_steer = clampf(steer, -1.0, 1.0)
	in_throttle = clampf(throttle, -1.0, 1.0)
	in_climb = clampf(climb, -1.0, 1.0)


# ---------------------------------------------------------------- flight

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		previous_plane = bomber.transform
		physics_delta = delta
		_fly(delta)
		moving_hull.transform = bomber.transform
		var vertical_speed := (bomber.position.y - previous_plane.origin.y) / delta
		instruments.update_readings(self, vertical_speed)
		sync_bomber.rpc(bomber.position, heading, pitch, roll, speed, throttle, vertical_speed)
		_step_cargo(delta)

func _fly(delta: float) -> void:
	# Throttle is a lever: it stays where you leave it.
	throttle = clampf(throttle + in_throttle * THROTTLE_RATE * delta, MIN_THROTTLE, 1.0)

	# 0 = stalled, 1 = full lift. Control authority also scales with airspeed.
	var lift := clampf((speed - STALL_SPEED) / (CRUISE_SPEED - STALL_SPEED), 0.0, 1.0)
	var authority := clampf(speed / CRUISE_SPEED, 0.3, 1.3)

	# Roll: stick commands a bank angle, which self-levels when released.
	roll = move_toward(roll, in_steer * MAX_ROLL, ROLL_RATE * authority * delta)

	# Pitch: stick commands a rate. With no input the nose eases back to level
	# (this is also the "autopilot" when nobody is at the helm).
	if absf(in_climb) > 0.01:
		pitch += in_climb * PITCH_RATE * authority * maxf(lift, 0.3) * delta
	else:
		pitch = move_toward(pitch, 0.0, LEVEL_RATE * delta)
	pitch -= (1.0 - lift) * STALL_NOSE_DROP * delta   # stalled: nose drops
	pitch = clampf(pitch, -MAX_PITCH, MAX_PITCH)

	# Coordinated turn: yaw rate = g * tan(bank) / speed. Faster = wider turns.
	# Positive roll is a right turn, which means heading decreases.
	heading -= GRAVITY * tan(roll) / maxf(speed, 1.0) * TURN_FACTOR * delta

	# Energy: thrust vs drag, and climbing trades speed for height.
	var accel := MAX_THRUST * throttle - DRAG * speed * speed - PITCH_GRAVITY * sin(pitch)
	speed = clampf(speed + accel * delta, 4.0, MAX_SPEED)

	# Velocity follows the nose, minus sink from stalling and from banking.
	var cp := cos(pitch)
	var vel := Vector3(-sin(heading) * cp, sin(pitch), -cos(heading) * cp) * speed
	vel.y -= (1.0 - lift) * STALL_SINK
	vel.y -= (1.0 - cos(roll)) * 4.0   # lift lost to bank
	bomber.position += vel * delta

	# Altitude limits: ground/ceiling push the nose back toward level.
	if bomber.position.y < MIN_ALTITUDE:
		bomber.position.y = MIN_ALTITUDE
		pitch = maxf(pitch, 0.0)
	elif bomber.position.y > MAX_ALTITUDE:
		bomber.position.y = MAX_ALTITUDE
		pitch = minf(pitch, 0.0)

	_apply_attitude()
	
	
func _apply_attitude() -> void:
	# Godot's YXZ euler order = yaw, then pitch, then roll. Right wing down = -z.
	bomber.rotation = Vector3(pitch, heading, -roll)


@rpc("authority", "unreliable_ordered")
func sync_bomber(pos: Vector3, h: float, p: float, r: float, s: float, power: float, vertical_speed: float) -> void:
	bomber.position = pos
	heading = h
	pitch = p
	roll = r
	speed = s
	throttle = power
	instruments.update_readings(self, vertical_speed)
	_apply_attitude()


func aimed_pile(view: Transform3D) -> int:
	for kind in PILES:
		var offset: Vector3 = bomber.to_global(PILES[kind]) - view.origin
		var along := offset.dot(-view.basis.z)
		if along > 0 and offset.length() <= pickup_range and (offset + view.basis.z * along).length() <= 0.62:
			return kind
	return Cargo.Kind.EMPTY


func aimed_loose(view: Transform3D) -> int:
	var target := 0
	var nearest := pickup_range
	for item_id in loose:
		var offset: Vector3 = loose[item_id].global_position - view.origin
		var along := offset.dot(-view.basis.z)
		if along <= 0 or offset.length() > pickup_range or along >= nearest:
			continue
		if (offset + view.basis.z * along).length() > Cargo.HALF_SIZE + 0.08:
			continue
		var ray := PhysicsRayQueryParameters3D.create(view.origin, view.origin + offset, 1 | 16)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			target = item_id
			nearest = along
	return target


func cargo_action(action: String, item_id := 0) -> void:
	var id := multiplayer.get_unique_id()
	if not players.has(id):
		return
	var elf = players[id]
	if multiplayer.is_server():
		_handle_cargo(id, action, elf.rotation.y, elf.pitch, item_id)
	else:
		_cargo_rpc.rpc_id(1, action, elf.rotation.y, elf.pitch, item_id)


@rpc("any_peer", "unreliable_ordered")
func _cargo_rpc(action: String, yaw: float, look_pitch: float, item_id: int) -> void:
	if multiplayer.is_server():
		_handle_cargo(multiplayer.get_remote_sender_id(), action, yaw, look_pitch, item_id)


func _handle_cargo(id: int, action: String, yaw: float, look_pitch: float, item_id: int) -> void:
	if id == pilot_id or not players.has(id) or not is_finite(yaw) or not is_finite(look_pitch):
		return
	var elf = players[id]
	var feet: Vector3 = elf.position if id == 1 else elf.net_pos
	var aim := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, clampf(look_pitch, -1.5, 1.5))
	var view := Transform3D(bomber.basis * aim, bomber.to_global(feet + Vector3.UP * 1.6))
	if action == "pickup" and elf.held_kind == Cargo.Kind.EMPTY:
		if item_id != 0:
			if loose.has(item_id) and aimed_loose(view) == item_id:
				var loose_kind: int = loose[item_id].get_meta("kind")
				remove_loose.rpc(item_id)
				set_held.rpc(id, loose_kind)
			return
		var kind := aimed_pile(view)
		if kind != Cargo.Kind.EMPTY:
			set_held.rpc(id, kind)
		return
	if elf.held_kind == Cargo.Kind.EMPTY:
		return
	match action:
		"charge":
			if not charge_start.has(id):
				charge_start[id] = Time.get_ticks_msec()
		"cancel":
			charge_start.erase(id)
		"drop", "throw":
			var impulse := 0.0
			if action == "throw":
				if not charge_start.has(id):
					return
				var seconds := (Time.get_ticks_msec() - int(charge_start[id])) / 1000.0
				impulse = lerpf(min_throw_speed, max_throw_speed, clampf(seconds / charge_seconds, 0, 1))
			charge_start.erase(id)
			_release(id, elf.held_kind, view, impulse)


@rpc("authority", "call_local", "reliable")
func set_held(id: int, kind: int) -> void:
	if players.has(id):
		players[id].carry(kind)


func _release(id: int, kind: int, view: Transform3D, impulse: float) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = Cargo.shape(kind)
	query.transform = view
	query.collision_mask = 1 | 4 | 16
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return
	query.motion = view.basis * Vector3(0.20, -0.18, -0.95)
	var fraction := space.cast_motion(query)[0]
	var pos := view.origin + query.motion * maxf(0, fraction - 0.025)
	# Difference the release point across plane poses to include rotation and altitude limits.
	var local_pos := bomber.to_local(pos)
	var inherited := (pos - previous_plane * local_pos) / physics_delta
	if loose.size() >= max_loose_items and not loose.is_empty():
		remove_loose.rpc(loose.keys()[0])
	var item_id := next_item
	next_item += 1
	set_held.rpc(id, Cargo.Kind.EMPTY)
	show_loose.rpc(item_id, kind, Transform3D(view.basis, pos))
	var body: RigidBody3D = loose[item_id]
	body.linear_velocity = inherited - view.basis.z * impulse


@rpc("authority", "call_local", "reliable")
func show_loose(item_id: int, kind: int, pose: Transform3D) -> void:
	if loose.has(item_id):
		return
	var node := Cargo.model(kind)
	if multiplayer.is_server():
		var body := RigidBody3D.new()
		body.collision_layer = 4
		body.collision_mask = 1 | 4 | 8
		body.continuous_cd = true
		body.can_sleep = false
		body.contact_monitor = true
		body.max_contacts_reported = 8
		body.body_entered.connect(func(other: Node3D):
			if other is PhysicsBody3D and (other.collision_layer & 1) != 0:
				body.set_meta("landed", true)
		)
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp = 0
		body.physics_material_override = PhysicsMaterial.new()
		body.physics_material_override.friction = cargo_friction
		var collider := CollisionShape3D.new()
		collider.shape = Cargo.shape(kind)
		body.add_child(collider)
		body.add_child(node)
		node = body
		node.set_meta("previous", pose.origin)
		node.set_meta("age", 0.0)
	node.set_meta("kind", kind)
	node.transform = pose
	add_child(node)
	loose[item_id] = node


func _step_cargo(delta: float) -> void:
	var snapshot := {}
	for item_id in loose.keys():
		var body: Node3D = loose[item_id]
		var prev: Vector3 = body.get_meta("previous")
		var pos := body.position
		var age := float(body.get_meta("age")) + delta
		var delivered := false
		if body.get_meta("kind") == Cargo.Kind.PRESENT and prev.y >= 7.5 and pos.y < 7.5:
			var crossing := prev.lerp(pos, (prev.y - 7.5) / (prev.y - pos.y))
			for chimney in chimneys:
				if crossing.distance_to(chimney.top) < 0.5:
					_award(chimney)
					delivered = true
					break
		if not delivered and body.has_meta("landed"):
			landing_burst.rpc(pos, body.get_meta("kind"))
			remove_loose.rpc(item_id)
			continue
		if delivered or age >= cargo_lifetime or pos.y < -5 or pos.distance_to(bomber.position) > 3000:
			remove_loose.rpc(item_id)
			continue
		body.set_meta("age", age)
		body.set_meta("previous", pos)
		if Engine.get_physics_frames() % 3 == 0:
			snapshot[item_id] = body.transform
	if not snapshot.is_empty():
		sync_loose.rpc(snapshot, bomber.transform)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func sync_loose(snapshot: Dictionary, plane_pose: Transform3D) -> void:
	var inverse_plane := plane_pose.affine_inverse()
	for id in snapshot:
		if not loose.has(id):
			continue
		var visual: Node3D = loose[id]
		var pose: Transform3D = snapshot[id]
		var cabin_pose := inverse_plane * pose
		# Keep deck cargo aligned with the faster flight updates between snapshots.
		var in_cabin := AABB(Vector3(-3.5, -0.6, -7.5), Vector3(7, 4, 15)).has_point(cabin_pose.origin)
		var parent: Node3D = bomber if in_cabin else self
		if visual.get_parent() != parent:
			visual.reparent(parent, false)
		visual.transform = cabin_pose if in_cabin else pose


@rpc("authority", "call_local", "reliable")
func landing_burst(pos: Vector3, kind: int) -> void:
	var burst := Node3D.new()
	add_child(burst)
	burst.position = pos
	var bomb := kind == Cargo.Kind.BOMB
	var colors := [Color.ORANGE_RED, Color.GOLD, Color.ORANGE] if bomb else [Color.CRIMSON, Color.GOLD, Color.SEA_GREEN]
	var tween := burst.create_tween().set_parallel(true)
	for i in 16:
		var t := float(i) / 15.0
		var angle := i * 2.4
		var direction := Vector3(cos(angle) * sqrt(1-t*t), t, sin(angle) * sqrt(1-t*t))
		var bit := MeshInstance3D.new()
		if bomb:
			var puff := SphereMesh.new()
			puff.radial_segments = 8
			puff.rings = 4
			bit.mesh = puff
		else:
			var scrap := BoxMesh.new()
			scrap.size = Vector3(0.32, 0.12, 0.5)
			bit.mesh = scrap
		bit.material_override = _mat(colors[i % colors.size()], true)
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.add_child(bit)
		bit.rotation = direction * i
		tween.tween_property(bit, "position", direction * (2.8 if bomb else 1.9), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "scale", Vector3.ONE * 0.01, 0.4).set_delay(0.15)
	tween.chain().tween_callback(burst.queue_free)


@rpc("authority", "call_local", "reliable")
func remove_loose(item_id: int) -> void:
	if loose.has(item_id):
		loose[item_id].queue_free()
		loose.erase(item_id)


func _award(chimney: Dictionary) -> void:
	if chimney["nice"]:
		score += NICE_POINTS
		sync_score.rpc(score, "Delivered! +%d" % NICE_POINTS)
	else:
		score -= NAUGHTY_PENALTY
		sync_score.rpc(score, "Naughty house! -%d" % NAUGHTY_PENALTY)


@rpc("authority", "call_local", "reliable")
func sync_score(s: int, msg: String) -> void:
	score = s
	hud_msg.text = msg
	msg_timer = 2.0


# ---------------------------------------------------------------- HUD

func _process(delta: float) -> void:
	hud_score.text = "Score: %d" % score
	var me := multiplayer.get_unique_id()
	var txt := "Speed %d   Altitude %d\n" % [speed, bomber.position.y]
	if pilot_id == me:
		txt += "PILOTING: W/S speed, A/D turn, Space/Shift climb/dive, E to leave the helm"
		if players.has(me) and players[me].chase.current:
			txt += "   Hold RMB and drag to orbit"
	else:
		var elf = players.get(me)
		if elf and elf.at_ladder():
			txt += "E to use gunner ladder"
		elif elf and elf.held_kind != Cargo.Kind.EMPTY:
			txt += "Hold left click to throw   G to drop"
			if elf.charging_since >= 0:
				var elapsed := (Time.get_ticks_msec() - int(elf.charging_since)) / 1000.0
				txt += "   Charge: %d%%" % roundi(100 * clampf(elapsed / charge_seconds, 0, 1))
		elif elf and aimed_loose(elf.head.global_transform) != 0:
			txt += "E to pick up dropped cargo"
		elif elf and aimed_pile(elf.head.global_transform) != Cargo.Kind.EMPTY:
			txt += "E to pick up " + ("a present" if aimed_pile(elf.head.global_transform) == Cargo.Kind.PRESENT else "a bomb")
		else:
			txt += "WASD walk, Space jump, E at the helm to fly"
	txt += "\nGreen chimney = nice, red chimney = naughty. Esc frees the mouse."
	hud_info.text = txt
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			hud_msg.text = ""
