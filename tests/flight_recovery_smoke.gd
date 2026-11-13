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
	w.bomber.position = Vector3(0, 80, 0)
	w.players[1].global_position = w.Airfield.SPAWN
	w.pitch = w.MAX_PITCH
	w.speed = 26
	w.throttle = 1
	w.grounded = false
	w.in_climb = 1
	w._apply_attitude()
	var state: Dictionary = w.flight_state()
	check(not state.crew_aboard, "Fallen player leaves the aircraft unattended")
	var dt := 1.0 / 60
	for i in 120: w.advance_flight(state, dt)
	check(is_equal_approx(state.throttle, 1), "Brief boarding-boundary crossings respect the recovery grace period")
	var before: Dictionary = w.flight_state()
	w.forecast_flight(.4)
	check(w.flight_state() == before, "Recovery-aware prediction cannot mutate live flight")
	for i in 120: w.advance_flight(state, dt)
	check(state.throttle < 1 and state.in_climb == 0, "Abandoned aircraft sheds throttle and clears stale climb input")
	for i in 7200:
		w.advance_flight(state, dt)
		if state.grounded and state.speed < .01 and state.throttle < .01: break
	check(state.grounded and state.speed < .01 and state.throttle < .01, "Steep abandoned climb returns to the ground and stops")
	check(is_equal_approx(state.position.y, w.MIN_ALTITUDE), "Recovery preserves the plane's ground clearance")
	# Crew can walk away from the helm, use cargo stations, or occupy the belly gun.
	w.players[1].global_position = w.bomber.to_global(Vector3(0,.05,1))
	check(w.has_crew_aboard(), "Walking passengers keep normal cruise")
	state = w.flight_state()
	state.unattended_seconds = 10.0
	for i in 600: w.advance_flight(state, dt)
	check(state.unattended_seconds == 0 and is_equal_approx(state.throttle, 1), "Boarded crew cancels recovery without cutting power")
	w.players[1].global_position = w.bomber.to_global(Vector3(1.7,-2,-7))
	w.stations.occupants.turret = 1
	check(w.has_crew_aboard(), "Occupied belly turret counts as aboard")
	w.stations.occupants.turret = 0
	w.players[1].global_position = w.Airfield.SPAWN
	w.unattended_seconds = 2.5
	w.pilot_id = 1
	for i in 120: w._fly(dt)
	check(w.pilot_id == 0, "A fallen pilot cannot leave the helm permanently claimed")
	w.begin_level()
	check(w.unattended_seconds == 0 and w.grounded, "New level clears recovery state")
	print("FLIGHT RECOVERY CHECKS: ", "PASS" if failures == 0 else "FAIL")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)
