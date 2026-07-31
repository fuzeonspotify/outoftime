extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/world/interactable.gd")
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"

var _player: CharacterBody3D
var _journals_read: int = 0
var _read_journals: Dictionary = {}
var _woman_interaction: Area3D
var _woman_visual: Node3D
var _chapter_finished: bool = false
var _journal_label: Label
var _floating_skulls: Array[Node3D] = []


func _ready() -> void:
	SFXDirector.stop_environment(0.6)
	MusicDirector.play_cue("circles_reveal", 2.0)
	_build_environment()
	_build_chamber()
	_build_bone_columns()
	_build_central_dais()
	_build_journals()
	_build_woman()
	_build_floating_skulls()
	_spawn_player()
	_build_hud()


func _process(delta: float) -> void:
	var time_seconds: float = float(Time.get_ticks_msec()) * 0.001
	for index: int in range(_floating_skulls.size()):
		var skull_root: Node3D = _floating_skulls[index]
		skull_root.rotation.y += delta * (0.18 + float(index) * 0.025)
		skull_root.position.y = 2.8 + sin(time_seconds * 0.85 + float(index)) * 0.35


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("010207")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("252c50")
	environment.ambient_light_energy = 0.54
	environment.fog_enabled = true
	environment.fog_light_color = Color("20335e")
	environment.fog_density = 0.035
	environment.glow_enabled = true
	environment.glow_bloom = 0.10
	environment.glow_intensity = 0.60
	world_environment.environment = environment
	add_child(world_environment)

	var top_light: DirectionalLight3D = DirectionalLight3D.new()
	top_light.rotation_degrees = Vector3(-80.0, 0.0, 0.0)
	top_light.light_color = Color("8298d9")
	top_light.light_energy = 0.78
	top_light.shadow_enabled = true
	add_child(top_light)


func _build_chamber() -> void:
	_create_static_box("ChamberFloor", Vector3(0.0, -0.35, -4.0), Vector3(38.0, 0.7, 70.0), Color("080b13"))
	_create_static_box("LeftStoneWall", Vector3(-19.0, 5.0, -4.0), Vector3(1.0, 10.0, 70.0), Color("101522"))
	_create_static_box("RightStoneWall", Vector3(19.0, 5.0, -4.0), Vector3(1.0, 10.0, 70.0), Color("101522"))
	_create_static_box("BackStoneWall", Vector3(0.0, 5.0, -39.0), Vector3(38.0, 10.0, 1.0), Color("0c101b"))
	_create_static_box("FrontStoneWallLeft", Vector3(-12.0, 5.0, 31.0), Vector3(14.0, 10.0, 1.0), Color("0c101b"))
	_create_static_box("FrontStoneWallRight", Vector3(12.0, 5.0, 31.0), Vector3(14.0, 10.0, 1.0), Color("0c101b"))

	for z_position: float in [24.0, 12.0, 0.0, -12.0, -24.0, -34.0]:
		_create_visual_box("FloorInlay", Vector3(0.0, 0.025, z_position), Vector3(11.0, 0.04, 0.18), Color("394a78"))

	for lamp_z: float in [22.0, 8.0, -6.0, -20.0, -33.0]:
		_create_wall_lamp(Vector3(-17.8, 2.8, lamp_z), Color("526ee0"))
		_create_wall_lamp(Vector3(17.8, 2.8, lamp_z - 3.0), Color("8c4fc6"))


func _build_bone_columns() -> void:
	for z_position: float in [19.0, 5.0, -9.0, -23.0]:
		_create_bone_column(Vector3(-13.0, 0.0, z_position))
		_create_bone_column(Vector3(13.0, 0.0, z_position - 2.0))


func _build_central_dais() -> void:
	_create_static_box("DaisBase", Vector3(0.0, 0.35, -32.0), Vector3(12.0, 0.7, 9.0), Color("161426"))
	_create_static_box("DaisStep", Vector3(0.0, 0.15, -27.7), Vector3(8.0, 0.3, 2.0), Color("211d35"))
	_create_glowing_box("DaisRune", Vector3(0.0, 0.73, -32.0), Vector3(7.0, 0.06, 5.0), Color("354d96"), 0.42)

	var title: Label3D = Label3D.new()
	title.text = "THEY ALL WROTE THE SAME ENDING"
	title.font_size = 45
	title.modulate = Color("aab9e8")
	title.outline_size = 8
	title.position = Vector3(0.0, 5.8, -38.3)
	add_child(title)


