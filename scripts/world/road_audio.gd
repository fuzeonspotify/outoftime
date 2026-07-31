extends Node


func _ready() -> void:
	SFXDirector.start_pontiac_ambience()


func _exit_tree() -> void:
	SFXDirector.stop_environment(0.45)
