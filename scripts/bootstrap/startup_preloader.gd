extends Node

signal progress_changed(progress: float, status: String)
signal preload_completed(used_fallbacks: bool)

const ENVIRONMENT_LIBRARY_SCRIPT: Script = preload("res://scripts/assets/polyhaven_environment_library_expanded.gd")
const CAR_LIBRARY_SCRIPT: Script = preload("res://scripts/assets/custom_porsche_car_library.gd")
const CHARACTER_LIBRARY_SCRIPT: Script = preload("res://scripts/assets/realistic_character_library.gd")
const REQUIRED_BAT_SCENE_PATH: String = "res://assets/models/animals/realistic_bat/scene.gltf"
const REQUIRED_ROADBLOCK_SCENE_PATH: String = "res://assets/models/props/concrete_roadblock_scan/scene.gltf"

const SCENE_PATHS: Array[String] = [
	"res://scenes/cemetery.tscn",
	"res://scenes/road_memory.tscn",
	"res://scenes/afterlife_city.tscn",
	"res://scenes/ruined_nightclub.tscn",
	"res://scenes/skeleton_chamber.tscn"
]

var _environment_library: Node
var _car_library: Node
var _character_library: Node
var _roadblock_prototype: Node3D
var _scene_cache: Dictionary = {}
var _progress: float = 0.0
var _status: String = "STARTING MEMORY ARCHIVE"
var _ready_for_gameplay: bool = false
var _preparing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_environment_library = ENVIRONMENT_LIBRARY_SCRIPT.new() as Node
	_car_library = CAR_LIBRARY_SCRIPT.new() as Node
	_character_library = CHARACTER_LIBRARY_SCRIPT.new() as Node
	add_child(_environment_library)
	add_child(_car_library)
	add_child(_character_library)
	_prepare_all.call_deferred()


func is_ready() -> bool:
	return _ready_for_gameplay


func get_progress() -> float:
	return _progress


func get_status() -> String:
	return _status


func used_fallbacks() -> bool:
	return false


func get_preloaded_scene(scene_path: String) -> PackedScene:
	return _scene_cache.get(scene_path) as PackedScene


func get_environment_prototype(asset_id: String) -> Node3D:
	if _environment_library == null:
		return null
	return _environment_library.call("get_model_prototype", asset_id) as Node3D


func get_environment_material(material_id: String) -> StandardMaterial3D:
	if _environment_library == null:
		return null
	return _environment_library.call("get_surface_material", material_id) as StandardMaterial3D


func get_level_prototype(_source_id: String, file_name: String) -> Node3D:
	# Compatibility only. Active scenes use exact Poly Haven IDs directly.
	return get_environment_prototype(file_name.get_basename())


func get_car_prototype() -> Node3D:
	if _car_library == null:
		return null
	return _car_library.call("get_prototype") as Node3D


func get_car_model_name() -> String:
	if _car_library == null:
		return "required Porsche unavailable"
	return str(_car_library.call("get_selected_model_name"))


func get_player_character_prototype() -> Node3D:
	if _character_library == null:
		return null
	return _character_library.call("get_player_character_prototype") as Node3D


func get_skeleton_head_prototype() -> Node3D:
	return get_player_character_prototype()


func get_ghost_woman_prototype() -> Node3D:
	if _character_library == null:
		return null
	return _character_library.call("get_ghost_woman_prototype") as Node3D


func get_roadblock_prototype() -> Node3D:
	if _roadblock_prototype == null or not is_instance_valid(_roadblock_prototype):
		return null
	return _roadblock_prototype.duplicate() as Node3D


func get_void_prototype(_model_path: String) -> Node3D:
	return null


func get_void_source_models() -> Dictionary:
	return {}


func _prepare_all() -> void:
	if _preparing or _ready_for_gameplay:
		return
	_preparing = true
	_update_progress(0.02, "OPENING EXACT ASSET ARCHIVE")
	await get_tree().process_frame

	var scenes_ready: bool = await _prepare_scene_resources()
	await _prepare_audio()
	var character_ready: bool = await _prepare_character_assets()
	var car_ready: bool = await _prepare_car_asset()
	var environment_ready: bool = await _prepare_environment_assets()

	_ready_for_gameplay = scenes_ready and character_ready and car_ready and environment_ready
	_preparing = false
	if _ready_for_gameplay:
		_update_progress(1.0, "EXACT HIGH-QUALITY ASSETS READY")
	else:
		var failure_detail: String = ""
		if _environment_library != null and _environment_library.has_method("get_last_error"):
			failure_detail = str(_environment_library.call("get_last_error"))
		var final_status: String = "REQUIRED ASSET FAILED  //  NO FALLBACK LOADED"
		if not failure_detail.is_empty():
			final_status += "  //  " + failure_detail.to_upper()
		_update_progress(1.0, final_status)
	preload_completed.emit(false)


func _prepare_scene_resources() -> bool:
	var all_loaded: bool = true
	for scene_index: int in range(SCENE_PATHS.size()):
		var scene_path: String = SCENE_PATHS[scene_index]
		_update_progress(
			lerpf(0.04, 0.13, float(scene_index + 1) / float(SCENE_PATHS.size())),
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
	_update_progress(0.15, "PREPARING HEADPHONE AUDIO")
	if not OnlineAudioLibrary.has_method("prepare_library"):
		return false
	OnlineAudioLibrary.call("prepare_library")
	while not bool(OnlineAudioLibrary.call("is_ready")):
		await get_tree().process_frame
	return bool(OnlineAudioLibrary.call("has_cached_audio"))


func _prepare_character_assets() -> bool:
	_update_progress(0.24, "PREPARING REQUIRED CHARACTER RIGS")
	if _character_library == null or not _character_library.has_method("prepare"):
		return false
	var prepared_variant: Variant = await _character_library.call("prepare")
	var prepared: bool = bool(prepared_variant)
	_update_progress(
		0.34,
		"REQUIRED CHARACTER RIGS READY" if prepared else "REQUIRED CHARACTER RIG FAILED"
	)
	await get_tree().process_frame
	return prepared


func _prepare_car_asset() -> bool:
	_update_progress(0.36, "PREPARING REQUIRED PORSCHE")
	if _car_library == null or not _car_library.has_method("prepare"):
		return false
	var prepared_variant: Variant = await _car_library.call("prepare")
	var prepared: bool = bool(prepared_variant)
	_update_progress(
		0.43,
		"REQUIRED PORSCHE READY" if prepared else "REQUIRED PORSCHE FAILED"
	)
	await get_tree().process_frame
	return prepared


func _prepare_environment_assets() -> bool:
	_update_progress(0.45, "DOWNLOADING EXPANDED POLY HAVEN ENVIRONMENTS")
	if _environment_library == null or not _environment_library.has_method("prepare"):
		return false
	var prepared_variant: Variant = await _environment_library.call("prepare")
	var prepared: bool = bool(prepared_variant)
	if prepared:
		_update_progress(0.94, "VERIFYING REQUIRED ANIMATED CEMETERY BAT")
		prepared = _validate_required_bat()
	if prepared:
		_update_progress(0.96, "VERIFYING REQUIRED SCANNED ROADBLOCK")
		prepared = _validate_required_roadblock()
	_update_progress(
		0.98,
		"EXPANDED ENVIRONMENT MODELS READY" if prepared else "REQUIRED ENVIRONMENT ASSET FAILED"
	)
	await get_tree().process_frame
	return prepared


func _validate_required_bat() -> bool:
	if not ResourceLoader.exists(REQUIRED_BAT_SCENE_PATH):
		push_error(
			"REQUIRED BAT MODEL ERROR: %s is missing. Run tools/install_sketchfab_realistic_bat.ps1. No substitute bat is allowed." % REQUIRED_BAT_SCENE_PATH
		)
		return false

	var bat_scene: PackedScene = load(REQUIRED_BAT_SCENE_PATH) as PackedScene
	if bat_scene == null:
		push_error("REQUIRED BAT MODEL ERROR: the installed bat scene could not be loaded.")
		return false
	var bat_instance: Node3D = bat_scene.instantiate() as Node3D
	if bat_instance == null:
		push_error("REQUIRED BAT MODEL ERROR: the installed bat scene could not be instantiated.")
		return false

	var mesh_nodes: Array[Node] = bat_instance.find_children("*", "MeshInstance3D", true, false)
	var animation_players: Array[Node] = bat_instance.find_children(
		"*",
		"AnimationPlayer",
		true,
		false
	)
	var has_animation: bool = false
	for node: Node in animation_players:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		if animation_player != null and not animation_player.get_animation_list().is_empty():
			has_animation = true
			break
	bat_instance.free()

	if mesh_nodes.is_empty() or not has_animation:
		push_error(
			"REQUIRED BAT MODEL ERROR: the bat must contain a complete mesh and authored flight animation."
		)
		return false
	return true


func _validate_required_roadblock() -> bool:
	if not ResourceLoader.exists(REQUIRED_ROADBLOCK_SCENE_PATH):
		push_error(
			"REQUIRED ROADBLOCK MODEL ERROR: %s is missing. Run tools/install_sketchfab_concrete_roadblock.ps1. No substitute roadblock is allowed." % REQUIRED_ROADBLOCK_SCENE_PATH
		)
		return false

	var roadblock_scene: PackedScene = load(REQUIRED_ROADBLOCK_SCENE_PATH) as PackedScene
	if roadblock_scene == null:
		push_error("REQUIRED ROADBLOCK MODEL ERROR: the installed Sketchfab scene could not be loaded.")
		return false

	var roadblock_instance: Node3D = roadblock_scene.instantiate() as Node3D
	if roadblock_instance == null:
		push_error("REQUIRED ROADBLOCK MODEL ERROR: the installed Sketchfab scene could not be instantiated.")
		return false

	var mesh_nodes: Array[Node] = roadblock_instance.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		roadblock_instance.free()
		push_error("REQUIRED ROADBLOCK MODEL ERROR: the installed scene contains no visible mesh.")
		return false

	_roadblock_prototype = roadblock_instance
	return true


func _update_progress(progress_value: float, status_text: String) -> void:
	_progress = clampf(progress_value, 0.0, 1.0)
	_status = status_text
	progress_changed.emit(_progress, _status)
