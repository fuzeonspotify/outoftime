extends Node

signal library_ready
signal pack_ready(pack_id: String)

const CACHE_ROOT: String = "user://out_of_time_audio_v1"

const PACKS: Dictionary = {
	"interface": {
		"page_url": "https://kenney.nl/assets/interface-sounds",
		"archive_url": "https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip"
	},
	"scifi": {
		"page_url": "https://kenney.nl/assets/sci-fi-sounds",
		"archive_url": "https://opengameart.org/sites/default/files/sci-fi_sounds.zip"
	},
	"impact": {
		"page_url": "https://kenney.nl/assets/impact-sounds",
		"archive_url": ""
	},
	"rpg": {
		"page_url": "https://kenney.nl/assets/rpg-audio",
		"archive_url": "https://opengameart.org/sites/default/files/RPGsounds_Kenney.zip"
	}
}

const CUE_RULES: Dictionary = {
	"ui_hover": {"pack": "interface", "keywords": ["rollover", "hover", "select", "click"]},
	"ui_confirm": {"pack": "interface", "keywords": ["confirmation", "confirm", "switch", "click"]},
	"ui_cancel": {"pack": "interface", "keywords": ["back", "close", "minimize", "error"]},
	"dialogue_tick": {"pack": "interface", "keywords": ["scroll", "tick", "click", "tap"]},
	"dialogue_choice": {"pack": "interface", "keywords": ["confirmation", "switch", "maximize"]},
	"interaction_read": {"pack": "rpg", "keywords": ["bookopen", "bookflip", "bookplace"]},
	"interaction_restore": {"pack": "scifi", "keywords": ["dooropen", "impactmetal", "forcefield"]},
	"interaction_stabilize": {"pack": "scifi", "keywords": ["forcefield", "computernoise"]},
	"reveal": {"pack": "scifi", "keywords": ["lowfrequency_explosion", "forcefield"]},
	"transition": {"pack": "scifi", "keywords": ["dooropen", "spaceengine", "thrusterfire"]},
	"void_pulse": {"pack": "scifi", "keywords": ["forcefield", "computernoise", "spaceenginelow"]},
	"footstep_grass": {"pack": "impact", "keywords": ["footstep_grass"]},
	"footstep_concrete": {"pack": "impact", "keywords": ["footstep_concrete"]},
	"impact_metal": {"pack": "impact", "keywords": ["impactmetal_medium", "impactmetal_heavy"]},
	"journal": {"pack": "rpg", "keywords": ["bookopen", "bookflip", "bookplace"]},
	"creak": {"pack": "rpg", "keywords": ["creak"]}
}

var _paths_by_pack: Dictionary = {}
var _stream_cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _library_is_ready: bool = false


func _ready() -> void:
	_rng.seed = 8271998
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	_prepare_library.call_deferred()


func is_ready() -> bool:
	return _library_is_ready


func get_stream(cue_id: String) -> AudioStream:
	var rule_variant: Variant = CUE_RULES.get(cue_id)
	if not (rule_variant is Dictionary):
		return null
	var rule: Dictionary = rule_variant
	var pack_id: String = str(rule.get("pack", ""))
	var keywords_variant: Variant = rule.get("keywords", [])
	var keywords: Array[String] = []
	if keywords_variant is Array:
		for keyword_variant: Variant in keywords_variant:
			keywords.append(str(keyword_variant).to_lower())

	var candidates: Array[String] = _matching_paths(pack_id, keywords)
	if candidates.is_empty():
		return null
	var selected_path: String = candidates[_rng.randi_range(0, candidates.size() - 1)]
	return _load_stream(selected_path)


func _prepare_library() -> void:
	for pack_id_variant: Variant in PACKS.keys():
		var pack_id: String = str(pack_id_variant)
		var source_variant: Variant = PACKS.get(pack_id)
		if source_variant is Dictionary:
			var source: Dictionary = source_variant
			await _ensure_pack(pack_id, source)
	_library_is_ready = true
	library_ready.emit()


