extends "res://scripts/world/road_memory_realistic_wreck_dynamics_release.gd"

const OBSTACLE_SENSOR_MARGIN: Vector3 = Vector3(0.28, 0.22, 0.28)
const BARRIER_COLLIDER_SIZE: Vector3 = Vector3(1.72, 1.18, 1.28)
const BARRIER_COLLIDER_CENTER: Vector3 = Vector3(0.0, 0.58, 0.0)
const SKELETON_COLLIDER_SIZE: Vector3 = Vector3(0.86, 2.35, 0.78)
const SKELETON_COLLIDER_CENTER: Vector3 = Vector3(0.0, 1.15, 0.0)
const MAX_DEMOLITION_FRAGMENTS: int = 18
const DEMOLITION_FRAGMENT_LIFETIME: float = 14.0
const MIN_FRAGMENT_SIZE: float = 0.045
const PRE_BARRIER_CLEANUP_EPSILON: float = 0.02

var _obstacle_demolition_serial: int = 0


func _create_obstacle(
	obstacle_type: String,
	lane_x: float,
	local_z: float
) -> Node3D:
	var obstacle_root: Node3D = super._create_obstacle(
		obstacle_type,
		lane_x,
		local_z
	)
	if obstacle_root == null:
		return obstacle_root

	obstacle_root.set_meta("car_activated_demolition", true)
	obstacle_root.set_meta("demolition_activated", false)
	obstacle_root.add_to_group("car_activated_road_obstacle")
	_install_dormant_obstacle_physics(obstacle_root, obstacle_type)
	return obstacle_root


func _install_dormant_obstacle_physics(
	obstacle_root: Node3D,
	obstacle_type: String
) -> void:
	var collider_size: Vector3 = BARRIER_COLLIDER_SIZE
	var collider_center: Vector3 = BARRIER_COLLIDER_CENTER
	if obstacle_type == "skeleton":
		collider_size = SKELETON_COLLIDER_SIZE
		collider_center = SKELETON_COLLIDER_CENTER

	# The obstacle is solid, but remains a StaticBody until the Porsche itself
	# touches its dedicated Area3D sensor. Crash debris is on layer 8 and cannot
	# activate the sensor, which listens exclusively to the car's layer 16.
	var dormant_body: StaticBody3D = StaticBody3D.new()
	dormant_body.name = "DormantCarOnlyObstacleBody"
	dormant_body.collision_layer = CRASH_PROP_LAYER
	dormant_body.collision_mask = CAR_CRASH_LAYER
	obstacle_root.add_child(dormant_body)

	var dormant_shape: BoxShape3D = BoxShape3D.new()
	dormant_shape.size = collider_size
	var dormant_collision: CollisionShape3D = CollisionShape3D.new()
	dormant_collision.name = "DormantObstacleCollision"
	dormant_collision.shape = dormant_shape
	dormant_collision.position = collider_center
	dormant_body.add_child(dormant_collision)

	var activation_area: Area3D = Area3D.new()
	activation_area.name = "PorscheOnlyDemolitionSensor"
	activation_area.collision_layer = 0
	activation_area.collision_mask = CAR_CRASH_LAYER
	activation_area.monitoring = true
	activation_area.monitorable = false
	obstacle_root.add_child(activation_area)

	var sensor_shape: BoxShape3D = BoxShape3D.new()
	sensor_shape.size = collider_size + OBSTACLE_SENSOR_MARGIN
	var sensor_collision: CollisionShape3D = CollisionShape3D.new()
	sensor_collision.name = "PorscheOnlySensorShape"
	sensor_collision.shape = sensor_shape
	sensor_collision.position = collider_center
	activation_area.add_child(sensor_collision)
	activation_area.body_entered.connect(
		_on_obstacle_sensor_body_entered.bind(obstacle_root)
	)


func _update_obstacles() -> void:
	# The drivable Porsche is a scripted Node3D before the cinematic crash, so
	# normal gameplay contact is detected with the existing lane-distance test.
	# That direct Porsche contact is allowed to trigger demolition. Once the car
	# becomes a RigidBody3D, the layer-16 Area3D sensor takes over automatically.
	if _car == null or not is_instance_valid(_car):
		return

	for segment: Node3D in _road_segments:
		if segment == null or not is_instance_valid(segment):
			continue
		var segment_items: Array = _segment_obstacles.get(segment.name, [])
		for item_variant: Variant in segment_items:
			if not (item_variant is Dictionary):
				continue
			var item: Dictionary = item_variant
			if bool(item.get("hit", false)):
				continue

			var obstacle_node: Node3D = item.get("node") as Node3D
			if obstacle_node == null or not is_instance_valid(obstacle_node):
				continue

			var obstacle_position: Vector3 = obstacle_node.global_position
			var car_position: Vector3 = _car.global_position
			var touched_by_gameplay_car: bool = (
				absf(obstacle_position.z - car_position.z) <= COLLISION_Z_THRESHOLD
				and absf(obstacle_position.x - car_position.x) <= COLLISION_X_THRESHOLD
			)
			if not touched_by_gameplay_car:
				continue

			item["hit"] = true
			_activate_obstacle_demolition(
				obstacle_node,
				_get_scripted_car_contact_velocity(),
				null
			)
			_handle_obstacle_collision(str(item.get("type", "barrier")))


