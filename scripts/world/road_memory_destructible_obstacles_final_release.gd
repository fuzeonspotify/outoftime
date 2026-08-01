extends "res://scripts/world/road_memory_car_activated_obstacles_release.gd"

var _demolition_fragment_runtime_serial: int = 0


func _activate_obstacle_demolition(
	obstacle_root: Node3D,
	car_velocity: Vector3,
	physical_car: RigidBody3D
) -> void:
	if obstacle_root == null or not is_instance_valid(obstacle_root):
		return
	if bool(obstacle_root.get_meta("demolition_activated", false)):
		return

	# queue_free() occurs at the end of the frame. Disable collision using
	# deferred property changes so this remains safe when called from an Area3D
	# body_entered callback while Godot is flushing physics queries.
	var dormant_body: StaticBody3D = obstacle_root.get_node_or_null(
		"DormantCarOnlyObstacleBody"
	) as StaticBody3D
	if dormant_body != null:
		dormant_body.set_deferred("collision_layer", 0)
		dormant_body.set_deferred("collision_mask", 0)
		var dormant_shapes: Array[Node] = dormant_body.find_children(
			"*",
			"CollisionShape3D",
			true,
			false
		)
		for shape_node: Node in dormant_shapes:
			var collision_shape: CollisionShape3D = shape_node as CollisionShape3D
			if collision_shape != null:
				collision_shape.set_deferred("disabled", true)

	var activation_area: Area3D = obstacle_root.get_node_or_null(
		"PorscheOnlyDemolitionSensor"
	) as Area3D
	if activation_area != null:
		activation_area.set_deferred("monitoring", false)
		activation_area.set_deferred("collision_mask", 0)

	super._activate_obstacle_demolition(
		obstacle_root,
		car_velocity,
		physical_car
	)


func _spawn_obstacle_fragment(
	source_mesh: MeshInstance3D,
	obstacle_center: Vector3,
	car_velocity: Vector3,
	rng: RandomNumberGenerator
) -> bool:
	var source_scale: Vector3 = source_mesh.global_basis.get_scale().abs()
	var source_size: Vector3 = source_mesh.get_aabb().size
	var raw_scaled_size: Vector3 = Vector3(
		source_size.x * source_scale.x,
		source_size.y * source_scale.y,
		source_size.z * source_scale.z
	)

	# Skeleton obstacles include a deliberately flattened reflection beneath the
	# real figure. It remains a visual effect and never becomes a rigid fragment.
	if raw_scaled_size.y < 0.035:
		return false

	var child_count_before: int = get_child_count()
	var spawned: bool = super._spawn_obstacle_fragment(
		source_mesh,
		obstacle_center,
		car_velocity,
		rng
	)
	if not spawned:
		return false

	for child_index: int in range(child_count_before, get_child_count()):
		var fragment: RigidBody3D = get_child(child_index) as RigidBody3D
		if fragment == null:
			continue
		if not str(fragment.name).begins_with("CarDemolishedObstaclePiece"):
			continue
		_demolition_fragment_runtime_serial += 1
		fragment.name = "CarDemolishedObstaclePiece_%05d" % (
			_demolition_fragment_runtime_serial
		)
	return true
