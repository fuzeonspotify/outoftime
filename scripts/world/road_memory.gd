extends Node3D

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const CITY_SCENE_PATH: String = "res://scenes/afterlife_city.tscn"
const ROAD_SEGMENT_LENGTH: float = 14.0
const ROAD_SEGMENT_COUNT: int = 18
const DRIVE_SPEED: float = 17.0
const STEER_SPEED: float = 6.5
const LANE_LIMIT: float = 2.35
const MEMORY_DISTANCE: float = 610.0

var _car: Node3D
var _car_camera: Camera3D
var _road_segments: Array[Node3D] = []
var _cloud_layers: Array[Node3D] = []
var _distance_travelled: float = 0.0
var _sequence_finished: bool = false
var _distance_label: Label
var _sky_root: Node3D
var _horizon_root: Node3D
var _water_visual: MeshInstance3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20020714
	_ensure_input_actions()
	_build_environment()
	_build_sky()
	_build_water()
	_build_horizon()
	_build_road()
	_build_car()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if _sequence_finished or _car == null:
		return

	var steer_input: float = Input.get_axis("move_left", "move_right")
	var target_x: float = steer_input * LANE_LIMIT
	_car.position.x = move_toward(_car.position.x, target_x, STEER_SPEED * delta)
	_car.position.z -= DRIVE_SPEED * delta
	_car.rotation_degrees.z = move_toward(_car.rotation_degrees.z, -steer_input * 4.0, 20.0 * delta)

	var travelled_this_frame: float = DRIVE_SPEED * delta
	_distance_travelled += travelled_this_frame
	_distance_label.text = "MEMORY DISTANCE  %03d" % int(_distance_travelled)

	var recycle_distance: float = ROAD_SEGMENT_LENGTH * float(ROAD_SEGMENT_COUNT)
	for segment: Node3D in _road_segments:
		if segment.position.z > _car.position.z + ROAD_SEGMENT_LENGTH * 2.0:
			segment.position.z -= recycle_distance

	_update_atmosphere(delta, steer_input)

	if _distance_travelled >= MEMORY_DISTANCE:
		_show_memory_end()


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("020611")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("40517d")
	environment.ambient_light_energy = 0.74
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.fog_enabled = true
	environment.fog_light_color = Color("263252")
	environment.fog_density = 0.010
	environment.fog_sky_affect = 0.34
	world_environment.environment = environment
	add_child(world_environment)

	var moonlight: DirectionalLight3D = DirectionalLight3D.new()
	moonlight.name = "Moonlight"
	moonlight.rotation_degrees = Vector3(-46.0, -24.0, 0.0)
	moonlight.light_color = Color("9eb7ff")
	moonlight.light_energy = 1.18
	moonlight.shadow_enabled = true
	add_child(moonlight)

	var soft_fill: DirectionalLight3D = DirectionalLight3D.new()
	soft_fill.name = "HorizonFill"
	soft_fill.rotation_degrees = Vector3(-12.0, 155.0, 0.0)
	soft_fill.light_color = Color("8c557e")
	soft_fill.light_energy = 0.24
	add_child(soft_fill)


