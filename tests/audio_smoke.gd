extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var main = load("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	var w = main.get_node("World")
	var audio = w.flight_audio
	w.set_physics_process(false)
	w.players[1].set_physics_process(false)
	audio.set_process(false)
	var events := {}
	audio.effect_played.connect(func(kind: String): events[kind] = events.get(kind,0)+1)
	audio.update_audio(.1)
	check(not audio.engine.playing and not audio.runners.playing,"Parked aircraft starts quiet")
	for p in audio.gains:
		check(p.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and p.stream.loop_end > 0,"Continuous sounds loop")
	for p in audio.get_children():
		check(p.bus == "Master","Every effect respects master volume/mute")
	w.throttle = .25
	for i in range(60): audio.update_audio(1.0/60)
	var low_pitch: float = audio.engine.pitch_scale
	var low_gain: float = audio.gains[audio.engine]
	w.throttle = 1
	w.speed = 30
	for i in range(120): audio.update_audio(1.0/60)
	check(audio.engine.playing and audio.engine.pitch_scale > low_pitch and audio.gains[audio.engine] > low_gain,"Engine spools with throttle")
	check(audio.gains[audio.engine] < .18 and audio.gains[audio.runners] < .15,"Reduced engine and runner levels stay below the quieter mix ceilings")
	check(audio.runners.playing,"Taxiing produces runner rumble")
	w.grounded = false
	w.bomber.position.y = 20
	for i in range(120): audio.update_audio(1.0/60)
	check(audio.wind.playing and audio.gains[audio.wind] > .01 and audio.gains[audio.wind] < .16,"Airspeed produces quieter wind")
	check(not audio.runners.playing,"Runner rumble fades after takeoff")
	w.bomber.position.y = w.MIN_ALTITUDE
	w.grounded = true
	audio.update_audio(.1)
	audio.update_audio(.1)
	check(events.get("touchdown",0) == 1 and audio.landing.playing,"Touchdown produces exactly one impact")
	w.access.set_state("hatch",true,0)
	audio.update_audio(.1)
	check(audio.motors.hatch.playing,"Hatch motor follows movement")
	w.access.step(1.2)
	audio.update_audio(.1)
	check(events.get("hatch_latch",0) == 1,"Hatch latches at animation endpoint")
	w.access.set_state("door",false,1)
	audio.update_audio(.1)
	w.access.step(1.2)
	audio.update_audio(.1)
	check(events.get("door_latch",0) == 1,"Boarding door latches at endpoint")
	# Wind requires an actual exterior opening, even at maximum airspeed.
	w.grounded = false
	w.bomber.position.y = 30
	w.speed = w.MAX_SPEED
	w.access.set_state("door",false,0)
	w.emergency.set_gone(false,false)
	audio.update_audio(.1)
	check(not audio.wind.playing and is_zero_approx(audio.gains[audio.wind]),"Closed exterior doors silence wind even with the legacy hatch open")
	w.access.set_state("door",true,.25)
	for i in 120: audio.update_audio(1.0/60)
	var partial_wind: float = audio.gains[audio.wind]
	check(audio.wind.playing and partial_wind > .001,"Partially open boarding door admits wind")
	w.access.set_state("door",true,1)
	for i in 120: audio.update_audio(1.0/60)
	check(audio.gains[audio.wind] > partial_wind*2,"Wind increases as the boarding door opens")
	w.emergency.set_gone(true,false)
	w.access.set_state("door",false,0)
	audio.update_audio(.1)
	check(audio.wind.playing,"Open emergency exit keeps wind playing when boarding door closes")
	w.emergency.set_gone(false,false)
	audio.update_audio(.1)
	check(not audio.wind.playing and is_zero_approx(audio.gains[audio.wind]),"Closing both exterior doors stops wind without a lingering loop")
	w.emergency.set_gone(true,false)
	for i in 120: audio.update_audio(1.0/60)
	check(audio.wind.playing and audio.gains[audio.wind] > .001,"Emergency exit alone starts wind from silence")
	w.landing_burst(Vector3(0,0,-900),w.Cargo.Kind.BOMB)
	w.landing_burst(Vector3(1,0,-900),w.Cargo.Kind.PRESENT)
	check(events.get("bomb",0) == 1 and events.get("present",0) == 1,"Existing replicated cargo effects play distinct sounds")
	for i in range(20): audio.cargo_impact(Vector3.ZERO,true)
	var voices := 0
	for p in audio.impacts:
		if p.playing: voices += 1
	check(voices <= 8,"Impact pool stays bounded")
	w.begin_level()
	audio.update_audio(.1)
	check(not audio.engine.playing and not audio.landing.playing,"Level reset stops old audio without a false landing")
	check(events.get("touchdown",0) == 1,"Reset does not replay landing")
	main._return_to_menu("Audio smoke complete")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(audio),"Leaving the game frees all world audio")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.2).timeout
	print("AUDIO CHECKS: ","PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)
