extends Node

const KENNEY_WAIT_TIMEOUT: float = 45.0
const KENNEY_CHECK_INTERVAL: float = 0.25
const VERTICAL_NORMAL_LIMIT: float = 0.62
const TRIANGLE_EPSILON: float = 0.000001

var _root: Node3D


func _ready() -> void:
	_wait_for_kenney_city.call_deferred()


func _wait_for_kenney_city() -> void:
	_root = get_parent() as Node3D
	if _root == null:
		return

	var elapsed_time: float = 0.0
	while elapsed_time < KENNEY_WAIT_TIMEOUT:
		var kenney_container: Node3D = _root.get_node_or_null("KenneyCityModels") as Node3D
		if kenney_container != null:
			await get_tree().process_frame
			_hide_legacy_city_visuals()
			_face_buildings_toward_street(kenney_container)
			return
		await get_tree().create_timer(KENNEY_CHECK_INTERVAL).timeout
		elapsed_time += KENNEY_CHECK_INTERVAL


func _hide_legacy_city_visuals() -> void:
	var root_children: Array[Node] = _root.get_children()
	for child: Node in root_children:
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance != null:
			var mesh_name: String = str(mesh_instance.name)
			var is_old_road_visual: bool = mesh_name in ["Road", "LeftSidewalk", "RightSidewalk", "RoadMarker"]
			var is_old_building_detail: bool = (
				absf(mesh_instance.position.x) >= 8.5
				and mesh_instance.position.z > -49.0
				and mesh_instance.position.z < 42.0
				and mesh_name != "StorefrontGlass"
			)
			var is_old_facade_piece: bool = mesh_name in ["Window", "BrokenSign"]
			if is_old_road_visual or is_old_building_detail or is_old_facade_piece:
				mesh_instance.visible = false
			continue

		var static_body: StaticBody3D = child as StaticBody3D
		if static_body != null and str(static_body.name).begins_with("Building"):
			_set_mesh_visibility(static_body, false)


func _set_mesh_visibility(parent_node: Node, visible_value: bool) -> void:
	var descendants: Array[Node] = parent_node.find_children("*", "MeshInstance3D", true, false)
	for descendant: Node in descendants:
		var mesh_instance: MeshInstance3D = descendant as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = visible_value


func _face_buildings_toward_street(kenney_container: Node3D) -> void:
	var model_children: Array[Node] = kenney_container.get_children()
	for child: Node in model_children:
		var model_root: Node3D = child as Node3D
		if model_root == null or not str(model_root.name).begins_with("Kenney_building_"):
			continue

		var detected_front: Vector3 = _detect_detailed_facade_direction(model_root)
		var street_direction: Vector3 = Vector3.RIGHT if model_root.position.x < 0.0 else Vector3.LEFT
		var front_angle: float = atan2(detected_front.x, detected_front.z)
		var street_angle: float = atan2(street_direction.x, street_direction.z)
		var corrected_yaw: float = snappedf(rad_to_deg(street_angle - front_angle) + 180.0, 90.0)
		model_root.rotation_degrees = Vector3(0.0, corrected_yaw, 0.0)


func _detect_detailed_facade_direction(model_root: Node3D) -> Vector3:
	var side_scores: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var height_range: Vector2 = _get_model_height_range(model_root)
	var model_height: float = maxf(height_range.y - height_range.x, 0.001)
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)

	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var array_mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
		if array_mesh == null:
			continue

		var mesh_to_model: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index: int in range(array_mesh.get_surface_count()):
			var surface_arrays: Array = array_mesh.surface_get_arrays(surface_index)
			if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if vertices.is_empty():
				continue

			var indices: PackedInt32Array = PackedInt32Array()
			if surface_arrays.size() > Mesh.ARRAY_INDEX:
				indices = surface_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			if indices.is_empty():
				_score_unindexed_triangles(vertices, mesh_to_model, height_range.x, model_height, side_scores)
			else:
				_score_indexed_triangles(vertices, indices, mesh_to_model, height_range.x, model_height, side_scores)

	var best_side: int = 0
	for side_index: int in range(1, side_scores.size()):
		if side_scores[side_index] > side_scores[best_side]:
			best_side = side_index
	match best_side:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.LEFT
		2:
			return Vector3.FORWARD
		_:
			return Vector3.BACK


