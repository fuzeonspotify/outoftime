extends Node

const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"

var _canvas: CanvasLayer
var _overlay: Control
var _resume_button: Button
var _pause_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_pause_open(not _pause_open)
		get_viewport().set_input_as_handled()


func _build_pause_menu() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "MemoryTrainPauseCanvas"
	_canvas.layer = 180
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.add_child(_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.003, 0.015, 0.93)
	_overlay.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 430.0)
	panel.add_theme_stylebox_override(
		"panel",
		UI_STYLE.make_signal_panel_style(
			Color(0.025, 0.010, 0.042, 0.98),
			UI_STYLE.COLOR_ACCENT,
			28.0
		)
	)
	center.add_child(panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)

	var eyebrow: Label = UI_STYLE.make_label("CHAPTER III  //  MEMORY TRAIN", 13, UI_STYLE.COLOR_ACCENT_COOL)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)

	var heading: Label = UI_STYLE.make_label("TRAIN SUSPENDED", 36, UI_STYLE.COLOR_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var note: Label = UI_STYLE.make_label(
		"The wheels are still turning somewhere outside the pause.",
		13,
		UI_STYLE.COLOR_TEXT_MUTED
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(note)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 12.0)
	stack.add_child(spacer)

	_resume_button = UI_STYLE.make_button("RESUME RUN", true, Vector2(320.0, 54.0))
	_resume_button.pressed.connect(_on_resume_pressed)
	stack.add_child(_resume_button)

	var restart_button: Button = UI_STYLE.make_button("RESTART MEMORY TRAIN", false, Vector2(320.0, 48.0))
	restart_button.pressed.connect(_on_restart_pressed)
	stack.add_child(restart_button)

	var title_button: Button = UI_STYLE.make_button("RETURN TO TITLE", false, Vector2(320.0, 48.0))
	title_button.pressed.connect(_on_title_pressed)
	stack.add_child(title_button)

	var quit_button: Button = UI_STYLE.make_button("QUIT GAME", false, Vector2(320.0, 48.0))
	quit_button.pressed.connect(get_tree().quit)
	stack.add_child(quit_button)


func _set_pause_open(open_value: bool) -> void:
	if _overlay == null:
		return
	_pause_open = open_value
	_overlay.visible = open_value
	get_tree().paused = open_value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SFXDirector.duck_for_dialogue(open_value)
	MusicDirector.duck_for_dialogue(open_value)
	if open_value and _resume_button != null:
		_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_pause_open(false)


func _on_restart_pressed() -> void:
	_set_pause_open(false)
	MusicDirector.stop_music(1.0)
	SFXDirector.stop_environment(0.6)
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	_set_pause_open(false)
	MusicDirector.stop_music(2.0)
	SFXDirector.stop_environment(0.8)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
