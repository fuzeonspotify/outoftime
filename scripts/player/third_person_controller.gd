extends CharacterBody3D

const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 18.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.003

var _gravity: float = 9.8
var _camera_yaw: Node3D
var _camera_pitch: Node3D
var _visual_root: Node3D

var _hud_canvas: CanvasLayer
var _objective_panel: PanelContainer
var _chapter_label: Label
var _objective_label: Label
var _controls_panel: PanelContainer
var _crosshair_horizontal: ColorRect
var _crosshair_vertical: ColorRect
var _prompt_panel: PanelContainer
var _prompt_title_label: Label
var _prompt_action_label: Label
var _prompt_progress: ProgressBar
var _message_panel: PanelContainer
var _message_source_label: Label
var _message_body_label: Label
var _pause_canvas: CanvasLayer
var _pause_overlay: Control
var _resume_button: Button

var _interaction_target: Node
var _interaction_hold_duration: float = 0.42
var _interaction_hold_elapsed: float = 0.0
var _interaction_triggered: bool = false
var _message_token: int = 0
var _objective_text: String = ""
var _pause_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_ensure_input_actions()
	_build_collision()
	_build_skeleton_visual()
	_build_camera()
	_build_hud()
	_build_pause_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_interaction_hold(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_pause_open(not _pause_open)
		get_viewport().set_input_as_handled()
		return

	if get_tree().paused:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_yaw.rotate_y(-mouse_event.relative.x * mouse_sensitivity)
		_camera_pitch.rotation.x = clampf(
			_camera_pitch.rotation.x - mouse_event.relative.y * mouse_sensitivity,
			deg_to_rad(-55.0),
			deg_to_rad(35.0)
		)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = -_camera_yaw.global_transform.basis.z
	var right: Vector3 = _camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	if move_direction.length_squared() > 0.001:
		move_direction = move_direction.normalized()

	var target_speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity: Vector3 = move_direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if _visual_root != null:
		var planar_speed: float = Vector2(velocity.x, velocity.z).length()
		var bob_amount: float = clampf(planar_speed / sprint_speed, 0.0, 1.0)
		_visual_root.position.y = sin(float(Time.get_ticks_msec()) * 0.009) * 0.025 * bob_amount
		if move_direction.length_squared() > 0.001:
			_visual_root.rotation.y = lerp_angle(
				_visual_root.rotation.y,
				atan2(-move_direction.x, -move_direction.z),
				minf(1.0, delta * 10.0)
			)

	move_and_slide()


func set_interaction_target(
	target: Node,
	prompt_text: String,
	title_text: String = "INTERACTION",
	context_text: String = "HOLD TO INTERACT",
	hold_seconds: float = 0.42
) -> void:
	if target == null:
		return
	if _interaction_target != target:
		_reset_interaction_hold()
	_interaction_target = target
	_interaction_hold_duration = maxf(0.0, hold_seconds)
	_prompt_title_label.text = title_text.to_upper()
	_prompt_action_label.text = prompt_text
	_prompt_progress.visible = _interaction_hold_duration > 0.08
	_prompt_progress.value = 0.0
	_prompt_panel.tooltip_text = context_text
	_prompt_panel.visible = true
	_prompt_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var reveal_tween: Tween = create_tween()
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.14)
	reveal_tween.tween_property(_prompt_panel, "position:y", _prompt_panel.position.y - 4.0, 0.14)
	_set_crosshair_focused(true)


func clear_interaction_target(target: Node) -> void:
	if _interaction_target != target:
		return
	_interaction_target = null
	_reset_interaction_hold()
	_prompt_panel.visible = false
	_set_crosshair_focused(false)


func set_objective(text: String) -> void:
	var cleaned_text: String = text.strip_edges()
	if cleaned_text == _objective_text:
		return
	_objective_text = cleaned_text
	_objective_label.text = cleaned_text
	_objective_panel.modulate = Color(1.0, 1.0, 1.0, 0.72)
	var objective_tween: Tween = create_tween()
	objective_tween.tween_property(_objective_panel, "modulate", Color.WHITE, 0.28)


