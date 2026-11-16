extends CanvasLayer

const DispatchPage = preload("res://dispatch_page.gd")
const Look = preload("res://ui_theme.gd")
const TITLES := {"play":"Play", "join":"Join a Game", "connecting":"Connecting", "pause":"Flight Menu", "options":"Settings", "help":"How to Play", "credits":"Credits"}
const TAB_NAMES := ["General", "Graphics", "Controls"]
var shell: DispatchPage
var pause_card: PanelContainer
var tab_sections: Array[VBoxContainer] = []
var active_tab := 0

const HELP := """THE LAST STOP
Sit on a couch cushion with {interact}; {jump} gets you up. Grab a practice parcel and hold/release {crew_primary} to aim for the chimney. Face the quartermaster and press {interact} to chat or shop. Buy a wrapped present to carry, or upgrade the whole crew with a throwing mitt or quick sling. Successful gift deliveries earn crew vouchers.

NAVIGATION
Take the folded chart from the coffee table with {interact}. Use {crew_primary} to read or fold it, {mark_chart} over the paper to pencil in a shared waypoint, and {show_chart} to offer it to a crewmate. In the cabin, face the board beside the dispatch terminal and press {interact} to pin the chart. Anyone can read it there with {crew_primary} or take it down with {interact}. The runway and departure lounge stay put; each new lobby surveys a different delivery district.

NORTH STAR MK II
Collect presents and bombs from the rear stores with {interact}. Carry them to the loading end of either return track and press {interact}. Each track holds five mixed items. Position 1 is NEXT; arrows point toward its enclosed chute.

With empty hands, aim at any queued item and press {interact} to retrieve it. Reload it at the loading end to move it to the back. Full or cycling tracks keep your held item safe.

DELIVERY CONSOLE
Aim at the port-side console ahead of the tracks and press {interact} with empty hands. Both cargo launchers are controlled here: {launcher_left} selects LEFT, {launcher_right} selects RIGHT, and {launcher_release} releases one item. The green circle and center crosshair predict the selected cargo landing after the 0.45-second release delay, assuming current flight inputs continue. Cargo is never guided. {launcher_leave} leaves the station.

VENTRAL TURRET
Use {crew_primary} at the BELLY GUN hatch to the right of the cockpit stairs with empty hands to climb into the glass pod. {turret_leave} returns you to the cabin beside the stairs. Mouse aims, {turret_fire} fires a snowball, and holding {turret_look} lets you look around without moving the guns. The turret rotates through 360 degrees; shots into the aircraft are blocked. Snowballs create cosmetic impacts only. A teammate can operate delivery independently.

FLIGHT AND DELIVERY
Use {interact} at the helm. {move_forward}/{move_back} moves the throttle lever. Hold {jump} at 18 m/s to lift off and release it at your desired pitch. {pilot_view} switches between cockpit and chase view. Hold {pilot_orbit} and drag to orbit.
Flight assist is on at takeoff. Release steering and pitch to level out. Hold {afterburner} in the air for extra thrust. Release it to coast back to your throttle setting. Half throttle works well over a delivery.
Watch BURNER HEAT on the dash. EASE OFF warns at 75%. Releasing early lets you boost again immediately. At 100%, boost cuts out. Release {afterburner} and let the needle cool to RESET (35%). READY means you can boost again.
Press {aerobatics} for aerobatics. {move_left}/{move_right} roll the wings and {jump}/{descend} pitch around the wing axis. Bank, then pull to turn. Combine both axes for a barrel roll. Release to keep your attitude, or press {aerobatics} again for assist. Brake while pulling for a tighter turn.
At 14 m/s or faster, release the flight controls and press {cruise_hold} to level out and hold heading and altitude. Leave the helm with {interact} to work in the cabin. Any flight input or another press of {cruise_hold} returns control to the pilot.
Presents: nice house +10, precise nice chimney +15 total; naughty house −5. Bombs destroy only the house directly hit and add no score.

WALKING
{move_forward}/{move_left}/{move_back}/{move_right} move • {jump} jump • {crouch} crouch • {interact} interact
Hold/release {crew_primary} to throw held cargo • {drop_cargo} drop
{interact} operates the outside boarding door from either side.

{flight_menu} opens the menu. Online play continues; your gameplay input is suppressed. {launcher_leave} leaves the delivery console; {turret_leave} leaves the turret."""
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
var number_fields := {}
var backdrop: Control
var binding_buttons := {}
var capture_action := ""
var consume_release := 0
var main_margin: MarginContainer
var main_logo: TextureRect
var scrim: ColorRect

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://ui_theme.gd").create()
	add_child(root)
	root.resized.connect(_layout_main)
	show_page("main")

