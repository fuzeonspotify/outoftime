extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/world/interactable.gd")

const VOID_FALL_LIMIT: float = -38.0
const VOID_RISE_LIMIT: float = 42.0
const VOID_SIDE_LIMIT: float = 58.0
const PORTAL_POSITION: Vector3 = Vector3(0.0, 1.0, -118.0)

var _player: CharacterBody3D
var _portal_interaction: Area3D
var _portal_root: Node3D
var _void_core: MeshInstance3D
var _anchors_stabilized: int = 0
var _stabilized_anchor_ids: Dictionary = {}
var _anchor_visuals: Dictionary = {}
var _floating_bodies: Array[StaticBody3D] = []
var _rotating_nodes: Array[Node3D] = []
var _stars: Array[MeshInstance3D] = []
var _gravity_wells: Array[Node3D] = []
var _gravity_state: StringName = &""
var _checkpoint_position: Vector3 = Vector3(0.0, 0.2, 54.0)
var _elapsed_time: float = 0.0
var _default_gravity: float = 9.8
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 6111998
	_default_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	MusicDirector.stop_music(0.35)
	SFXDirector.start_city_ambience()
	_build_environment()
	_build_starfield()
	_build_void_core()
	_build_floating_route()
	_build_distant_megastructures()
	_build_gravity_fields()
	_build_gravity_anchors()
	_build_nightclub_portal()
	_spawn_player()


func _exit_tree() -> void:
	MusicDirector.stop_music(0.2)
	SFXDirector.stop_environment(0.6)


func _process(delta: float) -> void:
	_elapsed_time += delta
	_animate_starfield(delta)
	_animate_floating_geometry()
	_animate_rotating_nodes(delta)
	_animate_void_core()
	_animate_portal()


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	_update_checkpoint()
	_apply_gravity_profile(delta)
	_apply_void_wells(delta)

	if (
		_player.position.y < VOID_FALL_LIMIT
		or _player.position.y > VOID_RISE_LIMIT
		or absf(_player.position.x) > VOID_SIDE_LIMIT
	):
		_recover_player()


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "VoidEnvironment"

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("010007")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("352454")
	environment.ambient_light_energy = 0.76
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.fog_enabled = true
	environment.fog_light_color = Color("25123e")
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.18
	environment.glow_enabled = true
	environment.glow_bloom = 0.22
	environment.glow_intensity = 1.12
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var violet_light: DirectionalLight3D = DirectionalLight3D.new()
	violet_light.name = "VioletVoidLight"
	violet_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	violet_light.light_color = Color("8b72e8")
	violet_light.light_energy = 1.08
	violet_light.shadow_enabled = true
	add_child(violet_light)

	var magenta_light: DirectionalLight3D = DirectionalLight3D.new()
	magenta_light.name = "MagentaVoidFill"
	magenta_light.rotation_degrees = Vector3(18.0, 148.0, 0.0)
	magenta_light.light_color = Color("d73f9d")
	magenta_light.light_energy = 0.38
	add_child(magenta_light)


