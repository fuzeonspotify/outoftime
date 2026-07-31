extends Node3D

const TRAIN_AUDIO_SCRIPT: Script = preload("res://scripts/audio/memory_train_audio.gd")
const NIGHTCLUB_SCENE_PATH: String = "res://scenes/ruined_nightclub.tscn"

const STAGE_PASSENGER: int = 0
const STAGE_SWITCH: int = 1
const STAGE_ROOF: int = 2
const STAGE_ENGINE: int = 3
const STAGE_FINALE: int = 4

const RUNNER_GROUND_Y: float = 0.42
const RUNNER_Z: float = 2.0
const LANE_CHANGE_SPEED: float = 13.0
const JUMP_VELOCITY: float = 7.8
const JUMP_GRAVITY: float = 19.0
const POST_LAND_COOLDOWN: float = 0.18

const LANE_POSITIONS: Array[float] = [-2.35, 0.0, 2.35]
const STAGE_DURATIONS: Array[float] = [25.0, 16.0, 31.0, 25.0, 8.0]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _train_audio: Node
var _section_root: Node3D
var _obstacle_root: Node3D
var _scenery_root: Node3D
var _runner: Node3D
var _runner_visual: Node3D
var _camera_rig: Node3D
var _camera: Camera3D
var _world_environment: WorldEnvironment
var _train_shell: Node3D

var _stage: int = STAGE_PASSENGER
var _stage_time: float = 0.0
var _total_time: float = 0.0
var _train_speed: float = 17.0
var _spawn_timer: float = 1.5
var _gameplay_active: bool = false
var _transition_started: bool = false
var _lane_index: int = 1
var _target_lane_index: int = 1
var _vertical_velocity: float = 0.0
var _grounded: bool = true
var _land_cooldown: float = 0.0
var _integrity: int = 3
var _invulnerability: float = 0.0
var _shake_trauma: float = 0.0
var _camera_time: float = 0.0
var _cinematic_running: bool = false
var _route_choice: StringName = &""
var _choice_active: bool = false
var _choice_time: float = 0.0
var _choice_lane: int = 1
var _engine_gate_index: int = 0
var _required_lane: int = -1
var _required_lane_timer: float = 0.0
var _collision_event_played: bool = false
var _roof_event_played: bool = false
var _bridge_event_played: bool = false
var _section_scroll: float = 0.0

var _hud_canvas: CanvasLayer
var _stage_label: Label
var _objective_label: Label
var _speed_label: Label
var _integrity_label: Label
var _message_panel: PanelContainer
var _message_source: Label
var _message_body: Label
var _choice_panel: PanelContainer
var _choice_left: Label
var _choice_right: Label
var _choice_timer_label: Label
var _flash_rect: ColorRect
var _vignette: ColorRect
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _message_token: int = 0

var _obstacles: Array[Node3D] = []
var _scrolling_details: Array[Node3D] = []


func _ready() -> void:
	_rng.seed = 19980817
	_ensure_input_actions()
	_build_environment()
	_build_world()
	_build_runner()
	_build_camera()
	_build_hud()
	_train_audio = TRAIN_AUDIO_SCRIPT.new() as Node
	add_child(_train_audio)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_sequence.call_deferred()


