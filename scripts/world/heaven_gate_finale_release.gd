extends "res://scripts/world/heaven_gate_finale.gd"

const CINEMATIC_ANGEL_SCRIPT: Script = preload("res://scripts/world/heaven_angel_cinematic.gd")
const FIRST_GATE_HOLD_SECONDS: float = 5.0
const ATTACK_TRIGGER_PROGRESS: float = 0.50
const FIRST_PERSON_THROW_SECONDS: float = 0.28
const TURN_HOLD_SECONDS: float = 0.32
const ANGEL_WINDUP_SECONDS: float = 0.16
const ANGEL_LUNGE_SECONDS: float = 0.62
const JUMPSCARE_HOLD_SECONDS: float = 0.58

var _halfway_attack_triggered: bool = false
var _live_hold_progress_enabled: bool = false


func _ready() -> void:
	super._ready()
	_gate_interaction.set("hold_duration", FIRST_GATE_HOLD_SECONDS)
	_gate_interaction.set("interaction_context", "HOLD TO OPEN")
	_gate_interaction.call("refresh_release_presentation")
	if _gate_interaction.has_signal("hold_progressed"):
		_gate_interaction.connect("hold_progressed", Callable(self, "_on_gate_hold_progressed"))
		_live_hold_progress_enabled = true


func _build_angel_procession() -> void:
	var z_positions: Array[float] = [
		30.0, 18.0, 5.0, -8.0, -21.0, -34.0, -47.0,
		-60.0, -73.0, -86.0, -99.0, -112.0, -126.0
	]
	for index: int in range(z_positions.size()):
		for side: float in [-1.0, 1.0]:
			var angel: Node3D = CINEMATIC_ANGEL_SCRIPT.new() as Node3D
			angel.name = "Angel_%02d_%s" % [index, "L" if side < 0.0 else "R"]
			add_child(angel)
			angel.call(
				"configure",
				Vector3(side * (6.7 + float(index % 3) * 0.75), 0.0, z_positions[index]),
				float(index) * 0.53 + side
			)
			_angels.append(angel)


func _on_gate_hold_progressed(player: Node, progress: float) -> void:
	if _purified or _encounter_active or _halfway_attack_triggered:
		return
	var hold_progress: float = clampf(progress, 0.0, 1.0)
	var opening_strength: float = smoothstep(0.0, ATTACK_TRIGGER_PROGRESS, hold_progress)
	_gate_root.scale = Vector3.ONE * lerpf(1.0, 1.065, opening_strength)
	_gold_flash.color.a = lerpf(0.0, 0.20, opening_strength)
	if hold_progress < ATTACK_TRIGGER_PROGRESS:
		return
	_trigger_halfway_attack(player)


func _on_gate_activated(player: Node) -> void:
	if _transition_started or _encounter_active:
		return
	if _purified:
		super._on_gate_activated(player)
		return
	# Live hold progress owns the first attempt and interrupts it at 50%.
	if _live_hold_progress_enabled:
		return
	_trigger_halfway_attack(player)


func _trigger_halfway_attack(player: Node) -> void:
	if _halfway_attack_triggered or _encounter_active or _purified:
		return
	if player != _player or _player == null:
		return
	_halfway_attack_triggered = true
	_encounter_active = true
	_gate_interaction.set("_used", true)
	_gate_interaction.monitoring = false
	_gate_interaction.monitorable = false
	_gate_interaction.collision_layer = 0
	if player.has_method("clear_interaction_target"):
		player.call("clear_interaction_target", _gate_interaction)
	_start_gate_encounter.call_deferred(player)


func _start_gate_encounter(player: Node) -> void:
	if player != _player or _player == null:
		_encounter_active = false
		_halfway_attack_triggered = false
		return

	_player.velocity = Vector3.ZERO
	_player.call("set_cinematic_mode", true)
	_gate_scare_audio.call("play_gate_attempt")
	_audio.call("play_gate_open")
	SFXDirector.play_transition()
	_player.set_objective("The portal stops exactly halfway open.")

	_attacker = _select_attacker()
	if _attacker == null:
		await _complete_qte_success()
		return

	_scare_title.text = "THE GATE STOPS HALFWAY"
	_scare_instruction.text = "SOMETHING IS STANDING BESIDE YOU"
	_finale_overlay.visible = true
	_finale_overlay.modulate.a = 0.0
	var overlay_tween: Tween = create_tween()
	overlay_tween.tween_property(_finale_overlay, "modulate:a", 1.0, 0.16)

	var gate_tween: Tween = create_tween().set_parallel(true)
	gate_tween.tween_property(
		_gate_root,
		"scale",
		Vector3(1.085, 1.085, 1.085),
		0.42
	).set_trans(Tween.TRANS_SINE)
	gate_tween.tween_property(_gold_flash, "color:a", 0.30, 0.42).set_trans(Tween.TRANS_SINE)

	var player_head: Vector3 = _player.global_position + Vector3.UP * 1.62
	var attacker_face: Vector3 = _get_attacker_face_position()
	var attack_direction: Vector3 = attacker_face - player_head
	attack_direction.y = 0.0
	if attack_direction.length_squared() < 0.001:
		attack_direction = Vector3.FORWARD
	else:
		attack_direction = attack_direction.normalized()
	_scare_camera_forward = attack_direction

	_build_first_person_camera()
	_store_and_hide_player_presentation(true)
	_scare_camera_rig.look_at(attacker_face, Vector3.UP)
	_scare_trauma = 0.18
	var throw_tween: Tween = create_tween().set_parallel(true)
	throw_tween.tween_property(
		_scare_camera_rig,
		"global_position",
		player_head,
		FIRST_PERSON_THROW_SECONDS
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	throw_tween.tween_property(
		_scare_camera,
		"fov",
		74.0,
		FIRST_PERSON_THROW_SECONDS
	).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(FIRST_PERSON_THROW_SECONDS).timeout

	_scare_title.text = "IT WAS ALREADY WATCHING YOU"
	_scare_instruction.text = "YOU CANNOT TURN AWAY"
	await get_tree().create_timer(TURN_HOLD_SECONDS).timeout

	var attacker_target: Vector3 = (
		_player.global_position
		+ attack_direction * 0.62
		+ Vector3.DOWN * 0.68
	)
	if _attacker.has_method("begin_finale_lunge"):
		_attacker.call(
			"begin_finale_lunge",
			attacker_target,
			ANGEL_WINDUP_SECONDS,
			ANGEL_LUNGE_SECONDS
		)
	elif _attacker.has_method("begin_finale_grab"):
		_attacker.call("begin_finale_grab", attacker_target, ANGEL_LUNGE_SECONDS)

	_scare_title.text = "SHE MOVES"
	_scare_instruction.text = "TOO FAST"
	var lens_tween: Tween = create_tween()
	lens_tween.tween_property(
		_scare_camera,
		"fov",
		60.0,
		ANGEL_WINDUP_SECONDS + ANGEL_LUNGE_SECONDS
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(ANGEL_WINDUP_SECONDS).timeout

	_gate_scare_audio.call("play_grab")
	_audio.call("set_corruption", 1.0)
	_scare_trauma = 0.46
	_blood_flash.color.a = 0.34
	var blood_tween: Tween = create_tween()
	blood_tween.tween_property(_blood_flash, "color:a", 0.05, ANGEL_LUNGE_SECONDS)
	await get_tree().create_timer(ANGEL_LUNGE_SECONDS * 0.76).timeout

	_scare_trauma = 1.0
	_blood_flash.color.a = 0.62
	_scare_title.text = "SHE IS IN YOUR FACE"
	_scare_instruction.text = "BREAK HER GRIP"
	await get_tree().create_timer(ANGEL_LUNGE_SECONDS * 0.24).timeout
	await get_tree().create_timer(JUMPSCARE_HOLD_SECONDS).timeout
	_begin_qte()
