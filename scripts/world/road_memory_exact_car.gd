extends "res://scripts/world/road_memory_final_cut.gd"

const REQUIRED_CAR_NODE_NAME: String = "Porsche911Turbo"
const BODY_MESH_NODE_NAME: String = "car_body"
const METALLIC_RED: Color = Color("d0182b")
const CENTER_WRECK_TIME_SCALE: float = 0.14
const CAR_CRASH_LAYER: int = 16
const CRASH_PROP_LAYER: int = 8
const PHYSICAL_CAR_MASS: float = 780.0
const PHYSICAL_OUTCOME_MAX_SECONDS: float = 8.0
const LEGACY_CAR_NODE_NAMES: Array[String] = [
	"ModeledPontiacFallback",
	"KenneyCC0Car",
	"ExternalPontiac",
	"ProceduralPontiac"
]

var _physical_wreck_body: RigidBody3D


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


func _start_center_impact_car_motion(impact_position: Vector3) -> void:
	if _car == null or not is_instance_valid(_car):
		return

	# Continue the Porsche through the shattered barrier while the three long
	# close-up shots play. This tween is deliberately measured in game time, so
	# the fourteen-percent time scale stretches it across the full montage.
	var pass_through_position: Vector3 = impact_position + Vector3(0.72, 0.26, -6.15)
	var movement_tween: Tween = create_tween().set_parallel(true)
	movement_tween.tween_property(
		_car,
		"position",
		pass_through_position,
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(-11.0, 8.0, -7.5),
		0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


func _begin_final_car_physics(
	_crash_set: Node3D,
	rail_position: Vector3,
	rail_tween: Tween
) -> RigidBody3D:
	if _car == null or not is_instance_valid(_car):
		push_error("PORSCHE PHYSICS ERROR: the live Porsche root is unavailable.")
		return null

	# Stop the authored sideways tween at the actual guardrail contact. From this
	# point onward no script writes the Porsche transform; Godot physics owns it.
	if rail_tween != null and rail_tween.is_valid():
		rail_tween.kill()

	var car_global_transform: Transform3D = _car.global_transform
	var target_global_position: Vector3 = to_global(rail_position)
	var impact_direction: Vector3 = target_global_position - car_global_transform.origin
	impact_direction.y = 0.0
	if impact_direction.length_squared() <= 0.0001:
		impact_direction = Vector3(0.35, 0.0, -1.0)
	impact_direction = impact_direction.normalized()

	var body: RigidBody3D = RigidBody3D.new()
	body.name = "PhysicalPorscheWreck"
	body.mass = PHYSICAL_CAR_MASS
	body.freeze = false
	body.sleeping = false
	body.can_sleep = true
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 24
	body.linear_damp = 0.10
	body.angular_damp = 0.14
	body.collision_layer = CAR_CRASH_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER
	body.add_to_group("physical_porsche_wreck")

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.82
	physics_material.bounce = 0.06
	body.physics_material_override = physics_material

	add_child(body)
	body.global_transform = car_global_transform
	_add_physical_porsche_collision(body)

	_car.reparent(body, true)
	_car.transform = Transform3D.IDENTITY
	_physical_wreck_body = body

	var initial_velocity: Vector3 = (
		impact_direction * 13.5
		+ Vector3(3.0, 1.35, 0.0)
	)
	var initial_angular_velocity: Vector3 = Vector3(0.65, -0.95, -1.35)
	_launch_physical_porsche_after_frame(
		body,
		initial_velocity,
		initial_angular_velocity
	)

	print(
		"PORSCHE PHYSICS HANDOFF: final position is now determined by rigid-body collisions at ",
		body.global_position
	)
	return body


func _add_physical_porsche_collision(body: RigidBody3D) -> void:
	_add_porsche_box_shape(
		body,
		"LowerBodyCollision",
		Vector3(1.92, 0.58, 4.30),
		Vector3(0.0, 0.43, 0.0)
	)
	_add_porsche_box_shape(
		body,
		"CabinCollision",
		Vector3(1.54, 0.62, 1.92),
		Vector3(0.0, 0.92, 0.08)
	)


func _add_porsche_box_shape(
	body: RigidBody3D,
	shape_name: String,
	shape_size: Vector3,
	shape_position: Vector3
) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = shape_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = shape_name
	collision.shape = shape
	collision.position = shape_position
	body.add_child(collision)


func _launch_physical_porsche_after_frame(
	body: RigidBody3D,
	initial_velocity: Vector3,
	initial_angular_velocity: Vector3
) -> void:
	await get_tree().physics_frame
	if body == null or not is_instance_valid(body):
		return
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = initial_velocity
	body.angular_velocity = initial_angular_velocity
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,
		initial_velocity
	)
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY,
		initial_angular_velocity
	)