func _process(delta: float) -> void:
	_camera_time += delta
	_update_camera_shake(delta)
	_update_scrolling_details(delta)
	_update_flash(delta)

	if not _gameplay_active or _transition_started:
		return

	_total_time += delta
	_stage_time += delta
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_land_cooldown = maxf(0.0, _land_cooldown - delta)
	_update_runner(delta)
	_update_obstacles(delta)
	_update_stage_logic(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_active or _transition_started:
		return

	if event.is_action_pressed("move_left"):
		_target_lane_index = maxi(0, _target_lane_index - 1)
		if _choice_active:
			_choice_lane = 0
			_refresh_choice_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_target_lane_index = mini(2, _target_lane_index + 1)
		if _choice_active:
			_choice_lane = 2
			_refresh_choice_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") and _grounded and _land_cooldown <= 0.0:
		_grounded = false
		_vertical_velocity = JUMP_VELOCITY
		SFXDirector.play_jump()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and _choice_active:
		_confirm_route_choice()
		get_viewport().set_input_as_handled()


func _start_sequence() -> void:
	MusicDirector.stop_music(1.5)
	SFXDirector.stop_environment(1.0)
	_train_audio.call("start")
	_set_section(STAGE_PASSENGER)
	_camera_rig.position = Vector3(-12.0, 4.8, 14.0)
	_camera_rig.rotation_degrees = Vector3(-10.0, -52.0, 0.0)
	_set_letterbox(true)
	_flash_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_train_audio.call("play_horn")
	_show_message("THE CONDUCTOR", "TICKET: ONE LIFE. DESTINATION: WHERE YOU LEFT HER.", 4.4)

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_flash_rect, "color:a", 0.0, 1.2)
	await fade_tween.finished

	var camera_tween: Tween = create_tween().set_parallel(true)
	camera_tween.tween_property(_camera_rig, "position", Vector3(0.0, 3.15, 10.2), 2.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_camera_rig, "rotation_degrees", Vector3(-7.0, 0.0, 0.0), 2.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	await camera_tween.finished
	_set_letterbox(false)
	_gameplay_active = true
	_show_message("MEMORY TRAIN", "A / D SHIFT CARSIDE  •  SPACE VAULT  •  SURVIVE TO THE ENGINE", 5.0)


func _update_runner(delta: float) -> void:
	_runner.position.x = move_toward(
		_runner.position.x,
		LANE_POSITIONS[_target_lane_index],
		LANE_CHANGE_SPEED * delta
	)
	_lane_index = _nearest_lane_index(_runner.position.x)

	if not _grounded:
		_vertical_velocity -= JUMP_GRAVITY * delta
		_runner.position.y += _vertical_velocity * delta
		if _runner.position.y <= RUNNER_GROUND_Y:
			_runner.position.y = RUNNER_GROUND_Y
			_vertical_velocity = 0.0
			_grounded = true
			_land_cooldown = POST_LAND_COOLDOWN
			SFXDirector.play_land()
			_add_shake(0.16)

	var stride: float = sin(_total_time * (8.0 + _train_speed * 0.18))
	_runner_visual.rotation_degrees.z = stride * 2.8
	_runner_visual.position.y = absf(stride) * 0.035


func _update_stage_logic(delta: float) -> void:
	var intensity: float = clampf((_total_time / 92.0) + 0.20, 0.0, 1.0)
	_train_audio.call("set_intensity", intensity)

	if _choice_active:
		_choice_time -= delta
		_choice_timer_label.text = "TRACK LOCK IN  %.1f" % maxf(0.0, _choice_time)
		if _choice_time <= 0.0:
			_confirm_route_choice()

	if _required_lane >= 0:
		_required_lane_timer -= delta
		if _required_lane_timer <= 0.0:
			_resolve_engine_gate()

	match _stage:
		STAGE_PASSENGER:
			_train_speed = lerpf(17.0, 21.0, clampf(_stage_time / STAGE_DURATIONS[STAGE_PASSENGER], 0.0, 1.0))
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_passenger_obstacle()
				_spawn_timer = _rng.randf_range(0.90, 1.45)
			if _stage_time >= 8.0 and not _collision_event_played:
				_collision_event_played = true
				_play_side_collision_cutscene()
		STAGE_SWITCH:
			_train_speed = 20.0
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_baggage_obstacle()
				_spawn_timer = _rng.randf_range(1.05, 1.55)
		STAGE_ROOF:
			_train_speed = lerpf(23.0, 29.0, clampf(_stage_time / STAGE_DURATIONS[STAGE_ROOF], 0.0, 1.0))
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_roof_obstacle()
				_spawn_timer = _rng.randf_range(0.76, 1.18)
			if _stage_time >= 7.0 and not _roof_event_played:
				_roof_event_played = true
				_play_passing_train_cutscene()
			if _stage_time >= 19.0 and not _bridge_event_played:
				_bridge_event_played = true
				_play_bridge_collapse_event()
		STAGE_ENGINE:
			_train_speed = lerpf(27.0, 34.0, clampf(_stage_time / STAGE_DURATIONS[STAGE_ENGINE], 0.0, 1.0))
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_engine_obstacle()
				_spawn_timer = _rng.randf_range(0.82, 1.20)
			if _engine_gate_index < 3 and _required_lane < 0:
				var gate_time: float = 4.5 + float(_engine_gate_index) * 6.0
				if _stage_time >= gate_time:
					_start_engine_gate()

	if _stage_time >= STAGE_DURATIONS[_stage] and _stage < STAGE_FINALE:
		_advance_stage()


func _advance_stage() -> void:
	_stage += 1
	_stage_time = 0.0
	_spawn_timer = 1.0
	_clear_obstacles()
	_set_section(_stage)
	match _stage:
		STAGE_SWITCH:
			_start_track_choice()
		STAGE_ROOF:
			_play_roof_transition()
		STAGE_ENGINE:
			_train_audio.call("play_engine_overdrive")
			_show_message("ENGINE CAR", "THREE CONTROL BANKS. ALIGN WITH THE LIT CHANNEL BEFORE EACH GATE HITS.", 5.0)
		STAGE_FINALE:
			_play_finale()


func _start_track_choice() -> void:
	_choice_active = true
	_choice_time = 7.0
	_choice_lane = 1
	_choice_panel.visible = true
	_refresh_choice_focus()
	_set_letterbox(true)
	_train_audio.call("play_brakes")
	_show_message("THE WOMAN", "The left rail leads to me. The right rail leads to what you buried.", 5.6)
	_play_choice_camera_move()


func _confirm_route_choice() -> void:
	if not _choice_active:
		return
	_choice_active = false
	_choice_panel.visible = false
	_route_choice = &"her" if _choice_lane <= 1 else &"self"
	_target_lane_index = 0 if _route_choice == &"her" else 2
	_train_audio.call("play_track_switch")
	_add_shake(0.75)
	var tilt_direction: float = -1.0 if _route_choice == &"her" else 1.0
	var tilt_tween: Tween = create_tween()
	tilt_tween.tween_property(_train_shell, "rotation_degrees:z", tilt_direction * 8.0, 0.32).set_trans(Tween.TRANS_QUAD)
	tilt_tween.tween_property(_train_shell, "rotation_degrees:z", 0.0, 0.72).set_trans(Tween.TRANS_ELASTIC)
	if _route_choice == &"her":
		_show_message("ROUTE ACCEPTED", "FOLLOW HER  //  The windows remember warmth that may never have happened.", 5.0)
	else:
		_show_message("ROUTE ACCEPTED", "FOLLOW YOURSELF  //  Every reflection is now looking back.", 5.0)
	_set_letterbox(false)


func _start_engine_gate() -> void:
	var gate_sequence: Array[int] = [0, 2, 1]
	_required_lane = gate_sequence[_engine_gate_index]
	_required_lane_timer = 3.4
	var lane_names: Array[String] = ["LEFT PRESSURE BANK", "RIGHT BRAKE BANK", "CENTER MEMORY CORE"]
	_objective_label.text = "ALIGN: %s" % lane_names[_required_lane]
	_train_audio.call("play_memory_pulse")
	_pulse_lane_beacon(_required_lane)


func _resolve_engine_gate() -> void:
	if _required_lane < 0:
		return
	var success: bool = _nearest_lane_index(_runner.position.x) == _required_lane
	if success:
		_train_audio.call("play_track_switch")
		_show_message("ENGINE STABLE", "CONTROL BANK %d / 3 LOCKED" % (_engine_gate_index + 1), 2.1)
	else:
		_apply_hit(1, float(_required_lane - 1))
		_show_message("ENGINE MISALIGNED", "THE TRAIN TORE THROUGH THE WRONG MEMORY CHANNEL.", 2.6)
	_engine_gate_index += 1
	_required_lane = -1
	_required_lane_timer = 0.0


func _spawn_passenger_obstacle() -> void:
	var lane: int = _rng.randi_range(0, 2)
	var jump_required: bool = _rng.randf() < 0.54
	_spawn_obstacle(lane, jump_required, "LUGGAGE" if jump_required else "SHADOW PASSENGER")


func _spawn_baggage_obstacle() -> void:
	var lane: int = _rng.randi_range(0, 2)
	_spawn_obstacle(lane, _rng.randf() < 0.68, "MEMORY CASE")
	if _rng.randf() < 0.28:
		var second_lane: int = (lane + _rng.randi_range(1, 2)) % 3
		_spawn_obstacle(second_lane, true, "FALLEN TABLE", -44.0)


func _spawn_roof_obstacle() -> void:
	if _rng.randf() < 0.20:
		_spawn_gap()
		return
	var lane: int = _rng.randi_range(0, 2)
	var jump_required: bool = _rng.randf() < 0.72
	_spawn_obstacle(lane, jump_required, "SIGNAL FRAME" if jump_required else "LIVE CABLE")


func _spawn_engine_obstacle() -> void:
	var lane: int = _rng.randi_range(0, 2)
	_spawn_obstacle(lane, _rng.randf() < 0.60, "BOILER DEBRIS")


func _spawn_obstacle(lane: int, jump_required: bool, obstacle_name: String, start_z: float = -38.0) -> void:
	var obstacle: Node3D = Node3D.new()
	obstacle.name = obstacle_name.replace(" ", "")
	obstacle.position = Vector3(LANE_POSITIONS[lane], 0.55, start_z)
	obstacle.set_meta("lane", lane)
	obstacle.set_meta("jump_required", jump_required)
	obstacle.set_meta("hit", false)
	obstacle.set_meta("kind", obstacle_name)
	_obstacle_root.add_child(obstacle)
	_obstacles.append(obstacle)

	var color: Color = Color("d84f9f") if jump_required else Color("7855db")
	if _route_choice == &"self":
		color = Color("5b8cff") if jump_required else Color("b744ea")
	if jump_required:
		_add_box(obstacle, Vector3(0.0, 0.25, 0.0), Vector3(1.45, 0.85, 1.10), Color("17101f"))
		_add_box(obstacle, Vector3(0.0, 0.75, -0.10), Vector3(1.12, 0.08, 0.70), color, color)
	else:
		_add_box(obstacle, Vector3(0.0, 1.25, 0.0), Vector3(1.25, 2.50, 0.42), Color(0.08, 0.03, 0.12, 0.86))
		_add_box(obstacle, Vector3(0.0, 2.20, 0.0), Vector3(0.40, 0.40, 0.40), color, color)


func _spawn_gap() -> void:
	var obstacle: Node3D = Node3D.new()
	obstacle.name = "RoofGap"
	obstacle.position = Vector3(0.0, 0.10, -40.0)
	obstacle.set_meta("lane", -1)
	obstacle.set_meta("jump_required", true)
	obstacle.set_meta("hit", false)
	obstacle.set_meta("kind", "ROOF GAP")
	_obstacle_root.add_child(obstacle)
	_obstacles.append(obstacle)
	_add_box(obstacle, Vector3.ZERO, Vector3(8.0, 0.06, 2.8), Color(0.01, 0.0, 0.02, 1.0))
	for edge_x: float in [-3.7, 3.7]:
		_add_box(obstacle, Vector3(edge_x, 0.35, 0.0), Vector3(0.08, 0.70, 2.8), Color("ff4faf"), Color("ff4faf"))


func _update_obstacles(delta: float) -> void:
	for obstacle: Node3D in _obstacles.duplicate():
		if not is_instance_valid(obstacle):
			_obstacles.erase(obstacle)
			continue
		obstacle.position.z += _train_speed * delta
		var distance_z: float = absf(obstacle.position.z - RUNNER_Z)
		if distance_z < 0.90 and not bool(obstacle.get_meta("hit", false)):
			var lane: int = int(obstacle.get_meta("lane", -1))
			var lane_matches: bool = lane < 0 or absf(obstacle.position.x - _runner.position.x) < 0.92
			if lane_matches:
				var jump_required: bool = bool(obstacle.get_meta("jump_required", true))
				var avoided: bool = jump_required and _runner.position.y >= 1.18
				if not avoided:
					obstacle.set_meta("hit", true)
					_apply_hit(1, signf(obstacle.position.x))
		if obstacle.position.z > 15.0:
			_obstacles.erase(obstacle)
			obstacle.queue_free()


func _apply_hit(damage: int, side: float) -> void:
	if _invulnerability > 0.0 or _transition_started:
		return
	_invulnerability = 1.0
	_integrity = maxi(0, _integrity - damage)
	_add_shake(1.0)
	_train_audio.call("play_collision", side)
	_flash_rect.color = Color(0.88, 0.08, 0.34, 0.62)
	var kick_direction: float = -1.0 if side >= 0.0 else 1.0
	_runner.rotation_degrees.z = kick_direction * 18.0
	var recovery_tween: Tween = create_tween()
	recovery_tween.tween_property(_runner, "rotation_degrees:z", 0.0, 0.55).set_trans(Tween.TRANS_ELASTIC)
	if _integrity <= 0:
		_reset_checkpoint()


func _reset_checkpoint() -> void:
	_integrity = 3
	_invulnerability = 2.0
	_vertical_velocity = 0.0
	_runner.position.y = RUNNER_GROUND_Y
	_grounded = true
	_clear_obstacles()
	_show_message("MEMORY REWOUND", "The conductor returned you to the last stable car.", 3.2)
	_flash_rect.color = Color(0.55, 0.28, 0.92, 0.82)


func _play_side_collision_cutscene() -> void:
	if _cinematic_running:
		return
	_cinematic_running = true
	_train_audio.call("play_horn")
	_show_message("THE CONDUCTOR", "Another version of you missed the transfer.", 3.8)
	var phantom: Node3D = _build_phantom_train(-9.0)
	var phantom_tween: Tween = create_tween()
	phantom_tween.tween_property(phantom, "position:z", 18.0, 2.4).set_trans(Tween.TRANS_QUINT)

	var camera_out: Tween = create_tween().set_parallel(true)
	camera_out.tween_property(_camera_rig, "position", Vector3(10.5, 4.0, 4.0), 0.55).set_trans(Tween.TRANS_QUAD)
	camera_out.tween_property(_camera_rig, "rotation_degrees", Vector3(-6.0, 76.0, 0.0), 0.55).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(0.75).timeout
	_add_shake(1.0)
	_train_audio.call("play_collision", -1.0)
	_train_audio.call("play_sparks", -1.0)
	await get_tree().create_timer(1.15).timeout
	_return_gameplay_camera(0.75)
	await get_tree().create_timer(0.8).timeout
	phantom.queue_free()
	_cinematic_running = false


func _play_choice_camera_move() -> void:
	if _cinematic_running:
		return
	_cinematic_running = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_camera_rig, "position", Vector3(0.0, 4.8, -5.2), 0.9).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_camera_rig, "rotation_degrees", Vector3(-8.0, 180.0, 0.0), 0.9).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(3.2).timeout
	_return_gameplay_camera(0.9)
	await get_tree().create_timer(0.95).timeout
	_cinematic_running = false


