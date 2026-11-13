extends Node
var w: Node3D
var main: Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func aim(id: int, point: Vector3, offset: Vector3 = Vector3(0,0,1.2)) -> void:
	var elf = w.players[id]
	elf.global_position = w.bomber.to_global(point+offset-Vector3(0,elf.head.position.y,0))
	elf.head.look_at(w.bomber.to_global(point))
func load_item(rack: int, kind: int, id: int = 1) -> bool:
	w.set_held(id,kind)
	aim(id,w.queues.loader(rack),Vector3(0,.6,1.2))
	return w.queues.handle(id,"load",rack)
func _ready() -> void:
	main = load("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	w = main.get_node("World")
	w.set_physics_process(false)
	w.players[1].set_physics_process(false)
	w.queues.set_physics_process(false)
	w.stations.set_physics_process(false)
	for i in 3: await get_tree().physics_frame
	if "--capture-only" in OS.get_cmdline_user_args():
		await captures()
		main.queue_free()
		await get_tree().create_timer(.3).timeout
		get_tree().quit()
		return
	for rack in 2:
		for i in 5:
			var marker: Node3D = w.instruments.get_node("Rack%dSlot%d_rig" % [rack,i+1])
			check(marker.position.distance_to(w.queues.slot(rack,i)) < .001,"Exported Blender slots match gameplay positions")
		var outlet: Node3D = w.instruments.get_node("ChuteOutlet%d_rig" % rack)
		check(outlet.position.distance_to(w.queues.outlet(rack)) < .001,"Exported outlet scale and coordinates match release")
	# Walk the blockout's 3 m aisle both ways before proceeding to mechanism checks.
	var elf = w.players[1]
	for x in [-.6,.6]:
		elf.global_position = w.bomber.to_global(Vector3(x,.05,4.0))
		for i in 110:
			elf.velocity = Vector3(0,-2,-4)
			elf.move_and_slide()
			await get_tree().physics_frame
		check(w.bomber.to_local(elf.global_position).z < 0,"Two elves can pass along the loading aisle")
	for rack in 2:
		for kind in [1,2,1,2,1]: check(load_item(rack,kind),"Mixed queue loads")
		check(w.queues.queues[rack].size() == 5,"Queue capacity five")
		check(not load_item(rack,2) and elf.held_kind == 2,"Full rack preserves held item")
	w.set_held(1,0)
	for index in [0,2,2]:
		var before: Array = w.queues.queues[0].duplicate(true)
		var chosen: Dictionary = before[index]
		aim(1,w.queues.slot(0,index),Vector3(.9,.2,0))
		check(w.queues.handle(1,"retrieve",0,chosen.id),"Retrieve arbitrary stable item ID")
		before.remove_at(index)
		check(w.queues.queues[0] == before,"Remaining order preserved")
		check(elf.held_kind == chosen.kind,"Retrieved type preserved")
		check(not w.queues.handle(1,"retrieve",0,chosen.id),"Duplicate retrieval rejected")
		w.set_held(1,0)
	check(load_item(0,2),"Reload appends to tail")
	check(w.queues.queues[0][-1].kind == 2,"Reload reorders")
	w.set_held(1,0)
	aim(1,w.stations.CONTROLS.delivery,Vector3(.9,.2,0))
	check(w.queues.aimed(1).is_empty(),"Console aim does not select a loading point")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	elf._unhandled_input(interact)
	check(w.stations.occupants.delivery == 1,"E enters the intended console")
	w.add_player(2)
	w.players[2].set_physics_process(false)
	aim(2,w.stations.CONTROLS.delivery,Vector3(.9,.2,0))
	check(not w.stations.occupy(2,"delivery"),"Station cannot be double occupied")
	aim(2,w.stations.CONTROLS.turret,Vector3(0,.8,1.25))
	check(w.queues.aimed(2).is_empty(),"Turret controls do not conflict with loading end")
	check(w.stations.occupy(2,"turret"),"Two independent operators")
	w.stations._physics_process(.016)
	check(w.players[2].global_position.distance_to(w.stations.turret_pitch.get_node("GunnerSeat_rig").global_position)<.01,"Operator occupies rotating pod seat")
	check(not w.queues.handle(2,"release",0),"Only console owner can discharge")
	var blocker := StaticBody3D.new()
	w.add_child(blocker)
	blocker.global_position = w.bomber.to_global(w.queues.outlet(0))
	w._hull_box(blocker,Vector3(1.2,1,1.2),Vector3.ZERO)
	await get_tree().physics_frame
	# Ground obstruction cancels the reserved release, preserving inventory.
	var before: Array = w.queues.queues[0].duplicate(true)
	check(w.queues.handle(1,"release",0),"Release reserves front ID")
	check(not w.queues.handle(1,"retrieve",0,before[0].id),"Reservation blocks retrieval race")
	check(not w.queues.handle(1,"load",0),"Busy rack blocks loading race")
	w.queues._physics_process(.5)
	check(w.queues.queues[0] == before,"Blocked outlet preserves all cargo")
	blocker.queue_free()
	await get_tree().physics_frame
	w.bomber.position = Vector3(0,60,700)
	w.previous_plane = w.bomber.transform
	w.moving_hull.transform = w.bomber.transform
	for i in 3: await get_tree().physics_frame
	check(w.queues.handle(1,"release",0),"Airborne release begins")
	var count: int = w.loose.size()
	w.queues._physics_process(.5)
	check(w.loose.size() == count+1,"Exactly one physical cargo spawn")
	check(w.queues.queues[0].size() == before.size()-1,"FIFO consumes exactly front item")
	check(w.loose[w.next_item-1].get_meta("kind") == before[0].kind,"FIFO type matches physical body")
	w.queues._physics_process(.5)
	check(w.loose.size() == count+1,"Commit does not repeat")
	# Shape-aware prediction and actual physics use the same release state.
	for scenario in [Vector3(0,40,0),Vector3(12,70,.25),Vector3(30,100,-.3)]:
		w.bomber.position = Vector3(0,scenario.y,700)
		w.bomber.rotation.z = scenario.z
		w.previous_plane = w.bomber.transform
		w.previous_plane.origin.z += scenario.x/60
		w.physics_delta = 1.0/60
		w.moving_hull.transform = w.bomber.transform
		for i in 3: await get_tree().physics_frame
		for kind in [1,2]:
			var state: Dictionary = w.queues.release_state(1,kind)
			check(not state.is_empty(),"Release path clear")
			if state.is_empty(): continue
			var predicted: Dictionary = w.stations.predict(state,kind)
			check(not predicted.is_empty(),"Prediction finds terrain")
			check(predicted.has("path") and predicted.path.size()>2 and predicted.path[-1].distance_to(predicted.point)<.001,"Dashed targeting path ends at the physics impact")
			var id: int = w.next_item
			w.next_item += 1
			w.show_loose(id,kind,state.pose)
			w.loose[id].linear_velocity = state.velocity
			var actual: Vector3 = state.pose.origin
			for tick in 360:
				await get_tree().physics_frame
				actual = w.loose[id].global_position
				if actual.y < .5: break
			check(actual.distance_to(predicted.point) < 2,"Predicted and actual release impact agree at speed/altitude/bank")
			w.remove_loose(id)
	w.bomber.rotation = Vector3.ZERO
	w.previous_plane = w.bomber.transform
	for i in 2: await get_tree().physics_frame
	check(w.stations.apply_aim(2,TAU+.1,-.4),"Yaw wraps full revolution")
	check(absf(w.stations.yaw-.1)<.001,"0/360 boundary is continuous")
	check(not w.stations.fire(1,0,-.5),"Non-owner cannot fire")
	check(w.stations.fire(2,0,-.5),"Owner fires real snowball")
	check(not w.stations.fire(2,0,-.5),"Fire rate enforced")
	w.stations.last_fire = -1000
	check(not w.stations.fire(2,0,.35),"Fuselage blocks upward firing")
	check(w.stations.projectiles.balls.size() == 1,"Rejected shots create nothing")
	var select_right := InputEventKey.new()
	select_right.physical_keycode = KEY_2
	select_right.pressed = true
	w.stations.handle_input(select_right)
	check(w.stations.selected == 1,"2 selects right cargo launcher")
	w.queues.queues[1] = [{"id":999,"kind":1}]
	w.queues.remaining[1] = 0
	select_right.physical_keycode = KEY_SPACE
	w.stations.handle_input(select_right)
	check(w.queues.reserved[1] == 999 and w.queues.remaining[1]>0,"Space releases selected right launcher through real input")
	main.ui.show_page("pause")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	w.stations.handle_input(key)
	check(w.stations.occupants.delivery == 1,"Menu suppresses station input")
	main.ui.resume_game()
	w.stations.handle_input(key)
	check(w.stations.occupants.delivery == 0 and elf.cam.current,"Q restores walking camera")
	w.stations.drop_peer(2)
	check(w.stations.occupants.turret == 0,"Disconnect releases station")
	check(w.players[2].global_position.distance_to(w.bomber.to_global(w.stations.SEATS.turret))<.01,"Leaving pod restores safe cabin position")
	elf.global_position = w.bomber.to_global(w.HELM_POS)
	elf.head.look_at(w.bomber.to_global(w.stations.CONTROLS.turret))
	check(w.stations.aimed(1) != "turret","Sealed cockpit floor blocks hatch interaction from the helm")
	aim(1,w.stations.CONTROLS.turret,Vector3(0,.8,1.25))
	check(w.instruments.get_node("VentralControls_rig").position.distance_to(w.stations.CONTROLS.turret)<.001,"Hatch interaction matches exported entrance")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var enter_hatch := InputEventMouseButton.new()
	enter_hatch.button_index = MOUSE_BUTTON_LEFT
	enter_hatch.pressed = true
	w.set_held(1,1)
	elf._unhandled_input(enter_hatch)
	check(w.stations.occupants.turret == 0 and elf.held_kind == 1,"Hatch requires empty hands without throwing cargo")
	w.set_held(1,0)
	elf._unhandled_input(interact)
	check(w.stations.occupants.turret == 0,"Gun hatch uses click rather than E")
	elf._unhandled_input(enter_hatch)
	check(w.stations.occupants.turret == 1 and w.stations.turret_camera.current,"Click enters gun hatch from lower cabin")
	w.stations._physics_process(.1)
	check(w.stations.hatch.rotation.y < -.1,"Gunner hatch opens during entry")
	w.stations.climb_time = 0
	var before_yaw: float = w.stations.desired_yaw
	var before_pitch: float = w.stations.desired_pitch
	var look := InputEventMouseButton.new()
	look.button_index = MOUSE_BUTTON_RIGHT
	look.pressed = true
	w.stations.handle_input(look)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100,30)
	w.stations.handle_input(motion)
	check(w.stations.desired_yaw==before_yaw and w.stations.desired_pitch==before_pitch,"Free look does not drag station guns")
	check(w.stations.look_offset.length()>0 and w.stations.turret_camera.get_parent()==w.stations.turret_yaw,"Camera looks independently from seat yaw frame")
	check(w.stations.muzzle.get_parent()==w.stations.turret_pitch,"Gun muzzle belongs to turret rig, not player or camera")
	var exit_hatch := InputEventKey.new()
	exit_hatch.physical_keycode = KEY_CTRL
	exit_hatch.pressed = true
	main.ui.show_page("pause")
	elf._unhandled_input(exit_hatch)
	check(w.stations.occupants.turret == 1,"Menu suppresses Ctrl turret exit")
	main.ui.resume_game()
	elf._unhandled_input(exit_hatch)
	check(w.stations.occupants.turret == 0 and elf.cam.current,"Ctrl leaves turret and restores walking camera")
	check(w.bomber.to_local(elf.global_position).distance_to(w.stations.SEATS.turret)<.01,"Turret exit returns beside stairs, away from helm")
	for tick in 30:
		elf.velocity = Vector3(0,-2,2)
		elf.move_and_slide()
		await get_tree().physics_frame
	var exit_point: Vector3 = w.bomber.to_local(elf.global_position)
	check(absf(exit_point.y)<.12 and exit_point.z > -3.5,"Crew can walk away from the hatch without falling or catching the stairs")
	for tick in 90: w.stations._physics_process(1.0/60)
	check(is_zero_approx(w.stations.hatch.rotation.y),"Hatch closes after the crew transition")
	w.begin_level()
	check(w.queues.queues == [[],[]] and w.stations.projectiles.balls.is_empty(),"Reset clears queues and projectiles")
	if DisplayServer.get_name() != "headless": await captures()
	print("MK II CHECKS: ","PASS" if failures == 0 else "FAIL ("+str(failures)+")")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	get_tree().quit(failures)