func _resolve_final_car_outcome(
	crash_set: Node3D,
	rail_position: Vector3,
	physical_car: RigidBody3D
) -> void:
	if physical_car == null or not is_instance_valid(physical_car):
		await super._resolve_final_car_outcome(
			crash_set,
			rail_position,
			physical_car
		)
		return

	_set_crash_caption("YOU HAVE DONE THIS BEFORE")
	_crash_audio.call("start_tinnitus")
	if _crash_camera != null:
		_crash_camera.current = true

	var elapsed: float = 0.0
	var settled_duration: float = 0.0
	var outcome: String = "STILL MOVING"
	var bridge_height: float = crash_set.global_position.y

	while elapsed < PHYSICAL_OUTCOME_MAX_SECONDS:
		await get_tree().physics_frame
		if physical_car == null or not is_instance_valid(physical_car):
			outcome = "PHYSICS BODY LOST"
			break

		var physics_delta: float = get_physics_process_delta_time()
		elapsed += physics_delta
		_update_physical_wreck_camera(physical_car, physics_delta)

		var linear_speed: float = physical_car.linear_velocity.length()
		var angular_speed: float = physical_car.angular_velocity.length()
		var car_is_below_bridge: bool = (
			physical_car.global_position.y < bridge_height - 18.0
		)
		if car_is_below_bridge and elapsed >= 1.6:
			outcome = "FELL FROM BRIDGE"
			break

		var car_is_settled: bool = (
			linear_speed < 0.72
			and angular_speed < 0.58
			and physical_car.global_position.y > bridge_height - 3.0
		)
		if car_is_settled:
			settled_duration += physics_delta
			if settled_duration >= 1.05:
				outcome = "CAME TO REST ON BRIDGE"
				break
		else:
			settled_duration = 0.0

	if physical_car != null and is_instance_valid(physical_car):
		if outcome == "STILL MOVING":
			outcome = (
				"FELL FROM BRIDGE"
				if physical_car.global_position.y < bridge_height - 4.0
				else "REMAINED IN MOTION ON BRIDGE"
			)
		print(
			"PORSCHE PHYSICS OUTCOME: ",
			outcome,
			" at ",
			physical_car.global_position,
			" velocity ",
			physical_car.linear_velocity
		)

	await _wait_real_time(0.85)


func _update_physical_wreck_camera(body: RigidBody3D, delta: float) -> void:
	if _crash_rig == null or _crash_camera == null:
		return

	var target_position: Vector3 = body.global_position + Vector3.UP * 0.58
	var planar_velocity: Vector3 = Vector3(
		body.linear_velocity.x,
		0.0,
		body.linear_velocity.z
	)
	var travel_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
	if planar_velocity.length_squared() > 0.08:
		travel_direction = planar_velocity.normalized()
	var lateral: Vector3 = Vector3.UP.cross(travel_direction).normalized()
	var desired_position: Vector3 = (
		target_position
		- travel_direction * 9.2
		+ lateral * 2.8
		+ Vector3.UP * 4.2
	)
	var camera_response: float = clampf(delta * 4.0, 0.0, 1.0)
	_crash_rig.global_position = _crash_rig.global_position.lerp(
		desired_position,
		camera_response
	)
	_crash_rig.look_at(target_position, Vector3.UP)
	_crash_camera.fov = lerpf(_crash_camera.fov, 70.0, camera_response)
	_crash_camera.current = true


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
