extends MarginContainer
## Shared header, scrolling page body and fixed action bar.
const Look = preload("res://ui_theme.gd")
const EMBLEM = preload("res://assets/ui/winged-bell.svg")

var content := VBoxContainer.new()
var tabs := HBoxContainer.new()
var footer := HBoxContainer.new()
var scroller := ScrollContainer.new()
var header := BoxContainer.new()
var title := Label.new()
var body_margin := MarginContainer.new()
var compact := false

func build(caption: String, is_compact: bool) -> void:
	compact = is_compact
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	add_child(stack)
	stack.add_child(header)
	header.add_theme_constant_override("separation", 14)
	var lockup := HBoxContainer.new()
	lockup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lockup.add_theme_constant_override("separation", 12)
	header.add_child(lockup)
	var emblem := TextureRect.new()
	emblem.texture = EMBLEM
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size.x = 54 if compact else 76
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lockup.add_child(emblem)
	var divider := ColorRect.new()
	divider.color = Look.GOLD
	divider.custom_minimum_size = Vector2(1, 40)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lockup.add_child(divider)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	lockup.add_child(titles)
	title.text = caption.to_upper()
	title.theme_type_variation = &"DispatchHeading"
	titles.add_child(title)
	var brand := Label.new()
	brand.text = "J I N G L E   S H E L L S"
	brand.add_theme_font_size_override("font_size", 12)
	titles.add_child(brand)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tabs)
	scroller.follow_focus = true
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroller)
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(body_margin)
	content.add_theme_constant_override("separation", 12 if not compact else 6)
	body_margin.add_child(content)
	stack.add_child(footer)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var pad := 18 if compact else clampi(roundi(size.x * .034), 14, 64)
	for side in ["left","right","top","bottom"]:
		add_theme_constant_override("margin_" + side, pad)
	header.vertical = size.x < 760 and tabs.get_child_count() > 0
	title.add_theme_font_size_override("font_size", 26 if compact else clampi(roundi(size.x*.032), 24, 54))
	body_margin.add_theme_constant_override("margin_left", 0 if compact else int(size.x*.18))
	body_margin.add_theme_constant_override("margin_right", 2 if compact else int(size.x*.29))
	body_margin.add_theme_constant_override("margin_top", 4 if compact else int(size.y*.066))
	body_margin.add_theme_constant_override("margin_bottom", 8)

static func rule(parent: Container) -> void:
	var line := ColorRect.new()
	line.color = Color("#bc985c")
	line.custom_minimum_size = Vector2(8, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func section(parent: Container, caption: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = 43
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption.to_upper()
	name_label.theme_type_variation = &"DispatchHeading"
	name_label.add_theme_font_size_override("font_size", 23)
	row.add_child(name_label)
	rule(row)
