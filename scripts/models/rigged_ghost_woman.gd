extends Node

const TARGET_CHARACTER_HEIGHT: float = 2.16

var _records: Array[Dictionary] = []
var _elapsed: float = 0.0


func _ready() -> void:
	_install_characters.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	for record: Dictionary in _records:
		_update_character(record, delta)


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

	_hide_existing_meshes(woman)
	complete_model.name = "RiggedGhostWoman"
	woman.add_child(complete_model)
	_normalize_character(complete_model)
	_apply_spectral_materials(complete_model)
	_stop_embedded_animation_players(complete_model)
	_add_spectral_light(woman)
	_records.append({
		"model": complete_model,
		"skeleton": skeleton,
		"base_position": complete_model.position,
		"phase": float(_records.size()) * 0.83,
		"spine": _find_bone(skeleton, ["spine1", "spine", "chest"]),
		"head": _find_bone(skeleton, ["head"]),
		"left_arm": _find_bone(skeleton, ["leftupperarm", "upperarml", "armleft"]),
		"right_arm": _find_bone(skeleton, ["rightupperarm", "upperarmr", "armright"]),
		"left_forearm": _find_bone(skeleton, ["leftforearm", "lowerarml", "forearml"]),
		"right_forearm": _find_bone(skeleton, ["rightforearm", "lowerarmr", "forearmr"])
	})


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


func _hide_existing_meshes(woman: Node3D) -> void:
	var old_meshes: Array[Node] = woman.find_children("*", "MeshInstance3D", true, false)
	for node: Node in old_meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _normalize_character(model: Node3D) -> void:
	var bounds: AABB = _calculate_local_bounds(model)
	if bounds.size.y <= 0.001:
		return
	var scale_factor: float = TARGET_CHARACTER_HEIGHT / bounds.size.y
	model.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	model.position = Vector3(
		-center.x * scale_factor,
		-bounds.position.y * scale_factor,
		-center.z * scale_factor
	)
	model.rotation_degrees.y = 180.0


func _calculate_local_bounds(model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
	return bounds


func _apply_spectral_materials(model: Node3D) -> void:
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.visible = true
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var source_standard: StandardMaterial3D = source_material as StandardMaterial3D
			var spectral: StandardMaterial3D = StandardMaterial3D.new()
			if source_standard != null:
				spectral = source_standard.duplicate() as StandardMaterial3D
			if spectral == null:
				spectral = StandardMaterial3D.new()
			var source_color: Color = spectral.albedo_color
			var ghost_color: Color = source_color.lerp(Color("817694"), 0.42)
			spectral.albedo_color = Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.76)
			spectral.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			spectral.roughness = maxf(spectral.roughness, 0.46)
			spectral.emission_enabled = true
			spectral.emission = ghost_color.darkened(0.36)
			spectral.emission_energy_multiplier = 0.42
			mesh_instance.set_surface_override_material(surface_index, spectral)


func _stop_embedded_animation_players(model: Node3D) -> void:
	var animation_nodes: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	for node: Node in animation_nodes:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		if animation_player != null:
			animation_player.stop()


func _add_spectral_light(woman: Node3D) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "RiggedGhostWomanLight"
	light.position = Vector3(0.0, 1.72, -0.48)
	light.light_color = Color("9584bd")
	light.light_energy = 0.86
	light.omni_range = 4.2
	woman.add_child(light)


func _find_bone(skeleton: Skeleton3D, aliases: Array[String]) -> int:
	for bone_index: int in range(skeleton.get_bone_count()):
		var normalized_name: String = _normalize_bone_name(str(skeleton.get_bone_name(bone_index)))
		for alias: String in aliases:
			if normalized_name.contains(_normalize_bone_name(alias)):
				return bone_index
	return -1


func _normalize_bone_name(bone_name: String) -> String:
	return bone_name.to_lower().replace("mixamorig", "").replace("_", "").replace(".", "").replace("-", "").replace(" ", "")


func _update_character(record: Dictionary, _delta: float) -> void:
	var model: Node3D = record.get("model") as Node3D
	var skeleton: Skeleton3D = record.get("skeleton") as Skeleton3D
	if model == null or skeleton == null or not is_instance_valid(model) or not is_instance_valid(skeleton):
		return
	var base_position: Vector3 = record.get("base_position", Vector3.ZERO)
	var phase: float = float(record.get("phase", 0.0))
	model.position = base_position + Vector3.UP * sin(_elapsed * 0.78 + phase) * 0.045
	model.rotation_degrees.z = sin(_elapsed * 0.34 + phase) * 0.65

	_set_bone_rotation(skeleton, int(record.get("spine", -1)), Vector3.FORWARD, sin(_elapsed * 0.62 + phase) * 0.045)
	_set_bone_rotation(skeleton, int(record.get("head", -1)), Vector3.UP, sin(_elapsed * 0.41 + phase) * 0.085)
	_set_bone_rotation(skeleton, int(record.get("left_arm", -1)), Vector3.FORWARD, -0.18 + sin(_elapsed * 0.52 + phase) * 0.035)
	_set_bone_rotation(skeleton, int(record.get("right_arm", -1)), Vector3.FORWARD, 0.18 - sin(_elapsed * 0.52 + phase) * 0.035)
	_set_bone_rotation(skeleton, int(record.get("left_forearm", -1)), Vector3.RIGHT, -0.10)
	_set_bone_rotation(skeleton, int(record.get("right_forearm", -1)), Vector3.RIGHT, -0.10)


func _set_bone_rotation(
	skeleton: Skeleton3D,
	bone_index: int,
	axis: Vector3,
	angle: float
) -> void:
	if bone_index < 0:
		return
	skeleton.set_bone_pose_rotation(bone_index, Quaternion(axis, angle))
