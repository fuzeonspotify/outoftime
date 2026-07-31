extends "res://scripts/models/realistic_environment_replacements.gd"


func _install_exact_environment() -> void:
	# Child _ready() runs before the level root's _ready(). One deferred frame is
	# enough for the procedural collision/layout pass to finish, without leaving
	# retired low-poly visuals visible for multiple rendered frames.
	await get_tree().process_frame

	_root = get_parent() as Node3D
	if _root == null:
		return
	if _root.get_node_or_null(EXACT_CONTAINER_NAME) != null:
		return

	_container = Node3D.new()
	_container.name = EXACT_CONTAINER_NAME
	_root.add_child(_container)

	match str(_root.name):
		"Cemetery":
			_upgrade_cemetery()
		"RoadMemory":
			_upgrade_memory_road()
			set_process(true)
		"HeavenDescent":
			_upgrade_false_heaven()
		"RuinedNightclub":
			_upgrade_nightclub()
		"SkeletonChamber":
			_upgrade_skeleton_chamber()
		_:
			push_error("No exact environment replacement plan for scene %s." % _root.name)


func _upgrade_cemetery() -> void:
	super._upgrade_cemetery()
	# street_lamp_02 is a required primary gate fixture, not an unused backup.
	_place_model(
		"street_lamp_02",
		Vector3(-3.65, 0.0, -28.7),
		Vector3(0.0, 20.0, 0.0),
		3.6
	)
	_place_model(
		"street_lamp_02",
		Vector3(3.65, 0.0, -28.7),
		Vector3(0.0, 160.0, 0.0),
		3.6
	)


func _upgrade_road_crash_barriers() -> void:
	var crash_set: Node3D = _root.get_node_or_null("BridgeCrashSet") as Node3D
	if crash_set == null:
		return
	var barriers: Array[Node] = crash_set.find_children(
		"CenteredBarrier*",
		"MeshInstance3D",
		true,
		false
	)
	if barriers.is_empty():
		return

	for node: Node in barriers:
		var barrier_mesh: MeshInstance3D = node as MeshInstance3D
		if barrier_mesh == null:
			continue
		var barrier_position: Vector3 = barrier_mesh.position
		var barrier_rotation: Vector3 = barrier_mesh.rotation_degrees
		barrier_mesh.visible = false
		barrier_mesh.queue_free()
		_place_model(
			"concrete_road_barrier_02",
			barrier_position,
			barrier_rotation,
			2.25,
			crash_set
		)
	_road_crash_upgraded = true
