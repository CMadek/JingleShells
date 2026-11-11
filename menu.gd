extends CanvasLayer

const HELP := "Work together to deliver presents down chimneys. Green beams mark nice houses (+10); red beams mark naughty houses (-5). Only presents score.\n\nWALKING\nWASD — Move   •   Space — Jump\nE — Pick up cargo you look at, or take/leave the nearby helm\nHold left mouse — Charge; release — Throw\nG — Drop held cargo\n\nAT THE HELM\nW/S — Throttle   •   A/D — Turn\nSpace — Climb   •   Shift — Dive   •   E — Leave helm\n\nEscape — Open/close menu. The online game continues."
var root: Control
var box: VBoxContainer
var status: Label
var page := "main"
var return_page := "main"
var draft: Dictionary
var previous: Dictionary
var menu_revision := 0
var dialog: ConfirmationDialog
var display_deadline := 0
var display_dialog: ConfirmationDialog

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://ui_theme.gd").create()
	add_child(root)
	show_page("main")

func in_game() -> bool:
	return get_parent().get_node_or_null("World") != null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if is_instance_valid(display_dialog):
			_revert_display()
		elif is_instance_valid(dialog):
			dialog.queue_free()
			dialog = null
		elif not root.visible:
			show_page("pause")
		elif page == "pause":
			resume_game()
		elif page == "options":
			show_page(return_page)
		elif page == "connecting":
			get_parent()._return_to_menu("Connection canceled.")
		elif page == "main":
			confirm_exit()
		else:
			show_page("pause" if in_game() else "main")

func _process(_delta: float) -> void:
	if page == "play" and root.visible and Game.steam_ready and not get_parent().busy():
		for child in box.get_children():
			if child is Button and child.text in ["Host Game", "Join Game"]:
				child.disabled = false
	if is_instance_valid(display_dialog):
		var seconds := ceili((display_deadline - Time.get_ticks_msec()) / 1000.0)
		display_dialog.dialog_text = "Keep these display settings? Reverting in %d seconds." % seconds
		if seconds <= 0:
			_revert_display()

func _block_input() -> void:
	Game.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world = get_parent().get_node_or_null("World")
	if world:
		var elf = world.players.get(multiplayer.get_unique_id())
		if elf:
			elf.dragging_orbit = false
			elf.charging_since = -1
			world.cargo_action("cancel")
			if world.pilot_id == elf.peer_id:
				world.send_pilot_input(0, 0, 0)

func show_page(next: String, message: String = "") -> void:
	# A disconnect or invite may change pages while a display trial is open.
	if is_instance_valid(display_dialog):
		Game.values = previous.duplicate()
		Game.apply_settings()
		display_dialog = null
	dialog = null
	menu_revision += 1
	_block_input()
	root.show()
	page = next
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.10, 0.80 if in_game() else 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	if not in_game():
		var snow := preload("res://menu_snow.gd").new()
		snow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(snow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	root.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	if page == "main":
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)
	box = VBoxContainer.new()
	box.custom_minimum_size.x = 380 if in_game() or page == "main" else 500
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	if page == "main":
		var logo := TextureRect.new()
		logo.texture = preload("res://assets/ui/jingle-bells-logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(0, 245)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(logo)
		var subtitle := label("A little crew. A long Christmas Eve.")
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 16)
		button("Play", func(): show_page("play"))
		common_buttons()
		button("Credits", func(): show_page("credits"))
		button("Exit", confirm_exit)
	elif page == "play":
		label("PLAY", 28)
		var host := button("Host Game", func(): get_parent().host_game())
		var join := button("Join Game", func(): show_page("join"))
		host.disabled = not Game.steam_ready or get_parent().busy()
		join.disabled = host.disabled
		if not Game.steam_ready:
			label("Steam multiplayer is unavailable. Start Steam and check that this game installation includes multiplayer support.")
		elif get_parent().busy():
			label("Waiting for Steam to finish a canceled request. Please try again shortly.")
		back()
	elif page == "join":
		label("JOIN GAME", 28)
		label("Paste the host's Steam lobby ID, or accept a Steam invite.")
		var address := LineEdit.new()
		address.placeholder_text = "Steam lobby ID"
		address.max_length = 20
		box.add_child(address)
		var submit := func():
			var text := address.text.strip_edges()
			if not text.is_valid_int() or text.length() < 10 or text.to_int() <= 0:
				show_notice("Enter a valid numeric Steam lobby ID.")
			else:
				get_parent().join_game(text.to_int())
		button("Join", submit)
		address.text_submitted.connect(func(_text: String): submit.call())
		back()
	elif page == "connecting":
		label("PLEASE WAIT", 28)
		button("Cancel", func(): get_parent()._return_to_menu("Connection canceled."))
	elif page == "pause":
		label("FLIGHT MENU", 28)
		label("Online game continues")
		button("Resume", resume_game)
		common_buttons()
		label("Steam lobby: %d" % get_parent().lobby_id)
		button("Copy Lobby ID", func(): DisplayServer.clipboard_set(str(get_parent().lobby_id)))
		var invite := button("Invite Friends", func(): Game.steam.activateGameOverlayInviteDialog(get_parent().lobby_id))
		invite.disabled = not Game.steam_ready or not Game.steam.isOverlayEnabled()
		button("End Session for Everyone" if multiplayer.is_server() else "Leave Game", confirm_leave)
		button("Exit to Desktop", confirm_exit)
	elif page == "options":
		build_options()
	elif page == "help":
		label("HOW TO PLAY", 28)
		label(HELP)
		back()
	elif page == "credits":
		label("JINGLE BELLS", 28)
		label("By Synk Studios & Memceco\n\nA cooperative Christmas aviation game.\nBuilt with Godot. Multiplayer powered by GodotSteam / Steam.")
		back()
	status = label(message)
	_focus_first.call_deferred(menu_revision)

