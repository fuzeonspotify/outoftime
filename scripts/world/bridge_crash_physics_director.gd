extends Node

const CENTER_IMPACT_DELAY: float = 11.25
const RAIL_IMPACT_DELAY: float = 15.05
const CRASH_PROP_LAYER: int = 8
const CAR_CRASH_LAYER: int = 16
const CENTER_BARRIER_COUNT: int = 7
const RIGHT_RAIL_SEGMENT_COUNT: int = 13

var _road: Node3D = null
var _crash_set: Node3D = null
var _elapsed: float = 0.0
var _armed: bool = false
var _center_triggered: bool = false
var _rail_triggered: bool = false
var _fragment_serial: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _launched_records: Array[Dictionary] = []
var _debug_canvas: CanvasLayer = null
var _debug_label: Label = null


func _ready() -> void:
	_rng.seed = 8142026
	process_priority = 300
	set_physics_process(true)
	print("BRIDGE PHYSICS DIRECTOR READY")


func _physics_process(delta: float) -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return

	if not _armed:
		_crash_set = _find_live_cinematic_crash_set()
		if _crash_set != null:
			_arm_from_live_crash_set()
		return

	_elapsed += delta

	# The trigger clock begins when the exact cinematic crash set appears. These
	# times match road_memory_final_cut.gd and do not depend on private variables,
	# inherited callbacks, car collision, or frame-perfect position detection.
	if not _center_triggered and _elapsed >= CENTER_IMPACT_DELAY:
		_trigger_center_impact()
	if not _rail_triggered and _elapsed >= RAIL_IMPACT_DELAY:
		_trigger_right_rail_impact()

	_reinforce_launched_bodies(delta)


func _find_live_cinematic_crash_set() -> Node3D:
	var exact_set: Node3D = _road.get_node_or_null("CenteredBridgeCrashSet") as Node3D
	if exact_set != null:
		return exact_set
	var legacy_set: Node3D = _road.get_node_or_null("BridgeCrashSet") as Node3D
	if legacy_set != null:
		return legacy_set
	return null


func _arm_from_live_crash_set() -> void:
	_armed = true
	_elapsed = 0.0
	_build_collision_deck()
	_build_debug_overlay()
	_show_debug_status("PHYSICS ARMED — WAITING FOR IMPACT", Color("8fd7ff"))
	print(
		"BRIDGE PHYSICS ARMED FROM LIVE SET: ",
		_crash_set.name,
		" at ",
		_crash_set.global_position
	)


func _trigger_center_impact() -> void:
	if _center_triggered or _crash_set == null or not is_instance_valid(_crash_set):
		return
	_center_triggered = true
	_hide_original_center_obstacles()

	var launched_count: int = 0
	for barrier_index: int in range(CENTER_BARRIER_COUNT):
		var center_x: float = -6.0 + float(barrier_index) * 2.0
		var outward: float = signf(center_x)
		if is_zero_approx(outward):
			outward = -1.0 if barrier_index % 2 == 0 else 1.0

		launched_count += int(_spawn_rigid_piece(
			"Barrier%02d_Base" % barrier_index,
			Vector3(center_x, 0.22, 0.0),
			Vector3(1.88, 0.42, 1.10),
			Color("aaa79f"),
			12.0,
			Vector3(outward * _rng.randf_range(5.5, 9.5), _rng.randf_range(4.0, 7.0), _rng.randf_range(-13.0, -7.0))
		))
		launched_count += int(_spawn_rigid_piece(
			"Barrier%02d_LeftChunk" % barrier_index,
			Vector3(center_x - 0.47, 0.89, 0.0),
			Vector3(0.90, 0.92, 1.04),
			Color("cbc7bd"),
			10.0,
			Vector3(outward * _rng.randf_range(8.0, 14.0), _rng.randf_range(8.0, 15.0), _rng.randf_range(-17.0, -8.0)),
			Color("ff315f") if barrier_index % 2 == 0 else Color.TRANSPARENT
		))
		launched_count += int(_spawn_rigid_piece(
			"Barrier%02d_RightChunk" % barrier_index,
			Vector3(center_x + 0.47, 0.89, 0.0),
			Vector3(0.90, 0.92, 1.04),
			Color("c3bfb5"),
			10.0,
			Vector3(outward * _rng.randf_range(9.0, 15.0), _rng.randf_range(7.0, 14.0), _rng.randf_range(-16.0, -7.0)),
			Color("ff315f") if barrier_index % 2 != 0 else Color.TRANSPARENT
		))

	for warning_index: int in range(5):
		var warning_x: float = -4.0 + float(warning_index) * 2.0
		var warning_outward: float = -1.0 if warning_index < 3 else 1.0
		launched_count += int(_spawn_rigid_piece(
			"WarningPanel%02d" % warning_index,
			Vector3(warning_x, 0.24, 5.8),
			Vector3(1.12, 0.22, 2.30),
			Color("d42f66"),
			5.0,
			Vector3(warning_outward * _rng.randf_range(12.0, 19.0), _rng.randf_range(10.0, 18.0), _rng.randf_range(-18.0, -9.0)),
			Color("ff2d70")
		))

	_spawn_fragment_burst(Vector3(0.0, 0.78, 0.0), 56, Color("c6c1b8"))
	_spawn_impact_flash(Vector3(0.0, 1.0, 0.0), Color("ff653f"))
	_show_debug_status("PHYSICS IMPACT — %d ROADBLOCK PIECES" % launched_count, Color("ffad73"))
	print("BRIDGE PHYSICS CENTER IMPACT: spawned ", launched_count, " fresh rigid pieces.")


