extends Node
## The host keeps the manifest and only pays the crew after a successful return.
const ADDRESSES := ["Boathouse", "Netmaker's Cottage", "Clockmaker", "Bell Street Bakery", "Mill Office", "Night Shift Bunkhouse"]
const Cargo := preload("res://cargo.gd")
const CHILDREN := ["Elsie", "Pip", "Ada", "Milo", "Nell", "Otto"]
const ORDERS := [Cargo.Kind.PRESENT, Cargo.Kind.BOMB, Cargo.Kind.PRESENT, Cargo.Kind.PRESENT, Cargo.Kind.BOMB, Cargo.Kind.PRESENT]
const REQUIRED := [1, 1, 2, 2, 3, 3]
const WINDOW := 18 * 60
var world: Node3D
var active := false
var seconds := float(WINDOW)
var delivered := PackedInt32Array([0,0,0,0,0,0])
var pending := 0
var receipt := ""
var last_second := WINDOW
var snowfall := MultiMeshInstance3D.new()
var snow_material := ShaderMaterial.new()
const FLAKES := 8400
const FIELD_RADIUS := 55.0

func _ready() -> void:
	var flakes := MultiMesh.new()
	flakes.transform_format = MultiMesh.TRANSFORM_3D
	flakes.use_custom_data = true
	var mesh := QuadMesh.new()
	snow_material.shader = preload("res://assets/materials/valley_snow.gdshader")
	var cabin: AABB = world.CABIN_BOUNDS.grow(.25)
	snow_material.set_shader_parameter("cabin_min",cabin.position)
	snow_material.set_shader_parameter("cabin_max",cabin.end)
	mesh.material = snow_material
	flakes.mesh = mesh
	flakes.instance_count = FLAKES
	var rng := RandomNumberGenerator.new()
	rng.seed = 1946
	for i in flakes.instance_count:
		flakes.set_instance_transform(i, Transform3D.IDENTITY)
		flakes.set_instance_custom_data(i, Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
	snowfall.multimesh = flakes
	snowfall.custom_aabb = AABB(Vector3.ONE*-FIELD_RADIUS,Vector3.ONE*2*FIELD_RADIUS)
	snowfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snowfall)
	process_priority = 10 # Follow the active pilot, crew or station camera after it moves.

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not world.bomber: return
	snowfall.global_position = camera.global_position
	snow_material.set_shader_parameter("world_to_plane",world.bomber.global_transform.affine_inverse())
	var velocity := Vector3.ZERO
	if camera.global_position.distance_squared_to(world.bomber.global_position) < 60.0*60.0:
		velocity = -world.bomber.global_basis.z * world.speed
	snow_material.set_shader_parameter("viewer_velocity",velocity)

func completed() -> int:
	var count := 0
	for i in REQUIRED.size():
		if delivered[i] == REQUIRED[i]: count += 1
	return count

func weather() -> String:
	if seconds <= 180: return "Runway closing"
	if seconds <= 480: return "Heavy snow"
	if seconds <= 780: return "Driving snow"
	return "Steady snowfall"

func tick(delta: float) -> void:
	if not active:
		if world.grounded: return
		active = true
		pending = 0
		delivered.fill(0)
		seconds = WINDOW
		last_second = WINDOW
		receipt = ""
		publish()
	seconds = maxf(0, seconds - delta)
	var p: Vector3 = world.bomber.position
	var home: bool = absf(p.x) <= world.Airfield.WIDTH * .5 and p.z >= -300 and p.z <= 900
	for i in REQUIRED.size():
		if world.recipients.houses[world.district.stops[i]].destroyed and delivered[i] < REQUIRED[i]:
			finish(false, "Delivery address lost")
			return
	if seconds <= 0:
		finish(false, "Weather closure")
	elif world.grounded and home and world.speed < 2:
		finish(completed() == REQUIRED.size(), "Manifest incomplete")
	elif ceili(seconds) != last_second:
		last_second = ceili(seconds)
		publish()

func deliver(house: int, kind: int, amount: int) -> String:
	var i: int = world.district.stops.find(house)
	if not active or i < 0 or ORDERS[i] != kind or delivered[i] >= REQUIRED[i]: return ""
	delivered[i] += 1
	pending += amount
	if delivered[i] == REQUIRED[i]: world.mark_delivered.rpc(house)
	publish()
	return "%s  %d/%d   +%d pending" % [CHILDREN[i], delivered[i], REQUIRED[i], amount]

func finish(success: bool, reason: String) -> void:
	settle(success, reason)
	world.begin_level()

func settle(success: bool, reason: String) -> void:
	active = false
	receipt = "%d vouchers banked. Kettle's on." % pending if success else "%s. %d pending vouchers forfeited." % [reason, pending]
	if success: world.mess.earn(pending)
	pending = 0
	delivered.fill(0)
	publish()

func publish(peer := 0) -> void:
	sync.rpc_id(peer, active, ceili(seconds), delivered, pending, receipt)
	if peer == 0: refresh()

@rpc("authority", "reliable")
func sync(flying: bool, left: int, counts: PackedInt32Array, earnings: int, result: String) -> void:
	active = flying
	seconds = left
	delivered = counts
	pending = earnings
	receipt = result
	refresh()

func refresh() -> void:
	var storm := smoothstep(0.0, float(WINDOW), WINDOW - seconds) if active else 0.0
	var intensity := lerpf(.58,1.0,storm) if active else .35
	snowfall.multimesh.visible_instance_count = roundi(intensity * FLAKES)
	snow_material.set_shader_parameter("intensity",intensity)
	world.weather_env.fog_density = lerpf(.00058, .0082, storm)
	world.weather_env.fog_light_color = Color(.30,.36,.51).lerp(Color(.58,.63,.69), storm)
	if world.district:
		for i in world.district.placards.size():
			var sign: Label3D = world.district.placards[i]
			var done := delivered[i] == int(REQUIRED[i])
			var coal: bool = ORDERS[i] == Cargo.Kind.BOMB
			sign.text = "%02d   %s · %s\n%s" % [i+1, CHILDREN[i], ADDRESSES[i], "Signed for" if done else "%s   %d/%d" % ["NAUGHTY · COAL" if coal else "NICE · GIFTS", delivered[i], REQUIRED[i]]]
			sign.modulate = Color("bad1c9") if done else (Color("ff9b83") if coal else Color("ffe5a4"))

	if world.mess and world.mess.chart:
		world.mess.chart.queue_redraw()
		world.mess.chart.get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE

func briefing() -> String:
	if not active:
		return (receipt + "   " if receipt != "" else "") + "Frostmere • Check the chart: gifts for nice, coal bombs for naughty • Clock starts at liftoff"
	var left := ceili(seconds)
	var instruction := "Return to runway and stop" if completed() == REQUIRED.size() else weather()
	if world.grounded and completed() < REQUIRED.size(): instruction = "Stopping on home runway forfeits pay"
	return "Frostmere   %d/6 stops   %d pending   %02d:%02d   %s" % [completed(), pending, floori(left / 60.0), left % 60, instruction]
