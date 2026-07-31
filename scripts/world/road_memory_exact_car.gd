extends "res://scripts/world/road_memory_final_cut.gd"


func _build_car() -> void:
	var prototype: Node3D = StartupPreloader.get_car_prototype()
	if prototype == null:
		push_error("REQUIRED MODEL ERROR: assets/models/cars/porsche_911_turbo.glb did not load. No substitute vehicle will be created.")
		return

	_car = Node3D.new()
	_car.name = "SpectralPontiac"
	_car.position = Vector3(0.0, 0.04, 8.0)
	add_child(_car)

	_real_car_visual = prototype.duplicate() as Node3D
	if _real_car_visual == null:
		_car.queue_free()
		_car = null
		push_error("REQUIRED MODEL ERROR: the Porsche prototype could not be duplicated. No substitute vehicle will be created.")
		return

	_real_car_visual.name = "Porsche911Turbo"
	_car.add_child(_real_car_visual)
	_normalize_car_model(_real_car_visual)
	# The supplied Porsche faces positive Z. Bridge travel is toward negative Z.
	_real_car_visual.rotation_degrees.y = 180.0
	_tint_car_model(_real_car_visual)
	_add_car_lighting()
	_add_car_camera()
