extends "res://scripts/world/road_memory_crash_release.gd"

const CRASH_CENTER_X: float = 0.0
const ROADBLOCK_DISTANCE: float = 66.0
const PREMONITION_SECONDS: float = 2.20
const APPROACH_SECONDS_FINAL: float = 5.80
const BRAKE_SECONDS: float = 2.20
const IMPACT_HOLD_SECONDS: float = 1.20
const RAIL_SLIDE_SECONDS_FINAL: float = 3.60
const FALL_SECONDS_FINAL: float = 5.40
const CENTER_IMPACT_TIME_SCALE: float = 0.24
const RAIL_IMPACT_TIME_SCALE: float = 0.30


func _play_crash_sequence(failed: bool) -> void:
	Engine.time_scale = 1.0
	MusicDirector.stop_music(11.0)
	SFXDirector.stop_environment(5.0)
	_distance_label.text = "BRIDGE SIGNAL  LOST"
	_integrity_label.text = "MEMORY INTEGRITY  CRITICAL"
	_message_label.visible = true
	_message_label.text = (
		"The bridge remembers the crash before you do."
		if not failed
		else "The failed memory chooses the same ending."
	)
	_build_crash_camera()
	var crash_set: Node3D = _build_crash_set()
	_set_cinematic_bars(92.0)
	_set_crash_caption("THE ROAD NARROWS TO ONE POINT")
	_crash_audio.call("play_heartbeat")

	var start_y: float = _car.position.y
	var impact_z: float = crash_set.position.z
	var impact_position: Vector3 = Vector3(CRASH_CENTER_X, start_y + 0.16, impact_z)
	var approach_position: Vector3 = impact_position + Vector3(0.0, -0.16, 18.0)
	var brake_position: Vector3 = impact_position + Vector3(0.0, -0.10, 4.2)

	await get_tree().create_timer(PREMONITION_SECONDS).timeout
	_crash_audio.call("play_tire_screech")
	_crash_rig.global_position = _car.global_position + Vector3(-11.0, 3.4, 13.5)
	_crash_rig.look_at(_car.global_position + Vector3(0.0, 0.8, -9.0), Vector3.UP)
	var approach_tween: Tween = create_tween().set_parallel(true)
	approach_tween.tween_property(
		_car,
		"position",
		approach_position,
		APPROACH_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	approach_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(0.0, 0.0, -2.5),
		APPROACH_SECONDS_FINAL * 0.76
	).set_trans(Tween.TRANS_SINE)
	approach_tween.tween_property(
		_crash_rig,
		"global_position",
		Vector3(-11.5, 4.1, impact_z + 10.0),
		APPROACH_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(APPROACH_SECONDS_FINAL).timeout

	_set_crash_caption("THE ROADBLOCK IS DIRECTLY AHEAD")
	_crash_rig.global_position = approach_position + Vector3(0.0, 2.6, 9.5)
	_crash_rig.look_at(impact_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	var brake_tween: Tween = create_tween().set_parallel(true)
	brake_tween.tween_property(
		_car,
		"position",
		brake_position,
		BRAKE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	brake_tween.tween_property(
		_car,
		"rotation_degrees:z",
		4.0,
		BRAKE_SECONDS
	).set_trans(Tween.TRANS_SINE)
	brake_tween.tween_property(_crash_camera, "fov", 61.0, BRAKE_SECONDS)
	await get_tree().create_timer(BRAKE_SECONDS).timeout

	_set_crash_caption("THERE IS NOWHERE LEFT TO STEER")
	var impact_tween: Tween = create_tween().set_parallel(true)
	impact_tween.tween_property(
		_car,
		"position",
		impact_position,
		1.05
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	impact_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(-7.0, 0.0, 1.5),
		1.05
	).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(1.05).timeout

	_crash_audio.call("play_major_impact")
	_crash_audio.call("play_glass_burst")
	_add_crash_shake(1.0)
	_flash_crash(Color(1.0, 0.38, 0.55, 0.82), 0.92)
	_trigger_center_physics_now()
	_break_centered_roadblock(crash_set)
	_start_center_impact_car_motion(impact_position)
	await _play_center_impact_slow_motion(crash_set)
	await get_tree().create_timer(0.22).timeout

	_crash_audio.call("play_guardrail_hit", 0.94)
	_set_crash_caption("THE IMPACT THROWS YOU SIDEWAYS")
	var rail_position: Vector3 = impact_position + Vector3(6.15, 0.52, -14.5)
	_crash_rig.global_position = impact_position + Vector3(11.5, 4.0, 8.0)
	_crash_rig.look_at(impact_position + Vector3(3.0, 0.7, -7.0), Vector3.UP)
	var rail_tween: Tween = create_tween().set_parallel(true)
	rail_tween.tween_property(
		_car,
		"position",
		rail_position,
		RAIL_SLIDE_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	rail_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(18.0, -42.0, -36.0),
		RAIL_SLIDE_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUAD)
	rail_tween.tween_property(
		_crash_rig,
		"global_position",
		rail_position + Vector3(9.2, 4.6, 7.4),
		RAIL_SLIDE_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(RAIL_SLIDE_SECONDS_FINAL * 0.72).timeout
	_trigger_rail_physics_now()
	_break_right_guardrail(crash_set)
	var physical_car: RigidBody3D = _begin_final_car_physics(
		crash_set,
		rail_position,
		rail_tween
	)
	await _play_rail_impact_slow_motion(crash_set)
	if physical_car == null:
		await get_tree().create_timer(RAIL_SLIDE_SECONDS_FINAL * 0.28).timeout

	_crash_audio.call("play_major_impact")
	_add_crash_shake(0.96)
	_flash_crash(Color(1.0, 0.82, 0.94, 0.72), 0.86)
	await get_tree().create_timer(0.90).timeout

	await _resolve_final_car_outcome(crash_set, rail_position, physical_car)

	_crash_audio.call("play_heartbeat")
	await get_tree().create_timer(0.85).timeout
	var whiteout_tween: Tween = create_tween()
	whiteout_tween.tween_property(_crash_whiteout, "color:a", 1.0, 2.80).set_trans(Tween.TRANS_SINE)
	await whiteout_tween.finished
	_crash_audio.call("stop_all", 1.6)
	await get_tree().create_timer(0.70).timeout
	Engine.time_scale = 1.0
	var heaven_scene: PackedScene = StartupPreloader.get_preloaded_scene(CITY_SCENE_PATH)
	if heaven_scene != null:
		get_tree().change_scene_to_packed(heaven_scene)
	else:
		get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _play_center_impact_slow_motion(crash_set: Node3D) -> void:
	Engine.time_scale = CENTER_IMPACT_TIME_SCALE
	var target: Vector3 = crash_set.to_global(Vector3(0.0, 0.86, 0.0))
	_place_close_crash_camera(target + Vector3(-4.2, 1.25, 3.35), target, 46.0)
	await _wait_real_time(0.52)
	_place_close_crash_camera(target + Vector3(3.45, 1.55, -2.55), target + Vector3(0.0, 0.30, -0.4), 42.0)
	await _wait_real_time(0.50)
	_place_close_crash_camera(target + Vector3(-0.55, 5.05, 1.35), target, 50.0)
	await _wait_real_time(0.46)
	Engine.time_scale = 1.0


func _play_rail_impact_slow_motion(crash_set: Node3D) -> void:
	Engine.time_scale = RAIL_IMPACT_TIME_SCALE
	var target: Vector3 = crash_set.to_global(Vector3(5.95, 0.78, -14.5))
	_place_close_crash_camera(target + Vector3(2.9, 0.95, 2.55), target, 43.0)
	await _wait_real_time(0.48)
	_place_close_crash_camera(target + Vector3(-2.75, 1.30, -1.45), target + Vector3(0.5, 0.15, 0.0), 39.0)
	await _wait_real_time(0.50)
	_place_close_crash_camera(target + Vector3(1.0, 4.65, 3.0), target, 48.0)
	await _wait_real_time(0.44)
	Engine.time_scale = 1.0


func _wait_real_time(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _place_close_crash_camera(
	camera_position: Vector3,
	target_position: Vector3,
	field_of_view: float
) -> void:
	if _crash_rig == null or _crash_camera == null:
		return
	_crash_rig.global_position = camera_position
	_crash_rig.look_at(target_position, Vector3.UP)
	_crash_camera.fov = field_of_view


func _trigger_center_physics_now() -> void:
	var physics_director: Node = get_node_or_null("BridgeCrashPhysicsDirector")
	if physics_director != null and physics_director.has_method("_trigger_center_impact"):
		physics_director.call("_trigger_center_impact")


func _trigger_rail_physics_now() -> void:
	var physics_director: Node = get_node_or_null("BridgeCrashPhysicsDirector")
	if physics_director != null and physics_director.has_method("_trigger_right_rail_impact"):
		physics_director.call("_trigger_right_rail_impact")
	var final_edge_director: Node = get_node_or_null("BridgeFinalEdgeRailPhysics")
	if final_edge_director != null and final_edge_director.has_method("_trigger_final_edge_rail"):
		final_edge_director.call("_trigger_final_edge_rail")


func _start_center_impact_car_motion(_impact_position: Vector3) -> void:
	pass


func _begin_final_car_physics(
	_crash_set: Node3D,
	_rail_position: Vector3,
	_rail_tween: Tween
) -> RigidBody3D:
	return null


func _resolve_final_car_outcome(
	_crash_set: Node3D,
	rail_position: Vector3,
	_physical_car: RigidBody3D
) -> void:
	_set_crash_caption("YOU HAVE DONE THIS BEFORE")
	var fall_position: Vector3 = rail_position + Vector3(11.0, -30.0, -42.0)
	var fall_tween: Tween = create_tween().set_parallel(true)
	fall_tween.tween_property(
		_car,
		"position",
		fall_position,
		FALL_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(246.0, 352.0, 284.0),
		FALL_SECONDS_FINAL
	).set_trans(Tween.TRANS_QUAD)
	fall_tween.tween_property(
		_crash_rig,
		"global_position",
		rail_position + Vector3(-4.0, 18.0, 16.0),
		FALL_SECONDS_FINAL * 0.76
	).set_trans(Tween.TRANS_QUINT)
	fall_tween.tween_property(_crash_camera, "fov", 90.0, FALL_SECONDS_FINAL * 0.84)
	_crash_audio.call("start_tinnitus")
	await get_tree().create_timer(FALL_SECONDS_FINAL).timeout


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _build_crash_set() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CenteredBridgeCrashSet"
	root.position = Vector3(CRASH_CENTER_X, 0.0, _car.position.z - ROADBLOCK_DISTANCE)
	add_child(root)

	_add_box(root, Vector3(0.0, -0.03, -13.0), Vector3(16.0, 0.18, 52.0), Color("161321"))
	_add_box(root, Vector3(0.0, -0.15, -41.0), Vector3(16.0, 0.10, 8.0), Color("010003"))
	_add_box(root, Vector3(0.0, 0.015, 9.0), Vector3(0.16, 0.025, 22.0), Color("e9d8ae"), Color("f6c96a"))

	for side: float in [-1.0, 1.0]:
		var rail: MeshInstance3D = _add_box(
			root,
			Vector3(side * 7.55, 0.82, -13.0),
			Vector3(0.24, 1.64, 52.0),
			Color("54617d")
		)
		rail.name = "BridgeRail_%s" % ("Left" if side < 0.0 else "Right")
		rail.set_meta("crash_rail", true)

	for barrier_index: int in range(7):
		var barrier_x: float = -6.0 + float(barrier_index) * 2.0
		var barrier: MeshInstance3D = _add_box(
			root,
			Vector3(barrier_x, 0.72, 0.0),
			Vector3(1.88, 1.38, 1.10),
			Color("d9d3c6"),
			Color("ff315f")
		)
		barrier.name = "CenteredRoadblock_%02d" % barrier_index
		barrier.set_meta("crash_barrier", true)

	for warning_index: int in range(5):
		var warning_x: float = -4.0 + float(warning_index) * 2.0
		var warning: MeshInstance3D = _add_box(
			root,
			Vector3(warning_x, 0.14, 5.8),
			Vector3(1.10, 0.14, 2.3),
			Color("f24a86"),
			Color("ff276d")
		)
		warning.rotation_degrees.y = 16.0 if warning_index % 2 == 0 else -16.0
	return root


func _break_centered_roadblock(crash_set: Node3D) -> void:
	var mesh_nodes: Array[Node] = crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var piece: MeshInstance3D = node as MeshInstance3D
		if piece == null or not bool(piece.get_meta("crash_barrier", false)):
			continue
		var outward: float = signf(piece.position.x)
		if is_zero_approx(outward):
			outward = -1.0 if _rng.randf() < 0.5 else 1.0
		var barrier_tween: Tween = create_tween().set_parallel(true)
		barrier_tween.tween_property(
			piece,
			"position",
			piece.position + Vector3(outward * 3.8, 1.4, -3.0),
			1.35
		).set_trans(Tween.TRANS_QUAD)
		barrier_tween.tween_property(
			piece,
			"rotation_degrees",
			Vector3(72.0, outward * 48.0, outward * 84.0),
			1.35
		).set_trans(Tween.TRANS_QUAD)


func _break_right_guardrail(crash_set: Node3D) -> void:
	var mesh_nodes: Array[Node] = crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var rail: MeshInstance3D = node as MeshInstance3D
		if rail == null or not bool(rail.get_meta("crash_rail", false)) or rail.position.x < 0.0:
			continue
		var rail_tween: Tween = create_tween().set_parallel(true)
		rail_tween.tween_property(rail, "rotation_degrees:z", -82.0, 1.75).set_trans(Tween.TRANS_QUAD)
		rail_tween.tween_property(
			rail,
			"position",
			rail.position + Vector3(3.8, -3.2, -2.2),
			1.95
		).set_trans(Tween.TRANS_QUAD)
