extends "res://scripts/world/road_memory_exact_car.gd"

const OCEAN_OUTCOME_MAX_SECONDS: float = 12.0
const OCEAN_IMPACT_HOLD_SECONDS: float = 4.2


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


func _resolve_final_car_outcome(
	crash_set: Node3D,
	rail_position: Vector3,
	physical_car: RigidBody3D
) -> void:
	if physical_car == null or not is_instance_valid(physical_car):
		await super._resolve_final_car_outcome(crash_set, rail_position, physical_car)
		return

	_set_crash_caption("YOU HAVE DONE THIS BEFORE")
	_crash_audio.call("start_tinnitus")
	if _crash_camera != null:
		_crash_camera.current = true

	var ocean: Node = get_node_or_null("BridgeRealisticOcean")
	var elapsed: float = 0.0
	var settled_duration: float = 0.0
	var ocean_time: float = 0.0
	var entered_ocean: bool = false
	var outcome: String = "STILL MOVING"
	var bridge_height: float = crash_set.global_position.y

	while elapsed < OCEAN_OUTCOME_MAX_SECONDS:
		await get_tree().physics_frame
		if physical_car == null or not is_instance_valid(physical_car):
			outcome = "PHYSICS BODY LOST"
			break

		var physics_delta: float = get_physics_process_delta_time()
		elapsed += physics_delta
		_update_physical_wreck_camera(physical_car, physics_delta)

		var body_entered_ocean: bool = false
		if ocean != null and ocean.has_method("has_body_entered_water"):
			body_entered_ocean = bool(ocean.call("has_body_entered_water", physical_car))

		if body_entered_ocean:
			if not entered_ocean:
				entered_ocean = true
				_set_crash_caption("THE OCEAN CATCHES WHAT THE BRIDGE LETS GO")
				ocean_time = 0.0
			ocean_time += physics_delta
			if ocean_time >= OCEAN_IMPACT_HOLD_SECONDS:
				outcome = "ENTERED OCEAN"
				break
			continue

		var linear_speed: float = physical_car.linear_velocity.length()
		var angular_speed: float = physical_car.angular_velocity.length()
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

		# This is only an emergency guard if the ocean controller is unavailable.
		if ocean == null and physical_car.global_position.y < bridge_height - 30.0:
			outcome = "FELL FROM BRIDGE WITHOUT OCEAN RESPONSE"
			break

	if physical_car != null and is_instance_valid(physical_car):
		if outcome == "STILL MOVING":
			if entered_ocean:
				outcome = "ENTERED OCEAN"
			elif physical_car.global_position.y < bridge_height - 4.0:
				outcome = "FELL TOWARD OCEAN"
			else:
				outcome = "REMAINED IN MOTION ON BRIDGE"
		print(
			"PORSCHE PHYSICS OUTCOME: ",
			outcome,
			" at ",
			physical_car.global_position,
			" velocity ",
			physical_car.linear_velocity
		)

	await _wait_real_time(0.85)
