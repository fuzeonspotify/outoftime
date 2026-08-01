extends Node

const ROADBLOCK_DISTANCE: float = 66.0
const CENTER_TRIGGER_SECONDS: float = 10.85
const RAIL_TRIGGER_SECONDS: float = 14.95
const CENTER_TRIGGER_DISTANCE: float = 4.8
const RAIL_TRIGGER_DISTANCE: float = 5.4
const CRASH_PROP_LAYER: int = 8
const CAR_CRASH_LAYER: int = 16
const CENTER_BARRIER_COUNT: int = 7
const RAIL_SEGMENT_COUNT: int = 13

var _road: Node3D
var _car: Node3D
var _wreck: Node3D
var _car_body: AnimatableBody3D
var _center_bodies: Array[RigidBody3D] = []
var _right_rail_bodies: Array[RigidBody3D] = []
var _launched_records: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _armed: bool = false
var _center_triggered: bool = false
var _rail_triggered: bool = false
var _elapsed: float = 0.0
var _fragment_serial: int = 0


func _ready() -> void:
	_rng.seed = 8142026
	process_priority = 200
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return

	_hide_visual_only_crash_sets()
	_sync_car_collider()

	if not _armed:
		if bool(_road.get("_crash_active")):
			_arm_physical_wreck()
		return

	_elapsed += delta
	_car = _road.get("_car") as Node3D
	if _car != null and is_instance_valid(_car):
		if not _center_triggered:
			var center_position: Vector3 = _wreck.to_global(Vector3(0.0, 0.72, 0.0))
			if _horizontal_distance(_car.global_position, center_position) <= CENTER_TRIGGER_DISTANCE:
				_trigger_center_impact()
		if _center_triggered and not _rail_triggered:
			var rail_position: Vector3 = _wreck.to_global(Vector3(7.05, 0.82, -14.5))
			if _horizontal_distance(_car.global_position, rail_position) <= RAIL_TRIGGER_DISTANCE:
				_trigger_right_rail_impact()

	# These time guards are intentionally independent of inherited callbacks.
	# Even if the cinematic path or car collider misses by a frame, the physical
	# wreck still releases at the exact final-cut impact timings.
	if not _center_triggered and _elapsed >= CENTER_TRIGGER_SECONDS:
		_trigger_center_impact()
	if _center_triggered and not _rail_triggered and _elapsed >= RAIL_TRIGGER_SECONDS:
		_trigger_right_rail_impact()

	_reinforce_launched_bodies()


func _arm_physical_wreck() -> void:
	_car = _road.get("_car") as Node3D
	if _car == null or not is_instance_valid(_car):
		push_error("BRIDGE PHYSICS ERROR: the Porsche was missing when the physical wreck armed.")
		return

	_armed = true
	_elapsed = 0.0
	_wreck = Node3D.new()
	_wreck.name = "PhysicalBridgeWreck"
	_road.add_child(_wreck)
	_wreck.global_position = Vector3(0.0, 0.0, _car.global_position.z - ROADBLOCK_DISTANCE)
	_wreck.set_meta("genuine_rigid_wreck", true)

	_build_collision_deck()
	_build_breakable_roadblock()
	_build_segmented_guardrails()
	_build_car_collider()

	print(
		"BRIDGE PHYSICS ARMED: ",
		_center_bodies.size(),
		" center pieces and ",
		_right_rail_bodies.size(),
		" right-rail pieces."
	)


func _build_collision_deck() -> void:
	_create_static_box(
		"PhysicsCrashDeck",
		Vector3(0.0, -0.04, -13.0),
		Vector3(16.0, 0.20, 52.0),
		Color("15131d")
	)
	_create_static_box(
		"PhysicsCrashVoidLip",
		Vector3(0.0, -0.18, -41.0),
		Vector3(16.0, 0.12, 8.0),
		Color("010003")
	)


func _build_breakable_roadblock() -> void:
	# Each concrete barrier is assembled from three independent rigid pieces.
	# They appear as one obstacle before impact and physically separate afterward.
	for barrier_index: int in range(CENTER_BARRIER_COUNT):
		var center_x: float = -6.0 + float(barrier_index) * 2.0
		var base: RigidBody3D = _create_held_rigid_box(
			"Barrier%02d_Base" % barrier_index,
			Vector3(center_x, 0.22, 0.0),
			Vector3(1.88, 0.42, 1.10),
			Color("aaa79f"),
			12.0
		)
		var left_chunk: RigidBody3D = _create_held_rigid_box(
			"Barrier%02d_LeftChunk" % barrier_index,
			Vector3(center_x - 0.47, 0.89, 0.0),
			Vector3(0.90, 0.92, 1.04),
			Color("cbc7bd"),
			10.0,
			Color("ff315f") if barrier_index % 2 == 0 else Color.TRANSPARENT
		)
		var right_chunk: RigidBody3D = _create_held_rigid_box(
			"Barrier%02d_RightChunk" % barrier_index,
			Vector3(center_x + 0.47, 0.89, 0.0),
			Vector3(0.90, 0.92, 1.04),
			Color("c3bfb5"),
			10.0,
			Color("ff315f") if barrier_index % 2 != 0 else Color.TRANSPARENT
		)
		for body: RigidBody3D in [base, left_chunk, right_chunk]:
			body.set_meta("center_piece", true)
			body.set_meta("barrier_index", barrier_index)
			_center_bodies.append(body)

	# Low warning boards are also genuine rigid objects and are launched first.
	for warning_index: int in range(5):
		var warning_x: float = -4.0 + float(warning_index) * 2.0
		var panel: RigidBody3D = _create_held_rigid_box(
			"WarningPanel%02d" % warning_index,
			Vector3(warning_x, 0.22, 5.8),
			Vector3(1.12, 0.22, 2.30),
			Color("d42f66"),
			5.0,
			Color("ff2d70")
		)
		panel.rotation_degrees.y = 16.0 if warning_index % 2 == 0 else -16.0
		panel.set_meta("warning_piece", true)
		_center_bodies.append(panel)


func _build_segmented_guardrails() -> void:
	for side: float in [-1.0, 1.0]:
		for segment_index: int in range(RAIL_SEGMENT_COUNT):
			var z_position: float = 10.0 - float(segment_index) * 4.0
			var beam: RigidBody3D = _create_held_rigid_box(
				"Rail%s_%02d_Beam" % ["L" if side < 0.0 else "R", segment_index],
				Vector3(side * 7.05, 1.03, z_position),
				Vector3(0.30, 0.48, 3.76),
				Color("586780"),
				13.0
			)
			var post: RigidBody3D = _create_held_rigid_box(
				"Rail%s_%02d_Post" % ["L" if side < 0.0 else "R", segment_index],
				Vector3(side * 7.05, 0.52, z_position),
				Vector3(0.38, 1.04, 0.42),
				Color("46546b"),
				8.0
			)
			for body: RigidBody3D in [beam, post]:
				body.set_meta("rail_piece", true)
				body.set_meta("rail_side", side)
				body.set_meta("rail_z", z_position)
				if side > 0.0:
					_right_rail_bodies.append(body)


func _build_car_collider() -> void:
	if _car_body != null and is_instance_valid(_car_body):
		return
	_car_body = AnimatableBody3D.new()
	_car_body.name = "PhysicalPorscheCollider"
	_car_body.sync_to_physics = true
	_car_body.collision_layer = CAR_CRASH_LAYER
	_car_body.collision_mask = CRASH_PROP_LAYER
	_road.add_child(_car_body)
	_car_body.global_transform = _car.global_transform

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.96, 1.30, 4.64)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "PorscheImpactShape"
	collision.position = Vector3(0.0, 0.70, 0.0)
	collision.shape = shape
	_car_body.add_child(collision)


func _sync_car_collider() -> void:
	if _car_body == null or not is_instance_valid(_car_body):
		return
	if _road == null:
		return
	_car = _road.get("_car") as Node3D
	if _car == null or not is_instance_valid(_car):
		return
	_car_body.global_transform = _car.global_transform


func _trigger_center_impact() -> void:
	if _center_triggered:
		return
	_center_triggered = true
	print("BRIDGE PHYSICS IMPACT: releasing physical roadblock pieces.")

	for body_index: int in range(_center_bodies.size()):
		var body: RigidBody3D = _center_bodies[body_index]
		if body == null or not is_instance_valid(body):
			continue
		var outward: float = signf(body.position.x)
		if is_zero_approx(outward):
			outward = -1.0 if body_index % 2 == 0 else 1.0
		var velocity: Vector3 = Vector3(
			outward * _rng.randf_range(7.0, 14.0),
			_rng.randf_range(7.0, 14.0),
			_rng.randf_range(-16.0, -7.0)
		)
		if bool(body.get_meta("warning_piece", false)):
			velocity *= 1.35
		_release_body(body, velocity)

	_spawn_fragment_burst(Vector3(0.0, 0.72, 0.0), 48, Color("c6c1b8"))
	_spawn_impact_flash(Vector3(0.0, 1.0, 0.0), Color("ff653f"))


func _trigger_right_rail_impact() -> void:
	if _rail_triggered:
		return
	_rail_triggered = true
	print("BRIDGE PHYSICS IMPACT: releasing segmented right guardrail.")

	for body: RigidBody3D in _right_rail_bodies:
		if body == null or not is_instance_valid(body):
			continue
		var rail_z: float = float(body.get_meta("rail_z", body.position.z))
		var weight: float = clampf(1.0 - absf(rail_z + 14.5) / 34.0, 0.32, 1.0)
		var velocity: Vector3 = Vector3(
			_rng.randf_range(11.0, 19.0) * weight,
			_rng.randf_range(6.0, 13.0) * weight,
			_rng.randf_range(-10.0, 7.0) * weight
		)
		_release_body(body, velocity)

	_spawn_fragment_burst(Vector3(7.05, 0.86, -14.5), 40, Color("65748d"))
	_spawn_impact_flash(Vector3(7.05, 1.05, -14.5), Color("ffd08a"))


func _release_body(body: RigidBody3D, local_velocity: Vector3) -> void:
	_unlock_body(body)
	body.gravity_scale = 1.25
	body.can_sleep = false
	body.sleeping = false
	var global_velocity: Vector3 = _wreck.global_basis * local_velocity
	body.linear_velocity = global_velocity
	body.angular_velocity = Vector3(
		_rng.randf_range(-11.0, 11.0),
		_rng.randf_range(-13.0, 13.0),
		_rng.randf_range(-15.0, 15.0)
	)
	body.apply_central_impulse(global_velocity * body.mass * 0.32)
	body.apply_torque_impulse(Vector3(
		_rng.randf_range(-24.0, 24.0),
		_rng.randf_range(-28.0, 28.0),
		_rng.randf_range(-32.0, 32.0)
	))
	_launched_records.append({
		"body": body,
		"start": body.global_position,
		"velocity": global_velocity,
		"age": 0.0,
		"rescued": false
	})


func _reinforce_launched_bodies() -> void:
	for record_index: int in range(_launched_records.size() - 1, -1, -1):
		var record: Dictionary = _launched_records[record_index]
		var body: RigidBody3D = record.get("body") as RigidBody3D
		if body == null or not is_instance_valid(body):
			_launched_records.remove_at(record_index)
			continue

		var age: float = float(record.get("age", 0.0)) + get_physics_process_delta_time()
		record["age"] = age
		var velocity: Vector3 = record.get("velocity", Vector3.ZERO)

		# Maintain a short physical force pulse rather than relying on a single
		# one-frame impulse that a solver or overlap correction could absorb.
		if age < 0.30:
			body.apply_central_force(velocity * body.mass * 2.8)

		if age >= 0.34 and not bool(record.get("rescued", false)):
			var start_position: Vector3 = record.get("start", body.global_position)
			if body.global_position.distance_to(start_position) < 0.22:
				# Still genuine rigid-body motion: unlock again, wake again, then use
				# a stronger velocity and impulse after the body has entered physics.
				_unlock_body(body)
				body.sleeping = false
				body.linear_velocity = velocity * 1.75
				body.angular_velocity = Vector3(8.0, -10.0, 12.0)
				body.apply_central_impulse(velocity * body.mass * 0.75)
			record["rescued"] = true

		if age > 3.0:
			_launched_records.remove_at(record_index)
		else:
			_launched_records[record_index] = record