func in_game() -> bool:
	return get_parent().get_node_or_null("World") != null

func _input(event: InputEvent) -> void:
	if capture_action != "":
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel") or ((event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()):
			capture_binding(event)
		return
	if consume_release != 0 and Game.bindings.event_code(event) == consume_release:
		if event.is_echo() or not event.is_pressed():
			get_viewport().set_input_as_handled()
			if not event.is_pressed():
				consume_release = 0
			return
		consume_release = 0
	if not root.visible:
		var world = get_parent().get_node_or_null("World")
		if world and world.mess.dialogue.choosing() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("flight_menu")):
			if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
				get_viewport().set_input_as_handled()
				world.mess.dialogue.close()
			return
		if event.is_action_pressed("flight_menu") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")):
			get_viewport().set_input_as_handled()
			show_page("pause")
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(display_dialog):
			_revert_display()
		elif is_instance_valid(dialog):
			dialog.queue_free()
			dialog = null
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

		return
	if page == "options" and not is_instance_valid(dialog) and not is_instance_valid(display_dialog):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		if event.is_action_pressed("previous_tab") or event.is_action_pressed("next_tab"):
			get_viewport().set_input_as_handled()
			var step := -1 if event.is_action_pressed("previous_tab") else 1
			select_tab(wrapi(active_tab + step, 0, TAB_NAMES.size()), true)

func _process(_delta: float) -> void:
	if page in ["main", "play"] and root.visible:
		for child in box.get_children():
			if child is Button and child.text in ["Host Game", "Join Game", "Host a Game", "Join a Game"]:
				child.disabled = not Game.steam_ready or get_parent().busy()
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
		world.stations.turret_free_look = false
		world.stations.look_offset = Vector2.ZERO
		var elf = world.players.get(multiplayer.get_unique_id())
		if elf:
			if world.mess: world.mess.dialogue.close()
			if world.mess and world.mess.presenting: world.mess.read_sheet(false)
			if world.mess and world.mess.held(elf.peer_id) > 0: world.mess.request("cancel")
			elf.dragging_orbit = false
			elf.charging_since = -1
			world.cargo_action("cancel")
			if world.pilot_id == elf.peer_id:
				world.send_pilot_input(0, 0, 0)

