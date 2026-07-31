extends Node

const NIGHTCLUB_SCENE_PATH: String = "res://scenes/ruined_nightclub.tscn"

var _transition_started: bool = false


func _ready() -> void:
	call_deferred("_connect_nightclub_entrance")


func _connect_nightclub_entrance() -> void:
	var city_root: Node = get_parent()
	if city_root == null:
		return
	var entrance: Area3D = city_root.get_node_or_null("NightclubEntrance") as Area3D
	if entrance == null:
		push_warning("NightclubEntrance was not found in the afterlife city.")
		return
	var callback: Callable = Callable(self, "_on_nightclub_entered")
	if not entrance.is_connected("activated", callback):
		entrance.connect("activated", callback)


func _on_nightclub_entered(player: Node) -> void:
	if _transition_started:
		return
	_transition_started = true
	if player.has_method("set_objective"):
		player.call("set_objective", "Enter the ruined nightclub.")
	SFXDirector.stop_environment(0.55)
	await get_tree().create_timer(0.65).timeout
	get_tree().change_scene_to_file(NIGHTCLUB_SCENE_PATH)
