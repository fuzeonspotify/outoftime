extends Node3D

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const CITY_SCENE_PATH: String = "res://scenes/afterlife_city.tscn"
const ROAD_SEGMENT_LENGTH: float = 16.0
const ROAD_SEGMENT_COUNT: int = 22
const DRIVE_SPEED: float = 21.0
const STEER_SPEED: float = 8.0
const LANE_LIMIT: float = 2.7
const MEMORY_DISTANCE: float = 760.0
const COLLISION_Z_THRESHOLD: float = 2.8
const COLLISION_X_THRESHOLD: float = 1.25
const CAMERA_MIN_DISTANCE: float = 6.2
const CAMERA_MAX_DISTANCE: float = 12.5
const CAMERA_ZOOM_STEP: float = 0.8
const LANE_MARKER_HIDE_DISTANCE: float = 16.0

var _car: Node3D
var _car_camera: Camera3D
var _road_segments: Array[Node3D] = []
var _segment_obstacles: Dictionary = {}
var _cloud_layers: Array[Node3D] = []
var _lane_markers: Array[MeshInstance3D] = []
var _distance_travelled: float = 0.0
var _sequence_finished: bool = false
var _distance_label: Label
var _integrity_label: Label
var _message_label: Label
var _sky_root: Node3D
var _horizon_root: Node3D
var _water_visual: MeshInstance3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _memory_integrity: int = 3
var _camera_distance: float = 8.8
var _camera_target_distance: float = 8.8
var _collision_flash: ColorRect
var _film_grain_rect: ColorRect
var _cinematic_bar_top: ColorRect
var _cinematic_bar_bottom: ColorRect


func _ready() -> void:
	_rng.seed = 19980604
	_ensure_input_actions()
	_build_environment()
	_build_sky()
	_build_water()
	_build_horizon()
	_build_road()
	_build_car()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_target_distance = maxf(CAMERA_MIN_DISTANCE, _camera_target_distance - CAMERA_ZOOM_STEP)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_target_distance = minf(CAMERA_MAX_DISTANCE, _camera_target_distance + CAMERA_ZOOM_STEP)


func _process(delta: float) -> void:
	if _sequence_finished or _car == null:
		return

	var steer_input: float = Input.get_axis("move_left", "move_right")
	var target_x: float = steer_input * LANE_LIMIT
	_car.position.x = move_toward(_car.position.x, target_x, STEER_SPEED * delta)
	_car.position.z -= DRIVE_SPEED * delta
	_car.rotation_degrees.z = move_toward(_car.rotation_degrees.z, -steer_input * 6.0, 22.0 * delta)

	var travelled_this_frame: float = DRIVE_SPEED * delta
	_distance_travelled += travelled_this_frame
	_distance_label.text = "MEMORY DISTANCE  %03d" % int(_distance_travelled)

	var recycle_distance: float = ROAD_SEGMENT_LENGTH * float(ROAD_SEGMENT_COUNT)
	for segment: Node3D in _road_segments:
		if segment.position.z > _car.position.z + ROAD_SEGMENT_LENGTH * 2.5:
			segment.position.z -= recycle_distance
			_reseed_segment(segment)

	_update_atmosphere(delta, steer_input)
	_update_obstacles()

	if _distance_travelled >= MEMORY_DISTANCE:
		_show_memory_end()


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("040311")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4d4587")
	environment.ambient_light_energy = 0.82
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.fog_enabled = true
	environment.fog_light_color = Color("7b2e9b")
	environment.fog_density = 0.020
	environment.fog_sky_affect = 0.48
	environment.glow_enabled = true
	environment.glow_bloom = 0.12
	environment.glow_intensity = 0.85
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var moonlight: DirectionalLight3D = DirectionalLight3D.new()
	moonlight.name = "Moonlight"
	moonlight.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	moonlight.light_color = Color("95a7ff")
	moonlight.light_energy = 0.92
	moonlight.shadow_enabled = true
	add_child(moonlight)

	var magenta_fill: DirectionalLight3D = DirectionalLight3D.new()
	magenta_fill.name = "MagentaFill"
	magenta_fill.rotation_degrees = Vector3(-8.0, 145.0, 0.0)
	magenta_fill.light_color = Color("f03fa3")
	magenta_fill.light_energy = 0.24
	add_child(magenta_fill)


