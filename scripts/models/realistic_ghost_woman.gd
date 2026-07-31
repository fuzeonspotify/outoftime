extends Node

const TARGET_HEIGHT: float = 2.48

var _installed_models: Array[Node3D] = []
var _elapsed: float = 0.0


func _ready() -> void:
	_install_models.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	for index: int in range(_installed_models.size()):
		var model: Node3D = _installed_models[index]
		if not is_instance_valid(model):
			continue
		model.position.y = sin(_elapsed * 0.82 + float(index) * 0.7) * 0.035
		model.rotation_degrees.z = sin(_elapsed * 0.37 + float(index)) * 0.55


func _install_models() -> void:
	for _frame_index: int in range(7):
		await get_tree().process_frame
	var scene_root: Node3D = get_parent() as Node3D
	if scene_root == null:
		return
	var prototype: Node3D = StartupPreloader.get_ghost_woman_prototype()
	if prototype == null:
		return
	var woman_nodes: Array[Node3D] = []
	var cemetery_woman: Node3D = scene_root.get_node_or_null("MysteriousWoman") as Node3D
	if cemetery_woman != null:
		woman_nodes.append(cemetery_woman)
	var chamber_woman: Node3D = scene_root.get_node_or_null("WomanAtDais") as Node3D
	if chamber_woman != null:
		woman_nodes.append(chamber_woman)
	for woman: Node3D in woman_nodes:
		_install_on_woman(woman, prototype)


func _install_on_woman(woman: Node3D, prototype: Node3D) -> void:
	var realistic_model: Node3D = prototype.duplicate() as Node3D
	if realistic_model == null:
		return
	_hide_existing_visuals(woman)
	var presentation_root: Node3D = Node3D.new()
	presentation_root.name = "RealisticGhostWoman"
	presentation_root.rotation_degrees.y = 180.0
	woman.add_child(presentation_root)
	realistic_model.name = "CorsetMannequinBody"
	presentation_root.add_child(realistic_model)
	_normalize_model(realistic_model)
	_apply_spectral_materials(realistic_model)
	_add_face_and_hair(presentation_root)
	_add_spectral_light(woman)
	_installed_models.append(presentation_root)


func _hide_existing_visuals(woman: Node3D) -> void:
	var mesh_nodes: Array[Node] = woman.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _normalize_model(model_root: Node3D) -> void:
	var bounds: AABB = _calculate_local_bounds(model_root)
	if bounds.size.y <= 0.001:
		return
	var scale_factor: float = TARGET_HEIGHT / bounds.size.y
	model_root.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	model_root.position = Vector3(
		-center.x * scale_factor,
		-bounds.position.y * scale_factor,
		-center.z * scale_factor
	)


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


func _apply_spectral_materials(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.visible = true
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var material: StandardMaterial3D = source_material as StandardMaterial3D
			if material == null:
				continue
			var spectral: StandardMaterial3D = material.duplicate() as StandardMaterial3D
			if spectral == null:
				continue
			var source_color: Color = spectral.albedo_color
			var ghost_color: Color = source_color.lerp(Color("aaa0c2"), 0.34)
			spectral.albedo_color = Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.84)
			spectral.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			spectral.roughness = maxf(0.48, spectral.roughness)
			spectral.emission_enabled = true
			spectral.emission = ghost_color.darkened(0.32)
			spectral.emission_energy_multiplier = 0.36
			mesh_instance.set_surface_override_material(surface_index, spectral)


func _add_face_and_hair(presentation_root: Node3D) -> void:
	var face_root: Node3D = Node3D.new()
	face_root.name = "SpectralFace"
	face_root.position = Vector3(0.0, 2.25, -0.02)
	presentation_root.add_child(face_root)

	var skin: StandardMaterial3D = _make_spectral_material(Color("c3bac7"), 0.76, 0.28)
	var hair: StandardMaterial3D = _make_spectral_material(Color("17131d"), 0.92, 0.18)
	var eyes: StandardMaterial3D = _make_spectral_material(Color("a999d2"), 0.30, 1.65)
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.245
	head_mesh.height = 0.48
	_add_mesh(face_root, head_mesh, Vector3.ZERO, skin)
	var hair_mesh: SphereMesh = SphereMesh.new()
	hair_mesh.radius = 0.275
	hair_mesh.height = 0.54
	var hair_cap: MeshInstance3D = _add_mesh(face_root, hair_mesh, Vector3(0.0, 0.09, 0.05), hair)
	hair_cap.scale = Vector3(1.05, 0.84, 1.06)
	var hair_back_mesh: CapsuleMesh = CapsuleMesh.new()
	hair_back_mesh.radius = 0.16
	hair_back_mesh.height = 0.86
	_add_mesh(face_root, hair_back_mesh, Vector3(0.0, -0.34, 0.16), hair)
	var eye_mesh: SphereMesh = SphereMesh.new()
	eye_mesh.radius = 0.030
	eye_mesh.height = 0.052
	_add_mesh(face_root, eye_mesh, Vector3(-0.082, 0.025, -0.224), eyes)
	_add_mesh(face_root, eye_mesh, Vector3(0.082, 0.025, -0.224), eyes)


func _add_spectral_light(woman: Node3D) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "RealisticWomanFaceLight"
	light.position = Vector3(0.0, 1.95, -0.42)
	light.light_color = Color("b6a5d7")
	light.light_energy = 0.72
	light.omni_range = 3.4
	woman.add_child(light)


func _make_spectral_material(color: Color, roughness: float, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.88)
	material.roughness = roughness
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color.darkened(0.24)
	material.emission_energy_multiplier = emission_energy
	return material


func _add_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance
