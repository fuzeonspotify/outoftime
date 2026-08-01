extends "res://scripts/world/road_memory_extra_crash_velocity_release.gd"

const WHEEL_OFFSETS: Array = [
	Vector3(-0.78, 0.25, -1.43),
	Vector3(0.78, 0.25, -1.43),
	Vector3(-0.78, 0.25, 1.34),
	Vector3(0.78, 0.25, 1.34)
]
const WHEEL_COLLISION_RADIUS: float = 0.29
const SUSPENSION_RAY_START: float = 0.16
const SUSPENSION_RAY_LENGTH: float = 0.78
const TIRE_GRIP_RESPONSE: float = 3.15
const TIRE_PEAK_FRICTION: float = 1.08
const TIRE_SLIDE_FRICTION: float = 0.30
const BODY_SLIDE_FRICTION: float = 0.68
const AIRBORNE_FRICTION: float = 0.08
const ROLLING_RESISTANCE: float = 0.018
const AERODYNAMIC_DRAG: float = 0.00034
const ROLL_FORCE_LEVER_ARM: float = 0.42
const IMPACT_DELTA_V_THRESHOLD: float = 2.35
const IMPACT_RESPONSE_COOLDOWN: float = 0.14
const MAX_IMPACT_TORQUE_IMPULSE: float = 285.0
const MAX_GRIP_CATCH_TORQUE_IMPULSE: float = 190.0

var _realistic_wreck_body: RigidBody3D
var _wreck_physics_material: PhysicsMaterial
var _previous_wreck_velocity: Vector3 = Vector3.ZERO
var _previous_lateral_speed: float = 0.0
var _impact_response_cooldown: float = 0.0
var _impact_asymmetry: float = 0.0
var _wreck_state: String = ""
var _dynamics_initialized: bool = false


func _begin_center_impact_physics() -> RigidBody3D:
	var body: RigidBody3D = super._begin_center_impact_physics()
	if body == null or not is_instance_valid(body):
		return body

	_realistic_wreck_body = body
	body.linear_damp = 0.014
	body.angular_damp = 0.018
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.0, 0.31, 0.10)
	body.max_contacts_reported = 48

	_wreck_physics_material = PhysicsMaterial.new()
	_wreck_physics_material.friction = TIRE_SLIDE_FRICTION
	_wreck_physics_material.bounce = 0.018
	_wreck_physics_material.rough = false
	body.physics_material_override = _wreck_physics_material

	_add_wheel_corner_collisions(body)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	# This never adds sideways translation. It only breaks impossible perfect
	# symmetry when a real measured collision creates a rotational impulse.
	_impact_asymmetry = rng.randf_range(-0.18, 0.18)
	_previous_wreck_velocity = Vector3.ZERO
	_previous_lateral_speed = 0.0
	_impact_response_cooldown = 0.0
	_dynamics_initialized = false
	set_physics_process(true)

	print(
		"PORSCHE REALISTIC WRECK DYNAMICS READY: tire slip, grip catch, pitch, yaw and rollover are physics-driven."
	)
	return body


func _physics_process(delta: float) -> void:
	if _realistic_wreck_body == null or not is_instance_valid(_realistic_wreck_body):
		return
	if bool(_realistic_wreck_body.get_meta("ocean_entered", false)):
		_set_wreck_state("IN WATER")
		return

	# Wait until the parent release has assigned the 67.5 launch velocity. This
	# prevents the launch itself from being mistaken for a collision delta-v.
	if not _dynamics_initialized:
		if _realistic_wreck_body.linear_velocity.length() < 10.0:
			return
		_previous_wreck_velocity = _realistic_wreck_body.linear_velocity
		var launch_basis: Basis = _realistic_wreck_body.global_basis.orthonormalized()
		_previous_lateral_speed = _realistic_wreck_body.linear_velocity.dot(
			launch_basis.x.normalized()
		)
		_dynamics_initialized = true
		print(
			"PORSCHE REALISTIC WRECK DYNAMICS ACTIVE at velocity ",
			_previous_wreck_velocity
		)
		return

	_update_realistic_wreck_dynamics(
		_realistic_wreck_body,
		maxf(delta, 0.0001)
	)


