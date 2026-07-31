extends Node

const CACHE_ROOT: String = "user://kenney_void_assets"
const SPACE_STATION_URL: String = "https://kenney.nl/media/pages/assets/space-station-kit/6475288f2e-1712749919/kenney_space-station-kit.zip"
const SPACE_KIT_URL: String = "https://www.kenney.nl/media/pages/assets/space-kit/20874c75ac-1677698978/kenney_space-kit.zip"

const SOURCE_IDS: Array[String] = ["station", "space"]

var _root: Node3D
var _model_container: Node3D
var _source_models: Dictionary = {}
var _prototype_cache: Dictionary = {}
var _animated_models: Array[Node3D] = []
var _status_canvas: CanvasLayer
var _status_label: Label


func _ready() -> void:
	_start_loading.call_deferred()


func _process(delta: float) -> void:
	for model: Node3D in _animated_models:
		if not is_instance_valid(model):
			continue
		var rotation_speed: float = float(model.get_meta("rotation_speed", 0.0))
		model.rotate_y(deg_to_rad(rotation_speed * delta))
		var tumble_speed: float = float(model.get_meta("tumble_speed", 0.0))
		model.rotate_x(deg_to_rad(tumble_speed * delta))


func _start_loading() -> void:
	_root = get_parent() as Node3D
	if _root == null or str(_root.name) != "AfterlifeVoid":
		return
	if _root.get_node_or_null("VoidGLBModels") != null:
		return

	_ensure_cache_directories()
	_create_status_display()
	_set_status("PREPARING FREE VOID GLB ASSETS...")

	for source_id: String in SOURCE_IDS:
		var source_ready: bool = await _ensure_source_ready(source_id)
		if not source_ready:
			_set_status("SOME VOID MODELS COULD NOT LOAD — USING PROCEDURAL ART")
			await get_tree().create_timer(2.4).timeout
			_remove_status_display()
			return

	_model_container = Node3D.new()
	_model_container.name = "VoidGLBModels"
	_root.add_child(_model_container)
	_build_void_model_pass()
	_set_status("FREE VOID GLB MODELS LOADED")
	await get_tree().create_timer(1.2).timeout
	_remove_status_display()


func _ensure_cache_directories() -> void:
	for source_id: String in SOURCE_IDS:
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(_models_root(source_id))
		)


func _ensure_source_ready(source_id: String) -> bool:
	var existing_models: Array[String] = _scan_source_models(source_id)
	if not existing_models.is_empty():
		_source_models[source_id] = existing_models
		return true

	_set_status("DOWNLOADING %s..." % _source_display_name(source_id))
	var zip_path: String = CACHE_ROOT.path_join("%s.zip" % source_id)
	var downloaded: bool = await _download_file(_source_url(source_id), zip_path)
	if not downloaded:
		return false

	_set_status("EXTRACTING %s GLBS..." % _source_display_name(source_id))
	var extracted: bool = _extract_glbs(source_id, zip_path)
	if not extracted:
		return false

	var extracted_models: Array[String] = _scan_source_models(source_id)
	_source_models[source_id] = extracted_models
	return not extracted_models.is_empty()


func _download_file(remote_url: String, local_path: String) -> bool:
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 60.0
	request_node.download_file = local_path
	add_child(request_node)

	var request_error: int = request_node.request(remote_url)
	if request_error != OK:
		request_node.queue_free()
		return false

	var response: Array = await request_node.request_completed
	request_node.queue_free()
	var request_result: int = int(response[0])
	var response_code: int = int(response[1])
	var succeeded: bool = (
		request_result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 300
		and FileAccess.file_exists(local_path)
	)
	if not succeeded and FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	return succeeded


func _extract_glbs(source_id: String, zip_path: String) -> bool:
	var reader: ZIPReader = ZIPReader.new()
	var open_error: int = reader.open(ProjectSettings.globalize_path(zip_path))
	if open_error != OK:
		return false

	var extracted_count: int = 0
	var archive_files: PackedStringArray = reader.get_files()
	for internal_path: String in archive_files:
		if not internal_path.to_lower().ends_with(".glb"):
			continue
		var model_bytes: PackedByteArray = reader.read_file(internal_path)
		if model_bytes.is_empty():
			continue

		var safe_name: String = internal_path.to_lower()
		safe_name = safe_name.replace("\\", "__")
		safe_name = safe_name.replace("/", "__")
		safe_name = safe_name.replace(" ", "-")
		var destination_path: String = _models_root(source_id).path_join(safe_name)
		var output_file: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
		if output_file == null:
			continue
		output_file.store_buffer(model_bytes)
		output_file.close()
		extracted_count += 1

	reader.close()
	return extracted_count > 0


func _scan_source_models(source_id: String) -> Array[String]:
	var results: Array[String] = []
	var directory: DirAccess = DirAccess.open(_models_root(source_id))
	if directory == null:
		return results

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.to_lower().ends_with(".glb"):
			results.append(_models_root(source_id).path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	results.sort()
	return results


func _build_void_model_pass() -> void:
	_build_arrival_station_ruins()
	_build_low_gravity_satellites()
	_build_inversion_station_ceiling()
	_build_drift_field_models()
	_build_portal_station_remains()
	_build_distant_space_models()


func _build_arrival_station_ruins() -> void:
	_place_keyword_model(
		"station", ["structure"], ["barrier"],
		Vector3(-8.0, 0.2, 52.0), Vector3(12.0, 25.0, -8.0), Vector3(3.2, 3.2, 3.2),
		Color("665779"), "ArrivalStructureLeft", 0.8, 0.0
	)
	_place_keyword_model(
		"station", ["structure", "panel"], [],
		Vector3(8.0, 1.0, 50.0), Vector3(-10.0, 205.0, 12.0), Vector3(3.5, 3.5, 3.5),
		Color("594a70"), "ArrivalStructureRight", -0.6, 0.0
	)
	_place_keyword_model(
		"station", ["rocks"], [],
		Vector3(-15.0, -4.0, 46.0), Vector3(18.0, 42.0, 12.0), Vector3(5.5, 5.5, 5.5),
		Color("51465d"), "ArrivalRockCluster", 0.4, 0.25
	)


func _build_low_gravity_satellites() -> void:
	_place_keyword_model(
		"space", ["satellite"], [],
		Vector3(-15.0, 10.0, 31.0), Vector3(18.0, 36.0, -12.0), Vector3(3.4, 3.4, 3.4),
		Color("6d6b89"), "LowGravitySatellite", 2.8, 1.0
	)
	_place_keyword_model(
		"station", ["structure", "barrier"], [],
		Vector3(13.0, 6.0, 20.0), Vector3(32.0, 84.0, 18.0), Vector3(4.0, 4.0, 4.0),
		Color("685474"), "LowGravityBarrier", -1.4, 0.4
	)
	_place_keyword_model(
		"space", ["asteroid"], [],
		Vector3(18.0, -3.0, 9.0), Vector3(12.0, 58.0, 24.0), Vector3(6.5, 6.5, 6.5),
		Color("56495f"), "LowGravityAsteroid", 0.6, -0.3
	)


func _build_inversion_station_ceiling() -> void:
	var wall_positions: Array[Vector3] = [
		Vector3(-7.0, 14.2, -5.0), Vector3(7.0, 14.2, -14.0),
		Vector3(-7.0, 14.2, -24.0), Vector3(7.0, 14.2, -34.0)
	]
	for index: int in range(wall_positions.size()):
		var includes: Array[String] = ["wall", "window"] if index % 2 == 0 else ["wall", "pillar"]
		_place_keyword_model(
			"station", includes, [],
			wall_positions[index], Vector3(180.0, float(index) * 90.0, 0.0), Vector3(4.5, 4.5, 4.5),
			Color("604c73") if index % 2 == 0 else Color("4f4569"),
			"InversionStationPart%d" % index, float(index - 2) * 0.25, 0.0
		)

	_place_keyword_model(
		"station", ["stairs"], [],
		Vector3(0.0, 13.8, -20.0), Vector3(180.0, 0.0, 0.0), Vector3(4.0, 4.0, 4.0),
		Color("654e76"), "InversionStairs", 0.0, 0.0
	)


func _build_drift_field_models() -> void:
	_place_keyword_model(
		"space", ["asteroid"], [],
		Vector3(-18.0, 2.0, -53.0), Vector3(21.0, 17.0, 9.0), Vector3(8.5, 8.5, 8.5),
		Color("54445c"), "DriftAsteroidA", 1.2, 0.45
	)
	_place_keyword_model(
		"space", ["asteroid"], [],
		Vector3(20.0, 13.0, -72.0), Vector3(-12.0, 64.0, 25.0), Vector3(6.0, 6.0, 6.0),
		Color("5b4965"), "DriftAsteroidB", -1.0, -0.5
	)
	_place_keyword_model(
		"station", ["table", "planet"], [],
		Vector3(-5.0, 9.1, -81.0), Vector3(0.0, 32.0, 0.0), Vector3(3.2, 3.2, 3.2),
		Color("705989"), "DriftPlanetDisplay", 3.2, 0.0
	)
	_place_keyword_model(
		"space", ["ship"], [],
		Vector3(26.0, 16.0, -86.0), Vector3(20.0, 214.0, -14.0), Vector3(4.8, 4.8, 4.8),
		Color("594e72"), "DriftingShipWreck", -0.8, 0.3
	)


func _build_portal_station_remains() -> void:
	_place_keyword_model(
		"station", ["wall", "door", "wide"], [],
		Vector3(0.0, 0.0, -121.5), Vector3(0.0, 180.0, 0.0), Vector3(6.0, 6.0, 6.0),
		Color("6f4f72"), "PortalDoorFrame", 0.0, 0.0
	)
	_place_keyword_model(
		"station", ["wall", "pillar"], [],
		Vector3(-8.0, 0.0, -119.0), Vector3(0.0, 90.0, -10.0), Vector3(5.5, 5.5, 5.5),
		Color("5f4c69"), "PortalPillarLeft", 0.0, 0.0
	)
	_place_keyword_model(
		"station", ["wall", "pillar"], [],
		Vector3(8.0, 0.0, -119.0), Vector3(0.0, -90.0, 10.0), Vector3(5.5, 5.5, 5.5),
		Color("5f4c69"), "PortalPillarRight", 0.0, 0.0
	)
	_place_keyword_model(
		"station", ["rocks"], [],
		Vector3(10.0, -3.0, -113.0), Vector3(22.0, 11.0, -18.0), Vector3(5.0, 5.0, 5.0),
		Color("4c4056"), "PortalRockCluster", 0.5, 0.2
	)


func _build_distant_space_models() -> void:
	var planet_positions: Array[Vector3] = [
		Vector3(-64.0, 34.0, -45.0),
		Vector3(72.0, -18.0, -132.0)
	]
	for index: int in range(planet_positions.size()):
		_place_keyword_model(
			"space", ["planet"], ["ring"],
			planet_positions[index], Vector3(12.0 * float(index), 28.0 * float(index), 8.0),
			Vector3(18.0 + float(index) * 7.0, 18.0 + float(index) * 7.0, 18.0 + float(index) * 7.0),
			Color("6b4a82") if index == 0 else Color("594f8d"),
			"DistantPlanet%d" % index, 0.12 + float(index) * 0.08, 0.0
		)

	_place_keyword_model(
		"space", ["station"], [],
		Vector3(58.0, 20.0, 18.0), Vector3(22.0, 42.0, 13.0), Vector3(11.0, 11.0, 11.0),
		Color("504665"), "DistantSpaceStation", 0.22, 0.0
	)
	_place_keyword_model(
		"space", ["ship"], [],
		Vector3(-52.0, 12.0, -112.0), Vector3(-18.0, 48.0, 20.0), Vector3(7.0, 7.0, 7.0),
		Color("59496b"), "DistantShip", -0.32, 0.0
	)


func _place_keyword_model(
	source_id: String,
	include_keywords: Array[String],
	exclude_keywords: Array[String],
	model_position: Vector3,
	model_rotation: Vector3,
	model_scale: Vector3,
	tint: Color,
	model_name: String,
	rotation_speed: float,
	tumble_speed: float
) -> Node3D:
	var model_path: String = _find_model_path(source_id, include_keywords, exclude_keywords)
	if model_path.is_empty():
		return null

	var prototype: Node3D = _load_prototype(model_path)
	if prototype == null:
		return null
	var model_instance: Node3D = prototype.duplicate() as Node3D
	if model_instance == null:
		return null

	model_instance.name = model_name
	model_instance.position = model_position
	model_instance.rotation_degrees = model_rotation
	model_instance.scale = model_scale
	model_instance.set_meta("rotation_speed", rotation_speed)
	model_instance.set_meta("tumble_speed", tumble_speed)
	_model_container.add_child(model_instance)
	_tint_model(model_instance, tint)
	if not is_zero_approx(rotation_speed) or not is_zero_approx(tumble_speed):
		_animated_models.append(model_instance)
	return model_instance


func _find_model_path(source_id: String, include_keywords: Array[String], exclude_keywords: Array[String]) -> String:
	var models_variant: Variant = _source_models.get(source_id, [])
	var model_paths: Array[String] = []
	if models_variant is Array:
		for model_variant: Variant in models_variant:
			model_paths.append(str(model_variant))

	for model_path: String in model_paths:
		var lower_name: String = model_path.get_file().to_lower()
		var includes_all: bool = true
		for keyword: String in include_keywords:
			if not lower_name.contains(keyword.to_lower()):
				includes_all = false
				break
		if not includes_all:
			continue

		var excluded: bool = false
		for keyword: String in exclude_keywords:
			if lower_name.contains(keyword.to_lower()):
				excluded = true
				break
		if not excluded:
			return model_path
	return ""


func _load_prototype(model_path: String) -> Node3D:
	if _prototype_cache.has(model_path):
		return _prototype_cache[model_path] as Node3D

	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var base_path: String = model_path.get_base_dir()
	var import_error: int = document.append_from_file(model_path, state, 0, base_path)
	if import_error != OK:
		push_warning("Could not load free void GLB: %s" % model_path)
		return null

	var generated_scene: Node = document.generate_scene(state)
	var prototype: Node3D = generated_scene as Node3D
	if prototype == null:
		push_warning("Void GLB did not generate a Node3D: %s" % model_path)
		return null
	_prototype_cache[model_path] = prototype
	return prototype


func _tint_model(model_root: Node3D, tint: Color) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var standard_material: StandardMaterial3D = source_material as StandardMaterial3D
			if standard_material == null:
				continue
			var tinted_material: StandardMaterial3D = standard_material.duplicate() as StandardMaterial3D
			if tinted_material == null:
				continue
			tinted_material.albedo_color *= tint
			tinted_material.roughness = maxf(tinted_material.roughness, 0.64)
			mesh_instance.set_surface_override_material(surface_index, tinted_material)


func _source_url(source_id: String) -> String:
	return SPACE_STATION_URL if source_id == "station" else SPACE_KIT_URL


func _source_display_name(source_id: String) -> String:
	return "KENNEY SPACE STATION KIT" if source_id == "station" else "KENNEY SPACE KIT"


func _models_root(source_id: String) -> String:
	return CACHE_ROOT.path_join(source_id).path_join("models")


func _create_status_display() -> void:
	_status_canvas = CanvasLayer.new()
	_status_canvas.layer = 91
	add_child(_status_canvas)

	var panel: ColorRect = ColorRect.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -86.0
	panel.offset_bottom = -30.0
	panel.color = Color(0.02, 0.005, 0.05, 0.90)
	_status_canvas.add_child(panel)

	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("e2caef"))
	panel.add_child(_status_label)


func _set_status(status_text: String) -> void:
	if _status_label != null:
		_status_label.text = status_text


func _remove_status_display() -> void:
	if _status_canvas != null:
		_status_canvas.queue_free()
	_status_canvas = null
	_status_label = null
