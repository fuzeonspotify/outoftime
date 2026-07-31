extends Node

const TEXTURE_SIZE: int = 192

var _material_cache: Dictionary = {}
var _root: Node3D


func _ready() -> void:
	call_deferred("_apply_art_pass")


func _apply_art_pass() -> void:
	_root = get_parent() as Node3D
	if _root == null:
		return

	_apply_procedural_materials()
	match str(_root.name):
		"Cemetery":
			_decorate_cemetery()
		"RoadMemory":
			_decorate_road_memory()
		"AfterlifeCity":
			_decorate_afterlife_city()
		"RuinedNightclub":
			_decorate_ruined_nightclub()
		"SkeletonChamber":
			_decorate_skeleton_chamber()


func _apply_procedural_materials() -> void:
	var mesh_nodes: Array[Node] = _root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var category: String = _classify_mesh(mesh_instance)
		if category.is_empty():
			continue
		var source_material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
		var base_color: Color = Color("6f6f78")
		if source_material != null:
			base_color = source_material.albedo_color
		mesh_instance.material_override = _get_material(category, base_color, source_material)


func _classify_mesh(mesh_instance: MeshInstance3D) -> String:
	var descriptor: String = str(mesh_instance.get_path()).to_lower()
	if _contains_any(descriptor, ["moonlitwater", "water", "moon", "star", "cloud"]):
		return ""
	if _contains_any(descriptor, ["window", "glass", "screen", "cabin", "storefront"]):
		return "glass"
	if _contains_any(descriptor, ["skull", "bone", "rib", "limb", "skeleton", "jaw", "spine", "pelvis"]):
		return "bone"
	if _contains_any(descriptor, ["tree", "trunk", "branch", "bench", "bartop", "barcounter", "newspaper"]):
		return "wood"
	if _contains_any(descriptor, ["grass", "cemetery/ground", "gravebase"]):
		return "soil"
	if _contains_any(descriptor, ["road", "mainpath", "clubfloor", "dancefloor", "dancetile", "sidewalk"]):
		return "asphalt"
	if _contains_any(descriptor, ["grave", "memorial", "stone", "column", "wall", "building", "stage", "floor", "dais"]):
		return "stone"
	if _contains_any(descriptor, ["fence", "gate", "rail", "truss", "speaker", "breaker", "lantern", "streetlight", "post", "support", "cable", "car", "pontiac", "bottle"]):
		return "metal"
	if _contains_any(descriptor, ["woman", "dress", "curtain", "cloth"]):
		return "fabric"
	return "concrete"


func _contains_any(text: String, words: Array[String]) -> bool:
	for word: String in words:
		if text.contains(word):
			return true
	return false


func _get_material(category: String, base_color: Color, source: StandardMaterial3D = null) -> StandardMaterial3D:
	var key: String = "%s:%s" % [category, base_color.to_html(true)]
	if source != null and source.emission_enabled:
		key += ":emissive:%s" % source.emission.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D

	var material: StandardMaterial3D = StandardMaterial3D.new()
	var adjusted_base: Color = _category_base_color(category, base_color)
	var accent: Color = _category_accent_color(category, adjusted_base)
	material.albedo_color = Color.WHITE
	material.albedo_texture = _make_noise_texture(adjusted_base, accent, category, absi(key.hash()))
	material.uv1_scale = _category_uv_scale(category)
	material.roughness = _category_roughness(category)
	material.metallic = _category_metallic(category)

	if category == "glass":
		material.albedo_color = Color(adjusted_base.r, adjusted_base.g, adjusted_base.b, 0.48)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.16
		material.metallic = 0.18

	if source != null:
		if source.emission_enabled:
			material.emission_enabled = true
			material.emission = source.emission
			material.emission_energy_multiplier = minf(source.emission_energy_multiplier, 2.2)
		if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if source.albedo_color.a < 0.99:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = source.albedo_color.a

	_material_cache[key] = material
	return material


