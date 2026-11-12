extends Node
var main: Node
var w: Node3D
var is_host := false
var failures := 0
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
	var error := peer.create_server(28764,2) if is_host else peer.create_client("127.0.0.1",28764)
	check(error == OK,"Loopback transport opens")
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
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	get_tree().quit(failures)
func host_checks() -> void:
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
	check(absf(w.in_steer-.4)<.001 and absf(w.in_throttle-.2)<.001 and absf(w.in_climb-.1)<.001,"Client receives flight controls for delayed-release prediction")
	var elf = w.players[id]
	elf.set_physics_process(false)
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

