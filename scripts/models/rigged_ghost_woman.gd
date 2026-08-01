extends Node

const TARGET_CHARACTER_HEIGHT: float = 2.10
const SOURCE_MESH_HEIGHT: float = 1.70
const SOURCE_MESH_CENTER_X: float = 0.0884
const MIN_CHARACTER_SCALE: float = 0.50
const MAX_CHARACTER_SCALE: float = 2.00
const IDLE_ANIMATION_NAME: StringName = &"hooded_woman_idle"
const IDLE_LENGTH: float = 8.0
const IDLE_KEY_COUNT: int = 17


func _ready() -> void:
	_install_characters.call_deferred()


func _install_characters() -> void:
	for _frame_index: int in range(8):
		await get_tree().process_frame
	var scene_root: Node3D = get_parent() as Node3D
	if scene_root == null:
		return
	var prototype: Node3D = StartupPreloader.get_ghost_woman_prototype()
	if prototype == null:
		return

	var woman_nodes: Array[Node3D] = []
	var cemetery_woman: Node3D = scene_root.get_node_or_null("MysteriousWoman") as Node3D
	if cemetery_woman != null:
		woman_nodes.append(cemetery_woman)
	var chamber_woman: Node3D = scene_root.get_node_or_null("WomanAtDais") as Node3D
	if chamber_woman != null:
		woman_nodes.append(chamber_woman)

	for woman_index: int in range(woman_nodes.size()):
		_install_on_woman(woman_nodes[woman_index], prototype, woman_index)


func _install_on_woman(woman: Node3D, prototype: Node3D, woman_index: int) -> void:
	var complete_model: Node3D = prototype.duplicate() as Node3D
	if complete_model == null:
		return
	var skeleton: Skeleton3D = _find_primary_skeleton(complete_model)
	if skeleton == null:
		complete_model.free()
		return

	_disable_imported_run_animation(complete_model, skeleton)
	_hide_existing_meshes(woman)

	complete_model.name = "RiggedGhostWomanFullBody"
	woman.add_child(complete_model)
	_normalize_character(complete_model)
	_preserve_and_grade_materials(complete_model)
	_add_spectral_lighting(woman)
	_create_true_idle_animation(complete_model, skeleton, woman_index)


func _disable_imported_run_animation(model: Node3D, skeleton: Skeleton3D) -> void:
	# The Sketchfab source contains only RunFast. It remains disabled permanently;
	# the new AnimationPlayer below owns a dedicated, safe idle clip.
	var animation_nodes: Array[Node] = model.find_children(
		"*",
		"AnimationPlayer",
		true,
		false
	)
	for node: Node in animation_nodes:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		if animation_player == null:
			continue
		animation_player.stop(false)
		animation_player.process_mode = Node.PROCESS_MODE_DISABLED

	skeleton.reset_bone_poses()
	skeleton.show_rest_only = false


