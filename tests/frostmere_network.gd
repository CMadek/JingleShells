extends "res://tests/flight_network.gd"
## Exercise host settlement, replicated jam recovery and player two carrying a real lounge prop.

func drop_order(index: int, chimney: bool = false, wrong := false) -> void:
	var house: Dictionary = w.recipients.houses[w.district.stops[index]]
	var id: int = w.next_item
	w.next_item += 1
	w.show_loose.rpc(id,w.Cargo.Kind.PRESENT if wrong else w.contract.ORDERS[index],Transform3D(Basis.IDENTITY,house.base))
	var collider: Node = house.root
	if chimney:
		for child in collider.get_children():
			if child.has_meta("chimney"): collider = child
	w._resolve_impact(id,collider,house.base)

func host_checks() -> void:
	w.set_physics_process(false)
	w.grounded = false
	w.contract.tick(1)
	drop_order(0,true)
	drop_order(0,true)
	check(w.contract.pending == 15 and w.mess.vouchers == 12,"Duplicate address awards no extra pending pay")
	w.contract.tick(901)
	w.roll = deg_to_rad(25)
	w.queues.queues = [[{"id":1,"kind":1}],[{"id":2,"kind":1}]]
	w.queues.serial = 3
	w.stations.occupants.delivery = 1
	w.queues.handle(1,"release",0)
	check(w.queues.jammed == 0 and w.queues.queues[0].size() == 1,"Banked release jams and retains the head parcel")
	check(w.queues.handle(1,"release",1),"Other chute can release")
	w.roll = 0
	var deadline := Time.get_ticks_msec() + 12000
	while w.queues.queues[1].is_empty() or w.queues.queues[1][0].id < 3:
		if Time.get_ticks_msec() >= deadline:
			check(false,"Player two's throw reaches the starboard rack")
			return
		await get_tree().physics_frame
		w._step_cargo(1.0/60)
	if not await until(func(): return w.mess.holders[1] > 1,"Client picks up practice present"): return
	var pilot = w.players[w.mess.holders[1]]
	if not await until(func(): return pilot.presentation.current == "carry_walk","Host sees player two walking with the parcel"): return
	check(w.mess.prop_visuals[1].get_parent() == pilot.presentation.socket,"Remote prop rides the animated socket")
	if not await until(func(): return w.queues.jammed < 0,"Player two physically clears the jam"): return
	drop_order(1, false, true)
	check(w.contract.delivered[1] == 0 and w.contract.pending == 15, "A gift cannot satisfy a coal order")
	for i in range(1,6):
		for parcel in w.contract.REQUIRED[i]: drop_order(i)
	check(w.contract.pending == 125 and w.contract.completed() == 6,"Six full addresses accumulated unpaid earnings")
	w.grounded = true
	w.speed = 0
	w.contract.tick(.1)
	check(w.mess.vouchers == 137 and w.contract.pending == 0,"Runway stop banks exactly once")
	await get_tree().create_timer(.6).timeout
	w.grounded = false
	w.contract.tick(.1)
	drop_order(0)
	w.contract.tick(w.contract.WINDOW+1)
	check(w.mess.vouchers == 137 and not w.contract.active,"Closure forfeits only the second flight")
	await get_tree().create_timer(.8).timeout

func client_checks() -> void:
	var id := multiplayer.get_unique_id()
	if not await until(func(): return w.players.has(id) and w.queues.jammed == 0 and w.contract.pending == 15,"Late join receives manifest, earnings and jam"): return
	check(w.contract.seconds <= 180 and w.weather_env.fog_density > .006,"Player two sees closing weather")
	var elf = w.players[id]
	elf.global_position = w.bomber.to_global(Vector3(-.42, .04, 8.20))
	var stock: Vector3 = w.bomber.to_global(Vector3(-1.48, .44, 8.20))
	var aim: Vector3 = (stock - elf.head.global_position).normalized()
	elf.rotation.y = atan2(-aim.x, -aim.z)
	elf.pitch = asin(aim.y)
	elf.head.rotation.x = elf.pitch
	elf._share_pose(true, true)
	await get_tree().create_timer(.4).timeout
	check(w.aimed_pile(elf.head.global_transform) == w.Cargo.Kind.PRESENT, "Player two can aim at the parcel pile")
	w.cargo_action("pickup")
	if not await until(func(): return elf.held_kind == w.Cargo.Kind.PRESENT, "Host confirms player two's pile pickup"): return
	elf.global_position = w.bomber.to_global(Vector3(0,.04,7.44))
	aim = (w.bomber.to_global(w.queues.mouth(1)+Vector3.UP*.34)-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-aim.x,-aim.z)
	elf.pitch = asin(aim.y)
	elf.head.rotation.x = elf.pitch
	elf._share_pose(true,true)
	w.cargo_action("charge")
	await get_tree().create_timer(1.1).timeout
	w.cargo_action("throw")
	if not await until(func(): return elf.held_kind == 0 and w.queues.queues[1].size() == 1 and w.queues.queues[1][0].id >= 3, "Remote throw loads and replicates the available rack"): return
	var point: Vector3 = w.mess.props[1].global_position
	elf.global_position = point + Vector3(0,-point.y+.1,1.2)
	var direction: Vector3 = (point-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-direction.x,-direction.z)
	elf.pitch = asin(direction.y)
	elf.head.rotation.x = elf.pitch
	await get_tree().create_timer(.4).timeout
	w.mess.request("prop1")
	if not await until(func(): return w.mess.held(id) == 1,"Local pickup confirmed"): return
	var carried: Node3D = w.mess.prop_visuals[1]
	Input.action_press("move_right")
	for tick in 30:
		await get_tree().physics_frame
		check(carried.global_position.distance_to(elf.presentation.socket.global_position)<.001,"Held item stays in player two's hands between snapshots")
	Input.action_release("move_right")
	w.mess.request("drop")
	if not await until(func(): return w.mess.held(id) < 0,"Release returns ownership to host physics"): return
	elf.set_physics_process(false)
	point = w.queues.loader(0)
	elf.global_position = w.bomber.to_global(point+Vector3(0,.6,1.2)-Vector3.UP*elf.head.position.y)
	direction = (w.bomber.to_global(point)-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-direction.x,-direction.z)
	elf.pitch = asin(direction.y)
	elf.head.rotation.x = elf.pitch
	elf._share_pose(true,true)
	await get_tree().create_timer(.55).timeout
	w.queues.interact(id)
	if not await until(func(): return w.mess.vouchers == 137 and w.contract.receipt.contains("banked"),"Client receives bank receipt"): return
	if not await until(func(): return w.contract.receipt.contains("forfeited"),"Client sees subsequent failure"): return
	check(w.mess.vouchers == 137 and w.contract.pending == 0,"Banked money survives on both peers")
