extends Node
var main: Node
var w: Node3D
var is_host := false
var failures := 0
var chart_verified := false

@rpc("any_peer","reliable")
func verify_chart(seed_value: int, sites: int, chart_mark: Vector3) -> void:
	if not is_host: return
	check(seed_value == w.district.route_seed and sites == hash(w.district.sites),"Both processes generated identical delivery targets")
	check(chart_mark == w.mess.waypoint,"Late join restored pencil mark")
	chart_verified = true
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	is_host = "--host" in OS.get_cmdline_user_args()
	main = load("res://main.gd").new()
	main.name = "Main"
	add_child(main)
	var peer := ENetMultiplayerPeer.new()
	var port := 28764
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): port = argument.trim_prefix("--port=").to_int()
	peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(port,2) if is_host else peer.create_client("127.0.0.1",port)
	check(error == OK,"Loopback transport opens")
	if error != OK:
		get_tree().quit(1)
		return
	main.multiplayer.multiplayer_peer = peer
	main.operation = "host" if is_host else "join"
	main.deadline = Time.get_ticks_msec()+60000
	if is_host: main._start_world()
	for i in 400:
		if main.get_node_or_null("World"): break
		await get_tree().create_timer(.05).timeout
	w = main.get_node_or_null("World")
	if not w:
		print("TRANSPORT STATUS: ",peer.get_connection_status()," OPERATION ",main.operation," NOTICE ",main.ui.status.text)
		check(false,"Connected world starts")
		get_tree().quit(1)
		return
	if is_host: await host_checks()
	else: await client_checks()
	print("MK II LOOPBACK ","HOST" if is_host else "CLIENT",": ","PASS" if failures == 0 else "FAIL")
	main._return_to_menu()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	get_tree().quit(failures)
func host_checks() -> void:
	w.mess.set_mark(Vector3(90,0,-840))
	w.mess.earn(3)
	w.set_physics_process(false)
	w.players[1].set_physics_process(false)
	w.bomber.position.y = 60
	w.grounded = false
	w.speed = 20
	w.throttle = .4
	w.in_steer = .4
	w.in_throttle = .2
	w.in_climb = .1
	w.previous_plane = w.bomber.transform
	w.moving_hull.transform = w.bomber.transform
	w.queues.queues = [[{"id":101,"kind":1},{"id":102,"kind":2}],[{"id":103,"kind":2}]]
	w.queues.serial = 104
	w.queues.publish()
	w.stations.occupants.delivery = 1
	w.stations.occupancy(w.stations.occupants)
	for i in 1200:
		if w.stations.occupants.turret != 0: break
		await get_tree().create_timer(.05).timeout
	check(w.stations.occupants.turret != 0,"Remote station request accepted alongside host operator")
	check(chart_verified,"Remote chart compared against host district")
	check(w.mess.vouchers == 3 and w.mess.upgrades == 2 and not w.mess.dialogue.visible,"Client catalog orders charge shared funds, apply the sling, and leave host dialogue alone")
	var remote_id: int = w.stations.occupants.turret
	check(remote_id != 1,"Remote owner identity preserved")
	check(w.queues.handle(1,"release",0),"Host console begins discharge")
	for i in 160:
		if w.stations.occupants.turret == 0: break
		await get_tree().create_timer(.05).timeout
	check(w.stations.occupants.turret == 0,"Remote station exit replicates")
	await get_tree().create_timer(1).timeout
	check(w.queues.queues[0].size() == 1 and w.queues.queues[0][0].id == 102,"Network discharge preserves ordered IDs")
	w.begin_level()
	await get_tree().create_timer(1).timeout