func _build_starfield() -> void:
	var star_material: StandardMaterial3D = StandardMaterial3D.new()
	star_material.albedo_color = Color("b9c8ff")
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.emission_enabled = true
	star_material.emission = Color("819dff")
	star_material.emission_energy_multiplier = 1.8

	var pink_star_material: StandardMaterial3D = star_material.duplicate() as StandardMaterial3D
	if pink_star_material != null:
		pink_star_material.albedo_color = Color("ffc0e5")
		pink_star_material.emission = Color("e752b2")
		pink_star_material.emission_energy_multiplier = 1.55

	for index: int in range(190):
		var star_mesh: SphereMesh = SphereMesh.new()
		var radius: float = _rng.randf_range(0.025, 0.12)
		star_mesh.radius = radius
		star_mesh.height = radius * 2.0

		var star: MeshInstance3D = MeshInstance3D.new()
		star.name = "VoidStar%d" % index
		star.mesh = star_mesh
		star.position = Vector3(
			_rng.randf_range(-105.0, 105.0),
			_rng.randf_range(-42.0, 62.0),
			_rng.randf_range(-240.0, 105.0)
		)
		star.material_override = pink_star_material if index % 7 == 0 else star_material
		star.set_meta("drift_speed", _rng.randf_range(1.0, 5.2))
		add_child(star)
		_stars.append(star)

	for streak_index: int in range(38):
		var streak_mesh: BoxMesh = BoxMesh.new()
		streak_mesh.size = Vector3(0.03, 0.03, _rng.randf_range(1.2, 5.2))
		var streak: MeshInstance3D = MeshInstance3D.new()
		streak.name = "StarStreak%d" % streak_index
		streak.mesh = streak_mesh
		streak.position = Vector3(
			_rng.randf_range(-72.0, 72.0),
			_rng.randf_range(-22.0, 38.0),
			_rng.randf_range(-220.0, 80.0)
		)
		streak.material_override = pink_star_material if streak_index % 3 == 0 else star_material
		streak.set_meta("drift_speed", _rng.randf_range(8.0, 17.0))
		add_child(streak)
		_stars.append(streak)


func _build_void_core() -> void:
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 18.0
	core_mesh.height = 36.0

	var core_material: StandardMaterial3D = StandardMaterial3D.new()
	core_material.albedo_color = Color(0.05, 0.005, 0.09, 0.66)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.emission_enabled = true
	core_material.emission = Color("5a1684")
	core_material.emission_energy_multiplier = 1.28

	_void_core = _add_visual_mesh(
		self,
		core_mesh,
		Vector3(0.0, -48.0, -38.0),
		core_material,
		Vector3(1.0, 0.68, 1.0)
	)
	_void_core.name = "VoidCore"

	for ring_index: int in range(6):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 20.0 + float(ring_index) * 2.9
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.18
		var ring_material: StandardMaterial3D = _make_emissive_material(
			Color("8a32c4") if ring_index % 2 == 0 else Color("cf3e9b"),
			1.30,
			0.46
		)
		var ring: MeshInstance3D = _add_visual_mesh(
			self,
			ring_mesh,
			Vector3(0.0, -48.0, -38.0),
			ring_material
		)
		ring.name = "VoidCoreRing%d" % ring_index
		ring.rotation_degrees = Vector3(
			18.0 + float(ring_index) * 13.0,
			float(ring_index) * 37.0,
			9.0 + float(ring_index) * 11.0
		)
		ring.set_meta("rotation_speed", 4.0 + float(ring_index) * 2.4)
		_rotating_nodes.append(ring)


