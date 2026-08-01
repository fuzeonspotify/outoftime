extends "res://scripts/world/road_memory_exact_car.gd"

const CRASH_PROP_LAYER: int = 8
const CAR_CRASH_LAYER: int = 16
const DEBRIS_LIFETIME: float = 10.0
const CENTER_BARRIER_COUNT: int = 7
const RAIL_SEGMENT_COUNT: int = 14

var _crash_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _crash_car_body: AnimatableBody3D
var _fragment_serial: int = 0


func _ready() -> void:
	_crash_rng.seed = 8142026
	super._ready()
	_install_car_crash_collider.call_deferred()


func _physics_process(_delta: float) -> void:
	# The Porsche is animated by the cinematic with a Node3D tween. Keep a
	# separate AnimatableBody3D synchronized in physics space so it can transfer
	# motion to the rigid wreck props instead of being only a visual model.
	if (
		_crash_car_body == null
		or not is_instance_valid(_crash_car_body)
		or _car == null
		or not is_instance_valid(_car)
	):
		return
	_crash_car_body.global_transform = _car.global_transform


func _install_car_crash_collider() -> void:
	# The exact-car cleanup runs for 32 deferred frames. Install the collider as a
	# scene-root sibling after that pass so it cannot be removed as legacy car
	# geometry and so parent Node3D movement cannot bypass physics synchronization.
	for _frame_index: int in range(36):
		await get_tree().process_frame
	if _car == null or not is_instance_valid(_car):
		push_error("BRIDGE PHYSICS ERROR: Porsche root is unavailable for its crash collider.")
		return
	if get_node_or_null("PorscheCrashPhysicsBody") != null:
		return

	_crash_car_body = AnimatableBody3D.new()
	_crash_car_body.name = "PorscheCrashPhysicsBody"
	_crash_car_body.sync_to_physics = true
	_crash_car_body.collision_layer = CAR_CRASH_LAYER
	_crash_car_body.collision_mask = CRASH_PROP_LAYER
	_crash_car_body.global_transform = _car.global_transform
	add_child(_crash_car_body)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.96, 1.30, 4.64)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "PorscheCrashShape"
	collision.position = Vector3(0.0, 0.70, 0.0)
	collision.shape = shape
	_crash_car_body.add_child(collision)


func _build_crash_set() -> Node3D:
	# This layout is aligned to road_memory_final_cut.gd. That script treats the
	# crash-set origin as the centered roadblock impact and later moves the car to
	# local X ~= 6.15 / Z ~= -14.5 for the right-rail impact.
	var root: Node3D = Node3D.new()
	root.name = "BridgeCrashSet"
	root.position = Vector3(CRASH_CENTER_X, 0.0, _car.position.z - ROADBLOCK_DISTANCE)
	root.set_meta("physics_crash_set", true)
	add_child(root)

	_create_static_crash_box(
		root,
		"CrashDeck",
		Vector3(0.0, -0.03, -13.0),
		Vector3(16.0, 0.18, 52.0),
		Color("161321")
	)
	_create_static_crash_box(
		root,
		"CrashVoidLip",
		Vector3(0.0, -0.15, -41.0),
		Vector3(16.0, 0.10, 8.0),
		Color("010003")
	)

	# Real rigid concrete roadblocks sit exactly at the first scripted impact.
	for barrier_index: int in range(CENTER_BARRIER_COUNT):
		var barrier_x: float = -6.0 + float(barrier_index) * 2.0
		var barrier: RigidBody3D = _create_rigid_crash_box(
			root,
			"PhysicsCenteredBarrier_%02d" % barrier_index,
			Vector3(barrier_x, 0.72, 0.0),
			Vector3(1.88, 1.38, 1.10),
			Color("c8c4bb"),
			32.0,
			Color("ff315f") if barrier_index % 2 == 0 else Color(0.0, 0.0, 0.0, 0.0)
		)
		barrier.set_meta("crash_barrier", true)
		barrier.set_meta("barrier_index", barrier_index)

	# Warning panels are separate rigid pieces, not decorations attached to the
	# roadblock. They are thrown by the first impact shockwave.
	for warning_index: int in range(5):
		var warning_x: float = -4.0 + float(warning_index) * 2.0
		var panel: RigidBody3D = _create_rigid_crash_box(
			root,
			"PhysicsWarningPanel_%02d" % warning_index,
			Vector3(warning_x, 0.24, 5.8),
			Vector3(1.10, 0.20, 2.30),
			Color("d42f66"),
			7.0,
			Color("ff2d70")
		)
		panel.rotation_degrees.y = 16.0 if warning_index % 2 == 0 else -16.0
		panel.set_meta("warning_panel", true)

	# Both rails are segmented rigid bodies. The left rail remains intact while
	# the right-side segments around Z -14.5 are released at the second impact.
	for side: float in [-1.0, 1.0]:
		for segment_index: int in range(RAIL_SEGMENT_COUNT):
			var z_position: float = 11.0 - float(segment_index) * 4.0
			var rail: RigidBody3D = _create_rigid_crash_box(
				root,
				"PhysicsRail_%s_%02d" % ["L" if side < 0.0 else "R", segment_index],
				Vector3(side * 7.05, 0.82, z_position),
				Vector3(0.34, 1.64, 3.82),
				Color("53627b"),
				38.0
			)
			rail.set_meta("crash_rail", true)
			rail.set_meta("impact_side", side)
			rail.set_meta("rail_segment_index", segment_index)

	_verify_crash_set(root)
	return root


