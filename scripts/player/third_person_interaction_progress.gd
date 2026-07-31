extends "res://scripts/player/third_person_camera_input.gd"


func _update_interaction_hold(delta: float) -> void:
	if not is_instance_valid(_interaction_target):
		if _interaction_target != null:
			_interaction_target = null
			_prompt_panel.visible = false
			_set_crosshair_focused(false)
		_reset_interaction_hold()
		return

	if Input.is_action_just_released("interact"):
		var released_target: Node = _interaction_target
		if released_target.has_method("interaction_hold_progress"):
			released_target.call("interaction_hold_progress", self, 0.0)
		_reset_interaction_hold()
		return

	if not Input.is_action_pressed("interact") or _interaction_triggered:
		return

	if _interaction_hold_duration <= 0.08:
		_trigger_interaction()
		return

	_interaction_hold_elapsed += delta
	var progress_ratio: float = clampf(
		_interaction_hold_elapsed / _interaction_hold_duration,
		0.0,
		1.0
	)
	_prompt_progress.value = progress_ratio * 100.0
	_prompt_action_label.modulate = UI_STYLE.COLOR_TEXT.lerp(Color.WHITE, progress_ratio)

	var active_target: Node = _interaction_target
	if active_target.has_method("interaction_hold_progress"):
		active_target.call("interaction_hold_progress", self, progress_ratio)
	if active_target != _interaction_target or not is_instance_valid(_interaction_target):
		return

	if progress_ratio >= 1.0:
		_trigger_interaction()
