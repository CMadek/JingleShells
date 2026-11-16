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
	check(not w.aerobatics, "New flights start in flight assist")
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
	w.aerobatics = true
	w.begin_level()
	check(not w.aerobatics, "Restarting a sortie restores flight assist")
	check(w.unattended_seconds == 0 and w.grounded, "New level clears recovery state")
	check_handling(w, dt)
	check_aerobatics(w, dt)
	check_afterburner(w, dt)
	check_burner_heat(w, dt)
	check_cruise(w, dt)
	print("FLIGHT RECOVERY CHECKS: ", "PASS" if failures == 0 else "FAIL")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)

func check_handling(w: Node, dt: float) -> void:
	var state: Dictionary = w.flight_state()
	state.aerobatics = false
	state.grounded = false
	state.crew_aboard = true
	state.position.y = 150
	state.speed = 20
	state.throttle = .4
	state.in_steer = 1
	for i in 60: w.advance_flight(state, dt)
	check(rad_to_deg(state.roll) >= 24.0 and rad_to_deg(state.roll) <= 28.01, "A delivery turn reaches useful bank within one second")
	var slow_heading: float = state.heading
	var fast := state.duplicate()
	fast.speed = 30
	fast.throttle = .9
	for i in 60:
		w.advance_flight(state, dt)
		w.advance_flight(fast, dt)
	check(absf(state.heading - slow_heading) > absf(fast.heading - slow_heading), "A slower pass gives a tighter turn")
	var start_turn: Vector3 = state.position
	var start_heading: float = state.heading
	for i in 900:
		w.advance_flight(state, dt)
		if absf(state.heading - start_heading) >= PI: break
	check(absf(state.heading - start_heading) >= PI and start_turn.distance_to(state.position) < 175,
		"A missed house can be lined up again with a bank-limited half turn")
	state.in_steer = 0
	state.pitch = deg_to_rad(20)
	for i in 90: w.advance_flight(state, dt)
	check(is_zero_approx(state.roll) and is_zero_approx(state.pitch), "Released controls level the wings and nose within 1.5 seconds")
	var level_heading: float = state.heading
	for i in 60: w.advance_flight(state, dt)
	check(is_equal_approx(state.heading, level_heading), "Released steering stops the turn")

func check_aerobatics(w: Node, dt: float) -> void:
	var start: Dictionary = w.flight_state()
	start.merge({"grounded":false, "crew_aboard":true, "position":Vector3(0,160,0),
		"speed":53.0, "throttle":1.0, "aerobatics":true},true)
	for direction in [-1,1]:
		var s := start.duplicate()
		s.in_steer = direction
		for tick in 86: w.advance_flight(s,dt)
		check(w.flight_pose(s).basis.y.y < -.995, "Either roll direction reaches inverted")
		var inverted: Basis = w.flight_pose(s).basis
		s.in_steer = 0
		for tick in 60: w.advance_flight(s,dt)
		check(inverted.is_equal_approx(w.flight_pose(s).basis), "Releasing the stick holds an inverted attitude")
		s.in_steer = -direction
		for tick in 86: w.advance_flight(s,dt)
		check(w.flight_pose(s).basis.y.y > .999, "Reversing the roll recovers upright")
	var loop := start.duplicate()
	loop.in_climb = 1
	var apex := 0.0
	for tick in 450:
		w.advance_flight(loop,dt)
		apex = maxf(apex,loop.position.y - start.position.y)
		if tick == 224: check(w.flight_pose(loop).basis.z.z < -.99, "Top of loop reverses flight direction")
	check(w.flight_pose(loop).basis.z.z > .995 and apex > 100 and absf(loop.position.y-start.position.y) < 25,
		"Completed loop returns to the entry heading and altitude band (forward %.3f, rise %.1f m, altitude change %.1f m)" %
		[w.flight_pose(loop).basis.z.z, apex, loop.position.y - start.position.y])
	var barrel := start.duplicate()
	barrel.in_steer = 1
	barrel.in_climb = 1
	for tick in 161: w.advance_flight(barrel,dt)
	check(absf(barrel.position.x) > 15 and w.flight_pose(barrel).basis.y.y > .98, "Combined pitch and roll flies a corkscrew through space")
	var vertical := start.duplicate()
	vertical.pitch = PI/2
	vertical.heading = .6
	vertical.roll = -.4
	vertical.in_climb = .05
	var entry: Basis = w.flight_pose(vertical).basis
	for tick in 60: w.advance_flight(vertical,dt)
	check((entry * Basis(Vector3.RIGHT, w.ACRO_PITCH_RATE*.05)).get_rotation_quaternion().angle_to(
		w.flight_pose(vertical).basis.get_rotation_quaternion()) < .001, "Small pitch inputs carry a banked aircraft through vertical")
	var recovery := start.duplicate()
	recovery.roll = PI
	recovery.aerobatics = false
	recovery.cruise_target = Vector2(recovery.heading, recovery.position.y)
	for tick in 720: w.advance_flight(recovery,dt)
	check(absf(recovery.roll) < .01 and absf(recovery.pitch) < .01 and absf(recovery.position.y - start.position.y) < .2 and absf(recovery.heading) < .01,
		"Cruise hold can recover a fully inverted aircraft (roll %.3f, pitch %.3f, height change %.3f, course %.3f)" %
		[recovery.roll, recovery.pitch, recovery.position.y-start.position.y, recovery.heading])
	var pass_speed := start.duplicate()
	pass_speed.throttle = .5
	for tick in 600: w.advance_flight(pass_speed,dt)
	check(pass_speed.speed > 21 and pass_speed.speed < 23, "Half throttle settles to a manageable delivery speed")

