extends Node

const PONTIAC_MODEL_PATH: String = "res://assets/models/vehicles/pontiac_coupe.glb"
const CITY_WRECK_MODEL_PATH: String = "res://assets/models/vehicles/abandoned_coupe.glb"
const TREE_MODEL_PATH: String = "res://assets/models/environment/dead_tree.glb"
const CLUB_SPEAKER_MODEL_PATH: String = "res://assets/models/props/club_speaker.glb"

var _root: Node3D


func _ready() -> void:
	call_deferred("_apply_model_pass")


func _apply_model_pass() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_root = get_parent() as Node3D
	if _root == null:
		return

	match str(_root.name):
		"Cemetery":
			_upgrade_cemetery_trees()
		"RoadMemory":
			_upgrade_pontiac()
		"AfterlifeCity":
			_upgrade_city_wreck()
		"RuinedNightclub":
			_upgrade_club_equipment()


func _upgrade_pontiac() -> void:
	var car: Node3D = _root.get_node_or_null("SpectralPontiac") as Node3D
	if car == null:
		return
	_hide_meshes(car)
	if _install_external_model(car, PONTIAC_MODEL_PATH, "ExternalPontiac", Vector3(1.0, 1.0, 1.0), Vector3.ZERO):
		return
	_build_pontiac_fallback(car, false)


func _upgrade_city_wreck() -> void:
	var wreck_body: StaticBody3D = _root.get_node_or_null("AbandonedCarBody") as StaticBody3D
	if wreck_body == null:
		return
	_hide_meshes(wreck_body)
	var cabin: MeshInstance3D = _root.get_node_or_null("AbandonedCarCabin") as MeshInstance3D
	if cabin != null:
		cabin.visible = false
	if _install_external_model(wreck_body, CITY_WRECK_MODEL_PATH, "ExternalCityWreck", Vector3(1.0, 1.0, 1.0), Vector3.ZERO):
		return
	_build_pontiac_fallback(wreck_body, true)


func _upgrade_cemetery_trees() -> void:
	var tree_z_values: Array[float] = [-25.0, -15.0, -5.0, 5.0, 15.0, 23.0]
	for tree_z: float in tree_z_values:
		_create_tree_model(Vector3(-15.5, 0.0, tree_z), 1.0 + absf(tree_z) * 0.005)
		_create_tree_model(Vector3(15.5, 0.0, tree_z + 1.8), 0.9 + absf(tree_z) * 0.006)


func _upgrade_club_equipment() -> void:
	var speaker_nodes: Array[Node] = _root.find_children("SpeakerTower*", "StaticBody3D", true, false)
	for node: Node in speaker_nodes:
		var speaker_body: StaticBody3D = node as StaticBody3D
		if speaker_body == null:
			continue
		_hide_meshes(speaker_body)
		if not _install_external_model(speaker_body, CLUB_SPEAKER_MODEL_PATH, "ExternalClubSpeaker", Vector3(1.0, 1.0, 1.0), Vector3.ZERO):
			_build_speaker_model(speaker_body)
	_build_dj_console()


func _install_external_model(parent: Node3D, resource_path: String, node_name: String, scale_value: Vector3, rotation_value: Vector3) -> bool:
	if not ResourceLoader.exists(resource_path):
		return false
	var resource: Resource = load(resource_path)
	var packed_scene: PackedScene = resource as PackedScene
	if packed_scene == null:
		return false
	var instance: Node = packed_scene.instantiate()
	var model: Node3D = instance as Node3D
	if model == null:
		instance.queue_free()
		return false
	model.name = node_name
	model.scale = scale_value
	model.rotation_degrees = rotation_value
	parent.add_child(model)
	return true


