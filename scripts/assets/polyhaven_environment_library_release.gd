extends Node

const API_ROOT: String = "https://api.polyhaven.com/files/"
const CACHE_ROOT: String = "user://out_of_time_polyhaven_required_v2"
const MAX_ASSET_BYTES: int = 50 * 1024 * 1024
const COMPLETE_MARKER_NAME: String = ".exact_bundle_complete"

var _request_headers: PackedStringArray = PackedStringArray([
	"User-Agent: OutOfTimeGame/1.0",
	"Accept: application/json"
])

var _legacy_api_ids: Dictionary = {
	"chandelier_01": "Chandelier_01",
	"shelf_01": "Shelf_01",
	"wooden_chair_01": "WoodenChair_01"
}

var _required_model_ids: Array[String] = [
	"street_lamp_01",
	"painted_wooden_bench",
	"dead_quiver_trunk",
	"street_lamp_02",
	"concrete_road_barrier_02",
	"marble_bust_01",
	"chandelier_01",
	"flower_empodium",
	"bar_chair_round_01",
	"industrial_coffee_table",
	"wine_barrel_01",
	"industrial_wall_sconce",
	"shelf_01",
	"gothic_coffee_table",
	"wooden_chair_01"
]

var _required_material_ids: Array[String] = [
	"monastery_stone_floor",
	"asphalt_02",
	"marble_01",
	"scuffed_cement",
	"stone_floor",
	"rock_ground"
]

var _model_prototypes: Dictionary = {}
var _surface_materials: Dictionary = {}
var _last_error: String = ""


func prepare() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	_model_prototypes.clear()
	_surface_materials.clear()
	_last_error = ""

	for asset_id: String in _required_model_ids:
		var prototype: Node3D = await _prepare_model(asset_id)
		if prototype == null:
			_last_error = "Required Poly Haven model failed: %s" % asset_id
			push_error(_last_error)
			return false
		_model_prototypes[asset_id] = prototype
		await get_tree().process_frame

	for material_id: String in _required_material_ids:
		var material: StandardMaterial3D = await _prepare_material(material_id)
		if material == null:
			_last_error = "Required Poly Haven PBR material failed: %s" % material_id
			push_error(_last_error)
			return false
		_surface_materials[material_id] = material
		await get_tree().process_frame

	return true


func get_model_prototype(asset_id: String) -> Node3D:
	return _model_prototypes.get(asset_id) as Node3D


func get_surface_material(material_id: String) -> StandardMaterial3D:
	return _surface_materials.get(material_id) as StandardMaterial3D


func get_last_error() -> String:
	return _last_error


func _prepare_model(asset_id: String) -> Node3D:
	var model_root: String = CACHE_ROOT.path_join("models").path_join(asset_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(model_root))
	var marker_path: String = model_root.path_join(COMPLETE_MARKER_NAME)

	var cached_model: Node3D = _load_completed_model(model_root, marker_path)
	if cached_model != null:
		return cached_model

	_clear_directory(model_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(model_root))

	var payload_variant: Variant = await _request_asset_json(asset_id)
	if not (payload_variant is Dictionary):
		return null
	var bundle: Dictionary = _select_model_bundle(payload_variant as Dictionary)
	if bundle.is_empty():
		push_error("No complete glTF bundle under 50 MB was found for %s." % asset_id)
		return null

	var total_bytes: int = int(bundle.get("total_bytes", 0))
	if total_bytes <= 0 or total_bytes > MAX_ASSET_BYTES:
		push_error("%s bundle exceeds the 50 MB asset limit." % asset_id)
		return null

	var records_variant: Variant = bundle.get("records", [])
	if not (records_variant is Array):
		return null
	for record_variant: Variant in records_variant as Array:
		if not (record_variant is Dictionary):
			return null
		var record: Dictionary = record_variant as Dictionary
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


func _load_completed_model(model_root: String, marker_path: String) -> Node3D:
	if not FileAccess.file_exists(marker_path):
		return null
	var marker_reader: FileAccess = FileAccess.open(marker_path, FileAccess.READ)
	if marker_reader == null:
		return null
	var main_relative_path: String = marker_reader.get_line().strip_edges()
	marker_reader.close()
	if main_relative_path.is_empty():
		return null
	var model: Node3D = _load_gltf_scene(model_root.path_join(main_relative_path))
	if model != null:
		return model
	DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	return null


