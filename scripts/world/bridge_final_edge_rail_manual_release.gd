extends "res://scripts/world/bridge_final_edge_rail_physics.gd"


func _physics_process(_delta: float) -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return

	if not _armed:
		_crash_set = _find_live_crash_set()
		if _crash_set != null:
			_armed = true
			_elapsed = 0.0
			print("BRIDGE FINAL EDGE RAIL ARMED FOR PHYSICAL CONTACT at ", _crash_set.global_position)
		return

	# The old elapsed-time fallback is deliberately removed. The active crash
	# sequence calls _trigger_final_edge_rail() only after the rigid Porsche has
	# physically reached the edge contact line.
