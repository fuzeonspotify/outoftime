extends Node

const SAMPLE_RATE: int = 22050
const ONE_SHOT_POOL_SIZE: int = 12

var _rumble_player: AudioStreamPlayer
var _wheel_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _metal_left: AudioStreamPlayer3D
var _metal_right: AudioStreamPlayer3D
var _one_shots: Array[AudioStreamPlayer] = []
var _one_shot_index: int = 0
var _intensity: float = 0.35
var _detail_timer: float = 2.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _rumble_stream: AudioStreamWAV
var _wheel_stream: AudioStreamWAV
var _wind_stream: AudioStreamWAV
var _metal_stream: AudioStreamWAV
var _horn_stream: AudioStreamWAV
var _impact_stream: AudioStreamWAV
var _spark_stream: AudioStreamWAV
var _brake_stream: AudioStreamWAV
var _switch_stream: AudioStreamWAV
var _pulse_stream: AudioStreamWAV


func _ready() -> void:
	_rng.seed = 731998
	_build_streams()
	_build_players()


func _process(delta: float) -> void:
	_detail_timer -= delta
	if _detail_timer <= 0.0:
		_play_moving_metal_detail()
		_detail_timer = _rng.randf_range(1.4, 3.4) / lerpf(0.85, 1.45, _intensity)


func start() -> void:
	_start_loop(_rumble_player, _rumble_stream, 0.18)
	_start_loop(_wheel_player, _wheel_stream, 0.17)
	_start_loop(_wind_player, _wind_stream, 0.08)
	MusicDirector.play_cue("rockstar_chase", 4.0)


func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _rumble_player != null:
		_rumble_player.pitch_scale = lerpf(0.92, 1.18, _intensity)
		_rumble_player.volume_linear = lerpf(0.14, 0.27, _intensity)
	if _wheel_player != null:
		_wheel_player.pitch_scale = lerpf(0.90, 1.30, _intensity)
		_wheel_player.volume_linear = lerpf(0.13, 0.25, _intensity)
	if _wind_player != null:
		_wind_player.pitch_scale = lerpf(0.88, 1.22, _intensity)
		_wind_player.volume_linear = lerpf(0.05, 0.16, _intensity)


func play_horn() -> void:
	_play_one_shot(_horn_stream, 0.48, 0.92)


func play_collision(side: float = 0.0) -> void:
	_play_one_shot(_impact_stream, 0.55, _rng.randf_range(0.88, 1.02))
	var position: Vector3 = Vector3(-5.5 if side < 0.0 else 5.5, 1.6, -2.0)
	_play_spatial(_metal_stream, position, 0.34, _rng.randf_range(0.82, 0.96), 34.0)


func play_sparks(side: float = 0.0) -> void:
	var position: Vector3 = Vector3(side * 4.6, 2.0, -4.0)
	_play_spatial(_spark_stream, position, 0.28, _rng.randf_range(0.94, 1.12), 28.0)


func play_brakes() -> void:
	_play_one_shot(_brake_stream, 0.35, 0.92)


func play_track_switch() -> void:
	_play_one_shot(_switch_stream, 0.38, 1.0)
	SFXDirector.play_transition()


func play_memory_pulse() -> void:
	_play_one_shot(_pulse_stream, 0.30, _rng.randf_range(0.94, 1.05))


func play_engine_overdrive() -> void:
	_play_horn_layered()
	_play_one_shot(_impact_stream, 0.28, 0.72)
	set_intensity(1.0)


func stop(fade_seconds: float = 2.5) -> void:
	_fade_player(_rumble_player, fade_seconds)
	_fade_player(_wheel_player, fade_seconds)
	_fade_player(_wind_player, fade_seconds)


func _build_players() -> void:
	_rumble_player = _make_player("TrainSubRumble", "Ambience")
	_wheel_player = _make_player("TrainWheelRhythm", "Ambience")
	_wind_player = _make_player("TrainWind", "Ambience")

	_metal_left = AudioStreamPlayer3D.new()
	_metal_left.name = "TrainMetalLeft"
	_metal_left.position = Vector3(-4.8, 1.3, 0.0)
	_metal_left.bus = "Ambience"
	_metal_left.max_distance = 32.0
	_metal_left.unit_size = 3.0
	add_child(_metal_left)

	_metal_right = AudioStreamPlayer3D.new()
	_metal_right.name = "TrainMetalRight"
	_metal_right.position = Vector3(4.8, 1.3, 0.0)
	_metal_right.bus = "Ambience"
	_metal_right.max_distance = 32.0
	_metal_right.unit_size = 3.0
	add_child(_metal_right)

	for index: int in range(ONE_SHOT_POOL_SIZE):
		var player: AudioStreamPlayer = _make_player("TrainOneShot%d" % index, "SFX")
		_one_shots.append(player)


