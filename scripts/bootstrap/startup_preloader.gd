extends Node

signal progress_changed(progress: float, status: String)
signal preload_completed(used_fallbacks: bool)

const LEVEL_LOADER_SCRIPT: Script = preload("res://scripts/world/kenney_level_expansion.gd")
const VOID_LOADER_SCRIPT: Script = preload("res://scripts/world/void_glb_loader.gd")
const VOID_ZIP_ROOT: String = "user://kenney_void_assets"
const VOID_EXTRACTION_BATCH: int = 8

const LEVEL_FILES: Dictionary = {
	"platformer": [
		"brick.glb", "cloud.glb", "flag.glb", "grass-small.glb", "grass.glb",
		"platform-grass-large-round.glb", "platform-large.glb", "platform-medium.glb",
		"platform.glb"
	],
	"fps": ["wall-high.glb", "wall-low.glb", "platform-large-grass.glb"]
}

var _level_helper: Node
var _void_helper: Node
var _void_source_models: Dictionary = {}
var _progress: float = 0.0
var _status: String = "STARTING MEMORY ARCHIVE"
var _ready_for_gameplay: bool = false
var _preparing: bool = false
var _used_fallbacks: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level_helper = LEVEL_LOADER_SCRIPT.new() as Node
	_void_helper = VOID_LOADER_SCRIPT.new() as Node
	add_child(_level_helper)
	add_child(_void_helper)
	_prepare_all.call_deferred()


func is_ready() -> bool:
	return _ready_for_gameplay


func get_progress() -> float:
	return _progress


func get_status() -> String:
	return _status


func used_fallbacks() -> bool:
	return _used_fallbacks


func get_level_prototype(source_id: String, file_name: String) -> Node3D:
	if _level_helper == null:
		return null
	var cache_variant: Variant = _level_helper.get("_prototype_cache")
	if not (cache_variant is Dictionary):
		return null
	var cache: Dictionary = cache_variant
	return cache.get("%s/%s" % [source_id, file_name]) as Node3D


func get_void_prototype(model_path: String) -> Node3D:
	if _void_helper == null:
		return null
	var cache_variant: Variant = _void_helper.get("_prototype_cache")
	if not (cache_variant is Dictionary):
		return null
	var cache: Dictionary = cache_variant
	return cache.get(model_path) as Node3D


func get_void_source_models() -> Dictionary:
	return _void_source_models.duplicate(true)


func _prepare_all() -> void:
	if _preparing or _ready_for_gameplay:
		return
	_preparing = true
	_update_progress(0.02, "OPENING MEMORY ARCHIVE")
	await get_tree().process_frame

	var audio_ready: bool = await _prepare_audio()
	var level_ready: bool = await _prepare_level_assets()
	var void_ready: bool = await _prepare_void_assets()
	_used_fallbacks = not audio_ready or not level_ready or not void_ready

	_ready_for_gameplay = true
	_preparing = false
	var final_status: String = "MEMORY ARCHIVE READY"
	if _used_fallbacks:
		final_status = "MEMORY ARCHIVE READY  //  PROCEDURAL FALLBACKS ACTIVE"
	_update_progress(1.0, final_status)
	preload_completed.emit(_used_fallbacks)


func _prepare_audio() -> bool:
	_update_progress(0.06, "PREPARING HEADPHONE AUDIO")
	if not OnlineAudioLibrary.has_method("prepare_library"):
		return false
	OnlineAudioLibrary.call("prepare_library")
	while not bool(OnlineAudioLibrary.call("is_ready")):
		await get_tree().process_frame
	return bool(OnlineAudioLibrary.call("has_cached_audio"))


func _prepare_level_assets() -> bool:
	_update_progress(0.28, "PREPARING ENVIRONMENT MODELS")
	_level_helper.call("_ensure_cache_directories")
	var all_cached: bool = bool(_level_helper.call("_all_assets_cached"))
	if not all_cached:
		var downloaded_variant: Variant = await _level_helper.call("_download_missing_assets")
		if not bool(downloaded_variant):
			return false

	var files_loaded: int = 0
	var total_files: int = 12
	for source_id_variant: Variant in LEVEL_FILES.keys():
		var source_id: String = str(source_id_variant)
		var source_files_variant: Variant = LEVEL_FILES.get(source_id, [])
		if not (source_files_variant is Array):
			continue
		var source_files: Array = source_files_variant
		for file_variant: Variant in source_files:
			var file_name: String = str(file_variant)
			_level_helper.call("_load_prototype", source_id, file_name)
			files_loaded += 1
			var ratio: float = float(files_loaded) / float(total_files)
			_update_progress(
				lerpf(0.30, 0.50, ratio),
				"LOADING ENVIRONMENT MODEL  %d / %d" % [files_loaded, total_files]
			)
			await get_tree().process_frame
	return true


