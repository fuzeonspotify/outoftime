extends Node

const KENNEY_WAIT_TIMEOUT: float = 45.0
const KENNEY_CHECK_INTERVAL: float = 0.25

var _root: Node3D


func _ready() -> void:
	_wait_for_kenney_city.call_deferred()


func _wait_for_kenney_city() -> void:
	_root = get_parent() as Node3D
	if _root == null:
		return

	var elapsed_time: float = 0.0
	while elapsed_time < KENNEY_WAIT_TIMEOUT:
		var kenney_container: Node3D = _root.get_node_or_null("KenneyCityModels") as Node3D
		if kenney_container != null:
			await get_tree().process_frame
			_hide_legacy_city_visuals()
			_rotate_all_buildings_forward(kenney_container)
			return
		await get_tree().create_timer(KENNEY_CHECK_INTERVAL).timeout
		elapsed_time += KENNEY_CHECK_INTERVAL


func _hide_legacy_city_visuals() -> void:
	var root_children: Array[Node] = _root.get_children()
	for child: Node in root_children:
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance != null:
			var mesh_name: String = str(mesh_instance.name)
			var is_old_road_visual: bool = mesh_name in [
				"Road",
				"LeftSidewalk",
				"RightSidewalk",
				"RoadMarker"
			]
			var is_old_building_detail: bool = (
				absf(mesh_instance.position.x) >= 8.5
				and mesh_instance.position.z > -49.0
				and mesh_instance.position.z < 42.0
				and mesh_name != "StorefrontGlass"
			)
			var is_old_facade_piece: bool = mesh_name in ["Window", "BrokenSign"]
			if is_old_road_visual or is_old_building_detail or is_old_facade_piece:
				mesh_instance.visible = false
			continue

		var static_body: StaticBody3D = child as StaticBody3D
		if static_body == null:
			continue
		if str(static_body.name).begins_with("Building"):
			_set_mesh_visibility(static_body, false)


func _set_mesh_visibility(parent_node: Node, visible_value: bool) -> void:
	var descendants: Array[Node] = parent_node.find_children("*", "MeshInstance3D", true, false)
	for descendant: Node in descendants:
		var mesh_instance: MeshInstance3D = descendant as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = visible_value


func _rotate_all_buildings_forward(kenney_container: Node3D) -> void:
	var model_children: Array[Node] = kenney_container.get_children()
	for child: Node in model_children:
		var model_root: Node3D = child as Node3D
		if model_root == null:
			continue
		if not str(model_root.name).begins_with("Kenney_building_"):
			continue

		var corrected_rotation: Vector3 = model_root.rotation_degrees
		corrected_rotation.y = fposmod(corrected_rotation.y + 180.0, 360.0)
		model_root.rotation_degrees = corrected_rotation
