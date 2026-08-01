extends "res://scripts/world/road_memory_speed_ramp_release.gd"

const EXTRA_CRASH_VELOCITY_MULTIPLIER: float = 1.5


func _begin_center_impact_physics() -> RigidBody3D:
	if _car == null or not is_instance_valid(_car):
		push_error("PORSCHE PHYSICS ERROR: the live Porsche root is unavailable at the first impact.")
		return null
	if _physical_wreck_body != null and is_instance_valid(_physical_wreck_body):
		return _physical_wreck_body

	var car_global_transform: Transform3D = _car.global_transform
	var forward_direction: Vector3 = -car_global_transform.basis.z
	forward_direction.y = 0.0
	if forward_direction.length_squared() <= 0.0001:
		forward_direction = Vector3(0.0, 0.0, -1.0)
	forward_direction = forward_direction.normalized()

	var body: RigidBody3D = RigidBody3D.new()
	body.name = "PhysicalPorscheWreck"
	body.mass = PHYSICAL_CAR_MASS * CRASH_MASS_MULTIPLIER
	body.freeze = false
	body.sleeping = false
	body.can_sleep = true
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 32
	body.linear_damp = 0.04
	body.angular_damp = 0.08
	body.collision_layer = CAR_CRASH_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.0, 0.22, 0.08)
	body.add_to_group("physical_porsche_wreck")

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.92
	physics_material.bounce = 0.025
	body.physics_material_override = physics_material

	add_child(body)
	body.global_transform = car_global_transform
	_add_physical_porsche_collision(body)
	_car.reparent(body, true)
	_car.transform = Transform3D.IDENTITY
	_physical_wreck_body = body

	# The original 2.5x crash boost remains active, with an additional 1.5x
	# stacked here. No lateral or angular launch is introduced.
	var total_velocity_multiplier: float = (
		CRASH_VELOCITY_MULTIPLIER
		* EXTRA_CRASH_VELOCITY_MULTIPLIER
	)
	var initial_velocity: Vector3 = (
		forward_direction
		* NATURAL_IMPACT_SPEED
		* total_velocity_multiplier
	)
	initial_velocity.y = -0.18 * total_velocity_multiplier
	_launch_physical_porsche_after_frame(body, initial_velocity, Vector3.ZERO)
	print(
		"PORSCHE NATURAL PHYSICS HANDOFF: mass ",
		body.mass,
		" and crash velocity ",
		initial_velocity,
		" using total multiplier ",
		total_velocity_multiplier
	)
	return body
