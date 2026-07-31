extends Node

const TARGET_SKULL_HEIGHT: float = 0.62


func _ready() -> void:
	_install_realistic_head.call_deferred()


func _install_realistic_head() -> void:
	for _frame_index: int in range(5):
		await get_tree().process_frame
	var player: CharacterBody3D = get_parent() as CharacterBody3D
	if player == null:
		return
	var visual_root: Node3D = player.get_node_or_null("SkeletonVisual") as Node3D
	if visual_root == null or visual_root.get_node_or_null("ExternalSkeletonModel") != null:
		return
	var model_root: Node3D = visual_root.get_node_or_null("DetailedSkeletonModel") as Node3D
	if model_root == null:
		return
	var prototype: Node3D = StartupPreloader.get_skeleton_head_prototype()
	if prototype == null:
		return
	var old_skull: Node3D = model_root.get_node_or_null("Skull") as Node3D
	if old_skull != null:
		old_skull.visible = false
	var realistic_skull: Node3D = prototype.duplicate() as Node3D
	if realistic_skull == null:
		return
	realistic_skull.name = "RealisticScannedSkull"
	model_root.add_child(realistic_skull)
	_normalize_skull(realistic_skull)
	_tune_skull_materials(realistic_skull)
	_add_eye_glow(realistic_skull)


func _normalize_skull(skull_root: Node3D) -> void:
	var bounds: AABB = _calculate_local_bounds(skull_root)
	if bounds.size.y <= 0.001:
		skull_root.position = Vector3(0.0, 1.72, 0.0)
		return
	var scale_factor: float = TARGET_SKULL_HEIGHT / bounds.size.y
	skull_root.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	skull_root.position = Vector3(
		-center.x * scale_factor,
		1.72 - center.y * scale_factor,
		-center.z * scale_factor
	)
	skull_root.rotation_degrees = Vector3(0.0, 180.0, 0.0)


func _calculate_local_bounds(model_root: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = model_root.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
	return bounds


func _tune_skull_materials(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var material: StandardMaterial3D = source_material as StandardMaterial3D
			if material == null:
				continue
			var tuned: StandardMaterial3D = material.duplicate() as StandardMaterial3D
			if tuned == null:
				continue
			tuned.albedo_color = tuned.albedo_color.lerp(Color("d8d1bd"), 0.18)
			tuned.roughness = maxf(0.62, tuned.roughness)
			mesh_instance.set_surface_override_material(surface_index, tuned)


func _add_eye_glow(skull_root: Node3D) -> void:
	var glow_material: StandardMaterial3D = StandardMaterial3D.new()
	glow_material.albedo_color = Color("866dff")
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.emission_enabled = true
	glow_material.emission = Color("6548ff")
	glow_material.emission_energy_multiplier = 2.2
	for side: float in [-1.0, 1.0]:
		var eye_mesh: SphereMesh = SphereMesh.new()
		eye_mesh.radius = 0.032
		eye_mesh.height = 0.055
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.name = "RealisticEyeGlow"
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.105, 0.035, -0.275)
		eye.material_override = glow_material
		skull_root.add_child(eye)
