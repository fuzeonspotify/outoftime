extends "res://scripts/assets/kenney_car_library.gd"

const CUSTOM_CAR_PATHS: Array[String] = [
	"res://assets/models/cars/porsche_911_turbo.glb",
	"res://assets/models/cars/porsche_911_turbo.gltf"
]


func prepare() -> bool:
	for model_path: String in CUSTOM_CAR_PATHS:
		if not FileAccess.file_exists(model_path):
			continue
		var custom_prototype: Node3D = _load_model_prototype(model_path)
		if custom_prototype == null:
			continue
		_prototype = custom_prototype
		_selected_model_path = model_path
		return true
	return await super.prepare()
