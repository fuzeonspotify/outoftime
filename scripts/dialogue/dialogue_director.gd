extends Node

signal conversation_started(conversation_id: String)
signal conversation_finished(conversation_id: String, outcome: String)

const DIALOGUE_PATH: String = "res://data/dialogues.json"
const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")

var _dialogues: Dictionary = {}
var _active: bool = false
var _conversation_id: String = ""
var _current_node_id: String = ""
var _current_node: Dictionary = {}
var _current_outcome: String = ""
var _player: Node
var _speaker: Node3D
var _completion_callback: Callable = Callable()

var _gameplay_camera: Camera3D
var _cinematic_camera: Camera3D
var _camera_target: Vector3 = Vector3.ZERO
var _camera_time: float = 0.0

var _canvas: CanvasLayer
var _overlay: Control
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _body_label: RichTextLabel
var _choices: VBoxContainer
var _choice_hint: Label
var _memory_link_label: Label
var _scanlines: Array[ColorRect] = []
var _typing_tween: Tween
var _text_fully_revealed: bool = false
var _last_tick_index: int = -1
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_dialogues()
	_build_interface()


func _process(delta: float) -> void:
	if not _active:
		return
	_camera_time += delta
	_update_cinematic_camera()
	_update_typewriter_audio()
	_update_scanlines()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if not _text_fully_revealed:
			_reveal_text_immediately()
		elif _choice_buttons.size() == 1 and _current_node.get("choices", []).is_empty():
			_choice_buttons[0].emit_signal("pressed")
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var choice_index: int = -1
			match key_event.physical_keycode:
				KEY_1:
					choice_index = 0
				KEY_2:
					choice_index = 1
				KEY_3:
					choice_index = 2
				KEY_4:
					choice_index = 3
			if choice_index >= 0 and choice_index < _choice_buttons.size() and _text_fully_revealed:
				_choice_buttons[choice_index].emit_signal("pressed")
				get_viewport().set_input_as_handled()


func start_conversation(
	conversation_id: String,
	player: Node,
	speaker: Node3D,
	completion_callback: Callable = Callable()
) -> bool:
	if _active or player == null or speaker == null:
		return false
	var conversation_variant: Variant = _dialogues.get(conversation_id)
	if not (conversation_variant is Dictionary):
		push_warning("Dialogue conversation not found: %s" % conversation_id)
		return false
	var conversation: Dictionary = conversation_variant as Dictionary
	var start_node: String = str(conversation.get("start", ""))
	if start_node.is_empty():
		return false

	_active = true
	_conversation_id = conversation_id
	_current_outcome = str(conversation.get("default_outcome", ""))
	_player = player
	_speaker = speaker
	_completion_callback = completion_callback
	_camera_time = 0.0
	_gameplay_camera = get_viewport().get_camera_3d()
	_create_cinematic_camera()

	if _player.has_method("set_cinematic_mode"):
		_player.call("set_cinematic_mode", true)
	SFXDirector.duck_for_dialogue(true)
	MusicDirector.duck_for_dialogue(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_overlay.visible = true
	_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_top_bar.size.y = 0.0
	_bottom_bar.size.y = 0.0
	var reveal_tween: Tween = create_tween().set_parallel(true)
	reveal_tween.tween_property(_overlay, "modulate:a", 1.0, 0.32)
	reveal_tween.tween_property(_top_bar, "size:y", 68.0, 0.42).set_trans(Tween.TRANS_SINE)
	reveal_tween.tween_property(_bottom_bar, "size:y", 68.0, 0.42).set_trans(Tween.TRANS_SINE)

	conversation_started.emit(conversation_id)
	_show_node(start_node)
	return true


func is_conversation_active() -> bool:
	return _active


func _load_dialogues() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_error("Dialogue data is missing: %s" % DIALOGUE_PATH)
		return
	var file: FileAccess = FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open dialogue data: %s" % DIALOGUE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_dialogues = parsed as Dictionary
	else:
		push_error("Dialogue data contains invalid JSON.")


func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "CinematicDialogue"
	_canvas.layer = 140
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	_overlay = Control.new()
	_overlay.name = "DialogueOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.add_child(_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.008, 0.028, 0.20)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	_build_scanlines()

	_top_bar = ColorRect.new()
	_top_bar.anchor_right = 1.0
	_top_bar.color = Color(0.005, 0.003, 0.010, 0.98)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_top_bar)

	_bottom_bar = ColorRect.new()
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_bar.color = Color(0.005, 0.003, 0.010, 0.98)
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_bottom_bar)

	var upper_status: HBoxContainer = HBoxContainer.new()
	upper_status.anchor_left = 0.07
	upper_status.anchor_right = 0.93
	upper_status.offset_top = 17.0
	upper_status.offset_bottom = 50.0
	upper_status.add_theme_constant_override("separation", 16)
	_overlay.add_child(upper_status)

	_memory_link_label = UI_STYLE.make_label("MEMORY LINK  //  ESTABLISHED", 12, UI_STYLE.COLOR_ACCENT_COOL)
	_memory_link_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper_status.add_child(_memory_link_label)

	var input_hint: Label = UI_STYLE.make_label("ENTER  REVEAL    1—4  RESPOND", 11, UI_STYLE.COLOR_TEXT_DIM)
	input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	upper_status.add_child(input_hint)

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.name = "DialoguePanel"
	_dialogue_panel.anchor_left = 0.10
	_dialogue_panel.anchor_right = 0.90
	_dialogue_panel.anchor_top = 0.60
	_dialogue_panel.anchor_bottom = 0.92
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_panel.add_theme_stylebox_override(
		"panel",
		UI_STYLE.make_signal_panel_style(Color(0.025, 0.016, 0.047, 0.97), UI_STYLE.COLOR_ACCENT, 20.0)
	)
	_overlay.add_child(_dialogue_panel)

	var content_margin: MarginContainer = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 26)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 26)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	_dialogue_panel.add_child(content_margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content_margin.add_child(content)

	var speaker_row: HBoxContainer = HBoxContainer.new()
	speaker_row.add_theme_constant_override("separation", 12)
	content.add_child(speaker_row)

	var speaker_mark: ColorRect = ColorRect.new()
	speaker_mark.custom_minimum_size = Vector2(5.0, 22.0)
	speaker_mark.color = UI_STYLE.COLOR_ACCENT
	speaker_row.add_child(speaker_mark)

	_speaker_label = UI_STYLE.make_label("THE WOMAN", 14, UI_STYLE.COLOR_ACCENT)
	_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_row.add_child(_speaker_label)

	var signal_label: Label = UI_STYLE.make_label("VOICEPRINT / UNKNOWN", 10, UI_STYLE.COLOR_TEXT_DIM)
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speaker_row.add_child(signal_label)

	_body_label = RichTextLabel.new()
	_body_label.name = "DialogueText"
	_body_label.bbcode_enabled = false
	_body_label.fit_content = false
	_body_label.custom_minimum_size = Vector2(0.0, 78.0)
	_body_label.scroll_active = false
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE.apply_rich_text(_body_label, 23, UI_STYLE.COLOR_TEXT)
	content.add_child(_body_label)

	var response_rule: ColorRect = ColorRect.new()
	response_rule.custom_minimum_size = Vector2(0.0, 1.0)
	response_rule.color = Color(0.49, 0.38, 0.72, 0.50)
	content.add_child(response_rule)

	_choice_hint = UI_STYLE.make_label("CHOOSE WHAT THIS VERSION OF YOU SAYS", 10, UI_STYLE.COLOR_TEXT_DIM)
	content.add_child(_choice_hint)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 7)
	content.add_child(_choices)


func _build_scanlines() -> void:
	for index: int in range(28):
		var line: ColorRect = ColorRect.new()
		var y_anchor: float = float(index) / 27.0
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = y_anchor
		line.anchor_bottom = y_anchor
		line.offset_bottom = 1.0
		line.color = Color(0.38, 0.25, 0.56, 0.018)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(line)
		_scanlines.append(line)


func _show_node(node_id: String) -> void:
	var conversation_variant: Variant = _dialogues.get(_conversation_id)
	if not (conversation_variant is Dictionary):
		_finish_conversation()
		return
	var conversation: Dictionary = conversation_variant as Dictionary
	var nodes_variant: Variant = conversation.get("nodes")
	if not (nodes_variant is Dictionary):
		_finish_conversation()
		return
	var nodes: Dictionary = nodes_variant as Dictionary
	var node_variant: Variant = nodes.get(node_id)
	if not (node_variant is Dictionary):
		_finish_conversation()
		return

	_current_node_id = node_id
	_current_node = node_variant as Dictionary
	_clear_choices()
	_text_fully_revealed = false
	_last_tick_index = -1
	_speaker_label.text = str(_current_node.get("speaker", "MEMORY")).to_upper()
	_body_label.text = str(_current_node.get("text", ""))
	_body_label.visible_ratio = 0.0
	_choice_hint.text = "LISTENING..."
	_set_camera_shot(str(_current_node.get("shot", "two_shot")))

	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	var duration: float = clampf(float(_body_label.text.length()) * 0.019, 0.42, 3.2)
	_typing_tween = create_tween()
	_typing_tween.tween_property(_body_label, "visible_ratio", 1.0, duration)
	_typing_tween.finished.connect(_on_typewriter_finished)


