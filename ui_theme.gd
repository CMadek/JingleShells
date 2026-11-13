extends RefCounted

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	var cream := Color("fff1cf")
	var gold := Color("efc66e")
	var green := Color("a6ca94")
	var red := Color("f18d81")
	for type in ["Label", "Button", "CheckButton", "LineEdit", "OptionButton"]:
		theme.set_color("font_color", type, cream)
		if type in ["Button", "CheckButton", "OptionButton"]:
			theme.set_color("font_color", type, green)
			theme.set_color("font_hover_color", type, red)
			theme.set_color("font_focus_color", type, red)
			theme.set_color("font_pressed_color", type, red)
			theme.set_color("font_hover_pressed_color", type, red)
			theme.set_color("font_disabled_color", type, Color("728377"))
	for type in ["Button", "OptionButton", "LineEdit", "PanelContainer"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("172740") if state != "pressed" else Color("244d49")
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
			style.border_color = gold if state in ["hover", "focus"] else Color("354760")
			style.set_border_width_all(2 if state == "focus" else 1)
			style.set_corner_radius_all(10)
			style.content_margin_left = 18
			style.content_margin_right = 18
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			theme.set_stylebox(state, type, style)
	return theme