func show_page(next: String, message: String = "", reset_options := false) -> void:
	# A disconnect or invite may change pages while a display trial is open.
	if is_instance_valid(display_dialog):
		Game.values = previous.duplicate()
		Game.apply_settings()
		display_dialog = null
	dialog = null
	capture_action = ""
	consume_release = 0
	binding_buttons.clear()
	menu_revision += 1
	_block_input()
	root.show()
	page = next
	_sync_backdrop()
	main_margin = null
	shell = null
	pause_card = null
	number_fields.clear()
	tab_sections.clear()
	main_logo = null
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color("#091a2678")
	if not in_game():
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/menu/readability.gdshader") if page == "main" else preload("res://assets/menu/page_scrim.gdshader")
		background.material = material
	scrim = background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	if page == "main":
		main_margin = MarginContainer.new()
		main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(main_margin)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		main_margin.add_child(scroll)
		box = VBoxContainer.new()
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
	else:
		shell = DispatchPage.new()
		if in_game():
			var center := CenterContainer.new()
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			root.add_child(center)
			pause_card = PanelContainer.new()
			center.add_child(pause_card)
			pause_card.add_child(shell)
		else:
			root.add_child(shell)
			shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shell.build(TITLES[next], in_game())
		box = shell.content
	if page == "main":
		var logo := TextureRect.new()
		logo.name = "GameLogo"
		logo.texture = preload("res://assets/ui/jingle-shells-logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(0, 240)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(logo)
		main_logo = logo
		box.add_theme_constant_override("separation", 4)
		DispatchPage.rule(box)
		var space := Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.custom_minimum_size.y = 22
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(space)
		var host := button("Host a Game", func(): get_parent().host_game())
		var join := button("Join a Game", func(): show_page("join"))
		host.disabled = not Game.steam_ready or get_parent().busy()
		join.disabled = host.disabled
		host.tooltip_text = "Create a Steam lobby for your crew." if Game.steam_ready else "Start Steam to host an online game."
		join.tooltip_text = "Join your crew using a Steam lobby ID." if Game.steam_ready else "Start Steam to join an online game."
		button("How to Play", func(): show_page("help"))
		button("Settings", func():
			return_page = "main"
			show_page("options"))
		button("Credits", func(): show_page("credits"))
		button("Quit to Desktop", confirm_exit)
		if not Game.steam_ready:
			var notice := label("Start Steam to host or join your crew.", 12)
			notice.add_theme_color_override("font_color", Color("b5bdaf"))
	elif page == "play":
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
		footer_button("Cancel", func(): get_parent()._return_to_menu("Connection canceled."))
	elif page == "pause":
		DispatchPage.rule(box)
		button("Resume", resume_game)
		common_buttons()
		label("Steam lobby  ·  %d" % get_parent().lobby_id, 15)
		button("Copy Lobby ID", func(): DisplayServer.clipboard_set(str(get_parent().lobby_id)))
		var invite := button("Invite Friends", func(): Game.steam.activateGameOverlayInviteDialog(get_parent().lobby_id))
		invite.disabled = not Game.steam_ready or not Game.steam.isOverlayEnabled()
		button("End Session for Everyone" if multiplayer.is_server() else "Leave Game", confirm_leave)
		button("Exit to Desktop", confirm_exit)
	elif page == "options":
		build_options(reset_options)
	elif page == "help":
		for paragraph in HELP.format(Game.bindings.labels).split("\n\n"):
			var lines := paragraph.split("\n", true, 1)
			if lines.size() == 2 and lines[0] == lines[0].to_upper():
				DispatchPage.section(box, lines[0])
				label(lines[1])
			else:
				label(paragraph)
		back()
	elif page == "credits":
		DispatchPage.section(box, "Created by")
		label("Synk Studios & Memceco", 26)
		DispatchPage.section(box, "Technology")
		label("Built with Godot. Multiplayer powered by GodotSteam / Steam.")
		back()
	status = label(message)
	status.visible = not message.is_empty()
	_layout_main()
	_focus_first.call_deferred(menu_revision)

func _sync_backdrop() -> void:
	var animated: bool = Game.values.menu_motion and not "--static-menu" in OS.get_cmdline_user_args()
	if is_instance_valid(backdrop) and (in_game() or backdrop.animated != animated):
		release_backdrop()
	if not in_game() and not is_instance_valid(backdrop):
		backdrop = preload("res://menu_backdrop.gd").new()
		backdrop.animated = animated
		add_child(backdrop)
		move_child(backdrop, 0)

func release_backdrop() -> void:
	if is_instance_valid(backdrop):
		backdrop.stop()
		remove_child(backdrop)
		backdrop.queue_free()
		backdrop = null

func _layout_main() -> void:
	if is_instance_valid(pause_card):
		pause_card.custom_minimum_size = Vector2(minf(root.size.x - 20, 680 if page == "options" else 540), minf(root.size.y - 20, 490 if page == "pause" else 520))
	if not is_instance_valid(main_margin) or not is_instance_valid(main_logo):
		return
	var width := clampf(root.size.x * .30, 300, 420)
	box.custom_minimum_size.x = width
	main_logo.custom_minimum_size.y = minf(width / 1.5, root.size.y * .34)
	main_margin.add_theme_constant_override("margin_left", int(clampf(root.size.x * .035, 24, 68)))
	main_margin.add_theme_constant_override("margin_top", int(clampf(root.size.y * .035, 16, 38)))
	main_margin.add_theme_constant_override("margin_bottom", int(clampf(root.size.y * .04, 20, 44)))
	if is_instance_valid(scrim) and scrim.material:
		scrim.material.set_shader_parameter("rail_end", (width + main_margin.get_theme_constant("margin_left")) / maxf(root.size.x, 1))

func _focus_first(revision: int) -> void:
	if revision != menu_revision:
		return
	if page == "options":
		shell.tabs.get_child(active_tab).grab_focus()
		return
	for child in root.find_children("*", "Control", true, false):
		if child.is_visible_in_tree() and child is Control and child.focus_mode == Control.FOCUS_ALL:
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
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if page == "main":
		node.add_theme_font_size_override("font_size", 25)
	node.custom_minimum_size.y = 35 if in_game() else 42
	node.pressed.connect(callback)
	box.add_child(node)
	return node

func common_buttons() -> void:
	button("Settings", func():
		return_page = "pause" if in_game() else "main"
		show_page("options"))
	button("How to Play", func(): show_page("help"))

func back() -> void:
	footer_button("Back", func(): show_page("pause" if in_game() else "main"))

func footer_button(caption: String, action: Callable, primary := false) -> Button:
	var control := Button.new()
	if caption == "Back":
		var contents := HBoxContainer.new()
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_theme_constant_override("separation", 9)
		control.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var key := Label.new()
		key.text = "ESC"
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_stylebox_override("normal", Look.outline())
		contents.add_child(key)
		var back_label := Label.new()
		back_label.text = caption
		back_label.add_theme_color_override("font_color", Look.RED)
		contents.add_child(back_label)
		contents.grow_horizontal = Control.GROW_DIRECTION_BOTH
		contents.grow_vertical = Control.GROW_DIRECTION_BOTH
		control.custom_minimum_size.x = 118
		control.accessibility_name = "Back (Escape)"
	else:
		control.text = caption
	control.custom_minimum_size.y = 36
	control.theme_type_variation = &"DispatchAction" if primary else &"DispatchTab"
	shell.footer.add_child(control)
	control.pressed.connect(action)
	return control

func show_notice(message: String) -> void:
	if not root.visible:
		show_page("pause", message)
	else:
		status.text = message
		status.visible = not message.is_empty()

func resume_game() -> void:
	if not in_game():
		return
	capture_action = ""
	consume_release = 0
	release_backdrop()
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
	dialog.title = "Jingle Shells"
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

func field_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 38
	box.add_child(row)
	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	return row

func choice(title: String, key: String, items: Array) -> OptionButton:
	var row := field_row(title)
	var node := OptionButton.new()
	node.name = key
	node.accessibility_name = title
	for item in items:
		node.add_item(item)
	node.select(draft[key])
	node.custom_minimum_size.x = 155
	node.item_selected.connect(func(index: int): draft[key] = index)
	row.add_child(node)
	return node

func toggle(title: String, key: String) -> CheckBox:
	var node := CheckBox.new()
	node.name = key
	node.text = title
	node.button_pressed = draft[key]
	node.toggled.connect(func(value: bool): draft[key] = value)
	box.add_child(node)
	return node

func number(title: String, key: String, minimum: float, maximum: float, step: float, unit := "", disabled_by: CheckBox = null) -> void:
	var row := field_row(title)
	var input := HBoxContainer.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_constant_override("separation", 10)
	row.add_child(input)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 62
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = draft[key]
	slider.tooltip_text = title
	slider.accessibility_name = title
	input.add_child(slider)
	var node := SpinBox.new()
	node.custom_minimum_size.x = 82
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = draft[key]
	node.suffix = unit
	node.get_line_edit().add_theme_stylebox_override("normal", Look.surface(Color.TRANSPARENT, 4, 2))
	node.tooltip_text = title
	node.get_line_edit().accessibility_name = title
	slider.share(node)
	node.value_changed.connect(func(value: float): draft[key] = int(value) if key == "fps" else value)
	input.add_child(node)
	number_fields[key] = node
	if disabled_by:
		var update_input := func(disabled: bool):
			if disabled and node.get_line_edit().has_focus():
				node.apply()
			slider.editable = not disabled
			node.editable = not disabled
			slider.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
			node.get_line_edit().focus_mode = slider.focus_mode
			slider.modulate.a = 0.65 if disabled else 1.0
		disabled_by.toggled.connect(update_input)
		update_input.call(disabled_by.button_pressed)

func build_display_options() -> void:
	DispatchPage.section(box, "Display")
	var mode := choice("Window Mode", "mode", ["Windowed", "Borderless", "Fullscreen"])
	var sizes := []
	for size: Vector2i in Game.RESOLUTIONS:
		sizes.append("%d × %d" % [size.x, size.y])
	var resolution := choice("Resolution", "resolution", sizes)
	var update_resolution := func(index: int):
		resolution.disabled = index != 0
		if resolution.disabled:
			resolution.select(-1)
			resolution.text = "Desktop resolution"
		else:
			resolution.select(draft.resolution)
	mode.item_selected.connect(update_resolution)
	update_resolution.call(draft.mode)
	var vsync := toggle("VSync", "vsync")
	var unlocked := toggle("Unlock FPS", "unlocked_fps")
	number("Target FPS", "fps", Game.MIN_FPS, Game.MAX_FPS, 1, "", unlocked)
	var sync_hint := label("VSync limits FPS to your display’s refresh rate.", 16)
	sync_hint.add_theme_color_override("font_color", Color("#c9c8b3"))
	var update_hint := func(_pressed: bool):
		sync_hint.visible = vsync.button_pressed and unlocked.button_pressed
	vsync.toggled.connect(update_hint)
	unlocked.toggled.connect(update_hint)
	update_hint.call(false)
	number("Field of View", "fov", 60, 110, 1, "°")

func build_options(reset: bool) -> void:
	draft = Game.DEFAULTS.duplicate() if reset else Game.values.duplicate()
	return_page = "pause" if in_game() else "main"
	for index in TAB_NAMES.size():
		var tab := Button.new()
		tab.text = TAB_NAMES[index].to_upper()
		tab.theme_type_variation = &"DispatchTab"
		tab.toggle_mode = true
		tab.tooltip_text = "{previous_tab} / {next_tab}   Previous / next tab".format(Game.bindings.labels)
		shell.tabs.add_child(tab)
		tab.pressed.connect(select_tab.bind(index, true))
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 15 if not in_game() else 9)
		shell.content.add_child(section)
		tab_sections.append(section)
	box = tab_sections[0]
	DispatchPage.section(box, "Audio")
	number("Master Volume", "volume", 0, 100, 1, "%")
	var section_gap := Control.new()
	section_gap.custom_minimum_size.y = 8 if in_game() else 28
	section_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(section_gap)
	DispatchPage.section(box, "Presentation")
	toggle("Animated Menu Background", "menu_motion")
	var hint := label("Snowy airfield and crew animations", 16)
	hint.add_theme_stylebox_override("normal", Look.surface(Color.TRANSPARENT, 36, 0))
	hint.add_theme_color_override("font_color", Color("#c9c8b3"))
	box = tab_sections[1]
	build_display_options()
	box = tab_sections[2]
	DispatchPage.section(box, "Mouse Look")
	number("Sensitivity", "sensitivity", 0.2, 3, 0.1)
	toggle("Invert Vertical Look", "invert")
	DispatchPage.section(box, "Crew Controls")
	label("Select a control, then press a key or mouse button. Esc cancels. Bindings save immediately.", 16)
	for action in Game.bindings.ACTIONS:
		var row := field_row(Game.bindings.ACTIONS[action][0])
		var control := Button.new()
		control.text = Game.bindings.labels[action]
		control.accessibility_name = "%s: %s" % [Game.bindings.ACTIONS[action][0], control.text]
		row.add_child(control)
		binding_buttons[action] = control
		control.pressed.connect(begin_capture.bind(action))
	button("Reset key bindings", func(): commit_bindings(Game.bindings.defaults()))
	box = shell.content
	footer_button("Back", func(): show_page(return_page))
	DispatchPage.rule(shell.footer)
	footer_button("Restore Defaults", restore_defaults)
	DispatchPage.rule(shell.footer)
	footer_button("Cancel", func(): show_page(return_page))
	footer_button("Apply", apply_options, true).custom_minimum_size.x = 105
	select_tab(0)
	shell._fit()

