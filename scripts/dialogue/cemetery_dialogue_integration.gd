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
