extends Node

const WOMAN_MODEL_PATH: String = "res://assets/models/characters/mysterious_woman.glb"


func _ready() -> void:
	call_deferred("_upgrade_woman_model")


func _upgrade_woman_model() -> void:
	var scene_root: Node3D = get_parent() as Node3D
	if scene_root == null:
		return

	var woman: Node3D = scene_root.get_node_or_null("MysteriousWoman") as Node3D
	if woman == null:
		return

	_hide_placeholder_meshes(woman)
	if _try_add_imported_model(woman):
		_add_reveal_lighting(woman)
		return

	_build_fallback_model(woman)
	_add_reveal_lighting(woman)


func _hide_placeholder_meshes(woman: Node3D) -> void:
	var existing_meshes: Array[Node] = woman.find_children("*", "MeshInstance3D", true, false)
	for node: Node in existing_meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _try_add_imported_model(woman: Node3D) -> bool:
	if not ResourceLoader.exists(WOMAN_MODEL_PATH):
		return false

	var resource: Resource = load(WOMAN_MODEL_PATH)
	var packed_scene: PackedScene = resource as PackedScene
	if packed_scene == null:
		return false

	var instance: Node = packed_scene.instantiate()
	var model_root: Node3D = instance as Node3D
	if model_root == null:
		instance.queue_free()
		return false

	model_root.name = "ImportedMysteriousWoman"
	model_root.scale = Vector3.ONE * 1.05
	model_root.rotation_degrees.y = 180.0
	woman.add_child(model_root)
	return true


func _build_fallback_model(woman: Node3D) -> void:
	var model_root: Node3D = Node3D.new()
	model_root.name = "DetailedWomanFallback"
	model_root.rotation_degrees.y = 180.0
	woman.add_child(model_root)

	var dress_material: StandardMaterial3D = _make_material(Color("50475f"), 0.78, Color("342c45"), 0.42)
	var trim_material: StandardMaterial3D = _make_material(Color("877b96"), 0.58, Color("50445e"), 0.30)
	var skin_material: StandardMaterial3D = _make_material(Color("b8afb9"), 0.82, Color("5d5667"), 0.22)
	var hair_material: StandardMaterial3D = _make_material(Color("17131d"), 0.94)
	var eye_material: StandardMaterial3D = _make_material(Color("14111a"), 0.42, Color("766b92"), 0.48)

	var skirt_mesh: CylinderMesh = CylinderMesh.new()
	skirt_mesh.top_radius = 0.29
	skirt_mesh.bottom_radius = 0.68
	skirt_mesh.height = 1.48
	_add_mesh(model_root, "DressSkirt", skirt_mesh, Vector3(0.0, 0.74, 0.0), dress_material)

	var torso_mesh: CapsuleMesh = CapsuleMesh.new()
	torso_mesh.radius = 0.25
	torso_mesh.height = 0.88
	_add_mesh(model_root, "DressTorso", torso_mesh, Vector3(0.0, 1.56, 0.0), dress_material)

	var shoulder_mesh: BoxMesh = BoxMesh.new()
	shoulder_mesh.size = Vector3(0.70, 0.14, 0.28)
	_add_mesh(model_root, "Shoulders", shoulder_mesh, Vector3(0.0, 1.77, 0.0), dress_material)

	var waist_trim_mesh: TorusMesh = TorusMesh.new()
	waist_trim_mesh.inner_radius = 0.25
	waist_trim_mesh.outer_radius = 0.31
	var waist_trim: MeshInstance3D = _add_mesh(model_root, "WaistTrim", waist_trim_mesh, Vector3(0.0, 1.22, 0.0), trim_material)
	waist_trim.rotation_degrees.x = 90.0

	var arm_mesh: CapsuleMesh = CapsuleMesh.new()
	arm_mesh.radius = 0.065
	arm_mesh.height = 0.72
	var left_arm: MeshInstance3D = _add_mesh(model_root, "LeftSleeve", arm_mesh, Vector3(-0.36, 1.39, 0.0), dress_material)
	left_arm.rotation_degrees.z = -8.0
	var right_arm: MeshInstance3D = _add_mesh(model_root, "RightSleeve", arm_mesh, Vector3(0.36, 1.39, 0.0), dress_material)
	right_arm.rotation_degrees.z = 8.0

	var hand_mesh: SphereMesh = SphereMesh.new()
	hand_mesh.radius = 0.085
	hand_mesh.height = 0.17
	_add_mesh(model_root, "LeftHand", hand_mesh, Vector3(-0.42, 1.03, 0.0), skin_material)
	_add_mesh(model_root, "RightHand", hand_mesh, Vector3(0.42, 1.03, 0.0), skin_material)

	var neck_mesh: CylinderMesh = CylinderMesh.new()
	neck_mesh.top_radius = 0.085
	neck_mesh.bottom_radius = 0.10
	neck_mesh.height = 0.24
	_add_mesh(model_root, "Neck", neck_mesh, Vector3(0.0, 1.98, 0.0), skin_material)

	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.49
	_add_mesh(model_root, "Head", head_mesh, Vector3(0.0, 2.24, 0.0), skin_material)

	var hair_cap_mesh: SphereMesh = SphereMesh.new()
	hair_cap_mesh.radius = 0.27
	hair_cap_mesh.height = 0.54
	var hair_cap: MeshInstance3D = _add_mesh(model_root, "HairCap", hair_cap_mesh, Vector3(0.0, 2.34, 0.035), hair_material)
	hair_cap.scale = Vector3(1.04, 0.80, 1.05)

	var hair_back_mesh: CapsuleMesh = CapsuleMesh.new()
	hair_back_mesh.radius = 0.15
	hair_back_mesh.height = 0.78
	_add_mesh(model_root, "HairBack", hair_back_mesh, Vector3(0.0, 1.96, 0.15), hair_material)

	var eye_mesh: SphereMesh = SphereMesh.new()
	eye_mesh.radius = 0.027
	eye_mesh.height = 0.05
	_add_mesh(model_root, "LeftEye", eye_mesh, Vector3(-0.078, 2.27, -0.225), eye_material)
	_add_mesh(model_root, "RightEye", eye_mesh, Vector3(0.078, 2.27, -0.225), eye_material)

	var necklace_mesh: TorusMesh = TorusMesh.new()
	necklace_mesh.inner_radius = 0.105
	necklace_mesh.outer_radius = 0.125
	var necklace: MeshInstance3D = _add_mesh(model_root, "Necklace", necklace_mesh, Vector3(0.0, 1.91, -0.16), trim_material)
	necklace.rotation_degrees.x = 80.0


func _add_reveal_lighting(woman: Node3D) -> void:
	var existing_light: OmniLight3D = woman.get_node_or_null("WomanBacklight") as OmniLight3D
	if existing_light == null:
		existing_light = OmniLight3D.new()
		existing_light.name = "WomanBacklight"
		woman.add_child(existing_light)
	existing_light.position = Vector3(0.0, 1.45, 0.90)
	existing_light.light_color = Color("8d84ba")
	existing_light.light_energy = 2.25
	existing_light.omni_range = 7.5

	var face_fill: OmniLight3D = woman.get_node_or_null("WomanFaceFill") as OmniLight3D
	if face_fill == null:
		face_fill = OmniLight3D.new()
		face_fill.name = "WomanFaceFill"
		woman.add_child(face_fill)
	face_fill.position = Vector3(0.0, 2.0, -0.85)
	face_fill.light_color = Color("c2b6d4")
	face_fill.light_energy = 0.55
	face_fill.omni_range = 3.0


func _make_material(
	base_color: Color,
	roughness: float,
	emission_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = base_color
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material


func _add_mesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	mesh_position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance