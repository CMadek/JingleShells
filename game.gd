extends Node
## Autoload. Registers input actions in code so the project has no input-map boilerplate.

func _ready() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)     # also "climb" while piloting
	_key("descend", KEY_SHIFT)  # dive while piloting
	_key("interact", KEY_E)


func _key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(action, e)
