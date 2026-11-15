extends PanelContainer

const LINES := preload("res://assets/audio/quartermaster/lines.tres")
const VISITS := [["welcome", "outfitter"], ["chart"], ["couch"], ["cocoa"]]
const HEARING_RANGE := 4.6
enum Page { CLOSED, OFFER, CHAT, SHOP, RECEIPT }

@onready var subtitle: Label = %Subtitle
@onready var hint: Label = %Hint
var voice := AudioStreamPlayer3D.new()
var listener: Node3D
var clerk: Node3D
var turn: Tween
var idle: AnimationPlayer
var lower_cup: Tween
var mouth: MeshInstance3D
var next_visit := 0
var pages: Array = []
var cues := PackedInt32Array()
var syllables := PackedInt32Array()
var beat := 0
var line_id := ""
var elapsed := 0.0
var page := Page.CLOSED
var room: Node3D
var pending_order := false
var buy_buttons: Array[Button] = []

func setup(mess: Node3D, actor: Node3D, voice_origin: Vector3) -> void:
	room = mess
	var button_theme := preload("res://ui_theme.gd").create()
	%Choices.theme = button_theme
	%Catalog.theme = button_theme
	%Chat.pressed.connect(start_chat)
	%Browse.pressed.connect(browse)
	%Goodbye.pressed.connect(close)
	%Back.pressed.connect(func(): offer(listener))
	for good: Dictionary in room.STOCK:
		add_product(good)
	clerk = actor
	idle = clerk.find_child("AnimationPlayer",true,false)
	var skeleton: Skeleton3D = clerk.find_children("*","Skeleton3D",true,false)[0]
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	skeleton.add_child(head)
	# Follow the stitched lip on the existing sculpt in its authored rest pose.
	var lip := Node3D.new()
	head.add_child(lip)
	lip.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse() * Transform3D(Basis.IDENTITY,Vector3(0,1.394,.221))
	mouth = MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radial_segments = 16
	shape.rings = 6
	mouth.mesh = shape
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("452b2b")
	felt.roughness = 1
	mouth.material_override = felt
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lip.add_child(mouth)
	mouth.hide()
	clerk.add_child(voice)
	voice.global_position = voice_origin
	voice.unit_size = 3.0
	voice.max_distance = 10
	voice.volume_db = -5
	get_viewport().size_changed.connect(fit_panel)
	fit_panel()
	set_process(false)

func fit_panel() -> void:
	var half_width := minf(325, get_viewport_rect().size.x * .5 - 16)
	offset_left = -half_width
	offset_right = half_width

func converse(elf: Node3D) -> void:
	if page == Page.CHAT:
		advance()
		return
	offer(elf)

func choosing() -> bool:
	return page == Page.OFFER or page == Page.SHOP

func offer(elf: Node3D) -> void:
	if room.held(elf.peer_id) > 0: room.request("cancel")
	if elf.charging_since >= 0:
		elf.charging_since = -1
		room.world.cargo_action("cancel")
	page = Page.OFFER
	pages.clear()
	begin_line(elf,"offer")
	%Choices.show()
	%Catalog.hide()
	offset_top = -142
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Chat.grab_focus()

func start_chat() -> void:
	page = Page.CHAT
	%Choices.hide()
	offset_top = -142
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pages = VISITS[next_visit].duplicate()
	next_visit = (next_visit + 1) % VISITS.size()
	begin_line(listener, pages.pop_front())

func browse() -> void:
	page = Page.SHOP
	begin_line(listener,"stock")
	%Choices.hide()
	%Catalog.show()
	refresh_stock()
	focus_available_product()

func add_product(good: Dictionary) -> void:
	var row := HBoxContainer.new()
	%StockRows.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",0)
	row.add_child(info)
	var title := Label.new()
	title.text = good.name
	info.add_child(title)
	var detail := Label.new()
	detail.text = good.detail
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",15)
	detail.add_theme_color_override("font_color",Color("c0ccbb"))
	info.add_child(detail)
	var price := Label.new()
	price.text = "%d vouchers" % good.cost
	price.add_theme_font_size_override("font_size",16)
	price.add_theme_color_override("font_color",Color("ead5aa"))
	row.add_theme_constant_override("separation",12)
	row.add_child(price)
	var buy := Button.new()
	buy.name = good.id
	buy.theme_type_variation = &"DispatchAction"
	buy.custom_minimum_size.x = 116
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(order.bind(good))
	row.add_child(buy)
	buy_buttons.append(buy)

func refresh_stock() -> void:
	if page != Page.SHOP or not is_instance_valid(listener): return
	%Balance.text = "Crew fund · %d vouchers" % room.vouchers
	for i in buy_buttons.size():
		var good: Dictionary = room.STOCK[i]
		var button := buy_buttons[i]
		var reason: String = room.unavailable(listener.peer_id,good)
		match reason:
			"owned": button.text = "Issued"
			"hands_full": button.text = "Hands full"
			"short": button.text = "%d short" % (good.cost-room.vouchers)
			_: button.text = "Buy"
		button.disabled = pending_order or reason != ""
		button.tooltip_text = "%s · %d vouchers" % [good.name,good.cost]
		button.accessibility_name = "%s · %s · %d vouchers" % [button.text,good.name,good.cost]
	var focused := get_viewport().gui_get_focus_owner() as Button
	if not pending_order and (not focused or focused.disabled):
		%Back.grab_focus()

func focus_available_product() -> void:
	for button in buy_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	%Back.grab_focus()

func order(good: Dictionary) -> void:
	if page != Page.SHOP or pending_order or room.unavailable(listener.peer_id,good) != "": return
	pending_order = true
	refresh_stock()
	room.request("order/"+str(good.id))

func handle_choice_input(event: InputEvent) -> void:
	# Native buttons handle pointer, focus navigation and the UI accept action.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: return
	if not event.is_action_pressed("interact"): return
	var button := get_viewport().gui_get_focus_owner() as Button
	if button and is_ancestor_of(button) and not button.disabled: button.pressed.emit()

func reply(elf: Node3D, id: String, from_catalog: bool) -> void:
	if from_catalog:
		pending_order = false
		if page != Page.SHOP: return
		refresh_stock()
		if id.is_empty():
			close()
			return
	if not is_instance_valid(elf) or Game.menu_open or elf.head.global_position.distance_to(voice.global_position) > HEARING_RANGE:
		return
	if visible and page == Page.RECEIPT and id == line_id: return
	pages.clear()
	if not from_catalog:
		if choosing(): return
		page = Page.RECEIPT
		offset_top = -142
	begin_line(elf, id)

func begin_line(elf: Node3D, id: String) -> void:
	listener = elf
	line_id = id
	var line: Dictionary = LINES.get_meta(id)
	cues = line.cues
	syllables = line.syllables
	beat = 0
	subtitle.text = line.text
	subtitle.visible_characters = 0
	elapsed = 0.0
	voice.stream = line.voice
	voice.play()
	if not visible:
		# Ease the cocoa mug back down before the clerk addresses the customer.
		var time := idle.current_animation_position
		var rest := time
		if time > 1.5 and time < 5.8: rest = 5.8
		if time > 13.5 and time < 17.8: rest = 17.8
		idle.pause()
		if rest != time:
			lower_cup = clerk.create_tween().set_trans(Tween.TRANS_SINE)
			lower_cup.tween_method(func(t: float): idle.seek(t,true),time,rest,.32)
	var to_elf := elf.global_position - clerk.global_position
	face(clampf(atan2(to_elf.x, to_elf.z), -.65, .65))
	show()
	update_hint()
	set_process(true)

func face(yaw: float) -> void:
	if turn: turn.kill()
	turn = clerk.create_tween().set_trans(Tween.TRANS_SINE)
	turn.tween_property(clerk, "rotation:y", yaw, .28)

func advance() -> void:
	if subtitle.visible_characters < cues.size():
		subtitle.visible_characters = cues.size()
		voice.stop()
		mouth.hide()
		update_hint()
	elif not pages.is_empty():
		begin_line(listener, pages.pop_front())
	else:
		offer(listener)

func update_hint() -> void:
	if page != Page.CHAT:
		hint.text = ""
		return
	var action := "Show line"
	if subtitle.visible_characters == cues.size():
		action = "Continue" if not pages.is_empty() else "Back to counter"
	hint.text = "%s   %s" % [Game.bindings.labels.interact, action]

func close() -> void:
	if not visible: return
	if choosing() and not Game.menu_open: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	page = Page.CLOSED
	%Choices.hide()
	%Catalog.hide()
	pending_order = false
	voice.stop()
	mouth.hide()
	if lower_cup: lower_cup.kill()
	idle.play()
	hide()
	set_process(false)
	pages.clear()
	listener = null
	line_id = ""
	face(0.0)

func _process(delta: float) -> void:
	if Game.menu_open or not is_instance_valid(listener) or listener.head.global_position.distance_to(voice.global_position) > HEARING_RANGE:
		close()
		return
	elapsed += delta
	var ms := elapsed * 1000.0
	while beat < syllables.size() and ms >= syllables[beat+1]:
		beat += 2
	mouth.visible = voice.playing and beat < syllables.size() and ms >= syllables[beat]
	if mouth.visible:
		var phase := inverse_lerp(syllables[beat],syllables[beat+1],ms)
		var opening := .038 * sin(PI*phase)
		mouth.scale = Vector3(.084,.003+opening,.012)
		mouth.position.y = -opening*.42
	var shown := subtitle.visible_characters
	while shown < cues.size() and cues[shown] <= ms:
		shown += 1
	if shown != subtitle.visible_characters:
		subtitle.visible_characters = shown
		if shown == cues.size(): update_hint()
	if page == Page.RECEIPT and elapsed >= voice.stream.get_length() + 2.25:
		close()
