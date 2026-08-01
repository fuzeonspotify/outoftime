extends "res://scripts/world/road_memory_exact_car.gd"

const CRASH_PROP_LAYER: int = 8
const CAR_CRASH_LAYER: int = 16
const DEBRIS_LIFETIME: float = 7.5

var _crash_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_crash_rng.seed = 8142026
	super._ready()
	_install_car_crash_collider.call_deferred()


func _install_car_crash_collider() -> void:
	# The exact-car cleanup runs for 32 deferred frames. Install the physical
	# collider after that pass so it cannot be mistaken for legacy car geometry.
	for _frame_index: int in range(36):
		await get_tree().process_frame
	if _car == null or not is_instance_valid(_car):
		return
	if _car.get_node_or_null("CrashCollider") != null:
		return

	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.name = "CrashCollider"
	body.position = Vector3(0.0, 0.72, 0.0)
	body.sync_to_physics = true
	body.collision_layer = CAR_CRASH_LAYER
	body.collision_mask = CRASH_PROP_LAYER

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.92, 1.28, 4.62)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_car.add_child(body)


func _build_crash_set() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BridgeCrashSet"
	root.position = _car.position + Vector3(0.0, 0.0, -35.0)
	add_child(root)

	_create_static_crash_box(
		root,
		"CrashDeck",
		Vector3(0.0, -0.02, 0.0),
		Vector3(12.0, 0.16, 18.0),
		Color("161321")
	)
	_create_static_crash_box(
		root,
		"CrashVoidLip",
		Vector3(0.0, -0.12, -12.0),
		Vector3(12.0, 0.10, 8.0),
		Color("010003")
	)

	# Segmented rails bend and scatter independently instead of rotating as one
	# fake mesh. All segments are real rigid bodies resting against the deck.
	for side: float in [-1.0, 1.0]:
		for segment_index: int in range(9):
			var z_position: float = 7.0 - float(segment_index) * 2.0
			var rail: RigidBody3D = _create_rigid_crash_box(
				root,
				"PhysicsRail_%s_%02d" % ["L" if side < 0.0 else "R", segment_index],
				Vector3(side * 5.72, 0.72, z_position),
				Vector3(0.28, 1.42, 1.86),
				Color("53627b"),
				24.0
			)
			rail.set_meta("crash_rail", true)
			rail.set_meta("impact_side", side)
			rail.set_meta("breakable", true)

	# The objects in the lane are also physical. Their panels and feet separate
	# at impact and can collide with the Porsche, rail, road and one another.
	for warning_index: int in range(5):
		var warning_x: float = -4.0 + float(warning_index) * 2.0
		var warning_z: float = -4.5 + absf(warning_x) * 0.08
		var panel: RigidBody3D = _create_rigid_crash_box(
			root,
			"PhysicsWarningPanel_%02d" % warning_index,
			Vector3(warning_x, 0.72, warning_z),
			Vector3(1.28, 0.82, 0.30),
			Color("d42f66"),
			10.0,
			Color("ff2d70")
		)
		panel.set_meta("warning_panel", true)
		panel.set_meta("breakable", true)

		for foot_side: float in [-1.0, 1.0]:
			var foot: RigidBody3D = _create_rigid_crash_box(
				root,
				"PhysicsWarningFoot_%02d_%s" % [warning_index, "L" if foot_side < 0.0 else "R"],
				Vector3(warning_x + foot_side * 0.40, 0.18, warning_z),
				Vector3(0.22, 0.36, 0.76),
				Color("5a233b"),
				4.0
			)
			foot.set_meta("warning_foot", true)
			foot.set_meta("breakable", true)

	return root


