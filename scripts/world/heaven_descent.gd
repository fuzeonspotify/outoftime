extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const INTERACTABLE_SCRIPT: Script = preload("res://scripts/world/interactable.gd")
const ANGEL_SCRIPT: Script = preload("res://scripts/world/heaven_angel.gd")
const HEAVEN_AUDIO_SCRIPT: Script = preload("res://scripts/audio/heaven_descent_audio.gd")
const NIGHTCLUB_SCENE_PATH: String = "res://scenes/ruined_nightclub.tscn"

const PLAYER_START: Vector3 = Vector3(0.0, 0.2, 38.0)
const CORRUPTION_START_Z: float = 16.0
const CORRUPTION_FULL_Z: float = -122.0
const EXIT_GATE_Z: float = -140.0
const FALL_LIMIT: float = -12.0

const FORWARD_MESSAGES: Array[String] = [
	"The air is warm. Every face welcomes you.",
	"The choir loses a note whenever you walk toward the distant gate.",
	"The angels are no longer looking at Heaven. They are looking at you.",
	"Their halos were never crowns. They were restraints.",
	"The light was only hiding what waited underneath.",
	"REVELATION COMPLETE — the final gate recognizes you."
]

const RETURN_MESSAGES: Array[String] = [
	"The warmth returns when you retreat.",
	"Their eyes soften as distance grows between you and the gate.",
	"The wings remember how to be white again.",
	"The choir finds the missing note.",
	"Heaven rebuilds itself behind your footsteps."
]

var _player: CharacterBody3D
var _environment: Environment
var _sun_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _sun_visual: MeshInstance3D
var _gate_root: Node3D
var _gate_interaction: Area3D
var _gate_enabled: bool = false
var _transition_started: bool = false

var _audio: Node
var _angels: Array[Node3D] = []
var _motes: Array[Dictionary] = []
var _morph_materials: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _corruption: float = 0.0
var _corruption_band: int = 0
var _elapsed: float = 0.0
var _whisper_timer: float = 5.0

var _sanctity_label: Label
var _state_label: Label
var _sanctity_bar: ProgressBar
var _direction_label: Label
var _wake_overlay: ColorRect
var _transition_overlay: ColorRect


func _ready() -> void:
	_rng.seed = 13061998
	MusicDirector.stop_music(3.5)
	SFXDirector.stop_environment(1.8)
	_build_environment()
	_build_landscape()
	_build_angel_procession()
	_build_exit_gate()
	_spawn_player()
	_build_hud()
	_audio = HEAVEN_AUDIO_SCRIPT.new() as Node
	add_child(_audio)
	_audio.call("start")
	_start_wake_sequence.call_deferred()


func _exit_tree() -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.call("stop", 0.8)


func _process(delta: float) -> void:
	_elapsed += delta
	if _player == null or not is_instance_valid(_player):
		return

	if _player.position.y < FALL_LIMIT:
		_player.position = PLAYER_START
		_player.velocity = Vector3.ZERO

	var target_corruption: float = clampf(
		inverse_lerp(CORRUPTION_START_Z, CORRUPTION_FULL_Z, _player.position.z),
		0.0,
		1.0
	)
	_corruption = move_toward(_corruption, target_corruption, delta * 0.46)
	_update_environment_state()
	_update_angels(delta)
	_update_motes(delta)
	_update_directional_audio(delta)
	_update_hud()
	_update_corruption_band()
	_set_gate_enabled(_corruption >= 0.92)


func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "HeavenEnvironment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("dff4ff")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("fff4d4")
	_environment.ambient_light_energy = 1.18
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("f5f1ff")
	_environment.fog_density = 0.004
	_environment.fog_sky_affect = 0.34
	_environment.glow_enabled = true
	_environment.glow_bloom = 0.24
	_environment.glow_intensity = 1.06
	_environment.adjustment_enabled = true
	_environment.adjustment_saturation = 1.08
	_environment.adjustment_contrast = 1.02
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = _environment
	add_child(world_environment)

	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "HeavenSun"
	_sun_light.rotation_degrees = Vector3(-48.0, -18.0, 0.0)
	_sun_light.light_color = Color("fff0b8")
	_sun_light.light_energy = 1.42
	_sun_light.shadow_enabled = true
	add_child(_sun_light)

	_fill_light = DirectionalLight3D.new()
	_fill_light.name = "HeavenFill"
	_fill_light.rotation_degrees = Vector3(22.0, 156.0, 0.0)
	_fill_light.light_color = Color("b9d8ff")
	_fill_light.light_energy = 0.72
	add_child(_fill_light)

	var sun_mesh: SphereMesh = SphereMesh.new()
	sun_mesh.radius = 7.5
	sun_mesh.height = 15.0
	var sun_material: StandardMaterial3D = _make_morph_material(
		Color("fff5c7"),
		Color("57102b"),
		0.12,
		Color("ffe69d"),
		Color("d20d43"),
		3.2,
		1.8
	)
	_sun_visual = _add_mesh(self, sun_mesh, Vector3(-34.0, 30.0, -92.0), sun_material)


func _build_landscape() -> void:
	var cloud_ground_material: StandardMaterial3D = _make_morph_material(
		Color("f8fbff"), Color("160b1d"), 0.88
	)
	var path_material: StandardMaterial3D = _make_morph_material(
		Color("fff8df"), Color("2a0e20"), 0.62,
		Color("ffe5a4"), Color("8e173d"), 0.32, 1.15
	)
	var gold_material: StandardMaterial3D = _make_morph_material(
		Color("e8c96d"), Color("4c1733"), 0.34,
		Color("ffe28b"), Color("c21e50"), 1.5, 1.7
	)
	var marble_material: StandardMaterial3D = _make_morph_material(
		Color("f0ecdf"), Color("24111f"), 0.72
	)
	var water_material: StandardMaterial3D = _make_morph_material(
		Color(0.58, 0.84, 1.0, 0.72), Color(0.18, 0.01, 0.12, 0.78), 0.18,
		Color("86d7ff"), Color("ad0b54"), 0.45, 1.10
	)

	_create_static_box(
		"HeavenGround",
		Vector3(0.0, -0.85, -52.0),
		Vector3(54.0, 1.7, 220.0),
		cloud_ground_material
	)
	_add_box(self, Vector3(0.0, 0.03, -52.0), Vector3(10.5, 0.12, 214.0), path_material)
	_add_box(self, Vector3(-8.5, -0.10, -52.0), Vector3(2.1, 0.22, 214.0), water_material)
	_add_box(self, Vector3(8.5, -0.10, -52.0), Vector3(2.1, 0.22, 214.0), water_material)

	_add_invisible_boundary(Vector3(-27.5, 4.0, -52.0), Vector3(2.0, 10.0, 220.0))
	_add_invisible_boundary(Vector3(27.5, 4.0, -52.0), Vector3(2.0, 10.0, 220.0))
	_add_invisible_boundary(Vector3(0.0, 4.0, 55.0), Vector3(54.0, 10.0, 2.0))

	for arch_index: int in range(8):
		var z_position: float = 28.0 - float(arch_index) * 22.0
		_build_arch(Vector3(0.0, 0.0, z_position), marble_material, gold_material, arch_index)

	for garden_index: int in range(34):
		var z_position: float = 39.0 - float(garden_index) * 5.4
		var side: float = -1.0 if garden_index % 2 == 0 else 1.0
		_build_flower_cluster(
			Vector3(side * _rng.randf_range(11.0, 19.5), 0.0, z_position),
			garden_index
		)

	var cloud_material: StandardMaterial3D = _make_morph_material(
		Color(0.97, 0.99, 1.0, 0.68),
		Color(0.08, 0.02, 0.10, 0.78),
		0.96,
		Color(0.70, 0.84, 1.0, 0.30),
		Color(0.35, 0.01, 0.16, 0.62),
		0.18,
		0.65
	)
	for cloud_index: int in range(48):
		var cloud_mesh: SphereMesh = SphereMesh.new()
		cloud_mesh.radius = _rng.randf_range(2.8, 7.2)
		cloud_mesh.height = _rng.randf_range(1.1, 2.8)
		var side: float = -1.0 if cloud_index % 2 == 0 else 1.0
		var cloud: MeshInstance3D = _add_mesh(
			self,
			cloud_mesh,
			Vector3(
				side * _rng.randf_range(18.0, 42.0),
				_rng.randf_range(-0.2, 9.0),
				_rng.randf_range(-168.0, 52.0)
			),
			cloud_material
		)
		cloud.scale = Vector3(_rng.randf_range(1.4, 2.8), 0.45, _rng.randf_range(0.9, 1.8))

	_build_floating_motes()