func _on_typewriter_finished() -> void:
	_text_fully_revealed = true
	_body_label.visible_ratio = 1.0
	_build_choices_for_current_node()


func _reveal_text_immediately() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	_body_label.visible_ratio = 1.0
	_text_fully_revealed = true
	_build_choices_for_current_node()


func _build_choices_for_current_node() -> void:
	if not _choice_buttons.is_empty():
		return
	var choices_variant: Variant = _current_node.get("choices", [])
	var node_choices: Array = choices_variant as Array if choices_variant is Array else []
	if node_choices.is_empty():
		_choice_hint.text = "THE MEMORY IS WAITING"
		var end_text: String = "CONTINUE" if _current_node.has("next") else "END CONVERSATION"
		var continue_button: Button = UI_STYLE.make_button(end_text, true, Vector2(0.0, 42.0))
		continue_button.pressed.connect(_on_continue_pressed)
		_choices.add_child(continue_button)
		_choice_buttons.append(continue_button)
		continue_button.grab_focus()
		return

	_choice_hint.text = "CHOOSE WHAT THIS VERSION OF YOU SAYS"
	for index: int in range(node_choices.size()):
		var choice_variant: Variant = node_choices[index]
		if not (choice_variant is Dictionary):
			continue
		var choice: Dictionary = choice_variant as Dictionary
		var choice_button: Button = UI_STYLE.make_button(
			"%02d  //  %s" % [index + 1, str(choice.get("text", "..."))],
			index == 0,
			Vector2(0.0, 40.0)
		)
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.pressed.connect(_on_choice_selected.bind(index))
		_choices.add_child(choice_button)
		_choice_buttons.append(choice_button)
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus()


func _clear_choices() -> void:
	_choice_buttons.clear()
	for child: Node in _choices.get_children():
		child.queue_free()


func _on_choice_selected(choice_index: int) -> void:
	if not _text_fully_revealed:
		return
	var choices_variant: Variant = _current_node.get("choices", [])
	if not (choices_variant is Array):
		return
	var node_choices: Array = choices_variant as Array
	if choice_index < 0 or choice_index >= node_choices.size():
		return
	var choice_variant: Variant = node_choices[choice_index]
	if not (choice_variant is Dictionary):
		return
	var choice: Dictionary = choice_variant as Dictionary
	var tone: String = str(choice.get("tone", ""))
	if not tone.is_empty():
		_current_outcome = tone
	SFXDirector.play_dialogue_choice()
	_pulse_camera()
	var next_node: String = str(choice.get("next", ""))
	if next_node.is_empty():
		_finish_conversation()
	else:
		_show_node(next_node)


func _on_continue_pressed() -> void:
	SFXDirector.play_dialogue_choice()
	var next_node: String = str(_current_node.get("next", ""))
	if not next_node.is_empty():
		_show_node(next_node)
		return
	var node_outcome: String = str(_current_node.get("outcome", ""))
	if not node_outcome.is_empty():
		_current_outcome = node_outcome
	_finish_conversation()


func _create_cinematic_camera() -> void:
	_cinematic_camera = Camera3D.new()
	_cinematic_camera.name = "DialogueCamera"
	_cinematic_camera.fov = 58.0
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		add_child(_cinematic_camera)
	else:
		current_scene.add_child(_cinematic_camera)
	if _gameplay_camera != null:
		_cinematic_camera.global_transform = _gameplay_camera.global_transform
		_cinematic_camera.fov = _gameplay_camera.fov
	_cinematic_camera.current = true


