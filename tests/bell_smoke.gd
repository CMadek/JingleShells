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
	var world = main.get_node("World")
	var elf = world.players[1]
	var bell = world.departure_bell
	world.set_physics_process(false)
	elf.set_physics_process(false)
	await get_tree().physics_frame
	check(bell.ring_count == 0 and not bell.sound.playing,"Bell starts silent")
	check(bell.sound.stream.get_length() > 3 and bell.sound.bus == "Master","Chime uses normal volume settings")
	bell.handle_pull(1)
	check(bell.ring_count == 0,"Cannot ring from depot")
	elf.global_position = world.bomber.to_global(Vector3(1.1,0,5.25))
	elf.head.look_at(bell.to_global(bell.HANDLE))
	await get_tree().physics_frame
	check(bell.aimed(elf.head.global_transform),"Rope is reachable from rear cabin")
	var e := InputEventAction.new()
	e.action = "interact"
	e.pressed = true
	Game.menu_open = true
	elf._unhandled_input(e)
	check(bell.ring_count == 0,"Menu suppresses pull")
	Game.menu_open = false
	elf._unhandled_input(e)
	check(bell.ring_count == 1 and bell.sound.playing,"E rings bell and plays chime")
	elf._unhandled_input(e)
	check(bell.ring_count == 1,"Rapid pulls are limited")
	bell._process(.12)
	check(bell.rope.position.y < -.1 and absf(bell.bell.rotation.z) > .05,"Rope and bell animate")
	if DisplayServer.get_name() != "headless":
		var saved_position: Vector3 = elf.global_position
		elf.global_position = world.Airfield.SPAWN
		var preview := Camera3D.new()
		world.bomber.add_child(preview)
		preview.position = Vector3(.2,1.8,5.25)
		preview.look_at(bell.to_global(Vector3(0,-.55,0)))
		preview.current = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.test-data/departure-bell.png")
		elf.global_position = saved_position
	bell._process(5)
	check(is_zero_approx(bell.rope.position.y) and is_zero_approx(bell.bell.rotation.z),"Bell returns to rest")
	# Validate occlusion independently of the cooldown.
	bell.last_pull_ms = -bell.COOLDOWN_MS
	var wall := StaticBody3D.new()
	world.bomber.add_child(wall)
	world._box(wall,Vector3(.1,2,1),Vector3(1.8,1,5.25),Color.GRAY,false,wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	bell.handle_pull(1)
	check(bell.ring_count == 1,"Cannot ring through cabin walls")
	print("BELL CHECKS: ","PASS" if failures == 0 else "FAIL")
	main._return_to_menu("Bell smoke complete")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(failures)
