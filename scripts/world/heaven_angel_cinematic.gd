extends "res://scripts/world/heaven_angel.gd"


func begin_finale_grab(target_world_position: Vector3, duration: float) -> void:
	_finale_grab_active = true
	_purified = false
	var target_local_position: Vector3 = target_world_position
	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d != null:
		target_local_position = parent_3d.to_local(target_world_position)
	var approach_duration: float = maxf(0.8, duration)
	var approach_tween: Tween = create_tween().set_parallel(true)
	approach_tween.tween_property(
		self,
		"position",
		target_local_position,
		approach_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_property(
		self,
		"rotation:z",
		0.0,
		approach_duration * 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_property(
		_visual_root,
		"scale",
		Vector3.ONE * 1.10,
		approach_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_property(
		_left_wing,
		"rotation_degrees",
		Vector3(32.0, -58.0, -88.0),
		approach_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_property(
		_right_wing,
		"rotation_degrees",
		Vector3(32.0, 58.0, 88.0),
		approach_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