func _trigger_right_rail_impact() -> void:
	if _rail_triggered or _crash_set == null or not is_instance_valid(_crash_set):
		return
	_rail_triggered = true
	_hide_original_right_guardrail()

	var launched_count: int = 0
	for segment_index: int in range(RIGHT_RAIL_SEGMENT_COUNT):
		var z_position: float = 10.0 - float(segment_index) * 4.0
		var distance_from_hit: float = absf(z_position + 14.5)
		var weight: float = clampf(1.0 - distance_from_hit / 34.0, 0.34, 1.0)
		launched_count += int(_spawn_rigid_piece(
			"RightRail%02d_Beam" % segment_index,
			Vector3(7.55, 1.03, z_position),
			Vector3(0.30, 0.48, 3.76),
			Color("586780"),
			13.0,
			Vector3(_rng.randf_range(13.0, 22.0) * weight, _rng.randf_range(7.0, 15.0) * weight, _rng.randf_range(-11.0, 8.0) * weight)
		))
		launched_count += int(_spawn_rigid_piece(
			"RightRail%02d_Post" % segment_index,
			Vector3(7.55, 0.52, z_position),
			Vector3(0.38, 1.04, 0.42),
			Color("46546b"),
			8.0,
			Vector3(_rng.randf_range(12.0, 21.0) * weight, _rng.randf_range(6.0, 14.0) * weight, _rng.randf_range(-10.0, 9.0) * weight)
		))

	_spawn_fragment_burst(Vector3(7.55, 0.90, -14.5), 48, Color("65748d"))
	_spawn_impact_flash(Vector3(7.55, 1.05, -14.5), Color("ffd08a"))
	_show_debug_status("PHYSICS IMPACT — %d GUARDRAIL PIECES" % launched_count, Color("ffe29c"))
	print("BRIDGE PHYSICS RAIL IMPACT: spawned ", launched_count, " fresh rigid pieces.")


func _spawn_rigid_piece(
	piece_name: String,
	local_position: Vector3,
	box_size: Vector3,
	color: Color,
	body_mass: float,
	local_velocity: Vector3,
	emission_color: Color = Color.TRANSPARENT
) -> bool:
	if _road == null or _crash_set == null:
		return false

	var body: RigidBody3D = RigidBody3D.new()
	body.name = piece_name
	body.mass = body_mass
	body.gravity_scale = 1.35
	body.can_sleep = false
	body.sleeping = false
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.linear_damp = 0.06
	body.angular_damp = 0.04
	body.collision_layer = CRASH_PROP_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER | CAR_CRASH_LAYER

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.52
	physics_material.bounce = 0.24
	body.physics_material_override = physics_material
	_add_visual_and_collision(body, box_size, color, emission_color)
	_road.add_child(body)

	body.global_transform = Transform3D(
		_crash_set.global_basis,
		_crash_set.to_global(local_position)
	)

	var global_velocity: Vector3 = _crash_set.global_basis * local_velocity
	var angular_velocity: Vector3 = Vector3(
		_rng.randf_range(-13.0, 13.0),
		_rng.randf_range(-15.0, 15.0),
		_rng.randf_range(-18.0, 18.0)
	)
	_launch_body_after_physics_frame(body, global_velocity, angular_velocity)
	_launched_records.append({
		"body": body,
		"start": body.global_position,
		"velocity": global_velocity,
		"angular": angular_velocity,
		"age": 0.0,
		"retry_count": 0
	})
	return true


func _launch_body_after_physics_frame(
	body: RigidBody3D,
	global_velocity: Vector3,
	angular_velocity: Vector3
) -> void:
	await get_tree().physics_frame
	if body == null or not is_instance_valid(body):
		return
	body.sleeping = false
	body.linear_velocity = global_velocity
	body.angular_velocity = angular_velocity
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,
		global_velocity
	)
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY,
		angular_velocity
	)
	body.apply_central_impulse(global_velocity * body.mass * 0.42)
	body.apply_torque_impulse(angular_velocity * body.mass * 0.18)


