extends "res://scripts/world/bridge_crash_physics_director.gd"


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
	# collision. The right rail is intentionally manual so it cannot explode unless
	# the naturally simulated Porsche actually reaches the contact line.
	if not _center_triggered and _elapsed >= CENTER_IMPACT_DELAY:
		_trigger_center_impact()
	_reinforce_launched_bodies(delta)
