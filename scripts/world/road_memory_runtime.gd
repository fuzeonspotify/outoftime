extends "res://scripts/world/road_memory.gd"

var _void_transition_started: bool = false


func _continue_to_city() -> void:
	if _void_transition_started:
		return
	_void_transition_started = true
	SFXDirector.stop_environment(0.8)
	var void_scene: PackedScene = StartupPreloader.get_preloaded_scene(CITY_SCENE_PATH)
	if void_scene != null:
		get_tree().change_scene_to_packed(void_scene)
	else:
		get_tree().change_scene_to_file(CITY_SCENE_PATH)
