extends Node

const SAMPLE_RATE: int = 22050
const ONE_SHOT_POOL_SIZE: int = 10

var _ambience_player: AudioStreamPlayer
var _detail_player: AudioStreamPlayer
var _music_bed_player: AudioStreamPlayer
var _one_shot_players: Array[AudioStreamPlayer] = []
var _one_shot_index: int = 0
var _current_environment: StringName = &""
var _dialogue_ducked: bool = false

var _wind_stream: AudioStreamWAV
var _lantern_stream: AudioStreamWAV
var _cemetery_music_stream: AudioStreamWAV
var _engine_stream: AudioStreamWAV
var _city_stream: AudioStreamWAV
var _city_electric_stream: AudioStreamWAV
var _city_siren_stream: AudioStreamWAV
var _footstep_stream: AudioStreamWAV
var _interaction_stream: AudioStreamWAV
var _reveal_stream: AudioStreamWAV
var _jump_stream: AudioStreamWAV
var _land_stream: AudioStreamWAV
var _creak_stream: AudioStreamWAV

var _tracked_player: CharacterBody3D
var _was_on_floor: bool = false
var _step_timer: float = 0.0
var _environment_detail_timer: float = 7.0
var _ui_hover_cooldown: float = 0.0
var _dialogue_tick_cooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 904211
	_build_audio_buses()
	_ambience_player = _create_player("EnvironmentAmbience", 0.22, "Ambience")
	_detail_player = _create_player("EnvironmentDetail", 0.13, "Ambience")
	_music_bed_player = _create_player("EnvironmentMusicBed", 0.0, "Ambience")

	for index: int in range(ONE_SHOT_POOL_SIZE):
		var player: AudioStreamPlayer = _create_player("SFXPlayer%d" % (index + 1), 0.35, "SFX")
		_one_shot_players.append(player)

	_wind_stream = _build_wind_stream()
	_lantern_stream = _build_lantern_stream()
	_cemetery_music_stream = _build_cemetery_music_stream()
	_engine_stream = _build_engine_stream()
	_city_stream = _build_city_stream()
	_city_electric_stream = _build_city_electric_stream()
	_city_siren_stream = _build_city_siren_stream()
	_footstep_stream = _build_footstep_stream()
	_interaction_stream = _build_chime_stream(620.0, 930.0, 0.38)
	_reveal_stream = _build_reveal_stream()
	_jump_stream = _build_chime_stream(180.0, 270.0, 0.20)
	_land_stream = _build_land_stream()
	_creak_stream = _build_creak_stream()
	MusicDirector.cue_started.connect(_on_music_cue_started)


func _process(delta: float) -> void:
	_ui_hover_cooldown = maxf(0.0, _ui_hover_cooldown - delta)
	_dialogue_tick_cooldown = maxf(0.0, _dialogue_tick_cooldown - delta)
	_update_player_sfx(delta)
	_update_environment_details(delta)


func start_cemetery_ambience() -> void:
	if _current_environment == &"cemetery" and _ambience_player.playing and _music_bed_player.playing:
		return
	_current_environment = &"cemetery"
	_start_loop(_ambience_player, _wind_stream, 0.20)
	_start_loop(_detail_player, _lantern_stream, 0.10)
	_start_loop(_music_bed_player, _cemetery_music_stream, 0.085)
	_environment_detail_timer = _rng.randf_range(4.0, 8.0)


func start_pontiac_ambience() -> void:
	if _current_environment == &"pontiac" and _ambience_player.playing:
		return
	_current_environment = &"pontiac"
	_start_loop(_ambience_player, _engine_stream, 0.18)
	_detail_player.stop()
	_music_bed_player.stop()


func start_city_ambience() -> void:
	start_void_ambience()


func start_void_ambience() -> void:
	if _current_environment == &"void" and _ambience_player.playing:
		return
	_current_environment = &"void"
	_start_loop(_ambience_player, _city_stream, 0.15)
	_start_loop(_detail_player, _city_electric_stream, 0.060)
	_music_bed_player.stop()
	_environment_detail_timer = _rng.randf_range(4.5, 9.0)


func start_club_ambience() -> void:
	if _current_environment == &"club" and _ambience_player.playing:
		return
	_current_environment = &"club"
	_start_loop(_ambience_player, _city_stream, 0.105)
	_start_loop(_detail_player, _city_electric_stream, 0.055)
	_music_bed_player.stop()
	_environment_detail_timer = _rng.randf_range(5.0, 10.0)


