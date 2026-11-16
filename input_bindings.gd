extends RefCounted

# Context masks allow the same button in mutually exclusive seats.
const WALK := 1
const PILOT := 2
const DELIVERY := 4
const TURRET := 8
const SETTINGS := 16
const FLIGHT := WALK | PILOT | DELIVERY | TURRET

# Physical keycodes are positive; mouse buttons use their negative index.
const ACTIONS := {
	"move_forward": ["Move forward / Throttle up", KEY_W, WALK | PILOT],
	"move_back": ["Move back / Brake", KEY_S, WALK | PILOT],
	"move_left": ["Move / Steer left", KEY_A, WALK | PILOT],
	"move_right": ["Move / Steer right", KEY_D, WALK | PILOT],
	"jump": ["Jump / Climb", KEY_SPACE, WALK | PILOT],
	"descend": ["Descend", KEY_SHIFT, PILOT],
	"crouch": ["Crouch", KEY_CTRL, WALK],
	"interact": ["Interact / Leave helm", KEY_E, WALK | PILOT],
	"drop_cargo": ["Drop cargo", KEY_G, WALK],
	"crew_primary": ["Throw cargo / Enter gun hatch", -MOUSE_BUTTON_LEFT, WALK],
	"show_chart": ["Offer flight chart", KEY_R, WALK],
	"mark_chart": ["Mark flight chart", -MOUSE_BUTTON_RIGHT, WALK],
	"pilot_view": ["Switch pilot view", KEY_V, PILOT],
	"aerobatics": ["Toggle aerobatic flight", KEY_R, PILOT],
	"afterburner": ["Hold afterburner", KEY_F, PILOT],
	"cruise_hold": ["Toggle cruise hold", KEY_C, PILOT],
	"pilot_orbit": ["Orbit chase camera", -MOUSE_BUTTON_RIGHT, PILOT],
	"launcher_left": ["Select left launcher", KEY_1, DELIVERY],
	"launcher_right": ["Select right launcher", KEY_2, DELIVERY],
	"launcher_release": ["Release cargo", KEY_SPACE, DELIVERY],
	"launcher_leave": ["Leave console", KEY_Q, DELIVERY],
	"turret_fire": ["Fire snowball", -MOUSE_BUTTON_LEFT, TURRET],
	"turret_look": ["Look around turret", -MOUSE_BUTTON_RIGHT, TURRET],
	"turret_leave": ["Leave turret", KEY_CTRL, TURRET],
	"flight_menu": ["Open flight menu", KEY_ESCAPE, FLIGHT],
	"previous_tab": ["Previous settings tab", KEY_Q, SETTINGS],
	"next_tab": ["Next settings tab", KEY_E, SETTINGS],
}
const MOUSE_NAMES := {
	-MOUSE_BUTTON_LEFT: "Left mouse", -MOUSE_BUTTON_RIGHT: "Right mouse",
	-MOUSE_BUTTON_MIDDLE: "Middle mouse", -MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	-MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}
var codes := {}
var labels := {}

func defaults() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = ACTIONS[action][1]
	return result

func from_config(config: ConfigFile) -> Dictionary:
	var result := defaults()
	for action in ACTIONS:
		var code = config.get_value("bindings", action, result[action])
		if typeof(code) == TYPE_INT and allowed(action, code):
			result[action] = code
	# Preserve older custom bindings when a newly introduced action needs a key.
	for action in ["cruise_hold", "aerobatics", "afterburner"]:
		if config.has_section_key("bindings", action) or conflict(action, result[action], result) == "": continue
		for code in range(KEY_A, KEY_Z + 1):
			if conflict(action, code, result) == "":
				result[action] = code
				break
	# Keep valid swaps. Reverting a collision can expose another default collision.
	while true:
		var repair := []
		for action in ACTIONS:
			if result[action] != ACTIONS[action][1] and conflict(action, result[action], result) != "":
				repair.append(action)
		if repair.is_empty():
			break
		for action in repair:
			result[action] = ACTIONS[action][1]
	return result

func allowed(action: String, code: int) -> bool:
	if code < 0:
		return MOUSE_NAMES.has(code) and ACTIONS[action][2] != SETTINGS
	if code == KEY_ESCAPE:
		return action == "flight_menu"
	if code < KEY_SPACE or code >= KEY_UNKNOWN or (code > 0x10ffff and code < KEY_SPECIAL):
		return false
	var key_name := OS.get_keycode_string(code)
	return not key_name.is_empty() and OS.find_keycode_from_string(key_name) == code

func conflict(action: String, code: int, mapping: Dictionary) -> String:
	for other in ACTIONS:
		if other != action and mapping[other] == code and (ACTIONS[action][2] & ACTIONS[other][2]) != 0:
			return other
	return ""

func event_code(event: InputEvent) -> int:
	if event is InputEventKey:
		return event.physical_keycode
	if event is InputEventMouseButton:
		return -event.button_index
	return 0

func apply(mapping: Dictionary) -> void:
	for action in ACTIONS:
		var code: int = mapping[action]
		if codes.get(action) == code:
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		if code < 0:
			var button := InputEventMouseButton.new()
			button.button_index = -code
			InputMap.action_add_event(action, button)
			labels[action] = MOUSE_NAMES[code]
		else:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
			var local_key := code
			if DisplayServer.get_name() != "headless":
				local_key = DisplayServer.keyboard_get_keycode_from_physical(code)
			labels[action] = OS.get_keycode_string(local_key if local_key else code)
	codes = mapping.duplicate()
