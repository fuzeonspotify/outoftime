extends "res://scripts/world/bridge_final_edge_rail_physics.gd"


func _physics_process(_delta: float) -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return

	if not _armed:
		_crash_set = _find_live_crash_set()
		if _crash_set != null:
			_armed = true
			_elapsed = 0.0
			print("BRIDGE FINAL EDGE RAIL ARMED FOR PHYSICAL CONTACT at ", _crash_set.global_position)
		return

	# No elapsed-time fallback. A rail is released only by trigger_edge_for_side()
	# after the physical Porsche reaches that edge's actual contact line.


func trigger_edge_for_side(side_value: float) -> void:
	if side_value >= 0.0:
		_trigger_final_edge_rail()
		return
	_trigger_left_edge_rail()


func _trigger_left_edge_rail() -> void:
	if _triggered or _crash_set == null or not is_instance_valid(_crash_set):
		return
	_triggered = true

	var edge_x: float = -EDGE_RAIL_X
	var hidden_count: int = _hide_original_edge_near_impact(edge_x)
	var spawned_count: int = 0
	for segment_index: int in range(RAIL_SEGMENT_COUNT):
		var local_z: float = 10.0 - float(segment_index) * 4.0
		var distance_from_hit: float = absf(local_z - IMPACT_LOCAL_Z)
		var weight: float = clampf(1.0 - distance_from_hit / 34.0, 0.30, 1.0)
		var beam_mass: float = lerpf(55.0, 260.0, weight)
		var beam_outward_speed: float = lerpf(8.5, 1.2, weight)
		var beam_upward_speed: float = lerpf(5.5, 0.7, weight)
		if _spawn_dynamic_piece(
			"FinalLeftEdgeBeam_%02d" % segment_index,
			Vector3(edge_x, 0.45, local_z),
			Vector3(0.20, 0.30, 3.78),
			Color("586780"),
			beam_mass,
			Vector3(
				-beam_outward_speed,
				beam_upward_speed,
				_rng.randf_range(-4.0, 4.0) * (1.15 - weight * 0.55)
			)
		):
			spawned_count += 1

		var post_mass: float = lerpf(18.0, 92.0, weight)
		var post_outward_speed: float = lerpf(9.0, 1.8, weight)
		var post_upward_speed: float = lerpf(6.0, 1.0, weight)
		if _spawn_dynamic_piece(
			"FinalLeftEdgePost_%02d" % segment_index,
			Vector3(edge_x, 0.90, local_z),
			Vector3(0.12, 0.85, 0.12),
			Color("65708b"),
			post_mass,
			Vector3(
				-post_outward_speed,
				post_upward_speed,
				_rng.randf_range(-5.0, 5.0) * (1.15 - weight * 0.55)
			)
		):
			spawned_count += 1

	_spawn_left_spark_fragments(edge_x)
	print(
		"BRIDGE FINAL LEFT EDGE RAIL IMPACT: hid ",
		hidden_count,
		" static edge pieces and spawned ",
		spawned_count,
		" rigid pieces at X=",
		edge_x
	)


func _hide_original_edge_near_impact(edge_x: float) -> int:
	var hidden_count: int = 0
	var impact_global_z: float = _crash_set.to_global(
		Vector3(edge_x, 0.45, IMPACT_LOCAL_Z)
	).z
	var segments: Array[Node] = _road.find_children(
		"BridgeSegment*",
		"Node3D",
		true,
		false
	)
	for segment_node: Node in segments:
		var segment: Node3D = segment_node as Node3D
		if segment == null:
			continue
		if absf(segment.global_position.z - impact_global_z) > 42.0:
			continue
		var meshes: Array[Node] = segment.find_children(
			"*",
			"MeshInstance3D",
			true,
			false
		)
		for mesh_node: Node in meshes:
			var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			if absf(mesh_instance.position.x - edge_x) > 0.12:
				continue
			var box: BoxMesh = mesh_instance.mesh as BoxMesh
			if box == null:
				continue
			var size: Vector3 = box.size
			var is_long_beam: bool = (
				size.z >= 12.0
				and size.x <= 0.30
				and size.y <= 0.45
			)
			var is_vertical_post: bool = (
				size.x <= 0.22
				and size.z <= 0.22
				and size.y >= 0.65
			)
			if is_long_beam or is_vertical_post:
				mesh_instance.visible = false
				hidden_count += 1
	return hidden_count


func _spawn_left_spark_fragments(edge_x: float) -> void:
	for fragment_index: int in range(24):
		_spawn_dynamic_piece(
			"FinalLeftRailSpark_%02d" % fragment_index,
			Vector3(
				edge_x,
				_rng.randf_range(0.55, 1.10),
				IMPACT_LOCAL_Z + _rng.randf_range(-2.0, 2.0)
			),
			Vector3(
				_rng.randf_range(0.05, 0.16),
				_rng.randf_range(0.04, 0.12),
				_rng.randf_range(0.10, 0.34)
			),
			Color("d9c48c") if fragment_index % 3 != 0 else Color("ffad54"),
			_rng.randf_range(0.12, 0.55),
			Vector3(
				_rng.randf_range(-22.0, -10.0),
				_rng.randf_range(8.0, 18.0),
				_rng.randf_range(-14.0, 12.0)
			)
		)
