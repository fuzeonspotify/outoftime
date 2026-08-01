extends "res://scripts/world/road_memory_natural_crash_release.gd"

const START_DRIVE_SPEED: float = 21.0
const MAX_DRIVE_SPEED: float = 42.0
const SPEED_RAMP_DISTANCE: float = 680.0
const MAX_STEERING_RESPONSE_MULTIPLIER: float = 1.45
const SPEED_FOV_BOOST: float = 8.0

var _current_drive_speed: float = START_DRIVE_SPEED
var _speed_progress: float = 0.0


func _process(delta: float) -> void:
	# The inherited runtime normally calls the fixed-speed base process and then
	# updates the crash camera. This release owns the gameplay process so every
	# movement-dependent system uses the same gradually increasing live speed.
	if _sequence_finished or _car == null:
		if _crash_active:
			_update_crash_camera(delta)
		return

	_update_live_drive_speed()

	var steer_input: float = Input.get_axis("move_left", "move_right")
	var target_x: float = steer_input * LANE_LIMIT
	var steering_multiplier: float = lerpf(
		1.0,
		MAX_STEERING_RESPONSE_MULTIPLIER,
		_speed_progress
	)
	_car.position.x = move_toward(
		_car.position.x,
		target_x,
		STEER_SPEED * steering_multiplier * delta
	)
	_car.position.z -= _current_drive_speed * delta
	_car.rotation_degrees.z = move_toward(
		_car.rotation_degrees.z,
		-steer_input * 6.0,
		22.0 * steering_multiplier * delta
	)

	var travelled_this_frame: float = _current_drive_speed * delta
	_distance_travelled += travelled_this_frame
	_distance_label.text = "MEMORY DISTANCE  %03d" % int(_distance_travelled)

	var recycle_distance: float = ROAD_SEGMENT_LENGTH * float(ROAD_SEGMENT_COUNT)
	for segment: Node3D in _road_segments:
		if segment.position.z > _car.position.z + ROAD_SEGMENT_LENGTH * 2.5:
			segment.position.z -= recycle_distance
			_reseed_segment(segment)

	_update_atmosphere(delta, steer_input)
	_apply_speed_camera_response(delta)
	_update_obstacles()

	if _distance_travelled >= MEMORY_DISTANCE:
		_show_memory_end()

	if _crash_active:
		_update_crash_camera(delta)


func _update_live_drive_speed() -> void:
	var linear_progress: float = clampf(
		_distance_travelled / SPEED_RAMP_DISTANCE,
		0.0,
		1.0
	)
	# Smoothstep avoids a noticeable acceleration jerk at the beginning and a
	# sudden stop in acceleration when the maximum speed is reached.
	_speed_progress = (
		linear_progress
		* linear_progress
		* (3.0 - 2.0 * linear_progress)
	)
	_current_drive_speed = lerpf(
		START_DRIVE_SPEED,
		MAX_DRIVE_SPEED,
		_speed_progress
	)


func _apply_speed_camera_response(delta: float) -> void:
	if _car_camera == null or not is_instance_valid(_car_camera):
		return
	var target_fov: float = 68.0 + SPEED_FOV_BOOST * _speed_progress
	_car_camera.fov = lerpf(
		_car_camera.fov,
		target_fov,
		clampf(delta * 2.4, 0.0, 1.0)
	)


func get_current_drive_speed() -> float:
	return _current_drive_speed


func get_max_drive_speed() -> float:
	return MAX_DRIVE_SPEED
