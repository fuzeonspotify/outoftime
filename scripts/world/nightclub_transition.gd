extends Node

const NIGHTCLUB_SCENE_PATH: String = "res://scenes/ruined_nightclub.tscn"

var _transition_started: bool = false


func _ready() -> void:
	_connect_void_portal.call_deferred()


func _connect_void_portal() -> void:
	var void_root: Node = get_parent()
	if void_root == null:
		return
	var entrance: Area3D = void_root.get_node_or_null("NightclubEntrance") as Area3D
	if entrance == null:
		push_warning("NightclubEntrance portal was not found in the afterlife void.")
		return
	var callback: Callable = Callable(self, "_on_nightclub_entered")
	if not entrance.is_connected("activated", callback):
		entrance.connect("activated", callback)


func _on_nightclub_entered(player: Node) -> void:
	if _transition_started:
		return
	_transition_started = true
	if player.has_method("set_objective"):
		player.call("set_objective", "Enter the ruined nightclub through the void.")
	SFXDirector.stop_environment(0.55)
	await get_tree().create_timer(0.65).timeout
	get_tree().change_scene_to_file(NIGHTCLUB_SCENE_PATH)
