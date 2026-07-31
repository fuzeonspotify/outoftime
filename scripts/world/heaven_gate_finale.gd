extends "res://scripts/world/heaven_descent.gd"

const GATE_SCARE_AUDIO_SCRIPT: Script = preload("res://scripts/audio/heaven_gate_jumpscare_audio.gd")
const QTE_SEQUENCE_LENGTH: int = 7
const QTE_STEP_SECONDS: float = 1.28
const MAX_QTE_CHANCES: int = 3

var _gate_scare_audio: Node
var _encounter_active: bool = false
var _qte_active: bool = false
var _purified: bool = false
var _purification_running: bool = false
var _attacker: Node3D
var _scare_camera_rig: Node3D
var _scare_camera: Camera3D
var _scare_camera_forward: Vector3 = Vector3.FORWARD
var _scare_trauma: float = 0.0
var _player_visual: Node3D
var _player_hud: CanvasLayer

var _qte_sequence: Array[int] = []
var _qte_index: int = 0
var _qte_chances: int = MAX_QTE_CHANCES
var _qte_time_remaining: float = QTE_STEP_SECONDS
var _golden_strength: float = 0.0

var _finale_canvas: CanvasLayer
var _finale_overlay: Control
var _blood_flash: ColorRect
var _gold_flash: ColorRect
var _blackout: ColorRect
var _scare_title: Label
var _scare_instruction: Label
var _chance_label: Label
var _timer_bar: ProgressBar
var _key_row: HBoxContainer
var _key_labels: Array[Label] = []


func _ready() -> void:
	super._ready()
	_gate_scare_audio = GATE_SCARE_AUDIO_SCRIPT.new() as Node
	add_child(_gate_scare_audio)
	_build_finale_ui()
	set_process_input(true)


func _exit_tree() -> void:
	if _gate_scare_audio != null and is_instance_valid(_gate_scare_audio):
		_gate_scare_audio.call("stop", 0.25)
	super._exit_tree()


func _process(delta: float) -> void:
	if _purified:
		_process_purified_heaven(delta)
	else:
		super._process(delta)

	if _encounter_active:
		_update_scare_camera(delta)
	if _qte_active:
		_qte_time_remaining -= delta
		_timer_bar.value = clampf(_qte_time_remaining / QTE_STEP_SECONDS, 0.0, 1.0) * 100.0
		if _qte_time_remaining <= 0.0:
			_fail_qte_attempt("TOO SLOW")


func _input(event: InputEvent) -> void:
	if not _qte_active:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var pressed_key: int = int(key_event.physical_keycode)
	if pressed_key not in [KEY_W, KEY_A, KEY_S, KEY_D]:
		return
	get_viewport().set_input_as_handled()
	if pressed_key == _qte_sequence[_qte_index]:
		_accept_qte_key()
	else:
		_fail_qte_attempt("WRONG MOVE")


func _on_gate_activated(player: Node) -> void:
	if _transition_started or _encounter_active:
		return
	if _purified:
		super._on_gate_activated(player)
		return
	_encounter_active = true
	_start_gate_encounter.call_deferred(player)