func set_chapter_title(text: String) -> void:
	if _chapter_label != null:
		_chapter_label.text = text.to_upper()


func show_interaction_message(
	text: String,
	duration: float = 4.0,
	source: String = "MEMORY"
) -> void:
	_message_token += 1
	var token: int = _message_token
	_message_source_label.text = source.to_upper()
	_message_body_label.text = text
	_message_panel.visible = true
	_message_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_message_panel.position.y += 8.0
	var reveal_tween: Tween = create_tween()
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(_message_panel, "modulate:a", 1.0, 0.22)
	reveal_tween.tween_property(_message_panel, "position:y", _message_panel.position.y - 8.0, 0.22)

	await get_tree().create_timer(duration, true).timeout
	if token != _message_token or _message_panel == null:
		return
	var hide_tween: Tween = create_tween()
	hide_tween.tween_property(_message_panel, "modulate:a", 0.0, 0.22)
	await hide_tween.finished
	if token == _message_token:
		_message_panel.visible = false


func _update_interaction_hold(delta: float) -> void:
	if not is_instance_valid(_interaction_target):
		if _interaction_target != null:
			_interaction_target = null
			_prompt_panel.visible = false
			_set_crosshair_focused(false)
		_reset_interaction_hold()
		return

	if Input.is_action_just_released("interact"):
		_reset_interaction_hold()
		return

	if not Input.is_action_pressed("interact") or _interaction_triggered:
		return

	if _interaction_hold_duration <= 0.08:
		_trigger_interaction()
		return

	_interaction_hold_elapsed += delta
	var progress_ratio: float = clampf(_interaction_hold_elapsed / _interaction_hold_duration, 0.0, 1.0)
	_prompt_progress.value = progress_ratio * 100.0
	_prompt_action_label.modulate = UI_STYLE.COLOR_TEXT.lerp(Color.WHITE, progress_ratio)
	if progress_ratio >= 1.0:
		_trigger_interaction()


func _trigger_interaction() -> void:
	if _interaction_triggered or not is_instance_valid(_interaction_target):
		return
	_interaction_triggered = true
	_prompt_progress.value = 100.0
	var active_target: Node = _interaction_target
	if active_target.has_method("interact"):
		active_target.call("interact", self)


func _reset_interaction_hold() -> void:
	_interaction_hold_elapsed = 0.0
	_interaction_triggered = false
	if _prompt_progress != null:
		_prompt_progress.value = 0.0
	if _prompt_action_label != null:
		_prompt_action_label.modulate = Color.WHITE


func _set_crosshair_focused(focused: bool) -> void:
	if _crosshair_horizontal == null or _crosshair_vertical == null:
		return
	var target_color: Color = UI_STYLE.COLOR_ACCENT if focused else Color(0.78, 0.78, 0.86, 0.78)
	var target_scale: Vector2 = Vector2(1.35, 1.35) if focused else Vector2.ONE
	_crosshair_horizontal.color = target_color
	_crosshair_vertical.color = target_color
	_crosshair_horizontal.scale = target_scale
	_crosshair_vertical.scale = target_scale


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
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)


func _build_collision() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(collision)