func _build_floating_route() -> void:
	_create_floating_island("ArrivalIsland", Vector3(0.0, -1.0, 55.0), 11.0, 3.0, Color("20172c"), 0.10, 0.0)
	_create_floating_island("LowGravityIsland", Vector3(0.0, 0.4, 38.0), 6.4, 2.2, Color("292040"), 0.16, 1.2)
	_create_floating_island("LowGravityStepA", Vector3(-4.8, 2.1, 28.0), 3.2, 1.3, Color("30244b"), 0.22, 2.4)
	_create_floating_island("LowGravityStepB", Vector3(5.0, 3.8, 18.0), 3.1, 1.2, Color("352550"), 0.25, 3.6)
	_create_floating_island("LowGravityStepC", Vector3(-4.0, 5.2, 9.0), 3.0, 1.1, Color("3a2858"), 0.27, 4.2)
	_create_floating_island("InversionLaunch", Vector3(0.0, 6.0, 1.0), 5.2, 1.8, Color("3b2859"), 0.12, 4.8)

	_create_static_box("InversionCeiling", Vector3(0.0, 15.0, -19.0), Vector3(18.0, 1.2, 42.0), Color("281b3d"))
	_create_static_box("InversionCeilingLeftRib", Vector3(-9.5, 13.2, -19.0), Vector3(1.0, 4.2, 42.0), Color("392550"))
	_create_static_box("InversionCeilingRightRib", Vector3(9.5, 13.2, -19.0), Vector3(1.0, 4.2, 42.0), Color("392550"))

	for ceiling_index: int in range(9):
		_create_visual_shard(
			Vector3(
				-7.0 + float(ceiling_index % 5) * 3.5,
				15.9,
				-36.0 + float(ceiling_index) * 4.1
			),
			Vector3(0.8, 2.2, 0.8),
			Color("604087")
		)

	_create_floating_island("DriftLanding", Vector3(0.0, 0.4, -44.0), 7.4, 2.4, Color("241a36"), 0.14, 5.3)
	_create_floating_island("DriftStepA", Vector3(-7.0, 4.2, -57.0), 3.2, 1.2, Color("2f2046"), 0.31, 6.1)
	_create_floating_island("DriftStepB", Vector3(6.4, 7.0, -69.0), 3.1, 1.1, Color("38234e"), 0.34, 7.0)
	_create_floating_island("DriftStepC", Vector3(-5.0, 9.0, -81.0), 3.2, 1.1, Color("432656"), 0.36, 7.8)
	_create_floating_island("GravityReturnIsland", Vector3(0.0, 0.2, -94.0), 7.6, 2.4, Color("251a38"), 0.12, 8.5)
	_create_floating_island("PortalApproachA", Vector3(-4.6, 0.5, -103.0), 3.1, 1.2, Color("2d1d40"), 0.18, 9.1)
	_create_floating_island("PortalApproachB", Vector3(4.3, 0.1, -111.0), 3.0, 1.2, Color("352047"), 0.20, 9.8)
	_create_floating_island("PortalIsland", Vector3(0.0, -1.0, -118.0), 12.0, 3.0, Color("1d152b"), 0.08, 10.4)

	var scenery_islands: Array[Vector3] = [
		Vector3(-22.0, -6.0, 44.0), Vector3(25.0, 8.0, 30.0),
		Vector3(-30.0, 12.0, 8.0), Vector3(31.0, -8.0, -12.0),
		Vector3(-27.0, 4.0, -38.0), Vector3(34.0, 14.0, -58.0),
		Vector3(-34.0, -10.0, -82.0), Vector3(27.0, 5.0, -101.0),
		Vector3(-24.0, 16.0, -128.0), Vector3(32.0, -7.0, -143.0)
	]
	for scenery_index: int in range(scenery_islands.size()):
		_create_floating_island(
			"SceneryIsland%d" % scenery_index,
			scenery_islands[scenery_index],
			_rng.randf_range(4.0, 9.0),
			_rng.randf_range(1.8, 4.5),
			Color("261934") if scenery_index % 2 == 0 else Color("33203f"),
			_rng.randf_range(0.12, 0.42),
			float(scenery_index) * 0.8
		)

	for shard_index: int in range(72):
		var side: float = -1.0 if shard_index % 2 == 0 else 1.0
		_create_visual_shard(
			Vector3(
				side * _rng.randf_range(10.0, 48.0),
				_rng.randf_range(-24.0, 28.0),
				_rng.randf_range(-165.0, 74.0)
			),
			Vector3(
				_rng.randf_range(0.5, 3.6),
				_rng.randf_range(1.0, 8.5),
				_rng.randf_range(0.5, 3.6)
			),
			Color("352344") if shard_index % 3 != 0 else Color("54255b")
		)


