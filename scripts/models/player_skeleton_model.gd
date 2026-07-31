extends Node

const EXTERNAL_MODEL_PATH: String = "res://assets/models/characters/skeleton_player.glb"

var _player: CharacterBody3D
var _model_root: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _uses_external_model: bool = false


func _ready() -> void:
	call_deferred("_install_model")


func _process(delta: float) -> void:
	if _player == null or _model_root == null or _uses_external_model:
		return

	var planar_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var sprint_speed_value: float = float(_player.get("sprint_speed"))
	var movement_amount: float = clampf(planar_speed / maxf(0.1, sprint_speed_value), 0.0, 1.0)
	var phase: float = float(Time.get_ticks_msec()) * 0.0105
	var swing: float = sin(phase) * 0.58 * movement_amount
	var settle_speed: float = minf(1.0, delta * 12.0)

	if _left_arm != null:
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, swing, settle_speed)
	if _right_arm != null:
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, -swing, settle_speed)
	if _left_leg != null:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, -swing * 0.72, settle_speed)
	if _right_leg != null:
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, swing * 0.72, settle_speed)


func _install_model() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_parent() as CharacterBody3D
	if _player == null:
		return

	var old_visual: Node3D = _player.get_node_or_null("SkeletonVisual") as Node3D
	if old_visual == null:
		return

	_hide_meshes(old_visual)
	if _try_install_external_model(old_visual):
		return
	_build_fallback_model(old_visual)


func _try_install_external_model(parent: Node3D) -> bool:
	if not ResourceLoader.exists(EXTERNAL_MODEL_PATH):
		return false
	var resource: Resource = load(EXTERNAL_MODEL_PATH)
	var packed_scene: PackedScene = resource as PackedScene
	if packed_scene == null:
		return false
	var instance: Node = packed_scene.instantiate()
	var external_model: Node3D = instance as Node3D
	if external_model == null:
		instance.queue_free()
		return false
	external_model.name = "ExternalSkeletonModel"
	external_model.scale = Vector3(1.0, 1.0, 1.0)
	external_model.rotation_degrees.y = 180.0
	parent.add_child(external_model)
	_model_root = external_model
	_uses_external_model = true
	return true


func _hide_meshes(parent: Node3D) -> void:
	var mesh_nodes: Array[Node] = parent.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.visible = false


func _build_fallback_model(parent: Node3D) -> void:
	_model_root = Node3D.new()
	_model_root.name = "DetailedSkeletonModel"
	parent.add_child(_model_root)

	var bone: StandardMaterial3D = _make_material(Color("d8d3c3"), 0.78, 0.02)
	var bone_dark: StandardMaterial3D = _make_material(Color("9f9a8d"), 0.82, 0.01)
	var void_material: StandardMaterial3D = _make_material(Color("07080d"), 0.94, 0.0)
	var eye_glow: StandardMaterial3D = _make_emissive_material(Color("7e63ff"), 1.35)

	_build_skull(_model_root, bone, bone_dark, void_material, eye_glow)
	_build_torso(_model_root, bone, bone_dark)
	_left_arm = _build_arm(_model_root, -1.0, bone, bone_dark)
	_right_arm = _build_arm(_model_root, 1.0, bone, bone_dark)
	_left_leg = _build_leg(_model_root, -1.0, bone, bone_dark)
	_right_leg = _build_leg(_model_root, 1.0, bone, bone_dark)