func _build_arch(
	arch_position: Vector3,
	marble_material: StandardMaterial3D,
	gold_material: StandardMaterial3D,
	arch_index: int
) -> void:
	var arch_root: Node3D = Node3D.new()
	arch_root.name = "HeavenArch%d" % arch_index
	arch_root.position = arch_position
	add_child(arch_root)
	for side: float in [-1.0, 1.0]:
		var pillar_mesh: CylinderMesh = CylinderMesh.new()
		pillar_mesh.top_radius = 0.44
		pillar_mesh.bottom_radius = 0.56
		pillar_mesh.height = 6.8
		_add_mesh(arch_root, pillar_mesh, Vector3(side * 5.25, 3.4, 0.0), marble_material)
		var capital_mesh: CylinderMesh = CylinderMesh.new()
		capital_mesh.top_radius = 0.74
		capital_mesh.bottom_radius = 0.64
		capital_mesh.height = 0.42
		_add_mesh(arch_root, capital_mesh, Vector3(side * 5.25, 6.75, 0.0), gold_material)
	_add_box(arch_root, Vector3(0.0, 6.78, 0.0), Vector3(11.2, 0.42, 0.70), gold_material)
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 1.65
	ring_mesh.outer_radius = 1.82
	var ring: MeshInstance3D = _add_mesh(arch_root, ring_mesh, Vector3(0.0, 6.65, 0.0), gold_material)
	ring.rotation_degrees.x = 90.0


func _build_flower_cluster(cluster_position: Vector3, cluster_index: int) -> void:
	var stem_material: StandardMaterial3D = _make_morph_material(
		Color("82a873"), Color("26101f"), 0.92
	)
	var blossom_color: Color = Color("ffe6f5") if cluster_index % 3 == 0 else Color("fff3ad")
	var blossom_material: StandardMaterial3D = _make_morph_material(
		blossom_color, Color("5e102d"), 0.68,
		blossom_color, Color("b00e42"), 0.28, 0.80
	)
	var root: Node3D = Node3D.new()
	root.position = cluster_position
	add_child(root)
	for flower_index: int in range(5):
		var stem_mesh: CylinderMesh = CylinderMesh.new()
		stem_mesh.top_radius = 0.025
		stem_mesh.bottom_radius = 0.035
		stem_mesh.height = 0.65 + float(flower_index % 2) * 0.22
		var x_offset: float = -0.5 + float(flower_index) * 0.24
		_add_mesh(root, stem_mesh, Vector3(x_offset, stem_mesh.height * 0.5, 0.0), stem_material)
		var blossom_mesh: SphereMesh = SphereMesh.new()
		blossom_mesh.radius = 0.11
		blossom_mesh.height = 0.16
		_add_mesh(root, blossom_mesh, Vector3(x_offset, stem_mesh.height + 0.05, 0.0), blossom_material)