func _build_distant_megastructures() -> void:
	for index: int in range(8):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var root: Node3D = Node3D.new()
		root.name = "DistantVoidStructure%d" % index
		root.position = Vector3(
			side * (44.0 + float(index % 3) * 16.0),
			-8.0 + float(index % 4) * 9.0,
			42.0 - float(index) * 29.0
		)
		root.rotation_degrees = Vector3(
			_rng.randf_range(-20.0, 20.0),
			_rng.randf_range(0.0, 180.0),
			_rng.randf_range(-18.0, 18.0)
		)
		root.set_meta("rotation_speed", _rng.randf_range(-1.8, 1.8))
		add_child(root)
		_rotating_nodes.append(root)

		var tower_material: StandardMaterial3D = _make_rock_material(Color("171022"))
		for column_index: int in range(3):
			var column_mesh: BoxMesh = BoxMesh.new()
			column_mesh.size = Vector3(3.0, 22.0 + float(column_index) * 7.0, 3.0)
			_add_visual_mesh(
				root,
				column_mesh,
				Vector3(float(column_index - 1) * 6.0, float(column_index) * 3.0, 0.0),
				tower_material
			)

		var arch_mesh: TorusMesh = TorusMesh.new()
		arch_mesh.inner_radius = 8.0
		arch_mesh.outer_radius = 8.5
		var arch: MeshInstance3D = _add_visual_mesh(
			root,
			arch_mesh,
			Vector3(0.0, 7.0, 0.0),
			_make_emissive_material(Color("63378f"), 0.55, 0.42)
		)
		arch.rotation_degrees.x = 90.0


func _build_gravity_fields() -> void:
	_create_gravity_gate("LowGravityGate", Vector3(0.0, 4.0, 40.0), Color("5c7fff"), 6.0, 9.0)
	_create_gravity_gate("InversionGate", Vector3(0.0, 8.0, 3.0), Color("ff4cac"), 6.3, -12.0)
	_create_gravity_gate("ZeroGravityGate", Vector3(0.0, 5.5, -42.0), Color("9e63ff"), 6.8, 7.0)
	_create_gravity_gate("GravityReturnGate", Vector3(0.0, 4.0, -88.0), Color("66d2ff"), 6.2, -9.0)

	_create_gravity_well(Vector3(-10.0, 6.0, -58.0), Color("8f45ff"), 0.0)
	_create_gravity_well(Vector3(9.0, 8.5, -74.0), Color("ff4ca3"), 1.7)


func _build_gravity_anchors() -> void:
	_create_gravity_anchor(
		"low",
		Vector3(0.0, 2.6, 38.0),
		"Stabilize the low-gravity anchor",
		"The anchor releases its hold. Your bones feel almost weightless.",
		Color("6687ff")
	)
	_create_gravity_anchor(
		"inverted",
		Vector3(0.0, 14.15, -22.0),
		"Stabilize the inverted anchor",
		"Up and down trade places. The void does not notice the difference.",
		Color("ff4cae")
	)
	_create_gravity_anchor(
		"drift",
		Vector3(-5.0, 10.2, -81.0),
		"Stabilize the drifting anchor",
		"The current slows. Far ahead, a doorway burns through the dark.",
		Color("a266ff")
	)


