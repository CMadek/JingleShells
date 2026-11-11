extends Node

const DEFAULTS := {"mode": 0, "resolution": 0, "vsync": true, "fps": 120, "fov": 75.0, "volume": 80.0, "sensitivity": 1.0, "invert": false}
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var values: Dictionary = DEFAULTS.duplicate()
var menu_open := true
var steam: Object
var steam_ready := false

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		var result: Dictionary = steam.steamInitEx(480, true)
		steam_ready = int(result.get("status", -1)) == 0 and ClassDB.class_exists("SteamMultiplayerPeer")
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key in DEFAULTS:
			var value = config.get_value("settings", key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]):
				values[key] = value
	values.mode = clampi(values.mode, 0, 2)
	values.resolution = clampi(values.resolution, 0, 2)
	values.fps = clampi(values.fps, 0, 360)
	values.fov = clampf(values.fov, 60, 110)
	values.volume = clampf(values.volume, 0, 100)
	values.sensitivity = clampf(values.sensitivity, 0.2, 3)
	apply_settings()
	for entry in [["move_forward", KEY_W], ["move_back", KEY_S], ["move_left", KEY_A], ["move_right", KEY_D], ["jump", KEY_SPACE], ["descend", KEY_SHIFT], ["interact", KEY_E], ["drop_cargo", KEY_G], ["pilot_view", KEY_V]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		InputMap.action_add_event(entry[0], event)

func apply_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, values.mode == 1)
	if values.mode == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif values.mode == 1:
		DisplayServer.window_set_size(DisplayServer.screen_get_size())
		DisplayServer.window_set_position(DisplayServer.screen_get_position())
	else:
		DisplayServer.window_set_size(RESOLUTIONS[values.resolution])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = values.fps
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(values.volume / 100.0, 0.0001)))
	AudioServer.set_bus_mute(0, values.volume == 0)
	for camera in get_tree().get_nodes_in_group("local_camera"):
		camera.fov = values.fov

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings", key, values[key])
	config.save("user://settings.cfg")