func _make_player(player_name: String, bus_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	add_child(player)
	return player


func _start_loop(player: AudioStreamPlayer, stream: AudioStreamWAV, volume: float) -> void:
	player.stop()
	player.stream = stream
	player.volume_linear = volume
	player.play()


func _fade_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null or not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_linear", 0.0, maxf(0.1, fade_seconds))
	tween.tween_callback(Callable(player, "stop"))


func _play_one_shot(stream: AudioStream, volume: float, pitch: float) -> void:
	if stream == null or _one_shots.is_empty():
		return
	var player: AudioStreamPlayer = _one_shots[_one_shot_index]
	_one_shot_index = (_one_shot_index + 1) % _one_shots.size()
	player.stop()
	player.stream = stream
	player.volume_linear = volume
	player.pitch_scale = pitch
	player.play()


func _play_spatial(stream: AudioStream, world_position: Vector3, volume: float, pitch: float, max_distance: float) -> void:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = world_position
	player.volume_linear = volume
	player.pitch_scale = pitch
	player.max_distance = max_distance
	player.unit_size = 3.0
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()


func _play_moving_metal_detail() -> void:
	var player: AudioStreamPlayer3D = _metal_left if _rng.randf() < 0.5 else _metal_right
	player.stop()
	player.stream = _metal_stream
	player.volume_linear = lerpf(0.07, 0.17, _intensity)
	player.pitch_scale = _rng.randf_range(0.72, 1.18)
	player.play()


func _play_horn_layered() -> void:
	play_horn()
	await get_tree().create_timer(0.16).timeout
	_play_one_shot(_horn_stream, 0.30, 0.61)


func _build_streams() -> void:
	_rumble_stream = _build_rumble_stream()
	_wheel_stream = _build_wheel_stream()
	_wind_stream = _build_wind_stream()
	_metal_stream = _build_metal_stream()
	_horn_stream = _build_horn_stream()
	_impact_stream = _build_impact_stream()
	_spark_stream = _build_spark_stream()
	_brake_stream = _build_brake_stream()
	_switch_stream = _build_switch_stream()
	_pulse_stream = _build_pulse_stream()


func _build_rumble_stream() -> AudioStreamWAV:
	var duration: float = 4.0
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var modulation: float = 0.82 + sin(TAU * 0.42 * time) * 0.12
		var sample: float = sin(TAU * 31.0 * time) * 0.19
		sample += sin(TAU * 47.0 * time + 0.6) * 0.10
		sample += sin(TAU * 62.0 * time) * 0.045
		samples[index] = sample * modulation
	return _make_wav(samples, true)


func _build_wheel_stream() -> AudioStreamWAV:
	var duration: float = 2.0
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var beat_phase: float = fmod(time, 0.25)
		var second_phase: float = fmod(time + 0.125, 0.25)
		var beat: float = exp(-beat_phase * 55.0) * sin(TAU * 118.0 * beat_phase) * 0.30
		var second: float = exp(-second_phase * 55.0) * sin(TAU * 92.0 * second_phase) * 0.22
		var rail: float = sin(TAU * 184.0 * time) * 0.018
		samples[index] = beat + second + rail
	return _make_wav(samples, true)


func _build_wind_stream() -> AudioStreamWAV:
	var duration: float = 4.0
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 94021
	var filtered: float = 0.0
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.025)
		var sweep: float = 0.45 + sin(TAU * 0.18 * time) * 0.24
		samples[index] = filtered * sweep * 0.15 + sin(TAU * 73.0 * time) * 0.012
	return _make_wav(samples, true)


func _build_metal_stream() -> AudioStreamWAV:
	var duration: float = 1.1
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 3.7)
		var bend: float = 82.0 - time * 31.0
		var sample: float = sin(TAU * bend * time) * 0.28
		sample += sin(TAU * 173.0 * time) * 0.12
		sample += sin(TAU * 349.0 * time) * 0.045
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_horn_stream() -> AudioStreamWAV:
	var duration: float = 2.8
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var envelope: float = sin(progress * PI)
		var sample: float = sin(TAU * 92.0 * time) * 0.35
		sample += sin(TAU * 138.0 * time) * 0.22
		sample += sin(TAU * 184.0 * time) * 0.11
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_impact_stream() -> AudioStreamWAV:
	var duration: float = 0.8
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17291
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 8.0)
		var sample: float = sin(TAU * 48.0 * time) * 0.75
		sample += sin(TAU * 96.0 * time) * 0.26
		sample += rng.randf_range(-1.0, 1.0) * 0.24
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_spark_stream() -> AudioStreamWAV:
	var duration: float = 0.55
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 88231
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 6.5)
		var crackle: float = rng.randf_range(-1.0, 1.0)
		var tone: float = sin(TAU * (1100.0 + sin(time * 80.0) * 400.0) * time)
		samples[index] = (crackle * 0.38 + tone * 0.12) * envelope
	return _make_wav(samples, false)


func _build_brake_stream() -> AudioStreamWAV:
	var duration: float = 2.2
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var frequency: float = lerpf(2100.0, 360.0, progress)
		var envelope: float = sin(progress * PI)
		samples[index] = sin(TAU * frequency * time) * envelope * 0.24
	return _make_wav(samples, false)


func _build_switch_stream() -> AudioStreamWAV:
	var duration: float = 0.7
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var first: float = sin(TAU * 290.0 * time) * exp(-time * 18.0) * 0.42
		var age: float = maxf(0.0, time - 0.28)
		var second: float = sin(TAU * 170.0 * age) * exp(-age * 16.0) * 0.35
		samples[index] = first + second
	return _make_wav(samples, false)


func _build_pulse_stream() -> AudioStreamWAV:
	var duration: float = 1.25
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 2.8)
		var frequency: float = lerpf(55.0, 180.0, time / duration)
		samples[index] = sin(TAU * frequency * time) * envelope * 0.48
	return _make_wav(samples, false)


func _new_samples(duration: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(duration * float(SAMPLE_RATE)))
	return samples


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
