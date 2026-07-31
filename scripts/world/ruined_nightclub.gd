extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/world/interactable.gd")
const CHAMBER_SCENE_PATH: String = "res://scenes/skeleton_chamber.tscn"
const ROOM_HALF_WIDTH: float = 17.0
const ROOM_FRONT_Z: float = 32.0
const ROOM_BACK_Z: float = -38.0
const MAX_STABILITY: float = 100.0

var _player: CharacterBody3D
var _ghosts: Array[Node3D] = []
var _breaker_interactions: Array[Area3D] = []
var _exit_interaction: Area3D
var _breakers_restored: int = 0
var _restored_breakers: Dictionary = {}
var _stability: float = MAX_STABILITY
var _stability_label: Label
var _breaker_label: Label
var _chapter_label: Label
var _pulse_lights: Array[OmniLight3D] = []
var _chapter_complete: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4041999
	SFXDirector.stop_environment(0.8)
	MusicDirector.play_cue("rockstar_chase", 1.6)
	_build_environment()
	_build_room()
	_build_stage()
	_build_bar()
	_build_dance_floor()
	_build_balcony()
	_build_debris()
	_build_story_interactions()
	_build_ghost_crowd()
	_spawn_player()
	_build_hud()


func _process(delta: float) -> void:
	_update_lighting()
	_update_ghosts(delta)


func _exit_tree() -> void:
	if not _chapter_complete:
		MusicDirector.stop_music(1.0)


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("020108")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("321e4b")
	environment.ambient_light_energy = 0.58
	environment.fog_enabled = true
	environment.fog_light_color = Color("5d1e5d")
	environment.fog_density = 0.022
	environment.glow_enabled = true
	environment.glow_bloom = 0.12
	environment.glow_intensity = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var ceiling_fill: DirectionalLight3D = DirectionalLight3D.new()
	ceiling_fill.rotation_degrees = Vector3(-76.0, 18.0, 0.0)
	ceiling_fill.light_color = Color("67529c")
	ceiling_fill.light_energy = 0.42
	ceiling_fill.shadow_enabled = true
	add_child(ceiling_fill)


func _build_room() -> void:
	_create_static_box("ClubFloor", Vector3(0.0, -0.35, -3.0), Vector3(36.0, 0.7, 74.0), Color("080711"))
	_create_static_box("LeftWall", Vector3(-18.0, 5.0, -3.0), Vector3(1.0, 10.0, 74.0), Color("100b18"))
	_create_static_box("RightWall", Vector3(18.0, 5.0, -3.0), Vector3(1.0, 10.0, 74.0), Color("100b18"))
	_create_static_box("BackWall", Vector3(0.0, 5.0, -39.0), Vector3(36.0, 10.0, 1.0), Color("0d0812"))
	_create_static_box("EntranceWallLeft", Vector3(-11.0, 5.0, 34.0), Vector3(14.0, 10.0, 1.0), Color("0d0812"))
	_create_static_box("EntranceWallRight", Vector3(11.0, 5.0, 34.0), Vector3(14.0, 10.0, 1.0), Color("0d0812"))

	for column_z: float in [25.0, 12.0, -1.0, -14.0, -27.0]:
		_create_static_box("LeftColumn", Vector3(-14.8, 3.0, column_z), Vector3(1.0, 6.0, 1.0), Color("211329"))
		_create_static_box("RightColumn", Vector3(14.8, 3.0, column_z), Vector3(1.0, 6.0, 1.0), Color("211329"))

	for truss_z: float in [22.0, 6.0, -10.0, -26.0]:
		_create_visual_box("CeilingTruss", Vector3(0.0, 7.1, truss_z), Vector3(31.0, 0.22, 0.22), Color("33243f"))
		for light_x: float in [-10.5, -3.5, 3.5, 10.5]:
			var color: Color = Color("f23c9c") if int(absf(light_x)) % 2 == 0 else Color("6e50ff")
			_create_pulse_light(Vector3(light_x, 6.6, truss_z), color)