func _build_sky() -> void:
	_sky_root = Node3D.new()
	_sky_root.name = "MemorySky"
	add_child(_sky_root)

	var moon_mesh: SphereMesh = SphereMesh.new()
	moon_mesh.radius = 3.4
	moon_mesh.height = 6.8
	var moon: MeshInstance3D = _add_mesh(_sky_root, moon_mesh, Vector3(-31.0, 23.5, -115.0), Color("dce6ff"))
	var moon_material: StandardMaterial3D = moon.material_override as StandardMaterial3D
	if moon_material != null:
		moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_material.emission_enabled = true
		moon_material.emission = Color("b6c9ff")
		moon_material.emission_energy_multiplier = 2.5

	var moon_glow_mesh: SphereMesh = SphereMesh.new()
	moon_glow_mesh.radius = 5.4
	moon_glow_mesh.height = 10.8
	var moon_glow: MeshInstance3D = _add_mesh(_sky_root, moon_glow_mesh, Vector3(-31.0, 23.5, -115.4), Color(0.35, 0.48, 0.82, 0.12))
	var moon_glow_material: StandardMaterial3D = moon_glow.material_override as StandardMaterial3D
	if moon_glow_material != null:
		moon_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		moon_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_glow_material.emission_enabled = true
		moon_glow_material.emission = Color("536baf")
		moon_glow_material.emission_energy_multiplier = 0.42

	for star_index: int in range(110):
		var star_mesh: SphereMesh = SphereMesh.new()
		var star_radius: float = _rng.randf_range(0.035, 0.095)
		star_mesh.radius = star_radius
		star_mesh.height = star_radius * 2.0
		var star_position: Vector3 = Vector3(
			_rng.randf_range(-72.0, 72.0),
			_rng.randf_range(10.0, 35.0),
			_rng.randf_range(-175.0, -45.0)
		)
		var star_color: Color = Color("dce7ff") if star_index % 5 != 0 else Color("f4d7df")
		var star: MeshInstance3D = _add_mesh(_sky_root, star_mesh, star_position, star_color)
		var star_material: StandardMaterial3D = star.material_override as StandardMaterial3D
		if star_material != null:
			star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			star_material.emission_enabled = true
			star_material.emission = star_color
			star_material.emission_energy_multiplier = _rng.randf_range(1.1, 2.1)

	_create_cloud_band(Vector3(-12.0, 17.5, -82.0), 0.30, 0.13, 36.0, 1.0)
	_create_cloud_band(Vector3(18.0, 22.0, -128.0), 0.18, 0.09, 45.0, 1.35)
	_create_cloud_band(Vector3(8.0, 13.5, -58.0), 0.42, 0.07, 28.0, 0.78)


func _create_cloud_band(
	origin: Vector3,
	speed: float,
	alpha: float,
	spread: float,
	scale_factor: float
) -> void:
	var band: Node3D = Node3D.new()
	band.position = origin
	band.set_meta("cloud_speed", speed)
	_sky_root.add_child(band)
	_cloud_layers.append(band)

	for cloud_index: int in range(9):
		var cloud_mesh: SphereMesh = SphereMesh.new()
		cloud_mesh.radius = _rng.randf_range(3.2, 6.8) * scale_factor
		cloud_mesh.height = _rng.randf_range(1.2, 2.4) * scale_factor
		var cloud_position: Vector3 = Vector3(
			-spread + (float(cloud_index) / 8.0) * spread * 2.0 + _rng.randf_range(-4.0, 4.0),
			_rng.randf_range(-1.2, 1.3),
			_rng.randf_range(-12.0, 12.0)
		)
		var cloud: MeshInstance3D = _add_mesh(band, cloud_mesh, cloud_position, Color(0.47, 0.53, 0.67, alpha))
		cloud.scale = Vector3(_rng.randf_range(1.2, 2.3), 0.32, _rng.randf_range(0.8, 1.5))
		var cloud_material: StandardMaterial3D = cloud.material_override as StandardMaterial3D
		if cloud_material != null:
			cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cloud_material.emission_enabled = true
			cloud_material.emission = Color("26314d")
			cloud_material.emission_energy_multiplier = 0.18


func _build_water() -> void:
	_water_visual = MeshInstance3D.new()
	_water_visual.name = "MoonlitWater"
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(190.0, 720.0)
	water_mesh.subdivide_width = 48
	water_mesh.subdivide_depth = 180
	_water_visual.mesh = water_mesh
	_water_visual.position = Vector3(0.0, -7.2, -270.0)

	var water_shader: Shader = Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color = vec3(0.006, 0.020, 0.055);
uniform vec3 mid_color = vec3(0.025, 0.080, 0.145);
uniform vec3 moon_color = vec3(0.32, 0.43, 0.67);

void vertex() {
	float wave_a = sin(VERTEX.x * 0.18 + TIME * 0.72);
	float wave_b = cos(VERTEX.z * 0.075 - TIME * 0.46);
	float wave_c = sin((VERTEX.x + VERTEX.z) * 0.055 + TIME * 0.31);
	VERTEX.y += wave_a * 0.16 + wave_b * 0.11 + wave_c * 0.08;
}

