extends "res://scripts/world/porsche_wheel_spin_release.gd"

var _wheel_skip_reported: bool = false


func _try_initialize() -> void:
	_initialization_attempts += 1
	if _initialization_attempts > 240:
		_disable_wheel_animation_cleanly(
			"exact Porsche wheel nodes were not exposed as separate transformable meshes"
		)
		return

	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return
	_car = _road.get("_car") as Node3D
	if _car == null or not is_instance_valid(_car):
		return
	_car_visual = _car.get_node_or_null("Porsche911Turbo") as Node3D
	if _car_visual == null:
		return

	var selected_by_quadrant: Dictionary = {}
	var candidate_nodes: Array[Node] = _car_visual.find_children(
		"*",
		"Node3D",
		true,
		false
	)
	for node: Node in candidate_nodes:
		var candidate: Node3D = node as Node3D
		if candidate == null:
			continue
		if not _name_has_wheel_marker(str(candidate.name).to_lower()):
			continue
		_consider_candidate(candidate, selected_by_quadrant, true)

	if selected_by_quadrant.size() < 4:
		var mesh_nodes: Array[Node] = _car_visual.find_children(
			"*",
			"MeshInstance3D",
			true,
			false
		)
		for node: Node in mesh_nodes:
			var mesh_candidate: MeshInstance3D = node as MeshInstance3D
			if mesh_candidate != null:
				_consider_candidate(mesh_candidate, selected_by_quadrant, false)

	_wheel_records.clear()
	for quadrant: Variant in selected_by_quadrant.keys():
		var candidate_record: Dictionary = selected_by_quadrant[quadrant]
		_wheel_records.append(candidate_record)

	if _wheel_records.size() < 2:
		_disable_wheel_animation_cleanly(
			"the imported Porsche uses merged wheel geometry"
		)
		return

	_last_car_position = _car.global_position
	_initialized = true
	var resolved_names: PackedStringArray = PackedStringArray()
	for record: Dictionary in _wheel_records:
		var wheel_node: Node3D = record.get("node") as Node3D
		if wheel_node != null:
			resolved_names.append(str(wheel_node.name))
	print(
		"PORSCHE WHEELS READY: animating ",
		_wheel_records.size(),
		" separate wheel nodes: ",
		", ".join(resolved_names)
	)


func _disable_wheel_animation_cleanly(reason: String) -> void:
	_wheel_records.clear()
	_initialized = false
	set_process(false)
	if _wheel_skip_reported:
		return
	_wheel_skip_reported = true
	print(
		"PORSCHE WHEEL SPIN SKIPPED: ",
		reason,
		". Exact Porsche geometry remains unchanged."
	)
