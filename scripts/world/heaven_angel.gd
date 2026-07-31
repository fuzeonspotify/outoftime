extends Node3D

var _base_position: Vector3 = Vector3.ZERO
var _base_yaw: float = 0.0
var _phase: float = 0.0
var _side: float = 1.0
var _elapsed: float = 0.0
var _finale_grab_active: bool = false
var _purified: bool = false

var _visual_root: Node3D
var _left_wing: Node3D
var _right_wing: Node3D
var _halo: MeshInstance3D
var _left_horn: MeshInstance3D
var _right_horn: MeshInstance3D

var _robe_material: StandardMaterial3D
var _skin_material: StandardMaterial3D
var _wing_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _eye_material: StandardMaterial3D
var _horn_material: StandardMaterial3D


func configure(spawn_position: Vector3, phase: float) -> void:
	_base_position = spawn_position
	_phase = phase
	_side = -1.0 if spawn_position.x < 0.0 else 1.0
	position = spawn_position
	_base_yaw = -PI * 0.5 if _side < 0.0 else PI * 0.5
	rotation.y = _base_yaw
	_build_visual()


func set_corruption(value: float, player_position: Vector3, delta: float) -> void:
	var corruption: float = clampf(value, 0.0, 1.0)
	_elapsed += delta
	if _purified:
		_update_purified_pose(delta)
		return
	if _finale_grab_active:
		_update_grab_pose(corruption)
		return

	var calm_bob: float = sin(_elapsed * 1.15 + _phase) * 0.06 * (1.0 - corruption)
	var hostile_tremor: float = sin(_elapsed * 8.0 + _phase) * 0.018 * corruption
	position.y = _base_position.y + calm_bob + hostile_tremor
	position.x = lerpf(_base_position.x, _side * 3.25, corruption)

	var player_offset: Vector3 = player_position - global_position
	player_offset.y = 0.0
	var hostile_yaw: float = _base_yaw
	if player_offset.length_squared() > 0.001:
		hostile_yaw = atan2(-player_offset.x, -player_offset.z)
	rotation.y = lerp_angle(_base_yaw, hostile_yaw, smoothstep(0.28, 0.82, corruption))
	rotation.z = sin(_elapsed * 2.4 + _phase) * deg_to_rad(4.0) * corruption

	_visual_root.position.y = lerpf(0.0, -0.12, corruption)
	_visual_root.rotation_degrees.x = lerpf(0.0, 13.0, corruption)
	_left_wing.rotation_degrees = Vector3(
		lerpf(4.0, 28.0, corruption),
		lerpf(-16.0, -48.0, corruption),
		lerpf(-18.0, -74.0, corruption)
	)
	_right_wing.rotation_degrees = Vector3(
		lerpf(4.0, 28.0, corruption),
		lerpf(16.0, 48.0, corruption),
		lerpf(18.0, 74.0, corruption)
	)

	_halo.position.y = lerpf(2.82, 2.18, corruption)
	_halo.rotation_degrees = Vector3(
		lerpf(90.0, 35.0, corruption),
		sin(_elapsed * 1.7 + _phase) * 22.0 * corruption,
		lerpf(0.0, 68.0 * _side, corruption)
	)
	_halo.scale = Vector3.ONE * lerpf(1.0, 0.62, corruption)
	var horn_scale: float = smoothstep(0.42, 0.82, corruption)
	_left_horn.scale = Vector3.ONE * horn_scale
	_right_horn.scale = Vector3.ONE * horn_scale
	_left_horn.rotation_degrees.z = lerpf(-18.0, -34.0, corruption)
	_right_horn.rotation_degrees.z = lerpf(18.0, 34.0, corruption)

	_update_materials(corruption)


