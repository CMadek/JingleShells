extends Node

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func mouse(code: MouseButton, pressed := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	return event

func _ready() -> void:
	var saved := Game.bindings.codes.duplicate()
	if "--expect-saved-orbit" in OS.get_cmdline_user_args():
		check(key(KEY_B).is_action_pressed("pilot_orbit"), "Fresh process loads the saved orbit binding")
	var main = preload("res://main.gd").new()
	add_child(main)
	main.ui.show_page("options")
	main.ui.select_tab(2)
	await get_tree().process_frame
	main.ui.commit_bindings(Game.bindings.defaults())
	main.ui.draft.volume = 13
	main.ui.binding_buttons.pilot_orbit.pressed.emit()
	get_viewport().push_input(key(KEY_V), true)
	check(main.ui.capture_action == "pilot_orbit" and "Switch pilot view" in main.ui.binding_buttons.pilot_orbit.text, "Conflicting action is named")
	get_viewport().push_input(key(KEY_ESCAPE), true)
	get_viewport().push_input(key(KEY_ESCAPE, false), true)
	check(main.ui.page == "options" and main.ui.capture_action == "", "Escape cancels only capture")
	main.ui.binding_buttons.pilot_orbit.pressed.emit()
	get_viewport().push_input(key(KEY_B), true)
	get_viewport().push_input(key(KEY_B, false), true)
	check(not mouse(MOUSE_BUTTON_RIGHT).is_action_pressed("pilot_orbit"), "Old orbit binding removed")
	main.ui.binding_buttons.launcher_right.pressed.emit()
	get_viewport().push_input(mouse(MOUSE_BUTTON_MIDDLE), true)
	get_viewport().push_input(mouse(MOUSE_BUTTON_MIDDLE, false), true)
	var config := ConfigFile.new()
	check(config.load("user://settings.cfg") == OK, "Bindings saved immediately")
	check(config.get_value("settings", "volume") == Game.values.volume, "Saving preserves unapplied volume draft")
	check(Game.bindings.from_config(config) == Game.bindings.codes, "All settings reload")
	config.set_value("bindings", "launcher_leave", -99)
	config.set_value("bindings", "turret_leave", "bad")
	config.set_value("bindings", "move_forward", KEY_S)
	config.erase_section_key("bindings", "jump")
	var repaired := Game.bindings.from_config(config)
	check(repaired.launcher_leave == KEY_Q and repaired.turret_leave == KEY_CTRL and repaired.move_forward == KEY_W and repaired.jump == KEY_SPACE, "Invalid, conflicting, and missing bindings recover")
	check(repaired.pilot_orbit == KEY_B, "Recovery retains unrelated custom bindings")
	config.erase_section_key("bindings", "cruise_hold")
	config.set_value("bindings", "descend", KEY_C)
	repaired = Game.bindings.from_config(config)
	check(repaired.descend == KEY_C and repaired.cruise_hold != KEY_C
		and Game.bindings.conflict("cruise_hold", repaired.cruise_hold, repaired) == "",
		"Existing pilots keep custom C bindings when cruise hold is added")
	config.erase_section_key("bindings", "aerobatics")
	config.set_value("bindings", "pilot_view", KEY_R)
	repaired = Game.bindings.from_config(config)
	check(repaired.pilot_view == KEY_R and Game.bindings.conflict("aerobatics", repaired.aerobatics, repaired) == "",
		"Existing pilots keep a custom R binding when aerobatics is added")
	config.erase_section_key("bindings", "afterburner")
	config.set_value("bindings", "move_forward", KEY_F)
	repaired = Game.bindings.from_config(config)
	check(repaired.move_forward == KEY_F and Game.bindings.conflict("afterburner", repaired.afterburner, repaired) == "",
		"Adding afterburner preserves a pilot's previous F binding")

	main.operation = "host"
	main.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	main._start_world()
	var world = main.get_node("World")
	var elf = world.players[1]
	world.set_pilot(1)
	world.toggle_pilot_view()
	get_viewport().push_input(key(KEY_B), true)
	check(elf.dragging_orbit, "Rebound key starts chase orbit")
	get_viewport().push_input(key(KEY_B, false), true)
	check(not elf.dragging_orbit, "Release ends chase orbit")
	world.stations.active_local = "delivery"
	world.stations.handle_input(mouse(MOUSE_BUTTON_MIDDLE))
	check(world.stations.selected == 1, "Mouse selects rebound launcher")
	world.stations.active_local = ""
	main._return_to_menu()
	main.ui.show_page("options")
	main.ui.commit_bindings(Game.bindings.defaults())
	check(mouse(MOUSE_BUTTON_RIGHT).is_action_pressed("pilot_orbit"), "Reset restores default orbit")
	check(not key(KEY_B).is_action_pressed("pilot_orbit"), "Reset clears previous override")
	config.load("user://settings.cfg")
	check(Game.bindings.from_config(config) == Game.bindings.defaults(), "Reset persists")
	Game.save_bindings(saved)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	print("BINDING CHECKS: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
