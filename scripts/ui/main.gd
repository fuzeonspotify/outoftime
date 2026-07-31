extends Control

const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")
const CEMETERY_SCENE_PATH: String = "res://scenes/cemetery.tscn"

var _main_panel: PanelContainer
var _controls_panel: PanelContainer
var _begin_button: Button
var _fade_rect: ColorRect
var _stars: Array[ColorRect] = []
var _star_phases: Array[float] = []
var _elapsed_time: float = 0.0
var _transition_started: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 6041998
	_build_interface()
	MusicDirector.cue_missing.connect(_on_cue_missing)
	_begin_button.grab_focus()


func _process(delta: float) -> void:
	_elapsed_time += delta
	for index: int in range(_stars.size()):
		var star: ColorRect = _stars[index]
		var phase: float = _star_phases[index]
		var alpha: float = 0.20 + (sin(_elapsed_time * 0.75 + phase) * 0.5 + 0.5) * 0.48
		star.modulate.a = alpha


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _controls_panel.visible:
		_show_main_panel()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = UI_STYLE.COLOR_VOID
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_build_starfield()
	_build_background_accents()

	var screen_margin: MarginContainer = MarginContainer.new()
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_margin.add_theme_constant_override("margin_left", 72)
	screen_margin.add_theme_constant_override("margin_top", 58)
	screen_margin.add_theme_constant_override("margin_right", 72)
	screen_margin.add_theme_constant_override("margin_bottom", 58)
	add_child(screen_margin)

	var layout: HBoxContainer = HBoxContainer.new()
	layout.add_theme_constant_override("separation", 64)
	screen_margin.add_child(layout)

	var title_column: VBoxContainer = VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	title_column.add_theme_constant_override("separation", 12)
	layout.add_child(title_column)

	var eyebrow: Label = UI_STYLE.make_label("A DESCENT THROUGH MEMORY", 14, UI_STYLE.COLOR_ACCENT_COOL)
	eyebrow.add_theme_constant_override("letter_spacing", 2)
	title_column.add_child(eyebrow)

	var title: Label = UI_STYLE.make_label("OUT OF TIME", 72, UI_STYLE.COLOR_TEXT)
	title.name = "GameTitle"
	title.add_theme_constant_override("outline_size", 8)
	title_column.add_child(title)

	var title_rule: ColorRect = ColorRect.new()
	title_rule.custom_minimum_size = Vector2(370.0, 3.0)
	title_rule.color = UI_STYLE.COLOR_ACCENT
	title_column.add_child(title_rule)

	var tagline: Label = UI_STYLE.make_label("YOU WERE NEVER THE FIRST", 21, UI_STYLE.COLOR_TEXT_MUTED)
	tagline.add_theme_constant_override("letter_spacing", 1)
	title_column.add_child(tagline)

	var description: Label = UI_STYLE.make_label(
		"Follow a familiar woman through a cemetery, a fractured memory,\na gravityless void, and the rooms that remember how you died.",
		17,
		UI_STYLE.COLOR_TEXT_MUTED
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(560.0, 88.0)
	title_column.add_child(description)

	var chapter_line: Label = UI_STYLE.make_label(
		"CEMETERY  •  MEMORY BRIDGE  •  VOID  •  RUINED CLUB  •  CHAMBER",
		12,
		UI_STYLE.COLOR_TEXT_DIM
	)
	title_column.add_child(chapter_line)

	var menu_holder: CenterContainer = CenterContainer.new()
	menu_holder.custom_minimum_size = Vector2(420.0, 0.0)
	layout.add_child(menu_holder)

	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(390.0, 410.0)
	UI_STYLE.apply_panel(_main_panel)
	menu_holder.add_child(_main_panel)

	var menu_stack: VBoxContainer = VBoxContainer.new()
	menu_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_stack.add_theme_constant_override("separation", 14)
	_main_panel.add_child(menu_stack)

	var menu_heading: Label = UI_STYLE.make_label("BEGIN THE DESCENT", 24, UI_STYLE.COLOR_TEXT)
	menu_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stack.add_child(menu_heading)

	var menu_subtitle: Label = UI_STYLE.make_label(
		"Headphones recommended\nKeyboard and mouse",
		13,
		UI_STYLE.COLOR_TEXT_MUTED
	)
	menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stack.add_child(menu_subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 18.0)
	menu_stack.add_child(spacer)

	_begin_button = UI_STYLE.make_button("BEGIN STORY", true, Vector2(320.0, 56.0))
	_begin_button.pressed.connect(_begin_game)
	menu_stack.add_child(_begin_button)

	var controls_button: Button = UI_STYLE.make_button("CONTROLS", false, Vector2(320.0, 50.0))
	controls_button.pressed.connect(_show_controls)
	menu_stack.add_child(controls_button)

	var quit_button: Button = UI_STYLE.make_button("QUIT GAME", false, Vector2(320.0, 50.0))
	quit_button.pressed.connect(get_tree().quit)
	menu_stack.add_child(quit_button)

	var footer: Label = UI_STYLE.make_label(
		"Some memories are safer when they stay buried.",
		12,
		UI_STYLE.COLOR_TEXT_DIM
	)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stack.add_child(footer)

	_controls_panel = _build_controls_panel()
	_controls_panel.visible = false
	menu_holder.add_child(_controls_panel)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var reveal_tween: Tween = create_tween()
	reveal_tween.tween_property(self, "modulate:a", 1.0, 0.65)


func _build_controls_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(390.0, 410.0)
	UI_STYLE.apply_panel(panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 13)
	panel.add_child(stack)

	var heading: Label = UI_STYLE.make_label("CONTROLS", 27, UI_STYLE.COLOR_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var instructions: Label = UI_STYLE.make_label(
		"WASD\nMove\n\nSHIFT\nSprint\n\nSPACE\nJump\n\nE\nHold to interact\n\nESC\nPause",
		15,
		UI_STYLE.COLOR_TEXT_MUTED
	)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(instructions)

	var back_button: Button = UI_STYLE.make_button("BACK", true, Vector2(300.0, 50.0))
	back_button.pressed.connect(_show_main_panel)
	stack.add_child(back_button)
	return panel


func _build_starfield() -> void:
	for index: int in range(76):
		var star: ColorRect = ColorRect.new()
		var size_value: float = _rng.randf_range(1.0, 3.0)
		var x_anchor: float = _rng.randf_range(0.02, 0.98)
		var y_anchor: float = _rng.randf_range(0.02, 0.98)
		star.anchor_left = x_anchor
		star.anchor_right = x_anchor
		star.anchor_top = y_anchor
		star.anchor_bottom = y_anchor
		star.offset_right = size_value
		star.offset_bottom = size_value
		star.color = Color("a8b8ff") if index % 6 != 0 else Color("e37abb")
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		_stars.append(star)
		_star_phases.append(_rng.randf_range(0.0, TAU))


func _build_background_accents() -> void:
	var left_glow: ColorRect = ColorRect.new()
	left_glow.anchor_bottom = 1.0
	left_glow.offset_right = 6.0
	left_glow.color = Color(0.84, 0.25, 0.60, 0.78)
	left_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_glow)

	var horizon: ColorRect = ColorRect.new()
	horizon.anchor_left = 0.0
	horizon.anchor_right = 1.0
	horizon.anchor_top = 0.78
	horizon.anchor_bottom = 0.78
	horizon.offset_top = -1.0
	horizon.offset_bottom = 1.0
	horizon.color = Color(0.34, 0.20, 0.48, 0.30)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horizon)


func _begin_game() -> void:
	if _transition_started:
		return
	_transition_started = true
	_begin_button.disabled = true
	MusicDirector.stop_music(0.35)
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), 0.75)
	await fade_tween.finished
	get_tree().change_scene_to_file(CEMETERY_SCENE_PATH)


func _show_controls() -> void:
	_main_panel.visible = false
	_controls_panel.visible = true
	var buttons: Array[Node] = _controls_panel.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		var back_button: Button = buttons[0] as Button
		if back_button != null:
			back_button.grab_focus()


func _show_main_panel() -> void:
	_controls_panel.visible = false
	_main_panel.visible = true
	_begin_button.grab_focus()


func _on_cue_missing(cue_id: String, expected_path: String) -> void:
	push_warning("Optional music cue '%s' is unavailable at %s" % [cue_id, expected_path])
