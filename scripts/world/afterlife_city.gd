extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/world/interactable.gd")

var _player: CharacterBody3D
var _woman_visual: Node3D
var _woman_target_z: float = 18.0
var _woman_is_moving: bool = false
var _club_interaction: Area3D
var _clues_found: int = 0
var _found_clues: Dictionary = {}
var _chapter_complete: bool = false


func _ready() -> void:
	MusicDirector.stop_music(2.0)
	SFXDirector.start_city_ambience()
	_build_environment()
	_build_ground()
	_build_city_blocks()
	_build_street_details()
	_build_woman()
	_build_story_interactions()
	_spawn_player()


func _exit_tree() -> void:
	SFXDirector.stop_environment(0.5)


func _process(delta: float) -> void:
	if not _woman_is_moving or _woman_visual == null:
		return
	_woman_visual.position.z = move_toward(_woman_visual.position.z, _woman_target_z, 2.4 * delta)
	var stride: float = sin(Time.get_ticks_msec() * 0.009) * 0.035
	_woman_visual.position.y = stride
	if is_equal_approx(_woman_visual.position.z, _woman_target_z):
		_woman_is_moving = false
		_woman_visual.position.y = 0.0


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("03040b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("34405f")
	environment.ambient_light_energy = 0.68
	environment.fog_enabled = true
	environment.fog_light_color = Color("202a46")
	environment.fog_density = 0.025
	world_environment.environment = environment
	add_child(world_environment)

	var moonlight: DirectionalLight3D = DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-58.0, 24.0, 0.0)
	moonlight.light_color = Color("899ee4")
	moonlight.light_energy = 1.15
	moonlight.shadow_enabled = true
	add_child(moonlight)


func _build_ground() -> void:
	_create_static_box("CityGround", Vector3(0.0, -0.35, -8.0), Vector3(58.0, 0.7, 112.0), Color("090c14"))
	_create_visual_box("Road", Vector3(0.0, 0.015, -8.0), Vector3(10.0, 0.04, 104.0), Color("161a24"))
	_create_visual_box("LeftSidewalk", Vector3(-7.0, 0.10, -8.0), Vector3(4.0, 0.20, 104.0), Color("262a33"))
	_create_visual_box("RightSidewalk", Vector3(7.0, 0.10, -8.0), Vector3(4.0, 0.20, 104.0), Color("262a33"))

	for z_value: int in range(-54, 44, 7):
		_create_visual_box("RoadMarker", Vector3(0.0, 0.05, float(z_value)), Vector3(0.16, 0.04, 3.3), Color("b7ad85"))

	_create_static_box("FarWall", Vector3(0.0, 3.0, -59.0), Vector3(58.0, 6.0, 1.0), Color("080a11"))


func _build_city_blocks() -> void:
	var building_z_values: Array[float] = [34.0, 21.0, 8.0, -5.0, -18.0, -31.0, -44.0]
	for index: int in range(building_z_values.size()):
		var z_position: float = building_z_values[index]
		var left_height: float = 7.0 + float((index * 3) % 6)
		var right_height: float = 8.0 + float((index * 5) % 7)
		_create_building(Vector3(-14.0, left_height * 0.5, z_position), Vector3(10.0, left_height, 10.0), index, false)
		_create_building(Vector3(14.0, right_height * 0.5, z_position - 2.0), Vector3(10.0, right_height, 10.0), index, true)

	_create_nightclub()


func _create_building(building_position: Vector3, building_size: Vector3, index: int, right_side: bool) -> void:
	var color: Color = Color("111624") if index % 2 == 0 else Color("171525")
	_create_static_box("Building%d" % index, building_position, building_size, color)

	var window_color: Color = Color("4c5f91") if index % 3 != 0 else Color("59234f")
	var frontage_x: float = building_position.x + (-building_size.x * 0.51 if right_side else building_size.x * 0.51)
	for floor_index: int in range(maxi(2, int(building_size.y / 2.2))):
		for window_index: int in range(2):
			var z_offset: float = -2.4 + float(window_index) * 4.8
			var window_position: Vector3 = Vector3(frontage_x, 1.5 + float(floor_index) * 2.0, building_position.z + z_offset)
			var window_size: Vector3 = Vector3(0.08, 0.72, 1.4)
			_create_glowing_box("Window", window_position, window_size, window_color, 0.75 if (floor_index + index) % 3 == 0 else 0.12)

	if index % 2 == 1:
		var sign_position: Vector3 = Vector3(frontage_x, 2.9, building_position.z)
		var sign_color: Color = Color("b42cff") if right_side else Color("e22d68")
		_create_glowing_box("BrokenSign", sign_position, Vector3(0.12, 1.0, 4.2), sign_color, 2.2)


