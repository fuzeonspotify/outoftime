extends Node

signal cue_started(cue_id: String)
signal cue_missing(cue_id: String, expected_path: String)

const CUES_PATH := "res://data/music_cues.json"
const SILENT_DB := -40.0

var _cues: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _active_index := 0


func _ready() -> void:
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)

	_load_cues()


func _load_cues() -> void:
	if not FileAccess.file_exists(CUES_PATH):
		push_error("Music cue file is missing: %s" % CUES_PATH)
		return

	var file := FileAccess.open(CUES_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open music cue file: %s" % CUES_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Music cue file contains invalid JSON.")
		return

	_cues = parsed


func play_cue(cue_id: String, fade_seconds := 1.2, start_offset := 0.0) -> bool:
	if not _cues.has(cue_id):
		push_warning("Unknown music cue: %s" % cue_id)
		return false

	var cue: Dictionary = _cues[cue_id]
	var audio_path := str(cue.get("path", ""))
	if audio_path.is_empty() or not ResourceLoader.exists(audio_path):
		cue_missing.emit(cue_id, audio_path)
		push_warning("Music file not found for '%s': %s" % [cue_id, audio_path])
		return false

	var stream := load(audio_path) as AudioStream
	if stream == null:
		cue_missing.emit(cue_id, audio_path)
		push_warning("Could not load music file for '%s': %s" % [cue_id, audio_path])
		return false

	var previous_player := _players[_active_index]
	var next_index := 1 - _active_index
	var next_player := _players[next_index]

	next_player.stop()
	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play(maxf(0.0, start_offset))

	var duration := maxf(0.05, fade_seconds)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(previous_player, "volume_db", SILENT_DB, duration)
	tween.tween_property(next_player, "volume_db", 0.0, duration)
	await tween.finished

	previous_player.stop()
	_active_index = next_index
	cue_started.emit(cue_id)
	return true


func stop_music(fade_seconds := 1.0) -> void:
	if _players.is_empty():
		return

	var player := _players[_active_index]
	if not player.playing:
		return

	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, maxf(0.05, fade_seconds))
	await tween.finished
	player.stop()


func get_cue(cue_id: String) -> Dictionary:
	if not _cues.has(cue_id):
		return {}
	return _cues[cue_id].duplicate(true)


func has_audio(cue_id: String) -> bool:
	var cue := get_cue(cue_id)
	if cue.is_empty():
		return false
	return ResourceLoader.exists(str(cue.get("path", "")))
