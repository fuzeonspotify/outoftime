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


func begin_finale_lunge(
	target_world_position: Vector3,
	windup_duration: float,
	lunge_duration: float
) -> void:
	_finale_grab_active = true
	_purified = false
	look_at(target_world_position + Vector3.UP * 1.35, Vector3.UP)

	var target_local_position: Vector3 = target_world_position
	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d != null:
		target_local_position = parent_3d.to_local(target_world_position)

	var retreat_direction: Vector3 = position - target_local_position
	retreat_direction.y = 0.0
	if retreat_direction.length_squared() < 0.001:
		retreat_direction = Vector3.BACK
	else:
		retreat_direction = retreat_direction.normalized()

	var windup_time: float = maxf(0.08, windup_duration)
	var jump_time: float = maxf(0.24, lunge_duration)
	var windup_position: Vector3 = position + retreat_direction * 0.48 + Vector3.DOWN * 0.10
	var lunge_tween: Tween = create_tween()
	lunge_tween.tween_property(
		self,
		"position",
		windup_position,
		windup_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge_tween.parallel().tween_property(
		_visual_root,
		"scale",
		Vector3.ONE * 0.92,
		windup_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge_tween.parallel().tween_property(
		_left_wing,
		"rotation_degrees",
		Vector3(18.0, -30.0, -48.0),
		windup_time
	).set_trans(Tween.TRANS_QUAD)
	lunge_tween.parallel().tween_property(
		_right_wing,
		"rotation_degrees",
		Vector3(18.0, 30.0, 48.0),
		windup_time
	).set_trans(Tween.TRANS_QUAD)

	lunge_tween.tween_property(
		self,
		"position",
		target_local_position,
		jump_time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge_tween.parallel().tween_property(
		self,
		"rotation:z",
		0.0,
		jump_time * 0.55
	).set_trans(Tween.TRANS_QUINT)
	lunge_tween.parallel().tween_property(
		_visual_root,
		"scale",
		Vector3.ONE * 1.18,
		jump_time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge_tween.parallel().tween_property(
		_left_wing,
		"rotation_degrees",
		Vector3(42.0, -70.0, -104.0),
		jump_time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge_tween.parallel().tween_property(
		_right_wing,
		"rotation_degrees",
		Vector3(42.0, 70.0, 104.0),
		jump_time
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
