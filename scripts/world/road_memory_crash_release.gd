extends "res://scripts/world/road_memory_cinematic_release.gd"


func _break_guardrail(crash_set: Node3D) -> void:
	var mesh_nodes: Array[Node] = crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var piece: MeshInstance3D = node as MeshInstance3D
		if piece == null or not bool(piece.get_meta("crash_barrier", false)):
			continue
		var outward: float = signf(piece.position.x)
		if is_zero_approx(outward):
			outward = 1.0
		var barrier_tween: Tween = create_tween().set_parallel(true)
		barrier_tween.tween_property(
			piece,
			"position",
			piece.position + Vector3(outward * 3.4, 1.2, -2.4),
			1.05
		).set_trans(Tween.TRANS_QUAD)
		barrier_tween.tween_property(
			piece,
			"rotation_degrees",
			Vector3(58.0, outward * 42.0, outward * 76.0),
			1.05
		).set_trans(Tween.TRANS_QUAD)
	_break_right_rail_later.call_deferred(crash_set)


func _break_right_rail_later(crash_set: Node3D) -> void:
	await get_tree().create_timer(0.72 + RAIL_SLIDE_SECONDS * 0.78).timeout
	if not is_instance_valid(crash_set):
		return
	var mesh_nodes: Array[Node] = crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var rail: MeshInstance3D = node as MeshInstance3D
		if rail == null or not bool(rail.get_meta("crash_rail", false)):
			continue
		if rail.position.x < 0.0:
			continue
		var rail_tween: Tween = create_tween().set_parallel(true)
		rail_tween.tween_property(
			rail,
			"rotation_degrees:z",
			-78.0,
			1.45
		).set_trans(Tween.TRANS_QUAD)
		rail_tween.tween_property(
			rail,
			"position",
			rail.position + Vector3(3.3, -2.8, -1.8),
			1.65
		).set_trans(Tween.TRANS_QUAD)