func _ensure_pack(pack_id: String, source: Dictionary) -> void:
	var pack_root: String = CACHE_ROOT.path_join(pack_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pack_root))
	var existing_paths: Array[String] = []
	_scan_audio_files(pack_root, existing_paths)
	if not existing_paths.is_empty():
		_paths_by_pack[pack_id] = existing_paths
		pack_ready.emit(pack_id)
		return

	var candidates: Array[String] = []
	var archive_url: String = str(source.get("archive_url", ""))
	if not archive_url.is_empty():
		candidates.append(archive_url)
	var resolved_url: String = await _resolve_archive_url(str(source.get("page_url", "")))
	if not resolved_url.is_empty() and not candidates.has(resolved_url):
		candidates.append(resolved_url)

	for candidate_url: String in candidates:
		var archive_bytes: PackedByteArray = await _download_bytes(candidate_url)
		if archive_bytes.is_empty():
			continue
		var archive_path: String = CACHE_ROOT.path_join("%s.zip" % pack_id)
		if not _write_bytes(archive_path, archive_bytes):
			continue
		if _extract_audio_archive(archive_path, pack_root):
			break

	var loaded_paths: Array[String] = []
	_scan_audio_files(pack_root, loaded_paths)
	if not loaded_paths.is_empty():
		_paths_by_pack[pack_id] = loaded_paths
		pack_ready.emit(pack_id)


func _resolve_archive_url(page_url: String) -> String:
	if page_url.is_empty():
		return ""
	var page_bytes: PackedByteArray = await _download_bytes(page_url)
	if page_bytes.is_empty():
		return ""
	var html: String = page_bytes.get_string_from_utf8().replace("&amp;", "&")
	var regex: RegEx = RegEx.new()
	var compile_error: Error = regex.compile("(https?://[^\\\"']+\\.zip|/media/pages/assets/[^\\\"']+\\.zip)")
	if compile_error != OK:
		return ""
	var match_result: RegExMatch = regex.search(html)
	if match_result == null:
		return ""
	var result_url: String = match_result.get_string(0)
	if result_url.begins_with("/"):
		result_url = "https://kenney.nl%s" % result_url
	return result_url


func _download_bytes(url: String) -> PackedByteArray:
	if url.is_empty():
		return PackedByteArray()
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.timeout = 24.0
	add_child(request_node)
	var request_error: Error = request_node.request(url)
	if request_error != OK:
		request_node.queue_free()
		return PackedByteArray()
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	if response.size() < 4:
		return PackedByteArray()
	var result_code: int = int(response[0])
	var response_code: int = int(response[1])
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return PackedByteArray()
	var body_variant: Variant = response[3]
	if body_variant is PackedByteArray:
		var body: PackedByteArray = body_variant
		return body
	return PackedByteArray()


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_buffer(bytes)
	output.close()
	return true


func _extract_audio_archive(archive_path: String, destination_root: String) -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(ProjectSettings.globalize_path(archive_path))
	if open_error != OK:
		return false
	var extracted_count: int = 0
	var archive_files: PackedStringArray = reader.get_files()
	for internal_path: String in archive_files:
		var normalized_path: String = internal_path.replace("\\", "/")
		var lower_path: String = normalized_path.to_lower()
		if normalized_path.ends_with("/") or normalized_path.contains(".."):
			continue
		if not (lower_path.ends_with(".ogg") or lower_path.ends_with(".wav")):
			continue
		var destination_path: String = destination_root.path_join(normalized_path)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_path.get_base_dir()))
		var file_bytes: PackedByteArray = reader.read_file(internal_path)
		if file_bytes.is_empty():
			continue
		if _write_bytes(destination_path, file_bytes):
			extracted_count += 1
	reader.close()
	return extracted_count > 0


func _scan_audio_files(directory_path: String, results: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		var entry_path: String = directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_audio_files(entry_path, results)
		else:
			var lower_name: String = entry_name.to_lower()
			if lower_name.ends_with(".ogg") or lower_name.ends_with(".wav"):
				results.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
	results.sort()


func _matching_paths(pack_id: String, keywords: Array[String]) -> Array[String]:
	var results: Array[String] = []
	var pack_paths_variant: Variant = _paths_by_pack.get(pack_id)
	if not (pack_paths_variant is Array):
		return results
	var pack_paths: Array = pack_paths_variant
	for path_variant: Variant in pack_paths:
		var path: String = str(path_variant)
		var normalized_name: String = path.get_file().get_basename().to_lower().replace("-", "").replace("_", "")
		for keyword: String in keywords:
			var normalized_keyword: String = keyword.replace("-", "").replace("_", "")
			if normalized_name.contains(normalized_keyword):
				results.append(path)
				break
	return results


func _load_stream(path: String) -> AudioStream:
	var cached_variant: Variant = _stream_cache.get(path)
	if cached_variant is AudioStream:
		return cached_variant as AudioStream
	var stream: AudioStream = null
	var lower_path: String = path.to_lower()
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if lower_path.ends_with(".ogg"):
		stream = AudioStreamOggVorbis.load_from_file(absolute_path)
	elif lower_path.ends_with(".wav"):
		stream = AudioStreamWAV.load_from_file(absolute_path)
	if stream != null:
		_stream_cache[path] = stream
	return stream
