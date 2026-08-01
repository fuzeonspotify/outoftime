extends "res://scripts/world/road_memory_physical_porsche_release.gd"

const NATURAL_IMPACT_SPEED: float = 18.0
const NATURAL_RAIL_WAIT_SECONDS: float = 5.5
const EDGE_RAIL_CONTACT_X: float = 4.72
const RAIL_ZONE_MIN_Z: float = -24.0
const RAIL_ZONE_MAX_Z: float = -7.0


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
	var rail_position: Vector3 = impact_position + Vector3(6.15, 0.52, -14.5)

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
	var physical_car: RigidBody3D = _begin_center_impact_physics()
	await _play_center_impact_slow_motion(crash_set)
	await get_tree().create_timer(0.22).timeout

	var edge_side: float = await _wait_for_natural_edge_contact(
		crash_set,
		physical_car,
		NATURAL_RAIL_WAIT_SECONDS
	)
	if not is_zero_approx(edge_side):
		_crash_audio.call("play_guardrail_hit", 0.94)
		_set_crash_caption("THE WRECK FINDS THE EDGE")
		_trigger_natural_edge_physics(crash_set, edge_side)
		await _play_natural_edge_slow_motion(crash_set, edge_side)
		_crash_audio.call("play_major_impact")
		_add_crash_shake(0.96)
		_flash_crash(Color(1.0, 0.82, 0.94, 0.72), 0.86)
		await get_tree().create_timer(0.90).timeout
	else:
		_set_crash_caption("THE WRECK CHOOSES ITS OWN ENDING")
		await _wait_real_time(0.55)

	await _resolve_final_car_outcome(crash_set, rail_position, physical_car)

	_crash_audio.call("play_heartbeat")
	await get_tree().create_timer(0.85).timeout
	var whiteout_tween: Tween = create_tween()
	whiteout_tween.tween_property(
		_crash_whiteout,
		"color:a",
		1.0,
		2.80
	).set_trans(Tween.TRANS_SINE)
	await whiteout_tween.finished
	_crash_audio.call("stop_all", 1.6)
	await get_tree().create_timer(0.70).timeout
	Engine.time_scale = 1.0
	var heaven_scene: PackedScene = StartupPreloader.get_preloaded_scene(CITY_SCENE_PATH)
	if heaven_scene != null:
		get_tree().change_scene_to_packed(heaven_scene)
	else:
		get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _begin_center_impact_physics() -> RigidBody3D:
	if _car == null or not is_instance_valid(_car):
		push_error("PORSCHE PHYSICS ERROR: the live Porsche root is unavailable at the first impact.")
		return null
	if _physical_wreck_body != null and is_instance_valid(_physical_wreck_body):
		return _physical_wreck_body

	var car_global_transform: Transform3D = _car.global_transform
	var forward_direction: Vector3 = -car_global_transform.basis.z
	forward_direction.y = 0.0
	if forward_direction.length_squared() <= 0.0001:
		forward_direction = Vector3(0.0, 0.0, -1.0)
	forward_direction = forward_direction.normalized()

	var body: RigidBody3D = RigidBody3D.new()
	body.name = "PhysicalPorscheWreck"
	body.mass = PHYSICAL_CAR_MASS
	body.freeze = false
	body.sleeping = false
	body.can_sleep = true
	body.gravity_scale = 1.0
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 32
	body.linear_damp = 0.04
	body.angular_damp = 0.08
	body.collision_layer = CAR_CRASH_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.0, 0.22, 0.08)
	body.add_to_group("physical_porsche_wreck")

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.92
	physics_material.bounce = 0.025
	body.physics_material_override = physics_material

	add_child(body)
	body.global_transform = car_global_transform
	_add_physical_porsche_collision(body)
	_car.reparent(body, true)
	_car.transform = Transform3D.IDENTITY
	_physical_wreck_body = body

	# No lateral velocity or target point is supplied. The concrete pieces, deck,
	# gravity, friction and subsequent contacts are the only sources of deviation.
	var initial_velocity: Vector3 = forward_direction * NATURAL_IMPACT_SPEED
	initial_velocity.y = -0.18
	_launch_physical_porsche_after_frame(body, initial_velocity, Vector3.ZERO)
	print(
		"PORSCHE NATURAL PHYSICS HANDOFF: first barrier impact owns the trajectory with velocity ",
		initial_velocity
	)
	return body


func _wait_for_natural_edge_contact(
	crash_set: Node3D,
	body: RigidBody3D,
	maximum_seconds: float
) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0

	var elapsed: float = 0.0
	var slow_duration: float = 0.0
	while elapsed < maximum_seconds:
		await get_tree().physics_frame
		if body == null or not is_instance_valid(body):
			return 0.0

		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		_update_physical_wreck_camera(body, delta)
		var local_position: Vector3 = crash_set.to_local(body.global_position)

		var reached_contact_line: bool = (
			absf(local_position.x) >= EDGE_RAIL_CONTACT_X
			and local_position.z >= RAIL_ZONE_MIN_Z
			and local_position.z <= RAIL_ZONE_MAX_Z
			and body.global_position.y > crash_set.global_position.y - 1.5
		)
		if reached_contact_line:
			var side: float = signf(local_position.x)
			print("PORSCHE NATURAL EDGE CONTACT: side ", side, " at ", local_position)
			return side

		if body.global_position.y < crash_set.global_position.y - 3.0:
			return 0.0
		if local_position.z < -41.0:
			return 0.0

		if body.linear_velocity.length() < 0.85 and body.angular_velocity.length() < 0.65:
			slow_duration += delta
			if slow_duration >= 0.85:
				return 0.0
		else:
			slow_duration = 0.0
	return 0.0


func _trigger_natural_edge_physics(crash_set: Node3D, side: float) -> void:
	if side > 0.0:
		_trigger_rail_physics_now()
		_break_right_guardrail(crash_set)
		return

	var mesh_nodes: Array[Node] = crash_set.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)
	for node: Node in mesh_nodes:
		var rail: MeshInstance3D = node as MeshInstance3D
		if rail == null:
			continue
		if bool(rail.get_meta("crash_rail", false)) and rail.position.x < 0.0:
			rail.visible = false

	var edge_director: Node = get_node_or_null("BridgeFinalEdgeRailPhysics")
	if edge_director != null and edge_director.has_method("trigger_edge_for_side"):
		edge_director.call("trigger_edge_for_side", -1.0)


func _play_natural_edge_slow_motion(crash_set: Node3D, side: float) -> void:
	if side > 0.0:
		await _play_rail_impact_slow_motion(crash_set)
		return

	Engine.time_scale = RAIL_IMPACT_TIME_SCALE
	var target: Vector3 = crash_set.to_global(Vector3(-5.95, 0.78, -14.5))
	_place_close_crash_camera(target + Vector3(-2.9, 0.95, 2.55), target, 43.0)
	await _wait_real_time(0.48)
	_place_close_crash_camera(
		target + Vector3(2.75, 1.30, -1.45),
		target + Vector3(-0.5, 0.15, 0.0),
		39.0
	)
	await _wait_real_time(0.50)
	_place_close_crash_camera(target + Vector3(-1.0, 4.65, 3.0), target, 48.0)
	await _wait_real_time(0.44)
	Engine.time_scale = 1.0


func _begin_final_car_physics(
	_crash_set: Node3D,
	_rail_position: Vector3,
	rail_tween: Tween
) -> RigidBody3D:
	if rail_tween != null and rail_tween.is_valid():
		rail_tween.kill()
	return _physical_wreck_body