func _build_street_details() -> void:
	var lamp_z_values: Array[float] = [30.0, 16.0, 2.0, -12.0, -26.0, -40.0]
	for lamp_z: float in lamp_z_values:
		_create_streetlight(Vector3(-4.8, 0.0, lamp_z), Color("6b79bb"))
		_create_streetlight(Vector3(4.8, 0.0, lamp_z - 3.5), Color("8d477e"))

	_create_static_box("AbandonedCarBody", Vector3(2.8, 0.65, -15.0), Vector3(2.1, 1.1, 4.3), Color("271018"))
	_create_visual_box("AbandonedCarCabin", Vector3(2.8, 1.35, -15.2), Vector3(1.7, 0.7, 2.0), Color("151d2b"))
	_create_static_box("BusStopBench", Vector3(-7.1, 0.48, -25.0), Vector3(3.2, 0.25, 0.65), Color("252936"))
	_create_visual_box("BusStopBack", Vector3(-8.5, 1.8, -25.0), Vector3(0.20, 3.2, 4.8), Color("172033"))


func _build_woman() -> void:
	_woman_visual = Node3D.new()
	_woman_visual.name = "MysteriousWoman"
	_woman_visual.position = Vector3(0.8, 0.0, 22.0)
	add_child(_woman_visual)

	var silhouette_material: StandardMaterial3D = StandardMaterial3D.new()
	silhouette_material.albedo_color = Color("9d9ab1")
	silhouette_material.emission_enabled = true
	silhouette_material.emission = Color("544e70")
	silhouette_material.emission_energy_multiplier = 1.2

	var dress: CylinderMesh = CylinderMesh.new()
	dress.top_radius = 0.24
	dress.bottom_radius = 0.55
	dress.height = 1.45
	_add_visual_mesh(_woman_visual, dress, Vector3(0.0, 0.72, 0.0), silhouette_material)

	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 0.82
	_add_visual_mesh(_woman_visual, torso, Vector3(0.0, 1.55, 0.0), silhouette_material)

	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.24
	head.height = 0.46
	_add_visual_mesh(_woman_visual, head, Vector3(0.0, 2.16, 0.0), silhouette_material)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.position = Vector3(0.0, 1.3, 0.0)
	glow.light_color = Color("766e9e")
	glow.light_energy = 1.25
	glow.omni_range = 5.0
	_woman_visual.add_child(glow)


func _build_story_interactions() -> void:
	var woman_interaction: Area3D = _create_interaction(
		"CityWomanInteraction",
		Vector3(0.8, 0.0, 22.0),
		Vector3(4.0, 3.5, 4.0),
		"Ask where everyone went",
		"\"They are still here,\" she says. \"The city just learned how to hide them.\"",
		true
	)
	woman_interaction.connect("activated", Callable(self, "_on_woman_activated"))

	var payphone: Area3D = _create_interaction(
		"PayphoneClue",
		Vector3(-6.6, 0.0, 3.5),
		Vector3(3.0, 3.0, 3.0),
		"Answer the ringing payphone",
		"There is no caller. Your own voice whispers: \"Don't follow her into the music.\"",
		true
	)
	payphone.connect("activated", Callable(self, "_on_clue_activated").bind("payphone"))
	_create_payphone(Vector3(-7.4, 1.25, 3.5))

	var reflection: Area3D = _create_interaction(
		"ReflectionClue",
		Vector3(6.7, 0.0, -9.0),
		Vector3(3.0, 3.0, 4.0),
		"Look into the dark storefront",
		"The glass reflects dozens of skeletons standing where you stand. Only one of them moves.",
		true
	)
	reflection.connect("activated", Callable(self, "_on_clue_activated").bind("reflection"))
	_create_glowing_box("StorefrontGlass", Vector3(8.9, 1.8, -9.0), Vector3(0.12, 3.2, 5.4), Color("17243d"), 0.45)

	var newspaper: Area3D = _create_interaction(
		"NewspaperClue",
		Vector3(-6.8, 0.0, -24.5),
		Vector3(3.5, 2.5, 4.0),
		"Read the abandoned newspaper",
		"Every photograph shows the same red Pontiac. Every date is different. Every driver is you.",
		true
	)
	newspaper.connect("activated", Callable(self, "_on_clue_activated").bind("newspaper"))
	_create_visual_box("Newspaper", Vector3(-6.8, 0.28, -24.5), Vector3(0.75, 0.04, 1.0), Color("bbb5a5"))

	_club_interaction = _create_interaction(
		"NightclubEntrance",
		Vector3(0.0, 0.0, -48.0),
		Vector3(7.0, 4.5, 5.0),
		"Enter the ruined nightclub",
		"Bass pulses through the chained doors. She is already waiting on the other side.",
		true
	)
	_club_interaction.monitoring = false
	_club_interaction.connect("activated", Callable(self, "_on_club_activated"))


