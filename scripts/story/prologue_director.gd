extends Node

const ROAD_SCENE_PATH: String = "res://scenes/road_memory.tscn"

var _sequence_started: bool = false
var _dialogue_layer: CanvasLayer
var _speaker_label: Label
var _dialogue_label: Label
var _continue_button: Button
var _fade_rect: ColorRect


func _ready() -> void:
	call_deferred("_bind_woman_interaction")


func _bind_woman_interaction() -> void:
	var attempts: int = 0
	while attempts < 12:
		var areas: Array[Node] = get_parent().find_children("*", "Area3D", true, false)
		for node: Node in areas:
			var area: Area3D = node as Area3D
			if area == null:
				continue
			var prompt_value: Variant = area.get("prompt_text")
			if str(prompt_value) != "Speak to the woman":
				continue
			var activation_handler: Callable = Callable(self, "_on_woman_activated")
			if not area.is_connected("activated", activation_handler):
				area.connect("activated", activation_handler)
			return
		attempts += 1
		await get_tree().process_frame

	push_warning("Prologue director could not find the woman interaction area.")


func _on_woman_activated(player: Node) -> void:
	if _sequence_started:
		return
	_sequence_started = true
	_run_dialogue_sequence(player)


func _run_dialogue_sequence(player: Node) -> void:
	await get_tree().create_timer(5.1).timeout

	var player_body: CharacterBody3D = player as CharacterBody3D
	if player_body != null:
		player_body.set_physics_process(false)
		player_body.set_process_unhandled_input(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_dialogue_ui()

	var speakers: Array[String] = [
		"SKELETON",
		"WOMAN",
		"SKELETON",
		"WOMAN"
	]
	var lines: Array[String] = [
		"Do I know you?",
		"Not yet. But you always do.",
		"Always?",
		"Come with me. The road remembers us."
	]

	for index: int in range(lines.size()):
		_speaker_label.text = speakers[index]
		_dialogue_label.text = lines[index]
		_continue_button.text = "FOLLOW HER" if index == lines.size() - 1 else "CONTINUE"
		await _continue_button.pressed

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), 1.4)
	await fade_tween.finished
	get_tree().change_scene_to_file(ROAD_SCENE_PATH)


func _build_dialogue_ui() -> void:
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.layer = 50
	add_child(_dialogue_layer)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.03, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(shade)

	var panel: ColorRect = ColorRect.new()
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.67
	panel.anchor_bottom = 0.94
	panel.color = Color(0.035, 0.045, 0.075, 0.96)
	_dialogue_layer.add_child(panel)

	_speaker_label = Label.new()
	_speaker_label.anchor_left = 0.04
	_speaker_label.anchor_right = 0.96
	_speaker_label.anchor_top = 0.08
	_speaker_label.anchor_bottom = 0.28
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", Color("9ca8cb"))
	panel.add_child(_speaker_label)

	_dialogue_label = Label.new()
	_dialogue_label.anchor_left = 0.04
	_dialogue_label.anchor_right = 0.96
	_dialogue_label.anchor_top = 0.28
	_dialogue_label.anchor_bottom = 0.72
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_size_override("font_size", 29)
	_dialogue_label.add_theme_color_override("font_color", Color("eef0f7"))
	panel.add_child(_dialogue_label)

	_continue_button = Button.new()
	_continue_button.anchor_left = 0.68
	_continue_button.anchor_right = 0.96
	_continue_button.anchor_top = 0.76
	_continue_button.anchor_bottom = 0.94
	_continue_button.text = "CONTINUE"
	_continue_button.add_theme_font_size_override("font_size", 16)
	panel.add_child(_continue_button)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(_fade_rect)