func begin_finale_grab(target_world_position: Vector3, duration: float) -> void:
	_finale_grab_active = true
	_purified = false
	var target_local_position: Vector3 = target_world_position
	var parent_3d: Node3D = get_parent() as Node3D
	if parent_3d != null:
		target_local_position = parent_3d.to_local(target_world_position)
	var lunge_tween: Tween = create_tween().set_parallel(true)
	lunge_tween.tween_property(self, "position", target_local_position, maxf(0.15, duration)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge_tween.tween_property(self, "rotation:z", 0.0, maxf(0.15, duration) * 0.55)
	lunge_tween.tween_property(_visual_root, "scale", Vector3.ONE * 1.10, maxf(0.15, duration)).set_trans(Tween.TRANS_QUINT)
	lunge_tween.tween_property(_left_wing, "rotation_degrees", Vector3(32.0, -58.0, -88.0), maxf(0.15, duration))
	lunge_tween.tween_property(_right_wing, "rotation_degrees", Vector3(32.0, 58.0, 88.0), maxf(0.15, duration))


func finish_finale_grab(success: bool) -> void:
	_finale_grab_active = false
	if success:
		_purified = true
		var release_tween: Tween = create_tween().set_parallel(true)
		release_tween.tween_property(self, "position", _base_position, 1.55).set_trans(Tween.TRANS_QUINT)
		release_tween.tween_property(self, "rotation", Vector3(0.0, _base_yaw, 0.0), 1.35).set_trans(Tween.TRANS_QUINT)
		release_tween.tween_property(_visual_root, "scale", Vector3.ONE, 1.15)
	else:
		var kill_tween: Tween = create_tween().set_parallel(true)
		kill_tween.tween_property(_visual_root, "scale", Vector3.ONE * 1.42, 0.42).set_trans(Tween.TRANS_EXPO)
		kill_tween.tween_property(_visual_root, "rotation_degrees:x", 34.0, 0.42).set_trans(Tween.TRANS_EXPO)


func set_purified(value: bool) -> void:
	_purified = value
	if value:
		_left_horn.scale = Vector3.ZERO
		_right_horn.scale = Vector3.ZERO


func get_face_position() -> Vector3:
	return _visual_root.to_global(Vector3(0.0, 2.30, -0.23))


func get_whisper_position() -> Vector3:
	return global_position + Vector3.UP * 1.75


func _update_grab_pose(_corruption: float) -> void:
	rotation.z = sin(_elapsed * 13.0 + _phase) * deg_to_rad(2.2)
	_visual_root.rotation_degrees.x = 18.0 + sin(_elapsed * 9.0) * 2.5
	_halo.position.y = 2.06
	_halo.rotation_degrees = Vector3(26.0, _elapsed * 96.0, 78.0 * _side)
	_halo.scale = Vector3.ONE * 0.48
	_left_horn.scale = Vector3.ONE
	_right_horn.scale = Vector3.ONE
	_update_materials(1.0)


func _update_purified_pose(_delta: float) -> void:
	var bob: float = sin(_elapsed * 1.05 + _phase) * 0.055
	if not _finale_grab_active:
		position.y = move_toward(position.y, _base_position.y + bob, 0.035)
	rotation.z = lerpf(rotation.z, 0.0, 0.08)
	_visual_root.position.y = lerpf(_visual_root.position.y, 0.0, 0.08)
	_visual_root.rotation_degrees.x = lerpf(_visual_root.rotation_degrees.x, 0.0, 0.08)
	_left_wing.rotation_degrees = _left_wing.rotation_degrees.lerp(Vector3(-8.0, -10.0, -30.0), 0.08)
	_right_wing.rotation_degrees = _right_wing.rotation_degrees.lerp(Vector3(-8.0, 10.0, 30.0), 0.08)
	_halo.position.y = lerpf(_halo.position.y, 2.90, 0.08)
	_halo.rotation_degrees = _halo.rotation_degrees.lerp(Vector3(90.0, 0.0, 0.0), 0.08)
	_halo.scale = _halo.scale.lerp(Vector3.ONE * 1.12, 0.08)
	_left_horn.scale = Vector3.ZERO
	_right_horn.scale = Vector3.ZERO
	_robe_material.albedo_color = Color("fffdf2")
	_skin_material.albedo_color = Color("f7dfc8")
	_wing_material.albedo_color = Color("fff9dd")
	_halo_material.albedo_color = Color("ffe17a")
	_halo_material.emission = Color("ffd14f")
	_halo_material.emission_energy_multiplier = 3.8
	_eye_material.albedo_color = Color("fff0a8")
	_eye_material.emission = Color("ffd869")
	_eye_material.emission_energy_multiplier = 2.6


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "AngelVisual"
	add_child(_visual_root)

	_robe_material = _make_material(Color("fffaf0"), 0.72)
	_skin_material = _make_material(Color("f4d8bf"), 0.78)
	_wing_material = _make_material(Color("fffdf5"), 0.82)
	_halo_material = _make_emissive_material(Color("ffe69a"), 2.6, 0.30)
	_eye_material = _make_emissive_material(Color("a8d7ff"), 1.1, 0.24)
	_horn_material = _make_material(Color("25172d"), 0.46)

	var robe_mesh: CylinderMesh = CylinderMesh.new()
	robe_mesh.top_radius = 0.38
	robe_mesh.bottom_radius = 0.78
	robe_mesh.height = 1.72
	_add_mesh(_visual_root, robe_mesh, Vector3(0.0, 0.86, 0.0), _robe_material)

	var torso_mesh: CapsuleMesh = CapsuleMesh.new()
	torso_mesh.radius = 0.30
	torso_mesh.height = 0.86
	_add_mesh(_visual_root, torso_mesh, Vector3(0.0, 1.65, 0.0), _robe_material)

	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.29
	head_mesh.height = 0.56
	_add_mesh(_visual_root, head_mesh, Vector3(0.0, 2.30, 0.0), _skin_material)

	var neck_mesh: CylinderMesh = CylinderMesh.new()
	neck_mesh.top_radius = 0.10
	neck_mesh.bottom_radius = 0.12
	neck_mesh.height = 0.28
	_add_mesh(_visual_root, neck_mesh, Vector3(0.0, 2.02, 0.0), _skin_material)

	for arm_side: float in [-1.0, 1.0]:
		var arm_mesh: CapsuleMesh = CapsuleMesh.new()
		arm_mesh.radius = 0.075
		arm_mesh.height = 0.76
		var arm: MeshInstance3D = _add_mesh(
			_visual_root,
			arm_mesh,
			Vector3(arm_side * 0.42, 1.55, 0.0),
			_skin_material
		)
		arm.rotation_degrees.z = arm_side * -10.0

	_left_wing = _build_wing(-1.0)
	_right_wing = _build_wing(1.0)

	var halo_mesh: TorusMesh = TorusMesh.new()
	halo_mesh.inner_radius = 0.42
	halo_mesh.outer_radius = 0.50
	_halo = _add_mesh(_visual_root, halo_mesh, Vector3(0.0, 2.82, 0.0), _halo_material)
	_halo.rotation_degrees.x = 90.0

	var horn_mesh: CylinderMesh = CylinderMesh.new()
	horn_mesh.top_radius = 0.0
	horn_mesh.bottom_radius = 0.095
	horn_mesh.height = 0.58
	_left_horn = _add_mesh(_visual_root, horn_mesh, Vector3(-0.17, 2.61, 0.0), _horn_material)
	_right_horn = _add_mesh(_visual_root, horn_mesh, Vector3(0.17, 2.61, 0.0), _horn_material)
	_left_horn.scale = Vector3.ZERO
	_right_horn.scale = Vector3.ZERO

	var eye_mesh: SphereMesh = SphereMesh.new()
	eye_mesh.radius = 0.045
	eye_mesh.height = 0.085
	_add_mesh(_visual_root, eye_mesh, Vector3(-0.10, 2.34, -0.255), _eye_material)
	_add_mesh(_visual_root, eye_mesh, Vector3(0.10, 2.34, -0.255), _eye_material)


func _build_wing(side: float) -> Node3D:
	var wing_root: Node3D = Node3D.new()
	wing_root.name = "LeftWing" if side < 0.0 else "RightWing"
	wing_root.position = Vector3(side * 0.24, 1.86, 0.20)
	_visual_root.add_child(wing_root)
	for feather_index: int in range(5):
		var feather_mesh: CapsuleMesh = CapsuleMesh.new()
		feather_mesh.radius = 0.10
		feather_mesh.height = 1.18 - float(feather_index) * 0.10
		var feather: MeshInstance3D = _add_mesh(
			wing_root,
			feather_mesh,
			Vector3(side * (0.20 + float(feather_index) * 0.18), -float(feather_index) * 0.13, 0.0),
			_wing_material
		)
		feather.rotation_degrees.z = side * (35.0 + float(feather_index) * 5.0)
	return wing_root


func _update_materials(corruption: float) -> void:
	_robe_material.albedo_color = Color("fffaf0").lerp(Color("190d20"), corruption)
	_robe_material.roughness = lerpf(0.72, 0.38, corruption)
	_skin_material.albedo_color = Color("f4d8bf").lerp(Color("78506a"), corruption)
	_wing_material.albedo_color = Color("fffdf5").lerp(Color("160c1b"), corruption)
	_wing_material.roughness = lerpf(0.82, 0.36, corruption)
	_halo_material.albedo_color = Color("ffe69a").lerp(Color("8a173f"), corruption)
	_halo_material.emission = Color("ffd96c").lerp(Color("c20c46"), corruption)
	_halo_material.emission_energy_multiplier = lerpf(2.6, 1.2, corruption)
	_eye_material.albedo_color = Color("a8d7ff").lerp(Color("ff173f"), corruption)
	_eye_material.emission = Color("7cc8ff").lerp(Color("ff082d"), corruption)
	_eye_material.emission_energy_multiplier = lerpf(1.1, 4.2, corruption)
	_horn_material.albedo_color = Color("25172d").lerp(Color("080308"), corruption)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _make_emissive_material(
	color: Color,
	emission_energy: float,
	roughness: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, roughness)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material


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