# road_memory_final_cut.gd calls this exact method at the centered collision.
func _break_centered_roadblock(crash_set: Node3D) -> void:
	if crash_set == null or not is_instance_valid(crash_set):
		push_error("BRIDGE PHYSICS ERROR: centered impact received no crash set.")
		return

	var activated_count: int = 0
	var rigid_nodes: Array[Node] = crash_set.find_children("*", "RigidBody3D", true, false)
	for node: Node in rigid_nodes:
		var body: RigidBody3D = node as RigidBody3D
		if body == null:
			continue
		var is_barrier: bool = bool(body.get_meta("crash_barrier", false))
		var is_warning: bool = bool(body.get_meta("warning_panel", false))
		if not is_barrier and not is_warning:
			continue

		var outward: float = signf(body.position.x)
		if is_zero_approx(outward):
			outward = -1.0 if _crash_rng.randf() < 0.5 else 1.0
		var local_velocity: Vector3 = Vector3(
			outward * _crash_rng.randf_range(5.5, 11.5),
			_crash_rng.randf_range(5.0, 10.5),
			_crash_rng.randf_range(-11.0, -5.0)
		)
		if is_warning:
			local_velocity *= 1.35
		_activate_rigid_body(body, crash_set.global_basis * local_velocity)
		activated_count += 1

	if activated_count == 0:
		push_error("BRIDGE PHYSICS ERROR: no centered rigid roadblocks were activated.")
	else:
		crash_set.set_meta("center_physics_activated", true)

	_spawn_impact_fragments(crash_set, Vector3(0.0, 0.72, 0.0), 36, "Center")
	_spawn_impact_flash(crash_set, Vector3(0.0, 0.95, 0.0), Color("ff633d"))
	_schedule_crash_cleanup(crash_set)


# road_memory_final_cut.gd calls this exact method during the sideways slide.
func _break_right_guardrail(crash_set: Node3D) -> void:
	if crash_set == null or not is_instance_valid(crash_set):
		push_error("BRIDGE PHYSICS ERROR: rail impact received no crash set.")
		return

	var rail_impact_z: float = -14.5
	var activated_count: int = 0
	var rigid_nodes: Array[Node] = crash_set.find_children("*", "RigidBody3D", true, false)
	for node: Node in rigid_nodes:
		var body: RigidBody3D = node as RigidBody3D
		if body == null or not bool(body.get_meta("crash_rail", false)):
			continue
		if float(body.get_meta("impact_side", -1.0)) < 0.0:
			continue

		var distance_from_hit: float = absf(body.position.z - rail_impact_z)
		var impact_weight: float = clampf(1.0 - distance_from_hit / 30.0, 0.28, 1.0)
		var local_velocity: Vector3 = Vector3(
			_crash_rng.randf_range(8.5, 15.0) * impact_weight,
			_crash_rng.randf_range(4.5, 10.0) * impact_weight,
			_crash_rng.randf_range(-7.0, 4.0) * impact_weight
		)
		_activate_rigid_body(body, crash_set.global_basis * local_velocity)
		activated_count += 1

	if activated_count == 0:
		push_error("BRIDGE PHYSICS ERROR: no right guardrail rigid bodies were activated.")
	else:
		crash_set.set_meta("right_rail_physics_activated", true)

	var impact_origin: Vector3 = Vector3(7.05, 0.82, rail_impact_z)
	_spawn_impact_fragments(crash_set, impact_origin, 28, "Rail")
	_spawn_impact_flash(crash_set, impact_origin, Color("ffd08a"))
	_schedule_crash_cleanup(crash_set)


# Compatibility with older crash sequences that called the former combined
# method. The active final-cut sequence uses the two overrides above.
func _break_guardrail(crash_set: Node3D) -> void:
	_break_centered_roadblock(crash_set)


func _activate_rigid_body(body: RigidBody3D, global_velocity: Vector3) -> void:
	body.freeze = false
	body.sleeping = false
	body.can_sleep = false
	body.linear_velocity = global_velocity
	body.angular_velocity = Vector3(
		_crash_rng.randf_range(-8.0, 8.0),
		_crash_rng.randf_range(-10.0, 10.0),
		_crash_rng.randf_range(-12.0, 12.0)
	)
	body.apply_central_impulse(global_velocity * body.mass * 0.16)
	body.apply_torque_impulse(Vector3(
		_crash_rng.randf_range(-16.0, 16.0),
		_crash_rng.randf_range(-18.0, 18.0),
		_crash_rng.randf_range(-22.0, 22.0)
	))