func _play_roof_transition() -> void:
	if _cinematic_running:
		return
	_cinematic_running = true
	_set_letterbox(true)
	_train_audio.call("play_sparks", 0.0)
	_add_shake(0.72)
	_show_message("ROOF ACCESS", "The train has run out of rooms. Keep moving anyway.", 4.2)
	var rise_tween: Tween = create_tween().set_parallel(true)
	rise_tween.tween_property(_camera_rig, "position", Vector3(-8.0, 7.2, 10.0), 1.15).set_trans(Tween.TRANS_QUINT)
	rise_tween.tween_property(_camera_rig, "rotation_degrees", Vector3(-18.0, -32.0, 0.0), 1.15).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(1.5).timeout
	_return_gameplay_camera(0.95)
	await get_tree().create_timer(1.0).timeout
	_set_letterbox(false)
	_cinematic_running = false


func _play_passing_train_cutscene() -> void:
	if _cinematic_running:
		return
	_cinematic_running = true
	var side: float = 1.0 if _route_choice == &"her" else -1.0
	var phantom: Node3D = _build_phantom_train(side * 9.0)
	phantom.position.z = -48.0
	_train_audio.call("play_horn")
	var pass_tween: Tween = create_tween()
	pass_tween.tween_property(phantom, "position:z", 28.0, 2.1).set_trans(Tween.TRANS_EXPO)
	var camera_tween: Tween = create_tween().set_parallel(true)
	camera_tween.tween_property(_camera_rig, "position", Vector3(-side * 9.0, 5.4, 4.8), 0.45)
	camera_tween.tween_property(_camera_rig, "rotation_degrees", Vector3(-9.0, -side * 78.0, 0.0), 0.45)
	await get_tree().create_timer(0.78).timeout
	_add_shake(0.92)
	_train_audio.call("play_sparks", side)
	await get_tree().create_timer(1.05).timeout
	_return_gameplay_camera(0.65)
	await get_tree().create_timer(0.75).timeout
	phantom.queue_free()
	_cinematic_running = false


