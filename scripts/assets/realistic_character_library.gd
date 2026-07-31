extends Node

const CACHE_ROOT: String = "user://out_of_time_required_characters_v1"
const PLAYER_PATH: String = CACHE_ROOT + "/kaykit_skeleton_minion.glb"
const GHOST_WOMAN_PATH: String = CACHE_ROOT + "/mpfb_ghost_woman.glb"

const PLAYER_URL: String = "https://cdn.jsdelivr.net/gh/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0@main/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Minion.glb"
const GHOST_WOMAN_URL: String = "https://raw.githubusercontent.com/met4citizen/TalkingHead/main/avatars/mpfb.glb"

var _player_character_prototype: Node3D
var _ghost_woman_prototype: Node3D


func prepare() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	_player_character_prototype = await _prepare_required_character(
		"main skeleton",
		PLAYER_URL,
		PLAYER_PATH
	)
	await get_tree().process_frame
	_ghost_woman_prototype = await _prepare_required_character(
		"ghost woman",
		GHOST_WOMAN_URL,
		GHOST_WOMAN_PATH
	)
	return _player_character_prototype != null and _ghost_woman_prototype != null


func get_player_character_prototype() -> Node3D:
	return _player_character_prototype


func get_skeleton_head_prototype() -> Node3D:
	return _player_character_prototype


func get_ghost_woman_prototype() -> Node3D:
	return _ghost_woman_prototype


func _prepare_required_character(
	asset_name: String,
	remote_url: String,
	local_path: String
) -> Node3D:
	var prototype: Node3D
	if FileAccess.file_exists(local_path):
		prototype = _load_rigged_glb(local_path)
	if prototype != null:
		return prototype

	if FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	if not await _download_file(remote_url, local_path):
		push_error("REQUIRED MODEL ERROR: %s could not be downloaded. No substitute model will be used." % asset_name)
		return null
	prototype = _load_rigged_glb(local_path)
	if prototype == null:
		if FileAccess.file_exists(local_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
		push_error("REQUIRED MODEL ERROR: %s is not a complete rigged model. No substitute model will be used." % asset_name)
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
