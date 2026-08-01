extends Node

const TARGET_CHARACTER_HEIGHT: float = 2.10
# The Sketchfab mesh accessor is authored at 1.70 units tall. Its Armature_25
# parent carries a 0.01 conversion scale for centimeter-based bones, so a
# hierarchy-transformed AABB reports roughly 0.017 and must not drive sizing.
const SOURCE_MESH_HEIGHT: float = 1.70
const SOURCE_MESH_CENTER_X: float = 0.0884
const MIN_CHARACTER_SCALE: float = 0.50
const MAX_CHARACTER_SCALE: float = 2.00

var _records: Array[Dictionary] = []
var _elapsed: float = 0.0


func _ready() -> void:
	_install_characters.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	for record: Dictionary in _records:
		_update_character(record)


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
	for woman: Node3D in woman_nodes:
		_install_on_woman(woman, prototype)


func _install_on_woman(woman: Node3D, prototype: Node3D) -> void:
	var complete_model: Node3D = prototype.duplicate() as Node3D
	if complete_model == null:
		return
	var skeleton: Skeleton3D = _find_primary_skeleton(complete_model)
	if skeleton == null:
		complete_model.free()
		return

	# The source model only contains a RunFast clip. Keep every imported
	# AnimationPlayer disabled and animate small pose offsets ourselves so the
	# skin never receives the clip's large translation or scale tracks.
	_prepare_imported_rig_for_idle(complete_model, skeleton)

	_hide_existing_meshes(woman)
	complete_model.name = "RiggedGhostWomanFullBody"
	woman.add_child(complete_model)
	_normalize_character(complete_model)
	_preserve_and_grade_materials(complete_model)
	_add_spectral_lighting(woman)

	var record: Dictionary = {
		"model": complete_model,
		"skeleton": skeleton,
		"base_position": complete_model.position,
		"base_rotation": complete_model.rotation_degrees,
		"phase": float(_records.size()) * 0.83,
		"spine": _find_bone(skeleton, ["spine02", "spine01", "spine"]),
		"head": _find_bone(skeleton, ["head"]),
		"left_arm": _find_bone(skeleton, ["leftarm"]),
		"right_arm": _find_bone(skeleton, ["rightarm"]),
		"left_forearm": _find_bone(skeleton, ["leftforearm"]),
		"right_forearm": _find_bone(skeleton, ["rightforearm"])
	}
	_apply_idle_pose(record)
	_records.append(record)


func _prepare_imported_rig_for_idle(model: Node3D, skeleton: Skeleton3D) -> void:
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
	# show_rest_only must be false for the safe pose offsets below to display.
	# Only bone rotations are changed; positions and scales remain at rest.
	skeleton.show_rest_only = false


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
	# Use the authored POSITION accessor height, not the converted armature
	# hierarchy. This evaluates to about 1.235 instead of the broken 123.5 scale.
	var scale_factor: float = clampf(
		TARGET_CHARACTER_HEIGHT / SOURCE_MESH_HEIGHT,
		MIN_CHARACTER_SCALE,
		MAX_CHARACTER_SCALE
	)
	model.scale = Vector3.ONE * scale_factor
	model.position = Vector3(-SOURCE_MESH_CENTER_X * scale_factor, 0.0, 0.0)
	# The previous 180-degree correction pointed her away from the player.
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


func _update_character(record: Dictionary) -> void:
	var model: Node3D = record.get("model") as Node3D
	var skeleton: Skeleton3D = record.get("skeleton") as Skeleton3D
	if (
		model == null
		or skeleton == null
		or not is_instance_valid(model)
		or not is_instance_valid(skeleton)
	):
		return

	var base_position: Vector3 = record.get("base_position", Vector3.ZERO)
	var base_rotation: Vector3 = record.get("base_rotation", Vector3.ZERO)
	var phase: float = float(record.get("phase", 0.0))
	model.position = base_position + Vector3.UP * sin(_elapsed * 0.72 + phase) * 0.018
	model.rotation_degrees = base_rotation + Vector3(
		sin(_elapsed * 0.31 + phase) * 0.22,
		sin(_elapsed * 0.24 + phase) * 0.55,
		sin(_elapsed * 0.29 + phase) * 0.20
	)
	_apply_idle_pose(record)


func _apply_idle_pose(record: Dictionary) -> void:
	var skeleton: Skeleton3D = record.get("skeleton") as Skeleton3D
	if skeleton == null or not is_instance_valid(skeleton):
		return

	var phase: float = float(record.get("phase", 0.0))
	var breath: float = sin(_elapsed * 1.05 + phase)
	var slow_drift: float = sin(_elapsed * 0.41 + phase)

	# Small rotations relative to each bone's authored rest transform create a
	# relaxed, bowed horror idle without touching bone position or scale tracks.
	_set_pose_rotation(
		skeleton,
		int(record.get("spine", -1)),
		Quaternion(Vector3.RIGHT, deg_to_rad(-3.0 + breath * 0.65))
	)
	_set_pose_rotation(
		skeleton,
		int(record.get("head", -1)),
		Quaternion(Vector3.RIGHT, deg_to_rad(-5.0 + breath * 0.45))
		* Quaternion(Vector3.UP, deg_to_rad(slow_drift * 2.2))
	)
	_set_pose_rotation(
		skeleton,
		int(record.get("left_arm", -1)),
		Quaternion(Vector3.FORWARD, deg_to_rad(-4.5 + breath * 0.35))
	)
	_set_pose_rotation(
		skeleton,
		int(record.get("right_arm", -1)),
		Quaternion(Vector3.FORWARD, deg_to_rad(4.5 - breath * 0.35))
	)
	_set_pose_rotation(
		skeleton,
		int(record.get("left_forearm", -1)),
		Quaternion(Vector3.RIGHT, deg_to_rad(-2.5 + slow_drift * 0.35))
	)
	_set_pose_rotation(
		skeleton,
		int(record.get("right_forearm", -1)),
		Quaternion(Vector3.RIGHT, deg_to_rad(-2.5 - slow_drift * 0.35))
	)


func _set_pose_rotation(skeleton: Skeleton3D, bone_index: int, rotation: Quaternion) -> void:
	if bone_index < 0:
		return
	skeleton.set_bone_pose_rotation(bone_index, rotation)