func _build_sky() -> void:
	_sky_root = Node3D.new()
	_sky_root.name = "MemorySky"
	add_child(_sky_root)

	var moon_mesh: SphereMesh = SphereMesh.new()
	moon_mesh.radius = 3.2
	moon_mesh.height = 6.4
	var moon: MeshInstance3D = _add_mesh(_sky_root, moon_mesh, Vector3(-34.0, 24.5, -120.0), Color("e8efff"))
	var moon_material: StandardMaterial3D = moon.material_override as StandardMaterial3D
	if moon_material != null:
		moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_material.emission_enabled = true
		moon_material.emission = Color("b4c8ff")
		moon_material.emission_energy_multiplier = 2.3

	var moon_glow_mesh: SphereMesh = SphereMesh.new()
	moon_glow_mesh.radius = 5.6
	moon_glow_mesh.height = 11.2
	var moon_glow: MeshInstance3D = _add_mesh(_sky_root, moon_glow_mesh, Vector3(-34.0, 24.5, -120.3), Color(0.55, 0.70, 1.0, 0.10))
	var moon_glow_material: StandardMaterial3D = moon_glow.material_override as StandardMaterial3D
	if moon_glow_material != null:
		moon_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		moon_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_glow_material.emission_enabled = true
		moon_glow_material.emission = Color("5975d1")
		moon_glow_material.emission_energy_multiplier = 0.42

	for star_index: int in range(84):
		var star_mesh: SphereMesh = SphereMesh.new()
		var star_radius: float = _rng.randf_range(0.03, 0.085)
		star_mesh.radius = star_radius
		star_mesh.height = star_radius * 2.0
		var star_position: Vector3 = Vector3(
			_rng.randf_range(-78.0, 78.0),
			_rng.randf_range(9.0, 34.0),
			_rng.randf_range(-180.0, -50.0)
		)
		var star_color: Color = Color("dae6ff") if star_index % 4 != 0 else Color("ffc3db")
		var star: MeshInstance3D = _add_mesh(_sky_root, star_mesh, star_position, star_color)
		var star_material: StandardMaterial3D = star.material_override as StandardMaterial3D
		if star_material != null:
			star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			star_material.emission_enabled = true
			star_material.emission = star_color
			star_material.emission_energy_multiplier = _rng.randf_range(1.0, 2.0)

	_create_cloud_band(Vector3(-18.0, 18.5, -90.0), 0.24, 0.11, 38.0, 1.1)
	_create_cloud_band(Vector3(20.0, 22.0, -135.0), 0.16, 0.08, 44.0, 1.4)
	_create_cloud_band(Vector3(7.0, 14.5, -60.0), 0.32, 0.06, 28.0, 0.82)


func _create_cloud_band(origin: Vector3, speed: float, alpha: float, spread: float, scale_factor: float) -> void:
	var band: Node3D = Node3D.new()
	band.position = origin
	band.set_meta("cloud_speed", speed)
	_sky_root.add_child(band)
	_cloud_layers.append(band)

	for cloud_index: int in range(8):
		var cloud_mesh: SphereMesh = SphereMesh.new()
		cloud_mesh.radius = _rng.randf_range(3.0, 6.0) * scale_factor
		cloud_mesh.height = _rng.randf_range(1.1, 2.0) * scale_factor
		var cloud_position: Vector3 = Vector3(
			-spread + (float(cloud_index) / 7.0) * spread * 2.0 + _rng.randf_range(-3.5, 3.5),
			_rng.randf_range(-1.2, 1.3),
			_rng.randf_range(-12.0, 12.0)
		)
		var cloud: MeshInstance3D = _add_mesh(band, cloud_mesh, cloud_position, Color(0.60, 0.50, 0.82, alpha))
		cloud.scale = Vector3(_rng.randf_range(1.2, 2.2), 0.25, _rng.randf_range(0.9, 1.5))
		var cloud_material: StandardMaterial3D = cloud.material_override as StandardMaterial3D
		if cloud_material != null:
			cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cloud_material.emission_enabled = true
			cloud_material.emission = Color("4b2a70")
			cloud_material.emission_energy_multiplier = 0.18


