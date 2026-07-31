extends Node

const KENNEY_COMMIT: String = "4535092b740b378b700efd9df9e27a631815b84a"
const RAW_MODEL_ROOT: String = "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-City-Builder/%s/models/" % KENNEY_COMMIT
const CACHE_ROOT: String = "user://kenney_city"
const TEXTURE_PATH: String = "Textures/colormap.png"

const MODEL_FILES: Array[String] = [
	"road-straight.glb",
	"road-intersection.glb",
	"road-corner.glb",
	"road-split.glb",
	"road-straight-lightposts.glb",
	"pavement.glb",
	"pavement-fountain.glb",
	"building-small-a.glb",
	"building-small-b.glb",
	"building-small-c.glb",
	"building-small-d.glb",
	"building-garage.glb",
	"grass-trees.glb",
	"grass-trees-tall.glb"
]

var _root: Node3D
var _status_canvas: CanvasLayer
var _status_label: Label
var _prototype_cache: Dictionary = {}
var _kenney_container: Node3D


func _ready() -> void:
	call_deferred("_start_kenney_city")


func _start_kenney_city() -> void:
	_root = get_parent() as Node3D
	if _root == null:
		return

	_create_status_display()
	_ensure_cache_directories()

	if not _all_assets_cached():
		_set_status("DOWNLOADING OFFICIAL KENNEY CITY MODELS...")
		var download_succeeded: bool = await _download_missing_assets()
		if not download_succeeded:
			_set_status("KENNEY CITY DOWNLOAD FAILED — USING BUILT-IN CITY")
			await get_tree().create_timer(4.0).timeout
			_remove_status_display()
			return

	_set_status("BUILDING THE AFTERLIFE CITY...")
	await get_tree().process_frame
	_build_kenney_city()
	_set_status("KENNEY CITY LOADED")
	await get_tree().create_timer(1.8).timeout
	_remove_status_display()


func _ensure_cache_directories() -> void:
	var cache_absolute: String = ProjectSettings.globalize_path(CACHE_ROOT)
	var texture_absolute: String = ProjectSettings.globalize_path(CACHE_ROOT.path_join("Textures"))
	DirAccess.make_dir_recursive_absolute(cache_absolute)
	DirAccess.make_dir_recursive_absolute(texture_absolute)


func _all_assets_cached() -> bool:
	if not FileAccess.file_exists(CACHE_ROOT.path_join(TEXTURE_PATH)):
		return false
	for file_name: String in MODEL_FILES:
		if not FileAccess.file_exists(CACHE_ROOT.path_join(file_name)):
			return false
	return true


func _download_missing_assets() -> bool:
	var files_to_download: Array[String] = [TEXTURE_PATH]
	files_to_download.append_array(MODEL_FILES)

	for relative_path: String in files_to_download:
		var local_path: String = CACHE_ROOT.path_join(relative_path)
		if FileAccess.file_exists(local_path):
			continue
		_set_status("DOWNLOADING KENNEY ASSET  %s" % relative_path.get_file().to_upper())
		var downloaded: bool = await _download_file(relative_path, local_path)
		if not downloaded:
			return false
	return true


func _download_file(relative_path: String, local_path: String) -> bool:
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 35.0
	request_node.download_file = local_path
	add_child(request_node)

	var request_error: int = request_node.request(RAW_MODEL_ROOT + relative_path)
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


func _build_kenney_city() -> void:
	_hide_procedural_city_shells()
	_kenney_container = Node3D.new()
	_kenney_container.name = "KenneyCityModels"
	_root.add_child(_kenney_container)

	_build_kenney_road()
	_build_kenney_sidewalks()
	_build_kenney_buildings()
	_build_kenney_greenery()
	_build_kenney_plaza()


func _hide_procedural_city_shells() -> void:
	var root_children: Array[Node] = _root.get_children()
	for child: Node in root_children:
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance != null:
			var mesh_name: String = str(mesh_instance.name)
			if mesh_name in ["Road", "LeftSidewalk", "RightSidewalk", "RoadMarker"]:
				mesh_instance.visible = false
			continue

		var static_body: StaticBody3D = child as StaticBody3D
		if static_body == null:
			continue
		var is_procedural_building: bool = (
			absf(static_body.position.x) > 9.0
			and static_body.position.z > -50.0
			and static_body.position.z < 42.0
		)
		if is_procedural_building:
			_set_mesh_visibility(static_body, false)


func _set_mesh_visibility(parent_node: Node, visible_value: bool) -> void:
	var descendants: Array[Node] = parent_node.find_children("*", "MeshInstance3D", true, false)
	for descendant: Node in descendants:
		var mesh_instance: MeshInstance3D = descendant as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = visible_value


func _build_kenney_road() -> void:
	var road_z_values: Array[float] = [35.0, 25.0, 15.0, 5.0, -5.0, -15.0, -25.0, -35.0, -45.0]
	for index: int in range(road_z_values.size()):
		var model_name: String = "road-straight.glb"
		if index == 3:
			model_name = "road-intersection.glb"
		elif index == 7:
			model_name = "road-straight-lightposts.glb"
		_instantiate_model(
			model_name,
			Vector3(0.0, 0.02, road_z_values[index]),
			Vector3.ZERO,
			Vector3(10.0, 10.0, 10.0),
			Color("6f7391")
		)


func _build_kenney_sidewalks() -> void:
	var sidewalk_z_values: Array[float] = [35.0, 25.0, 15.0, 5.0, -5.0, -15.0, -25.0, -35.0, -45.0]
	var sidewalk_x_values: Array[float] = [-7.0, 7.0]
	for z_position: float in sidewalk_z_values:
		for x_position: float in sidewalk_x_values:
			_instantiate_model(
				"pavement.glb",
				Vector3(x_position, 0.03, z_position),
				Vector3.ZERO,
				Vector3(4.0, 4.0, 10.0),
				Color("6b647f")
			)


func _build_kenney_buildings() -> void:
	var building_z_values: Array[float] = [34.0, 21.0, 8.0, -5.0, -18.0, -31.0, -44.0]
	var model_names: Array[String] = [
		"building-small-a.glb",
		"building-small-b.glb",
		"building-small-c.glb",
		"building-small-d.glb"
	]

	for index: int in range(building_z_values.size()):
		var z_position: float = building_z_values[index]
		var left_scale: float = 8.5 + float(index % 3) * 1.35
		var right_scale: float = 9.0 + float((index + 1) % 4) * 1.05
		var left_tint: Color = Color("77719b") if index % 2 == 0 else Color("765f89")
		var right_tint: Color = Color("6a789d") if index % 2 == 0 else Color("875f7d")

		_instantiate_model(
			model_names[index % model_names.size()],
			Vector3(-14.0, 0.0, z_position),
			Vector3(0.0, -90.0, 0.0),
			Vector3(left_scale, left_scale, left_scale),
			left_tint
		)
		_instantiate_model(
			model_names[(index + 2) % model_names.size()],
			Vector3(14.0, 0.0, z_position - 2.0),
			Vector3(0.0, 90.0, 0.0),
			Vector3(right_scale, right_scale, right_scale),
			right_tint
		)

	_instantiate_model(
		"building-garage.glb",
		Vector3(-14.0, 0.0, -50.5),
		Vector3(0.0, -90.0, 0.0),
		Vector3(9.5, 9.5, 9.5),
		Color("75475f")
	)


func _build_kenney_greenery() -> void:
	var tree_z_values: Array[float] = [31.0, 13.0, -6.0, -25.0, -42.0]
	for index: int in range(tree_z_values.size()):
		var model_name: String = "grass-trees-tall.glb" if index % 2 == 0 else "grass-trees.glb"
		_instantiate_model(
			model_name,
			Vector3(-22.0, 0.0, tree_z_values[index]),
			Vector3(0.0, float(index) * 31.0, 0.0),
			Vector3(7.0, 7.0, 7.0),
			Color("3f5260")
		)
		_instantiate_model(
			model_name,
			Vector3(22.0, 0.0, tree_z_values[index] - 5.0),
			Vector3(0.0, 180.0 - float(index) * 24.0, 0.0),
			Vector3(6.5, 6.5, 6.5),
			Color("503e5d")
		)


func _build_kenney_plaza() -> void:
	_instantiate_model(
		"pavement-fountain.glb",
		Vector3(-7.0, 0.04, 27.0),
		Vector3.ZERO,
		Vector3(4.0, 4.0, 4.0),
		Color("836f9b")
	)
	_instantiate_model(
		"road-split.glb",
		Vector3(0.0, 0.025, -52.0),
		Vector3.ZERO,
		Vector3(10.0, 10.0, 10.0),
		Color("746a86")
	)


func _instantiate_model(
	file_name: String,
	model_position: Vector3,
	model_rotation: Vector3,
	model_scale: Vector3,
	tint: Color
) -> void:
	var prototype: Node3D = _load_prototype(file_name)
	if prototype == null:
		return
	var model_instance: Node3D = prototype.duplicate() as Node3D
	if model_instance == null:
		return
	model_instance.name = "Kenney_%s" % file_name.get_basename().replace("-", "_")
	model_instance.position = model_position
	model_instance.rotation_degrees = model_rotation
	model_instance.scale = model_scale
	_kenney_container.add_child(model_instance)
	_tint_model(model_instance, tint)


func _load_prototype(file_name: String) -> Node3D:
	if _prototype_cache.has(file_name):
		return _prototype_cache[file_name] as Node3D

	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var file_path: String = CACHE_ROOT.path_join(file_name)
	var import_error: int = document.append_from_file(file_path, state, 0, CACHE_ROOT)
	if import_error != OK:
		push_warning("Could not load Kenney model: %s" % file_name)
		return null

	var generated_scene: Node = document.generate_scene(state)
	var prototype: Node3D = generated_scene as Node3D
	if prototype == null:
		push_warning("Kenney model did not generate a Node3D: %s" % file_name)
		return null
	_prototype_cache[file_name] = prototype
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
			tinted_material.roughness = maxf(tinted_material.roughness, 0.62)
			mesh_instance.set_surface_override_material(surface_index, tinted_material)


func _create_status_display() -> void:
	_status_canvas = CanvasLayer.new()
	_status_canvas.layer = 90
	add_child(_status_canvas)

	var panel: ColorRect = ColorRect.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = 22.0
	panel.offset_bottom = 70.0
	panel.color = Color(0.02, 0.01, 0.05, 0.86)
	_status_canvas.add_child(panel)

	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color("e5b4e8"))
	panel.add_child(_status_label)


func _set_status(status_text: String) -> void:
	if _status_label != null:
		_status_label.text = status_text


func _remove_status_display() -> void:
	if _status_canvas != null:
		_status_canvas.queue_free()
	_status_canvas = null
	_status_label = null