func _update_realistic_wreck_dynamics(body: RigidBody3D, delta: float) -> void:
	_impact_response_cooldown = maxf(0.0, _impact_response_cooldown - delta)

	var basis: Basis = body.global_basis.orthonormalized()
	var right_axis: Vector3 = basis.x.normalized()
	var local_up: Vector3 = basis.y.normalized()
	var forward_axis: Vector3 = -basis.z.normalized()
	var uprightness: float = local_up.dot(Vector3.UP)

	var contact_data: Dictionary = _sample_tire_contacts(body, local_up)
	var tire_contact_count: int = int(contact_data.get("count", 0))
	var tire_contact_ratio: float = float(tire_contact_count) / 4.0
	var body_contact_count: int = body.get_colliding_bodies().size()

	var velocity: Vector3 = body.linear_velocity
	var planar_velocity: Vector3 = velocity - Vector3.UP * velocity.dot(Vector3.UP)
	var speed: float = velocity.length()
	var forward_speed: float = planar_velocity.dot(forward_axis)
	var lateral_speed: float = planar_velocity.dot(right_axis)
	var slip_angle: float = atan2(
		absf(lateral_speed),
		maxf(absf(forward_speed), 0.50)
	)

	_apply_aerodynamic_drag(body, velocity, speed)

	var tires_can_grip: bool = tire_contact_count > 0 and uprightness > 0.24
	if tires_can_grip:
		_apply_tire_contact_forces(
			body,
			forward_axis,
			right_axis,
			planar_velocity,
			forward_speed,
			lateral_speed,
			slip_angle,
			tire_contact_ratio
		)
		_apply_grip_catch_rollover(
			body,
			forward_axis,
			lateral_speed,
			tire_contact_ratio
		)

	_apply_collision_rotation_response(
		body,
		forward_axis,
		right_axis,
		velocity,
		uprightness,
		tire_contact_count,
		body_contact_count
	)
	_update_contact_material(
		body,
		uprightness,
		tire_contact_count,
		body_contact_count,
		slip_angle
	)
	_update_wreck_state(
		body,
		uprightness,
		tire_contact_count,
		body_contact_count,
		slip_angle,
		speed
	)

	_previous_wreck_velocity = velocity
	_previous_lateral_speed = lateral_speed


func _sample_tire_contacts(body: RigidBody3D, local_up: Vector3) -> Dictionary:
	var world: World3D = body.get_world_3d()
	if world == null:
		return {"count": 0, "normal": Vector3.UP}
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	var contact_count: int = 0
	var accumulated_normal: Vector3 = Vector3.ZERO

	for offset_variant: Variant in WHEEL_OFFSETS:
		var wheel_offset: Vector3 = offset_variant
		var ray_from: Vector3 = body.to_global(
			wheel_offset + Vector3.UP * SUSPENSION_RAY_START
		)
		var ray_to: Vector3 = ray_from - local_up * SUSPENSION_RAY_LENGTH
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
		query.from = ray_from
		query.to = ray_to
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [body.get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			continue
		contact_count += 1
		var hit_normal: Vector3 = result.get("normal", Vector3.UP)
		accumulated_normal += hit_normal

	var average_normal: Vector3 = Vector3.UP
	if accumulated_normal.length_squared() > 0.0001:
		average_normal = accumulated_normal.normalized()
	return {"count": contact_count, "normal": average_normal}


func _apply_tire_contact_forces(
	body: RigidBody3D,
	forward_axis: Vector3,
	right_axis: Vector3,
	planar_velocity: Vector3,
	forward_speed: float,
	lateral_speed: float,
	slip_angle: float,
	contact_ratio: float
) -> void:
	# Grip peaks at a small slip angle and then falls away into a skid.
	var normalized_slip: float = slip_angle / 0.30
	var grip_falloff: float = 1.0 / (1.0 + normalized_slip * normalized_slip)
	var effective_friction: float = lerpf(
		TIRE_SLIDE_FRICTION,
		TIRE_PEAK_FRICTION,
		grip_falloff
	)
	var requested_lateral_force: Vector3 = (
		-right_axis
		* lateral_speed
		* body.mass
		* TIRE_GRIP_RESPONSE
		* contact_ratio
	)
	var maximum_lateral_force: float = (
		body.mass
		* 9.81
		* effective_friction
		* contact_ratio
	)
	requested_lateral_force = _limit_vector_length(
		requested_lateral_force,
		maximum_lateral_force
	)
	body.apply_central_force(requested_lateral_force)

	# Tire force occurs below the center of mass, creating load transfer and roll.
	var lateral_force_scalar: float = requested_lateral_force.dot(right_axis)
	body.apply_torque(
		forward_axis * (-lateral_force_scalar * ROLL_FORCE_LEVER_ARM)
	)

	if planar_velocity.length_squared() > 0.01:
		body.apply_central_force(
			-planar_velocity.normalized()
			* body.mass
			* 9.81
			* ROLLING_RESISTANCE
			* contact_ratio
		)

	# Low-slip tires resist yaw. Broadside tires lose this stabilizing effect.
	var yaw_rate: float = body.angular_velocity.dot(Vector3.UP)
	body.apply_torque(
		-Vector3.UP
		* yaw_rate
		* body.mass
		* 0.34
		* grip_falloff
		* contact_ratio
	)

	# A partially yawed car can carve a curved path when its tires still grip.
	if absf(forward_speed) > 1.0 and grip_falloff > 0.18:
		var desired_forward_velocity: Vector3 = forward_axis * forward_speed
		var direction_correction: Vector3 = (
			desired_forward_velocity - planar_velocity
		) * body.mass * 0.26 * grip_falloff * contact_ratio
		body.apply_central_force(
			_limit_vector_length(
				direction_correction,
				maximum_lateral_force * 0.32
			)
		)


func _apply_grip_catch_rollover(
	body: RigidBody3D,
	forward_axis: Vector3,
	lateral_speed: float,
	contact_ratio: float
) -> void:
	var previous_abs: float = absf(_previous_lateral_speed)
	var current_abs: float = absf(lateral_speed)
	var lateral_speed_removed: float = previous_abs - current_abs
	if previous_abs < 4.2 or lateral_speed_removed < 0.48:
		return

	# A broadside slide that suddenly regains wheel-edge or tire grip can roll.
	var catch_strength: float = (
		lateral_speed_removed
		* previous_abs
		* body.mass
		* 0.022
		* contact_ratio
	)
	var roll_sign: float = signf(_previous_lateral_speed)
	var rollover_impulse: Vector3 = (
		-forward_axis * roll_sign * catch_strength
	)
	rollover_impulse = _limit_vector_length(
		rollover_impulse,
		MAX_GRIP_CATCH_TORQUE_IMPULSE
	)
	body.apply_torque_impulse(rollover_impulse)


func _apply_collision_rotation_response(
	body: RigidBody3D,
	forward_axis: Vector3,
	right_axis: Vector3,
	current_velocity: Vector3,
	uprightness: float,
	tire_contact_count: int,
	body_contact_count: int
) -> void:
	if _impact_response_cooldown > 0.0:
		return
	if tire_contact_count == 0 and body_contact_count == 0:
		return

	var velocity_lost: Vector3 = _previous_wreck_velocity - current_velocity
	var impact_strength: float = velocity_lost.length()
	if impact_strength < IMPACT_DELTA_V_THRESHOLD:
		return

	var longitudinal_loss: float = maxf(velocity_lost.dot(forward_axis), 0.0)
	var lateral_loss: float = velocity_lost.dot(right_axis)
	var vertical_loss: float = velocity_lost.dot(Vector3.UP)

	# Longitudinal loss pitches the nose; lateral loss rolls and yaws the car.
	var pitch_impulse: Vector3 = (
		-right_axis * longitudinal_loss * body.mass * 0.030
	)
	var roll_impulse: Vector3 = (
		forward_axis * lateral_loss * body.mass * 0.040
	)
	var yaw_impulse: Vector3 = (
		Vector3.UP
		* body.mass
		* (
			-lateral_loss * 0.020
			+ longitudinal_loss * _impact_asymmetry * 0.018
		)
	)
	var vertical_tumble: Vector3 = (
		forward_axis
		* vertical_loss
		* body.mass
		* 0.010
		* (1.0 - absf(uprightness))
	)
	var total_torque_impulse: Vector3 = (
		pitch_impulse
		+ roll_impulse
		+ yaw_impulse
		+ vertical_tumble
	)
	total_torque_impulse = _limit_vector_length(
		total_torque_impulse,
		MAX_IMPACT_TORQUE_IMPULSE
	)
	body.apply_torque_impulse(total_torque_impulse)
	_impact_response_cooldown = IMPACT_RESPONSE_COOLDOWN

	print(
		"PORSCHE IMPACT ROTATION: delta-v ",
		impact_strength,
		", torque impulse ",
		total_torque_impulse
	)


func _apply_aerodynamic_drag(
	body: RigidBody3D,
	velocity: Vector3,
	speed: float
) -> void:
	if speed <= 0.05:
		return
	body.apply_central_force(
		-velocity
		* speed
		* body.mass
		* AERODYNAMIC_DRAG
	)


func _update_contact_material(
	body: RigidBody3D,
	uprightness: float,
	tire_contact_count: int,
	body_contact_count: int,
	slip_angle: float
) -> void:
	if _wreck_physics_material == null:
		return

	if tire_contact_count > 0 and uprightness > 0.24:
		var slide_blend: float = clampf(slip_angle / 0.70, 0.0, 1.0)
		_wreck_physics_material.friction = lerpf(0.26, 0.42, slide_blend)
		body.angular_damp = lerpf(0.055, 0.020, slide_blend)
	elif body_contact_count > 0:
		# Roof, rocker-panel and side contact scrape harder than rolling tires.
		_wreck_physics_material.friction = BODY_SLIDE_FRICTION
		body.angular_damp = 0.070
	else:
		_wreck_physics_material.friction = AIRBORNE_FRICTION
		body.angular_damp = 0.012


func _update_wreck_state(
	body: RigidBody3D,
	uprightness: float,
	tire_contact_count: int,
	body_contact_count: int,
	slip_angle: float,
	speed: float
) -> void:
	var angular_speed: float = body.angular_velocity.length()
	var state: String
	if tire_contact_count == 0 and body_contact_count == 0:
		state = "AIRBORNE"
	elif absf(uprightness) < 0.42 and angular_speed > 0.75:
		state = "TUMBLING"
	elif tire_contact_count == 0 and body_contact_count > 0:
		state = "BODY SLIDE"
	elif slip_angle > 0.28 and speed > 4.0:
		state = "TIRE SLIDE / SPIN"
	else:
		state = "TIRES GRIPPING"
	_set_wreck_state(state)


func _set_wreck_state(new_state: String) -> void:
	if new_state == _wreck_state:
		return
	_wreck_state = new_state
	print("PORSCHE WRECK STATE: ", new_state)


func _add_wheel_corner_collisions(body: RigidBody3D) -> void:
	for wheel_index: int in range(WHEEL_OFFSETS.size()):
		var wheel_offset: Vector3 = WHEEL_OFFSETS[wheel_index]
		var wheel_shape: SphereShape3D = SphereShape3D.new()
		wheel_shape.radius = WHEEL_COLLISION_RADIUS
		var wheel_collision: CollisionShape3D = CollisionShape3D.new()
		wheel_collision.name = "WheelCornerCollision_%d" % wheel_index
		wheel_collision.shape = wheel_shape
		wheel_collision.position = wheel_offset
		body.add_child(wheel_collision)


func _limit_vector_length(value: Vector3, maximum_length: float) -> Vector3:
	if maximum_length <= 0.0:
		return Vector3.ZERO
	var length_value: float = value.length()
	if length_value <= maximum_length or length_value <= 0.0001:
		return value
	return value * (maximum_length / length_value)
