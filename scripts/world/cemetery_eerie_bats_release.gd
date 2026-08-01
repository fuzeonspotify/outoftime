extends Node

const BAT_SCENE_PATH: String = "res://assets/models/animals/realistic_bat/scene.gltf"
const BAT_COUNT: int = 7
const TARGET_BAT_WINGSPAN: float = 0.82

var _cemetery: Node3D
var _bat_records: Array[Dictionary] = []
var _elapsed: float = 0.0


func _ready() -> void:
	set_process(false)
	_install_cemetery_release_pass.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	for record: Dictionary in _bat_records:
		_update_bat(record)


func _install_cemetery_release_pass() -> void:
	# Cemetery builds its environment procedurally in the parent _ready(). Wait
	# until that setup and the expanded geometry pass have both completed.
	for _frame_index: int in range(10):
		await get_tree().process_frame

	_cemetery = get_parent() as Node3D
	if _cemetery == null:
		return

	_dark_grade_cemetery()
	_add_cemetery_moon_fill()
	_install_required_bats()


func _dark_grade_cemetery() -> void:
	var environment_nodes: Array[Node] = _cemetery.find_children(
		"*",
		"WorldEnvironment",
		true,
		false
	)
	for node: Node in environment_nodes:
		var world_environment: WorldEnvironment = node as WorldEnvironment
		if world_environment == null or world_environment.environment == null:
			continue
		var environment: Environment = world_environment.environment

		var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("010207")
		sky_material.sky_horizon_color = Color("09101a")
		sky_material.ground_bottom_color = Color("000104")
		sky_material.ground_horizon_color = Color("080b10")
		sky_material.sun_angle_max = 0.8
		sky_material.sun_curve = 0.02

		var sky: Sky = Sky.new()
		sky.sky_material = sky_material
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.background_energy_multiplier = 0.28
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("263249")
		environment.ambient_light_energy = 0.30
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG

		environment.fog_enabled = true
		environment.fog_light_color = Color("202b3b")
		environment.fog_light_energy = 0.42
		environment.fog_density = 0.052
		environment.fog_height = 1.2
		environment.fog_height_density = 0.36
		environment.fog_sky_affect = 0.92

		environment.glow_enabled = true
		environment.glow_intensity = 0.72
		environment.glow_bloom = 0.14
		environment.adjustment_enabled = true
		environment.adjustment_brightness = 0.72
		environment.adjustment_contrast = 1.18
		environment.adjustment_saturation = 0.64
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var directional_nodes: Array[Node] = _cemetery.find_children(
		"*",
		"DirectionalLight3D",
		true,
		false
	)
	for node: Node in directional_nodes:
		var moonlight: DirectionalLight3D = node as DirectionalLight3D
		if moonlight == null:
			continue
		moonlight.light_color = Color("7185ae")
		moonlight.light_energy = minf(moonlight.light_energy, 0.58)
		moonlight.shadow_enabled = true
		moonlight.directional_shadow_max_distance = 82.0

	# Existing lanterns remain readable, but their warm pools are tightened so
	# the spaces between them stay genuinely dark.
	var omni_nodes: Array[Node] = _cemetery.find_children("*", "OmniLight3D", true, false)
	for node: Node in omni_nodes:
		var light: OmniLight3D = node as OmniLight3D
		if light == null:
			continue
		if str(light.name).contains("RiggedGhostWoman"):
			continue
		light.light_energy *= 0.62
		light.omni_range *= 0.82


func _add_cemetery_moon_fill() -> void:
	if _cemetery.get_node_or_null("EerieCemeteryFill") != null:
		return

	var fill_root: Node3D = Node3D.new()
	fill_root.name = "EerieCemeteryFill"
	_cemetery.add_child(fill_root)

	var gate_fill: OmniLight3D = OmniLight3D.new()
	gate_fill.name = "GateColdFill"
	gate_fill.position = Vector3(0.0, 4.5, -26.0)
	gate_fill.light_color = Color("4c5f8e")
	gate_fill.light_energy = 0.72
	gate_fill.omni_range = 16.0
	gate_fill.shadow_enabled = true
	fill_root.add_child(gate_fill)

	var memorial_fill: OmniLight3D = OmniLight3D.new()
	memorial_fill.name = "MemorialBloodFill"
	memorial_fill.position = Vector3(0.0, 1.2, -19.0)
	memorial_fill.light_color = Color("5c1830")
	memorial_fill.light_energy = 0.44
	memorial_fill.omni_range = 7.5
	fill_root.add_child(memorial_fill)