func _prepare_void_assets() -> bool:
	_update_progress(0.52, "PREPARING VOID MODEL ARCHIVE")
	_void_helper.call("_ensure_cache_directories")
	_void_source_models.clear()

	for source_index: int in range(2):
		var source_id: String = "station" if source_index == 0 else "space"
		var models: Array[String] = _scan_void_models(source_id)
		if models.is_empty():
			var zip_path: String = VOID_ZIP_ROOT.path_join("%s.zip" % source_id)
			if not FileAccess.file_exists(zip_path):
				_update_progress(
					0.54 + float(source_index) * 0.10,
					"DOWNLOADING %s" % str(_void_helper.call("_source_display_name", source_id))
				)
				var remote_url: String = str(_void_helper.call("_source_url", source_id))
				var downloaded_variant: Variant = await _void_helper.call("_download_file", remote_url, zip_path)
				if not bool(downloaded_variant):
					return false
			var extracted: bool = await _extract_void_archive(source_id, zip_path, source_index)
			if not extracted:
				return false
			models = _scan_void_models(source_id)
		if models.is_empty():
			return false
		_void_source_models[source_id] = models
		await get_tree().process_frame

	_void_helper.set("_source_models", _void_source_models.duplicate(true))
	var warmup_container: Node3D = Node3D.new()
	warmup_container.name = "StartupVoidWarmup"
	add_child(warmup_container)
	_void_helper.set("_model_container", warmup_container)

	var build_methods: Array[String] = [
		"_build_arrival_station_ruins",
		"_build_low_gravity_satellites",
		"_build_inversion_station_ceiling",
		"_build_drift_field_models",
		"_build_portal_station_remains",
		"_build_distant_space_models"
	]
	for method_index: int in range(build_methods.size()):
		_update_progress(
			lerpf(0.78, 0.96, float(method_index + 1) / float(build_methods.size())),
			"WARMING VOID MODEL SET  %d / %d" % [method_index + 1, build_methods.size()]
		)
		_void_helper.call(build_methods[method_index])
		await get_tree().process_frame

	warmup_container.queue_free()
	_void_helper.set("_model_container", null)
	_void_helper.set("_animated_models", [])
	return true


func _scan_void_models(source_id: String) -> Array[String]:
	var result_variant: Variant = _void_helper.call("_scan_source_models", source_id)
	var results: Array[String] = []
	if result_variant is Array:
		for path_variant: Variant in result_variant:
			results.append(str(path_variant))
	return results


func _extract_void_archive(source_id: String, zip_path: String, source_index: int) -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(ProjectSettings.globalize_path(zip_path))
	if open_error != OK:
		return false

	var extracted_models: int = 0
	var processed_files: int = 0
	var archive_files: PackedStringArray = reader.get_files()
	var model_root: String = str(_void_helper.call("_models_root", source_id))

	for internal_path: String in archive_files:
		var normalized_path: String = internal_path.replace("\\", "/")
		if normalized_path.ends_with("/") or normalized_path.contains(".."):
			continue
		if not bool(_void_helper.call("_should_extract_archive_file", normalized_path)):
			continue

		var destination_path: String = model_root.path_join(normalized_path)
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(destination_path.get_base_dir())
		)
		var file_bytes: PackedByteArray = reader.read_file(internal_path)
		if not file_bytes.is_empty():
			var output_file: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
			if output_file != null:
				output_file.store_buffer(file_bytes)
				output_file.close()
				if normalized_path.to_lower().ends_with(".glb"):
					extracted_models += 1

		processed_files += 1
		if processed_files % VOID_EXTRACTION_BATCH == 0:
			var base_progress: float = 0.62 + float(source_index) * 0.08
			_update_progress(
				minf(base_progress + 0.06, 0.77),
				"UNPACKING VOID MODELS  //  %d READY" % extracted_models
			)
			await get_tree().process_frame

	reader.close()
	return extracted_models > 0


func _update_progress(progress_value: float, status_text: String) -> void:
	_progress = clampf(progress_value, 0.0, 1.0)
	_status = status_text
	progress_changed.emit(_progress, _status)
