extends Node

const MIN_FPS := 30
const MAX_FPS := 360
const DEFAULTS := {"mode": 0, "resolution": 0, "vsync": true, "fps": 120, "unlocked_fps": false, "fov": 75.0, "volume": 80.0, "sensitivity": 1.0, "invert": false, "menu_motion": true}
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var values: Dictionary = DEFAULTS.duplicate()
var bindings := preload("res://input_bindings.gd").new()
var menu_open := true
var steam: Object
var steam_ready := false

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		var result: Dictionary = steam.steamInitEx(480, true)
		steam_ready = int(result.get("status", -1)) == 0 and ClassDB.class_exists("SteamMultiplayerPeer")
	var config := ConfigFile.new()
	var settings_error := config.load("user://settings.cfg")
	if settings_error == ERR_FILE_NOT_FOUND:
		# One-time compatibility with the old title's sibling Godot data directory.
		settings_error = config.load(OS.get_user_data_dir().get_base_dir().path_join("Jingle Bells/settings.cfg"))
	if settings_error == OK:
		values = settings_from_config(config)
	apply_settings()
	bindings.apply(bindings.from_config(config))

func settings_from_config(config: ConfigFile) -> Dictionary:
	var settings := DEFAULTS.duplicate()
	for key in DEFAULTS:
		var value = config.get_value("settings", key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]):
			settings[key] = value
	# Older versions stored an unlimited frame rate as a zero cap.
	if settings.fps == 0 and not config.has_section_key("settings", "unlocked_fps"):
		settings.unlocked_fps = true
		settings.fps = DEFAULTS.fps
	settings.mode = clampi(settings.mode, 0, 2)
	settings.resolution = clampi(settings.resolution, 0, RESOLUTIONS.size() - 1)
	settings.fps = clampi(settings.fps, MIN_FPS, MAX_FPS)
	settings.fov = clampf(settings.fov, 60, 110)
	settings.volume = clampf(settings.volume, 0, 100)
	settings.sensitivity = clampf(settings.sensitivity, 0.2, 3)
	return settings

func apply_settings(update_window := true) -> void:
	if update_window:
		_apply_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	values.fps = clampi(values.fps, MIN_FPS, MAX_FPS)
	Engine.max_fps = 0 if values.unlocked_fps else values.fps
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(values.volume / 100.0, 0.0001)))
	AudioServer.set_bus_mute(0, values.volume == 0)
	for camera in get_tree().get_nodes_in_group("local_camera"):
		camera.fov = values.fov

func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, values.mode == 1)
	if values.mode == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif values.mode == 1:
		DisplayServer.window_set_size(DisplayServer.screen_get_size())
		DisplayServer.window_set_position(DisplayServer.screen_get_position())
	else:
		DisplayServer.window_set_size(RESOLUTIONS[values.resolution])

func save_settings(mapping: Dictionary = bindings.codes) -> Error:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings", key, values[key])
	for action in mapping:
		config.set_value("bindings", action, mapping[action])
	return config.save("user://settings.cfg")

func save_bindings(mapping: Dictionary) -> Error:
	var error := save_settings(mapping)
	if error == OK:
		bindings.apply(mapping)
	return error
