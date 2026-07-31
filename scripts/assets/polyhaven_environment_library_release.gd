extends "res://scripts/assets/polyhaven_environment_library.gd"

const COMPLETE_MARKER_NAME: String = ".exact_bundle_complete"


func _prepare_model(asset_id: String) -> Node3D:
	var model_root: String = CACHE_ROOT.path_join("models").path_join(asset_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(model_root))
	var marker_path: String = model_root.path_join(COMPLETE_MARKER_NAME)

	if FileAccess.file_exists(marker_path):
		var marker_reader: FileAccess = FileAccess.open(marker_path, FileAccess.READ)
		if marker_reader != null:
			var cached_main_relative_path: String = marker_reader.get_line().strip_edges()
			marker_reader.close()
			if not cached_main_relative_path.is_empty():
				var cached_model: Node3D = _load_gltf_scene(
					model_root.path_join(cached_main_relative_path)
				)
				if cached_model != null:
					return cached_model
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))

	var payload_variant: Variant = await _request_asset_json(asset_id)
	if not (payload_variant is Dictionary):
		return null
	var payload: Dictionary = payload_variant
	var bundle: Dictionary = _select_model_bundle(payload)
	if bundle.is_empty():
		push_error("No <=50 MB 1K/2K glTF bundle found for %s." % asset_id)
		return null

	var total_bytes: int = int(bundle.get("total_bytes", 0))
	if total_bytes <= 0 or total_bytes > MAX_ASSET_BYTES:
		push_error("%s model bundle is outside the allowed size: %d bytes." % [asset_id, total_bytes])
		return null

	var records_variant: Variant = bundle.get("records", [])
	if not (records_variant is Array):
		return null
	var records: Array = records_variant
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			return null
		var record: Dictionary = record_variant
		var relative_path: String = str(record.get("relative_path", ""))
		if relative_path.is_empty():
			return null
		if not await _download_record(record, model_root.path_join(relative_path)):
			return null

	var main_relative_path: String = str(bundle.get("main_relative_path", ""))
	if main_relative_path.is_empty():
		return null
	var model: Node3D = _load_gltf_scene(model_root.path_join(main_relative_path))
	if model == null:
		return null

	var marker_writer: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
	if marker_writer == null:
		model.free()
		return null
	marker_writer.store_line(main_relative_path)
	marker_writer.store_line(str(total_bytes))
	marker_writer.close()
	return model


func _download_record(record: Dictionary, destination: String) -> bool:
	var expected_size: int = int(record.get("size", 0))
	var expected_md5: String = str(record.get("md5", "")).to_lower()
	if FileAccess.file_exists(destination):
		if _file_matches(destination, expected_size, expected_md5):
			return true
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(destination.get_base_dir())
	)
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 180.0
	request_node.download_file = destination
	add_child(request_node)
	var request_error: Error = request_node.request(
		str(record.get("url", "")),
		REQUEST_HEADERS
	)
	if request_error != OK:
		request_node.queue_free()
		return false

	var response: Array = await request_node.request_completed
	request_node.queue_free()
	var succeeded: bool = (
		response.size() >= 2
		and int(response[0]) == HTTPRequest.RESULT_SUCCESS
		and int(response[1]) >= 200
		and int(response[1]) < 300
		and FileAccess.file_exists(destination)
		and _file_matches(destination, expected_size, expected_md5)
	)
	if not succeeded and FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	return succeeded


func _file_matches(path: String, expected_size: int, expected_md5: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var actual_size: int = file.get_length()
	file.close()
	if expected_size > 0 and actual_size != expected_size:
		return false
	if not expected_md5.is_empty():
		return FileAccess.get_md5(path).to_lower() == expected_md5
	return true
