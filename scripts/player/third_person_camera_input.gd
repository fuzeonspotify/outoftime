extends "res://scripts/player/third_person_controller.gd"

const MIN_CAMERA_PITCH: float = -55.0
const MAX_CAMERA_PITCH: float = 35.0


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


func _apply_mouse_look(look_delta: Vector2) -> void:
	if _camera_yaw == null or _camera_pitch == null or look_delta == Vector2.ZERO:
		return

	_camera_yaw.rotate_y(-look_delta.x * mouse_sensitivity)
	_camera_pitch.rotation.x = clampf(
		_camera_pitch.rotation.x - look_delta.y * mouse_sensitivity,
		deg_to_rad(MIN_CAMERA_PITCH),
		deg_to_rad(MAX_CAMERA_PITCH)
	)