func _start_gate_encounter(player: Node) -> void:
	if player != _player or _player == null:
		_encounter_active = false
		return
	_player.velocity = Vector3.ZERO
	_player.call("set_cinematic_mode", true)
	_store_and_hide_player_presentation(false)
	_gate_scare_audio.call("play_gate_attempt")
	_audio.call("play_gate_open")
	SFXDirector.play_transition()
	_player.set_objective("The portal is opening...")
	var gate_tween: Tween = create_tween().set_parallel(true)
	gate_tween.tween_property(_gate_root, "scale", Vector3(1.08, 1.08, 1.08), 0.72).set_trans(Tween.TRANS_SINE)
	gate_tween.tween_property(_gold_flash, "color:a", 0.30, 0.72).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.74).timeout

	_attacker = _select_attacker()
	if _attacker == null:
		await _complete_qte_success()
		return

	_build_first_person_camera()
	_store_and_hide_player_presentation(true)
	_scare_title.text = "SHE WAS WAITING FOR YOU TO OPEN IT"
	_scare_instruction.text = "DO NOT LOOK AWAY"
	_finale_overlay.visible = true
	_finale_overlay.modulate.a = 0.0
	var overlay_tween: Tween = create_tween()
	overlay_tween.tween_property(_finale_overlay, "modulate:a", 1.0, 0.16)

	var player_head: Vector3 = _player.global_position + Vector3.UP * 1.62
	var active_camera: Camera3D = get_viewport().get_camera_3d()
	if active_camera != null:
		_scare_camera_forward = -active_camera.global_transform.basis.z.normalized()
	if _scare_camera_forward.length_squared() < 0.5:
		_scare_camera_forward = Vector3.FORWARD
	var attacker_target: Vector3 = (
		_player.global_position
		+ _scare_camera_forward * 0.78
		+ Vector3.DOWN * 0.68
	)
	if _attacker.has_method("begin_finale_grab"):
		_attacker.call("begin_finale_grab", attacker_target, 0.92)

	_gate_scare_audio.call("play_grab")
	_audio.call("set_corruption", 1.0)
	_scare_trauma = 0.68
	_blood_flash.color.a = 0.62
	var blood_tween: Tween = create_tween()
	blood_tween.tween_property(_blood_flash, "color:a", 0.08, 0.65)

	var camera_tween: Tween = create_tween().set_parallel(true)
	camera_tween.tween_property(_scare_camera_rig, "global_position", player_head, 0.34).set_trans(Tween.TRANS_QUINT)
	camera_tween.tween_property(_scare_camera, "fov", 76.0, 0.34).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(0.36).timeout
	var face_position: Vector3 = _get_attacker_face_position()
	var close_position: Vector3 = face_position - _scare_camera_forward * 0.24
	var pull_tween: Tween = create_tween().set_parallel(true)
	pull_tween.tween_property(_scare_camera_rig, "global_position", close_position, 0.66).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	pull_tween.tween_property(_scare_camera, "fov", 62.0, 0.66).set_trans(Tween.TRANS_EXPO)
	await get_tree().create_timer(0.68).timeout
	_scare_trauma = 1.0
	_blood_flash.color.a = 0.48
	await get_tree().create_timer(0.28).timeout
	_begin_qte()


func _begin_qte() -> void:
	_qte_active = true
	_qte_chances = MAX_QTE_CHANCES
	_qte_index = 0
	_qte_time_remaining = QTE_STEP_SECONDS
	_scare_title.text = "BREAK HER GRIP"
	_scare_instruction.text = "PRESS THE SEQUENCE — THREE CHANCES"
	_generate_qte_sequence()
	_update_qte_display()


func _generate_qte_sequence() -> void:
	_qte_sequence.clear()
	var choices: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D]
	var previous_key: int = 0
	for _sequence_index: int in range(QTE_SEQUENCE_LENGTH):
		var next_key: int = choices[_rng.randi_range(0, choices.size() - 1)]
		while next_key == previous_key:
			next_key = choices[_rng.randi_range(0, choices.size() - 1)]
		_qte_sequence.append(next_key)
		previous_key = next_key


func _accept_qte_key() -> void:
	_gate_scare_audio.call("play_correct", _qte_index)
	_scare_trauma = minf(1.0, _scare_trauma + 0.12)
	_qte_index += 1
	_qte_time_remaining = QTE_STEP_SECONDS
	if _qte_index >= _qte_sequence.size():
		_qte_active = false
		_complete_qte_success.call_deferred()
		return
	_update_qte_display()


func _fail_qte_attempt(reason: String) -> void:
	if not _qte_active:
		return
	_qte_chances -= 1
	_gate_scare_audio.call("play_wrong", _qte_chances)
	_scare_trauma = 1.0
	_blood_flash.color.a = 0.72
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_blood_flash, "color:a", 0.12, 0.42)
	if _qte_chances <= 0:
		_qte_active = false
		_play_qte_death.call_deferred(reason)
		return
	_scare_instruction.text = "%s — TRY AGAIN" % reason
	_qte_index = 0
	_qte_time_remaining = QTE_STEP_SECONDS
	_generate_qte_sequence()
	_update_qte_display()