func _create_true_idle_animation(
	model: Node3D,
	skeleton: Skeleton3D,
	woman_index: int
) -> void:
	var idle_player: AnimationPlayer = AnimationPlayer.new()
	idle_player.name = "HoodedWomanIdleAnimationPlayer"
	idle_player.root_node = NodePath("..")
	model.add_child(idle_player)

	var idle_library: AnimationLibrary = AnimationLibrary.new()
	var idle_animation: Animation = Animation.new()
	idle_animation.length = IDLE_LENGTH
	idle_animation.loop_mode = Animation.LOOP_LINEAR

	# Each record is [bone aliases, base Euler degrees, breathing amplitude,
	# horizontal sway amplitude, secondary phase offset]. The animation is
	# intentionally asymmetric so it reads as a living stance, not a sine-wave
	# mannequin or a whole-model hover.
	var bone_motion_records: Array[Dictionary] = [
		{
			"aliases": ["hips"],
			"base": Vector3(0.2, 0.0, -0.5),
			"breath": Vector3(0.35, 0.20, 0.30),
			"sway": Vector3(0.20, 0.65, 0.45),
			"phase": 0.20
		},
		{
			"aliases": ["spine02"],
			"base": Vector3(-1.8, 0.0, 0.3),
			"breath": Vector3(0.62, 0.18, 0.20),
			"sway": Vector3(0.15, 0.55, 0.48),
			"phase": 0.00
		},
		{
			"aliases": ["spine01"],
			"base": Vector3(-2.7, 0.0, -0.2),
			"breath": Vector3(0.86, 0.22, 0.25),
			"sway": Vector3(0.18, 0.82, 0.58),
			"phase": 0.12
		},
		{
			"aliases": ["spine"],
			"base": Vector3(-2.2, 0.0, 0.2),
			"breath": Vector3(1.05, 0.28, 0.30),
			"sway": Vector3(0.22, 1.05, 0.64),
			"phase": 0.26
		},
		{
			"aliases": ["neck"],
			"base": Vector3(-3.2, 0.0, 0.0),
			"breath": Vector3(0.46, 0.20, 0.20),
			"sway": Vector3(0.22, 1.28, 0.62),
			"phase": 0.55
		},
		{
			"aliases": ["head"],
			"base": Vector3(-5.8, -0.8, 0.8),
			"breath": Vector3(0.55, 0.22, 0.18),
			"sway": Vector3(0.70, 3.40, 1.15),
			"phase": 0.92
		},
		{
			"aliases": ["leftshoulder"],
			"base": Vector3(0.0, -1.0, -2.2),
			"breath": Vector3(0.28, 0.22, 0.72),
			"sway": Vector3(0.20, 0.50, 0.62),
			"phase": 0.22
		},
		{
			"aliases": ["rightshoulder"],
			"base": Vector3(0.0, 1.0, 2.8),
			"breath": Vector3(0.26, 0.20, -0.66),
			"sway": Vector3(0.18, -0.46, -0.58),
			"phase": 0.68
		},
		{
			"aliases": ["leftarm"],
			"base": Vector3(-1.2, -1.4, -5.8),
			"breath": Vector3(0.32, 0.26, 0.52),
			"sway": Vector3(0.42, 0.64, 0.88),
			"phase": 0.36
		},
		{
			"aliases": ["rightarm"],
			"base": Vector3(-0.6, 1.0, 4.6),
			"breath": Vector3(0.28, -0.22, -0.44),
			"sway": Vector3(0.36, -0.58, -0.78),
			"phase": 0.78
		},
		{
			"aliases": ["leftforearm"],
			"base": Vector3(-3.8, 0.5, -1.4),
			"breath": Vector3(0.34, 0.18, 0.22),
			"sway": Vector3(0.72, 0.42, 0.38),
			"phase": 0.58
		},
		{
			"aliases": ["rightforearm"],
			"base": Vector3(-2.7, -0.4, 1.0),
			"breath": Vector3(0.30, -0.16, -0.18),
			"sway": Vector3(0.62, -0.38, -0.34),
			"phase": 0.94
		}
	]

	for motion_record: Dictionary in bone_motion_records:
		var aliases_variant: Variant = motion_record.get("aliases", [])
		if not (aliases_variant is Array):
			continue
		var aliases: Array[String] = []
		for alias_variant: Variant in aliases_variant as Array:
			aliases.append(str(alias_variant))
		var bone_index: int = _find_bone(skeleton, aliases)
		if bone_index < 0:
			continue
		_add_idle_bone_track(
			idle_animation,
			model,
			skeleton,
			bone_index,
			motion_record.get("base", Vector3.ZERO),
			motion_record.get("breath", Vector3.ZERO),
			motion_record.get("sway", Vector3.ZERO),
			float(motion_record.get("phase", 0.0))
		)

	idle_library.add_animation(IDLE_ANIMATION_NAME, idle_animation)
	idle_player.add_animation_library(&"", idle_library)
	idle_player.play(IDLE_ANIMATION_NAME, 0.0, 1.0 + float(woman_index) * 0.025)
	idle_player.seek(fmod(float(woman_index) * 2.37, IDLE_LENGTH), true)