func _build_floating_motes() -> void:
	var mote_material: StandardMaterial3D = _make_morph_material(
		Color("fff4b8"), Color("ff174f"), 0.10,
		Color("ffeaa3"), Color("e70942"), 2.2, 3.4
	)
	for mote_index: int in range(74):
		var mote_mesh: SphereMesh = SphereMesh.new()
		var radius: float = _rng.randf_range(0.025, 0.075)
		mote_mesh.radius = radius
		mote_mesh.height = radius * 2.0
		var base_position: Vector3 = Vector3(
			_rng.randf_range(-20.0, 20.0),
			_rng.randf_range(0.8, 8.0),
			_rng.randf_range(-154.0, 45.0)
		)
		var mote: MeshInstance3D = _add_mesh(self, mote_mesh, base_position, mote_material)
		_motes.append({
			"node": mote,
			"base": base_position,
			"phase": _rng.randf_range(0.0, TAU),
			"speed": _rng.randf_range(0.45, 1.35)
		})


func _build_angel_procession() -> void:
	var z_positions: Array[float] = [
		30.0, 18.0, 5.0, -8.0, -21.0, -34.0, -47.0,
		-60.0, -73.0, -86.0, -99.0, -112.0, -126.0
	]
	for index: int in range(z_positions.size()):
		for side: float in [-1.0, 1.0]:
			var angel: Node3D = ANGEL_SCRIPT.new() as Node3D
			angel.name = "Angel_%02d_%s" % [index, "L" if side < 0.0 else "R"]
			add_child(angel)
			angel.call(
				"configure",
				Vector3(side * (6.7 + float(index % 3) * 0.75), 0.0, z_positions[index]),
				float(index) * 0.53 + side
			)
			_angels.append(angel)


func _build_exit_gate() -> void:
	_gate_root = Node3D.new()
	_gate_root.name = "RevelationGate"
	_gate_root.position = Vector3(0.0, 0.0, EXIT_GATE_Z)
	add_child(_gate_root)
	var gate_material: StandardMaterial3D = _make_morph_material(
		Color("f7edc9"), Color("180711"), 0.54,
		Color("ffe28b"), Color("ff0e4c"), 0.70, 3.0
	)
	for side: float in [-1.0, 1.0]:
		_add_box(_gate_root, Vector3(side * 4.3, 3.6, 0.0), Vector3(1.1, 7.2, 1.4), gate_material)
	_add_box(_gate_root, Vector3(0.0, 7.0, 0.0), Vector3(9.7, 1.0, 1.4), gate_material)
	var gate_void_material: StandardMaterial3D = _make_morph_material(
		Color(0.86, 0.95, 1.0, 0.16), Color(0.20, 0.0, 0.08, 0.88), 0.10,
		Color("bce8ff"), Color("ed0d4d"), 0.35, 2.8
	)
	_add_box(_gate_root, Vector3(0.0, 3.5, 0.22), Vector3(7.4, 6.0, 0.16), gate_void_material)

	_gate_interaction = Area3D.new()
	_gate_interaction.name = "HeavenExit"
	_gate_interaction.set_script(INTERACTABLE_SCRIPT)
	_gate_interaction.set("prompt_text", "Enter the revealed doorway")
	_gate_interaction.set("interaction_title", "FALSE HEAVEN")
	_gate_interaction.set("interaction_context", "HOLD TO DESCEND")
	_gate_interaction.set("interaction_message", "")
	_gate_interaction.set("suppress_message", true)
	_gate_interaction.set("one_shot", true)
	_gate_interaction.set("hold_duration", 1.0)
	_gate_interaction.set("marker_height", 3.0)
	_gate_interaction.set("marker_color", Color("ff245f"))
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(8.5, 7.0, 5.0)
	collision.shape = shape
	collision.position = Vector3(0.0, 3.3, 0.0)
	_gate_interaction.add_child(collision)
	_gate_root.add_child(_gate_interaction)
	_gate_interaction.connect("activated", Callable(self, "_on_gate_activated"))
	_gate_interaction.monitoring = false
	_gate_interaction.monitorable = false
	_gate_interaction.collision_layer = 0


