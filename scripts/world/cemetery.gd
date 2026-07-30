extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT := preload("res://scripts/world/interactable.gd")

var _player: CharacterBody3D
var _woman_visual: Node3D
var _woman_interaction: Area3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_cemetery()
	_build_memorial()
	_build_woman_reveal()
	_spawn_player()
	MusicDirector.play_cue("okay_intro", 2.0)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070a13")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("56617a")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("5d6577")
	environment.fog_density = 0.035
	world_environment.environment = environment
	add_child(world_environment)

	var moonlight := DirectionalLight3D.new()
	moonlight.name = "Moonlight"
	moonlight.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moonlight.light_color = Color("a8b8e8")
	moonlight.light_energy = 1.35
	moonlight.shadow_enabled = true
	add_child(moonlight)

	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 2.4
	moon_mesh.height = 4.8
	moon.mesh = moon_mesh
	moon.position = Vector3(-18.0, 24.0, -42.0)
	var moon_material := StandardMaterial3D.new()
	moon_material.albedo_color = Color("d8e1ff")
	moon_material.emission_enabled = true
	moon_material.emission = Color("aebfff")
	moon_material.emission_energy_multiplier = 3.0
	moon.material_override = moon_material
	add_child(moon)


func _build_ground() -> void:
	_create_static_box(
		"Ground",
		Vector3(0.0, -0.3, -4.0),
		Vector3(42.0, 0.6, 64.0),
		Color("111720")
	)

	_create_visual_box(
		"MainPath",
		Vector3(0.0, 0.015, -4.0),
		Vector3(4.2, 0.03, 57.0),
		Color("292c32")
	)

	for z_position in range(-27, 24, 4):
		_create_visual_box(
			"PathStone",
			Vector3(0.0, 0.04, float(z_position)),
			Vector3(3.4, 0.05, 2.2),
			Color("33343a")
		)


func _build_cemetery() -> void:
	var grave_index := 0
	for row in range(8):
		var z_position := 15.0 - float(row) * 5.5
		for side in [-1.0, 1.0]:
			for column in range(2):
				var x_position := side * (4.3 + float(column) * 3.4)
				_create_grave(Vector3(x_position, 0.0, z_position), grave_index)
				grave_index += 1

	for z_position in [-25.0, -15.0, -5.0, 5.0, 15.0, 23.0]:
		_create_tree(Vector3(-15.5, 0.0, z_position), 1.0 + abs(z_position) * 0.005)
		_create_tree(Vector3(15.5, 0.0, z_position + 1.8), 0.9 + abs(z_position) * 0.006)

	_create_static_box("FenceLeft", Vector3(-19.0, 1.0, -4.0), Vector3(0.35, 2.0, 62.0), Color("17181d"))
	_create_static_box("FenceRight", Vector3(19.0, 1.0, -4.0), Vector3(0.35, 2.0, 62.0), Color("17181d"))
	_create_static_box("FenceBackLeft", Vector3(-10.5, 1.0, -34.8), Vector3(17.0, 2.0, 0.35), Color("17181d"))
	_create_static_box("FenceBackRight", Vector3(10.5, 1.0, -34.8), Vector3(17.0, 2.0, 0.35), Color("17181d"))

	_create_static_box("GatePostLeft", Vector3(-2.7, 2.0, -29.5), Vector3(0.75, 4.0, 0.75), Color("22242b"))
	_create_static_box("GatePostRight", Vector3(2.7, 2.0, -29.5), Vector3(0.75, 4.0, 0.75), Color("22242b"))
	_create_static_box("GateTop", Vector3(0.0, 4.0, -29.5), Vector3(6.2, 0.55, 0.7), Color("22242b"))

	for lamp_z in [12.0, 2.0, -8.0, -18.0]:
		_create_lantern(Vector3(-2.5, 0.0, lamp_z))
		_create_lantern(Vector3(2.5, 0.0, lamp_z))