func _category_base_color(category: String, original: Color) -> Color:
	match category:
		"bone":
			return original.lerp(Color("d7d1bd"), 0.42)
		"wood":
			return original.lerp(Color("523525"), 0.38)
		"soil":
			return original.lerp(Color("20271f"), 0.45)
		"asphalt":
			return original.lerp(Color("171922"), 0.48)
		"stone":
			return original.lerp(Color("55545d"), 0.28)
		"metal":
			return original.lerp(Color("38404d"), 0.28)
		"fabric":
			return original.lerp(Color("5c416a"), 0.26)
		"glass":
			return original.lerp(Color("32476a"), 0.35)
		_:
			return original.lerp(Color("494b53"), 0.20)


func _category_accent_color(category: String, base: Color) -> Color:
	match category:
		"bone":
			return base.lightened(0.20)
		"wood":
			return base.darkened(0.28)
		"soil":
			return base.lerp(Color("3b4938"), 0.35)
		"asphalt":
			return base.lightened(0.11)
		"stone":
			return base.darkened(0.24)
		"metal":
			return base.lightened(0.18)
		"fabric":
			return base.darkened(0.20)
		"glass":
			return base.lightened(0.22)
		_:
			return base.darkened(0.18)


func _category_uv_scale(category: String) -> Vector3:
	match category:
		"wood":
			return Vector3(2.8, 6.5, 2.8)
		"asphalt":
			return Vector3(7.0, 7.0, 7.0)
		"metal":
			return Vector3(4.0, 4.0, 4.0)
		"bone":
			return Vector3(3.0, 3.0, 3.0)
		_:
			return Vector3(4.5, 4.5, 4.5)


func _category_roughness(category: String) -> float:
	match category:
		"metal":
			return 0.38
		"glass":
			return 0.16
		"bone":
			return 0.72
		"wood":
			return 0.80
		"asphalt":
			return 0.92
		_:
			return 0.84


func _category_metallic(category: String) -> float:
	if category == "metal":
		return 0.62
	if category == "glass":
		return 0.18
	return 0.02


func _make_noise_texture(base: Color, accent: Color, category: String, seed: int) -> NoiseTexture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = _noise_frequency(category)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.52
	noise.fractal_lacunarity = 2.0

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, base.darkened(0.16))
	gradient.set_color(1, accent)
	gradient.add_point(0.48, base)

	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = gradient
	return texture


func _noise_frequency(category: String) -> float:
	match category:
		"wood":
			return 0.018
		"asphalt":
			return 0.090
		"metal":
			return 0.055
		"bone":
			return 0.038
		"soil":
			return 0.070
		_:
			return 0.048


func _decorate_cemetery() -> void:
	_replace_grave_markers()
	_model_cemetery_lanterns()
	_add_gate_details()
	_add_cemetery_ground_details()


func _replace_grave_markers() -> void:
	var grave_nodes: Array[Node] = _root.find_children("GraveStone*", "StaticBody3D", true, false)
	for node: Node in grave_nodes:
		var grave_body: StaticBody3D = node as StaticBody3D
		if grave_body == null:
			continue
		for child: Node in grave_body.get_children():
			var old_mesh: MeshInstance3D = child as MeshInstance3D
			if old_mesh != null:
				old_mesh.visible = false

		var model_root: Node3D = Node3D.new()
		model_root.name = "ModeledHeadstone"
		grave_body.add_child(model_root)
		var stone_material: StandardMaterial3D = _get_material("stone", Color("4a4b50"))
		_add_box(model_root, Vector3(0.0, -0.18, 0.0), Vector3(0.92, 1.05, 0.32), stone_material)
		var cap_mesh: SphereMesh = SphereMesh.new()
		cap_mesh.radius = 0.46
		cap_mesh.height = 0.55
		var cap: MeshInstance3D = _add_mesh(model_root, cap_mesh, Vector3(0.0, 0.33, 0.0), stone_material)
		cap.scale = Vector3(1.0, 0.75, 0.36)
		_add_box(model_root, Vector3(0.0, -0.08, -0.18), Vector3(0.62, 0.58, 0.035), _get_material("stone", Color("33343a")))


func _model_cemetery_lanterns() -> void:
	var post_nodes: Array[Node] = _root.find_children("LanternPost*", "MeshInstance3D", true, false)
	for node: Node in post_nodes:
		var post_mesh: MeshInstance3D = node as MeshInstance3D
		if post_mesh == null:
			continue
		var lantern_root: Node3D = Node3D.new()
		lantern_root.name = "ModeledLanternHousing"
		lantern_root.position = post_mesh.position + Vector3(0.0, 1.35, 0.0)
		_root.add_child(lantern_root)

		var metal: StandardMaterial3D = _get_material("metal", Color("202126"))
		var glass: StandardMaterial3D = _get_material("glass", Color("d7b77e"))
		_add_box(lantern_root, Vector3.ZERO, Vector3(0.62, 0.72, 0.62), glass)
		for x_value: float in [-0.34, 0.34]:
			for z_value: float in [-0.34, 0.34]:
				_add_box(lantern_root, Vector3(x_value, 0.0, z_value), Vector3(0.06, 0.82, 0.06), metal)
		_add_box(lantern_root, Vector3(0.0, -0.42, 0.0), Vector3(0.78, 0.12, 0.78), metal)
		var roof_mesh: CylinderMesh = CylinderMesh.new()
		roof_mesh.top_radius = 0.08
		roof_mesh.bottom_radius = 0.55
		roof_mesh.height = 0.38
		_add_mesh(lantern_root, roof_mesh, Vector3(0.0, 0.58, 0.0), metal)


func _add_gate_details() -> void:
	var metal: StandardMaterial3D = _get_material("metal", Color("252831"))
	for x_value: float in [-2.7, 2.7]:
		var finial_mesh: CylinderMesh = CylinderMesh.new()
		finial_mesh.top_radius = 0.0
		finial_mesh.bottom_radius = 0.28
		finial_mesh.height = 0.65
		_add_mesh(_root, finial_mesh, Vector3(x_value, 4.35, -29.5), metal)
	for x_index: int in range(-5, 6):
		var x_position: float = float(x_index) * 0.48
		_add_box(_root, Vector3(x_position, 2.25, -29.48), Vector3(0.08, 2.8, 0.08), metal)
		var spike_mesh: CylinderMesh = CylinderMesh.new()
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.10
		spike_mesh.height = 0.38
		_add_mesh(_root, spike_mesh, Vector3(x_position, 3.84, -29.48), metal)


func _add_cemetery_ground_details() -> void:
	var soil: StandardMaterial3D = _get_material("soil", Color("252a23"))
	for index: int in range(20):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var x_position: float = side * (5.0 + float(index % 5) * 2.3)
		var z_position: float = 18.0 - float(index) * 2.5
		var rock_mesh: SphereMesh = SphereMesh.new()
		rock_mesh.radius = 0.20 + float(index % 3) * 0.05
		rock_mesh.height = 0.25
		var rock: MeshInstance3D = _add_mesh(_root, rock_mesh, Vector3(x_position, 0.10, z_position), soil)
		rock.scale = Vector3(1.35, 0.55, 1.0)


func _decorate_road_memory() -> void:
	_upgrade_pontiac_model()
	_add_bridge_fixture_details()


