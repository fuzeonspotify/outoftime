extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/world/interactable.gd")

const VOID_FALL_LIMIT: float = -18.0
const VOID_RISE_LIMIT: float = 20.0
const VOID_SIDE_LIMIT: float = 24.0
const PORTAL_POSITION: Vector3 = Vector3(0.0, 1.0, -48.0)

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
var _checkpoint_position: Vector3 = Vector3(0.0, 0.2, 28.0)
var _elapsed_time: float = 0.0
var _default_gravity: float = 9.8
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 6111998
	_default_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	MusicDirector.stop_music(1.6)
	SFXDirector.start_city_ambience()
	_build_environment()
	_build_starfield()
	_build_void_core()
	_build_floating_route()
	_build_gravity_fields()
	_build_gravity_anchors()
	_build_nightclub_portal()
	_spawn_player()


func _exit_tree() -> void:
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
	environment.background_color = Color("010008")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("352454")
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.fog_enabled = true
	environment.fog_light_color = Color("25123e")
	environment.fog_density = 0.012
	environment.fog_sky_affect = 0.25
	environment.glow_enabled = true
	environment.glow_bloom = 0.18
	environment.glow_intensity = 1.05
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var violet_light: DirectionalLight3D = DirectionalLight3D.new()
	violet_light.name = "VioletVoidLight"
	violet_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	violet_light.light_color = Color("8b72e8")
	violet_light.light_energy = 1.05
	violet_light.shadow_enabled = true
	add_child(violet_light)

	var magenta_light: DirectionalLight3D = DirectionalLight3D.new()
	magenta_light.name = "MagentaVoidFill"
	magenta_light.rotation_degrees = Vector3(18.0, 148.0, 0.0)
	magenta_light.light_color = Color("d73f9d")
	magenta_light.light_energy = 0.34
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

	for index: int in range(110):
		var star_mesh: SphereMesh = SphereMesh.new()
		var radius: float = _rng.randf_range(0.025, 0.11)
		star_mesh.radius = radius
		star_mesh.height = radius * 2.0

		var star: MeshInstance3D = MeshInstance3D.new()
		star.name = "VoidStar%d" % index
		star.mesh = star_mesh
		star.position = Vector3(
			_rng.randf_range(-45.0, 45.0),
			_rng.randf_range(-18.0, 28.0),
			_rng.randf_range(-125.0, 58.0)
		)
		star.material_override = pink_star_material if index % 7 == 0 else star_material
		star.set_meta("drift_speed", _rng.randf_range(1.2, 4.8))
		add_child(star)
		_stars.append(star)

	for streak_index: int in range(18):
		var streak_mesh: BoxMesh = BoxMesh.new()
		streak_mesh.size = Vector3(0.025, 0.025, _rng.randf_range(0.8, 2.8))
		var streak: MeshInstance3D = MeshInstance3D.new()
		streak.name = "StarStreak%d" % streak_index
		streak.mesh = streak_mesh
		streak.position = Vector3(
			_rng.randf_range(-32.0, 32.0),
			_rng.randf_range(-8.0, 18.0),
			_rng.randf_range(-110.0, 35.0)
		)
		streak.material_override = pink_star_material if streak_index % 3 == 0 else star_material
		streak.set_meta("drift_speed", _rng.randf_range(7.0, 13.0))
		add_child(streak)
		_stars.append(streak)


func _build_void_core() -> void:
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 8.0
	core_mesh.height = 16.0

	var core_material: StandardMaterial3D = StandardMaterial3D.new()
	core_material.albedo_color = Color(0.06, 0.01, 0.10, 0.62)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.emission_enabled = true
	core_material.emission = Color("5a1684")
	core_material.emission_energy_multiplier = 1.15

	_void_core = _add_visual_mesh(
		self,
		core_mesh,
		Vector3(0.0, -24.0, -13.0),
		core_material,
		Vector3(1.0, 0.72, 1.0)
	)
	_void_core.name = "VoidCore"

	for ring_index: int in range(4):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 8.7 + float(ring_index) * 1.35
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.12
		var ring_material: StandardMaterial3D = _make_emissive_material(
			Color("8a32c4") if ring_index % 2 == 0 else Color("cf3e9b"),
			1.25,
			0.48
		)
		var ring: MeshInstance3D = _add_visual_mesh(
			self,
			ring_mesh,
			Vector3(0.0, -24.0, -13.0),
			ring_material
		)
		ring.name = "VoidCoreRing%d" % ring_index
		ring.rotation_degrees = Vector3(
			22.0 + float(ring_index) * 17.0,
			float(ring_index) * 41.0,
			11.0 + float(ring_index) * 13.0
		)
		ring.set_meta("rotation_speed", 7.0 + float(ring_index) * 3.0)
		_rotating_nodes.append(ring)