func _build_skeleton_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "SkeletonVisual"
	add_child(_visual_root)

	var bone_material: StandardMaterial3D = StandardMaterial3D.new()
	bone_material.albedo_color = Color("d9d6c8")
	bone_material.roughness = 0.82

	var dark_material: StandardMaterial3D = StandardMaterial3D.new()
	dark_material.albedo_color = Color("171923")
	dark_material.roughness = 0.95

	var skull_mesh: SphereMesh = SphereMesh.new()
	skull_mesh.radius = 0.27
	skull_mesh.height = 0.52
	_add_mesh(_visual_root, skull_mesh, Vector3(0.0, 1.67, 0.0), Vector3.ONE, bone_material)

	var eye_mesh: SphereMesh = SphereMesh.new()
	eye_mesh.radius = 0.055
	eye_mesh.height = 0.1
	_add_mesh(_visual_root, eye_mesh, Vector3(-0.09, 1.71, -0.235), Vector3.ONE, dark_material)
	_add_mesh(_visual_root, eye_mesh, Vector3(0.09, 1.71, -0.235), Vector3.ONE, dark_material)

	var jaw_mesh: BoxMesh = BoxMesh.new()
	jaw_mesh.size = Vector3(0.28, 0.13, 0.22)
	_add_mesh(_visual_root, jaw_mesh, Vector3(0.0, 1.48, -0.015), Vector3.ONE, bone_material)

	var spine_mesh: CylinderMesh = CylinderMesh.new()
	spine_mesh.top_radius = 0.055
	spine_mesh.bottom_radius = 0.055
	spine_mesh.height = 0.57
	_add_mesh(_visual_root, spine_mesh, Vector3(0.0, 1.13, 0.0), Vector3.ONE, bone_material)

	for rib_y: float in [1.37, 1.25, 1.13]:
		var rib_mesh: BoxMesh = BoxMesh.new()
		rib_mesh.size = Vector3(0.55, 0.055, 0.13)
		_add_mesh(_visual_root, rib_mesh, Vector3(0.0, rib_y, 0.0), Vector3.ONE, bone_material)

	var pelvis_mesh: BoxMesh = BoxMesh.new()
	pelvis_mesh.size = Vector3(0.42, 0.18, 0.22)
	_add_mesh(_visual_root, pelvis_mesh, Vector3(0.0, 0.82, 0.0), Vector3.ONE, bone_material)

	var limb_mesh: CapsuleMesh = CapsuleMesh.new()
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

	var spring_arm: SpringArm3D = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 5.2
	spring_arm.margin = 0.12
	spring_arm.collision_mask = 1
	_camera_pitch.add_child(spring_arm)

	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 68.0
	spring_arm.add_child(camera)


func _build_hud() -> void:
	_hud_canvas = CanvasLayer.new()
	_hud_canvas.name = "PlayerHUD"
	_hud_canvas.layer = 50
	add_child(_hud_canvas)

	var hud_root: Control = Control.new()
	hud_root.name = "HUDRoot"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_canvas.add_child(hud_root)

	_build_objective_panel(hud_root)
	_build_controls_panel(hud_root)
	_build_crosshair(hud_root)
	_build_prompt_panel(hud_root)
	_build_message_panel(hud_root)


func _build_objective_panel(hud_root: Control) -> void:
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "ObjectivePanel"
	_objective_panel.position = Vector2(24.0, 24.0)
	_objective_panel.size = Vector2(470.0, 112.0)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE.apply_panel(_objective_panel)
	hud_root.add_child(_objective_panel)

	var objective_stack: VBoxContainer = VBoxContainer.new()
	objective_stack.add_theme_constant_override("separation", 7)
	_objective_panel.add_child(objective_stack)

	_chapter_label = UI_STYLE.make_label(_resolve_chapter_title(), 13, UI_STYLE.COLOR_ACCENT_COOL)
	_chapter_label.name = "ChapterLabel"
	objective_stack.add_child(_chapter_label)

	var divider: ColorRect = ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.color = Color(0.79, 0.29, 0.61, 0.78)
	objective_stack.add_child(divider)

	_objective_label = UI_STYLE.make_label("Awaiting objective.", 18, UI_STYLE.COLOR_TEXT)
	_objective_label.name = "ObjectiveText"
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_stack.add_child(_objective_label)