func _focus_first(revision: int) -> void:
	if revision != menu_revision:
		return
	for child in box.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL:
			if child is BaseButton and child.disabled:
				continue
			child.grab_focus()
			break

func label(text: String, font_size: int = 18) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	box.add_child(node)
	return node

func button(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	if page == "main":
		node.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	if text in ["Exit", "Exit to Desktop", "End Session for Everyone", "Leave Game"]:
		node.add_theme_color_override("font_color", Color("dca69b"))
	elif text in ["Host Game", "Resume"]:
		node.add_theme_color_override("font_color", Color("b8d4b7"))
	box.add_child(node)
	return node

func common_buttons() -> void:
	button("Options", func():
		return_page = "pause" if in_game() else "main"
		show_page("options"))
	button("How to Play", func(): show_page("help"))

func back() -> void:
	button("Back", func(): show_page("pause" if in_game() else "main"))

func show_notice(message: String) -> void:
	if not root.visible:
		show_page("pause", message)
	else:
		status.text = message

func resume_game() -> void:
	if not in_game():
		return
	root.hide()
	Game.menu_open = false
	var world = get_parent().get_node("World")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if world.pilot_id == multiplayer.get_unique_id() else Input.MOUSE_MODE_CAPTURED

func confirm(text: String, callback: Callable) -> void:
	if is_instance_valid(dialog):
		return
	_block_input()
	if not root.visible:
		show_page("pause")
	dialog = ConfirmationDialog.new()
	dialog.title = "Jingle Bells"
	dialog.dialog_text = text
	dialog.theme = root.theme
	root.add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		dialog = null
		callback.call())
	dialog.canceled.connect(func():
		dialog.queue_free()
		dialog = null)
	dialog.popup_centered()

func confirm_leave() -> void:
	confirm("End the session for everyone?" if multiplayer.is_server() else "Leave this game and return to the main menu?", func(): get_parent()._return_to_menu())

func confirm_exit() -> void:
	if is_instance_valid(display_dialog):
		_revert_display()
	confirm("Exit to desktop? This ends the session for everyone." if in_game() and multiplayer.is_server() else "Exit to desktop?", func(): get_parent().quit_game())

func choice(title: String, key: String, items: Array) -> void:
	label(title)
	var node := OptionButton.new()
	for item in items:
		node.add_item(item)
	node.select(draft[key])
	node.item_selected.connect(func(index: int): draft[key] = index)
	box.add_child(node)

func toggle(title: String, key: String) -> void:
	var node := CheckButton.new()
	node.text = title
	node.button_pressed = draft[key]
	node.toggled.connect(func(value: bool): draft[key] = value)
	box.add_child(node)

func number(title: String, key: String, minimum: float, maximum: float, step: float) -> void:
	label(title)
	var node := SpinBox.new()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = draft[key]
	node.value_changed.connect(func(value: float): draft[key] = int(value) if key == "fps" else value)
	box.add_child(node)

func build_options(reset: bool = false) -> void:
	draft = Game.DEFAULTS.duplicate() if reset else Game.values.duplicate()
	label("OPTIONS", 28)
	choice("Window mode", "mode", ["Windowed", "Borderless", "Fullscreen"])
	choice("Windowed resolution", "resolution", ["1280 × 720", "1600 × 900", "1920 × 1080"])
	toggle("VSync", "vsync")
	number("Frame limit (0 = unlimited)", "fps", 0, 360, 1)
	number("Field of view", "fov", 60, 110, 1)
	number("Master volume (%)", "volume", 0, 100, 5)
	number("Mouse sensitivity", "sensitivity", 0.2, 3, 0.1)
	toggle("Invert vertical look", "invert")
	label("Controls: WASD · Space · Shift · E · G · Left mouse\nSee How to Play for walking and helm controls.")
	button("Apply", apply_options)
	button("Restore Defaults", func():
		show_page("options")
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		build_options(true)
		status = label("Defaults selected. Apply to save.")
		_focus_first.call_deferred(menu_revision))
	button("Cancel / Back", func(): show_page(return_page))

func apply_options() -> void:
	previous = Game.values.duplicate()
	Game.values = draft.duplicate()
	Game.apply_settings()
	if previous.mode != draft.mode or previous.resolution != draft.resolution:
		display_dialog = ConfirmationDialog.new()
		display_dialog.title = "Keep display settings?"
		display_dialog.theme = root.theme
		root.add_child(display_dialog)
		display_deadline = Time.get_ticks_msec() + 15000
		display_dialog.confirmed.connect(func():
			display_dialog.queue_free()
			display_dialog = null
			Game.save_settings()
			show_page(return_page))
		display_dialog.canceled.connect(_revert_display)
		display_dialog.popup_centered()
	else:
		Game.save_settings()
		show_page(return_page)

func _revert_display() -> void:
	if not is_instance_valid(display_dialog):
		return
	display_dialog.queue_free()
	display_dialog = null
	Game.values = previous.duplicate()
	Game.apply_settings()
	show_page("options", "Display changes reverted.")