func begin_capture(action: String) -> void:
	capture_action = action
	binding_buttons[action].text = "Press input… (Esc cancels)"

func capture_binding(event: InputEvent) -> void:
	var action := capture_action
	var code := Game.bindings.event_code(event)
	if event.is_action_pressed("ui_cancel"):
		capture_action = ""
		consume_release = code
		binding_buttons[action].text = Game.bindings.labels[action]
		return
	if not Game.bindings.allowed(action, code):
		binding_buttons[action].text = "Try another key (Esc cancels)"
		return
	var other := Game.bindings.conflict(action, code, Game.bindings.codes)
	if other != "":
		binding_buttons[action].text = "In use: " + Game.bindings.ACTIONS[other][0]
		return
	var mapping := Game.bindings.codes.duplicate()
	mapping[action] = code
	capture_action = ""
	consume_release = code
	commit_bindings(mapping)

func commit_bindings(mapping: Dictionary) -> void:
	var error := Game.save_bindings(mapping)
	for action in binding_buttons:
		var control: Button = binding_buttons[action]
		control.text = Game.bindings.labels[action]
		control.accessibility_name = "%s: %s" % [Game.bindings.ACTIONS[action][0], control.text]
	for tab in shell.tabs.get_children():
		tab.tooltip_text = "{previous_tab} / {next_tab}   Previous / next tab".format(Game.bindings.labels)
	if error != OK:
		show_notice("Could not save controls: " + error_string(error))