func _build_controls_panel(hud_root: Control) -> void:
	_controls_panel = PanelContainer.new()
	_controls_panel.name = "ControlsHint"
	_controls_panel.anchor_left = 1.0
	_controls_panel.anchor_right = 1.0
	_controls_panel.offset_left = -380.0
	_controls_panel.offset_right = -24.0
	_controls_panel.offset_top = 24.0
	_controls_panel.offset_bottom = 92.0
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_STYLE.apply_panel(_controls_panel, true)
	hud_root.add_child(_controls_panel)

	var controls: Label = UI_STYLE.make_label(
		"WASD  MOVE    SHIFT  SPRINT    SPACE  JUMP\nE  INTERACT    ESC  PAUSE",
		13,
		UI_STYLE.COLOR_TEXT_MUTED
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controls_panel.add_child(controls)

	var hint_tween: Tween = create_tween()
	hint_tween.tween_interval(8.0)
	hint_tween.tween_property(_controls_panel, "modulate:a", 0.0, 1.0)


func _build_crosshair(hud_root: Control) -> void:
	var crosshair_root: Control = Control.new()
	crosshair_root.name = "Crosshair"
	crosshair_root.anchor_left = 0.5
	crosshair_root.anchor_top = 0.5
	crosshair_root.anchor_right = 0.5
	crosshair_root.anchor_bottom = 0.5
	crosshair_root.offset_left = -10.0
	crosshair_root.offset_top = -10.0
	crosshair_root.offset_right = 10.0
	crosshair_root.offset_bottom = 10.0
	crosshair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(crosshair_root)

	_crosshair_horizontal = ColorRect.new()
	_crosshair_horizontal.position = Vector2(4.0, 9.0)
	_crosshair_horizontal.size = Vector2(12.0, 2.0)
	_crosshair_horizontal.pivot_offset = Vector2(6.0, 1.0)
	_crosshair_horizontal.color = Color(0.78, 0.78, 0.86, 0.78)
	crosshair_root.add_child(_crosshair_horizontal)

	_crosshair_vertical = ColorRect.new()
	_crosshair_vertical.position = Vector2(9.0, 4.0)
	_crosshair_vertical.size = Vector2(2.0, 12.0)
	_crosshair_vertical.pivot_offset = Vector2(1.0, 6.0)
	_crosshair_vertical.color = Color(0.78, 0.78, 0.86, 0.78)
	crosshair_root.add_child(_crosshair_vertical)


func _build_prompt_panel(hud_root: Control) -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "InteractionPrompt"
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -300.0
	_prompt_panel.offset_right = 300.0
	_prompt_panel.offset_top = -128.0
	_prompt_panel.offset_bottom = -42.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	UI_STYLE.apply_panel(_prompt_panel)
	hud_root.add_child(_prompt_panel)

	var prompt_row: HBoxContainer = HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 14)
	_prompt_panel.add_child(prompt_row)

	var key_panel: PanelContainer = PanelContainer.new()
	key_panel.custom_minimum_size = Vector2(52.0, 52.0)
	key_panel.add_theme_stylebox_override(
		"panel",
		UI_STYLE.make_panel_style(Color(0.14, 0.08, 0.17, 0.98), UI_STYLE.COLOR_ACCENT, 9, 2, 8.0)
	)
	prompt_row.add_child(key_panel)

	var key_label: Label = UI_STYLE.make_label("E", 22, Color.WHITE)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_panel.add_child(key_label)

	var prompt_stack: VBoxContainer = VBoxContainer.new()
	prompt_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_stack.add_theme_constant_override("separation", 2)
	prompt_row.add_child(prompt_stack)

	_prompt_title_label = UI_STYLE.make_label("INTERACTION", 12, UI_STYLE.COLOR_ACCENT_COOL)
	prompt_stack.add_child(_prompt_title_label)

	_prompt_action_label = UI_STYLE.make_label("Interact", 18, UI_STYLE.COLOR_TEXT)
	prompt_stack.add_child(_prompt_action_label)

	_prompt_progress = ProgressBar.new()
	_prompt_progress.custom_minimum_size = Vector2(0.0, 7.0)
	_prompt_progress.min_value = 0.0
	_prompt_progress.max_value = 100.0
	_prompt_progress.value = 0.0
	UI_STYLE.apply_progress(_prompt_progress)
	prompt_stack.add_child(_prompt_progress)


