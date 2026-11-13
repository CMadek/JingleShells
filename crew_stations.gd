extends Node3D
## Independent console and turret occupancy, cameras and input contexts.
const SEATS := {"delivery":Vector3(-1.65,.05,-.05),"turret":Vector3(1.9,.05,-4.25)}
const CONTROLS := {"delivery":Vector3(-2.55,1.15,-.05),"turret":Vector3(1.9,.78,-5.48)}
var world: Node3D
var occupants := {"delivery":0,"turret":0}
var yaw := 0.0
var pitch := -.45
var desired_yaw := 0.0
var desired_pitch := -.45
var selected := 0
var last_fire := -1000
var last_aim := 0
var aim_clock := 0.0
var turret_yaw: Node3D
var turret_pitch: Node3D
var muzzle: Node3D
var console_camera: Camera3D
var turret_camera: Camera3D
var ui: CanvasLayer
var text: Label
var reticle: Label
var circles: Array[Node3D] = []
var predictions: Array = [{},{}]
var active_local := ""
var projectiles: Node3D
var climb_time := 0.0
var climb_tween: Tween
var turret_free_look := false
var look_offset := Vector2.ZERO
var hatch: Node3D
var hatch_time := 0.0
const GUNNER_VIEW := Vector3(0,.22,-.14)
const SNOWBALL_SPEED := 42.0

func build(w: Node3D) -> void:
	world = w
	turret_yaw = world.instruments.get_node("VentralYaw_rig")
	turret_pitch = turret_yaw.get_node("VentralPitch_rig")
	muzzle = turret_pitch.get_node("SnowballMuzzle_rig")
	hatch = world.instruments.get_node("GunnerHatch_rig")
	console_camera = Camera3D.new()
	world.bomber.add_child(console_camera)
	console_camera.position = Vector3(0,-2.75,3.2)
	console_camera.rotation.x = deg_to_rad(-90)
	console_camera.fov = 72
	console_camera.far = 3000
	turret_camera = Camera3D.new()
	turret_yaw.add_child(turret_camera)
	turret_camera.position = GUNNER_VIEW
	turret_camera.far = 3000
	for key in ["delivery"]:
		world._hull_box(world.bomber.get_node("Hull"),Vector3(.65,1,1),Vector3(CONTROLS[key].x,.5,CONTROLS[key].z))
		if world.moving_hull: world._hull_box(world.moving_hull,Vector3(.65,1,1),Vector3(CONTROLS[key].x,.5,CONTROLS[key].z))
	ui = CanvasLayer.new()
	add_child(ui)
	text = Label.new()
	text.position = Vector2(22,270)
	text.add_theme_font_size_override("font_size",20)
	text.add_theme_constant_override("outline_size",8)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(text)
	reticle = Label.new()
	reticle.text = "+"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.add_theme_font_size_override("font_size",32)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(reticle)
	var overlay := preload("res://target_overlay.gd").new()
	overlay.stations = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	for rack in 2:
		var marker := Node3D.new()
		world.add_child(marker)
		for ring_index in (1 if rack == 0 else 2):
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = .8+ring_index*.4
			mesh.outer_radius = mesh.inner_radius+.18
			ring.mesh = mesh
			ring.material_override = world._mat(Color.CYAN if rack == 0 else Color.GOLD,true)
			marker.add_child(ring)
			ring.hide()
		var label := Label3D.new()
		label.text = "L • 1" if rack == 0 else "R • 2"
		label.font_size = 64
		label.pixel_size = .025
		label.position.y = 2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.add_child(label)
		label.hide()
		marker.hide()
		circles.append(marker)
	projectiles = preload("res://snowball_projectiles.gd").new()
	projectiles.name = "Snowballs"
	add_child(projectiles)
	projectiles.world = world

func station_for(id: int) -> String:
	for key in occupants:
		if occupants[key] == id and id != 0: return key
	return ""

func aimed(id: int) -> String:
	for key in CONTROLS:
		if world.queues.sees(id,CONTROLS[key],.6): return key
	return ""

func request(key: String) -> void:
	if multiplayer.is_server(): occupy(1,key)
	else: request_remote.rpc_id(1,key)

