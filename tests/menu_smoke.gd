extends Node

func _ready() -> void:
	await get_tree().process_frame
	var main = load("res://main.gd").new()
	add_child(main)
	await get_tree().process_frame
	for page in ["play", "join", "help", "credits", "options", "main"]:
		main.ui.show_page(page)
		await get_tree().process_frame
		assert(main.ui.root.visible)
	main.ui.show_page("options")
	var saved: Dictionary = Game.values.duplicate()
	main.ui.draft.volume = 65.0
	main.ui.apply_options()
	assert(Game.values.volume == 65.0)
	var config := ConfigFile.new()
	assert(config.load("user://settings.cfg") == OK)
	assert(config.get_value("settings", "volume") == 65.0)
	main.ui.show_page("options")
	main.ui.draft.mode = 2 if Game.values.mode != 2 else 0
	main.ui.apply_options()
	assert(is_instance_valid(main.ui.display_dialog))
	main.ui._revert_display()
	assert(Game.values.mode == saved.mode)
	Game.values = saved
	Game.apply_settings()
	Game.save_settings()
	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	await get_tree().process_frame
	assert(not Game.menu_open)
	var world = main.get_node("World")
	var elf = world.players[1]
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size / 2.0
	motion.global_position = motion.position
	motion.relative = Vector2(20, 10)
	var initial_yaw: float = elf.rotation.y
	get_viewport().push_input(motion, true)
	if is_equal_approx(elf.rotation.y, initial_yaw):
		push_error("Mouse look did not receive motion through the HUD")
		get_tree().quit(1)
		return
	main.ui.show_page("pause")
	assert(Game.menu_open)
	var paused_yaw: float = elf.rotation.y
	get_viewport().push_input(motion, true)
	assert(is_equal_approx(elf.rotation.y, paused_yaw))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://flight-menu.png")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	elf._unhandled_input(event)
	assert(elf.charging_since == -1)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(not get_tree().paused)
	main.ui.resume_game()
	assert(not Game.menu_open)
	get_viewport().push_input(motion, true)
	assert(not is_equal_approx(elf.rotation.y, paused_yaw))
	# The sleigh's pilot camera must coexist with menu input suppression.
	assert(InputMap.has_action("pilot_view"))
	world.set_pilot(1)
	var switch_view := InputEventAction.new()
	switch_view.action = "pilot_view"
	switch_view.pressed = true
	get_viewport().push_input(switch_view, true)
	assert(elf.chase.current)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(elf.presentation.model.visible, "Pilot body must appear in chase view")
	assert(not elf.presentation.hands.visible, "First-person arms must stay hidden at the helm")
	var orbit_button := InputEventMouseButton.new()
	orbit_button.button_index = MOUSE_BUTTON_RIGHT
	orbit_button.position = motion.position
	orbit_button.pressed = true
	get_viewport().push_input(orbit_button, true)
	assert(elf.dragging_orbit)
	var before_orbit: float = elf.orbit_yaw
	get_viewport().push_input(motion, true)
	assert(not is_equal_approx(elf.orbit_yaw, before_orbit))
	main.ui.show_page("pause")
	assert(not elf.dragging_orbit)
	before_orbit = elf.orbit_yaw
	get_viewport().push_input(motion, true)
	get_viewport().push_input(switch_view, true)
	assert(is_equal_approx(elf.orbit_yaw, before_orbit) and elf.chase.current)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(world.in_throttle == 0.0 and world.in_climb == 0.0)
	Input.action_release("move_forward")
	Input.action_release("jump")
	main.ui.resume_game()
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(not elf.dragging_orbit)
	get_viewport().push_input(switch_view, true)
	assert(elf.cam.current)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not elf.presentation.model.visible, "Pilot body must hide in cockpit view")
	world.set_pilot(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(elf.presentation.hands.visible, "First-person arms must return after leaving helm")
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	main._return_to_menu("Test disconnect")
	assert(main.get_node_or_null("World") == null)
	assert(Game.menu_open)
	main.ui.show_page("options")
	main.ui.draft.mode = 2 if Game.values.mode != 2 else 0
	main.ui.apply_options()
	main._return_to_menu("Disconnected during display confirmation")
	assert(Game.values.mode == saved.mode)
	assert(not is_instance_valid(main.ui.display_dialog))
	main.ui.show_page("main")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://main-menu.png")
	print("PASS: menu navigation, settings persistence/reversion, offline world lifecycle, input suppression and resume")
	get_tree().quit()
