extends Node

const EXACT_CONTAINER_NAME: String = "ExactEnvironmentModels"

var _root: Node3D
var _container: Node3D
var _instance_counter: int = 0
var _road_crash_upgraded: bool = false


func _ready() -> void:
	set_process(false)
	_install_exact_environment.call_deferred()


func _process(_delta: float) -> void:
	if _root != null and str(_root.name) == "RoadMemory" and not _road_crash_upgraded:
		_upgrade_road_crash_barriers()


func _install_exact_environment() -> void:
	for _frame_index: int in range(8):
		await get_tree().process_frame

	_root = get_parent() as Node3D
	if _root == null:
		return
	if _root.get_node_or_null(EXACT_CONTAINER_NAME) != null:
		return

	_container = Node3D.new()
	_container.name = EXACT_CONTAINER_NAME
	_root.add_child(_container)

	match str(_root.name):
		"Cemetery":
			_upgrade_cemetery()
		"RoadMemory":
			_upgrade_memory_road()
			set_process(true)
		"HeavenDescent":
			_upgrade_false_heaven()
		"RuinedNightclub":
			_upgrade_nightclub()
		"SkeletonChamber":
			_upgrade_skeleton_chamber()
		_:
			push_error("No exact environment replacement plan for scene %s." % _root.name)


func _upgrade_cemetery() -> void:
	_apply_material_by_markers(
		"monastery_stone_floor",
		["mainpath", "pathstone", "gravebase", "gravestone", "memorial"]
	)
	_apply_material_by_markers("rock_ground", ["ground"])

	_hide_meshes_by_markers(["lanternpost", "upgradeddeadtree"])
	_hide_original_cemetery_tree_meshes()

	var lamp_z_values: Array[float] = [12.0, 2.0, -8.0, -18.0]
	for lamp_z: float in lamp_z_values:
		_place_model("street_lamp_01", Vector3(-2.5, 0.0, lamp_z), Vector3.ZERO, 3.9)
		_place_model("street_lamp_01", Vector3(2.5, 0.0, lamp_z), Vector3(0.0, 180.0, 0.0), 3.9)

	var tree_z_values: Array[float] = [-25.0, -15.0, -5.0, 5.0, 15.0, 23.0]
	for tree_index: int in range(tree_z_values.size()):
		var tree_z: float = tree_z_values[tree_index]
		_place_model(
			"dead_quiver_trunk",
			Vector3(-15.5, 0.0, tree_z),
			Vector3(0.0, float(tree_index) * 41.0, 0.0),
			5.4
		)
		_place_model(
			"dead_quiver_trunk",
			Vector3(15.5, 0.0, tree_z + 1.8),
			Vector3(0.0, 180.0 + float(tree_index) * 37.0, 0.0),
			5.2
		)

	_place_model(
		"painted_wooden_bench",
		Vector3(-5.8, 0.0, -18.0),
		Vector3(0.0, 24.0, 0.0),
		2.15
	)
	_place_model(
		"painted_wooden_bench",
		Vector3(5.8, 0.0, -22.0),
		Vector3(0.0, 204.0, 0.0),
		2.15
	)


func _upgrade_memory_road() -> void:
	var segments: Array[Node] = _root.find_children("BridgeSegment*", "Node3D", true, false)
	for segment_index: int in range(segments.size()):
		var segment: Node3D = segments[segment_index] as Node3D
		if segment == null:
			continue
		var mesh_nodes: Array[Node] = segment.find_children("*", "MeshInstance3D", true, false)
		for node: Node in mesh_nodes:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance == null:
				continue
			if absf(mesh_instance.position.x) < 5.45 and mesh_instance.position.y < 0.38:
				_apply_material(mesh_instance, "asphalt_02")
		if segment_index % 2 == 0:
			_place_model(
				"street_lamp_01",
				Vector3(-5.55, 0.12, 0.0),
				Vector3.ZERO,
				3.9,
				segment
			)
			_place_model(
				"street_lamp_01",
				Vector3(5.55, 0.12, 0.0),
				Vector3(0.0, 180.0, 0.0),
				3.9,
				segment
			)


func _upgrade_road_crash_barriers() -> void:
	var crash_set: Node3D = _root.get_node_or_null("BridgeCrashSet") as Node3D
	if crash_set == null:
		return
	var barriers: Array[Node] = crash_set.find_children("CenteredBarrier*", "MeshInstance3D", true, false)
	if barriers.is_empty():
		return
	for node: Node in barriers:
		var barrier_mesh: MeshInstance3D = node as MeshInstance3D
		if barrier_mesh == null:
			continue
		barrier_mesh.visible = false
		barrier_mesh.queue_free()
		_place_model(
			"concrete_road_barrier_02",
			barrier_mesh.position,
			barrier_mesh.rotation_degrees,
			2.25,
			crash_set
		)
	_road_crash_upgraded = true


