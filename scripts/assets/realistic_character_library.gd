extends Node

const CACHE_ROOT: String = "user://out_of_time_rigged_characters_v3"
const PLAYER_PATH: String = CACHE_ROOT + "/kaykit_skeleton_mininion.glb"
const PLAYER_FALLBACK_PATH: String = CACHE_ROOT + "/rigged_figure_fallback.glb"
const GHOST_WOMAN_PATH: String = CACHE_ROOT + "/mpfb_ghost_woman.glb"
const GHOST_FALLBACK_PATH: String = CACHE_ROOT + "/kaykit_mage_fallback.glb"

const PLAYER_URL: String = "https://cdn.jsdelivr.net/gh/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0@main/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Minion.glb"
const PLAYER_FALLBACK_URL: String = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/RiggedFigure/glTF-Binary/RiggedFigure.glb"
const GHOST_WOMAN_URL: String = "https://raw.githubusercontent.com/met4citizen/TalkingHead/main/avatars/mpfb.glb"
const GHOST_FALLBACK_URL: String = "https://cdn.jsdelivr.net/gh/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0@main/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb"

var _player_character_prototype: Node3D
var _ghost_woman_prototype: Node3D


func prepare() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	var player_ready: bool = await _prepare_character_with_fallback(
		PLAYER_URL,
		PLAYER_PATH,
		PLAYER_FALLBACK_URL,
		PLAYER_FALLBACK_PATH,
		true
	)
	await get_tree().process_frame
	var ghost_ready: bool = await _prepare_character_with_fallback(
		GHOST_WOMAN_URL,
		GHOST_WOMAN_PATH,
		GHOST_FALLBACK_URL,
		GHOST_FALLBACK_PATH,
		false
	)
	return player_ready and ghost_ready


func get_player_character_prototype() -> Node3D:
	return _player_character_prototype


func get_skeleton_head_prototype() -> Node3D:
	# Compatibility for stale cached scenes from the retired head-only pass.
	return _player_character_prototype


func get_ghost_woman_prototype() -> Node3D:
	return _ghost_woman_prototype


func _prepare_character_with_fallback(
	primary_url: String,
	primary_path: String,
	fallback_url: String,
	fallback_path: String,
	is_player: bool
) -> bool:
	var prototype: Node3D = await _prepare_direct_character(primary_url, primary_path)
	if prototype == null:
		prototype = await _prepare_direct_character(fallback_url, fallback_path)
	if prototype == null:
		return false
	if is_player:
		_player_character_prototype = prototype
	else:
		_ghost_woman_prototype = prototype
	return true


func _prepare_direct_character(remote_url: String, local_path: String) -> Node3D:
	var prototype: Node3D
	if FileAccess.file_exists(local_path):
		prototype = _load_rigged_glb(local_path)
	if prototype != null:
		return prototype

	if FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	if not await _download_file(remote_url, local_path):
		return null
	prototype = _load_rigged_glb(local_path)
	if prototype == null and FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	return prototype


func _download_file(remote_url: String, local_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(local_path.get_base_dir()))
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 90.0
	request_node.download_file = local_path
	add_child(request_node)
	var request_error: Error = request_node.request(remote_url)
	if request_error != OK:
		request_node.queue_free()
		return false
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	var result_code: int = int(response[0])
	var http_code: int = int(response[1])
	var succeeded: bool = (
		result_code == HTTPRequest.RESULT_SUCCESS
		and http_code >= 200
		and http_code < 300
		and FileAccess.file_exists(local_path)
	)
	if not succeeded and FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	return succeeded


func _load_rigged_glb(model_path: String) -> Node3D:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var import_error: Error = document.append_from_file(
		model_path,
		state,
		0,
		model_path.get_base_dir()
	)
	if import_error != OK:
		return null
	var generated_scene: Node = document.generate_scene(state)
	var generated_root: Node3D = generated_scene as Node3D
	if generated_root == null:
		if generated_scene != null:
			generated_scene.free()
		return null
	var skeleton_nodes: Array[Node] = generated_root.find_children(
		"*",
		"Skeleton3D",
		true,
		false
	)
	var mesh_nodes: Array[Node] = generated_root.find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)
	if skeleton_nodes.is_empty() or mesh_nodes.is_empty():
		generated_root.free()
		return null
	return generated_root