func _build_skull(parent: Node3D, bone: Material, bone_dark: Material, void_material: Material, eye_glow: Material) -> void:
	var sides: Array[float] = [-1.0, 1.0]
	var skull_root: Node3D = Node3D.new()
	skull_root.name = "Skull"
	skull_root.position = Vector3(0.0, 1.63, 0.0)
	parent.add_child(skull_root)

	var cranium_mesh: SphereMesh = SphereMesh.new()
	cranium_mesh.radius = 0.32
	cranium_mesh.height = 0.56
	var cranium: MeshInstance3D = _add_mesh(skull_root, cranium_mesh, Vector3(0.0, 0.10, 0.0), bone)
	cranium.scale = Vector3(0.92, 1.02, 0.82)

	var jaw_mesh: BoxMesh = BoxMesh.new()
	jaw_mesh.size = Vector3(0.31, 0.17, 0.24)
	_add_mesh(skull_root, jaw_mesh, Vector3(0.0, -0.19, -0.01), bone_dark)

	var cheek_mesh: CapsuleMesh = CapsuleMesh.new()
	cheek_mesh.radius = 0.055
	cheek_mesh.height = 0.30
	for side: float in sides:
		var cheek: MeshInstance3D = _add_mesh(skull_root, cheek_mesh, Vector3(side * 0.21, -0.02, -0.17), bone)
		cheek.rotation_degrees = Vector3(0.0, 0.0, side * 55.0)

	var brow_mesh: BoxMesh = BoxMesh.new()
	brow_mesh.size = Vector3(0.20, 0.065, 0.075)
	for side: float in sides:
		var brow: MeshInstance3D = _add_mesh(skull_root, brow_mesh, Vector3(side * 0.105, 0.13, -0.245), bone_dark)
		brow.rotation_degrees.z = side * 8.0

	var socket_mesh: SphereMesh = SphereMesh.new()
	socket_mesh.radius = 0.083
	socket_mesh.height = 0.12
	for side: float in sides:
		var socket: MeshInstance3D = _add_mesh(skull_root, socket_mesh, Vector3(side * 0.105, 0.055, -0.265), void_material)
		socket.scale = Vector3(1.0, 0.85, 0.45)
		var eye_mesh: SphereMesh = SphereMesh.new()
		eye_mesh.radius = 0.028
		eye_mesh.height = 0.05
		_add_mesh(skull_root, eye_mesh, Vector3(side * 0.105, 0.055, -0.306), eye_glow)

	var nose_mesh: BoxMesh = BoxMesh.new()
	nose_mesh.size = Vector3(0.07, 0.10, 0.06)
	var nose: MeshInstance3D = _add_mesh(skull_root, nose_mesh, Vector3(0.0, -0.045, -0.285), void_material)
	nose.rotation_degrees.z = 45.0

	for tooth_index: int in range(6):
		var tooth_mesh: BoxMesh = BoxMesh.new()
		tooth_mesh.size = Vector3(0.035, 0.065, 0.045)
		var tooth_x: float = -0.095 + float(tooth_index) * 0.038
		_add_mesh(skull_root, tooth_mesh, Vector3(tooth_x, -0.175, -0.135), bone)


func _build_torso(parent: Node3D, bone: Material, bone_dark: Material) -> void:
	var sides: Array[float] = [-1.0, 1.0]
	var spine_mesh: CylinderMesh = CylinderMesh.new()
	spine_mesh.top_radius = 0.045
	spine_mesh.bottom_radius = 0.065
	spine_mesh.height = 0.72
	_add_mesh(parent, spine_mesh, Vector3(0.0, 1.08, 0.06), bone_dark)

	var sternum_mesh: BoxMesh = BoxMesh.new()
	sternum_mesh.size = Vector3(0.10, 0.58, 0.09)
	_add_mesh(parent, sternum_mesh, Vector3(0.0, 1.20, -0.08), bone)

	for rib_index: int in range(5):
		var rib_y: float = 1.43 - float(rib_index) * 0.11
		var half_width: float = 0.31 - float(rib_index) * 0.018
		for side: float in sides:
			var rib_mesh: CapsuleMesh = CapsuleMesh.new()
			rib_mesh.radius = 0.028
			rib_mesh.height = half_width * 1.9
			var rib: MeshInstance3D = _add_mesh(parent, rib_mesh, Vector3(side * half_width * 0.53, rib_y, 0.0), bone)
			rib.rotation_degrees = Vector3(90.0, 0.0, side * (63.0 - float(rib_index) * 3.0))

	var clavicle_mesh: CapsuleMesh = CapsuleMesh.new()
	clavicle_mesh.radius = 0.038
	clavicle_mesh.height = 0.46
	for side: float in sides:
		var clavicle: MeshInstance3D = _add_mesh(parent, clavicle_mesh, Vector3(side * 0.19, 1.48, -0.03), bone)
		clavicle.rotation_degrees.z = side * 68.0

	var pelvis_mesh: BoxMesh = BoxMesh.new()
	pelvis_mesh.size = Vector3(0.46, 0.20, 0.25)
	_add_mesh(parent, pelvis_mesh, Vector3(0.0, 0.73, 0.0), bone_dark)
	for side: float in sides:
		var hip_mesh: SphereMesh = SphereMesh.new()
		hip_mesh.radius = 0.13
		hip_mesh.height = 0.22
		var hip: MeshInstance3D = _add_mesh(parent, hip_mesh, Vector3(side * 0.22, 0.74, 0.0), bone)
		hip.scale = Vector3(1.15, 0.8, 0.9)


