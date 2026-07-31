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
			_verify_exact_porsche(scene_root)
		"Cemetery":
			_hide_replaced_tree_geometry(scene_root)


func _align_player_model(player_root: Node3D) -> void:
	var visual_root: Node3D = player_root.get_node_or_null("SkeletonVisual") as Node3D
	if visual_root == null:
		return
	var complete_rig: Node3D = visual_root.get_node_or_null("RiggedMainSkeleton") as Node3D
	if complete_rig == null:
		push_error("REQUIRED MODEL ERROR: RiggedMainSkeleton was not installed. No substitute skeleton is allowed.")


func _verify_exact_porsche(road_root: Node3D) -> void:
	var pontiac: Node3D = road_root.get_node_or_null("SpectralPontiac") as Node3D
	if pontiac == null:
		push_error("REQUIRED MODEL ERROR: the bridge vehicle root was not created.")
		return
	var porsche: Node3D = pontiac.get_node_or_null("Porsche911Turbo") as Node3D
	if porsche == null:
		push_error("REQUIRED MODEL ERROR: Porsche911Turbo is missing. No backup vehicle is allowed.")


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
