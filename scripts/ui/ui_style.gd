class_name UIStyle
extends RefCounted

const COLOR_VOID: Color = Color("05040c")
const COLOR_PANEL: Color = Color(0.028, 0.020, 0.052, 0.95)
const COLOR_PANEL_SOFT: Color = Color(0.040, 0.032, 0.071, 0.88)
const COLOR_BORDER: Color = Color(0.44, 0.34, 0.66, 0.82)
const COLOR_BORDER_SOFT: Color = Color(0.27, 0.23, 0.40, 0.70)
const COLOR_ACCENT: Color = Color("d84b9e")
const COLOR_ACCENT_COOL: Color = Color("7f8cff")
const COLOR_SIGNAL: Color = Color("9b67d9")
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
	style.border_width_left = maxi(border_width, 1)
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = maxi(2, radius / 3)
	style.corner_radius_bottom_left = maxi(2, radius / 3)
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	return style


static func make_signal_panel_style(
	background: Color = COLOR_PANEL,
	border: Color = COLOR_ACCENT,
	padding: float = 18.0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = make_panel_style(background, border, 16, 1, padding)
	style.border_width_left = 4
	style.border_width_bottom = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 2
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

	var normal_background: Color = Color(0.064, 0.048, 0.096, 0.97)
	var normal_border: Color = COLOR_BORDER_SOFT
	var hover_background: Color = Color(0.13, 0.072, 0.16, 0.99)
	var hover_border: Color = COLOR_ACCENT if primary else COLOR_ACCENT_COOL
	var pressed_background: Color = Color(0.19, 0.062, 0.15, 1.0)

	if primary:
		normal_background = Color(0.31, 0.055, 0.22, 0.99)
		normal_border = Color(0.90, 0.34, 0.65, 0.94)
		hover_background = Color(0.47, 0.075, 0.31, 1.0)

	button.add_theme_stylebox_override("normal", make_signal_panel_style(normal_background, normal_border, 10.0))
	button.add_theme_stylebox_override("hover", make_signal_panel_style(hover_background, hover_border, 10.0))
	button.add_theme_stylebox_override("pressed", make_signal_panel_style(pressed_background, COLOR_ACCENT, 10.0))
	button.add_theme_stylebox_override("focus", make_signal_panel_style(Color(0.055, 0.042, 0.086, 0.98), COLOR_ACCENT_COOL, 10.0))
	button.add_theme_stylebox_override("disabled", make_signal_panel_style(Color(0.035, 0.035, 0.045, 0.74), Color(0.15, 0.15, 0.19, 0.66), 10.0))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	button.add_theme_font_size_override("font_size", 16)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("release_styled", true)
	_bind_button_audio(button)


static func _bind_button_audio(button: Button) -> void:
	if button.has_meta("audio_feedback_bound"):
		return
	button.set_meta("audio_feedback_bound", true)
	var hover_callable: Callable = Callable(SFXDirector, "play_ui_hover")
	var confirm_callable: Callable = Callable(SFXDirector, "play_ui_confirm")
	if not button.mouse_entered.is_connected(hover_callable):
		button.mouse_entered.connect(hover_callable)
	if not button.focus_entered.is_connected(hover_callable):
		button.focus_entered.connect(hover_callable)
	if not button.pressed.is_connected(confirm_callable):
		button.pressed.connect(confirm_callable)


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
		make_panel_style(Color(0.014, 0.012, 0.026, 0.94), COLOR_BORDER_SOFT, 3, 1, 0.0)
	)
	progress.add_theme_stylebox_override(
		"fill",
		make_panel_style(Color("a83d86"), Color("ec78bd"), 3, 0, 0.0)
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
