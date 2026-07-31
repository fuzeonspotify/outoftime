extends Node

const TARGET_CHARACTER_HEIGHT: float = 2.10

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
	complete_model.name = "RiggedGhostWomanFullBody"
	woman.add_child(complete_model)
	_normalize_character(complete_model)
	_preserve_and_grade_materials(complete_model)
	var animation_player: AnimationPlayer = _find_primary_animation_player(complete_model)
	var idle_animation: StringName = _start_idle_animation(animation_player)
	_add_spectral_lighting(woman)
	_records.append({
		"model": complete_model,
		"skeleton": skeleton,
		"animation_player": animation_player,
		"idle_animation": idle_animation,
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


func _preserve_and_grade_materials(model: Node3D) -> void:
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
			var graded: StandardMaterial3D = source_standard.duplicate() as StandardMaterial3D
			if graded == null:
				continue
			var source_color: Color = graded.albedo_color
			graded.albedo_color = source_color.lerp(Color("8d849e"), 0.16)
			graded.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			graded.roughness = clampf(graded.roughness, 0.38, 0.86)
			graded.emission_enabled = true
			graded.emission = source_color.lerp(Color("675b84"), 0.44).darkened(0.52)
			graded.emission_energy_multiplier = 0.16
			mesh_instance.set_surface_override_material(surface_index, graded)


func _start_idle_animation(animation_player: AnimationPlayer) -> StringName:
	if animation_player == null:
		return &""
	var selected: StringName = _find_animation(animation_player, ["idle", "standing", "breath"])
	if selected == &"":
		selected = _first_usable_animation(animation_player)
	if selected == &"":
		return &""
	var animation: Animation = animation_player.get_animation(selected)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(selected, 0.20, 0.72)
	return selected


func _find_animation(animation_player: AnimationPlayer, keywords: Array[String]) -> StringName:
	for animation_name_variant: Variant in animation_player.get_animation_list():
		var animation_name: StringName = StringName(str(animation_name_variant))
		var descriptor: String = str(animation_name).to_lower()
		if descriptor == "reset":
			continue
		for keyword: String in keywords:
			if descriptor.contains(keyword):
				return animation_name
	return &""


func _first_usable_animation(animation_player: AnimationPlayer) -> StringName:
	for animation_name_variant: Variant in animation_player.get_animation_list():
		var animation_name: StringName = StringName(str(animation_name_variant))
		if str(animation_name).to_lower() != "reset":
			return animation_name
	return &""


func _add_spectral_lighting(woman: Node3D) -> void:
	var back_light: OmniLight3D = OmniLight3D.new()
	back_light.name = "RiggedGhostWomanBackLight"
	back_light.position = Vector3(0.0, 1.55, 0.72)
	back_light.light_color = Color("806ca8")
	back_light.light_energy = 1.08
	back_light.omni_range = 4.8
	woman.add_child(back_light)
	var face_light: OmniLight3D = OmniLight3D.new()
	face_light.name = "RiggedGhostWomanFaceLight"
	face_light.position = Vector3(0.0, 1.78, -0.54)
	face_light.light_color = Color("c1b4d5")
	face_light.light_energy = 0.48
	face_light.omni_range = 2.8
	woman.add_child(face_light)


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
	model.position = base_position + Vector3.UP * sin(_elapsed * 0.72 + phase) * 0.030
	model.rotation_degrees.z = sin(_elapsed * 0.30 + phase) * 0.42

	var animation_player: AnimationPlayer = record.get("animation_player") as AnimationPlayer
	if animation_player != null and animation_player.is_playing():
		return
	_set_bone_rotation(skeleton, int(record.get("spine", -1)), Vector3.FORWARD, sin(_elapsed * 0.55 + phase) * 0.038)
	_set_bone_rotation(skeleton, int(record.get("head", -1)), Vector3.UP, sin(_elapsed * 0.38 + phase) * 0.070)
	_set_bone_rotation(skeleton, int(record.get("left_arm", -1)), Vector3.FORWARD, -0.14 + sin(_elapsed * 0.48 + phase) * 0.028)
	_set_bone_rotation(skeleton, int(record.get("right_arm", -1)), Vector3.FORWARD, 0.14 - sin(_elapsed * 0.48 + phase) * 0.028)
	_set_bone_rotation(skeleton, int(record.get("left_forearm", -1)), Vector3.RIGHT, -0.08)
	_set_bone_rotation(skeleton, int(record.get("right_forearm", -1)), Vector3.RIGHT, -0.08)


func _set_bone_rotation(
	skeleton: Skeleton3D,
	bone_index: int,
	axis: Vector3,
	angle: float
) -> void:
	if bone_index < 0:
		return
	skeleton.set_bone_pose_rotation(bone_index, Quaternion(axis, angle))