func _prepare_material(asset_id: String) -> StandardMaterial3D:
	var material_root: String = CACHE_ROOT.path_join("materials").path_join(asset_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(material_root))

	var cached_material: StandardMaterial3D = _load_cached_material(material_root, asset_id)
	if cached_material != null:
		return cached_material

	var payload_variant: Variant = await _request_asset_json(asset_id)
	if not (payload_variant is Dictionary):
		return null
	var payload: Dictionary = payload_variant as Dictionary
	var diffuse_record: Dictionary = _select_texture_record(payload, ["diff"])
	var normal_record: Dictionary = _select_texture_record(payload, ["nor_gl"])
	var rough_record: Dictionary = _select_texture_record(payload, ["rough"])
	if diffuse_record.is_empty() or normal_record.is_empty() or rough_record.is_empty():
		push_error("Incomplete 1K PBR texture set for %s." % asset_id)
		return null

	var diffuse_path: String = await _download_texture_record(diffuse_record, material_root)
	var normal_path: String = await _download_texture_record(normal_record, material_root)
	var rough_path: String = await _download_texture_record(rough_record, material_root)
	if diffuse_path.is_empty() or normal_path.is_empty() or rough_path.is_empty():
		return null

	return _material_from_paths(asset_id, diffuse_path, normal_path, rough_path)


