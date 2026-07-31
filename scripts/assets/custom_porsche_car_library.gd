extends Node

const CUSTOM_CAR_PATH: String = "res://assets/models/cars/porsche_911_turbo.glb"
const CUSTOM_CAR_SCENE: PackedScene = preload("res://assets/models/cars/porsche_911_turbo.glb")

var _prototype: Node3D


func prepare() -> bool:
	_prototype = CUSTOM_CAR_SCENE.instantiate() as Node3D
	if _prototype == null:
		push_error("REQUIRED MODEL ERROR: porsche_911_turbo.glb could not be instantiated. No backup car is allowed.")
		return false
	return true


func get_prototype() -> Node3D:
	return _prototype


func get_selected_model_name() -> String:
	return CUSTOM_CAR_PATH.get_file()