func _upgrade_pontiac_model() -> void:
	var car: Node3D = _root.get_node_or_null("SpectralPontiac") as Node3D
	if car == null:
		return
	var paint: StandardMaterial3D = _get_material("metal", Color("8f174b"))
	paint.metallic = 0.72
	paint.roughness = 0.24
	var chrome: StandardMaterial3D = _get_material("metal", Color("b8b8c6"))
	chrome.metallic = 0.92
	chrome.roughness = 0.14
	var glass: StandardMaterial3D = _get_material("glass", Color("1b315b"))
	var dark: StandardMaterial3D = _get_material("metal", Color("0a0b10"))

	_add_box(car, Vector3(0.0, 0.72, -1.25), Vector3(2.05, 0.18, 1.75), paint)
	_add_box(car, Vector3(0.0, 0.76, 1.45), Vector3(2.08, 0.16, 1.20), paint)
	_add_box(car, Vector3(0.0, 0.76, -0.58), Vector3(1.62, 0.08, 0.12), chrome)
	_add_box(car, Vector3(0.0, 0.86, 0.48), Vector3(1.62, 0.08, 0.12), chrome)
	_add_box(car, Vector3(0.0, 0.53, -2.42), Vector3(2.18, 0.16, 0.16), chrome)
	_add_box(car, Vector3(0.0, 0.48, 2.38), Vector3(2.18, 0.16, 0.16), chrome)
	_add_box(car, Vector3(0.0, 0.55, -2.44), Vector3(1.22, 0.30, 0.06), dark)
	for grille_index: int in range(7):
		var grille_x: float = -0.48 + float(grille_index) * 0.16
		_add_box(car, Vector3(grille_x, 0.55, -2.49), Vector3(0.035, 0.25, 0.035), chrome)
	for mirror_x: float in [-1.18, 1.18]:
		_add_box(car, Vector3(mirror_x, 1.02, -0.40), Vector3(0.20, 0.12, 0.30), chrome)
	for seat_x: float in [-0.43, 0.43]:
		var seat_mesh: CapsuleMesh = CapsuleMesh.new()
		seat_mesh.radius = 0.26
		seat_mesh.height = 0.72
		var seat: MeshInstance3D = _add_mesh(car, seat_mesh, Vector3(seat_x, 0.98, 0.18), dark)
		seat.rotation_degrees.x = 8.0
	_add_box(car, Vector3(0.0, 1.17, -0.57), Vector3(1.48, 0.05, 0.08), chrome)
	_add_box(car, Vector3(0.0, 1.13, -0.64), Vector3(1.42, 0.46, 0.035), glass)
	_add_box(car, Vector3(0.0, 0.55, 2.49), Vector3(0.78, 0.28, 0.035), _get_material("concrete", Color("d7d4cc")))


func _add_bridge_fixture_details() -> void:
	var segments: Array[Node] = _root.find_children("BridgeSegment*", "Node3D", true, false)
	var metal: StandardMaterial3D = _get_material("metal", Color("32394a"))
	for node: Node in segments:
		var segment: Node3D = node as Node3D
		if segment == null:
			continue
		for side: float in [-1.0, 1.0]:
			var fixture_mesh: CylinderMesh = CylinderMesh.new()
			fixture_mesh.top_radius = 0.11
			fixture_mesh.bottom_radius = 0.15
			fixture_mesh.height = 0.42
			_add_mesh(segment, fixture_mesh, Vector3(side * 5.35, 2.18, -3.5 * side), metal)


func _decorate_afterlife_city() -> void:
	_upgrade_city_wreck()
	_model_payphone_details()
	_add_city_street_props()
	_add_fire_escapes()


func _upgrade_city_wreck() -> void:
	var wreck_body: StaticBody3D = _root.get_node_or_null("AbandonedCarBody") as StaticBody3D
	if wreck_body == null:
		return
	var rusty: StandardMaterial3D = _get_material("metal", Color("4b1720"))
	var rubber: StandardMaterial3D = _get_material("metal", Color("090a0d"))
	var glass: StandardMaterial3D = _get_material("glass", Color("1c3044"))
	for wheel_position: Vector3 in [Vector3(-1.05, -0.20, -1.35), Vector3(1.05, -0.20, -1.35), Vector3(-1.05, -0.20, 1.35), Vector3(1.05, -0.20, 1.35)]:
		var wheel_mesh: CylinderMesh = CylinderMesh.new()
		wheel_mesh.top_radius = 0.38
		wheel_mesh.bottom_radius = 0.38
		wheel_mesh.height = 0.24
		var wheel: MeshInstance3D = _add_mesh(wreck_body, wheel_mesh, wheel_position, rubber)
		wheel.rotation_degrees.z = 90.0
	_add_box(wreck_body, Vector3(0.0, 0.50, -1.55), Vector3(1.85, 0.16, 1.25), rusty)
	_add_box(wreck_body, Vector3(0.0, 0.92, -0.34), Vector3(1.52, 0.42, 0.035), glass)
	_add_box(wreck_body, Vector3(0.0, 0.18, 2.15), Vector3(1.95, 0.14, 0.12), rusty)


func _model_payphone_details() -> void:
	var payphone: MeshInstance3D = _root.get_node_or_null("PayphoneStand") as MeshInstance3D
	if payphone == null:
		return
	var position_value: Vector3 = payphone.position
	var metal: StandardMaterial3D = _get_material("metal", Color("27303d"))
	var dark: StandardMaterial3D = _get_material("metal", Color("11151d"))
	_add_box(_root, position_value + Vector3(0.0, 1.38, 0.0), Vector3(1.15, 0.18, 1.0), metal)
	_add_box(_root, position_value + Vector3(-0.48, 0.25, -0.48), Vector3(0.16, 0.82, 0.16), dark)
	_add_box(_root, position_value + Vector3(-0.48, 0.60, -0.50), Vector3(0.28, 0.50, 0.12), dark)
	var cord_mesh: CylinderMesh = CylinderMesh.new()
	cord_mesh.top_radius = 0.025
	cord_mesh.bottom_radius = 0.025
	cord_mesh.height = 0.78
	var cord: MeshInstance3D = _add_mesh(_root, cord_mesh, position_value + Vector3(-0.45, -0.02, -0.47), dark)
	cord.rotation_degrees.z = 12.0


func _add_city_street_props() -> void:
	var metal: StandardMaterial3D = _get_material("metal", Color("303540"))
	var red_metal: StandardMaterial3D = _get_material("metal", Color("7c2537"))
	for z_position: float in [24.0, -2.0, -29.0]:
		var can_mesh: CylinderMesh = CylinderMesh.new()
		can_mesh.top_radius = 0.42
		can_mesh.bottom_radius = 0.46
		can_mesh.height = 1.10
		_add_mesh(_root, can_mesh, Vector3(-7.6, 0.55, z_position), metal)
		_add_box(_root, Vector3(-7.6, 1.15, z_position), Vector3(0.82, 0.08, 0.82), metal)
	for z_position: float in [12.0, -18.0, -38.0]:
		var hydrant_root: Node3D = Node3D.new()
		hydrant_root.position = Vector3(6.5, 0.0, z_position)
		_root.add_child(hydrant_root)
		var body_mesh: CylinderMesh = CylinderMesh.new()
		body_mesh.top_radius = 0.24
		body_mesh.bottom_radius = 0.28
		body_mesh.height = 0.92
		_add_mesh(hydrant_root, body_mesh, Vector3(0.0, 0.46, 0.0), red_metal)
		_add_box(hydrant_root, Vector3(0.0, 0.96, 0.0), Vector3(0.55, 0.12, 0.55), red_metal)
		_add_box(hydrant_root, Vector3(-0.34, 0.62, 0.0), Vector3(0.28, 0.22, 0.22), red_metal)
		_add_box(hydrant_root, Vector3(0.34, 0.62, 0.0), Vector3(0.28, 0.22, 0.22), red_metal)


