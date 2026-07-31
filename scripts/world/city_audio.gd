extends Node


func _ready() -> void:
	await get_tree().create_timer(0.70).timeout
	SFXDirector.start_city_ambience()
