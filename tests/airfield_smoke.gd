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
	var elf = w.players[1]
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(w.speed == 0 and w.grounded, "Sleigh starts parked")
	check(elf.global_position.distance_to(w.Airfield.SPAWN) < 3,"Spawn in depot")
	w.set_physics_process(false)
	elf.set_physics_process(false)
	check(w.supply_points.size() == 18,"Nine individual supply shelves on each side")
	var shelf_interact := InputEventAction.new()
	shelf_interact.action = "interact"
	shelf_interact.pressed = true
	for supply in w.supply_points:
		elf.global_position = w.bomber.to_global(Vector3(signf(supply.point.x)*.8,.05,supply.point.z))
		var direction: Vector3 = (w.bomber.to_global(supply.point)-elf.head.global_position).normalized()
		var yaw := atan2(-direction.x,-direction.z)
		var look_pitch := asin(direction.y)
		elf.rotation.y = yaw
		elf.pitch = look_pitch
		elf.head.rotation = Vector3(look_pitch,0,0)
		elf._unhandled_input(shelf_interact)
		check(elf.held_kind == supply.kind,"Individual shelf item is collectible: " + str(supply.point))
		w.set_held(1,0)
	var outside: Vector3 = w.bomber.to_global(Vector3(4,1.4,0))
	var through_wall := Transform3D(Basis.IDENTITY,outside).looking_at(w.bomber.to_global(Vector3(2.42,1.385,0)))
	check(w.aimed_pile(through_wall) == 0,"Cannot collect shelf supplies through fuselage")
	w.set_held(1,1)
	elf.rotation = Vector3.ZERO
	elf.pitch = 0
	elf.head.rotation = Vector3.ZERO
	elf.global_position = w.Airfield.SPAWN
	for target in [Vector3(-24,0,840),Vector3(-22,0,835.2),Vector3(-9,0,835.2),Vector3(-1,1.82,835.2)]:
		for i in range(360):
			var offset: Vector3 = target-elf.global_position
			offset.y = 0
			if offset.length() < .2: break
			elf.velocity = offset.normalized()*5
			elf.velocity.y = -2
			elf.move_and_slide()
			await get_tree().physics_frame
		check(Vector2(elf.position.x-target.x,elf.position.z-target.z).length() < .4,"Walkable loading route: " + str(target))
	check(w.aboard(elf.global_position),"Board through North Star doorway")
	# The POC's original open aisle runs between the shelves and the rear deck.
	elf.global_position = w.bomber.to_global(Vector3(0,.05,-1.8))
	for target_z in [6.0,-1.8]:
		for i in range(200):
			var offset_z: float = target_z-w.bomber.to_local(elf.global_position).z
			if absf(offset_z) < .15: break
			elf.velocity = Vector3(0,-2,signf(offset_z)*4)
			elf.move_and_slide()
			await get_tree().physics_frame
		check(absf(w.bomber.to_local(elf.global_position).z-target_z) < .2,"Original cabin aisle is clear in both directions")
	check(not w.aboard(w.bomber.to_global(Vector3(0,0,9))),"Aircraft bounds match original POC length")
	# Shelf boards physically support released cargo as well as blocking players.
	w.set_held(1,1)
	elf.global_position = w.bomber.to_global(Vector3(0,.05,0))
	w._handle_cargo(1,"drop",0,0,0)
	var shelf_item: int = w.next_item-1
	w.loose[shelf_item].global_position = w.bomber.to_global(Vector3(2.42,1.55,0))
	w.loose[shelf_item].linear_velocity = Vector3.ZERO
	for i in range(60): await get_tree().physics_frame
	var shelf_height: float = w.bomber.to_local(w.loose[shelf_item].global_position).y
	check(shelf_height > 1.3 and shelf_height < 1.5,"Loose cargo rests on middle shelf collision")
	w.remove_loose(shelf_item)
	w.set_held(1,1)
	elf.global_position = w.bomber.to_global(Vector3(0,.05,0))
	w._handle_cargo(1,"drop",0,0,0)
	check(elf.held_kind == 0 and w.loose.size() == 1,"Unload carried gear")
	for i in range(60):
		await get_tree().physics_frame
		w._step_cargo(1.0/60)
	check(w.loose.size() == 1,"Loaded gear remains available")
	for item in w.loose.values(): check(w.aboard(item.global_position),"Cargo rests in cabin")
	# Ground crew stay at depot; boarded crew ride, including the upper station.
	elf.global_position = w.Airfield.SPAWN
	var original: Vector3 = elf.global_position
	var old: Transform3D = w.bomber.transform
	w.bomber.position.z -= 10
	w.carry_crew(old)
	check(elf.global_position == original,"Ground crew must not move with sleigh")
	elf.global_position = w.bomber.to_global(Vector3(0,2.19,-2.8))
	old = w.bomber.transform
	w.bomber.position.z -= 10
	w.carry_crew(old)
	check(w.bomber.to_local(elf.global_position).distance_to(Vector3(0,2.19,-2.8)) < .01,"Dorsal gunner rides sleigh")
	w.sync_bomber(w.bomber.position+Vector3(0,0,-5),.1,0,0,10,.2,0)
	check(w.bomber.to_local(elf.global_position).distance_to(Vector3(0,2.19,-2.8)) < .01,"Received aircraft pose carries boarded crew")
	w.heading = 0
	w._apply_attitude()
	w.bomber.position = w.Airfield.PARK
	# This manual test teleport is not aircraft motion inherited by released cargo.
	w.previous_plane = w.bomber.transform
	w.moving_hull.transform = w.bomber.transform
	elf.global_position = w.Airfield.SPAWN
	w.access.set_state("hatch",true,0)
	w.access.step(1.2)
	check(w.access.panels.hatch.get_child(1).disabled,"Open hatch has real collision opening")
	check(is_equal_approx(w.access.hatch_leaves[0].rotation.z,-PI/2) and is_equal_approx(w.access.hatch_leaves[1].rotation.z,PI/2),"Bomber hatch opens downwards from centre on outer hinges")
	# Drop real cargo through the open bay, including the host physics gate.
	elf.global_position = w.bomber.to_global(Vector3(0,.05,4.1))
	w.set_held(1,1)
	w._handle_cargo(1,"drop",0,-1.0,0)
	var dropped_id: int = w.next_item-1
	for i in range(70): await get_tree().physics_frame
	check(w.loose.has(dropped_id) and w.loose[dropped_id].global_position.y < w.bomber.position.y-.5,"Cargo falls through the open bomber bay")
	if w.loose.has(dropped_id): w.remove_loose(dropped_id)
	elf.global_position = w.bomber.to_global(Vector3(0,0,3))
	w.access.set_state("hatch",false,1)
	w.access.step(.1)
	check(w.access.opened.hatch,"Hatch reverses when occupied")
	elf.global_position = w.Airfield.SPAWN
	w.access.set_state("hatch",false,1)
	w.access.step(1.2)
	check(not w.access.panels.hatch.get_child(1).disabled,"Closed hatch supports cargo")
	# Close the door using the player's actual E interaction, even after taxiing.
	elf.global_position = w.bomber.to_global(Vector3(-1.7,0,-4.8))
	elf.head.look_at(w.bomber.to_global(w.access.POINTS.door))
	w.speed = 8
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	elf._unhandled_input(interact)
	check(not w.access.opened.door,"E must close door from inside while taxiing")
	w.access.step(1.2)
	check(w.access.amount.door == 0,"Door finishes closing")
	check(w.access.ramp.visible and w.access.ramp.scale == Vector3.ONE and not w.access.ramp.get_child(1).disabled and not w.access.ramp_cargo.disabled,"Closed door keeps full ramp and cargo collision deployed")
	w.grounded = false
	w.speed = 35
	elf._unhandled_input(interact)
	check(w.access.opened.door,"E opens boarding door at flight speed")
	w.access.step(.5)
	elf._unhandled_input(interact)
	check(not w.access.opened.door,"E reverses door mid-animation")
	w.access.step(.2)
	elf._unhandled_input(interact)
	w.access.step(1.2)
	check(w.access.amount.door == 1,"Door can reopen immediately")
	w.grounded = true
	# Restored state uses the same path as a late join snapshot.
	w.access.set_state("hatch",true,.5)
	w.access.step(.6)
	check(w.access.amount.hatch == 1.0,"Snapshot resumes in-progress hatch animation")
	w.access.set_state("hatch",false,0)
	w.speed = 0
	w.throttle = 0
	elf.global_position = w.bomber.to_global(w.HELM_POS)
	elf.head.rotation = Vector3.ZERO
	elf._unhandled_input(interact)
	check(w.pilot_id == 1,"E must engage helm")
	w.send_pilot_input(0,1,1)
	var distance := 0.0
	for i in range(600):
		w._fly(1.0/60)
		w.access.step(1.0/60)
		if not w.grounded:
			distance = w.Airfield.PARK.z-w.bomber.position.z
			break
	check(not w.grounded and distance < 300,"Takeoff fits runway")
	check(w.access.opened.door and w.access.amount.door == 1,"Takeoff leaves boarding door under crew control")
	print("TAKEOFF: ",distance)
	w.bomber.position = Vector3(0,1.85,500)
	w.pitch = -.1
	w.in_climb = 0
	w.in_throttle = -1
	w._fly(.1)
	check(w.grounded and w.bomber.position.z < 501,"Touchdown preserves location")
	w.speed = 45
	w.throttle = 1
	var start_z: float = w.bomber.position.z
	for i in range(600): w._fly(1.0/60)
	check(w.speed == 0 and start_z-w.bomber.position.z < 300,"Maximum-speed landing roll fits runway")
	print("MAX SPEED STOP: ",start_z-w.bomber.position.z)
	w.begin_level()
	check(w.loose.is_empty() and w.pilot_id == 0 and elf.held_kind == 0,"New level resets loading state")
	check(elf.global_position.distance_to(w.Airfield.SPAWN) < 3,"New level returns crew to depot")
	w.access.step(0)
	w.instruments.update_readings(w,0)
	check(is_zero_approx(w.instruments.speed.rotation.z-w.instruments.SWEEP),"Instrument reflects parked speed")
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		w.add_child(camera)
		camera.current = true
		camera.position = Vector3(-20,10,813)
		camera.look_at(Vector3(-5,2,837))
		await screenshot("airfield")
		camera.position = Vector3(-10,3.3,831)
		camera.look_at(w.bomber.to_global(Vector3(-3,1.1,-4.8)))
		await screenshot("boarding")
		camera.position = Vector3(-28,2,844)
		camera.look_at(Vector3(-28,2,834))
		await screenshot("shop")
		camera.position = w.bomber.to_global(Vector3(0,1.7,6))
		camera.look_at(w.bomber.to_global(Vector3(0,1,-2)))
		await screenshot("restored-cabin")
		camera.position = w.bomber.to_global(Vector3(0,1.7,-1))
		camera.look_at(w.bomber.to_global(Vector3(0,1.3,7)))
		await screenshot("rear-room")
		camera.position = w.bomber.to_global(Vector3(0,1.7,4.8))
		camera.look_at(w.bomber.to_global(Vector3(0,1.4,-.5)))
		await screenshot("poc-cabin-shelves")
		camera.position = w.bomber.to_global(Vector3(.1,1.6,1.5))
		camera.look_at(w.bomber.to_global(Vector3(-2.42,1.4,0)))
		await screenshot("individual-shelves")
		w.access.set_state("hatch",true,1)
		w.access.step(0)
		camera.position = w.bomber.to_global(Vector3(0,1.4,5.1))
		camera.look_at(w.bomber.to_global(Vector3(0,-.4,3)))
		await screenshot("bomber-hatch")
	print("AIRFIELD CHECKS: ","PASS" if failures == 0 else "FAIL")
	main._return_to_menu("Airfield smoke complete")
	await get_tree().process_frame
	await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame
	# Let the audio mixer finish its stop/fade commands before process shutdown.
	await get_tree().create_timer(.2).timeout
	get_tree().quit(failures)

func screenshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.test-data/"+label+".png")