func check_afterburner(w: Node, dt: float) -> void:
	var elf = w.players[1]
	w.set_pilot(1)
	elf.global_position = w.bomber.to_global(w.HELM_POS)
	Input.action_press("afterburner")
	elf._send_flight_controls()
	var taxi: Dictionary = w.flight_state()
	for tick in 60: w.advance_flight(taxi,dt)
	check(taxi.speed == 0 and not w.afterburner_active(), "Holding boost on the runway cannot propel a parked aircraft")
	w.grounded = false
	w.bomber.position.y = 100
	elf.global_position = w.bomber.to_global(w.HELM_POS)
	w.speed = 53.2
	w.throttle = .5
	var forecast: Dictionary = w.forecast_flight(.25)
	for tick in 15:
		var old: Transform3D = w.bomber.transform
		w._fly(dt)
		w.carry_crew(old)
	check(w.bomber.position.distance_to(forecast.pose.origin) < .001, "Delivery forecast uses the same boost as the host")
	for tick in 105:
		var old: Transform3D = w.bomber.transform
		w._fly(dt)
		w.carry_crew(old)
	print("AFTERBURNER: 53.2 to %.2f m/s in 2 seconds" % w.speed)
	check(w.speed > 77 and w.speed < 83 and w.throttle == .5 and not w.aerobatics, "Held afterburner accelerates the aircraft in assist without moving the lever")
	var fast: float = w.speed
	Input.action_release("afterburner")
	elf._send_flight_controls()
	var coast: Dictionary = w.flight_state()
	w.advance_flight(coast,dt)
	check(not w.afterburner_active() and coast.speed < fast and coast.speed > fast-.3, "Release cuts thrust and preserves momentum")
	for tick in 900: w.advance_flight(coast,dt)
	check(absf(coast.speed-22.36) < .2, "Aircraft settles at the original delivery power")
	w.request_cruise_hold()
	w.send_pilot_input(0,0,0,true)
	check(w.cruise_target == w.CRUISE_OFF and w.afterburner_active(), "Boost releases cruise hold")
	w.set_pilot(0)
	check(not w.afterburner_held, "Leaving the helm cuts afterburner")
	w.begin_level()

func check_burner_heat(w: Node, dt: float) -> void:
	var s: Dictionary = w.flight_state()
	s.merge({"grounded":false,"crew_aboard":true,"position":Vector3(0,80,0),"speed":53.0,
		"throttle":1.0,"afterburner_held":true},true)
	for tick in 360: w.advance_flight(s,dt)
	check(is_equal_approx(s.burner_heat, w.HEAT_WARNING) and not s.burner_locked, "Six seconds brings a cold burner into the warning band")
	s.afterburner_held = false
	for tick in 60: w.advance_flight(s,dt)
	check(is_equal_approx(s.burner_heat,.625) and not s.burner_locked, "Letting off early cools the engine and allows immediate reuse")
	s.afterburner_held = true
	for tick in 180: w.advance_flight(s,dt)
	check(s.burner_locked and s.burner_heat == 1.0, "Reigniting with residual heat uses only the remaining burst")
	var coast := s.duplicate()
	coast.afterburner_held = false
	w.advance_flight(s,dt)
	w.advance_flight(coast,dt)
	check(is_equal_approx(s.speed,coast.speed), "Held boost supplies no thrust during thermal cutoff")
	for tick in 311:
		w.advance_flight(s,dt)
		w.advance_flight(coast,dt)
	check(is_equal_approx(s.burner_heat,w.HEAT_REARM) and s.burner_locked and not coast.burner_locked,
		"Cooling to the reset mark rearms a released key and leaves a held key locked")
	s.afterburner_held = false
	w.advance_flight(s,dt)
	s.afterburner_held = true
	var previous_heat: float = s.burner_heat
	w.advance_flight(s,dt)
	check(not s.burner_locked and s.burner_heat > previous_heat, "Release and press again restores thrust after cooldown")
	w.burner_heat = .8
	w.burner_locked = true
	w.set_pilot(1)
	w.set_pilot(0)
	check(w.burner_heat == .8 and w.burner_locked, "Changing pilots preserves the engine's heat and lockout")
	var parked: Dictionary = w.flight_state()
	for tick in 240: w.advance_flight(parked,dt)
	check(not parked.burner_locked and is_equal_approx(parked.burner_heat,.3), "Engines cool while parked and unattended")
	w.begin_level()
	check(w.burner_heat == 0 and not w.burner_locked and not w.aerobatics, "A fresh sortie starts cold with assist on")