func _build_memorial() -> void:
	_create_static_box("MemorialBase", Vector3(0.0, 0.35, -20.0), Vector3(4.8, 0.7, 3.5), Color("24252b"))
	_create_static_box("MemorialStone", Vector3(0.0, 1.65, -20.5), Vector3(2.8, 2.6, 0.65), Color("3b3b41"))
	_create_visual_box("MemorialCap", Vector3(0.0, 3.08, -20.5), Vector3(3.2, 0.28, 0.85), Color("45464e"))

	var inscription := Label3D.new()
	inscription.text = "FOR THE ONES\nWHO RAN OUT OF TIME"
	inscription.font_size = 36
	inscription.modulate = Color("c7c4b8")
	inscription.outline_size = 4
	inscription.position = Vector3(0.0, 1.75, -20.12)
	inscription.rotation_degrees.y = 180.0
	add_child(inscription)

	var flower_stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.025
	stem_mesh.height = 0.75
	flower_stem.mesh = stem_mesh
	flower_stem.position = Vector3(0.0, 0.95, -18.9)
	var stem_material := StandardMaterial3D.new()
	stem_material.albedo_color = Color("33533d")
	flower_stem.material_override = stem_material
	add_child(flower_stem)

	var flower := MeshInstance3D.new()
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.16
	flower_mesh.height = 0.28
	flower.mesh = flower_mesh
	flower.position = Vector3(0.0, 1.35, -18.9)
	var flower_material := StandardMaterial3D.new()
	flower_material.albedo_color = Color("7d1830")
	flower_material.emission_enabled = true
	flower_material.emission = Color("5f1023")
	flower_material.emission_energy_multiplier = 1.8
	flower.material_override = flower_material
	add_child(flower)

	var memorial := Area3D.new()
	memorial.name = "MemorialInteraction"
	memorial.set_script(INTERACTABLE_SCRIPT)
	memorial.set("prompt_text", "Inspect the memorial")
	memorial.set("interaction_message", "A fresh red flower rests beneath names worn away by time.\nYou remember placing it here before — but that cannot be possible.")
	memorial.set("one_shot", true)

	var interaction_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(5.2, 3.0, 4.6)
	interaction_shape.shape = box_shape
	interaction_shape.position = Vector3(0.0, 1.4, 0.0)
	memorial.add_child(interaction_shape)
	memorial.position = Vector3(0.0, 0.0, -18.8)
	memorial.connect("activated", Callable(self, "_on_memorial_activated"))
	add_child(memorial)


func _build_woman_reveal() -> void:
	_woman_visual = Node3D.new()
	_woman_visual.name = "MysteriousWoman"
	_woman_visual.position = Vector3(0.0, 0.0, -32.0)
	_woman_visual.visible = false
	add_child(_woman_visual)

	var silhouette_material := StandardMaterial3D.new()
	silhouette_material.albedo_color = Color("a7a2bd")
	silhouette_material.emission_enabled = true
	silhouette_material.emission = Color("625d7c")
	silhouette_material.emission_energy_multiplier = 1.45

	var dress := CylinderMesh.new()
	dress.top_radius = 0.24
	dress.bottom_radius = 0.55
	dress.height = 1.45
	_add_visual_mesh(_woman_visual, dress, Vector3(0.0, 0.72, 0.0), silhouette_material)

	var torso := CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 0.82
	_add_visual_mesh(_woman_visual, torso, Vector3(0.0, 1.55, 0.0), silhouette_material)

	var head := SphereMesh.new()
	head.radius = 0.24
	head.height = 0.46
	_add_visual_mesh(_woman_visual, head, Vector3(0.0, 2.16, 0.0), silhouette_material)

	var reveal_light := OmniLight3D.new()
	reveal_light.light_color = Color("827aa8")
	reveal_light.light_energy = 2.0
	reveal_light.omni_range = 7.0
	reveal_light.position = Vector3(0.0, 1.2, 0.0)
	_woman_visual.add_child(reveal_light)

	_woman_interaction = Area3D.new()
	_woman_interaction.name = "WomanInteraction"
	_woman_interaction.set_script(INTERACTABLE_SCRIPT)
	_woman_interaction.set("prompt_text", "Speak to the woman")
	_woman_interaction.set("interaction_message", "\"You're late,\" she whispers.\n\"But maybe this time will be different.\"")
	_woman_interaction.set("one_shot", true)
	_woman_interaction.monitoring = false

	var woman_shape_node := CollisionShape3D.new()
	var woman_shape := CylinderShape3D.new()
	woman_shape.radius = 2.0
	woman_shape.height = 3.5
	woman_shape_node.shape = woman_shape
	woman_shape_node.position = Vector3(0.0, 1.5, 0.0)
	_woman_interaction.add_child(woman_shape_node)
	_woman_interaction.position = _woman_visual.position
	_woman_interaction.connect("activated", Callable(self, "_on_woman_activated"))
	add_child(_woman_interaction)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(0.0, 0.1, 21.0)
	add_child(_player)
	if _player.has_method("set_objective"):
		_player.set_objective("Find the memorial at the end of the path.")