func _get_scripted_car_contact_velocity() -> Vector3:
	var forward_direction: Vector3 = -_car.global_basis.z
	forward_direction.y = 0.0
	if forward_direction.length_squared() <= 0.0001:
		forward_direction = Vector3(0.0, 0.0, -1.0)
	forward_direction = forward_direction.normalized()
	var drive_speed: float = get_current_drive_speed()
	return forward_direction * drive_speed


func _on_obstacle_sensor_body_entered(
	body: Node3D,
	obstacle_root: Node3D
) -> void:
	var physical_car: RigidBody3D = body as RigidBody3D
	if physical_car == null or not is_instance_valid(physical_car):
		return
	var is_porsche: bool = physical_car.is_in_group("physical_porsche_wreck")
	is_porsche = is_porsche or (
		physical_car.collision_layer & CAR_CRASH_LAYER
	) != 0
	if not is_porsche:
		return

	_activate_obstacle_demolition(
		obstacle_root,
		physical_car.linear_velocity,
		physical_car
	)


func _activate_obstacle_demolition(
	obstacle_root: Node3D,
	car_velocity: Vector3,
	physical_car: RigidBody3D
) -> void:
	if obstacle_root == null or not is_instance_valid(obstacle_root):
		return
	if bool(obstacle_root.get_meta("demolition_activated", false)):
		return
	obstacle_root.set_meta("demolition_activated", true)

	var source_meshes: Array[Node] = obstacle_root.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)
	var spawned_count: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for source_node: Node in source_meshes:
		if spawned_count >= MAX_DEMOLITION_FRAGMENTS:
			break
		var source_mesh: MeshInstance3D = source_node as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			continue
		if not source_mesh.visible:
			continue
		if _spawn_obstacle_fragment(
			source_mesh,
			obstacle_root.global_position,
			car_velocity,
			rng
		):
			spawned_count += 1

	# Remove the original static collider and sensor before the next physics step.
	# Only the freshly created pieces remain, and their mask excludes layer-8
	# debris so unrelated fragments cannot keep kicking them around.
	obstacle_root.visible = false
	for child_name: String in [
		"DormantCarOnlyObstacleBody",
		"PorscheOnlyDemolitionSensor"
	]:
		var dormant_node: Node = obstacle_root.get_node_or_null(child_name)
		if dormant_node != null:
			dormant_node.queue_free()
	obstacle_root.queue_free()

	_obstacle_demolition_serial += 1
	print(
		"ROAD OBSTACLE DEMOLITION ",
		_obstacle_demolition_serial,
		": Porsche-only contact spawned ",
		spawned_count,
		" physical pieces at velocity ",
		car_velocity
	)

	# The physical Porsche already lost momentum against the dormant solid body.
	# A restrained additional response prevents it from clipping through a dense
	# object without inventing a sideways launch.
	if physical_car != null and is_instance_valid(physical_car):
		physical_car.sleeping = false