func _spawn_player() -> void:
	var instance: Node = PLAYER_SCENE.instantiate()
	_player = instance as CharacterBody3D
	if _player == null:
		push_error("Player scene root must be CharacterBody3D.")
		return
	_player.position = PLAYER_START
	add_child(_player)
	_player.set_chapter_title("CHAPTER III  //  THE WELCOME")
	_player.set_objective("Walk toward the distant gate. Turn back whenever the light changes.")


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "HeavenSignalHUD"
	canvas.layer = 58
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.33
	panel.anchor_right = 0.67
	panel.offset_top = 26.0
	panel.offset_bottom = 118.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.025, 0.05, 0.72)
	style.border_color = Color(0.92, 0.81, 0.48, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	_state_label = _make_label("HEAVEN SIGNAL  //  STABLE", 13, Color("ffe6a3"))
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_state_label)
	_sanctity_label = _make_label("SANCTITY  100%", 12, Color("f5f0df"))
	_sanctity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_sanctity_label)
	_sanctity_bar = ProgressBar.new()
	_sanctity_bar.min_value = 0.0
	_sanctity_bar.max_value = 100.0
	_sanctity_bar.value = 100.0
	_sanctity_bar.show_percentage = false
	_sanctity_bar.custom_minimum_size = Vector2(0.0, 9.0)
	stack.add_child(_sanctity_bar)

	_direction_label = _make_label(
		"THE WORLD RESPONDS TO YOUR DIRECTION",
		11,
		Color("c5bdd0")
	)
	_direction_label.anchor_left = 0.25
	_direction_label.anchor_right = 0.75
	_direction_label.anchor_top = 1.0
	_direction_label.anchor_bottom = 1.0
	_direction_label.offset_top = -46.0
	_direction_label.offset_bottom = -18.0
	_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_direction_label)

	_wake_overlay = ColorRect.new()
	_wake_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wake_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	_wake_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_wake_overlay)
	_transition_overlay = ColorRect.new()
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_transition_overlay)


func _start_wake_sequence() -> void:
	await get_tree().process_frame
	_set_gate_enabled(false, true)
	if _player != null and _player.has_method("set_cinematic_mode"):
		_player.call("set_cinematic_mode", true)
	_audio.call("play_threshold", false)
	var fade: Tween = create_tween()
	fade.tween_property(_wake_overlay, "color:a", 0.0, 2.6).set_trans(Tween.TRANS_SINE)
	await fade.finished
	if _player != null and _player.has_method("set_cinematic_mode"):
		_player.call("set_cinematic_mode", false)
	_player.show_interaction_message(
		"You wake without pain. The angels insist this is where the bridge was taking you.",
		5.4,
		"THE WELCOME"
	)


func _update_environment_state() -> void:
	var corruption_curve: float = smoothstep(0.0, 1.0, _corruption)
	_environment.background_color = Color("dff4ff").lerp(Color("080109"), corruption_curve)
	_environment.ambient_light_color = Color("fff4d4").lerp(Color("54102f"), corruption_curve)
	_environment.ambient_light_energy = lerpf(1.18, 0.34, corruption_curve)
	_environment.fog_light_color = Color("f5f1ff").lerp(Color("37051e"), corruption_curve)
	_environment.fog_density = lerpf(0.004, 0.032, corruption_curve)
	_environment.fog_sky_affect = lerpf(0.34, 0.88, corruption_curve)
	_environment.glow_intensity = lerpf(1.06, 1.48, corruption_curve)
	_environment.adjustment_saturation = lerpf(1.08, 0.76, corruption_curve)
	_environment.adjustment_contrast = lerpf(1.02, 1.28, corruption_curve)
	_sun_light.light_color = Color("fff0b8").lerp(Color("d11247"), corruption_curve)
	_sun_light.light_energy = lerpf(1.42, 0.48, corruption_curve)
	_fill_light.light_color = Color("b9d8ff").lerp(Color("4d0a62"), corruption_curve)
	_fill_light.light_energy = lerpf(0.72, 0.92, corruption_curve)
	_sun_visual.scale = Vector3.ONE * lerpf(1.0, 0.72, corruption_curve)

	for record: Dictionary in _morph_materials:
		var material: StandardMaterial3D = record.get("material") as StandardMaterial3D
		if material == null:
			continue
		var light_color: Color = record.get("light_color", Color.WHITE)
		var dark_color: Color = record.get("dark_color", Color.BLACK)
		material.albedo_color = light_color.lerp(dark_color, corruption_curve)
		material.roughness = lerpf(
			float(record.get("light_roughness", 0.7)),
			float(record.get("dark_roughness", 0.4)),
			corruption_curve
		)
		if material.emission_enabled:
			var light_emission: Color = record.get("light_emission", Color.BLACK)
			var dark_emission: Color = record.get("dark_emission", Color.BLACK)
			material.emission = light_emission.lerp(dark_emission, corruption_curve)
			material.emission_energy_multiplier = lerpf(
				float(record.get("light_energy", 0.0)),
				float(record.get("dark_energy", 0.0)),
				corruption_curve
			)


