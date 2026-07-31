extends Node

const SAMPLE_RATE: int = 22050
const ONE_SHOT_COUNT: int = 6

var _one_shots: Array[AudioStreamPlayer] = []
var _one_shot_index: int = 0
var _pressure_player: AudioStreamPlayer

var _gate_stream: AudioStreamWAV
var _grab_stream: AudioStreamWAV
var _pressure_stream: AudioStreamWAV
var _correct_stream: AudioStreamWAV
var _wrong_stream: AudioStreamWAV
var _success_stream: AudioStreamWAV
var _death_stream: AudioStreamWAV


func _ready() -> void:
	_gate_stream = _build_gate_attempt_stream()
	_grab_stream = _build_grab_stream()
	_pressure_stream = _build_pressure_stream()
	_correct_stream = _build_correct_stream()
	_wrong_stream = _build_wrong_stream()
	_success_stream = _build_success_stream()
	_death_stream = _build_death_stream()
	_pressure_player = _make_player("GatePressure", "Ambience")
	for index: int in range(ONE_SHOT_COUNT):
		_one_shots.append(_make_player("GateScareOneShot%d" % index, "SFX"))


func play_gate_attempt() -> void:
	_play_one_shot(_gate_stream, 0.36, 0.92)


func play_grab() -> void:
	_play_one_shot(_grab_stream, 0.62, 0.84)
	_start_pressure()


func play_correct(step_index: int) -> void:
	_play_one_shot(_correct_stream, 0.25, 0.94 + float(step_index) * 0.055)


func play_wrong(chances_left: int) -> void:
	_play_one_shot(_wrong_stream, 0.52, 0.78 + float(chances_left) * 0.04)


func play_success() -> void:
	_stop_pressure(0.55)
	_play_one_shot(_success_stream, 0.54, 1.0)


func play_death() -> void:
	_stop_pressure(0.10)
	_play_one_shot(_death_stream, 0.72, 0.76)


func stop(fade_seconds: float = 0.8) -> void:
	_stop_pressure(fade_seconds)
	for player: AudioStreamPlayer in _one_shots:
		_fade_player(player, minf(fade_seconds, 0.35))


func _start_pressure() -> void:
	_pressure_player.stop()
	_pressure_player.stream = _pressure_stream
	_pressure_player.volume_linear = 0.20
	_pressure_player.pitch_scale = 1.0
	_pressure_player.play()


func _stop_pressure(fade_seconds: float) -> void:
	_fade_player(_pressure_player, fade_seconds)


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


func _fade_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if player == null or not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_linear", 0.0, maxf(0.05, fade_seconds))
	tween.tween_callback(Callable(player, "stop"))


func _build_gate_attempt_stream() -> AudioStreamWAV:
	var duration: float = 2.4
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var envelope: float = sin(progress * PI)
		var frequency: float = lerpf(92.0, 410.0, progress)
		var sample: float = sin(TAU * frequency * time) * 0.28
		sample += sin(TAU * frequency * 1.5 * time) * 0.11
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_grab_stream() -> AudioStreamWAV:
	var duration: float = 1.35
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 913701
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 3.4)
		var sweep: float = lerpf(1850.0, 74.0, minf(1.0, time / duration))
		var shriek: float = sin(TAU * sweep * time + sin(time * 91.0) * 1.4) * 0.31
		var impact: float = sin(TAU * 42.0 * time) * exp(-time * 8.0) * 0.78
		var noise: float = rng.randf_range(-1.0, 1.0) * 0.19
		samples[index] = (shriek + impact + noise) * envelope
	return _make_wav(samples, false)


func _build_pressure_stream() -> AudioStreamWAV:
	var duration: float = 2.0
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var beat_phase: float = fmod(time, 0.62)
		var heartbeat: float = sin(TAU * 48.0 * beat_phase) * exp(-beat_phase * 13.0) * 0.48
		var drone: float = sin(TAU * 31.0 * time) * 0.13
		drone += sin(TAU * 46.0 * time + sin(time * 0.8)) * 0.08
		samples[index] = heartbeat + drone
	return _make_wav(samples, true)


func _build_correct_stream() -> AudioStreamWAV:
	var duration: float = 0.22
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 18.0)
		var sample: float = sin(TAU * 720.0 * time) * 0.30
		sample += sin(TAU * 1080.0 * time) * 0.12
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_wrong_stream() -> AudioStreamWAV:
	var duration: float = 0.48
	var samples: PackedFloat32Array = _new_samples(duration)
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 8.5)
		var sample: float = sin(TAU * 116.0 * time) * 0.58
		sample += sin(TAU * 73.0 * time) * 0.26
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_success_stream() -> AudioStreamWAV:
	var duration: float = 4.4
	var samples: PackedFloat32Array = _new_samples(duration)
	var notes: Array[float] = [261.63, 329.63, 392.0, 523.25, 659.25]
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var progress: float = time / duration
		var envelope: float = pow(sin(progress * PI), 0.72)
		var sample: float = 0.0
		for note_index: int in range(notes.size()):
			var onset: float = float(note_index) * 0.22
			var age: float = maxf(0.0, time - onset)
			if time >= onset:
				sample += sin(TAU * notes[note_index] * age) * 0.075
				sample += sin(TAU * notes[note_index] * 2.0 * age) * 0.018
		samples[index] = sample * envelope
	return _make_wav(samples, false)


func _build_death_stream() -> AudioStreamWAV:
	var duration: float = 2.0
	var samples: PackedFloat32Array = _new_samples(duration)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33719
	for index: int in range(samples.size()):
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = exp(-time * 2.6)
		var sample: float = sin(TAU * 32.0 * time) * 0.88
		sample += sin(TAU * 61.0 * time) * 0.30
		sample += rng.randf_range(-1.0, 1.0) * 0.22
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
