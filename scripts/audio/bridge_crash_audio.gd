extends Node

const SAMPLE_RATE: int = 22050
const ONE_SHOT_POOL_SIZE: int = 8

var _one_shots: Array[AudioStreamPlayer] = []
var _one_shot_index: int = 0
var _screech_player: AudioStreamPlayer
var _tinnitus_player: AudioStreamPlayer

var _screech_stream: AudioStreamWAV
var _impact_stream: AudioStreamWAV
var _glass_stream: AudioStreamWAV
var _metal_stream: AudioStreamWAV
var _tinnitus_stream: AudioStreamWAV
var _heartbeat_stream: AudioStreamWAV


func _ready() -> void:
	_screech_stream = _build_screech_stream()
	_impact_stream = _build_impact_stream()
	_glass_stream = _build_glass_stream()
	_metal_stream = _build_metal_stream()
	_tinnitus_stream = _build_tinnitus_stream()
	_heartbeat_stream = _build_heartbeat_stream()

	_screech_player = _make_player("CrashTireScreech", "SFX")
	_tinnitus_player = _make_player("CrashTinnitus", "Ambience")
	for index: int in range(ONE_SHOT_POOL_SIZE):
		_one_shots.append(_make_player("CrashOneShot%d" % index, "SFX"))


func play_tire_screech() -> void:
	_screech_player.stop()
	_screech_player.stream = _screech_stream
	_screech_player.volume_linear = 0.34
	_screech_player.pitch_scale = 1.0
	_screech_player.play()


func play_guardrail_hit(side: float) -> void:
	_play_one_shot(_metal_stream, 0.42, 0.88)
	var hit_position: Vector3 = Vector3(-5.0 if side < 0.0 else 5.0, 1.1, -4.0)
	_play_spatial(_metal_stream, hit_position, 0.32, 0.74, 32.0)


func play_major_impact() -> void:
	_play_one_shot(_impact_stream, 0.68, 0.82)
	SFXDirector.play_reveal()


func play_glass_burst() -> void:
	_play_one_shot(_glass_stream, 0.42, 1.0)
	var left_position: Vector3 = Vector3(-3.4, 2.0, -2.0)
	var right_position: Vector3 = Vector3(3.4, 2.0, -2.0)
	_play_spatial(_glass_stream, left_position, 0.18, 0.91, 24.0)
	_play_spatial(_glass_stream, right_position, 0.18, 1.08, 24.0)


func play_heartbeat() -> void:
	_play_one_shot(_heartbeat_stream, 0.34, 0.82)


func start_tinnitus() -> void:
	_tinnitus_player.stop()
	_tinnitus_player.stream = _tinnitus_stream
	_tinnitus_player.volume_linear = 0.18
	_tinnitus_player.pitch_scale = 1.0
	_tinnitus_player.play()


func stop_all(fade_seconds: float = 1.5) -> void:
	_fade_player(_screech_player, fade_seconds)
	_fade_player(_tinnitus_player, fade_seconds)
	for player: AudioStreamPlayer in _one_shots:
		_fade_player(player, minf(fade_seconds, 0.45))


func _make_player(player_name: String, bus_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	add_child(player)
	return player


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


func _play_spatial(
	stream: AudioStream,
	world_position: Vector3,
	volume: float,
	pitch: float,
	max_distance: float
) -> void:
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


func _fade_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null or not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_linear", 0.0, maxf(0.05, fade_seconds))
	tween.tween_callback(Callable(player, "stop"))


func _build_screech_stream() -> AudioStreamWAV:
	var duration: float = 2.8
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 201771
	var filtered_noise: float = 0.0
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.16)
		var frequency: float = lerpf(1560.0, 510.0, progress)
		var envelope: float = sin(progress * PI)
		var tone: float = sin(TAU * frequency * time + sin(time * 58.0) * 0.8)
		samples[index] = (tone * 0.24 + filtered_noise * 0.18) * envelope
	return _make_wav(samples)


func _build_impact_stream() -> AudioStreamWAV:
	var duration: float = 1.4
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 55091
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 4.2)
		var sub_hit: float = sin(TAU * 38.0 * time) * 0.82
		var body_hit: float = sin(TAU * 91.0 * time) * 0.34
		var debris: float = rng.randf_range(-1.0, 1.0) * 0.24
		samples[index] = (sub_hit + body_hit + debris) * envelope
	return _make_wav(samples)


func _build_glass_stream() -> AudioStreamWAV:
	var duration: float = 1.25
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 90517
	var shard_times: Array[float] = [0.02, 0.08, 0.15, 0.25, 0.39, 0.56, 0.82]
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for shard_index: int in range(shard_times.size()):
			var age: float = time - shard_times[shard_index]
			if age >= 0.0 and age < 0.22:
				var frequency: float = 1560.0 + float(shard_index) * 317.0
				sample += sin(TAU * frequency * age) * exp(-age * 20.0) * 0.18
		sample += rng.randf_range(-1.0, 1.0) * exp(-time * 8.0) * 0.08
		samples[index] = sample
	return _make_wav(samples)


func _build_metal_stream() -> AudioStreamWAV:
	var duration: float = 1.8
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 2.8)
		var bend: float = 118.0 - time * 44.0
		var sample: float = sin(TAU * bend * time) * 0.38
		sample += sin(TAU * 226.0 * time) * 0.16
		sample += sin(TAU * 483.0 * time) * 0.06
		samples[index] = sample * envelope
	return _make_wav(samples)


func _build_tinnitus_stream() -> AudioStreamWAV:
	var duration: float = 4.0
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var envelope: float = pow(maxf(0.0, 1.0 - progress), 1.4)
		var frequency: float = 3420.0 + sin(time * 0.8) * 110.0
		samples[index] = sin(TAU * frequency * time) * envelope * 0.20
	return _make_wav(samples)


func _build_heartbeat_stream() -> AudioStreamWAV:
	var duration: float = 1.7
	var samples: PackedFloat32Array = _new_samples(duration)
	var beat_times: Array[float] = [0.12, 0.38, 1.02, 1.28]
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for beat_time: float in beat_times:
			var age: float = time - beat_time
			if age >= 0.0 and age < 0.22:
				sample += sin(TAU * 54.0 * age) * exp(-age * 18.0) * 0.58
		samples[index] = sample
	return _make_wav(samples)


func _new_samples(duration: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(duration * float(SAMPLE_RATE)))
	return samples


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
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
	return stream