func _play_bridge_collapse_event() -> void:
	_train_audio.call("play_horn")
	_show_message("SIGNAL FAILURE", "THE BRIDGE IS COMING DOWN — JUMP THE DEAD SECTION.", 3.8)
	for index: int in range(3):
		_spawn_gap_at(-42.0 - float(index) * 8.0)
	_add_shake(0.45)
	var arch: Node3D = Node3D.new()
	arch.position = Vector3(0.0, 8.5, -25.0)
	_obstacle_root.add_child(arch)
	_add_box(arch, Vector3.ZERO, Vector3(12.0, 0.45, 0.70), Color("372345"), Color("c03b9a"))
	var fall_tween: Tween = create_tween()
	fall_tween.tween_property(arch, "rotation_degrees:z", 72.0, 2.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_callback(Callable(arch, "queue_free"))


func _spawn_gap_at(start_z: float) -> void:
	var obstacle: Node3D = Node3D.new()
	obstacle.name = "BridgeGap"
	obstacle.position = Vector3(0.0, 0.08, start_z)
	obstacle.set_meta("lane", -1)
	obstacle.set_meta("jump_required", true)
	obstacle.set_meta("hit", false)
	obstacle.set_meta("kind", "BRIDGE GAP")
	_obstacle_root.add_child(obstacle)
	_obstacles.append(obstacle)
	_add_box(obstacle, Vector3.ZERO, Vector3(8.2, 0.05, 2.5), Color("030106"))


func _play_finale() -> void:
	_gameplay_active = false
	_transition_started = true
	_set_letterbox(true)
	_clear_obstacles()
	_train_audio.call("play_engine_overdrive")
	_train_audio.call("play_horn")
	_show_message(
		"FINAL DESTINATION",
		"The train never had an engine. It was your memory pushing from behind.",
		5.2
	)
	var neon_gate: Node3D = _build_nightclub_gate()
	neon_gate.position.z = -48.0
	var gate_tween: Tween = create_tween()
	gate_tween.tween_property(neon_gate, "position:z", -5.0, 4.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	var camera_tween: Tween = create_tween().set_parallel(true)
	camera_tween.tween_property(_camera_rig, "position", Vector3(0.0, 2.1, 7.0), 3.8).set_trans(Tween.TRANS_QUINT)
	camera_tween.tween_property(_camera, "fov", 84.0, 3.8).set_trans(Tween.TRANS_QUINT)
	for pulse_index: int in range(5):
		await get_tree().create_timer(0.62).timeout
		_add_shake(0.34 + float(pulse_index) * 0.12)
		_train_audio.call("play_sparks", -1.0 if pulse_index % 2 == 0 else 1.0)

	_flash_rect.color = Color(1.0, 0.62, 0.88, 0.0)
	var impact_tween: Tween = create_tween()
	impact_tween.tween_property(_flash_rect, "color:a", 1.0, 0.18)
	await impact_tween.finished
	_train_audio.call("play_collision", 0.0)
	_train_audio.call("stop", 2.2)
	MusicDirector.stop_music(3.5)
	await get_tree().create_timer(0.45).timeout
	var nightclub_scene: PackedScene = StartupPreloader.get_preloaded_scene(NIGHTCLUB_SCENE_PATH)
	if nightclub_scene != null:
		get_tree().change_scene_to_packed(nightclub_scene)
	else:
		get_tree().change_scene_to_file(NIGHTCLUB_SCENE_PATH)


func _set_section(stage: int) -> void:
	for child: Node in _section_root.get_children():
		child.queue_free()
	_scrolling_details.clear()
	match stage:
		STAGE_PASSENGER:
			_build_passenger_car()
		STAGE_SWITCH:
			_build_switch_car()
		STAGE_ROOF:
			_build_roof_section()
		STAGE_ENGINE, STAGE_FINALE:
			_build_engine_car()


func _build_world() -> void:
	_train_shell = Node3D.new()
	_train_shell.name = "MemoryTrain"
	add_child(_train_shell)

	_section_root = Node3D.new()
	_section_root.name = "TrainSection"
	_train_shell.add_child(_section_root)

	_obstacle_root = Node3D.new()
	_obstacle_root.name = "ActionObstacles"
	_train_shell.add_child(_obstacle_root)

	_scenery_root = Node3D.new()
	_scenery_root.name = "MovingNight"
	add_child(_scenery_root)
	_build_outside_scenery()


func _build_environment() -> void:
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "TrainEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("010006")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("30204b")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("311344")
	environment.fog_density = 0.010
	environment.glow_enabled = true
	environment.glow_bloom = 0.28
	environment.glow_intensity = 1.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_world_environment.environment = environment
	add_child(_world_environment)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -18.0, 0.0)
	key_light.light_color = Color("8c76ff")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(18.0, 148.0, 0.0)
	fill_light.light_color = Color("ff3f9f")
	fill_light.light_energy = 0.42
	add_child(fill_light)


func _build_passenger_car() -> void:
	_build_car_shell(Color("17101f"), Color("c13f91"))
	var seat_z_values: Array[float] = [-12.0, -7.0, -2.0, 7.0, 12.0]
	for seat_z: float in seat_z_values:
		for side: float in [-1.0, 1.0]:
			_add_box(_section_root, Vector3(side * 3.10, 0.65, seat_z), Vector3(1.10, 1.30, 1.70), Color("24172d"))
			if int(absf(seat_z)) % 2 == 0:
				_build_ghost_passenger(Vector3(side * 3.10, 1.10, seat_z))
	_objective_label.text = "MOVE FORWARD THROUGH THE PASSENGER CARS"
	_stage_label.text = "CAR 01  //  THE PASSENGERS"


func _build_switch_car() -> void:
	_build_car_shell(Color("14101d"), Color("8058ff"))
	var table_z_values: Array[float] = [-11.0, -4.0, 5.0, 12.0]
	for index: int in range(table_z_values.size()):
		var table_z: float = table_z_values[index]
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_add_box(_section_root, Vector3(side * 2.75, 0.75, table_z), Vector3(1.8, 0.16, 1.2), Color("3a2343"))
		_add_box(_section_root, Vector3(side * 2.75, 1.55, table_z), Vector3(0.22, 1.60, 0.22), Color("6f5087"))
	_build_switch_lever(Vector3(0.0, 0.0, -15.0))
	_objective_label.text = "CHOOSE A TRACK WHILE THE CAR KEEPS MOVING"
	_stage_label.text = "CAR 06  //  THE SPLIT"


func _build_roof_section() -> void:
	_add_box(_section_root, Vector3(0.0, 0.0, 0.0), Vector3(8.0, 0.45, 80.0), Color("18121f"))
	for rail_x: float in [-3.85, 3.85]:
		_add_box(_section_root, Vector3(rail_x, 0.45, 0.0), Vector3(0.12, 0.90, 80.0), Color("62416d"), Color("9f3a91"))
	for z_index: int in range(16):
		var z_position: float = -36.0 + float(z_index) * 5.0
		_add_box(_section_root, Vector3(0.0, 0.25, z_position), Vector3(7.8, 0.08, 0.12), Color("59415f"))
	_objective_label.text = "RUN THE ROOF — WATCH SIGNAL FRAMES AND DEAD SECTIONS"
	_stage_label.text = "ROOF LINE  //  NO SHELTER"


func _build_engine_car() -> void:
	_build_car_shell(Color("160d18"), Color("ff456f"))
	for machinery_index: int in range(8):
		var side: float = -1.0 if machinery_index % 2 == 0 else 1.0
		var z_position: float = -14.0 + float(machinery_index) * 4.0
		_add_box(_section_root, Vector3(side * 3.15, 1.30, z_position), Vector3(1.20, 2.60, 1.70), Color("24151e"))
		_add_box(_section_root, Vector3(side * 3.15, 2.15, z_position), Vector3(0.55, 0.55, 0.25), Color("ff4a88"), Color("ff4a88"))
	for lane_index: int in range(3):
		_build_control_beacon(lane_index)
	_objective_label.text = "STABILIZE THE ENGINE BEFORE THE FINAL DESTINATION"
	_stage_label.text = "ENGINE 13  //  NO DRIVER"


func _build_car_shell(base_color: Color, accent: Color) -> void:
	_add_box(_section_root, Vector3(0.0, 0.0, 0.0), Vector3(8.2, 0.45, 80.0), base_color)
	_add_box(_section_root, Vector3(-4.1, 2.5, 0.0), Vector3(0.28, 5.0, 80.0), base_color)
	_add_box(_section_root, Vector3(4.1, 2.5, 0.0), Vector3(0.28, 5.0, 80.0), base_color)
	_add_box(_section_root, Vector3(0.0, 5.0, 0.0), Vector3(8.2, 0.24, 80.0), base_color)
	for z_index: int in range(14):
		var z_position: float = -34.0 + float(z_index) * 5.2
		_add_box(_section_root, Vector3(0.0, 4.65, z_position), Vector3(5.4, 0.10, 0.18), accent, accent)
		for side: float in [-1.0, 1.0]:
			var window: Node3D = _add_box(
				_section_root,
				Vector3(side * 4.00, 2.65, z_position),
				Vector3(0.10, 1.55, 2.8),
				Color(0.12, 0.04, 0.20, 0.48),
				accent.darkened(0.35)
			)
			window.set_meta("scroll_speed", _rng.randf_range(0.92, 1.08))
			_scrolling_details.append(window)


func _build_runner() -> void:
	_runner = Node3D.new()
	_runner.name = "MemoryRunner"
	_runner.position = Vector3(0.0, RUNNER_GROUND_Y, RUNNER_Z)
	add_child(_runner)
	_runner_visual = Node3D.new()
	_runner_visual.name = "RunnerVisual"
	_runner.add_child(_runner_visual)

	var bone: Color = Color("d8d3c4")
	var dark: Color = Color("17141d")
	_add_sphere(_runner_visual, Vector3(0.0, 1.72, 0.0), 0.28, bone)
	_add_box(_runner_visual, Vector3(0.0, 1.42, 0.0), Vector3(0.42, 0.18, 0.28), bone)
	_add_box(_runner_visual, Vector3(0.0, 1.08, 0.0), Vector3(0.18, 0.58, 0.18), bone)
	for rib_y: float in [1.34, 1.22, 1.10]:
		_add_box(_runner_visual, Vector3(0.0, rib_y, 0.0), Vector3(0.62, 0.055, 0.18), bone)
	_add_box(_runner_visual, Vector3(0.0, 0.78, 0.0), Vector3(0.46, 0.20, 0.28), bone)
	for side: float in [-1.0, 1.0]:
		_add_box(_runner_visual, Vector3(side * 0.35, 1.05, 0.0), Vector3(0.10, 0.70, 0.10), bone)
		_add_box(_runner_visual, Vector3(side * 0.16, 0.38, 0.0), Vector3(0.12, 0.72, 0.12), bone)
		_add_sphere(_runner_visual, Vector3(side * 0.09, 1.76, -0.24), 0.052, dark)


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "ActionCameraRig"
	_camera_rig.position = Vector3(0.0, 3.15, 10.2)
	_camera_rig.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	add_child(_camera_rig)
	_camera = Camera3D.new()
	_camera.name = "ActionCamera"
	_camera.current = true
	_camera.fov = 66.0
	_camera_rig.add_child(_camera)


func _build_hud() -> void:
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.layer = 100
	add_child(_hud_canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_canvas.add_child(root)

	_stage_label = _make_label("CAR 01  //  THE PASSENGERS", 15, Color("ee92cf"))
	_stage_label.position = Vector2(48.0, 38.0)
	root.add_child(_stage_label)
	_objective_label = _make_label("MOVE FORWARD THROUGH THE PASSENGER CARS", 17, Color("f3eef7"))
	_objective_label.position = Vector2(48.0, 67.0)
	root.add_child(_objective_label)
	_speed_label = _make_label("088 MPH", 15, Color("91a8ff"))
	_speed_label.anchor_left = 1.0
	_speed_label.anchor_right = 1.0
	_speed_label.position = Vector2(-155.0, 42.0)
	root.add_child(_speed_label)
	_integrity_label = _make_label("TRAIN MEMORY  ◆ ◆ ◆", 14, Color("f3eef7"))
	_integrity_label.anchor_left = 1.0
	_integrity_label.anchor_right = 1.0
	_integrity_label.position = Vector2(-260.0, 70.0)
	root.add_child(_integrity_label)

	_message_panel = PanelContainer.new()
	_message_panel.anchor_left = 0.16
	_message_panel.anchor_right = 0.84
	_message_panel.anchor_top = 0.70
	_message_panel.anchor_bottom = 0.90
	_message_panel.visible = false
	var message_style: StyleBoxFlat = StyleBoxFlat.new()
	message_style.bg_color = Color(0.02, 0.008, 0.035, 0.94)
	message_style.border_color = Color("b44396")
	message_style.set_border_width_all(2)
	message_style.set_corner_radius_all(5)
	message_style.content_margin_left = 24.0
	message_style.content_margin_right = 24.0
	message_style.content_margin_top = 16.0
	message_style.content_margin_bottom = 16.0
	_message_panel.add_theme_stylebox_override("panel", message_style)
	root.add_child(_message_panel)
	var message_stack: VBoxContainer = VBoxContainer.new()
	message_stack.add_theme_constant_override("separation", 8)
	_message_panel.add_child(message_stack)
	_message_source = _make_label("THE CONDUCTOR", 12, Color("ee63b4"))
	message_stack.add_child(_message_source)
	_message_body = _make_label("", 21, Color("f4edf7"))
	_message_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_stack.add_child(_message_body)

	_choice_panel = PanelContainer.new()
	_choice_panel.anchor_left = 0.12
	_choice_panel.anchor_right = 0.88
	_choice_panel.anchor_top = 0.16
	_choice_panel.anchor_bottom = 0.38
	_choice_panel.visible = false
	var choice_style: StyleBoxFlat = message_style.duplicate() as StyleBoxFlat
	if choice_style != null:
		choice_style.border_color = Color("785bff")
		_choice_panel.add_theme_stylebox_override("panel", choice_style)
	root.add_child(_choice_panel)
	var choice_stack: VBoxContainer = VBoxContainer.new()
	choice_stack.add_theme_constant_override("separation", 12)
	_choice_panel.add_child(choice_stack)
	var choice_title: Label = _make_label("CHOOSE THE NEXT TRACK  //  A / D THEN E", 14, Color("cabfff"))
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_stack.add_child(choice_title)
	var choice_row: HBoxContainer = HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 32)
	choice_stack.add_child(choice_row)
	_choice_left = _make_label("A  FOLLOW HER", 22, Color("f5a3d4"))
	_choice_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_row.add_child(_choice_left)
	_choice_right = _make_label("D  FOLLOW YOURSELF", 22, Color("9ab4ff"))
	_choice_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_row.add_child(_choice_right)
	_choice_timer_label = _make_label("TRACK LOCK IN  7.0", 12, Color("bbb1c5"))
	_choice_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_stack.add_child(_choice_timer_label)

	_top_bar = ColorRect.new()
	_top_bar.anchor_right = 1.0
	_top_bar.offset_bottom = 0.0
	_top_bar.color = Color("050308")
	root.add_child(_top_bar)
	_bottom_bar = ColorRect.new()
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_top = 0.0
	_bottom_bar.color = Color("050308")
	root.add_child(_bottom_bar)

	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.12, 0.01, 0.18, 0.11)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash_rect)