func _build_journals() -> void:
	var journal_ids: Array[String] = ["first", "second", "third"]
	var journal_positions: Array[Vector3] = [
		Vector3(-9.0, 0.0, 10.0),
		Vector3(8.5, 0.0, -5.0),
		Vector3(-7.5, 0.0, -21.0)
	]
	var journal_prompts: Array[String] = [
		"Read Journal I",
		"Read Journal II",
		"Read Journal III"
	]
	var journal_messages: Array[String] = [
		"DAY 12: She says I am different from the others. I believe her because I need to.",
		"DAY 38: The bridge showed me my own body. She said it was only a warning.",
		"FINAL ENTRY: When the song ended, she asked me to close my eyes. I heard the blade before I felt it."
	]

	for index: int in range(journal_ids.size()):
		var journal_position: Vector3 = journal_positions[index]
		_create_pedestal(journal_position)
		var interaction: Area3D = _create_interaction(
			"Journal_%s" % journal_ids[index],
			journal_position,
			Vector3(3.5, 3.0, 3.5),
			journal_prompts[index],
			journal_messages[index],
			true
		)
		interaction.connect("activated", Callable(self, "_on_journal_read").bind(journal_ids[index]))


func _build_woman() -> void:
	_woman_visual = Node3D.new()
	_woman_visual.name = "WomanAtDais"
	_woman_visual.position = Vector3(0.0, 0.7, -32.0)
	add_child(_woman_visual)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.50, 0.47, 0.66, 0.70)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color("5f5a89")
	material.emission_energy_multiplier = 1.0

	var dress: CylinderMesh = CylinderMesh.new()
	dress.top_radius = 0.24
	dress.bottom_radius = 0.58
	dress.height = 1.55
	_add_visual_mesh(_woman_visual, dress, Vector3(0.0, 0.78, 0.0), material)
	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 0.82
	_add_visual_mesh(_woman_visual, torso, Vector3(0.0, 1.62, 0.0), material)
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.24
	head.height = 0.46
	_add_visual_mesh(_woman_visual, head, Vector3(0.0, 2.22, 0.0), material)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.position = Vector3(0.0, 1.4, 0.0)
	glow.light_color = Color("736ca0")
	glow.light_energy = 1.2
	glow.omni_range = 6.0
	_woman_visual.add_child(glow)

	_woman_interaction = _create_interaction(
		"ConfrontWoman",
		Vector3(0.0, 0.7, -32.0),
		Vector3(5.0, 3.5, 5.0),
		"Confront the woman",
		"\"You were not supposed to read those,\" she says. For the first time, she sounds afraid.",
		true
	)
	_woman_interaction.monitoring = false
	_woman_interaction.connect("activated", Callable(self, "_on_woman_confronted"))


func _build_floating_skulls() -> void:
	for index: int in range(7):
		var root: Node3D = Node3D.new()
		var angle: float = TAU * float(index) / 7.0
		root.position = Vector3(cos(angle) * 7.0, 2.8, -32.0 + sin(angle) * 5.0)
		add_child(root)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.55, 0.65, 0.94, 0.42)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color("607bd2")
		material.emission_energy_multiplier = 0.62
		var skull: SphereMesh = SphereMesh.new()
		skull.radius = 0.24
		skull.height = 0.44
		_add_visual_mesh(root, skull, Vector3.ZERO, material)
		_floating_skulls.append(root)


func _spawn_player() -> void:
	var instance: Node = PLAYER_SCENE.instantiate()
	_player = instance as CharacterBody3D
	if _player == null:
		push_error("Player scene root must be CharacterBody3D.")
		return
	_player.position = Vector3(0.0, 0.1, 27.5)
	add_child(_player)
	_player.set_objective("Read the three journals hidden in the chamber.")
	_player.show_interaction_message("The music slows. Every skull turns toward the woman, not you.", 5.5)


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 25
	add_child(canvas)
	_journal_label = Label.new()
	_journal_label.anchor_left = 1.0
	_journal_label.anchor_right = 1.0
	_journal_label.offset_left = -360.0
	_journal_label.offset_right = -30.0
	_journal_label.offset_top = 126.0
	_journal_label.offset_bottom = 165.0
	_journal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_journal_label.text = "JOURNALS  0 / 3"
	_journal_label.add_theme_font_size_override("font_size", 17)
	_journal_label.add_theme_color_override("font_color", Color("aebeea"))
	canvas.add_child(_journal_label)


