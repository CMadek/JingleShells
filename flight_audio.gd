extends Node3D
## Presentation follows replicated flight/access state; no extra input authority.
signal effect_played(kind: String)
const ENGINE = preload("res://assets/audio/engine_loop.wav")
const WIND = preload("res://assets/audio/wind_loop.wav")
const RUNNERS = preload("res://assets/audio/runner_loop.wav")
const MOTOR = preload("res://assets/audio/mechanism_loop.wav")
const LATCH = preload("res://assets/audio/latch.wav")
const LANDING = preload("res://assets/audio/touchdown.wav")
const BOMB = preload("res://assets/audio/bomb_burst.wav")
const PRESENT = preload("res://assets/audio/present_pop.wav")
var world: Node3D
var engine: AudioStreamPlayer3D
var wind: AudioStreamPlayer3D
var runners: AudioStreamPlayer3D
var landing: AudioStreamPlayer3D
var motors := {}
var latches := {}
var moving := {"door": false, "hatch": false}
var gains := {}
var was_grounded := true
var last_position := Vector3.ZERO
var last_vertical_speed := 0.0
var impacts: Array[AudioStreamPlayer3D] = []

func voice(stream: AudioStream, pos: Vector3, loop := false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Master"
	p.unit_size = 12
	p.max_distance = 160
	p.position = pos
	if loop:
		var wav := stream.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length()*wav.mix_rate)
		p.stream = wav
		p.volume_db = -80
		gains[p] = 0.0
	else:
		p.stream = stream
	add_child(p)
	return p

func build(w: Node3D) -> void:
	world = w
	engine = voice(ENGINE,Vector3(0,4.35,9.1),true)
	wind = voice(WIND,Vector3(0,1,0),true)
	runners = voice(RUNNERS,Vector3(0,-1.5,1),true)
	landing = voice(LANDING,Vector3(0,-1,0))
	for key in world.access.POINTS:
		motors[key] = voice(MOTOR,world.access.POINTS[key],true)
		latches[key] = voice(LATCH,world.access.POINTS[key])
		motors[key].unit_size = 5
		latches[key].unit_size = 5
	# Bounded pool; burst sounds disappear with this world on disconnect.
	for i in range(8):
		var p := voice(PRESENT,Vector3.ZERO)
		p.top_level = true
		impacts.append(p)
	reset_state()

func reset_state() -> void:
	was_grounded = world.grounded
	last_position = world.bomber.global_position
	last_vertical_speed = 0
	landing.stop()
	for p in latches.values(): p.stop()
	for p in impacts: p.stop()
	for key in moving: moving[key] = false
	for p in gains:
		p.stop()
		gains[p] = 0.0
		p.volume_db = -80

func mix_loop(p: AudioStreamPlayer3D, target: float, pitch: float, delta: float) -> void:
	var gain := lerpf(float(gains[p]),target,1-exp(-4*delta))
	gains[p] = gain
	p.pitch_scale = lerpf(p.pitch_scale,pitch,1-exp(-3*delta))
	p.volume_db = linear_to_db(maxf(gain,.0001))
	if gain > .001 and not p.playing: p.play()
	if gain <= .001 and target == 0: p.stop()

func _process(delta: float) -> void:
	if world: update_audio(delta)

func _exit_tree() -> void:
	for p in get_children():
		if p is AudioStreamPlayer3D: p.stop()

func update_audio(delta: float) -> void:
	var speed: float = clampf(world.speed/world.MAX_SPEED,0,1)
	var throttle: float = clampf(world.throttle,0,1)
	var camera := get_viewport().get_camera_3d()
	var inside: bool = camera != null and world.aboard(camera.global_position)
	var cabin := .7 if inside else 1.0
	mix_loop(engine,sqrt(throttle)*.38*cabin,.65+throttle*.7+speed*.15,delta)
	var exposure: float = 1.0+world.access.amount.hatch*.35+world.access.amount.door*.2
	mix_loop(wind,speed*speed*.26*exposure*(.2 if world.grounded else 1.0),.85+speed*.35,delta)
	mix_loop(runners,speed*.3 if world.grounded else 0.0,.7+speed*.6,delta)
	var pos: Vector3 = world.bomber.global_position
	var teleported := pos.distance_to(last_position) > 100
	if not was_grounded and world.grounded and not teleported:
		landing.volume_db = lerpf(-16,-5,clampf(absf(last_vertical_speed)/12,0,1))
		landing.play()
		effect_played.emit("touchdown")
	last_vertical_speed = (pos.y-last_position.y)/maxf(delta,.001)
	last_position = pos
	was_grounded = world.grounded
	for key in moving:
		var target := 1.0 if world.access.opened[key] else 0.0
		var active: bool = absf(float(world.access.amount[key])-target) > .001
		mix_loop(motors[key],.16 if active else 0.0,.8 if key == "hatch" else 1.1,delta)
		if moving[key] and not active:
			latches[key].volume_db = -12
			latches[key].play()
			effect_played.emit(key+"_latch")
		moving[key] = active

func cargo_impact(pos: Vector3, bomb: bool) -> void:
	var selected: AudioStreamPlayer3D = null
	for p in impacts:
		if not p.playing:
			selected = p
			break
	if selected == null: return
	selected.stream = BOMB if bomb else PRESENT
	selected.global_position = pos
	selected.volume_db = -5 if bomb else -12
	selected.unit_size = 18 if bomb else 7
	selected.play()
	effect_played.emit("bomb" if bomb else "present")
