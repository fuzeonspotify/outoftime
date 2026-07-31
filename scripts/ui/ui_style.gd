class_name UIStyle
extends RefCounted

const COLOR_VOID: Color = Color("05040c")
const COLOR_PANEL: Color = Color(0.035, 0.027, 0.065, 0.94)
const COLOR_PANEL_SOFT: Color = Color(0.045, 0.040, 0.080, 0.86)
const COLOR_BORDER: Color = Color(0.39, 0.31, 0.58, 0.78)
const COLOR_BORDER_SOFT: Color = Color(0.26, 0.23, 0.38, 0.66)
const COLOR_ACCENT: Color = Color("d84b9e")
const COLOR_ACCENT_COOL: Color = Color("7f8cff")
const COLOR_TEXT: Color = Color("f3edf7")
const COLOR_TEXT_MUTED: Color = Color("aaa4b9")
const COLOR_TEXT_DIM: Color = Color("747083")


static func make_panel_style(
	background: Color = COLOR_PANEL,
	border: Color = COLOR_BORDER,
	radius: int = 12,
	border_width: int = 1,
	padding: float = 16.0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	return style


static func apply_panel(panel: PanelContainer, subtle: bool = false) -> void:
	if panel == null:
		return
	var background: Color = COLOR_PANEL_SOFT if subtle else COLOR_PANEL
	var border: Color = COLOR_BORDER_SOFT if subtle else COLOR_BORDER
	panel.add_theme_stylebox_override("panel", make_panel_style(background, border, 12, 1, 14.0))
	panel.set_meta("release_styled", true)


static func apply_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return

	var normal_background: Color = Color(0.075, 0.058, 0.105, 0.96)
	var normal_border: Color = COLOR_BORDER_SOFT
	var hover_background: Color = Color(0.13, 0.080, 0.16, 0.98)
	var hover_border: Color = COLOR_ACCENT if primary else COLOR_ACCENT_COOL
	var pressed_background: Color = Color(0.18, 0.075, 0.15, 1.0)

	if primary:
		normal_background = Color(0.34, 0.075, 0.24, 0.98)
		normal_border = Color(0.90, 0.34, 0.65, 0.92)
		hover_background = Color(0.48, 0.09, 0.32, 1.0)

	button.add_theme_stylebox_override("normal", make_panel_style(normal_background, normal_border, 9, 1, 12.0))
	button.add_theme_stylebox_override("hover", make_panel_style(hover_background, hover_border, 9, 2, 12.0))
	button.add_theme_stylebox_override("pressed", make_panel_style(pressed_background, COLOR_ACCENT, 9, 2, 12.0))
	button.add_theme_stylebox_override("focus", make_panel_style(Color(0.0, 0.0, 0.0, 0.0), COLOR_ACCENT_COOL, 9, 2, 12.0))
	button.add_theme_stylebox_override("disabled", make_panel_style(Color(0.04, 0.04, 0.05, 0.72), Color(0.16, 0.16, 0.20, 0.65), 9, 1, 12.0))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	button.add_theme_font_size_override("font_size", 16)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("release_styled", true)


static func apply_label(
	label: Label,
	font_size: int = 16,
	font_color: Color = COLOR_TEXT,
	outline_size: int = 3
) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.005, 0.004, 0.012, 0.94))
	label.add_theme_constant_override("outline_size", outline_size)
	label.set_meta("release_styled", true)


static func apply_rich_text(
	label: RichTextLabel,
	font_size: int = 17,
	font_color: Color = COLOR_TEXT
) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.005, 0.004, 0.012, 0.94))
	label.add_theme_constant_override("outline_size", 3)
	label.set_meta("release_styled", true)


static func apply_progress(progress: ProgressBar) -> void:
	if progress == null:
		return
	progress.show_percentage = false
	progress.add_theme_stylebox_override(
		"background",
		make_panel_style(Color(0.018, 0.016, 0.030, 0.92), COLOR_BORDER_SOFT, 4, 1, 0.0)
	)
	progress.add_theme_stylebox_override(
		"fill",
		make_panel_style(Color("a83d86"), Color("ec78bd"), 4, 0, 0.0)
	)
	progress.set_meta("release_styled", true)


static func make_label(
	text_value: String,
	font_size: int = 16,
	font_color: Color = COLOR_TEXT
) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	apply_label(label, font_size, font_color)
	return label


static func make_button(
	text_value: String,
	primary: bool = false,
	minimum_size: Vector2 = Vector2(320.0, 50.0)
) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum_size
	apply_button(button, primary)
	return button