func _break_guardrail(crash_set: Node3D) -> void:
	if crash_set == null or not is_instance_valid(crash_set):
		return

	var impact_origin: Vector3 = Vector3(3.4, 0.72, -3.6)
	var rigid_nodes: Array[Node] = crash_set.find_children("*", "RigidBody3D", true, false)
	for node: Node in rigid_nodes:
		var body: RigidBody3D = node as RigidBody3D
		if body == null or not bool(body.get_meta("breakable", false)):
			continue

		# Keep the untouched left rail stable while the impact-side rail, warning
		# panels and feet react physically to the car.
		var is_rail: bool = bool(body.get_meta("crash_rail", false))
		if is_rail and float(body.get_meta("impact_side", -1.0)) < 0.0:
			continue

		body.freeze = false
		body.sleeping = false
		var away: Vector3 = body.position - impact_origin
		if away.length_squared() < 0.001:
			away = Vector3.RIGHT
		away = away.normalized()
		away.y = absf(away.y) + _crash_rng.randf_range(0.30, 0.82)

		var impulse_strength: float = 28.0
		if is_rail:
			impulse_strength = 42.0
		elif bool(body.get_meta("warning_panel", false)):
			impulse_strength = 34.0
		var impulse: Vector3 = away.normalized() * impulse_strength
		impulse += Vector3(
			_crash_rng.randf_range(4.0, 13.0),
			_crash_rng.randf_range(8.0, 18.0),
			_crash_rng.randf_range(-9.0, 9.0)
		)
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(Vector3(
			_crash_rng.randf_range(-18.0, 18.0),
			_crash_rng.randf_range(-22.0, 22.0),
			_crash_rng.randf_range(-26.0, 26.0)
		))

	_spawn_impact_fragments(crash_set, impact_origin)
	_spawn_impact_flash(crash_set, impact_origin)
	_cleanup_crash_physics_later(crash_set)


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
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.linear_damp = 0.12
	body.angular_damp = 0.10
	body.collision_layer = CRASH_PROP_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER | CAR_CRASH_LAYER

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.58
	physics_material.bounce = 0.16
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
	material.metallic = 0.48
	material.roughness = 0.44
	if emission_color.a > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 2.8
	mesh.material = material

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func _spawn_impact_fragments(crash_set: Node3D, impact_origin: Vector3) -> void:
	for fragment_index: int in range(30):
		var shard_size: Vector3 = Vector3(
			_crash_rng.randf_range(0.06, 0.26),
			_crash_rng.randf_range(0.05, 0.20),
			_crash_rng.randf_range(0.10, 0.50)
		)
		var shard_color: Color = Color("5c6880")
		if fragment_index % 4 == 0:
			shard_color = Color("d63269")
		elif fragment_index % 5 == 0:
			shard_color = Color("f4b45d")

		var shard: RigidBody3D = _create_rigid_crash_box(
			crash_set,
			"ImpactShard_%02d" % fragment_index,
			impact_origin + Vector3(
				_crash_rng.randf_range(-0.75, 0.75),
				_crash_rng.randf_range(-0.15, 0.70),
				_crash_rng.randf_range(-0.75, 0.75)
			),
			shard_size,
			shard_color,
			_crash_rng.randf_range(0.18, 1.2),
			Color("ff9d52") if fragment_index % 5 == 0 else Color(0.0, 0.0, 0.0, 0.0)
		)
		shard.freeze = false
		var direction: Vector3 = Vector3(
			_crash_rng.randf_range(-0.55, 1.0),
			_crash_rng.randf_range(0.28, 1.0),
			_crash_rng.randf_range(-1.0, 1.0)
		).normalized()
		shard.apply_central_impulse(direction * _crash_rng.randf_range(9.0, 25.0))
		shard.apply_torque_impulse(Vector3(
			_crash_rng.randf_range(-12.0, 12.0),
			_crash_rng.randf_range(-12.0, 12.0),
			_crash_rng.randf_range(-12.0, 12.0)
		))


func _spawn_impact_flash(crash_set: Node3D, impact_origin: Vector3) -> void:
	var flash: OmniLight3D = OmniLight3D.new()
	flash.name = "PhysicalImpactFlash"
	flash.position = impact_origin + Vector3(0.0, 0.75, 0.0)
	flash.light_color = Color("ff7b39")
	flash.light_energy = 12.0
	flash.omni_range = 14.0
	crash_set.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.24).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(Callable(flash, "queue_free"))


func _cleanup_crash_physics_later(crash_set: Node3D) -> void:
	await get_tree().create_timer(DEBRIS_LIFETIME).timeout
	if crash_set != null and is_instance_valid(crash_set):
		crash_set.queue_free()
