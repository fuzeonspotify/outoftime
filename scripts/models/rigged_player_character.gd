extends Node

const TARGET_CHARACTER_HEIGHT: float = 1.88

var _player: CharacterBody3D
var _model_root: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _active_animation: StringName = &""
var _bone_indices: Dictionary = {}
var _walk_phase: float = 0.0


func _ready() -> void:
	_install_character.call_deferred()


func _process(delta: float) -> void:
	if (
		_player == null
		or _model_root == null
		or _skeleton == null
		or not is_instance_valid(_model_root)
		or not is_instance_valid(_skeleton)
	):
		return
	if _animation_player != null and is_instance_valid(_animation_player):
		_update_embedded_animation()
	else:
		_animate_rig_fallback(delta)


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
	complete_model.name = "RiggedMainSkeleton"
	visual_root.add_child(complete_model)
	_model_root = complete_model
	_normalize_character(complete_model)
	_prepare_materials(complete_model)
	_animation_player = _find_primary_animation_player(complete_model)
	_cache_animation_bones()
	_update_embedded_animation(true)


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


func _find_primary_animation_player(model: Node3D) -> AnimationPlayer:
	var animation_nodes: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	var selected: AnimationPlayer
	var largest_animation_count: int = 0
	for node: Node in animation_nodes:
		var candidate: AnimationPlayer = node as AnimationPlayer
		if candidate == null:
			continue
		var animation_count: int = candidate.get_animation_list().size()
		if animation_count <= largest_animation_count:
			continue
		selected = candidate
		largest_animation_count = animation_count
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
			if source_standard == null:
				continue
			var material: StandardMaterial3D = source_standard.duplicate() as StandardMaterial3D
			if material == null:
				continue
			material.roughness = maxf(material.roughness, 0.56)
			material.metallic = minf(material.metallic, 0.10)
			mesh_instance.set_surface_override_material(surface_index, material)


func _update_embedded_animation(force: bool = false) -> void:
	if _animation_player == null:
		return
	var planar_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var target_keywords: Array[String] = ["idle", "standing"]
	var playback_speed: float = 1.0
	if not _player.is_on_floor():
		target_keywords = ["jump", "fall", "air"]
		playback_speed = 1.0
	elif planar_speed > float(_player.get("walk_speed")) + 0.8:
		target_keywords = ["run", "sprint"]
		playback_speed = clampf(planar_speed / 7.0, 0.85, 1.35)
	elif planar_speed > 0.20:
		target_keywords = ["walk", "move"]
		playback_speed = clampf(planar_speed / 4.5, 0.72, 1.25)

	var target_animation: StringName = _find_animation(target_keywords)
	if target_animation == &"":
		target_animation = _first_usable_animation()
	if target_animation == &"":
		return
	_animation_player.speed_scale = playback_speed
	if not force and target_animation == _active_animation and _animation_player.is_playing():
		return
	_active_animation = target_animation
	var animation: Animation = _animation_player.get_animation(target_animation)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(target_animation, 0.18, 1.0)


func _find_animation(keywords: Array[String]) -> StringName:
	if _animation_player == null:
		return &""
	for animation_name_variant: Variant in _animation_player.get_animation_list():
		var animation_name: StringName = StringName(str(animation_name_variant))
		var descriptor: String = str(animation_name).to_lower()
		if descriptor == "reset":
			continue
		for keyword: String in keywords:
			if descriptor.contains(keyword):
				return animation_name
	return &""


func _first_usable_animation() -> StringName:
	if _animation_player == null:
		return &""
	for animation_name_variant: Variant in _animation_player.get_animation_list():
		var animation_name: StringName = StringName(str(animation_name_variant))
		if str(animation_name).to_lower() != "reset":
			return animation_name
	return &""


func _cache_animation_bones() -> void:
	_bone_indices["hips"] = _find_bone(["hips", "pelvis", "root"])
	_bone_indices["spine"] = _find_bone(["spine1", "spine", "chest"])
	_bone_indices["head"] = _find_bone(["head"])
	_bone_indices["left_arm"] = _find_bone(["leftupperarm", "upperarml", "armleft", "lupperarm"])
	_bone_indices["right_arm"] = _find_bone(["rightupperarm", "upperarmr", "armright", "rupperarm"])
	_bone_indices["left_thigh"] = _find_bone(["leftupleg", "leftupperleg", "thighl", "upperlegl"])
	_bone_indices["right_thigh"] = _find_bone(["rightupleg", "rightupperleg", "thighr", "upperlegr"])


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


func _animate_rig_fallback(delta: float) -> void:
	var planar_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var sprint_speed_value: float = maxf(0.1, float(_player.get("sprint_speed")))
	var movement_amount: float = clampf(planar_speed / sprint_speed_value, 0.0, 1.0)
	_walk_phase += delta * lerpf(2.0, 9.4, movement_amount)
	var swing: float = sin(_walk_phase) * 0.62 * movement_amount
	_set_bone_rotation("left_arm", Vector3.RIGHT, -swing * 0.82)
	_set_bone_rotation("right_arm", Vector3.RIGHT, swing * 0.82)
	_set_bone_rotation("left_thigh", Vector3.RIGHT, swing * 0.74)
	_set_bone_rotation("right_thigh", Vector3.RIGHT, -swing * 0.74)
	_set_bone_rotation("spine", Vector3.FORWARD, sin(_walk_phase * 2.0) * 0.025 * movement_amount)
	_set_bone_rotation("head", Vector3.UP, sin(_walk_phase * 0.42) * 0.035 * (1.0 - movement_amount))


func _set_bone_rotation(key: String, axis: Vector3, angle: float) -> void:
	var bone_index: int = int(_bone_indices.get(key, -1))
	if bone_index < 0:
		return
	_skeleton.set_bone_pose_rotation(bone_index, Quaternion(axis, angle))