@rpc("any_peer","reliable")
func request_remote(key: String) -> void:
	if multiplayer.is_server(): occupy(multiplayer.get_remote_sender_id(),key)

func occupy(id: int, key: String) -> bool:
	if not world.players.has(id): return false
	var current := station_for(id)
	if key == "leave":
		if current == "": return false
		var updated := occupants.duplicate()
		updated[current] = 0
		occupancy.rpc(updated)
		return true
	elif not occupants.has(key) or occupants[key] or current != "" or world.pilot_id == id: return false
	elif world.players[id].held_kind != 0:
		world.access.notice.rpc_id(id,"Put down your cargo before operating a station")
		return false
	elif aimed(id) != key: return false
	else:
		world.charge_start.erase(id)
		world.players[id].charging_since = -1
	var updated := occupants.duplicate()
	updated[key] = id
	occupancy.rpc(updated)
	return true

@rpc("authority","call_local","reliable")
func occupancy(value: Dictionary) -> void:
	var old_turret: int = occupants.turret
	if old_turret != int(value.turret): hatch_time = 1.25
	if old_turret != 0 and old_turret != int(value.turret) and world.players.has(old_turret):
		var elf = world.players[old_turret]
		elf.global_position = world.bomber.to_global(SEATS.turret)
		elf.net_pos = elf.global_position
		elf.global_rotation = Vector3(0,world.heading+PI,0)
		elf.net_yaw = elf.rotation.y
		elf.pitch = 0
		elf.net_pitch = 0
		elf.head.rotation = Vector3.ZERO
		elf.velocity = Vector3.ZERO
	occupants = value.duplicate()
	refresh_camera()

func refresh_camera() -> void:
	var next := station_for(multiplayer.get_unique_id())
	if next == active_local: return
	if climb_tween: climb_tween.kill()
	climb_time = 0
	active_local = next
	var elf = world.players.get(multiplayer.get_unique_id())
	if not elf: return
	elf.dragging_orbit = false
	elf.charging_since = -1
	turret_free_look = false
	look_offset = Vector2.ZERO
	if next == "delivery": console_camera.make_current()
	elif next == "turret":
		desired_yaw = yaw
		desired_pitch = pitch
		climb_time = .95
		turret_camera.global_transform = elf.head.global_transform
		turret_camera.make_current()
		# Crouch through the cabin hatch, then descend beneath the sealed pilot deck.
		climb_tween = create_tween()
		for step in [{"point":Vector3(1.9,.75,-5.20),"time":.25},{"point":Vector3(1.75,.55,-6.55),"time":.30}]:
			var target: Vector3 = turret_yaw.to_local(world.bomber.to_global(step.point))
			climb_tween.tween_property(turret_camera,"position",target,step.time).set_trans(Tween.TRANS_SINE)
		climb_tween.tween_property(turret_camera,"position",GUNNER_VIEW,.40).set_trans(Tween.TRANS_SINE)
		climb_tween.parallel().tween_property(turret_camera,"rotation",Vector3.ZERO,.40).set_trans(Tween.TRANS_SINE)
	else: elf.cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Game.menu_open else Input.MOUSE_MODE_CAPTURED

func handle_input(event: InputEvent) -> void:
	if Game.menu_open or active_local == "": return
	if event is InputEventKey and event.pressed and not event.echo:
		if (active_local == "turret" and event.physical_keycode == KEY_CTRL) or (active_local == "delivery" and event.physical_keycode == KEY_Q): request("leave")
		elif active_local == "delivery":
			if event.physical_keycode == KEY_1: selected = 0
			elif event.physical_keycode == KEY_2: selected = 1
			elif event.physical_keycode == KEY_SPACE: world.queues.request("release",selected)
	if active_local == "turret" and climb_time <= 0:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			turret_free_look = event.pressed
			if not event.pressed: look_offset = Vector2.ZERO
		if event is InputEventMouseMotion and turret_free_look:
			look_offset.x = clampf(look_offset.x-event.relative.x*.0022,-1.5,1.5)
			look_offset.y = clampf(look_offset.y-event.relative.y*.0022,-.8,.8)
		elif event is InputEventMouseMotion:
			desired_yaw = wrapf(desired_yaw-event.relative.x*.0022*Game.values.sensitivity,-PI,PI)
			desired_pitch = clampf(desired_pitch-event.relative.y*.0022*Game.values.sensitivity*(-1 if Game.values.invert else 1),deg_to_rad(-80),deg_to_rad(20))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if multiplayer.is_server(): fire(1,desired_yaw,desired_pitch)
			else: fire_remote.rpc_id(1,desired_yaw,desired_pitch)