func _update_angels(delta: float) -> void:
	for angel: Node3D in _angels:
		if not is_instance_valid(angel):
			continue
		var local_delay: float = clampf((18.0 - angel.position.z) / 210.0, 0.0, 0.22)
		var angel_corruption: float = clampf((_corruption - local_delay) / maxf(0.01, 1.0 - local_delay), 0.0, 1.0)
		angel.call("set_corruption", angel_corruption, _player.global_position, delta)


func _update_motes(delta: float) -> void:
	for record: Dictionary in _motes:
		var mote: MeshInstance3D = record.get("node") as MeshInstance3D
		if mote == null:
			continue
		var base_position: Vector3 = record.get("base", Vector3.ZERO)
		var phase: float = float(record.get("phase", 0.0))
		var speed: float = float(record.get("speed", 1.0))
		var rise: float = fmod(_elapsed * speed + phase, 6.0)
		var light_position: Vector3 = base_position + Vector3(
			sin(_elapsed * 0.4 + phase) * 0.34,
			rise,
			cos(_elapsed * 0.3 + phase) * 0.26
		)
		var dark_position: Vector3 = base_position + Vector3(
			sin(_elapsed * 2.2 + phase) * 1.4,
			-fmod(_elapsed * speed * 1.8 + phase, 7.0),
			cos(_elapsed * 1.7 + phase) * 1.1
		)
		mote.position = light_position.lerp(dark_position, _corruption)
		mote.scale = Vector3.ONE * lerpf(1.0, 1.7, _corruption)
		mote.rotate_y(delta * lerpf(0.4, 4.0, _corruption))


func _update_directional_audio(delta: float) -> void:
	_audio.call("set_corruption", _corruption)
	_whisper_timer -= delta
	if _corruption < 0.38 or _whisper_timer > 0.0 or _angels.is_empty():
		return
	var angel: Node3D = _angels[_rng.randi_range(0, _angels.size() - 1)]
	var whisper_position_variant: Variant = angel.call("get_whisper_position")
	if whisper_position_variant is Vector3:
		_audio.call("play_directional_whisper", whisper_position_variant, _corruption)
	_whisper_timer = lerpf(7.5, 2.2, _corruption)


func _update_hud() -> void:
	var sanctity: int = int(round((1.0 - _corruption) * 100.0))
	_sanctity_label.text = "SANCTITY  %03d%%" % sanctity
	_sanctity_bar.value = float(sanctity)
	var light_color: Color = Color("ffe6a3")
	var dark_color: Color = Color("ff245f")
	var signal_color: Color = light_color.lerp(dark_color, _corruption)
	_state_label.add_theme_color_override("font_color", signal_color)
	_sanctity_label.add_theme_color_override("font_color", Color("f5f0df").lerp(Color("ff9db8"), _corruption))
	if _corruption < 0.16:
		_state_label.text = "HEAVEN SIGNAL  //  STABLE"
	elif _corruption < 0.44:
		_state_label.text = "HEAVEN SIGNAL  //  DRIFTING"
	elif _corruption < 0.72:
		_state_label.text = "HEAVEN SIGNAL  //  MASK FAILURE"
	elif _corruption < 0.92:
		_state_label.text = "HEAVEN SIGNAL  //  HOSTILE"
	else:
		_state_label.text = "FALSE HEAVEN  //  REVEALED"


func _update_corruption_band() -> void:
	var next_band: int = clampi(int(floor(_corruption * 5.0 + 0.001)), 0, 5)
	if next_band == _corruption_band:
		return
	var darkening: bool = next_band > _corruption_band
	_corruption_band = next_band
	_audio.call("play_threshold", darkening)
	if darkening:
		_player.show_interaction_message(
			FORWARD_MESSAGES[next_band],
			4.2,
			"HEAVEN SIGNAL"
		)
	else:
		var return_index: int = clampi(next_band, 0, RETURN_MESSAGES.size() - 1)
		_player.show_interaction_message(
			RETURN_MESSAGES[return_index],
			3.4,
			"RESTORATION"
		)

	if next_band >= 5:
		_player.set_objective("The false Heaven is fully exposed. Enter the gate at the end of the procession.")
	elif next_band >= 3:
		_player.set_objective("Keep walking to reveal the lie, or turn back to restore the light.")
	else:
		_player.set_objective("Walk toward the distant gate. Your direction controls what this place becomes.")


func _set_gate_enabled(enabled: bool, force: bool = false) -> void:
	if not force and enabled == _gate_enabled:
		return
	_gate_enabled = enabled
	if _gate_interaction == null:
		return
	_gate_interaction.monitoring = enabled
	_gate_interaction.monitorable = enabled
	_gate_interaction.collision_layer = 2 if enabled else 0
	if enabled:
		_gate_interaction.call("refresh_release_presentation")
	else:
		if _player != null and _player.has_method("clear_interaction_target"):
			_player.call("clear_interaction_target", _gate_interaction)


func _on_gate_activated(player: Node) -> void:
	if _transition_started:
		return
	_transition_started = true
	if player.has_method("set_cinematic_mode"):
		player.call("set_cinematic_mode", true)
	_audio.call("play_gate_open")
	SFXDirector.play_transition()
	MusicDirector.stop_music(2.5)
	var fade: Tween = create_tween()
	fade.tween_property(_transition_overlay, "color:a", 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	await fade.finished
	_audio.call("stop", 1.0)
	var nightclub_scene: PackedScene = StartupPreloader.get_preloaded_scene(NIGHTCLUB_SCENE_PATH)
	if nightclub_scene != null:
		get_tree().change_scene_to_packed(nightclub_scene)
	else:
		get_tree().change_scene_to_file(NIGHTCLUB_SCENE_PATH)


func _make_morph_material(
	light_color: Color,
	dark_color: Color,
	light_roughness: float,
	light_emission: Color = Color(0.0, 0.0, 0.0, 0.0),
	dark_emission: Color = Color(0.0, 0.0, 0.0, 0.0),
	light_energy: float = 0.0,
	dark_energy: float = 0.0
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = light_color
	material.roughness = light_roughness
	if light_color.a < 1.0 or dark_color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var uses_emission: bool = light_emission.a > 0.0 or dark_emission.a > 0.0
	if uses_emission:
		material.emission_enabled = true
		material.emission = light_emission
		material.emission_energy_multiplier = light_energy
	_morph_materials.append({
		"material": material,
		"light_color": light_color,
		"dark_color": dark_color,
		"light_roughness": light_roughness,
		"dark_roughness": maxf(0.12, light_roughness * 0.58),
		"light_emission": light_emission,
		"dark_emission": dark_emission,
		"light_energy": light_energy,
		"dark_energy": dark_energy
	})
	return material


func _create_static_box(
	body_name: String,
	body_position: Vector3,
	box_size: Vector3,
	material: Material
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = body_position
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
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


func _add_invisible_boundary(boundary_position: Vector3, boundary_size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = boundary_position
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = boundary_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_box(
	parent: Node3D,
	box_position: Vector3,
	box_size: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	return _add_mesh(parent, mesh, box_position, material)


func _add_mesh(
	parent: Node3D,
	mesh: Mesh,
	mesh_position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("outline_size", 4)
	return label