func client_checks() -> void:
	var id := multiplayer.get_unique_id()
	for i in 160:
		if w.players.has(id) and w.queues.queues[0].size() == 2: break
		await get_tree().create_timer(.05).timeout
	check(w.queues.queues[0] == [{"id":101,"kind":1},{"id":102,"kind":2}],"Late join receives exact ordered mixed queue")
	check(w.stations.occupants.delivery == 1,"Late join receives station occupancy")
	check(w.mess.vouchers == 15 and w.mess.waypoint == Vector3(90,0,-840),"Late join receives quartermaster and map state")
	verify_chart.rpc_id(1,w.district.route_seed,hash(w.district.sites),w.mess.waypoint)
	check(absf(w.in_steer-.4)<.001 and absf(w.in_throttle-.2)<.001 and absf(w.in_climb-.1)<.001,"Client receives flight controls for delayed-release prediction")
	var elf = w.players[id]
	elf.set_physics_process(false)
	elf.position = Vector3(-32.1,.12,841)
	var chart_direction: Vector3 = (w.mess.props[0].position-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-chart_direction.x,-chart_direction.z)
	elf.pitch = asin(chart_direction.y)
	elf.head.rotation.x = elf.pitch
	main.sync_elf.rpc(elf.position,elf.rotation.y,elf.pitch,false,true)
	await get_tree().create_timer(.5).timeout
	w.mess.request("prop0")
	for i in 40:
		if w.mess.held(id) == 0: break
		await get_tree().create_timer(.05).timeout
	check(w.mess.held(id) == 0,"Client picks up the shared chart via host")
	w.mess.request("drop")
	await get_tree().create_timer(.2).timeout
	check(w.mess.held(id) < 0,"Host replicates chart release")
	elf.position = Vector3(-28.4,.1,836.6)
	var clerk_direction: Vector3 = (w.mess.CLERK_FACE-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-clerk_direction.x,-clerk_direction.z)
	elf.pitch = asin(clerk_direction.y)
	elf.head.rotation.x = elf.pitch
	main.sync_elf.rpc(elf.position,elf.rotation.y,elf.pitch,false,true)
	await get_tree().create_timer(.5).timeout
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	elf._unhandled_input(interact)
	var shop = w.mess.dialogue
	check(shop.line_id == "offer","Client sees the clerk's opening question")
	shop.get_node("%Browse").pressed.emit()
	shop.buy_buttons[2].pressed.emit()
	for i in 60:
		if shop.line_id == "issued_present" and elf.held_kind == w.Cargo.Kind.PRESENT: break
		await get_tree().create_timer(.05).timeout
	check(elf.held_kind == w.Cargo.Kind.PRESENT and w.mess.vouchers == 13 and shop.buy_buttons[2].disabled,"Client receives usable gift cargo and the updated shop balance")
	shop.buy_buttons[1].pressed.emit()
	for i in 60:
		if shop.line_id == "issued_sling" and w.mess.vouchers == 3: break
		await get_tree().create_timer(.05).timeout
	check(shop.line_id == "issued_sling" and w.mess.vouchers == 3 and shop.buy_buttons[1].text == "Issued","Buying client receives the upgrade, balance and spoken receipt")
	shop.close()
	w.cargo_action("drop")
	await get_tree().create_timer(.2).timeout
	var point: Vector3 = w.stations.CONTROLS.turret
	elf.global_position = w.bomber.to_global(point+Vector3(0,.8,1.25)-Vector3.UP*elf.head.position.y)
	var direction: Vector3 = (w.bomber.to_global(point)-elf.head.global_position).normalized()
	elf.rotation.y = atan2(-direction.x,-direction.z)
	elf.pitch = asin(direction.y)
	elf.head.rotation.x = elf.pitch
	main.sync_elf.rpc(elf.position,elf.rotation.y,elf.pitch,false,true)
	await get_tree().create_timer(.5).timeout
	w.stations.request("turret")
	for i in 400:
		if w.stations.occupants.turret == id: break
		await get_tree().create_timer(.05).timeout
	check(w.stations.occupants.turret == id,"Client owns independent turret")
	for i in 400:
		if w.queues.queues[0].size() == 1: break
		await get_tree().create_timer(.05).timeout
	check(w.queues.queues[0].size() == 1 and w.queues.queues[0][0].id == 102,"Reliable release reconciles physical queue")
	check(w.stations.turret_camera.current,"Client receives station camera")
	w.stations.request("leave")
	await get_tree().create_timer(.4).timeout
	check(elf.cam.current,"Remote station exit restores walking camera")
	for i in 400:
		if w.queues.queues == [[],[]]: break
		await get_tree().create_timer(.05).timeout
	check(w.queues.queues == [[],[]],"World reset reliably clears remote queues")

