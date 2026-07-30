extends Area3D

signal activated(player: Node)

@export var prompt_text := "Inspect"
@export_multiline var interaction_message := "Something about this place feels familiar."
@export var one_shot := false
@export var music_cue := ""

var _used := false
var _nearby_player: Node


func _ready() -> void:
	monitorable = true
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact(player: Node) -> void:
	if one_shot and _used:
		return

	_used = true
	if player.has_method("show_interaction_message"):
		player.show_interaction_message(interaction_message, 5.0)
	if not music_cue.is_empty():
		MusicDirector.play_cue(music_cue, 1.8)
	activated.emit(player)

	if one_shot and player.has_method("clear_interaction_target"):
		player.clear_interaction_target(self)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_nearby_player = body
	if not (one_shot and _used) and body.has_method("set_interaction_target"):
		body.set_interaction_target(self, prompt_text)


func _on_body_exited(body: Node) -> void:
	if body != _nearby_player:
		return
	_nearby_player = null
	if body.has_method("clear_interaction_target"):
		body.clear_interaction_target(self)
