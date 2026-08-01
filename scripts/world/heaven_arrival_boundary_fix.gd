extends Node

const OLD_FRONT_BOUNDARY_Z: float = 55.0
const POSITION_TOLERANCE: float = 0.25
const EXPECTED_WIDTH: float = 54.0
const EXPECTED_DEPTH: float = 2.0


func _ready() -> void:
	_remove_obsolete_front_boundary.call_deferred()


func _remove_obsolete_front_boundary() -> void:
	# The original Heaven map ended at Z=55. The expanded arrival court now
	# continues to Z=86, so this old anonymous collider must be removed while the
	# newer outer boundary remains active.
	for _frame_index: int in range(4):
		await get_tree().process_frame

	var heaven_root: Node3D = get_parent() as Node3D
	if heaven_root == null:
		return

	var static_bodies: Array[Node] = heaven_root.find_children(
		"*",
		"StaticBody3D",
		true,
		false
	)
	for node: Node in static_bodies:
		var body: StaticBody3D = node as StaticBody3D
		if body == null:
			continue
		if absf(body.position.z - OLD_FRONT_BOUNDARY_Z) > POSITION_TOLERANCE:
			continue
		if absf(body.position.x) > POSITION_TOLERANCE:
			continue

		var collision_nodes: Array[Node] = body.find_children(
			"*",
			"CollisionShape3D",
			true,
			false
		)
		for collision_node: Node in collision_nodes:
			var collision: CollisionShape3D = collision_node as CollisionShape3D
			if collision == null:
				continue
			var box: BoxShape3D = collision.shape as BoxShape3D
			if box == null:
				continue
			if absf(box.size.x - EXPECTED_WIDTH) > 0.5:
				continue
			if absf(box.size.z - EXPECTED_DEPTH) > 0.5:
				continue

			collision.disabled = true
			body.collision_layer = 0
			body.collision_mask = 0
			body.queue_free()
			return