func _add_fire_escapes() -> void:
	var metal: StandardMaterial3D = _get_material("metal", Color("2c3040"))
	for side: float in [-1.0, 1.0]:
		for z_position: float in [18.0, -10.0, -36.0]:
			var x_position: float = side * 8.95
			_add_box(_root, Vector3(x_position, 4.2, z_position), Vector3(0.18, 0.12, 4.2), metal)
			_add_box(_root, Vector3(x_position, 4.2, z_position - 1.9), Vector3(1.9, 0.12, 0.18), metal)
			_add_box(_root, Vector3(x_position, 4.2, z_position + 1.9), Vector3(1.9, 0.12, 0.18), metal)
			for rung_index: int in range(6):
				var rung_y: float = 1.3 + float(rung_index) * 0.55
				_add_box(_root, Vector3(x_position - side * 0.6, rung_y, z_position), Vector3(1.2, 0.06, 0.12), metal)


func _decorate_ruined_nightclub() -> void:
	_add_club_bar_stools()
	_add_club_tables()
	_add_dj_booth()
	_add_speaker_grilles()
	_add_club_ceiling_cables()


func _add_club_bar_stools() -> void:
	var metal: StandardMaterial3D = _get_material("metal", Color("28232f"))
	var vinyl: StandardMaterial3D = _get_material("fabric", Color("6b244f"))
	for index: int in range(7):
		var z_position: float = -0.2 + float(index) * 2.1
		var stool_root: Node3D = Node3D.new()
		stool_root.position = Vector3(-8.8, 0.0, z_position)
		_root.add_child(stool_root)
		var post_mesh: CylinderMesh = CylinderMesh.new()
		post_mesh.top_radius = 0.07
		post_mesh.bottom_radius = 0.10
		post_mesh.height = 1.15
		_add_mesh(stool_root, post_mesh, Vector3(0.0, 0.58, 0.0), metal)
		var seat_mesh: CylinderMesh = CylinderMesh.new()
		seat_mesh.top_radius = 0.43
		seat_mesh.bottom_radius = 0.43
		seat_mesh.height = 0.18
		_add_mesh(stool_root, seat_mesh, Vector3(0.0, 1.18, 0.0), vinyl)
		for leg_angle: int in range(4):
			var radians_value: float = deg_to_rad(float(leg_angle) * 90.0)
			var leg_position: Vector3 = Vector3(cos(radians_value) * 0.28, 0.22, sin(radians_value) * 0.28)
			var leg_mesh: CylinderMesh = CylinderMesh.new()
			leg_mesh.top_radius = 0.035
			leg_mesh.bottom_radius = 0.035
			leg_mesh.height = 0.56
			var leg: MeshInstance3D = _add_mesh(stool_root, leg_mesh, leg_position, metal)
			leg.rotation_degrees.z = 18.0 * cos(radians_value)
			leg.rotation_degrees.x = 18.0 * sin(radians_value)


func _add_club_tables() -> void:
	var metal: StandardMaterial3D = _get_material("metal", Color("292530"))
	var top_material: StandardMaterial3D = _get_material("wood", Color("3d2338"))
	var table_positions: Array[Vector3] = [Vector3(-8.0, 0.0, 20.0), Vector3(8.0, 0.0, 15.0), Vector3(-7.0, 0.0, -8.0), Vector3(7.0, 0.0, -15.0)]
	for table_position: Vector3 in table_positions:
		var table_root: Node3D = Node3D.new()
		table_root.position = table_position
		_root.add_child(table_root)
		var post_mesh: CylinderMesh = CylinderMesh.new()
		post_mesh.top_radius = 0.10
		post_mesh.bottom_radius = 0.14
		post_mesh.height = 1.05
		_add_mesh(table_root, post_mesh, Vector3(0.0, 0.53, 0.0), metal)
		var top_mesh: CylinderMesh = CylinderMesh.new()
		top_mesh.top_radius = 0.82
		top_mesh.bottom_radius = 0.82
		top_mesh.height = 0.12
		_add_mesh(table_root, top_mesh, Vector3(0.0, 1.10, 0.0), top_material)


func _add_dj_booth() -> void:
	var dark_metal: StandardMaterial3D = _get_material("metal", Color("111118"))
	var neon: StandardMaterial3D = _get_material("metal", Color("9c2f7f"))
	neon.emission_enabled = true
	neon.emission = Color("e844af")
	neon.emission_energy_multiplier = 1.7
	_add_box(_root, Vector3(0.0, 1.65, -29.2), Vector3(5.6, 1.65, 1.4), dark_metal)
	_add_box(_root, Vector3(0.0, 2.52, -29.15), Vector3(5.2, 0.10, 1.2), neon)
	for deck_x: float in [-1.25, 1.25]:
		var deck_mesh: CylinderMesh = CylinderMesh.new()
		deck_mesh.top_radius = 0.58
		deck_mesh.bottom_radius = 0.58
		deck_mesh.height = 0.08
		_add_mesh(_root, deck_mesh, Vector3(deck_x, 2.61, -29.12), dark_metal)
	_add_box(_root, Vector3(0.0, 2.65, -29.10), Vector3(0.82, 0.08, 0.62), dark_metal)


func _add_speaker_grilles() -> void:
	var speaker_bodies: Array[Node] = _root.find_children("SpeakerTower*", "StaticBody3D", true, false)
	var grille: StandardMaterial3D = _get_material("metal", Color("15171e"))
	for node: Node in speaker_bodies:
		var speaker_body: StaticBody3D = node as StaticBody3D
		if speaker_body == null:
			continue
		for y_value: float in [-1.0, 0.35, 1.35]:
			var cone_mesh: CylinderMesh = CylinderMesh.new()
			cone_mesh.top_radius = 0.54
			cone_mesh.bottom_radius = 0.54
			cone_mesh.height = 0.12
			var cone: MeshInstance3D = _add_mesh(speaker_body, cone_mesh, Vector3(0.0, y_value, 1.16), grille)
			cone.rotation_degrees.x = 90.0


func _add_club_ceiling_cables() -> void:
	var cable_material: StandardMaterial3D = _get_material("metal", Color("18151e"))
	for index: int in range(12):
		var cable_mesh: CylinderMesh = CylinderMesh.new()
		cable_mesh.top_radius = 0.025
		cable_mesh.bottom_radius = 0.025
		cable_mesh.height = 2.0 + float(index % 4) * 0.5
		var cable: MeshInstance3D = _add_mesh(_root, cable_mesh, Vector3(-13.0 + float(index) * 2.35, 5.9, -5.0 + float(index % 3) * 8.0), cable_material)
		cable.rotation_degrees.z = -8.0 + float(index % 5) * 4.0


func _decorate_skeleton_chamber() -> void:
	_add_chamber_bone_piles()
	_add_chamber_candle_stands()
	_add_hanging_chains()
	_add_journal_pedestal_details()


func _add_chamber_bone_piles() -> void:
	var bone: StandardMaterial3D = _get_material("bone", Color("c8c1ad"))
	var pile_positions: Array[Vector3] = [Vector3(-8.0, 0.0, 8.0), Vector3(8.0, 0.0, 5.0), Vector3(-7.0, 0.0, -10.0), Vector3(7.5, 0.0, -13.0)]
	for pile_index: int in range(pile_positions.size()):
		var pile_root: Node3D = Node3D.new()
		pile_root.position = pile_positions[pile_index]
		_root.add_child(pile_root)
		for bone_index: int in range(9):
			var bone_mesh: CapsuleMesh = CapsuleMesh.new()
			bone_mesh.radius = 0.055
			bone_mesh.height = 0.65 + float(bone_index % 3) * 0.15
			var bone_piece: MeshInstance3D = _add_mesh(pile_root, bone_mesh, Vector3(-0.65 + float(bone_index % 5) * 0.32, 0.12 + float(bone_index / 5) * 0.15, -0.35 + float(bone_index % 3) * 0.34), bone)
			bone_piece.rotation_degrees = Vector3(60.0 + float(bone_index % 4) * 12.0, float(bone_index) * 33.0, 18.0)
		var skull_mesh: SphereMesh = SphereMesh.new()
		skull_mesh.radius = 0.28
		skull_mesh.height = 0.48
		_add_mesh(pile_root, skull_mesh, Vector3(0.15, 0.32, 0.05), bone)