func _build_nightclub_portal() -> void:
	_portal_root = Node3D.new()
	_portal_root.name = "NightclubVoidPortal"
	_portal_root.position = PORTAL_POSITION
	add_child(_portal_root)

	for ring_index: int in range(3):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 2.5 + float(ring_index) * 0.7
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.22
		var ring_material: StandardMaterial3D = _make_emissive_material(
			Color("7d356f").lightened(float(ring_index) * 0.08),
			0.45,
			0.76
		)
		var ring: MeshInstance3D = _add_visual_mesh(
			_portal_root,
			ring_mesh,
			Vector3(0.0, 2.8, 0.0),
			ring_material
		)
		ring.rotation_degrees = Vector3(90.0, float(ring_index) * 17.0, float(ring_index) * 9.0)
		ring.name = "PortalRing%d" % ring_index
		ring.set_meta("rotation_speed", 22.0 + float(ring_index) * 7.0)
		_rotating_nodes.append(ring)

	var portal_mesh: SphereMesh = SphereMesh.new()
	portal_mesh.radius = 2.25
	portal_mesh.height = 4.5
	var portal_material: StandardMaterial3D = _make_emissive_material(Color("38112f"), 0.25, 0.64)
	portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var portal_surface: MeshInstance3D = _add_visual_mesh(
		_portal_root,
		portal_mesh,
		Vector3(0.0, 2.8, 0.0),
		portal_material,
		Vector3(1.0, 1.2, 0.14)
	)
	portal_surface.name = "PortalSurface"

	var portal_label: Label3D = Label3D.new()
	portal_label.name = "PortalLabel"
	portal_label.text = "THE DOORWAY REMEMBERS YOU"
	portal_label.font_size = 52
	portal_label.modulate = Color("8c6b87")
	portal_label.outline_size = 8
	portal_label.position = Vector3(0.0, 6.7, 0.0)
	_portal_root.add_child(portal_label)

	_portal_interaction = _create_interaction(
		"NightclubEntrance",
		PORTAL_POSITION,
		Vector3(7.0, 7.0, 7.0),
		"Step through the void",
		"The doorway opens onto broken glass, cold static, and a room that remembers your name.",
		true
	)
	_portal_interaction.monitoring = false
	_portal_interaction.connect("activated", Callable(self, "_on_portal_activated"))


func _spawn_player() -> void:
	var instance: Node = PLAYER_SCENE.instantiate()
	_player = instance as CharacterBody3D
	if _player == null:
		push_error("Player scene root must be CharacterBody3D.")
		return
	_player.position = _checkpoint_position
	add_child(_player)
	_player.set_objective("Cross the expanded void and stabilize the three gravity anchors.")
	_player.show_interaction_message(
		"The city is gone. Its gravity has spread across a much larger emptiness.",
		5.5
	)


func _apply_gravity_profile(delta: float) -> void:
	var player_z: float = _player.position.z
	var gravity_multiplier: float = 1.0
	var vertical_damping: float = 0.0
	var state: StringName = &"normal"

	if player_z <= 40.0 and player_z > 3.0:
		gravity_multiplier = 0.22
		vertical_damping = 0.13
		state = &"low"
	elif player_z <= 3.0 and player_z > -42.0:
		gravity_multiplier = -0.62
		vertical_damping = 0.16
		state = &"inverted"
	elif player_z <= -42.0 and player_z > -88.0:
		gravity_multiplier = 0.04
		vertical_damping = 1.05
		state = &"drift"

	_player.velocity.y += _default_gravity * (1.0 - gravity_multiplier) * delta
	if vertical_damping > 0.0:
		_player.velocity.y = move_toward(_player.velocity.y, 0.0, vertical_damping * delta)

	if state == &"drift":
		_player.velocity.z -= 0.34 * delta

	if state != _gravity_state:
		_gravity_state = state
		_announce_gravity_state(state)


func _apply_void_wells(delta: float) -> void:
	if _gravity_state != &"drift":
		return

	for well: Node3D in _gravity_wells:
		var offset: Vector3 = well.global_position - _player.global_position
		var distance: float = offset.length()
		if distance <= 0.01 or distance > 16.0:
			continue
		var pull_strength: float = (1.0 - distance / 16.0) * 4.1
		_player.velocity += offset.normalized() * pull_strength * delta


func _announce_gravity_state(state: StringName) -> void:
	if _player == null:
		return

	match state:
		&"low":
			_player.show_interaction_message("GRAVITY: 22% — the wider gaps are reachable now.", 3.2)
		&"inverted":
			_player.show_interaction_message("GRAVITY INVERTED — the ceiling path is pulling you upward.", 3.8)
		&"drift":
			_player.show_interaction_message("GRAVITY: NEAR ZERO — follow the currents between the distant islands.", 3.5)
		_:
			_player.show_interaction_message("GRAVITY RESTORED.", 2.2)


