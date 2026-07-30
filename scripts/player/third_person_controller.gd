extends CharacterBody3D

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var acceleration := 18.0
@export var jump_velocity := 6.0
@export var mouse_sensitivity := 0.003

var _gravity := 9.8
var _camera_yaw: Node3D
var _camera_pitch: Node3D
var _visual_root: Node3D
var _prompt_label: Label
var _message_label: Label
var _objective_label: Label
var _interaction_target: Node
var _message_token := 0


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_ensure_input_actions()
	_build_collision()
	_build_skeleton_visual()
	_build_camera()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_yaw.rotate_y(-event.relative.x * mouse_sensitivity)
		_camera_pitch.rotation.x = clamp(
			_camera_pitch.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-55.0),
			deg_to_rad(35.0)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_VISIBLE
		)

	if event.is_action_pressed("interact") and is_instance_valid(_interaction_target):
		if _interaction_target.has_method("interact"):
			_interaction_target.interact(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -_camera_yaw.global_transform.basis.z
	var right := _camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction := right * input_vector.x + forward * -input_vector.y
	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := move_direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if _visual_root != null:
		var planar_speed := Vector2(velocity.x, velocity.z).length()
		var bob_amount := clamp(planar_speed / sprint_speed, 0.0, 1.0)
		_visual_root.position.y = sin(Time.get_ticks_msec() * 0.009) * 0.025 * bob_amount
		if move_direction.length_squared() > 0.001:
			_visual_root.rotation.y = lerp_angle(
				_visual_root.rotation.y,
				atan2(-move_direction.x, -move_direction.z),
				min(1.0, delta * 10.0)
			)

	move_and_slide()


func set_interaction_target(target: Node, prompt_text: String) -> void:
	_interaction_target = target
	if _prompt_label != null:
		_prompt_label.text = "[E] %s" % prompt_text
		_prompt_label.visible = true


func clear_interaction_target(target: Node) -> void:
	if _interaction_target != target:
		return
	_interaction_target = null
	if _prompt_label != null:
		_prompt_label.visible = false


func set_objective(text: String) -> void:
	if _objective_label != null:
		_objective_label.text = "OBJECTIVE\n%s" % text


func show_interaction_message(text: String, duration := 4.0) -> void:
	_message_token += 1
	var token := _message_token
	_message_label.text = text
	_message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if token == _message_token:
		_message_label.visible = false


func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("interact", KEY_E)


func _add_key_action(action_name: StringName, physical_keycode: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(collision)


func _build_skeleton_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "SkeletonVisual"
	add_child(_visual_root)

	var bone_material := StandardMaterial3D.new()
	bone_material.albedo_color = Color("d9d6c8")
	bone_material.roughness = 0.82

	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color("171923")
	dark_material.roughness = 0.95

	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.27
	skull_mesh.height = 0.52
	_add_mesh(_visual_root, skull_mesh, Vector3(0.0, 1.67, 0.0), Vector3.ONE, bone_material)

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.055
	eye_mesh.height = 0.1
	_add_mesh(_visual_root, eye_mesh, Vector3(-0.09, 1.71, -0.235), Vector3.ONE, dark_material)
	_add_mesh(_visual_root, eye_mesh, Vector3(0.09, 1.71, -0.235), Vector3.ONE, dark_material)

	var jaw_mesh := BoxMesh.new()
	jaw_mesh.size = Vector3(0.28, 0.13, 0.22)
	_add_mesh(_visual_root, jaw_mesh, Vector3(0.0, 1.48, -0.015), Vector3.ONE, bone_material)

	var spine_mesh := CylinderMesh.new()
	spine_mesh.top_radius = 0.055
	spine_mesh.bottom_radius = 0.055
	spine_mesh.height = 0.57
	_add_mesh(_visual_root, spine_mesh, Vector3(0.0, 1.13, 0.0), Vector3.ONE, bone_material)

	for rib_y in [1.37, 1.25, 1.13]:
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(0.55, 0.055, 0.13)
		_add_mesh(_visual_root, rib_mesh, Vector3(0.0, rib_y, 0.0), Vector3.ONE, bone_material)

	var pelvis_mesh := BoxMesh.new()
	pelvis_mesh.size = Vector3(0.42, 0.18, 0.22)
	_add_mesh(_visual_root, pelvis_mesh, Vector3(0.0, 0.82, 0.0), Vector3.ONE, bone_material)

	var limb_mesh := CapsuleMesh.new()
	limb_mesh.radius = 0.06
	limb_mesh.height = 0.62
	_add_mesh(_visual_root, limb_mesh, Vector3(-0.39, 1.12, 0.0), Vector3.ONE, bone_material, Vector3(0.0, 0.0, -10.0))
	_add_mesh(_visual_root, limb_mesh, Vector3(0.39, 1.12, 0.0), Vector3.ONE, bone_material, Vector3(0.0, 0.0, 10.0))
	_add_mesh(_visual_root, limb_mesh, Vector3(-0.14, 0.45, 0.0), Vector3.ONE, bone_material, Vector3(0.0, 0.0, 2.0))
	_add_mesh(_visual_root, limb_mesh, Vector3(0.14, 0.45, 0.0), Vector3.ONE, bone_material, Vector3(0.0, 0.0, -2.0))


func _build_camera() -> void:
	_camera_yaw = Node3D.new()
	_camera_yaw.name = "CameraYaw"
	_camera_yaw.position = Vector3(0.0, 1.35, 0.0)
	add_child(_camera_yaw)

	_camera_pitch = Node3D.new()
	_camera_pitch.name = "CameraPitch"
	_camera_pitch.rotation.x = deg_to_rad(-10.0)
	_camera_yaw.add_child(_camera_pitch)

	var spring_arm := SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 5.2
	spring_arm.margin = 0.12
	spring_arm.collision_mask = 1
	_camera_pitch.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 68.0
	spring_arm.add_child(camera)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PlayerHUD"
	add_child(canvas)

	_objective_label = Label.new()
	_objective_label.position = Vector2(30.0, 26.0)
	_objective_label.size = Vector2(520.0, 90.0)
	_objective_label.text = "OBJECTIVE\nFind the memorial at the end of the path."
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", Color("d8dbea"))
	canvas.add_child(_objective_label)

	var controls := Label.new()
	controls.anchor_left = 1.0
	controls.anchor_right = 1.0
	controls.offset_left = -340.0
	controls.offset_right = -24.0
	controls.offset_top = 24.0
	controls.offset_bottom = 96.0
	controls.text = "WASD Move   Shift Sprint   Space Jump\nMouse Look   Esc Release Cursor"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color("8991a8"))
	canvas.add_child(controls)

	var crosshair := Label.new()
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -10.0
	crosshair.offset_right = 10.0
	crosshair.offset_top = -14.0
	crosshair.offset_bottom = 14.0
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 18)
	crosshair.add_theme_color_override("font_color", Color("b7bdd0"))
	canvas.add_child(crosshair)

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -330.0
	_prompt_label.offset_right = 330.0
	_prompt_label.offset_top = -105.0
	_prompt_label.offset_bottom = -60.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 21)
	_prompt_label.add_theme_color_override("font_color", Color("f2f0e7"))
	_prompt_label.visible = false
	canvas.add_child(_prompt_label)

	_message_label = Label.new()
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 0.72
	_message_label.anchor_bottom = 0.72
	_message_label.offset_left = -420.0
	_message_label.offset_right = 420.0
	_message_label.offset_top = -50.0
	_message_label.offset_bottom = 80.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.add_theme_color_override("font_color", Color("e6dfcf"))
	_message_label.visible = false
	canvas.add_child(_message_label)


func _add_mesh(
	parent: Node3D,
	mesh: Mesh,
	mesh_position: Vector3,
	mesh_scale: Vector3,
	material: Material,
	mesh_rotation_degrees := Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.scale = mesh_scale
	instance.rotation_degrees = mesh_rotation_degrees
	instance.material_override = material
	parent.add_child(instance)
	return instance
