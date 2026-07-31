extends Node

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
	SFXDirector.start_chamber_ambience()
	_woman_interaction = _scene_root.get_node_or_null("ConfrontWoman") as Area3D
	_woman_visual = _scene_root.get_node_or_null("WomanAtDais") as Node3D
	if _woman_interaction == null or _woman_visual == null:
		push_warning("Chamber cinematic conversation targets were not found.")
		return

	var legacy_callback: Callable = Callable(_scene_root, "_on_woman_confronted")
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
		"chamber_woman",
		player,
		_woman_visual,
		callback
	)
	if not started:
		_conversation_started = false


func _on_dialogue_finished(outcome: String) -> void:
	if _scene_root == null or not is_instance_valid(_scene_root):
		return
	_scene_root.set("_chapter_finished", true)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_objective"):
		match outcome:
			"mercy":
				_player.call("set_objective", "THE CYCLE HAS LOST ITS HOLD")
			"truth":
				_player.call("set_objective", "DESTROY THE MACHINE THAT FEEDS ON ENDINGS")
			_:
				_player.call("set_objective", "THE CYCLE IS BREAKING")
	SFXDirector.play_reveal()
	MusicDirector.stop_music(2.0)
	await get_tree().create_timer(1.6).timeout
	if _scene_root.has_method("_show_chapter_end"):
		_scene_root.call("_show_chapter_end")
