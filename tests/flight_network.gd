extends "res://tests/mk2_network.gd"
## Real two-process helm handoff, flight snapshots and crew operations.

func until(condition: Callable, description: String) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	var passed: bool = condition.call()
	check(passed, description)
	return passed

func host_checks() -> void:
	w.set_physics_process(false)
	var elf = w.players[1]
	w.bomber.position = Vector3(1000, 90, 1000)
	w.grounded = false
	w.speed = 20
	w.throttle = .4
	w.previous_plane = w.bomber.transform
	w.moving_hull.transform = w.bomber.transform
	elf.position = w.bomber.to_global(w.HELM_POS)
	w.request_helm()
	w.request_cruise_hold()
	w.request_helm()
	elf.position = w.bomber.to_global(Vector3(0, .05, 1))
	w.queues.queues[0] = [{"id":1, "kind":w.Cargo.Kind.PRESENT}]
	w.queues.serial = 2
	w.queues.publish()
	if not await until(func(): return w.pilot_id > 1, "Joining pilot takes the empty helm"): return
	w.set_physics_process(true)
	if not await until(func(): return w.in_steer == 1 and w.in_throttle == 1, "Remote pilot can turn and open the throttle together"): return
	var start: Vector3 = w.bomber.to_local(elf.position)
	Input.action_press("move_back")
	await get_tree().create_timer(.25).timeout
	Input.action_release("move_back")
	check(w.bomber.to_local(elf.position).z > start.z + .25 and w.aboard(elf.position)
		and elf.global_basis.y.dot(Vector3.UP) > .9999, "Host walks the deck upright during the remote pilot's bank")
	if not await until(func(): return w.afterburner_active() and w.speed > 63, "Remote afterburner adds real airspeed on the host"): return
	if not await until(func(): return w.burner_locked and w.afterburner_held and not w.afterburner_active(), "Host cuts off the remote pilot's overheated burner"): return
	if not await until(func(): return not w.burner_locked and w.burner_heat <= w.HEAT_REARM, "Host rearms after the remote pilot releases"): return
	if not await until(func(): return w.aerobatics and w.bomber.basis.y.y < -.90, "Remote roll puts the aircraft upside down"): return
	start = w.bomber.to_local(elf.position)
	Input.action_press("move_back")
	await get_tree().create_timer(.25).timeout
	Input.action_release("move_back")
	var walked: Vector3 = w.bomber.to_local(elf.position) - start
	check(walked.z > .35 and absf(walked.y) < .3 and elf.global_basis.y.dot(w.bomber.basis.y) > .99,
		"Crew walks along the inverted deck with feet on the cabin floor")
	if not await until(func(): return w.pilot_id == 0 and w.cruise_target != w.CRUISE_OFF, "Remote pilot leaves with hold engaged"): return
	var target: Vector2 = w.cruise_target
	elf.position = w.bomber.to_global(w.stations.SEATS.delivery)
	elf.head.look_at(w.bomber.to_global(w.stations.CONTROLS.delivery))
	w.stations.request("delivery")
	check(w.stations.occupants.delivery == 1, "Host takes the delivery console while the helm is empty")
	check(not w.queues.prediction_state(0, w.Cargo.Kind.PRESENT).is_empty(), "A crewed cruise has a drop solution")
	check(w.queues.handle(1, "release", 0), "Host releases a present during hands-off cruise")
	if not await until(func(): return w.queues.queues[0].is_empty() and w.next_item > 1, "Host really launches the queued present"): return
	if not await until(func(): return w.pilot_id > 1, "Remote pilot retakes the helm"): return
	if not await until(func(): return w.players.size() == 1, "Remote pilot disconnects"): return
	check(w.pilot_id == 0 and w.cruise_target == target, "A disconnect frees the helm and preserves the remaining crew's hold")

func client_checks() -> void:
	var id := multiplayer.get_unique_id()
	if not await until(func(): return w.players.has(id) and w.cruise_target == Vector2(0, 90), "Late join restores the active course and altitude"): return
	var elf = w.players[id]
	elf.position = w.bomber.to_global(w.HELM_POS)
	# Give the host time to receive the walking pose before requesting the seat.
	await get_tree().create_timer(.4).timeout
	w.request_helm()
	if not await until(func(): return w.pilot_id == id, "Remote player receives the helm"): return
	Input.action_press("move_right")
	Input.action_press("move_forward")
	var moved := await until(func(): return w.cruise_target == w.CRUISE_OFF and w.roll > deg_to_rad(12),
		"Remote flight input disengages hold and banks the replicated aircraft")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	if not moved: return
	if not await until(func(): return w.in_throttle == 0 and w.in_steer == 0, "Host sees released controls"): return
	Input.action_press("afterburner")
	if not await until(func(): return w.afterburner_active() and w.speed > 67, "Remote pilot sees the burner and measured speed increase"): return
	if not await until(func(): return w.burner_locked and w.instruments.annunciator.text == "COOLING", "Remote dash and engines enter cutoff together"): return
	if not await until(func(): return w.instruments.annunciator.text == "RELEASE" and not w.afterburner_active(), "Holding through cooldown shows the release instruction"): return
	Input.action_release("afterburner")
	if not await until(func(): return not w.burner_locked and w.instruments.annunciator.text == "READY", "Remote pilot sees the ready annunciator after release"): return
	var mode := InputEventAction.new()
	mode.action = "aerobatics"
	mode.pressed = true
	get_viewport().push_input(mode, true)
	if not await until(func(): return w.aerobatics, "Bound mode switch selects free flight on the host"): return
	Input.action_press("move_right")
	if not await until(func(): return w.bomber.basis.y.y < -.97, "Client sees its roll reach inverted"): return
	Input.action_release("move_right")
	await get_tree().create_timer(.5).timeout
	Input.action_press("move_left")
	if not await until(func(): return w.bomber.basis.y.y > .995, "Client reverses the roll and recovers upright"): return
	Input.action_release("move_left")
	var toggle := InputEventAction.new()
	toggle.action = "cruise_hold"
	toggle.pressed = true
	get_viewport().push_input(toggle, true)
	if not await until(func(): return w.cruise_target != w.CRUISE_OFF, "Pilot can engage hold through the bound control"): return
	var target: Vector2 = w.cruise_target
	w.request_helm()
	if not await until(func(): return w.pilot_id == 0 and w.queues.queues[0].is_empty(), "Client sees the crew's discharge after leaving the helm"): return
	check(w.cruise_target == target and w.aboard(elf.position), "Hold and walking position survive the handoff")
	w.request_helm()
	if not await until(func(): return w.pilot_id == id, "Remote pilot can reclaim the cruising aircraft"): return
	await get_tree().create_timer(.3).timeout
