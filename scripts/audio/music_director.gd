extends Node

signal cue_started(cue_id: String)
signal cue_missing(cue_id: String, expected_path: String)

const CUES_PATH: String = "res://data/music_cues.json"
const MUSIC_VOLUME_LINEAR: float = 0.30

var _cues: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _active_index: int = 0


func _ready() -> void:
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.volume_linear = 0.0
		add_child(player)
		_players.append(player)
	_load_cues()


func _load_cues() -> void:
	if not FileAccess.file_exists(CUES_PATH):
		push_error("Music cue file is missing: %s" % CUES_PATH)
		return

	var file: FileAccess = FileAccess.open(CUES_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open music cue file: %s" % CUES_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Music cue file contains invalid JSON.")
		return
	_cues = parsed as Dictionary


func play_cue(cue_id: String, fade_seconds: float = 1.2, start_offset: float = 0.0) -> bool:
	if _should_suppress_cue(cue_id):
		return false
	if not _cues.has(cue_id):
		push_warning("Unknown music cue: %s" % cue_id)
		return false

	var cue: Dictionary = _cues[cue_id] as Dictionary
	var audio_path: String = str(cue.get("path", ""))
	if audio_path.is_empty() or not ResourceLoader.exists(audio_path):
		cue_missing.emit(cue_id, audio_path)
		push_warning("Music file not found for '%s': %s" % [cue_id, audio_path])
		return false

	var stream: AudioStream = load(audio_path) as AudioStream
	if stream == null:
		cue_missing.emit(cue_id, audio_path)
		push_warning("Could not load music file for '%s': %s" % [cue_id, audio_path])
		return false

	var previous_player: AudioStreamPlayer = _players[_active_index]
	var next_index: int = 1 - _active_index
	var next_player: AudioStreamPlayer = _players[next_index]

	next_player.stop()
	next_player.stream = stream
	next_player.volume_linear = 0.0
	next_player.play(maxf(0.0, start_offset))

	var duration: float = maxf(0.05, fade_seconds)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(previous_player, "volume_linear", 0.0, duration)
	tween.tween_property(next_player, "volume_linear", MUSIC_VOLUME_LINEAR, duration)
	await tween.finished

	previous_player.stop()
	_active_index = next_index
	cue_started.emit(cue_id)
	return true


func stop_music(fade_seconds: float = 1.0) -> void:
	if _players.is_empty():
		return
	var playing_players: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _players:
		if player.playing:
			playing_players.append(player)
	if playing_players.is_empty():
		return

	var duration: float = maxf(0.05, fade_seconds)
	var tween: Tween = create_tween().set_parallel(true)
	for player: AudioStreamPlayer in playing_players:
		tween.tween_property(player, "volume_linear", 0.0, duration)
	await tween.finished
	for player: AudioStreamPlayer in playing_players:
		player.stop()


func get_cue(cue_id: String) -> Dictionary:
	if not _cues.has(cue_id):
		return {}
	return (_cues[cue_id] as Dictionary).duplicate(true)


func has_audio(cue_id: String) -> bool:
	var cue: Dictionary = get_cue(cue_id)
	if cue.is_empty():
		return false
	return ResourceLoader.exists(str(cue.get("path", "")))


func _should_suppress_cue(cue_id: String) -> bool:
	if cue_id != "okay_intro":
		return false
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false
	return current_scene.scene_file_path == "res://scenes/cemetery.tscn"