func _update_checkpoint() -> void:
	var player_z: float = _player.position.z
	if player_z < -112.0:
		_checkpoint_position = Vector3(4.3, 0.5, -111.0)
	elif player_z < -96.0:
		_checkpoint_position = Vector3(0.0, 0.4, -94.0)
	elif player_z < -70.0:
		_checkpoint_position = Vector3(6.4, 7.7, -69.0)
	elif player_z < -46.0:
		_checkpoint_position = Vector3(0.0, 1.5, -44.0)
	elif player_z < -3.0:
		_checkpoint_position = Vector3(0.0, 13.6, -6.0)
	elif player_z < 36.0:
		_checkpoint_position = Vector3(0.0, 1.7, 38.0)


func _recover_player() -> void:
	_player.position = _checkpoint_position
	_player.velocity = Vector3.ZERO
	_player.show_interaction_message("The void folds you back to the last stable island.", 3.0)


func _on_anchor_activated(player: Node, anchor_id: String) -> void:
	if _stabilized_anchor_ids.has(anchor_id):
		return

	_stabilized_anchor_ids[anchor_id] = true
	_anchors_stabilized += 1
	SFXDirector.play_reveal()

	var anchor_variant: Variant = _anchor_visuals.get(anchor_id)
	var anchor_root: Node3D = anchor_variant as Node3D
	if anchor_root != null:
		anchor_root.set_meta("stabilized", true)

	if _anchors_stabilized >= 3:
		_portal_interaction.monitoring = true
		_activate_portal_visuals()
		if player.has_method("set_objective"):
			player.call("set_objective", "Reach the doorway burning at the far edge of the void.")
		return

	if player.has_method("set_objective"):
		player.call("set_objective", "Gravity anchors stabilized: %d / 3" % _anchors_stabilized)


func _on_portal_activated(player: Node) -> void:
	MusicDirector.stop_music(0.15)
	if player.has_method("set_objective"):
		player.call("set_objective", "VOID CROSSING COMPLETE — enter the ruined nightclub.")
	SFXDirector.play_reveal()


func _activate_portal_visuals() -> void:
	if _portal_root == null:
		return

	var mesh_nodes: Array[Node] = _portal_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
		if material == null:
			continue
		material.emission_energy_multiplier = 3.1
		material.albedo_color = Color("dc4ea7")
		material.emission = Color("c23796")

	var portal_label: Label3D = _portal_root.get_node_or_null("PortalLabel") as Label3D
	if portal_label != null:
		portal_label.modulate = Color("ffd0e9")
		portal_label.text = "THE NIGHTCLUB IS WAITING"


func _animate_starfield(delta: float) -> void:
	var reference_z: float = _player.position.z if _player != null else 0.0
	for star: MeshInstance3D in _stars:
		var speed: float = float(star.get_meta("drift_speed", 2.0))
		star.position.z += speed * delta
		if star.position.z > reference_z + 105.0:
			star.position.z = reference_z - _rng.randf_range(160.0, 260.0)
			star.position.x = _rng.randf_range(-105.0, 105.0)
			star.position.y = _rng.randf_range(-42.0, 62.0)


func _animate_floating_geometry() -> void:
	for body: StaticBody3D in _floating_bodies:
		var base_position_variant: Variant = body.get_meta("base_position", body.position)
		var base_position: Vector3 = body.position
		if base_position_variant is Vector3:
			base_position = base_position_variant
		var bob_amplitude: float = float(body.get_meta("bob_amplitude", 0.0))
		var bob_phase: float = float(body.get_meta("bob_phase", 0.0))
		body.position.y = base_position.y + sin(_elapsed_time * 0.52 + bob_phase) * bob_amplitude
		body.rotation_degrees.z = sin(_elapsed_time * 0.18 + bob_phase) * 1.0


func _animate_rotating_nodes(delta: float) -> void:
	for node: Node3D in _rotating_nodes:
		if not is_instance_valid(node):
			continue
		var rotation_speed: float = float(node.get_meta("rotation_speed", 8.0))
		node.rotate_y(deg_to_rad(rotation_speed * delta))