void fragment() {
	float ripple_a = sin(UV.x * 95.0 + TIME * 0.75);
	float ripple_b = cos(UV.y * 62.0 - TIME * 0.48);
	float ripple = clamp((ripple_a + ripple_b) * 0.25 + 0.5, 0.0, 1.0);
	float horizon = smoothstep(0.10, 0.92, UV.y);
	float moon_path = pow(max(0.0, 1.0 - abs(UV.x - 0.34) * 5.0), 8.0);
	vec3 water = mix(deep_color, mid_color, ripple * 0.30 + horizon * 0.12);
	water += moon_color * moon_path * ripple * 0.24;
	ALBEDO = water;
	EMISSION = water * 0.22;
	ROUGHNESS = 0.26;
	METALLIC = 0.08;
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

	for index: int in range(18):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var distance_from_center: float = 29.0 + float(index % 5) * 7.5
		var building_height: float = 5.0 + float((index * 7) % 12)
		var building_width: float = 4.0 + float((index * 3) % 7)
		var z_offset: float = -48.0 - float(index / 2) * 11.0
		var building_position: Vector3 = Vector3(
			side * distance_from_center,
			-7.2 + building_height * 0.5,
			z_offset
		)
		_add_box(
			_horizon_root,
			building_position,
			Vector3(building_width, building_height, 6.0),
			Color("080b15")
		)

		if index % 3 == 0:
			var window_color: Color = Color("425b8c") if index % 2 == 0 else Color("744161")
			_add_box(
				_horizon_root,
				building_position + Vector3(-side * (building_width * 0.51), 1.0, 0.0),
				Vector3(0.08, 0.34, 1.7),
				window_color,
				window_color
			)

	var horizon_glow: MeshInstance3D = _add_box(
		_horizon_root,
		Vector3(0.0, -5.8, -145.0),
		Vector3(120.0, 1.2, 5.0),
		Color("141225"),
		Color("38234d")
	)
	var horizon_material: StandardMaterial3D = horizon_glow.material_override as StandardMaterial3D
	if horizon_material != null:
		horizon_material.emission_energy_multiplier = 0.65


func _build_road() -> void:
	for index: int in range(ROAD_SEGMENT_COUNT):
		var segment: Node3D = Node3D.new()
		segment.name = "BridgeSegment%d" % index
		segment.position.z = 28.0 - float(index) * ROAD_SEGMENT_LENGTH
		add_child(segment)
		_road_segments.append(segment)

		_add_box(segment, Vector3(0.0, -0.24, 0.0), Vector3(11.8, 0.48, ROAD_SEGMENT_LENGTH), Color("101622"))
		_add_box(segment, Vector3(0.0, 0.01, 0.0), Vector3(8.4, 0.035, ROAD_SEGMENT_LENGTH), Color("1a202c"))
		_add_box(segment, Vector3(-4.72, -0.02, 0.0), Vector3(1.02, 0.12, ROAD_SEGMENT_LENGTH), Color("0a0e17"))
		_add_box(segment, Vector3(4.72, -0.02, 0.0), Vector3(1.02, 0.12, ROAD_SEGMENT_LENGTH), Color("0a0e17"))

		for marker_index: int in range(3):
			var marker_z: float = -4.5 + float(marker_index) * 4.5
			_add_box(
				segment,
				Vector3(0.0, 0.045, marker_z),
				Vector3(0.12, 0.025, 2.15),
				Color("d7d0ae"),
				Color("61583a")
			)

		_add_box(segment, Vector3(-5.48, 0.58, 0.0), Vector3(0.15, 0.18, ROAD_SEGMENT_LENGTH), Color("44516a"))
		_add_box(segment, Vector3(5.48, 0.58, 0.0), Vector3(0.15, 0.18, ROAD_SEGMENT_LENGTH), Color("44516a"))
		_add_box(segment, Vector3(-5.48, 1.16, 0.0), Vector3(0.10, 0.12, ROAD_SEGMENT_LENGTH), Color("2c3549"))
		_add_box(segment, Vector3(5.48, 1.16, 0.0), Vector3(0.10, 0.12, ROAD_SEGMENT_LENGTH), Color("2c3549"))

		for post_index: int in range(4):
			var post_z: float = -5.25 + float(post_index) * 3.5
			_add_box(segment, Vector3(-5.48, 0.80, post_z), Vector3(0.13, 1.35, 0.13), Color("344057"))
			_add_box(segment, Vector3(5.48, 0.80, post_z), Vector3(0.13, 1.35, 0.13), Color("344057"))

		_add_box(segment, Vector3(0.0, -1.10, 0.0), Vector3(10.2, 0.20, ROAD_SEGMENT_LENGTH), Color("0a0f19"))
		for truss_index: int in range(2):
			var truss_z: float = -3.5 + float(truss_index) * 7.0
			_add_box(segment, Vector3(0.0, -2.0, truss_z), Vector3(10.0, 0.18, 0.18), Color("111927"))
			_add_box(segment, Vector3(-4.8, -3.7, truss_z), Vector3(0.28, 5.2, 0.28), Color("0b111d"))
			_add_box(segment, Vector3(4.8, -3.7, truss_z), Vector3(0.28, 5.2, 0.28), Color("0b111d"))

		if index % 6 == 0:
			_build_bridge_tower(segment)

		var glow_color: Color = Color("6f83d8") if index % 2 == 0 else Color("c26483")
		_add_roadside_light(segment, Vector3(-5.05, 0.0, -3.2), glow_color)
		_add_roadside_light(segment, Vector3(5.05, 0.0, 3.2), glow_color)


func _build_bridge_tower(parent: Node3D) -> void:
	var tower_sides: Array[float] = [-1.0, 1.0]
	for side: float in tower_sides:
		_add_box(parent, Vector3(side * 5.0, 5.1, 0.0), Vector3(0.46, 10.2, 0.60), Color("182235"))
		_add_box(parent, Vector3(side * 5.0, 8.5, -4.1), Vector3(0.16, 0.16, 8.6), Color("485778"))

		for cable_index: int in range(4):
			var cable_z: float = -5.2 + float(cable_index) * 3.45
			var cable: MeshInstance3D = _add_box(
				parent,
				Vector3(side * 5.0, 4.9, cable_z),
				Vector3(0.07, 6.8, 0.07),
				Color("60719a")
			)
			cable.rotation_degrees.x = -18.0 + float(cable_index) * 12.0

	_add_box(parent, Vector3(0.0, 9.1, 0.0), Vector3(10.5, 0.42, 0.62), Color("1b263a"))


func _build_car() -> void:
	_car = Node3D.new()
	_car.name = "SpectralPontiac"
	_car.position = Vector3(0.0, 0.55, 8.0)
	add_child(_car)

	var red: Color = Color("8f152d")
	var dark_red: Color = Color("3d0a17")
	var glass: Color = Color("18243a")
	_add_box(_car, Vector3(0.0, 0.38, 0.0), Vector3(2.25, 0.55, 4.6), red, Color("320711"))
	_add_box(_car, Vector3(0.0, 0.86, -0.15), Vector3(1.78, 0.72, 2.25), dark_red)
	_add_box(_car, Vector3(0.0, 0.98, -0.45), Vector3(1.58, 0.42, 1.45), glass, Color("0b1730"))
	_add_box(_car, Vector3(0.0, 0.42, -2.1), Vector3(2.0, 0.2, 0.35), dark_red)

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
		var wheel: MeshInstance3D = _add_mesh(_car, wheel_mesh, wheel_position, Color("08090d"))
		wheel.rotation_degrees.z = 90.0

	var tail_positions: Array[float] = [-0.7, 0.7]
	for tail_x: float in tail_positions:
		var tail_light: OmniLight3D = OmniLight3D.new()
		tail_light.position = Vector3(tail_x, 0.55, 2.18)
		tail_light.light_color = Color("ff204d")
		tail_light.light_energy = 2.0
		tail_light.omni_range = 4.5
		_car.add_child(tail_light)

	var headlight_positions: Array[float] = [-0.67, 0.67]
	for headlight_x: float in headlight_positions:
		var headlight: SpotLight3D = SpotLight3D.new()
		headlight.position = Vector3(headlight_x, 0.52, -2.22)
		headlight.rotation_degrees.x = -7.0
		headlight.light_color = Color("d9e3ff")
		headlight.light_energy = 3.2
		headlight.spot_range = 19.0
		headlight.spot_angle = 34.0
		_car.add_child(headlight)

	_car_camera = Camera3D.new()
	_car_camera.name = "MemoryCamera"
	_car_camera.position = Vector3(0.0, 3.75, 8.7)
	_car_camera.rotation_degrees.x = -13.5
	_car_camera.fov = 66.0
	_car_camera.current = true
	_car.add_child(_car_camera)


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var title: Label = Label.new()
	title.position = Vector2(28.0, 24.0)
	title.size = Vector2(520.0, 50.0)
	title.text = "PONTIAC  //  MEMORY 01"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f1d7de"))
	canvas.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.position = Vector2(29.0, 62.0)
	subtitle.size = Vector2(680.0, 45.0)
	subtitle.text = "A / D TO DRIFT THROUGH A NIGHT YOU ALMOST REMEMBER"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("8c95b5"))
	canvas.add_child(subtitle)

	_distance_label = Label.new()
	_distance_label.anchor_left = 1.0
	_distance_label.anchor_right = 1.0
	_distance_label.offset_left = -300.0
	_distance_label.offset_right = -25.0
	_distance_label.offset_top = 28.0
	_distance_label.offset_bottom = 68.0
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_distance_label.text = "MEMORY DISTANCE  000"
	_distance_label.add_theme_font_size_override("font_size", 16)
	_distance_label.add_theme_color_override("font_color", Color("a8b2d0"))
	canvas.add_child(_distance_label)

	var cinematic_overlay: ColorRect = ColorRect.new()
	cinematic_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_shader: Shader = Shader.new()
	overlay_shader.code = """
shader_type canvas_item;

float random_value(vec2 coordinate) {
	return fract(sin(dot(coordinate, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.34, 0.76, length(centered));
	float grain = random_value(UV * vec2(1280.0, 720.0) + floor(TIME * 18.0));
	float top_bar = 1.0 - smoothstep(0.0, 0.035, UV.y);
	float bottom_bar = smoothstep(0.965, 1.0, UV.y);
	float bars = max(top_bar, bottom_bar);
	vec3 tint = vec3(0.025, 0.012, 0.045);
	float alpha = vignette * 0.38 + grain * 0.018 + bars * 0.92;
	COLOR = vec4(tint, alpha);
}
"""
	var overlay_material: ShaderMaterial = ShaderMaterial.new()
	overlay_material.shader = overlay_shader
	cinematic_overlay.material = overlay_material
	canvas.add_child(cinematic_overlay)