func _build_message_panel(hud_root: Control) -> void:
	_message_panel = PanelContainer.new()
	_message_panel.name = "NarrativeMessage"
	_message_panel.anchor_left = 0.5
	_message_panel.anchor_right = 0.5
	_message_panel.anchor_top = 0.70
	_message_panel.anchor_bottom = 0.70
	_message_panel.offset_left = -430.0
	_message_panel.offset_right = 430.0
	_message_panel.offset_top = -54.0
	_message_panel.offset_bottom = 80.0
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.visible = false
	UI_STYLE.apply_panel(_message_panel)
	hud_root.add_child(_message_panel)

	var message_stack: VBoxContainer = VBoxContainer.new()
	message_stack.add_theme_constant_override("separation", 8)
	_message_panel.add_child(message_stack)

	_message_source_label = UI_STYLE.make_label("MEMORY", 12, UI_STYLE.COLOR_ACCENT)
	_message_source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_stack.add_child(_message_source_label)

	_message_body_label = UI_STYLE.make_label("", 21, UI_STYLE.COLOR_TEXT)
	_message_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_stack.add_child(_message_body_label)


func _build_pause_menu() -> void:
	_pause_canvas = CanvasLayer.new()
	_pause_canvas.name = "PauseMenu"
	_pause_canvas.layer = 100
	_pause_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_canvas)

	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_canvas.add_child(_pause_overlay)

	var fade: ColorRect = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.01, 0.005, 0.018, 0.90)
	_pause_overlay.add_child(fade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var pause_panel: PanelContainer = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(430.0, 430.0)
	UI_STYLE.apply_panel(pause_panel)
	center.add_child(pause_panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	pause_panel.add_child(stack)

	var heading: Label = UI_STYLE.make_label("PAUSED", 38, UI_STYLE.COLOR_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var chapter: Label = UI_STYLE.make_label(_resolve_chapter_title(), 13, UI_STYLE.COLOR_ACCENT_COOL)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(chapter)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 14.0)
	stack.add_child(spacer)

	_resume_button = UI_STYLE.make_button("RESUME", true, Vector2(300.0, 52.0))
	_resume_button.pressed.connect(_on_resume_pressed)
	stack.add_child(_resume_button)

	var restart_button: Button = UI_STYLE.make_button("RESTART CHAPTER", false, Vector2(300.0, 48.0))
	restart_button.pressed.connect(_on_restart_pressed)
	stack.add_child(restart_button)

	var title_button: Button = UI_STYLE.make_button("RETURN TO TITLE", false, Vector2(300.0, 48.0))
	title_button.pressed.connect(_on_title_pressed)
	stack.add_child(title_button)

	var quit_button: Button = UI_STYLE.make_button("QUIT GAME", false, Vector2(300.0, 48.0))
	quit_button.pressed.connect(_on_quit_pressed)
	stack.add_child(quit_button)


func _set_pause_open(open_value: bool) -> void:
	_pause_open = open_value
	_pause_overlay.visible = open_value
	get_tree().paused = open_value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open_value else Input.MOUSE_MODE_CAPTURED
	if open_value and _resume_button != null:
		_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	_set_pause_open(false)


func _on_restart_pressed() -> void:
	_set_pause_open(false)
	SFXDirector.stop_environment(0.2)
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	_set_pause_open(false)
	MusicDirector.stop_music(0.4)
	SFXDirector.stop_environment(0.4)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _resolve_chapter_title() -> String:
	var scene_name: String = str(get_parent().name) if get_parent() != null else ""
	match scene_name:
		"Cemetery":
			return "CHAPTER I  //  THE CEMETERY"
		"AfterlifeVoid":
			return "CHAPTER III  //  THE VOID"
		"RuinedNightclub":
			return "CHAPTER IV  //  THE RUINED CLUB"
		"SkeletonChamber":
			return "CHAPTER V  //  THE CHAMBER"
		_:
			return "OUT OF TIME"


func _add_mesh(
	parent: Node3D,
	mesh: Mesh,
	mesh_position: Vector3,
	mesh_scale: Vector3,
	material: Material,
	mesh_rotation_degrees: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.scale = mesh_scale
	instance.rotation_degrees = mesh_rotation_degrees
	instance.material_override = material
	parent.add_child(instance)
	return instance