func _on_journal_read(player: Node, journal_id: String) -> void:
	if _read_journals.has(journal_id):
		return
	_read_journals[journal_id] = true
	_journals_read += 1
	_journal_label.text = "JOURNALS  %d / 3" % _journals_read
	SFXDirector.play_reveal()
	if _journals_read >= 3:
		_woman_interaction.monitoring = true
		if player.has_method("set_objective"):
			player.call("set_objective", "Confront the woman on the central dais.")
		if player.has_method("show_interaction_message"):
			player.call("show_interaction_message", "Every journal ends in the same handwriting: yours.", 5.0)
	else:
		if player.has_method("set_objective"):
			player.call("set_objective", "Journals read: %d / 3" % _journals_read)


func _on_woman_confronted(player: Node) -> void:
	if _chapter_finished:
		return
	_chapter_finished = true
	if player.has_method("set_objective"):
		player.call("set_objective", "THE CYCLE IS BREAKING")
	MusicDirector.stop_music(2.0)
	await get_tree().create_timer(1.6).timeout
	_show_chapter_end()


func _show_chapter_end() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 0.0)
	canvas.add_child(background)
	var fade: Tween = create_tween()
	fade.tween_property(background, "color", Color(0.0, 0.0, 0.0, 0.96), 1.5)
	await fade.finished

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)

	var heading: Label = Label.new()
	heading.text = "THE CYCLE HAS YOUR NAME"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	stack.add_child(heading)

	var body: Label = Label.new()
	body.text = "The journals prove this has happened before.\nShe led every version of you here—and every version died trusting her."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color("aeb5cc"))
	stack.add_child(body)

	var next_label: Label = Label.new()
	next_label.text = "NEXT CHAPTER: BETRAYAL"
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 17)
	next_label.add_theme_color_override("font_color", Color("db6f9f"))
	stack.add_child(next_label)

	var return_button: Button = Button.new()
	return_button.text = "RETURN TO TITLE"
	return_button.custom_minimum_size = Vector2(300.0, 50.0)
	return_button.pressed.connect(_return_to_title)
	stack.add_child(return_button)


func _return_to_title() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _create_bone_column(column_position: Vector3) -> void:
	_create_static_box("BoneColumnCore", column_position + Vector3(0.0, 2.5, 0.0), Vector3(0.7, 5.0, 0.7), Color("202737"))
	var bone_material: StandardMaterial3D = _make_material(Color("a9a89d"))
	for index: int in range(8):
		var bone: CapsuleMesh = CapsuleMesh.new()
		bone.radius = 0.07
		bone.height = 1.2
		var angle: float = TAU * float(index) / 8.0
		var bone_instance: MeshInstance3D = _add_visual_mesh(
			self,
			bone,
			column_position + Vector3(cos(angle) * 0.48, 0.75 + float(index % 4) * 1.15, sin(angle) * 0.48),
			bone_material
		)
		bone_instance.rotation_degrees = Vector3(0.0, rad_to_deg(angle), 18.0)


func _create_pedestal(pedestal_position: Vector3) -> void:
	_create_static_box("JournalPedestal", pedestal_position + Vector3(0.0, 0.65, 0.0), Vector3(1.4, 1.3, 1.4), Color("171c2b"))
	_create_glowing_box("JournalPage", pedestal_position + Vector3(0.0, 1.38, 0.0), Vector3(0.85, 0.06, 1.05), Color("8798c4"), 0.55)


func _create_wall_lamp(light_position: Vector3, color: Color) -> void:
	_create_glowing_box("WallLamp", light_position, Vector3(0.28, 0.70, 0.28), color, 1.7)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position
	light.light_color = color
	light.light_energy = 1.25
	light.omni_range = 7.0
	add_child(light)


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
	material.roughness = 0.82
	return material


func _add_visual_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance
