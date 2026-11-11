extends Node
func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/elf/" + name + ".png")
func _ready() -> void:
	var main = load("res://main.gd").new()
	add_child(main)
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	var world = main.get_node("World")
	var elf = world.players[1]
	await get_tree().physics_frame
	print("ANIMATIONS: ", elf.presentation.animation.get_animation_list())
	Input.action_press("crouch")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(elf.crouched)
	assert(is_equal_approx(elf.capsule_node.shape.height, 1.15))
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,.15,2)
	collider.shape = shape
	ceiling.add_child(collider)
	world.bomber.add_child(ceiling)
	ceiling.position = elf.position + Vector3(0,1.5,0)
	for i in range(3): await get_tree().physics_frame
	Input.action_release("crouch")
	for i in range(4): await get_tree().physics_frame
	assert(elf.crouched, "Ceiling blocks standing")
	main.ui.show_page("pause")
	for i in range(4): await get_tree().physics_frame
	assert(elf.crouched, "Menus must respect clearance")
	ceiling.queue_free()
	for i in range(4): await get_tree().physics_frame
	assert(not elf.crouched)
	main.ui.resume_game()
	elf.position = Vector3(0,.05,0)
	elf.rotation.y = 0
	elf.set_physics_process(false)
	world.set_physics_process(false)
	# Both sleigh ladder directions must survive the character integration.
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	elf.position = Vector3(1.14, .03, -.83)
	assert(elf.at_ladder())
	elf._unhandled_input(interact)
	assert(elf.position.is_equal_approx(Vector3(.55, 2.19, -2.80)))
	assert(elf.at_ladder())
	elf._unhandled_input(interact)
	assert(elf.position.is_equal_approx(Vector3(1.14, .03, -.83)))
	elf.position = Vector3(0, .05, 0)
	elf.carry(1)
	await get_tree().create_timer(.5).timeout
	await snap("hands_present")
	elf.carry(2)
	await snap("hands_bomb")
	elf.carry(0)
	await get_tree().create_timer(.5).timeout
	await snap("hands_empty")
	var camera := Camera3D.new()
	world.bomber.add_child(camera)
	camera.current = true
	camera.position = Vector3(0,1.25,-3.0)
	camera.look_at(elf.to_global(Vector3(0,1.0,0)))
	await snap("elf_front")
	camera.position = Vector3(2.8,1.25,0)
	camera.look_at(elf.to_global(Vector3(0,1.0,0)))
	await snap("elf_side")
	camera.position = Vector3(0,1.25,3)
	camera.look_at(elf.to_global(Vector3(0,1.0,0)))
	await snap("elf_back")
	elf.crouched = true
	await get_tree().create_timer(.5).timeout
	camera.position = Vector3(2.8,1.25,0)
	camera.look_at(elf.to_global(Vector3(0,.8,0)))
	await snap("elf_crouch")
	world.add_player(2)
	var remote = world.players[2]
	assert(remote.capsule_node.shape != elf.capsule_node.shape)
	world.crew_posture(2, true, true)
	assert(remote.crouched)
	world.set_held(2, 1)
	world.crew_action(2, "charge")
	assert(remote.presentation.charge_pose)
	world.crew_action(2, "cancel")
	assert(not remote.presentation.charge_pose)
	assert(remote.held_kind == 1)
	print("PASS crouch clearance, menu release, assets and screenshots")
	get_tree().quit()