func start_chamber_ambience() -> void:
	if _current_environment == &"chamber" and _ambience_player.playing:
		return
	_current_environment = &"chamber"
	_start_loop(_ambience_player, _wind_stream, 0.10)
	_start_loop(_detail_player, _lantern_stream, 0.045)
	_music_bed_player.stop()
	_environment_detail_timer = _rng.randf_range(5.0, 11.0)


func stop_environment(fade_seconds: float = 0.5) -> void:
	_current_environment = &""
	_fade_out_player(_ambience_player, fade_seconds)
	_fade_out_player(_detail_player, fade_seconds)
	_fade_out_player(_music_bed_player, fade_seconds)


func duck_for_dialogue(enabled: bool) -> void:
	_dialogue_ducked = enabled
	var ambience_target: float = 0.045 if enabled else _resolved_ambience_volume()
	var detail_target: float = 0.020 if enabled else _resolved_detail_volume()
	var bed_target: float = 0.025 if enabled else (0.085 if _current_environment == &"cemetery" else 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_ambience_player, "volume_linear", ambience_target, 0.35)
	tween.tween_property(_detail_player, "volume_linear", detail_target, 0.35)
	tween.tween_property(_music_bed_player, "volume_linear", bed_target, 0.35)


func play_footstep(intensity: float = 0.5) -> void:
	var external_cue: String = "footstep_grass" if _current_environment == &"cemetery" else "footstep_concrete"
	var external_stream: AudioStream = OnlineAudioLibrary.get_stream(external_cue)
	var player: AudioStreamPlayer = _next_one_shot_player()
	player.stream = external_stream if external_stream != null else _footstep_stream
	player.bus = "SFX"
	player.volume_linear = lerpf(0.10, 0.22, clampf(intensity, 0.0, 1.0))
	player.pitch_scale = _rng.randf_range(0.92, 1.08)
	player.play()


func play_interaction(context: String = "") -> void:
	var normalized_context: String = context.to_upper()
	var cue_id: String = "ui_confirm"
	if normalized_context.contains("READ") or normalized_context.contains("EXAMINE"):
		cue_id = "interaction_read"
	elif normalized_context.contains("RESTORE"):
		cue_id = "interaction_restore"
	elif normalized_context.contains("STABILIZE"):
		cue_id = "interaction_stabilize"
	var external_stream: AudioStream = OnlineAudioLibrary.get_stream(cue_id)
	_play_one_shot(external_stream if external_stream != null else _interaction_stream, 0.28, _rng.randf_range(0.97, 1.03), "SFX")


func play_reveal() -> void:
	var external_stream: AudioStream = OnlineAudioLibrary.get_stream("reveal")
	_play_one_shot(external_stream if external_stream != null else _reveal_stream, 0.34, 1.0, "SFX")


func play_transition() -> void:
	var external_stream: AudioStream = OnlineAudioLibrary.get_stream("transition")
	_play_one_shot(external_stream if external_stream != null else _reveal_stream, 0.30, 0.96, "SFX")


func play_jump() -> void:
	_play_one_shot(_jump_stream, 0.16, _rng.randf_range(0.96, 1.04), "SFX")


func play_land() -> void:
	var external_stream: AudioStream = OnlineAudioLibrary.get_stream("impact_metal")
	_play_one_shot(external_stream if external_stream != null else _land_stream, 0.20, _rng.randf_range(0.90, 1.02), "SFX")


func play_ui_hover() -> void:
	if _ui_hover_cooldown > 0.0:
		return
	_ui_hover_cooldown = 0.055
	var stream: AudioStream = OnlineAudioLibrary.get_stream("ui_hover")
	if stream != null:
		_play_one_shot(stream, 0.11, _rng.randf_range(0.98, 1.04), "UI")
	else:
		_play_one_shot(_interaction_stream, 0.065, 1.22, "UI")


func play_ui_confirm() -> void:
	var stream: AudioStream = OnlineAudioLibrary.get_stream("ui_confirm")
	_play_one_shot(stream if stream != null else _interaction_stream, 0.18, 1.0, "UI")


