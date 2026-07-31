extends Node

const SAMPLE_RATE: int = 22050
const ONE_SHOT_POOL_SIZE: int = 6

var _ambience_player: AudioStreamPlayer
var _detail_player: AudioStreamPlayer
var _one_shot_players: Array[AudioStreamPlayer] = []
var _one_shot_index: int = 0
var _current_environment: StringName = &""

var _wind_stream: AudioStreamWAV
var _lantern_stream: AudioStreamWAV
var _engine_stream: AudioStreamWAV
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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 904211
	_ambience_player = _create_player("EnvironmentAmbience", 0.22)
	_detail_player = _create_player("EnvironmentDetail", 0.13)

	for index: int in range(ONE_SHOT_POOL_SIZE):
		var player: AudioStreamPlayer = _create_player("SFXPlayer%d" % (index + 1), 0.35)
		_one_shot_players.append(player)

	_wind_stream = _build_wind_stream()
	_lantern_stream = _build_lantern_stream()
	_engine_stream = _build_engine_stream()
	_footstep_stream = _build_footstep_stream()
	_interaction_stream = _build_chime_stream(620.0, 930.0, 0.38)
	_reveal_stream = _build_reveal_stream()
	_jump_stream = _build_chime_stream(180.0, 270.0, 0.20)
	_land_stream = _build_land_stream()
	_creak_stream = _build_creak_stream()
	MusicDirector.cue_started.connect(_on_music_cue_started)


func _process(delta: float) -> void:
	_update_player_sfx(delta)
	_update_environment_details(delta)


func start_cemetery_ambience() -> void:
	if _current_environment == &"cemetery" and _ambience_player.playing:
		return
	_current_environment = &"cemetery"
	_start_loop(_ambience_player, _wind_stream, 0.22)
	_start_loop(_detail_player, _lantern_stream, 0.11)
	_environment_detail_timer = _rng.randf_range(5.0, 10.0)


func start_pontiac_ambience() -> void:
	if _current_environment == &"pontiac" and _ambience_player.playing:
		return
	_current_environment = &"pontiac"
	_start_loop(_ambience_player, _engine_stream, 0.18)
	_detail_player.stop()


func stop_environment(fade_seconds: float = 0.5) -> void:
	_current_environment = &""
	_fade_out_player(_ambience_player, fade_seconds)
	_fade_out_player(_detail_player, fade_seconds)


func play_footstep(intensity: float = 0.5) -> void:
	var player: AudioStreamPlayer = _next_one_shot_player()
	player.stream = _footstep_stream
	player.volume_linear = lerpf(0.16, 0.28, clampf(intensity, 0.0, 1.0))
	player.pitch_scale = _rng.randf_range(0.92, 1.08)
	player.play()


func play_interaction() -> void:
	_play_one_shot(_interaction_stream, 0.32, _rng.randf_range(0.97, 1.03))


func play_reveal() -> void:
	_play_one_shot(_reveal_stream, 0.36, 1.0)


func play_jump() -> void:
	_play_one_shot(_jump_stream, 0.20, _rng.randf_range(0.96, 1.04))


func play_land() -> void:
	_play_one_shot(_land_stream, 0.28, _rng.randf_range(0.94, 1.02))


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
	if _current_environment != &"cemetery":
		return
	_environment_detail_timer -= delta
	if _environment_detail_timer > 0.0:
		return
	_play_one_shot(_creak_stream, 0.11, _rng.randf_range(0.82, 1.12))
	_environment_detail_timer = _rng.randf_range(6.0, 14.0)


func _create_player(player_name: String, initial_volume: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.volume_linear = initial_volume
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


func _play_one_shot(stream: AudioStreamWAV, volume: float, pitch: float) -> void:
	var player: AudioStreamPlayer = _next_one_shot_player()
	player.stream = stream
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