func _build_stage() -> void:
	_create_static_box("Stage", Vector3(0.0, 0.55, -31.0), Vector3(18.0, 1.1, 9.0), Color("1a1021"))
	_create_visual_box("StageBackdrop", Vector3(0.0, 4.0, -36.0), Vector3(18.0, 7.0, 0.4), Color("19091a"))
	_create_glowing_box("StageNeon", Vector3(0.0, 5.2, -35.7), Vector3(12.0, 0.35, 0.18), Color("f13b99"), 3.0)

	var sign: Label3D = Label3D.new()
	sign.text = "OUT OF TIME"
	sign.font_size = 78
	sign.modulate = Color("ffc2e4")
	sign.outline_size = 10
	sign.position = Vector3(0.0, 4.25, -35.45)
	add_child(sign)

	for speaker_x: float in [-7.0, 7.0]:
		_create_static_box("SpeakerTower", Vector3(speaker_x, 2.0, -33.0), Vector3(2.5, 4.0, 2.2), Color("09080d"))
		for speaker_y: float in [1.0, 2.4, 3.4]:
			var speaker_mesh: CylinderMesh = CylinderMesh.new()
			speaker_mesh.top_radius = 0.55
			speaker_mesh.bottom_radius = 0.55
			speaker_mesh.height = 0.16
			var speaker: MeshInstance3D = _add_visual_mesh(self, speaker_mesh, Vector3(speaker_x, speaker_y, -31.84), _make_material(Color("20202a")))
			speaker.rotation_degrees.x = 90.0


func _build_bar() -> void:
	_create_static_box("BarCounter", Vector3(-13.0, 1.0, 6.0), Vector3(6.5, 2.0, 16.0), Color("241329"))
	_create_visual_box("BarTop", Vector3(-13.0, 2.05, 6.0), Vector3(6.8, 0.15, 16.2), Color("4b2850"))
	_create_glowing_box("BarStrip", Vector3(-9.55, 1.2, 6.0), Vector3(0.10, 0.20, 14.5), Color("a84cff"), 1.8)

	for bottle_index: int in range(13):
		var z_position: float = -0.2 + float(bottle_index) * 1.05
		var bottle_color: Color = Color("54b7ff") if bottle_index % 2 == 0 else Color("f85da8")
		_create_glowing_box("Bottle", Vector3(-9.7, 2.55, z_position), Vector3(0.16, 0.72, 0.16), bottle_color, 1.1)


func _build_dance_floor() -> void:
	var tile_size: float = 2.1
	for x_index: int in range(-4, 5):
		for z_index: int in range(-6, 6):
			var tile_color: Color = Color("48235f")
			if (x_index + z_index) % 3 == 0:
				tile_color = Color("7b295d")
			elif (x_index + z_index) % 3 == 1:
				tile_color = Color("253c6d")
			_create_glowing_box(
				"DanceTile",
				Vector3(float(x_index) * tile_size, 0.03, 6.0 + float(z_index) * tile_size),
				Vector3(tile_size - 0.08, 0.06, tile_size - 0.08),
				tile_color,
				0.28
			)


func _build_balcony() -> void:
	_create_static_box("BalconyFloor", Vector3(12.5, 4.0, -10.0), Vector3(9.0, 0.55, 18.0), Color("16101d"))
	_create_static_box("BalconyStairs1", Vector3(13.0, 0.35, 3.0), Vector3(7.0, 0.7, 2.4), Color("21152a"))
	_create_static_box("BalconyStairs2", Vector3(13.0, 1.05, 0.7), Vector3(7.0, 0.7, 2.4), Color("21152a"))
	_create_static_box("BalconyStairs3", Vector3(13.0, 1.75, -1.6), Vector3(7.0, 0.7, 2.4), Color("21152a"))
	_create_static_box("BalconyStairs4", Vector3(13.0, 2.45, -3.9), Vector3(7.0, 0.7, 2.4), Color("21152a"))
	_create_static_box("BalconyStairs5", Vector3(13.0, 3.15, -6.2), Vector3(7.0, 0.7, 2.4), Color("21152a"))
	_create_visual_box("BalconyRail", Vector3(8.4, 5.0, -10.0), Vector3(0.18, 2.0, 18.0), Color("56415f"))


