extends "res://scripts/world/void_glb_expansion.gd"

const VERSIONED_CACHE_ROOT: String = "user://kenney_void_assets_v2"
const ZIP_CACHE_ROOT: String = "user://kenney_void_assets"


func _build_inversion_station_ceiling() -> void:
	var wall_positions: Array[Vector3] = [
		Vector3(-7.0, 14.2, -5.0), Vector3(7.0, 14.2, -14.0),
		Vector3(-7.0, 14.2, -24.0), Vector3(7.0, 14.2, -34.0)
	]
	var empty_excludes: Array[String] = []
	for index: int in range(wall_positions.size()):
		var includes: Array[String] = []
		if index % 2 == 0:
			includes.append("wall")
			includes.append("window")
		else:
			includes.append("wall")
			includes.append("pillar")
		_place_keyword_model(
			"station", includes, empty_excludes,
			wall_positions[index], Vector3(180.0, float(index) * 90.0, 0.0), Vector3(4.5, 4.5, 4.5),
			Color("604c73") if index % 2 == 0 else Color("4f4569"),
			"InversionStationPart%d" % index, float(index - 2) * 0.25, 0.0
		)

	var stair_includes: Array[String] = []
	stair_includes.append("stairs")
	_place_keyword_model(
		"station", stair_includes, empty_excludes,
		Vector3(0.0, 13.8, -20.0), Vector3(180.0, 0.0, 0.0), Vector3(4.0, 4.0, 4.0),
		Color("654e76"), "InversionStairs", 0.0, 0.0
	)


func _start_loading() -> void:
	_root = get_parent() as Node3D
	if _root == null or str(_root.name) != "AfterlifeVoid":
		return
	if _root.get_node_or_null("VoidGLBModels") != null:
		return
	if not StartupPreloader.is_ready():
		return

	var preloaded_sources: Dictionary = StartupPreloader.get_void_source_models()
	if preloaded_sources.is_empty():
		return
	_source_models = preloaded_sources

	_model_container = Node3D.new()
	_model_container.name = "VoidGLBModels"
	_root.add_child(_model_container)

	_build_arrival_station_ruins()
	await get_tree().process_frame
	_build_low_gravity_satellites()
	await get_tree().process_frame
	_build_inversion_station_ceiling()
	await get_tree().process_frame
	_build_drift_field_models()
	await get_tree().process_frame
	_build_portal_station_remains()
	await get_tree().process_frame
	_build_distant_space_models()


func _load_prototype(model_path: String) -> Node3D:
	if _prototype_cache.has(model_path):
		return _prototype_cache[model_path] as Node3D

	var startup_prototype: Node3D = StartupPreloader.get_void_prototype(model_path)
	if startup_prototype != null:
		_prototype_cache[model_path] = startup_prototype
		return startup_prototype

	return super._load_prototype(model_path)


func _ensure_cache_directories() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZIP_CACHE_ROOT))
	for source_id: String in SOURCE_IDS:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_models_root(source_id)))


func _models_root(source_id: String) -> String:
	return VERSIONED_CACHE_ROOT.path_join(source_id)


func _extract_glbs(source_id: String, zip_path: String) -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: int = reader.open(ProjectSettings.globalize_path(zip_path))
	if open_error != OK:
		return false

	var extracted_model_count: int = 0
	var archive_files: PackedStringArray = reader.get_files()
	for internal_path: String in archive_files:
		var normalized_path: String = internal_path.replace("\\", "/")
		if normalized_path.ends_with("/") or normalized_path.contains(".."):
			continue
		if not _should_extract_archive_file(normalized_path):
			continue

		var destination_path: String = _models_root(source_id).path_join(normalized_path)
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(destination_path.get_base_dir())
		)

		var file_bytes: PackedByteArray = reader.read_file(internal_path)
		if file_bytes.is_empty():
			continue
		var output_file: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
		if output_file == null:
			continue
		output_file.store_buffer(file_bytes)
		output_file.close()

		if normalized_path.to_lower().ends_with(".glb"):
			extracted_model_count += 1

	reader.close()
	return extracted_model_count > 0


func _should_extract_archive_file(file_path: String) -> bool:
	var lower_path: String = file_path.to_lower()
	return (
		lower_path.ends_with(".glb")
		or lower_path.ends_with(".gltf")
		or lower_path.ends_with(".bin")
		or lower_path.ends_with(".png")
		or lower_path.ends_with(".jpg")
		or lower_path.ends_with(".jpeg")
		or lower_path.ends_with(".webp")
	)


func _scan_source_models(source_id: String) -> Array[String]:
	var results: Array[String] = []
	_scan_directory_for_glbs(_models_root(source_id), results)
	results.sort()
	return results


func _scan_directory_for_glbs(directory_path: String, results: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		var entry_path: String = directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_directory_for_glbs(entry_path, results)
		elif entry_name.to_lower().ends_with(".glb"):
			results.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