func _set_camera_shot(shot_name: String) -> void:
	if _cinematic_camera == null:
		return
	var player_focus: Vector3 = _player_focus_position()
	var speaker_focus: Vector3 = _speaker_focus_position()
	var direction: Vector3 = speaker_focus - player_focus
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var side: Vector3 = Vector3.UP.cross(direction).normalized()
	var midpoint: Vector3 = (player_focus + speaker_focus) * 0.5
	var destination: Vector3
	var target: Vector3
	var target_fov: float = 55.0

	match shot_name:
		"speaker_close":
			destination = speaker_focus - direction * 2.8 + side * 1.05 + Vector3.UP * 0.45
			target = speaker_focus
			target_fov = 48.0
		"player_close":
			destination = player_focus + direction * 2.7 - side * 1.0 + Vector3.UP * 0.42
			target = player_focus
			target_fov = 49.0
		"wide":
			destination = midpoint + side * 6.2 + Vector3.UP * 2.5 - direction * 1.0
			target = midpoint
			target_fov = 62.0
		_:
			destination = midpoint + side * 4.6 + Vector3.UP * 1.5
			target = midpoint
			target_fov = 56.0

	_camera_target = target
	var camera_tween: Tween = create_tween().set_parallel(true)
	camera_tween.tween_property(_cinematic_camera, "global_position", destination, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_cinematic_camera, "fov", target_fov, 0.78).set_trans(Tween.TRANS_SINE)


func _update_cinematic_camera() -> void:
	if _cinematic_camera == null:
		return
	var target_drift: Vector3 = Vector3(
		sin(_camera_time * 0.71) * 0.025,
		sin(_camera_time * 0.53) * 0.020,
		0.0
	)
	var look_target: Vector3 = _camera_target + target_drift
	if _cinematic_camera.global_position.distance_squared_to(look_target) > 0.01:
		_cinematic_camera.look_at(look_target, Vector3.UP)


func _pulse_camera() -> void:
	if _cinematic_camera == null:
		return
	var base_fov: float = _cinematic_camera.fov
	var pulse: Tween = create_tween()
	pulse.tween_property(_cinematic_camera, "fov", base_fov - 1.8, 0.10)
	pulse.tween_property(_cinematic_camera, "fov", base_fov, 0.20)


func _player_focus_position() -> Vector3:
	if _player != null and _player.has_method("get_dialogue_focus_position"):
		var result: Variant = _player.call("get_dialogue_focus_position")
		if result is Vector3:
			return result as Vector3
	var player_3d: Node3D = _player as Node3D
	return player_3d.global_position + Vector3.UP * 1.45 if player_3d != null else Vector3.ZERO


func _speaker_focus_position() -> Vector3:
	return _speaker.global_position + Vector3.UP * 1.45 if _speaker != null else Vector3.ZERO


func _update_typewriter_audio() -> void:
	if _text_fully_revealed or _body_label.text.is_empty():
		return
	var visible_characters: int = int(round(_body_label.visible_ratio * float(_body_label.text.length())))
	var tick_index: int = visible_characters / 3
	if tick_index > _last_tick_index:
		_last_tick_index = tick_index
		SFXDirector.play_dialogue_tick()


func _update_scanlines() -> void:
	for index: int in range(_scanlines.size()):
		var alpha: float = 0.010 + (sin(_camera_time * 1.7 + float(index) * 0.43) * 0.5 + 0.5) * 0.014
		var line: ColorRect = _scanlines[index]
		line.color.a = alpha


func _finish_conversation() -> void:
	if not _active:
		return
	_active = false
	var finished_id: String = _conversation_id
	var finished_outcome: String = _current_outcome
	_clear_choices()

	var fade_tween: Tween = create_tween().set_parallel(true)
	fade_tween.tween_property(_overlay, "modulate:a", 0.0, 0.34)
	fade_tween.tween_property(_top_bar, "size:y", 0.0, 0.34)
	fade_tween.tween_property(_bottom_bar, "size:y", 0.0, 0.34)
	await fade_tween.finished
	_overlay.visible = false

	if _gameplay_camera != null and is_instance_valid(_gameplay_camera):
		_gameplay_camera.current = true
	if _cinematic_camera != null and is_instance_valid(_cinematic_camera):
		_cinematic_camera.queue_free()
	_cinematic_camera = null

	if _player != null and is_instance_valid(_player) and _player.has_method("set_cinematic_mode"):
		_player.call("set_cinematic_mode", false)
	SFXDirector.duck_for_dialogue(false)
	MusicDirector.duck_for_dialogue(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	conversation_finished.emit(finished_id, finished_outcome)
	if _completion_callback.is_valid():
		_completion_callback.call(finished_outcome)

	_conversation_id = ""
	_current_node_id = ""
	_current_node = {}
	_current_outcome = ""
	_player = null
	_speaker = null
	_completion_callback = Callable()