func captures() -> void:
	w.hud_info.get_parent().hide()
	w.bomber.position.y = w.Airfield.PARK.y
	var parked_camera := Camera3D.new()
	w.bomber.add_child(parked_camera)
	parked_camera.position = Vector3(7,-1.5,-11)
	parked_camera.look_at(w.bomber.to_global(Vector3(1.75,-1.55,-7.3)))
	parked_camera.make_current()
	await snap("parked-turret")
	parked_camera.queue_free()
	w.bomber.position.y = 45
	w.grounded = false
	w.speed = 20
	w.throttle = .4
	w.in_steer = 0
	w.in_climb = 0
	w.in_throttle = 0
	w.previous_plane = w.bomber.transform
	w.moving_hull.transform = w.bomber.transform
	for rack in 2:
		for kind in [1,2,1,2,1]: load_item(rack,kind)
	w.set_held(1,0)
	await get_tree().create_timer(.4).timeout
	var camera := Camera3D.new()
	w.bomber.add_child(camera)
	camera.current = true
	for view in [{"name":"front","pos":Vector3(22,10,-24),"target":Vector3(0,0,0)}, {"name":"side","pos":Vector3(30,6,3),"target":Vector3(0,0,0)}, {"name":"rear","pos":Vector3(20,7,27),"target":Vector3(0,0,3)}, {"name":"underside","pos":Vector3(9,-9,10),"target":Vector3(0,-1,1)}, {"name":"cabin","pos":Vector3(0,1.8,6.5),"target":Vector3(0,1,1)}, {"name":"cockpit","pos":Vector3(0,3.15,-7),"target":Vector3(0,3.35,-12)}, {"name":"rear-stores","pos":Vector3(0,1.8,7.4),"target":Vector3(0,1.1,11)}, {"name":"queue","pos":Vector3(0,1.7,4.8),"target":Vector3(-2.22,1,2.7)}, {"name":"rear-passage","pos":Vector3(0,1.6,3.7),"target":Vector3(0,1.4,8.4)}, {"name":"gunner-entry","pos":Vector3(1.8,1.55,-3.3),"target":Vector3(1.9,.78,-5.55)}, {"name":"cockpit-landing","pos":Vector3(0,3.15,-5.75),"target":Vector3(0,2.35,-8.7)}, {"name":"stair-hatch","pos":Vector3(-.65,1.8,-.5),"target":Vector3(.7,1.65,-5.8)}]:
		camera.fov = 55 if view.name in ["front","side","rear"] else 75
		camera.position = view.pos
		camera.look_at(w.bomber.to_global(view.target))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.test-data/mk2-"+view.name+".png")

	w.set_held(1,0)
	aim(1,w.queues.slot(0,2),Vector3(.9,.2,0))
	w.queues.handle(1,"retrieve",0,w.queues.queues[0][2].id)
	await get_tree().create_timer(.35).timeout
	await snap("retrieved-middle")
	w.set_held(1,0)
	aim(1,w.stations.CONTROLS.delivery,Vector3(.9,.2,0))
	w.stations.occupy(1,"delivery")
	w.stations.set_physics_process(true)
	await get_tree().create_timer(.4).timeout
	await snap("delivery-console")
	w.bomber.position = w.chimneys[0].top+Vector3(1.32,40,56)
	w.moving_hull.transform = w.bomber.transform
	w.previous_plane = w.bomber.transform
	w.previous_plane.origin += Vector3(0,0,20*w.physics_delta)
	await get_tree().create_timer(.4).timeout
	await snap("targeting-flight")
	w.stations.request("leave")
	aim(1,w.stations.CONTROLS.turret,Vector3(0,.8,1.25))
	w.stations.occupy(1,"turret")
	w.stations.desired_pitch = -.65
	await get_tree().create_timer(1.15).timeout
	await snap("turret-camera")
	w.stations.request("leave")
	w.stations.set_physics_process(false)
	camera.make_current()
	camera.position = Vector3(5,-3.5,-11)
	camera.look_at(w.bomber.to_global(Vector3(1.75,-1.55,-7.3)))
	for angle in [0.0,PI/2,PI]:
		w.stations.turret_yaw.rotation.y = angle
		w.stations.turret_pitch.rotation.x = -.4
		await snap("turret-"+str(roundi(rad_to_deg(angle))))
	w.stations.occupants.delivery = 1
	w.queues.handle(1,"release",0)
	w.queues._physics_process(.2)
	await snap("chute-opening")
func snap(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.test-data/mk2-"+label+".png")