func _build_outside_scenery() -> void:
	for light_index: int in range(34):
		var side: float = -1.0 if light_index % 2 == 0 else 1.0
		var light: Node3D = _add_box(
			_scenery_root,
			Vector3(side * _rng.randf_range(9.0, 28.0), _rng.randf_range(-1.0, 8.0), -55.0 + float(light_index) * 4.2),
			Vector3(_rng.randf_range(0.08, 0.22), _rng.randf_range(0.08, 1.2), _rng.randf_range(0.6, 3.4)),
			Color("7136a8") if light_index % 3 != 0 else Color("f03c9c"),
			Color("7136a8") if light_index % 3 != 0 else Color("f03c9c")
		)
		light.set_meta("scenery_speed", _rng.randf_range(0.72, 1.35))
		_scrolling_details.append(light)


func _update_scrolling_details(delta: float) -> void:
	_section_scroll += _train_speed * delta
	for detail: Node3D in _scrolling_details:
		if not is_instance_valid(detail):
			continue
		var speed_scale: float = float(detail.get_meta("scenery_speed", detail.get_meta("scroll_speed", 1.0)))
		detail.position.z += _train_speed * speed_scale * delta
		if detail.position.z > 36.0:
			detail.position.z -= 92.0


func _update_camera_shake(delta: float) -> void:
	_shake_trauma = maxf(0.0, _shake_trauma - delta * 0.95)
	var shake_strength: float = _shake_trauma * _shake_trauma
	var base_roll: float = sin(_camera_time * 18.0) * 0.18 * (_train_speed / 34.0)
	_camera.position = Vector3(
		sin(_camera_time * 41.0) * 0.20 * shake_strength,
		sin(_camera_time * 47.0 + 1.3) * 0.16 * shake_strength,
		0.0
	)
	_camera.rotation_degrees = Vector3(
		sin(_camera_time * 31.0) * 0.80 * shake_strength,
		sin(_camera_time * 37.0) * 0.95 * shake_strength,
		base_roll + sin(_camera_time * 43.0) * 1.25 * shake_strength
	)


