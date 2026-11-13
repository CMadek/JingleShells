extends Control
## A private render world: no gameplay scripts, physics, input, audio or Steam.
const STAGE = preload("res://menu_stage.gd")
const STILL := "res://assets/menu/airfield_still.jpg"
var viewport: SubViewport
var stage: Node3D
var animated := true

func _ready() -> void:
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var still := TextureRect.new()
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(STILL):
		still.texture = load(STILL)
	add_child(still)
	if not animated:
		return
	viewport = SubViewport.new()
	viewport.name = "AirfieldViewport"
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	stage = STAGE.new()
	viewport.add_child(stage)
	var picture := TextureRect.new()
	picture.name = "LiveAirfield"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = viewport.get_texture()
	add_child(picture)
	resized.connect(_resize_render)
	_resize_render()

func _resize_render() -> void:
	if not is_instance_valid(viewport) or size.x < 1 or size.y < 1:
		return
	# Preserve aspect while limiting background cost; UI stays at native resolution.
	var scale_factor := minf(1.0, minf(1600.0 / size.x, 900.0 / size.y))
	viewport.size = Vector2i((size * scale_factor).round())
	stage.fit_aspect(size.x / size.y)

func stop() -> void:
	# Stop immediately, even during the frame before queue_free is processed.
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