func _complete_qte_success() -> void:
	if _purification_running:
		return
	_purification_running = true
	_qte_active = false
	_purified = true
	_gate_scare_audio.call("play_success")
	_audio.call("play_threshold", false)
	_scare_title.text = "YOU REMEMBERED THE WAY OUT"
	_scare_instruction.text = "THE FALSE HEAVEN RELEASES YOU"
	for angel: Node3D in _angels:
		if is_instance_valid(angel) and angel.has_method("set_purified"):
			angel.call("set_purified", true)
	if _attacker != null and is_instance_valid(_attacker) and _attacker.has_method("finish_finale_grab"):
		_attacker.call("finish_finale_grab", true)

	var gold_tween: Tween = create_tween().set_parallel(true)
	gold_tween.tween_property(self, "_golden_strength", 1.0, 2.4).set_trans(Tween.TRANS_QUINT)
	gold_tween.tween_property(_gold_flash, "color:a", 0.92, 0.34).set_trans(Tween.TRANS_SINE)
	gold_tween.tween_property(_blood_flash, "color:a", 0.0, 0.40)
	await get_tree().create_timer(0.42).timeout
	var gold_release: Tween = create_tween()
	gold_release.tween_property(_gold_flash, "color:a", 0.10, 1.8).set_trans(Tween.TRANS_SINE)

	var player_head: Vector3 = _player.global_position + Vector3.UP * 1.62
	var return_tween: Tween = create_tween().set_parallel(true)
	return_tween.tween_property(_scare_camera_rig, "global_position", player_head, 1.15).set_trans(Tween.TRANS_QUINT)
	return_tween.tween_property(_scare_camera, "fov", 72.0, 1.15).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(1.18).timeout
	_restore_player_camera_and_presentation()
	_rearm_purified_gate()
	_player.call("set_cinematic_mode", false)
	_player.set_objective("Heaven is purified. Open the golden portal.")
	_player.show_interaction_message(
		"The angels lower their heads. The gate finally belongs to you.",
		5.2,
		"PURIFICATION"
	)
	var overlay_hide: Tween = create_tween()
	overlay_hide.tween_property(_finale_overlay, "modulate:a", 0.0, 0.65)
	await overlay_hide.finished
	_finale_overlay.visible = false
	_encounter_active = false
	_purification_running = false


func _play_qte_death(reason: String) -> void:
	_gate_scare_audio.call("play_death")
	_scare_title.text = "SHE KEPT YOU"
	_scare_instruction.text = "%s — THE MEMORY CLOSES" % reason
	if _attacker != null and is_instance_valid(_attacker) and _attacker.has_method("finish_finale_grab"):
		_attacker.call("finish_finale_grab", false)
	_scare_trauma = 1.0
	var death_tween: Tween = create_tween().set_parallel(true)
	death_tween.tween_property(_blood_flash, "color:a", 0.92, 0.16)
	death_tween.tween_property(_scare_camera, "fov", 104.0, 0.48).set_trans(Tween.TRANS_EXPO)
	await get_tree().create_timer(0.52).timeout
	var blackout_tween: Tween = create_tween()
	blackout_tween.tween_property(_blackout, "color:a", 1.0, 0.65)
	await blackout_tween.finished
	_gate_scare_audio.call("stop", 0.1)
	get_tree().reload_current_scene()


func _process_purified_heaven(delta: float) -> void:
	_elapsed += delta
	if _player == null or not is_instance_valid(_player):
		return
	if _player.position.y < FALL_LIMIT:
		_player.position = PLAYER_START
		_player.velocity = Vector3.ZERO
	_corruption = move_toward(_corruption, 0.0, delta * 0.72)
	_update_environment_state()
	_update_angels(delta)
	_update_motes(delta)
	_audio.call("set_corruption", 0.0)
	_update_hud()
	_set_gate_enabled(true)

	var gold: float = smoothstep(0.0, 1.0, _golden_strength)
	_environment.background_color = _environment.background_color.lerp(Color("fff7d6"), gold)
	_environment.ambient_light_color = _environment.ambient_light_color.lerp(Color("ffe7a1"), gold)
	_environment.ambient_light_energy = lerpf(_environment.ambient_light_energy, 1.52, gold)
	_environment.fog_light_color = _environment.fog_light_color.lerp(Color("ffecc2"), gold)
	_environment.fog_density = lerpf(_environment.fog_density, 0.0025, gold)
	_environment.glow_intensity = lerpf(_environment.glow_intensity, 1.34, gold)
	_environment.adjustment_saturation = lerpf(_environment.adjustment_saturation, 1.18, gold)
	_sun_light.light_color = _sun_light.light_color.lerp(Color("ffd66b"), gold)
	_sun_light.light_energy = lerpf(_sun_light.light_energy, 1.78, gold)
	_fill_light.light_color = _fill_light.light_color.lerp(Color("fff1c7"), gold)
	_fill_light.light_energy = lerpf(_fill_light.light_energy, 0.94, gold)
	_gate_root.scale = Vector3.ONE * (1.0 + sin(_elapsed * 1.7) * 0.018 * gold)
	_state_label.text = "HEAVEN SIGNAL  //  PURIFIED"
	_state_label.add_theme_color_override("font_color", Color("ffe17a"))
	_sanctity_label.text = "SANCTITY  100%"
	_sanctity_bar.value = 100.0