func apply_aim(id: int, y: float, p: float) -> bool:
	if id != occupants.turret or id == 0 or not is_finite(y) or not is_finite(p): return false
	yaw = wrapf(y,-PI,PI)
	pitch = clampf(p,deg_to_rad(-80),deg_to_rad(20))
	return true

@rpc("any_peer","unreliable_ordered")
func aim_remote(y: float, p: float) -> void:
	if multiplayer.is_server() and apply_aim(multiplayer.get_remote_sender_id(),y,p): orientation.rpc(yaw,pitch)

@rpc("authority","call_remote","unreliable_ordered")
func orientation(y: float, p: float) -> void:
	yaw = y
	pitch = p

@rpc("any_peer","reliable")
func fire_remote(y: float, p: float) -> void:
	if multiplayer.is_server(): fire(multiplayer.get_remote_sender_id(),y,p)

func fire(id: int, y: float, p: float) -> bool:
	if not apply_aim(id,y,p) or Time.get_ticks_msec()-last_fire < 200: return false
	var old_y := turret_yaw.rotation.y
	var old_p := turret_pitch.rotation.x
	turret_yaw.rotation.y = yaw
	turret_pitch.rotation.x = pitch
	var start: Vector3 = turret_pitch.global_position
	var end: Vector3 = muzzle.global_position
	var basis: Basis = muzzle.global_basis
	var shape := SphereShape3D.new()
	shape.radius = .12
	var hit: Dictionary = world.Trajectory.sweep(get_world_3d().direct_space_state,shape,Transform3D(basis,start),end-start,1|16)
	turret_yaw.rotation.y = old_y
	turret_pitch.rotation.x = old_p
	if not hit.is_empty(): return false
	# The fitted belly can sit just beyond the muzzle. Validate the first flight
	# step too, so a shot that would immediately strike the aircraft is refused.
	var clearance: float = maxf(.3,SNOWBALL_SPEED*world.physics_delta+shape.radius)
	if not world.Trajectory.sweep(get_world_3d().direct_space_state,shape,Transform3D(basis,end),-basis.z*clearance,1|16).is_empty(): return false
	last_fire = Time.get_ticks_msec()
	var local: Vector3 = world.bomber.to_local(end)
	var inherited: Vector3 = (end-world.previous_plane*local)/maxf(world.physics_delta,.001)
	projectiles.launch(end,-basis.z*SNOWBALL_SPEED+inherited)
	orientation.rpc(yaw,pitch)
	return true

func drop_peer(id: int) -> void:
	var updated := occupants.duplicate()
	for key in updated:
		if updated[key] == id: updated[key] = 0
	occupancy.rpc(updated)

func reset() -> void:
	occupancy.rpc({"delivery":0,"turret":0})
	yaw = 0
	pitch = -.45
	occupancy.rpc(occupants)
	orientation.rpc(yaw,pitch)
	projectiles.clear_all.rpc()

func snapshot(id: int) -> void:
	occupancy.rpc_id(id,occupants)
	orientation.rpc_id(id,yaw,pitch)