func play_ui_cancel() -> void:
	var stream: AudioStream = OnlineAudioLibrary.get_stream("ui_cancel")
	_play_one_shot(stream if stream != null else _interaction_stream, 0.15, 0.82, "UI")


func play_dialogue_tick() -> void:
	if _dialogue_tick_cooldown > 0.0:
		return
	_dialogue_tick_cooldown = 0.045
	var stream: AudioStream = OnlineAudioLibrary.get_stream("dialogue_tick")
	if stream != null:
		_play_one_shot(stream, 0.045, _rng.randf_range(1.12, 1.28), "Dialogue")


func play_dialogue_choice() -> void:
	var stream: AudioStream = OnlineAudioLibrary.get_stream("dialogue_choice")
	_play_one_shot(stream if stream != null else _interaction_stream, 0.18, 1.04, "Dialogue")


func play_world_cue(
	cue_id: String,
	world_position: Vector3,
	volume: float = 0.18,
	pitch: float = 1.0,
	max_distance: float = 28.0
) -> void:
	var stream: AudioStream = OnlineAudioLibrary.get_stream(cue_id)
	if stream == null:
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "WorldSFX_%s" % cue_id
	player.stream = stream
	player.position = world_position
	player.volume_linear = volume
	player.pitch_scale = pitch
	player.max_distance = max_distance
	player.unit_size = 4.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()


func _on_music_cue_started(cue_id: String) -> void:
	if cue_id.begins_with("pontiac"):
		start_pontiac_ambience()


func _update_player_sfx(delta: float) -> void:
	var candidate: Node = get_tree().get_first_node_in_group("player")
	var player: CharacterBody3D = candidate as CharacterBody3D
	if player != _tracked_player:
		_tracked_player = player
		_step_timer = 0.0
		_was_on_floor = player != null and player.is_on_floor()

	if _tracked_player == null:
		return

	var on_floor: bool = _tracked_player.is_on_floor()
	var planar_speed: float = Vector2(_tracked_player.velocity.x, _tracked_player.velocity.z).length()
	var max_reference_speed: float = 8.0
	var movement_intensity: float = clampf(planar_speed / max_reference_speed, 0.0, 1.0)

	if on_floor and planar_speed > 0.7:
		_step_timer -= delta
		if _step_timer <= 0.0:
			play_footstep(movement_intensity)
			_step_timer = lerpf(0.48, 0.29, movement_intensity)
	else:
		_step_timer = 0.0

	if not _was_on_floor and on_floor:
		play_land()
	elif _was_on_floor and not on_floor and _tracked_player.velocity.y > 0.5:
		play_jump()

	_was_on_floor = on_floor


func _update_environment_details(delta: float) -> void:
	if _current_environment == &"" or _tracked_player == null or _dialogue_ducked:
		return
	_environment_detail_timer -= delta
	if _environment_detail_timer > 0.0:
		return

	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(7.0, 16.0)
	var detail_position: Vector3 = _tracked_player.global_position + Vector3(cos(angle) * radius, _rng.randf_range(0.5, 4.0), sin(angle) * radius)
	match _current_environment:
		&"cemetery":
			var creak_stream: AudioStream = OnlineAudioLibrary.get_stream("creak")
			if creak_stream != null:
				play_world_cue("creak", detail_position, 0.12, _rng.randf_range(0.88, 1.08), 25.0)
			else:
				_play_one_shot(_creak_stream, 0.08, _rng.randf_range(0.82, 1.12), "Ambience")
			_environment_detail_timer = _rng.randf_range(5.0, 12.0)
		&"void":
			play_world_cue("void_pulse", detail_position, 0.12, _rng.randf_range(0.82, 1.08), 40.0)
			_environment_detail_timer = _rng.randf_range(4.0, 9.0)
		&"club":
			play_world_cue("impact_metal", detail_position, 0.09, _rng.randf_range(0.82, 1.12), 32.0)
			_environment_detail_timer = _rng.randf_range(5.0, 11.0)
		&"chamber":
			play_world_cue("journal", detail_position, 0.08, _rng.randf_range(0.82, 1.04), 28.0)
			_environment_detail_timer = _rng.randf_range(6.0, 13.0)
		_:
			_environment_detail_timer = _rng.randf_range(8.0, 15.0)


