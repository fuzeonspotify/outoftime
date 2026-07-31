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
var _road_segments: Array[Node3D] = []
var _distance_travelled: float = 0.0
var _sequence_finished: bool = false
var _distance_label: Label


func _ready() -> void:
	_ensure_input_actions()
	_build_environment()
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

	if _distance_travelled >= MEMORY_DISTANCE:
		_show_memory_end()


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("040510")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("39466f")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("301f4d")
	environment.fog_density = 0.018
	world_environment.environment = environment
	add_child(world_environment)

	var moonlight: DirectionalLight3D = DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-48.0, -18.0, 0.0)
	moonlight.light_color = Color("8fa4ff")
	moonlight.light_energy = 1.2
	add_child(moonlight)


func _build_road() -> void:
	for index: int in range(ROAD_SEGMENT_COUNT):
		var segment: Node3D = Node3D.new()
		segment.name = "RoadSegment%d" % index
		segment.position.z = 28.0 - float(index) * ROAD_SEGMENT_LENGTH
		add_child(segment)
		_road_segments.append(segment)

		_add_box(segment, Vector3(0.0, -0.18, 0.0), Vector3(8.0, 0.35, ROAD_SEGMENT_LENGTH), Color("151824"))
		_add_box(segment, Vector3(-4.65, -0.12, 0.0), Vector3(1.3, 0.25, ROAD_SEGMENT_LENGTH), Color("090b12"))
		_add_box(segment, Vector3(4.65, -0.12, 0.0), Vector3(1.3, 0.25, ROAD_SEGMENT_LENGTH), Color("090b12"))

		for marker_index: int in range(3):
			var marker_z: float = -4.5 + float(marker_index) * 4.5
			_add_box(segment, Vector3(0.0, 0.01, marker_z), Vector3(0.12, 0.025, 2.2), Color("d8d3b5"), Color("665f42"))

		var glow_color: Color = Color("8b2cff") if index % 2 == 0 else Color("ee285f")
		_add_roadside_light(segment, Vector3(-5.2, 0.0, -3.2), glow_color)
		_add_roadside_light(segment, Vector3(5.2, 0.0, 3.2), glow_color)


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

	for tail_x: float in [-0.7, 0.7]:
		var tail_light: OmniLight3D = OmniLight3D.new()
		tail_light.position = Vector3(tail_x, 0.55, 2.18)
		tail_light.light_color = Color("ff204d")
		tail_light.light_energy = 2.0
		tail_light.omni_range = 4.5
		_car.add_child(tail_light)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 3.7, 8.5)
	camera.rotation_degrees.x = -13.0
	camera.fov = 67.0
	camera.current = true
	_car.add_child(camera)


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
	subtitle.size = Vector2(580.0, 45.0)
	subtitle.text = "A / D TO DRIFT THROUGH THE MEMORY"
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
	note.text = "The memory road opens into a city that should not exist."
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
	_add_box(parent, light_position + Vector3(0.0, 0.8, 0.0), Vector3(0.1, 1.6, 0.1), Color("11131b"))
	_add_box(parent, light_position + Vector3(0.0, 1.72, 0.0), Vector3(0.22, 0.22, 0.22), glow_color, glow_color)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position + Vector3(0.0, 1.72, 0.0)
	light.light_color = glow_color
	light.light_energy = 1.8
	light.omni_range = 5.5
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
			material.emission_energy_multiplier = 2.2
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