func _upgrade_false_heaven() -> void:
	var arches: Array[Node] = _root.find_children("HeavenArch*", "Node3D", true, false)
	for arch_index: int in range(arches.size()):
		var arch: Node3D = arches[arch_index] as Node3D
		if arch == null:
			continue
		var arch_meshes: Array[Node] = arch.find_children("*", "MeshInstance3D", true, false)
		for node: Node in arch_meshes:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance != null and absf(mesh_instance.position.x) > 4.0:
				_apply_material(mesh_instance, "marble_01")
		_place_model(
			"marble_bust_01",
			Vector3(-3.65, 0.0, 0.0),
			Vector3(0.0, 20.0, 0.0),
			1.55,
			arch
		)
		_place_model(
			"marble_bust_01",
			Vector3(3.65, 0.0, 0.0),
			Vector3(0.0, -20.0, 0.0),
			1.55,
			arch
		)
		if arch_index % 2 == 0:
			_place_model(
				"chandelier_01",
				Vector3(0.0, 6.15, 0.0),
				Vector3.ZERO,
				1.05,
				arch
			)

	var flower_clusters: Array[Node3D] = _find_heaven_flower_clusters()
	for cluster: Node3D in flower_clusters:
		_hide_mesh_descendants(cluster)
		_place_model("flower_empodium", Vector3.ZERO, Vector3.ZERO, 1.3, cluster)

	_apply_material_by_markers("marble_01", ["gateroot", "gatepillar", "gatebase"])


func _find_heaven_flower_clusters() -> Array[Node3D]:
	var results: Array[Node3D] = []
	for child: Node in _root.get_children():
		var child_3d: Node3D = child as Node3D
		if child_3d == null:
			continue
		if absf(child_3d.position.x) < 10.0 or child_3d.position.y > 0.2:
			continue
		if child_3d.position.z < -150.0 or child_3d.position.z > 45.0:
			continue
		var mesh_nodes: Array[Node] = child_3d.find_children("*", "MeshInstance3D", true, false)
		if mesh_nodes.size() >= 8 and mesh_nodes.size() <= 12:
			results.append(child_3d)
	return results


func _upgrade_nightclub() -> void:
	_apply_material_by_markers(
		"scuffed_cement",
		[
			"clubfloor", "leftwall", "rightwall", "backwall", "entrancewall",
			"stage", "balconyfloor", "balconystairs"
		]
	)
	_hide_meshes_by_markers(["bottle", "debris"])

	for chair_index: int in range(7):
		_place_model(
			"bar_chair_round_01",
			Vector3(-9.1, 0.0, -0.2 + float(chair_index) * 2.05),
			Vector3(0.0, 90.0, 0.0),
			0.82
		)

	var table_positions: Array[Vector3] = [
		Vector3(-6.5, 0.0, 19.0),
		Vector3(6.5, 0.0, 16.0),
		Vector3(-6.7, 0.0, -8.0),
		Vector3(6.8, 0.0, -14.0)
	]
	for table_index: int in range(table_positions.size()):
		_place_model(
			"industrial_coffee_table",
			table_positions[table_index],
			Vector3(0.0, float(table_index) * 29.0, 0.0),
			1.45
		)

	var barrel_positions: Array[Vector3] = [
		Vector3(-15.3, 0.0, -3.0),
		Vector3(-15.1, 0.0, 14.0),
		Vector3(11.0, 0.0, -28.0),
		Vector3(14.0, 0.0, -29.0)
	]
	for barrel_index: int in range(barrel_positions.size()):
		_place_model(
			"wine_barrel_01",
			barrel_positions[barrel_index],
			Vector3(0.0, float(barrel_index) * 47.0, 0.0),
			0.95
		)

	for lamp_z: float in [25.0, 12.0, -1.0, -14.0, -27.0]:
		_place_model(
			"industrial_wall_sconce",
			Vector3(-17.35, 3.5, lamp_z),
			Vector3(0.0, 90.0, 0.0),
			0.55
		)
		_place_model(
			"industrial_wall_sconce",
			Vector3(17.35, 3.5, lamp_z),
			Vector3(0.0, -90.0, 0.0),
			0.55
		)


func _upgrade_skeleton_chamber() -> void:
	_apply_material_by_markers(
		"stone_floor",
		[
			"chamberfloor", "stonewall", "floorinlay", "daisbase", "daisstep",
			"pedestal"
		]
	)
	_hide_meshes_by_markers(["walllamp", "pedestal"])

	var lamp_positions: Array[Vector3] = [
		Vector3(-17.8, 2.8, 22.0), Vector3(17.8, 2.8, 19.0),
		Vector3(-17.8, 2.8, 8.0), Vector3(17.8, 2.8, 5.0),
		Vector3(-17.8, 2.8, -6.0), Vector3(17.8, 2.8, -9.0),
		Vector3(-17.8, 2.8, -20.0), Vector3(17.8, 2.8, -23.0),
		Vector3(-17.8, 2.8, -33.0), Vector3(17.8, 2.8, -36.0)
	]
	for lamp_position: Vector3 in lamp_positions:
		var facing_y: float = 90.0 if lamp_position.x < 0.0 else -90.0
		_place_model(
			"industrial_wall_sconce",
			lamp_position,
			Vector3(0.0, facing_y, 0.0),
			0.55
		)

	_place_model("shelf_01", Vector3(-13.0, 0.0, -37.8), Vector3(0.0, 180.0, 0.0), 3.7)
	_place_model("shelf_01", Vector3(13.0, 0.0, -37.8), Vector3(0.0, 180.0, 0.0), 3.7)
	_place_model("gothic_coffee_table", Vector3(0.0, 0.72, -31.0), Vector3.ZERO, 2.6)

	var journal_positions: Array[Vector3] = [
		Vector3(-9.0, 0.0, 10.0),
		Vector3(8.5, 0.0, -5.0),
		Vector3(-7.5, 0.0, -21.0)
	]
	for journal_index: int in range(journal_positions.size()):
		_place_model(
			"painted_wooden_bench",
			journal_positions[journal_index],
			Vector3(0.0, 90.0 + float(journal_index) * 55.0, 0.0),
			1.55
		)

	for chair_position: Vector3 in [
		Vector3(-3.0, 0.7, -28.5),
		Vector3(3.0, 0.7, -28.5),
		Vector3(-3.0, 0.7, -35.0),
		Vector3(3.0, 0.7, -35.0)
	]:
		var look_direction: float = 0.0 if chair_position.z < -32.0 else 180.0
		_place_model(
			"wooden_chair_01",
			chair_position,
			Vector3(0.0, look_direction, 0.0),
			2.25
		)


func _place_model(
	asset_id: String,
	local_position: Vector3,
	local_rotation: Vector3,
	target_longest_dimension: float,
	parent_override: Node3D = null
) -> Node3D:
	var prototype: Node3D = StartupPreloader.get_environment_prototype(asset_id)
	if prototype == null:
		push_error("REQUIRED ENVIRONMENT MODEL MISSING: %s" % asset_id)
		return null

	var model: Node3D = prototype.duplicate() as Node3D
	if model == null:
		push_error("REQUIRED ENVIRONMENT MODEL COULD NOT DUPLICATE: %s" % asset_id)
		return null

	var parent_node: Node3D = parent_override if parent_override != null else _container
	var anchor: Node3D = Node3D.new()
	_instance_counter += 1
	anchor.name = "PH_%s_%03d" % [asset_id, _instance_counter]
	anchor.position = local_position
	anchor.rotation_degrees = local_rotation
	parent_node.add_child(anchor)
	anchor.add_child(model)
	_normalize_model(model, target_longest_dimension)
	return anchor


func _normalize_model(model: Node3D, target_longest_dimension: float) -> void:
	var bounds: AABB = _calculate_bounds(model)
	var longest_dimension: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_dimension <= 0.001:
		return
	var scale_factor: float = target_longest_dimension / longest_dimension
	model.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	model.position = Vector3(
		-center.x * scale_factor,
		-bounds.position.y * scale_factor,
		-center.z * scale_factor
	)


func _calculate_bounds(model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)
	return bounds


func _apply_material_by_markers(material_id: String, markers: Array[String]) -> void:
	var mesh_nodes: Array[Node] = _root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var descriptor: String = str(mesh_instance.get_path()).to_lower()
		for marker: String in markers:
			if descriptor.contains(marker):
				_apply_material(mesh_instance, material_id)
				break


func _apply_material(mesh_instance: MeshInstance3D, material_id: String) -> void:
	var source: StandardMaterial3D = StartupPreloader.get_environment_material(material_id)
	if source == null:
		push_error("REQUIRED ENVIRONMENT MATERIAL MISSING: %s" % material_id)
		return
	mesh_instance.material_override = source.duplicate() as StandardMaterial3D


func _hide_meshes_by_markers(markers: Array[String]) -> void:
	var mesh_nodes: Array[Node] = _root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var descriptor: String = str(mesh_instance.get_path()).to_lower()
		for marker: String in markers:
			if descriptor.contains(marker):
				mesh_instance.visible = false
				mesh_instance.queue_free()
				break


func _hide_mesh_descendants(parent: Node3D) -> void:
	var mesh_nodes: Array[Node] = parent.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false
			mesh_instance.queue_free()


func _hide_original_cemetery_tree_meshes() -> void:
	var mesh_nodes: Array[Node] = _root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var is_tree_zone: bool = absf(mesh_instance.position.x) > 14.0
		var is_tree_height: bool = mesh_instance.position.y > 1.8
		if is_tree_zone and is_tree_height:
			mesh_instance.visible = false
			mesh_instance.queue_free()