func _spawn_player() -> void:
	var instance: Node = PLAYER_SCENE.instantiate()
	_player = instance as CharacterBody3D
	if _player == null:
		push_error("Player scene root must be CharacterBody3D.")
		return
	_player.position = Vector3(0.0, 0.1, 31.0)
	add_child(_player)
	_player.set_objective("Find the woman waiting in the street.")


func _on_woman_activated(player: Node) -> void:
	_woman_target_z = -34.0
	_woman_is_moving = true
	if player.has_method("set_objective"):
		player.call("set_objective", "Search the empty street for three memory clues.")


func _on_clue_activated(player: Node, clue_id: String) -> void:
	if _found_clues.has(clue_id):
		return
	_found_clues[clue_id] = true
	_clues_found += 1

	if _clues_found >= 3:
		_club_interaction.monitoring = true
		SFXDirector.play_reveal()
		if player.has_method("set_objective"):
			player.call("set_objective", "Reach the nightclub at the end of the street.")
		return

	if player.has_method("set_objective"):
		player.call("set_objective", "Memory clues found: %d / 3" % _clues_found)


func _on_club_activated(player: Node) -> void:
	if _chapter_complete:
		return
	_chapter_complete = true
	if player.has_method("set_objective"):
		player.call("set_objective", "CITY ARRIVAL COMPLETE — Next: survive the ruined club.")
	SFXDirector.play_reveal()


func _create_nightclub() -> void:
	_create_static_box("Nightclub", Vector3(0.0, 5.0, -54.0), Vector3(18.0, 10.0, 10.0), Color("120c19"))
	_create_static_box("ClubDoorLeft", Vector3(-2.0, 2.0, -48.85), Vector3(3.6, 4.0, 0.5), Color("291021"))
	_create_static_box("ClubDoorRight", Vector3(2.0, 2.0, -48.85), Vector3(3.6, 4.0, 0.5), Color("291021"))
	_create_glowing_box("ClubSign", Vector3(0.0, 6.7, -48.72), Vector3(9.0, 1.2, 0.18), Color("ce276a"), 3.0)

	var club_label: Label3D = Label3D.new()
	club_label.text = "OUT OF TIME"
	club_label.font_size = 70
	club_label.modulate = Color("f0c0d3")
	club_label.outline_size = 8
	club_label.position = Vector3(0.0, 6.65, -48.52)
	add_child(club_label)


func _create_payphone(phone_position: Vector3) -> void:
	_create_visual_box("PayphoneStand", phone_position, Vector3(0.8, 2.4, 0.8), Color("202936"))
	_create_glowing_box("PayphoneScreen", phone_position + Vector3(0.0, 0.35, -0.43), Vector3(0.42, 0.36, 0.06), Color("4bde9a"), 1.7)


func _create_streetlight(light_position: Vector3, light_color: Color) -> void:
	_create_visual_box("StreetlightPost", light_position + Vector3(0.0, 2.0, 0.0), Vector3(0.16, 4.0, 0.16), Color("151a24"))
	_create_glowing_box("StreetlightLamp", light_position + Vector3(0.0, 4.0, 0.0), Vector3(0.7, 0.22, 0.45), light_color, 1.7)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position + Vector3(0.0, 3.8, 0.0)
	light.light_color = light_color
	light.light_energy = 1.35
	light.omni_range = 7.5
	add_child(light)


func _create_interaction(
	node_name: String,
	interaction_position: Vector3,
	shape_size: Vector3,
	prompt: String,
	message: String,
	one_shot: bool
) -> Area3D:
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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	var instance: MeshInstance3D = _add_visual_mesh(self, mesh, box_position, material)
	instance.name = node_name
	return instance


func _create_glowing_box(node_name: String, box_position: Vector3, box_size: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = energy > 0.0
	material.emission = color
	material.emission_energy_multiplier = energy
	var instance: MeshInstance3D = _add_visual_mesh(self, mesh, box_position, material)
	instance.name = node_name
	return instance


func _add_visual_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance