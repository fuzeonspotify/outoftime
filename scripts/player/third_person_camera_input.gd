extends "res://scripts/player/third_person_controller.gd"

const MIN_CAMERA_PITCH: float = -55.0
const MAX_CAMERA_PITCH: float = 35.0
const VOID_LANDING_JUMP_DELAY: float = 0.5
const VOID_JUMP_BUFFER_SECONDS: float = 0.16
const VOID_FLOOR_GRACE_SECONDS: float = 0.12
const VOID_LANDING_MIN_AIR_TIME: float = 0.10
const DEFAULT_FLOOR_SNAP_LENGTH: float = 0.10
const VOID_FLOOR_SNAP_LENGTH: float = 0.38

var _void_jump_mode: bool = false
var _void_jump_lock_remaining: float = 0.0
var _void_jump_buffer_remaining: float = 0.0
var _void_floor_grace_remaining: float = 0.0
var _void_airborne_time: float = 0.0
var _void_ground_state_initialized: bool = false


func set_void_jump_mode(enabled: bool) -> void:
	_void_jump_mode = enabled
	floor_snap_length = VOID_FLOOR_SNAP_LENGTH if enabled else DEFAULT_FLOOR_SNAP_LENGTH
	_void_jump_lock_remaining = 0.0
	_void_jump_buffer_remaining = 0.0
	_void_floor_grace_remaining = 0.0
	_void_airborne_time = 0.0
	_void_ground_state_initialized = false
	up_direction = Vector3.UP


func set_void_gravity_state(state: StringName) -> void:
	if not _void_jump_mode:
		return
	var next_up_direction: Vector3 = Vector3.DOWN if state == &"inverted" else Vector3.UP
	if up_direction.is_equal_approx(next_up_direction):
		return
	up_direction = next_up_direction
	_void_floor_grace_remaining = 0.0
	_void_airborne_time = 0.0
	_void_ground_state_initialized = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_pause_open(not _pause_open)
		get_viewport().set_input_as_handled()
		return

	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion == null:
		return

	_apply_mouse_look(mouse_motion.relative)
	get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	# Camera look is intentionally handled in _input so full-screen UI layers
	# cannot consume mouse motion before it reaches the player controller.
	pass


func _physics_process(delta: float) -> void:
	if not _void_jump_mode:
		super._physics_process(delta)
		return
	if get_tree().paused:
		return

	_void_jump_lock_remaining = maxf(0.0, _void_jump_lock_remaining - delta)
	_void_jump_buffer_remaining = maxf(0.0, _void_jump_buffer_remaining - delta)
	if Input.is_action_just_pressed("jump"):
		_void_jump_buffer_remaining = VOID_JUMP_BUFFER_SECONDS

	var grounded_before_move: bool = is_on_floor()
	if grounded_before_move:
		_void_floor_grace_remaining = VOID_FLOOR_GRACE_SECONDS
		_remove_velocity_into_active_surface()
	else:
		_void_floor_grace_remaining = maxf(0.0, _void_floor_grace_remaining - delta)
		velocity.y -= _gravity * delta

	if (
		_void_jump_buffer_remaining > 0.0
		and _void_jump_lock_remaining <= 0.0
		and (grounded_before_move or _void_floor_grace_remaining > 0.0)
	):
		_perform_void_jump()
		grounded_before_move = false

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var forward: Vector3 = -_camera_yaw.global_transform.basis.z
	var right: Vector3 = _camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()

	var target_speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity: Vector3 = move_direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if _visual_root != null:
		var planar_speed: float = Vector2(velocity.x, velocity.z).length()
		var bob_amount: float = clampf(planar_speed / sprint_speed, 0.0, 1.0)
		_visual_root.position.y = sin(float(Time.get_ticks_msec()) * 0.009) * 0.025 * bob_amount
		if move_direction.length_squared() > 0.001:
			_visual_root.rotation.y = lerp_angle(
				_visual_root.rotation.y,
				atan2(-move_direction.x, -move_direction.z),
				minf(1.0, delta * 10.0)
			)

	move_and_slide()
	_update_void_landing_state(delta, grounded_before_move)


func _perform_void_jump() -> void:
	var current_up_speed: float = velocity.dot(up_direction)
	velocity += up_direction * (jump_velocity - current_up_speed)
	_void_jump_buffer_remaining = 0.0
	_void_floor_grace_remaining = 0.0
	_void_airborne_time = 0.0


func _remove_velocity_into_active_surface() -> void:
	var current_up_speed: float = velocity.dot(up_direction)
	if current_up_speed < 0.0:
		velocity -= up_direction * current_up_speed


func _update_void_landing_state(delta: float, grounded_before_move: bool) -> void:
	var grounded_after_move: bool = is_on_floor()
	if grounded_after_move:
		var completed_real_landing: bool = (
			_void_ground_state_initialized
			and not grounded_before_move
			and _void_airborne_time >= VOID_LANDING_MIN_AIR_TIME
		)
		if completed_real_landing:
			_void_jump_lock_remaining = VOID_LANDING_JUMP_DELAY
		_void_floor_grace_remaining = VOID_FLOOR_GRACE_SECONDS
		_void_airborne_time = 0.0
	else:
		_void_airborne_time += delta
	_void_ground_state_initialized = true


func _apply_mouse_look(look_delta: Vector2) -> void:
	if _camera_yaw == null or _camera_pitch == null or look_delta == Vector2.ZERO:
		return

	_camera_yaw.rotate_y(-look_delta.x * mouse_sensitivity)
	_camera_pitch.rotation.x = clampf(
		_camera_pitch.rotation.x - look_delta.y * mouse_sensitivity,
		deg_to_rad(MIN_CAMERA_PITCH),
		deg_to_rad(MAX_CAMERA_PITCH)
	)
