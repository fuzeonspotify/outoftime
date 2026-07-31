extends Node

const REALISTIC_CAR_URL: String = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CarConcept/glTF-Binary/CarConcept.glb"
const PRIMARY_ARCHIVE_URL: String = "https://www.kenney.nl/media/pages/assets/car-kit/1a312ec241-1775131960/kenney_car-kit.zip"
const MIRROR_ARCHIVE_URL: String = "https://opengameart.org/sites/default/files/kenney_car-kit_3.1.zip"
const CACHE_ROOT: String = "user://bridge_vehicle_models_v2"
const REALISTIC_CAR_PATH: String = CACHE_ROOT + "/CarConcept.glb"
const ARCHIVE_PATH: String = CACHE_ROOT + "/kenney_car-kit.zip"
const MODELS_ROOT: String = CACHE_ROOT + "/kenney_models"
const READY_MARKER: String = CACHE_ROOT + "/.ready"
const EXTRACTION_BATCH_SIZE: int = 12

var _prototype: Node3D
var _selected_model_path: String = ""


func prepare() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS_ROOT))
	if await _prepare_realistic_car():
		_write_ready_marker()
		return true

	var model_paths: Array[String] = _scan_model_paths()
	if model_paths.is_empty():
		var extracted: bool = false
		if FileAccess.file_exists(ARCHIVE_PATH):
			extracted = await _extract_archive()
		if not extracted:
			if FileAccess.file_exists(ARCHIVE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVE_PATH))
			if not await _download_archive():
				return false
			extracted = await _extract_archive()
		if not extracted:
			return false
		model_paths = _scan_model_paths()

	if model_paths.is_empty() or not _select_and_load_model(model_paths):
		return false
	_write_ready_marker()
	return true


func get_prototype() -> Node3D:
	return _prototype


func get_selected_model_name() -> String:
	return _selected_model_path.get_file()


func _prepare_realistic_car() -> bool:
	if not FileAccess.file_exists(REALISTIC_CAR_PATH):
		var downloaded: bool = await _download_file(REALISTIC_CAR_URL, REALISTIC_CAR_PATH)
		if not downloaded:
			return false
	var realistic_prototype: Node3D = _load_model_prototype(REALISTIC_CAR_PATH)
	if realistic_prototype == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REALISTIC_CAR_PATH))
		return false
	_prototype = realistic_prototype
	_selected_model_path = REALISTIC_CAR_PATH
	return true


func _download_archive() -> bool:
	var urls: Array[String] = [PRIMARY_ARCHIVE_URL, MIRROR_ARCHIVE_URL]
	for remote_url: String in urls:
		if FileAccess.file_exists(ARCHIVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVE_PATH))
		var downloaded: bool = await _download_file(remote_url, ARCHIVE_PATH)
		if downloaded:
			return true
	return false


func _download_file(remote_url: String, local_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(local_path.get_base_dir()))
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


func _extract_archive() -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(ProjectSettings.globalize_path(ARCHIVE_PATH))
	if open_error != OK:
		return false
	var extracted_models: int = 0
	var processed_files: int = 0
	for internal_path: String in reader.get_files():
		var normalized_path: String = internal_path.replace("\\", "/")
		if normalized_path.ends_with("/") or normalized_path.contains(".."):
			continue
		var lower_path: String = normalized_path.to_lower()
		if not _should_extract_file(lower_path):
			continue
		var destination_path: String = MODELS_ROOT.path_join(normalized_path)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_path.get_base_dir()))
		var bytes: PackedByteArray = reader.read_file(internal_path)
		if bytes.is_empty():
			continue
		var output_file: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
		if output_file == null:
			continue
		output_file.store_buffer(bytes)
		output_file.close()
		if lower_path.ends_with(".glb") or lower_path.ends_with(".gltf"):
			extracted_models += 1
		processed_files += 1
		if processed_files % EXTRACTION_BATCH_SIZE == 0:
			await get_tree().process_frame
	reader.close()
	return extracted_models > 0


func _should_extract_file(lower_path: String) -> bool:
	return (
		lower_path.ends_with(".glb")
		or lower_path.ends_with(".gltf")
		or lower_path.ends_with(".bin")
		or lower_path.ends_with(".png")
		or lower_path.ends_with(".jpg")
		or lower_path.ends_with(".jpeg")
		or lower_path.ends_with(".webp")
	)


func _scan_model_paths() -> Array[String]:
	var results: Array[String] = []
	_scan_directory(MODELS_ROOT, results)
	results.sort()
	return results


func _scan_directory(directory_path: String, results: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		var entry_path: String = directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_directory(entry_path, results)
		else:
			var lower_name: String = entry_name.to_lower()
			if lower_name.ends_with(".glb") or lower_name.ends_with(".gltf"):
				results.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _select_and_load_model(model_paths: Array[String]) -> bool:
	var remaining_paths: Array[String] = []
	remaining_paths.append_array(model_paths)
	while not remaining_paths.is_empty():
		var best_index: int = 0
		var best_score: int = _score_model_path(remaining_paths[0])
		for index: int in range(1, remaining_paths.size()):
			var candidate_score: int = _score_model_path(remaining_paths[index])
			if candidate_score > best_score:
				best_score = candidate_score
				best_index = index
		var candidate_path: String = remaining_paths[best_index]
		remaining_paths.remove_at(best_index)
		if best_score <= -900:
			continue
		var candidate_prototype: Node3D = _load_model_prototype(candidate_path)
		if candidate_prototype == null:
			continue
		_selected_model_path = candidate_path
		_prototype = candidate_prototype
		return true
	return false


func _score_model_path(model_path: String) -> int:
	var file_name: String = model_path.get_file().to_lower()
	var score: int = 0
	var preferred_terms: Array[String] = ["muscle", "sedan", "sports", "sport", "coupe", "car"]
	var rejected_terms: Array[String] = [
		"wheel", "debris", "cone", "kart", "tractor", "truck", "van",
		"ambulance", "fire", "police", "taxi", "race-driver", "character"
	]
	for rejected_term: String in rejected_terms:
		if file_name.contains(rejected_term):
			score -= 1000
	for term_index: int in range(preferred_terms.size()):
		if file_name.contains(preferred_terms[term_index]):
			score += 120 - term_index * 14
	if file_name.contains("sedan-sports") or file_name.contains("sports-sedan"):
		score += 180
	if file_name.ends_with(".glb"):
		score += 8
	return score


func _load_model_prototype(model_path: String) -> Node3D:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var import_error: Error = document.append_from_file(model_path, state, 0, model_path.get_base_dir())
	if import_error != OK:
		return null
	var generated_scene: Node = document.generate_scene(state)
	var generated_root: Node3D = generated_scene as Node3D
	if generated_root == null and generated_scene != null:
		generated_scene.free()
	return generated_root


func _write_ready_marker() -> void:
	var marker: FileAccess = FileAccess.open(READY_MARKER, FileAccess.WRITE)
	if marker == null:
		return
	marker.store_string(_selected_model_path)
	marker.close()
