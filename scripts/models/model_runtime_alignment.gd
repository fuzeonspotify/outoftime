extends Node


func _ready() -> void:
	_apply_alignment.call_deferred()


func _apply_alignment() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var scene_root: Node3D = get_parent() as Node3D
	if scene_root == null:
		return

	match str(scene_root.name):
		"SkeletonPlayer":
			_align_player_model(scene_root)
		"RoadMemory":
			_align_pontiac(scene_root)
		"Cemetery":
			_hide_replaced_tree_geometry(scene_root)


func _align_player_model(player_root: Node3D) -> void:
	var visual_root: Node3D = player_root.get_node_or_null("SkeletonVisual") as Node3D
	if visual_root == null:
		return
	var external_model: Node3D = visual_root.get_node_or_null("ExternalSkeletonModel") as Node3D
	if external_model != null:
		external_model.rotation_degrees.y = 0.0
	var left_leg: Node3D = visual_root.get_node_or_null("DetailedSkeletonModel/LeftLeg") as Node3D
	var right_leg: Node3D = visual_root.get_node_or_null("DetailedSkeletonModel/RightLeg") as Node3D
	if left_leg != null:
		left_leg.position.y = 1.28
	if right_leg != null:
		right_leg.position.y = 1.28


func _align_pontiac(road_root: Node3D) -> void:
	var pontiac: Node3D = road_root.get_node_or_null("SpectralPontiac") as Node3D
	if pontiac == null:
		return
	var imported_model: Node3D = pontiac.get_node_or_null("KenneyCC0Car") as Node3D
	if imported_model != null:
		# The imported car faces positive Z, while the bridge drives toward negative Z.
		imported_model.rotation_degrees.y = 180.0
	var fallback_model: Node3D = pontiac.get_node_or_null("ModeledPontiacFallback") as Node3D
	if fallback_model != null:
		fallback_model.position.y = -0.22


func _hide_replaced_tree_geometry(cemetery_root: Node3D) -> void:
	var children: Array[Node] = cemetery_root.get_children()
	for child: Node in children:
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null:
			continue
		var cylinder_mesh: CylinderMesh = mesh_instance.mesh as CylinderMesh
		if cylinder_mesh == null:
			continue
		var is_tree_part: bool = absf(mesh_instance.position.x) > 12.0 and mesh_instance.position.y > 1.4
		if is_tree_part:
			mesh_instance.visible = false
