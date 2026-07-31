extends Node

const SAMPLE_RATE: int = 22050

var _choir_player: AudioStreamPlayer
var _breeze_player: AudioStreamPlayer
var _corruption_player: AudioStreamPlayer
var _heartbeat_player: AudioStreamPlayer
var _one_shot_player: AudioStreamPlayer

var _choir_stream: AudioStreamWAV
var _breeze_stream: AudioStreamWAV
var _corruption_stream: AudioStreamWAV
var _heartbeat_stream: AudioStreamWAV
var _bell_stream: AudioStreamWAV
var _whisper_stream: AudioStreamWAV
var _gate_stream: AudioStreamWAV

var _corruption: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 13061998
	_choir_stream = _build_choir_stream()
	_breeze_stream = _build_breeze_stream()
	_corruption_stream = _build_corruption_stream()
	_heartbeat_stream = _build_heartbeat_stream()
	_bell_stream = _build_bell_stream()
	_whisper_stream = _build_whisper_stream()
	_gate_stream = _build_gate_stream()

	_choir_player = _make_player("HeavenChoir", "Ambience")
	_breeze_player = _make_player("HeavenBreeze", "Ambience")
	_corruption_player = _make_player("HeavenCorruption", "Ambience")
	_heartbeat_player = _make_player("HeavenHeartbeat", "Ambience")
	_one_shot_player = _make_player("HeavenOneShot", "SFX")


func start() -> void:
	_start_loop(_choir_player, _choir_stream, 0.19)
	_start_loop(_breeze_player, _breeze_stream, 0.11)
	_start_loop(_corruption_player, _corruption_stream, 0.0)
	_start_loop(_heartbeat_player, _heartbeat_stream, 0.0)


func set_corruption(value: float) -> void:
	_corruption = clampf(value, 0.0, 1.0)
	var sanctity: float = 1.0 - _corruption
	_choir_player.volume_linear = lerpf(0.015, 0.19, pow(sanctity, 1.35))
	_choir_player.pitch_scale = lerpf(0.74, 1.0, sanctity)
	_breeze_player.volume_linear = lerpf(0.035, 0.11, sanctity)
	_breeze_player.pitch_scale = lerpf(0.72, 1.05, sanctity)
	_corruption_player.volume_linear = lerpf(0.0, 0.24, pow(_corruption, 1.25))
	_corruption_player.pitch_scale = lerpf(0.82, 1.12, _corruption)
	_heartbeat_player.volume_linear = lerpf(0.0, 0.17, maxf(0.0, (_corruption - 0.52) / 0.48))
	_heartbeat_player.pitch_scale = lerpf(0.82, 1.18, _corruption)


func play_threshold(darkening: bool) -> void:
	_one_shot_player.stop()
	_one_shot_player.stream = _bell_stream
	_one_shot_player.volume_linear = 0.20
	_one_shot_player.pitch_scale = 0.68 if darkening else 1.18
	_one_shot_player.play()


func play_gate_open() -> void:
	_one_shot_player.stop()
	_one_shot_player.stream = _gate_stream
	_one_shot_player.volume_linear = 0.38
	_one_shot_player.pitch_scale = 0.86
	_one_shot_player.play()


func play_directional_whisper(world_position: Vector3, intensity: float) -> void:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "AngelWhisper"
	player.stream = _whisper_stream
	player.position = world_position
	player.volume_linear = lerpf(0.06, 0.22, clampf(intensity, 0.0, 1.0))
	player.pitch_scale = _rng.randf_range(0.72, 1.08)
	player.max_distance = 34.0
	player.unit_size = 3.0
	player.bus = "Dialogue"
	add_child(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()


func stop(fade_seconds: float = 2.0) -> void:
	_fade_player(_choir_player, fade_seconds)
	_fade_player(_breeze_player, fade_seconds)
	_fade_player(_corruption_player, fade_seconds)
	_fade_player(_heartbeat_player, fade_seconds)
	_fade_player(_one_shot_player, minf(fade_seconds, 0.5))


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
	player.pitch_scale = 1.0
	player.play()


func _fade_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null or not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_linear", 0.0, maxf(0.05, fade_seconds))
	tween.tween_callback(Callable(player, "stop"))


func _build_choir_stream() -> AudioStreamWAV:
	var duration: float = 8.0
	var samples: PackedFloat32Array = _new_samples(duration)
	var notes: Array[float] = [110.0, 146.83, 164.81, 220.0, 293.66]
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var breath: float = 0.55 + sin(TAU * 0.0625 * time) * 0.25
		var sample: float = 0.0
		for note_index: int in range(notes.size()):
			var phase: float = float(note_index) * 0.72
			var weight: float = 0.052 / float(note_index + 1)
			sample += sin(TAU * notes[note_index] * time + phase) * weight
			sample += sin(TAU * notes[note_index] * 2.0 * time + phase) * weight * 0.18
		samples[index] = sample * breath
	return _make_wav(samples, true)


func _build_breeze_stream() -> AudioStreamWAV:
	var duration: float = 5.0
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 72131
	var filtered: float = 0.0
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.018)
		var shimmer: float = sin(TAU * 690.0 * time) * (0.003 + sin(time * 0.5) * 0.001)
		samples[index] = filtered * 0.10 + shimmer
	return _make_wav(samples, true)


func _build_corruption_stream() -> AudioStreamWAV:
	var duration: float = 6.0
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var pulse: float = 0.72 + sin(TAU * 0.19 * time) * 0.24
		var sample: float = sin(TAU * 37.0 * time) * 0.18
		sample += sin(TAU * 51.0 * time + sin(time * 0.7)) * 0.10
		sample += sin(TAU * 73.0 * time) * 0.035
		samples[index] = sample * pulse
	return _make_wav(samples, true)


func _build_heartbeat_stream() -> AudioStreamWAV:
	var duration: float = 1.4
	var samples: PackedFloat32Array = _new_samples(duration)
	var beats: Array[float] = [0.10, 0.36]
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for beat_time: float in beats:
			var age: float = fmod(maxf(0.0, time - beat_time), duration)
			if time >= beat_time and age < 0.24:
				sample += sin(TAU * 48.0 * age) * exp(-age * 17.0) * 0.54
		samples[index] = sample
	return _make_wav(samples, true)


func _build_bell_stream() -> AudioStreamWAV:
	var duration: float = 2.2
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 2.1)
		var sample: float = sin(TAU * 523.25 * time) * 0.28
		sample += sin(TAU * 784.88 * time) * 0.14
		sample += sin(TAU * 1046.50 * time) * 0.06
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_whisper_stream() -> AudioStreamWAV:
	var duration: float = 1.9
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11173
	var filtered: float = 0.0
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.10)
		var envelope: float = pow(sin(progress * PI), 1.4)
		var vowel: float = sin(TAU * (176.0 + sin(time * 3.1) * 32.0) * time) * 0.08
		samples[index] = (filtered * 0.16 + vowel) * envelope
	return _make_wav(samples, false)


func _build_gate_stream() -> AudioStreamWAV:
	var duration: float = 3.2
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var frequency: float = lerpf(58.0, 310.0, progress)
		var envelope: float = sin(progress * PI)
		var sample: float = sin(TAU * frequency * time) * 0.34
		sample += sin(TAU * frequency * 1.5 * time) * 0.12
		samples[index] = sample * envelope
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