func _reinforce_launched_bodies(delta: float) -> void:
	for record_index: int in range(_launched_records.size() - 1, -1, -1):
		var record: Dictionary = _launched_records[record_index]
		var body: RigidBody3D = record.get("body") as RigidBody3D
		if body == null or not is_instance_valid(body):
			_launched_records.remove_at(record_index)
			continue

		var age: float = float(record.get("age", 0.0)) + delta
		record["age"] = age
		var velocity: Vector3 = record.get("velocity", Vector3.ZERO)
		var angular: Vector3 = record.get("angular", Vector3.ZERO)

		if age < 0.45:
			body.sleeping = false
			body.apply_central_force(velocity * body.mass * 3.4)

		if age >= 0.40 and int(record.get("retry_count", 0)) < 2:
			var start_position: Vector3 = record.get("start", body.global_position)
			if body.global_position.distance_to(start_position) < 0.25:
				var retry_count: int = int(record.get("retry_count", 0)) + 1
				record["retry_count"] = retry_count
				var boosted_velocity: Vector3 = velocity * (1.7 + float(retry_count) * 0.55)
				body.sleeping = false
				body.linear_velocity = boosted_velocity
				body.angular_velocity = angular * 1.4
				PhysicsServer3D.body_set_state(
					body.get_rid(),
					PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,
					boosted_velocity
				)
				body.apply_central_impulse(boosted_velocity * body.mass * 0.65)

		if age > 7.0:
			body.queue_free()
			_launched_records.remove_at(record_index)
		else:
			_launched_records[record_index] = record


func _build_collision_deck() -> void:
	var deck: StaticBody3D = StaticBody3D.new()
	deck.name = "PhysicsCrashCollisionDeck"
	deck.collision_layer = 1
	deck.collision_mask = CRASH_PROP_LAYER | CAR_CRASH_LAYER
	_road.add_child(deck)
	deck.global_transform = Transform3D(
		_crash_set.global_basis,
		_crash_set.to_global(Vector3(0.0, -0.06, -13.0))
	)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(16.0, 0.22, 52.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	deck.add_child(collision)


func _hide_original_center_obstacles() -> void:
	var mesh_nodes: Array[Node] = _crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		var is_center_barrier: bool = bool(mesh_instance.get_meta("crash_barrier", false))
		is_center_barrier = is_center_barrier or str(mesh_instance.name).begins_with("CenteredRoadblock")
		var is_warning_board: bool = (
			absf(mesh_instance.position.z - 5.8) < 0.8
			and mesh_instance.position.y < 0.50
			and absf(mesh_instance.position.x) < 6.0
		)
		if is_center_barrier or is_warning_board:
			mesh_instance.visible = false


func _hide_original_right_guardrail() -> void:
	var mesh_nodes: Array[Node] = _crash_set.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var rail: MeshInstance3D = node as MeshInstance3D
		if rail == null or not bool(rail.get_meta("crash_rail", false)):
			continue
		if rail.position.x > 0.0:
			rail.visible = false


func _add_visual_and_collision(
	body: CollisionObject3D,
	box_size: Vector3,
	color: Color,
	emission_color: Color = Color.TRANSPARENT
) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.34
	material.roughness = 0.50
	if emission_color.a > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 2.8
	mesh.material = material

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "PhysicsVisual"
	visual.mesh = mesh
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "PhysicsCollision"
	collision.shape = shape
	body.add_child(collision)


func _spawn_fragment_burst(origin: Vector3, count: int, base_color: Color) -> void:
	for _index: int in range(count):
		var serial: int = _fragment_serial
		_fragment_serial += 1
		var fragment_size: Vector3 = Vector3(
			_rng.randf_range(0.08, 0.36),
			_rng.randf_range(0.06, 0.28),
			_rng.randf_range(0.12, 0.68)
		)
		_spawn_rigid_piece(
			"ImpactFragment_%03d" % serial,
			origin + Vector3(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-0.1, 1.0),
				_rng.randf_range(-1.0, 1.0)
			),
			fragment_size,
			base_color.darkened(_rng.randf_range(0.0, 0.32)),
			_rng.randf_range(0.18, 1.5),
			Vector3(
				_rng.randf_range(-17.0, 19.0),
				_rng.randf_range(10.0, 23.0),
				_rng.randf_range(-20.0, 16.0)
			),
			Color("ff9d52") if serial % 9 == 0 else Color.TRANSPARENT
		)


func _spawn_impact_flash(origin: Vector3, flash_color: Color) -> void:
	var flash: OmniLight3D = OmniLight3D.new()
	flash.name = "PhysicalWreckFlash"
	flash.position = _crash_set.to_global(origin)
	flash.light_color = flash_color
	flash.light_energy = 16.0
	flash.omni_range = 18.0
	flash.light_volumetric_fog_energy = 0.0
	_road.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.34).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(Callable(flash, "queue_free"))


func _build_debug_overlay() -> void:
	if not OS.is_debug_build() or _debug_canvas != null:
		return
	_debug_canvas = CanvasLayer.new()
	_debug_canvas.layer = 250
	_road.add_child(_debug_canvas)
	_debug_label = Label.new()
	_debug_label.position = Vector2(18.0, 150.0)
	_debug_label.size = Vector2(760.0, 42.0)
	_debug_label.add_theme_font_size_override("font_size", 18)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 6)
	_debug_canvas.add_child(_debug_label)


func _show_debug_status(message: String, color: Color) -> void:
	if _debug_label == null:
		return
	_debug_label.text = message
	_debug_label.add_theme_color_override("font_color", color)
	_debug_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(_debug_label, "modulate:a", 0.0, 0.55)