func _update_flash(delta: float) -> void:
	if _flash_rect.color.a <= 0.0:
		return
	var color: Color = _flash_rect.color
	color.a = maxf(0.0, color.a - delta * 1.8)
	_flash_rect.color = color


func _update_hud() -> void:
	_speed_label.text = "%03d MPH" % int(72.0 + _train_speed * 3.7)
	var diamonds: String = ""
	for index: int in range(3):
		diamonds += "◆ " if index < _integrity else "◇ "
	_integrity_label.text = "TRAIN MEMORY  %s" % diamonds.strip_edges()
	if _required_lane < 0 and not _choice_active:
		_objective_label.modulate = Color.WHITE


func _show_message(source: String, text: String, duration: float) -> void:
	_message_token += 1
	var token: int = _message_token
	_message_source.text = source.to_upper()
	_message_body.text = text
	_message_panel.visible = true
	_message_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var reveal: Tween = create_tween()
	reveal.tween_property(_message_panel, "modulate:a", 1.0, 0.22)
	await get_tree().create_timer(duration).timeout
	if token != _message_token or _message_panel == null:
		return
	var hide: Tween = create_tween()
	hide.tween_property(_message_panel, "modulate:a", 0.0, 0.24)
	await hide.finished
	if token == _message_token:
		_message_panel.visible = false


func _set_letterbox(enabled: bool) -> void:
	var top_target: float = 64.0 if enabled else 0.0
	var bottom_target: float = -64.0 if enabled else 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_top_bar, "offset_bottom", top_target, 0.38)
	tween.tween_property(_bottom_bar, "offset_top", bottom_target, 0.38)


func _return_gameplay_camera(duration: float) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_camera_rig, "position", Vector3(0.0, 3.15, 10.2), duration).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_camera_rig, "rotation_degrees", Vector3(-7.0, 0.0, 0.0), duration).set_trans(Tween.TRANS_QUINT)


func _refresh_choice_focus() -> void:
	_choice_left.modulate = Color.WHITE if _choice_lane <= 1 else Color(0.48, 0.42, 0.55, 0.72)
	_choice_right.modulate = Color.WHITE if _choice_lane >= 2 else Color(0.48, 0.42, 0.55, 0.72)


func _pulse_lane_beacon(lane: int) -> void:
	var beacon: Node3D = _section_root.get_node_or_null("ControlBeacon%d" % lane) as Node3D
	if beacon == null:
		return
	var tween: Tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(beacon, "scale", Vector3.ONE * 1.35, 0.22)
	tween.tween_property(beacon, "scale", Vector3.ONE, 0.22)


func _build_control_beacon(lane: int) -> void:
	var beacon: Node3D = Node3D.new()
	beacon.name = "ControlBeacon%d" % lane
	beacon.position = Vector3(LANE_POSITIONS[lane], 2.8, -11.0)
	_section_root.add_child(beacon)
	var color: Color = Color("ff4c8e") if lane != 1 else Color("8f73ff")
	_add_box(beacon, Vector3.ZERO, Vector3(1.4, 0.18, 0.18), color, color)
	_add_box(beacon, Vector3(0.0, -0.35, 0.0), Vector3(0.18, 0.70, 0.18), color, color)


