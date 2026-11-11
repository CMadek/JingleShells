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
	main.ui.show_page("pause")
	assert(Game.menu_open)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	elf._unhandled_input(event)
	assert(elf.charging_since == -1)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(not get_tree().paused)
	main.ui.resume_game()
	assert(not Game.menu_open)
	main._return_to_menu("Test disconnect")
	assert(main.get_node_or_null("World") == null)
	assert(Game.menu_open)
	main.ui.show_page("main")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.test-data/main-menu.png")
	print("PASS: menu navigation, settings persistence/reversion, offline world lifecycle, input suppression and resume")
	get_tree().quit()