func _hide_meshes(parent: Node3D) -> void:
	var mesh_nodes: Array[Node] = parent.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _build_pontiac_fallback(parent: Node3D, damaged: bool) -> void:
	var sides: Array[float] = [-1.0, 1.0]
	var wheel_z_positions: Array[float] = [-1.43, 1.43]
	var hood_line_positions: Array[float] = [-0.48, 0.48]
	var headlight_positions: Array[float] = [-0.67, 0.67]
	var taillight_positions: Array[float] = [-0.68, 0.68]
	var seat_positions: Array[float] = [-0.42, 0.42]
	var exhaust_positions: Array[float] = [-0.62, 0.62]
	var model_root: Node3D = Node3D.new()
	model_root.name = "ModeledPontiacFallback" if not damaged else "ModeledCityWreckFallback"
	if damaged:
		model_root.position = Vector3(0.0, -0.45, 0.0)
		model_root.rotation_degrees = Vector3(0.0, 4.0, -3.0)
	parent.add_child(model_root)

	var paint_color: Color = Color("8f174b") if not damaged else Color("5b2023")
	var paint: StandardMaterial3D = _make_material(paint_color, 0.24 if not damaged else 0.62, 0.70 if not damaged else 0.32)
	var secondary: StandardMaterial3D = _make_material(Color("320d20") if not damaged else Color("2a1716"), 0.42, 0.36)
	var chrome: StandardMaterial3D = _make_material(Color("c2c6d1") if not damaged else Color("696a6b"), 0.14 if not damaged else 0.58, 0.92 if not damaged else 0.42)
	var rubber: StandardMaterial3D = _make_material(Color("07080b"), 0.96, 0.02)
	var glass: StandardMaterial3D = _make_glass_material(Color("253c68") if not damaged else Color("17202c"), 0.46 if not damaged else 0.62)
	var light_white: StandardMaterial3D = _make_emissive_material(Color("ffd6f4"), 2.2)
	var light_red: StandardMaterial3D = _make_emissive_material(Color("ff2e86"), 2.0)
	var dark: StandardMaterial3D = _make_material(Color("0b0b11"), 0.78, 0.18)

	var lower_body_mesh: SphereMesh = SphereMesh.new()
	lower_body_mesh.radius = 1.0
	lower_body_mesh.height = 2.0
	var lower_body: MeshInstance3D = _add_mesh(model_root, lower_body_mesh, Vector3(0.0, 0.48, 0.0), paint)
	lower_body.scale = Vector3(1.17, 0.38, 2.25)

	var cabin_mesh: SphereMesh = SphereMesh.new()
	cabin_mesh.radius = 1.0
	cabin_mesh.height = 2.0
	var cabin: MeshInstance3D = _add_mesh(model_root, cabin_mesh, Vector3(0.0, 0.92, 0.14), secondary)
	cabin.scale = Vector3(0.83, 0.38, 1.18)

	_add_box(model_root, Vector3(0.0, 0.70, -1.58), Vector3(2.08, 0.18, 1.35), paint)
	_add_box(model_root, Vector3(0.0, 0.69, 1.72), Vector3(2.06, 0.16, 1.00), paint)
	_add_box(model_root, Vector3(0.0, 0.48, -2.28), Vector3(2.20, 0.22, 0.22), chrome)
	_add_box(model_root, Vector3(0.0, 0.47, 2.27), Vector3(2.18, 0.20, 0.20), chrome)

	_add_box(model_root, Vector3(0.0, 1.10, -0.55), Vector3(1.52, 0.48, 0.045), glass)
	_add_box(model_root, Vector3(0.0, 1.09, 0.76), Vector3(1.45, 0.43, 0.045), glass)
	for side: float in sides:
		_add_box(model_root, Vector3(side * 0.84, 1.05, 0.10), Vector3(0.045, 0.43, 1.26), glass)
		_add_box(model_root, Vector3(side * 1.13, 0.73, -0.18), Vector3(0.06, 0.58, 2.08), secondary)
		_add_box(model_root, Vector3(side * 1.18, 1.00, -0.45), Vector3(0.20, 0.14, 0.28), chrome)

	for hood_line_x: float in hood_line_positions:
		_add_box(model_root, Vector3(hood_line_x, 0.82, -1.60), Vector3(0.035, 0.025, 1.15), chrome)

	for head_x: float in headlight_positions:
		_add_box(model_root, Vector3(head_x, 0.60, -2.34), Vector3(0.48, 0.20, 0.06), light_white)
	for tail_x: float in taillight_positions:
		_add_box(model_root, Vector3(tail_x, 0.60, 2.35), Vector3(0.44, 0.18, 0.06), light_red)

	_add_box(model_root, Vector3(0.0, 0.54, -2.38), Vector3(0.82, 0.25, 0.05), dark)
	for grille_index: int in range(7):
		var grille_x: float = -0.30 + float(grille_index) * 0.10
		_add_box(model_root, Vector3(grille_x, 0.54, -2.42), Vector3(0.022, 0.21, 0.035), chrome)

	for side: float in sides:
		for z_position: float in wheel_z_positions:
			_build_wheel(model_root, Vector3(side * 1.10, 0.18, z_position), rubber, chrome, dark, damaged and side > 0.0 and z_position > 0.0)

	for seat_x: float in seat_positions:
		var seat_mesh: CapsuleMesh = CapsuleMesh.new()
		seat_mesh.radius = 0.25
		seat_mesh.height = 0.70
		var seat: MeshInstance3D = _add_mesh(model_root, seat_mesh, Vector3(seat_x, 0.88, 0.16), dark)
		seat.rotation_degrees.x = 8.0

	var steering_mesh: CylinderMesh = CylinderMesh.new()
	steering_mesh.top_radius = 0.20
	steering_mesh.bottom_radius = 0.20
	steering_mesh.height = 0.045
	var steering: MeshInstance3D = _add_mesh(model_root, steering_mesh, Vector3(-0.40, 1.03, -0.42), dark)
	steering.rotation_degrees.x = 75.0

	_add_box(model_root, Vector3(0.0, 0.82, 2.18), Vector3(1.62, 0.10, 0.50), paint)
	_add_box(model_root, Vector3(0.0, 1.00, 2.12), Vector3(1.38, 0.10, 0.30), paint)
	_add_box(model_root, Vector3(-0.63, 0.86, 2.08), Vector3(0.10, 0.42, 0.10), secondary)
	_add_box(model_root, Vector3(0.63, 0.86, 2.08), Vector3(0.10, 0.42, 0.10), secondary)

	for exhaust_x: float in exhaust_positions:
		var exhaust_mesh: CylinderMesh = CylinderMesh.new()
		exhaust_mesh.top_radius = 0.08
		exhaust_mesh.bottom_radius = 0.10
		exhaust_mesh.height = 0.36
		var exhaust: MeshInstance3D = _add_mesh(model_root, exhaust_mesh, Vector3(exhaust_x, 0.28, 2.38), chrome)
		exhaust.rotation_degrees.x = 90.0

	if damaged:
		_add_box(model_root, Vector3(0.32, 1.10, -0.58), Vector3(0.04, 0.40, 0.04), dark)
		_add_box(model_root, Vector3(-0.20, 1.03, -0.58), Vector3(0.04, 0.36, 0.04), dark)
		var broken_panel: MeshInstance3D = _add_box(model_root, Vector3(1.12, 0.60, 1.10), Vector3(0.08, 0.52, 0.90), secondary)
		broken_panel.rotation_degrees.z = -12.0


