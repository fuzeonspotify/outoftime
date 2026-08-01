extends "res://scripts/world/bridge_crash_physics_director.gd"

const CRASH_DECK_SEGMENT_LENGTH: float = 24.0
const CRASH_DECK_SEGMENT_STRIDE: float = 23.5
const CRASH_DECK_SEGMENT_COUNT: int = 34
const CRASH_DECK_WIDTH: float = 12.4
const CRASH_DECK_THICKNESS: float = 1.20
const CRASH_DECK_FORWARD_EDGE_Z: float = 12.0


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
	# Retain the first-impact safety trigger, which matches the authored concrete
	# collision. Edge rails remain manual so they cannot explode unless the
	# naturally simulated Porsche actually reaches a contact line.
	if not _center_triggered and _elapsed >= CENTER_IMPACT_DELAY:
		_trigger_center_impact()
	_reinforce_launched_bodies(delta)


func _build_collision_deck() -> void:
	if _road == null or _crash_set == null:
		return

	var existing_deck: Node = _road.get_node_or_null("PhysicsCrashCollisionDeck")
	if existing_deck != null:
		existing_deck.queue_free()

	var deck: StaticBody3D = StaticBody3D.new()
	deck.name = "PhysicsCrashCollisionDeck"
	deck.collision_layer = 1
	deck.collision_mask = CRASH_PROP_LAYER | CAR_CRASH_LAYER

	var deck_material: PhysicsMaterial = PhysicsMaterial.new()
	deck_material.friction = 0.94
	deck_material.bounce = 0.015
	deck.physics_material_override = deck_material

	_road.add_child(deck)
	deck.global_transform = _crash_set.global_transform

	for segment_index: int in range(CRASH_DECK_SEGMENT_COUNT):
		var center_z: float = (
			CRASH_DECK_FORWARD_EDGE_Z
			- CRASH_DECK_SEGMENT_LENGTH * 0.5
			- float(segment_index) * CRASH_DECK_SEGMENT_STRIDE
		)

		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(
			CRASH_DECK_WIDTH,
			CRASH_DECK_THICKNESS,
			CRASH_DECK_SEGMENT_LENGTH
		)

		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "CrashDeckSection_%02d" % segment_index
		collision.shape = shape
		# Top of the collider remains at road height while the extra thickness
		# extends downward, preventing high-speed penetration through the bottom.
		collision.position = Vector3(
			0.0,
			-CRASH_DECK_THICKNESS * 0.5,
			center_z
		)
		deck.add_child(collision)

	var covered_length: float = (
		CRASH_DECK_SEGMENT_LENGTH
		+ float(CRASH_DECK_SEGMENT_COUNT - 1) * CRASH_DECK_SEGMENT_STRIDE
	)
	print(
		"BRIDGE CRASH COLLISION DECK READY: ",
		covered_length,
		" meters of thick overlapping road collision."
	)