func _build_audio_buses() -> void:
	_ensure_bus("Music", "Master")
	_ensure_bus("Ambience", "Master")
	_ensure_bus("SFX", "Master")
	_ensure_bus("Dialogue", "Master")
	_ensure_bus("UI", "Master")

	var ambience_index: int = AudioServer.get_bus_index("Ambience")
	if ambience_index >= 0 and AudioServer.get_bus_effect_count(ambience_index) == 0:
		var reverb: AudioEffectReverb = AudioEffectReverb.new()
		reverb.room_size = 0.74
		reverb.damping = 0.58
		reverb.spread = 0.86
		reverb.hipass = 0.12
		reverb.dry = 0.78
		reverb.wet = 0.24
		AudioServer.add_bus_effect(ambience_index, reverb)

	var dialogue_index: int = AudioServer.get_bus_index("Dialogue")
	if dialogue_index >= 0 and AudioServer.get_bus_effect_count(dialogue_index) == 0:
		var dialogue_reverb: AudioEffectReverb = AudioEffectReverb.new()
		dialogue_reverb.room_size = 0.38
		dialogue_reverb.damping = 0.72
		dialogue_reverb.spread = 0.62
		dialogue_reverb.dry = 0.90
		dialogue_reverb.wet = 0.10
		AudioServer.add_bus_effect(dialogue_index, dialogue_reverb)


func _ensure_bus(bus_name: String, send_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_name)


func _resolved_ambience_volume() -> float:
	match _current_environment:
		&"cemetery":
			return 0.20
		&"pontiac":
			return 0.18
		&"void":
			return 0.15
		&"club":
			return 0.105
		&"chamber":
			return 0.10
		_:
			return 0.0


func _resolved_detail_volume() -> float:
	match _current_environment:
		&"cemetery":
			return 0.10
		&"void":
			return 0.060
		&"club":
			return 0.055
		&"chamber":
			return 0.045
		_:
			return 0.0