func _spawn_obstacle_fragment(
	source_mesh: MeshInstance3D,
	obstacle_center: Vector3,
	car_velocity: Vector3,
	rng: RandomNumberGenerator
) -> bool:
	var source_scale: Vector3 = source_mesh.global_basis.get_scale().abs()
	var local_size: Vector3 = source_mesh.get_aabb().size
	var fragment_size: Vector3 = Vector3(
		maxf(local_size.x * source_scale.x, MIN_FRAGMENT_SIZE),
		maxf(local_size.y * source_scale.y, MIN_FRAGMENT_SIZE),
		maxf(local_size.z * source_scale.z, MIN_FRAGMENT_SIZE)
	)

	# Ignore the paper-thin reflected skeleton that is rendered on the road.
	if fragment_size.y < 0.035:
		return false

	var body: RigidBody3D = RigidBody3D.new()
	body.name = "CarDemolishedObstaclePiece_%04d" % _obstacle_demolition_serial
	body.mass = clampf(fragment_size.x * fragment_size.y * fragment_size.z * 7.5, 0.22, 24.0)
	body.freeze = false
	body.sleeping = false
	body.can_sleep = true
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.contact_monitor = false
	body.linear_damp = 0.08
	body.angular_damp = 0.075
	body.collision_layer = CRASH_PROP_LAYER
	body.collision_mask = 1 | CAR_CRASH_LAYER

	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.64
	material.bounce = 0.08
	body.physics_material_override = material
	add_child(body)
	body.global_transform = Transform3D(
		source_mesh.global_basis.orthonormalized(),
		source_mesh.global_position
	)

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "DemolishedVisual"
	visual.mesh = source_mesh.mesh
	visual.material_override = source_mesh.material_override
	visual.scale = source_scale
	for surface_index: int in range(source_mesh.mesh.get_surface_count()):
		var override_material: Material = source_mesh.get_surface_override_material(
			surface_index
		)
		if override_material != null:
			visual.set_surface_override_material(surface_index, override_material)
	body.add_child(visual)

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = fragment_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "DemolishedCollision"
	collision.shape = box_shape
	body.add_child(collision)

	var outward: Vector3 = source_mesh.global_position - obstacle_center
	outward.y = 0.0
	if outward.length_squared() <= 0.0001:
		outward = Vector3(
			rng.randf_range(-1.0, 1.0),
			0.0,
			rng.randf_range(-1.0, 1.0)
		)
	if outward.length_squared() <= 0.0001:
		outward = Vector3.RIGHT
	outward = outward.normalized()

	var transferred_velocity: Vector3 = car_velocity * rng.randf_range(0.34, 0.58)
	var separation_velocity: Vector3 = (
		outward * rng.randf_range(1.2, 4.4)
		+ Vector3.UP * rng.randf_range(0.7, 3.6)
	)
	body.linear_velocity = transferred_velocity + separation_velocity
	body.angular_velocity = Vector3(
		rng.randf_range(-7.0, 7.0),
		rng.randf_range(-9.0, 9.0),
		rng.randf_range(-8.0, 8.0)
	)
	_cleanup_demolition_fragment_later(body)
	return true


func _cleanup_demolition_fragment_later(body: RigidBody3D) -> void:
	await get_tree().create_timer(DEMOLITION_FRAGMENT_LIFETIME).timeout
	if body != null and is_instance_valid(body):
		body.queue_free()


func _clear_live_road_obstacles_for_crash() -> void:
	if _car == null or not is_instance_valid(_car):
		return

	var barrier_global_z: float = _car.global_position.z - ROADBLOCK_DISTANCE
	var cleared_count: int = 0
	var preserved_count: int = 0
	var processed_ids: Dictionary = {}

	for segment: Node3D in _road_segments:
		if segment == null or not is_instance_valid(segment):
			continue
		var entries_variant: Variant = _segment_obstacles.get(segment.name, [])
		var kept_entries: Array = []
		if entries_variant is Array:
			var entries: Array = entries_variant
			for entry_variant: Variant in entries:
				if not (entry_variant is Dictionary):
					continue
				var entry: Dictionary = entry_variant
				var obstacle_node: Node3D = entry.get("node") as Node3D
				if obstacle_node == null or not is_instance_valid(obstacle_node):
					continue
				processed_ids[obstacle_node.get_instance_id()] = true
				if _obstacle_is_before_or_at_barrier(
					obstacle_node,
					barrier_global_z
				):
					obstacle_node.visible = false
					obstacle_node.queue_free()
					cleared_count += 1
				else:
					kept_entries.append(entry)
					preserved_count += 1
		_segment_obstacles[segment.name] = kept_entries

	# Replacement art may have been added after the obstacle dictionary was
	# populated. Apply the same world-space cutoff, rather than deleting every
	# metadata-bearing obstacle as the previous implementation did.
	var remaining_nodes: Array[Node] = find_children(
		"*",
		"Node3D",
		true,
		false
	)
	for node: Node in remaining_nodes:
		var obstacle_root: Node3D = node as Node3D
		if obstacle_root == null or not obstacle_root.has_meta("obstacle_type"):
			continue
		if processed_ids.has(obstacle_root.get_instance_id()):
			continue
		if obstacle_root.is_queued_for_deletion():
			continue
		if _obstacle_is_before_or_at_barrier(
			obstacle_root,
			barrier_global_z
		):
			obstacle_root.visible = false
			obstacle_root.queue_free()
			cleared_count += 1
		else:
			preserved_count += 1

	print(
		"BRIDGE CRASH SELECTIVE ROAD CLEANUP: removed ",
		cleared_count,
		" obstacles before the first barrier and preserved ",
		preserved_count,
		" car-activated obstacles beyond it."
	)


func _obstacle_is_before_or_at_barrier(
	obstacle_root: Node3D,
	barrier_global_z: float
) -> bool:
	# Bridge travel is toward negative Z. Greater/equal Z is behind the authored
	# barrier from the Porsche's approach direction and must be cleared. Lower Z
	# is beyond the impact and remains available for the physical wreck to hit.
	return obstacle_root.global_position.z >= (
		barrier_global_z - PRE_BARRIER_CLEANUP_EPSILON
	)
