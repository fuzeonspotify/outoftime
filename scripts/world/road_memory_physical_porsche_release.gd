extends "res://scripts/world/road_memory_exact_car.gd"


func _begin_final_car_physics(
	_crash_set: Node3D,
	rail_position: Vector3,
	rail_tween: Tween
) -> RigidBody3D:
	if _car == null or not is_instance_valid(_car):
		push_error("PORSCHE PHYSICS ERROR: the live Porsche root is unavailable.")
		return null

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

	# Preserve strong forward crash speed while avoiding a scripted outward throw.
	# The remaining lateral velocity is enough to contact the rail, but the heavy
	# rail pieces and deck friction now determine whether the car stays or falls.
	var initial_velocity: Vector3 = (
		impact_direction * 7.2
		+ Vector3(0.0, 0.85, -1.4)
	)
	var initial_angular_velocity: Vector3 = Vector3(0.45, -0.75, -0.95)
	_launch_physical_porsche_after_frame(
		body,
		initial_velocity,
		initial_angular_velocity
	)

	print(
		"PORSCHE PHYSICS HANDOFF: guardrail contact now determines the final trajectory at ",
		body.global_position
	)
	return body