func _build_water() -> void:
	_water_visual = MeshInstance3D.new()
	_water_visual.name = "MoonlitWater"
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(220.0, 820.0)
	water_mesh.subdivide_width = 64
	water_mesh.subdivide_depth = 200
	_water_visual.mesh = water_mesh
	_water_visual.position = Vector3(0.0, -7.8, -280.0)

	var water_shader: Shader = Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color = vec3(0.020, 0.005, 0.060);
uniform vec3 mid_color = vec3(0.070, 0.015, 0.140);
uniform vec3 moon_color = vec3(0.44, 0.28, 0.86);
uniform vec3 neon_color = vec3(0.96, 0.16, 0.62);

void vertex() {
	float wave_a = sin(VERTEX.x * 0.18 + TIME * 0.85);
	float wave_b = cos(VERTEX.z * 0.065 - TIME * 0.52);
	float wave_c = sin((VERTEX.x + VERTEX.z) * 0.058 + TIME * 0.34);
	VERTEX.y += wave_a * 0.15 + wave_b * 0.11 + wave_c * 0.07;
}

void fragment() {
	float ripple_a = sin(UV.x * 110.0 + TIME * 0.85);
	float ripple_b = cos(UV.y * 80.0 - TIME * 0.52);
	float ripple = clamp((ripple_a + ripple_b) * 0.25 + 0.5, 0.0, 1.0);
	float horizon = smoothstep(0.08, 0.95, UV.y);
	float moon_path = pow(max(0.0, 1.0 - abs(UV.x - 0.32) * 4.2), 7.0);
	float neon_path = pow(max(0.0, 1.0 - abs(UV.x - 0.52) * 5.0), 8.0);
	vec3 water = mix(deep_color, mid_color, ripple * 0.45 + horizon * 0.18);
	water += moon_color * moon_path * ripple * 0.22;
	water += neon_color * neon_path * ripple * 0.18;
	ALBEDO = water;
	EMISSION = water * 0.28;
	ROUGHNESS = 0.16;
	METALLIC = 0.10;
}
"""
	var water_material: ShaderMaterial = ShaderMaterial.new()
	water_material.shader = water_shader
	_water_visual.material_override = water_material
	add_child(_water_visual)


func _build_horizon() -> void:
	_horizon_root = Node3D.new()
	_horizon_root.name = "DistantHorizon"
	add_child(_horizon_root)

	for index: int in range(24):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var distance_from_center: float = 22.0 + float(index % 6) * 6.2
		var building_height: float = 8.0 + float((index * 7) % 18)
		var building_width: float = 4.0 + float((index * 5) % 8)
		var z_offset: float = -36.0 - float(index / 2) * 9.0
		var building_position: Vector3 = Vector3(side * distance_from_center, -4.5 + building_height * 0.5, z_offset)
		_add_box(_horizon_root, building_position, Vector3(building_width, building_height, 6.0), Color("090a16"))

		var sign_color: Color = Color("7f4cff") if index % 2 == 0 else Color("ff3da3")
		if index % 3 == 0:
			_add_box(
				_horizon_root,
				building_position + Vector3(-side * (building_width * 0.52), 2.0, _rng.randf_range(-1.7, 1.7)),
				Vector3(0.12, 1.1, 3.0),
				sign_color,
				sign_color
			)

		for window_index: int in range(3):
			var y_position: float = -1.2 + float(window_index) * 2.7
			var window_color: Color = Color("69a0ff") if (window_index + index) % 2 == 0 else Color("ff68bd")
			_add_box(
				_horizon_root,
				building_position + Vector3(-side * (building_width * 0.51), y_position, -1.4 + float(window_index) * 1.4),
				Vector3(0.08, 0.42, 1.0),
				window_color,
				window_color
			)

	var horizon_glow: MeshInstance3D = _add_box(
		_horizon_root,
		Vector3(0.0, -4.5, -150.0),
		Vector3(130.0, 2.0, 6.0),
		Color("1c0f2c"),
		Color("8c2bd4")
	)
	var horizon_material: StandardMaterial3D = horizon_glow.material_override as StandardMaterial3D
	if horizon_material != null:
		horizon_material.emission_energy_multiplier = 0.85


func _build_road() -> void:
	for index: int in range(ROAD_SEGMENT_COUNT):
		var segment: Node3D = Node3D.new()
		segment.name = "BridgeSegment%d" % index
		segment.position.z = 30.0 - float(index) * ROAD_SEGMENT_LENGTH
		add_child(segment)
		_road_segments.append(segment)

		_add_box(segment, Vector3(0.0, -0.24, 0.0), Vector3(12.6, 0.48, ROAD_SEGMENT_LENGTH), Color("121521"))
		_add_box(segment, Vector3(0.0, -0.02, 0.0), Vector3(8.8, 0.06, ROAD_SEGMENT_LENGTH), Color("171b28"))
		_add_box(segment, Vector3(-5.3, -0.06, 0.0), Vector3(1.2, 0.12, ROAD_SEGMENT_LENGTH), Color("111321"))
		_add_box(segment, Vector3(5.3, -0.06, 0.0), Vector3(1.2, 0.12, ROAD_SEGMENT_LENGTH), Color("111321"))

		for marker_index: int in range(2):
			var marker_z: float = -4.4 + float(marker_index) * 8.8
			var lane_marker: MeshInstance3D = _add_box(
				segment,
				Vector3(0.0, 0.018, marker_z),
				Vector3(0.07, 0.012, 1.35),
				Color("51475f")
			)
			lane_marker.name = "MutedLaneMarker"
			_lane_markers.append(lane_marker)

		_add_box(segment, Vector3(-5.95, 0.45, 0.0), Vector3(0.18, 0.30, ROAD_SEGMENT_LENGTH), Color("49526b"))
		_add_box(segment, Vector3(5.95, 0.45, 0.0), Vector3(0.18, 0.30, ROAD_SEGMENT_LENGTH), Color("49526b"))

		for post_index: int in range(5):
			var post_z: float = -6.0 + float(post_index) * 3.0
			_add_box(segment, Vector3(-5.95, 0.9, post_z), Vector3(0.12, 0.85, 0.12), Color("65708b"))
			_add_box(segment, Vector3(5.95, 0.9, post_z), Vector3(0.12, 0.85, 0.12), Color("65708b"))

		for support_index: int in range(2):
			var support_z: float = -4.0 + float(support_index) * 8.0
			_add_box(segment, Vector3(-4.8, -3.3, support_z), Vector3(0.30, 6.2, 0.30), Color("10131c"))
			_add_box(segment, Vector3(4.8, -3.3, support_z), Vector3(0.30, 6.2, 0.30), Color("10131c"))
			_add_box(segment, Vector3(0.0, -6.3, support_z), Vector3(9.6, 0.28, 0.34), Color("0d0f16"))

		_add_bridge_tower(segment, -9.6)
		_add_bridge_tower(segment, 9.6)

		var glow_color: Color = Color("8e53ff") if index % 2 == 0 else Color("ff4fa7")
		_add_roadside_light(segment, Vector3(-5.35, 0.0, -3.5), glow_color)
		_add_roadside_light(segment, Vector3(5.35, 0.0, 3.5), glow_color)

		_seed_segment_obstacles(segment)


func _add_bridge_tower(parent: Node3D, x_position: float) -> void:
	_add_box(parent, Vector3(x_position, 6.2, 0.0), Vector3(0.45, 11.6, 0.45), Color("24293b"))
	for cable_index: int in range(4):
		var z_position: float = -5.4 + float(cable_index) * 3.6
		var cable: MeshInstance3D = _add_box(parent, Vector3(x_position * 0.5, 3.2, z_position), Vector3(absf(x_position), 0.04, 0.04), Color("544b6f"), Color("7d5ae2"))
		cable.rotation_degrees.z = 12.0 if x_position < 0.0 else -12.0


func _seed_segment_obstacles(segment: Node3D) -> void:
	_segment_obstacles[segment.name] = []
	if _rng.randf() < 0.18:
		return

	var obstacle_count: int = 1 if _rng.randf() < 0.65 else 2
	var lane_positions: Array[float] = [-2.3, 0.0, 2.3]
	var chosen_indices: Array[int] = []

	for _obstacle_index: int in range(obstacle_count):
		var lane_index: int = _rng.randi_range(0, lane_positions.size() - 1)
		while chosen_indices.has(lane_index):
			lane_index = _rng.randi_range(0, lane_positions.size() - 1)
		chosen_indices.append(lane_index)

		var local_z: float = _rng.randf_range(-5.0, 5.0)
		var obstacle_type: String = "barrier" if _rng.randf() < 0.65 else "skeleton"
		var obstacle: Node3D = _create_obstacle(obstacle_type, lane_positions[lane_index], local_z)
		segment.add_child(obstacle)
		var obstacle_data: Dictionary = {
			"node": obstacle,
			"lane_x": lane_positions[lane_index],
			"local_z": local_z,
			"hit": false,
			"type": obstacle_type
		}
		var segment_items: Array = _segment_obstacles[segment.name]
		segment_items.append(obstacle_data)
		_segment_obstacles[segment.name] = segment_items


func _create_obstacle(obstacle_type: String, lane_x: float, local_z: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = Vector3(lane_x, 0.0, local_z)
	root.set_meta("obstacle_type", obstacle_type)

	if obstacle_type == "barrier":
		var base_color: Color = Color("ff5f95")
		_add_box(root, Vector3(0.0, 0.55, 0.0), Vector3(1.55, 0.95, 1.10), Color("261323"))
		_add_box(root, Vector3(0.0, 0.58, 0.0), Vector3(1.35, 0.18, 1.00), Color("ffd7f4"), base_color)
		for stripe_index: int in range(3):
			var stripe_x: float = -0.45 + float(stripe_index) * 0.45
			_add_box(root, Vector3(stripe_x, 0.62, -0.34), Vector3(0.18, 0.26, 0.08), base_color, base_color)
			_add_box(root, Vector3(stripe_x, 0.62, 0.34), Vector3(0.18, 0.26, 0.08), base_color, base_color)
	else:
		var skeleton_material: StandardMaterial3D = StandardMaterial3D.new()
		skeleton_material.albedo_color = Color(0.88, 0.90, 1.0, 0.72)
		skeleton_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		skeleton_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		skeleton_material.emission_enabled = true
		skeleton_material.emission = Color("9caeff")
		skeleton_material.emission_energy_multiplier = 1.5
		_create_skeleton_figure(root, skeleton_material, true)
		var reflection_material: StandardMaterial3D = skeleton_material.duplicate() as StandardMaterial3D
		if reflection_material != null:
			reflection_material.albedo_color = Color(1.0, 0.55, 0.80, 0.32)
			reflection_material.emission = Color("ff5ab4")
			reflection_material.emission_energy_multiplier = 0.95
			_create_skeleton_figure(root, reflection_material, false)
	return root


func _create_skeleton_figure(parent: Node3D, material: StandardMaterial3D, upright: bool) -> void:
	var y_offset: float = 1.1 if upright else 0.06
	var x_scale: float = 1.0 if upright else 1.1
	var body_root: Node3D = Node3D.new()
	body_root.position = Vector3(0.0, y_offset, 0.0)
	if not upright:
		body_root.scale = Vector3(x_scale, 0.01, 1.0)
	body_root.rotation_degrees.y = 180.0 if upright else 0.0
	parent.add_child(body_root)

	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.20
	skull.height = 0.38
	_add_mesh_with_material(body_root, skull, Vector3(0.0, 1.03, 0.0), material)

	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = 0.11
	torso.height = 0.78
	_add_mesh_with_material(body_root, torso, Vector3(0.0, 0.55, 0.0), material)

	for rib_index: int in range(3):
		var rib_mesh: BoxMesh = BoxMesh.new()
		rib_mesh.size = Vector3(0.44, 0.045, 0.10)
		_add_mesh_with_material(body_root, rib_mesh, Vector3(0.0, 0.75 - float(rib_index) * 0.11, 0.0), material)

	var limb_mesh: CapsuleMesh = CapsuleMesh.new()
	limb_mesh.radius = 0.05
	limb_mesh.height = 0.58
	_add_mesh_with_material(body_root, limb_mesh, Vector3(-0.25, 0.58, 0.0), material, Vector3(0.0, 0.0, -16.0))
	_add_mesh_with_material(body_root, limb_mesh, Vector3(0.25, 0.58, 0.0), material, Vector3(0.0, 0.0, 16.0))
	_add_mesh_with_material(body_root, limb_mesh, Vector3(-0.10, 0.05, 0.0), material, Vector3(0.0, 0.0, 6.0))
	_add_mesh_with_material(body_root, limb_mesh, Vector3(0.10, 0.05, 0.0), material, Vector3(0.0, 0.0, -6.0))


func _reseed_segment(segment: Node3D) -> void:
	var current_items: Array = _segment_obstacles.get(segment.name, [])
	for entry_variant: Variant in current_items:
		var entry: Dictionary = entry_variant as Dictionary
		var obstacle_node: Node3D = entry.get("node") as Node3D
		if obstacle_node != null:
			obstacle_node.queue_free()
	_seed_segment_obstacles(segment)


func _update_obstacles() -> void:
	for segment: Node3D in _road_segments:
		var segment_items: Array = _segment_obstacles.get(segment.name, [])
		for item_variant: Variant in segment_items:
			var item: Dictionary = item_variant as Dictionary
			if bool(item.get("hit", false)):
				continue
			var lane_x: float = float(item.get("lane_x", 0.0))
			var local_z: float = float(item.get("local_z", 0.0))
			var obstacle_global_z: float = segment.position.z + local_z
			var obstacle_global_x: float = lane_x
			if absf(obstacle_global_z - _car.position.z) <= COLLISION_Z_THRESHOLD and absf(obstacle_global_x - _car.position.x) <= COLLISION_X_THRESHOLD:
				item["hit"] = true
				_handle_obstacle_collision(str(item.get("type", "barrier")))


func _handle_obstacle_collision(obstacle_type: String) -> void:
	if _sequence_finished:
		return
	_memory_integrity = maxi(0, _memory_integrity - 1)
	_update_integrity_label()
	_collision_flash.color = Color(1.0, 0.25, 0.55, 0.46)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_collision_flash, "color", Color(1.0, 0.25, 0.55, 0.0), 0.55)
	SFXDirector.play_reveal()
	_message_label.visible = true
	_message_label.text = "A failed memory brushes past you." if obstacle_type == "skeleton" else "You hit a barricade from another timeline."
	var message_tween: Tween = create_tween()
	message_tween.tween_interval(1.1)
	message_tween.tween_callback(Callable(self, "_hide_message"))
	if _memory_integrity <= 0:
		_show_memory_end(true)


func _hide_message() -> void:
	if _message_label != null:
		_message_label.visible = false


func _build_car() -> void:
	_car = Node3D.new()
	_car.name = "SpectralPontiac"
	_car.position = Vector3(0.0, 0.55, 8.0)
	add_child(_car)

	var body_red: Color = Color("9d1f58")
	var chrome_pink: Color = Color("ff73c5")
	var dark_magenta: Color = Color("41122a")
	var glass: Color = Color("201c46")
	_add_box(_car, Vector3(0.0, 0.38, 0.0), Vector3(2.30, 0.55, 4.70), body_red, chrome_pink)
	_add_box(_car, Vector3(0.0, 0.86, -0.15), Vector3(1.82, 0.72, 2.28), dark_magenta)
	_add_box(_car, Vector3(0.0, 0.98, -0.45), Vector3(1.60, 0.42, 1.48), glass, Color("3758b6"))
	_add_box(_car, Vector3(0.0, 0.42, -2.14), Vector3(2.02, 0.2, 0.35), dark_magenta)

	var wheel_positions: Array[Vector3] = [
		Vector3(-1.08, 0.1, -1.45),
		Vector3(1.08, 0.1, -1.45),
		Vector3(-1.08, 0.1, 1.45),
		Vector3(1.08, 0.1, 1.45)
	]
	for wheel_position: Vector3 in wheel_positions:
		var wheel_mesh: CylinderMesh = CylinderMesh.new()
		wheel_mesh.top_radius = 0.38
		wheel_mesh.bottom_radius = 0.38
		wheel_mesh.height = 0.24
		var wheel: MeshInstance3D = _add_mesh(_car, wheel_mesh, wheel_position, Color("07080d"))
		wheel.rotation_degrees.z = 90.0

	for head_x: float in [-0.72, 0.72]:
		var head_light: OmniLight3D = OmniLight3D.new()
		head_light.position = Vector3(head_x, 0.52, -2.38)
		head_light.light_color = Color("ffcfff")
		head_light.light_energy = 2.4
		head_light.omni_range = 7.0
		_car.add_child(head_light)

	for tail_x: float in [-0.7, 0.7]:
		var tail_light: OmniLight3D = OmniLight3D.new()
		tail_light.position = Vector3(tail_x, 0.55, 2.18)
		tail_light.light_color = Color("ff3090")
		tail_light.light_energy = 2.2
		tail_light.omni_range = 4.6
		_car.add_child(tail_light)

	_car_camera = Camera3D.new()
	_camera_distance = 8.8
	_camera_target_distance = 8.8
	_car_camera.position = Vector3(0.0, 3.8, _camera_distance)
	_car_camera.rotation_degrees = Vector3(-13.5, 0.0, 0.0)
	_car_camera.fov = 68.0
	_car_camera.current = true
	_car.add_child(_car_camera)


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	_cinematic_bar_top = ColorRect.new()
	_cinematic_bar_top.anchor_right = 1.0
	_cinematic_bar_top.offset_bottom = 54.0
	_cinematic_bar_top.color = Color(0.0, 0.0, 0.0, 0.82)
	canvas.add_child(_cinematic_bar_top)

	_cinematic_bar_bottom = ColorRect.new()
	_cinematic_bar_bottom.anchor_left = 0.0
	_cinematic_bar_bottom.anchor_top = 1.0
	_cinematic_bar_bottom.anchor_right = 1.0
	_cinematic_bar_bottom.anchor_bottom = 1.0
	_cinematic_bar_bottom.offset_top = -54.0
	_cinematic_bar_bottom.color = Color(0.0, 0.0, 0.0, 0.82)
	canvas.add_child(_cinematic_bar_bottom)

	var title: Label = Label.new()
	title.position = Vector2(28.0, 62.0)
	title.size = Vector2(620.0, 40.0)
	title.text = "PONTIAC  //  MEMORY BRIDGE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffd3f1"))
	canvas.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.position = Vector2(28.0, 98.0)
	subtitle.size = Vector2(760.0, 42.0)
	subtitle.text = "A / D STEER   •   MOUSE WHEEL ZOOM   •   DODGE THE DEAD"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("b3a2d2"))
	canvas.add_child(subtitle)

	_distance_label = Label.new()
	_distance_label.anchor_left = 1.0
	_distance_label.anchor_right = 1.0
	_distance_label.offset_left = -300.0
	_distance_label.offset_right = -28.0
	_distance_label.offset_top = 62.0
	_distance_label.offset_bottom = 98.0
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_distance_label.text = "MEMORY DISTANCE  000"
	_distance_label.add_theme_font_size_override("font_size", 16)
	_distance_label.add_theme_color_override("font_color", Color("dbc6ff"))
	canvas.add_child(_distance_label)

	_integrity_label = Label.new()
	_integrity_label.anchor_left = 1.0
	_integrity_label.anchor_right = 1.0
	_integrity_label.offset_left = -300.0
	_integrity_label.offset_right = -28.0
	_integrity_label.offset_top = 92.0
	_integrity_label.offset_bottom = 126.0
	_integrity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_integrity_label.add_theme_font_size_override("font_size", 15)
	_integrity_label.add_theme_color_override("font_color", Color("ff93ca"))
	canvas.add_child(_integrity_label)
	_update_integrity_label()

	_message_label = Label.new()
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 1.0
	_message_label.anchor_bottom = 1.0
	_message_label.offset_left = -420.0
	_message_label.offset_right = 420.0
	_message_label.offset_top = -115.0
	_message_label.offset_bottom = -72.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override("font_color", Color("ffe2f3"))
	_message_label.visible = false
	canvas.add_child(_message_label)

	_collision_flash = ColorRect.new()
	_collision_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collision_flash.color = Color(1.0, 0.25, 0.55, 0.0)
	_collision_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_collision_flash)

	_film_grain_rect = ColorRect.new()
	_film_grain_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_film_grain_rect.color = Color(0.07, 0.01, 0.08, 0.035)
	_film_grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_film_grain_rect)


func _update_integrity_label() -> void:
	if _integrity_label != null:
		_integrity_label.text = "MEMORY INTEGRITY  %d / 3" % _memory_integrity


func _update_atmosphere(delta: float, steer_input: float) -> void:
	for cloud_band: Node3D in _cloud_layers:
		var speed_value: Variant = cloud_band.get_meta("cloud_speed")
		var speed: float = float(speed_value)
		cloud_band.position.x += speed * delta
		if cloud_band.position.x > 68.0:
			cloud_band.position.x = -68.0

	for lane_marker: MeshInstance3D in _lane_markers:
		if is_instance_valid(lane_marker):
			var marker_distance: float = absf(lane_marker.global_position.z - _car.global_position.z)
			lane_marker.visible = marker_distance >= LANE_MARKER_HIDE_DISTANCE

	if _car_camera != null:
		var time_seconds: float = float(Time.get_ticks_msec()) * 0.001
		_camera_distance = move_toward(_camera_distance, _camera_target_distance, delta * 7.5)
		var zoom_progress: float = inverse_lerp(CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE, _camera_distance)
		var camera_height: float = lerpf(3.25, 4.25, zoom_progress)
		_car_camera.position.z = _camera_distance
		_car_camera.position.y = camera_height + sin(time_seconds * 1.45) * 0.06
		_car_camera.position.x = sin(time_seconds * 0.55) * 0.04
		_car_camera.rotation_degrees.x = lerpf(-15.0, -11.5, zoom_progress)
		_car_camera.rotation_degrees.z = lerpf(_car_camera.rotation_degrees.z, -steer_input * 2.8, delta * 4.0)

	if _film_grain_rect != null:
		_film_grain_rect.color = Color(0.07 + _rng.randf_range(-0.01, 0.01), 0.01, 0.08, 0.030 + _rng.randf_range(0.0, 0.02))


func _show_memory_end(failed: bool = false) -> void:
	_sequence_finished = true

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 80
	add_child(canvas)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 0.0)
	canvas.add_child(background)

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(background, "color", Color(0.0, 0.0, 0.0, 0.94), 1.5)
	await fade_tween.finished

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)

	var heading: Label = Label.new()
	heading.text = "THE BRIDGE REMEMBERS EVERYONE" if failed else "YOU HAVE TAKEN THIS RIDE BEFORE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	stack.add_child(heading)

	var note: Label = Label.new()
	note.text = "Too many failed reflections caught up with you." if failed else "The memory road opens into a city that should not exist."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color("b9b4ca"))
	stack.add_child(note)

	var continue_button: Button = Button.new()
	continue_button.text = "ENTER THE CITY"
	continue_button.custom_minimum_size = Vector2(300.0, 52.0)
	continue_button.pressed.connect(_continue_to_city)
	stack.add_child(continue_button)

	var return_button: Button = Button.new()
	return_button.text = "RETURN TO TITLE"
	return_button.custom_minimum_size = Vector2(300.0, 44.0)
	return_button.pressed.connect(_return_to_title)
	stack.add_child(return_button)


func _continue_to_city() -> void:
	SFXDirector.stop_environment(0.6)
	get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _return_to_title() -> void:
	MusicDirector.stop_music(1.2)
	SFXDirector.stop_environment(0.6)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _add_roadside_light(parent: Node3D, light_position: Vector3, glow_color: Color) -> void:
	_add_box(parent, light_position + Vector3(0.0, 0.85, 0.0), Vector3(0.1, 1.8, 0.1), Color("171725"))
	_add_box(parent, light_position + Vector3(0.0, 1.85, 0.0), Vector3(0.24, 0.24, 0.24), glow_color, glow_color)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position + Vector3(0.0, 1.85, 0.0)
	light.light_color = glow_color
	light.light_energy = 2.3
	light.omni_range = 6.0
	parent.add_child(light)


func _add_box(parent: Node3D, box_position: Vector3, box_size: Vector3, color: Color, emission_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var instance: MeshInstance3D = _add_mesh(parent, mesh, box_position, color)
	if emission_color.a > 0.0:
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		if material != null:
			material.emission_enabled = true
			material.emission = emission_color
			material.emission_energy_multiplier = 2.25
	return instance


func _add_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.26
	material.metallic = 0.08
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_mesh_with_material(parent: Node3D, mesh: Mesh, mesh_position: Vector3, material: Material, rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.rotation_degrees = rotation_degrees
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _ensure_input_actions() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)


func _add_key_action(action_name: StringName, physical_keycode: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)