func _build_debris() -> void:
	for debris_index: int in range(18):
		var x_position: float = _rng.randf_range(-13.5, 13.5)
		var z_position: float = _rng.randf_range(-27.0, 28.0)
		if absf(x_position) < 4.0 and z_position < -22.0:
			continue
		var size: Vector3 = Vector3(
			_rng.randf_range(0.25, 1.2),
			_rng.randf_range(0.10, 0.35),
			_rng.randf_range(0.35, 1.4)
		)
		var debris: MeshInstance3D = _create_visual_box("Debris", Vector3(x_position, size.y * 0.5, z_position), size, Color("241b2d"))
		debris.rotation_degrees.y = _rng.randf_range(0.0, 180.0)


func _build_story_interactions() -> void:
	var breaker_ids: Array[String] = ["bar", "stage", "balcony"]
	var breaker_positions: Array[Vector3] = [
		Vector3(-9.3, 0.0, 13.0),
		Vector3(0.0, 1.0, -29.0),
		Vector3(12.0, 4.1, -14.0)
	]
	var breaker_prompts: Array[String] = [
		"Restore the bar breaker",
		"Restore the stage breaker",
		"Restore the balcony breaker"
	]
	var breaker_messages: Array[String] = [
		"The bottles light up. In every reflection, you are smiling beside someone different.",
		"The speakers wake. The crowd mouths lyrics you have not written yet.",
		"From above, every dancer has your skull and someone else's clothes."
	]

	for index: int in range(breaker_ids.size()):
		var breaker_position: Vector3 = breaker_positions[index]
		var interaction: Area3D = _create_interaction(
			"Breaker_%s" % breaker_ids[index],
			breaker_position,
			Vector3(3.0, 3.0, 3.0),
			breaker_prompts[index],
			breaker_messages[index],
			true
		)
		interaction.connect("activated", Callable(self, "_on_breaker_restored").bind(breaker_ids[index]))
		_breaker_interactions.append(interaction)
		_create_breaker_visual(breaker_position + Vector3(0.0, 1.1, 0.0))

	_exit_interaction = _create_interaction(
		"BackstageExit",
		Vector3(0.0, 0.0, -36.0),
		Vector3(7.0, 4.0, 4.0),
		"Descend beneath the stage",
		"The woman is gone. A stairwell breathes cold air from somewhere below the club.",
		true
	)
	_exit_interaction.monitoring = false
	_exit_interaction.connect("activated", Callable(self, "_on_exit_activated"))


func _build_ghost_crowd() -> void:
	var spawn_positions: Array[Vector3] = [
		Vector3(-7.0, 0.0, 22.0),
		Vector3(7.0, 0.0, 18.0),
		Vector3(-5.5, 0.0, 5.0),
		Vector3(6.5, 0.0, -2.0),
		Vector3(-7.5, 0.0, -13.0),
		Vector3(7.0, 0.0, -22.0)
	]
	for index: int in range(spawn_positions.size()):
		var ghost: Node3D = _create_ghost(index)
		ghost.position = spawn_positions[index]
		ghost.set_meta("speed", 1.65 + float(index % 3) * 0.24)
		ghost.set_meta("phase", float(index) * 1.4)
		add_child(ghost)
		_ghosts.append(ghost)


func _spawn_player() -> void:
	var instance: Node = PLAYER_SCENE.instantiate()
	_player = instance as CharacterBody3D
	if _player == null:
		push_error("Player scene root must be CharacterBody3D.")
		return
	_player.position = Vector3(0.0, 0.1, 28.5)
	add_child(_player)
	_player.set_objective("Restore three breakers while avoiding the spectral crowd.")
	_player.show_interaction_message("The doors lock behind you. The music recognizes your heartbeat.", 5.0)


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 25
	add_child(canvas)

	_chapter_label = Label.new()
	_chapter_label.position = Vector2(30.0, 126.0)
	_chapter_label.size = Vector2(520.0, 36.0)
	_chapter_label.text = "CHAPTER 03  //  RUINED CLUB"
	_chapter_label.add_theme_font_size_override("font_size", 16)
	_chapter_label.add_theme_color_override("font_color", Color("f3a9d1"))
	canvas.add_child(_chapter_label)

	_stability_label = Label.new()
	_stability_label.anchor_left = 1.0
	_stability_label.anchor_right = 1.0
	_stability_label.offset_left = -330.0
	_stability_label.offset_right = -30.0
	_stability_label.offset_top = 126.0
	_stability_label.offset_bottom = 160.0
	_stability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stability_label.add_theme_font_size_override("font_size", 17)
	_stability_label.add_theme_color_override("font_color", Color("f18abf"))
	canvas.add_child(_stability_label)

	_breaker_label = Label.new()
	_breaker_label.anchor_left = 1.0
	_breaker_label.anchor_right = 1.0
	_breaker_label.offset_left = -330.0
	_breaker_label.offset_right = -30.0
	_breaker_label.offset_top = 158.0
	_breaker_label.offset_bottom = 192.0
	_breaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_breaker_label.add_theme_font_size_override("font_size", 15)
	_breaker_label.add_theme_color_override("font_color", Color("b7a7d9"))
	canvas.add_child(_breaker_label)
	_update_hud()


