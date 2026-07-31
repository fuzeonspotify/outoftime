extends Node

const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"

var _scan_timer: float = 0.0
var _styled_controls: Dictionary = {}
var _pause_canvas: CanvasLayer
var _pause_overlay: Control
var _resume_button: Button
var _pause_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_build_pause_menu()
	_apply_release_copy.call_deferred()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.35
	_apply_release_copy()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_pause_open(not _pause_open)
		get_viewport().set_input_as_handled()


func _apply_release_copy() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	var labels: Array[Node] = scene_root.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label == null:
			continue
		if label.text.contains("opens into a city that should not exist") or label.text.contains("gravity has been torn apart"):
			label.text = "The bridge keeps driving toward an ending you cannot remember."
		elif label.text == "PONTIAC  //  MEMORY BRIDGE":
			label.text = "CHAPTER II  //  THE MEMORY ROAD"
		elif label.text.contains("DODGE THE DEAD"):
			label.text = "A / D  STEER    •    MOUSE WHEEL  CAMERA    •    AVOID FAILED MEMORIES"
		_style_label(label)

	var buttons: Array[Node] = scene_root.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button == null:
			continue
		UI_STYLE.apply_button(button, button.text == "RESUME")


func _style_label(label: Label) -> void:
	var instance_id: int = label.get_instance_id()
	if _styled_controls.has(instance_id):
		return
	var text_value: String = label.text.strip_edges()
	if text_value.begins_with("CHAPTER II"):
		UI_STYLE.apply_label(label, 22, UI_STYLE.COLOR_TEXT, 5)
	elif text_value.begins_with("MEMORY DISTANCE") or text_value.begins_with("BRIDGE SIGNAL"):
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_ACCENT_COOL, 3)
	elif text_value.begins_with("MEMORY INTEGRITY"):
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_ACCENT, 3)
	elif text_value.contains("STEER"):
		UI_STYLE.apply_label(label, 13, UI_STYLE.COLOR_TEXT_MUTED, 3)
	elif label.get_theme_font_size("font_size") >= 28:
		UI_STYLE.apply_label(label, label.get_theme_font_size("font_size"), UI_STYLE.COLOR_TEXT, 6)
	else:
		UI_STYLE.apply_label(label, maxi(15, label.get_theme_font_size("font_size")), UI_STYLE.COLOR_TEXT_MUTED, 3)
	_styled_controls[instance_id] = true


func _build_pause_menu() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	_pause_canvas = CanvasLayer.new()
	_pause_canvas.name = "RoadPauseMenu"
	_pause_canvas.layer = 100
	_pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	scene_root.call_deferred("add_child", _pause_canvas)
	await get_tree().process_frame

	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_canvas.add_child(_pause_overlay)

	var fade: ColorRect = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.01, 0.005, 0.018, 0.90)
	_pause_overlay.add_child(fade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 390.0)
	UI_STYLE.apply_panel(panel)
	center.add_child(panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)

	var heading: Label = UI_STYLE.make_label("PAUSED", 38, UI_STYLE.COLOR_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var chapter: Label = UI_STYLE.make_label("CHAPTER II  //  THE MEMORY ROAD", 13, UI_STYLE.COLOR_ACCENT_COOL)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(chapter)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 14.0)
	stack.add_child(spacer)

	_resume_button = UI_STYLE.make_button("RESUME", true, Vector2(300.0, 52.0))
	_resume_button.pressed.connect(_on_resume_pressed)
	stack.add_child(_resume_button)

	var restart_button: Button = UI_STYLE.make_button("RESTART CHAPTER", false, Vector2(300.0, 48.0))
	restart_button.pressed.connect(_on_restart_pressed)
	stack.add_child(restart_button)

	var title_button: Button = UI_STYLE.make_button("RETURN TO TITLE", false, Vector2(300.0, 48.0))
	title_button.pressed.connect(_on_title_pressed)
	stack.add_child(title_button)

	var quit_button: Button = UI_STYLE.make_button("QUIT GAME", false, Vector2(300.0, 48.0))
	quit_button.pressed.connect(get_tree().quit)
	stack.add_child(quit_button)


func _set_pause_open(open_value: bool) -> void:
	if _pause_overlay == null:
		return
	_pause_open = open_value
	_pause_overlay.visible = open_value
	get_tree().paused = open_value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if open_value and _resume_button != null:
		_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_pause_open(false)


func _on_restart_pressed() -> void:
	_set_pause_open(false)
	SFXDirector.stop_environment(0.2)
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	_set_pause_open(false)
	MusicDirector.stop_music(0.4)
	SFXDirector.stop_environment(0.4)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
