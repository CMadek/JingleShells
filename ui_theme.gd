extends RefCounted

const CREAM := Color("#fff1cf")
const GOLD := Color("#e4b35c")
const GREEN := Color("#a6ca94")
const RED := Color("#f18d81")

static func surface(fill: Color, margin_x: int = 12, margin_y: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(4)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style

static func outline(fill: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := surface(fill)
	style.border_color = GOLD
	style.set_border_width_all(2)
	return style

static func create() -> Theme:
	var theme := Theme.new()
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "serif"])
	theme.default_font = serif
	theme.default_font_size = 19
	var clear := surface(Color.TRANSPARENT)
	var hover := surface(Color("#682e333e"))
	var evergreen := surface(Color("#244b3e"))
	var card := surface(Color("#10212bf5"), 2, 2)
	card.border_color = Color("#a38754")
	card.border_width_top = 2
	var focus := outline()
	var inset := surface(Color("#132831"), 10, 5)
	inset.border_color = Color("#7c8270")
	inset.border_width_bottom = 1
	theme.set_stylebox("panel", "PanelContainer", card)
	theme.set_stylebox("panel", "PopupMenu", surface(Color("#122833"), 8, 6))
	theme.set_stylebox("hover", "PopupMenu", evergreen)
	theme.set_stylebox("panel", "AcceptDialog", surface(Color("#132630"), 16, 12))
	for state in ["embedded_border", "embedded_unfocused_border"]:
		var frame := surface(Color("#142932"), 5, 5)
		frame.expand_margin_top = 32
		theme.set_stylebox(state, "Window", frame)
	theme.set_color("title_color", "Window", CREAM)
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "PopupMenu", CREAM)
	for kind in ["Button", "CheckBox", "OptionButton"]:
		theme.set_color("font_color", kind, GREEN if kind == "Button" else CREAM)
		theme.set_color("font_hover_color", kind, RED)
		theme.set_color("font_focus_color", kind, RED)
		theme.set_color("font_pressed_color", kind, CREAM)
		theme.set_color("font_hover_pressed_color", kind, RED)
		theme.set_color("font_disabled_color", kind, Color("#9aa69e"))
		theme.set_stylebox("normal", kind, inset if kind == "OptionButton" else clear)
		theme.set_stylebox("disabled", kind, clear)
		theme.set_stylebox("hover", kind, hover)
		theme.set_stylebox("pressed", kind, evergreen)
		theme.set_stylebox("focus", kind, focus)
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_stylebox("normal", "LineEdit", inset)
	theme.set_stylebox("focus", "LineEdit", focus)
	for variant in ["DispatchTab", "DispatchAction"]:
		theme.set_type_variation(variant, "Button")
		theme.set_color("font_color", variant, CREAM)
	theme.set_stylebox("normal", "DispatchAction", outline(Color("#274d40")))
	var selected := surface(Color("#264d3f"))
	selected.border_color = GOLD
	selected.border_width_bottom = 2
	theme.set_stylebox("pressed", "DispatchTab", selected)
	theme.set_stylebox("hover_pressed", "DispatchTab", selected)
	var track := surface(Color("#636756"), 0, 2)
	var progress := surface(GOLD, 0, 2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", progress)
	theme.set_stylebox("grabber_area_highlight", "HSlider", progress)
	theme.set_stylebox("focus", "HSlider", focus)
	var thumb := preload("res://assets/ui/slider-thumb.svg")
	theme.set_icon("grabber", "HSlider", thumb)
	theme.set_icon("grabber_highlight", "HSlider", thumb)
	theme.set_icon("checked", "CheckBox", preload("res://assets/ui/check-on.svg"))
	theme.set_icon("unchecked", "CheckBox", preload("res://assets/ui/check-off.svg"))
	theme.set_constant("h_separation", "CheckBox", 10)
	theme.set_stylebox("pressed", "CheckBox", clear)
	theme.set_stylebox("hover_pressed", "CheckBox", hover)
	var heading := serif.duplicate() as SystemFont
	heading.font_weight = 700
	theme.set_type_variation("DispatchHeading", "Label")
	theme.set_font("font", "DispatchHeading", heading)
	theme.set_font("font", "DispatchTab", heading)
	return theme