func _update_atmosphere(delta: float, steer_input: float) -> void:
	if _sky_root != null:
		_sky_root.position.z = _car.position.z

	for cloud_band: Node3D in _cloud_layers:
		var cloud_speed: float = float(cloud_band.get_meta("cloud_speed", 0.25))
		cloud_band.position.x += cloud_speed * delta
		if cloud_band.position.x > 58.0:
			cloud_band.position.x = -58.0

	if _water_visual != null:
		_water_visual.position.z = _car.position.z - 285.0

	if _horizon_root != null:
		_horizon_root.position.z = _car.position.z - 36.0

	if _car_camera != null:
		var elapsed: float = float(Time.get_ticks_msec()) * 0.001
		var camera_target_y: float = 3.75 + sin(elapsed * 1.15) * 0.055
		var camera_target_x: float = sin(elapsed * 0.33) * 0.07
		_car_camera.position.y = lerpf(_car_camera.position.y, camera_target_y, clampf(delta * 3.0, 0.0, 1.0))
		_car_camera.position.x = lerpf(_car_camera.position.x, camera_target_x, clampf(delta * 2.0, 0.0, 1.0))
		_car_camera.rotation_degrees.z = lerpf(
			_car_camera.rotation_degrees.z,
			-steer_input * 1.7 + sin(elapsed * 0.28) * 0.22,
			clampf(delta * 3.8, 0.0, 1.0)
		)


