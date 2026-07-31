extends Node

const TARGET_CHARACTER_HEIGHT: float = 1.86

var _player: CharacterBody3D
var _model_root: Node3D
var _skeleton: Skeleton3D
var _bone_indices: Dictionary = {}
var _walk_phase: float = 0.0


func _ready() -> void:
	_install_character.call_deferred()


func _process(delta: float) -> void:
	if _player == null or _skeleton == null or not is_instance_valid(_skeleton):
		return
	_animate_rig(delta)


func _install_character() -> void:
	for _frame_index: int in range(6):
		await get_tree().process_frame
	_player = get_parent() as CharacterBody3D
	if _player == null:
		return
	var visual_root: Node3D = _player.get_node_or_null("SkeletonVisual") as Node3D
	if visual_root == null:
		return
	var prototype: Node3D = StartupPreloader.get_player_character_prototype()
	if prototype == null:
		return
	var complete_model: Node3D = prototype.duplicate() as Node3D
	if complete_model == null:
		return
	_skeleton = _find_primary_skeleton(complete_model)
	if _skeleton == null:
		complete_model.free()
		return

	_hide_existing_meshes(visual_root)
	complete_model.name = "RiggedMainCharacter"
	visual_root.add_child(complete_model)
	_model_root = complete_model
	_normalize_character(complete_model)
	_prepare_materials(complete_model)
	_stop_embedded_animation_players(complete_model)
	_cache_animation_bones()


func _find_primary_skeleton(model: Node3D) -> Skeleton3D:
	var skeleton_nodes: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	var selected: Skeleton3D
	var largest_bone_count: int = 0
	for node: Node in skeleton_nodes:
		var candidate: Skeleton3D = node as Skeleton3D
		if candidate == null:
			continue
		if candidate.get_bone_count() <= largest_bone_count:
			continue
		selected = candidate
		largest_bone_count = candidate.get_bone_count()
	return selected


func _hide_existing_meshes(visual_root: Node3D) -> void:
	var old_meshes: Array[Node] = visual_root.find_children("*", "MeshInstance3D", true, false)
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


func _prepare_materials(model: Node3D) -> void:
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.visible = true
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var source_standard: StandardMaterial3D = source_material as StandardMaterial3D
			var material: StandardMaterial3D = StandardMaterial3D.new()
			if source_standard != null:
				material = source_standard.duplicate() as StandardMaterial3D
			if material == null:
				material = StandardMaterial3D.new()
			var source_color: Color = material.albedo_color
			material.albedo_color = source_color.lerp(Color("b8b1a5"), 0.46)
			material.roughness = maxf(material.roughness, 0.64)
			material.metallic = minf(material.metallic, 0.08)
			mesh_instance.set_surface_override_material(surface_index, material)


func _stop_embedded_animation_players(model: Node3D) -> void:
	var animation_nodes: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	for node: Node in animation_nodes:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		if animation_player != null:
			animation_player.stop()


func _cache_animation_bones() -> void:
	_bone_indices["hips"] = _find_bone(["hips", "pelvis", "root"])
	_bone_indices["spine"] = _find_bone(["spine1", "spine", "chest"])
	_bone_indices["head"] = _find_bone(["head"])
	_bone_indices["left_arm"] = _find_bone(["leftupperarm", "upperarml", "armleft", "lupperarm"])
	_bone_indices["right_arm"] = _find_bone(["rightupperarm", "upperarmr", "armright", "rupperarm"])
	_bone_indices["left_forearm"] = _find_bone(["leftforearm", "lowerarml", "forearml"])
	_bone_indices["right_forearm"] = _find_bone(["rightforearm", "lowerarmr", "forearmr"])
	_bone_indices["left_thigh"] = _find_bone(["leftupleg", "leftupperleg", "thighl", "upperlegl"])
	_bone_indices["right_thigh"] = _find_bone(["rightupleg", "rightupperleg", "thighr", "upperlegr"])
	_bone_indices["left_shin"] = _find_bone(["leftleg", "leftlowerleg", "calfl", "shinl"])
	_bone_indices["right_shin"] = _find_bone(["rightleg", "rightlowerleg", "calfr", "shinr"])


func _find_bone(aliases: Array[String]) -> int:
	if _skeleton == null:
		return -1
	for bone_index: int in range(_skeleton.get_bone_count()):
		var normalized_name: String = _normalize_bone_name(str(_skeleton.get_bone_name(bone_index)))
		for alias: String in aliases:
			if normalized_name.contains(_normalize_bone_name(alias)):
				return bone_index
	return -1


func _normalize_bone_name(bone_name: String) -> String:
	return bone_name.to_lower().replace("mixamorig", "").replace("_", "").replace(".", "").replace("-", "").replace(" ", "")


func _animate_rig(delta: float) -> void:
	var planar_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var sprint_speed_value: float = maxf(0.1, float(_player.get("sprint_speed")))
	var movement_amount: float = clampf(planar_speed / sprint_speed_value, 0.0, 1.0)
	_walk_phase += delta * lerpf(2.0, 9.4, movement_amount)
	var swing: float = sin(_walk_phase) * 0.62 * movement_amount
	var idle_breath: float = sin(float(Time.get_ticks_msec()) * 0.0018) * 0.035
	var airborne_amount: float = 0.0 if _player.is_on_floor() else 1.0

	_set_bone_rotation("left_arm", Vector3.RIGHT, -swing * 0.82 - airborne_amount * 0.18)
	_set_bone_rotation("right_arm", Vector3.RIGHT, swing * 0.82 - airborne_amount * 0.18)
	_set_bone_rotation("left_forearm", Vector3.RIGHT, maxf(0.0, swing) * 0.24)
	_set_bone_rotation("right_forearm", Vector3.RIGHT, maxf(0.0, -swing) * 0.24)
	_set_bone_rotation("left_thigh", Vector3.RIGHT, swing * 0.74 - airborne_amount * 0.22)
	_set_bone_rotation("right_thigh", Vector3.RIGHT, -swing * 0.74 - airborne_amount * 0.22)
	_set_bone_rotation("left_shin", Vector3.RIGHT, maxf(0.0, -swing) * 0.46 + airborne_amount * 0.24)
	_set_bone_rotation("right_shin", Vector3.RIGHT, maxf(0.0, swing) * 0.46 + airborne_amount * 0.24)
	_set_bone_rotation("spine", Vector3.FORWARD, idle_breath + sin(_walk_phase * 2.0) * 0.025 * movement_amount)
	_set_bone_rotation("head", Vector3.UP, sin(_walk_phase * 0.42) * 0.035 * (1.0 - movement_amount))

	var hips_index: int = int(_bone_indices.get("hips", -1))
	if hips_index >= 0:
		_skeleton.set_bone_pose_position(
			hips_index,
			Vector3(0.0, absf(sin(_walk_phase * 2.0)) * 0.025 * movement_amount, 0.0)
		)


func _set_bone_rotation(key: String, axis: Vector3, angle: float) -> void:
	var bone_index: int = int(_bone_indices.get(key, -1))
	if bone_index < 0:
		return
	_skeleton.set_bone_pose_rotation(bone_index, Quaternion(axis, angle))