func _physics_process(delta: float) -> void:
	if not world: return
	refresh_camera()
	hatch_time = maxf(0,hatch_time-delta)
	hatch.rotation.y = move_toward(hatch.rotation.y,-1.4 if hatch_time > .25 else 0.0,delta*7.5)
	climb_time = maxf(0,climb_time-delta)
	var local_turret := active_local == "turret"
	if local_turret:
		turret_yaw.rotation.y = desired_yaw
		turret_pitch.rotation.x = desired_pitch
		if climb_time <= 0:
			turret_camera.position = GUNNER_VIEW
			turret_camera.rotation = Vector3(desired_pitch+look_offset.y,look_offset.x,0)
		aim_clock += delta
		if aim_clock >= .05 and not Game.menu_open:
			aim_clock = 0
			if multiplayer.is_server():
				apply_aim(1,desired_yaw,desired_pitch)
				orientation.rpc(yaw,pitch)
			else: aim_remote.rpc_id(1,desired_yaw,desired_pitch)
	else:
		turret_yaw.rotation.y = lerp_angle(turret_yaw.rotation.y,yaw,minf(1,delta*12))
		turret_pitch.rotation.x = lerpf(turret_pitch.rotation.x,pitch,minf(1,delta*12))
	for key in occupants:
		var id: int = occupants[key]
		if id and world.players.has(id):
			world.players[id].global_position = turret_pitch.get_node("GunnerSeat_rig").global_position if key == "turret" else world.bomber.to_global(SEATS[key])
			if key == "turret": world.players[id].global_basis = turret_pitch.global_basis
			world.players[id].net_pos = world.players[id].global_position
			world.players[id].velocity = Vector3.ZERO
	text.position.y = get_viewport().get_visible_rect().size.y-155
	ui.visible = active_local != "" and not Game.menu_open
	reticle.visible = active_local == "turret" and not turret_free_look
	text.text = "BELLY GUN • Mouse: aim all directions • Left click: fire • Hold RMB: look around • Ctrl: climb out\nShots into the aircraft or ground are blocked" if active_local == "turret" else "CARGO LAUNCHERS • 1: LEFT • 2: RIGHT • Space: release • Q: leave\nBoth launchers are operated here.\n"
	if active_local == "delivery":
		for rack in 2:
			var names: Array[String] = []
			for item in world.queues.queues[rack]: names.append("PRESENT" if item.kind == 1 else "BOMB")
			text.text += ("> " if rack == selected else "  ")+("L" if rack == 0 else "R")+" [%s] • %d free" % [" → ".join(names) if names.size() else "EMPTY",5-names.size()]
			text.text += " • NEXT: "+(names[0] if names.size() else "—")
			text.text += " • BUSY\n" if world.queues.remaining[rack] > 0 else "\n"
	# Refresh the selected impact every physics tick; the sight must not lag Space.
	for rack in 2:
		circles[rack].hide()
		predictions[rack] = {}
		if active_local != "delivery" or Game.menu_open or rack != selected or world.queues.queues[rack].is_empty(): continue
		var kind: int = world.queues.queues[rack][0].kind
		var state: Dictionary = world.queues.prediction_state(rack,kind)
		var hit := predict(state,kind)
		predictions[rack] = hit
		if not hit.is_empty():
			circles[rack].global_position = hit.point+hit.normal*.12
			circles[rack].show()

	if active_local == "delivery":
		var aim_point: Vector3 = world.bomber.to_global(Vector3(0,-35,-35))
		if not predictions[selected].is_empty(): aim_point = predictions[selected].point
		if console_camera.global_position.distance_to(aim_point) > .1: console_camera.look_at(aim_point,-world.bomber.global_basis.z)

func predict(state: Dictionary, kind: int) -> Dictionary:
	if state.is_empty(): return {}
	var pose: Transform3D = state.pose
	var velocity: Vector3 = state.velocity
	var path := PackedVector3Array([pose.origin])
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))
	var step := 1.0/Engine.physics_ticks_per_second
	var excluded: Array[RID] = state.get("excluded",[])
	for i in ceili(24/step):
		velocity += Vector3.DOWN*gravity*step
		var motion := velocity*step
		var hit: Dictionary = world.Trajectory.sweep(get_world_3d().direct_space_state,world.Cargo.shape(kind),pose,motion,1|16,excluded)
		if not hit.is_empty():
			path.append(hit.point)
			hit["path"] = path
			return hit
		pose.origin += motion
		path.append(pose.origin)
	return {}

func _exit_tree() -> void:
	for marker in circles:
		if is_instance_valid(marker): marker.queue_free()