func select_tab(index: int, focus_tab := false) -> void:
	for field in number_fields.values():
		if field.get_line_edit().has_focus():
			field.apply()
	active_tab = index
	for i in tab_sections.size():
		tab_sections[i].visible = i == index
		var tab: Button = shell.tabs.get_child(i)
		tab.set_pressed_no_signal(i == index)
		if focus_tab and i == index:
			tab.grab_focus()
	shell.scroller.scroll_vertical = 0

func restore_defaults() -> void:
	var selected := active_tab
	show_page("options", "Defaults selected. Apply to save.", true)
	select_tab(selected, true)

func apply_options() -> void:
	# Commit text even when Apply is activated before the field loses focus.
	for field in number_fields.values():
		field.apply()
	previous = Game.values.duplicate()
	Game.values = draft.duplicate()
	var window_changed: bool = previous.mode != draft.mode or (draft.mode == 0 and previous.resolution != draft.resolution)
	Game.apply_settings(window_changed)
	if window_changed:
		display_dialog = ConfirmationDialog.new()
		display_dialog.title = "Keep display settings?"
		display_dialog.theme = root.theme
		root.add_child(display_dialog)
		display_deadline = Time.get_ticks_msec() + 15000
		display_dialog.confirmed.connect(func():
			display_dialog.queue_free()
			display_dialog = null
			_save_options(true))
		display_dialog.canceled.connect(_revert_display)
		display_dialog.popup_centered()
	else:
		_save_options(false)

func _save_options(window_changed: bool) -> void:
	var error := Game.save_settings()
	if error != OK:
		Game.values = previous.duplicate()
		Game.apply_settings(window_changed)
		show_notice("Could not save settings: " + error_string(error))
		return
	show_page(return_page)

func _revert_display() -> void:
	if not is_instance_valid(display_dialog):
		return
	display_dialog.queue_free()
	display_dialog = null
	Game.values = previous.duplicate()
	Game.apply_settings()
	var selected := active_tab
	show_page("options", "Display changes reverted.")
	select_tab(selected, true)
