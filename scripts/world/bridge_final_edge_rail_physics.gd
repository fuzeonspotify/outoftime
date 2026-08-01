extends Node

const RAIL_BREAK_DELAY: float = 14.92
const EDGE_RAIL_X: float = 5.95
const IMPACT_LOCAL_Z: float = -14.5
const RAIL_SEGMENT_COUNT: int = 13
const CRASH_PROP_LAYER: int = 8
const CAR_CRASH_LAYER: int = 16

var _road: Node3D = null
var _crash_set: Node3D = null
var _elapsed: float = 0.0
var _armed: bool = false
var _triggered: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7312026
	process_priority = 320
	set_physics_process(true)
	print("BRIDGE FINAL EDGE RAIL PHYSICS READY")


func _physics_process(delta: float) -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return

	if not _armed:
		_crash_set = _find_live_crash_set()
		if _crash_set != null:
			_armed = true
			_elapsed = 0.0
			print("BRIDGE FINAL EDGE RAIL ARMED at ", _crash_set.global_position)
		return

	if _triggered:
		return

	_elapsed += delta
	if _elapsed >= RAIL_BREAK_DELAY:
		_trigger_final_edge_rail()


func _find_live_crash_set() -> Node3D:
	var exact_set: Node3D = _road.get_node_or_null("CenteredBridgeCrashSet") as Node3D
	if exact_set != null:
		return exact_set
	return _road.get_node_or_null("BridgeCrashSet") as Node3D


func _trigger_final_edge_rail() -> void:
	if _triggered or _crash_set == null or not is_instance_valid(_crash_set):
		return
	_triggered = true

	var hidden_count: int = _hide_original_bridge_edge_near_impact()
	var spawned_count: int = 0
	for segment_index: int in range(RAIL_SEGMENT_COUNT):
		var local_z: float = 10.0 - float(segment_index) * 4.0
		var distance_from_hit: float = absf(local_z - IMPACT_LOCAL_Z)
		var weight: float = clampf(1.0 - distance_from_hit / 34.0, 0.30, 1.0)

		if _spawn_dynamic_piece(
			"FinalEdgeBeam_%02d" % segment_index,
			Vector3(EDGE_RAIL_X, 0.45, local_z),
			Vector3(0.20, 0.30, 3.78),
			Color("586780"),
			11.0,
			Vector3(
				_rng.randf_range(11.0, 19.0) * weight,
				_rng.randf_range(4.5, 10.0) * weight,
				_rng.randf_range(-9.0, 7.0) * weight
			)
		):
			spawned_count += 1

		if _spawn_dynamic_piece(
			"FinalEdgePost_%02d" % segment_index,
			Vector3(EDGE_RAIL_X, 0.90, local_z),
			Vector3(0.12, 0.85, 0.12),
			Color("65708b"),
			5.5,
			Vector3(
				_rng.randf_range(10.0, 18.0) * weight,
				_rng.randf_range(5.0, 12.0) * weight,
				_rng.randf_range(-10.0, 8.0) * weight
			)
		):
			spawned_count += 1

	_spawn_spark_fragments()
	print(
		"BRIDGE FINAL EDGE RAIL IMPACT: hid ",
		hidden_count,
		" static edge pieces and spawned ",
		spawned_count,
		" rigid pieces at X=", EDGE_RAIL_X
	)


func _hide_original_bridge_edge_near_impact() -> int:
	var hidden_count: int = 0
	var impact_global_z: float = _crash_set.to_global(
		Vector3(EDGE_RAIL_X, 0.45, IMPACT_LOCAL_Z)
	).z
	var segments: Array[Node] = _road.find_children("BridgeSegment*", "Node3D", true, false)
	for segment_node: Node in segments:
		var segment: Node3D = segment_node as Node3D
		if segment == null:
			continue
		# Each base segment spans 16 units. Only remove the sections surrounding
		# the actual final impact so the distant bridge remains visually intact.
		if absf(segment.global_position.z - impact_global_z) > 42.0:
			continue
		var meshes: Array[Node] = segment.find_children("*", "MeshInstance3D", true, false)
		for mesh_node: Node in meshes:
			var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			if absf(mesh_instance.position.x - EDGE_RAIL_X) > 0.12:
				continue
			var box: BoxMesh = mesh_instance.mesh as BoxMesh
			if box == null:
				continue
			var size: Vector3 = box.size
			var is_long_beam: bool = (
				size.z >= 12.0
				and size.x <= 0.30
				and size.y <= 0.45
			)
			var is_vertical_post: bool = (
				size.x <= 0.22
				and size.z <= 0.22
				and size.y >= 0.65
			)
			if is_long_beam or is_vertical_post:
				mesh_instance.visible = false
				hidden_count += 1
	return hidden_count


func _spawn_dynamic_piece(
	piece_name: String,
	local_position: Vector3,
	box_size: Vector3,
	color: Color,
	body_mass: float,
	local_velocity: Vector3
) -> bool:
	if _road == null or _crash_set == null:
		return false

	var body: RigidBody3D = RigidBody3D.new()
	body.name = piece_name
	body.mass = body_mass
	body.freeze = false
	body.gravity_scale = 1.35
	body.can_sleep = false
	body.sleeping = false
	body.continuous_cd = true
	body.linear_damp = 0.06
	body.angular_damp = 0.04
	body.collision_layer = CRASH_PROP_LAYER
	body.collision_mask = 1 | CRASH_PROP_LAYER | CAR_CRASH_LAYER

	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.friction = 0.48
	physics_material.bounce = 0.24
	body.physics_material_override = physics_material

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.58
	material.roughness = 0.38
	mesh.material = material
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	_road.add_child(body)
	body.global_transform = Transform3D(
		_crash_set.global_basis,
		_crash_set.to_global(local_position)
	)

	var global_velocity: Vector3 = _crash_set.global_basis * local_velocity
	_launch_after_physics_frame(body, global_velocity)
	return true


func _launch_after_physics_frame(body: RigidBody3D, global_velocity: Vector3) -> void:
	await get_tree().physics_frame
	if body == null or not is_instance_valid(body):
		return
	body.freeze = false
	body.sleeping = false
	body.linear_velocity = global_velocity
	body.angular_velocity = Vector3(
		_rng.randf_range(-13.0, 13.0),
		_rng.randf_range(-15.0, 15.0),
		_rng.randf_range(-18.0, 18.0)
	)
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,
		global_velocity
	)
	body.apply_central_impulse(global_velocity * body.mass * 0.42)
	body.apply_torque_impulse(Vector3(
		_rng.randf_range(-22.0, 22.0),
		_rng.randf_range(-26.0, 26.0),
		_rng.randf_range(-30.0, 30.0)
	))


func _spawn_spark_fragments() -> void:
	for fragment_index: int in range(24):
		var fragment_position: Vector3 = Vector3(
			EDGE_RAIL_X,
			_rng.randf_range(0.55, 1.10),
			IMPACT_LOCAL_Z + _rng.randf_range(-2.0, 2.0)
		)
		_spawn_dynamic_piece(
			"FinalRailSpark_%02d" % fragment_index,
			fragment_position,
			Vector3(
				_rng.randf_range(0.05, 0.16),
				_rng.randf_range(0.04, 0.12),
				_rng.randf_range(0.10, 0.34)
			),
			Color("d9c48c") if fragment_index % 3 != 0 else Color("ffad54"),
			_rng.randf_range(0.12, 0.55),
			Vector3(
				_rng.randf_range(10.0, 22.0),
				_rng.randf_range(8.0, 18.0),
				_rng.randf_range(-14.0, 12.0)
			)
		)