func _create_static_crash_box(
	parent: Node3D,
	body_name: String,
	body_position: Vector3,
	box_size: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = body_position
	body.collision_layer = 1
	body.collision_mask = CRASH_PROP_LAYER | CAR_CRASH_LAYER
	_add_box_visual_and_collision(body, box_size, color)
	parent.add_child(body)
	return body


func _create_rigid_crash_box(
	parent: Node3D,
	body_name: String,
	body_position: Vector3,
	box_size: Vector3,
	color: Color,
	body_mass: float,
	emission_color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = body_name
	body.position = body_position
	body.mass = body_mass
	body.gravity_scale = 1.12
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 12
	body.linear_damp = 0.10
	body.angular_damp = 0.08
	body.collision_layer = CRASH_PROP_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER | CAR_CRASH_LAYER

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.60
	physics_material.bounce = 0.18
	body.physics_material_override = physics_material

	_add_box_visual_and_collision(body, box_size, color, emission_color)
	parent.add_child(body)
	return body


func _add_box_visual_and_collision(
	body: CollisionObject3D,
	box_size: Vector3,
	color: Color,
	emission_color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.42
	material.roughness = 0.48
	if emission_color.a > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 2.6
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


func _spawn_impact_fragments(
	crash_set: Node3D,
	impact_origin: Vector3,
	fragment_count: int,
	stage_name: String
) -> void:
	for _fragment_index: int in range(fragment_count):
		var fragment_id: int = _fragment_serial
		_fragment_serial += 1
		var shard_size: Vector3 = Vector3(
			_crash_rng.randf_range(0.07, 0.30),
			_crash_rng.randf_range(0.05, 0.22),
			_crash_rng.randf_range(0.12, 0.58)
		)
		var shard_color: Color = Color("5c6880")
		if fragment_id % 4 == 0:
			shard_color = Color("d63269")
		elif fragment_id % 5 == 0:
			shard_color = Color("d4cfc5")

		var shard: RigidBody3D = _create_rigid_crash_box(
			crash_set,
			"%sImpactShard_%03d" % [stage_name, fragment_id],
			impact_origin + Vector3(
				_crash_rng.randf_range(-0.90, 0.90),
				_crash_rng.randf_range(-0.10, 0.85),
				_crash_rng.randf_range(-0.90, 0.90)
			),
			shard_size,
			shard_color,
			_crash_rng.randf_range(0.20, 1.4),
			Color("ff9d52") if fragment_id % 7 == 0 else Color(0.0, 0.0, 0.0, 0.0)
		)
		var local_velocity: Vector3 = Vector3(
			_crash_rng.randf_range(-9.0, 13.0),
			_crash_rng.randf_range(6.0, 17.0),
			_crash_rng.randf_range(-14.0, 10.0)
		)
		_activate_rigid_body(shard, crash_set.global_basis * local_velocity)


func _spawn_impact_flash(
	crash_set: Node3D,
	impact_origin: Vector3,
	flash_color: Color
) -> void:
	var flash: OmniLight3D = OmniLight3D.new()
	flash.name = "PhysicalImpactFlash"
	flash.position = impact_origin
	flash.light_color = flash_color
	flash.light_energy = 13.0
	flash.light_volumetric_fog_energy = 0.0
	flash.omni_range = 15.0
	crash_set.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(Callable(flash, "queue_free"))


func _verify_crash_set(crash_set: Node3D) -> void:
	var barrier_count: int = 0
	var left_rail_count: int = 0
	var right_rail_count: int = 0
	var rigid_nodes: Array[Node] = crash_set.find_children("*", "RigidBody3D", true, false)
	for node: Node in rigid_nodes:
		var body: RigidBody3D = node as RigidBody3D
		if body == null:
			continue
		if bool(body.get_meta("crash_barrier", false)):
			barrier_count += 1
		if bool(body.get_meta("crash_rail", false)):
			if float(body.get_meta("impact_side", 0.0)) < 0.0:
				left_rail_count += 1
			else:
				right_rail_count += 1

	crash_set.set_meta("center_barrier_count", barrier_count)
	crash_set.set_meta("left_rail_count", left_rail_count)
	crash_set.set_meta("right_rail_count", right_rail_count)
	if barrier_count != CENTER_BARRIER_COUNT:
		push_error("BRIDGE PHYSICS ERROR: expected %d centered barriers, found %d." % [CENTER_BARRIER_COUNT, barrier_count])
	if left_rail_count != RAIL_SEGMENT_COUNT or right_rail_count != RAIL_SEGMENT_COUNT:
		push_error(
			"BRIDGE PHYSICS ERROR: expected %d rail segments per side, found L%d/R%d." % [
				RAIL_SEGMENT_COUNT,
				left_rail_count,
				right_rail_count
			]
		)


func _schedule_crash_cleanup(crash_set: Node3D) -> void:
	if bool(crash_set.get_meta("cleanup_scheduled", false)):
		return
	crash_set.set_meta("cleanup_scheduled", true)
	_cleanup_crash_physics_later.call_deferred(crash_set)


func _cleanup_crash_physics_later(crash_set: Node3D) -> void:
	await get_tree().create_timer(DEBRIS_LIFETIME).timeout
	if crash_set != null and is_instance_valid(crash_set):
		crash_set.queue_free()