func _add_chamber_candle_stands() -> void:
	var metal: StandardMaterial3D = _get_material("metal", Color("292630"))
	var wax: StandardMaterial3D = _get_material("concrete", Color("d2c5a4"))
	var candle_positions: Array[Vector3] = [Vector3(-5.5, 0.0, 2.0), Vector3(5.5, 0.0, 2.0), Vector3(-5.5, 0.0, -8.0), Vector3(5.5, 0.0, -8.0)]
	for candle_position: Vector3 in candle_positions:
		var stand_root: Node3D = Node3D.new()
		stand_root.position = candle_position
		_root.add_child(stand_root)
		var stand_mesh: CylinderMesh = CylinderMesh.new()
		stand_mesh.top_radius = 0.08
		stand_mesh.bottom_radius = 0.14
		stand_mesh.height = 1.25
		_add_mesh(stand_root, stand_mesh, Vector3(0.0, 0.63, 0.0), metal)
		var candle_mesh: CylinderMesh = CylinderMesh.new()
		candle_mesh.top_radius = 0.09
		candle_mesh.bottom_radius = 0.10
		candle_mesh.height = 0.72
		_add_mesh(stand_root, candle_mesh, Vector3(0.0, 1.56, 0.0), wax)
		var flame_mesh: SphereMesh = SphereMesh.new()
		flame_mesh.radius = 0.10
		flame_mesh.height = 0.26
		var flame_material: StandardMaterial3D = _get_material("fabric", Color("ff9a54"))
		flame_material.emission_enabled = true
		flame_material.emission = Color("ff7b36")
		flame_material.emission_energy_multiplier = 2.2
		_add_mesh(stand_root, flame_mesh, Vector3(0.0, 2.05, 0.0), flame_material)


func _add_hanging_chains() -> void:
	var chain_material: StandardMaterial3D = _get_material("metal", Color("2f3138"))
	for chain_index: int in range(8):
		var chain_x: float = -10.0 + float(chain_index) * 2.9
		var chain_z: float = -4.0 + float(chain_index % 3) * 7.0
		for link_index: int in range(7):
			var link_mesh: CylinderMesh = CylinderMesh.new()
			link_mesh.top_radius = 0.045
			link_mesh.bottom_radius = 0.045
			link_mesh.height = 0.34
			var link: MeshInstance3D = _add_mesh(_root, link_mesh, Vector3(chain_x, 6.4 - float(link_index) * 0.32, chain_z), chain_material)
			link.rotation_degrees.z = 90.0 if link_index % 2 == 0 else 0.0


func _add_journal_pedestal_details() -> void:
	var journal_nodes: Array[Node] = _root.find_children("Journal*", "MeshInstance3D", true, false)
	var leather: StandardMaterial3D = _get_material("fabric", Color("482539"))
	var paper: StandardMaterial3D = _get_material("concrete", Color("c9c0aa"))
	for node: Node in journal_nodes:
		var journal: MeshInstance3D = node as MeshInstance3D
		if journal == null:
			continue
		journal.material_override = leather
		var page_mesh: BoxMesh = BoxMesh.new()
		page_mesh.size = Vector3(0.65, 0.025, 0.78)
		var page: MeshInstance3D = _add_mesh(_root, page_mesh, journal.position + Vector3(0.0, 0.045, -0.03), paper)
		page.rotation_degrees = journal.rotation_degrees


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