func _animate_void_core() -> void:
	if _void_core == null:
		return
	var pulse: float = 1.0 + sin(_elapsed_time * 0.54) * 0.05
	_void_core.scale = Vector3(pulse, pulse * 0.68, pulse)


func _animate_portal() -> void:
	if _portal_root == null:
		return
	var portal_pulse: float = 1.0 + sin(_elapsed_time * 1.8) * 0.04
	_portal_root.scale = Vector3.ONE * portal_pulse


func _create_floating_island(
	island_name: String,
	island_position: Vector3,
	radius: float,
	depth: float,
	color: Color,
	bob_amplitude: float,
	bob_phase: float
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = island_name
	body.position = island_position
	body.set_meta("base_position", island_position)
	body.set_meta("bob_amplitude", bob_amplitude)
	body.set_meta("bob_phase", bob_phase)

	var island_mesh: CylinderMesh = CylinderMesh.new()
	island_mesh.top_radius = radius
	island_mesh.bottom_radius = radius * 0.50
	island_mesh.height = depth
	var island_visual: MeshInstance3D = MeshInstance3D.new()
	island_visual.mesh = island_mesh
	island_visual.material_override = _make_rock_material(color)
	body.add_child(island_visual)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = radius * 0.94
	cylinder_shape.height = depth
	collision_shape.shape = cylinder_shape
	body.add_child(collision_shape)

	add_child(body)
	_floating_bodies.append(body)

	for fragment_index: int in range(7):
		var fragment_mesh: CylinderMesh = CylinderMesh.new()
		var fragment_radius: float = radius * _rng.randf_range(0.07, 0.17)
		fragment_mesh.top_radius = fragment_radius
		fragment_mesh.bottom_radius = fragment_radius * 0.10
		fragment_mesh.height = depth * _rng.randf_range(0.9, 2.8)
		var angle: float = TAU * float(fragment_index) / 7.0 + bob_phase
		var fragment_position: Vector3 = Vector3(
			cos(angle) * radius * _rng.randf_range(0.28, 0.76),
			-depth * 0.78,
			sin(angle) * radius * _rng.randf_range(0.28, 0.76)
		)
		var fragment: MeshInstance3D = _add_visual_mesh(
			body,
			fragment_mesh,
			fragment_position,
			_make_rock_material(color.darkened(0.18))
		)
		fragment.rotation_degrees = Vector3(
			_rng.randf_range(-12.0, 12.0),
			_rng.randf_range(0.0, 180.0),
			_rng.randf_range(-15.0, 15.0)
		)

	return body


func _create_static_box(node_name: String, box_position: Vector3, box_size: Vector3, color: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = box_position

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _make_rock_material(color)
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	add_child(body)
	return body


func _create_visual_shard(shard_position: Vector3, shard_scale: Vector3, color: Color) -> void:
	var shard_mesh: CylinderMesh = CylinderMesh.new()
	shard_mesh.top_radius = 0.45
	shard_mesh.bottom_radius = 0.06
	shard_mesh.height = 2.0
	var shard: MeshInstance3D = _add_visual_mesh(
		self,
		shard_mesh,
		shard_position,
		_make_rock_material(color),
		shard_scale
	)
	shard.rotation_degrees = Vector3(
		_rng.randf_range(-55.0, 55.0),
		_rng.randf_range(0.0, 180.0),
		_rng.randf_range(-55.0, 55.0)
	)
	shard.set_meta("rotation_speed", _rng.randf_range(-5.0, 5.0))
	_rotating_nodes.append(shard)


func _create_gravity_gate(
	gate_name: String,
	gate_position: Vector3,
	color: Color,
	radius: float,
	rotation_speed: float
) -> void:
	var root: Node3D = Node3D.new()
	root.name = gate_name
	root.position = gate_position
	add_child(root)

	for ring_index: int in range(4):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = radius + float(ring_index) * 0.62
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.11
		var material: StandardMaterial3D = _make_emissive_material(
			color.lightened(float(ring_index) * 0.07),
			1.40 - float(ring_index) * 0.16,
			0.72
		)
		var ring: MeshInstance3D = _add_visual_mesh(root, ring_mesh, Vector3.ZERO, material)
		ring.rotation_degrees = Vector3(90.0, float(ring_index) * 19.0, float(ring_index) * 11.0)
		ring.set_meta("rotation_speed", rotation_speed + float(ring_index) * 3.5)
		_rotating_nodes.append(ring)


func _create_gravity_well(well_position: Vector3, color: Color, phase: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GravityWell"
	root.position = well_position
	root.set_meta("rotation_speed", 11.0 + phase * 2.0)
	add_child(root)
	_rotating_nodes.append(root)
	_gravity_wells.append(root)

	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 1.3
	sphere_mesh.height = 2.6
	_add_visual_mesh(root, sphere_mesh, Vector3.ZERO, _make_emissive_material(color, 1.9, 0.56))

	for ring_index: int in range(3):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 2.0 + float(ring_index) * 0.65
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.10
		var ring: MeshInstance3D = _add_visual_mesh(
			root,
			ring_mesh,
			Vector3.ZERO,
			_make_emissive_material(color.lightened(float(ring_index) * 0.08), 1.0, 0.48)
		)
		ring.rotation_degrees = Vector3(27.0 + float(ring_index) * 21.0, phase * 36.0, float(ring_index) * 18.0)


func _create_gravity_anchor(
	anchor_id: String,
	anchor_position: Vector3,
	prompt: String,
	message: String,
	color: Color
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GravityAnchor_%s" % anchor_id
	root.position = anchor_position
	root.set_meta("rotation_speed", 15.0)
	add_child(root)
	_rotating_nodes.append(root)
	_anchor_visuals[anchor_id] = root

	var core_mesh: OctahedronMesh = OctahedronMesh.new()
	core_mesh.size = 1.5
	_add_visual_mesh(root, core_mesh, Vector3.ZERO, _make_emissive_material(color, 2.1, 0.36))

	for ring_index: int in range(3):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 1.15 + float(ring_index) * 0.32
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.08
		var ring: MeshInstance3D = _add_visual_mesh(
			root,
			ring_mesh,
			Vector3.ZERO,
			_make_emissive_material(color.lightened(0.10), 1.25, 0.45)
		)
		ring.rotation_degrees = Vector3(float(ring_index) * 33.0, 90.0, float(ring_index) * 17.0)

	var interaction: Area3D = _create_interaction(
		"AnchorInteraction_%s" % anchor_id,
		anchor_position - Vector3(0.0, 1.0, 0.0),
		Vector3(4.8, 4.8, 4.8),
		prompt,
		message,
		true
	)
	interaction.connect("activated", Callable(self, "_on_anchor_activated").bind(anchor_id))


func _create_interaction(
	interaction_name: String,
	interaction_position: Vector3,
	interaction_size: Vector3,
	prompt: String,
	message: String,
	one_shot: bool
) -> Area3D:
	var interaction: Area3D = Area3D.new()
	interaction.name = interaction_name
	interaction.position = interaction_position
	interaction.set_script(INTERACTABLE_SCRIPT)
	interaction.set("prompt_text", prompt)
	interaction.set("interaction_message", message)
	interaction.set("one_shot", one_shot)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = interaction_size
	collision.shape = shape
	collision.position = Vector3(0.0, interaction_size.y * 0.5, 0.0)
	interaction.add_child(collision)
	add_child(interaction)
	return interaction


func _make_rock_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	material.metallic = 0.08
	return material


func _make_emissive_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _add_visual_mesh(
	parent: Node3D,
	mesh: Mesh,
	mesh_position: Vector3,
	material: Material,
	mesh_scale: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.scale = mesh_scale
	instance.material_override = material
	parent.add_child(instance)
	return instance