func _build_wheel(parent: Node3D, position_value: Vector3, rubber: Material, chrome: Material, dark: Material, damaged: bool) -> void:
	var wheel_root: Node3D = Node3D.new()
	wheel_root.position = position_value
	wheel_root.rotation_degrees.z = 90.0
	if damaged:
		wheel_root.rotation_degrees.y = 14.0
		wheel_root.position.y -= 0.10
	parent.add_child(wheel_root)

	var tire_mesh: CylinderMesh = CylinderMesh.new()
	tire_mesh.top_radius = 0.43
	tire_mesh.bottom_radius = 0.43
	tire_mesh.height = 0.24
	_add_mesh(wheel_root, tire_mesh, Vector3.ZERO, rubber)

	var rim_mesh: CylinderMesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.27
	rim_mesh.bottom_radius = 0.27
	rim_mesh.height = 0.255
	_add_mesh(wheel_root, rim_mesh, Vector3.ZERO, chrome)

	var hub_mesh: CylinderMesh = CylinderMesh.new()
	hub_mesh.top_radius = 0.08
	hub_mesh.bottom_radius = 0.08
	hub_mesh.height = 0.27
	_add_mesh(wheel_root, hub_mesh, Vector3.ZERO, dark)

	for spoke_index: int in range(5):
		var spoke: MeshInstance3D = _add_box(wheel_root, Vector3.ZERO, Vector3(0.28, 0.045, 0.055), dark)
		spoke.rotation_degrees.y = float(spoke_index) * 72.0


func _create_tree_model(position_value: Vector3, scale_factor: float) -> void:
	var tree_root: Node3D = Node3D.new()
	tree_root.name = "UpgradedDeadTree"
	tree_root.position = position_value
	tree_root.scale = Vector3.ONE * scale_factor
	_root.add_child(tree_root)

	if _install_external_model(tree_root, TREE_MODEL_PATH, "ExternalDeadTree", Vector3.ONE, Vector3.ZERO):
		return

	var bark: StandardMaterial3D = _make_material(Color("211a1b"), 0.94, 0.0)
	var bark_light: StandardMaterial3D = _make_material(Color("352728"), 0.90, 0.0)
	_build_branch(tree_root, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 3.7, 0.0), 0.46, 0.30, bark)
	_build_branch(tree_root, Vector3(0.0, 3.1, 0.0), Vector3(-1.7, 5.2, 0.4), 0.24, 0.09, bark)
	_build_branch(tree_root, Vector3(0.0, 3.3, 0.0), Vector3(1.8, 5.5, -0.5), 0.22, 0.08, bark_light)
	_build_branch(tree_root, Vector3(-0.35, 4.0, 0.1), Vector3(-2.4, 6.0, -0.7), 0.16, 0.055, bark)
	_build_branch(tree_root, Vector3(0.40, 4.1, -0.1), Vector3(2.5, 6.2, 0.8), 0.15, 0.05, bark_light)
	_build_branch(tree_root, Vector3(-1.4, 5.0, 0.3), Vector3(-2.8, 6.6, 0.6), 0.10, 0.035, bark)
	_build_branch(tree_root, Vector3(1.5, 5.2, -0.3), Vector3(2.9, 6.8, -0.9), 0.10, 0.035, bark_light)
	_build_branch(tree_root, Vector3(0.0, 3.8, 0.0), Vector3(0.4, 6.5, 0.2), 0.14, 0.045, bark)


func _build_branch(parent: Node3D, start: Vector3, end: Vector3, start_radius: float, end_radius: float, material: Material) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.001:
		return
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = end_radius
	mesh.bottom_radius = start_radius
	mesh.height = length
	var branch: MeshInstance3D = _add_mesh(parent, mesh, (start + end) * 0.5, material)
	branch.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _build_speaker_model(parent: Node3D) -> void:
	var cabinet: StandardMaterial3D = _make_material(Color("0b0b10"), 0.88, 0.10)
	var trim: StandardMaterial3D = _make_material(Color("32333c"), 0.45, 0.58)
	var cone: StandardMaterial3D = _make_material(Color("151720"), 0.72, 0.18)
	var center: StandardMaterial3D = _make_material(Color("050608"), 0.90, 0.0)

	_add_box(parent, Vector3.ZERO, Vector3(2.3, 3.9, 2.0), cabinet)
	_add_box(parent, Vector3(0.0, 0.0, 1.03), Vector3(2.05, 3.65, 0.08), trim)
	var driver_data: Array[Vector2] = [Vector2(-1.02, 0.64), Vector2(0.28, 0.50), Vector2(1.18, 0.36)]
	for driver: Vector2 in driver_data:
		var driver_mesh: CylinderMesh = CylinderMesh.new()
		driver_mesh.top_radius = driver.y
		driver_mesh.bottom_radius = driver.y
		driver_mesh.height = 0.14
		var driver_instance: MeshInstance3D = _add_mesh(parent, driver_mesh, Vector3(0.0, driver.x, 1.10), cone)
		driver_instance.rotation_degrees.x = 90.0
		var center_mesh: CylinderMesh = CylinderMesh.new()
		center_mesh.top_radius = driver.y * 0.34
		center_mesh.bottom_radius = driver.y * 0.34
		center_mesh.height = 0.16
		var center_instance: MeshInstance3D = _add_mesh(parent, center_mesh, Vector3(0.0, driver.x, 1.18), center)
		center_instance.rotation_degrees.x = 90.0


