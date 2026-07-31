extends Node

var _player: Node
var _hud: CanvasLayer
var _was_processing: bool = true
var _was_physics_processing: bool = true
var _was_input_processing: bool = true
var _was_unhandled_input_processing: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueDirector.conversation_started.connect(Callable(self, "_on_conversation_started"))
	DialogueDirector.conversation_finished.connect(Callable(self, "_on_conversation_finished"))


func _on_conversation_started(_conversation_id: String) -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return

	_was_processing = _player.is_processing()
	_was_physics_processing = _player.is_physics_processing()
	_was_input_processing = _player.is_processing_input()
	_was_unhandled_input_processing = _player.is_processing_unhandled_input()

	_player.set_process(false)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)

	var character: CharacterBody3D = _player as CharacterBody3D
	if character != null:
		character.velocity = Vector3.ZERO

	_hud = _player.get_node_or_null("PlayerHUD") as CanvasLayer
	if _hud != null:
		_hud.visible = false


func _on_conversation_finished(_conversation_id: String, _outcome: String) -> void:
	if _player == null or not is_instance_valid(_player):
		_reset_state()
		return

	_player.set_process(_was_processing)
	_player.set_physics_process(_was_physics_processing)
	_player.set_process_input(_was_input_processing)
	_player.set_process_unhandled_input(_was_unhandled_input_processing)
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	_reset_state()


func _reset_state() -> void:
	_player = null
	_hud = null
	_was_processing = true
	_was_physics_processing = true
	_was_input_processing = true
	_was_unhandled_input_processing = true
