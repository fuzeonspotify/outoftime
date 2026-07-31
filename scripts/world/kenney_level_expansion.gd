extends Node

const PLATFORMER_COMMIT: String = "3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0"
const FPS_COMMIT: String = "185fd2326d74a5cf858cffc616f87cf9696f9cc0"
const PLATFORMER_REMOTE_ROOT: String = "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-3D-Platformer/%s/models/" % PLATFORMER_COMMIT
const FPS_REMOTE_ROOT: String = "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-FPS/%s/models/" % FPS_COMMIT
const CACHE_ROOT: String = "user://kenney_level_expansion"
const TEXTURE_FILE: String = "Textures/colormap.png"

const PLATFORMER_FILES: Array[String] = [
	"brick.glb",
	"cloud.glb",
	"flag.glb",
	"grass-small.glb",
	"grass.glb",
	"platform-grass-large-round.glb",
	"platform-large.glb",
	"platform-medium.glb",
	"platform.glb"
]

const FPS_FILES: Array[String] = [
	"wall-high.glb",
	"wall-low.glb",
	"platform-large-grass.glb"
]

var _root: Node3D
var _model_container: Node3D
var _prototype_cache: Dictionary = {}
var _status_canvas: CanvasLayer
var _status_label: Label


func _ready() -> void:
	_start_expansion.call_deferred()


func _start_expansion() -> void:
	_root = get_parent() as Node3D
	if _root == null:
		return
	if _root.get_node_or_null("KenneyLevelModels") != null:
		return

	await get_tree().process_frame
	_ensure_cache_directories()

	if not _all_assets_cached():
		_create_status_display()
		_set_status("DOWNLOADING OFFICIAL KENNEY LEVEL MODELS...")
		var download_succeeded: bool = await _download_missing_assets()
		if not download_succeeded:
			_set_status("KENNEY MODEL DOWNLOAD FAILED — USING EXISTING ART")
			await get_tree().create_timer(3.0).timeout
			_remove_status_display()
			return

	_model_container = Node3D.new()
	_model_container.name = "KenneyLevelModels"
	_root.add_child(_model_container)
	_build_scene_expansion(str(_root.name))

	if _status_canvas != null:
		_set_status("KENNEY LEVEL MODELS LOADED")
		await get_tree().create_timer(1.2).timeout
		_remove_status_display()


func _ensure_cache_directories() -> void:
	var platformer_root: String = _source_cache_root("platformer")
	var fps_root: String = _source_cache_root("fps")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(platformer_root.path_join("Textures")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fps_root.path_join("Textures")))


func _all_assets_cached() -> bool:
	if not FileAccess.file_exists(_source_cache_root("platformer").path_join(TEXTURE_FILE)):
		return false
	if not FileAccess.file_exists(_source_cache_root("fps").path_join(TEXTURE_FILE)):
		return false

	for file_name: String in PLATFORMER_FILES:
		if not FileAccess.file_exists(_source_cache_root("platformer").path_join(file_name)):
			return false
	for file_name: String in FPS_FILES:
		if not FileAccess.file_exists(_source_cache_root("fps").path_join(file_name)):
			return false
	return true


func _download_missing_assets() -> bool:
	var platformer_downloaded: bool = await _download_source_files("platformer", PLATFORMER_FILES)
	if not platformer_downloaded:
		return false
	var fps_downloaded: bool = await _download_source_files("fps", FPS_FILES)
	return fps_downloaded


func _download_source_files(source_id: String, model_files: Array[String]) -> bool:
	var required_files: Array[String] = [TEXTURE_FILE]
	required_files.append_array(model_files)

	for relative_path: String in required_files:
		var local_path: String = _source_cache_root(source_id).path_join(relative_path)
		if FileAccess.file_exists(local_path):
			continue
		_set_status("DOWNLOADING  %s" % relative_path.get_file().to_upper())
		var downloaded: bool = await _download_file(
			_source_remote_root(source_id) + relative_path,
			local_path
		)
		if not downloaded:
			return false
	return true


func _download_file(remote_url: String, local_path: String) -> bool:
	var request_node: HTTPRequest = HTTPRequest.new()
	request_node.use_threads = true
	request_node.timeout = 35.0
	request_node.download_file = local_path
	add_child(request_node)

	var request_error: int = request_node.request(remote_url)
	if request_error != OK:
		request_node.queue_free()
		return false

	var request_response: Array = await request_node.request_completed
	request_node.queue_free()
	var request_result: int = int(request_response[0])
	var response_code: int = int(request_response[1])
	var succeeded: bool = (
		request_result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 300
		and FileAccess.file_exists(local_path)
	)
	if not succeeded and FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
	return succeeded


