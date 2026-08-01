extends "res://scripts/world/road_memory_extra_crash_velocity_release.gd"

const LOOSE_SURFACE_FRICTION: float = 0.34
const LOOSE_LINEAR_DAMP: float = 0.025
const LOOSE_ANGULAR_DAMP: float = 0.025
const MIN_YAW_SPEED: float = 0.42
const MAX_YAW_SPEED: float = 1.18
const MAX_ROLL_SPEED: float = 0.34


func _begin_center_impact_physics() -> RigidBody3D:
	var body: RigidBody3D = super._begin_center_impact_physics()
	if body == null or not is_instance_valid(body):
		return body

	body.linear_damp = LOOSE_LINEAR_DAMP
	body.angular_damp = LOOSE_ANGULAR_DAMP
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.0, 0.36, 0.20)

	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = LOOSE_SURFACE_FRICTION
	material.bounce = 0.035
	material.rough = false
	body.physics_material_override = material

	_apply_rotational_instability_after_launch(body)
	return body


func _apply_rotational_instability_after_launch(body: RigidBody3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if body == null or not is_instance_valid(body):
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var turn_sign: float = -1.0 if rng.randf() < 0.5 else 1.0
	var angular_bias: Vector3 = Vector3(
		rng.randf_range(-0.16, 0.16),
		turn_sign * rng.randf_range(MIN_YAW_SPEED, MAX_YAW_SPEED),
		-turn_sign * rng.randf_range(0.08, MAX_ROLL_SPEED)
	)

	body.angular_velocity += angular_bias
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY,
		body.angular_velocity
	)
	print(
		"PORSCHE LOOSE TRACTION: friction ",
		LOOSE_SURFACE_FRICTION,
		", angular bias ",
		angular_bias,
		", velocity remains ",
		body.linear_velocity
	)