func _show_memory_end() -> void:
	_sequence_finished = true

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 80
	add_child(canvas)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 0.0)
	canvas.add_child(background)

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(background, "color", Color(0.0, 0.0, 0.0, 0.92), 1.5)
	await fade_tween.finished

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)

	var heading: Label = Label.new()
	heading.text = "YOU HAVE TAKEN THIS RIDE BEFORE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	stack.add_child(heading)

	var note: Label = Label.new()
	note.text = "The bridge disappears behind you. The memory opens into a city that should not exist."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color("a6aec5"))
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
	_add_box(parent, light_position + Vector3(0.0, 1.0, 0.0), Vector3(0.11, 2.0, 0.11), Color("111824"))
	_add_box(parent, light_position + Vector3(0.0, 2.12, 0.0), Vector3(0.28, 0.24, 0.28), glow_color, glow_color)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position + Vector3(0.0, 2.12, 0.0)
	light.light_color = glow_color
	light.light_energy = 1.55
	light.omni_range = 6.3
	parent.add_child(light)


func _add_box(
	parent: Node3D,
	box_position: Vector3,
	box_size: Vector3,
	color: Color,
	emission_color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var instance: MeshInstance3D = _add_mesh(parent, mesh, box_position, color)
	if emission_color.a > 0.0:
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		if material != null:
			material.emission_enabled = true
			material.emission = emission_color
			material.emission_energy_multiplier = 2.0
	return instance


func _add_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
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