func _update_lighting() -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) * 0.001
	for index: int in range(_pulse_lights.size()):
		var light: OmniLight3D = _pulse_lights[index]
		var pulse: float = 0.70 + sin(time_seconds * 3.2 + float(index) * 0.85) * 0.35
		light.light_energy = maxf(0.15, pulse * 2.0)


func _update_ghosts(delta: float) -> void:
	if _player == null or _chapter_complete:
		return

	var nearest_distance: float = 999.0
	var time_seconds: float = float(Time.get_ticks_msec()) * 0.001
	for ghost: Node3D in _ghosts:
		if not is_instance_valid(ghost):
			continue
		var planar_target: Vector3 = _player.global_position
		planar_target.y = ghost.global_position.y
		var direction: Vector3 = planar_target - ghost.global_position
		var distance: float = direction.length()
		nearest_distance = minf(nearest_distance, distance)
		if distance > 0.08:
			var speed: float = float(ghost.get_meta("speed", 1.8))
			ghost.global_position += direction.normalized() * speed * delta
			ghost.look_at(planar_target, Vector3.UP, true)
		var phase: float = float(ghost.get_meta("phase", 0.0))
		ghost.position.y = 0.12 + sin(time_seconds * 2.0 + phase) * 0.12

		if distance < 1.45:
			_stability -= delta * 20.0
			var push_direction: Vector3 = (_player.global_position - ghost.global_position).normalized()
			_player.velocity.x += push_direction.x * delta * 8.0
			_player.velocity.z += push_direction.z * delta * 8.0

	if nearest_distance > 2.8:
		_stability += delta * 5.0
	_stability = clampf(_stability, 0.0, MAX_STABILITY)
	_update_hud()
	if _stability <= 0.0:
		_reset_player_after_collapse()


func _reset_player_after_collapse() -> void:
	_stability = MAX_STABILITY
	_player.position = Vector3(0.0, 0.1, 28.5)
	_player.velocity = Vector3.ZERO
	_player.show_interaction_message("The club rewinds you to the entrance. The breakers remain restored.", 4.5)
	SFXDirector.play_reveal()
	for index: int in range(_ghosts.size()):
		var ghost: Node3D = _ghosts[index]
		ghost.position = Vector3(-7.0 + float(index % 2) * 14.0, 0.0, 20.0 - float(index) * 7.5)
	_update_hud()


func _on_breaker_restored(player: Node, breaker_id: String) -> void:
	if _restored_breakers.has(breaker_id):
		return
	_restored_breakers[breaker_id] = true
	_breakers_restored += 1
	SFXDirector.play_reveal()
	_update_hud()

	if _breakers_restored >= 3:
		_exit_interaction.monitoring = true
		if player.has_method("set_objective"):
			player.call("set_objective", "Reach the stairwell behind the stage.")
		if player.has_method("show_interaction_message"):
			player.call("show_interaction_message", "All three circuits are alive. A hidden door opens behind the stage.", 5.0)
	else:
		if player.has_method("set_objective"):
			player.call("set_objective", "Breakers restored: %d / 3" % _breakers_restored)


