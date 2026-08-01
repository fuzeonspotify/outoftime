extends "res://scripts/world/road_memory_final_cut.gd"

const REQUIRED_CAR_NODE_NAME: String = "Porsche911Turbo"
const BODY_MESH_NODE_NAME: String = "car_body"
const METALLIC_RED: Color = Color("d0182b")
const CENTER_WRECK_TIME_SCALE: float = 0.14
const LEGACY_CAR_NODE_NAMES: Array[String] = [
	"ModeledPontiacFallback",
	"KenneyCC0Car",
	"ExternalPontiac",
	"ProceduralPontiac"
]


func _ready() -> void:
	super._ready()
	_enforce_exact_car_only.call_deferred()


func _build_car() -> void:
	_remove_existing_bridge_car()

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

	_real_car_visual.name = REQUIRED_CAR_NODE_NAME
	_car.add_child(_real_car_visual)
	_normalize_car_model(_real_car_visual)
	# The supplied Porsche faces positive Z. Bridge travel is toward negative Z.
	_real_car_visual.rotation_degrees.y = 180.0
	_paint_car_metallic_red(_real_car_visual)
	_add_car_lighting()
	_add_car_camera()
	_purge_non_porsche_geometry()


func _build_crash_set() -> Node3D:
	# Remove every recycled gameplay obstacle before the cinematic roadblock is
	# built. This prevents a random barricade or skeleton from remaining between
	# the Porsche and the authored first impact.
	_clear_live_road_obstacles_for_crash()
	return super._build_crash_set()


func _play_center_impact_slow_motion(crash_set: Node3D) -> void:
	# The first wreck now reads as a deliberate impact study rather than a quick
	# montage. Real-time timers keep each shot length stable while physics runs at
	# fourteen percent speed.
	Engine.time_scale = CENTER_WRECK_TIME_SCALE
	var target: Vector3 = crash_set.to_global(Vector3(0.0, 0.86, 0.0))
	_place_close_crash_camera(target + Vector3(-4.2, 1.25, 3.35), target, 46.0)
	await _wait_real_time(1.10)
	_place_close_crash_camera(
		target + Vector3(3.45, 1.55, -2.55),
		target + Vector3(0.0, 0.30, -0.4),
		42.0
	)
	await _wait_real_time(1.08)
	_place_close_crash_camera(target + Vector3(-0.55, 5.05, 1.35), target, 50.0)
	await _wait_real_time(1.02)
	Engine.time_scale = 1.0


func _clear_live_road_obstacles_for_crash() -> void:
	var cleared_count: int = 0
	for segment: Node3D in _road_segments:
		if segment == null or not is_instance_valid(segment):
			continue
		var entries_variant: Variant = _segment_obstacles.get(segment.name, [])
		if entries_variant is Array:
			var entries: Array = entries_variant
			for entry_variant: Variant in entries:
				if not (entry_variant is Dictionary):
					continue
				var entry: Dictionary = entry_variant
				var obstacle_node: Node3D = entry.get("node") as Node3D
				if obstacle_node == null or not is_instance_valid(obstacle_node):
					continue
				obstacle_node.visible = false
				if not obstacle_node.is_queued_for_deletion():
					obstacle_node.queue_free()
				cleared_count += 1
		_segment_obstacles[segment.name] = []

	# Catch any replacement hierarchy that was installed after the obstacle
	# dictionary was populated. The metadata lives on each original obstacle root.
	var remaining_nodes: Array[Node] = find_children("*", "Node3D", true, false)
	for node: Node in remaining_nodes:
		var obstacle_root: Node3D = node as Node3D
		if obstacle_root == null or not obstacle_root.has_meta("obstacle_type"):
			continue
		if obstacle_root.is_queued_for_deletion():
			continue
		obstacle_root.visible = false
		obstacle_root.queue_free()
		cleared_count += 1

	print("BRIDGE CRASH ROAD CLEARED: removed ", cleared_count, " live gameplay obstacles.")


func _paint_car_metallic_red(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	var body_mesh: MeshInstance3D
	var fallback_mesh: MeshInstance3D
	var largest_surface_count: int = -1

	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		# Whole-mesh overrides take priority over all surface overrides. The old
		# environment pass installed one of these, which is why previous paint
		# changes never appeared.
		mesh_instance.material_override = null

		var node_name: String = str(mesh_instance.name).to_lower()
		if node_name == BODY_MESH_NODE_NAME or node_name.contains(BODY_MESH_NODE_NAME):
			body_mesh = mesh_instance

		var surface_count: int = mesh_instance.mesh.get_surface_count()
		if surface_count > largest_surface_count:
			largest_surface_count = surface_count
			fallback_mesh = mesh_instance

	if body_mesh == null:
		body_mesh = fallback_mesh
	if body_mesh == null or body_mesh.mesh == null or body_mesh.mesh.get_surface_count() == 0:
		push_error("PORSCHE PAINT ERROR: the imported car_body mesh was not found.")
		return

	# The supplied GLB maps Material.005 (the exterior shell) to surface 0 of
	# car_body. Targeting this exact surface avoids changing glass, tires, chrome,
	# headlights, taillights, or the interior.
	_apply_metallic_red(body_mesh, 0)


func _apply_metallic_red(mesh_instance: MeshInstance3D, surface_index: int) -> void:
	var source_material: Material = mesh_instance.mesh.surface_get_material(surface_index)
	var painted_material: BaseMaterial3D
	if source_material != null:
		painted_material = source_material.duplicate() as BaseMaterial3D
	if painted_material == null:
		painted_material = StandardMaterial3D.new()

	painted_material.albedo_color = METALLIC_RED
	painted_material.metallic = 1.0
	painted_material.roughness = 0.12
	painted_material.emission_enabled = false
	mesh_instance.material_override = null
	mesh_instance.set_surface_override_material(surface_index, painted_material)


func _clear_porsche_whole_mesh_overrides() -> void:
	if _real_car_visual == null or not is_instance_valid(_real_car_visual):
		return
	var mesh_nodes: Array[Node] = _real_car_visual.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_override = null


func _remove_existing_bridge_car() -> void:
	var existing_cars: Array[Node] = find_children("SpectralPontiac", "Node3D", false, false)
	for node: Node in existing_cars:
		var existing_car: Node3D = node as Node3D
		if existing_car == null:
			continue
		existing_car.visible = false
		existing_car.queue_free()


func _enforce_exact_car_only() -> void:
	# Wait through every deferred scene-art installation window, removing legacy
	# geometry and any whole-mesh material override each frame. Repaint once more
	# after those systems have finished.
	for _frame_index: int in range(32):
		await get_tree().process_frame
		_purge_non_porsche_geometry()
		_clear_porsche_whole_mesh_overrides()
	if _real_car_visual != null and is_instance_valid(_real_car_visual):
		_paint_car_metallic_red(_real_car_visual)


func _purge_non_porsche_geometry() -> void:
	if _car == null or not is_instance_valid(_car):
		return
	if _real_car_visual == null or not is_instance_valid(_real_car_visual):
		return

	# Remove known retired model roots immediately.
	for legacy_name: String in LEGACY_CAR_NODE_NAMES:
		var legacy_nodes: Array[Node] = _car.find_children(legacy_name, "Node3D", true, false)
		for node: Node in legacy_nodes:
			var legacy_visual: Node3D = node as Node3D
			if legacy_visual == null or legacy_visual == _real_car_visual:
				continue
			legacy_visual.visible = false
			legacy_visual.queue_free()

	# The Porsche is the only hierarchy allowed to contribute car geometry.
	var mesh_nodes: Array[Node] = _car.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		if _real_car_visual == mesh_instance or _real_car_visual.is_ancestor_of(mesh_instance):
			continue
		mesh_instance.visible = false
		mesh_instance.queue_free()

	# Remove any remaining top-level retired visual roots while preserving only
	# the required Porsche, camera, and lights.
	var car_children: Array[Node] = _car.get_children()
	for child: Node in car_children:
		if child == _real_car_visual or child is Camera3D or child is Light3D:
			continue
		var child_3d: Node3D = child as Node3D
		if child_3d == null:
			continue
		child_3d.visible = false
		child_3d.queue_free()
