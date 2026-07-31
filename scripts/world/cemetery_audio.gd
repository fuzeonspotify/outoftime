extends Node


func _ready() -> void:
	call_deferred("_apply_scene_audio_and_polish")


func _exit_tree() -> void:
	SFXDirector.stop_environment(0.35)


func _apply_scene_audio_and_polish() -> void:
	MusicDirector.stop_music(0.15)
	SFXDirector.start_cemetery_ambience()
	_fix_memorial_inscription()
	_connect_memorial_reveal_sound()


func _fix_memorial_inscription() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	for child: Node in scene_root.get_children():
		var label: Label3D = child as Label3D
		if label != null and label.text.begins_with("FOR THE ONES"):
			label.rotation_degrees.y = 0.0
			return


func _connect_memorial_reveal_sound() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	var memorial: Node = scene_root.get_node_or_null("MemorialInteraction")
	if memorial != null:
		memorial.connect("activated", Callable(self, "_on_memorial_activated"))


func _on_memorial_activated(_player: Node) -> void:
	SFXDirector.play_reveal()