func _on_exit_activated(player: Node) -> void:
	if _chapter_complete:
		return
	_chapter_complete = true
	if player.has_method("set_objective"):
		player.call("set_objective", "Descend beneath the nightclub.")
	MusicDirector.stop_music(1.0)
	await get_tree().create_timer(1.1).timeout
	get_tree().change_scene_to_file(CHAMBER_SCENE_PATH)


func _create_breaker_visual(breaker_position: Vector3) -> void:
	_create_static_box("BreakerCabinet", breaker_position, Vector3(0.9, 1.6, 0.45), Color("18141e"))
	_create_glowing_box("BreakerLamp", breaker_position + Vector3(0.0, 0.42, -0.25), Vector3(0.28, 0.22, 0.08), Color("ff4da3"), 2.0)
	_create_visual_box("BreakerHandle", breaker_position + Vector3(0.0, -0.15, -0.28), Vector3(0.14, 0.48, 0.12), Color("b8a7c5"))


func _create_ghost(index: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "SpectralCrowdMember%d" % index
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var base_color: Color = Color("8b75e8") if index % 2 == 0 else Color("e05b9f")
	material.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.50)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = base_color
	material.emission_energy_multiplier = 0.72

	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.24
	skull.height = 0.46
	_add_visual_mesh(root, skull, Vector3(0.0, 1.86, 0.0), material)

	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = 0.20
	torso.height = 1.0
	_add_visual_mesh(root, torso, Vector3(0.0, 1.14, 0.0), material)

	for rib_index: int in range(3):
		var rib: BoxMesh = BoxMesh.new()
		rib.size = Vector3(0.55, 0.05, 0.13)
		_add_visual_mesh(root, rib, Vector3(0.0, 1.42 - float(rib_index) * 0.14, -0.02), material)

	var limb: CapsuleMesh = CapsuleMesh.new()
	limb.radius = 0.055
	limb.height = 0.72
	var left_arm: MeshInstance3D = _add_visual_mesh(root, limb, Vector3(-0.36, 1.16, 0.0), material)
	left_arm.rotation_degrees.z = -14.0
	var right_arm: MeshInstance3D = _add_visual_mesh(root, limb, Vector3(0.36, 1.16, 0.0), material)
	right_arm.rotation_degrees.z = 14.0
	_add_visual_mesh(root, limb, Vector3(-0.14, 0.43, 0.0), material)
	_add_visual_mesh(root, limb, Vector3(0.14, 0.43, 0.0), material)
	return root


func _create_pulse_light(light_position: Vector3, color: Color) -> void:
	_create_glowing_box("ClubFixture", light_position, Vector3(0.70, 0.18, 0.50), color, 2.2)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position - Vector3(0.0, 0.25, 0.0)
	light.light_color = color
	light.light_energy = 1.8
	light.omni_range = 8.0
	add_child(light)
	_pulse_lights.append(light)


func _create_interaction(node_name: String, interaction_position: Vector3, shape_size: Vector3, prompt: String, message: String, one_shot: bool) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = node_name
	area.set_script(INTERACTABLE_SCRIPT)
	area.set("prompt_text", prompt)
	area.set("interaction_message", message)
	area.set("one_shot", one_shot)
	area.position = interaction_position
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = shape_size
	collision.shape = shape
	collision.position = Vector3(0.0, shape_size.y * 0.5, 0.0)
	area.add_child(collision)
	add_child(area)
	return area


func _create_static_box(node_name: String, box_position: Vector3, box_size: Vector3, color: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _make_material(color)
	body.add_child(visual)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _create_visual_box(node_name: String, box_position: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var instance: MeshInstance3D = _add_visual_mesh(self, mesh, box_position, _make_material(color))
	instance.name = node_name
	return instance


func _create_glowing_box(node_name: String, box_position: Vector3, box_size: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var material: StandardMaterial3D = _make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var instance: MeshInstance3D = _add_visual_mesh(self, mesh, box_position, material)
	instance.name = node_name
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func _add_visual_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _update_hud() -> void:
	if _stability_label != null:
		_stability_label.text = "SOUL STABILITY  %03d%%" % int(round(_stability))
	if _breaker_label != null:
		_breaker_label.text = "BREAKERS  %d / 3" % _breakers_restored
