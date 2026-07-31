extends "res://scripts/world/road_memory.gd"

const CRASH_AUDIO_SCRIPT: Script = preload("res://scripts/audio/bridge_crash_audio.gd")
const CAR_TARGET_LENGTH: float = 4.9

var _crash_audio: Node
var _crash_active: bool = false
var _crash_trauma: float = 0.0
var _crash_rig: Node3D
var _crash_camera: Camera3D
var _crash_flash: ColorRect
var _crash_whiteout: ColorRect
var _crash_caption: Label
var _real_car_visual: Node3D


func _ready() -> void:
	super._ready()
	_crash_audio = CRASH_AUDIO_SCRIPT.new() as Node
	add_child(_crash_audio)
	_build_crash_overlay()


func _process(delta: float) -> void:
	super._process(delta)
	if _crash_active:
		_update_crash_camera(delta)


func _build_car() -> void:
	var prototype: Node3D = StartupPreloader.get_car_prototype()
	if prototype == null:
		super._build_car()
		return

	_car = Node3D.new()
	_car.name = "SpectralPontiac"
	_car.position = Vector3(0.0, 0.04, 8.0)
	add_child(_car)

	_real_car_visual = prototype.duplicate() as Node3D
	if _real_car_visual == null:
		_car.queue_free()
		_car = null
		super._build_car()
		return
	_real_car_visual.name = "KenneyCC0Car"
	_car.add_child(_real_car_visual)
	_normalize_car_model(_real_car_visual)
	_tint_car_model(_real_car_visual)
	_add_car_lighting()
	_add_car_camera()


func _normalize_car_model(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)

	if not has_bounds:
		model_root.scale = Vector3.ONE
		return
	var horizontal_length: float = maxf(bounds.size.x, bounds.size.z)
	if horizontal_length <= 0.001:
		return
	var scale_factor: float = CAR_TARGET_LENGTH / horizontal_length
	model_root.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	model_root.position = Vector3(
		-center.x * scale_factor,
		-bounds.position.y * scale_factor + 0.02,
		-center.z * scale_factor
	)