func _add_idle_bone_track(
	animation: Animation,
	model: Node3D,
	skeleton: Skeleton3D,
	bone_index: int,
	base_degrees: Vector3,
	breath_degrees: Vector3,
	sway_degrees: Vector3,
	phase_offset: float
) -> void:
	var skeleton_path: NodePath = model.get_path_to(skeleton)
	var bone_name: String = str(skeleton.get_bone_name(bone_index))
	var track_path: NodePath = NodePath("%s:%s" % [str(skeleton_path), bone_name])
	var track_index: int = animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track_index, track_path)
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)

	for key_index: int in range(IDLE_KEY_COUNT):
		var normalized_time: float = float(key_index) / float(IDLE_KEY_COUNT - 1)
		var key_time: float = normalized_time * IDLE_LENGTH
		var cycle: float = normalized_time * TAU
		var breath_wave: float = sin(cycle * 2.0 + phase_offset)
		var slow_sway: float = sin(cycle + phase_offset * 1.7)
		var micro_motion: float = sin(cycle * 3.0 + phase_offset * 2.4) * 0.18
		var euler_degrees: Vector3 = (
			base_degrees
			+ breath_degrees * breath_wave
			+ sway_degrees * slow_sway
			+ Vector3(micro_motion, micro_motion * 0.55, -micro_motion * 0.35)
		)
		var rotation: Quaternion = (
			Quaternion(Vector3.RIGHT, deg_to_rad(euler_degrees.x))
			* Quaternion(Vector3.UP, deg_to_rad(euler_degrees.y))
			* Quaternion(Vector3.FORWARD, deg_to_rad(euler_degrees.z))
		)
		animation.track_insert_key(track_index, key_time, rotation)


func _find_primary_skeleton(model: Node3D) -> Skeleton3D:
	var skeleton_nodes: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	var selected: Skeleton3D
	var largest_bone_count: int = 0
	for node: Node in skeleton_nodes:
		var candidate: Skeleton3D = node as Skeleton3D
		if candidate == null or candidate.get_bone_count() <= largest_bone_count:
			continue
		selected = candidate
		largest_bone_count = candidate.get_bone_count()
	return selected


func _find_bone(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for alias: String in aliases:
		var normalized_alias: String = _normalize_bone_name(alias)
		for bone_index: int in range(skeleton.get_bone_count()):
			var normalized_name: String = _normalize_bone_name(
				str(skeleton.get_bone_name(bone_index))
			)
			if normalized_name == normalized_alias or normalized_name.contains(normalized_alias):
				return bone_index
	return -1


func _normalize_bone_name(bone_name: String) -> String:
	return bone_name.to_lower().replace("mixamorig", "").replace("_", "").replace(".", "").replace("-", "").replace(" ", "")


func _hide_existing_meshes(woman: Node3D) -> void:
	var old_meshes: Array[Node] = woman.find_children("*", "MeshInstance3D", true, false)
	for node: Node in old_meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _normalize_character(model: Node3D) -> void:
	var scale_factor: float = clampf(
		TARGET_CHARACTER_HEIGHT / SOURCE_MESH_HEIGHT,
		MIN_CHARACTER_SCALE,
		MAX_CHARACTER_SCALE
	)
	model.scale = Vector3.ONE * scale_factor
	model.position = Vector3(-SOURCE_MESH_CENTER_X * scale_factor, 0.0, 0.0)
	model.rotation_degrees = Vector3.ZERO


func _preserve_and_grade_materials(model: Node3D) -> void:
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.visible = true
		mesh_instance.material_override = null
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var source_standard: StandardMaterial3D = source_material as StandardMaterial3D
			if source_standard == null:
				continue
			var graded: StandardMaterial3D = source_standard.duplicate() as StandardMaterial3D
			if graded == null:
				continue
			var source_color: Color = graded.albedo_color
			graded.albedo_color = source_color.lerp(Color("a69bb5"), 0.10)
			graded.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			graded.cull_mode = BaseMaterial3D.CULL_DISABLED
			graded.roughness = clampf(graded.roughness, 0.38, 0.86)
			graded.emission_enabled = true
			graded.emission = source_color.lerp(Color("76658f"), 0.38).darkened(0.40)
			graded.emission_energy_multiplier = 0.20
			mesh_instance.set_surface_override_material(surface_index, graded)


func _add_spectral_lighting(woman: Node3D) -> void:
	var old_lights: Array[Node] = woman.find_children(
		"RiggedGhostWoman*Light",
		"OmniLight3D",
		true,
		false
	)
	for node: Node in old_lights:
		node.queue_free()

	var back_light: OmniLight3D = OmniLight3D.new()
	back_light.name = "RiggedGhostWomanBackLight"
	back_light.position = Vector3(0.0, 1.45, 0.72)
	back_light.light_color = Color("967cc4")
	back_light.light_energy = 1.35
	back_light.omni_range = 5.2
	woman.add_child(back_light)

	var face_light: OmniLight3D = OmniLight3D.new()
	face_light.name = "RiggedGhostWomanFaceLight"
	face_light.position = Vector3(0.0, 1.62, -0.58)
	face_light.light_color = Color("d7c9e8")
	face_light.light_energy = 0.72
	face_light.omni_range = 3.2
	woman.add_child(face_light)