func _load_cached_material(material_root: String, asset_id: String) -> StandardMaterial3D:
	var directory: DirAccess = DirAccess.open(material_root)
	if directory == null:
		return null
	var diffuse_path: String = ""
	var normal_path: String = ""
	var rough_path: String = ""
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir():
			var lower_name: String = file_name.to_lower()
			if lower_name.contains("diff") and _is_image_file(lower_name):
				diffuse_path = material_root.path_join(file_name)
			elif lower_name.contains("nor_gl") and _is_image_file(lower_name):
				normal_path = material_root.path_join(file_name)
			elif lower_name.contains("rough") and _is_image_file(lower_name):
				rough_path = material_root.path_join(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	if diffuse_path.is_empty() or normal_path.is_empty() or rough_path.is_empty():
		return null
	return _material_from_paths(asset_id, diffuse_path, normal_path, rough_path)


func _material_from_paths(
	asset_id: String,
	diffuse_path: String,
	normal_path: String,
	rough_path: String
) -> StandardMaterial3D:
	var diffuse_texture: Texture2D = _load_image_texture(diffuse_path)
	var normal_texture: Texture2D = _load_image_texture(normal_path)
	var rough_texture: Texture2D = _load_image_texture(rough_path)
	if diffuse_texture == null or normal_texture == null or rough_texture == null:
		return null
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "PolyHaven_%s" % asset_id
	material.albedo_texture = diffuse_texture
	material.normal_enabled = true
	material.normal_texture = normal_texture
	material.roughness = 1.0
	material.roughness_texture = rough_texture
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	return material


func _request_asset_json(asset_id: String) -> Variant:
	var payload: Variant = await _request_json(API_ROOT + asset_id)
	if payload is Dictionary:
		return payload
	var legacy_id: String = str(_legacy_api_ids.get(asset_id, ""))
	if legacy_id.is_empty():
		return null
	return await _request_json(API_ROOT + legacy_id)


func _request_json(url: String) -> Variant:
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 90.0
	add_child(request_node)
	var request_error: Error = request_node.request(url, _request_headers)
	if request_error != OK:
		request_node.queue_free()
		return null
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	if response.size() < 4:
		return null
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return null
	var http_code: int = int(response[1])
	if http_code < 200 or http_code >= 300:
		return null
	var body: PackedByteArray = response[3] as PackedByteArray
	return JSON.parse_string(body.get_string_from_utf8())


func _select_model_bundle(payload: Dictionary) -> Dictionary:
	var gltf_variant: Variant = payload.get("gltf")
	if not (gltf_variant is Dictionary):
		return {}
	var gltf_group: Dictionary = gltf_variant as Dictionary
	for resolution: String in ["1k", "2k", "4k"]:
		var resolution_variant: Variant = gltf_group.get(resolution)
		if not (resolution_variant is Dictionary):
			continue
		var records: Array = []
		_collect_file_records(resolution_variant, [], records)
		var main_record: Dictionary = {}
		for record_variant: Variant in records:
			var record: Dictionary = record_variant as Dictionary
			var url: String = str(record.get("url", "")).to_lower()
			if url.ends_with(".gltf") or url.ends_with(".glb"):
				main_record = record
				break
		if main_record.is_empty():
			continue

		var unique_records: Array = []
		var seen_urls: Dictionary = {}
		var total_bytes: int = 0
		for record_variant: Variant in records:
			var record: Dictionary = record_variant as Dictionary
			var url: String = str(record.get("url", ""))
			if url.is_empty() or seen_urls.has(url):
				continue
			var relative_path: String = _record_relative_path(record)
			var size_bytes: int = int(record.get("size", 0))
			if relative_path.is_empty() or size_bytes <= 0:
				continue
			var stored_record: Dictionary = record.duplicate(true)
			stored_record["relative_path"] = relative_path
			unique_records.append(stored_record)
			seen_urls[url] = true
			total_bytes += size_bytes
		if total_bytes <= 0 or total_bytes > MAX_ASSET_BYTES:
			continue
		return {
			"records": unique_records,
			"total_bytes": total_bytes,
			"main_relative_path": _record_relative_path(main_record)
		}
	return {}


func _collect_file_records(value: Variant, path_parts: Array, output: Array) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary
		if dictionary.has("url"):
			output.append({
				"url": str(dictionary.get("url", "")),
				"size": int(dictionary.get("size", 0)),
				"md5": str(dictionary.get("md5", "")),
				"path_parts": path_parts.duplicate()
			})
		for key_variant: Variant in dictionary.keys():
			var key: String = str(key_variant)
			if key == "url" or key == "size" or key == "md5":
				continue
			var next_path: Array = path_parts.duplicate()
			next_path.append(key)
			_collect_file_records(dictionary[key_variant], next_path, output)
	elif value is Array:
		var array_value: Array = value as Array
		for index: int in range(array_value.size()):
			var next_path: Array = path_parts.duplicate()
			next_path.append(str(index))
			_collect_file_records(array_value[index], next_path, output)


func _record_relative_path(record: Dictionary) -> String:
	var path_variant: Variant = record.get("path_parts", [])
	if path_variant is Array:
		var path_parts: Array = path_variant as Array
		var include_index: int = path_parts.find("include")
		if include_index >= 0 and include_index + 1 < path_parts.size():
			var dependency_parts: PackedStringArray = PackedStringArray()
			for index: int in range(include_index + 1, path_parts.size()):
				var part: String = str(path_parts[index])
				if not part.is_empty() and not part.is_valid_int():
					dependency_parts.append(part)
			if not dependency_parts.is_empty():
				return "/".join(dependency_parts)
	var url: String = str(record.get("url", ""))
	return url.get_file().uri_decode()


func _select_texture_record(payload: Dictionary, markers: Array[String]) -> Dictionary:
	var records: Array = []
	_collect_file_records(payload, [], records)
	var best_record: Dictionary = {}
	var best_score: int = -1000000
	for record_variant: Variant in records:
		var record: Dictionary = record_variant as Dictionary
		var url: String = str(record.get("url", "")).to_lower()
		if not _is_image_file(url):
			continue
		var path_text: String = _record_path_text(record)
		var matches: bool = true
		for marker: String in markers:
			if not path_text.contains(marker):
				matches = false
				break
		if not matches:
			continue
		if path_text.contains("nor_dx") or path_text.contains("disp") or path_text.contains("preview"):
			continue
		var score: int = 0
		if path_text.contains("1k"):
			score += 100
		elif path_text.contains("2k"):
			score += 40
		else:
			score -= 60
		if url.ends_with(".jpg"):
			score += 12
		elif url.ends_with(".png"):
			score += 8
		if score > best_score:
			best_score = score
			best_record = record
	return best_record


func _record_path_text(record: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var path_variant: Variant = record.get("path_parts", [])
	if path_variant is Array:
		for part_variant: Variant in path_variant as Array:
			parts.append(str(part_variant).to_lower())
	parts.append(str(record.get("url", "")).to_lower())
	return "/".join(parts)


func _download_texture_record(record: Dictionary, material_root: String) -> String:
	var url: String = str(record.get("url", ""))
	if url.is_empty():
		return ""
	var destination: String = material_root.path_join(url.get_file().uri_decode())
	if not await _download_record(record, destination):
		return ""
	return destination


func _download_record(record: Dictionary, destination: String) -> bool:
	var expected_size: int = int(record.get("size", 0))
	var expected_md5: String = str(record.get("md5", "")).to_lower()
	if FileAccess.file_exists(destination):
		if _file_matches(destination, expected_size, expected_md5):
			return true
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 180.0
	request_node.download_file = destination
	add_child(request_node)
	var request_error: Error = request_node.request(str(record.get("url", "")), _request_headers)
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


func _load_gltf_scene(model_path: String) -> Node3D:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var import_error: Error = document.append_from_file(model_path, state, 0, model_path.get_base_dir())
	if import_error != OK:
		return null
	var generated_scene: Node = document.generate_scene(state)
	var generated_root: Node3D = generated_scene as Node3D
	if generated_root == null:
		if generated_scene != null:
			generated_scene.free()
		return null
	return generated_root


func _load_image_texture(image_path: String) -> Texture2D:
	var image: Image = Image.new()
	if image.load(image_path) != OK:
		return null
	if not image.has_mipmaps():
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _is_image_file(path: String) -> bool:
	var lower_path: String = path.to_lower()
	return lower_path.ends_with(".jpg") or lower_path.ends_with(".jpeg") or lower_path.ends_with(".png")


func _clear_directory(directory_path: String) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path: String = directory_path.path_join(entry_name)
			if directory.current_is_dir():
				_clear_directory(entry_path)
				DirAccess.remove_absolute(ProjectSettings.globalize_path(entry_path))
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(entry_path))
		entry_name = directory.get_next()
	directory.list_dir_end()