func _create_held_rigid_box(
	body_name: String,
	local_position: Vector3,
	box_size: Vector3,
	color: Color,
	body_mass: float,
	emission_color: Color = Color.TRANSPARENT
) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = body_name
	body.position = local_position
	body.mass = body_mass
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.sleeping = false
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.linear_damp = 0.08
	body.angular_damp = 0.06
	body.collision_layer = CRASH_PROP_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER | CAR_CRASH_LAYER
	_lock_body(body)

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.58
	physics_material.bounce = 0.20
	body.physics_material_override = physics_material
	_add_visual_and_collision(body, box_size, color, emission_color)
	_wreck.add_child(body)
	return body


func _create_static_box(
	body_name: String,
	local_position: Vector3,
	box_size: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = local_position
	body.collision_layer = 1
	body.collision_mask = CRASH_PROP_LAYER | CAR_CRASH_LAYER
	_add_visual_and_collision(body, box_size, color)
	_wreck.add_child(body)
	return body


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
	material.metallic = 0.36
	material.roughness = 0.52
	if emission_color.a > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 2.8
	mesh.material = material
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "RigidVisual"
	visual.mesh = mesh
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "RigidCollision"
	collision.shape = shape
	body.add_child(collision)


func _spawn_fragment_burst(origin: Vector3, count: int, base_color: Color) -> void:
	for _index: int in range(count):
		var serial: int = _fragment_serial
		_fragment_serial += 1
		var size: Vector3 = Vector3(
			_rng.randf_range(0.08, 0.34),
			_rng.randf_range(0.06, 0.26),
			_rng.randf_range(0.12, 0.62)
		)
		var color: Color = base_color.darkened(_rng.randf_range(0.0, 0.30))
		var fragment: RigidBody3D = _create_held_rigid_box(
			"ImpactFragment_%03d" % serial,
			origin + Vector3(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-0.1, 1.0),
				_rng.randf_range(-1.0, 1.0)
			),
			size,
			color,
			_rng.randf_range(0.18, 1.4),
			Color("ff9d52") if serial % 8 == 0 else Color.TRANSPARENT
		)
		_release_body(fragment, Vector3(
			_rng.randf_range(-15.0, 17.0),
			_rng.randf_range(8.0, 21.0),
			_rng.randf_range(-18.0, 14.0)
		))


func _spawn_impact_flash(origin: Vector3, color: Color) -> void:
	var flash: OmniLight3D = OmniLight3D.new()
	flash.name = "PhysicalWreckFlash"
	flash.position = origin
	flash.light_color = color
	flash.light_energy = 16.0
	flash.omni_range = 18.0
	flash.light_volumetric_fog_energy = 0.0
	_wreck.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.34).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(Callable(flash, "queue_free"))


func _lock_body(body: RigidBody3D) -> void:
	body.axis_lock_linear_x = true
	body.axis_lock_linear_y = true
	body.axis_lock_linear_z = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true


func _unlock_body(body: RigidBody3D) -> void:
	body.axis_lock_linear_x = false
	body.axis_lock_linear_y = false
	body.axis_lock_linear_z = false
	body.axis_lock_angular_x = false
	body.axis_lock_angular_y = false
	body.axis_lock_angular_z = false


func _hide_visual_only_crash_sets() -> void:
	if _road == null:
		return
	for crash_name: String in ["CenteredBridgeCrashSet", "BridgeCrashSet"]:
		var nodes: Array[Node] = _road.find_children(crash_name, "Node3D", true, false)
		for node: Node in nodes:
			var legacy_set: Node3D = node as Node3D
			if legacy_set != null and legacy_set != _wreck:
				legacy_set.visible = false


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