func _build_switch_lever(lever_position: Vector3) -> void:
	var lever: Node3D = Node3D.new()
	lever.position = lever_position
	_section_root.add_child(lever)
	_add_box(lever, Vector3(0.0, 0.55, 0.0), Vector3(2.8, 1.1, 1.2), Color("23182d"))
	_add_box(lever, Vector3(-0.75, 1.35, 0.0), Vector3(0.18, 1.6, 0.18), Color("ef4ba3"), Color("ef4ba3"))
	_add_box(lever, Vector3(0.75, 1.35, 0.0), Vector3(0.18, 1.6, 0.18), Color("6f75ff"), Color("6f75ff"))


func _build_ghost_passenger(passenger_position: Vector3) -> void:
	var ghost: Node3D = Node3D.new()
	ghost.position = passenger_position
	_section_root.add_child(ghost)
	_add_box(ghost, Vector3(0.0, 0.55, 0.0), Vector3(0.65, 1.10, 0.42), Color(0.09, 0.02, 0.13, 0.82))
	_add_sphere(ghost, Vector3(0.0, 1.35, 0.0), 0.30, Color(0.28, 0.10, 0.35, 0.78))


func _build_phantom_train(side_x: float) -> Node3D:
	var phantom: Node3D = Node3D.new()
	phantom.position = Vector3(side_x, 0.0, -32.0)
	add_child(phantom)
	_add_box(phantom, Vector3(0.0, 2.0, 0.0), Vector3(5.4, 4.0, 34.0), Color(0.04, 0.01, 0.06, 0.94))
	for window_index: int in range(8):
		var z_position: float = -14.0 + float(window_index) * 4.0
		_add_box(phantom, Vector3(-signf(side_x) * 2.72, 2.4, z_position), Vector3(0.10, 1.3, 2.2), Color("ce3a9a"), Color("ce3a9a"))
	return phantom


func _build_nightclub_gate() -> Node3D:
	var gate: Node3D = Node3D.new()
	add_child(gate)
	_add_box(gate, Vector3(0.0, 4.0, 0.0), Vector3(16.0, 8.0, 1.0), Color("120916"))
	_add_box(gate, Vector3(0.0, 4.0, 0.55), Vector3(10.0, 6.4, 0.16), Color("ff3d9e"), Color("ff3d9e"))
	_add_box(gate, Vector3(0.0, 4.0, 0.72), Vector3(8.4, 5.2, 0.20), Color("08040b"))
	var label: Label3D = Label3D.new()
	label.text = "OUT OF TIME"
	label.font_size = 88
	label.modulate = Color("ffd0e9")
	label.outline_size = 12
	label.position = Vector3(0.0, 6.6, 0.9)
	gate.add_child(label)
	return gate


func _clear_obstacles() -> void:
	for obstacle: Node3D in _obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	_obstacles.clear()


func _nearest_lane_index(x_position: float) -> int:
	var nearest: int = 0
	var nearest_distance: float = INF
	for index: int in range(LANE_POSITIONS.size()):
		var distance: float = absf(x_position - LANE_POSITIONS[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func _add_shake(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _add_box(
	parent: Node3D,
	box_position: Vector3,
	box_size: Vector3,
	color: Color,
	emission_color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> Node3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = box_position
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.48
	material.metallic = 0.24
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_color.a > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 2.3
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, sphere_position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = sphere_position
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _ensure_input_actions() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("interact", KEY_E)


func _add_key_action(action_name: StringName, physical_keycode: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)