func _install_required_bats() -> void:
	if not ResourceLoader.exists(BAT_SCENE_PATH):
		push_error(
			"REQUIRED BAT MODEL ERROR: %s is missing. No substitute bat will be created." % BAT_SCENE_PATH
		)
		return

	var bat_scene: PackedScene = load(BAT_SCENE_PATH) as PackedScene
	if bat_scene == null:
		push_error(
			"REQUIRED BAT MODEL ERROR: the installed realistic bat scene could not be loaded. No substitute bat will be created."
		)
		return

	var flight_root: Node3D = Node3D.new()
	flight_root.name = "RealisticBatFlock"
	_cemetery.add_child(flight_root)

	var flight_centers: Array[Vector3] = [
		Vector3(-6.0, 8.2, -8.0),
		Vector3(7.5, 10.0, -18.0),
		Vector3(-10.0, 7.4, 7.0),
		Vector3(11.0, 9.0, 13.0),
		Vector3(0.0, 11.2, -27.0),
		Vector3(-14.0, 8.8, -23.0),
		Vector3(14.0, 7.8, -2.0)
	]

	for bat_index: int in range(BAT_COUNT):
		var path_root: Node3D = Node3D.new()
		path_root.name = "BatFlight%02d" % bat_index
		flight_root.add_child(path_root)

		var bat_model: Node3D = bat_scene.instantiate() as Node3D
		if bat_model == null:
			path_root.queue_free()
			continue
		bat_model.name = "RealisticAnimatedBat"
		path_root.add_child(bat_model)
		_normalize_bat(bat_model)

		var animation_player: AnimationPlayer = _find_animation_player(bat_model)
		var animation_name: StringName = _select_flight_animation(animation_player)
		if animation_player == null or animation_name == &"":
			bat_model.queue_free()
			path_root.queue_free()
			push_error("REQUIRED BAT MODEL ERROR: the bat has no usable flight animation.")
			continue
		var flight_animation: Animation = animation_player.get_animation(animation_name)
		if flight_animation != null:
			flight_animation.loop_mode = Animation.LOOP_LINEAR
		animation_player.play(animation_name, 0.15, 0.82 + float(bat_index % 4) * 0.09)

		var record: Dictionary = {
			"root": path_root,
			"model": bat_model,
			"center": flight_centers[bat_index],
			"radius_x": 5.2 + float(bat_index % 3) * 2.0,
			"radius_z": 7.0 + float((bat_index + 1) % 3) * 2.3,
			"speed": 0.38 + float(bat_index % 4) * 0.055,
			"phase": float(bat_index) * 0.91,
			"height_wave": 0.7 + float(bat_index % 3) * 0.32
		}
		_bat_records.append(record)
		_update_bat(record)

	set_process(not _bat_records.is_empty())


func _normalize_bat(model: Node3D) -> void:
	var bounds: AABB = _calculate_model_bounds(model)
	var longest_axis: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_axis <= 0.001:
		push_error("REQUIRED BAT MODEL ERROR: invalid mesh bounds.")
		return
	var scale_factor: float = clampf(TARGET_BAT_WINGSPAN / longest_axis, 0.02, 8.0)
	model.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	model.position = -center * scale_factor


func _calculate_model_bounds(model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = (
			model.global_transform.affine_inverse() * mesh_instance.global_transform
		)
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
	return bounds


func _find_animation_player(model: Node3D) -> AnimationPlayer:
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	var selected: AnimationPlayer
	var largest_count: int = -1
	for node: Node in players:
		var candidate: AnimationPlayer = node as AnimationPlayer
		if candidate == null:
			continue
		var count: int = candidate.get_animation_list().size()
		if count > largest_count:
			selected = candidate
			largest_count = count
	return selected


func _select_flight_animation(animation_player: AnimationPlayer) -> StringName:
	if animation_player == null:
		return &""
	var keywords: Array[String] = ["fly", "flight", "flap", "wing", "takeoff"]
	for animation_variant: Variant in animation_player.get_animation_list():
		var animation_name: StringName = StringName(str(animation_variant))
		var descriptor: String = str(animation_name).to_lower()
		if descriptor == "reset":
			continue
		for keyword: String in keywords:
			if descriptor.contains(keyword):
				return animation_name
	for animation_variant: Variant in animation_player.get_animation_list():
		var animation_name: StringName = StringName(str(animation_variant))
		if str(animation_name).to_lower() != "reset":
			return animation_name
	return &""


func _update_bat(record: Dictionary) -> void:
	var path_root: Node3D = record.get("root") as Node3D
	if path_root == null or not is_instance_valid(path_root):
		return
	var center: Vector3 = record.get("center", Vector3.ZERO)
	var radius_x: float = float(record.get("radius_x", 6.0))
	var radius_z: float = float(record.get("radius_z", 8.0))
	var speed: float = float(record.get("speed", 0.4))
	var phase: float = float(record.get("phase", 0.0))
	var height_wave: float = float(record.get("height_wave", 1.0))
	var angle: float = _elapsed * speed + phase

	var position_now: Vector3 = center + Vector3(
		cos(angle) * radius_x,
		sin(angle * 2.15 + phase) * height_wave,
		sin(angle) * radius_z
	)
	var look_angle: float = angle + 0.045
	var position_next: Vector3 = center + Vector3(
		cos(look_angle) * radius_x,
		sin(look_angle * 2.15 + phase) * height_wave,
		sin(look_angle) * radius_z
	)
	path_root.position = position_now
	path_root.look_at(position_next, Vector3.UP, true)
	path_root.rotation.z += sin(angle * 1.7) * 0.14