func _build_arm(parent: Node3D, side: float, bone: Material, bone_dark: Material) -> Node3D:
	var arm_root: Node3D = Node3D.new()
	arm_root.name = "LeftArm" if side < 0.0 else "RightArm"
	arm_root.position = Vector3(side * 0.40, 1.44, 0.0)
	parent.add_child(arm_root)

	var upper_mesh: CapsuleMesh = CapsuleMesh.new()
	upper_mesh.radius = 0.052
	upper_mesh.height = 0.56
	var upper: MeshInstance3D = _add_mesh(arm_root, upper_mesh, Vector3(side * 0.06, -0.27, 0.0), bone)
	upper.rotation_degrees.z = side * 10.0

	var elbow_mesh: SphereMesh = SphereMesh.new()
	elbow_mesh.radius = 0.075
	elbow_mesh.height = 0.13
	_add_mesh(arm_root, elbow_mesh, Vector3(side * 0.11, -0.58, 0.0), bone_dark)

	var forearm_mesh: CapsuleMesh = CapsuleMesh.new()
	forearm_mesh.radius = 0.045
	forearm_mesh.height = 0.52
	var forearm: MeshInstance3D = _add_mesh(arm_root, forearm_mesh, Vector3(side * 0.15, -0.83, 0.0), bone)
	forearm.rotation_degrees.z = side * 8.0

	var hand_mesh: SphereMesh = SphereMesh.new()
	hand_mesh.radius = 0.09
	hand_mesh.height = 0.16
	var hand: MeshInstance3D = _add_mesh(arm_root, hand_mesh, Vector3(side * 0.19, -1.12, -0.01), bone_dark)
	hand.scale = Vector3(0.72, 1.0, 0.55)

	for finger_index: int in range(3):
		var finger_mesh: CapsuleMesh = CapsuleMesh.new()
		finger_mesh.radius = 0.015
		finger_mesh.height = 0.15
		var finger_x: float = side * (0.15 + float(finger_index) * 0.035)
		var finger: MeshInstance3D = _add_mesh(arm_root, finger_mesh, Vector3(finger_x, -1.22, -0.015), bone)
		finger.rotation_degrees.z = side * 5.0
	return arm_root


func _build_leg(parent: Node3D, side: float, bone: Material, bone_dark: Material) -> Node3D:
	var leg_root: Node3D = Node3D.new()
	leg_root.name = "LeftLeg" if side < 0.0 else "RightLeg"
	leg_root.position = Vector3(side * 0.14, 0.68, 0.0)
	parent.add_child(leg_root)

	var thigh_mesh: CapsuleMesh = CapsuleMesh.new()
	thigh_mesh.radius = 0.062
	thigh_mesh.height = 0.55
	_add_mesh(leg_root, thigh_mesh, Vector3(0.0, -0.27, 0.0), bone)

	var knee_mesh: SphereMesh = SphereMesh.new()
	knee_mesh.radius = 0.085
	knee_mesh.height = 0.14
	_add_mesh(leg_root, knee_mesh, Vector3(0.0, -0.58, -0.015), bone_dark)

	var shin_mesh: CapsuleMesh = CapsuleMesh.new()
	shin_mesh.radius = 0.050
	shin_mesh.height = 0.52
	_add_mesh(leg_root, shin_mesh, Vector3(0.0, -0.84, 0.02), bone)

	var ankle_mesh: SphereMesh = SphereMesh.new()
	ankle_mesh.radius = 0.060
	ankle_mesh.height = 0.10
	_add_mesh(leg_root, ankle_mesh, Vector3(0.0, -1.13, 0.02), bone_dark)

	var foot_mesh: BoxMesh = BoxMesh.new()
	foot_mesh.size = Vector3(0.18, 0.10, 0.36)
	_add_mesh(leg_root, foot_mesh, Vector3(0.0, -1.20, -0.10), bone)
	return leg_root


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.35, 0.05)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _add_mesh(parent: Node3D, mesh: Mesh, position_value: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)
	return instance
