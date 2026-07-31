extends Node

const CACHE_ROOT: String = "user://out_of_time_rigged_characters_v2"
const PLAYER_ROOT: String = CACHE_ROOT + "/player"
const PLAYER_ARCHIVE_PATH: String = CACHE_ROOT + "/male_base_mesh.zip"
const PLAYER_FALLBACK_PATH: String = PLAYER_ROOT + "/RiggedFigure.glb"
const GHOST_WOMAN_PATH: String = CACHE_ROOT + "/mpfb_ghost_woman.glb"

const PLAYER_ARCHIVE_URL: String = "https://github.com/BoQsc/Godot-3D-Male-Base-Mesh/releases/latest/download/male_base_mesh.zip"
const PLAYER_FALLBACK_URL: String = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/RiggedFigure/glTF-Binary/RiggedFigure.glb"
const GHOST_WOMAN_URL: String = "https://raw.githubusercontent.com/met4citizen/TalkingHead/main/avatars/mpfb.glb"

var _player_character_prototype: Node3D
var _ghost_woman_prototype: Node3D


func prepare() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PLAYER_ROOT))
	var player_ready: bool = await _prepare_player_character()
	await get_tree().process_frame
	var ghost_ready: bool = await _prepare_direct_character(
		GHOST_WOMAN_URL,
		GHOST_WOMAN_PATH,
		false
	)
	return player_ready and ghost_ready


func get_player_character_prototype() -> Node3D:
	return _player_character_prototype


func get_ghost_woman_prototype() -> Node3D:
	return _ghost_woman_prototype


func _prepare_player_character() -> bool:
	var model_paths: Array[String] = _scan_glb_paths(PLAYER_ROOT)
	if model_paths.is_empty() and FileAccess.file_exists(PLAYER_ARCHIVE_PATH):
		await _extract_player_archive()
		model_paths = _scan_glb_paths(PLAYER_ROOT)

	if model_paths.is_empty():
		if FileAccess.file_exists(PLAYER_ARCHIVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_ARCHIVE_PATH))
		if await _download_file(PLAYER_ARCHIVE_URL, PLAYER_ARCHIVE_PATH):
			await _extract_player_archive()
			model_paths = _scan_glb_paths(PLAYER_ROOT)

	for model_path: String in model_paths:
		var prototype: Node3D = _load_rigged_glb(model_path)
		if prototype == null:
			continue
		_player_character_prototype = prototype
		return true

	return await _prepare_direct_character(
		PLAYER_FALLBACK_URL,
		PLAYER_FALLBACK_PATH,
		true
	)


func _prepare_direct_character(
	remote_url: String,
	local_path: String,
	is_player: bool
) -> bool:
	var prototype: Node3D
	if FileAccess.file_exists(local_path):
		prototype = _load_rigged_glb(local_path)
	if prototype == null:
		if FileAccess.file_exists(local_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
		if not await _download_file(remote_url, local_path):
			return false
		prototype = _load_rigged_glb(local_path)
	if prototype == null:
		if FileAccess.file_exists(local_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
		return false
	if is_player:
		_player_character_prototype = prototype
	else:
		_ghost_woman_prototype = prototype
	return true


func _download_file(remote_url: String, local_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(local_path.get_base_dir()))
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 75.0
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


func _extract_player_archive() -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(ProjectSettings.globalize_path(PLAYER_ARCHIVE_PATH))
	if open_error != OK:
		return false
	var extracted_count: int = 0
	var processed_count: int = 0
	for internal_path: String in reader.get_files():
		var normalized_path: String = internal_path.replace("\\", "/")
		var lower_path: String = normalized_path.to_lower()
		if normalized_path.ends_with("/") or normalized_path.contains(".."):
			continue
		if not lower_path.ends_with(".glb"):
			continue
		var output_path: String = PLAYER_ROOT.path_join(normalized_path.get_file())
		var bytes: PackedByteArray = reader.read_file(internal_path)
		if bytes.is_empty():
			continue
		var output_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		if output_file == null:
			continue
		output_file.store_buffer(bytes)
		output_file.close()
		extracted_count += 1
		processed_count += 1
		if processed_count % 3 == 0:
			await get_tree().process_frame
	reader.close()
	return extracted_count > 0


func _scan_glb_paths(directory_path: String) -> Array[String]:
	var results: Array[String] = []
	_scan_glb_directory(directory_path, results)
	results.sort()
	return results


func _scan_glb_directory(directory_path: String, results: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		var entry_path: String = directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_glb_directory(entry_path, results)
		elif entry_name.to_lower().ends_with(".glb"):
			results.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


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
	if skeleton_nodes.is_empty():
		generated_root.free()
		return null
	return generated_root
