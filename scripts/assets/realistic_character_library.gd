extends Node

const CACHE_ROOT: String = "user://out_of_time_character_models_v1"
const SKULL_PATH: String = CACHE_ROOT + "/realistic_skull.glb"
const GHOST_WOMAN_PATH: String = CACHE_ROOT + "/ghost_woman_corset.glb"

const SKULL_URL: String = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Skull/glTF-Binary/Skull.glb"
const GHOST_WOMAN_URL: String = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Corset/glTF-Binary/Corset.glb"

var _skeleton_head_prototype: Node3D
var _ghost_woman_prototype: Node3D


func prepare() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	var skull_ready: bool = await _prepare_model(SKULL_URL, SKULL_PATH, true)
	await get_tree().process_frame
	var ghost_ready: bool = await _prepare_model(GHOST_WOMAN_URL, GHOST_WOMAN_PATH, false)
	return skull_ready and ghost_ready


func get_skeleton_head_prototype() -> Node3D:
	return _skeleton_head_prototype


func get_ghost_woman_prototype() -> Node3D:
	return _ghost_woman_prototype


func _prepare_model(remote_url: String, local_path: String, is_skull: bool) -> bool:
	if not FileAccess.file_exists(local_path):
		var downloaded: bool = await _download_file(remote_url, local_path)
		if not downloaded:
			return false

	var prototype: Node3D = _load_glb(local_path)
	if prototype == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
		return false
	if is_skull:
		_skeleton_head_prototype = prototype
	else:
		_ghost_woman_prototype = prototype
	return true


func _download_file(remote_url: String, local_path: String) -> bool:
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 30.0
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


func _load_glb(model_path: String) -> Node3D:
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
	if generated_root == null and generated_scene != null:
		generated_scene.free()
	return generated_root
