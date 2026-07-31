extends "res://scripts/world/road_memory_realistic_release.gd"

const CRASH_SET_DISTANCE: float = 52.0
const APPROACH_SECONDS: float = 3.55
const CENTER_IMPACT_SECONDS: float = 1.15
const RAIL_SLIDE_SECONDS: float = 2.35
const FALL_SECONDS: float = 4.15


func _tint_car_model(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var node_descriptor: String = str(mesh_instance.get_path()).to_lower()
		if _is_branding_descriptor(node_descriptor):
			mesh_instance.visible = false
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			if source_material == null:
				continue
			var material_descriptor: String = str(source_material.resource_name).to_lower()
			if _is_branding_descriptor(material_descriptor):
				var hidden_material: StandardMaterial3D = StandardMaterial3D.new()
				hidden_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
				hidden_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.set_surface_override_material(surface_index, hidden_material)
				continue
			var standard_material: StandardMaterial3D = source_material as StandardMaterial3D
			if standard_material == null:
				continue
			var preserved_material: StandardMaterial3D = standard_material.duplicate() as StandardMaterial3D
			if preserved_material == null:
				continue
			var paint_surface: bool = (
				material_descriptor.contains("paint")
				or material_descriptor.contains("panel")
				or material_descriptor.contains("body")
			)
			if paint_surface and preserved_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				preserved_material.albedo_color = preserved_material.albedo_color.lerp(Color("42182b"), 0.12)
				preserved_material.metallic = maxf(preserved_material.metallic, 0.32)
				preserved_material.roughness = minf(preserved_material.roughness, 0.32)
			mesh_instance.set_surface_override_material(surface_index, preserved_material)


func _play_crash_sequence(failed: bool) -> void:
	MusicDirector.stop_music(8.5)
	SFXDirector.stop_environment(4.0)
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
	_set_cinematic_bars(88.0)
	_set_crash_caption("THE ROAD WAS NEVER LEADING OUT")
	_crash_audio.call("play_heartbeat")

	var start_y: float = _car.position.y
	var impact_position: Vector3 = Vector3(0.0, start_y + 0.14, _car.position.z - CRASH_SET_DISTANCE)
	var approach_position: Vector3 = impact_position + Vector3(0.0, -0.14, 9.5)

	await get_tree().create_timer(1.35).timeout
	_crash_audio.call("play_tire_screech")
	_crash_rig.global_position = _car.global_position + Vector3(-9.8, 3.15, 10.8)
	_crash_rig.look_at(_car.global_position + Vector3(0.0, 0.8, -7.0), Vector3.UP)
	var approach_tween: Tween = create_tween().set_parallel(true)
	approach_tween.tween_property(
		_car,
		"position",
		approach_position,
		APPROACH_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	approach_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(0.0, 0.0, -4.0),
		APPROACH_SECONDS * 0.70
	).set_trans(Tween.TRANS_SINE)
	approach_tween.tween_property(
		_crash_rig,
		"global_position",
		Vector3(-10.5, 3.8, impact_position.z + 5.0),
		APPROACH_SECONDS
	).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(APPROACH_SECONDS).timeout

	_set_crash_caption("THERE IS NOWHERE LEFT TO STEER")
	var impact_tween: Tween = create_tween().set_parallel(true)
	impact_tween.tween_property(
		_car,
		"position",
		impact_position,
		CENTER_IMPACT_SECONDS
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	impact_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(-5.0, 0.0, 2.0),
		CENTER_IMPACT_SECONDS
	).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(CENTER_IMPACT_SECONDS).timeout

	_crash_audio.call("play_major_impact")
	_crash_audio.call("play_glass_burst")
	_add_crash_shake(1.0)
	_flash_crash(Color(1.0, 0.42, 0.60, 0.78), 0.70)
	_break_guardrail(crash_set)
	await get_tree().create_timer(0.72).timeout

	_crash_audio.call("play_guardrail_hit", 0.92)
	_set_crash_caption("THE BRIDGE OPENS BENEATH YOU")
	var rail_position: Vector3 = impact_position + Vector3(5.45, 0.46, -10.5)
	_crash_rig.global_position = impact_position + Vector3(10.0, 3.6, 8.5)
	_crash_rig.look_at(impact_position + Vector3(2.4, 0.7, -5.0), Vector3.UP)
	var rail_tween: Tween = create_tween().set_parallel(true)
	rail_tween.tween_property(
		_car,
		"position",
		rail_position,
		RAIL_SLIDE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	rail_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(12.0, -35.0, -31.0),
		RAIL_SLIDE_SECONDS
	).set_trans(Tween.TRANS_QUAD)
	rail_tween.tween_property(
		_crash_rig,
		"global_position",
		rail_position + Vector3(8.5, 4.0, 6.5),
		RAIL_SLIDE_SECONDS
	).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(RAIL_SLIDE_SECONDS).timeout

	_crash_audio.call("play_major_impact")
	_add_crash_shake(0.95)
	_flash_crash(Color(1.0, 0.80, 0.92, 0.68), 0.72)
	await get_tree().create_timer(0.58).timeout

	_set_crash_caption("YOU HAVE DONE THIS BEFORE")
	var fall_position: Vector3 = rail_position + Vector3(9.0, -24.0, -34.0)
	var fall_tween: Tween = create_tween().set_parallel(true)
	fall_tween.tween_property(
		_car,
		"position",
		fall_position,
		FALL_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(
		_car,
		"rotation_degrees",
		Vector3(222.0, 318.0, 246.0),
		FALL_SECONDS
	).set_trans(Tween.TRANS_QUAD)
	fall_tween.tween_property(
		_crash_rig,
		"global_position",
		rail_position + Vector3(-3.0, 15.5, 13.0),
		FALL_SECONDS * 0.72
	).set_trans(Tween.TRANS_QUINT)
	fall_tween.tween_property(_crash_camera, "fov", 88.0, FALL_SECONDS * 0.80)
	_crash_audio.call("start_tinnitus")
	await get_tree().create_timer(FALL_SECONDS).timeout

	_crash_audio.call("play_heartbeat")
	await get_tree().create_timer(0.55).timeout
	var whiteout_tween: Tween = create_tween()
	whiteout_tween.tween_property(_crash_whiteout, "color:a", 1.0, 2.25).set_trans(Tween.TRANS_SINE)
	await whiteout_tween.finished
	_crash_audio.call("stop_all", 1.4)
	await get_tree().create_timer(0.55).timeout
	var heaven_scene: PackedScene = StartupPreloader.get_preloaded_scene(CITY_SCENE_PATH)
	if heaven_scene != null:
		get_tree().change_scene_to_packed(heaven_scene)
	else:
		get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _build_crash_set() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BridgeCrashSet"
	root.position = Vector3(0.0, 0.0, _car.position.z - CRASH_SET_DISTANCE)
	add_child(root)

	_add_box(root, Vector3(0.0, -0.03, -9.0), Vector3(14.0, 0.18, 40.0), Color("161321"))
	_add_box(root, Vector3(0.0, -0.15, -31.0), Vector3(14.0, 0.10, 7.0), Color("010003"))

	for side: float in [-1.0, 1.0]:
		var rail: MeshInstance3D = _add_box(
			root,
			Vector3(side * 6.65, 0.78, -8.0),
			Vector3(0.22, 1.55, 38.0),
			Color("54617d")
		)
		rail.set_meta("crash_rail", true)

	for barrier_index: int in range(5):
		var barrier_x: float = -4.8 + float(barrier_index) * 2.4
		var barrier: MeshInstance3D = _add_box(
			root,
			Vector3(barrier_x, 0.62, 0.0),
			Vector3(2.25, 1.18, 0.85),
			Color("d8d1bd"),
			Color("ff315f")
		)
		barrier.name = "CenteredBarrier_%02d" % barrier_index
		barrier.set_meta("crash_barrier", true)

	for warning_index: int in range(6):
		var warning_x: float = -5.0 + float(warning_index) * 2.0
		var warning: MeshInstance3D = _add_box(
			root,
			Vector3(warning_x, 0.16, 4.0),
			Vector3(1.25, 0.16, 2.6),
			Color("f24a86"),
			Color("ff276d")
		)
		warning.rotation_degrees.y = 18.0 if warning_index % 2 == 0 else -18.0
	return root


func _break_guardrail(crash_set: Node3D) -> void:
	var mesh_nodes: Array[Node] = crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var piece: MeshInstance3D = node as MeshInstance3D
		if piece == null:
			continue
		if bool(piece.get_meta("crash_barrier", false)):
			var outward: float = signf(piece.position.x)
			if is_zero_approx(outward):
				outward = 1.0
			var barrier_tween: Tween = create_tween().set_parallel(true)
			barrier_tween.tween_property(
				piece,
				"position",
				piece.position + Vector3(outward * 3.4, 1.2, -2.4),
				1.05
			).set_trans(Tween.TRANS_QUAD)
			barrier_tween.tween_property(
				piece,
				"rotation_degrees",
				Vector3(58.0, outward * 42.0, outward * 76.0),
				1.05
			).set_trans(Tween.TRANS_QUAD)
			continue
		if not bool(piece.get_meta("crash_rail", false)) or piece.position.x < 0.0:
			continue
		var rail_tween: Tween = create_tween().set_parallel(true)
		rail_tween.tween_property(piece, "rotation_degrees:z", -78.0, 1.45).set_trans(Tween.TRANS_QUAD)
		rail_tween.tween_property(
			piece,
			"position",
			piece.position + Vector3(3.3, -2.8, -1.8),
			1.65
		).set_trans(Tween.TRANS_QUAD)