func _tint_car_model(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var standard_material: StandardMaterial3D = source_material as StandardMaterial3D
			if standard_material == null:
				continue
			var tinted_material: StandardMaterial3D = standard_material.duplicate() as StandardMaterial3D
			if tinted_material == null:
				continue
			if tinted_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				tinted_material.albedo_color = tinted_material.albedo_color.lerp(Color("9d1f58"), 0.32)
				tinted_material.metallic = maxf(tinted_material.metallic, 0.18)
				tinted_material.roughness = minf(tinted_material.roughness, 0.46)
			mesh_instance.set_surface_override_material(surface_index, tinted_material)


func _add_car_lighting() -> void:
	for head_x: float in [-0.72, 0.72]:
		var head_light: OmniLight3D = OmniLight3D.new()
		head_light.position = Vector3(head_x, 0.58, -2.30)
		head_light.light_color = Color("ffe7ff")
		head_light.light_energy = 2.7
		head_light.omni_range = 8.5
		_car.add_child(head_light)
	for tail_x: float in [-0.72, 0.72]:
		var tail_light: OmniLight3D = OmniLight3D.new()
		tail_light.position = Vector3(tail_x, 0.58, 2.20)
		tail_light.light_color = Color("ff256f")
		tail_light.light_energy = 2.4
		tail_light.omni_range = 5.0
		_car.add_child(tail_light)


func _add_car_camera() -> void:
	_car_camera = Camera3D.new()
	_car_camera.name = "PontiacCamera"
	_camera_distance = 8.8
	_camera_target_distance = 8.8
	_car_camera.position = Vector3(0.0, 3.8, _camera_distance)
	_car_camera.rotation_degrees = Vector3(-13.5, 0.0, 0.0)
	_car_camera.fov = 68.0
	_car_camera.current = true
	_car.add_child(_car_camera)


func _show_memory_end(failed: bool = false) -> void:
	if _sequence_finished:
		return
	_sequence_finished = true
	_crash_active = true
	_play_crash_sequence.call_deferred(failed)


func _play_crash_sequence(failed: bool) -> void:
	MusicDirector.stop_music(6.5)
	SFXDirector.stop_environment(3.0)
	_distance_label.text = "BRIDGE SIGNAL  LOST"
	_integrity_label.text = "MEMORY INTEGRITY  CRITICAL"
	_message_label.visible = true
	_message_label.text = "The bridge remembers the crash before you do." if not failed else "The failed memory chooses the same ending."
	_build_crash_camera()
	var crash_set: Node3D = _build_crash_set()
	_set_cinematic_bars(88.0)
	_set_crash_caption("THE ROAD WAS NEVER LEADING OUT")
	_crash_audio.call("play_heartbeat")

	await get_tree().create_timer(0.65).timeout
	_crash_audio.call("play_tire_screech")
	var approach_position: Vector3 = _car.position + Vector3(2.6, 0.0, -24.0)
	var approach_tween: Tween = create_tween().set_parallel(true)
	approach_tween.tween_property(_car, "position", approach_position, 1.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	approach_tween.tween_property(_car, "rotation_degrees:z", -9.0, 0.75).set_trans(Tween.TRANS_QUAD)
	approach_tween.tween_property(_crash_rig, "global_position", approach_position + Vector3(-8.5, 2.4, 7.0), 1.0).set_trans(Tween.TRANS_QUINT)
	approach_tween.tween_property(_crash_rig, "rotation_degrees", Vector3(-7.0, -68.0, 0.0), 1.0).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(1.05).timeout

	_crash_audio.call("play_guardrail_hit", 1.0)
	_add_crash_shake(0.72)
	_flash_crash(Color(1.0, 0.22, 0.48, 0.52), 0.34)
	_break_guardrail(crash_set)
	var rail_position: Vector3 = approach_position + Vector3(2.7, 0.32, -12.0)
	var rail_tween: Tween = create_tween().set_parallel(true)
	rail_tween.tween_property(_car, "position", rail_position, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	rail_tween.tween_property(_car, "rotation_degrees", Vector3(4.0, -24.0, -22.0), 0.72)
	rail_tween.tween_property(_crash_rig, "global_position", rail_position + Vector3(7.2, 3.0, 5.5), 0.55)
	rail_tween.tween_property(_crash_rig, "rotation_degrees", Vector3(-12.0, 48.0, 0.0), 0.55)
	await get_tree().create_timer(0.70).timeout

	_crash_audio.call("play_glass_burst")
	_crash_audio.call("play_major_impact")
	_add_crash_shake(1.0)
	_flash_crash(Color(1.0, 0.78, 0.92, 0.86), 0.55)
	_set_crash_caption("YOU HAVE DONE THIS BEFORE")
	var fall_position: Vector3 = rail_position + Vector3(3.8, -15.0, -24.0)
	var fall_tween: Tween = create_tween().set_parallel(true)
	fall_tween.tween_property(_car, "position", fall_position, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(_car, "rotation_degrees", Vector3(118.0, 176.0, 146.0), 2.2).set_trans(Tween.TRANS_QUAD)
	fall_tween.tween_property(_crash_rig, "global_position", rail_position + Vector3(-1.0, 11.0, 8.0), 1.3).set_trans(Tween.TRANS_QUINT)
	fall_tween.tween_property(_crash_rig, "rotation_degrees", Vector3(-54.0, 8.0, 0.0), 1.3).set_trans(Tween.TRANS_QUINT)
	fall_tween.tween_property(_crash_camera, "fov", 84.0, 1.7)
	_crash_audio.call("start_tinnitus")
	await get_tree().create_timer(1.55).timeout

	_crash_audio.call("play_heartbeat")
	var whiteout_tween: Tween = create_tween()
	whiteout_tween.tween_property(_crash_whiteout, "color:a", 1.0, 1.55).set_trans(Tween.TRANS_SINE)
	await whiteout_tween.finished
	_crash_audio.call("stop_all", 1.0)
	await get_tree().create_timer(0.35).timeout
	var heaven_scene: PackedScene = StartupPreloader.get_preloaded_scene(CITY_SCENE_PATH)
	if heaven_scene != null:
		get_tree().change_scene_to_packed(heaven_scene)
	else:
		get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _build_crash_camera() -> void:
	_crash_rig = Node3D.new()
	_crash_rig.name = "BridgeCrashCameraRig"
	add_child(_crash_rig)
	_crash_rig.global_transform = _car_camera.global_transform
	_crash_camera = Camera3D.new()
	_crash_camera.name = "BridgeCrashCamera"
	_crash_camera.fov = _car_camera.fov
	_crash_camera.current = true
	_crash_rig.add_child(_crash_camera)


func _build_crash_set() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BridgeCrashSet"
	root.position = _car.position + Vector3(0.0, 0.0, -35.0)
	add_child(root)
	_add_box(root, Vector3(0.0, -0.02, 0.0), Vector3(12.0, 0.16, 18.0), Color("161321"))
	_add_box(root, Vector3(0.0, -0.12, -12.0), Vector3(12.0, 0.10, 8.0), Color("010003"))
	for side: float in [-1.0, 1.0]:
		var rail: MeshInstance3D = _add_box(
			root,
			Vector3(side * 5.8, 0.75, -1.0),
			Vector3(0.20, 1.5, 18.0),
			Color("54617d")
		)
		rail.set_meta("crash_rail", true)
	for warning_index: int in range(5):
		var warning_x: float = -4.0 + float(warning_index) * 2.0
		_add_box(
			root,
			Vector3(warning_x, 0.55, -4.5),
			Vector3(1.25, 1.0, 0.32),
			Color("f24a86"),
			Color("ff276d")
		)
	return root


func _break_guardrail(crash_set: Node3D) -> void:
	var mesh_nodes: Array[Node] = crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var rail: MeshInstance3D = node as MeshInstance3D
		if rail == null or not bool(rail.get_meta("crash_rail", false)):
			continue
		if rail.position.x < 0.0:
			continue
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(rail, "rotation_degrees:z", -74.0, 0.65).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(rail, "position", rail.position + Vector3(3.0, -2.5, 2.0), 0.85).set_trans(Tween.TRANS_QUAD)


func _build_crash_overlay() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "BridgeCrashOverlay"
	canvas.layer = 130
	add_child(canvas)
	_crash_flash = ColorRect.new()
	_crash_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crash_flash.color = Color(0.0, 0.0, 0.0, 0.0)
	_crash_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_crash_flash)
	_crash_caption = Label.new()
	_crash_caption.anchor_left = 0.12
	_crash_caption.anchor_right = 0.88
	_crash_caption.anchor_top = 0.47
	_crash_caption.anchor_bottom = 0.56
	_crash_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crash_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crash_caption.add_theme_font_size_override("font_size", 28)
	_crash_caption.add_theme_color_override("font_color", Color("fff1fa"))
	_crash_caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	_crash_caption.add_theme_constant_override("outline_size", 7)
	_crash_caption.modulate.a = 0.0
	canvas.add_child(_crash_caption)
	_crash_whiteout = ColorRect.new()
	_crash_whiteout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crash_whiteout.color = Color(1.0, 1.0, 1.0, 0.0)
	_crash_whiteout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_crash_whiteout)


func _set_crash_caption(text_value: String) -> void:
	_crash_caption.text = text_value
	_crash_caption.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_crash_caption, "modulate:a", 1.0, 0.24)
	tween.tween_interval(1.15)
	tween.tween_property(_crash_caption, "modulate:a", 0.0, 0.35)


func _flash_crash(color: Color, duration: float) -> void:
	_crash_flash.color = color
	var tween: Tween = create_tween()
	tween.tween_property(_crash_flash, "color:a", 0.0, duration)


func _set_cinematic_bars(height: float) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_cinematic_bar_top, "offset_bottom", height, 0.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cinematic_bar_bottom, "offset_top", -height, 0.42).set_trans(Tween.TRANS_SINE)


func _add_crash_shake(amount: float) -> void:
	_crash_trauma = clampf(_crash_trauma + amount, 0.0, 1.0)


func _update_crash_camera(delta: float) -> void:
	if _crash_camera == null:
		return
	_crash_trauma = maxf(0.0, _crash_trauma - delta * 0.82)
	var strength: float = _crash_trauma * _crash_trauma
	_crash_camera.position = Vector3(
		_rng.randf_range(-0.34, 0.34) * strength,
		_rng.randf_range(-0.26, 0.26) * strength,
		_rng.randf_range(-0.20, 0.20) * strength
	)
	_crash_camera.rotation_degrees = Vector3(
		_rng.randf_range(-2.2, 2.2) * strength,
		_rng.randf_range(-2.8, 2.8) * strength,
		_rng.randf_range(-3.8, 3.8) * strength
	)