func _source_cache_root(source_id: String) -> String:
	return CACHE_ROOT.path_join(source_id)


func _source_remote_root(source_id: String) -> String:
	return PLATFORMER_REMOTE_ROOT if source_id == "platformer" else FPS_REMOTE_ROOT


func _build_scene_expansion(scene_name: String) -> void:
	match scene_name:
		"Cemetery":
			_build_cemetery_expansion()
		"RoadMemory":
			_build_bridge_expansion()
		"AfterlifeCity":
			_build_city_expansion()
		"RuinedNightclub":
			_build_nightclub_expansion()
		"SkeletonChamber":
			_build_chamber_expansion()


func _build_cemetery_expansion() -> void:
	_hide_named_meshes(["PathStone"])

	for z_value: int in range(-27, 24, 4):
		_place_model(
			"platformer",
			"brick.glb",
			Vector3(0.0, 0.04, float(z_value)),
			Vector3.ZERO,
			Vector3(2.8, 0.18, 1.8),
			Color("55535d")
		)

	_place_model(
		"platformer",
		"platform-grass-large-round.glb",
		Vector3(0.0, -0.04, -20.0),
		Vector3.ZERO,
		Vector3(1.08, 0.52, 0.82),
		Color("403f4d")
	)

	var grass_positions: Array[Vector3] = [
		Vector3(-10.5, 0.0, 17.0), Vector3(11.0, 0.0, 13.0),
		Vector3(-12.5, 0.0, 3.0), Vector3(12.0, 0.0, -2.0),
		Vector3(-10.0, 0.0, -13.0), Vector3(11.5, 0.0, -24.0)
	]
	for index: int in range(grass_positions.size()):
		var grass_name: String = "grass.glb" if index % 2 == 0 else "grass-small.glb"
		_place_model(
			"platformer",
			grass_name,
			grass_positions[index],
			Vector3(0.0, float(index) * 37.0, 0.0),
			Vector3(2.4, 2.4, 2.4),
			Color("39464a")
		)

	_place_model("platformer", "flag.glb", Vector3(-3.6, 0.0, -22.8), Vector3.ZERO, Vector3(2.2, 2.2, 2.2), Color("6b506b"))
	_place_model("platformer", "flag.glb", Vector3(3.6, 0.0, -22.8), Vector3(0.0, 180.0, 0.0), Vector3(2.2, 2.2, 2.2), Color("6b506b"))

	for z_position: float in [-24.0, -8.0, 8.0, 24.0]:
		_place_model("fps", "wall-low.glb", Vector3(-18.45, 0.0, z_position), Vector3(0.0, 90.0, 0.0), Vector3(5.2, 1.0, 1.0), Color("494a54"))
		_place_model("fps", "wall-low.glb", Vector3(18.45, 0.0, z_position), Vector3(0.0, 90.0, 0.0), Vector3(5.2, 1.0, 1.0), Color("494a54"))


func _build_bridge_expansion() -> void:
	var root_children: Array[Node] = _root.get_children()
	for child: Node in root_children:
		var segment: Node3D = child as Node3D
		if segment == null or not str(segment.name).begins_with("BridgeSegment"):
			continue
		_hide_bridge_rail_meshes(segment)
		_place_model("fps", "wall-low.glb", Vector3(-5.95, 0.18, 0.0), Vector3(0.0, 90.0, 0.0), Vector3(10.8, 0.92, 0.92), Color("53617b"), segment)
		_place_model("fps", "wall-low.glb", Vector3(5.95, 0.18, 0.0), Vector3(0.0, 90.0, 0.0), Vector3(10.8, 0.92, 0.92), Color("53617b"), segment)

	var sky_root: Node3D = _root.get_node_or_null("MemorySky") as Node3D
	if sky_root != null:
		var cloud_positions: Array[Vector3] = [
			Vector3(-24.0, 19.0, -82.0),
			Vector3(21.0, 23.0, -118.0),
			Vector3(5.0, 15.0, -58.0),
			Vector3(-8.0, 27.0, -150.0)
		]
		for index: int in range(cloud_positions.size()):
			_place_model(
				"platformer",
				"cloud.glb",
				cloud_positions[index],
				Vector3(0.0, float(index) * 41.0, 0.0),
				Vector3(8.0 + float(index), 2.2, 5.5 + float(index) * 0.5),
				Color(0.42, 0.34, 0.62, 0.55),
				sky_root
			)