func _build_floating_route() -> void:
	_create_floating_island(
		"ArrivalIsland",
		Vector3(0.0, -1.0, 28.0),
		7.5,
		2.0,
		Color("20172c"),
		0.10,
		0.0
	)
	_create_floating_island(
		"LowGravityIsland",
		Vector3(0.0, 0.3, 14.0),
		4.4,
		1.6,
		Color("292040"),
		0.18,
		1.2
	)
	_create_floating_island(
		"LowGravityStepA",
		Vector3(-1.8, 1.25, 7.8),
		2.1,
		1.0,
		Color("30244b"),
		0.24,
		2.4
	)
	_create_floating_island(
		"LowGravityStepB",
		Vector3(1.7, 2.25, 2.4),
		2.0,
		1.0,
		Color("352550"),
		0.26,
		3.6
	)
	_create_floating_island(
		"InversionLaunch",
		Vector3(0.0, 3.35, -3.5),
		3.5,
		1.4,
		Color("3a2758"),
		0.12,
		4.6
	)

	_create_static_box(
		"InversionCeiling",
		Vector3(0.0, 9.0, -11.5),
		Vector3(10.0, 0.9, 16.0),
		Color("281b3d")
	)
	for ceiling_index: int in range(5):
		_create_visual_shard(
			Vector3(
				-4.0 + float(ceiling_index) * 2.0,
				9.65,
				-16.5 + float(ceiling_index % 3) * 4.2
			),
			Vector3(0.7, 1.8, 0.7),
			Color("5f3b86")
		)

	_create_floating_island(
		"DriftLanding",
		Vector3(0.0, 0.2, -21.5),
		5.2,
		1.8,
		Color("241a36"),
		0.14,
		5.3
	)
	_create_floating_island(
		"DriftStepA",
		Vector3(-3.0, 2.8, -27.0),
		2.0,
		0.9,
		Color("2f2046"),
		0.32,
		6.1
	)
	_create_floating_island(
		"DriftStepB",
		Vector3(2.8, 3.8, -32.0),
		2.0,
		0.9,
		Color("38234e"),
		0.34,
		7.0
	)
	_create_floating_island(
		"PortalIsland",
		Vector3(0.0, -1.0, -46.0),
		8.5,
		2.2,
		Color("1d152b"),
		0.08,
		8.2
	)

	for shard_index: int in range(28):
		var side: float = -1.0 if shard_index % 2 == 0 else 1.0
		_create_visual_shard(
			Vector3(
				side * _rng.randf_range(8.0, 22.0),
				_rng.randf_range(-8.0, 12.0),
				_rng.randf_range(-58.0, 36.0)
			),
			Vector3(
				_rng.randf_range(0.4, 2.2),
				_rng.randf_range(1.0, 5.5),
				_rng.randf_range(0.4, 2.2)
			),
			Color("352344") if shard_index % 3 != 0 else Color("54255b")
		)


func _build_gravity_fields() -> void:
	_create_gravity_gate(
		"LowGravityGate",
		Vector3(0.0, 3.0, 9.5),
		Color("5c7fff"),
		4.0,
		11.0
	)
	_create_gravity_gate(
		"InversionGate",
		Vector3(0.0, 5.1, -5.0),
		Color("ff4cac"),
		4.2,
		-15.0
	)
	_create_gravity_gate(
		"ZeroGravityGate",
		Vector3(0.0, 4.2, -19.0),
		Color("9e63ff"),
		4.5,
		8.0
	)
	_create_gravity_gate(
		"GravityReturnGate",
		Vector3(0.0, 3.0, -37.0),
		Color("66d2ff"),
		4.1,
		-10.0
	)

	_create_gravity_well(Vector3(-5.5, 4.5, -27.0), Color("8f45ff"), 0.0)
	_create_gravity_well(Vector3(5.0, 5.2, -32.0), Color("ff4ca3"), 1.7)


func _build_gravity_anchors() -> void:
	_create_gravity_anchor(
		"low",
		Vector3(0.0, 1.9, 14.0),
		"Stabilize the low-gravity anchor",
		"The anchor releases its hold. Your bones feel almost weightless.",
		Color("6687ff")
	)
	_create_gravity_anchor(
		"inverted",
		Vector3(0.0, 8.25, -12.0),
		"Stabilize the inverted anchor",
		"Up and down trade places. The void does not notice the difference.",
		Color("ff4cae")
	)
	_create_gravity_anchor(
		"drift",
		Vector3(2.8, 4.8, -32.0),
		"Stabilize the drifting anchor",
		"The current slows. Far ahead, a doorway begins to burn through the dark.",
		Color("a266ff")
	)


func _build_nightclub_portal() -> void:
	_portal_root = Node3D.new()
	_portal_root.name = "NightclubVoidPortal"
	_portal_root.position = PORTAL_POSITION
	add_child(_portal_root)

	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 1.65
	ring_mesh.outer_radius = 2.15
	var ring_material: StandardMaterial3D = _make_emissive_material(Color("7d356f"), 0.35, 0.78)
	var ring: MeshInstance3D = _add_visual_mesh(
		_portal_root,
		ring_mesh,
		Vector3(0.0, 1.8, 0.0),
		ring_material
	)
	ring.rotation_degrees.x = 90.0
	ring.name = "PortalRing"
	ring.set_meta("rotation_speed", 26.0)
	_rotating_nodes.append(ring)

	var portal_mesh: SphereMesh = SphereMesh.new()
	portal_mesh.radius = 1.45
	portal_mesh.height = 2.9
	var portal_material: StandardMaterial3D = _make_emissive_material(Color("38112f"), 0.22, 0.62)
	portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var portal_surface: MeshInstance3D = _add_visual_mesh(
		_portal_root,
		portal_mesh,
		Vector3(0.0, 1.8, 0.0),
		portal_material,
		Vector3(1.0, 1.15, 0.16)
	)
	portal_surface.name = "PortalSurface"

	var portal_label: Label3D = Label3D.new()
	portal_label.name = "PortalLabel"
	portal_label.text = "THE MUSIC IS STILL PLAYING"
	portal_label.font_size = 44
	portal_label.modulate = Color("8c6b87")
	portal_label.outline_size = 7
	portal_label.position = Vector3(0.0, 4.6, 0.0)
	_portal_root.add_child(portal_label)

	_portal_interaction = _create_interaction(
		"NightclubEntrance",
		PORTAL_POSITION,
		Vector3(5.5, 5.0, 5.5),
		"Step through the void",
		"The portal opens onto bass, broken glass, and a room that remembers your name.",
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
	_player.set_objective("Cross the void and stabilize the three gravity anchors.")
	_player.show_interaction_message(
		"The city is gone. Only its gravity remains, broken into pieces.",
		5.5
	)


func _apply_gravity_profile(delta: float) -> void:
	var player_z: float = _player.position.z
	var gravity_multiplier: float = 1.0
	var vertical_damping: float = 0.0
	var state: StringName = &"normal"

	if player_z <= 9.5 and player_z > -5.0:
		gravity_multiplier = 0.22
		vertical_damping = 0.15
		state = &"low"
	elif player_z <= -5.0 and player_z > -19.0:
		gravity_multiplier = -0.62
		vertical_damping = 0.18
		state = &"inverted"
	elif player_z <= -19.0 and player_z > -37.0:
		gravity_multiplier = 0.04
		vertical_damping = 1.25
		state = &"drift"

	_player.velocity.y += _default_gravity * (1.0 - gravity_multiplier) * delta
	if vertical_damping > 0.0:
		_player.velocity.y = move_toward(_player.velocity.y, 0.0, vertical_damping * delta)

	if state == &"drift":
		_player.velocity.z -= 0.45 * delta

	if state != _gravity_state:
		_gravity_state = state
		_announce_gravity_state(state)


func _apply_void_wells(delta: float) -> void:
	if _gravity_state != &"drift":
		return

	for well: Node3D in _gravity_wells:
		var offset: Vector3 = well.global_position - _player.global_position
		var distance: float = offset.length()
		if distance <= 0.01 or distance > 10.0:
			continue
		var pull_strength: float = (1.0 - distance / 10.0) * 4.5
		var pull_direction: Vector3 = offset.normalized()
		_player.velocity += pull_direction * pull_strength * delta


func _announce_gravity_state(state: StringName) -> void:
	if _player == null:
		return

	match state:
		&"low":
			_player.show_interaction_message("GRAVITY: 22% — every jump carries too far.", 3.0)
		&"inverted":
			_player.show_interaction_message("GRAVITY INVERTED — the ceiling is pulling you upward.", 3.6)
		&"drift":
			_player.show_interaction_message("GRAVITY: NEAR ZERO — use the currents to cross.", 3.2)
		_:
			_player.show_interaction_message("GRAVITY RESTORED.", 2.2)


func _update_checkpoint() -> void:
	var player_z: float = _player.position.z
	if player_z < -39.0:
		_checkpoint_position = Vector3(0.0, 0.25, -42.0)
	elif player_z < -20.0:
		_checkpoint_position = Vector3(0.0, 1.35, -22.0)
	elif player_z < 1.0:
		_checkpoint_position = Vector3(0.0, 4.25, -3.5)
	elif player_z < 11.0:
		_checkpoint_position = Vector3(0.0, 1.25, 14.0)


func _recover_player() -> void:
	_player.position = _checkpoint_position
	_player.velocity = Vector3.ZERO
	_player.show_interaction_message(
		"The void folds you back to the last stable piece of ground.",
		3.0
	)


func _on_anchor_activated(player: Node, anchor_id: String) -> void:
	if _stabilized_anchor_ids.has(anchor_id):
		return

	_stabilized_anchor_ids[anchor_id] = true
	_anchors_stabilized += 1
	SFXDirector.play_reveal()

	var anchor_root: Node3D = _anchor_visuals.get(anchor_id) as Node3D
	if anchor_root != null:
		anchor_root.set_meta("stabilized", true)

	if _anchors_stabilized >= 3:
		_portal_interaction.monitoring = true
		_activate_portal_visuals()
		if player.has_method("set_objective"):
			player.call("set_objective", "Reach the portal burning at the end of the void.")
		return

	if player.has_method("set_objective"):
		player.call(
			"set_objective",
			"Gravity anchors stabilized: %d / 3" % _anchors_stabilized
		)


func _on_portal_activated(player: Node) -> void:
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
		material.emission_energy_multiplier = 2.8
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
		if star.position.z > reference_z + 58.0:
			star.position.z = reference_z - _rng.randf_range(90.0, 150.0)
			star.position.x = _rng.randf_range(-45.0, 45.0)
			star.position.y = _rng.randf_range(-18.0, 28.0)


func _animate_floating_geometry() -> void:
	for body: StaticBody3D in _floating_bodies:
		var base_position: Vector3 = body.get_meta("base_position", body.position)
		var bob_amplitude: float = float(body.get_meta("bob_amplitude", 0.0))
		var bob_phase: float = float(body.get_meta("bob_phase", 0.0))
		body.position.y = base_position.y + sin(_elapsed_time * 0.65 + bob_phase) * bob_amplitude
		body.rotation_degrees.z = sin(_elapsed_time * 0.22 + bob_phase) * 1.2


func _animate_rotating_nodes(delta: float) -> void:
	for node: Node3D in _rotating_nodes:
		var rotation_speed: float = float(node.get_meta("rotation_speed", 8.0))
		node.rotate_y(deg_to_rad(rotation_speed * delta))


func _animate_void_core() -> void:
	if _void_core == null:
		return
	var pulse: float = 1.0 + sin(_elapsed_time * 0.72) * 0.045
	_void_core.scale = Vector3(pulse, pulse * 0.72, pulse)


func _animate_portal() -> void:
	if _portal_root == null:
		return
	var portal_pulse: float = 1.0 + sin(_elapsed_time * 2.1) * 0.035
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
	island_mesh.bottom_radius = radius * 0.52
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

	for fragment_index: int in range(5):
		var fragment_mesh: CylinderMesh = CylinderMesh.new()
		var fragment_radius: float = radius * _rng.randf_range(0.08, 0.18)
		fragment_mesh.top_radius = fragment_radius
		fragment_mesh.bottom_radius = fragment_radius * 0.12
		fragment_mesh.height = depth * _rng.randf_range(0.8, 2.2)
		var angle: float = TAU * float(fragment_index) / 5.0 + bob_phase
		var fragment_position: Vector3 = Vector3(
			cos(angle) * radius * _rng.randf_range(0.25, 0.72),
			-depth * 0.72,
			sin(angle) * radius * _rng.randf_range(0.25, 0.72)
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


func _create_static_box(
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	color: Color
) -> StaticBody3D:
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


func _create_visual_shard(
	shard_position: Vector3,
	shard_scale: Vector3,
	color: Color
) -> void:
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

	for ring_index: int in range(3):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = radius + float(ring_index) * 0.42
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.08
		var material: StandardMaterial3D = _make_emissive_material(
			color.lightened(float(ring_index) * 0.08),
			1.35 - float(ring_index) * 0.18,
			0.72
		)
		var ring: MeshInstance3D = _add_visual_mesh(
			root,
			ring_mesh,
			Vector3.ZERO,
			material
		)
		ring.rotation_degrees = Vector3(
			90.0,
			float(ring_index) * 19.0,
			float(ring_index) * 11.0
		)
		ring.set_meta("rotation_speed", rotation_speed + float(ring_index) * 4.0)
		_rotating_nodes.append(ring)


func _create_gravity_well(
	well_position: Vector3,
	color: Color,
	phase: float
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GravityWell"
	root.position = well_position
	root.set_meta("well_phase", phase)
	add_child(root)
	_gravity_wells.append(root)

	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.5
	core_mesh.height = 1.0
	_add_visual_mesh(
		root,
		core_mesh,
		Vector3.ZERO,
		_make_emissive_material(color, 2.2, 0.76)
	)

	for ring_index: int in range(2):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 1.2 + float(ring_index) * 0.55
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.08
		var ring: MeshInstance3D = _add_visual_mesh(
			root,
			ring_mesh,
			Vector3.ZERO,
			_make_emissive_material(color, 1.3, 0.55)
		)
		ring.rotation_degrees = Vector3(25.0 + float(ring_index) * 35.0, 0.0, 50.0)
		ring.set_meta("rotation_speed", 18.0 + float(ring_index) * 8.0)
		_rotating_nodes.append(ring)


func _create_gravity_anchor(
	anchor_id: String,
	anchor_position: Vector3,
	prompt_text: String,
	message_text: String,
	color: Color
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GravityAnchor_%s" % anchor_id
	root.position = anchor_position
	root.set_meta("stabilized", false)
	add_child(root)
	_anchor_visuals[anchor_id] = root

	var pedestal_mesh: CylinderMesh = CylinderMesh.new()
	pedestal_mesh.top_radius = 0.72
	pedestal_mesh.bottom_radius = 0.95
	pedestal_mesh.height = 0.55
	_add_visual_mesh(
		root,
		pedestal_mesh,
		Vector3(0.0, 0.25, 0.0),
		_make_rock_material(Color("322440"))
	)

	var orb_mesh: SphereMesh = SphereMesh.new()
	orb_mesh.radius = 0.38
	orb_mesh.height = 0.76
	_add_visual_mesh(
		root,
		orb_mesh,
		Vector3(0.0, 1.2, 0.0),
		_make_emissive_material(color, 2.2, 0.84)
	)

	for ring_index: int in range(2):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 0.62 + float(ring_index) * 0.26
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.055
		var ring: MeshInstance3D = _add_visual_mesh(
			root,
			ring_mesh,
			Vector3(0.0, 1.2, 0.0),
			_make_emissive_material(color, 1.5, 0.68)
		)
		ring.rotation_degrees = Vector3(
			35.0 + float(ring_index) * 40.0,
			float(ring_index) * 30.0,
			15.0
		)
		ring.set_meta("rotation_speed", 24.0 + float(ring_index) * 11.0)
		_rotating_nodes.append(ring)

	var interaction: Area3D = _create_interaction(
		"GravityAnchorInteraction_%s" % anchor_id,
		anchor_position,
		Vector3(3.0, 3.5, 3.0),
		prompt_text,
		message_text,
		true
	)
	interaction.connect(
		"activated",
		Callable(self, "_on_anchor_activated").bind(anchor_id)
	)


func _create_interaction(
	node_name: String,
	interaction_position: Vector3,
	interaction_size: Vector3,
	prompt_text: String,
	message_text: String,
	one_shot: bool
) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = node_name
	area.set_script(INTERACTABLE_SCRIPT)
	area.set("prompt_text", prompt_text)
	area.set("interaction_message", message_text)
	area.set("one_shot", one_shot)
	area.position = interaction_position

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = interaction_size
	collision.shape = shape
	collision.position = Vector3(0.0, interaction_size.y * 0.45, 0.0)
	area.add_child(collision)
	add_child(area)
	return area


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


func _make_rock_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic = 0.08
	return material


func _make_emissive_material(
	color: Color,
	emission_energy: float,
	alpha: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material