func _create_player(player_name: String, initial_volume: float, bus_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.volume_linear = initial_volume
	player.bus = bus_name
	add_child(player)
	return player


func _start_loop(player: AudioStreamPlayer, stream: AudioStreamWAV, volume: float) -> void:
	player.stop()
	player.stream = stream
	player.pitch_scale = 1.0
	player.volume_linear = volume
	player.play()


func _fade_out_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null or not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_linear", 0.0, maxf(0.05, fade_seconds))
	tween.tween_callback(Callable(player, "stop"))


func _play_one_shot(stream: AudioStream, volume: float, pitch: float, bus_name: String = "SFX") -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_one_shot_player()
	player.stream = stream
	player.bus = bus_name
	player.volume_linear = volume
	player.pitch_scale = pitch
	player.play()


func _next_one_shot_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _one_shot_players[_one_shot_index]
	_one_shot_index = (_one_shot_index + 1) % _one_shot_players.size()
	player.stop()
	return player


func _build_wind_stream() -> AudioStreamWAV:
	var duration: float = 4.0
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var slow_motion: float = sin(TAU * 0.25 * time) * 0.10
		var mid_motion: float = sin(TAU * 0.50 * time + 1.4) * 0.055
		var air: float = sin(TAU * 43.0 * time) * (0.012 + 0.008 * sin(TAU * 0.25 * time))
		samples[index] = slow_motion + mid_motion + air
	return _make_wav(samples, true)


func _build_lantern_stream() -> AudioStreamWAV:
	var duration: float = 2.0
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var pulse_times: Array[float] = [0.24, 0.71, 1.16, 1.62]
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = sin(TAU * 72.0 * time) * 0.012
		for pulse_time: float in pulse_times:
			var age: float = time - pulse_time
			if age >= 0.0 and age < 0.055:
				sample += sin(TAU * 1250.0 * age) * exp(-age * 75.0) * 0.16
		samples[index] = sample
	return _make_wav(samples, true)


func _build_cemetery_music_stream() -> AudioStreamWAV:
	var duration: float = 16.0
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var notes: Array[float] = [55.0, 110.0, 130.81, 164.81, 220.0]
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var cycle: float = time / duration
		var breath: float = 0.45 + 0.55 * pow(sin(PI * cycle), 2.0)
		var movement: float = 0.82 + 0.18 * sin(TAU * 0.0625 * time)
		var sample: float = 0.0
		for note_index: int in range(notes.size()):
			var note_volume: float = 0.050 / float(note_index + 1)
			var phase_offset: float = float(note_index) * 0.73
			sample += sin(TAU * notes[note_index] * time + phase_offset) * note_volume
			sample += sin(TAU * notes[note_index] * 0.5 * time + phase_offset) * note_volume * 0.35
		var shimmer: float = sin(TAU * 392.0 * time) * (0.004 + 0.003 * sin(TAU * 0.125 * time))
		samples[index] = (sample * breath * movement) + shimmer
	return _make_wav(samples, true)


func _build_engine_stream() -> AudioStreamWAV:
	var duration: float = 2.0
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var pulse: float = sin(TAU * 36.0 * time) * 0.16
		var harmonic: float = sin(TAU * 72.0 * time) * 0.07
		var road: float = sin(TAU * 108.0 * time) * 0.025
		samples[index] = pulse + harmonic + road
	return _make_wav(samples, true)


func _build_city_stream() -> AudioStreamWAV:
	var duration: float = 6.0
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var transformer: float = sin(TAU * 50.0 * time) * 0.07
		var harmonic: float = sin(TAU * 100.0 * time) * 0.025
		var distant_air: float = sin(TAU * 31.0 * time + sin(TAU * 0.17 * time)) * 0.035
		var pulse: float = sin(TAU * 0.18 * time) * 0.018
		samples[index] = transformer + harmonic + distant_air + pulse
	return _make_wav(samples, true)


func _build_city_electric_stream() -> AudioStreamWAV:
	var duration: float = 3.0
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var pulse_times: Array[float] = [0.33, 0.91, 1.72, 2.42]
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = sin(TAU * 118.0 * time) * 0.012
		for pulse_time: float in pulse_times:
			var age: float = time - pulse_time
			if age >= 0.0 and age < 0.11:
				sample += sin(TAU * 1720.0 * age) * exp(-age * 38.0) * 0.11
		samples[index] = sample
	return _make_wav(samples, true)


func _build_city_siren_stream() -> AudioStreamWAV:
	var duration: float = 3.5
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var envelope: float = pow(sin(progress * PI), 2.0)
		var sweep: float = 420.0 + sin(TAU * 0.42 * time) * 105.0
		samples[index] = sin(TAU * sweep * time) * envelope * 0.13
	return _make_wav(samples, false)


func _build_footstep_stream() -> AudioStreamWAV:
	var duration: float = 0.16
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 51019
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 28.0)
		var thump: float = sin(TAU * 92.0 * time) * 0.52
		var grit: float = rng.randf_range(-1.0, 1.0) * 0.14
		samples[index] = (thump + grit) * envelope
	return _make_wav(samples, false)


func _build_chime_stream(start_frequency: float, end_frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var frequency: float = lerpf(start_frequency, end_frequency, progress)
		var envelope: float = exp(-time * 7.5)
		samples[index] = sin(TAU * frequency * time) * envelope * 0.42
	return _make_wav(samples, false)


func _build_reveal_stream() -> AudioStreamWAV:
	var duration: float = 1.25
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var envelope: float = sin(progress * PI)
		var tone: float = sin(TAU * (115.0 + 90.0 * progress) * time) * 0.24
		var shimmer: float = sin(TAU * 710.0 * time) * 0.05
		samples[index] = (tone + shimmer) * envelope
	return _make_wav(samples, false)


func _build_land_stream() -> AudioStreamWAV:
	var duration: float = 0.22
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 66813
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 20.0)
		var low_hit: float = sin(TAU * 58.0 * time) * 0.62
		var grit: float = rng.randf_range(-1.0, 1.0) * 0.09
		samples[index] = (low_hit + grit) * envelope
	return _make_wav(samples, false)


func _build_creak_stream() -> AudioStreamWAV:
	var duration: float = 0.85
	var sample_count: int = int(duration * float(SAMPLE_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in range(sample_count):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var frequency: float = lerpf(210.0, 78.0, progress)
		var envelope: float = sin(progress * PI) * 0.7
		samples[index] = sin(TAU * frequency * time) * envelope * 0.24
	return _make_wav(samples, false)


func _make_wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for index: int in range(samples.size()):
		var sample: float = clampf(samples[index], -1.0, 1.0)
		data.encode_s16(index * 2, int(sample * 32767.0))

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