func _hide_bridge_rail_meshes(segment: Node3D) -> void:
	var segment_children: Array[Node] = segment.get_children()
	for child: Node in segment_children:
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null:
			continue
		var x_distance: float = absf(mesh_instance.position.x)
		var should_hide: bool = (
			x_distance >= 5.75
			and x_distance <= 6.15
			and mesh_instance.position.y >= 0.25
			and mesh_instance.position.y <= 1.45
		)
		if should_hide:
			mesh_instance.visible = false


func _build_city_expansion() -> void:
	var rubble_positions: Array[Vector3] = [
		Vector3(-5.5, 0.15, 18.0), Vector3(5.7, 0.15, 9.0),
		Vector3(-5.8, 0.15, -5.0), Vector3(5.5, 0.15, -20.0),
		Vector3(-5.6, 0.15, -35.0)
	]
	for index: int in range(rubble_positions.size()):
		_place_model(
			"platformer",
			"brick.glb",
			rubble_positions[index],
			Vector3(float(index) * 8.0, float(index) * 29.0, float(index) * 5.0),
			Vector3(1.8, 1.1, 1.5),
			Color("5d536b")
		)

	_place_model("platformer", "flag.glb", Vector3(-5.2, 0.0, -47.0), Vector3.ZERO, Vector3(2.6, 2.6, 2.6), Color("8b456f"))
	_place_model("platformer", "flag.glb", Vector3(5.2, 0.0, -47.0), Vector3(0.0, 180.0, 0.0), Vector3(2.6, 2.6, 2.6), Color("654c87"))
	_place_model("fps", "wall-low.glb", Vector3(-8.4, 0.0, 27.0), Vector3(0.0, 90.0, 0.0), Vector3(4.8, 1.0, 1.0), Color("5e596b"))

	var city_grass_positions: Array[Vector3] = [
		Vector3(-7.5, 0.0, 31.0),
		Vector3(7.5, 0.0, 14.0),
		Vector3(-7.5, 0.0, -14.0)
	]
	for grass_position: Vector3 in city_grass_positions:
		_place_model("platformer", "grass-small.glb", grass_position, Vector3.ZERO, Vector3(2.0, 2.0, 2.0), Color("46545c"))


func _build_nightclub_expansion() -> void:
	_place_model("platformer", "platform-large.glb", Vector3(0.0, 0.02, -28.5), Vector3.ZERO, Vector3(2.4, 0.55, 1.65), Color("403147"))
	_place_model("fps", "platform-large-grass.glb", Vector3(0.0, -0.03, 5.0), Vector3.ZERO, Vector3(2.3, 0.28, 1.7), Color("352c3d"))

	_place_model("fps", "wall-high.glb", Vector3(-10.0, 0.0, -35.6), Vector3.ZERO, Vector3(5.0, 2.3, 1.0), Color("3e3348"))
	_place_model("fps", "wall-high.glb", Vector3(10.0, 0.0, -35.6), Vector3.ZERO, Vector3(5.0, 2.3, 1.0), Color("3e3348"))
	_place_model("platformer", "flag.glb", Vector3(-7.0, 3.8, -32.5), Vector3(0.0, 180.0, 0.0), Vector3(2.3, 2.3, 2.3), Color("7e3e68"))
	_place_model("platformer", "flag.glb", Vector3(7.0, 3.8, -32.5), Vector3(0.0, 180.0, 0.0), Vector3(2.3, 2.3, 2.3), Color("534a82"))

	var rubble_positions: Array[Vector3] = [
		Vector3(-10.5, 0.15, 10.0), Vector3(9.5, 0.15, 2.0),
		Vector3(-8.0, 0.15, -18.0), Vector3(8.5, 0.15, -25.0)
	]
	for index: int in range(rubble_positions.size()):
		_place_model("platformer", "brick.glb", rubble_positions[index], Vector3(12.0 * float(index), 31.0 * float(index), 0.0), Vector3(2.0, 1.3, 1.7), Color("554252"))