func _score_unindexed_triangles(
	vertices: PackedVector3Array,
	mesh_to_model: Transform3D,
	minimum_y: float,
	model_height: float,
	side_scores: Array[float]
) -> void:
	var triangle_start: int = 0
	while triangle_start + 2 < vertices.size():
		_score_triangle(
			mesh_to_model * vertices[triangle_start],
			mesh_to_model * vertices[triangle_start + 1],
			mesh_to_model * vertices[triangle_start + 2],
			minimum_y,
			model_height,
			side_scores
		)
		triangle_start += 3


func _score_indexed_triangles(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	mesh_to_model: Transform3D,
	minimum_y: float,
	model_height: float,
	side_scores: Array[float]
) -> void:
	var index_offset: int = 0
	while index_offset + 2 < indices.size():
		var first_index: int = indices[index_offset]
		var second_index: int = indices[index_offset + 1]
		var third_index: int = indices[index_offset + 2]
		if (
			first_index >= 0
			and second_index >= 0
			and third_index >= 0
			and first_index < vertices.size()
			and second_index < vertices.size()
			and third_index < vertices.size()
		):
			_score_triangle(
				mesh_to_model * vertices[first_index],
				mesh_to_model * vertices[second_index],
				mesh_to_model * vertices[third_index],
				minimum_y,
				model_height,
				side_scores
			)
		index_offset += 3


func _get_model_height_range(model_root: Node3D) -> Vector2:
	var minimum_y: float = INF
	var maximum_y: float = -INF
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var array_mesh: ArrayMesh = mesh_instance.mesh as ArrayMesh
		if array_mesh == null:
			continue
		var mesh_to_model: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index: int in range(array_mesh.get_surface_count()):
			var surface_arrays: Array = array_mesh.surface_get_arrays(surface_index)
			if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex: Vector3 in vertices:
				var model_vertex: Vector3 = mesh_to_model * vertex
				minimum_y = minf(minimum_y, model_vertex.y)
				maximum_y = maxf(maximum_y, model_vertex.y)
	if is_inf(minimum_y) or is_inf(maximum_y):
		return Vector2(0.0, 1.0)
	return Vector2(minimum_y, maximum_y)


func _score_triangle(
	first_vertex: Vector3,
	second_vertex: Vector3,
	third_vertex: Vector3,
	minimum_y: float,
	model_height: float,
	side_scores: Array[float]
) -> void:
	var cross_product: Vector3 = (second_vertex - first_vertex).cross(third_vertex - first_vertex)
	var doubled_area: float = cross_product.length()
	if doubled_area <= TRIANGLE_EPSILON:
		return
	var normal: Vector3 = cross_product / doubled_area
	if absf(normal.y) > VERTICAL_NORMAL_LIMIT:
		return

	var centroid_y: float = (first_vertex.y + second_vertex.y + third_vertex.y) / 3.0
	var normalized_height: float = clampf((centroid_y - minimum_y) / model_height, 0.0, 1.0)
	var lower_facade_weight: float = lerpf(1.8, 0.72, normalized_height)
	var detail_weight: float = clampf(0.18 / maxf(sqrt(doubled_area), 0.025), 0.35, 2.6)
	var score: float = lower_facade_weight * detail_weight

	if absf(normal.x) > absf(normal.z):
		if normal.x >= 0.0:
			side_scores[0] += score
		else:
			side_scores[1] += score
	elif normal.z < 0.0:
		side_scores[2] += score
	else:
		side_scores[3] += score