func _select_attacker() -> Node3D:
	var selected: Node3D
	var closest_distance_squared: float = INF
	for angel: Node3D in _angels:
		if not is_instance_valid(angel):
			continue
		var distance_squared: float = angel.global_position.distance_squared_to(_player.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			selected = angel
	return selected


func _build_first_person_camera() -> void:
	var active_camera: Camera3D = get_viewport().get_camera_3d()
	_scare_camera_rig = Node3D.new()
	_scare_camera_rig.name = "JumpscareFirstPersonRig"
	add_child(_scare_camera_rig)
	if active_camera != null:
		_scare_camera_rig.global_transform = active_camera.global_transform
	_scare_camera = Camera3D.new()
	_scare_camera.name = "JumpscareCamera"
	_scare_camera.fov = active_camera.fov if active_camera != null else 68.0
	_scare_camera.current = true
	_scare_camera_rig.add_child(_scare_camera)


func _update_scare_camera(delta: float) -> void:
	if _scare_camera_rig == null or _scare_camera == null:
		return
	if _attacker != null and is_instance_valid(_attacker):
		var face_position: Vector3 = _get_attacker_face_position()
		if _scare_camera_rig.global_position.distance_squared_to(face_position) > 0.001:
			_scare_camera_rig.look_at(face_position, Vector3.UP)
	_scare_trauma = maxf(0.0, _scare_trauma - delta * 0.42)
	var strength: float = _scare_trauma * _scare_trauma
	_scare_camera.position = Vector3(
		_rng.randf_range(-0.025, 0.025) * strength,
		_rng.randf_range(-0.022, 0.022) * strength,
		_rng.randf_range(-0.018, 0.018) * strength
	)
	_scare_camera.rotation_degrees = Vector3(
		_rng.randf_range(-1.4, 1.4) * strength,
		_rng.randf_range(-1.8, 1.8) * strength,
		_rng.randf_range(-2.2, 2.2) * strength
	)


func _get_attacker_face_position() -> Vector3:
	if _attacker != null and is_instance_valid(_attacker) and _attacker.has_method("get_face_position"):
		var face_variant: Variant = _attacker.call("get_face_position")
		if face_variant is Vector3:
			return face_variant
	return _attacker.global_position + Vector3.UP * 2.25 if _attacker != null else _player.global_position + Vector3.UP * 1.65


func _store_and_hide_player_presentation(hide_visual: bool) -> void:
	if _player_visual == null:
		_player_visual = _player.get_node_or_null("SkeletonVisual") as Node3D
	if _player_hud == null:
		_player_hud = _player.get_node_or_null("PlayerHUD") as CanvasLayer
	if hide_visual and _player_visual != null:
		_player_visual.visible = false
	if _player_hud != null:
		_player_hud.visible = false


func _restore_player_camera_and_presentation() -> void:
	if _player_visual != null:
		_player_visual.visible = true
	if _player_hud != null:
		_player_hud.visible = true
	var normal_camera: Camera3D = _player.get_node_or_null("CameraYaw/CameraPitch/SpringArm3D/Camera3D") as Camera3D
	if normal_camera != null:
		normal_camera.current = true
	if _scare_camera_rig != null:
		_scare_camera_rig.queue_free()
	_scare_camera_rig = null
	_scare_camera = null


func _rearm_purified_gate() -> void:
	_gate_interaction.set("_used", false)
	_gate_interaction.set("prompt_text", "Open the golden portal")
	_gate_interaction.set("interaction_title", "PURIFIED GATE")
	_gate_interaction.set("interaction_context", "HOLD TO OPEN")
	_gate_interaction.set("hold_duration", 0.85)
	_gate_interaction.set("marker_color", Color("ffd85e"))
	_gate_interaction.monitoring = true
	_gate_interaction.monitorable = true
	_gate_interaction.collision_layer = 2
	_gate_interaction.call("refresh_release_presentation")


func _update_qte_display() -> void:
	_chance_label.text = "CHANCES  %d / %d" % [_qte_chances, MAX_QTE_CHANCES]
	for index: int in range(_key_labels.size()):
		var label: Label = _key_labels[index]
		label.text = _key_name(_qte_sequence[index])
		if index < _qte_index:
			label.modulate = Color("70ffad")
		elif index == _qte_index:
			label.modulate = Color("ffffff")
			label.scale = Vector2(1.18, 1.18)
		else:
			label.modulate = Color("8d748e")
			label.scale = Vector2.ONE


func _key_name(keycode: int) -> String:
	match keycode:
		KEY_W:
			return "W"
		KEY_A:
			return "A"
		KEY_S:
			return "S"
		KEY_D:
			return "D"
	return "?"


func _build_finale_ui() -> void:
	_finale_canvas = CanvasLayer.new()
	_finale_canvas.name = "HeavenGateFinaleUI"
	_finale_canvas.layer = 145
	add_child(_finale_canvas)
	_finale_overlay = Control.new()
	_finale_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finale_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_overlay.visible = false
	_finale_canvas.add_child(_finale_overlay)

	var top_shadow: ColorRect = ColorRect.new()
	top_shadow.anchor_right = 1.0
	top_shadow.offset_bottom = 110.0
	top_shadow.color = Color(0.0, 0.0, 0.0, 0.82)
	_finale_overlay.add_child(top_shadow)
	var bottom_shadow: ColorRect = ColorRect.new()
	bottom_shadow.anchor_top = 1.0
	bottom_shadow.anchor_right = 1.0
	bottom_shadow.anchor_bottom = 1.0
	bottom_shadow.offset_top = -185.0
	bottom_shadow.color = Color(0.0, 0.0, 0.0, 0.88)
	_finale_overlay.add_child(bottom_shadow)

	_blood_flash = ColorRect.new()
	_blood_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blood_flash.color = Color(0.68, 0.0, 0.12, 0.0)
	_blood_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_overlay.add_child(_blood_flash)
	_gold_flash = ColorRect.new()
	_gold_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gold_flash.color = Color(1.0, 0.82, 0.32, 0.0)
	_gold_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_overlay.add_child(_gold_flash)
	_blackout = ColorRect.new()
	_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blackout.color = Color(0.0, 0.0, 0.0, 0.0)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finale_overlay.add_child(_blackout)

	_scare_title = Label.new()
	_scare_title.anchor_left = 0.12
	_scare_title.anchor_right = 0.88
	_scare_title.offset_top = 34.0
	_scare_title.offset_bottom = 86.0
	_scare_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scare_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scare_title.add_theme_font_size_override("font_size", 25)
	_scare_title.add_theme_color_override("font_color", Color("fff1f5"))
	_scare_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	_scare_title.add_theme_constant_override("outline_size", 7)
	_finale_overlay.add_child(_scare_title)

	var qte_center: CenterContainer = CenterContainer.new()
	qte_center.anchor_left = 0.0
	qte_center.anchor_top = 1.0
	qte_center.anchor_right = 1.0
	qte_center.anchor_bottom = 1.0
	qte_center.offset_top = -174.0
	qte_center.offset_bottom = -18.0
	_finale_overlay.add_child(qte_center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 9)
	qte_center.add_child(stack)
	_scare_instruction = Label.new()
	_scare_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scare_instruction.add_theme_font_size_override("font_size", 14)
	_scare_instruction.add_theme_color_override("font_color", Color("ffb7c6"))
	stack.add_child(_scare_instruction)
	_key_row = HBoxContainer.new()
	_key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_key_row.add_theme_constant_override("separation", 11)
	stack.add_child(_key_row)
	for _index: int in range(QTE_SEQUENCE_LENGTH):
		var key_label: Label = Label.new()
		key_label.custom_minimum_size = Vector2(52.0, 52.0)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 28)
		key_label.add_theme_color_override("font_color", Color.WHITE)
		key_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		key_label.add_theme_constant_override("outline_size", 7)
		_key_row.add_child(key_label)
		_key_labels.append(key_label)
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(440.0, 9.0)
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	_timer_bar.show_percentage = false
	stack.add_child(_timer_bar)
	_chance_label = Label.new()
	_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chance_label.add_theme_font_size_override("font_size", 13)
	_chance_label.add_theme_color_override("font_color", Color("ff6f8d"))
	stack.add_child(_chance_label)
