extends Node3D
## The whole game world: night-time village, the bomber, presents, scoring and networking.
## The host (peer 1) is authoritative for flight, drops and score.

const PlayerScript := preload("res://player.gd")

const HELM_POS := Vector3(0, 0, -5.2)   # stand here to take the helm
const HATCH_POS := Vector3(0, 0, 3.0)   # stand here to drop presents
const GRAVITY := 9.8
const START_ALTITUDE := 45.0
const MIN_ALTITUDE := 20.0
const MAX_ALTITUDE := 90.0
const MIN_SPEED := 8.0
const MAX_SPEED := 30.0
const TURN_RATE := 0.45
const DROP_COOLDOWN_MS := 500
const NICE_POINTS := 10
const NAUGHTY_PENALTY := 5

var bomber: Node3D
var players := {}          # peer id -> player node
var pilot_id := 0          # 0 = helm is empty
var score := 0
var chimneys: Array = []   # {top: Vector3, nice: bool}
var presents: Array = []   # {node: Node3D, vel: Vector3}
var last_drop_ms := 0

# Flight state. The host simulates it; clients receive it via sync_bomber.
var heading := 0.0
var speed := 14.0
var in_steer := 0.0
var in_throttle := 0.0
var in_climb := 0.0

var hud_score: Label
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
	var house := Node3D.new()
	house.position = base
	add_child(house)
	_box(house, Vector3(8, 5, 7), Vector3(0, 2.5, 0), col)

	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(9, 2.5, 7.6)
	roof.mesh = prism
	roof.material_override = _mat(Color(0.35, 0.2, 0.2))
	roof.position = Vector3(0, 6.25, 0)
	house.add_child(roof)

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
#penis

func _build_bomber() -> void:
	bomber = Node3D.new()
	bomber.name = "Bomber"
	bomber.position = Vector3(0, START_ALTITUDE, 300)
	add_child(bomber)

	var red := Color(0.7, 0.1, 0.1)
	var wood := Color(0.45, 0.28, 0.15)
	var gold := Color(0.95, 0.8, 0.2)

	var hull := StaticBody3D.new()
	hull.name = "Hull"
	bomber.add_child(hull)
	_box(hull, Vector3(6, 0.4, 14), Vector3(0, -0.2, 0), wood, false, hull)       # floor
	_box(hull, Vector3(0.3, 2.5, 14), Vector3(-3, 1.25, 0), red, false, hull)     # left wall
	_box(hull, Vector3(0.3, 2.5, 14), Vector3(3, 1.25, 0), red, false, hull)      # right wall
	_box(hull, Vector3(6.3, 2.5, 0.3), Vector3(0, 1.25, 7), red, false, hull)     # back wall
	_box(hull, Vector3(6.3, 1.0, 0.3), Vector3(0, 0.5, -7), red, false, hull)     # low front rail
	_box(hull, Vector3(1.6, 1.0, 0.8), Vector3(0, 0.5, -6.3), wood, false, hull)  # helm console

	_box(bomber, Vector3(26, 0.25, 3.5), Vector3(0, -0.4, 1), gold)               # wings
	_box(bomber, Vector3(0.3, 3.0, 2.0), Vector3(0, 2.5, 7.8), gold)              # tail fin
	_box(bomber, Vector3(2, 0.05, 2), Vector3(0, 0.03, 3), Color(1, 0.85, 0.2), true)  # hatch plate

	_label3d(bomber, "HELM - press E", Vector3(0, 2.2, -5.8))
	_label3d(bomber, "PRESENT HATCH - click", Vector3(0, 2.0, 3.0))

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.2, 0)
	lamp.light_color = Color(1, 0.85, 0.6)
	lamp.omni_range = 14.0
	bomber.add_child(lamp)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
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
	pilot_id = id
	in_steer = 0.0
	in_throttle = 0.0
	in_climb = 0.0


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

func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		speed = clampf(speed + in_throttle * 8.0 * delta, MIN_SPEED, MAX_SPEED)
		heading -= in_steer * TURN_RATE * delta
		bomber.position += forward() * speed * delta
		bomber.position.y = clampf(bomber.position.y + in_climb * 8.0 * delta, MIN_ALTITUDE, MAX_ALTITUDE)
		bomber.rotation.y = heading
		sync_bomber.rpc(bomber.position, heading, speed)
	_step_presents(delta)


@rpc("authority", "unreliable_ordered")
func sync_bomber(pos: Vector3, h: float, s: float) -> void:
	bomber.position = pos
	bomber.rotation.y = h
	heading = h
	speed = s


# ---------------------------------------------------------------- presents

func request_drop() -> void:
	if multiplayer.is_server():
		_handle_drop(1)
	else:
		_drop_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _drop_rpc() -> void:
	if multiplayer.is_server():
		_handle_drop(multiplayer.get_remote_sender_id())


func _handle_drop(id: int) -> void:
	if not players.has(id) or id == pilot_id:
		return
	if players[id].position.distance_to(HATCH_POS) > 3.0:
		return
	var now := Time.get_ticks_msec()
	if now - last_drop_ms < DROP_COOLDOWN_MS:
		return
	last_drop_ms = now
	var gpos := bomber.to_global(HATCH_POS + Vector3(0, -1.2, 0))
	spawn_present.rpc(gpos, forward() * speed)


@rpc("authority", "call_local", "reliable")
func spawn_present(gpos: Vector3, vel: Vector3) -> void:
	var n := Node3D.new()
	_box(n, Vector3(0.5, 0.5, 0.5), Vector3.ZERO, Color(0.85, 0.1, 0.15))
	_box(n, Vector3(0.52, 0.1, 0.52), Vector3.ZERO, Color(0.95, 0.8, 0.2))
	_box(n, Vector3(0.1, 0.52, 0.52), Vector3.ZERO, Color(0.95, 0.8, 0.2))
	add_child(n)
	n.position = gpos
	presents.append({"node": n, "vel": vel})


func _step_presents(delta: float) -> void:
	for i in range(presents.size() - 1, -1, -1):
		var d: Dictionary = presents[i]
		var n: Node3D = d["node"]
		var v: Vector3 = d["vel"]
		var prev := n.position
		v.y -= GRAVITY * delta
		d["vel"] = v
		n.position += v * delta
		n.rotate_x(2.0 * delta)
		var done := false
		for c in chimneys:
			var top: Vector3 = c["top"]
			if prev.y >= top.y and n.position.y < top.y:
				if Vector2(n.position.x - top.x, n.position.z - top.z).length() < 0.5:
					if multiplayer.is_server():
						_award(c)
					done = true
					break
		if done or n.position.y < 0.0:
			n.queue_free()
			presents.remove_at(i)


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
	else:
		txt += "WASD walk, Space jump, E at the helm to fly, click on the gold hatch to drop a present\n"
		txt += "Helm: %s" % ("empty" if pilot_id == 0 else "an elf is flying")
	txt += "\nGreen chimney = nice, red chimney = naughty. Esc frees the mouse."
	hud_info.text = txt
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			hud_msg.text = ""
