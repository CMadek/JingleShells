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
	w.set_physics_process(false)
	w.players[1].set_physics_process(false)
	w.queues.set_physics_process(false)
	w.stations.set_physics_process(false)
	var dt := 1.0/Engine.physics_ticks_per_second
	var scenarios := [Vector3(14,0,0),Vector3(25,.45,0),Vector3(35,-.35,.35),Vector3(20,0,-.3)]
	for rack in 2:
		for scenario in scenarios:
			w.queues.reset()
			w.stations.occupants.delivery = 1
			w.bomber.position = Vector3(1000,45,1000)
			w.heading = .2
			w.pitch = 0
			w.roll = 0
			w.speed = scenario.x
			w.throttle = .6
			w.in_throttle = .2
			w.in_steer = scenario.y
			w.in_climb = scenario.z
			w.grounded = false
			w._apply_attitude()
			w.physics_delta = dt
			w.previous_plane = w.bomber.transform
			w.moving_hull.transform = w.bomber.transform
			w.queues.queues[rack] = [{"id":1,"kind":1}]
			for i in 2: await get_tree().physics_frame
			var before: Dictionary = w.flight_state()
			var state: Dictionary = w.queues.prediction_state(rack,1)
			check(w.flight_state()==before,"Forecast does not mutate live flight")
			check(not state.is_empty(),"Delayed release has a valid state")
			if state.is_empty(): continue
			var predicted: Dictionary = w.stations.predict(state,1)
			check(not predicted.is_empty(),"Delayed target finds terrain")
			if predicted.is_empty(): continue
			var id: int = w.next_item
			check(w.queues.handle(1,"release",rack),"Real release command starts cycle")
			var ticks := 0
			var midway := {}
			while not w.loose.has(id) and ticks<60:
				w.previous_plane = w.bomber.transform
				w._fly(dt)
				w.moving_hull.transform = w.bomber.transform
				w.queues._physics_process(dt)
				ticks += 1
				if ticks==10: midway = w.queues.prediction_state(rack,1)
				if not w.loose.has(id): await get_tree().physics_frame
			check(ticks==ceili(w.queues.RELEASE_DELAY/dt-.00001),"Preview and real cycle agree on commit tick")
			check(w.loose.has(id),"Real cycle spawned present")
			if not w.loose.has(id): continue
			var body: RigidBody3D = w.loose[id]
			check(body.position.distance_to(state.pose.origin)<.01,"Forecast release position matches real spawn")
			check(body.linear_velocity.distance_to(state.velocity)<.02,"Forecast inherits real release velocity")
			check(not midway.is_empty() and midway.pose.origin.distance_to(state.pose.origin)<.01,"Countdown uses remaining opening time")
			check(w.queues.prediction_state(rack,1).is_empty(),"Closing chute does not advertise another immediate release")
			for tick in 420:
				await get_tree().physics_frame
				if body.has_meta("impact_collider") or body.position.y<.27: break
			var error := Vector2(body.position.x-predicted.point.x,body.position.z-predicted.point.z).length()
			print("DELAY IMPACT ERROR rack=",rack," controls=",scenario,": ",error)
			check(error<.8,"Crosshair matches actual delayed present impact within 0.8m")
			w.remove_loose(id)
	print("RELEASE PREDICTION CHECKS: ","PASS" if failures==0 else "FAIL")
	main.queue_free()
	await get_tree().create_timer(.3).timeout
	get_tree().quit(failures)
