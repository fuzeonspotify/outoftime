extends Node

const ROAD_SCENE_PATH: String = "res://scenes/road_memory.tscn"

var _scene_root: Node3D
var _woman_interaction: Area3D
var _woman_visual: Node3D
var _player: Node
var _conversation_started: bool = false


func _ready() -> void:
	_connect_conversation.call_deferred()


func _connect_conversation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scene_root = get_parent() as Node3D
	if _scene_root == null:
		return
	_woman_interaction = _scene_root.get_node_or_null("WomanInteraction") as Area3D
	_woman_visual = _scene_root.get_node_or_null("MysteriousWoman") as Node3D
	if _woman_interaction == null or _woman_visual == null:
		push_warning("Cemetery cinematic conversation targets were not found.")
		return

	var legacy_callback: Callable = Callable(_scene_root, "_on_woman_activated")
	if _woman_interaction.is_connected("activated", legacy_callback):
		_woman_interaction.disconnect("activated", legacy_callback)
	var dialogue_callback: Callable = Callable(self, "_on_woman_activated")
	if not _woman_interaction.is_connected("activated", dialogue_callback):
		_woman_interaction.connect("activated", dialogue_callback)
	_woman_interaction.set("suppress_message", true)


func _on_woman_activated(player: Node) -> void:
	if _conversation_started:
		return
	_conversation_started = true
	_player = player
	var callback: Callable = Callable(self, "_on_dialogue_finished")
	var started: bool = DialogueDirector.start_conversation(
		"cemetery_woman",
		player,
		_woman_visual,
		callback
	)
	if not started:
		_conversation_started = false


func _on_dialogue_finished(outcome: String) -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("set_objective"):
		match outcome:
			"trust":
				_player.call("set_objective", "Follow the woman into the memory waiting beyond the gate.")
			"defiance":
				_player.call("set_objective", "Enter the next memory on your own terms.")
			_:
				_player.call("set_objective", "Follow her—but remember what she refused to answer.")
	SFXDirector.play_transition()
	MusicDirector.play_cue("pontiac_memory", 2.5)
	await get_tree().create_timer(1.15).timeout
	await _fade_to_memory_road()


func _fade_to_memory_road() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "MemoryRoadTransition"
	canvas.layer = 180
	add_child(canvas)

	var fade_rect: ColorRect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.015, 0.006, 0.025, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(fade_rect)

	var transition_label: Label = Label.new()
	transition_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_label.text = "THE NEXT MEMORY IS ALREADY MOVING"
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transition_label.add_theme_font_size_override("font_size", 18)
	transition_label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.88, 0.0))
	transition_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	transition_label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(transition_label)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(fade_rect, "color", Color(0.008, 0.003, 0.015, 1.0), 1.15)
	tween.tween_property(transition_label, "theme_override_colors/font_color", Color("bba4d1"), 0.75).set_delay(0.35)
	await tween.finished
	SFXDirector.stop_environment(0.4)
	get_tree().change_scene_to_file(ROAD_SCENE_PATH)
