extends Node

signal progress_changed(progress: float, status: String)
signal preload_completed(used_fallbacks: bool)

const LEVEL_LOADER_SCRIPT: Script = preload("res://scripts/world/kenney_level_expansion.gd")
const CAR_LIBRARY_SCRIPT: Script = preload("res://scripts/assets/kenney_car_library.gd")

const SCENE_PATHS: Array[String] = [
	"res://scenes/cemetery.tscn",
	"res://scenes/road_memory.tscn",
	"res://scenes/afterlife_city.tscn",
	"res://scenes/ruined_nightclub.tscn",
	"res://scenes/skeleton_chamber.tscn"
]

const LEVEL_FILES: Dictionary = {
	"platformer": [
		"brick.glb", "cloud.glb", "flag.glb", "grass-small.glb", "grass.glb",
		"platform-grass-large-round.glb", "platform-large.glb", "platform-medium.glb",
		"platform.glb"
	],
	"fps": ["wall-high.glb", "wall-low.glb", "platform-large-grass.glb"]
}

var _level_helper: Node
var _car_library: Node
var _scene_cache: Dictionary = {}
var _progress: float = 0.0
var _status: String = "STARTING MEMORY ARCHIVE"
var _ready_for_gameplay: bool = false
var _preparing: bool = false
var _used_fallbacks: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level_helper = LEVEL_LOADER_SCRIPT.new() as Node
	_car_library = CAR_LIBRARY_SCRIPT.new() as Node
	add_child(_level_helper)
	add_child(_car_library)
	_prepare_all.call_deferred()


func is_ready() -> bool:
	return _ready_for_gameplay


func get_progress() -> float:
	return _progress


func get_status() -> String:
	return _status


func used_fallbacks() -> bool:
	return _used_fallbacks


func get_preloaded_scene(scene_path: String) -> PackedScene:
	return _scene_cache.get(scene_path) as PackedScene


func get_level_prototype(source_id: String, file_name: String) -> Node3D:
	if _level_helper == null:
		return null
	var cache_variant: Variant = _level_helper.get("_prototype_cache")
	if not (cache_variant is Dictionary):
		return null
	var cache: Dictionary = cache_variant
	return cache.get("%s/%s" % [source_id, file_name]) as Node3D


func get_car_prototype() -> Node3D:
	if _car_library == null:
		return null
	return _car_library.call("get_prototype") as Node3D


func get_car_model_name() -> String:
	if _car_library == null:
		return "procedural fallback"
	return str(_car_library.call("get_selected_model_name"))


func get_void_prototype(_model_path: String) -> Node3D:
	# Compatibility for retired cached scenes. The active chapter is Heaven.
	return null


func get_void_source_models() -> Dictionary:
	return {}


func _prepare_all() -> void:
	if _preparing or _ready_for_gameplay:
		return
	_preparing = true
	_update_progress(0.02, "OPENING MEMORY ARCHIVE")
	await get_tree().process_frame

	var scenes_ready: bool = await _prepare_scene_resources()
	var audio_ready: bool = await _prepare_audio()
	var car_ready: bool = await _prepare_car_asset()
	var level_ready: bool = await _prepare_level_assets()
	_used_fallbacks = not scenes_ready or not audio_ready or not car_ready or not level_ready

	_ready_for_gameplay = true
	_preparing = false
	var final_status: String = "MEMORY ARCHIVE READY"
	if _used_fallbacks:
		final_status = "MEMORY ARCHIVE READY  //  PROCEDURAL FALLBACKS ACTIVE"
	_update_progress(1.0, final_status)
	preload_completed.emit(_used_fallbacks)


func _prepare_scene_resources() -> bool:
	var all_loaded: bool = true
	for scene_index: int in range(SCENE_PATHS.size()):
		var scene_path: String = SCENE_PATHS[scene_index]
		_update_progress(
			lerpf(0.04, 0.16, float(scene_index + 1) / float(SCENE_PATHS.size())),
			"WARMING CHAPTER  %d / %d" % [scene_index + 1, SCENE_PATHS.size()]
		)
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if packed_scene == null:
			all_loaded = false
		else:
			_scene_cache[scene_path] = packed_scene
		await get_tree().process_frame
	return all_loaded


func _prepare_audio() -> bool:
	_update_progress(0.20, "PREPARING HEADPHONE AUDIO")
	if not OnlineAudioLibrary.has_method("prepare_library"):
		return false
	OnlineAudioLibrary.call("prepare_library")
	while not bool(OnlineAudioLibrary.call("is_ready")):
		await get_tree().process_frame
	return bool(OnlineAudioLibrary.call("has_cached_audio"))


func _prepare_car_asset() -> bool:
	_update_progress(0.38, "PREPARING CC0 BRIDGE VEHICLE")
	if _car_library == null or not _car_library.has_method("prepare"):
		return false
	var prepared_variant: Variant = await _car_library.call("prepare")
	var prepared: bool = bool(prepared_variant)
	if prepared:
		_update_progress(0.50, "BRIDGE VEHICLE READY")
	else:
		_update_progress(0.50, "BRIDGE VEHICLE FALLBACK READY")
	await get_tree().process_frame
	return prepared


func _prepare_level_assets() -> bool:
	_update_progress(0.54, "PREPARING CEMETERY AND NIGHTCLUB MODELS")
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
				lerpf(0.56, 0.96, ratio),
				"LOADING ENVIRONMENT MODEL  %d / %d" % [files_loaded, total_files]
			)
			await get_tree().process_frame
	return true


func _update_progress(progress_value: float, status_text: String) -> void:
	_progress = clampf(progress_value, 0.0, 1.0)
	_status = status_text
	progress_changed.emit(_progress, _status)