func _on_memorial_activated(player: Node) -> void:
	_woman_visual.visible = true
	_woman_interaction.monitoring = true
	if player.has_method("set_objective"):
		player.set_objective("Approach the woman beyond the cemetery gate.")

	var tween := create_tween()
	_woman_visual.scale = Vector3(0.01, 0.01, 0.01)
	tween.tween_property(_woman_visual, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_SINE)


func _on_woman_activated(player: Node) -> void:
	if player.has_method("set_objective"):
		player.set_objective("PROLOGUE COMPLETE — She remembers you.")
	MusicDirector.play_cue("pontiac_memory", 2.5)


func _create_grave(grave_position: Vector3, index: int) -> void:
	var tilt := -4.0 + float(index % 5) * 2.0
	_create_static_box(
		"GraveBase%d" % index,
		grave_position + Vector3(0.0, 0.14, 0.0),
		Vector3(1.45, 0.28, 0.72),
		Color("292b31")
	)
	var stone := _create_static_box(
		"GraveStone%d" % index,
		grave_position + Vector3(0.0, 1.0, 0.18),
		Vector3(0.95, 1.55, 0.28),
		Color("3a3c42")
	)
	stone.rotation_degrees.z = tilt

	if index % 3 == 0:
		_create_visual_box(
			"CrossHorizontal%d" % index,
			grave_position + Vector3(0.0, 1.42, 0.0),
			Vector3(1.2, 0.16, 0.22),
			Color("44464c")
		)


func _create_tree(tree_position: Vector3, scale_factor: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.35 * scale_factor
	trunk_mesh.bottom_radius = 0.52 * scale_factor
	trunk_mesh.height = 5.5 * scale_factor
	trunk.mesh = trunk_mesh
	trunk.position = tree_position + Vector3(0.0, 2.75 * scale_factor, 0.0)
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("171517")
	trunk.material_override = trunk_material
	add_child(trunk)

	for branch_index in range(3):
		var branch := MeshInstance3D.new()
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.08
		branch_mesh.bottom_radius = 0.15
		branch_mesh.height = 3.1 * scale_factor
		branch.mesh = branch_mesh
		branch.position = tree_position + Vector3(0.0, (3.7 + branch_index * 0.55) * scale_factor, 0.0)
		branch.rotation_degrees = Vector3(0.0, branch_index * 115.0, 58.0 - branch_index * 8.0)
		branch.material_override = trunk_material
		add_child(branch)


func _create_lantern(lantern_position: Vector3) -> void:
	_create_visual_box("LanternPost", lantern_position + Vector3(0.0, 1.2, 0.0), Vector3(0.14, 2.4, 0.14), Color("202126"))
	var light := OmniLight3D.new()
	light.position = lantern_position + Vector3(0.0, 2.35, 0.0)
	light.light_color = Color("d5b27a")
	light.light_energy = 1.3
	light.omni_range = 5.0
	add_child(light)

	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.12
	bulb_mesh.height = 0.22
	bulb.mesh = bulb_mesh
	bulb.position = light.position
	var bulb_material := StandardMaterial3D.new()
	bulb_material.albedo_color = Color("e8c994")
	bulb_material.emission_enabled = true
	bulb_material.emission = Color("d5a95f")
	bulb_material.emission_energy_multiplier = 2.5
	bulb.material_override = bulb_material
	add_child(bulb)


func _create_static_box(box_name: String, box_position: Vector3, box_size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = box_position

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)

	add_child(body)
	return body


func _create_visual_box(box_name: String, box_position: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _add_visual_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance
