extends Node

const WHEEL_NAME_MARKERS: Array[String] = ["wheel", "tire", "tyre", "rim"]
const MAX_WHEEL_DIMENSION: float = 1.55
const MIN_WHEEL_DIAMETER: float = 0.32
const MAX_ANGULAR_SPEED: float = 92.0

var _road: Node3D
var _car: Node3D
var _car_visual: Node3D
var _wheel_records: Array[Dictionary] = []
var _last_car_position: Vector3
var _angular_speed: float = 0.0
var _initialized: bool = false
var _initialization_attempts: int = 0


func _ready() -> void:
	process_priority = 260
	set_process(true)


func _process(delta: float) -> void:
	if not _initialized:
		_try_initialize()
		return
	if _car == null or not is_instance_valid(_car):
		_initialized = false
		_wheel_records.clear()
		return
	if delta <= 0.00001:
		return

	var current_position: Vector3 = _car.global_position
	var movement: Vector3 = current_position - _last_car_position
	_last_car_position = current_position
	var distance: float = movement.length()

	var average_radius: float = 0.36
	if not _wheel_records.is_empty():
		var radius_total: float = 0.0
		for record: Dictionary in _wheel_records:
			radius_total += float(record.get("radius", 0.36))
		average_radius = maxf(radius_total / float(_wheel_records.size()), 0.12)

	var target_angular_speed: float = 0.0
	if distance > 0.0001:
		var linear_speed: float = distance / delta
		target_angular_speed = clampf(linear_speed / average_radius, 0.0, MAX_ANGULAR_SPEED)
	_angular_speed = move_toward(_angular_speed, target_angular_speed, delta * 42.0)

	var spin_angle: float = _angular_speed * delta
	if absf(spin_angle) <= 0.00001:
		return
	for record: Dictionary in _wheel_records:
		var wheel_node: Node3D = record.get("node") as Node3D
		if wheel_node == null or not is_instance_valid(wheel_node):
			continue
		var axis: Vector3 = record.get("axis", Vector3.RIGHT)
		var spin_sign: float = float(record.get("sign", 1.0))
		wheel_node.rotate_object_local(axis, spin_angle * spin_sign)


func _try_initialize() -> void:
	_initialization_attempts += 1
	if _initialization_attempts > 240:
		set_process(false)
		push_error("PORSCHE WHEEL ERROR: the exact Porsche wheel nodes could not be resolved.")
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
	var candidate_nodes: Array[Node] = _car_visual.find_children("*", "Node3D", true, false)
	for node: Node in candidate_nodes:
		var candidate: Node3D = node as Node3D
		if candidate == null or not _name_has_wheel_marker(str(candidate.name).to_lower()):
			continue
		_consider_candidate(candidate, selected_by_quadrant, true)

	if selected_by_quadrant.size() < 4:
		var mesh_nodes: Array[Node] = _car_visual.find_children("*", "MeshInstance3D", true, false)
		for node: Node in mesh_nodes:
			var mesh_candidate: MeshInstance3D = node as MeshInstance3D
			if mesh_candidate == null:
				continue
			_consider_candidate(mesh_candidate, selected_by_quadrant, false)

	_wheel_records.clear()
	for quadrant: Variant in selected_by_quadrant.keys():
		var candidate_record: Dictionary = selected_by_quadrant[quadrant]
		_wheel_records.append(candidate_record)

	if _wheel_records.size() < 2:
		_wheel_records.clear()
		set_process(false)
		push_error(
			"PORSCHE WHEEL ERROR: the supplied exact Porsche does not expose enough separate wheel meshes to animate safely."
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


func _consider_candidate(
	candidate: Node3D,
	selected_by_quadrant: Dictionary,
	explicit_name_match: bool
) -> void:
	var bounds_result: Dictionary = _calculate_candidate_bounds(candidate)
	if not bool(bounds_result.get("valid", false)):
		return
	var bounds: AABB = bounds_result.get("bounds", AABB())
	var size: Vector3 = bounds.size.abs()
	var smallest: float = minf(size.x, minf(size.y, size.z))
	var largest: float = maxf(size.x, maxf(size.y, size.z))
	var middle: float = size.x + size.y + size.z - smallest - largest
	if largest > MAX_WHEEL_DIMENSION or middle > MAX_WHEEL_DIMENSION:
		return
	if largest < MIN_WHEEL_DIAMETER or middle < MIN_WHEEL_DIAMETER:
		return
	if smallest > 0.78:
		return

	var center_global: Vector3 = candidate.to_global(bounds.get_center())
	var center_car_local: Vector3 = _car.to_local(center_global)
	if absf(center_car_local.x) < 0.42 or absf(center_car_local.z) < 0.62:
		return
	if center_car_local.y < -0.45 or center_car_local.y > 1.45:
		return

	var descriptor: String = str(candidate.name).to_lower()
	var material_match: bool = _candidate_material_mentions_wheel(candidate)
	if not explicit_name_match and not material_match:
		# Geometry-only detection is allowed only for strongly wheel-shaped meshes.
		var roundness_difference: float = absf(largest - middle)
		if roundness_difference > largest * 0.34 or smallest > largest * 0.62:
			return

	var quadrant: String = (
		("L" if center_car_local.x < 0.0 else "R")
		+ ("F" if center_car_local.z < 0.0 else "B")
	)
	var score: float = 0.0
	if explicit_name_match:
		score += 12.0
	if descriptor.contains("tire") or descriptor.contains("tyre"):
		score += 5.0
	elif descriptor.contains("wheel"):
		score += 4.0
	elif descriptor.contains("rim"):
		score += 3.0
	if material_match:
		score += 4.0
	score += 2.0 - minf(absf(largest - middle), 2.0)
	score -= largest * 0.15

	if selected_by_quadrant.has(quadrant):
		var existing: Dictionary = selected_by_quadrant[quadrant]
		if float(existing.get("score", -1000.0)) >= score:
			return

	var axis: Vector3 = Vector3.RIGHT
	var radius: float = maxf(size.y, size.z) * 0.5
	if size.y <= size.x and size.y <= size.z:
		axis = Vector3.UP
		radius = maxf(size.x, size.z) * 0.5
	elif size.z <= size.x and size.z <= size.y:
		axis = Vector3.BACK
		radius = maxf(size.x, size.y) * 0.5

	var mirror_sign: float = -1.0 if candidate.global_transform.basis.determinant() < 0.0 else 1.0
	selected_by_quadrant[quadrant] = {
		"node": candidate,
		"axis": axis,
		"radius": clampf(radius, 0.18, 0.72),
		"sign": mirror_sign,
		"score": score
	}


func _calculate_candidate_bounds(candidate: Node3D) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	var candidate_mesh: MeshInstance3D = candidate as MeshInstance3D
	if candidate_mesh != null and candidate_mesh.mesh != null:
		meshes.append(candidate_mesh)
	var descendants: Array[Node] = candidate.find_children("*", "MeshInstance3D", true, false)
	for node: Node in descendants:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			meshes.append(mesh_instance)

	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for mesh_instance: MeshInstance3D in meshes:
		var relative_transform: Transform3D = (
			candidate.global_transform.affine_inverse() * mesh_instance.global_transform
		)
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)
	return {
		"valid": has_bounds,
		"bounds": bounds
	}


func _candidate_material_mentions_wheel(candidate: Node3D) -> bool:
	var mesh_nodes: Array[Node] = candidate.find_children("*", "MeshInstance3D", true, false)
	var candidate_mesh: MeshInstance3D = candidate as MeshInstance3D
	if candidate_mesh != null:
		mesh_nodes.append(candidate_mesh)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var material: Material = mesh_instance.get_active_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material == null:
				continue
			var material_name: String = str(material.resource_name).to_lower()
			if _name_has_wheel_marker(material_name) or material_name.contains("rubber"):
				return true
	return false


func _name_has_wheel_marker(value: String) -> bool:
	for marker: String in WHEEL_NAME_MARKERS:
		if value.contains(marker):
			return true
	return false
