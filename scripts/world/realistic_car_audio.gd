extends Node

const ENGINE_AUDIO_PATH: String = "res://assets/audio/car/engine_loop.ogg"
const ROAD_AUDIO_PATH: String = "res://assets/audio/car/road_noise.ogg"
const REFERENCE_SPEED: float = 34.0
const LEGACY_MUTE_INTERVAL: float = 0.75

var _road: Node3D
var _car: Node3D
var _engine_low: AudioStreamPlayer3D
var _engine_high: AudioStreamPlayer3D
var _road_noise: AudioStreamPlayer3D
var _last_car_position: Vector3
var _smoothed_speed: float = 0.0
var _legacy_mute_remaining: float = 0.0
var _initialized: bool = false
var _missing_audio_reported: bool = false


func _ready() -> void:
	process_priority = 275
	set_process(true)
	var cue_callable: Callable = Callable(self, "_on_music_cue_started")
	if not MusicDirector.cue_started.is_connected(cue_callable):
		MusicDirector.cue_started.connect(cue_callable)
	_mute_legacy_procedural_engine.call_deferred()


func _process(delta: float) -> void:
	_legacy_mute_remaining -= delta
	if _legacy_mute_remaining <= 0.0:
		_legacy_mute_remaining = LEGACY_MUTE_INTERVAL
		_mute_legacy_procedural_engine()

	if not _initialized:
		_try_initialize()
		return
	if _car == null or not is_instance_valid(_car):
		_initialized = false
		return
	if delta <= 0.00001:
		return

	var current_position: Vector3 = _car.global_position
	var raw_speed: float = current_position.distance_to(_last_car_position) / delta
	_last_car_position = current_position
	var response: float = 1.0 - exp(-delta * 5.5)
	_smoothed_speed = lerpf(_smoothed_speed, raw_speed, response)
	_update_audio_mix()


func _try_initialize() -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return
	_car = _road.get("_car") as Node3D
	if _car == null or not is_instance_valid(_car):
		return

	if not ResourceLoader.exists(ENGINE_AUDIO_PATH) or not ResourceLoader.exists(ROAD_AUDIO_PATH):
		if not _missing_audio_reported:
			_missing_audio_reported = true
			push_error(
				"REALISTIC CAR AUDIO MISSING: run tools/install_freesound_car_audio.ps1, then reopen Godot."
			)
		set_process(false)
		return

	var engine_stream: AudioStreamOggVorbis = load(ENGINE_AUDIO_PATH) as AudioStreamOggVorbis
	var road_stream: AudioStreamOggVorbis = load(ROAD_AUDIO_PATH) as AudioStreamOggVorbis
	if engine_stream == null or road_stream == null:
		push_error("REALISTIC CAR AUDIO ERROR: one or both installed Ogg streams failed to load.")
		set_process(false)
		return

	engine_stream.loop = true
	road_stream.loop = true
	_engine_low = _create_vehicle_player("EngineLowLayer", engine_stream)
	_engine_high = _create_vehicle_player("EngineHighLayer", engine_stream)
	_road_noise = _create_vehicle_player("InteriorRoadLayer", road_stream)

	_engine_low.pitch_scale = 0.86
	_engine_high.pitch_scale = 1.08
	_road_noise.pitch_scale = 0.90
	_engine_low.play(0.0)
	_engine_high.play(5.7)
	_road_noise.play(7.0)

	_last_car_position = _car.global_position
	_initialized = true
	print("REALISTIC CAR AUDIO READY: quiet engine and interior-road layers are following Porsche speed.")


func _create_vehicle_player(
	player_name: String,
	stream: AudioStream
) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = stream
	player.position = Vector3(0.0, 0.72, 0.0)
	player.volume_linear = 0.0
	player.unit_size = 3.2
	player.max_distance = 30.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.bus = "SFX"
	_car.add_child(player)
	return player


func _update_audio_mix() -> void:
	if _engine_low == null or _engine_high == null or _road_noise == null:
		return

	var speed_ratio: float = clampf(_smoothed_speed / REFERENCE_SPEED, 0.0, 1.15)
	var low_weight: float = 1.0 - smoothstep(0.42, 1.02, speed_ratio)
	var high_weight: float = smoothstep(0.18, 0.94, speed_ratio)
	var road_weight: float = smoothstep(0.08, 0.82, speed_ratio)

	# Audio does not automatically slow with Engine.time_scale. Lower the pitch
	# during the authored wreck slow motion so sound and image remain connected.
	var time_ratio: float = clampf(Engine.time_scale, 0.0, 1.0)
	var slow_motion_pitch: float = lerpf(0.64, 1.0, time_ratio)
	var slow_motion_volume: float = lerpf(0.82, 1.0, time_ratio)

	_engine_low.pitch_scale = clampf(0.84 + speed_ratio * 0.25, 0.80, 1.16) * slow_motion_pitch
	_engine_high.pitch_scale = clampf(1.03 + speed_ratio * 0.32, 0.96, 1.40) * slow_motion_pitch
	_road_noise.pitch_scale = clampf(0.88 + speed_ratio * 0.18, 0.84, 1.12) * lerpf(0.82, 1.0, time_ratio)

	# The combined mix intentionally stays restrained beneath music, narration,
	# impacts, and the bridge ambience.
	_engine_low.volume_linear = (0.018 + 0.040 * low_weight) * slow_motion_volume
	_engine_high.volume_linear = 0.040 * high_weight * slow_motion_volume
	_road_noise.volume_linear = 0.034 * road_weight * slow_motion_volume


func _mute_legacy_procedural_engine() -> void:
	# SFXDirector previously supplied a synthesized Pontiac engine bed. Stop that
	# layer so it cannot phase against the real recordings or make the car loud.
	SFXDirector.stop_environment(0.12)


func _on_music_cue_started(cue_id: String) -> void:
	if cue_id.begins_with("pontiac"):
		_mute_legacy_procedural_engine.call_deferred()


func _exit_tree() -> void:
	var cue_callable: Callable = Callable(self, "_on_music_cue_started")
	if MusicDirector.cue_started.is_connected(cue_callable):
		MusicDirector.cue_started.disconnect(cue_callable)