func check_cruise(w: Node, dt: float) -> void:
	var elf = w.players[1]
	w.set_pilot(1)
	w.request_cruise_hold()
	check(w.cruise_target == w.CRUISE_OFF, "Hold cannot engage on the runway")
	w.grounded = false
	w.bomber.position.y = 90
	w.speed = 20
	w.throttle = .4
	w.roll = w.MAX_ROLL
	w.pitch = deg_to_rad(14)
	w.heading = -PI + .01
	w._apply_attitude()
	elf.position = w.bomber.to_global(w.HELM_POS)
	var toggle := InputEventAction.new()
	toggle.action = "cruise_hold"
	toggle.pressed = true
	elf._unhandled_input(toggle)
	var course := Vector2(w.heading, w.bomber.position.y)
	check(w.cruise_target == course, "Helm action captures current course and altitude mid-turn and climb")
	w.request_helm()
	check(w.pilot_id == 0 and w.cruise_target == course, "Leaving the helm keeps hold engaged")
	w.request_cruise_hold()
	w.send_pilot_input(-1, -1, -1)
	check(w.cruise_target == course, "A walking player cannot change cruise or fly the aircraft")
	for i in 600:
		var old: Transform3D = w.bomber.transform
		w._fly(dt)
		w.carry_crew(old)
	check(w.cruise_target == course and absf(angle_difference(w.heading, course.x)) < deg_to_rad(.25)
		and absf(w.bomber.position.y - course.y) < .15, "Unoccupied helm recaptures heading and altitude")
	check(is_equal_approx(w.throttle, .4) and w.aboard(elf.position) and elf.global_basis.y.dot(Vector3.UP) > .9999,
		"Cruising preserves the throttle lever and carries an upright crewmate")
	w.request_helm()
	check(w.pilot_id == 1 and w.cruise_target == course, "Retaking the helm preserves hold until an input")
	for axes in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		w.send_pilot_input(axes.x, axes.y, axes.z)
		check(w.cruise_target == w.CRUISE_OFF, "Each manual flight axis cancels hold immediately")
		w.send_pilot_input(0, 0, 0)
		w.request_cruise_hold()
	w.request_cruise_hold()
	check(w.cruise_target == w.CRUISE_OFF, "A second press returns to manual flight")
	w.request_cruise_hold()
	w.speed = w.CRUISE_SPEED - 1
	w._fly(dt)
	check(w.cruise_target == w.CRUISE_OFF and "LOW AIRSPEED" in w.flight_status(), "Airspeed loss disconnects hold and warns the crew")
	w.speed = w.STALL_SPEED - 1
	w.throttle = 0
	w.request_cruise_hold()
	check(w.cruise_target == w.CRUISE_OFF and "STALL" in w.flight_status(), "A stalled aircraft cannot engage hold")
	var state: Dictionary = w.flight_state()
	var stall_height: float = state.position.y
	state.throttle = 1
	for i in 180: w.advance_flight(state, dt)
	check(state.speed > w.CRUISE_SPEED and state.position.y < stall_height and not state.grounded, "Adding power recovers from a stall with real height loss")
	w.speed = 20
	w.request_cruise_hold()
	w.request_helm()
	elf.position = w.Airfield.SPAWN
	for i in 200: w._fly(dt)
	check(w.cruise_target == w.CRUISE_OFF and w.throttle < .4, "The last crew member leaving overrides hold with the recovery glide")
	w.begin_level()
	check(w.cruise_target == w.CRUISE_OFF and w.flight_status() == "", "Reset clears hold and airspeed warnings")