func _build_dj_console() -> void:
	var deck_positions: Array[float] = [-1.45, 1.45]
	if _root.get_node_or_null("UpgradedDJConsole") != null:
		return
	var console_root: Node3D = Node3D.new()
	console_root.name = "UpgradedDJConsole"
	console_root.position = Vector3(0.0, 2.63, -29.08)
	_root.add_child(console_root)

	var body: StandardMaterial3D = _make_material(Color("101117"), 0.48, 0.48)
	var chrome: StandardMaterial3D = _make_material(Color("858897"), 0.18, 0.88)
	var platter: StandardMaterial3D = _make_material(Color("090a0e"), 0.78, 0.18)
	var screen: StandardMaterial3D = _make_emissive_material(Color("b947ff"), 1.35)
	var red: StandardMaterial3D = _make_emissive_material(Color("ff467f"), 1.20)

	_add_box(console_root, Vector3.ZERO, Vector3(4.9, 0.16, 1.12), body)
	for deck_x: float in deck_positions:
		var platter_mesh: CylinderMesh = CylinderMesh.new()
		platter_mesh.top_radius = 0.55
		platter_mesh.bottom_radius = 0.55
		platter_mesh.height = 0.06
		_add_mesh(console_root, platter_mesh, Vector3(deck_x, 0.11, 0.0), platter)
		var spindle_mesh: CylinderMesh = CylinderMesh.new()
		spindle_mesh.top_radius = 0.05
		spindle_mesh.bottom_radius = 0.05
		spindle_mesh.height = 0.09
		_add_mesh(console_root, spindle_mesh, Vector3(deck_x, 0.16, 0.0), chrome)
		_add_box(console_root, Vector3(deck_x + 0.52, 0.18, 0.25), Vector3(0.05, 0.05, 0.50), chrome)

	_add_box(console_root, Vector3(0.0, 0.13, 0.0), Vector3(0.78, 0.10, 0.78), body)
	for knob_index: int in range(8):
		var x_position: float = -0.28 + float(knob_index % 4) * 0.18
		var z_position: float = -0.22 + float(knob_index / 4) * 0.44
		var knob_mesh: CylinderMesh = CylinderMesh.new()
		knob_mesh.top_radius = 0.045
		knob_mesh.bottom_radius = 0.045
		knob_mesh.height = 0.08
		_add_mesh(console_root, knob_mesh, Vector3(x_position, 0.22, z_position), chrome)

	var laptop_root: Node3D = Node3D.new()
	laptop_root.position = Vector3(0.0, 0.28, -0.38)
	laptop_root.rotation_degrees.x = -18.0
	console_root.add_child(laptop_root)
	_add_box(laptop_root, Vector3.ZERO, Vector3(1.25, 0.06, 0.78), body)
	_add_box(laptop_root, Vector3(0.0, 0.43, 0.35), Vector3(1.25, 0.82, 0.06), screen)
	for pad_index: int in range(4):
		var pad_x: float = -0.28 + float(pad_index) * 0.19
		_add_box(console_root, Vector3(pad_x, 0.22, 0.34), Vector3(0.12, 0.06, 0.12), red)


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _make_glass_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(Color(color.r, color.g, color.b, alpha), 0.14, 0.16)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.30, 0.22)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _add_box(parent: Node3D, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	return _add_mesh(parent, mesh, position_value, material)


func _add_mesh(parent: Node3D, mesh: Mesh, position_value: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)
	return instance