func _build_chamber_expansion() -> void:
	_hide_static_body_visual("DaisBase")
	_hide_static_body_visual("DaisStep")

	_place_model("platformer", "platform-grass-large-round.glb", Vector3(0.0, 0.0, -32.0), Vector3.ZERO, Vector3(2.4, 0.75, 1.8), Color("35384f"))
	_place_model("platformer", "platform-medium.glb", Vector3(0.0, 0.0, -27.7), Vector3.ZERO, Vector3(2.4, 0.48, 1.0), Color("41405a"))

	for x_position: float in [-13.5, -6.8, 6.8, 13.5]:
		_place_model("fps", "wall-high.glb", Vector3(x_position, 0.0, -38.4), Vector3.ZERO, Vector3(4.4, 2.5, 1.0), Color("343b55"))

	_place_model("platformer", "flag.glb", Vector3(-5.0, 0.0, -37.6), Vector3(0.0, 180.0, 0.0), Vector3(2.8, 2.8, 2.8), Color("5e5680"))
	_place_model("platformer", "flag.glb", Vector3(5.0, 0.0, -37.6), Vector3(0.0, 180.0, 0.0), Vector3(2.8, 2.8, 2.8), Color("704966"))

	var rubble_positions: Array[Vector3] = [
		Vector3(-14.0, 0.1, 15.0), Vector3(14.0, 0.1, 7.0),
		Vector3(-14.5, 0.1, -12.0), Vector3(14.0, 0.1, -25.0)
	]
	for index: int in range(rubble_positions.size()):
		_place_model("platformer", "brick.glb", rubble_positions[index], Vector3(0.0, float(index) * 43.0, float(index) * 7.0), Vector3(2.1, 1.3, 1.8), Color("41475a"))


func _hide_named_meshes(name_prefixes: Array[String]) -> void:
	var mesh_nodes: Array[Node] = _root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		for prefix: String in name_prefixes:
			if str(mesh_instance.name).begins_with(prefix):
				mesh_instance.visible = false
				break


func _hide_static_body_visual(body_name: String) -> void:
	var static_body: StaticBody3D = _root.get_node_or_null(body_name) as StaticBody3D
	if static_body == null:
		return
	var mesh_nodes: Array[Node] = static_body.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _place_model(
	source_id: String,
	file_name: String,
	model_position: Vector3,
	model_rotation: Vector3,
	model_scale: Vector3,
	tint: Color,
	custom_parent: Node3D = null
) -> Node3D:
	var prototype: Node3D = _load_prototype(source_id, file_name)
	if prototype == null:
		return null
	var model_instance: Node3D = prototype.duplicate() as Node3D
	if model_instance == null:
		return null
	model_instance.name = "KenneyExpansion_%s" % file_name.get_basename().replace("-", "_")
	model_instance.position = model_position
	model_instance.rotation_degrees = model_rotation
	model_instance.scale = model_scale
	var target_parent: Node3D = custom_parent if custom_parent != null else _model_container
	target_parent.add_child(model_instance)
	_tint_model(model_instance, tint)
	return model_instance


func _load_prototype(source_id: String, file_name: String) -> Node3D:
	var cache_key: String = "%s/%s" % [source_id, file_name]
	if _prototype_cache.has(cache_key):
		return _prototype_cache[cache_key] as Node3D

	var source_root: String = _source_cache_root(source_id)
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var import_error: int = document.append_from_file(source_root.path_join(file_name), state, 0, source_root)
	if import_error != OK:
		push_warning("Could not load Kenney model: %s" % cache_key)
		return null

	var generated_scene: Node = document.generate_scene(state)
	var prototype: Node3D = generated_scene as Node3D
	if prototype == null:
		push_warning("Kenney model did not generate a Node3D: %s" % cache_key)
		return null
	_prototype_cache[cache_key] = prototype
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
			tinted_material.roughness = maxf(tinted_material.roughness, 0.68)
			mesh_instance.set_surface_override_material(surface_index, tinted_material)


func _create_status_display() -> void:
	_status_canvas = CanvasLayer.new()
	_status_canvas.layer = 91
	add_child(_status_canvas)

	var panel: ColorRect = ColorRect.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -270.0
	panel.offset_right = 270.0
	panel.offset_top = -82.0
	panel.offset_bottom = -30.0
	panel.color = Color(0.02, 0.01, 0.05, 0.88)
	_status_canvas.add_child(panel)

	_status_label = Label.new()
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("d9c3ea"))
	panel.add_child(_status_label)


func _set_status(status_text: String) -> void:
	if _status_label != null:
		_status_label.text = status_text


func _remove_status_display() -> void:
	if _status_canvas != null:
		_status_canvas.queue_free()
	_status_canvas = null
	_status_label = null
